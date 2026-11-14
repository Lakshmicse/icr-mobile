import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/app_community_manage.dart';
import 'package:icr_mobile/core/auth/session_user.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/core/widgets/manage_pencil.dart';
import 'package:icr_mobile/core/widgets/title_bar.dart';
import 'package:icr_mobile/features/chapters/chapter_controller.dart';
import 'package:icr_mobile/features/chapters/chapter_screen.dart';
import 'package:icr_mobile/features/chapters/chapters_controller.dart';
import 'package:icr_mobile/features/chapters/chapters_screen.dart';
import 'package:icr_mobile/features/councils/councils_controller.dart';
import 'package:icr_mobile/features/councils/councils_screen.dart';
import 'package:icr_mobile/features/councils/demo_councils_repository.dart';
import 'package:icr_mobile/features/events/event_manage_scope.dart';
import 'package:icr_mobile/features/events/events_controller.dart';
import 'package:icr_mobile/features/events/events_screen.dart';
import 'package:icr_mobile/features/events/widgets/event_card.dart';
import 'package:icr_mobile/features/feed/demo_feed_repository.dart';
import 'package:icr_mobile/features/shell/icr_bottom_nav.dart';
import 'package:icr_mobile/features/shell/shell_page.dart';
import 'package:provider/provider.dart';

import 'helpers/community_fakes.dart';
import 'helpers/events_fixtures.dart';
import 'helpers/fonts.dart';

/// The pencil beside the bell on the Chapters, Councils and Events pages: who is given it (the website's
/// `chapters:manage` / `councils:manage` / `events:manage`), where it is drawn, and what a tap hands on.
SessionUser _user({String role = 'PROFESSIONAL', List<String> keys = const [], List<String> scoped = const []}) =>
    SessionUser.fromJson({
      'id': 'u1',
      'email': 'a@icr.test',
      'firstName': 'A',
      'lastName': 'B',
      'role': role,
      'permissions': keys,
      'scopedPermissions': scoped,
    });

