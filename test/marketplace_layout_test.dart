import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/marketplace/demo_marketplace_repository.dart';
import 'package:icr_mobile/features/marketplace/marketplace_controller.dart';
import 'package:icr_mobile/features/marketplace/marketplace_filters.dart';
import 'package:icr_mobile/features/marketplace/marketplace_screen.dart';
import 'package:icr_mobile/features/marketplace/supplier_controller.dart';
import 'package:icr_mobile/features/marketplace/supplier_sheet.dart';
import 'package:icr_mobile/features/marketplace/widgets/supplier_card.dart';
import 'package:provider/provider.dart';

import 'helpers/fonts.dart';
import 'helpers/layout_audit.dart';
import 'marketplace_fakes.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    // The licence number is set in `Courier` on a phone; a test has no such font, so it borrows Roboto.
    final courier = FontLoader('Courier')..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    await courier.load();
  });

  /// A design's fixed heights were set for text under the app's 12 sp floor, so a card's rating ("4.8"), its
  /// "(124 reviews)" and a two-line company name were cut at the bottom, and the profile's "View Hubs" hung
  /// below the title it belongs to. Both the common 390 dp phone and a narrow 360 dp one, where the cards are
  /// narrower still.
  group('no text on the Marketplace screens is cut off by its box', () {
    void sized(WidgetTester tester, double width, double height) {
      tester.view.physicalSize = Size(width * 2, height * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
    }

    Future<void> pumpMart(WidgetTester tester, DemoMarketplaceRepository repo, {int? columns}) async {
      final market = MarketplaceController(repo);
      addTearDown(market.dispose);
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
      await tester.pumpAndSettle();
    }

    Future<void> pumpSheet(WidgetTester tester, SupplierTab tab) async {
      final repo = DemoMarketplaceRepository();
      final market = MarketplaceController(repo);
      final controller = SupplierController(repository: repo, seed: DemoMarketplaceRepository.vikasha, tab: tab);
      addTearDown(market.dispose);
      addTearDown(controller.dispose);
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
      await tester.pumpAndSettle();
    }

    void expectNothingCut(WidgetTester tester) {
      expect(layoutProblems().where((p) => p.startsWith('clipped')), isEmpty);
      expect(tester.takeException(), isNull);
    }

    for (final width in [390.0, 360.0]) {
      final dp = width.toInt();

      testWidgets('the mart, two columns of the design\'s cards at $dp dp', (tester) async {
        sized(tester, width, 1400);
        await pumpMart(tester, DemoMarketplaceRepository());
        expect(find.byType(SupplierCard), findsWidgets);
        expectNothingCut(tester);
      });

      testWidgets('the mart, three columns of the tablet comp\'s cards at $dp dp', (tester) async {
        sized(tester, width, 1600);
        await pumpMart(tester, DemoMarketplaceRepository(cards: DemoMarketplaceRepository.tabletCards()), columns: 3);
        expect(find.byType(SupplierCard), findsWidgets);
        expectNothingCut(tester);
      });

      testWidgets('the mart with live suppliers, a company name over two lines, at $dp dp', (tester) async {
        sized(tester, width, 1000);
        final repo = SpyMarketplaceRepository()
          ..searchAnswer = (f, p) => SupplierPage(
            suppliers: [
              fakeSupplier('a', name: 'Meridian Facility Services', headline: null, about: null),
              fakeSupplier('b', name: 'Duct Masters', rating: 4.5, ratingCount: 1),
              fakeSupplier('c', name: 'Vikasha Aero Tech', rating: 0, ratingCount: 0),
              fakeSupplier('d', name: 'Meridian Integrated Facility Management Services'),
            ],
            total: 4,
            page: 1,
            hasMore: false,
          );
        await pumpMart(tester, repo);
        expect(find.text('Meridian Facility Services'), findsOneWidget);
        expectNothingCut(tester);
      });

      for (final tab in SupplierTab.values) {
        testWidgets('the supplier profile, ${tab.label}, at $dp dp', (tester) async {
          sized(tester, width, 1200);
          await pumpSheet(tester, tab);
          expect(find.text('Vikasha Aero Tech'), findsWidgets);
          expectNothingCut(tester);
        });
      }
    }
  });
}
