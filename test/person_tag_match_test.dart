import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/forum/mentions/mention_person.dart';
import 'package:icr_mobile/features/forum/mentions/tag_person.dart';

MentionPerson _p(String id, String first, String last, String slug) =>
    MentionPerson(id: id, firstName: first, lastName: last, slug: slug);

/// The owner, 14 Nov 2026: a person tagged in a post is told, as on WhatsApp. Posts on dev carried "@divyacn" and
/// "@bindhyas", typed by hand; the members' handles are "divya-c-n" and "bindhya-s", so the forum told no one.
void main() {
  final people = [
    _p('u-divya', 'Divya', 'C N', 'divya-c-n'),
    _p('u-divya2', 'Divya', 'Rao', 'divya-rao'),
    _p('u-bindhya', 'Bindhya', 'S', 'bindhya-s'),
    _p('u-prashant', 'Prashant', 'Chari', 'prashant-chari'),
  ];
  final handles = {for (final p in people) p.slug!: p.id};
  final searched = <String>[];

  /// The forum's search: each word must start a first or a last name.
  Future<List<MentionPerson>> search(String q) async {
    searched.add(q);
    final words = q.toLowerCase().split(' ').where((w) => w.isNotEmpty).toList();
    return [
      for (final p in people)
        if (words.every((w) => p.firstName.toLowerCase().startsWith(w) || p.lastName.toLowerCase().startsWith(w))) p,
    ];
  }

  Future<String?> byHandle(String h) async => handles[h];
  Future<PersonTagMatch> match(String typed) => matchPersonTag(typed, byHandle: byHandle, search: search);

  setUp(searched.clear);

  test('a handle typed exactly is kept, with no search', () async {
    expect((await match('@prashant-chari')).tag, '@prashant-chari');
    expect(searched, isEmpty);
  });

  test('a name typed without its spaces finds the member and stores their handle', () async {
    expect((await match('@divyacn')).tag, '@divya-c-n');
    expect((await match('#@bindhyas')).tag, '@bindhya-s');
    expect((await match('@Divya.C.N')).tag, '@divya-c-n');
  });

  test('a first name alone is enough when only one member has it, and refused when several do', () async {
    expect((await match('@prashant')).tag, '@prashant-chari');
    final divya = await match('@divya');
    expect(divya.tag, isNull);
    expect(divya.several, isTrue);
  });

  test('a name nobody has is no one', () async {
    final none = await match('@bindhyarajs');
    expect(none.tag, isNull);
    expect(none.several, isFalse);
    expect((await match('@x')).tag, isNull, reason: 'too short to look up');
  });
}