void _phone(WidgetTester tester, {double height = 1800}) {
  tester.view.physicalSize = Size(780, height);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

final _pencil = find.byKey(const ValueKey('bar-edit'));

void main() {
  setUpAll(loadAppFonts);

  group('who may manage', () {
    test('a member with no staff role holds no key', () {
      final member = _user();
      expect(holdsPermission(member, 'chapters:manage'), isFalse);
      expect(holdsPermission(null, 'chapters:manage'), isFalse);
      // An older API sends neither list.
      final old = SessionUser.fromJson({'id': 'u', 'role': 'PROFESSIONAL'});
      expect(old.permissions, isEmpty);
      expect(old.scopedPermissions, isEmpty);
    });

    test('a Super Admin holds every key, everywhere, with none listed', () {
      final admin = _user(role: 'SUPER_ADMIN');
      for (final key in const ['chapters:manage', 'councils:manage', 'events:manage']) {
        expect(holdsPermission(admin, key), isTrue);
        expect(holdsPermissionEverywhere(admin, key), isTrue);
      }
    });

    test('a Chapters Admin holds the chapters key alone', () {
      final staff = _user(keys: const ['chapters:manage']);
      expect(holdsPermission(staff, 'chapters:manage'), isTrue);
      expect(holdsPermissionEverywhere(staff, 'chapters:manage'), isTrue);
      expect(holdsPermission(staff, 'councils:manage'), isFalse);
      expect(holdsPermission(staff, 'events:manage'), isFalse);
    });

    test('a role given over some chapters holds the key, but not everywhere', () {
      final staff = _user(keys: const ['chapters:manage', 'events:manage'], scoped: const ['chapters:manage']);
      expect(holdsPermission(staff, 'chapters:manage'), isTrue);
      expect(holdsPermissionEverywhere(staff, 'chapters:manage'), isFalse);
      expect(holdsPermissionEverywhere(staff, 'events:manage'), isTrue);
    });
  });

  group('a record page\'s pencil', () {
    Future<List<String>> pump(WidgetTester tester, Future<bool> Function(String) may, {String id = 'c1'}) async {
      final opened = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TitleBar(
              title: 'Chapter',
              onBell: () {},
              actions: [
                ManagePencil(
                  manage: RecordManage(may: may, open: (_, id) => opened.add(id)),
                  id: id,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return opened;
    }

    testWidgets('is drawn for a record the reader may manage, and opens that record', (tester) async {
      final opened = await pump(tester, (id) async => id == 'c1');
      expect(_pencil, findsOneWidget);
      await tester.tap(_pencil);
      expect(opened, ['c1']);
    });

    testWidgets('is not drawn for a record outside their role, nor when the question fails', (tester) async {
      await pump(tester, (id) async => false);
      expect(_pencil, findsNothing);
      await pump(tester, (id) async => throw StateError('offline'));
      expect(_pencil, findsNothing);
    });
  });

  group('the website\'s console address (a staff notification\'s link)', () {
    final chapters = _user(keys: const ['chapters:manage']);
    final councils = _user(keys: const ['councils:manage']);
    final events = _user(keys: const ['events:manage']);
    final all = _user(role: 'SUPER_ADMIN');

    test('opens the section its tab names, for the staff who run it', () {
      expect(consolePageFor(all, {'tab': 'councils'}), (section: ManageSection.councils, tab: null));
      expect(consolePageFor(all, {'tab': 'events'}), (section: ManageSection.events, tab: null));
      expect(consolePageFor(events, {'tab': 'event-hosts', 'application': 'a1'}), (
        section: ManageSection.events,
        tab: 'event-hosts',
      ));
    });

    test('a chapter application is the chapter staff\'s, a council proposal the council staff\'s', () {
      expect(consolePageFor(all, {'tab': 'applications', 'application': 'a1'}), (
        section: ManageSection.chapters,
        tab: 'applications',
      ));
      expect(consolePageFor(all, {'tab': 'applications', 'proposal': 'p1'}), (
        section: ManageSection.councils,
        tab: 'applications',
      ));
      expect(consolePageFor(councils, {'tab': 'applications'}), (section: ManageSection.councils, tab: 'applications'));
    });

    test('a tab they do not run, or none, opens the first section they do', () {
      expect(consolePageFor(chapters, {'tab': 'events'}), (section: ManageSection.chapters, tab: null));
      expect(consolePageFor(events, const {}), (section: ManageSection.events, tab: null));
    });

    test('is nobody else\'s', () {
      expect(consolePageFor(_user(), {'tab': 'chapters'}), isNull);
      expect(consolePageFor(null, const {}), isNull);
    });
  });

  group('the Chapters pages', () {
    Future<void> board(WidgetTester tester, {VoidCallback? onManage}) async {
      _phone(tester, height: 3600);
      final controller = ChaptersController(FakeChapters());
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ChangeNotifierProvider.value(
            value: controller,
            child: ChaptersScreen(onBack: () {}, onOpenEvent: (_) {}, onBell: () {}, onManage: onManage),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the board has no pencil for a member', (tester) async {
      await board(tester);
      expect(_pencil, findsNothing);
    });

    testWidgets('the board\'s pencil opens Manage Chapters for the staff who run them', (tester) async {
      var opened = 0;
      await board(tester, onManage: () => opened++);
      expect(_pencil, findsOneWidget);
      await tester.tap(_pencil);
      expect(opened, 1);
    });

    testWidgets('a chapter\'s page asks about that chapter and opens its manage page', (tester) async {
      _phone(tester, height: 5200);
      final asked = <String>[];
      final opened = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ChangeNotifierProvider(
            create: (_) => ChapterController(repository: FakeChapters(), idOrSlug: 'bengaluru', clock: () => testNow),
            child: ChapterScreen(
              onBack: () {},
              onOpenEvent: (_) {},
              onBell: () {},
              manage: RecordManage(
                may: (id) async {
                  asked.add(id);
                  return true;
                },
                open: (_, id) => opened.add(id),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(asked, ['id-bengaluru']);
      await tester.tap(_pencil);
      expect(opened, ['id-bengaluru']);
    });
  });

  group('the Councils board', () {
    Future<void> board(WidgetTester tester, {VoidCallback? onManage}) async {
      _phone(tester, height: 3600);
      final controller = CouncilsController(DemoCouncilsRepository());
      addTearDown(controller.dispose);
      await tester.runAsync(controller.start);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ChangeNotifierProvider.value(
            value: controller,
            child: CouncilsScreen(onBack: () {}, opener: (_, _) async {}, onManage: onManage),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('has no pencil for a member, and one for the staff who run councils', (tester) async {
      await board(tester);
      expect(_pencil, findsNothing);
      var opened = 0;
      await board(tester, onManage: () => opened++);
      await tester.tap(_pencil);
      expect(opened, 1);
    });
  });

  group('the Events pages', () {
    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pumpAndSettle();
    }

    Future<void> board(
      WidgetTester tester, {
      VoidCallback? onManage,
      ValueChanged<String>? onManageEvent,
      bool framed = false,
    }) async {
      _phone(tester, height: 7000);
      final events = EventsController(repoOn(FakeApi(EventsWorld().routes())));
      await tester.runAsync(() async {
        await events.start();
        await events.speakersSettled;
      });
      addTearDown(events.dispose);
      final screen = EventManageScope(
        onManage: onManageEvent,
        child: EventsScreen(onBack: () {}, viewer: DemoFeedRepository.me, onAccount: () {}, onManage: onManage),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ChangeNotifierProvider.value(
            value: events,
            child: framed ? ShellPage(tab: AppTab.home, child: screen) : screen,
          ),
        ),
      );
      await settle(tester);
    }

    testWidgets('the board has no pencil for a member, and one for the staff who run events', (tester) async {
      await board(tester);
      expect(_pencil, findsNothing);
      var opened = 0;
      await board(tester, onManage: () => opened++);
      await tester.tap(_pencil);
      expect(opened, 1);
    });

    testWidgets('an event\'s sheet has no pencil for a member', (tester) async {
      await board(tester);
      await tester.tap(find.byType(EventCard).first);
      await settle(tester);
      expect(find.byKey(const ValueKey('event-manage')), findsNothing);
    });

    testWidgets('an event\'s sheet: the pencil closes it and hands the event on to its manage page', (tester) async {
      final managed = <String>[];
      await board(tester, onManageEvent: managed.add);
      final card = tester.widget<EventCard>(find.byType(EventCard).first);
      await tester.tap(find.byType(EventCard).first);
      await settle(tester);
      final pencil = find.byKey(const ValueKey('event-manage'));
      expect(pencil, findsOneWidget);
      await tester.tap(pencil);
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 10));
      expect(managed, [card.event.id]);
      expect(pencil, findsNothing); // the sheet has gone
    });

    testWidgets('the board stands over the bottom bar, as Home does', (tester) async {
      await board(tester, framed: true);
      expect(find.byType(IcrBottomNav), findsOneWidget);
    });
  });
}
