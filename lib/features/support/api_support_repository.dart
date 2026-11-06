import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/config.dart';
import 'support_models.dart';
import 'support_repository.dart';

/// The support desk against the ICR API, through the signed-in client. Every failure comes out as an [ApiError]
/// carrying the API's own sentence.
class ApiSupportRepository implements SupportRepository {
  ApiSupportRepository({required this.api});

  final ApiClient api;

  Future<T> _call<T>(Future<T> Function(Dio dio) body) async {
    try {
      return await body(api.dio);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<Map<String, dynamic>> _map(Future<Response<dynamic>> Function(Dio dio) send) => _call((dio) async {
    final data = (await send(dio)).data;
    return data is Map ? data.cast<String, dynamic>() : const <String, dynamic>{};
  });

  @override
  Future<TicketPage> tickets({String status = 'OPEN_ONLY', String? search, int page = 1, int limit = 20}) async =>
      TicketPage.fromJson(
        await _map(
          (dio) => dio.get<dynamic>(
            '/support/tickets',
            queryParameters: {
              'status': status,
              if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
              'page': page,
              'limit': limit,
            },
          ),
        ),
      );

  @override
  Future<SupportTicket> ticket(String id) async =>
      SupportTicket.fromJson(await _map((dio) => dio.get<dynamic>('/support/tickets/${Uri.encodeComponent(id)}')));

  @override
  Future<SupportTicketRaised> raise(RaiseDraft draft) async {
    final json = await _map((dio) => dio.post<dynamic>('/support/tickets', data: draft.toJson()));
    return SupportTicketRaised(id: json['id'] as String? ?? '', reference: (json['reference'] as num?)?.toInt() ?? 0);
  }

  @override
  Future<SupportTicket> reply(String id, String body, List<SupportAttachmentDraft> attachments) async =>
      SupportTicket.fromJson(
        await _map(
          (dio) => dio.post<dynamic>(
            '/support/tickets/${Uri.encodeComponent(id)}/messages',
            data: {
              'body': body.trim(),
              if (attachments.isNotEmpty) 'attachments': [for (final a in attachments) a.toJson()],
            },
          ),
        ),
      );

  @override
  Future<SupportTicket> reopen(String id) async => SupportTicket.fromJson(
    await _map((dio) => dio.post<dynamic>('/support/tickets/${Uri.encodeComponent(id)}/reopen')),
  );

  @override
  Future<SupportTicket> rate(String id, int score) async => SupportTicket.fromJson(
    await _map((dio) => dio.post<dynamic>('/support/tickets/${Uri.encodeComponent(id)}/rate', data: {'score': score})),
  );

  @override
  Future<List<SupportFaq>> faqs({String? category, String? search, int limit = 4}) => _call((dio) async {
    final data = (await dio.get<dynamic>(
      '/support/faqs',
      queryParameters: {
        'category': ?category,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'limit': limit,
      },
    )).data;
    final rows = data is List ? data : (data is Map ? data['data'] as List? : null) ?? const [];
    return [
      for (final r in rows)
        if (r is Map) SupportFaq.fromJson(r.cast<String, dynamic>()),
    ];
  });

  @override
  Future<void> markFaqViewed(String id) async {
    try {
      await api.dio.post<void>('/support/faqs/${Uri.encodeComponent(id)}/view');
    } catch (_) {
      // A failed count must never break the page.
    }
  }

  @override
  Future<void> markFaqHelpful(String id) async {
    try {
      await api.dio.post<void>('/support/faqs/${Uri.encodeComponent(id)}/helpful');
    } catch (_) {
      // A failed count must never break the page.
    }
  }

  @override
  Future<AccountManager?> accountManager() => _call((dio) async {
    final data = (await dio.get<dynamic>('/subscriptions/account-manager')).data;
    return AccountManager.fromJson(data);
  });

  @override
  Future<SupportAttachmentDraft> upload(SupportPickedFile file) => _call((dio) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        file.bytes,
        filename: file.name,
        contentType: DioMediaType.parse(file.contentType),
      ),
    });
    final res = await dio.post<Map<String, dynamic>>('/uploads', data: form, queryParameters: {'purpose': 'support'});
    final data = res.data ?? const <String, dynamic>{};
    return SupportAttachmentDraft(
      fileUrl: data['url'] as String? ?? '',
      fileName: data['name'] as String? ?? file.name,
      mimeType: data['mimeType'] as String? ?? file.contentType,
      sizeBytes: (data['size'] as num?)?.toInt() ?? file.bytes.length,
    );
  });

  @override
  Future<Uint8List> fileBytes(String url) async {
    try {
      final res = await api.dio.get<List<int>>(
        AppConfig.absoluteUrl(url, apiBase: api.dio.options.baseUrl)!,
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(res.data ?? const []);
    } on DioException catch (e) {
      throw _errorOfBytes(e);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  /// A refusal to a bytes download arrives as bytes: the API's JSON sentence is read out of them.
  ApiError _errorOfBytes(DioException e) {
    final data = e.response?.data;
    if (data is List<int>) {
      try {
        final json = jsonDecode(utf8.decode(data));
        if (json is Map && json['message'] is String) {
          return ApiError(json['message'] as String, statusCode: e.response?.statusCode);
        }
      } catch (_) {
        // Not JSON: fall through to the generic sentence.
      }
    }
    return ApiError.from(e);
  }
}
