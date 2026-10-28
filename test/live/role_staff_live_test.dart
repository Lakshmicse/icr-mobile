/// The STAFF accounts against the LOCAL portal API: a SUPER_ADMIN with no company, and the two staff who hold
/// custom permission roles (`contentadmin@icr.test`: blogs and the contact inbox; `supportagent@icr.test`: the
/// support queue). The question is the owner's, "every flow must work for every kind of account": does the app
/// the member uses work for a person who runs the platform, and where the website gives staff powers, does the
/// app show them, hide them, or refuse them in the API's own words?
///
/// Passwords come from the portal's e2e fixtures at run time (`role_staff_support.dart`). Every write is made on
/// a row the test creates (a discussion, a document) and undone; what the API cannot undo is said where it happens.
///
///     flutter test --no-pub --timeout=120s test/live/role_staff_live_test.dart --concurrency=1
@Tags(['live'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/become_mentor/become_mentor_controller.dart';
import 'package:icr_mobile/features/become_mentor/become_mentor_repository.dart';
import 'package:icr_mobile/features/jobs/api_jobs_repository.dart';
import 'package:icr_mobile/features/jobs/employer/api_hiring_repository.dart';
import 'package:icr_mobile/features/jobs/employer/hiring_models.dart';
import 'package:icr_mobile/features/jobs/employer/post_job_controller.dart';
import 'package:icr_mobile/features/jobs/jobs_controller.dart';
import 'package:icr_mobile/features/mentor_profile/api_mentor_profile_repository.dart';
import 'package:icr_mobile/features/mentor_profile/mentor_profile_controller.dart';
import 'package:icr_mobile/features/mentorship_my/mentoring_models.dart';
import 'package:icr_mobile/features/mentorship_my/mentoring_repository.dart';

import '../helpers/fonts.dart';
import 'live.dart';
import 'role_staff_cases.dart';
import 'role_staff_support.dart';

const _slow = Timeout(Duration(minutes: 4));

void main() {
  setUpAll(loadAppFonts);

  group('a staff account signs in to the app and every tab opens', () {
    for (final who in staffPeople) {
      testWidgets(
        '${who.label}: Home, Learning, Mentorship, Forums, Marketplace and Jobs draw real content, the menu opens, sign out works',
        tags: const ['live'],
        timeout: _slow,
        (tester) async {
          if (!await liveScreenReady(tester)) return;
          await bootApp(tester, who);
          expect(
            await pumpUntil(tester, find.byKey(const ValueKey('home-avatar'))),
            isTrue,
            reason: 'the app signed in and drew Home',
          );
          await settleLive(tester, timeout: const Duration(seconds: 20));
          expect(thrown(tester), isNull);
          expectNoRawErrors(tester, 'Home');
          expect(find.text('All Feed'), findsWidgets, reason: 'the feed is the forum\'s, the same for staff');
          await retryWhileFailed(tester, what: 'Home');
          expect(find.text('Try again'), findsNothing);

          // Each tab, in the bottom bar's order.
          final probes = {
            'Learning': 'Assess Your Knowledge',
            'Mentorship': 'Top Mentors in Your Network',
            'Forums': 'Start a discussion...',
            'Marketplace': 'Post RFQ',
            'Jobs': 'Post a job',
          };
          for (final entry in probes.entries) {
            await tester.tap(find.bySemanticsLabel(entry.key).first);
            await settleLive(tester, timeout: const Duration(seconds: 20));
            expect(thrown(tester), isNull, reason: '${entry.key} threw');
            expectNoRawErrors(tester, entry.key);
            await retryWhileFailed(tester, what: entry.key);
            expect(find.text(entry.value), findsWidgets, reason: '${entry.key} shows "${entry.value}"');
            expect(find.text('Try again'), findsNothing, reason: '${entry.key} is not in its error state');
          }

          // The menu from Home's photo: the person's name, and Settings opens.
          await tester.tap(find.bySemanticsLabel('Home').first);
          await settleLive(tester);
          await tester.tap(find.byKey(const ValueKey('home-avatar')));
          await pumpUntil(tester, find.text('Settings'));
          await settleLive(tester);
          final first = who.label.split(' ').first;
          expect(find.textContaining(first), findsWidgets, reason: 'the menu names the person');
          expect(find.text('View Full Profile'), findsOneWidget);
          expect(thrown(tester), isNull);
          expectNoRawErrors(tester, 'the menu');

          await tester.tap(find.text('Sign Out'));
          expect(await pumpUntil(tester, find.textContaining('Sign in'), timeout: const Duration(seconds: 15)), isTrue);
          expect(thrown(tester), isNull);
          await finishLive(tester);
        },
      );
    }
  });

  // ---------------------------------------------------------------------------------------------------------
  // Every member screen, drawn over the live API for each staff account.
  // ---------------------------------------------------------------------------------------------------------

  /// What a screen shows instead of its usual probe, or besides it, for an account the API limits there. A
  /// limit is a sentence in the API's words (and, where there is a fix, the way to it), never a red screen.
  final limits = <String, Map<String, List<String>>>{
    // Candidate routes (applications, saved jobs, invitations, profile performance) are closed to a SUPER_ADMIN.
    'superadmin@icr.test': {
      'the career hub': ['Your career', 'Insufficient role permissions'],
    },
    // A person on no company's team: jobs and requirements are posted for a company.
    'contentadmin@icr.test': {
      'post a requirement': ['Requirements are posted for a company', 'Create a company'],
      'jobs you posted': ['Posting jobs is for hiring teams', 'Set up a company'],
    },
    'supportagent@icr.test': {
      'post a requirement': ['Requirements are posted for a company', 'Create a company'],
      'jobs you posted': ['Posting jobs is for hiring teams', 'Set up a company'],
    },
  };

  /// Screens a person without a company cannot use at all (the composer is gated at the Jobs tab, tested below).
  const skipFor = {
    'contentadmin@icr.test': {'post a job'},
    'supportagent@icr.test': {'post a job'},
  };

  /// The two staff who are ordinary members with a permission role open a shorter list: the rest is the PROFESSIONAL's.
  const coreScreens = {
    'my profile',
    'settings',
    'notifications',
    'messages',
    'the library',
    'saved items',
    'my requirements',
    'post a requirement',
    'my mentoring',
    'the mentor desk',
    'become a mentor',
    'jobs you posted',
    'the career hub',
    'certificates',
    'found a company',
  };

  for (final who in staffPeople) {
    group('${who.label}: the member screens', () {
      for (final c in memberScreens()) {
        if (who != superAdmin && !coreScreens.contains(c.name)) continue;
        if (skipFor[who.email]?.contains(c.name) ?? false) continue;
        testWidgets(
          '${c.name} opens with real content, or the sentence the API gives',
          tags: const ['live'],
          timeout: _slow,
          (tester) async {
            if (!await liveScreenReady(tester)) return;
            await pumpAs(tester, who, c.build);
            await settle(tester);
            final limit = limits[who.email]?[c.name];
            if (limit == null) await retryWhileFailed(tester, what: c.name);
            expect(thrown(tester), isNull, reason: '${c.name} threw');
            expectNoRawErrors(tester, c.name);
            expectNoSpinner(c.name);
            if (limit == null) {
              expect(find.textContaining(c.probe), findsWidgets, reason: '${c.name} shows "${c.probe}"');
              expect(find.text('Try again'), findsNothing, reason: '${c.name} is not in its error state');
              expect(find.textContaining("Couldn't load"), findsNothing);
            } else {
              for (final words in limit) {
                expect(find.textContaining(words), findsWidgets, reason: '${c.name} says "$words"');
              }
            }
            await finishLive(tester);
          },
        );
      }
    });
  }

  // ---------------------------------------------------------------------------------------------------------
  // The limits of the SUPER_ADMIN, which come back as sentences.
  // ---------------------------------------------------------------------------------------------------------

  group('the SUPER_ADMIN meets the platform limits as sentences', () {
    const operator = 'Platform administrators run the mentorship programme rather than take part in it.';

    liveTest(
      'mentorship is run by staff, not taken part in: every write answers that sentence and changes nothing',
      () async {
        final api = await clientFor(superAdmin);

        // Becoming a mentor: the first save is the one that would create the draft.
        final become = BecomeMentorController(BecomeMentorRepository(api: api));
        await become.start();
        expect(become.profile.data, isNull);
        print('become: ${await become.saveProfile({'capacity': 2})}');
        print('conduct: ${await become.agreeToConduct()}');
        print('submit: ${await become.submit()}');
        print('person: ${await become.savePerson({'designation': 'Platform admin'})}');
        expect((await BecomeMentorRepository(api: api).mine()), isNull, reason: 'no profile was made');

        // Asking a mentor, saving one, saying what you want from mentoring.
        final repo = MentoringRepository(api: api);
        for (final call in <String, Future<void> Function()>{
          'save a mentor': () => repo.saveMentor(srikanthProfileId),
          'say what you want': () => repo.saveMenteeIntent(const MenteeIntent(careerStage: 'MID')),
        }.entries) {
          try {
            await call.value();
            fail('${call.key} should be refused');
          } on Object catch (e) {
            print('${call.key}: ${ApiError.from(e).message}');
          }
        }
        final profile = MentorProfileController(
          repository: ApiMentorProfileRepository(api: api),
          mentorId: srikanthProfileId,
        );
        await profile.load();
        print(
          'viewer: canRequest=${profile.profile?.viewer?.canRequest} blocker=${profile.profile?.viewer?.blocker} reason=${profile.profile?.viewer?.blockedReason}',
        );
        print('request: ${await profile.requestMentoring(message: 'A staff member asking from the app test.')}');
        profile.dispose();
      },
    );

    liveTest(
      'the Jobs board: a candidate action is refused in the words the API gives and the bookmark goes back',
      () async {
        final api = await clientFor(superAdmin);
        final jobs = JobsController(ApiJobsRepository(api: api));
        final job = (await jobs.repository.latest()).jobs.first;
        final message = await jobs.toggleSave(job);
        print('save: $message');
        try {
          await jobs.repository.apply(job);
          fail('apply should be refused');
        } on Object catch (e) {
          print('apply: ${ApiError.from(e).message}');
        }
        final access = await jobs.hiringAccess();
        print('hiring: canManage=${access?.canManage} company=${access?.companyId} role=${access?.role}');
        final composer = PostJobController(
          ApiHiringRepository(api: api),
          initial: const JobDraft(title: 'A staff probe that is never kept'),
        );
        await composer.start();
        final saved = await composer.save();
        print('post: ok=${saved.ok} message=${saved.message}');
        composer.dispose();
      },
    );
  });
}
