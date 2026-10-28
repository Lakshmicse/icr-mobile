import 'package:flutter/foundation.dart';

import '../../../core/api/api_error.dart';
import '../account_models.dart';
import '../account_repository.dart';
import '../account_rules.dart';

/// One part of the profile page: what was read, whether a read is running, and
/// why it failed. Each section reads and fails on its own, so one list that
/// cannot be read never blanks the page.
class Section<T> {
  T? value;
  bool loading = true;
  String? error;

  bool get ready => value != null;
}

/// The person's own profile page: the account row with its résumé, the career
/// lists, the links and the credentials, each read on its own, and every edit a
/// sheet makes.
///
/// A write is made by the page's own sheets, which show the API's refusal
/// beside their Save and keep what was typed: every method here throws an
/// [ApiError] carrying the API's own sentence, and leaves the page as it was
/// when it does. The experience, education and career-break lists are saved
/// WHOLE (`PUT` replaces every row and hands back new ids), so a sheet edits
/// one item and the controller merges it into the list it holds; the buttons
/// wait for the list to load, since saving against nothing would wipe it.
class MyProfileController extends ChangeNotifier {
  MyProfileController(this.repository, {this.onIdentityChanged, DateTime Function()? clock}) : clock = clock ?? DateTime.now;

  final AccountRepository repository;

  /// The name, photo or headline changed: the app's header and menus read them
  /// from the session, so it is read again (`AuthController.refreshUser`).
  final Future<void> Function()? onIdentityChanged;

  /// "Now", for the career gaps and the durations.
  final DateTime Function() clock;

  final profile = Section<MyProfile>();
  final experience = Section<List<Experience>>();
  final education = Section<List<Education>>();
  final breaks = Section<List<CareerBreak>>();
  final links = Section<ProfileLinks>();
  final credentials = Section<List<Credential>>();

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // --- reading -----------------------------------------------------------------------------------------------

  /// Reads every section at once.
  Future<void> load() => Future.wait([
    _read(profile, repository.myProfile),
    _read(experience, repository.experience),
    _read(education, repository.education),
    _read(breaks, repository.careerBreaks),
    _read(links, repository.links),
    _read(credentials, repository.credentials),
  ]);

  /// Pull to refresh: what is on screen stays while it reads again.
  Future<void> refresh() => Future.wait([
    _read(profile, repository.myProfile, keep: true),
    _read(experience, repository.experience, keep: true),
    _read(education, repository.education, keep: true),
    _read(breaks, repository.careerBreaks, keep: true),
    _read(links, repository.links, keep: true),
    _read(credentials, repository.credentials, keep: true),
  ]);

  /// A section's "Try again".
  Future<void> retry(Section<Object?> section) {
    if (identical(section, profile)) return _read(profile, repository.myProfile);
    if (identical(section, experience)) return _read(experience, repository.experience);
    if (identical(section, education)) return _read(education, repository.education);
    if (identical(section, breaks)) return _read(breaks, repository.careerBreaks);
    if (identical(section, links)) return _read(links, repository.links);
    return _read(credentials, repository.credentials);
  }

  Future<void> _read<T>(Section<T> s, Future<T> Function() read, {bool keep = false}) async {
    if (!keep || !s.ready) {
      s
        ..loading = true
        ..error = null;
      _notify();
    }
    try {
      s.value = await read();
      s.error = null;
    } catch (e) {
      // A pull that fails while something is showing keeps it.
      if (!keep || !s.ready) s.error = ApiError.from(e).message;
    } finally {
      s.loading = false;
      _notify();
    }
  }

  /// Reads the account row again after a write that changes what it shows (the
  /// completeness, the headline). A failure here is not the write's failure.
  Future<void> _reloadProfile() => _read(profile, repository.myProfile, keep: true);

  Future<void> _identity() async {
    try {
      await onIdentityChanged?.call();
    } catch (_) {}
  }

  // --- the timeline ------------------------------------------------------------------------------------------

  /// Roles and breaks in the order people read a career: what is still going on first.
  List<TimelineEntry> get timeline {
    final roles = experience.value ?? const <Experience>[];
    final pauses = breaks.value ?? const <CareerBreak>[];
    final entries = <TimelineEntry>[
      for (final r in roles) TimelineEntry.role(r),
      for (final b in pauses) TimelineEntry.pause(b),
    ];
    final ordered = newerFirst<TimelineEntry>(entries, (e) => experienceKeys(e.dates));
    if (!experience.ready || !breaks.ready) return ordered;
    final gaps = careerGaps([for (final r in roles) _datesOf(r)], breaks: [for (final b in pauses) _datesOf(b)], now: clock());
    return newerFirst<TimelineEntry>([...ordered, for (final g in gaps) TimelineEntry.gap(g)], (e) => experienceKeys(e.dates));
  }

