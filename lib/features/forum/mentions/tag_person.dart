import 'package:flutter/foundation.dart';

import 'mention_person.dart';

/// A tag written as a person ("#@prashant"), as members tagged people before the "@" list existed: the name after the
/// "@", with "_", "." and "-" read as spaces. Null for any other tag, and for a name too short to look up.
String? personTagName(String tag) {
  var t = tag.trim();
  if (t.startsWith('#')) t = t.substring(1);
  if (!t.startsWith('@')) return null;
  final name = t.substring(1).replaceAll(RegExp(r'[_.\-\s]+'), ' ').trim();
  return name.length < 2 ? null : name;
}

/// Who [name] means among the people the forum [found]: the one whose first name, last name or whole name it is
/// (any case, spaces ignored), else the only person found. Null when nobody fits, or several do.
MentionPerson? personNamed(String name, List<MentionPerson> found) {
  String key(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  final want = key(name);
  final exact = found
      .where((p) => key(p.firstName) == want || key(p.lastName) == want || key(p.name) == want)
      .toList();
  if (exact.length == 1) return exact.single;
  if (exact.isEmpty && found.length == 1) return found.single;
  return null;
}

/// A person tag tapped: opens that person's profile through [onOpenMember] when [search] finds exactly them, and
/// otherwise does nothing (owner, 3 Nov 2026: "#@prashant" never opens the Forums tab, and a name with no profile
/// leaves the screen as it is). Answers whether a profile was opened; any other tag answers false at once.
Future<bool> openTaggedPerson(
  String tag, {
  required MentionSearch search,
  required ValueChanged<String>? onOpenMember,
}) async {
  final name = personTagName(tag);
  if (name == null || onOpenMember == null) return false;
  final List<MentionPerson> found;
  try {
    found = await search(name);
  } catch (_) {
    // No answer (offline, or an API without `/members/mentionable`): the same as no profile.
    return false;
  }
  final person = personNamed(name, found);
  if (person == null) return false;
  onOpenMember(person.id);
  return true;
}
