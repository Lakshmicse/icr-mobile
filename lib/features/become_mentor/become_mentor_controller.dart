import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import '../mentorship_my/loader.dart';
import 'become_mentor_models.dart';
import 'become_mentor_repository.dart';
import 'become_mentor_rules.dart';

/// The pop-up a line of the checklist opens (the website's `dialogForField`).
enum FixTarget {
  photo,
  intro,
  languages,
  experience,
  bio,
  expertise,
  audience,
  availability,
  certifications,
  training,
  conduct,
}

/// One thing still needed before submitting, and where it is fixed.
class Need {
  const Need(this.target, this.message);

  final FixTarget target;
  final String message;
}

/// One step of the application's progress bar.
class Step {
  const Step(this.label, this.done);

  final String label;
  final bool done;
}

/// The become-a-mentor page: the caller's mentor profile and the person behind it, the gates (code of conduct,
/// training, evidence), and every write on them. An action answers the API's refusal as a sentence, or null when
/// it went through, and reads again what it changed.
class BecomeMentorController extends ChangeNotifier {
  BecomeMentorController(this.repository) {
    profile = Loader(repository.mine, _notify);
    readiness = Loader(repository.readiness, _notify);
    person = Loader(repository.person, _notify);
    experience = Loader(repository.experience, _notify);
    credentials = Loader(repository.credentials, _notify);
    conduct = Loader(repository.codeOfConduct, _notify);
    documents = Loader(repository.documents, _notify);
    jobTitles = Loader(repository.jobTitles, _notify);
  }

  final BecomeMentorRepository repository;

  /// The mentor profile; `data` is null both before it loads and when the member has none: read [loaded].
  late final Loader<MyMentorProfile?> profile;
  late final Loader<MentorReadiness> readiness;
  late final Loader<PersonProfile> person;
  late final Loader<List<ExperienceRow>> experience;
  late final Loader<List<HeldCredential>> credentials;
  late final Loader<CodeOfConduct> conduct;
  late final Loader<List<MentorDocument>> documents;
  late final Loader<List<String>> jobTitles;

  bool _disposed = false;
  bool _started = false;
  bool _busy = false;

  bool get started => _started;

  /// A write is in flight.
  bool get busy => _busy;

  /// The first screenful: the profile, where it stands and the person behind it.
  Future<void> start() {
    if (_started) return Future.value();
    _started = true;
    return refresh();
  }

  Future<void> refresh() async {
    await Future.wait([
      profile.load(),
      readiness.load(),
      person.load(),
      experience.load(),
      credentials.load(),
      conduct.ensure(),
    ]);
    if (profile.data != null) await documents.load();
  }

  /// What the page shows while its first reads are out.
  bool get loading => !_firstScreenLoaded && (profile.loading || person.loading || readiness.loading);

  bool get _firstScreenLoaded => profile.loaded && person.loaded && readiness.loaded;

  /// The first reads failed (and nothing was shown): the API's sentence.
  String? get error => !_firstScreenLoaded ? (profile.error ?? person.error ?? readiness.error) : null;

  // --- derived --------------------------------------------------------------------

  MyMentorProfile? get mentor => profile.data;
  bool get hasProfile => mentor != null;
  MentorStatus get status => mentor?.status ?? MentorStatus.draft;

  /// Required training, when the API has any configured.
  TrainingStatus get training => readiness.data?.training ?? const TrainingStatus();
  bool get trainingRequired => training.requiredCount > 0;
  bool get conductAccepted => readiness.data?.conductAccepted ?? false;

  /// The credentials on the card that the member no longer holds.
  List<String> get staleCertifications {
    if (!credentials.loaded) return const [];
    final held = {for (final c in credentials.data ?? const <HeldCredential>[]) c.code};
    return [
      for (final c in mentor?.certifications ?? const <String>[])
        if (!held.contains(c.toUpperCase())) c,
    ];
  }

  /// The person's side as the rules read it.
  MentorPersonFacts get personFacts => MentorPersonFacts(
    avatarUrl: person.data?.avatarUrl,
    designation: person.data?.designation,
    yearsExperience: person.data?.yearsExperience,
    languages: person.data?.languages,
    experienceCount: experience.data?.length ?? 0,
  );

  MentorProfileFacts get profileFacts => MentorProfileFacts(
    bioHtml: mentor?.bioHtml,
    competencies: mentor?.competencies,
    expertiseKeys: mentor?.expertiseKeys,
    topics: mentor?.topics,
    targetRoles: mentor?.targetRoles,
    targetAudiences: mentor?.targetAudiences,
    availabilityNote: mentor?.availabilityNote,
  );

  static FixTarget _personTarget(MentorPersonField f) => switch (f) {
    MentorPersonField.avatarUrl => FixTarget.photo,
    MentorPersonField.designation || MentorPersonField.yearsExperience => FixTarget.intro,
    MentorPersonField.languages => FixTarget.languages,
    MentorPersonField.experience => FixTarget.experience,
  };

