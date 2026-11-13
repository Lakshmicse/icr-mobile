import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/talent/talent_labels.dart';
import 'package:icr_mobile/features/talent/talent_models.dart';
import 'package:icr_mobile/features/talent/talent_repository.dart';
import 'package:icr_mobile/features/talent/talent_screen.dart';

import 'helpers/fonts.dart';

/// The employer's talent search (the website's `/talent`, 'Source Candidates'), against the sample pool: the
/// search and its filters, a candidate's quick view with the team's notes and tags, saved searches, the paywall's
/// and the API's refusals in their own words, and what a member with no hiring team is told.
/// The sheets' own lists: a text field carries a `Scrollable` of its own, so `find.byType(Scrollable).last`
/// would drag a field instead of the sheet.
Finder inFilters() =>
    find.descendant(of: find.byKey(const ValueKey('filters-list')), matching: find.byType(Scrollable)).first;
Finder inQuickView() =>
    find.descendant(of: find.byKey(const ValueKey('qv-list')), matching: find.byType(Scrollable)).first;

void main() {
  setUpAll(loadAppFonts);

  late DemoTalentRepository repo;
  final opened = <String>[];

  Future<void> pump(WidgetTester tester, {DemoTalentRepository? repository}) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    opened.clear();
    repo = repository ?? DemoTalentRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: TalentScreen(onBack: () {}, repository: repo, onOpenMember: opened.add),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openFilters(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('talent-filters-chip')));
    await tester.pumpAndSettle();
    expect(find.text('Filters'), findsWidgets);
  }

  Future<void> applyFilters(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('filters-apply')));
    await tester.pumpAndSettle();
  }

  Future<void> openQuickView(WidgetTester tester, String userId) async {
    await tester.tap(find.byKey(ValueKey('candidate-$userId')));
    await tester.pumpAndSettle();
  }

  group('search', () {
    testWidgets("lists the pool as the website's cards, in rows: name, headline, skills and the facts", (tester) async {
      await pump(tester);
      expect(find.text('Source Candidates'), findsOneWidget);
      expect(find.text('6 candidates'), findsOneWidget);
      expect(find.text('Priya Sharma'), findsOneWidget);
      expect(find.text('Senior Facility Manager · Integrated FM'), findsOneWidget);
      expect(find.text('Featured'), findsOneWidget, reason: "the candidate's plan makes them featured");
      expect(find.text('Ready for Next Role'), findsNWidgets(2));
      expect(find.byKey(const ValueKey('ring-cand-priya')), findsOneWidget, reason: 'told to everyone: the ring');
      expect(find.byKey(const ValueKey('ring-cand-rohan')), findsNothing, reason: 'told to recruiters only');
      expect(find.text('+1'), findsNWidgets(2), reason: 'five skills shown, the rest counted');
      expect(find.text('9 yrs · Mumbai · JLL · Expects ₹18,00,000 a year · 30d notice'), findsOneWidget);
      expect(find.text('7 yrs · Hyderabad · Sodexo · Serving notice · free 15 Dec 2026'), findsOneWidget);
      expect(find.text('3 yrs · Pune · Knight Frank · Immediate'), findsOneWidget);
      expect(find.byType(Card), findsNothing, reason: 'rows the whole width, hairlines between');
    });

    testWidgets('the search box narrows the list to the words typed, and the chip takes them off again', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(
        find.descendant(of: find.byKey(const ValueKey('talent-search')), matching: find.byType(TextField)),
        'lease',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('1 candidate'), findsOneWidget);
      expect(find.text('Arjun Mehta'), findsOneWidget);
      expect(find.text('Priya Sharma'), findsNothing);
      expect(find.byKey(const ValueKey('chip-q')), findsOneWidget);
      expect(find.text('“lease”'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('chip-q')));
      await tester.pumpAndSettle();
      expect(find.text('6 candidates'), findsOneWidget);
    });

    testWidgets('typing is applied after the debounce, without the search key', (tester) async {
      await pump(tester);
      await tester.enterText(
        find.descendant(of: find.byKey(const ValueKey('talent-search')), matching: find.byType(TextField)),
        'HVAC',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('2 candidates'), findsOneWidget, reason: 'Priya and Kavya list HVAC');
    });

    testWidgets('the sort sheet reorders the list', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('talent-sort-chip')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Most Experienced'));
      await tester.pumpAndSettle();
      final first = tester.getTopLeft(find.text('Sanjay Iyer')).dy;
      final second = tester.getTopLeft(find.text('Priya Sharma')).dy;
      expect(first, lessThan(second), reason: '12 years before 9');
      expect(find.text('Most Experienced'), findsOneWidget, reason: 'the chip names the order');
    });

    testWidgets('nothing matching says so in the website\'s words', (tester) async {
      await pump(tester);
      await tester.enterText(
        find.descendant(of: find.byKey(const ValueKey('talent-search')), matching: find.byType(TextField)),
        'zzzz',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('talent-empty')), findsOneWidget);
      expect(find.text('Try removing a filter or widening the notice-period range.'), findsOneWidget);
    });
  });

  group('filters', () {
    testWidgets("the Filters sheet narrows the list and the active chips say how, in the website's words", (
      tester,
    ) async {
      await pump(tester);
      await openFilters(tester);
      expect(find.text('ROLE & SKILLS'), findsOneWidget);
      expect(find.text('Matches their headline or desired roles.'), findsOneWidget);
      await tester.scrollUntilVisible(find.byKey(const ValueKey('notice-30')), 300, scrollable: inFilters());
      await tester.tap(find.byKey(const ValueKey('notice-30')));
      await tester.pump();
      await applyFilters(tester);

      expect(find.text('3 candidates'), findsOneWidget, reason: 'Priya 30, Rohan 0, Kavya 30; Meera has none');
      expect(find.text('Filters (1)'), findsOneWidget);
      expect(find.byKey(const ValueKey('chip-notice')), findsOneWidget);
      expect(find.text('≤ 30d notice'), findsOneWidget);
      expect(find.text('Arjun Mehta'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('chip-notice')));
      await tester.pumpAndSettle();
      expect(find.text('6 candidates'), findsOneWidget);
      expect(find.text('Filters'), findsOneWidget);
    });

    testWidgets('text facets, a work mode and a tick combine; Clear all in the sheet resets everything', (
      tester,
    ) async {
      await pump(tester);
      await openFilters(tester);
      await tester.enterText(
        find.descendant(of: find.byKey(const ValueKey('filter-skills')), matching: find.byType(TextField)),
        'Vendor Management, Yardi',
      );
      await tester.scrollUntilVisible(find.byKey(const ValueKey('wm-HYBRID')), 300, scrollable: inFilters());
      await tester.tap(find.byKey(const ValueKey('wm-HYBRID')));
      await tester.pump();
      await applyFilters(tester);
      expect(find.text('1 candidate'), findsOneWidget, reason: 'Priya alone holds one of the skills and wants hybrid');
      expect(find.text('Vendor Management'), findsWidgets);
      expect(find.text('Yardi'), findsWidgets);
      expect(find.text('Hybrid'), findsOneWidget);
      expect(find.text('Filters (2)'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('talent-clear-all')));
      await tester.pumpAndSettle();
      expect(find.text('6 candidates'), findsOneWidget);
      expect(find.byKey(const ValueKey('talent-clear-all')), findsNothing);
    });

    testWidgets('the website\'s chip words for the other facets', (tester) async {
      const masters = TalentMasters();
      final chips = const TalentFilters(
        titles: ['Facility Manager'],
        currentCompany: 'CBRE',
        seniority: 'SENIOR',
        minYears: 8,
        maxYears: 15,
        noticePeriodMaxDays: 0,
        expectedSalaryMax: 1500000,
        employmentTypes: ['FREELANCE'],
        industries: ['FM_SERVICES'],
        functions: ['HARD_SERVICES'],
        shift: 'NIGHT',
        willingToRelocate: true,
        nextRole: true,
        updatedWithinDays: 30,
        hideViewed: true,
        hidePastApplicants: true,
      ).chips(masters).map((c) => c.label).toList();
      expect(chips, [
        'Facility Manager',
        'at CBRE',
        'Senior',
        '8+ yrs',
        '≤ 15 yrs',
        'Immediate Joiners',
        '≤ ₹15.0L expected',
        'Open to Relocating',
        'Freelance / Consultant',
        'Facility management services',
        'Hard services / engineering',
        'Night Shift',
        'Updated ≤ 30d',
        'Ready for Next Role',
        'Hiding Viewed',
        'Hiding Past Applicants',
      ]);
      final query = const TalentFilters(skills: ['FM', 'Lease admin'], hideViewed: true).toQuery(page: 2, limit: 12);
      expect(query, {'page': 2, 'limit': 12, 'skills': 'FM,Lease admin', 'hideViewed': true, 'sort': 'recent'});
    });
  });

  group('quick view', () {
    testWidgets('opens on a candidate with what they want, the contact behind the paywall, an invitation, a message', (
      tester,
    ) async {
      await pump(tester);
      await openQuickView(tester, 'cand-priya');
      expect(find.byKey(const ValueKey('qv-facts')), findsOneWidget);
      expect(find.text('9 yrs experience · Mumbai · at JLL · Expects ₹18,00,000 a year · 30d notice'), findsOneWidget);
      expect(find.text('WHAT THEY WANT'), findsOneWidget);
      expect(find.text('Open to Relocating'), findsOneWidget);
      expect(find.text('Corporate occupier'), findsOneWidget);
      expect(find.text('SUMMARY'), findsOneWidget);

      // Contact: revealed through the paywall.
      await tester.tap(find.byKey(const ValueKey('qv-reveal')));
      await tester.pumpAndSettle();
      expect(find.text('priya.sharma@example.com'), findsOneWidget);
      expect(repo.sent, contains(equals({'op': 'contact', 'id': 'cand-priya'})));

      // Invite to apply: pick one of the company's jobs.
      await tester.scrollUntilVisible(find.byKey(const ValueKey('qv-invite')), 200, scrollable: inQuickView());
      await tester.tap(find.byKey(const ValueKey('qv-invite-job')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lease Administrator').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('qv-invite')));
      await tester.pumpAndSettle();
      expect(repo.sent, contains(equals({'op': 'invite', 'jobId': 'job-2', 'candidateId': 'cand-priya'})));
      expect(find.text('Invitation sent.'), findsOneWidget);

      // Message.
      await tester.scrollUntilVisible(find.byKey(const ValueKey('qv-send')), 200, scrollable: inQuickView());
      await tester.enterText(find.byKey(const ValueKey('qv-message')), 'Hi Priya, we have a role in Mumbai.');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('qv-send')));
      await tester.pumpAndSettle();
      expect(repo.sent.last, {
        'op': 'message',
        'id': 'cand-priya',
        'message': 'Hi Priya, we have a role in Mumbai.',
        'jobTitle': 'Lease Administrator',
      });
    });

    testWidgets('saves a tag and a private note for the team, and removes the tag', (tester) async {
      await pump(tester);
      await openQuickView(tester, 'cand-arjun');
      await tester.scrollUntilVisible(find.byKey(const ValueKey('qv-note-save')), 200, scrollable: inQuickView());
      expect(find.text('No tags yet.'), findsOneWidget);
      expect(find.text('No notes yet.'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('qv-tag-input')), 'Strong FM background');
      await tester.tap(find.byKey(const ValueKey('qv-tag-add')));
      await tester.pumpAndSettle();
      expect(repo.sent, contains(equals({'op': 'tag.add', 'id': 'cand-arjun', 'label': 'Strong FM background'})));
      expect(find.byKey(const ValueKey('tag-Strong FM background')), findsOneWidget);
      expect(find.text('No tags yet.'), findsNothing);

      await tester.enterText(find.byKey(const ValueKey('qv-note-input')), 'Spoke on Tuesday; keen on Bengaluru roles.');
      await tester.tap(find.byKey(const ValueKey('qv-note-save')));
      await tester.pumpAndSettle();
      expect(repo.sent.last, {
        'op': 'note.add',
        'id': 'cand-arjun',
        'body': 'Spoke on Tuesday; keen on Bengaluru roles.',
      });
      expect(find.text('Spoke on Tuesday; keen on Bengaluru roles.'), findsOneWidget);
      expect(find.textContaining('Chetan CompanyAdmin · '), findsOneWidget, reason: 'who wrote it, and when');
      expect(find.text('No notes yet.'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('tag-remove-Strong FM background')));
      await tester.pumpAndSettle();
      expect(repo.sent.last, {'op': 'tag.remove', 'id': 'cand-arjun', 'label': 'Strong FM background'});
      expect(find.text('No tags yet.'), findsOneWidget);
    });

    testWidgets("the name opens the member's profile when it is public", (tester) async {
      await pump(tester);
      await openQuickView(tester, 'cand-priya');
      await tester.tap(find.byKey(const ValueKey('qv-name')));
      await tester.pumpAndSettle();
      expect(opened, ['cand-priya']);

      await tester.tap(find.byKey(const ValueKey('qv-close')));
      await tester.pumpAndSettle();
      await openQuickView(tester, 'cand-rohan');
      expect(find.byKey(const ValueKey('qv-view-profile')), findsNothing, reason: 'a private profile has no link');
    });
  });

  group('saved searches', () {
    testWidgets('a search is saved under a name, shown as a chip, and reopened with its filters', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('talent-save-search')));
      await tester.pumpAndSettle();
      expect(find.text('Set at least one filter first.'), findsOneWidget, reason: 'nothing to save yet');

      await openFilters(tester);
      await tester.scrollUntilVisible(find.byKey(const ValueKey('notice-30')), 300, scrollable: inFilters());
      await tester.tap(find.byKey(const ValueKey('notice-30')));
      await tester.pump();
      await applyFilters(tester);
      expect(find.text('3 candidates'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('talent-save-search')));
      await tester.pumpAndSettle();
      expect(find.text('Save This Search'), findsOneWidget);
      expect(find.text('Alerts are checked once a day.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('save-search-name')), 'Quick joiners');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('save-search-submit')));
      await tester.pumpAndSettle();
      expect(repo.sent.last, {
        'op': 'search.save',
        'name': 'Quick joiners',
        'criteria': {'noticePeriodMaxDays': 30, 'sort': 'recent'},
        'alertsEnabled': true,
      });
      expect(find.byKey(const ValueKey('saved-search-1')), findsOneWidget);
      expect(find.text('Quick joiners'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('talent-clear-all')));
      await tester.pumpAndSettle();
      expect(find.text('6 candidates'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('saved-search-1')));
      await tester.pumpAndSettle();
      expect(find.text('3 candidates'), findsOneWidget, reason: 'reopened with its criteria');
      expect(find.text('≤ 30d notice'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('saved-menu-search-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('saved-menu-alerts')));
      await tester.pumpAndSettle();
      expect(repo.sent.last, {'op': 'search.update', 'id': 'search-1', 'alertsEnabled': false});

      await tester.tap(find.byKey(const ValueKey('saved-menu-search-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('saved-menu-delete')));
      await tester.pumpAndSettle();
      expect(repo.sent.last, {'op': 'search.delete', 'id': 'search-1'});
      expect(find.byKey(const ValueKey('saved-search-1')), findsNothing);
    });

    testWidgets('a saved search the API already holds is listed with its new matches', (tester) async {
      await pump(
        tester,
        repository: DemoTalentRepository(
          saved: [
            const SavedSearch(
              id: 'search-9',
              name: 'Mumbai FM leads',
              criteria: TalentFilters(locations: ['Mumbai']),
              alertsEnabled: true,
              newMatchCount: 3,
            ),
          ],
        ),
      );
      expect(find.text('Mumbai FM leads'), findsOneWidget);
      expect(find.text('3'), findsOneWidget, reason: 'new to you');
      await tester.tap(find.byKey(const ValueKey('saved-search-9')));
      await tester.pumpAndSettle();
      expect(find.text('1 candidate'), findsOneWidget);
      expect(find.text('Priya Sharma'), findsOneWidget);
    });
  });

  group('describe who you want', () {
    testWidgets('a brief becomes filters, said back as the website says it', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('talent-describe-chip')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('describe-title')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('describe-example-0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('talent-parse-line')), findsOneWidget);
      expect(
        find.text(
          'Read as experience, notice period, seniority, location, keywords. Matched locally without AI. Adjust '
          'anything in the filters.',
        ),
        findsOneWidget,
      );
      expect(find.text('8+ yrs'), findsOneWidget);
      expect(find.text('≤ 30d notice'), findsOneWidget);
      expect(find.text('Mumbai'), findsWidgets);
      expect(find.text('Senior'), findsOneWidget);
      expect(find.text('1 candidate'), findsOneWidget, reason: 'Priya: senior, Mumbai, 9 years, 30 days');
    });

    testWidgets('a brief nothing can be read from says so and changes nothing', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('talent-describe-chip')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('describe-input')), '???');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('describe-apply')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('describe-error')), findsOneWidget);
      expect(find.text('Unable to read that as filters. Try naming a role, city or experience level.'), findsOneWidget);
    });
  });

  group('match to a job', () {
    testWidgets('ranks the pool against one of the company\'s jobs with a match chip each', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('mode-match')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('match-pick')), findsOneWidget);
      expect(find.text('Select one of your jobs to rank matching candidates.'), findsOneWidget);
      expect(find.byKey(const ValueKey('talent-sort-chip')), findsNothing, reason: 'a match has its own order');

      await tester.tap(find.byKey(const ValueKey('match-job-chip')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Senior Facility Manager — Mumbai').last);
      await tester.pumpAndSettle();
      expect(find.textContaining("Showing candidates who meet this job's experience"), findsOneWidget);
      expect(find.text('3 candidates'), findsOneWidget, reason: 'Priya, Meera and Kavya hold a required skill');
      expect(find.text('100% Match'), findsOneWidget);
      expect(find.text('20% Match'), findsNWidgets(2));
      expect(find.text('Arjun Mehta'), findsNothing);
    });
  });

  group('the gate', () {
    testWidgets("the API's refusal of a search is shown in its own words, with Try again", (tester) async {
      await pump(tester, repository: DemoTalentRepository(refuseSearch: 'Boolean search comes with Silver.'));
      expect(find.byKey(const ValueKey('talent-error')), findsOneWidget);
      expect(find.text('Boolean search comes with Silver.'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets("an unverified company's search is capped as the API caps it, and contact and messages are locked", (
      tester,
    ) async {
      await pump(
        tester,
        repository: DemoTalentRepository(
          access_: const TalentAccess(
            tier: 'FREE',
            verified: false,
            canRevealContact: false,
            canMessage: false,
            resultCap: 2,
          ),
        ),
      );
      expect(find.text('2 candidates'), findsOneWidget, reason: 'the reachable total, never the real one');
      expect(find.byKey(const ValueKey('candidate-cand-meera')), findsNothing);

      await openQuickView(tester, 'cand-priya');
      expect(find.byKey(const ValueKey('qv-locked-contact')), findsOneWidget);
      expect(find.text('Verify your company to reveal candidate contact details.'), findsOneWidget);
      expect(find.byKey(const ValueKey('qv-reveal')), findsNothing);
      await tester.scrollUntilVisible(find.byKey(const ValueKey('qv-locked-message')), 200, scrollable: inQuickView());
      expect(find.text('Verify your company to message candidates.'), findsOneWidget);
      expect(find.text('Verify Company'), findsNWidgets(2));
      expect(find.byKey(const ValueKey('qv-send')), findsNothing);
    });

    testWidgets('a verified company on a plan without contact is told to subscribe, or to ask its admin', (
      tester,
    ) async {
      await pump(
        tester,
        repository: DemoTalentRepository(
          viewer_: const TalentViewer(role: 'RECRUITER', companyId: 'company-1'),
          access_: const TalentAccess(tier: 'FREE', canRevealContact: false, canMessage: false),
        ),
      );
      await openQuickView(tester, 'cand-priya');
      expect(
        find.text("Your company's plan doesn't include candidate contact details. Ask your company admin to upgrade."),
        findsOneWidget,
        reason: 'a recruiter cannot buy the Corporate plan',
      );
      expect(find.text('View Plans'), findsWidgets);
    });

    testWidgets("an invitation the API refuses is shown in the API's words", (tester) async {
      await pump(
        tester,
        repository: DemoTalentRepository(
          access_: const TalentAccess(verified: false, canRevealContact: false, canMessage: false, resultCap: 20),
        ),
      );
      await openQuickView(tester, 'cand-priya');
      await tester.scrollUntilVisible(find.byKey(const ValueKey('qv-invite')), 200, scrollable: inQuickView());
      await tester.tap(find.byKey(const ValueKey('qv-invite-job')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lease Administrator').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('qv-invite')));
      await tester.pumpAndSettle();
      expect(find.text('Verify your company to invite candidates to apply.'), findsOneWidget);
      expect(repo.sent.where((s) => s['op'] == 'invite'), isEmpty);
    });
  });

  group('who may source', () {
    testWidgets('a member acting as themselves with companies is told to switch', (tester) async {
      await pump(
        tester,
        repository: DemoTalentRepository(viewer_: const TalentViewer(role: 'PROFESSIONAL', companiesHeld: 2)),
      );
      expect(find.byKey(const ValueKey('talent-hirers-only')), findsOneWidget);
      expect(find.text('You Are Using Your Personal Account'), findsOneWidget);
      expect(find.textContaining('Switch to one of your companies'), findsOneWidget);
      expect(find.byKey(const ValueKey('talent-search')), findsNothing);
    });

    testWidgets('a member with no company is told to set one up', (tester) async {
      await pump(
        tester,
        repository: DemoTalentRepository(viewer_: const TalentViewer(role: 'PROFESSIONAL')),
      );
      expect(find.text('Candidates Are Sourced for a Company'), findsOneWidget);
      expect(find.textContaining('Create your company on ICR'), findsOneWidget);
    });

    testWidgets('a role at the company that does not source is told to ask its admin', (tester) async {
      await pump(
        tester,
        repository: DemoTalentRepository(
          viewer_: const TalentViewer(role: 'BUYER', companyId: 'company-1'),
        ),
      );
      expect(find.text('Candidates Are Sourced by the Hiring Team'), findsOneWidget);
      expect(find.textContaining('Ask its admin to make you a recruiter'), findsOneWidget);
    });

    testWidgets("ICR staff with no company search, but are told what needs one, and the quick view offers none of it", (
      tester,
    ) async {
      await pump(
        tester,
        repository: DemoTalentRepository(viewer_: const TalentViewer(role: 'SUPER_ADMIN')),
      );
      expect(find.byKey(const ValueKey('talent-no-company')), findsOneWidget);
      expect(find.textContaining('You can search candidates and save searches'), findsOneWidget);
      expect(find.byKey(const ValueKey('mode-match')), findsNothing);
      expect(find.text('6 candidates'), findsOneWidget);

      await openQuickView(tester, 'cand-priya');
      expect(find.byKey(const ValueKey('qv-no-company')), findsOneWidget);
      expect(
        find.text('A company is required to contact this candidate, invite them to apply or keep notes on them.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('qv-reveal')), findsNothing);
      expect(find.byKey(const ValueKey('qv-note-save')), findsNothing);
    });
  });
}
