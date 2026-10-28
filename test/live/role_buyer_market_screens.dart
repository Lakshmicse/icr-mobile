/// Role matrix, part 2b: the Marketplace and requirements screens, drawn over the live API for each of the four
/// accounts that belong to no company.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/auth/auth_controller.dart';
import 'package:icr_mobile/features/account/companies/create_company_screen.dart';
import 'package:icr_mobile/features/marketplace/marketplace_controller.dart';
import 'package:icr_mobile/features/marketplace/marketplace_screen.dart';
import 'package:icr_mobile/features/marketplace/widgets/supplier_card.dart';
import 'package:icr_mobile/features/rfq/my_bids_screen.dart';
import 'package:icr_mobile/features/rfq/my_rfqs_screen.dart';
import 'package:icr_mobile/features/rfq/open_requirements_screen.dart';
import 'package:icr_mobile/features/rfq/post_rfq_screen.dart';
import 'package:icr_mobile/features/rfq/rfq_alerts_screen.dart';
import 'package:icr_mobile/features/rfq/rfq_models.dart';
import 'package:provider/provider.dart';

import '../helpers/fonts.dart';
import 'career_live_support.dart';
import 'role_buyer_market.dart';
import 'role_buyer_support.dart';

void roleBuyerMarketScreens() {
  setUpAll(loadAppFonts);

  group('the Marketplace and requirements screens, drawn for every account', () {
    testWidgets(
      'the quote form for a person with no company shows the API sentence and offers Create a company',
      tags: const ['live'],
      (tester) async {
        if (!await liveScreenReady(tester)) return;
        for (final w in (await tester.runAsync(everyone))!) {
          final market = (await tester.runAsync(() async {
            final c = MarketplaceController(marketOf(w));
            await c.start();
            return c;
          }))!;
          final phoneBefore = w.phone;
          await loadScreen(
            tester,
            MarketplaceScreen(onBack: () {}),
            providers: [ChangeNotifierProvider<MarketplaceController>.value(value: market)],
            // Where IcrApp keeps the client and the session: a route pushed over the screen reaches them.
            appProviders: [
              Provider<ApiClient>.value(value: w.api),
              ChangeNotifierProvider<AuthController>(
                create: (_) => AuthController(api: w.api, tokens: w.api.tokens),
              ),
            ],
            size: const Size(390, 1100),
          );
          final text = expectHealthy(tester, 'the Marketplace as ${w.email}');
          expect(text, contains('Post RFQ'));
          expect(text, contains('Alerts'));
          expect(find.byType(SupplierCard), findsWidgets, reason: '${w.email}: the suppliers are drawn');

          // The supplier sheet, then its Request for Quote.
          await tester.tap(find.byType(SupplierCard).first);
          await afterTap(tester);
          expectHealthy(tester, 'the supplier sheet as ${w.email}');
          final ask = find.byKey(const ValueKey('request-quote'));
          expect(ask, findsOneWidget, reason: '${w.email}: the sheet offers Request for Quote');
          await tester.tap(ask);
          await afterTap(tester);
          expect(find.text('Request a quote'), findsOneWidget);
          await tester.enterText(find.byKey(const ValueKey('quote-notes')), 'Night shifts only (role matrix).');
          if (find.byKey(const ValueKey('quote-phone')).evaluate().isNotEmpty) {
            await tester.enterText(find.byKey(const ValueKey('quote-phone')), '+91 98123 45670');
          }
          final send = find.byKey(const ValueKey('quote-send'));
          await tester.ensureVisible(send);
          await tester.tap(send);
          await afterTap(tester);

          // The API's refusal is on the form, with what was typed and the way out.
          final error = find.byKey(const ValueKey('quote-error'));
          expect(error, findsOneWidget, reason: '${w.email}: the refusal is shown');
          final sentence = ((error.evaluate().single.widget as Container).child as Text).data!;
          expect(sentence, isNotEmpty);
          expect(sentence.toLowerCase(), isNot(contains('insufficient role')), reason: 'the person is told what to do');
          expect(find.text('Night shifts only (role matrix).'), findsOneWidget, reason: 'what was typed is kept');
          final create = find.byKey(const ValueKey('quote-create-company'));
          expect(create, findsOneWidget, reason: '${w.email}: Create a company is offered');

          // It opens the app's own page for founding a company.
          await tester.ensureVisible(create);
          await tester.tap(create);
          await afterTap(tester);
          expect(
            find.byType(CreateCompanyScreen),
            findsOneWidget,
            reason: '${w.email}: the company page opens in the app',
          );
          expectHealthy(tester, 'Create a company as ${w.email}');
          record(
            'Marketplace: quote form without a company',
            w.person,
            'bug fixed',
            'shows "$sentence" and offers Create a company (opens the in-app page)',
          );
          await unmount(tester);
          market.dispose();
          // A refused quote must not have saved a phone number.
          final after = (await tester.runAsync(() => w.api.dio.get<Map<String, dynamic>>('/auth/me')))!.data!;
          expect(after['phone'], phoneBefore, reason: '${w.email}: a refusal wrote nothing to the profile');
        }
      },
    );

    testWidgets('My RFQ\'s lists what its chip counts, or says why not with Create a company', tags: const ['live'], (
      tester,
    ) async {
      if (!await liveScreenReady(tester)) return;
      for (final w in (await tester.runAsync(everyone))!) {
        final created = <String>[];
        final repo = rfqOf(w);
        await loadScreen(
          tester,
          MyRfqsScreen(repository: repo, onBack: () {}, onCreateCompany: () => created.add(w.email)),
          size: const Size(390, 1600),
        );
        final text = expectHealthy(tester, 'My RFQ\'s as ${w.email}');
        if (w.me['role'] == 'BUYER') {
          final all = (await tester.runAsync(repo.summary))!.count(MyView.all);
          final chip = (await tester.runAsync(marketOf(w).counts))!.myRfqs;
          expect(text, contains('All $all'), reason: '${w.email}: the All tab counts $all');
          expect(chip, all, reason: '${w.email}: the Marketplace chip and the All tab agree');
          record('Requirements: My RFQ\'s screen', w.person, 'works', 'All tab $all = chip $chip');
        } else {
          expect(text, contains('Requirements are posted by buyers and companies'));
          final button = find.text('Create a company page');
          expect(button, findsOneWidget);
          await tester.tap(button);
          await tester.pump();
          expect(created, [w.email], reason: 'the button founds a company');
          record('Requirements: My RFQ\'s screen', w.person, 'refused correctly', 'sentence + Create a company page');
        }
        await unmount(tester);
      }
    });

    testWidgets(
      'Post RFQ tells a person with no company so before the form, and offers Create a company',
      tags: const ['live'],
      (tester) async {
        if (!await liveScreenReady(tester)) return;
        for (final w in (await tester.runAsync(everyone))!) {
          var created = 0;
          await loadScreen(
            tester,
            PostRfqScreen(repository: rfqOf(w), onBack: () {}, onCreateCompany: () => created++),
            size: const Size(390, 1200),
          );
          final text = expectHealthy(tester, 'Post RFQ as ${w.email}');
          expect(text, contains('Requirements are posted for a company'));
          await tester.tap(find.text('Create a company'));
          await tester.pump();
          expect(created, 1);
          record(
            'Requirements: Post RFQ screen',
            w.person,
            'refused correctly',
            'the form says so first + Create a company',
          );
          await unmount(tester);
        }
      },
    );

    testWidgets(
      'Alerts, Find work and My Bids draw for every account: the supplier screens say they are for suppliers',
      tags: const ['live'],
      (tester) async {
        if (!await liveScreenReady(tester)) return;
        for (final w in (await tester.runAsync(everyone))!) {
          final repo = rfqOf(w);
          await loadScreen(
            tester,
            RfqAlertsScreen(repository: repo, onBack: () {}),
            size: const Size(390, 900),
          );
          expectHealthy(tester, 'Alerts as ${w.email}');
          await unmount(tester);
          await loadScreen(
            tester,
            OpenRequirementsScreen(repository: repo, onBack: () {}),
            size: const Size(390, 900),
          );
          var text = expectHealthy(tester, 'Find work as ${w.email}');
          expect(text, contains('This is for supplier accounts'));
          await unmount(tester);
          await loadScreen(
            tester,
            MyBidsScreen(repository: repo, onBack: () {}),
            size: const Size(390, 900),
          );
          text = expectHealthy(tester, 'My Bids as ${w.email}');
          expect(text, contains('This is for supplier accounts'));
          await unmount(tester);
          record(
            'Requirements: Alerts, Find work, My Bids screens',
            w.person,
            'works',
            'alerts draw; the supplier screens say "for supplier accounts"',
          );
        }
      },
    );
  });
}
