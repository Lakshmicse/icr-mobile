import 'package:dio/dio.dart' show Options;

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/config.dart';
import 'learning_format.dart';
import 'learning_models.dart';
import 'learning_repository.dart';

/// The Learning screens from the API: the catalogue (`GET /learning/courses`),
/// a course (`GET /learning/courses/:code`, runs and syllabus included), the
/// member's enrolments, a course's reviews, and enrolment and enquiries.
class ApiLearningRepository implements LearningRepository {
  ApiLearningRepository({required this.api});

  final ApiClient api;

  Map<String, MyEnrolment>? _mine;

  @override
  Future<List<Course>> courses() async {
    await _loadMine(force: true);
    final rows = await _list('/learning/courses');
    return rows.map(_course).toList();
  }

  @override
  Future<Course> detail(Course course) async {
    await _loadMine();
    final json = await _get('/learning/courses/${Uri.encodeComponent(course.code)}');
    return _course(json, detail: true);
  }

  @override
  Future<List<MyEnrolment>> myEnrolments() async {
    await _loadMine(force: true);
    return _mine!.values.toList();
  }

  /// How many reviews the sheet loads; the site's own page asks for a page at a time.
  static const reviewsPerPage = 20;

  @override
  Future<CourseReviews> reviews(Course course) async {
    try {
      final res = await _get('/learning/courses/${Uri.encodeComponent(course.code)}/reviews', {
        'page': 1,
        'limit': reviewsPerPage,
      });
      final rows = (res['data'] as List? ?? const []).cast<Map<String, dynamic>>();
      final meta = res['meta'] as Map<String, dynamic>? ?? const {};
      return CourseReviews(
        total: (meta['total'] as num?)?.toInt() ?? rows.length,
        items: [
          for (final r in rows)
            if ((r['body'] as String? ?? '').trim().isNotEmpty) _review(r),
        ],
      );
    } catch (_) {
      return const CourseReviews();
    }
  }

  CourseReview _review(Map<String, dynamic> r) {
    final author = r['author'] as Map<String, dynamic>? ?? const {};
    return CourseReview(
      id: r['id'] as String? ?? '',
      body: (r['body'] as String? ?? '').trim(),
      author: author['name'] as String? ?? 'An ICR member',
      role: _text(r['roleLabel']),
      photo: _picture(author['avatarUrl'] as String?),
      rating: (r['rating'] as num?)?.toInt(),
    );
  }

  @override
  Future<MyEnrolment> enrol(Course course, {CourseRun? run}) async {
    final res = await _send('POST', '/learning/courses/${Uri.encodeComponent(course.code)}/enroll', {
      if (run != null) 'batchId': run.id,
    });
    final json = (res as Map<String, dynamic>?)?['enrollment'] as Map<String, dynamic>? ?? const {};
    final mine = MyEnrolment(
      id: json['id'] as String? ?? '',
      courseId: json['courseId'] as String? ?? course.id,
      runId: json['batchId'] as String? ?? run?.id,
      status: EnrolmentStatus.fromApi(json['status'] as String?),
      startsAt: run?.startsAt,
      endsAt: run?.endsAt,
      location: run?.location,
    );
    (_mine ??= {})[mine.courseId] = mine;
    return mine;
  }

  @override
  Future<void> withdraw(Course course) async {
    await _send('DELETE', '/learning/courses/${Uri.encodeComponent(course.id)}/enroll');
    _mine?.remove(course.id);
  }

  @override
  Future<void> enquire(
    Course course, {
    required String message,
    EnquiryKind kind = EnquiryKind.question,
    String? company,
    int? headcount,
  }) async {
    final me = await _get('/auth/me');
    final user = (me['user'] as Map<String, dynamic>?) ?? me;
    final name = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
    final corporate = kind == EnquiryKind.inHouse;
    await _send('POST', '/learning/courses/${Uri.encodeComponent(course.code)}/enquire', {
      'name': name.isEmpty ? 'ICR member' : name,
      'email': user['email'],
      'message': message.trim(),
      if (corporate) 'kind': 'CORPORATE',
      if (corporate && company != null && company.trim().isNotEmpty) 'company': company.trim(),
      if (corporate && headcount != null) 'headcount': headcount,
    });
  }

  @override
  Future<int> unreadNotifications() async {
    final res = await _get('/notifications/unread-count');
    return (res['unread'] as num?)?.toInt() ?? 0;
  }

  @override
  Uri link(Course course) => AppConfig.sitePage('/learning/professional-development/${course.code}');

  @override
  Uri checkoutLink(Course course, CourseRun? run) =>
      AppConfig.sitePage('/learning/professional-development/${course.code}#enrol');

  // --- mapping -------------------------------------------------------------

