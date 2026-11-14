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

/// What a hand-typed person tag came to: the tag to store (the member's own, "@divya-c-n"), or why there is none.
typedef PersonTagMatch = ({String? tag, bool several});

/// The member a person tag typed by hand means ("@divyacn", "@divya-c-n", "@Divya"), so the post carries their own
/// handle and the forum tells them (owner, 14 Nov 2026: tagged people are told, as on WhatsApp; "@divyacn" matched
/// no handle, since Divya C N's is "divya-c-n", and told no one). In turn: the exact handle ([byHandle]); then a
/// member whose whole name or handle is the typed text once spaces and punctuation are dropped ("divyacn" is
/// Divya C N), searching by the words typed and then by the first six, four and three letters, since the forum
/// matches names from their start; then the only member the words find whose first name it is. Several who fit
/// is `several`, nobody is a null tag.
Future<PersonTagMatch> matchPersonTag(
  String typed, {
  required Future<String?> Function(String handle) byHandle,
  required MentionSearch search,
}) async {
  final handle = (personTagHandle(typed) ?? typed.trim().toLowerCase()).replaceAll(RegExp(r'^[-_.]+|[-_.]+$'), '');
  String compact(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  final want = compact(handle);
  if (want.length < 2) return (tag: null, several: false);
  if (await byHandle(handle) != null) return (tag: '@$handle', several: false);

  final words = handle.replaceAll(RegExp(r'[-_.]+'), ' ').trim();
  final queries = <String>{
    words,
    for (final n in const [6, 4, 3])
      if (want.length > n) want.substring(0, n),
  };
  var several = false;
  for (final query in queries) {
    final found = await search(query);
    final byId = <String, MentionPerson>{};
    for (final p in found) {
      if (compact(p.name) == want || compact(p.slug ?? '') == want) byId[p.id] = p;
    }
    if (byId.length == 1) return (tag: tagForPerson(byId.values.single), several: false);
    if (byId.length > 1) return (tag: null, several: true);
    if (query == words) {
      final first = [
        for (final p in found)
          if (compact(p.firstName) == want) p,
      ];
      if (first.length == 1 && found.length == 1) return (tag: tagForPerson(first.single), several: false);
      if (first.length > 1) several = true;
    }
  }
  return (tag: null, several: several);
}

/// Who [name] means among the people the forum [found]: the one whose first name, last name or whole name it is
/// (any case, spaces ignored), else the only person found. Null when nobody fits, or several do.
MentionPerson? personNamed(String name, List<MentionPerson> found) {
  String key(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  final want = key(name);
  final exact = found.where((p) => key(p.firstName) == want || key(p.lastName) == want || key(p.name) == want).toList();
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
