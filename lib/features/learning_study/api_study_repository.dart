import 'package:dio/dio.dart' show DioException, Options;

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/config.dart';
import '../feed/feed_models.dart' show FeedPicture;
import 'study_models.dart';
import 'study_repository.dart';

/// The study screens from the API: the shelves (`GET /learning/resources`), a shelf's cards
/// (`/learning/resources/:slug`), the plan's deck number (`/learning/me/paper-unlocks`) and the member's stars
/// (`/learning/me/resource-stars`).
class ApiStudyRepository implements StudyRepository {
  ApiStudyRepository({required this.api});

  final ApiClient api;

  @override
  Future<List<StudyTopic>> topics() async {
    final rows = await _list('/learning/resources');
    return [for (final r in rows) _topic(r)];
  }

  @override
  Future<StudyTopic> topic(String slug) async {
    try {
      final res = await api.dio.get<Map<String, dynamic>>('/learning/resources/${Uri.encodeComponent(slug)}');
      final json = res.data ?? const <String, dynamic>{};
      final cards = [for (final c in (json['cards'] as List? ?? const []).cast<Map<String, dynamic>>()) _card(c)];
      return _topic(json).withCards(cards);
    } on DioException catch (e) {
      throw _locked(e) ?? ApiError.from(e);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  @override
  Future<DeckPlan?> deckPlan() async {
    try {
      final res = await api.dio.get<Map<String, dynamic>>('/learning/me/paper-unlocks');
      final data = res.data ?? const <String, dynamic>{};
      final plan = data['plan'] as Map<String, dynamic>?;
      final decks = plan?['flashCardDecks'] as Map<String, dynamic>?;
      if (decks == null) return null;
      final courses = plan?['assessmentCourses'] as Map<String, dynamic>?;
      return DeckPlan(
        limit: (decks['limit'] as num?)?.toInt(),
        opened: [for (final id in decks['openedDeckIds'] as List? ?? const []) id.toString()],
        allOpen: data['allOpen'] == true,
        upgradePlan: plan?['upgradePlan'] as String?,
        // The courses a deck may belong with (the API since 27 Oct 2026; an older one sends neither list, and no
        // deck is linked then).
        openedCourseIds: [for (final id in courses?['openedCourseIds'] as List? ?? const []) id.toString()],
        unlockedCourseIds: [for (final id in data['unlockedCourseIds'] as List? ?? const []) id.toString()],
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<StudyCard>> starredCards() async {
    final rows = await _list('/learning/me/resource-stars');
    return [for (final r in rows) _card(r)];
  }

  @override
  Future<void> setStar(String cardId, bool starred) async {
    try {
      await api.dio.request<dynamic>(
        '/learning/me/resource-stars/${Uri.encodeComponent(cardId)}',
        options: Options(method: starred ? 'PUT' : 'DELETE'),
      );
    } on DioException catch (e) {
      throw _locked(e) ?? ApiError.from(e);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  @override
  Future<int> unreadNotifications() async {
    try {
      final res = await api.dio.get<Map<String, dynamic>>('/notifications/unread-count');
      return (res.data?['unread'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Uri plansLink([String slug = 'professional']) => AppConfig.sitePage('/pricing/$slug');

  // --- mapping -------------------------------------------------------------

  StudyTopic _topic(Map<String, dynamic> json) => StudyTopic(
    id: json['id'] as String? ?? '',
    slug: json['slug'] as String? ?? '',
    title: (json['title'] as String? ?? '').trim(),
    description: _text(json['description']),
    kind: StudyKind.fromApi(json['kind'] as String?),
    cover: _picture(json['imageUrl'] as String?),
    cardCount: (json['cardCount'] as num?)?.toInt() ?? 0,
    sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    courseId: _text(json['courseId']),
    course: StudyCourseRef.fromApi(json['course']),
  );

  StudyCard _card(Map<String, dynamic> json) {
    final topic = json['topic'] as Map<String, dynamic>?;
    return StudyCard(
      id: json['id'] as String? ?? '',
      front: (json['front'] as String? ?? '').trim(),
      back: json['back'] as String? ?? '',
      topicId: json['topicId'] as String? ?? topic?['id'] as String?,
      topicTitle: (topic?['title'] as String?)?.trim(),
      topicSlug: topic?['slug'] as String?,
      example: _text(json['example']),
      examples: [
        for (final e in (json['examples'] as List? ?? const []).whereType<Map<String, dynamic>>()) _example(e),
      ],
      resourceUrl: _text(json['resourceUrl']),
      resourceLabel: _text(json['resourceLabel']),
      category: _text(json['category']),
      tags: [
        for (final t in json['tags'] as List? ?? const [])
          if (t.toString().trim().isNotEmpty) t.toString().trim(),
      ],
    );
  }

  FormulaExample _example(Map<String, dynamic> json) => FormulaExample(
    given: [
      for (final g in (json['given'] as List? ?? const []).whereType<Map<String, dynamic>>())
        FormulaGiven((g['label'] as String? ?? '').trim(), (g['value'] as String? ?? '').trim()),
    ],
    working: _text(json['working']),
    result: _text(json['result']),
    analysis: _text(json['analysis']),
    decision: _text(json['decision']),
  );

  /// Null for a blank, so "no example" and "an empty example" read the same.
  static String? _text(Object? v) {
    final s = v is String ? v.trim() : null;
    return s == null || s.isEmpty ? null : s;
  }

  FeedPicture? _picture(String? path) {
    final url = AppConfig.absoluteUrl(path, apiBase: api.dio.options.baseUrl);
    return url == null ? null : FeedPicture.network(url);
  }

  /// A `403 DECK_LOCKED` as the exception that carries the plans page too.
  DeckLocked? _locked(DioException e) {
    final data = e.response?.data;
    if (e.response?.statusCode != 403 || data is! Map || data['code'] != 'DECK_LOCKED') return null;
    final raw = data['message'];
    return DeckLocked(
      raw is String ? raw : 'Your plan does not include this deck.',
      pricingSlug: data['pricingSlug'] as String? ?? 'professional',
      plan: data['plan'] as String?,
      reason: data['reason'] as String?,
      // A deck that belongs with a course names it, so the screen can send the member to the course.
      course: StudyCourseRef.fromApi(data['course']),
      placesLeft: (data['placesLeft'] as num?)?.toInt(),
    );
  }

  Future<List<Map<String, dynamic>>> _list(String path) async {
    try {
      final res = await api.dio.get<dynamic>(path);
      final data = res.data;
      final rows = data is List ? data : (data is Map ? data['data'] as List? : null);
      return (rows ?? const []).cast<Map<String, dynamic>>();
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}
