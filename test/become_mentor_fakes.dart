/// A stateful fake of everything the become-a-mentor flow reads and writes, in the shapes the real API answers with
/// (each shape was checked against a live call as Kiran): a write changes what the next read says, so a test proves
/// the effect, and `api.requests` records what was sent.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/become_mentor/become_mentor_person_forms.dart';
import 'package:icr_mobile/features/become_mentor/become_mentor_repository.dart';
import 'package:icr_mobile/features/become_mentor/become_mentor_rules.dart';
import 'package:icr_mobile/features/become_mentor/become_mentor_screen.dart';

import 'mentoring_fakes.dart';

class MentorWorld {
  MentorWorld({
    this.withProfile = false,
    this.status = 'DRAFT',
    this.avatar = '/uploads/kiran.jpg',
    this.designation,
    this.years,
    this.languages = const [],
    this.requiredCourses = const [],
    List<Map<String, Object?>>? experience,
  }) {
    this.experience = experience ?? [];
    if (withProfile) profile = _newProfile();
  }

  final bool withProfile;
  String status;
  String? avatar;
  String? designation;
  int? years;
  List<String> languages;
  List<Map<String, Object?>> requiredCourses;
  late List<Map<String, Object?>> experience;
  List<Map<String, Object?>> credentials = [];
  List<Map<String, Object?>> documents = [];
  Map<String, Object?>? profile;
  bool conductAccepted = false;
  String? conductVersion;
  String? reviewNote;
  bool renewalDue = false;
  String? withdrawRefusal;
  int _n = 0;

  /// What the next call to a route answers instead, once (a refusal).
  final Map<String, (int, String)> refusals = {};

  Map<String, Object?> _newProfile() => {
    'id': 'mp-kiran',
    'user': {'id': 'u-kiran', 'firstName': 'Kiran', 'lastName': 'Shah', 'avatarUrl': avatar},
    'headline': designation ?? '',
    'yearsExperience': years,
    'competencies': <String>[],
    'expertiseKeys': <String>[],
    'certifications': <String>[],
    'languages': languages,
    'targetRoles': <String>[],
    'targetAudiences': <String>[],
    'preferredModes': ['VIDEO'],
    'cadence': null,
    'openSlots': 2,
    'capacity': 2,
    'status': status,
    'bioHtml': null,
    'topics': <String>[],
    'availabilityNote': null,
    'availabilityBlocks': <Object?>[],
    'timezone': 'Asia/Kolkata',
    'reviewNote': reviewNote,
    'discoverable': true,
    'meetingLink': null,
  };

  List<String> _list(Object? v) => (v as List? ?? const []).map((e) => e.toString()).toList();

  MentorPersonFacts get personFacts => MentorPersonFacts(
    avatarUrl: avatar,
    designation: designation,
    yearsExperience: years,
    languages: languages,
    experienceCount: experience.length,
  );

  MentorProfileFacts get profileFacts => MentorProfileFacts(
    bioHtml: profile?['bioHtml'] as String?,
    competencies: _list(profile?['competencies']),
    expertiseKeys: _list(profile?['expertiseKeys']),
    topics: _list(profile?['topics']),
    targetRoles: _list(profile?['targetRoles']),
    targetAudiences: _list(profile?['targetAudiences']),
    availabilityNote: profile?['availabilityNote'] as String?,
  );

  bool get trainingComplete => requiredCourses.every((c) => c['completed'] == true);

  Map<String, Object?> get training => {
    'required': requiredCourses,
    'completedCount': requiredCourses.where((c) => c['completed'] == true).length,
    'requiredCount': requiredCourses.length,
    'allComplete': trainingComplete,
    'completedAt': null,
  };

  List<String> get problems => [
    for (final p in mentorPersonProblems(personFacts, forSubmit: true)) p.message,
    for (final p in mentorProfileProblems(profileFacts, forSubmit: true)) p.message,
  ];

