import 'package:dio/dio.dart' show DioMediaType, FormData, MultipartFile, Options;

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import 'become_mentor_models.dart';

/// Everything the become-a-mentor flow reads and writes, on the real API.
///
/// Two halves, as the website's composer says out loud: the PERSON's half
/// (photo, current role, years, languages, work history) is the member's own
/// profile, edited through `PATCH /users/me` and `PUT /profile/experience`;
/// the MENTORING half is `PUT /mentorship/mentors/me`, a partial patch whose
/// first save creates the DRAFT.
class BecomeMentorRepository {
  BecomeMentorRepository({required this.api});

  final ApiClient api;

  // --- the mentor profile ---------------------------------------------------------

  /// The caller's mentor profile; null when they have none (the API answers 200 with an empty body).
  Future<MyMentorProfile?> mine() async {
    final res = await _get('/mentorship/mentors/me');
    return res.isEmpty ? null : MyMentorProfile.fromJson(res);
  }

  /// Saves what is sent, and only that. A list is cleared with `[]`, a scalar with `null`. The first save creates
  /// the DRAFT.
  Future<MyMentorProfile> save(Map<String, dynamic> patch) async =>
      MyMentorProfile.fromJson((await _send('PUT', '/mentorship/mentors/me', patch)) as Map<String, dynamic>);

  /// Sends the profile to ICR's review team.
  Future<MyMentorProfile> submit() async =>
      MyMentorProfile.fromJson((await _send('POST', '/mentorship/mentors/me/submit')) as Map<String, dynamic>);

  /// Hides the profile from the directory and keeps the history. The API refuses while mentorships are under way.
  Future<void> withdraw() => _send('DELETE', '/mentorship/mentors/me');

  /// "Accepting new requests", on its own.
  Future<MyMentorProfile> setVisibility(bool discoverable) async => MyMentorProfile.fromJson(
    (await _send('PATCH', '/mentorship/mentors/me/visibility', {'discoverable': discoverable})) as Map<String, dynamic>,
  );

  /// Replaces the weekly hours (`[]` clears them).
  Future<MyMentorProfile> saveAvailability(List<AvailabilityBlock> blocks) async => MyMentorProfile.fromJson(
    (await _send('PUT', '/mentorship/mentors/me/availability', {
          'blocks': [for (final b in blocks) b.toJson()],
        }))
        as Map<String, dynamic>,
  );

  // --- the gates ------------------------------------------------------------------

  Future<MentorReadiness> readiness() async => MentorReadiness.fromJson(await _get('/mentorship/mentors/me/readiness'));

  Future<CodeOfConduct> codeOfConduct() async => CodeOfConduct.fromJson(await _get('/mentorship/code-of-conduct'));

  /// Records the agreement to [version]. The API refuses a version that is not the current one.
  Future<void> acceptConduct(String version) =>
      _send('POST', '/mentorship/mentors/me/code-of-conduct', {'version': version});

  // --- evidence -------------------------------------------------------------------

  Future<List<MentorDocument>> documents() async => [
    for (final d in await _getList('/mentorship/mentors/me/documents')) MentorDocument.fromJson(d),
  ];

  /// Attaches a file already uploaded (see [upload]).
  Future<void> addDocument({
    required String kind,
    required String fileUrl,
    String? label,
    String? fileName,
    int? fileSize,
  }) => _send('POST', '/mentorship/mentors/me/documents', {
    'kind': kind,
    'fileUrl': fileUrl,
    if (label != null && label.trim().isNotEmpty) 'label': label.trim(),
    'fileName': ?fileName,
    'fileSize': ?fileSize,
  });

  Future<void> removeDocument(String id) => _send('DELETE', '/mentorship/mentors/me/documents/$id');

  /// Uploads a file (`POST /uploads?purpose=`). The answer's `url` is root-relative (`/uploads/<hash>.pdf`).
  Future<({String url, String name, int size})> upload(PickedFile file, {required String purpose}) async {
    try {
      final mime = file.mimeType ?? _mimeFor(file.name);
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          file.bytes,
          filename: file.name,
          contentType: mime == null ? null : DioMediaType.parse(mime),
        ),
      });
      final res = await api.dio.post<Map<String, dynamic>>(
        '/uploads',
        data: form,
        queryParameters: {'purpose': purpose},
      );
      final d = res.data ?? const {};
      return (
        url: d['url'] as String,
        name: d['name'] as String? ?? file.name,
        size: (d['size'] as num?)?.toInt() ?? file.bytes.length,
      );
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  static String? _mimeFor(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    return switch (ext) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      _ => null,
    };
  }

  // --- the person -----------------------------------------------------------------

  Future<PersonProfile> person() async => PersonProfile.fromJson(await _get('/users/me/profile'));

  /// Writes the person's own fields (`designation`, `yearsExperience`, `languages`, `avatarUrl`). An empty
  /// string clears the role or the photo, `null` clears the years.
  Future<void> updatePerson(Map<String, dynamic> patch) => _send('PATCH', '/users/me', patch);

  Future<List<ExperienceRow>> experience() async => [
    for (final r in await _getList('/profile/experience')) ExperienceRow.fromJson(r),
  ];

  /// Saves the whole career history (the API replaces the list).
  Future<void> replaceExperience(List<ExperienceRow> rows) => _send('PUT', '/profile/experience', {
    'rows': [for (final r in rows) r.toJson()],
  });

  /// The credentials the member holds with a short code a mentor card can show: never a rejected one.
  Future<List<HeldCredential>> credentials() async {
    final res = await _get('/credentials/me');
    final byCode = <String, HeldCredential>{};
    for (final c in (res['credentials'] as List? ?? const []).whereType<Map<String, dynamic>>()) {
      final code = (c['code'] as String?)?.trim().toUpperCase();
      if (code == null || code.isEmpty || c['status'] == 'REJECTED') continue;
      final verified = c['status'] == 'VERIFIED';
      final seen = byCode[code];
      if (seen == null || (!seen.verified && verified)) {
        byCode[code] = HeldCredential(code: code, label: c['name'] as String? ?? code, verified: verified);
      }
    }
    return byCode.values.toList();
  }

  /// ICR's list of job titles, for a role to be picked from (any other text is accepted too).
  Future<List<String>> jobTitles() async => [
    for (final t in await _getList('/job-titles'))
      if (t['name'] is String) t['name'] as String,
  ];

  // --- transport ------------------------------------------------------------------

  Future<Map<String, dynamic>> _get(String path) async {
    try {
      final res = await api.dio.get<dynamic>(path);
      final data = res.data;
      return data is Map<String, dynamic> ? data : const {};
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<List<Map<String, dynamic>>> _getList(String path) async {
    try {
      final res = await api.dio.get<dynamic>(path);
      final data = res.data;
      if (data is List) return data.whereType<Map<String, dynamic>>().toList();
      if (data is Map && data['data'] is List) return (data['data'] as List).whereType<Map<String, dynamic>>().toList();
      return const [];
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<dynamic> _send(String method, String path, [Map<String, dynamic>? body]) async {
    try {
      final res = await api.dio.request<dynamic>(
        path,
        data: body,
        options: Options(method: method),
      );
      return res.data;
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}
