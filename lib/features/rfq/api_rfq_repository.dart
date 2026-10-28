import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import 'rfq_format.dart' show mimeTypeFor, titleFromFileName;
import 'rfq_links.dart' show PickedRfqFile;
import 'rfq_models.dart';
import 'rfq_repository.dart';

/// The requirements module from the ICR API (`/rfq/*`, with `/vendors`,
/// `/notifications`, `/categories` and `/locations` for what it leans on).
class ApiRfqRepository implements RfqRepository {
  ApiRfqRepository({required this.api, this.pageSize = 20, this.supportsBidChanges = false});

  final ApiClient api;

  /// How many rows a page of the buyer's list holds.
  final int pageSize;

  List<CategoryNode>? _tree;
  Future<List<CategoryNode>>? _treeLoad;
  final _names = <String, String>{};

  Future<dynamic> _get(String path, [Map<String, dynamic>? query]) async =>
      (await api.dio.get<dynamic>(path, queryParameters: query)).data;

  Future<dynamic> _post(String path, [Object? body]) async => (await api.dio.post<dynamic>(path, data: body)).data;

  Future<dynamic> _patch(String path, [Object? body]) async => (await api.dio.patch<dynamic>(path, data: body)).data;

  static List<Map<String, dynamic>> _rows(dynamic data) =>
      data is Map<String, dynamic> ? asMaps(data['data']) : asMaps(data);

  // ---- Who is asking ------------------------------------------------------------

  @override
  Future<Poster> me() async {
    final j = asMap(await _get('/auth/me'));
    final companyId = asText(j['companyId']);
    String? companyName;
    if (companyId != null) {
      try {
        companyName = asText(asMap(await _get('/companies/$companyId'))['name']);
      } catch (_) {
        // The name is a courtesy; posting still stamps the company.
      }
    }
    return Poster(
      id: j['id'] as String? ?? '',
      name: '${j['firstName'] as String? ?? ''} ${j['lastName'] as String? ?? ''}'.trim(),
      email: j['email'] as String? ?? '',
      role: j['role'] as String? ?? 'PROFESSIONAL',
      phone: asText(j['phone']),
      companyId: companyId,
      companyName: companyName,
    );
  }

  // ---- The buyer's requirements ---------------------------------------------------

  @override
  Future<RequirementsSummary> summary() async => RequirementsSummary.fromJson(asMap(await _get('/rfq/mine/summary')));

  @override
  Future<RequirementPage> mine({
    MyView view = MyView.all,
    String search = '',
    RfqKind? kind,
    MySort sort = MySort.updated,
    int page = 1,
  }) async {
    final data = asMap(
      await _get('/rfq/mine', {
        'page': page,
        'limit': pageSize,
        if (view != MyView.all) 'view': view.wire,
        if (search.trim().isNotEmpty) 'search': search.trim(),
        'kind': ?kind?.wire,
        'sort': sort.wire,
      }),
    );
    final meta = asMap(data['meta']);
    final rows = [for (final r in asMaps(data['data'])) Requirement.fromJson(r)];
    return RequirementPage(rows: rows, total: asInt(meta['total']) ?? rows.length, hasMore: meta['hasNext'] == true);
  }

  @override
  Future<Requirement> requirement(String id) async => Requirement.fromJson(asMap(await _get('/rfq/$id')));

  @override
  Future<PostResult> create(Map<String, dynamic> body) async => PostResult.fromJson(asMap(await _post('/rfq', body)));

  @override
  Future<void> update(String id, Map<String, dynamic> patch) => _patch('/rfq/$id', patch);

  @override
  Future<void> act(String id, RfqAction action) => _post('/rfq/$id/${action.name}');

  @override
  Future<void> deleteDraft(String id) => api.dio.delete<dynamic>('/rfq/$id');

  @override
  Future<void> setStage(String id, RfqStage stage) => _post('/rfq/$id/stage', {'stage': stage.wire});

  // ---- Responses, for the owner ---------------------------------------------------

  @override
  Future<List<Bid>> bids(String rfqId) async => [
    for (final b in _rows(await _get('/rfq/$rfqId/bids'))) Bid.fromJson(b),
  ];

  @override
  Future<void> triageBid(String rfqId, String bidId, BidStatus status) =>
      _patch('/rfq/$rfqId/bids/$bidId', {'status': status.wire});

