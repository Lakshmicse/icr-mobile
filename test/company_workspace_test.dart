import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/account/account_models.dart' show PickedPhoto;
import 'package:icr_mobile/features/account/widgets/account_kit.dart' show AccountSelectField, CoverBand;
import 'package:icr_mobile/features/company/company_models.dart' show Completeness;
import 'package:icr_mobile/features/company/company_repository.dart';
import 'package:icr_mobile/features/company/company_workspace_screen.dart';
import 'package:icr_mobile/features/site/site_kit.dart' show SiteButton;

import 'helpers/fonts.dart';

/// The company workspace (the website's `/company`), native since 12 Nov 2026: the header, the overview's cards, the
/// Company Details sections edited in sheets that send only what changed, the verified lock, the company check, the
/// supplier level request, the certifications, and the notice for a member acting for no company.
void main() {
  setUpAll(() async {
    await loadAppFonts();
    CoverBand.loadArt = false;
  });

  final today = DateTime(2026, 11, 12, 10);
  late DemoCompanyRepository repo;

  Future<void> pump(
    WidgetTester tester, {
    DemoCompanyRepository? repository,
    String? tab,
    VoidCallback? onOpenTeam,
    void Function(String id)? onOpenCompanyPage,
  }) async {
    tester.view.physicalSize = const Size(400, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repo = repository ?? DemoCompanyRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: CompanyWorkspaceScreen(
          onBack: () {},
          tab: tab,
          repository: repo,
          onOpenTeam: onOpenTeam,
          onOpenCompanyPage: onOpenCompanyPage,
          now: today,
          pickDocument: () async =>
              const PickedPhoto(bytes: [1, 2, 3, 4], name: 'Insurance 2027.pdf', mimeType: 'application/pdf'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  group('the header and the overview', () {
    testWidgets("names the company, its facts and its trust mark, with the owner's wording", (tester) async {
      String? opened;
      await pump(tester, onOpenCompanyPage: (id) => opened = id);
      expect(find.text('My Company'), findsOneWidget, reason: 'the bar');
      expect(find.text('COMPANY PROFILE'), findsOneWidget);
      expect(find.text('Acme Facility Services'), findsWidgets);
      expect(
        find.text('Facility management services · 51–200 employees · Bengaluru · acme-fm.example'),
        findsOneWidget,
      );
      expect(find.text('Changes are visible to all company members.'), findsOneWidget);
      expect(find.text('Switch Company'), findsOneWidget, reason: 'the person belongs to two companies');
      await tapKey(tester, 'company-view-public');
      expect(opened, DemoCompanyRepository.sampleCompanyId);
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Company Details'), findsOneWidget);
      expect(find.text('Certifications'), findsWidgets);
      expect(find.byType(Card), findsNothing, reason: 'hairlines, never boxes');
    });

    testWidgets('the completeness card lists what is missing, and Add opens where it is filled', (tester) async {
      await pump(tester);
      expect(find.text('Company Profile Completeness'), findsOneWidget);
      expect(find.text('85% Complete'), findsOneWidget);
      expect(find.text('Add the year of establishment'), findsOneWidget);
      expect(find.text('Pin the head office on the map'), findsOneWidget);
      await tapKey(tester, 'completeness-edit');
      expect(find.byKey(const ValueKey('identity-details')), findsOneWidget, reason: 'Edit Company Profile');
    });

    testWidgets('a complete company page has no completeness card; the trust card leads', (tester) async {
      await pump(
        tester,
        repository: DemoCompanyRepository(completeness: const Completeness(score: 100, missing: [])),
      );
      expect(find.byKey(const ValueKey('completeness-card')), findsNothing);
      expect(find.text('Company Profile Completeness'), findsNothing);
      expect(find.text('100% Complete'), findsNothing);
      expect(find.byKey(const ValueKey('trust-card')), findsOneWidget);
    });

    testWidgets('the trust card gives the company check and the supplier level apart', (tester) async {
      await pump(tester);
      expect(find.text('Trust & Verification'), findsOneWidget);
      expect(find.text('Your Company’s Verification Status'), findsOneWidget);
      expect(find.text('Company Verification'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('trust-check-sentence')),
          matching: find.textContaining(
            'Your company is verified and eligible to publish jobs on ICR.',
            findRichText: true,
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Supplier Trust Level'), findsOneWidget);
      expect(find.text('Verified – Level 2'), findsOneWidget);
      expect(find.text('Upgrade Trust Level'), findsOneWidget);
      await tapKey(tester, 'trust-raise-level');
      expect(find.byKey(const ValueKey('supplier-level-card')), findsOneWidget, reason: 'opens Certifications');
    });

    testWidgets('the overview panel, the plans and the public profile', (tester) async {
      await pump(tester);
      expect(find.text('Company Overview'), findsOneWidget);
      for (final label in [
        'Members',
        'Office Locations',
        'Active Job Listings',
        'Products Listed',
        'Services Listed',
        'Certifications Uploaded',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(
        find.descendant(of: find.byKey(const ValueKey('figure-members')), matching: find.text('6')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(const ValueKey('figure-open-jobs')), matching: find.text('3')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(const ValueKey('figure-certificates')), matching: find.text('1')),
        findsOneWidget,
        reason: 'ISO 9001 is held; ISO 14001 has no certificate',
      );
      expect(find.text('Membership & Subscriptions'), findsOneWidget);
      expect(find.text('Job Portal Plan'), findsOneWidget);
      expect(find.text('Talent'), findsOneWidget);
      expect(find.text('Marketplace Plan'), findsOneWidget);
      expect(find.text('Business'), findsOneWidget);
      expect(find.text('View Plans & Payment History'), findsOneWidget);
      expect(find.text('Company Public Profile'), findsOneWidget);
      expect(find.textContaining('/companies/${DemoCompanyRepository.sampleCompanyId}'), findsOneWidget);
      expect(find.text('Copy Profile Link'), findsOneWidget);
    });
  });

  group('Company Details', () {
    testWidgets('a section is read-only; its sheet saves only the field that changed', (tester) async {
      await pump(tester, tab: 'identity');
      expect(find.text('Company Contact Details'), findsOneWidget);
      expect(find.text('Head of Operations'), findsOneWidget);
      await tapKey(tester, 'identity-edit-contact');
      await tester.enterText(find.byKey(const ValueKey('field-contactDesignation')), 'Head of Procurement');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sheet.save')));
      await tester.pumpAndSettle();
      expect(repo.sent.where((s) => s['call'] == 'updateCompany').toList(), [
        {
          'call': 'updateCompany',
          'patch': {'contactDesignation': 'Head of Procurement'},
        },
      ]);
      expect(find.text('Saved.'), findsOneWidget);
      expect(find.text('Head of Procurement'), findsOneWidget, reason: 'the row reads what was saved');
    });

    testWidgets('a sheet with nothing changed sends nothing', (tester) async {
      await pump(tester, tab: 'identity');
      await tapKey(tester, 'identity-edit-details');
      await tester.tap(find.byKey(const Key('sheet.save')));
      await tester.pumpAndSettle();
      expect(repo.sent, isEmpty);
    });

    testWidgets("a verified company's locked fields are disabled with the sentence the API refuses with", (
      tester,
    ) async {
      await pump(tester, tab: 'identity');
      expect(find.byKey(const ValueKey('identity-tax-ids-locked')), findsOneWidget);
      await tapKey(tester, 'identity-edit-registration');
      expect(tester.widget<TextField>(find.byKey(const ValueKey('field-panNumber'))).enabled, isFalse);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('field-gstNumber'))).enabled, isFalse);
      expect(
        find.text('PAN and GSTIN cannot be edited after verification. Contact ICR Support for changes.'),
        findsWidgets,
      );
      expect(tester.widget<TextField>(find.byKey(const ValueKey('field-legalName'))).enabled, isFalse);
      expect(
        find.text('The registered name is locked once your company is verified. Contact support to change it.'),
        findsOneWidget,
      );
      expect(tester.widget<AccountSelectField>(find.byKey(const ValueKey('field-legalStructure'))).onTap, isNull);
      expect(
        find.text('The organisation type is locked once your company is verified. Contact support to change it.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('doc-panDoc-upload')), findsNothing, reason: 'the PAN card is locked too');
    });

    testWidgets("an unverified company's PAN is checked as the API checks it, before anything is sent", (tester) async {
      await pump(tester, tab: 'identity', repository: DemoCompanyRepository(checkStatus: null));
      await tapKey(tester, 'identity-edit-registration');
      expect(tester.widget<TextField>(find.byKey(const ValueKey('field-panNumber'))).enabled, isTrue);
      await tester.enterText(find.byKey(const ValueKey('field-panNumber')), 'ABCDE');
      await tester.tap(find.byKey(const Key('sheet.save')));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid PAN (e.g. AAAPZ1234C).'), findsOneWidget);
      expect(repo.sent, isEmpty);
    });
  });

  group('the company check', () {
    testWidgets('a verified company reads where it stands, with the way to support', (tester) async {
      await pump(tester, tab: 'verification');
      expect(find.byKey(const ValueKey('company-check')), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const ValueKey('company-check-status')), matching: find.text('Verified')),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Verified on 6 Oct 2026. Your company can publish jobs and connect with candidates on ICR.',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(find.text('Need help with verification?'), findsOneWidget);
      expect(find.text('Contact ICR Support'), findsOneWidget);
      expect(find.byKey(const ValueKey('company-check-submit')), findsNothing, reason: 'nothing to file once verified');
    });

    testWidgets('a company that never filed sees the checklist and files the dossier from its profile', (tester) async {
      await pump(tester, tab: 'verification', repository: DemoCompanyRepository(checkStatus: null));
      expect(
        find.descendant(of: find.byKey(const ValueKey('company-check-status')), matching: find.text('Ready to Submit')),
        findsOneWidget,
      );
      expect(find.text('10 of 10 ready'), findsOneWidget);
      await tapKey(tester, 'company-check-submit');
      final filed = repo.sent.singleWhere((s) => s['call'] == 'submitCheck')['dossier']! as Map<String, Object?>;
      expect(filed['legalName'], 'Acme Facility Services Private Limited');
      expect(filed['panNumber'], 'AAACZ1234C');
      expect(filed['gstNumber'], '27AAACZ1234C1ZR');
      expect(filed['contactEmail'], 'ops@acme-fm.example');
      expect(
        [for (final d in filed['documents']! as List) (d as Map)['kind']],
        ['PAN_CARD', 'GST_CERTIFICATE', 'INCORPORATION_PROOF'],
      );
      expect(
        find.descendant(of: find.byKey(const ValueKey('company-check-status')), matching: find.text('Under Review')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('company-check-filed')), findsOneWidget);
      expect(find.byKey(const ValueKey('company-check-submit')), findsNothing, reason: 'ICR is reviewing it');
    });

    testWidgets('what the check still needs is listed, each opening its section, and the button waits', (tester) async {
      await pump(
        tester,
        tab: 'verification',
        repository: DemoCompanyRepository(
          checkStatus: null,
          company: DemoCompanyRepository.sampleCompany(
            verified: false,
          ).merged({'addressLine': null, 'gstDocUrl': null}),
        ),
      );
      expect(find.text('8 of 10 ready'), findsOneWidget);
      expect(find.text('Complete 2 more items to submit.'), findsOneWidget);
      expect(tester.widget<SiteButton>(find.byKey(const ValueKey('company-check-submit'))).onPressed, isNull);
      await tapKey(tester, 'company-check-add-addressLine');
      expect(find.text('Business Location & Coverage'), findsWidgets, reason: 'the location sheet is open');
      expect(find.byKey(const ValueKey('field-addressLine')), findsOneWidget);
    });
  });

  group('Certifications', () {
    testWidgets('the supplier level: the checklist the reviewer reads, and a request with its evidence', (
      tester,
    ) async {
      await pump(tester, tab: 'certifications');
      expect(find.text('Supplier Trust Levels'), findsOneWidget);
      expect(find.text('Your Verification Status'), findsOneWidget);
      expect(find.text('ICR Verified Supplier'), findsOneWidget);
      expect(find.text('Certified Level Requirements'), findsOneWidget);
      expect(find.text('7 of 8 completed'), findsOneWidget);
      expect(find.text('Business Experience'), findsOneWidget);
      expect(find.text('Completed'), findsWidgets);
      expect(
        find.descendant(of: find.byKey(const ValueKey('checklist-insurance')), matching: find.text('Under Review')),
        findsOneWidget,
        reason: 'the insurance policy uploaded earlier awaits review',
      );
      await tapKey(tester, 'level-request');
      expect(find.text('Apply for Certified Status'), findsWidgets);
      await tapKey(tester, 'evidence-upload');
      expect(find.text('Insurance 2027.pdf'), findsOneWidget);
      await tester.tap(find.byKey(const Key('sheet.save')));
      await tester.pumpAndSettle();
      final request = repo.sent.singleWhere((s) => s['call'] == 'requestLevel');
      expect(request['vendorId'], DemoCompanyRepository.sampleVendorId);
      expect((request['request']! as Map)['level'], 'CERTIFIED');
      expect(find.text('Upgrade to Certified is under review'), findsOneWidget);
    });

    testWidgets('a missing profile item says Pending and Add Details opens the company details', (tester) async {
      await pump(
        tester,
        tab: 'certifications',
        repository: DemoCompanyRepository(company: DemoCompanyRepository.sampleCompany().merged({'website': null})),
      );
      expect(
        find.descendant(of: find.byKey(const ValueKey('checklist-website')), matching: find.text('Pending')),
        findsOneWidget,
      );
      await tapKey(tester, 'checklist-fix-website');
      expect(find.byKey(const ValueKey('identity-details')), findsOneWidget);
    });

    testWidgets('the renewals and the certifications held, pending upload and recorded', (tester) async {
      await pump(tester, tab: 'certifications');
      expect(find.text('Certificates & Renewals'), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const ValueKey('renewal-cert-1')), matching: find.text('139d left')),
        findsOneWidget,
      );
      expect(find.text('Company Certifications'), findsOneWidget);
      expect(find.text('ISO 9001 · exp 31 Mar 2027'), findsOneWidget);
      expect(find.text('CERTIFICATES PENDING UPLOAD'), findsOneWidget);
      expect(find.text('ISO 14001: Upload Certificate'), findsOneWidget);
      await tapKey(tester, 'add-certification');
      expect(find.text('Add Certification'), findsWidgets);
      await tapKey(tester, 'certification-type');
      await tester.tap(find.text('MSME / Udyam Registration').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byKey(const ValueKey('certification-issuer'))).controller!.text,
        'Ministry of Micro, Small and Medium Enterprises (Udyam)',
        reason: 'the one body ICR knows is filled in',
      );
      await tapKey(tester, 'certificate-upload');
      await tester.tap(find.byKey(const Key('sheet.save')));
      await tester.pumpAndSettle();
      final recorded = repo.sent.singleWhere((s) => s['call'] == 'recordCertification')['draft']! as Map;
      expect(recorded['certificationTypeId'], 'type-msme');
      expect((recorded['documentUrls']! as List).length, 1);
      expect(find.text('Certification recorded.'), findsOneWidget);
    });

    testWidgets('a company that does not sell is told certifications come with the listing', (tester) async {
      await pump(tester, tab: 'certifications', repository: DemoCompanyRepository(sells: false));
      expect(find.text('Your Company Has No Supplier Listing Yet'), findsOneWidget);
      await tapKey(tester, 'listing-start-selling');
      expect(repo.sent.single, {'call': 'startSelling', 'companyId': DemoCompanyRepository.sampleCompanyId});
      expect(find.byKey(const ValueKey('supplier-level-card')), findsOneWidget, reason: 'it sells now');
    });
  });

  group('who sees what', () {
    testWidgets('acting for no company, with none to switch to: the way to create one', (tester) async {
      await pump(tester, repository: DemoCompanyRepository(noCompany: true, role: 'PROFESSIONAL', companiesHeld: 0));
      expect(find.byKey(const ValueKey('no-company')), findsOneWidget);
      expect(find.text('Your Account Isn’t Linked to a Company'), findsOneWidget);
      expect(find.text('Create a Company'), findsOneWidget);
      expect(find.text('Contact Support'), findsOneWidget);
      expect(find.text('Company Overview'), findsNothing);
    });

    testWidgets('acting as themselves while belonging to companies: the switch', (tester) async {
      await pump(tester, repository: DemoCompanyRepository(noCompany: true, role: 'PROFESSIONAL', companiesHeld: 2));
      expect(find.text('You Are Using Your Personal Account'), findsOneWidget);
      expect(find.byKey(const ValueKey('no-company-switch')), findsOneWidget);
    });

    testWidgets('a role that does not edit the company profile is told so', (tester) async {
      await pump(tester, repository: DemoCompanyRepository(role: 'RECRUITER'));
      expect(find.byKey(const ValueKey('not-an-editor')), findsOneWidget);
      expect(find.text('Your Role Does Not Edit the Company Profile'), findsOneWidget);
    });

    testWidgets('the Team tab opens the team page the lead wired', (tester) async {
      var opened = 0;
      await pump(tester, onOpenTeam: () => opened++);
      await tester.tap(find.text('Team'));
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(find.byKey(const ValueKey('completeness-card')), findsOneWidget, reason: 'the page stays where it was');
    });

    testWidgets('a profile that cannot be read says so and can be tried again', (tester) async {
      await pump(tester, repository: DemoCompanyRepository(failProfile: true));
      expect(find.byKey(const ValueKey('company-error')), findsOneWidget);
      expect(find.text('Could not load your company.'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });
  });
}