  static TimelineDates _datesOf(Object r) => switch (r) {
    Experience() => (startYear: r.startYear, startMonth: r.startMonth, endYear: r.endYear, endMonth: r.endMonth, isCurrent: r.isCurrent),
    CareerBreak() => (startYear: r.startYear, startMonth: r.startMonth, endYear: r.endYear, endMonth: r.endMonth, isCurrent: r.isCurrent),
    _ => (startYear: null, startMonth: null, endYear: null, endMonth: null, isCurrent: false),
  };

  /// Qualifications in date order.
  List<Education> get educationOrdered => newerFirst<Education>(
    education.value ?? const [],
    (e) => educationKeys((startYear: e.startYear, startMonth: null, endYear: e.endYear, endMonth: null, isCurrent: false)),
  );

  // --- the intro ---------------------------------------------------------------------------------------------

  /// Name, headline, years and city. The headline is the person's role
  /// (`User.designation`, which a mentor card also reads); for anyone with a
  /// résumé it is the résumé's job title too, as at sign-up. A blank headline
  /// leaves the résumé's title alone: a résumé needs a name.
  Future<void> saveIntro({
    required String firstName,
    required String lastName,
    required String headline,
    int? years,
    required String location,
  }) async {
    final me = profile.value;
    await repository.updateMe({
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'designation': headline.trim(),
      'yearsExperience': years,
    });
    final title = headline.trim();
    final place = location.trim();
    final retitle = title.isNotEmpty && title != (me?.jobTitle ?? '').trim();
    final relocate = place != (me?.location ?? '').trim();
    if (me != null && me.hasResume && (retitle || relocate)) {
      await repository.updateResume({if (retitle) 'jobTitle': title, if (relocate) 'location': place});
    }
    await _reloadProfile();
    await _identity();
  }

  // --- photo and cover ---------------------------------------------------------------------------------------

  /// Uploads the picture and makes it the profile photo.
  Future<void> uploadPhoto(PickedPhoto photo) async {
    final file = await repository.upload(photo);
    await repository.updateMe({'avatarUrl': file.url});
    await _reloadProfile();
    await _identity();
  }

  Future<void> removePhoto() async {
    await repository.updateMe({'avatarUrl': ''});
    await _reloadProfile();
    await _identity();
  }

  /// Makes [cover] (a ready-made cover's id, or an `/uploads/...` path) the
  /// banner; null takes it away.
  Future<void> setCover(String? cover) async {
    await repository.updateMe({'coverImage': cover});
    await _reloadProfile();
    await _identity();
  }

  /// Uploads the picture and makes it the banner.
  Future<String> uploadCover(PickedPhoto photo) async {
    final file = await repository.upload(photo);
    await setCover(file.url);
    return file.url;
  }

  // --- about, skills, languages ------------------------------------------------------------------------------

  Future<void> saveAbout(String summary) async {
    final p = await repository.updateResume({'summary': summary.trim()});
    profile.value = p;
    _notify();
  }

  Future<void> saveSkills(List<String> skills) async {
    final p = await repository.updateResume({'skills': skills});
    profile.value = p;
    _notify();
  }

  Future<void> saveLanguages(List<String> languages) async {
    final p = await repository.updateMe({'languages': languages});
    profile.value = p;
    _notify();
  }

  // --- experience, education, career breaks ------------------------------------------------------------------

  List<Experience> _rolesOrThrow() {
    final rows = experience.value;
    if (rows == null) throw ApiError("Your experience hasn't loaded yet. Try again in a moment.");
    return rows;
  }

  /// Adds [role] (no id) or replaces the saved role with its id.
  Future<void> saveRole(Experience role) async {
    final rows = [..._rolesOrThrow()];
    if (role.id == null) {
      rows.add(role);
    } else {
      final at = rows.indexWhere((r) => r.id == role.id);
      if (at < 0) throw ApiError('That role is no longer on your profile. Pull to refresh.');
      rows[at] = role;
    }
    experience.value = await repository.saveExperience(rows);
    _notify();
    await _reloadProfile();
  }

  Future<void> deleteRole(String id) async {
    experience.value = await repository.saveExperience([
      for (final r in _rolesOrThrow())
        if (r.id != id) r,
    ]);
    _notify();
    await _reloadProfile();
  }

  List<Education> _degreesOrThrow() {
    final rows = education.value;
    if (rows == null) throw ApiError("Your education hasn't loaded yet. Try again in a moment.");
    return rows;
  }