  @override
  Future<String?> award(String rfqId, String bidId) async =>
      asText(asMap(await _post('/rfq/$rfqId/bids/$bidId/award'))['poNumber']);

  @override
  Future<List<PreQualResponse>> responses(String rfqId) async => [
    for (final r in _rows(await _get('/rfq/$rfqId/responses'))) PreQualResponse.fromJson(r),
  ];

  @override
  Future<void> screen(String rfqId, String vendorId, PreQualStatus status) =>
      _patch('/rfq/$rfqId/responses/$vendorId/screen', {'preQualStatus': status.wire});

  @override
  Future<void> shortlist(String rfqId, List<String> vendorIds) =>
      _post('/rfq/$rfqId/shortlist', {'vendorIds': vendorIds});

  @override
  Future<List<SupplierInvite>> invites(String rfqId) async => [
    for (final i in _rows(await _get('/rfq/$rfqId/invites'))) SupplierInvite.fromJson(i),
  ];

  @override
  Future<List<SupplierHit>> suggested(String rfqId) async => [
    for (final v in _rows(await _get('/rfq/$rfqId/suggested-vendors'))) SupplierHit.fromJson(v),
  ];

  @override
  Future<List<SupplierHit>> findSuppliers(String query) async => [
    for (final v in _rows(await _get('/vendors', {'search': query.trim(), 'limit': 20}))) SupplierHit.fromJson(v),
  ];

  @override
  Future<List<SupplierInvite>> invite(String rfqId, List<String> vendorIds) async => [
    for (final i in _rows(await _post('/rfq/$rfqId/invites', {'vendorIds': vendorIds}))) SupplierInvite.fromJson(i),
  ];

  @override
  Future<List<SupplierThread>> threads(String rfqId) async => [
    for (final t in _rows(await _get('/rfq/$rfqId/conversations'))) SupplierThread.fromJson(t),
  ];

  @override
  Future<String> openConversation(String rfqId, {String? supplierCompanyId}) async {
    final data = asMap(await _post('/rfq/$rfqId/conversation', {'supplierCompanyId': ?supplierCompanyId}));
    return data['id'] as String;
  }

  // ---- The supplier's side ----------------------------------------------------------

  @override
  Future<VendorAccess> access() async => VendorAccess.fromJson(asMap(await _get('/vendors/me/access')));

  @override
  Future<List<Requirement>> openBoard(BoardQuery query, {int page = 1, int limit = 20}) async => [
    for (final r in _rows(await _get('/rfq/open', query.toQuery(page: page, limit: limit)))) Requirement.fromJson(r),
  ];

  @override
  Future<List<Requirement>> invited() async => [
    for (final r in _rows(await _get('/rfq/invited'))) Requirement.fromJson(r),
  ];

  @override
  Future<List<MyBid>> myBids() async => [for (final b in _rows(await _get('/rfq/bids/mine'))) MyBid.fromJson(b)];

  @override
  Future<OpportunityContext> opportunity(String rfqId) async =>
      OpportunityContext.fromJson(asMap(await _get('/rfq/$rfqId/opportunity')));

  @override
  Future<MyBid> placeBid(String rfqId, Map<String, dynamic> body) async =>
      MyBid.fromJson(asMap(await _post('/rfq/$rfqId/bids', body)));

  /// Switched on once the portal has `PATCH|DELETE /rfq/:id/bids/mine` (`docs/backend-requests/rfq.md`).
  @override
  final bool supportsBidChanges;

  @override
  Future<MyBid> updateBid(String rfqId, Map<String, dynamic> body) async =>
      MyBid.fromJson(asMap(await _patch('/rfq/$rfqId/bids/mine', body)));

  @override
  Future<void> withdrawBid(String rfqId) => api.dio.delete<dynamic>('/rfq/$rfqId/bids/mine');

  @override
  Future<void> declineInvite(String rfqId) => _post('/rfq/$rfqId/decline');

  @override
  Future<void> submitPreQual(String rfqId, Map<String, dynamic> body) => _post('/rfq/$rfqId/prequal', body);

  @override
  Future<BuyerContact> revealContact(String rfqId) async =>
      BuyerContact.fromJson(asMap(await _get('/rfq/$rfqId/contact')));

  @override
  Future<void> startSelling(String companyId) => _post('/vendors', {'companyId': companyId});

  // ---- Alerts and counts --------------------------------------------------------------

  /// How many hundreds of notifications `alerts` reads at most.
  static const _alertPages = 5;

