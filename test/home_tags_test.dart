import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/feed/feed_controller.dart';
import 'package:icr_mobile/features/feed/feed_models.dart';
import 'package:icr_mobile/features/feed/home_screen.dart';
import 'package:icr_mobile/features/forum/forum_callbacks.dart';
import 'package:icr_mobile/features/forum/forums_controller.dart';
import 'package:icr_mobile/features/forum/forums_screen.dart';
import 'package:icr_mobile/features/forum/mentions/mention_person.dart';
import 'package:icr_mobile/features/forum/mentions/tag_person.dart';
import 'package:icr_mobile/features/forum/mentions/tag_suggestions.dart';
import 'package:icr_mobile/features/shell/app_shell.dart';
import 'package:provider/provider.dart';

import 'helpers/feed_fixtures.dart';
import 'helpers/fonts.dart';
import 'helpers/offline_feed.dart';

/// A tag on a Home card (owner, 3 Nov 2026): a person's tag ("#@prashant", how members tagged people before the "@"
/// list) opens that person's profile, or does nothing when no profile fits; any other tag does nothing. Neither
/// opens the Forums tab. On the Forums tab a person's tag does the same, and only a plain tag filters the tab.
void main() {
  setUpAll(loadAppFonts);

  MentionPerson person(String id, String first, String last) =>
      MentionPerson(id: id, firstName: first, lastName: last);

  group('a person tag', () {
    test('is a tag that starts with "@", with or without its "#"', () {
      expect(personTagName('#@prashant'), 'prashant');
      expect(personTagName('@prashant'), 'prashant');
      expect(personTagName('#@prashant_kumar'), 'prashant kumar');
      expect(personTagName('@divya.r'), 'divya r');
      expect(personTagName('#HVAC'), isNull);
      expect(personTagName('HVAC'), isNull);
      expect(personTagName('#@'), isNull);
      expect(personTagName('#@a'), isNull, reason: 'one letter would be anyone');
    });

    test('means the one person with that name, else the only person found', () {
      final prashant = person('p1', 'Prashant', 'Kumar');
      final pravin = person('p2', 'Pravin', 'Shetty');
      expect(personNamed('prashant', [prashant, pravin])?.id, 'p1', reason: 'the first name');
      expect(personNamed('kumar', [prashant])?.id, 'p1', reason: 'the last name');
      expect(personNamed('prashant kumar', [prashant])?.id, 'p1', reason: 'the whole name');
      expect(personNamed('prash', [prashant])?.id, 'p1', reason: 'the only person found');
      expect(personNamed('prashant', const []), isNull, reason: 'nobody');
      expect(
        personNamed('prashant', [prashant, person('p3', 'Prashant', 'Rao')]),
        isNull,
        reason: 'two people of that name: neither is guessed',
      );
      expect(personNamed('pra', [prashant, pravin]), isNull, reason: 'several found, none by that name');
    });

    test("the handle is the tag's text after the \"@\", as the forum stores it", () {
      expect(personTagHandle('#@vinay-kumar'), 'vinay-kumar');
      expect(personTagHandle('@Vinay-Kumar'), 'vinay-kumar');
      expect(personTagHandle('#hvac'), isNull);
      expect(personTagHandle('#@'), isNull);
      expect(personTagName('#@vinay-kumar'), 'vinay kumar');
    });

    test('a handle names the person first; then the name; then a company of that name', () async {
      final asked = <String>[];
      final opened = <String>[];
      final companies = <String>[];
      Future<bool> open(String tag, {String? handleId, List<MentionPerson> people = const [], List<TagCompany> cos = const []}) =>
          openTaggedPerson(
            tag,
            search: (q) async {
              asked.add('people:$q');
              return people;
            },
            onOpenMember: opened.add,
            byHandle: (h) async {
              asked.add('handle:$h');
              return handleId;
            },
            searchCompanies: (q) async {
              asked.add('companies:$q');
              return cos;
            },
            onOpenCompany: companies.add,
          );

      expect(await open('#@vinay-kumar', handleId: 'u-vinay'), isTrue);
      expect(asked, ['handle:vinay-kumar'], reason: 'an exact handle needs no search');
      expect(opened, ['u-vinay']);

      asked.clear();
      expect(await open('#@acme-fm', cos: const [TagCompany(id: 'co-acme', name: 'Acme FM')]), isTrue);
      expect(asked, ['handle:acme-fm', 'people:acme fm', 'companies:acme fm']);
      expect(companies, ['co-acme']);

      asked.clear();
      expect(
        await open('#@acme', cos: const [TagCompany(id: 'co-a', name: 'Acme FM'), TagCompany(id: 'co-b', name: 'Acme Ltd')]),
        isFalse,
        reason: 'no company is named exactly that',
      );
    });

    test('a failed look-up opens nothing', () async {
      final opened = <String>[];
      final done = await openTaggedPerson(
        '#@prashant',
        search: (_) async => throw StateError('offline'),
        onOpenMember: opened.add,
      );
      expect(done, isFalse);
      expect(opened, isEmpty);
    });
  });

  group('on Home', () {
    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pumpAndSettle();
    }

    late FakeForum api;
    late FeedController feed;
    late ForumsController forums;
    late List<String> opened;

    Future<void> pumpApp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(780, 7600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final world = FeedWorld();
      world.threads.first['tags'] = ['HVAC', '@prashant', '@divya', '@pravin', '@vinay-kumar'];
      api = FakeForum({
        ...world.routes(),
        // A profile handle the API knows (a person picked from the Tags "@" list is tagged by it).
        'GET /members/vinay-kumar': (_) => member('u-vinay', 'Vinay Kumar'),
        'GET /members/mentionable': (o) {
          final q = (o.queryParameters['search'] as String).toLowerCase();
          return [
            for (final m in [
              member('u-prashant', 'Prashant Kumar', headline: 'Facility Manager'),
              member('u-divya-1', 'Divya Rao'),
              member('u-divya-2', 'Divya Nair'),
            ])
              if ('${m['firstName']} ${m['lastName']}'.toLowerCase().split(' ').any((w) => w.startsWith(q))) m,
          ];
        },
      });
      feed = FeedController(OfflineFeed(repositoryOn(api)));
      forums = ForumsController(feed.repository.forum);
      opened = [];
      addTearDown(feed.dispose);
      addTearDown(forums.dispose);
      await tester.runAsync(() async {
        await feed.start();
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      const viewer = FeedAuthor(id: 'me', name: 'Bharat Buyer');
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FeedController>.value(value: feed),
            InheritedProvider<ForumsController>.value(value: forums),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            home: AppShell(
              // As `lib/app.dart` wires Home: a member's profile, and no `onOpenTag`.
              home: HomeScreen(
                viewer: viewer,
                onAccount: () {},
                callbacks: ForumCallbacks(onOpenMember: opened.add),
              ),
              forums: Builder(
                builder: (ctx) => ForumsScreen(
                  viewer: viewer,
                  onBack: () => AppShell.selectHome(ctx),
                  controller: ctx.read<ForumsController>(),
                ),
              ),
            ),
          ),
        ),
      );
      await settle(tester);
    }

    Future<void> tapTag(WidgetTester tester, String tag) async {
      await tester.tap(
        find.descendant(of: find.byKey(const ValueKey('iot')), matching: find.byKey(ValueKey('tag:#$tag'))),
      );
      await settle(tester);
    }

    void expectNoForums() {
      expect(find.byType(ForumsScreen), findsNothing, reason: 'a Home tag never opens the Forums tab');
      expect(forums.query.tag, isNull);
      expect(api.to('GET', '/forum/threads').where((o) => o.queryParameters['tag'] != null), isEmpty);
    }

    testWidgets("a person's tag opens that person's profile", (tester) async {
      await pumpApp(tester);
      await tapTag(tester, '@prashant');
      expect(api.to('GET', '/members/prashant'), hasLength(1), reason: 'the handle is tried first');
      expect(api.to('GET', '/members/mentionable').single.queryParameters['search'], 'prashant');
      expect(opened, ['u-prashant']);
      expectNoForums();
    });

    testWidgets("a person picked from the Tags' list is found by their handle, with no search", (tester) async {
      await pumpApp(tester);
      await tapTag(tester, '@vinay-kumar');
      expect(opened, ['u-vinay']);
      expect(api.to('GET', '/members/mentionable'), isEmpty);
      expectNoForums();
    });

    testWidgets('a name no profile fits, or several do, does nothing', (tester) async {
      await pumpApp(tester);
      await tapTag(tester, '@pravin');
      await tapTag(tester, '@divya');
      expect(api.to('GET', '/members/mentionable'), hasLength(2), reason: 'each name is looked up');
      expect(opened, isEmpty);
      expectNoForums();
    });

    testWidgets('a plain tag does nothing', (tester) async {
      await pumpApp(tester);
      await tapTag(tester, 'HVAC');
      expect(api.to('GET', '/members/mentionable'), isEmpty);
      expect(opened, isEmpty);
      expectNoForums();
    });
  });
}
