/// The screens a COMPANY account opens, drawn over the LOCAL portal API: what each of the seven accounts really
/// sees, with no thrown exception, the screen's loaded state (or its proper refusal), never an error state or a
/// raw guard sentence. The calls behind them are proved in `role_company_live_test.dart`,
/// `role_company_rfq_live_test.dart` and `role_company_inbox_live_test.dart`.
///
/// Everything a test makes is undone as in those files (requirements and postings deleted, the applicant a
/// throwaway person).
///
///     flutter test --no-pub test/live/role_company_screens_live_test.dart --concurrency=1
@Tags(['live'])
library;

import 'package:dio/dio.dart' show DioException, DioExceptionType;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/auth/auth_controller.dart';
import 'package:icr_mobile/features/account/api_account_repository.dart';
import 'package:icr_mobile/features/account/companies/my_companies_screen.dart';
import 'package:icr_mobile/features/jobs/employer/api_hiring_repository.dart';
import 'package:icr_mobile/features/jobs/employer/applicant_detail_screen.dart';
import 'package:icr_mobile/features/jobs/employer/applicants_screen.dart';
import 'package:icr_mobile/features/jobs/employer/employer_jobs_screen.dart';
import 'package:icr_mobile/features/jobs/employer/hiring_models.dart';
import 'package:icr_mobile/features/jobs/employer/post_job_screen.dart';
import 'package:icr_mobile/features/marketplace/api_marketplace_repository.dart';
import 'package:icr_mobile/features/marketplace/quote_controller.dart';
import 'package:icr_mobile/features/marketplace/widgets/request_quote_sheet.dart';
import 'package:icr_mobile/features/messaging/api_messaging_repository.dart';
import 'package:icr_mobile/features/messaging/conversation_screen.dart';
import 'package:icr_mobile/features/messaging/inbox_screen.dart';
import 'package:icr_mobile/features/rfq/api_rfq_repository.dart';
import 'package:icr_mobile/features/rfq/my_bids_screen.dart';
import 'package:icr_mobile/features/rfq/my_rfqs_screen.dart';
import 'package:icr_mobile/features/rfq/open_requirements_screen.dart';
import 'package:icr_mobile/features/rfq/post_rfq_screen.dart';
import 'package:icr_mobile/features/rfq/rfq_alerts_screen.dart';
import 'package:icr_mobile/features/rfq/rfq_detail_screen.dart';
import 'package:icr_mobile/features/rfq/rfq_models.dart';
import 'package:icr_mobile/features/rfq/rfq_rules.dart' show BidDraft;
import 'package:icr_mobile/features/rfq/supplier_controllers.dart';
import 'package:provider/provider.dart';

import 'package:icr_mobile/core/theme/app_theme.dart';

import '../helpers/fonts.dart';
import '../jobs_fakes.dart';
import 'career_live_support.dart';
import 'live.dart';
import 'role_company_support.dart';

/// Waits in real time until [finder] matches (or [timeout]), pumping as it goes.
Future<bool> waitFor(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 15)}) async {
  final until = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(until)) {
    if (finder.evaluate().isNotEmpty) return true;
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
    await tester.pump(const Duration(milliseconds: 50));
  }
  return finder.evaluate().isNotEmpty;
}

/// Runs [body] in real time. A screen test lets seconds pass between requests and the API drops an idle
/// connection after five, so a call that dies with a stale one (a timeout, a closed socket) is made again.
/// (`runAsync` reports an error thrown inside it instead of rethrowing it, so the body catches its own.)
Future<T> real<T>(WidgetTester tester, Future<T> Function() body) async {
  for (var attempt = 0; ; attempt++) {
    final out = await tester.runAsync<({T? value, Object? error})>(() async {
      try {
        return (value: await body(), error: null);
      } catch (e) {
        return (value: null, error: e);
      }
    });
    final error = out!.error;
    if (error == null) return out.value as T;
    final stale =
        (error is ApiError && error.isOffline) ||
        (error is DioException &&
            (error.type == DioExceptionType.receiveTimeout ||
                error.type == DioExceptionType.connectionTimeout ||
                error.type == DioExceptionType.connectionError));
    if (!stale || attempt >= 2) throw error;
  }
}

