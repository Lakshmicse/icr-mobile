/// Role matrix, part 8: Notifications and Messaging for the four accounts that belong to no company, with the
/// two-person checks: one account acts, the other sees it. The notifications read are the ones the test provoked
/// (a reply to a discussion it made), so no account's seeded unread rows are touched. A message cannot be taken
/// back; it can be withdrawn, and the plain thread between two people is reused by every run.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/forum/forum_models.dart';
import 'package:icr_mobile/features/messaging/api_messaging_repository.dart';
import 'package:icr_mobile/features/messaging/inbox_screen.dart';
import 'package:icr_mobile/features/messaging/messaging_repository.dart';
import 'package:icr_mobile/features/notifications/api_notifications_repository.dart';
import 'package:icr_mobile/features/notifications/notification_target.dart';
import 'package:icr_mobile/features/notifications/notifications_screen.dart';

import '../helpers/fonts.dart';
import 'career_live_support.dart';
import 'live.dart';
import 'role_buyer_community.dart';
import 'role_buyer_support.dart';

final _notifications = <String, ApiNotificationsRepository>{};
ApiNotificationsRepository notificationsOf(Who w) =>
    _notifications.putIfAbsent(w.email, () => ApiNotificationsRepository(api: w.api));

final _messaging = <String, ApiMessagingRepository>{};
ApiMessagingRepository messagingOf(Who w) =>
    _messaging.putIfAbsent(w.email, () => ApiMessagingRepository(api: w.api, viewerId: w.id));

