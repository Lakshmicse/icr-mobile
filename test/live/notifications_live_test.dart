@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/app_notifications.dart' show appNotificationKinds, notificationKindsInWebView;
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/messaging/api_messaging_repository.dart';
import 'package:icr_mobile/features/notifications/api_notifications_repository.dart';
import 'package:icr_mobile/features/notifications/notification_models.dart';
import 'package:icr_mobile/features/notifications/notification_router.dart';
import 'package:icr_mobile/features/notifications/notification_target.dart';
import 'package:icr_mobile/features/notifications/unread_counts.dart';

import 'live.dart';

/// The bell against the local API: every parser on what the API really answers
/// (the rows `tool/seed/inbox.ts` gives Bharat Buyer), and every write.
///
/// Bharat's own rows are only READ here, so the emulator keeps its unread
/// count. The writes (read one, read all, "I opened the record") run as the
/// supplier's seller (Vikram Vendor): the Inbox Persona (Anita Rao,
/// `tool/seed/inbox.ts`) writes to the supplier's inbox in a thread Bharat is
/// not in, which makes the API write each of the supplier's people a bell row.
/// Nothing in the API un-reads a notification, so those rows stay behind as
/// read ones (one per message sent); re-running the seed clears them. The
/// messages the persona sent are withdrawn.
///
/// (A message between two PEOPLE writes no bell row at all: see
/// `docs/backend-requests/messaging.md`.)
///
/// Run: `flutter test test/live/notifications_live_test.dart --concurrency=1`
const vendor = LivePerson('vendor@icr.dev', 'Vendor@123', 'Vikram Vendor');
const anita = LivePerson('inbox.friend@inbox-seed.icr.test', 'Inbox@12345', 'Anita Rao');

const _sandboxThread = 'inbox-seed-conv-sandbox';
const _supplierCompany = 'cmupai6jm01esmyzcwg2fprhe';

