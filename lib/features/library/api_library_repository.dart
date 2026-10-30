import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/config.dart';
import '../chapters/community_api.dart';
import 'library_models.dart';
import 'library_repository.dart';

/// The Digital Library from the API (the portal's documents module):
/// `GET /documents` (paged, `search`, `category`, `fileType`, `mine`, `sortBy`, `sortDir`),
/// `/documents/categories`, `/documents/file-types`, `GET /documents/:id/download` (`fileId`, `preview`),
/// `POST /documents/:id/view`, `POST /uploads?purpose=document-hub`, `POST /documents`,
/// `POST /documents/:id/files`, `DELETE /documents/:id/files/:fileId`, `DELETE /documents/:id`,
/// `POST /documents/:id/report`, `GET /categories/tree` and `GET /auth/me`.
class ApiLibraryRepository implements LibraryRepository {
  ApiLibraryRepository({required ApiClient api}) : _api = CommunityApi(api);

  final CommunityApi _api;

  Dio get _dio => _api.client.dio;

  /// How far `document(id)` reads the library before it says the document is gone.
  static const maxScanPages = 8;

  @override
  Future<LibraryPage> documents(LibraryQuery query) async {
    final search = query.search.trim();
    final res = await _api.page('/documents', {
      'page': query.page,
      'limit': query.limit,
      if (search.isNotEmpty) 'search': search,
      if (query.category != null) 'category': query.category,
      if (query.fileType != null) 'fileType': query.fileType!.api,
      if (query.mine) 'mine': 'true',
      'sortBy': query.sort.sortBy,
      'sortDir': query.sort.sortDir,
    });
    return LibraryPage(
      documents: [for (final row in res.items) _document(row)],
      total: res.total,
      page: res.page,
      hasNext: res.hasNext,
    );
  }