  static FixTarget _profileTarget(MentorProfileField f) => switch (f) {
    MentorProfileField.bioHtml => FixTarget.bio,
    MentorProfileField.competencies || MentorProfileField.topics => FixTarget.expertise,
    MentorProfileField.targetRoles || MentorProfileField.targetAudiences => FixTarget.audience,
    MentorProfileField.availabilityNote => FixTarget.availability,
  };

  /// The profile's own problems for a submit (the person's, the mentoring half's, a stale certification), the
  /// same list the API applies at submit, each naming where it is fixed.
  List<Need> get profileNeeds => [
    for (final p in mentorPersonProblems(personFacts, forSubmit: true)) Need(_personTarget(p.field), p.message),
    for (final p in mentorProfileProblems(profileFacts, forSubmit: true)) Need(_profileTarget(p.field), p.message),
    if (staleCertifications.isNotEmpty)
      Need(
        FixTarget.certifications,
        'Remove ${staleCertifications.join(', ')} from your certifications — no longer on your profile.',
      ),
  ];

  /// Everything still needed to submit: the profile's problems, then training.
  List<Need> get needed => [
    ...profileNeeds,
    if (trainingRequired && !(readiness.data?.trainingComplete ?? false))
      Need(
        FixTarget.training,
        'Finish mentor training (${training.completedCount} of ${training.requiredCount} modules).',
      ),
  ];

  /// Ready to submit: nothing needed, and the code of conduct agreed.
  bool get ready => needed.isEmpty && conductAccepted;

  List<Step> get steps => [
    Step('Your profile', hasProfile && profileNeeds.isEmpty),
    Step('Code of conduct', conductAccepted),
    if (trainingRequired) Step('Mentor training', readiness.data?.trainingComplete ?? false),
    Step(
      status.listed
          ? 'Listed in the directory'
          : status == MentorStatus.pending
          ? 'ICR review — in progress'
          : 'ICR review',
      status.listed,
    ),
  ];

  // --- writes ---------------------------------------------------------------------

  /// Saves the mentoring half (a partial patch; the first save creates the DRAFT).
  Future<String?> saveProfile(Map<String, dynamic> patch) => _act(() async {
    profile.data = await repository.save(patch);
    profile.loaded = true;
    _notify();
    await readiness.load();
  });

  /// Records the agreement to the code of conduct, creating the (empty) draft first when there is none.
  Future<String?> agreeToConduct() => _act(() async {
    await conduct.ensure();
    final version = conduct.data?.version;
    if (version == null || version.isEmpty) {
      throw ApiError('The code of conduct has not loaded yet — try again in a moment.');
    }
    if (!hasProfile) {
      profile.data = await repository.save(const {});
      profile.loaded = true;
    }
    await repository.acceptConduct(version);
    await Future.wait([readiness.load(), profile.load()]);
  });

  /// Sends the profile for review.
  Future<String?> submit() => _act(() async {
    profile.data = await repository.submit();
    _notify();
    await readiness.load();
  });

  /// Takes the profile off the directory (the API refuses while mentorships are under way).
  Future<String?> withdraw() => _act(() async {
    await repository.withdraw();
    profile.data = null;
    documents.reset();
    _notify();
    await readiness.load();
  });

  Future<String?> setVisibility(bool on) => _act(() async {
    profile.data = await repository.setVisibility(on);
    _notify();
  });

  Future<String?> saveHours(List<AvailabilityBlock> blocks) => _act(() async {
    profile.data = await repository.saveAvailability(blocks);
    _notify();
  });

  /// Writes the person's own fields, then reads them (and what depends on them) again.
  Future<String?> savePerson(Map<String, dynamic> patch) => _act(() async {
    await repository.updatePerson(patch);
    await Future.wait([person.load(), readiness.load(), if (hasProfile) profile.load()]);
  });

  Future<String?> uploadPhoto(PickedFile file) => _act(() async {
    final up = await repository.upload(file, purpose: 'avatar');
    await repository.updatePerson({'avatarUrl': up.url});
    await Future.wait([person.load(), readiness.load()]);
  });

  Future<String?> removePhoto() => savePerson({'avatarUrl': ''});

  /// Saves the whole career history.
  Future<String?> saveExperience(List<ExperienceRow> rows) => _act(() async {
    await repository.replaceExperience(rows);
    await Future.wait([experience.load(), readiness.load()]);
  });

  Future<String?> addDocument(PickedFile file, {required String kind, String? label}) => _act(() async {
    final up = await repository.upload(file, purpose: 'mentor-screening');
    await repository.addDocument(kind: kind, fileUrl: up.url, label: label, fileName: up.name, fileSize: up.size);
    await Future.wait([documents.load(), readiness.load()]);
  });

  Future<String?> removeDocument(MentorDocument d) => _act(() async {
    await repository.removeDocument(d.id);
    await Future.wait([documents.load(), readiness.load()]);
  });

  Future<String?> _act(Future<void> Function() action) async {
    _busy = true;
    _notify();
    try {
      await action();
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    } finally {
      _busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
