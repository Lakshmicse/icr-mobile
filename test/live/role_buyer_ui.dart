/// Role matrix, part 10: controls driven through the real screens over the live API, for the four accounts that
/// belong to no company: every tab of My mentoring, a bell row opened to its target, and a message typed into a
/// conversation and sent. The two-person ones: one account acts through the screen, the other sees it through the API.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/features/forum/forum_models.dart';
import 'package:icr_mobile/features/mentorship_my/my_mentoring_controller.dart' show MyTab;
import 'package:icr_mobile/features/mentorship_my/my_mentoring_screen.dart';
import 'package:icr_mobile/features/messaging/conversation_screen.dart';
import 'package:icr_mobile/features/notifications/notification_target.dart';
import 'package:icr_mobile/features/notifications/notifications_screen.dart';
import 'package:provider/provider.dart';

import '../helpers/fonts.dart';
import 'career_live_support.dart';
import 'role_buyer_community.dart';
import 'role_buyer_inbox.dart';
import 'role_buyer_mentorship.dart';
import 'role_buyer_support.dart';

void roleBuyerUi() {
  setUpAll(loadAppFonts);

  group('controls driven through the screens', () {
    testWidgets('My mentoring: every tab the account has opens and reads', tags: const ['live'], (tester) async {
      if (!await liveScreenReady(tester)) return;
      for (final w in (await tester.runAsync(everyone))!) {
        await loadScreen(
          tester,
          MyMentoringScreen(repository: mentoringOf(w)),
          appProviders: [Provider<ApiClient>.value(value: w.api)],
          size: const Size(390, 2200),
        );
        expectHealthy(tester, 'My mentoring as ${w.email}');
        var opened = 0;
        for (final tab in MyTab.values) {
          final label = find.text(tab.label);
          if (label.evaluate().isEmpty) continue; // tabs a person does not have are not drawn (Saved, Goals...)
          await tester.ensureVisible(label.first);
          await tester.tap(label.first);
          await afterTap(tester);
          expectHealthy(tester, 'My mentoring "${tab.label}" as ${w.email}');
          opened++;
        }
        expect(opened, greaterThanOrEqualTo(3), reason: '${w.email}: the tab strip has tabs');
        await unmount(tester);
        record('Mentorship: My mentoring, every tab opened', w.person, 'works', '$opened tabs');
      }
    });

    testWidgets(
      'a bell row opens its target in the app and reads (a reply to the account\'s own discussion)',
      tags: const ['live'],
      (tester) async {
        if (!await liveScreenReady(tester)) return;
        final people = (await tester.runAsync(everyone))!;
        for (var i = 0; i < people.length; i++) {
          final author = people[i];
          final replier = people[(i + 1) % people.length];
          final a = feedsOf(author);
          final tree = (await tester.runAsync(a.forum.taxonomy))!;
          final stamp = DateTime.now().millisecondsSinceEpoch;
          final thread = (await tester.runAsync(
            () => a.forum.create(
              ForumDraft(
                categoryKey: tree.first.key,
                title: 'Role matrix bell row ${author.first} $stamp',
                body: 'A discussion the role matrix replies to, then opens from the bell.',
                tags: const ['rolematrix'],
              ),
            ),
          ))!;
          try {
            await tester.runAsync(
              () => feedsOf(replier).forum.reply(thread.card.id, 'Bell row from ${replier.first}.'),
            );
            await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 800)));
            final targets = <NotificationTarget>[];
            await loadScreen(
              tester,
              NotificationsScreen(
                repository: notificationsOf(author),
                onOpenTarget: (context, target) async => targets.add(target),
              ),
              size: const Size(390, 2400),
            );
            // The newest row is the reply; tap it.
            final row = (await tester.runAsync(
              () => notificationsOf(author).list(),
            ))!.items.firstWhere((n) => n.link?.contains(thread.card.slug) ?? false);
            final title = find.textContaining(row.title.split(' ').first);
            await waitFor(tester, title);
            await tester.ensureVisible(title.first);
            await tester.tap(title.first);
            await afterTap(tester);
            expect(targets, isNotEmpty, reason: '${author.email}: the tap opened a target');
            expect(targets.single.href, contains(thread.card.slug));
            final after = (await tester.runAsync(
              () => notificationsOf(author).list(),
            ))!.items.firstWhere((n) => n.id == row.id);
            expect(after.unread, isFalse, reason: 'the row is read by opening it');
            expectHealthy(tester, 'Notifications as ${author.email}');
            await unmount(tester);
            record(
              'Notifications: a row opens its target and reads',
              author.person,
              'works',
              'two-person with ${replier.first}',
            );
          } finally {
            await tester.runAsync(() => a.forum.deleteThread(thread.card.id));
          }
        }
      },
    );

    testWidgets(
      'Messages: a message is typed into the conversation and sent, and the other person has it',
      tags: const ['live'],
      (tester) async {
        if (!await liveScreenReady(tester)) return;
        final people = (await tester.runAsync(everyone))!;
        for (var i = 0; i < people.length; i++) {
          final a = people[i];
          final b = people[(i + 1) % people.length];
          final id = (await tester.runAsync(() => messagingOf(a).startWithPerson(b.id)))!;
          final text = 'Typed by ${a.first} in the role matrix ${DateTime.now().millisecondsSinceEpoch}';
          await loadScreen(
            tester,
            ConversationScreen(conversationId: id, repository: messagingOf(a), poll: false),
            size: const Size(390, 1400),
          );
          expectHealthy(tester, 'the conversation as ${a.email}');
          await tester.enterText(find.byKey(const ValueKey('composer')), text);
          await tester.pump();
          await tester.tap(find.byKey(const ValueKey('send')));
          await waitFor(tester, find.text(text));
          await afterTap(tester);
          expect(find.text(text), findsOneWidget, reason: '${a.email}: the message is in the thread');
          final window = (await tester.runAsync(() => messagingOf(b).thread(id)))!;
          final sent = window.messages.firstWhere(
            (m) => m.body == text,
            orElse: () => throw StateError('${b.email} does not have it'),
          );
          await tester.runAsync(() => messagingOf(a).deleteMessage(id, sent.id));
          await unmount(tester);
          record(
            'Messages: type and send in a conversation',
            a.person,
            'works',
            'two-person with ${b.first}; withdrawn after',
          );
        }
      },
    );
  });
}
