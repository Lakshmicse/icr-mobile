import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/search/recent_searches.dart';
import 'package:icr_mobile/features/search/search_controller.dart';
import 'package:icr_mobile/features/search/search_models.dart';
import 'package:icr_mobile/features/search/search_screen.dart';

import '../helpers/fonts.dart';

/// A source that answers with fixed hits, for the pictures.
class _Fixed extends SearchSource {
  _Fixed(this.kind, this.hits, {this.more = false});

  @override
  final SearchKind kind;
  final List<SearchHit> hits;
  final bool more;

  @override
  Future<SourcePage> search(String query, {int page = 1}) async => SourcePage(hits, hasMore: more);
}

SearchHit hit(SearchKind kind, String id, String title, String subtitle, {bool verified = false}) =>
    SearchHit(kind: kind, id: id, title: title, subtitle: subtitle, verified: verified);

/// The search page at the phone's width, three states, also written to
/// build/screens/ at 2x to look at. Refresh with `flutter test --update-goldens`.
void main() {
  setUpAll(loadAppFonts);

  Future<void> export(WidgetTester tester, GlobalKey key, String name) async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/screens').createSync(recursive: true);
      File('build/screens/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  Future<GlobalKey> pump(WidgetTester tester, GlobalSearchController controller) async {
    tester.view.physicalSize = const Size(780, 1560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    addTearDown(controller.dispose);
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: RepaintBoundary(
          key: key,
          child: SearchScreen(
            controller: controller,
            onOpenHit: (_) async {},
            onOpenFeature: (_) async {},
          ),
        ),
      ),
    );
    await tester.pump();
    return key;
  }

  final sources = [
    _Fixed(SearchKind.person, [
      hit(SearchKind.person, 'p1', 'Meera Iyer', 'Head of Mentoring at Northwind Facilities'),
      hit(SearchKind.person, 'p2', 'Rohit Rao', 'Recruiter at Northwind Facilities'),
      hit(SearchKind.person, 'p3', 'Anand Menon', 'Mentor · Senior Vice President, Integrated Facility Management'),
      hit(SearchKind.person, 'p4', 'Sarah Jenkins', 'Senior Facilities Manager at Google'),
      hit(SearchKind.person, 'p5', 'Arvind Swamy', 'Brookfield Properties'),
    ]),
    _Fixed(SearchKind.job, [
      hit(SearchKind.job, 'j1', 'Mentor – Facilities Operations', 'CBRE South Asia · Bengaluru', verified: true),
      hit(SearchKind.job, 'j2', 'Senior Facilities Manager for STP Plant', 'JLL · Mumbai', verified: true),
      hit(SearchKind.job, 'j3', 'Head of Workplace Experience', 'Infosys · Pune'),
    ], more: true),
    _Fixed(SearchKind.mentor, [
      hit(SearchKind.mentor, 'm1', 'Rajesh Sharma', 'VP Facility Ops at Infosys', verified: true),
      hit(SearchKind.mentor, 'm2', 'Lisa Cheng', 'Director of Sustainability at Google', verified: true),
    ]),
    _Fixed(SearchKind.event, [
      hit(SearchKind.event, 'e1', 'Mentoring circle: moving into FM leadership', 'Roundtable · Nov 14 · Bengaluru'),
    ]),
    _Fixed(SearchKind.discussion, [
      hit(SearchKind.discussion, 'd1', 'How do you pick a mentor when changing careers?', 'Elena Rostova · 52 comments'),
    ]),
  ];

  GlobalSearchController make({List<String> recents = const []}) => GlobalSearchController(
    sources: sources,
    availableFeatures: {
      'jobs', 'learning', 'mentorship', 'marketplace', 'find_mentors', 'become_mentor', 'my_mentoring', 'mock',
      'events', 'plans', 'programmes', 'group_sessions',
    },
    recents: RecentSearches(MemoryRecentStore(recents)),
    debounce: const Duration(milliseconds: 5),
  );

  testWidgets('before typing: recent searches and places to go', (tester) async {
    final controller = make(recents: ['hvac maintenance', 'plans', 'mock exams', 'Meera Iyer']);
    final key = await pump(tester, controller);
    await tester.pump(const Duration(milliseconds: 20));
    await export(tester, key, 'search_idle');
    await expectLater(find.byKey(key), matchesGoldenFile('goldens/search_idle.png'));
  });

  testWidgets('typing "mentor": the app\'s places, then people, jobs, mentors, events and discussions', (tester) async {
    final controller = make();
    final key = await pump(tester, controller);
    await tester.enterText(find.byKey(const Key('search.field')), 'mentor');
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump();
    await export(tester, key, 'search_typing');
    await expectLater(find.byKey(key), matchesGoldenFile('goldens/search_typing.png'));
  });

  testWidgets('the People chip: every person the search found', (tester) async {
    final controller = make();
    final key = await pump(tester, controller);
    await tester.enterText(find.byKey(const Key('search.field')), 'meera');
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump();
    await tester.tap(find.byKey(const Key('search.chip.person')));
    await tester.pump();
    await export(tester, key, 'search_people');
    await expectLater(find.byKey(key), matchesGoldenFile('goldens/search_people.png'));
  });
}