  @override
  Future<List<RfqAlert>> alerts({bool unreadOnly = false}) async {
    // The API filters by read state only, so the notifications are read a hundred at a time, newest first, and the
    // requirement ones kept. A supplier is told about every matching requirement, so a busy one holds hundreds of
    // notices: one page would hide an invitation that is only a few days old behind newer ones of other kinds.
    final out = <RfqAlert>[];
    for (var page = 1; page <= _alertPages; page++) {
      final data = await _get('/notifications', {'limit': 100, 'page': page, if (unreadOnly) 'unread': 'true'});
      for (final r in _rows(data)) {
        if (RfqAlert.isAbout(r)) out.add(RfqAlert.fromJson(r));
      }
      if (data is! Map<String, dynamic> || asMap(data['meta'])['hasNext'] != true) break;
    }
    return out;
  }

  @override
  Future<void> markAlertRead(String id) => _patch('/notifications/$id/read');

  @override
  Future<void> markSeen(AlertSide side, String rfqId) =>
      _patch('/notifications/seen', {'kind': side == AlertSide.owner ? 'rfq.owner' : 'rfq.supplier', 'id': rfqId});

  @override
  Future<int> unreadNotifications() async => asInt(asMap(await _get('/notifications/unread-count'))['unread']) ?? 0;

  @override
  Future<RfqCounts> counts() async {
    var mine = 0;
    try {
      mine = (await summary()).open;
    } catch (_) {
      // A member who cannot post requirements has none.
    }
    var fresh = 0;
    try {
      fresh = (await alerts(unreadOnly: true)).length;
    } catch (_) {}
    return RfqCounts(myRfqs: mine, newAlerts: fresh);
  }

  // ---- The composer's lookups ---------------------------------------------------------

  @override
  Future<List<CategoryNode>> categories() async {
    final cached = _tree;
    if (cached != null) return cached;
    return _treeLoad ??= () async {
      try {
        final rows = asMaps(await _get('/categories/tree', {'kind': 'SERVICE', 'depth': 2}));
        final tree = [for (final r in rows) CategoryNode.fromJson(r)];
        void index(List<CategoryNode> nodes) {
          for (final n in nodes) {
            _names[n.key] = n.name;
            index(n.children);
          }
        }

        index(tree);
        return _tree = tree;
      } finally {
        _treeLoad = null;
      }
    }();
  }

  @override
  Future<List<CategoryNode>> specialisations(String parentId) async {
    final rows = _rows(await _get('/categories', {'parentId': parentId, 'limit': 100}));
    final nodes = [for (final r in rows) CategoryNode.fromJson(r)];
    for (final n in nodes) {
      _names[n.key] = n.name;
    }
    return nodes;
  }

  @override
  Future<List<RfqPlace>> searchPlaces(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final data = await _get('/locations/search', {'q': q, 'limit': 8});
    return [for (final p in _rows(data)) RfqPlace.fromJson(p)];
  }

  @override
  Future<RfqFile> uploadFile(PickedRfqFile file, {required String purpose}) async {
    final mime = file.mimeType ?? mimeTypeFor(file.name);
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        file.bytes,
        filename: file.name,
        contentType: mime == null ? null : DioMediaType.parse(mime),
      ),
    });
    final res = await api.dio.post<Map<String, dynamic>>('/uploads', data: form, queryParameters: {'purpose': purpose});
    final data = res.data ?? const <String, dynamic>{};
    final name = asText(data['name']) ?? file.name;
    return RfqFile(
      id: '',
      title: titleFromFileName(name),
      url: data['url'] as String? ?? '',
      name: name,
      mimeType: asText(data['mimeType']) ?? mime,
      size: asInt(data['size']) ?? file.size,
    );
  }

  @override
  Future<String> saveFile(RfqFile file) async {
    final url = AppConfig.absoluteUrl(file.url, apiBase: api.dio.options.baseUrl)!;
    final res = await api.dio.get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
    final dir = Directory('${Directory.systemTemp.path}${Platform.pathSeparator}icr-requirement-files')
      ..createSync(recursive: true);
    final name = (file.name ?? file.title).replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_');
    final out = File('${dir.path}${Platform.pathSeparator}$name');
    await out.writeAsBytes(res.data ?? const []);
    return out.path;
  }

  @override
  String? categoryName(String key) => _names[key];

  @override
  Uri sitePage(String path) => AppConfig.sitePage(path);
}