void roleBuyerInbox() {
  setUpAll(loadAppFonts);

  group('Notifications', () {
    liveTest('the list, the unread count and the preferences read for every account', () async {
      for (final w in await everyone()) {
        final repo = notificationsOf(w);
        final all = await repo.list();
        final unread = await repo.list(unreadOnly: true);
        final count = await repo.unreadCount();
        expect(count, greaterThanOrEqualTo(0));
        expect(unread.total, count, reason: '${w.email}: the unread list and the count agree');
        final prefs = await repo.preferences();
        expect(prefs, isNotEmpty);
        await repo.viewer();
        record('Notifications: list, unread, preferences', w.person, 'works', '${all.total} rows, $count unread');
      }
    });

    liveTest(
      'a reply to your discussion reaches your bell, names its page, reads, and opens its target (two-person)',
      () async {
        final people = await everyone();
        for (var i = 0; i < people.length; i++) {
          final author = people[i];
          final replier = people[(i + 1) % people.length];
          final a = feedsOf(author);
          final b = feedsOf(replier);
          final tree = await a.forum.taxonomy();
          final stamp = DateTime.now().millisecondsSinceEpoch;
          final thread = await a.forum.create(
            ForumDraft(
              categoryKey: tree.first.key,
              title: 'Role matrix bell ${author.first} $stamp',
              body: 'A discussion the role matrix replies to, to ring the bell.',
              tags: const ['rolematrix'],
            ),
          );
          try {
            final repo = notificationsOf(author);
            final before = await repo.unreadCount();
            await b.forum.reply(thread.card.id, 'Hello from ${replier.first}.');
            // The notification is written as the reply is; it may take a moment to be listed.
            var row = (await repo.list(
              unreadOnly: true,
            )).items.where((n) => n.link?.contains(thread.card.slug) ?? false);
            for (var tries = 0; row.isEmpty && tries < 5; tries++) {
              await Future<void>.delayed(const Duration(milliseconds: 400));
              row = (await repo.list(unreadOnly: true)).items.where((n) => n.link?.contains(thread.card.slug) ?? false);
            }
            expect(row, isNotEmpty, reason: '${author.email}: the reply is in the bell');
            final n = row.first;
            expect(n.unread, isTrue);
            expect(await repo.unreadCount(), greaterThan(before));
            final target = NotificationTarget.parse(n.link);
            expect(target.kind, isNot(NotificationKinds.none), reason: 'the row names a page the app knows');
            expect(target.href, contains(thread.card.slug));
            await repo.markRead(n.id);
            final after = (await repo.list()).items.firstWhere((x) => x.id == n.id);
            expect(after.unread, isFalse, reason: 'the row is read');
            record(
              'Notifications: a reply rings the bell, names its target, marks read',
              author.person,
              'works',
              'two-person with ${replier.first}',
            );
          } finally {
            await a.forum.deleteThread(thread.card.id);
          }
        }
      },
    );
  });

  group('Messaging', () {
    liveTest('the inbox, its filters, search and unread count read for every account', () async {
      for (final w in await everyone()) {
        final repo = messagingOf(w);
        expect(await repo.viewerId(), w.id);
        await repo.inboxes();
        final page = await repo.conversations(const ConversationQuery());
        await repo.conversations(const ConversationQuery(filter: InboxFilter.unread));
        await repo.conversations(const ConversationQuery(filter: InboxFilter.starred));
        await repo.pinned();
        await repo.searchMessages('hello');
        final unread = await repo.unreadCount();
        expect(unread.count, greaterThanOrEqualTo(0));
        if (page.conversations.isNotEmpty) {
          final first = page.conversations.first;
          final window = await repo.thread(first.id);
          expect(window.conversation.id, first.id);
        }
        record('Messaging: inbox, filters, search, open a thread', w.person, 'works');
      }
    });

    liveTest(
      'New message: a person is found, the thread starts, a message is sent, read, answered and withdrawn',
      () async {
        final people = await everyone();
        for (var i = 0; i < people.length; i++) {
          final a = people[i];
          final b = people[(i + 1) % people.length];
          final ra = messagingOf(a);
          final rb = messagingOf(b);
          final stamp = DateTime.now().millisecondsSinceEpoch;

          // New message: search finds the other person (two letters or more).
          final found = await ra.recipients(b.first.substring(0, 3));
          expect(found.people.map((p) => p.person.id), contains(b.id), reason: '${a.email} finds ${b.email}');

          final id = await ra.startWithPerson(b.id);
          final sent = await ra.send(id, body: 'Role matrix hello from ${a.first} $stamp.');
          // The other side sees the thread, with the message waiting, reads it, answers.
          final theirs = await rb.conversations(const ConversationQuery());
          expect(theirs.conversations.map((c) => c.id), contains(id), reason: '${b.email} sees the thread');
          final window = await rb.thread(id);
          expect(window.messages.map((m) => m.id), contains(sent.id));
          await rb.markRead(id);
          final answer = await rb.send(id, body: 'Role matrix reply from ${b.first} $stamp.', replyToId: sent.id);
          final back = await ra.thread(id);
          expect(back.messages.map((m) => m.id), contains(answer.id), reason: '${a.email} sees the answer');
          // Withdraw both messages: the thread stays (the API reuses a plain thread), the words go.
          await ra.deleteMessage(id, sent.id);
          await rb.deleteMessage(id, answer.id);
          record(
            'Messaging: New message, send, read, reply, withdraw',
            a.person,
            'works',
            'two-person with ${b.first}',
          );
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });

  group('the Notifications and Messages screens, drawn for every account', () {
    testWidgets('the bell\'s list and the inbox draw for every account', tags: const ['live'], (tester) async {
      if (!await liveScreenReady(tester)) return;
      for (final w in (await tester.runAsync(everyone))!) {
        final targets = <NotificationTarget>[];
        await loadScreen(
          tester,
          NotificationsScreen(repository: notificationsOf(w), onOpenTarget: (c, t) async => targets.add(t)),
          size: const Size(390, 1600),
        );
        var text = expectHealthy(tester, 'Notifications as ${w.email}');
        expect(text, contains('Notifications'));
        expect(text, contains('Preferences'));
        await unmount(tester);

        await loadScreen(tester, InboxScreen(repository: messagingOf(w)), size: const Size(390, 1600));
        text = expectHealthy(tester, 'the inbox as ${w.email}');
        expect(text, contains('Messaging'));
        await unmount(tester);
        record('Notifications and Messages: screens', w.person, 'works');
      }
    });
  });
}