  Future<void> saveDegree(Education degree) async {
    final rows = [..._degreesOrThrow()];
    if (degree.id == null) {
      rows.add(degree);
    } else {
      final at = rows.indexWhere((r) => r.id == degree.id);
      if (at < 0) throw ApiError('That qualification is no longer on your profile. Pull to refresh.');
      rows[at] = degree;
    }
    education.value = await repository.saveEducation(rows);
    _notify();
    await _reloadProfile();
  }

  Future<void> deleteDegree(String id) async {
    education.value = await repository.saveEducation([
      for (final r in _degreesOrThrow())
        if (r.id != id) r,
    ]);
    _notify();
    await _reloadProfile();
  }

  List<CareerBreak> _breaksOrThrow() {
    final rows = breaks.value;
    if (rows == null) throw ApiError("Your career breaks haven't loaded yet. Try again in a moment.");
    return rows;
  }

  Future<void> savePause(CareerBreak pause) async {
    final rows = [..._breaksOrThrow()];
    if (pause.id == null) {
      rows.add(pause);
    } else {
      final at = rows.indexWhere((r) => r.id == pause.id);
      if (at < 0) throw ApiError('That break is no longer on your profile. Pull to refresh.');
      rows[at] = pause;
    }
    breaks.value = await repository.saveCareerBreaks(rows);
    _notify();
  }

  Future<void> deletePause(String id) async {
    breaks.value = await repository.saveCareerBreaks([
      for (final r in _breaksOrThrow())
        if (r.id != id) r,
    ]);
    _notify();
  }

  // --- credentials -------------------------------------------------------------------------------------------

  /// A scan of the certificate, uploaded private (`purpose=credential`).
  Future<UploadedFile> uploadEvidence(PickedPhoto file) => repository.upload(file, purpose: 'credential');

  Future<void> addCredential(CredentialDraft draft) async {
    await repository.addCredential(draft);
    await _read(credentials, repository.credentials, keep: true);
    await _reloadProfile();
  }

  Future<void> updateCredential(String id, CredentialDraft draft) async {
    await repository.updateCredential(id, draft);
    await _read(credentials, repository.credentials, keep: true);
  }

  /// Removes a credential. The sentence when the code was also taken off a
  /// mentor profile, else null.
  Future<String?> deleteCredential(String id) async {
    final removedFromMentor = await repository.deleteCredential(id);
    await _read(credentials, repository.credentials, keep: true);
    return removedFromMentor;
  }

  // --- contact and links -------------------------------------------------------------------------------------

  /// The work email, the second number and the five links, as the Contact info
  /// sheet saves them: the links first, since the API is the one that judges a
  /// web address and a refusal there comes before anything else is written; a
  /// blank field clears one.
  Future<void> saveContact({
    required String workEmail,
    required String altPhone,
    Map<String, String>? changedLinks,
  }) async {
    final me = profile.value;
    if (changedLinks != null && changedLinks.isNotEmpty) {
      links.value = await repository.saveLinks(changedLinks);
      _notify();
    }
    final mail = workEmail.trim();
    final alt = altPhone.trim();
    final patch = <String, Object?>{
      if (mail != (me?.workEmail ?? '')) 'workEmail': mail.isEmpty ? null : mail,
      if (alt != (me?.altPhone ?? '')) 'altPhone': alt.isEmpty ? null : alt,
    };
    if (patch.isNotEmpty) profile.value = await repository.updateMe(patch);
    _notify();
  }
}

/// One line of the Experience timeline: a role, a break, or a gap between them.
class TimelineEntry {
  const TimelineEntry._(this.role, this.pause, this.gap);

  factory TimelineEntry.role(Experience r) => TimelineEntry._(r, null, null);
  factory TimelineEntry.pause(CareerBreak b) => TimelineEntry._(null, b, null);
  factory TimelineEntry.gap(CareerGap g) => TimelineEntry._(null, null, g);

  final Experience? role;
  final CareerBreak? pause;
  final CareerGap? gap;

  TimelineDates get dates {
    final r = role;
    if (r != null) {
      return (startYear: r.startYear, startMonth: r.startMonth, endYear: r.endYear, endMonth: r.endMonth, isCurrent: r.isCurrent);
    }
    final b = pause;
    if (b != null) {
      return (startYear: b.startYear, startMonth: b.startMonth, endYear: b.endYear, endMonth: b.endMonth, isCurrent: b.isCurrent);
    }
    final g = gap!;
    return (
      startYear: g.fromYear,
      startMonth: g.fromMonth,
      endYear: g.ongoing ? null : g.toYear,
      endMonth: g.ongoing ? null : g.toMonth,
      isCurrent: g.ongoing,
    );
  }
}
