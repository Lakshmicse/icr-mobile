/// Becoming a mentor against the LOCAL API, as the seeded member who has not applied (Kiran Shah,
/// `mentoring.kiran@design.icr.test`; run `tool/seed/mentoring.ts` first). Every write is undone: the profile is
/// emptied and withdrawn (`DELETE /mentorship/mentors/me`: the row stays, soft-deleted, and a later save revives it
/// as a DRAFT), the person's own fields go back to what the seed left, and the career history is emptied. What the
/// API has no way back for is said where it happens: a file that was uploaded stays in `backend/uploads`, and the
/// agreement to the code of conduct, once recorded on a profile, is kept on its row.
///
///     flutter test test/live/become_mentor_live_test.dart --concurrency=1
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/become_mentor/become_mentor_controller.dart';
import 'package:icr_mobile/features/become_mentor/become_mentor_models.dart';
import 'package:icr_mobile/features/become_mentor/become_mentor_repository.dart';
import 'package:icr_mobile/features/become_mentor/become_mentor_rules.dart';
import 'package:icr_mobile/features/mentorship_my/mentoring_clock.dart';

import 'live.dart';

const _password = 'Password123!';
const kiran = LivePerson('mentoring.kiran@design.icr.test', _password, 'Kiran Shah (applicant)');
const anand = LivePerson('mentoring.anand@design.icr.test', _password, 'Anand Iyer (a listed mentor)');

/// A 1 x 1 PNG, the smallest picture the uploader takes.
final tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// A one-line PDF.
/// The API's refusal of [call] as a sentence, or null when it went through.
Future<String?> refusalOf(Future<void> Function() call) async {
  try {
    await call();
    return null;
  } on Object catch (e) {
    return e.toString();
  }
}

final tinyPdf = utf8.encode('%PDF-1.1\n1 0 obj<</Type/Catalog>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n');

Future<BecomeMentorRepository> repoFor(LivePerson who) async => BecomeMentorRepository(api: await liveClient(who));

/// Empties the mentor profile and withdraws it. Safe to call with no profile.
Future<void> cleanProfile(BecomeMentorRepository repo) async {
  final p = await repo.mine();
  if (p == null) return;
  try {
    for (final d in await repo.documents()) {
      if (d.removable) await repo.removeDocument(d.id);
    }
  } on Object {
    // no documents to take back
  }
  await repo.saveAvailability(const []);
  await repo.save({
    'bioHtml': null,
    'competencies': <String>[],
    'topics': <String>[],
    'targetRoles': <String>[],
    'targetAudiences': <String>[],
    'certifications': <String>[],
    'availabilityNote': null,
    'cadence': null,
    'meetingLink': null,
    'preferredModes': ['VIDEO'],
    'capacity': 2,
    'discoverable': true,
  });
  await repo.withdraw();
}

/// The person's own fields back to what the seed left: no role, no years, no languages, no history, the seeded photo.
Future<void> cleanPerson(BecomeMentorRepository repo, String? avatar) async {
  await repo.updatePerson({
    'designation': '',
    'yearsExperience': null,
    'languages': <String>[],
    'avatarUrl': avatar ?? '',
  });
  await repo.replaceExperience(const []);
}

/// What the API says is missing, less the gates the controller names on their own lines (code of conduct, training).
List<String> apiBlockers(MentorReadiness r) => [
  for (final b in r.blockers)
    if (b != 'Create your mentor profile.' &&
        b != 'Agree to the mentor code of conduct.' &&
        !b.startsWith('Finish mentor training'))
      b,
];

/// Fills the person's side so only the mentoring half is left.
Future<void> completePerson(BecomeMentorController c) async {
  expect(
    await c.savePerson({
      'designation': 'Head of Facilities Strategy',
      'yearsExperience': 12,
      'languages': ['English', 'Hindi'],
    }),
    isNull,
  );
  expect(
    await c.saveExperience([
      const ExperienceRow(
        title: 'Head of Facilities',
        organisation: 'Prestige Group',
        city: 'Bengaluru',
        startYear: 2019,
        startMonth: 4,
        isCurrent: true,
      ),
    ]),
    isNull,
  );
}