  Map<String, Object?> get readiness {
    final blockers = [
      if (profile == null) 'Create your mentor profile.',
      if (profile != null) ...problems,
      if (!conductAccepted) 'Agree to the mentor code of conduct.',
    ];
    return {
      'profileComplete': profile != null && problems.isEmpty,
      'conductAccepted': conductAccepted,
      'conductVersion': conductVersion,
      'trainingComplete': trainingComplete,
      'training': training,
      'documentsUploaded': documents.length,
      'documentsVerified': documents.where((d) => d['status'] == 'VERIFIED').length,
      'canSubmit': blockers.isEmpty,
      'blockers': blockers,
      'approvalExpiresAt': renewalDue ? iso(DateTime(2026, 11, 10)) : null,
      'renewalDue': renewalDue,
    };
  }

  static const conduct = {
    'version': '2026.1',
    'clauses': [
      {'key': 'volunteer', 'title': 'I am volunteering', 'body': 'I offer my time freely.'},
      {'key': 'no-solicitation', 'title': 'I will not sell or recruit', 'body': 'I will not use mentoring to sell.'},
      {
        'key': 'confidentiality',
        'title': 'I will keep it confidential',
        'body': 'What my mentee tells me stays between us.',
      },
    ],
  };

  Reply _once(String key, Reply ok) => (o) {
    final r = refusals.remove(key);
    return r ?? ok(o);
  };

  Map<String, Reply> routes() => {
    'GET /mentorship/mentors/me': (_) => profile ?? '',
    'PUT /mentorship/mentors/me': _once('PUT me', (o) {
      final b = o.data as Map<String, dynamic>;
      profile ??= _newProfile();
      for (final e in b.entries) {
        profile![e.key] = e.value;
      }
      return profile!;
    }),
    'POST /mentorship/mentors/me/submit': _once('submit', (_) {
      if (profile == null) return refuse('Create your mentor profile before submitting it.', status: 404);
      final all = problems;
      if (all.isNotEmpty) return refuse(all.join(' '));
      if (!conductAccepted) {
        return refuse('Read and accept the mentor code of conduct before submitting — mentoring carries ICR’s name.');
      }
      if (!trainingComplete) return refuse('Finish mentor training first.');
      status = 'PENDING';
      profile!['status'] = 'PENDING';
      profile!['reviewNote'] = null;
      return profile!;
    }),
    'DELETE /mentorship/mentors/me': _once('withdraw', (_) {
      if (withdrawRefusal != null) return refuse(withdrawRefusal!);
      profile = null;
      return {'status': 'withdrawn'};
    }),
    'PATCH /mentorship/mentors/me/visibility': (o) {
      profile!['discoverable'] = (o.data as Map)['discoverable'];
      return profile!;
    },
    'PUT /mentorship/mentors/me/availability': _once('hours', (o) {
      final blocks = ((o.data as Map)['blocks'] as List).cast<Map>();
      for (final b in blocks) {
        if ((b['endMin'] as int) <= (b['startMin'] as int)) return refuse('Each window must end after it starts.');
      }
      profile!['availabilityBlocks'] = blocks;
      return profile!;
    }),
    'GET /mentorship/mentors/me/readiness': (_) => readiness,
    'GET /mentorship/code-of-conduct': (_) => conduct,
    'POST /mentorship/mentors/me/code-of-conduct': _once('conduct', (o) {
      final v = (o.data as Map)['version'];
      if (v != '2026.1') return refuse('That is not the current code of conduct (2026.1). Reload and read it again.');
      if (profile == null) return refuse('Create your mentor profile first.', status: 404);
      conductAccepted = true;
      conductVersion = '2026.1';
      return readiness;
    }),
    'GET /mentorship/mentors/me/documents': (_) =>
        profile == null ? refuse('Create your mentor profile first.', status: 404) : documents,
    'POST /mentorship/mentors/me/documents': (o) {
      final b = o.data as Map<String, dynamic>;
      documents = [
        {
          'id': 'doc-${++_n}',
          'kind': b['kind'],
          'label': b['label'],
          'fileUrl': b['fileUrl'],
          'fileName': b['fileName'],
          'fileSize': b['fileSize'],
          'status': 'PENDING',
          'reviewNote': null,
          'reviewedAt': null,
          'createdAt': iso(DateTime(2026, 10, 26)),
        },
        ...documents,
      ];
      return documents.first;
    },
    'POST /uploads': (o) => {
      'url': '/uploads/abc123.pdf',
      'name': 'upload.pdf',
      'size': 3,
      'mimeType': 'application/pdf',
    },
    'GET /users/me/profile': (_) => {
      'user': {
        'id': 'u-kiran',
        'firstName': 'Kiran',
        'lastName': 'Shah',
        'designation': designation,
        'yearsExperience': years,
        'languages': languages,
        'avatarUrl': avatar,
      },
    },
    'PATCH /users/me': _once('PATCH me', (o) {
      final b = o.data as Map<String, dynamic>;
      if (b.containsKey('designation')) {
        designation = (b['designation'] as String).isEmpty ? null : b['designation'] as String;
      }
      if (b.containsKey('yearsExperience')) years = b['yearsExperience'] as int?;
      if (b.containsKey('languages')) languages = (b['languages'] as List).cast<String>();
      if (b.containsKey('avatarUrl')) avatar = (b['avatarUrl'] as String).isEmpty ? null : b['avatarUrl'] as String;
      return {'ok': true};
    }),
    'GET /profile/experience': (_) => experience,
    'PUT /profile/experience': _once('PUT experience', (o) {
      final rows = ((o.data as Map)['rows'] as List).cast<Map<String, dynamic>>();
      experience = [
        for (final (i, r) in rows.indexed) {...r, 'id': 'xp-$i', 'sortOrder': i, 'company': null},
      ];
      return experience;
    }),
    'GET /credentials/me': (_) => {
      'credentials': credentials,
      'counts': {'total': credentials.length},
    },
    'GET /job-titles': (_) => [
      {'id': 'jt1', 'name': 'Facility Manager', 'active': true},
      {'id': 'jt2', 'name': 'Facilities Head', 'active': true},
      {'id': 'jt3', 'name': 'Energy Manager', 'active': true},
    ],
    'DELETE /mentorship/mentors/me/documents/doc-1': (_) {
      documents = documents.where((d) => d['id'] != 'doc-1').toList();
      return {'status': 'removed'};
    },
    'DELETE /mentorship/mentors/me/documents/doc-2': (_) {
      documents = documents.where((d) => d['id'] != 'doc-2').toList();
      return {'status': 'removed'};
    },
  };

