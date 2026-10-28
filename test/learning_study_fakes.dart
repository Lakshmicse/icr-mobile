/// A stand-in for the portal's Resource Center, for the study tests: an HTTP adapter that answers the study
/// screens' calls from the recorded responses of the local API (`test/fixtures/learning_study/`), keeps the
/// member's stars the way the API does, and can refuse a deck, a star or the whole list on demand.
///
/// Everything goes through the real `ApiStudyRepository`, so a screen test also proves the JSON mapping.
library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/auth/token_store.dart';
import 'package:icr_mobile/features/learning_study/api_study_repository.dart';

class NoTokens extends TokenStore {
  @override
  Future<String?> accessToken() async => 'token';
  @override
  Future<String?> refreshToken() async => null;
}

Object fixture(String name) => jsonDecode(File('test/fixtures/learning_study/$name.json').readAsStringSync()) as Object;

Map<String, dynamic> fixtureMap(String name) => (fixture(name) as Map).cast<String, dynamic>();

/// A deck of [count] cards in [categories] categories, for tests that need more cards than the recorded 14.
Map<String, dynamic> bigDeck(String slug, {int count = 20, int categories = 4}) => {
  'id': 'topic-$slug',
  'slug': slug,
  'title': 'Deck $slug',
  'kind': 'QNA',
  'cardCount': count,
  'imageUrl': null,
  'sortOrder': 0,
  'cards': [
    for (var i = 0; i < count; i++)
      {
        'id': '$slug-c$i',
        'topicId': 'topic-$slug',
        'front': 'Question $i of $slug?',
        'back': 'Answer $i of $slug.',
        'example': null,
        'examples': null,
        'resourceUrl': null,
        'resourceLabel': null,
        'category': 'Category ${i % categories}',
        'tags': ['Beginner'],
        'sortOrder': i,
        'active': true,
      },
  ],
};

class FakePortal implements HttpClientAdapter {
  FakePortal({
    String unlocks = 'paper_unlocks_study',
    Iterable<String> locked = const [],
    Iterable<String> starred = const [],
    this.unread = 0,
  }) : unlocks = fixtureMap(unlocks),
       locked = {...locked},
       starred = [...starred];

  /// What `GET /learning/me/paper-unlocks` answers.
  Map<String, dynamic> unlocks;

  /// Deck slugs the API refuses (403 DECK_LOCKED), with [lockMessage] as its sentence.
  final Set<String> locked;
  String lockMessage = 'Your plan opens 3 flash-card decks, and you have opened them all.';

  /// Deck slugs the API refuses because the Assess your knowledge course they belong with is closed (403
  /// DECK_LOCKED naming `course` and `opens`): slug → the course (`id`, `code`, `title`). Take a slug out and the
  /// deck opens, as it does once its course does.
  final Map<String, Map<String, String>> lockedByCourse = {};

  /// Card ids the member has starred, newest first.
  final List<String> starred;

  /// When set, a star or unstar is answered with this status and sentence.
  int? starStatus;
  String starMessage = 'Starring is not available right now.';

  /// When set, `GET /learning/resources` is answered with a 500 and this sentence.
  String? listFails;

  /// Shelves (or decks) whose own call fails with a 500.
  final Set<String> shelfFails = {};

  int unread;

  /// Decks and shelves served beyond the recorded ones, by slug.
  final Map<String, Map<String, dynamic>> extra = {};

  /// A resource list other than the recorded one.
  List<Object?>? list;

  /// Every call, `METHOD path`.
  final List<String> calls = [];

