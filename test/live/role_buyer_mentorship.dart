/// Role matrix, part 5: Mentorship for the four accounts that belong to no company: the landing and Find Mentors, a
/// mentor's profile with what each account may do there (a request, a free trial, or why not), and My mentoring.
/// Every request is withdrawn straight after, and the profile of the mentor is never the account's own.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/features/feed/feed_models.dart';
import 'package:icr_mobile/features/mentor_profile/mentor_profile_controller.dart';
import 'package:icr_mobile/features/mentor_profile/mentor_profile_screen.dart';
import 'package:icr_mobile/features/mentorship/find_mentors_screen.dart';
import 'package:icr_mobile/features/mentorship/mentorship_controller.dart';
import 'package:icr_mobile/features/mentorship/mentorship_screen.dart';
import 'package:icr_mobile/features/mentorship_my/my_mentoring_screen.dart';
import 'package:provider/provider.dart';
import 'package:icr_mobile/features/mentor_profile/api_mentor_profile_repository.dart';
import 'package:icr_mobile/features/mentor_profile/mentor_profile_models.dart';
import 'package:icr_mobile/features/mentorship/api_mentorship_repository.dart';
import 'package:icr_mobile/features/mentorship/mentorship_models.dart';
import 'package:icr_mobile/features/mentorship_my/mentoring_repository.dart';

import '../helpers/fonts.dart';
import 'career_live_support.dart';
import 'live.dart';
import 'role_buyer_support.dart';

final _mentorship = <String, ApiMentorshipRepository>{};
ApiMentorshipRepository mentorshipOf(Who w) =>
    _mentorship.putIfAbsent(w.email, () => ApiMentorshipRepository(api: w.api));

final _profiles = <String, ApiMentorProfileRepository>{};
ApiMentorProfileRepository profilesOf(Who w) =>
    _profiles.putIfAbsent(w.email, () => ApiMentorProfileRepository(api: w.api));

final _mentoring = <String, MentoringRepository>{};
MentoringRepository mentoringOf(Who w) => _mentoring.putIfAbsent(w.email, () => MentoringRepository(api: w.api));

/// The mentor the tests look at: the first listed one, who is never one of the four accounts.
Future<Mentor> _someMentor(Who w) async {
  final page = await mentorshipOf(w).search(const MentorFilters());
  return page.mentors.firstWhere((m) => m.userId != w.id);
}