  FakeApi api({Map<String, Reply> extra = const {}}) => FakeApi({...routes(), ...extra});
}

/// A complete applicant: everything the rules want is there but the code of conduct.
MentorWorld completeWorld({String status = 'DRAFT'}) =>
    MentorWorld(
        withProfile: true,
        status: status,
        designation: 'Head of Facilities Strategy',
        years: 12,
        languages: ['English', 'Hindi'],
        experience: [
          {
            'id': 'xp-0',
            'title': 'Head of Facilities',
            'organisation': 'Prestige Group',
            'company': null,
            'employmentType': null,
            'city': 'Bengaluru',
            'industryKeys': <String>[],
            'startYear': 2019,
            'startMonth': 4,
            'endYear': null,
            'endMonth': null,
            'isCurrent': true,
            'description': null,
            'sortOrder': 0,
          },
        ],
      )
      ..profile!.addAll({
        'bioHtml': '<p>${'I help facilities leads move from running a site to owning a portfolio. ' * 2}</p>',
        'competencies': ['Facility Management'],
        'targetAudiences': ['WORKING_PROFESSIONAL'],
      });

/// Pumps the screen over the world's fake API.
Future<(FakeApi, LinkRecorder)> pumpBecomeMentor(
  WidgetTester tester,
  MentorWorld world, {
  Map<String, Reply> extra = const {},
  FilePick? pickPhoto,
  FilePick? pickDocument,
  double height = 9000,
  FakeApi? api,
}) async {
  phone(tester, height: height);
  final fake = api ?? world.api(extra: extra);
  final rec = LinkRecorder();
  await pumpApp(
    tester,
    BecomeMentorScreen(
      repository: BecomeMentorRepository(api: fake.client()),
      links: rec.links,
      pickPhoto: pickPhoto ?? () async => null,
      pickDocument: pickDocument ?? () async => null,
    ),
  );
  return (fake, rec);
}
