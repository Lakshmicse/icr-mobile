import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/app_notifications.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/feed/demo_feed_repository.dart';
import 'package:icr_mobile/features/feed/feed_controller.dart';
import 'package:icr_mobile/features/forum/thread_controller.dart';
import 'package:icr_mobile/features/forum/thread_screen.dart';
import 'package:icr_mobile/features/jobs/demo_jobs_repository.dart';
import 'package:icr_mobile/features/jobs/jobs_controller.dart';
import 'package:icr_mobile/features/messaging/widgets/chat_avatar.dart';
import 'package:icr_mobile/features/notifications/api_notifications_repository.dart';
import 'package:icr_mobile/features/notifications/notification_models.dart';
import 'package:icr_mobile/features/notifications/notification_router.dart';
import 'package:icr_mobile/features/notifications/notification_target.dart';
import 'package:icr_mobile/features/notifications/notifications_screen.dart';
import 'package:icr_mobile/features/notifications/unread_counts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'helpers/feed_fixtures.dart';
import 'helpers/fonts.dart';
import 'notifications_fakes.dart';

/// What a member is told when someone reacts to, reposts or tags them in a discussion (the portal's
/// `forum.reacted`, `forum.reactedToReply`, `forum.reposted`, `forum.mentioned`, `forum.mentionedInReply`, all aimed at
/// the discussion page `/community/<slug>`, a reply as `#reply-<id>`): the row is drawn with the person's photo, sits under
/// Community and articles, and a tap opens the discussion, at the reply when there is one.
void main() {
  setUpAll(loadAppFonts);

  /// A row as `GET /notifications` sends it (`NotificationDto`), by the person who did it.
  Map<String, Object?> row(
    String id, {
    required String type,
    required String title,
    String link = '/community/slug-iot',
    String? body = 'Implementing IoT sensors for HVAC efficiency: Best practices?',
    String actor = 'Priya',
  }) => {
    'id': id,
    'type': type,
    'title': title,
    'body': body,
    'link': link,
    'count': 1,
    'readAt': null,
    'createdAt': DateTime(2026, 10, 25, 9).toUtc().toIso8601String(),
    'actor': {
      'id': 'u-${actor.toLowerCase()}',
      'firstName': actor,
      'lastName': 'Nambiar',
      'avatarUrl': '/uploads/$actor.jpg',
    },
  };

  final rows = [
    row('n-react', type: 'forum_reaction', title: 'Priya Nambiar reacted to your post'),
    row(
      'n-react-reply',
      type: 'forum_reaction',
      title: 'Priya Nambiar liked your comment',
      link: '/community/slug-iot#reply-r9',
    ),
    row('n-repost', type: 'forum_repost', title: 'Priya Nambiar reposted your post'),
    row('n-mention', type: 'forum_mention', title: 'Priya Nambiar mentioned you in a post'),
    row(
      'n-mention-reply',
      type: 'forum_mention',
      title: 'Priya Nambiar mentioned you in a comment',
      link: '/community/slug-iot#reply-r9',
    ),
    // A type the app has no category for still lands under Community, because it links to a discussion.
    row('n-odd', type: 'info', title: 'Priya Nambiar reposted your post', actor: 'Anita'),
  ];

  late FakeForum api;
  late List<AppNotification> items;

  Future<void> read(WidgetTester tester) async {
    api = FakeForum({
      'GET /notifications': (_) => {
        'data': rows,
        'meta': {'page': 1, 'limit': 20, 'total': rows.length, 'totalPages': 1, 'hasNext': false, 'hasPrev': false},
      },
    });
    final repo = ApiNotificationsRepository(api: clientOn(api));
    items = (await tester.runAsync(repo.list))!.items;
  }

  group('what the API sends', () {
    testWidgets('each row carries the person who did it, with the photo as an address on the API\'s host', (
      tester,
    ) async {
      await read(tester);
      expect(items.length, rows.length);
      for (final n in items) {
        expect(n.actor, isNotNull, reason: n.id);
        expect(n.actor!.fullName, isNotEmpty);
        expect(n.actor!.photo?.url, startsWith('http://api.test/uploads/'), reason: n.id);
      }
      expect(items.first.actor!.photo!.url, 'http://api.test/uploads/Priya.jpg');
      expect(items.first.actorName, 'Priya Nambiar');
    });

    testWidgets('all of them are Community and articles, whatever type the API gave', (tester) async {
      await read(tester);
      for (final n in items) {
        expect(n.category.id, 'community', reason: '${n.id} (${n.type})');
      }
      expect(notificationCategoryOf('forum_reaction').id, 'community');
      expect(notificationCategoryOf('info').id, 'general', reason: 'by its type alone, an unknown one is general');
    });

    testWidgets('the target is the discussion, and the comment when the page names one', (tester) async {
      await read(tester);
      final targets = {for (final n in items) n.id: NotificationTarget.parse(n.link)};
      for (final t in targets.values) {
        expect(t.kind, NotificationKinds.forumThread);
        expect(t['slug'], 'slug-iot');
      }
      expect(targets['n-react']!['replyId'], isNull);
      expect(targets['n-react-reply']!['replyId'], 'r9');
      expect(targets['n-mention']!['replyId'], isNull);
      expect(targets['n-mention-reply']!['replyId'], 'r9');
    });
  });

  group('in the list', () {
    Future<NotificationRouter> pumpList(
      WidgetTester tester,
      List<AppNotification> rows, {
      NotificationRouter? router,
    }) async {
      final repo = FakeNotificationsRepository(items: rows, pageSize: 100);
      final counts = UnreadCounts(_NoSource(), interval: const Duration(hours: 1));
      addTearDown(counts.dispose);
      final r = router ?? NotificationRouter(openers: const {});
      tester.view.physicalSize = const Size(780, 4000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<UnreadCounts>.value(value: counts),
            Provider<NotificationRouter>.value(value: r),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: NotificationsScreen(repository: repo, clock: () => DateTime(2026, 10, 25, 15)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return r;
    }

    testWidgets('a row is drawn with the person\'s photo and the Community glyph on its corner', (tester) async {
      await read(tester);
      await pumpList(tester, items);
      for (final n in items) {
        final tile = find.byKey(ValueKey('notification-${n.id}'));
        expect(tile, findsOneWidget, reason: n.id);
        final avatar = tester.widget<ChatAvatar>(find.descendant(of: tile, matching: find.byType(ChatAvatar)));
        expect(avatar.picture?.url, n.actor!.photo!.url, reason: '${n.id}: the actor\'s photo');
        expect(
          find.descendant(of: tile, matching: find.byIcon(LucideIcons.messagesSquare)),
          findsOneWidget,
          reason: n.id,
        );
      }
      expect(find.byKey(const ValueKey('chip-community')), findsOneWidget, reason: 'one chip for all of them');
    });

    testWidgets('the Community chip keeps them, and a row of another kind is left out', (tester) async {
      await read(tester);
      final other = note('n-msg', title: 'Someone sent you a message', type: 'message', link: '/messaging');
      await pumpList(tester, [...items, other]);
      expect(find.byKey(const ValueKey('notification-n-msg')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('chip-community')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('notification-n-msg')), findsNothing);
      for (final n in items) {
        expect(find.byKey(ValueKey('notification-${n.id}')), findsOneWidget, reason: n.id);
      }
    });

    testWidgets('a tap hands the discussion\'s page to the router, with the comment when there is one', (tester) async {
      await read(tester);
      final opened = <NotificationTarget>[];
      final router = NotificationRouter(
        openers: {
          NotificationKinds.forumThread: (context, t) {
            opened.add(t);
            return true;
          },
        },
      );
      await pumpList(tester, items, router: router);
      await tester.tap(find.byKey(const ValueKey('notification-n-react')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('notification-n-mention-reply')));
      await tester.tap(find.byKey(const ValueKey('notification-n-mention-reply')));
      await tester.pump();
      expect(opened.map((t) => (t['slug'], t['replyId'])), [('slug-iot', null), ('slug-iot', 'r9')]);
    });
  });

  group('opening it', () {
    late Map<String, NotificationOpener> openers;

    Future<void> tapThrough(WidgetTester tester, String href) async {
      late NotificationRouter router;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<JobsController>(create: (_) => JobsController(DemoJobsRepository())),
              ChangeNotifierProvider<FeedController>(create: (_) => FeedController(DemoFeedRepository())),
            ],
            child: Builder(
              builder: (shell) {
                openers = appNotificationOpeners(shell: shell, viewer: DemoFeedRepository.me);
                router = NotificationRouter(openers: openers, openSite: (context, path) async {});
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(shell).push(
                        // A pushed route, as the notifications list is: above the providers.
                        MaterialPageRoute<void>(
                          builder: (routeContext) => Scaffold(
                            body: ElevatedButton(
                              key: const ValueKey('tap'),
                              onPressed: () => router.open(routeContext, NotificationTarget.parse(href)),
                              child: const Text('tap'),
                            ),
                          ),
                        ),
                      ),
                      child: const Text('go'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tap')));
      await tester.pumpAndSettle();
    }

    ThreadController thread(WidgetTester tester) =>
        Provider.of<ThreadController>(tester.element(find.byType(ThreadScreen)), listen: false);

    testWidgets('a reaction, a repost or a mention in a post opens the discussion', (tester) async {
      await tapThrough(tester, '/community/slug-iot');
      expect(find.byType(ThreadScreen), findsOneWidget);
      expect(thread(tester).slug, 'slug-iot');
      expect(thread(tester).focusReplyId, isNull);
    });

    testWidgets('a reaction or a mention in a comment opens the discussion at that comment', (tester) async {
      await tapThrough(tester, '/community/slug-iot#reply-r9');
      expect(find.byType(ThreadScreen), findsOneWidget);
      expect(thread(tester).slug, 'slug-iot');
      expect(thread(tester).focusReplyId, 'r9');
    });
  });
}

class _NoSource implements UnreadSource {
  @override
  Future<int> notifications() async => 0;

  @override
  Future<int> messages() async => 0;
}