  static final _json = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };

  ResponseBody _ok(Object body) => ResponseBody.fromString(jsonEncode(body), 200, headers: _json);
  ResponseBody _err(int status, String message, [Map<String, Object?> more = const {}]) =>
      ResponseBody.fromString(jsonEncode({'statusCode': status, 'message': message, ...more}), status, headers: _json);

  Map<String, dynamic>? _shelf(String slug) {
    if (extra.containsKey(slug)) return extra[slug];
    const recorded = {'time-value-of-money', 'cost-analysis', 'depreciation-analysis', 'corporate-real-estate-cre'};
    if (recorded.contains(slug)) return fixtureMap('shelf_$slug');
    if (slug == 'capital-planning') return fixtureMap('deck_capital-planning');
    final row = ((list ?? fixture('resources_list')) as List).cast<Map>().where((r) => r['slug'] == slug);
    if (row.isEmpty) return null;
    return bigDeck(slug, count: 3, categories: 1)..['title'] = row.first['title'];
  }

  /// The member's starred cards as the API lists them: the card, its shelf and when.
  List<Map<String, dynamic>> _starList() {
    final out = <Map<String, dynamic>>[];
    final all = <Map<String, dynamic>>[
      for (final slug in ['capital-planning', ...extra.keys])
        if (_shelf(slug) != null) _shelf(slug)!,
    ];
    for (final id in starred) {
      for (final topic in all) {
        for (final c in (topic['cards'] as List).cast<Map<String, dynamic>>()) {
          if (c['id'] == id) {
            out.add({
              ...c,
              'topic': {'id': topic['id'], 'slug': topic['slug'], 'title': topic['title'], 'kind': topic['kind']},
              'starredAt': '2026-10-23T12:00:00.000Z',
            });
          }
        }
      }
    }
    return out;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add('${options.method} ${options.path}');
    final path = options.path;
    if (path == '/learning/resources' && options.method == 'GET') {
      return listFails != null ? _err(500, listFails!) : _ok(list ?? fixture('resources_list'));
    }
    if (path.startsWith('/learning/resources/') && options.method == 'GET') {
      final slug = Uri.decodeComponent(path.substring('/learning/resources/'.length));
      if (shelfFails.contains(slug)) return _err(500, 'The shelf $slug is not available.');
      final course = lockedByCourse[slug];
      if (course != null) {
        return _err(
          403,
          'These flash cards open with “${course['title']}”. Your plan includes 3 Assess your knowledge courses, and 3 are still free: open the course with your plan to read its cards and sit its levels.',
          {
            'code': 'DECK_LOCKED',
            'key': 'learning.assessmentCourses',
            'reason': 'PICK',
            'plan': null,
            'pricingSlug': 'professional',
            'opens': {'target': 'COURSE', 'id': course['id']},
            'placesLeft': 3,
            'course': course,
          },
        );
      }
      if (locked.contains(slug)) {
        return _err(403, lockMessage, {
          'code': 'DECK_LOCKED',
          'key': 'learning.assessmentCourses',
          'reason': 'DECKS',
          'plan': null,
          'pricingSlug': 'professional',
        });
      }
      final shelf = _shelf(slug);
      return shelf == null ? _err(404, 'Resource topic not found') : _ok(shelf);
    }
    if (path == '/learning/me/paper-unlocks') return _ok(unlocks);
    if (path == '/learning/me/resource-stars' && options.method == 'GET') return _ok(_starList());
    if (path.startsWith('/learning/me/resource-stars/')) {
      final id = Uri.decodeComponent(path.substring('/learning/me/resource-stars/'.length));
      if (starStatus != null) {
        return _err(
          starStatus!,
          starMessage,
          starStatus == 403 ? {'code': 'DECK_LOCKED', 'pricingSlug': 'professional'} : const {},
        );
      }
      if (options.method == 'PUT') {
        starred.remove(id);
        starred.insert(0, id);
        return _ok({'cardId': id, 'starred': true});
      }
      starred.remove(id);
      return _ok({'cardId': id, 'starred': false});
    }
    if (path == '/notifications/unread-count') return _ok({'unread': unread});
    return _err(404, 'Not found: $path');
  }

  @override
  void close({bool force = false}) {}
}

ApiStudyRepository repoOn(FakePortal portal) {
  final client = ApiClient(tokens: NoTokens(), baseUrl: 'http://api.test/api/v1');
  client.dio.httpClientAdapter = portal;
  return ApiStudyRepository(api: client);
}

/// The recorded deck list with `capital-planning` and `communication` made to belong with Assess your knowledge
/// courses (`CP`, `COMMUNICAT`), as the API sends it since the decks follow their courses.
List<Object?> linkedDeckList({Set<String> linkedSlugs = const {'capital-planning', 'communication'}}) {
  const courses = {
    'capital-planning': {'id': 'course-cp', 'code': 'CP', 'title': 'Capital Planning'},
    'communication': {'id': 'course-comm', 'code': 'COMMUNICAT', 'title': 'Communication'},
    'collabaration': {'id': 'course-collab', 'code': 'COLLAB', 'title': 'Collaboration'},
    'esg-and-sustainability': {'id': 'course-esg', 'code': 'ESG', 'title': 'ESG and Sustainability'},
  };
  return [
    for (final row in (fixture('resources_list') as List).cast<Map<String, dynamic>>())
      if (linkedSlugs.contains(row['slug']))
        {...row, 'courseId': courses[row['slug']]!['id'], 'course': courses[row['slug']]}
      else
        row,
  ];
}

/// What `GET /learning/me/paper-unlocks` answers: the plan's number (shared by courses and decks), the decks on
/// their own it has opened, the courses it has opened, and the courses of which a level is held on its own.
Map<String, dynamic> unlocksOf({
  int? limit = 3,
  List<String> decks = const [],
  List<String> courses = const [],
  List<String> unlockedCourses = const [],
  bool allOpen = false,
}) => {
  'allOpen': allOpen,
  'paperIds': <String>[],
  'creditPaperIds': <String>[],
  'unlockedCourseIds': unlockedCourses,
  'icrCredits': 10,
  'rupeesPerCredit': 100,
  'plan': {
    'assessmentCourses': {'limit': limit, 'openedCourseIds': courses},
    'mockExams': {'limit': 0, 'openedTopicIds': <String>[]},
    'flashCardDecks': {'limit': limit, 'openedDeckIds': decks},
    'upgradePlan': null,
    'mockUpgradePlan': null,
  },
};
