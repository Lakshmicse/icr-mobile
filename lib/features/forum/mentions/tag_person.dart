import 'package:flutter/foundation.dart';

import 'mention_person.dart';
import 'tag_suggestions.dart';

/// A tag written as a person ("#@prashant", as members tagged people before the "@" list existed, or
/// "#@vinay-kumar", a person picked from it): the name after the "@", with "_", "." and "-" read as spaces. Null
/// for any other tag, and for a name too short to look up.
String? personTagName(String tag) {
  final handle = personTagHandle(tag);
  if (handle == null) return null;
  final name = handle.replaceAll(RegExp(r'[_.\-\s]+'), ' ').trim();
  return name.length < 2 ? null : name;
}

/// The text after the "@" of a person's tag as the forum stores it ("vinay-kumar"): a profile handle when the tag
/// was picked from the "@" list. Null for any other tag.
String? personTagHandle(String tag) {
  var t = tag.trim();
  if (t.startsWith('#')) t = t.substring(1);
  if (!t.startsWith('@')) return null;
  final handle = t.substring(1).trim().toLowerCase();
  return handle.isEmpty ? null : handle;
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

/// A person's tag tapped ("#@vinay-kumar", "#@prashant"): opens what it names, and otherwise does nothing (owner,
/// 3 Nov 2026: such a tag never opens the Forums tab, and a name with nothing behind it leaves the screen as it
/// is). In turn: the member whose profile handle it is ([byHandle], exact — what a pick from the Tags "@" list
/// writes); the one member [search] finds by that name; the one company [searchCompanies] lists under that name
/// (a company picked from the list). Answers whether anything was opened; any other tag answers false at once.
Future<bool> openTaggedPerson(
  String tag, {
  required MentionSearch search,
  required ValueChanged<String>? onOpenMember,
  Future<String?> Function(String handle)? byHandle,
  TagCompanySearch? searchCompanies,
  ValueChanged<String>? onOpenCompany,
}) async {
  final handle = personTagHandle(tag);
  final name = personTagName(tag);
  if (handle == null || name == null) return false;

  Future<T?> attempt<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (_) {
      // No answer (offline, or an API without the route): the same as no one.
      return null;
    }
  }

  if (onOpenMember != null) {
    if (byHandle != null) {
      final id = await attempt(() => byHandle(handle));
      if (id != null) {
        onOpenMember(id);
        return true;
      }
    }
    final person = personNamed(name, await attempt(() => search(name)) ?? const []);
    if (person != null) {
      onOpenMember(person.id);
      return true;
    }
  }
  if (searchCompanies != null && onOpenCompany != null) {
    final companies = await attempt(() => searchCompanies(name)) ?? const <TagCompany>[];
    final named = companies.where((c) => tagHandleOf(c.name) == tagHandleOf(handle)).toList();
    if (named.length == 1) {
      onOpenCompany(named.single.id);
      return true;
    }
  }
  return false;
}
