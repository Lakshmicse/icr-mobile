import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../account_models.dart';
import '../account_rules.dart';

/// The line under a profile's headline, as LinkedIn draws it: the company the
/// person works at and the school they went to ("Table Space · University of
/// Mysore"), both taken from the profile's own Experience and Education.
///
/// Edit Intro's "Organisation" and "Education" choose them, as LinkedIn's do:
/// Organisation offers the CURRENT roles, Education the qualifications, and
/// "Please Select" shows neither. With nothing chosen the line follows
/// LinkedIn's default: the current role that started last, then the newest
/// qualification.
///
/// The API has no field for the choice (`PATCH /users/me` strips unknown keys,
/// and `PUT /profile/experience` stores rows in date order whatever order is
/// sent), so it is kept on this phone, per account. Every other reader of the
/// profile (another member's phone, the website) sees the default.

/// What Edit Intro chose. Null is "not chosen" (the default applies); an empty
/// string is "Please Select" (show none); anything else is the organisation's
/// or the school's name.
class IntroChoice {
  const IntroChoice({this.organisation, this.school});

  static const automatic = IntroChoice();

  final String? organisation;
  final String? school;

  IntroChoice withOrganisation(String? value) => IntroChoice(organisation: value, school: school);
  IntroChoice withSchool(String? value) => IntroChoice(organisation: organisation, school: value);

  Map<String, Object?> toJson() => {'organisation': organisation, 'school': school};

  factory IntroChoice.fromJson(Map<String, dynamic> json) =>
      IntroChoice(organisation: json['organisation'] as String?, school: json['school'] as String?);

  @override
  bool operator ==(Object other) =>
      other is IntroChoice && other.organisation == organisation && other.school == school;

  @override
  int get hashCode => Object.hash(organisation, school);
}

String _key(String s) => s.trim().toLowerCase();

/// What "Organisation" offers: the current roles, the one that started last
/// first (the API's `personCompanyLabel` order; equal dates keep their order),
/// one per organisation.
List<Experience> introRoles(List<Experience> roles) {
  final current = newerFirst<Experience>([
    for (final r in roles)
      if (r.isCurrent && r.organisation.trim().isNotEmpty) r,
  ], (r) => [r.startYear * 12 + (r.startMonth ?? 0)]);
  final seen = <String>{};
  return [
    for (final r in current)
      if (seen.add(_key(r.organisation))) r,
  ];
}

/// What "Education" offers: the qualifications newest first (as the profile
/// lists them), one per school.
List<Education> introSchools(List<Education> ordered) {
  final seen = <String>{};
  return [
    for (final e in ordered)
      if (e.institution.trim().isNotEmpty && seen.add(_key(e.institution))) e,
  ];
}

/// The role "Organisation" stands on: the chosen one while it is still a
/// current role, else the default; null for "Please Select" or no current role.
Experience? introRoleFor(List<Experience> options, String? chosen) {
  if (chosen != null && chosen.isEmpty) return null;
  if (chosen != null) {
    for (final r in options) {
      if (_key(r.organisation) == _key(chosen)) return r;
    }
  }
  return options.firstOrNull;
}

/// The qualification "Education" stands on, the same way.
Education? introSchoolFor(List<Education> options, String? chosen) {
  if (chosen != null && chosen.isEmpty) return null;
  if (chosen != null) {
    for (final e in options) {
      if (_key(e.institution) == _key(chosen)) return e;
    }
  }
  return options.firstOrNull;
}

/// "Company · School", or whichever of the two there is; null when neither.
///
/// [actingFor] is the company the person acts for: someone with no current
/// role on their profile is still named with it, as the API's cards do, unless
/// they chose "Please Select".
String? introLine({
  required List<Experience> roles,
  required List<Education> education,
  IntroChoice choice = IntroChoice.automatic,
  String? actingFor,
}) {
  final options = introRoles(roles);
  final role = introRoleFor(options, choice.organisation);
  final fallback = actingFor?.trim() ?? '';
  final company =
      role?.organisation.trim() ??
      (options.isEmpty && choice.organisation == null && fallback.isNotEmpty ? fallback : null);
  final school = introSchoolFor(introSchools(education), choice.school)?.institution.trim();
  final line = [?company, ?school].join(' · ');
  return line.isEmpty ? null : line;
}

/// Where the choice is kept between launches.
abstract class IntroChoiceStore {
  Future<IntroChoice> load(String userId);
  Future<void> save(String userId, IntroChoice choice);
}

/// On the phone, per account: the key carries the person's id, so a second
/// account on the same phone keeps its own.
class SecureIntroChoiceStore implements IntroChoiceStore {
  SecureIntroChoiceStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _keyFor(String userId) => 'icr.profile.intro.v1.$userId';

  @override
  Future<IntroChoice> load(String userId) async {
    try {
      final raw = await _storage.read(key: _keyFor(userId));
      if (raw == null) return IntroChoice.automatic;
      return IntroChoice.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      // A store that cannot be read is the default line, never a failed page.
      return IntroChoice.automatic;
    }
  }

  @override
  Future<void> save(String userId, IntroChoice choice) async {
    try {
      await _storage.write(key: _keyFor(userId), value: jsonEncode(choice.toJson()));
    } catch (_) {}
  }
}

/// Kept in memory only: tests, the demo.
class MemoryIntroChoiceStore implements IntroChoiceStore {
  MemoryIntroChoiceStore([Map<String, IntroChoice>? initial]) : _choices = {...?initial};

  final Map<String, IntroChoice> _choices;

  @override
  Future<IntroChoice> load(String userId) async => _choices[userId] ?? IntroChoice.automatic;

  @override
  Future<void> save(String userId, IntroChoice choice) async => _choices[userId] = choice;
}
