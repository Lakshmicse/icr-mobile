import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/search/recent_searches.dart';
import 'package:icr_mobile/features/search/search_controller.dart';
import 'package:icr_mobile/features/search/search_models.dart';
import 'package:icr_mobile/features/search/search_screen.dart';
import 'package:icr_mobile/features/search/search_widgets.dart' show GroupHeader, KindChip;

import 'search_controller_test.dart' show FakeSource;

class _Harness {
  _Harness(this.controller);

  final GlobalSearchController controller;
  final opened = <SearchHit>[];
  final features = <String>[];
}

SearchHit hitNamed(List<SearchHit> hits, String title) => hits.firstWhere((h) => h.title == title);

void main() {
  late Map<SearchKind, FakeSource> sources;
  late _Harness h;

  FakeSource source(SearchKind kind, Map<String, List<String>> answers, {bool pageable = false, int pageSize = 2}) =>
      sources[kind] = FakeSource(kind, answers: answers, pageable: pageable, pageSize: pageSize);

  /// The screen over fake sources. Debounce is short so one `pump` past it asks.
  Future<void> pumpSearch(
    WidgetTester tester, {
    Set<String>? features,
    List<String> recents = const [],
    double width = 390,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = GlobalSearchController(
      sources: sources.values.toList(),
      availableFeatures: features ?? {'jobs', 'mentorship', 'find_mentors', 'plans', 'events', 'mock'},
      recents: RecentSearches(MemoryRecentStore(recents)),
      debounce: const Duration(milliseconds: 10),
    );
    h = _Harness(controller);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 800), textScaler: TextScaler.linear(textScale)),
          child: SearchScreen(
            controller: controller,
            onOpenHit: (hit) async => h.opened.add(hit),
            onOpenFeature: (id) async => h.features.add(id),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('search.field')), text);
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump();
  }

  /// A chip may be past the right edge of a narrow phone: scroll it in, then tap.
  Future<void> tapChip(WidgetTester tester, String name) async {
    final chip = find.byKey(Key('search.chip.$name'), skipOffstage: false);
    await tester.ensureVisible(chip);
    await tester.pump();
    await tester.tap(chip);
    await tester.pump();
  }

  /// The group headings on the page (not the chips of the same names).
  Finder heading(String text) => find.descendant(of: find.byType(GroupHeader), matching: find.text(text));

  setUp(() {
    sources = {};
    source(SearchKind.person, {'mentor': ['Meera Mentor', 'Mentor Rao']});
    source(SearchKind.job, {'mentor': ['Mentor Lead']});
    source(SearchKind.mentor, {'mentor': ['Rajesh Sharma']});
    source(SearchKind.event, {'mentor': []});
  });

  group('before anything is typed', () {
    testWidgets('shows the field, the recent searches and places to go', (tester) async {
      await pumpSearch(tester, recents: ['hvac', 'plans']);
      expect(find.text('Search ICR'), findsOneWidget);
      expect(find.text('Recent searches'), findsOneWidget);
      expect(find.byKey(const Key('search.recent.hvac')), findsOneWidget);
      expect(find.byKey(const Key('search.recent.plans')), findsOneWidget);
      expect(find.text('Suggested for you'), findsOneWidget);
      expect(find.byKey(const Key('search.suggested.jobs')), findsOneWidget);
      expect(find.byKey(const Key('search.chip.all')), findsNothing, reason: 'no chips until there is a query');
    });

    testWidgets('with no history it still offers somewhere to go', (tester) async {
      await pumpSearch(tester);
      expect(find.text('Recent searches'), findsNothing);
      expect(find.text('Suggested for you'), findsOneWidget);
    });

    testWidgets('a suggestion opens the place it names', (tester) async {
      await pumpSearch(tester);
      await tester.tap(find.byKey(const Key('search.suggested.plans')));
      await tester.pump();
      expect(h.features, ['plans']);
    });

    testWidgets('tapping a recent search runs it', (tester) async {
      await pumpSearch(tester, recents: ['mentor']);
      await tester.tap(find.byKey(const Key('search.recent.mentor')));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pump();
      expect(tester.widget<TextField>(find.byKey(const Key('search.field'))).controller!.text, 'mentor');
      expect(find.text('Meera Mentor'), findsOneWidget);
      expect(sources[SearchKind.person]!.calls, ['mentor']);
    });

    testWidgets('a recent search is removed alone, and Clear all empties the list', (tester) async {
      await pumpSearch(tester, recents: ['one', 'two']);
      await tester.tap(find.descendant(of: find.byKey(const Key('search.recent.one')), matching: find.byIcon(Icons.close)));
      await tester.pump();
      expect(find.byKey(const Key('search.recent.one')), findsNothing);
      expect(find.byKey(const Key('search.recent.two')), findsOneWidget);
      await tester.tap(find.byKey(const Key('search.recent.clear')));
      await tester.pump();
      expect(find.text('Recent searches'), findsNothing);
    });
  });

  group('typing', () {
    testWidgets('groups hits by kind with the chips above, and leads with the feature the query names', (tester) async {
      await pumpSearch(tester);
      await type(tester, 'mentor');

      expect(find.byKey(const Key('search.chip.all')), findsOneWidget);
      expect(find.byKey(const Key('search.chip.person')), findsOneWidget);
      expect(find.byKey(const Key('search.chip.feature'), skipOffstage: false), findsOneWidget);
      // Groups, with the app's own place first because "mentor" names features.
      expect(heading('In the app'), findsOneWidget);
      expect(heading('People'), findsOneWidget);
      expect(heading('Jobs'), findsOneWidget);
      expect(heading('Mentors'), findsOneWidget);
      expect(heading('Events'), findsNothing, reason: 'a source with nothing to show has no group');
      expect(find.text('Find mentors'), findsOneWidget);
      expect(find.text('Meera Mentor'), findsOneWidget);
      expect(tester.getTopLeft(heading('In the app')).dy, lessThan(tester.getTopLeft(heading('People')).dy));
    });

    testWidgets('a hit shows its kind at the end of the row', (tester) async {
      await pumpSearch(tester);
      await type(tester, 'mentor');
      expect(find.text('Person'), findsWidgets);
      expect(find.text('Job'), findsOneWidget);
    });

    testWidgets('tapping a hit opens that record; tapping a feature opens the place', (tester) async {
      await pumpSearch(tester);
      await type(tester, 'mentor');
      await tester.tap(find.text('Mentor Lead'));
      await tester.pump();
      expect(h.opened.single.kind, SearchKind.job);
      expect(h.opened.single.title, 'Mentor Lead');

      await tester.tap(find.text('Find mentors'));
      await tester.pump();
      expect(h.features, ['find_mentors']);
    });

    testWidgets('a hit that was opened is kept as a recent search', (tester) async {
      await pumpSearch(tester);
      await type(tester, 'mentor');
      await tester.tap(find.text('Mentor Lead'));
      await tester.pump();
      await tester.pump();
      expect(h.controller.recents.items, ['mentor']);
    });

    testWidgets('the keyboard search key keeps the query', (tester) async {
      await pumpSearch(tester);
      await type(tester, 'mentor');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(h.controller.recents.items, ['mentor']);
    });

    testWidgets('the clear button empties the field and goes back to the recents', (tester) async {
      await pumpSearch(tester, recents: ['hvac']);
      await type(tester, 'mentor');
      expect(find.byKey(const Key('search.clear')), findsOneWidget);
      await tester.tap(find.byKey(const Key('search.clear')));
      await tester.pump();
      expect(find.text('Recent searches'), findsOneWidget);
      expect(find.byKey(const Key('search.chip.all')), findsNothing);
    });
  });

  group('the chips', () {
    testWidgets('a chip shows only its kind, without group headings or the kind label', (tester) async {
      await pumpSearch(tester);
      await type(tester, 'mentor');
      await tapChip(tester, 'person');
      expect(find.text('Meera Mentor'), findsOneWidget);
      expect(find.text('Mentor Rao'), findsOneWidget);
      expect(find.text('Mentor Lead'), findsNothing);
      expect(find.byType(GroupHeader), findsNothing, reason: 'the chip already says it');
      expect(find.text('Person'), findsNothing);
    });

    testWidgets('"See all" on a group goes to that chip', (tester) async {
      source(SearchKind.person, {'mentor': ['A one', 'B two', 'C three', 'D four', 'E five']}, pageSize: 10);
      await pumpSearch(tester);
      await type(tester, 'mentor');
      expect(find.text('See all people'), findsOneWidget);
      expect(find.text('E five'), findsNothing, reason: 'the All chip shows four');
      await tester.tap(find.text('See all people'));
      await tester.pump();
      expect(find.text('E five'), findsOneWidget);
      expect(h.controller.scope, SearchKind.person);
    });

    testWidgets('a paging chip loads more on "Show more results"', (tester) async {
      source(SearchKind.job, {'mentor': ['j1', 'j2', 'j3', 'j4', 'j5']}, pageable: true);
      await pumpSearch(tester);
      await type(tester, 'mentor');
      await tapChip(tester, 'job');
      expect(find.text('j2'), findsOneWidget);
      expect(find.text('j3'), findsNothing);
      await tester.tap(find.text('Show more results'));
      await tester.pump();
      await tester.pump();
      expect(find.text('j3'), findsOneWidget);
      expect(find.text('j4'), findsOneWidget);
    });

    testWidgets('the App chip lists the places the query is about, and a kind with nothing says so', (tester) async {
      await pumpSearch(tester);
      await type(tester, 'mentor');
      await tapChip(tester, 'feature');
      expect(find.text('Mentorship'), findsOneWidget);
      expect(find.text('Find mentors'), findsOneWidget);

      await tapChip(tester, 'event');
      await tester.pump();
      expect(find.textContaining('No events for'), findsOneWidget);
      await tester.tap(find.text('Search everything'));
      await tester.pump();
      expect(h.controller.scope, isNull);
    });
  });

  group('states', () {
    testWidgets('nothing found says so and offers places to go', (tester) async {
      await pumpSearch(tester);
      await type(tester, 'zzzzzz');
      expect(find.text('No results for “zzzzzz”'), findsOneWidget);
      // The chip row has a "Jobs" (the source); the body's is the place to go.
      expect(find.widgetWithText(KindChip, 'Jobs'), findsNWidgets(2), reason: 'suggested places as chips');
      await tester.tap(find.widgetWithText(KindChip, 'Jobs').last);
      await tester.pump();
      expect(h.features, ['jobs']);
    });

    testWidgets('every source down is "Can\'t reach ICR" with a retry', (tester) async {
      for (final s in sources.values) {
        s.failure = Exception('offline');
      }
      await pumpSearch(tester, features: <String>{});
      await type(tester, 'mentor');
      expect(find.text("Can't reach ICR"), findsOneWidget);

      for (final s in sources.values) {
        s.failure = null;
      }
      await tester.tap(find.byKey(const Key('search.retry')));
      await tester.pump();
      await tester.pump();
      expect(find.text("Can't reach ICR"), findsNothing);
      expect(find.text('Meera Mentor'), findsOneWidget);
    });

    testWidgets('a source still loading shows the progress bar, and its rows arrive in place', (tester) async {
      final gate = Completer<void>();
      sources[SearchKind.job]!.hold = gate;
      await pumpSearch(tester);
      await type(tester, 'mentor');
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Meera Mentor'), findsOneWidget, reason: 'the fast sources do not wait for the slow one');
      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Mentor Lead'), findsOneWidget);
    });

    testWidgets('the back arrow leaves the page', (tester) async {
      await pumpSearch(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => SearchScreen(
                    controller: h.controller,
                    onOpenHit: (_) async {},
                    onOpenFeature: (_) async {},
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('search.field')), findsOneWidget);
      await tester.tap(find.byKey(const Key('search.back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('search.field')), findsNothing);
    });
  });

  group('wide and large text', () {
    for (final (width, scale) in [(360.0, 1.0), (390.0, 1.3), (360.0, 1.3)]) {
      testWidgets('${width.toInt()} dp at text ${scale}x does not overflow', (tester) async {
        source(SearchKind.person, {
          'mentor': ['A very long member name that keeps going and going past the end of the line, Esq.'],
        });
        source(SearchKind.job, {'mentor': ['Senior Vice President, Integrated Facility Management Operations and Real Estate']});
        await pumpSearch(tester, width: width, textScale: scale, recents: ['a recent search that is quite long indeed']);
        expect(tester.takeException(), isNull);
        await type(tester, 'mentor');
        expect(tester.takeException(), isNull);
        await tapChip(tester, 'job');
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('opened from the app', () {
    testWidgets('openGlobalSearch builds the sources from the caller and opens hits with the caller\'s context', (tester) async {
      BuildContext? sourceContext;
      BuildContext? openerContext;
      SearchHit? openedHit;
      final people = FakeSource(SearchKind.person, answers: {'meera': ['Meera Iyer']});
      SearchEnvironment.current = SearchEnvironment(
        sources: (ctx) {
          sourceContext = ctx;
          return [people];
        },
        openers: {
          SearchKind.person: (ctx, hit) async {
            openerContext = ctx;
            openedHit = hit;
          },
        },
        features: {'jobs': (ctx) async {}},
      );
      addTearDown(() => SearchEnvironment.current = null);

      late BuildContext caller;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              caller = context;
              return const Scaffold(body: Text('home'));
            },
          ),
        ),
      );
      unawaited(openGlobalSearch(caller, query: 'meera'));
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      expect(sourceContext, same(caller));
      expect(find.text('Meera Iyer'), findsOneWidget, reason: 'the query passed in is run');

      await tester.tap(find.text('Meera Iyer'));
      await tester.pump();
      expect(openedHit?.title, 'Meera Iyer');
      expect(openerContext, same(caller), reason: 'the record opens over the screen that opened the search');
    });

    testWidgets('with no environment set it does nothing instead of failing', (tester) async {
      SearchEnvironment.current = null;
      late BuildContext caller;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              caller = c;
              return const SizedBox();
            },
          ),
        ),
      );
      await openGlobalSearch(caller);
      expect(tester.takeException(), isNull);
    });
  });
}