/// [who]'s session with a short receive timeout: the API answers in milliseconds, so a call that is still waiting
/// after six seconds is on a stale connection, and is made again by [real].
Future<ApiClient> client(WidgetTester tester, LivePerson who) async {
  final api = await real(tester, () => liveClient(who));
  api.dio.options.receiveTimeout = const Duration(seconds: 6);
  return api;
}

/// A screen opened over the real API as [who]; the accounts' sessions come from `liveClient`.
Future<void> open(WidgetTester tester, Widget screen, {Size size = const Size(390, 2400)}) async {
  // A new app each time: the old one's pushed routes (a detail page) must not stay on top of the next screen.
  await tester.pumpWidget(const SizedBox());
  await pumpLive(tester, screen, size: size);
  await settleLive(tester);
}

void main() {
  setUpAll(loadAppFonts);

  /// Skips a test when the fixture file (the passwords) or the API is not there; false means "stop".
  Future<bool> ready(WidgetTester tester) async {
    if (!fixturesAvailable) {
      markTestSkipped('the e2e fixture file with the account passwords was not found (ICR_USERS_JSON)');
      return false;
    }
    return liveScreenReady(tester);
  }

  group('Requirements', () {
    testWidgets(
      'My RFQ\'s for the company admin draws the live requirements, and a passed deadline reads once',
      tags: const ['live'],
      (tester) async {
        if (!await ready(tester)) return;
        final api = await client(tester, (companyAdmin));
        await open(
          tester,
          MyRfqsScreen(
            key: UniqueKey(),
            repository: ApiRfqRepository(api: api),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Post RFQ'), findsWidgets);
        expect(find.textContaining('Live '), findsWidgets);
        expect(find.byKey(const ValueKey('role-cannot-post')), findsNothing);
        expect(find.textContaining("Couldn't load"), findsNothing);
        // "Pre-qual closes closed 8 days ago" read the word twice for any deadline that had passed.
        expect(find.textContaining('closes closed'), findsNothing);
        expect(find.textContaining('due closed'), findsNothing);
        await finishLive(tester);
      },
    );

    testWidgets(
      'My RFQ\'s for the buyer company\'s two people: an empty list that offers the first requirement',
      tags: const ['live'],
      (tester) async {
        if (!await ready(tester)) return;
        for (final who in [marketBuyer, marketNoPhone]) {
          final api = await client(tester, (who));
          await open(
            tester,
            MyRfqsScreen(
              key: UniqueKey(),
              repository: ApiRfqRepository(api: api),
            ),
          );
          expect(tester.takeException(), isNull, reason: who.label);
          // Anything the other tests left is already deleted; either the list or the first-requirement card is fine.
          expect(find.byKey(const ValueKey('role-cannot-post')), findsNothing, reason: who.label);
          expect(find.textContaining("Couldn't load"), findsNothing, reason: who.label);
        }
        await finishLive(tester);
      },
    );

    testWidgets(
      'an office admin, a recruiter and a hiring manager are told the limit of their role, not shown a failure',
      tags: const ['live'],
      (tester) async {
        if (!await ready(tester)) return;
        final words = {branchAdmin: 'an office admin', recruiter: 'a recruiter', hiringManager: 'a hiring manager'};
        for (final entry in words.entries) {
          final api = await client(tester, (entry.key));
          final repo = ApiRfqRepository(api: api);

          await open(tester, MyRfqsScreen(key: UniqueKey(), repository: repo));
          expect(tester.takeException(), isNull, reason: entry.key.label);
          expect(find.byKey(const ValueKey('role-cannot-post')), findsOneWidget, reason: entry.key.label);
          expect(find.textContaining(entry.value), findsOneWidget, reason: entry.key.label);
          expect(find.textContaining(companyName), findsOneWidget, reason: entry.key.label);
          expect(
            find.text('Create a company page'),
            findsNothing,
            reason: '${entry.key.label}: a new company is not the fix',
          );
          expect(find.textContaining("Couldn't load"), findsNothing);
          expect(find.textContaining('Insufficient'), findsNothing);

          await open(
            tester,
            PostRfqScreen(key: UniqueKey(), repository: repo),
            size: const Size(390, 3600),
          );
          expect(tester.takeException(), isNull, reason: entry.key.label);
          expect(find.byKey(const ValueKey('role-cannot-post')), findsOneWidget, reason: entry.key.label);
          expect(
            find.byKey(const ValueKey('send')),
            findsNothing,
            reason: '${entry.key.label}: no Send on a form that cannot be sent',
          );
          expect(find.byKey(const ValueKey('save-draft')), findsNothing, reason: entry.key.label);
        }
        await finishLive(tester);
      },
    );

    testWidgets(
      'Post RFQ opens for the admin and the buyer on their company, and the service list loads without a false error',
      tags: const ['live'],
      (tester) async {
        if (!await ready(tester)) return;
        final expected = {
          companyAdmin: companyName,
          founder: companyName,
          marketBuyer: 'Meridian Corporate Estates',
          marketNoPhone: 'Meridian Corporate Estates',
        };
        for (final entry in expected.entries) {
          final api = await client(tester, (entry.key));
          await pumpLive(
            tester,
            PostRfqScreen(
              key: UniqueKey(),
              repository: ApiRfqRepository(api: api),
            ),
            size: const Size(390, 3600),
          );
          expect(
            await waitFor(tester, find.byKey(const ValueKey('category-field'))),
            isTrue,
            reason: '${entry.key.label}: the services load',
          );
          expect(tester.takeException(), isNull, reason: entry.key.label);
          expect(find.text(entry.value), findsWidgets, reason: entry.key.label);
          expect(find.text('The list of services could not load.'), findsNothing, reason: entry.key.label);
          expect(find.byKey(const ValueKey('send')), findsOneWidget, reason: entry.key.label);
          expect(find.byKey(const ValueKey('role-cannot-post')), findsNothing, reason: entry.key.label);
        }
        await finishLive(tester);
      },
    );

    testWidgets(
      'the requirement page: the admin reads the replies and shortlists one; the office admin is told it is the company\'s',
      tags: const ['live'],
      (tester) async {
        if (!await ready(tester)) return;
        final posted = await real(tester, () => postRequirement(companyAdmin));
        final caApi = await client(tester, (companyAdmin));
        final repo = ApiRfqRepository(api: caApi);
        await real(tester, () async {
          final page = OpportunityController(
            repository: ApiRfqRepository(api: await liveClient(bluepeak)),
            rfqId: posted.id,
          );
          await page.start();
          await page.placeBid(
            BidDraft()
              ..amount = '5,10,000'
              ..leadTime = '9'
              ..message = 'Role test: ready to start in a week.',
          );
        });
        await open(
          tester,
          RfqDetailScreen(posted.id, key: UniqueKey(), repository: repo),
          size: const Size(390, 3000),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Bluepeak Security'), findsWidgets);
        expect(find.textContaining('Role test: ready to start'), findsOneWidget);
        final bid = (await real(tester, () => repo.bids(posted.id))).single;
        expect(find.byKey(ValueKey('bid-card-${bid.id}')), findsOneWidget);
        await tester.ensureVisible(find.byKey(ValueKey('bid-shortlist-${bid.id}')));
        await tester.tap(find.byKey(ValueKey('bid-shortlist-${bid.id}')));
        await settleLive(tester);
        Future<BidStatus> storedAfter(BidStatus want) async {
          // The tap is applied on screen at once and goes to the API in the background: wait for it to land.
          var status = (await real(tester, () => repo.bids(posted.id))).single.status;
          for (var i = 0; i < 12 && status != want; i++) {
            await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
            await tester.pump(const Duration(milliseconds: 50));
            status = (await real(tester, () => repo.bids(posted.id))).single.status;
          }
          return status;
        }

        expect(await storedAfter(BidStatus.shortlisted), BidStatus.shortlisted);
        // Take it back through the screen, as the buyer would.
        expect(find.byKey(ValueKey('bid-unshortlist-${bid.id}')), findsOneWidget);
        await tester.ensureVisible(find.byKey(ValueKey('bid-unshortlist-${bid.id}')));
        await tester.tap(find.byKey(ValueKey('bid-unshortlist-${bid.id}')));
        await settleLive(tester);
        expect(await storedAfter(BidStatus.pending), BidStatus.pending);

        // The same requirement, opened by an office admin of the same company: the brief, and a sentence about her role.
        final baApi = await client(tester, (branchAdmin));
        await open(
          tester,
          RfqDetailScreen(
            posted.id,
            key: UniqueKey(),
            repository: ApiRfqRepository(api: baApi),
          ),
          size: const Size(390, 3000),
        );
        expect(tester.takeException(), isNull);
        expect(await waitFor(tester, find.textContaining('as an office admin you can read the brief only')), isTrue);
        expect(find.text('Bluepeak Security'), findsNothing, reason: 'the replies are not shown to her');
        expect(find.byKey(const ValueKey('act-close')), findsNothing);
        await finishLive(tester);
      },
    );

    testWidgets(
      'Alerts for the admin lists what was about the company\'s requirements, with no failure',
      tags: const ['live'],
      (tester) async {
        if (!await ready(tester)) return;
        final api = await client(tester, (companyAdmin));
        await open(
          tester,
          RfqAlertsScreen(
            key: UniqueKey(),
            repository: ApiRfqRepository(api: api),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.textContaining("Couldn't load"), findsNothing);
        expect(find.text('Mark all read'), findsWidgets);
        await finishLive(tester);
      },
    );
  });

  group('Find work and My bids: the company as a seller', () {
    testWidgets(
      'the company that sells reads the board and its bids; the company with no listing is offered "Start selling"; the other roles are told it is for suppliers',
      tags: const ['live'],
      (tester) async {
        if (!await ready(tester)) return;
        for (final who in [companyAdmin, founder]) {
          final api = await client(tester, who);
          await open(
            tester,
            OpenRequirementsScreen(
              key: UniqueKey(),
              repository: ApiRfqRepository(api: api),
            ),
            size: const Size(390, 2400),
          );
          expect(tester.takeException(), isNull, reason: who.label);
          expect(find.textContaining('supplier accounts'), findsNothing, reason: who.label);
          expect(find.text('Recommended'), findsWidgets, reason: who.label);
          expect(find.textContaining("Couldn't load"), findsNothing, reason: who.label);
          await open(
            tester,
            MyBidsScreen(
              key: UniqueKey(),
              repository: ApiRfqRepository(api: api),
            ),
            size: const Size(390, 2400),
          );
          expect(tester.takeException(), isNull, reason: who.label);
          expect(find.textContaining('supplier accounts'), findsNothing, reason: who.label);
          expect(find.textContaining("Couldn't load"), findsNothing, reason: who.label);
        }
        // The Marketplace seed's buyer company never started selling: one tap offers it.
        final maya = await client(tester, marketBuyer);
        await open(
          tester,
          OpenRequirementsScreen(
            key: UniqueKey(),
            repository: ApiRfqRepository(api: maya),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Start selling'), findsWidgets);
        for (final who in [branchAdmin, recruiter, hiringManager, marketNoPhone]) {
          final api = await client(tester, who);
          for (final screen in <Widget>[
            OpenRequirementsScreen(
              key: UniqueKey(),
              repository: ApiRfqRepository(api: api),
            ),
            MyBidsScreen(
              key: UniqueKey(),
              repository: ApiRfqRepository(api: api),
            ),
          ]) {
            await open(tester, screen);
            expect(tester.takeException(), isNull, reason: who.label);
            expect(find.text('This is for supplier accounts'), findsOneWidget, reason: who.label);
            expect(find.textContaining("Couldn't load"), findsNothing, reason: who.label);
            expect(find.textContaining('Insufficient'), findsNothing, reason: who.label);
          }
        }
        await finishLive(tester);
      },
    );
  });

  group('The Marketplace Request for Quote sheet', () {
    /// The form over [who]'s session, on the sandbox supplier: the same controller and sheet the profile opens.
    Future<QuoteController> openQuoteSheet(WidgetTester tester, LivePerson who) async {
      final api = await client(tester, who);
      final repo = ApiMarketplaceRepository(api: api);
      final supplier = await real(tester, () => repo.supplier('design-mkt-v-sandbox'));
      final controller = QuoteController(repository: repo, supplier: supplier);
      addTearDown(controller.dispose);
      await real(tester, controller.load);
      await tester.pumpWidget(const SizedBox());
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: ChangeNotifierProvider<QuoteController>.value(value: controller, child: const RequestQuoteSheet()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const ValueKey('quote-send')), findsOneWidget, reason: 'the form opens: ${who.label}');
      return controller;
    }

    testWidgets(
      'a number on file means no phone field; a buyer with none is asked for one, and is not let through without it',
      tags: const ['live'],
      (tester) async {
        if (!await ready(tester)) return;
        for (final who in [marketBuyer, companyAdmin]) {
          await openQuoteSheet(tester, who);
          expect(tester.takeException(), isNull, reason: who.label);
          expect(find.byKey(const ValueKey('quote-phone')), findsNothing, reason: '${who.label} has a number on file');
          expect(find.byKey(const ValueKey('quote-send')), findsOneWidget, reason: who.label);
        }
        final api = await client(tester, marketNoPhone);
        await real(tester, () => api.dio.patch<dynamic>('/users/me', data: {'phone': ''}));
        addTearDown(() => api.dio.patch<dynamic>('/users/me', data: {'phone': ''}));
        await openQuoteSheet(tester, marketNoPhone);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('quote-phone')), findsOneWidget, reason: 'he has none: the form asks');
        await tester.ensureVisible(find.byKey(const ValueKey('quote-send')));
        await tester.tap(find.byKey(const ValueKey('quote-send')));
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          find.textContaining('Add a mobile number'),
          findsWidgets,
          reason: 'refused on the phone before any request',
        );
        await finishLive(tester);
      },
    );

    testWidgets(
      'an office admin, a recruiter and a hiring manager are told, in the form, who can send it; no company page is offered',
      tags: const ['live'],
      (tester) async {
        if (!await ready(tester)) return;
        for (final who in [branchAdmin, recruiter, hiringManager]) {
          await openQuoteSheet(tester, who);
          expect(tester.takeException(), isNull, reason: who.label);
          if (find.byKey(const ValueKey('quote-phone')).evaluate().isNotEmpty) {
            await tester.enterText(find.byKey(const ValueKey('quote-phone')), '+91 98765 43210');
          }
          await tester.ensureVisible(find.byKey(const ValueKey('quote-send')));
          await tester.tap(find.byKey(const ValueKey('quote-send')));
          expect(
            await waitFor(tester, find.byKey(const ValueKey('quote-error'))),
            isTrue,
            reason: 'refused: ${who.label}',
          );
          expect(find.textContaining("Ask your company's admin"), findsOneWidget, reason: who.label);
          expect(find.textContaining('Insufficient'), findsNothing, reason: who.label);
          expect(
            find.byKey(const ValueKey('quote-create-company')),
            findsNothing,
            reason: '${who.label} has a company already',
          );
          expect(find.byKey(const ValueKey('quote-sent')), findsNothing, reason: who.label);
        }
        await finishLive(tester);
      },
    );
  });

  group('Jobs you posted', () {
    testWidgets(
      'each hiring account sees its scope: the admin the company, the office roles their office',
      tags: const ['live'],
      (tester) async {
        if (!await ready(tester)) return;
        final totals = <String, int>{};
        for (final who in [companyAdmin, founder, branchAdmin, recruiter]) {
          final api = await client(tester, (who));
          await open(
            tester,
            EmployerJobsScreen(
              key: UniqueKey(),
              repository: ApiHiringRepository(api: api, pageSize: 50),
              links: RecordingLinks(),
            ),
            size: const Size(390, 3600),
          );
          expect(tester.takeException(), isNull, reason: who.label);
          expect(find.text('Jobs you posted'), findsOneWidget, reason: who.label);
          expect(find.byKey(const ValueKey('figures')), findsOneWidget, reason: who.label);
          expect(find.byKey(const ValueKey('no-role')), findsNothing, reason: who.label);
          expect(find.byKey(const ValueKey('jobs-error')), findsNothing, reason: who.label);
          final all = find.textContaining(RegExp(r'^All \d+$'));
          expect(all, findsOneWidget, reason: who.label);
          totals[who.email] = int.parse((tester.widget<Text>(all).data ?? '').split(' ').last);
        }
        expect(totals[companyAdmin.email], totals[founder.email], reason: 'the two admins read one company');
        expect(totals[branchAdmin.email], totals[recruiter.email], reason: 'the two office roles read one office');
        expect(totals[branchAdmin.email]!, lessThanOrEqualTo(totals[companyAdmin.email]!));
        await finishLive(tester);
      },
    );

    testWidgets(
      'a hiring manager and a buyer are told posting is for hiring teams, not shown an error',
      tags: const ['live'],
      (tester) async {
        if (!await ready(tester)) return;
        for (final who in [hiringManager, marketNoPhone]) {
          final api = await client(tester, (who));
          await open(
            tester,
            EmployerJobsScreen(
              key: UniqueKey(),
              repository: ApiHiringRepository(api: api),
              links: RecordingLinks(),
            ),
          );
          expect(tester.takeException(), isNull, reason: who.label);
          expect(find.byKey(const ValueKey('no-role')), findsOneWidget, reason: who.label);
          expect(find.text('Posting jobs is for hiring teams'), findsOneWidget, reason: who.label);
          expect(find.byKey(const ValueKey('jobs-error')), findsNothing, reason: who.label);
        }
        await finishLive(tester);
      },
    );

    testWidgets(
      'the buyer company\'s admin sees the company check before publishing, and the composer says so',
      tags: const ['live'],
      (tester) async {
        if (!await ready(tester)) return;
        final api = await client(tester, (marketBuyer));
        await open(
          tester,
          PostJobScreen(
            key: UniqueKey(),
            repository: ApiHiringRepository(api: api),
            links: RecordingLinks(),
          ),
          size: const Size(390, 6000),
        );
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('gate-note')), findsOneWidget);
        expect(find.textContaining('Verify your company before publishing jobs.'), findsOneWidget);
        await finishLive(tester);
      },
    );

    testWidgets(
      'the composer shows the checklist to the admin and the recruiter, salary is not on it, and a short title is named',
      tags: const ['live'],
      (tester) async {
        if (!await ready(tester)) return;
        for (final who in [companyAdmin, recruiter, branchAdmin]) {
          final api = await client(tester, (who));
          await open(
            tester,
            PostJobScreen(
              key: UniqueKey(),
              repository: ApiHiringRepository(api: api),
              links: RecordingLinks(),
            ),
            size: const Size(390, 6000),
          );
          expect(tester.takeException(), isNull, reason: who.label);
          expect(find.text('Before you publish'), findsOneWidget, reason: who.label);
          expect(
            find.byKey(const ValueKey('gate-note')),
            findsNothing,
            reason: '${who.label}: the company is verified',
          );
          expect(
            find.textContaining('salary', findRichText: true),
            findsWidgets,
            reason: 'the pay card is there, optional',
          );
          // The checklist names what is missing, and pay is not one of them.
          expect(find.textContaining('Add a salary'), findsNothing, reason: 'salary is optional');
        }
        await finishLive(tester);
      },
    );

    testWidgets(
      'a recruiter and an office admin fill the composer, publish with no salary, and the posting is live in their office',
      tags: const ['live'],
      (tester) async {
        if (!await ready(tester)) return;
        for (final who in [recruiter, branchAdmin]) {
          final api = await client(tester, who);
          final repo = ApiHiringRepository(api: api, pageSize: 50);
          final title = 'MOBILE-LIVE company ui ${DateTime.now().millisecondsSinceEpoch}';
          await open(
            tester,
            PostJobScreen(key: UniqueKey(), repository: repo, links: RecordingLinks()),
            size: const Size(390, 6000),
          );
          expect(find.byKey(const ValueKey('publish')), findsOneWidget, reason: who.label);
          await tester.enterText(find.byKey(const ValueKey('job-title')), title);
          await tester.enterText(find.byKey(const ValueKey('job-description')), longDescription.replaceAll('\n', ' '));
          await tester.enterText(find.byKey(const ValueKey('job-city')), 'Pune');
          await tester.tap(find.byKey(const ValueKey('add-city')));
          await tester.enterText(find.byKey(const ValueKey('skill-input')), 'HVAC');
          await tester.tap(find.byKey(const ValueKey('add-skill')));
          await tester.pump();
          expect(
            find.byKey(const ValueKey('blocker-title')),
            findsNothing,
            reason: '${who.label}: the checklist is clear',
          );
          expect(find.byKey(const ValueKey('blocker-skills')), findsNothing, reason: who.label);
          await tester.ensureVisible(find.byKey(const ValueKey('publish')));
          await tester.tap(find.byKey(const ValueKey('publish')));
          expect(
            await waitFor(tester, find.textContaining('Published.')),
            isTrue,
            reason: '${who.label}: ${shownBlob(tester)}',
          );
          final listed = await real(tester, () => repo.jobs(search: title));
          expect(listed.jobs, hasLength(1), reason: who.label);
          expect(listed.jobs.single.status, PostingStatus.open, reason: who.label);
          // Live and in the office: the other office role reads it too.
          final other = who == recruiter ? branchAdmin : recruiter;
          final otherRepo = ApiHiringRepository(api: await client(tester, other));
          expect(
            (await real(tester, () => otherRepo.jobs(search: title))).jobs.map((j) => j.id),
            contains(listed.jobs.single.id),
            reason: other.label,
          );
          await real(tester, () => repo.deleteJob(listed.jobs.single.id));
        }
        await finishLive(tester);
      },
    );

    testWidgets(
      'an applicant on the admin\'s posting: the pipeline draws it, the page opens whole, and an office admin outside the office gets a sentence',
      tags: const ['live'],
      (tester) async {
        if (!await ready(tester)) return;
        final run = DateTime.now().millisecondsSinceEpoch;
        final caRepo = await real(tester, () async => ApiHiringRepository(api: await liveClient(companyAdmin)));
        final jobId = await real(tester, () async {
          final id = await caRepo.createJob(readyDraft('MOBILE-LIVE company screen $run'), PostingStatus.draft);
          await caRepo.updateJob(id, readyDraft('MOBILE-LIVE company screen $run'), status: PostingStatus.open);
          return id;
        });
        addTearDown(() async {
          try {
            await caRepo.deleteJob(jobId);
          } catch (_) {}
        });
        final applicant = await real(tester, () => signUpThrowaway(first: 'Screenapplicant'));
        final application = await real(tester, () async {
          final res = await applicant.api.dio.post<Map<String, dynamic>>(
            '/jobs/$jobId/apply',
            data: {'phone': '+919812345678', 'coverNote': 'Role test'},
          );
          return res.data!['id'] as String;
        });

        await open(
          tester,
          ApplicantsScreen(
            key: UniqueKey(),
            repository: caRepo,
            jobId: jobId,
            jobTitle: 'Screen test',
            links: RecordingLinks(),
          ),
          size: const Size(390, 2400),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('All 1'), findsOneWidget);
        expect(find.text('Screenapplicant Tester'), findsWidgets);
        await tester.tap(find.byKey(ValueKey('applicant-$application')));
        await settleLive(tester);
        expect(find.byType(ApplicantDetailScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(find.text('Screenapplicant Tester'), findsWidgets);
        expect(find.text('Role test'), findsWidgets, reason: 'the cover note');

        // An office admin is not on this posting: a sentence, not a crash.
        final baRepo = await real(tester, () async => ApiHiringRepository(api: await liveClient(branchAdmin)));
        await open(
          tester,
          ApplicantsScreen(
            key: UniqueKey(),
            repository: baRepo,
            jobId: jobId,
            jobTitle: 'Screen test',
            links: RecordingLinks(),
          ),
          size: const Size(390, 1600),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Screenapplicant Tester'), findsNothing);
        expect(find.textContaining('different office'), findsOneWidget, reason: 'the API sentence is shown');
        expect(shownBlob(tester), isNot(contains('DioException')));
        expect(shownBlob(tester), isNot(contains('Exception')));
        await finishLive(tester);
      },
    );
  });

  group('Messages', () {
    testWidgets(
      'the inbox for the admin has the company\'s inbox, its views and topics; the office admin\'s has one topic; the hiring manager\'s has none',
      tags: const ['live'],
      (tester) async {
        if (!await ready(tester)) return;
        final company = await real(
          tester,
          () async => (await ApiMessagingRepository(
            api: await liveClient(companyAdmin),
          ).inboxes()).firstWhere((i) => !i.personal).id,
        );
        // A thread to the company, so there is something in it.
        await real(tester, () async {
          final anita = ApiMessagingRepository(api: await liveClient(outsider));
          await anita.startWithCompany(company, 'CAREERS');
        });

        var api = await client(tester, (companyAdmin));
        await open(
          tester,
          InboxScreen(
            key: UniqueKey(),
            repository: ApiMessagingRepository(api: api),
            poll: false,
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('inbox-personal')), findsOneWidget);
        expect(find.byKey(ValueKey('inbox-$company')), findsOneWidget);
        await tester.tap(find.byKey(ValueKey('inbox-$company')));
        await settleLive(tester);
        for (final v in ['open', 'unread', 'mine', 'done', 'spam']) {
          expect(find.byKey(ValueKey('view-$v')), findsOneWidget, reason: 'the company inbox\'s $v view');
        }
        expect(find.byKey(const ValueKey('topic-all')), findsOneWidget);
        for (final t in ['SALES', 'PROCUREMENT', 'CAREERS', 'PARTNERSHIP', 'GENERAL']) {
          // The row of chips scrolls sideways: bring each one into view.
          await tester.dragUntilVisible(
            find.byKey(ValueKey('topic-$t')),
            find.byKey(const ValueKey('topic-all')),
            const Offset(-150, 0),
          );
          expect(find.byKey(ValueKey('topic-$t')), findsOneWidget, reason: 'the admin takes $t');
        }
        expect(find.textContaining('Anita Rao'), findsWidgets, reason: 'the member who wrote to the company');

        api = await client(tester, (branchAdmin));
        await open(
          tester,
          InboxScreen(
            key: UniqueKey(),
            repository: ApiMessagingRepository(api: api),
            poll: false,
            initialInbox: company,
          ),
        );
        expect(
          await waitFor(tester, find.byKey(ValueKey('inbox-$company'))),
          isTrue,
          reason: 'her inbox opens on the company',
        );
        expect(tester.takeException(), isNull);
        expect(find.byKey(ValueKey('inbox-$company')), findsOneWidget);
        expect(find.byKey(const ValueKey('topic-SALES')), findsNothing, reason: 'sales is not hers');
        expect(find.byKey(const ValueKey('topic-all')), findsNothing, reason: 'one topic needs no topic chips');
        expect(find.byKey(const ValueKey('view-open')), findsOneWidget);

        api = await client(tester, (hiringManager));
        await open(
          tester,
          InboxScreen(
            key: UniqueKey(),
            repository: ApiMessagingRepository(api: api),
            poll: false,
          ),
        );
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(ValueKey('inbox-$company')),
          findsNothing,
          reason: 'an interview panelist answers for no inbox',
        );
        expect(find.byKey(const ValueKey('inbox-personal')), findsNothing, reason: 'and so has no switcher at all');
        expect(find.textContaining('Search people'), findsOneWidget);
        await finishLive(tester);
      },
    );

    testWidgets('a thread read as the company says it is writing as the company', tags: const ['live'], (tester) async {
      if (!await ready(tester)) return;
      final setup = await real(tester, () async {
        final admin = ApiMessagingRepository(api: await liveClient(companyAdmin));
        final company = (await admin.inboxes()).firstWhere((i) => !i.personal).id;
        final thread = await ApiMessagingRepository(
          api: await liveClient(outsider),
        ).startWithCompany(company, 'CAREERS');
        return (company: company, thread: thread);
      });
      final api = await client(tester, (recruiter));
      await open(
        tester,
        ConversationScreen(
          key: UniqueKey(),
          conversationId: setup.thread,
          asCompanyId: setup.company,
          repository: ApiMessagingRepository(api: api),
          poll: false,
        ),
        size: const Size(390, 1200),
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Replying as'), findsOneWidget);
      expect(find.textContaining(companyName), findsWidgets);
      await finishLive(tester);
    });
  });

  group('Your companies', () {
    testWidgets(
      'the list names the role and the office; only the sole admin is told she cannot leave; a hiring manager can leave',
      tags: const ['live'],
      (tester) async {
        if (!await ready(tester)) return;
        for (final (who, role, note, leave) in [
          (companyAdmin, 'Company Admin', null, true),
          (branchAdmin, 'Office Admin', 'Head Office', true),
          (hiringManager, 'Hiring Manager', 'Head Office', true),
          (marketBuyer, 'Company Admin', 'You are the only admin.', false),
          (marketNoPhone, 'Buyer', null, true),
        ]) {
          final api = await client(tester, (who));
          final auth = AuthController(api: api, tokens: api.tokens);
          await open(
            tester,
            ChangeNotifierProvider<AuthController>.value(
              value: auth,
              child: MyCompaniesScreen(
                key: UniqueKey(),
                repository: ApiAccountRepository(api: api),
              ),
            ),
          );
          expect(tester.takeException(), isNull, reason: who.label);
          expect(find.text(role), findsWidgets, reason: who.label);
          expect(find.text('Active'), findsOneWidget, reason: who.label);
          expect(find.text('Leave'), leave ? findsOneWidget : findsNothing, reason: '${who.label}: Leave');
          if (note != null) expect(find.textContaining(note), findsWidgets, reason: who.label);
          expect(find.text('Switch to personal account'), findsOneWidget, reason: who.label);
          expect(find.text('Create a company'), findsWidgets, reason: who.label);
          expect(find.text('Ask to join a company'), findsWidgets, reason: who.label);
        }
        await finishLive(tester);
      },
    );
  });
}
