import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../partner_console/partner_console_models.dart' show UploadFile;
import 'community_manage_models.dart';
import 'community_manage_rules.dart';

export '../partner_console/partner_console_models.dart' show UploadFile;

/// Chapters and councils run the same console; this says which one a call is for.
enum OrgKind {
  chapter('chapters'),
  council('councils');

  const OrgKind(this.path);

  /// The API's collection (`/chapters`, `/councils`).
  final String path;
}

/// Everything the website's `/admin/community` asks the API for on its Chapters, Councils and Applications tabs
/// (`features/association/api.ts`, `requests.ts`). Each call needs `chapters:manage` or `councils:manage`; a grant
/// over some records only reaches the calls marked *scoped*, and the rest need the key everywhere.
abstract class CommunityManageRepository {
  // --- the lists ---

  /// `GET /chapters/admin?page&limit=20&search` (scoped: the holder's chapters only) — unpublished included,
  /// searched by name or city.
  Future<ManagePage<AdminChapter>> chapters({int page = 1, String? search});

  /// `GET /councils/admin?page&limit=20&search` (scoped) — searched by name or focus.
  Future<ManagePage<AdminCouncil>> councils({int page = 1, String? search});

  /// One chapter by id, read from the staff list (the API has no staff read of a single chapter); null when the
  /// reader's list does not hold it.
  Future<AdminChapter?> chapter(String id);

  Future<AdminCouncil?> council(String id);

  // --- create, edit, retire ---

  /// `POST /chapters` (everywhere).
  Future<void> createChapter(Map<String, Object?> body);

  /// `PATCH /chapters/:id` (scoped).
  Future<void> updateChapter(String id, Map<String, Object?> body);

  /// `POST /councils` (everywhere).
  Future<void> createCouncil(Map<String, Object?> body);

  /// `PATCH /councils/:id` (scoped).
  Future<void> updateCouncil(String id, Map<String, Object?> body);

  /// `DELETE /chapters/:id` or `/councils/:id` (everywhere): a soft delete; the record leaves the public directory.
  Future<void> retire(OrgKind kind, String id);

  // --- a record's content ---

  /// `GET /:kind/:id/content` (scoped): sponsors (chapters), resources, updates, leads and the members a lead can
  /// be picked from.
  Future<OrgContent> content(OrgKind kind, String id);

  /// `POST /chapters/:id/sponsors` (scoped) — `{ name, logoUrl?, url?, tier? }`.
  Future<void> addSponsor(String chapterId, Map<String, Object?> body);

  /// `DELETE /chapters/:id/sponsors/:sponsorId` (scoped).
  Future<void> removeSponsor(String chapterId, String sponsorId);

  /// `POST /:kind/:id/resources` (scoped) — `{ title, kind, url, sizeLabel? }`.
  Future<void> addResource(OrgKind kind, String id, Map<String, Object?> body);

  /// `DELETE /:kind/:id/resources/:resourceId` (scoped).
  Future<void> removeResource(OrgKind kind, String id, String resourceId);

  /// `POST /:kind/:id/announcements` (scoped) — `{ title, body, pinned }`.
  Future<void> addAnnouncement(OrgKind kind, String id, Map<String, Object?> body);

  /// `DELETE /:kind/:id/announcements/:announcementId` (scoped).
  Future<void> removeAnnouncement(OrgKind kind, String id, String announcementId);

  /// `GET /chapters/:id/lead-candidates?search` (everywhere) — people by name or email, the chapter's members first;
  /// nothing under two letters.
  Future<List<LeadCandidate>> leadCandidates(String chapterId, String search);

  /// `POST /chapters/:id/leads` (everywhere) — `{ userId, title?, linkedinUrl? }`; a person who has not joined is
  /// joined as they are made a lead.
  Future<void> addLead(String chapterId, Map<String, Object?> body);

  /// `PATCH /:kind/:id/members/:userId` (scoped) — a lead's `title`, `linkedinUrl`, `termStartsOn`, `termEndsOn`
  /// (an empty day clears it), or `role` `LEAD` / `MEMBER`.
  Future<void> updateMember(OrgKind kind, String id, String userId, Map<String, Object?> body);

  // --- members' requests ---

  /// `GET /admin/chapter-applications?status&page&limit=20` (everywhere).
  Future<ManagePage<ChapterApplication>> chapterApplications({required String status, int page = 1});

  /// `GET /admin/council-proposals?status&page&limit=20` (everywhere).
  Future<ManagePage<CouncilProposal>> councilProposals({required String status, int page = 1});

