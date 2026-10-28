/// The harness of the Marketplace widget tests: the tab over a spy repository,
/// with the hand-overs and the links recorded.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/marketplace/marketplace_controller.dart';
import 'package:icr_mobile/features/marketplace/marketplace_filters.dart';
import 'package:icr_mobile/features/marketplace/marketplace_models.dart';
import 'package:icr_mobile/features/marketplace/marketplace_navigation.dart';
import 'package:icr_mobile/features/marketplace/marketplace_screen.dart';
import 'package:provider/provider.dart';

import 'marketplace_fakes.dart';

class MartUnderTest {
  MartUnderTest(this.repo, this.links, this.market, this.events);

  final SpyMarketplaceRepository repo;
  final RecordingLinks links;
  final MarketplaceController market;

  /// What the hand-overs were called with, in order ("back", "postRfq", "message:s1"...).
  final List<String> events;
}

Future<MartUnderTest> pumpMart(
  WidgetTester tester, {
  SpyMarketplaceRepository? repo,
  Size size = const Size(390, 1000),
  bool wireNavigation = false,
  Future<MarketplaceCounts> Function()? counts,
  MarketplaceNavigation navigation = MarketplaceNavigation.none,
  int? columns,
  bool start = true,
  MarketplaceFilters initial = const MarketplaceFilters(),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final spy = repo ?? SpyMarketplaceRepository();
  final links = RecordingLinks();
  final market = MarketplaceController(spy, initial: initial);
  addTearDown(market.dispose);
  final events = <String>[];
  if (start) await tester.runAsync(market.start);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: ChangeNotifierProvider.value(
        value: market,
        child: MarketplaceScreen(
          onBack: () => events.add('back'),
          onPostRfq: wireNavigation ? () => events.add('postRfq') : null,
          onMyRfqs: wireNavigation ? () => events.add('myRfqs') : null,
          onRfqAlerts: wireNavigation ? () => events.add('alerts') : null,
          onBell: wireNavigation ? () => events.add('bell') : null,
          onMessageSupplier: wireNavigation ? (id) => events.add('message:$id') : null,
          counts: counts,
          navigation: navigation,
          links: links,
          forceColumns: columns,
        ),
      ),
    ),
  );
  await tester.pump();
  return MartUnderTest(spy, links, market, events);
}

/// Brings something already built (a chip in a sideways row) into view.
Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> tapChip(WidgetTester tester, String label) async {
  final chip = find.text(label);
  await reveal(tester, chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}