void roleBuyerMentorship() {
  setUpAll(loadAppFonts);

  group('Mentorship', () {
    liveTest(
      'the landing, Find Mentors (search, filters, sorts, paging) and a mentor\'s profile read for every account',
      () async {
        for (final w in await everyone()) {
          final repo = mentorshipOf(w);
          final overview = await repo.overview();
          expect(overview.shelves, isNotEmpty, reason: '${w.email}: the landing has mentors');
          final categories = await repo.categories();
          expect(categories, isNotEmpty);
          final page = await repo.search(const MentorFilters());
          expect(page.mentors, isNotEmpty);
          expect(page.total, greaterThan(0));
          for (final sort in MentorSort.values) {
            expect((await repo.search(MentorFilters(sort: sort))).mentors, isNotEmpty, reason: '$sort');
          }
          await repo.search(MentorFilters(category: categories.first.label));
          await repo.search(const MentorFilters(minExperience: 10));
          await repo.search(const MentorFilters(availableOnly: true));
          final byName = await repo.search(MentorFilters(search: page.mentors.first.name.split(' ').first));
          expect(byName.mentors, isNotEmpty);
          if (page.hasMore) expect((await repo.search(const MentorFilters(), page: 2)).mentors, isNotEmpty);
          expect(await repo.unreadNotifications(), greaterThanOrEqualTo(0));

          final mentor = await _someMentor(w);
          final profiles = profilesOf(w);
          final profile = await profiles.profile(mentor.id);
          expect(profile.id, mentor.id);
          await profiles.offerings(profile);
          await profiles.reviews(profile);
          await profiles.hasPhone();

          // Save and un-save a mentor, as the account had it.
          final saved = (await mentoringOf(w).savedMentors()).any((m) => m.mentorProfileId == mentor.id);
          await repo.setSaved(mentor, !saved);
          expect((await mentoringOf(w).savedMentors()).any((m) => m.mentorProfileId == mentor.id), !saved);
          await repo.setSaved(mentor, saved);
          expect((await mentoringOf(w).savedMentors()).any((m) => m.mentorProfileId == mentor.id), saved);
          record('Mentorship: landing, Find Mentors, mentor profile, save a mentor', w.person, 'works');
        }
      },
    );

    liveTest(
      'a mentoring request is kept as pending and withdrawn, or refused with the reason the profile shows',
      () async {
        for (final w in await everyone()) {
          final profiles = profilesOf(w);
          final mentor = await _someMentor(w);
          var profile = await profiles.profile(mentor.id);
          final viewer = profile.viewer;
          if (viewer == null || !viewer.canRequest) {
            expect(viewer?.blockedReason, isNotNull, reason: '${w.email}: the API says why');
            record(
              'Mentorship: request mentoring',
              w.person,
              'refused correctly',
              '${viewer?.blocker?.name}: "${viewer?.blockedReason}"',
            );
            continue;
          }
          // The profile offers the request: send it, see it pending, take it back.
          await profiles.requestMentoring(
            profile,
            message: 'Role matrix: I would like to learn how you moved into facilities leadership. Please ignore.',
            phone: w.phone == null ? '+91 98123 45670' : null,
          );
          try {
            profile = await profiles.profile(mentor.id);
            final pending = profile.viewer?.pendingRequestId;
            expect(pending, isNotNull, reason: '${w.email}: the request is with the mentor');
            expect(profile.viewer?.blocker, AskBlocker.requestPending);
            final sent = await mentoringOf(w).requestsSent();
            expect(sent.any((r) => r.id == pending), isTrue, reason: 'My mentoring lists it under Sent by you');
            await mentoringOf(w).withdrawRequest(pending!);
            expect((await profiles.profile(mentor.id)).viewer?.pendingRequestId, isNull);
            record('Mentorship: request mentoring, pending, withdrawn', w.person, 'works');
          } finally {
            if (w.phone == null) await w.api.dio.patch<dynamic>('/users/me', data: {'phone': ''});
          }
        }
      },
    );

    liveTest(
      'Book Trial (free 1:1 session): kept as a request, or refused with the API sentence; withdrawn after',
      () async {
        for (final w in await everyone()) {
          final profiles = profilesOf(w);
          final found = await mentorshipOf(w).search(const MentorFilters(search: 'Srikanth'));
          final mentor = found.mentors.firstWhere((m) => m.userId != w.id);
          final profile = await profiles.profile(mentor.id);
          final offerings = await profiles.offerings(profile);
          final trial = offerings.where((o) => o.kind == OfferingKind.oneOnOne && o.free).firstOrNull;
          expect(trial, isNotNull, reason: 'the seeded mentor lists a free 1:1 session');
          String? purchaseId;
          try {
            purchaseId = await profiles.requestSession(
              trial!,
              topic: 'Role matrix: I want to talk through moving from operations into facilities leadership.',
              mode: 'VIDEO',
              preferredTimes: 'Weekday evenings, IST',
              phone: w.phone == null ? '+91 98123 45670' : null,
            );
            expect(purchaseId, isNotNull);
            final mine = await mentoringOf(w).purchases();
            expect(mine.any((p) => p.id == purchaseId), isTrue, reason: '${w.email}: it is listed under Purchases');
            record('Mentorship: Book Trial (free 1:1) requested', w.person, 'works', 'withdrawn after');
          } catch (e) {
            // A refusal is the API sentence, which the request sheet shows with what was typed.
            final sentence = sentenceOf(e);
            expect(sentence, isNotEmpty);
            record('Mentorship: Book Trial (free 1:1)', w.person, 'refused correctly', '${statusOf(e)} "$sentence"');
          } finally {
            if (purchaseId != null) await mentoringOf(w).withdrawPurchaseRequest(purchaseId);
            if (purchaseId != null && w.phone == null) await w.api.dio.patch<dynamic>('/users/me', data: {'phone': ''});
          }
        }
      },
    );

    liveTest('My mentoring: every tab\'s reads answer for every account', () async {
      for (final w in await everyone()) {
        final repo = mentoringOf(w);
        await repo.summary();
        await repo.pairings();
        await repo.requestsSent();
        await repo.requestsReceived();
        await repo.upcomingSessions();
        await repo.quota();
        await repo.menteeIntent();
        await repo.goalsAcross();
        await repo.savedMentors();
        await repo.certificates();
        await repo.concerns();
        await repo.focusOptions();
        await repo.purchases();
        await repo.groupSeats();
        await repo.planTerms();
        final now = DateTime.now();
        await repo.calendar(DateTime(now.year, now.month), DateTime(now.year, now.month + 1));
        record('Mentorship: My mentoring tabs (reads)', w.person, 'works');
      }
    });
  });

  group('the Mentorship screens, drawn for every account', () {
    testWidgets('the landing and Find Mentors draw for every account', tags: const ['live'], (tester) async {
      if (!await liveScreenReady(tester)) return;
      for (final w in (await tester.runAsync(everyone))!) {
        final client = [Provider<ApiClient>.value(value: w.api)];
        final market = MentorshipController(mentorshipOf(w));
        await loadScreen(
          tester,
          MentorshipScreen(
            onBack: () {},
            onOpenMentor: (c, id) {},
            viewer: FeedAuthor(id: w.id, name: w.first),
            onAccount: () {},
          ),
          providers: [ChangeNotifierProvider<MentorshipController>.value(value: market)],
          appProviders: client,
          size: const Size(390, 2600),
        );
        await waitFor(tester, find.textContaining('Domains'));
        var text = expectHealthy(tester, 'the Mentorship landing as ${w.email}');
        expect(text, contains('Explore by Companies'));
        await unmount(tester);

        await loadScreen(
          tester,
          FindMentorsScreen(onBack: () {}, onOpenMentor: (c, id) {}),
          providers: [ChangeNotifierProvider<MentorshipController>.value(value: market)],
          appProviders: client,
          size: const Size(390, 2600),
        );
        await waitFor(tester, find.textContaining('matches'));
        text = expectHealthy(tester, 'Find Mentors as ${w.email}');
        expect(text, contains('Find Mentors'));
        await unmount(tester);
        record('Mentorship: landing and Find Mentors screens', w.person, 'works');
      }
    });

    testWidgets(
      'a mentor profile: the main button says where the person stands; with no mentee profile it opens the Goals tab in the app',
      tags: const ['live'],
      (tester) async {
        if (!await liveScreenReady(tester)) return;
        for (final w in (await tester.runAsync(everyone))!) {
          final client = [Provider<ApiClient>.value(value: w.api)];
          // A mentor with no free 1:1 session, so the main button is the one for the person's standing.
          final mentor = (await tester.runAsync(() async {
            final page = await mentorshipOf(w).search(const MentorFilters());
            for (final m in page.mentors.where((m) => m.userId != w.id)) {
              final profile = await profilesOf(w).profile(m.id);
              final offerings = await profilesOf(w).offerings(profile);
              final free = offerings.any((o) => o.kind == OfferingKind.oneOnOne && o.free);
              if (!free && (profile.viewer?.pendingRequestId == null) && profile.viewer?.mentorshipId == null) return m;
            }
            return null;
          }))!;
          final controller = MentorProfileController(repository: profilesOf(w), mentorId: mentor.id);
          await tester.runAsync(controller.load);
          await loadScreen(
            tester,
            MentorProfileScreen(mentorId: mentor.id, onBack: () {}),
            providers: [ChangeNotifierProvider<MentorProfileController>.value(value: controller)],
            appProviders: client,
            size: const Size(390, 2600),
          );
          var text = expectHealthy(tester, 'a mentor profile as ${w.email}');
          final blocker = controller.profile!.viewer?.blocker;
          if (blocker == AskBlocker.noMenteeProfile) {
            expect(
              text,
              contains('Tell Us Your Goals First'),
              reason: '${w.email}: the main button asks for the goals',
            );
            await tester.tap(find.text('Tell Us Your Goals First').first);
            await afterTap(tester);
            // The app's own My mentoring opens on its Goals tab; the website is not asked.
            expect(
              find.byType(MyMentoringScreen),
              findsOneWidget,
              reason: '${w.email}: the goals are written in the app',
            );
            text = expectHealthy(tester, 'My mentoring on Goals as ${w.email}');
            expect(text, contains('Goals'));
            record(
              'Mentorship: Tell Us Your Goals First',
              w.person,
              'bug fixed',
              'opened the website; now opens My mentoring on the Goals tab in the app',
            );
          } else {
            expect(
              text,
              contains('Request Mentoring'),
              reason: '${w.email}: a mentee profile exists, so the person may ask',
            );
            await tester.tap(find.text('Request Mentoring').first);
            await afterTap(tester);
            expect(find.textContaining('to mentor you'), findsOneWidget, reason: 'the request sheet opens');
            await tester.enterText(
              find.byType(TextField).first,
              'Role matrix: I would like to learn how you moved into facilities leadership. Please ignore.',
            );
            await tester.tap(find.text('Send request'));
            await afterTap(tester);
            final after = (await tester.runAsync(() => profilesOf(w).profile(mentor.id)))!;
            final pending = after.viewer?.pendingRequestId;
            expect(pending, isNotNull, reason: '${w.email}: the request is with the mentor');
            await tester.runAsync(() => mentoringOf(w).withdrawRequest(pending!));
            record('Mentorship: Request Mentoring from the profile, withdrawn after', w.person, 'works');
          }
          await unmount(tester);
          controller.dispose();
        }
      },
    );
  });
}