  /// `POST /admin/chapter-applications/:id/decide` or `/admin/council-proposals/:id/decide` (everywhere) —
  /// `{ decision: APPROVED | DECLINED, reason? }`; a decline needs its reason.
  Future<void> decide(OrgKind kind, String id, {required String decision, String? reason});

  // --- who may ---

  /// Whether the reader may manage this chapter: `GET /chapters/:id/content` answers 200 (false on 401, 403, 404).
  Future<bool> mayManageChapter(String id);

  /// Whether the reader may manage this council: `GET /councils/:id/content` answers 200.
  Future<bool> mayManageCouncil(String id);

  // --- what the forms need ---

  /// `POST /uploads?purpose=` — a picture, stored publicly; returns its `/uploads/...` path.
  Future<String> upload(UploadFile file, {required String purpose});

  /// `GET /locations/cities` — ICR's own city list, each with its state.
  Future<List<PlaceOption>> cities();

  /// `GET /locations/search?q=` — cities anywhere, for two letters or more.
  Future<List<PlaceOption>> searchPlaces(String query);
}

class ApiCommunityManageRepository implements CommunityManageRepository {
  ApiCommunityManageRepository({required this.api});

  final ApiClient api;

  Future<T> _call<T>(Future<T> Function(Dio dio) body) async {
    try {
      return await body(api.dio);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  static String _id(String id) => Uri.encodeComponent(id);

  Map<String, dynamic> _map(Object? data) => data is Map ? data.cast<String, dynamic>() : const {};

  List<Map<String, dynamic>> _rows(Object? data) => [
    for (final r in data is List ? data : const [])
      if (r is Map) r.cast<String, dynamic>(),
  ];

  Future<ManagePage<T>> _list<T>(
    String path,
    T Function(Map<String, dynamic>) row, {
    int page = 1,
    int limit = managePageSize,
    String? search,
    String? status,
  }) => _call((dio) async {
    final q = search?.trim() ?? '';
    final res = await dio.get<dynamic>(
      path,
      queryParameters: {'page': page, 'limit': limit, if (q.isNotEmpty) 'search': q, 'status': ?status},
    );
    return ManagePage.fromJson(res.data, row);
  });

  @override
  Future<ManagePage<AdminChapter>> chapters({int page = 1, String? search}) =>
      _list('/chapters/admin', AdminChapter.fromJson, page: page, search: search);

  @override
  Future<ManagePage<AdminCouncil>> councils({int page = 1, String? search}) =>
      _list('/councils/admin', AdminCouncil.fromJson, page: page, search: search);

  /// The staff list a hundred at a time (the API's most) until the id turns up.
  Future<T?> _find<T>(String path, T Function(Map<String, dynamic>) row, bool Function(T) match) async {
    for (var page = 1; page <= 20; page++) {
      final got = await _list(path, row, page: page, limit: 100);
      for (final r in got.rows) {
        if (match(r)) return r;
      }
      if (page >= got.totalPages || got.rows.isEmpty) break;
    }
    return null;
  }

  @override
  Future<AdminChapter?> chapter(String id) => _find('/chapters/admin', AdminChapter.fromJson, (c) => c.id == id);

  @override
  Future<AdminCouncil?> council(String id) => _find('/councils/admin', AdminCouncil.fromJson, (c) => c.id == id);

  @override
  Future<void> createChapter(Map<String, Object?> body) => _call((dio) => dio.post<dynamic>('/chapters', data: body));

  @override
  Future<void> updateChapter(String id, Map<String, Object?> body) =>
      _call((dio) => dio.patch<dynamic>('/chapters/${_id(id)}', data: body));

  @override
  Future<void> createCouncil(Map<String, Object?> body) => _call((dio) => dio.post<dynamic>('/councils', data: body));

  @override
  Future<void> updateCouncil(String id, Map<String, Object?> body) =>
      _call((dio) => dio.patch<dynamic>('/councils/${_id(id)}', data: body));

  @override
  Future<void> retire(OrgKind kind, String id) => _call((dio) => dio.delete<dynamic>('/${kind.path}/${_id(id)}'));

  @override
  Future<OrgContent> content(OrgKind kind, String id) => _call(
    (dio) async => OrgContent.fromJson(_map((await dio.get<dynamic>('/${kind.path}/${_id(id)}/content')).data)),
  );

  @override
  Future<void> addSponsor(String chapterId, Map<String, Object?> body) =>
      _call((dio) => dio.post<dynamic>('/chapters/${_id(chapterId)}/sponsors', data: body));

  @override
  Future<void> removeSponsor(String chapterId, String sponsorId) =>
      _call((dio) => dio.delete<dynamic>('/chapters/${_id(chapterId)}/sponsors/${_id(sponsorId)}'));

  @override
  Future<void> addResource(OrgKind kind, String id, Map<String, Object?> body) =>
      _call((dio) => dio.post<dynamic>('/${kind.path}/${_id(id)}/resources', data: body));

  @override
  Future<void> removeResource(OrgKind kind, String id, String resourceId) =>
      _call((dio) => dio.delete<dynamic>('/${kind.path}/${_id(id)}/resources/${_id(resourceId)}'));

  @override
  Future<void> addAnnouncement(OrgKind kind, String id, Map<String, Object?> body) =>
      _call((dio) => dio.post<dynamic>('/${kind.path}/${_id(id)}/announcements', data: body));

  @override
  Future<void> removeAnnouncement(OrgKind kind, String id, String announcementId) =>
      _call((dio) => dio.delete<dynamic>('/${kind.path}/${_id(id)}/announcements/${_id(announcementId)}'));

  @override
  Future<List<LeadCandidate>> leadCandidates(String chapterId, String search) => _call((dio) async {
    final q = search.trim();
    if (q.length < 2) return const <LeadCandidate>[];
    final res = await dio.get<dynamic>('/chapters/${_id(chapterId)}/lead-candidates', queryParameters: {'search': q});
    return [for (final r in _rows(res.data)) LeadCandidate.fromJson(r)];
  });

  @override
  Future<void> addLead(String chapterId, Map<String, Object?> body) =>
      _call((dio) => dio.post<dynamic>('/chapters/${_id(chapterId)}/leads', data: body));

  @override
  Future<void> updateMember(OrgKind kind, String id, String userId, Map<String, Object?> body) =>
      _call((dio) => dio.patch<dynamic>('/${kind.path}/${_id(id)}/members/${_id(userId)}', data: body));

  @override
  Future<ManagePage<ChapterApplication>> chapterApplications({required String status, int page = 1}) =>
      _list('/admin/chapter-applications', ChapterApplication.fromJson, page: page, status: status);

  @override
  Future<ManagePage<CouncilProposal>> councilProposals({required String status, int page = 1}) =>
      _list('/admin/council-proposals', CouncilProposal.fromJson, page: page, status: status);

  @override
  Future<void> decide(OrgKind kind, String id, {required String decision, String? reason}) => _call((dio) {
    final path = kind == OrgKind.chapter ? 'chapter-applications' : 'council-proposals';
    final note = reason?.trim() ?? '';
    return dio.post<dynamic>(
      '/admin/$path/${_id(id)}/decide',
      data: {'decision': decision, if (note.isNotEmpty) 'reason': note},
    );
  });

  Future<bool> _mayManage(OrgKind kind, String id) async {
    try {
      await api.dio.get<dynamic>('/${kind.path}/${_id(id)}/content');
      return true;
    } catch (e) {
      final error = ApiError.from(e);
      if (const {401, 403, 404}.contains(error.statusCode)) return false;
      throw error;
    }
  }

  @override
  Future<bool> mayManageChapter(String id) => _mayManage(OrgKind.chapter, id);

  @override
  Future<bool> mayManageCouncil(String id) => _mayManage(OrgKind.council, id);

  @override
  Future<String> upload(UploadFile file, {required String purpose}) => _call((dio) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(file.bytes, filename: file.name, contentType: DioMediaType.parse(file.mimeType)),
    });
    final res = await dio.post<dynamic>('/uploads', data: form, queryParameters: {'purpose': purpose});
    final url = _map(res.data)['url'];
    if (url is! String || url.isEmpty) throw ApiError('Upload failed. Check the file type and try again.');
    return url;
  });

  @override
  Future<List<PlaceOption>> cities() => _call((dio) async {
    final res = await dio.get<dynamic>('/locations/cities');
    return [
      for (final r in _rows(res.data))
        if (r['name'] is String) PlaceOption.fromCity(r),
    ];
  });

  @override
  Future<List<PlaceOption>> searchPlaces(String query) => _call((dio) async {
    final q = query.trim();
    if (q.length < 2) return const <PlaceOption>[];
    final res = await dio.get<dynamic>('/locations/search', queryParameters: {'q': q});
    return [
      for (final r in _rows(res.data))
        if (r['label'] is String && (r['label'] as String).isNotEmpty) PlaceOption.fromJson(r),
    ];
  });
}