void main() {
  late String? originalAvatar;

  Future<BecomeMentorController> started() async {
    final c = BecomeMentorController(await repoFor(kiran));
    await c.start();
    return c;
  }

  setUpAll(() async {
    if (!await liveApiReachable()) return;
    final repo = await repoFor(kiran);
    originalAvatar = (await repo.person()).avatarUrl;
    // A profile a previous run (or a probe) left: empty it, so every test starts from "has not applied".
    await cleanProfile(repo);
    await cleanPerson(repo, originalAvatar);
  });

  tearDownAll(() async {
    if (!await liveApiReachable()) return;
    final repo = await repoFor(kiran);
    await cleanProfile(repo);
    await cleanPerson(repo, originalAvatar);
  });

  group('becoming a mentor', () {
    liveTest('the reads parse the API\'s real answers for a member who has not applied', () async {
      final c = await started();
      expect(c.error, isNull, reason: '${c.error}');
      expect(c.profile.loaded, isTrue);
      expect(c.mentor, isNull, reason: 'the API answers 200 with an empty body');
      expect(c.hasProfile, isFalse);
      expect(c.status, MentorStatus.draft);
      expect(c.person.data!.name, 'Kiran Shah');
      expect(c.person.data!.avatarUrl, isNotNull);
      expect(c.person.data!.designation, isNull);
      expect(c.person.data!.languages, isEmpty);
      expect(c.experience.data, isEmpty);
      expect(c.credentials.error, isNull, reason: '${c.credentials.error}');
      final r = c.readiness.data!;
      expect(r.blockers, contains('Create your mentor profile.'));
      expect(r.canSubmit, isFalse);
      expect(r.training.requiredCount, greaterThanOrEqualTo(0));
      final conduct = c.conduct.data!;
      expect(conduct.version, '2026.1');
      expect(conduct.clauses, hasLength(7));
      expect(conduct.clauses.first.title, 'I am volunteering');
      expect(c.steps.map((s) => s.done), everyElement(isFalse));
      // Documents belong to a profile: before one exists the API says so, and the page never asks.
      expect(c.documents.loaded, isFalse);
    });

    liveTest(
      'the first save creates the DRAFT, and the checklist is the API\'s own list, line for line, at every step',
      () async {
        final c = await started();
        expect(await c.saveProfile({'bioHtml': bioToHtml('Short.')}), isNull);
        expect(c.hasProfile, isTrue);
        expect(c.status, MentorStatus.draft);
        expect(c.mentor!.bioHtml, '<p>Short.</p>');
        expect(c.mentor!.capacity, 2);
        expect(c.mentor!.preferredModes, ['VIDEO']);
        expect(c.mentor!.availability, isEmpty);

        List<String> mine() => [for (final n in c.needed) n.message];
        expect(mine(), apiBlockers(c.readiness.data!), reason: 'the first state: nothing but a short bio');
        expect(mine(), contains('Say a little more about how you mentor — at least 100 characters (6 so far).'));

        await completePerson(c);
        expect(mine(), apiBlockers(c.readiness.data!), reason: 'the person\'s half done');
        expect(mine(), isNot(contains('Add your current role.')));
        expect(mine(), isNot(contains('Add at least one role to your career history.')));

        expect(
          await c.saveProfile({
            'bioHtml': bioToHtml('I help facilities leads move from running a site to owning a portfolio. ' * 2),
          }),
          isNull,
        );
        expect(mine(), apiBlockers(c.readiness.data!));
        expect(
          await c.saveProfile({
            'competencies': ['Facility Management'],
            'targetAudiences': ['WORKING_PROFESSIONAL'],
          }),
          isNull,
        );
        expect(mine(), isEmpty);
        expect(apiBlockers(c.readiness.data!), isEmpty, reason: 'nothing left but the agreement');
        expect(c.readiness.data!.profileComplete, isTrue);
        expect(c.steps.first.done, isTrue);

        // A photo is part of it too: take it off and the API names it, in the same words and the same place.
        expect(await c.removePhoto(), isNull);
        expect(c.person.data!.avatarUrl, isNull);
        expect(mine(), ['Add a profile photo — it is the first thing a mentee sees.']);
        expect(mine(), apiBlockers(c.readiness.data!));
        expect(await c.savePerson({'avatarUrl': originalAvatar ?? ''}), isNull);
        expect(c.person.data!.avatarUrl, originalAvatar);

        await cleanProfile(c.repository);
        await cleanPerson(c.repository, originalAvatar);
      },
    );

    liveTest(
      'each section saves what it holds and reads it back: expertise, who you mentor, availability, the note',
      () async {
        final c = await started();
        expect(
          await c.saveProfile({
            'competencies': ['Facility Management', 'Sustainability & ESG'],
            'topics': ['Managing your first team'],
          }),
          isNull,
        );
        expect(c.mentor!.competencies, ['Facility Management', 'Sustainability & ESG']);
        expect(c.mentor!.topics, ['Managing your first team']);
        expect(
          await c.saveProfile({
            'targetAudiences': ['EARLY_CAREER', 'PEOPLE_LEADER'],
            'targetRoles': ['Facility Manager', 'Portfolio Lead'],
          }),
          isNull,
        );
        expect(c.mentor!.targetAudiences, ['EARLY_CAREER', 'PEOPLE_LEADER']);
        expect(c.mentor!.targetRoles, ['Facility Manager', 'Portfolio Lead']);
        expect(c.mentor!.competencies, hasLength(2), reason: 'a patch writes only what is sent');
        expect(
          await c.saveProfile({
            'capacity': 4,
            'preferredModes': ['VIDEO', 'PHONE'],
            'cadence': 'WEEKLY',
            'availabilityNote': 'Weekday evenings after 7pm IST',
          }),
          isNull,
        );
        expect(c.mentor!.capacity, 4);
        expect(c.mentor!.preferredModes, ['VIDEO', 'PHONE']);
        expect(c.mentor!.cadence, 'WEEKLY');
        expect(c.mentor!.availabilityNote, 'Weekday evenings after 7pm IST');
        // A cleared cadence and an emptied note are sent as null, and the API clears them.
        expect(await c.saveProfile({'cadence': null, 'availabilityNote': null}), isNull);
        expect(c.mentor!.cadence, isNull);
        expect(c.mentor!.availabilityNote, isNull);
        expect(c.mentor!.capacity, 4);
        await cleanProfile(c.repository);
      },
    );

    liveTest('the limits are the API\'s too: what the sheets stop before sending is refused if it is sent', () async {
      final c = await started();
      expect(
        await c.saveProfile({
          'competencies': ['Facility Management'],
        }),
        isNull,
      );
      final tooManyAreas = await c.saveProfile({
        'competencies': [for (var i = 0; i < 13; i++) 'Area $i'],
      });
      expect(tooManyAreas, contains('no more than 12'));
      expect(c.mentor!.competencies, ['Facility Management'], reason: 'a refused save changes nothing');
      expect(
        await c.saveProfile({
          'topics': [for (var i = 0; i < 13; i++) 'Topic $i'],
        }),
        contains('no more than 12'),
      );
      expect(
        await c.saveProfile({
          'targetRoles': [for (var i = 0; i < 9; i++) 'Role $i'],
        }),
        contains('no more than 8'),
      );
      expect(await c.saveProfile({'bioHtml': '<p>${'a' * 20001}</p>'}), contains('20000'));
      expect(await c.saveProfile({'capacity': 11}), isNotNull);
      expect(await c.saveProfile({'capacity': 0}), isNotNull);
      expect(
        await c.saveProfile({'meetingLink': 'nope'}),
        'Enter the full meeting link, for example https://meet.google.com/abc-defg-hij',
      );
      expect(
        await c.saveProfile({
          'targetAudiences': ['NOT_AN_AUDIENCE'],
        }),
        isNotNull,
      );
      expect(await c.saveProfile({'availabilityNote': 'a' * 281}), contains('280'));
      expect(
        await c.saveProfile({
          'certifications': ['NOTMINE'],
        }),
        contains('is not on your profile'),
      );
      expect(c.mentor!.competencies, ['Facility Management']);
      await cleanProfile(c.repository);
    });

    liveTest(
      'the person\'s own half: role, years, languages and career history are saved, read back and checked by the API',
      () async {
        final c = await started();
        expect(
          await c.savePerson({
            'designation': 'Head of Facilities Strategy',
            'yearsExperience': 12,
            'languages': ['English', 'Hindi'],
          }),
          isNull,
        );
        expect(c.person.data!.designation, 'Head of Facilities Strategy');
        expect(c.person.data!.yearsExperience, 12);
        expect(c.person.data!.languages, ['English', 'Hindi']);
        // The API's own refusals, which the sheets check first.
        expect(await c.savePerson({'designation': 'A'}), isNotNull);
        expect(await c.savePerson({'yearsExperience': 61}), isNotNull);
        expect(await c.savePerson({'yearsExperience': -1}), isNotNull);
        expect(
          await c.savePerson({
            'languages': [for (var i = 0; i < 9; i++) 'Language $i'],
          }),
          'Choose at most 8 languages.',
        );
        expect(c.person.data!.designation, 'Head of Facilities Strategy', reason: 'a refused save changes nothing');
        // Blank role and null years clear them.
        expect(await c.savePerson({'designation': '', 'yearsExperience': null}), isNull);
        expect(c.person.data!.designation, isNull);
        expect(c.person.data!.yearsExperience, isNull);

        expect(
          await c.saveExperience([
            const ExperienceRow(
              title: 'Head of Facilities',
              organisation: 'Prestige Group',
              city: 'Bengaluru',
              startYear: 2019,
              startMonth: 4,
              isCurrent: true,
            ),
            const ExperienceRow(
              title: 'Site Engineer',
              organisation: 'ACME',
              startYear: 2012,
              endYear: 2018,
              endMonth: 12,
              description: 'Built things.',
            ),
          ]),
          isNull,
        );
        final rows = c.experience.data!;
        expect(rows, hasLength(2));
        expect(
          rows.first.title,
          'Head of Facilities',
          reason: 'the API keeps a career newest first, a current role leading',
        );
        expect(rows.first.isCurrent, isTrue);
        expect(rows.first.span, 'Apr 2019 - Present');
        expect(rows.last.span, '2012 - Dec 2018');
        expect(rows.last.description, 'Built things.');
        // A role's own rules, in the API's hands: a future start is refused.
        final future = await c.saveExperience([
          ...rows,
          ExperienceRow(title: 'Later', organisation: 'Nowhere', startYear: mentoringNow().year + 2, isCurrent: true),
        ]);
        expect(future, isNotNull);
        expect(c.experience.data, hasLength(2));
        // The list is saved whole: removing one saves the rest.
        expect(await c.saveExperience([rows.first]), isNull);
        expect(c.experience.data!.single.title, 'Head of Facilities');
        await cleanPerson(c.repository, originalAvatar);
      },
    );

    liveTest('a photo is uploaded and becomes the member\'s own, then the seeded one is put back', () async {
      final c = await started();
      final before = c.person.data!.avatarUrl;
      expect(before, originalAvatar);
      expect(await c.uploadPhoto(PickedFile(bytes: tinyPng, name: 'kiran-live-test.png')), isNull);
      final now = c.person.data!.avatarUrl!;
      expect(now, startsWith('/uploads/'));
      expect(now, isNot(before), reason: 'the uploaded picture');
      expect(now, endsWith('.png'));
      // An upload the API does not accept is refused in its words.
      final refused = await c.uploadPhoto(
        PickedFile(bytes: utf8.encode('GIF89a'), name: 'a.gif', mimeType: 'image/gif'),
      );
      expect(refused, contains('is not an accepted file type'));
      expect(c.person.data!.avatarUrl, now, reason: 'nothing changed');
      expect(await c.removePhoto(), isNull);
      expect(c.person.data!.avatarUrl, isNull);
      expect(await c.savePerson({'avatarUrl': before ?? ''}), isNull);
      expect(c.person.data!.avatarUrl, before);
    });

    liveTest(
      'weekly hours: saved as minutes, read back, cleared; overlaps and backwards windows are refused',
      () async {
        final c = await started();
        expect(
          await c.saveProfile({
            'competencies': ['Facility Management'],
          }),
          isNull,
        );
        expect(
          await c.saveHours(const [
            AvailabilityBlock(weekday: 2, startMin: 1080, endMin: 1230),
            AvailabilityBlock(weekday: 4, startMin: 1080, endMin: 1230),
            AvailabilityBlock(weekday: 6, startMin: 600, endMin: 780),
          ]),
          isNull,
        );
        expect(c.mentor!.availability, hasLength(3));
        expect(c.mentor!.availability, contains(const AvailabilityBlock(weekday: 6, startMin: 600, endMin: 780)));
        expect(c.mentor!.timezone, 'Asia/Kolkata');
        expect(
          await c.saveHours(const [
            AvailabilityBlock(weekday: 2, startMin: 1080, endMin: 1230),
            AvailabilityBlock(weekday: 2, startMin: 1200, endMin: 1300),
          ]),
          'Windows on the same day must not overlap.',
        );
        expect(
          await c.saveHours(const [AvailabilityBlock(weekday: 2, startMin: 1080, endMin: 1080)]),
          'Each window must end after it starts.',
        );
        expect(
          await c.saveHours(const [AvailabilityBlock(weekday: 2, startMin: 1230, endMin: 1080)]),
          'Each window must end after it starts.',
        );
        expect(
          await c.saveHours([
            for (var i = 0; i < 22; i++)
              AvailabilityBlock(weekday: i % 7, startMin: (i ~/ 7) * 120, endMin: (i ~/ 7) * 120 + 60),
          ]),
          isNotNull,
          reason: 'at most 21 windows',
        );
        expect(c.mentor!.availability, hasLength(3), reason: 'refusals changed nothing');
        expect(await c.saveHours(const []), isNull);
        expect(c.mentor!.availability, isEmpty);
        await cleanProfile(c.repository);
      },
    );

    liveTest('"accepting new requests" is switched on its own, and put back', () async {
      final c = await started();
      expect(
        await c.saveProfile({
          'competencies': ['Facility Management'],
        }),
        isNull,
      );
      final first = c.mentor!.discoverable;
      expect(await c.setVisibility(!first), isNull);
      expect(c.mentor!.discoverable, !first);
      expect(c.mentor!.competencies, ['Facility Management'], reason: 'nothing else moved');
      expect(await c.setVisibility(first), isNull);
      expect(c.mentor!.discoverable, first);
      await cleanProfile(c.repository);
    });

    liveTest(
      'the code of conduct: read in full, agreed to once (the draft is created for it), a stale version refused',
      () async {
        final c = await started();
        expect(c.hasProfile, isFalse);
        expect(c.conduct.data!.version, '2026.1');
        expect(
          await refusalOf(() => c.repository.acceptConduct('2025.9')),
          contains('not the current code of conduct (2026.1)'),
        );
        expect(await c.agreeToConduct(), isNull);
        expect(c.hasProfile, isTrue, reason: 'the agreement attaches to the profile, so the (empty) draft was created');
        expect(c.conductAccepted, isTrue);
        expect(c.readiness.data!.conductVersion, '2026.1');
        expect(c.steps[1].done, isTrue);
        expect(await c.agreeToConduct(), isNull, reason: 'agreeing again is harmless');
        await cleanProfile(c.repository);
      },
    );

    liveTest('supporting documents: uploaded as private screening evidence, attached, read back, taken back', () async {
      final c = await started();
      expect(
        await c.saveProfile({
          'competencies': ['Facility Management'],
        }),
        isNull,
      );
      await c.documents.load();
      expect(c.documents.data, isEmpty);
      expect(
        await c.addDocument(
          PickedFile(bytes: tinyPdf, name: 'kiran-live-test.pdf'),
          kind: 'CERTIFICATION',
          label: 'CFMP certificate (live test)',
        ),
        isNull,
      );
      final d = c.documents.data!.single;
      expect(d.kind, 'CERTIFICATION');
      expect(d.kindLabel, 'Certificate');
      expect(d.label, 'CFMP certificate (live test)');
      expect(d.status, 'PENDING');
      expect(d.statusLabel, 'Awaiting review');
      expect(d.removable, isTrue);
      expect(d.fileUrl, startsWith('/uploads/'));
      expect(d.fileName, 'kiran-live-test.pdf');
      expect(d.fileSize, tinyPdf.length);
      expect(c.readiness.data!.documentsUploaded, 1);
      // A kind the API no longer collects is refused (the sheet never offers it).
      final id = await refusalOf(() => c.repository.addDocument(kind: 'ID_PROOF', fileUrl: d.fileUrl!));
      expect(id, contains('photo ID is no longer collected'));
      expect(await c.removeDocument(d), isNull);
      expect(c.documents.data, isEmpty);
      expect(c.readiness.data!.documentsUploaded, 0);
      expect(await c.removeDocument(d), isNotNull, reason: 'it is gone');
      await cleanProfile(c.repository);
    });

    liveTest(
      'submitting: a complete application goes to review, cannot go twice, and withdrawing takes it back to a fresh draft',
      () async {
        final c = await started();
        // The API refuses an incomplete submit with its whole list, which the checklist already shows.
        expect(await c.saveProfile({'bioHtml': bioToHtml('Short.')}), isNull);
        final refusal = await c.submit();
        expect(refusal, isNotNull);
        for (final n in c.profileNeeds) {
          expect(refusal, contains(n.message), reason: 'the API names what the checklist names');
        }
        expect(c.status, MentorStatus.draft);

        await completePerson(c);
        expect(
          await c.saveProfile({
            'bioHtml': bioToHtml('I help facilities leads move from running a site to owning a portfolio. ' * 2),
            'competencies': ['Facility Management'],
            'targetAudiences': ['WORKING_PROFESSIONAL'],
          }),
          isNull,
        );
        if (!c.conductAccepted) {
          // The agreement is the last gate: without it the API refuses with its own sentence.
          expect(await c.submit(), contains('code of conduct'));
          expect(await c.agreeToConduct(), isNull);
        }
        expect(c.ready, isTrue);
        expect(await c.submit(), isNull);
        expect(c.status, MentorStatus.pending);
        expect(c.mentor!.reviewNote, isNull);
        expect(c.steps.last.label, 'ICR review — in progress');
        expect(await c.submit(), 'Your profile is already with the review team.');

        expect(await c.withdraw(), isNull);
        expect(c.mentor, isNull);
        final again = await c.repository.mine();
        expect(again, isNull, reason: 'the API no longer shows it');
        // Starting again revives it as a DRAFT, not as the PENDING it left with.
        final back = await c.repository.save(const {});
        expect(back.status, MentorStatus.draft);
        await cleanProfile(c.repository);
        await cleanPerson(c.repository, originalAvatar);
      },
    );

    liveTest(
      'a mentor with mentorships under way cannot withdraw, in the API\'s words (Anand: nothing is changed)',
      () async {
        final repo = await repoFor(anand);
        final mine = await repo.mine();
        expect(mine, isNotNull);
        expect(mine!.status, MentorStatus.approved);
        expect(mine.status.listed, isTrue);
        expect(mine.status.canSubmit, isFalse);
        expect(mine.competencies, isNotEmpty);
        expect(mine.availability, isNotEmpty);
        expect(mine.capacity, greaterThan(0));
        final readiness = await repo.readiness();
        expect(readiness.conductAccepted, isTrue);
        expect(readiness.trainingComplete, isTrue);
        final refusal = await refusalOf(repo.withdraw);
        expect(refusal, contains('mentorship'));
        expect(refusal, contains('under way'));
        expect((await repo.mine())!.status, MentorStatus.approved, reason: 'still listed');
      },
    );

    liveTest(
      'the page\'s ends are clean: Kiran has no profile and the seeded role, years, languages and photo',
      () async {
        final c = await started();
        expect(c.mentor, isNull);
        expect(c.person.data!.designation, isNull);
        expect(c.person.data!.yearsExperience, isNull);
        expect(c.person.data!.languages, isEmpty);
        expect(c.experience.data, isEmpty);
        expect(c.person.data!.avatarUrl, originalAvatar);
      },
    );
  });
}