  @override
  Future<List<String>> categories() async {
    try {
      final res = await _dio.get<List<dynamic>>('/documents/categories');
      return [
        for (final c in res.data ?? const [])
          if (c is String && c.trim().isNotEmpty) c,
      ];
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  @override
  Future<List<FileTypeFacet>> fileTypes() async {
    final rows = await _api.getList('/documents/file-types');
    return [
      for (final r in rows)
        FileTypeFacet(
          type: LibraryFileType.fromApi(r['type'] as String?),
          label: r['label'] as String? ?? LibraryFileType.fromApi(r['type'] as String?).label,
          count: CommunityApi.count(r['count']),
        ),
    ];
  }

  @override
  Future<int> myUploadCount() async {
    try {
      final res = await _api.page('/documents', {'mine': 'true', 'limit': 1});
      return res.total;
    } on ApiError catch (e) {
      if (e.statusCode == 401) return 0;
      rethrow;
    }
  }

  @override
  Future<LibraryDocument> document(String id) async {
    for (var page = 1; page <= maxScanPages; page++) {
      final res = await _api.page('/documents', {'page': page, 'limit': 100, 'sortBy': 'createdAt', 'sortDir': 'desc'});
      for (final row in res.items) {
        if (row['id'] == id) return _document(row);
      }
      if (!res.hasNext) break;
    }
    throw ApiError('That document is no longer in the library.', statusCode: 404);
  }

  @override
  Future<List<TaxonomyNode>> taxonomy() async {
    final rows = await _api.getList('/categories/tree');
    TaxonomyNode node(Map<String, dynamic> n) => TaxonomyNode(
      label: n['name'] as String? ?? '',
      children: [
        for (final c in (n['children'] as List? ?? const []).cast<Map<String, dynamic>>())
          if ((c['name'] as String? ?? '').isNotEmpty) node(c),
      ],
    );
    return [
      for (final r in rows)
        if ((r['name'] as String? ?? '').isNotEmpty) node(r),
    ];
  }

  @override
  Future<LibraryViewer?> viewer() async {
    final me = await _api.viewer();
    return me == null ? null : LibraryViewer(id: me.id, isAdmin: me.isAdmin);
  }

  @override
  Future<DocumentBytes> previewFile(LibraryDocument document, LibraryFile file) async {
    try {
      // Always the viewer's read (`preview=true`): the app never asks the API for a download, so nothing it
      // does is counted as one.
      final res = await _dio.get<List<int>>(
        '/documents/${Uri.encodeComponent(document.id)}/download',
        queryParameters: {'fileId': file.id, 'preview': 'true'},
        options: Options(responseType: ResponseType.bytes),
      );
      return DocumentBytes(
        bytes: Uint8List.fromList(res.data ?? const []),
        fileName: file.fileName,
        mimeType: file.mimeType,
      );
    } on DioException catch (e) {
      throw _bytesError(e);
    }
  }

  /// A refusal read with `ResponseType.bytes` arrives as bytes: the JSON body is decoded so the API's own
  /// sentence (a plan that does not open the document, a sign-in wall) is the one shown.
  static ApiError _bytesError(DioException e) {
    final data = e.response?.data;
    if (data is List<int>) {
      try {
        final json = jsonDecode(utf8.decode(data));
        if (json is Map) {
          final raw = json['message'];
          final message = raw is String ? raw : (raw is List && raw.isNotEmpty ? raw.join('\n') : null);
          return ApiError(
            message ?? 'Something went wrong (${e.response?.statusCode}). Try again.',
            statusCode: e.response?.statusCode,
            code: json['code'] as String?,
          );
        }
      } catch (_) {
        // Not JSON: fall through to the generic wording.
      }
      return ApiError.from(
        DioException(
          requestOptions: e.requestOptions,
          response: Response(requestOptions: e.requestOptions, statusCode: e.response?.statusCode),
        ),
      );
    }
    return ApiError.from(e);
  }

  @override
  Future<int> recordView(String id) async {
    final res = await _api.send('POST', '/documents/${Uri.encodeComponent(id)}/view');
    return CommunityApi.count((res as Map?)?['viewCount']);
  }

  @override
  Future<StoredFile> upload(PickedFile file, {void Function(double)? onProgress}) async {
    final mime = file.mimeType ?? mimeForName(file.name);
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        file.bytes,
        filename: file.name,
        contentType: mime == null ? null : DioMediaType.parse(mime),
      ),
    });
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/uploads',
        data: form,
        queryParameters: {'purpose': 'document-hub'},
        onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call(sent / total);
        },
      );
      final data = res.data!;
      return StoredFile(
        url: data['url'] as String,
        name: data['name'] as String? ?? file.name,
        size: (data['size'] as num?)?.toInt() ?? file.size,
        mimeType: data['mimeType'] as String? ?? mime ?? 'application/octet-stream',
      );
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  @override
  Future<LibraryDocument> create(DocumentDraft draft, List<StoredFile> files) async {
    final res = await _api.send(
      'POST',
      '/documents',
      data: {
        'title': draft.title,
        if (draft.description != null) 'description': draft.description,
        if (draft.category != null) 'category': draft.category,
        if (draft.subcategory != null) 'subcategory': draft.subcategory,
        if (draft.specialization != null) 'specialization': draft.specialization,
        'files': [for (final f in files) f.toJson()],
      },
    );
    return _document((res as Map).cast<String, dynamic>());
  }

  @override
  Future<LibraryDocument> addFiles(String id, List<StoredFile> files) async {
    final res = await _api.send(
      'POST',
      '/documents/${Uri.encodeComponent(id)}/files',
      data: {
        'files': [for (final f in files) f.toJson()],
      },
    );
    return _document((res as Map).cast<String, dynamic>());
  }

  @override
  Future<void> removeFile(String documentId, String fileId) =>
      _api.send('DELETE', '/documents/${Uri.encodeComponent(documentId)}/files/${Uri.encodeComponent(fileId)}');

  @override
  Future<void> delete(String id) => _api.send('DELETE', '/documents/${Uri.encodeComponent(id)}');

  @override
  Future<void> report(String id, DocumentReportReason reason, {String? note}) => _api.send(
    'POST',
    '/documents/${Uri.encodeComponent(id)}/report',
    data: {'reason': reason.api, if (note != null && note.trim().isNotEmpty) 'note': note.trim()},
  );

  @override
  Future<int> unreadNotifications() => _api.unreadNotifications();

  @override
  Uri link() => AppConfig.sitePage('/documents');

  // --- mapping -------------------------------------------------------------

  LibraryDocument _document(Map<String, dynamic> j) {
    final uploader = j['uploader'] as Map<String, dynamic>?;
    return LibraryDocument(
      id: j['id'] as String,
      title: j['title'] as String? ?? '',
      description: CommunityApi.text(j['description']),
      category: CommunityApi.text(j['category']),
      subcategory: CommunityApi.text(j['subcategory']),
      specialization: CommunityApi.text(j['specialization']),
      files: [
        for (final f in (j['files'] as List? ?? const []).cast<Map<String, dynamic>>())
          LibraryFile(
            id: f['id'] as String,
            fileName: f['fileName'] as String? ?? '',
            mimeType: f['mimeType'] as String? ?? 'application/octet-stream',
            sizeBytes: CommunityApi.count(f['sizeBytes']),
            fileType: LibraryFileType.fromApi(f['fileType'] as String?),
            sortOrder: CommunityApi.count(f['sortOrder']),
            downloadCount: CommunityApi.count(f['downloadCount']),
          ),
      ],
      fileCount: (j['fileCount'] as num?)?.toInt() ?? 1,
      totalSizeBytes: CommunityApi.count(j['totalSizeBytes']),
      downloadCount: CommunityApi.count(j['downloadCount']),
      viewCount: CommunityApi.count(j['viewCount']),
      createdAt: CommunityApi.date(j['createdAt']),
      uploaderId: j['uploaderId'] as String? ?? uploader?['id'] as String? ?? '',
      uploader: uploader == null
          ? null
          : LibraryUploader(
              id: uploader['id'] as String? ?? '',
              firstName: uploader['firstName'] as String? ?? '',
              lastName: uploader['lastName'] as String? ?? '',
              photo: _api.picture(uploader['avatarUrl'] as String?),
              title: CommunityApi.text(uploader['title']),
            ),
    );
  }

  /// The MIME type of a library format by its name; null for one the library does not take.
  static String? mimeForName(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0) return null;
    return _mimeByExtension[name.substring(dot + 1).toLowerCase()];
  }

  static const _mimeByExtension = <String, String>{
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'csv': 'text/csv',
    'txt': 'text/plain',
    'zip': 'application/zip',
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'webp': 'image/webp',
  };
}