  Course _course(Map<String, dynamic> json, {bool detail = false}) {
    final kind = CourseKind.fromApi(json['kind'] as String?);
    final providerJson = json['provider'] as Map<String, dynamic>?;
    final provider = providerJson == null ? null : _provider(providerJson);
    final id = json['id'] as String;
    final runs = (json['batches'] as List? ?? const []).cast<Map<String, dynamic>>().map((b) => _run(b, id)).toList();
    final title = json['title'] as String? ?? '';
    final cpd = (json['cpdCredits'] as num?)?.toInt() ?? 0;
    final certificateEnabled = json['certificateEnabled'] == true;
    final contact = runs.map((r) => r.specialist).firstWhere((c) => c != null, orElse: () => null);
    return Course(
      id: id,
      code: json['code'] as String? ?? json['slug'] as String? ?? id,
      slug: json['slug'] as String?,
      title: title,
      summary: _text(json['summary']),
      description: _text(json['description']),
      kind: kind,
      level: levelLabel(json['level'] as String?),
      provider: provider,
      cover: _picture(json['imageUrl'] as String?),
      badge: coverBadge(json['level'] as String?, kind, certificateEnabled: certificateEnabled),
      priceAmount: (json['priceAmount'] as num?)?.toInt(),
      priceCurrency: json['priceCurrency'] as String? ?? 'INR',
      durationLabel: _text(json['durationLabel']),
      deliveryMode: _text(json['deliveryMode']),
      language: _text(json['language']),
      cpdCredits: cpd,
      certificateEnabled: certificateEnabled,
      enrollmentOpen: json['enrollmentOpen'] != false,
      batchStartsAt: _date(json['batchStartsAt']),
      full: json['full'] == true,
      waitlistEnabled: json['waitlistEnabled'] != false,
      brochureUrl: AppConfig.absoluteUrl(json['brochureUrl'] as String?, apiBase: api.dio.options.baseUrl),
      runs: runs,
      modules: [
        for (final m in (json['modules'] as List? ?? const []).cast<Map<String, dynamic>>())
          CourseModule(
            id: m['id'] as String? ?? '',
            title: m['title'] as String? ?? '',
            summary: _text(m['summary']),
            lessons: _strings(m['topics']),
          ),
      ],
      outcomes: _strings(json['learningOutcomes']),
      prerequisites: _strings(json['prerequisites']),
      audience: _strings(json['audience']),
      aboutCertificate: detail
          ? aboutCertificateText(
              provider: provider,
              cpdCredits: cpd,
              certificateEnabled: certificateEnabled,
              deliveryMode: _text(json['deliveryMode']),
            )
          : null,
      certificateBadges: [?provider?.logo],
      contact: contact,
      enrolment: _mine?[id],
      detailLoaded: detail,
    );
  }

  CourseProvider _provider(Map<String, dynamic> json) => CourseProvider(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? 'A partner institute',
    slug: json['slug'] as String?,
    logo: _picture(json['logoUrl'] as String?),
    website: json['website'] as String?,
    verified: json['verified'] == true,
  );

  CourseRun _run(Map<String, dynamic> json, String courseId) {
    final specialist = json['enrolmentSpecialist'] as Map<String, dynamic>?;
    final trainer = json['trainer'] as Map<String, dynamic>?;
    return CourseRun(
      id: json['id'] as String,
      courseId: json['courseId'] as String? ?? courseId,
      code: json['code'] as String? ?? '',
      title: _text(json['title']),
      mode: DeliveryMode.fromApi(json['mode'] as String?),
      startsAt: _date(json['startsAt']) ?? DateTime.now(),
      endsAt: _date(json['endsAt']),
      location: _text(json['location']),
      seatsCapacity: (json['seatsCapacity'] as num?)?.toInt(),
      seatsRemaining: (json['seatsRemaining'] as num?)?.toInt(),
      full: json['full'] == true,
      waitlistEnabled: json['waitlistEnabled'] != false,
      priceAmount: (json['priceAmount'] as num?)?.toInt(),
      priceCurrency: json['priceCurrency'] as String? ?? 'INR',
      durationLabel: _text(json['durationLabel']),
      schedule: _text(json['schedule']),
      instructor: trainer?['name'] as String? ?? _text(json['instructor']),
      specialist: specialist == null
          ? null
          : CourseContact(
              name: specialist['name'] as String? ?? 'Enrolment specialist',
              role: _text(specialist['title']) ?? 'Specialist – Program Enrollment',
              photo: _picture(specialist['photoUrl'] as String?),
            ),
    );
  }

  static String? _text(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  static DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

  static List<String> _strings(Object? v) =>
      (v as List? ?? const []).map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();

  FeedPicture? _picture(String? path) {
    final url = AppConfig.absoluteUrl(path, apiBase: api.dio.options.baseUrl);
    return url == null ? null : FeedPicture.network(url);
  }

  // --- the member's own places ------------------------------------------------

  Future<void> _loadMine({bool force = false}) async {
    if (!force && _mine != null) return;
    try {
      final rows = await _list('/learning/me/enrollments');
      _mine = {
        for (final r in rows)
          (r['courseId'] as String? ?? (r['course'] as Map<String, dynamic>?)?['id'] as String? ?? ''): MyEnrolment(
            id: r['id'] as String? ?? '',
            courseId: r['courseId'] as String? ?? '',
            runId: r['batchId'] as String?,
            status: EnrolmentStatus.fromApi(r['status'] as String?),
            startsAt: _date((r['batch'] as Map<String, dynamic>?)?['startsAt'] ?? r['batchStartsAt']),
            endsAt: _date((r['batch'] as Map<String, dynamic>?)?['endsAt']),
            location: _text((r['batch'] as Map<String, dynamic>?)?['location']),
          ),
      };
    } catch (_) {
      _mine ??= {};
    }
  }

  // --- transport -------------------------------------------------------------

  Future<List<Map<String, dynamic>>> _list(String path, [Map<String, dynamic>? query]) async {
    try {
      final res = await api.dio.get<dynamic>(path, queryParameters: query);
      final data = res.data;
      final rows = data is List ? data : (data is Map ? data['data'] as List? : null);
      return (rows ?? const []).cast<Map<String, dynamic>>();
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<Map<String, dynamic>> _get(String path, [Map<String, dynamic>? query]) async {
    try {
      final res = await api.dio.get<Map<String, dynamic>>(path, queryParameters: query);
      return res.data ?? const {};
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
