import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/core/widgets/title_bar.dart';
import 'package:icr_mobile/features/messaging/messaging_models.dart';
import 'package:icr_mobile/features/notifications/notification_models.dart';
import 'package:icr_mobile/features/notifications/notification_router.dart';
import 'package:icr_mobile/features/notifications/notification_seen.dart';
import 'package:icr_mobile/features/notifications/notification_target.dart';
import 'package:icr_mobile/features/notifications/notifications_bell.dart';
import 'package:icr_mobile/features/notifications/notifications_controller.dart';
import 'package:icr_mobile/features/notifications/notifications_repository.dart';
import 'package:icr_mobile/features/notifications/notifications_screen.dart';
import 'package:icr_mobile/features/notifications/unread_counts.dart';
import 'package:icr_mobile/features/notifications/widgets/notification_row.dart';
import 'package:provider/provider.dart';

import 'helpers/fonts.dart';
import 'messaging_fakes.dart';
import 'notifications_fakes.dart';

/// Every control of the bell screen, tapped: the list and its groups, reading
/// one row or all, what a tap opens (the app's own screen, or the website),
/// the Unread and Preferences tabs, paging, refresh and every refusal. What the
/// API does with each call is proved in `test/live/notifications_live_test.dart`.
void main() {
  setUpAll(loadAppFonts);

  final now = DateTime(2026, 10, 25, 15);

  /// Today, this week and earlier; three unread.
  List<AppNotification> sample() => [
    note(
      'msg',
      title: 'Sarah Jenkins sent you 3 messages',
      type: 'message',
      link: '/messaging?c=conv-1',
      count: 3,
      at: DateTime(2026, 10, 25, 14, 20),
      actor: const ChatPerson(id: 'sarah', firstName: 'Sarah', lastName: 'Jenkins'),
    ),
    note(
      'app',
      title: 'Your application for Energy Lead moved to Screening',
      body: 'Global Infra Solutions will be in touch.',
      type: 'application_stage_changed',
      link: '/career/applications/app-1',
      at: DateTime(2026, 10, 25, 9),
    ),
    note(
      'event',
      title: 'Reminder: Summit starts tomorrow',
      type: 'event_reminder',
      link: '/events/summit-design',
      at: DateTime(2026, 10, 24, 10),
      read: true,
    ),
    note(
      'forum',
      title: 'Marcus Reed replied to your discussion',
      type: 'forum_reply',
      link: '/community/thread-1#reply-r9',
      at: DateTime(2026, 10, 22, 8),
      actor: const ChatPerson(id: 'marcus', firstName: 'Marcus', lastName: 'Reed'),
    ),
    note(
      'ticket',
      title: 'Support replied to your request',
      type: 'support_reply',
      link: '/support/t-1',
      at: DateTime(2026, 10, 5, 8),
      read: true,
    ),
  ];

  late FakeNotificationsRepository repo;
  late List<String> opened;
  late List<String> siteOpened;
  late NotificationRouter router;
  late UnreadCounts counts;

  Future<void> pump(
    WidgetTester tester, {
    FakeNotificationsRepository? repository,
    NotificationsTab tab = NotificationsTab.all,
    NotificationTargetOpener? onOpenTarget,
    Size size = const Size(390, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repo = repository ?? FakeNotificationsRepository(items: sample());
    opened = [];
    siteOpened = [];
    router = NotificationRouter(
      openSite: (context, path) async => siteOpened.add(path),
      openers: {
        for (final kind in [
          NotificationKinds.applicationCandidate,
          NotificationKinds.event,
          NotificationKinds.forumThread,
          NotificationKinds.mentorshipMine,
        ])
          kind: (context, t) {
            opened.add('${t.kind} ${t.params}');
            return true;
          },
      },
    );
    counts = UnreadCounts(_NoSource(), interval: const Duration(hours: 1));
    addTearDown(counts.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UnreadCounts>.value(value: counts),
          Provider<NotificationRouter>.value(value: router),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: NotificationsScreen(repository: repo, initialTab: tab, onOpenTarget: onOpenTarget, clock: () => now),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder row(String id) => find.byKey(ValueKey('notification-$id'));
  Finder dotIn(String id) => find.descendant(of: row(id), matching: find.byKey(const ValueKey('unread-dot')));
  Finder textIn(String id, String text) =>
      find.descendant(of: row(id), matching: find.textContaining(text, findRichText: true));

  group('the list', () {
    testWidgets('groups rows Today, This week and Earlier, newest first, with the unread count on its chip', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('This week'), findsOneWidget);
      expect(find.text('Earlier'), findsOneWidget);
      expect(find.byType(NotificationRow), findsNWidgets(5));
      // Heading order: Today above This week above Earlier.
      expect(tester.getTopLeft(find.text('Today')).dy, lessThan(tester.getTopLeft(find.text('This week')).dy));
      expect(tester.getTopLeft(find.text('This week')).dy, lessThan(tester.getTopLeft(find.text('Earlier')).dy));
      expect(find.text('Unread (3)'), findsOneWidget);
    });

    testWidgets('a row shows its age short, as LinkedIn does: now, 5m, 3h, 2d, 1w', (tester) async {
      await pump(tester);
      expect(textIn('msg', '40m'), findsOneWidget, reason: '14:20 against a 15:00 clock');
      expect(textIn('app', '6h'), findsOneWidget);
      expect(textIn('event', '1d'), findsOneWidget);
      expect(textIn('forum', '3d'), findsOneWidget);
      expect(textIn('ticket', '2w'), findsOneWidget);
    });

    testWidgets('an unread row has the dot, a read one does not; the title carries the person in bold', (tester) async {
      await pump(tester);
      expect(dotIn('msg'), findsOneWidget);
      expect(dotIn('event'), findsNothing);
      expect(textIn('msg', 'sent you 3 messages'), findsOneWidget);
      expect(textIn('app', 'will be in touch'), findsOneWidget, reason: 'the body sits under the title');
      final rich = tester.widget<Text>(
        find.descendant(of: row('msg'), matching: find.byWidgetPredicate((w) => w is Text && w.textSpan != null)),
      );
      final spans = (rich.textSpan! as TextSpan).children!.cast<TextSpan>();
      expect(spans.where((s) => s.style?.fontWeight == FontWeight.w600).map((s) => s.text), ['Sarah Jenkins']);
    });

    testWidgets('a person on the row shows their initials; the platform shows its category glyph', (tester) async {
      await pump(tester);
      expect(find.descendant(of: row('msg'), matching: find.text('SJ')), findsOneWidget);
      expect(find.descendant(of: row('app'), matching: find.text('SJ')), findsNothing);
    });

    testWidgets('an empty account says so, an empty Unread tab says everything is read', (tester) async {
      await pump(tester, repository: FakeNotificationsRepository());
      expect(find.text('No notifications yet'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('tab-unread')));
      await tester.pumpAndSettle();
      expect(find.text('Nothing unread'), findsOneWidget);
    });

    testWidgets('a failed first load says why and Retry loads it', (tester) async {
      final failing = FakeNotificationsRepository(items: sample())..listError = ApiError('The server is busy.');
      await pump(tester, repository: failing);
      expect(find.text('Your notifications could not be loaded.'), findsOneWidget);
      expect(find.text('The server is busy.'), findsOneWidget);
      expect(find.byType(NotificationRow), findsNothing);

      failing.listError = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationRow), findsNWidgets(5));
    });

    testWidgets('pull to refresh reads the list and the count again', (tester) async {
      await pump(tester);
      final before = repo.calls.where((c) => c.startsWith('list')).length;
      await tester.fling(find.byType(CustomScrollView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(repo.calls.where((c) => c.startsWith('list')).length, before + 1);
      expect(repo.calls.where((c) => c == 'unreadCount').length, greaterThanOrEqualTo(2));
    });

    testWidgets('"Show older notifications" appends the next page and goes away at the end', (tester) async {
      final many = [
        for (var i = 0; i < 30; i++)
          note(
            'n$i',
            title: 'Row $i',
            at: DateTime(2026, 10, 25, 14).subtract(Duration(minutes: i)),
            read: true,
          ),
      ];
      await pump(
        tester,
        repository: FakeNotificationsRepository(items: many),
        size: const Size(390, 4000),
      );
      expect(find.byType(NotificationRow), findsNWidgets(20));
      expect(find.byKey(const ValueKey('show-older')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('show-older')));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationRow), findsNWidgets(30));
      expect(find.byKey(const ValueKey('show-older')), findsNothing);
      expect(repo.calls, contains('list page=2 unread=false'));
    });
  });

  group('filters and the row menu', () {
    testWidgets('after All and Unread there is a chip for each kind of notification that has a row', (tester) async {
      await pump(tester);
      expect(find.byKey(const ValueKey('chip-messages')), findsOneWidget);
      expect(find.byKey(const ValueKey('chip-jobs')), findsOneWidget);
      expect(find.byKey(const ValueKey('chip-events')), findsOneWidget);
      expect(find.byKey(const ValueKey('chip-community')), findsOneWidget);
      expect(find.byKey(const ValueKey('chip-support')), findsOneWidget);
      expect(find.byKey(const ValueKey('chip-mentoring')), findsNothing, reason: 'no row of that kind');
    });

    testWidgets('a kind\'s chip shows only its rows, and All brings the rest back', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('chip-jobs')));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationRow), findsOneWidget);
      expect(row('app'), findsOneWidget);
      expect(repo.calls.where((c) => c.startsWith('list')).length, 1, reason: 'filtered on the device: no new request');

      await tester.tap(find.byKey(const ValueKey('tab-all')));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationRow), findsNWidgets(5));
    });

    testWidgets('the ⋮ opens a sheet: Mark as read reads that row only', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('notification-menu-app')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('note-menu-read')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('note-menu-read')));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('markRead app'));
      expect(dotIn('app'), findsNothing);
      expect(dotIn('msg'), findsOneWidget);
      expect(opened, isEmpty, reason: 'the menu reads, it does not open the record');
    });

    testWidgets('a read row has no "Mark as read"; "Turn off" switches that kind\'s in-app channel off', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('notification-menu-event')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('note-menu-read')), findsNothing);
      expect(find.text('Turn off Events notifications'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('note-menu-off')));
      await tester.pumpAndSettle();
      final saved = repo.calls.where((c) => c.startsWith('savePreference')).toList();
      expect(saved, hasLength(1));
      expect(saved.single, contains('events'));
      expect(saved.single, contains('in=false'));
      expect(find.text('Events notifications are off.'), findsOneWidget);
    });

    testWidgets('an always-sent kind (support) offers no "Turn off"; the settings are one tap away', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('notification-menu-ticket')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('note-menu-off')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('note-menu-settings')));
      await tester.pumpAndSettle();
      expect(find.text('Notification preferences'), findsOneWidget);
    });

    testWidgets('the gear opens the preferences and a second tap goes back to the list', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('tab-preferences')));
      await tester.pumpAndSettle();
      expect(find.text('Notification preferences'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tab-preferences')));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationRow), findsNWidgets(5));
    });
  });

  group('reading', () {
    testWidgets('tapping a row reads it at once: the dot goes, the count and the bell follow, the API is told', (
      tester,
    ) async {
      await pump(tester);
      expect(counts.notifications, 3, reason: 'the screen sets the bell from its own count');
      await tester.tap(row('app'));
      await tester.pumpAndSettle();
      expect(dotIn('app'), findsNothing);
      expect(find.text('Unread (2)'), findsOneWidget);
      expect(counts.notifications, 2);
      expect(repo.calls, contains('markRead app'));
    });

    testWidgets('a refusal puts the dot and the count back and says why', (tester) async {
      final refusing = FakeNotificationsRepository(items: sample())
        ..markReadError = ApiError('Not allowed', statusCode: 403);
      await pump(tester, repository: refusing);
      await tester.tap(row('app'));
      await tester.pumpAndSettle();
      expect(dotIn('app'), findsOneWidget);
      expect(find.text('Unread (3)'), findsOneWidget);
      expect(counts.notifications, 3);
      expect(find.text('Not allowed'), findsOneWidget);
    });

    testWidgets('"Mark all read" reads every row and clears the bell; disabled when nothing is unread', (tester) async {
      await pump(tester);
      final button = find.byKey(const ValueKey('mark-all-read'));
      expect(tester.widget<TextButton>(button).onPressed, isNotNull);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(repo.calls, contains('markAllRead'));
      expect(find.byKey(const ValueKey('unread-dot')), findsNothing);
      expect(find.text('Unread'), findsOneWidget, reason: 'no count once everything is read');
      expect(counts.notifications, 0);
      expect(tester.widget<TextButton>(button).onPressed, isNull);
    });

    testWidgets('a refused "Mark all read" brings every dot back and shows the reason', (tester) async {
      final refusing = FakeNotificationsRepository(items: sample())..markAllError = ApiError('Try again later');
      await pump(tester, repository: refusing);
      await tester.tap(find.byKey(const ValueKey('mark-all-read')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('unread-dot')), findsNWidgets(3));
      expect(find.text('Try again later'), findsOneWidget);
      expect(counts.notifications, 3);
    });

    testWidgets('the Unread tab asks the API for unread rows only; reading all empties it', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('tab-unread')));
      await tester.pumpAndSettle();
      expect(repo.calls.last, 'list page=1 unread=true');
      expect(find.byType(NotificationRow), findsNWidgets(3));
      expect(find.byKey(const ValueKey('notification-event')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('mark-all-read')));
      await tester.pumpAndSettle();
      expect(find.text('Nothing unread'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('tab-all')));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationRow), findsNWidgets(5));
    });

    testWidgets('opening on the Unread tab starts there', (tester) async {
      await pump(tester, tab: NotificationsTab.unread);
      expect(repo.calls, contains('list page=1 unread=true'));
    });
  });

  group('coming back from a record', () {
    testWidgets('Back returns to the list at the same place, with the row read', (tester) async {
      final many = [
        for (var i = 0; i < 18; i++)
          note(
            'n$i',
            title: 'Row $i',
            type: 'application_stage_changed',
            link: '/career/applications/a$i',
            at: DateTime(2026, 10, 25, 14).subtract(Duration(minutes: i)),
          ),
      ];
      await pump(
        tester,
        repository: FakeNotificationsRepository(items: many),
        size: const Size(390, 700),
      );
      // The app's own screen for the record: a route over the list, as every opener pushes.
      router.register(NotificationKinds.applicationCandidate, (context, t) {
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('the record'))));
        return true;
      });

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await tester.pumpAndSettle();
      final target = row('n12');
      expect(target, findsOneWidget);
      final before = tester.getTopLeft(target).dy;
      expect(before, lessThan(700), reason: 'scrolled to where the row is on screen');

      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(find.text('the record'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('the record'), findsNothing);
      expect(tester.getTopLeft(row('n12')).dy, before, reason: 'the list is where it was left');
      expect(dotIn('n12'), findsNothing, reason: 'opening read it');
    });
  });

  group('what a tap opens', () {
    testWidgets('a record the app has a screen for goes to that screen with the ids the page names', (tester) async {
      await pump(tester);
      await tester.tap(row('app'));
      await tester.pumpAndSettle();
      expect(opened, ['application.candidate {applicationId: app-1}']);
      expect(siteOpened, isEmpty);
    });

    testWidgets('a forum reply opens its thread with the reply to scroll to', (tester) async {
      await pump(tester);
      await tester.tap(row('forum'));
      await tester.pumpAndSettle();
      expect(opened, ['forum.thread {slug: thread-1, replyId: r9}']);
    });

    testWidgets('a page no screen of the app takes opens on the website, as the API stored it', (tester) async {
      await pump(tester);
      await tester.tap(row('ticket'));
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
      expect(siteOpened, ['/support/t-1']);
    });

    testWidgets('an opener that declines (returns false) lets the website take it', (tester) async {
      await pump(tester);
      router.register(NotificationKinds.event, (context, t) => false);
      await tester.tap(row('event'));
      await tester.pumpAndSettle();
      expect(siteOpened, ['/events/summit-design']);
    });

    testWidgets('onOpenTarget replaces the router for a tapped row', (tester) async {
      final targets = <NotificationTarget>[];
      await pump(tester, onOpenTarget: (context, t) async => targets.add(t));
      await tester.tap(row('event'));
      await tester.pumpAndSettle();
      expect(targets.single.kind, 'event');
      expect(targets.single['eventId'], 'summit-design');
      expect(opened, isEmpty);
      expect(siteOpened, isEmpty);
    });

    testWidgets('a row with no page is read and opens nothing', (tester) async {
      await pump(
        tester,
        repository: FakeNotificationsRepository(items: [note('plain', title: 'A notice')]),
      );
      await tester.tap(row('plain'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('markRead plain'));
      expect(opened, isEmpty);
      expect(siteOpened, isEmpty);
    });

    testWidgets('a row about another company switches to it first, says so, and tells the app', (tester) async {
      const mine = ChatCompany(id: 'co-1', name: 'BrightCore');
      const other = ChatCompany(id: 'co-2', name: 'Acme');
      final repository = FakeNotificationsRepository(
        items: [
          note(
            'other',
            title: 'Acme got a bid',
            link: '/career/applications/app-9',
            company: other,
            at: DateTime(2026, 10, 25, 12),
          ),
          note(
            'mine',
            title: 'BrightCore got a bid',
            link: '/career/applications/app-8',
            company: mine,
            at: DateTime(2026, 10, 25, 11),
          ),
        ],
      )..viewerAnswer = const NotificationViewer(id: 'me', activeCompanyId: 'co-1', companyCount: 2);
      await pump(tester, repository: repository);
      final switched = <String>[];
      router.onCompanySwitched = (context, id) => switched.add(id);

      // Someone in two companies sees which one each row is for.
      expect(find.descendant(of: row('other'), matching: find.textContaining('For Acme')), findsOneWidget);

      await tester.tap(row('mine'));
      await tester.pumpAndSettle();
      expect(repository.calls.where((c) => c.startsWith('switchCompany')), isEmpty, reason: 'already acting for it');

      await tester.tap(row('other'));
      await tester.pumpAndSettle();
      expect(repository.calls, contains('switchCompany co-2'));
      expect(find.text('Now working as Acme'), findsOneWidget);
      expect(switched, ['co-2']);
      expect(opened.last, 'application.candidate {applicationId: app-9}');
    });

    testWidgets('a company the person has left cannot be opened: the reason is shown and nothing opens', (
      tester,
    ) async {
      final repository =
          FakeNotificationsRepository(
              items: [
                note(
                  'gone',
                  title: 'Gone Ltd got a bid',
                  link: '/career/applications/app-9',
                  company: const ChatCompany(id: 'co-3', name: 'Gone Ltd'),
                ),
              ],
            )
            ..viewerAnswer = const NotificationViewer(id: 'me', activeCompanyId: 'co-1', companyCount: 2)
            ..switchError = ApiError('gone', statusCode: 403);
      await pump(tester, repository: repository);
      await tester.tap(row('gone'));
      await tester.pumpAndSettle();
      expect(find.textContaining("no longer part of Gone Ltd"), findsOneWidget);
      expect(opened, isEmpty);
    });

    testWidgets('a person in one company is not told which company a row is for', (tester) async {
      final repository = FakeNotificationsRepository(
        items: [
          note(
            'x',
            title: 'Acme got a bid',
            company: const ChatCompany(id: 'co-1', name: 'Acme'),
          ),
        ],
      )..viewerAnswer = const NotificationViewer(id: 'me', activeCompanyId: 'co-1', companyCount: 1);
      await pump(tester, repository: repository);
      expect(find.textContaining('For Acme'), findsNothing);
    });
  });

  group('preferences', () {
    Future<void> openPreferences(WidgetTester tester, {FakeNotificationsRepository? repository}) async {
      await pump(tester, repository: repository, size: const Size(390, 3000));
      await tester.tap(find.byKey(const ValueKey('tab-preferences')));
      await tester.pumpAndSettle();
    }

    testWidgets('lists every category with its two switches; the mark-all button is not offered there', (tester) async {
      await openPreferences(tester);
      expect(find.text('Notification preferences'), findsOneWidget);
      expect(find.byKey(const ValueKey('mark-all-read')), findsNothing);
      expect(find.byType(Switch), findsNWidgets(30));
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Always sent'), findsNWidgets(3));
    });

    testWidgets('a switch moves at once and saves its category alone', (tester) async {
      await openPreferences(tester);
      await tester.tap(find.byKey(const ValueKey('pref-messages-Email')));
      await tester.pumpAndSettle();
      expect(repo.calls.last, 'savePreference messages in=true mail=false');
      expect(tester.widget<Switch>(find.byKey(const ValueKey('pref-messages-Email'))).value, isFalse);
      expect(tester.widget<Switch>(find.byKey(const ValueKey('pref-messages-In-app'))).value, isTrue);

      await tester.tap(find.byKey(const ValueKey('pref-jobs-In-app')));
      await tester.pumpAndSettle();
      expect(repo.calls.last, 'savePreference jobs in=false mail=true');
    });

    testWidgets('a refused save puts the switch back and says so; Dismiss clears the notice', (tester) async {
      final refusing = FakeNotificationsRepository(items: sample())..saveError = ApiError('boom', statusCode: 500);
      await openPreferences(tester, repository: refusing);
      await tester.tap(find.byKey(const ValueKey('pref-events-Email')));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byKey(const ValueKey('pref-events-Email'))).value, isTrue, reason: 'put back');
      expect(find.text('Your change could not be saved. Try again.'), findsOneWidget);
      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pumpAndSettle();
      expect(find.text('Your change could not be saved. Try again.'), findsNothing);
    });

    testWidgets('the locked categories are on and cannot be switched', (tester) async {
      await openPreferences(tester);
      final payments = find.byKey(const ValueKey('pref-payments-Email'));
      expect(tester.widget<Switch>(payments).value, isTrue);
      expect(tester.widget<Switch>(payments).onChanged, isNull);
      await tester.tap(payments, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(repo.calls.where((c) => c.startsWith('savePreference payments')), isEmpty);
    });

    testWidgets('preferences that cannot load can be retried', (tester) async {
      final failing = FakeNotificationsRepository(items: sample())..preferencesError = ApiError('x');
      await openPreferences(tester, repository: failing);
      expect(find.text('Your notification preferences could not be loaded.'), findsOneWidget);
      failing.preferencesError = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byType(Switch), findsNWidgets(30));
    });

    testWidgets('the tabs go back to the list', (tester) async {
      await openPreferences(tester);
      await tester.tap(find.byKey(const ValueKey('tab-all')));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationRow), findsNWidgets(5));
    });
  });

  group('the bell on every title bar', () {
    Future<void> pumpBar(WidgetTester tester, UnreadCounts counts) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<UnreadCounts>.value(value: counts),
            Provider<NotificationRouter>.value(value: NotificationRouter()),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TitleBar(title: 'Jobs', unread: bellUnread(context), onBell: () => openNotifications(context)),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('shows its red dot while anything is unread, and follows the count live', (tester) async {
      final counts = UnreadCounts(_NoSource(), interval: const Duration(hours: 1));
      addTearDown(counts.dispose);
      await pumpBar(tester, counts);
      expect(find.bySemanticsLabel('Notifications'), findsOneWidget);
      counts.setNotifications(4);
      await tester.pump();
      expect(find.bySemanticsLabel('Notifications, 4 unread'), findsOneWidget);
      counts.setNotifications(0);
      await tester.pump();
      expect(find.bySemanticsLabel('Notifications'), findsOneWidget);
    });

    testWidgets('a tab with no counts above it still draws a bell with no dot', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TitleBar(title: 'Jobs', unread: bellUnread(context), onBell: () {}),
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Notifications'), findsOneWidget);
    });

    testWidgets('tapping it opens the notifications screen over the page', (tester) async {
      final counts = UnreadCounts(_NoSource(), interval: const Duration(hours: 1));
      addTearDown(counts.dispose);
      final repository = FakeNotificationsRepository(items: sample());
      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider<UnreadCounts>.value(value: counts)],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: NotificationsBell(
                    onTap: () => Navigator.of(
                      context,
                    ).push(MaterialPageRoute<void>(builder: (_) => NotificationsScreen(repository: repository))),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(NotificationsBell));
      await tester.pumpAndSettle();
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.byType(NotificationRow), findsNWidgets(5));
      // Back returns to the page.
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsScreen), findsNothing);
    });
  });

  group('InboxHost: the counts and the router, once, above the signed-in app', () {
    testWidgets('reads the two counts from the API and gives every bell below it the number', (tester) async {
      final adapter = TableAdapter({
        'GET /notifications/unread-count': (_) => {'unread': 3},
        'GET /messaging/unread-count': (_) => {'count': 2, 'personal': 2, 'companies': <String, int>{}},
      });
      final routers = <NotificationRouter>[];
      await tester.runAsync(() async {
        await tester.pumpWidget(
          InboxHost(
            api: clientFor(adapter),
            router: NotificationRouter(),
            child: MaterialApp(
              home: Builder(
                builder: (context) {
                  routers.add(NotificationRouter.of(context));
                  return Scaffold(
                    body: Column(
                      children: [
                        Text('bell ${bellUnread(context)} messages ${messagesUnread(context)}'),
                        TitleBar(title: 'Jobs', unread: bellUnread(context), onBell: () {}),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
        // The first read answers on its own.
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      expect(find.text('bell 3 messages 2'), findsOneWidget);
      expect(find.bySemanticsLabel('Notifications, 3 unread'), findsOneWidget);
      expect(adapter.calls, containsAll(['GET /notifications/unread-count', 'GET /messaging/unread-count']));
      // The router the host was given is the one every screen below finds.
      expect(routers.last, isNotNull);
      // Leaving the app stops the timer (a test would otherwise end with one pending).
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a screen with no host above it gets no counts and the website router, never an error', (tester) async {
      var bell = -1;
      var messages = -1;
      NotificationRouter? router;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              bell = bellUnread(context);
              messages = messagesUnread(context);
              router = NotificationRouter.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect((bell, messages), (0, 0));
      expect(router, isNotNull);
    });
  });

  group('a record page clears what told the person about it', () {
    testWidgets('markNotificationsSeen tells the API the kind and the id and refreshes the bell', (tester) async {
      final repository = FakeNotificationsRepository()..seenAnswer = 2;
      final source = _CountingSource();
      final counts = UnreadCounts(source, interval: const Duration(hours: 1));
      addTearDown(counts.dispose);
      late BuildContext captured;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<UnreadCounts>.value(value: counts),
            Provider<NotificationsRepository>.value(value: repository),
          ],
          child: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.runAsync(() => markNotificationsSeen(captured, NotificationKinds.rfqSupplier, 'R1'));
      expect(repository.calls, ['markSeen rfq.supplier R1']);
      expect(source.reads, greaterThan(0), reason: 'rows were read: the bell reads again');
    });

    testWidgets('nothing read means the bell is left alone; a failure is swallowed', (tester) async {
      final repository = FakeNotificationsRepository();
      final source = _CountingSource();
      final counts = UnreadCounts(source, interval: const Duration(hours: 1));
      addTearDown(counts.dispose);
      late BuildContext captured;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<UnreadCounts>.value(value: counts),
            Provider<NotificationsRepository>.value(value: repository),
          ],
          child: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.runAsync(() => markNotificationsSeen(captured, NotificationKinds.job, 'J1'));
      expect(source.reads, 0);
      repository.seenError = ApiError('down');
      await tester.runAsync(() => markNotificationsSeen(captured, NotificationKinds.job, 'J1'));
    });
  });
}

class _NoSource implements UnreadSource {
  @override
  Future<int> notifications() async => 0;
  @override
  Future<int> messages() async => 0;
}

class _CountingSource implements UnreadSource {
  int reads = 0;
  @override
  Future<int> notifications() async {
    reads++;
    return 0;
  }

  @override
  Future<int> messages() async => 0;
}