void main() {
  liveTest('the list: every field of the real rows reads, grouped counts and company logos included', () async {
    final repo = ApiNotificationsRepository(api: await liveClient());
    final page = await repo.list();
    expect(page.items, isNotEmpty, reason: 'run tool/seed/inbox.ts: Bharat has the seeded rows');
    expect(page.total, greaterThanOrEqualTo(page.items.length));

    for (final n in page.items) {
      expect(n.id, isNotEmpty);
      expect(n.title, isNotEmpty);
      expect(n.type, isNotEmpty);
      expect(n.count, greaterThanOrEqualTo(1));
      expect(n.category.id, isNotEmpty);
      // A person's photo comes back as an absolute URL.
      final photo = n.actor?.photo?.url;
      if (photo != null) expect(photo, startsWith('http'));
    }

    final byId = {for (final n in page.items) n.id: n};
    final grouped = byId['inbox-seed-n-msg-sarah'];
    expect(grouped, isNotNull);
    expect(grouped!.count, 3);
    expect(grouped.title, 'Sarah Jenkins sent you 3 messages');
    expect(grouped.actor!.fullName, 'Sarah Jenkins');
    expect(grouped.category.id, 'messages');

    final fromCompany = byId['inbox-seed-n-msg-company'];
    expect(fromCompany!.actorCompany!.name, 'Global Infra Solutions');
    expect(fromCompany.actorCompany!.logo!.url, startsWith('http'));
    expect(fromCompany.actorName, 'Global Infra Solutions');

    final platform = byId['inbox-seed-n-app-stage'];
    expect(platform!.actor, isNull);
    expect(platform.body, isNotNull);
    expect(platform.category.id, 'jobs');
  });

  liveTest('every link the API stored names a page the app knows how to open', () async {
    final repo = ApiNotificationsRepository(api: await liveClient());
    final kinds = <String, String>{};
    for (var page = 1; page <= 3; page++) {
      final got = await repo.list(page: page);
      for (final n in got.items.where((n) => n.link != null)) {
        final target = NotificationTarget.parse(n.link);
        kinds[n.link!] = target.kind;
        expect(target.kind, isNot(NotificationKinds.none), reason: n.link);
        expect(target.href, n.link, reason: 'kept as stored for the website fallback');
      }
      if (!got.hasMore) break;
    }
    // The seeded rows cover these kinds.
    expect(kinds.values.toSet(), containsAll(['conversation', 'application.candidate', 'event', 'forum.thread']));
    expect(kinds.entries.firstWhere((e) => e.value == 'conversation').key, startsWith('/messaging?c='));
    final record = NotificationTarget.parse('/career/applications/design-lj-app-bharat-extra-2');
    expect(record.recordId, 'design-lj-app-bharat-extra-2');
  });

  liveTest(
    'every kind of notification in the list opens in the app: a screen, nothing (staff) or the web view the doc names',
    () async {
      final repo = ApiNotificationsRepository(api: await liveClient());
      final seen = <String, int>{};
      for (var page = 1; page <= 10; page++) {
        final got = await repo.list(page: page);
        for (final n in got.items) {
          final kind = NotificationTarget.parse(n.link).kind;
          seen[kind] = (seen[kind] ?? 0) + 1;
        }
        if (!got.hasMore) break;
      }
      expect(seen, isNotEmpty);
      final inApp = {...appNotificationKinds, ...NotificationRouter.builtInKinds};
      final staff = NotificationRouter.staffKinds;
      final strangers = [
        for (final kind in seen.keys)
          if (kind != NotificationKinds.none &&
              !inApp.contains(kind) &&
              !staff.contains(kind) &&
              !notificationKindsInWebView.contains(kind))
            kind,
      ];
      expect(
        strangers,
        isEmpty,
        reason: 'a kind in the list that the table in docs/NOTIFICATION_TARGETS.md does not place',
      );
      final viaWebView = seen.keys.where(notificationKindsInWebView.contains).toList();
      // ignore: avoid_print
      print('notification kinds in Bharat\'s list: $seen; in the web view: $viaWebView');
      expect(seen.keys.any(inApp.contains), isTrue, reason: 'the seeded rows include records the app opens itself');
    },
  );

  liveTest('the unread count is every unread row, and the Unread tab lists exactly those', () async {
    final repo = ApiNotificationsRepository(api: await liveClient());
    final count = await repo.unreadCount();
    final unread = await repo.list(unreadOnly: true);
    expect(unread.total, count);
    expect(unread.items.every((n) => n.unread), isTrue);
    final all = await repo.list();
    expect(all.total, greaterThanOrEqualTo(count));
  });

  liveTest('the app-wide counts read the same numbers the screens do', () async {
    final api = await liveClient();
    final notes = ApiNotificationsRepository(api: api);
    final counts = UnreadCounts.api(api, interval: const Duration(hours: 1));
    addTearDown(counts.dispose);
    await counts.refresh();
    expect(counts.notifications, await notes.unreadCount());
    final res = await api.dio.get<Map<String, dynamic>>('/messaging/unread-count');
    expect(counts.messages, (res.data!['count'] as num).toInt());
  });

  liveTest('preferences: the 15 categories with their locks; a switch is kept and put back', () async {
    final repo = ApiNotificationsRepository(api: await liveClient());
    final before = await repo.preferences();
    expect(before.length, notificationCategories.length);
    expect(before.where((p) => p.locked).map((p) => p.category.id), ['payments', 'support', 'security']);

    final community = before.firstWhere((p) => p.category.id == 'community');
    final flipped = await repo.savePreference(community.copyWith(email: !community.email));
    expect(flipped.firstWhere((p) => p.category.id == 'community').email, !community.email);
    expect((await repo.preferences()).firstWhere((p) => p.category.id == 'community').email, !community.email);

    // Undo.
    final restored = await repo.savePreference(community);
    expect(restored.firstWhere((p) => p.category.id == 'community').email, community.email);
  });

  liveTest('the viewer: who is reading and how many companies they belong to', () async {
    final bharatApi = await liveClient();
    final bharatView = await ApiNotificationsRepository(api: bharatApi).viewer();
    expect(bharatView.id, isNotEmpty);
    // As many companies as the API lists for him (other screens' live runs may have founded one).
    final listed = await bharatApi.dio.get<Map<String, dynamic>>('/me/companies');
    expect(bharatView.companyCount, (listed.data!['companies'] as List).length);

    final vendorView = await ApiNotificationsRepository(api: await liveClient(vendor)).viewer();
    expect(vendorView.id, isNot(bharatView.id));
    expect(vendorView.activeCompanyId, isNotNull);
    expect(vendorView.companyCount, greaterThanOrEqualTo(1));
  });

  liveTest('switching to a company the person works for gives a session that still works', () async {
    final api = await liveClient(vendor, true);
    final repo = ApiNotificationsRepository(api: api);
    final viewer = await repo.viewer();
    await repo.switchCompany(viewer.activeCompanyId!);
    // The new token pair is the session now.
    final again = await repo.viewer();
    expect(again.id, viewer.id);
    expect(again.activeCompanyId, viewer.activeCompanyId);
  });

  liveTest(
    'reading: a message to a supplier is a bell row for its people that groups, can be seen, read, and read all',
    () async {
      final sender = ApiMessagingRepository(api: await liveClient(anita));
      final bell = ApiNotificationsRepository(api: await liveClient(vendor));
      final sent = <String>[];
      addTearDown(() async {
        for (final id in sent) {
          try {
            await sender.deleteMessage(_sandboxThread, id);
          } catch (_) {}
        }
      });
      Future<void> say(String text) async => sent.add((await sender.send(_sandboxThread, body: text)).id);
      Future<AppNotification> aboutThread() async {
        final page = await bell.list(unreadOnly: true);
        return page.items.firstWhere(
          (n) => (n.link ?? '').contains('c=$_sandboxThread'),
          orElse: () => throw StateError('no unread row about $_sandboxThread: re-run tool/seed/inbox.ts'),
        );
      }

      // Start from nothing waiting about this thread.
      await bell.markSeen('conversation', _sandboxThread);
      final baseline = await bell.unreadCount();

      await say('notifications live test 1');
      var row = await aboutThread();
      expect(row.count, 1);
      expect(row.title, contains('Anita Rao'));
      expect(row.category.id, 'messages');
      expect(await bell.unreadCount(), baseline + 1);

      // A second message folds into the same unread row: "sent you 2 messages".
      await say('notifications live test 2');
      row = await aboutThread();
      expect(row.count, 2);
      expect(row.title, contains('2 messages'));
      expect(await bell.unreadCount(), baseline + 1, reason: 'one row, not two');

      // The row names the thread and the company inbox it is answered in.
      final target = NotificationTarget.parse(row.link);
      expect(target.kind, NotificationKinds.conversation);
      expect(target.recordId, _sandboxThread);
      expect(target['inbox'], _supplierCompany, reason: 'a seller reads it from the company inbox');

      // Opening the record reads whatever told them about it.
      expect(await bell.markSeen(target.kind, target.recordId!), 1);
      expect(await bell.unreadCount(), baseline);
      expect((await bell.list()).items.firstWhere((n) => n.id == row.id).unread, isFalse);

      // Reading one row.
      await say('notifications live test 3');
      row = await aboutThread();
      await bell.markRead(row.id);
      expect(await bell.unreadCount(), baseline);
      expect((await bell.list()).items.firstWhere((n) => n.id == row.id).unread, isFalse);

      // Reading all.
      await say('notifications live test 4');
      await aboutThread();
      expect(await bell.unreadCount(), greaterThan(0));
      expect(await bell.markAllRead(), greaterThanOrEqualTo(1));
      expect(await bell.unreadCount(), 0);
      expect((await bell.list(unreadOnly: true)).items, isEmpty);
    },
  );

  liveTest("a refused read is the API's own sentence", () async {
    final repo = ApiNotificationsRepository(api: await liveClient());
    Object? caught;
    try {
      await repo.markRead('no-such-notification');
    } catch (e) {
      caught = e;
    }
    expect(caught, isNotNull);
    final error = ApiError.from(caught!);
    expect(error.statusCode, 404);
    expect(error.message, isNotEmpty);
  });
}
