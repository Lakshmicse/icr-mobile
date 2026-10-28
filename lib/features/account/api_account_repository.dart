import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import 'account_models.dart';
import 'account_repository.dart';

/// The account screens against the ICR API, through the signed-in client.
/// Every failure comes out as an [ApiError] carrying the API's own sentence.
class ApiAccountRepository implements AccountRepository {
  ApiAccountRepository({required this.api});

  final ApiClient api;

  Future<T> _call<T>(Future<T> Function(Dio dio) body) async {
    try {
      return await body(api.dio);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<Map<String, dynamic>> _getMap(String path, [Map<String, dynamic>? query]) => _call(
    (dio) async => (await dio.get<Map<String, dynamic>>(path, queryParameters: query)).data ?? const {},
  );

  Future<List<Map<String, dynamic>>> _getList(String path, [Map<String, dynamic>? query]) => _call((dio) async {
    final data = (await dio.get<dynamic>(path, queryParameters: query)).data;
    final rows = data is List ? data : (data is Map ? data['data'] as List? : null) ?? const [];
    return [
      for (final r in rows)
        if (r is Map) r.cast<String, dynamic>(),
    ];
  });

  // --- lookups -----------------------------------------------------------------------------------------------

  @override
  Future<List<String>> jobTitles() async => [
    for (final t in await _getList('/job-titles'))
      if (t['active'] != false && t['name'] is String) t['name'] as String,
  ];

  @override
  Future<List<CompanyHit>> searchCompanies(String query) async =>
      (await _getList('/companies', {'search': query.trim(), 'limit': 8})).map(CompanyHit.fromJson).toList();

  @override
  Future<List<CityOption>> cities() async => (await _getList('/locations/cities')).map(CityOption.fromJson).toList();

  // --- my profile --------------------------------------------------------------------------------------------

  @override
  Future<MyProfile> myProfile() async => MyProfile.fromJson(await _getMap('/users/me/profile'));

  @override
  Future<List<Experience>> experience() async =>
      (await _getList('/profile/experience')).map(Experience.fromJson).toList();

  @override
  Future<List<Education>> education() async => (await _getList('/profile/education')).map(Education.fromJson).toList();

  @override
  Future<List<CareerBreak>> careerBreaks() async =>
      (await _getList('/profile/career-breaks')).map(CareerBreak.fromJson).toList();

  @override
  Future<ProfileLinks> links() async => ProfileLinks.fromJson(await _getMap('/profile/links'));

  @override
  Future<List<Credential>> credentials() async {
    final json = await _getMap('/credentials/me');
    return [
      for (final c in (json['credentials'] as List? ?? const []))
        if (c is Map) Credential.fromJson(c.cast<String, dynamic>()),
    ];
  }

  @override
  Future<MyProfile> updateMe(Map<String, Object?> patch) => _call(
    (dio) async => MyProfile.fromJson((await dio.patch<Map<String, dynamic>>('/users/me', data: patch)).data!),
  );

  @override
  Future<MyProfile> updateResume(Map<String, Object?> patch) => _call(
    (dio) async => MyProfile.fromJson((await dio.patch<Map<String, dynamic>>('/users/me/resume', data: patch)).data!),
  );

  Future<List<Map<String, dynamic>>> _put(String path, List<Map<String, dynamic>> rows) => _call((dio) async {
    final data = (await dio.put<List<dynamic>>(path, data: {'rows': rows})).data ?? const [];
    return [
      for (final r in data)
        if (r is Map) r.cast<String, dynamic>(),
    ];
  });

  @override
  Future<List<Experience>> saveExperience(List<Experience> rows) async => (await _put('/profile/experience', [
    for (final r in rows)
      if (r.title.trim().isNotEmpty && r.organisation.trim().isNotEmpty) r.toRow(),
  ])).map(Experience.fromJson).toList();

  @override
  Future<List<Education>> saveEducation(List<Education> rows) async => (await _put('/profile/education', [
    for (final r in rows)
      if (r.institution.trim().isNotEmpty) r.toRow(),
  ])).map(Education.fromJson).toList();

  @override
  Future<List<CareerBreak>> saveCareerBreaks(List<CareerBreak> rows) async => (await _put('/profile/career-breaks', [
    for (final r in rows) r.toRow(),
  ])).map(CareerBreak.fromJson).toList();

  @override
  Future<ProfileLinks> saveLinks(Map<String, String> links) => _call(
    (dio) async => ProfileLinks.fromJson((await dio.patch<Map<String, dynamic>>('/profile/links', data: links)).data!),
  );

  @override
  Future<UploadedFile> upload(PickedPhoto file, {String? purpose}) => _call((dio) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(file.bytes, filename: file.name, contentType: DioMediaType.parse(file.contentType)),
    });
    final res = await dio.post<Map<String, dynamic>>(
      '/uploads',
      data: form,
      queryParameters: {'purpose': ?purpose},
    );
    final data = res.data!;
    return UploadedFile(url: data['url'] as String, name: data['name'] as String? ?? file.name);
  });

  @override
  Future<String?> sendPhoneCode(String phone) => _call(
    (dio) async =>
        (await dio.post<Map<String, dynamic>>('/users/me/phone/send-otp', data: {'phone': phone})).data?['code']
            as String?,
  );

  @override
  Future<void> verifyPhoneCode(String phone, String code) =>
      _call((dio) => dio.post<void>('/users/me/phone/verify-otp', data: {'phone': phone, 'code': code}));

  @override
  Future<void> addCredential(CredentialDraft draft) =>
      _call((dio) => dio.post<void>('/credentials/me', data: draft.toJson()));

  @override
  Future<void> updateCredential(String id, CredentialDraft draft) =>
      _call((dio) => dio.patch<void>('/credentials/me/$id', data: draft.toJson()));

  @override
  Future<String?> deleteCredential(String id) => _call(
    (dio) async =>
        (await dio.delete<Map<String, dynamic>>('/credentials/me/$id')).data?['removedFromMentorProfile'] as String?,
  );

  // --- other members -----------------------------------------------------------------------------------------

  @override
  Future<MemberProfile> member(String idOrSlug) async =>
      MemberProfile.fromJson(await _getMap('/members/${Uri.encodeComponent(idOrSlug)}'));

  @override
  Future<FollowState> follow(String memberId) => _call(
    (dio) async => FollowState.fromJson((await dio.post<Map<String, dynamic>>('/members/$memberId/follow')).data),
  );

  @override
  Future<FollowState> unfollow(String memberId) => _call(
    (dio) async => FollowState.fromJson((await dio.delete<Map<String, dynamic>>('/members/$memberId/follow')).data),
  );

  @override
  Future<List<ForumPost>> memberPosts(String userId, {int limit = 5}) async => (await _getList('/forum/threads', {
    'authorId': userId,
    'limit': limit,
    'sort': 'latest',
  })).map(ForumPost.fromJson).toList();

  @override
  Future<String> startConversation(String userId) => _call(
    (dio) async =>
        (await dio.post<Map<String, dynamic>>(
              '/messaging/conversations',
              data: {
                'participantIds': [userId],
              },
            )).data!['id']
            as String,
  );

  // --- companies ---------------------------------------------------------------------------------------------

  @override
  Future<MyCompanies> myCompanies() async => MyCompanies.fromJson(await _getMap('/me/companies'));

  Future<SessionTokens> _tokens(Future<Response<Map<String, dynamic>>> Function(Dio dio) send) =>
      _call((dio) async => SessionTokens.fromJson((await send(dio)).data!));

  @override
  Future<SessionTokens> switchCompany(String? companyId) =>
      _tokens((dio) => dio.post<Map<String, dynamic>>('/me/companies/switch', data: {'companyId': companyId}));

  @override
  Future<SessionTokens> leaveCompany(String companyId) =>
      _tokens((dio) => dio.post<Map<String, dynamic>>('/me/companies/$companyId/leave'));

  @override
  Future<MyCompanies> withdrawRequest(String companyId) => _call(
    (dio) async =>
        MyCompanies.fromJson((await dio.delete<Map<String, dynamic>>('/me/companies/requests/$companyId')).data!),
  );

  @override
  Future<SessionTokens> createCompany(CompanyDraft draft) =>
      _tokens((dio) => dio.post<Map<String, dynamic>>('/me/companies', data: draft.toJson()));

  @override
  Future<List<CompanyLookalike>> lookalikes({String? name, String? website}) async =>
      (await _getList('/me/companies/lookalikes', {
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (website != null && website.trim().isNotEmpty) 'website': website.trim(),
      })).map(CompanyLookalike.fromJson).toList();

  @override
  Future<void> requestToJoin(String companyId, {String? note}) => _call(
    (dio) => dio.post<void>(
      '/team/companies/$companyId/join-requests',
      data: {if (note != null && note.trim().isNotEmpty) 'note': note.trim()},
    ),
  );

  // --- settings ----------------------------------------------------------------------------------------------

  @override
  Future<String?> accountLocale() async => (await _getMap('/auth/me'))['locale'] as String?;

  @override
  Future<List<NotificationPreference>> notificationPreferences() async =>
      (await _getList('/notifications/preferences')).map(NotificationPreference.fromJson).toList();

  @override
  Future<List<NotificationPreference>> saveNotificationPreferences(List<NotificationPreference> rows) =>
      _call((dio) async {
        final data =
            (await dio.put<List<dynamic>>(
              '/notifications/preferences',
              data: {
                'preferences': [
                  for (final r in rows) {'category': r.category, 'inApp': r.inApp, 'email': r.email},
                ],
              },
            )).data ??
            const [];
        return [
          for (final r in data)
            if (r is Map) NotificationPreference.fromJson(r.cast<String, dynamic>()),
        ];
      });

  @override
  Future<Map<String, dynamic>> exportData() => _getMap('/users/me/export');

  @override
  Future<void> deleteAccount() => _call((dio) => dio.delete<void>('/users/me'));
}
