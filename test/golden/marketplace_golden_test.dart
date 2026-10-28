@Tags(['golden'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/marketplace/demo_marketplace_repository.dart';
import 'package:icr_mobile/features/marketplace/marketplace_controller.dart';
import 'package:icr_mobile/features/marketplace/marketplace_filters.dart';
import 'package:icr_mobile/features/marketplace/marketplace_screen.dart';
import 'package:icr_mobile/features/marketplace/supplier_controller.dart';
import 'package:icr_mobile/features/marketplace/supplier_sheet.dart';
import 'package:provider/provider.dart';

import '../helpers/fonts.dart';

/// The Marketplace screens at the designs' frames, exported at 2x to build/screens/.
/// `--dart-define=GOLDEN_SCALE=4` also exports a 4x picture (the designs' own scale) to measure with.
const _measureScale = int.fromEnvironment('GOLDEN_SCALE', defaultValue: 2);

void main() {
  setUpAll(() async {
    await loadAppFonts();
    // The licence number is set in `Courier` on a phone; a test has no such font, so it borrows Roboto.
    final courier = FontLoader('Courier')..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    await courier.load();
  });

  Future<void> precacheAll(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pumpAndSettle();
  }

  Future<void> export(WidgetTester tester, Finder finder, String name) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.ancestor(of: finder, matching: find.byType(RepaintBoundary)).first,
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/screens').createSync(recursive: true);
      File('build/screens/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      if (_measureScale != 2) {
        final big = await boundary.toImage(pixelRatio: _measureScale.toDouble());
        final data = await big.toByteData(format: ui.ImageByteFormat.png);
        File('build/screens/${name}_${_measureScale}x.png').writeAsBytesSync(data!.buffer.asUint8List());
      }
    });
  }

  Future<void> board(
    WidgetTester tester, {
    required Size size,
    required DemoMarketplaceRepository repo,
    int? columns,
    required String name,
    MarketplaceFilters? initial,
  }) async {
    tester.view.physicalSize = Size(size.width * 2, size.height * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final market = MarketplaceController(repo, initial: initial ?? const MarketplaceFilters());
    await tester.runAsync(market.start);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: ChangeNotifierProvider.value(
          value: market,
          child: MarketplaceScreen(onBack: () {}, forceColumns: columns),
        ),
      ),
    );
    await precacheAll(tester);
    await export(tester, find.byType(MarketplaceScreen), name);
    await expectLater(find.byType(MarketplaceScreen), matchesGoldenFile('goldens/$name.png'));
  }

  testWidgets('marketplace, phone: two columns (demo content) at 390 x 1143', (tester) async {
    await board(
      tester,
      size: const Size(390, 1143),
      repo: DemoMarketplaceRepository(),
      name: 'marketplace',
      // The design reads "Filters (3)": two categories and a city.
      initial: const MarketplaceFilters(categories: {'PHYSICAL_SECURITY', 'ELECTRONIC_SECURITY'}, city: 'Bengaluru'),
    );
  });

  testWidgets('marketplace, tablet comp: three columns (demo content) at 390 x 1530', (tester) async {
    await board(
      tester,
      size: const Size(390, 1530),
      repo: DemoMarketplaceRepository(cards: DemoMarketplaceRepository.tabletCards()),
      columns: 3,
      name: 'marketplace_3col',
      initial: const MarketplaceFilters(categories: {'PHYSICAL_SECURITY', 'ELECTRONIC_SECURITY'}, city: 'Bengaluru'),
    );
  });

  Future<void> sheet(
    WidgetTester tester, {
    required SupplierTab tab,
    required double height,
    required String name,
  }) async {
    tester.view.physicalSize = Size(780, height * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final repo = DemoMarketplaceRepository();
    final market = MarketplaceController(repo);
    final controller = SupplierController(repository: repo, seed: DemoMarketplaceRepository.vikasha, tab: tab);
    await tester.runAsync(() async {
      await market.start();
      await controller.load();
    });
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: ChangeNotifierProvider.value(
          value: market,
          child: ChangeNotifierProvider.value(
            value: controller,
            child: const Scaffold(
              backgroundColor: Colors.white,
              body: SupplierSheetFrame(topInset: 0, body: SupplierSheetBody(), bottomBar: SupplierSheetBar()),
            ),
          ),
        ),
      ),
    );
    await precacheAll(tester);
    await export(tester, find.byType(SupplierSheetFrame), name);
    await expectLater(find.byType(SupplierSheetFrame), matchesGoldenFile('goldens/$name.png'));
  }

  testWidgets('supplier profile, Overview (demo content) at 390 x 780', (tester) async {
    await sheet(tester, tab: SupplierTab.overview, height: 780, name: 'supplier_overview');
  });

  testWidgets('supplier profile, Products & services (demo content) at 390 x 1095', (tester) async {
    await sheet(tester, tab: SupplierTab.catalog, height: 1095, name: 'supplier_services');
  });

  testWidgets('supplier profile, Compliances & Proofs (demo content) at 390 x 898', (tester) async {
    await sheet(tester, tab: SupplierTab.proofs, height: 898, name: 'supplier_compliances');
  });
}
