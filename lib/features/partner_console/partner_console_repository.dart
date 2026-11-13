import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import 'partner_console_models.dart';

/// The partner institute's Learning console: what the website's Courses, Batches and Enrolments pages read and
/// change, every call under `/learning/admin` (scoped to the caller's institute by `providerScopeOf`).
abstract class PartnerConsoleRepository {
  /// `GET /learning/admin/me`.
  Future<ConsoleContext> context();

  /// `GET /learning/admin/courses?kind=DEVELOPMENT` — drafts and archived courses included.
  Future<List<ConsoleCourse>> courses();

  /// `POST /learning/admin/courses`.
  Future<ConsoleCourse> createCourse(Map<String, Object?> body);

  /// `PATCH /learning/admin/courses/:id`.
  Future<ConsoleCourse> updateCourse(String id, Map<String, Object?> body);

  /// `DELETE /learning/admin/courses/:id`.
  Future<void> deleteCourse(String id);

  /// `POST /learning/admin/courses/:id/submit` — hand the course to ICR's reviewers.
  Future<ConsoleCourse> submitCourse(String id);

  /// `POST /learning/admin/courses/:id/withdraw` — take it back while ICR has not ruled.
  Future<ConsoleCourse> withdrawCourse(String id);

  /// `GET /learning/admin/batches[?courseId=]` — past and cancelled batches included.
  Future<List<ConsoleBatch>> batches({String? courseId});

  /// `POST /learning/admin/courses/:courseId/batches`.
  Future<ConsoleBatch> createBatch(String courseId, Map<String, Object?> body);

  /// `PATCH /learning/admin/batches/:id`.
  Future<ConsoleBatch> updateBatch(String id, Map<String, Object?> body);

  /// `DELETE /learning/admin/batches/:id`.
  Future<void> deleteBatch(String id);

  /// `POST /learning/admin/batches/:id/trainers/:trainerId/invite` — ask a trainer again after they declined.
  Future<void> reinviteTrainer(String batchId, String trainerId);

  /// `GET /learning/admin/trainers` — the institute's trainers and enrolment specialists.
  Future<List<FacultyMember>> faculty();

  /// `GET /learning/admin/enrollments?courseId=&status=&page=&limit=25`.
  Future<EnrolmentsPage> enrolments({String? courseId, String? status, int page = 1});

  /// `PATCH /learning/admin/enrollments/:id { status }`.
  Future<ConsoleEnrolment> setEnrolmentStatus(String id, String status);

  /// `GET /categories/tree?kind=SERVICE&depth=2` — where a course may be filed.
  Future<List<CourseCategory>> categories();

  /// `POST /uploads?purpose=learning` — a cover image or a brochure, stored publicly; returns the file's URL.
  Future<String> upload(UploadFile file);
}

class ApiPartnerConsoleRepository implements PartnerConsoleRepository {
  ApiPartnerConsoleRepository({required this.api});

  final ApiClient api;

  static const _base = '/learning/admin';

  Future<T> _call<T>(Future<T> Function(Dio dio) body) async {
    try {
      return await body(api.dio);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Map<String, dynamic> _map(Object? data) => data is Map ? data.cast<String, dynamic>() : const {};

  List<Map<String, dynamic>> _rows(Object? data) => [
    for (final r in data is List ? data : const [])
      if (r is Map) r.cast<String, dynamic>(),
  ];

  @override
  Future<ConsoleContext> context() =>
      _call((dio) async => ConsoleContext.fromJson(_map((await dio.get<dynamic>('$_base/me')).data)));

  @override
  Future<List<ConsoleCourse>> courses() => _call((dio) async {
    final res = await dio.get<dynamic>('$_base/courses', queryParameters: {'kind': 'DEVELOPMENT'});
    return [for (final r in _rows(res.data)) ConsoleCourse.fromJson(r)];
  });

  @override
  Future<ConsoleCourse> createCourse(Map<String, Object?> body) =>
      _call((dio) async => ConsoleCourse.fromJson(_map((await dio.post<dynamic>('$_base/courses', data: body)).data)));

  @override
  Future<ConsoleCourse> updateCourse(String id, Map<String, Object?> body) => _call(
    (dio) async => ConsoleCourse.fromJson(
      _map((await dio.patch<dynamic>('$_base/courses/${Uri.encodeComponent(id)}', data: body)).data),
    ),
  );

  @override
  Future<void> deleteCourse(String id) => _call((dio) => dio.delete<void>('$_base/courses/${Uri.encodeComponent(id)}'));

  @override
  Future<ConsoleCourse> submitCourse(String id) => _call(
    (dio) async => ConsoleCourse.fromJson(
      _map((await dio.post<dynamic>('$_base/courses/${Uri.encodeComponent(id)}/submit')).data),
    ),
  );

  @override
  Future<ConsoleCourse> withdrawCourse(String id) => _call(
    (dio) async => ConsoleCourse.fromJson(
      _map((await dio.post<dynamic>('$_base/courses/${Uri.encodeComponent(id)}/withdraw')).data),
    ),
  );

  @override
  Future<List<ConsoleBatch>> batches({String? courseId}) => _call((dio) async {
    final res = await dio.get<dynamic>(
      '$_base/batches',
      queryParameters: {if (courseId != null && courseId.isNotEmpty) 'courseId': courseId},
    );
    return [for (final r in _rows(res.data)) ConsoleBatch.fromJson(r)];
  });

  @override
  Future<ConsoleBatch> createBatch(String courseId, Map<String, Object?> body) => _call(
    (dio) async => ConsoleBatch.fromJson(
      _map((await dio.post<dynamic>('$_base/courses/${Uri.encodeComponent(courseId)}/batches', data: body)).data),
    ),
  );

  @override
  Future<ConsoleBatch> updateBatch(String id, Map<String, Object?> body) => _call(
    (dio) async => ConsoleBatch.fromJson(
      _map((await dio.patch<dynamic>('$_base/batches/${Uri.encodeComponent(id)}', data: body)).data),
    ),
  );

  @override
  Future<void> deleteBatch(String id) => _call((dio) => dio.delete<void>('$_base/batches/${Uri.encodeComponent(id)}'));

  @override
  Future<void> reinviteTrainer(String batchId, String trainerId) => _call(
    (dio) => dio.post<void>(
      '$_base/batches/${Uri.encodeComponent(batchId)}/trainers/${Uri.encodeComponent(trainerId)}/invite',
    ),
  );

  @override
  Future<List<FacultyMember>> faculty() => _call((dio) async {
    final res = await dio.get<dynamic>('$_base/trainers');
    return [for (final r in _rows(res.data)) FacultyMember.fromJson(r)];
  });

  @override
  Future<EnrolmentsPage> enrolments({String? courseId, String? status, int page = 1}) => _call((dio) async {
    final res = await dio.get<dynamic>(
      '$_base/enrollments',
      queryParameters: {
        'page': page,
        'limit': 25,
        if (courseId != null && courseId.isNotEmpty) 'courseId': courseId,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return EnrolmentsPage.fromJson(_map(res.data));
  });

  @override
  Future<ConsoleEnrolment> setEnrolmentStatus(String id, String status) => _call(
    (dio) async => ConsoleEnrolment.fromJson(
      _map((await dio.patch<dynamic>('$_base/enrollments/${Uri.encodeComponent(id)}', data: {'status': status})).data),
    ),
  );

  @override
  Future<List<CourseCategory>> categories() => _call((dio) async {
    final res = await dio.get<dynamic>('/categories/tree', queryParameters: {'kind': 'SERVICE', 'depth': 2});
    return [
      for (final r in _rows(res.data))
        if (r['active'] != false && r['key'] != null) CourseCategory.fromJson(r),
    ];
  });

  @override
  Future<String> upload(UploadFile file) => _call((dio) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(file.bytes, filename: file.name, contentType: DioMediaType.parse(file.mimeType)),
    });
    final res = await dio.post<dynamic>('/uploads', data: form, queryParameters: {'purpose': 'learning'});
    final url = _map(res.data)['url'];
    if (url is! String || url.isEmpty) throw ApiError('Upload failed. Check the file and try again.');
    return url;
  });
}

/// A sample institute for the demo and for tests, kept in memory and changed in place: two courses (one live
/// with a batch ahead, one draft with a scheduled batch), their batches, a team of three and a few enrolments.
class DemoPartnerConsoleRepository implements PartnerConsoleRepository {
  DemoPartnerConsoleRepository({
    List<ConsoleCourse>? courses,
    List<ConsoleBatch>? batches,
    List<ConsoleEnrolment>? enrolments,
    List<FacultyMember>? faculty,
    ConsoleContext? context,
    this.delay = Duration.zero,
    this.failList = false,
    this.refuse,
    this.lockEnrolments,
  }) : courseRows = courses ?? sampleCourses(),
       batchRows = batches ?? sampleBatches(),
       enrolmentRows = enrolments ?? sampleEnrolments(),
       facultyRows = faculty ?? sampleFaculty(),
       consoleContext = context ?? sampleContext;

  final List<ConsoleCourse> courseRows;
  final List<ConsoleBatch> batchRows;
  final List<ConsoleEnrolment> enrolmentRows;
  final List<FacultyMember> facultyRows;
  final ConsoleContext consoleContext;
  final Duration delay;

  /// Every list read fails ("Could not load…").
  final bool failList;

  /// Every change is refused with this sentence (the API's refusal, shown as the website shows it).
  final String? refuse;

  /// The enrolments list answers 403 with this sentence: the institute's plan leaves participant management out.
  final String? lockEnrolments;

  /// Every change sent, in order (tests).
  final sent = <Map<String, Object?>>[];

  int _n = 0;

  static const sampleContext = ConsoleContext(
    isPartner: true,
    providerId: 'inst-1',
    providerName: 'Demo Learning Institute',
    partnerStatus: 'ACTIVE',
    capabilities: ['COURSE_LISTING', 'MATERIALS', 'BATCHES', 'ENROLMENT', 'ASSESSMENTS', 'CERTIFICATES'],
  );

  static List<ConsoleBatch> sampleBatches() => [
    ConsoleBatch(
      id: 'batch-1',
      courseId: 'course-1',
      title: 'March 2027 — weekend',
      code: 'FMF-202703',
      status: 'OPEN',
      mode: 'VIRTUAL',
      startsAt: DateTime.utc(2027, 3, 6),
      endsAt: DateTime.utc(2027, 4, 25),
      durationLabel: '16 classes · 48 hours',
      durationHours: 48,
      schedule: 'Sat & Sun, 10:00–13:00',
      classDays: const [6, 0],
      classStartTime: '10:00',
      classEndTime: '13:00',
      timezone: 'Asia/Kolkata',
      maxSeats: 25,
      seatsTaken: 9,
      seatsCapacity: 25,
      priceAmount: 1800000,
      discountPercent: 10,
      discountEndsOn: '2027-02-15',
      trainerPlaces: const [
        TrainerPlace(trainerId: 'tr-1', name: 'Meera Iyer', status: 'ACCEPTED'),
        TrainerPlace(trainerId: 'tr-2', name: 'Arjun Shetty', status: 'INVITED'),
      ],
      enrolmentSpecialistId: 'tr-3',
      enrolmentSpecialistName: 'Kavya Rao',
      courseCode: 'FMF',
      courseTitle: 'Facility Management Fundamentals',
      notes: 'Second weekend run; the first filled in three weeks.',
    ),
    ConsoleBatch(
      id: 'batch-2',
      courseId: 'course-1',
      title: null,
      code: 'FMF-202610',
      status: 'COMPLETED',
      mode: 'IN_PERSON',
      startsAt: DateTime.utc(2026, 10, 3),
      endsAt: DateTime.utc(2026, 10, 25),
      durationLabel: '8 classes · 24 hours',
      schedule: 'Sat & Sun, 10:00–13:00',
      classDays: const [6, 0],
      classStartTime: '10:00',
      classEndTime: '13:00',
      timezone: 'Asia/Kolkata',
      location: 'Bengaluru campus, Koramangala',
      maxSeats: 20,
      seatsTaken: 20,
      seatsCapacity: 20,
      full: true,
      priceAmount: 2200000,
      trainerPlaces: const [TrainerPlace(trainerId: 'tr-1', name: 'Meera Iyer', status: 'ACCEPTED')],
      courseCode: 'FMF',
      courseTitle: 'Facility Management Fundamentals',
    ),
    ConsoleBatch(
      id: 'batch-3',
      courseId: 'course-2',
      title: 'January 2027',
      code: 'EAW-202701',
      status: 'SCHEDULED',
      mode: 'VIRTUAL',
      startsAt: DateTime.utc(2027, 1, 11),
      endsAt: DateTime.utc(2027, 1, 15),
      enrollmentClosesAt: DateTime.utc(2026, 11, 1, 12, 30),
      durationLabel: '5 classes · 10 hours',
      schedule: 'Mon–Fri, 18:00–20:00',
      classDays: const [1, 2, 3, 4, 5],
      classStartTime: '18:00',
      classEndTime: '20:00',
      timezone: 'Asia/Kolkata',
      seatsTaken: 0,
      courseCode: 'EAW',
      courseTitle: 'Energy Audit Workshop',
    ),
  ];

  static List<ConsoleCourse> sampleCourses() {
    final seeded = sampleBatches();
    return [
      ConsoleCourse(
        id: 'course-1',
        code: 'FMF',
        title: 'Facility Management Fundamentals',
        status: 'PUBLISHED',
        providerId: 'inst-1',
        summary: 'The operations, maintenance and vendor management every new facility manager needs.',
        description:
            'Eight weekends on how a building runs: hard and soft services, contracts, budgets and the people.',
        access: 'PAID',
        deliveryMode: 'Virtual live training',
        durationLabel: '8 weeks · 48 hours',
        cpdCredits: 12,
        category: 'FACILITY_MANAGEMENT',
        subcategory: 'HOUSEKEEPING',
        learningOutcomes: const [
          'Apply FM best practices across operations and maintenance',
          'Read a maintenance contract and know what it promises',
        ],
        audience: const ['Facility managers moving into a strategic role', 'Property executives new to FM'],
        batches: [
          for (final b in seeded)
            if (b.courseId == 'course-1') b,
        ],
      ),
      ConsoleCourse(
        id: 'course-2',
        code: 'EAW',
        title: 'Energy Audit Workshop',
        status: 'DRAFT',
        providerId: 'inst-1',
        summary: 'A week of evenings on measuring and cutting a building’s energy use.',
        access: 'FREE',
        category: 'SUSTAINABILITY',
        batches: [
          for (final b in seeded)
            if (b.courseId == 'course-2') b,
        ],
      ),
    ];
  }

  static List<FacultyMember> sampleFaculty() => const [
    FacultyMember(id: 'tr-1', name: 'Meera Iyer', role: 'TRAINER', title: 'Senior FM Consultant', hasUser: true),
    FacultyMember(id: 'tr-2', name: 'Arjun Shetty', role: 'TRAINER', title: 'Energy Auditor', hasUser: true),
    FacultyMember(id: 'tr-4', name: 'Rohit Nair', role: 'TRAINER', title: 'Guest faculty'),
    FacultyMember(id: 'tr-3', name: 'Kavya Rao', role: 'ENROLMENT_SPECIALIST', title: 'Programme desk', hasUser: true),
  ];

  static List<ConsoleEnrolment> sampleEnrolments() => [
    ConsoleEnrolment(
      id: 'enr-1',
      status: 'PENDING',
      createdAt: DateTime(2026, 11, 8, 14, 20),
      firstName: 'Asha',
      lastName: 'Rao',
      email: 'asha.rao@example.com',
      courseId: 'course-1',
      courseCode: 'FMF',
      courseTitle: 'Facility Management Fundamentals',
      batchId: 'batch-1',
      batchTitle: 'March 2027 — weekend',
      batchMode: 'VIRTUAL',
      batchStartsAt: DateTime.utc(2027, 3, 6),
      note: 'I manage two office floors in Pune and want the weekend batch.',
    ),
    ConsoleEnrolment(
      id: 'enr-2',
      status: 'CONFIRMED',
      createdAt: DateTime(2026, 11, 2, 9, 5),
      firstName: 'Vikram',
      lastName: 'Menon',
      email: 'vikram.menon@example.com',
      courseId: 'course-1',
      courseCode: 'FMF',
      courseTitle: 'Facility Management Fundamentals',
      batchId: 'batch-1',
      batchTitle: 'March 2027 — weekend',
      batchMode: 'VIRTUAL',
      batchStartsAt: DateTime.utc(2027, 3, 6),
      decidedAt: DateTime(2026, 11, 3, 10, 0),
    ),
    ConsoleEnrolment(
      id: 'enr-3',
      status: 'WAITLISTED',
      createdAt: DateTime(2026, 10, 28, 17, 45),
      firstName: 'Neha',
      lastName: 'Kulkarni',
      email: 'neha.k@example.com',
      courseId: 'course-2',
      courseCode: 'EAW',
      courseTitle: 'Energy Audit Workshop',
      batchId: 'batch-3',
      batchTitle: 'January 2027',
      batchMode: 'VIRTUAL',
      batchStartsAt: DateTime.utc(2027, 1, 11),
    ),
  ];

  static List<CourseCategory> sampleCategories() => const [
    CourseCategory(
      key: 'FACILITY_MANAGEMENT',
      name: 'Facility Management',
      children: [
        CourseCategory(key: 'HOUSEKEEPING', name: 'Housekeeping'),
        CourseCategory(key: 'MEP_MAINTENANCE', name: 'MEP Maintenance'),
      ],
    ),
    CourseCategory(
      key: 'SUSTAINABILITY',
      name: 'Sustainability',
      children: [CourseCategory(key: 'ENERGY_MANAGEMENT', name: 'Energy Management')],
    ),
    CourseCategory(key: 'CORPORATE_REAL_ESTATE', name: 'Corporate Real Estate'),
  ];

  Future<void> _wait() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
  }

  void _refuseIfSet() {
    if (refuse != null) throw ApiError(refuse!, statusCode: 400);
  }

  @override
  Future<ConsoleContext> context() async {
    await _wait();
    return consoleContext;
  }

  @override
  Future<List<ConsoleCourse>> courses() async {
    await _wait();
    if (failList) throw ApiError('Could not load courses.');
    return [for (final c in courseRows) _withBatches(c)];
  }

  ConsoleCourse _withBatches(ConsoleCourse c) => ConsoleCourse(
    id: c.id,
    code: c.code,
    title: c.title,
    status: c.status,
    kind: c.kind,
    providerId: c.providerId,
    summary: c.summary,
    description: c.description,
    access: c.access,
    priceAmount: c.priceAmount,
    deliveryMode: c.deliveryMode,
    durationLabel: c.durationLabel,
    cpdCredits: c.cpdCredits,
    imageUrl: c.imageUrl,
    brochureUrl: c.brochureUrl,
    category: c.category,
    subcategory: c.subcategory,
    learningOutcomes: c.learningOutcomes,
    audience: c.audience,
    reviewNote: c.reviewNote,
    batches: [
      for (final b in batchRows)
        if (b.courseId == c.id) b,
    ],
    json: c.json,
  );

  ConsoleCourse _courseFrom(ConsoleCourse? base, Map<String, Object?> body, {String? id}) {
    final title = '${body['title'] ?? base?.title ?? ''}';
    final code = base?.code ?? _codeFor(title);
    return ConsoleCourse(
      id: id ?? base!.id,
      code: code,
      title: title,
      status: '${body['status'] ?? base?.status ?? 'DRAFT'}',
      providerId: 'inst-1',
      summary: body.containsKey('summary') ? '${body['summary']}' : base?.summary,
      description: body.containsKey('description') ? '${body['description']}' : base?.description,
      access: '${body['access'] ?? base?.access ?? 'FREE'}',
      deliveryMode: base?.deliveryMode,
      durationLabel: base?.durationLabel,
      cpdCredits: base?.cpdCredits ?? 0,
      imageUrl: body.containsKey('imageUrl') ? body['imageUrl'] as String? : base?.imageUrl,
      brochureUrl: body.containsKey('brochureUrl') ? body['brochureUrl'] as String? : base?.brochureUrl,
      category: body.containsKey('category') ? body['category'] as String? : base?.category,
      subcategory: body.containsKey('subcategory') ? body['subcategory'] as String? : base?.subcategory,
      learningOutcomes: body['learningOutcomes'] is List
          ? [for (final s in body['learningOutcomes'] as List) '$s']
          : base?.learningOutcomes ?? const [],
      audience: body['audience'] is List
          ? [for (final s in body['audience'] as List) '$s']
          : base?.audience ?? const [],
      reviewNote: base?.reviewNote,
    );
  }

  static String _codeFor(String title) {
    final words = title.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final code = [for (final w in words) w[0].toUpperCase()].join();
    return code.isEmpty ? 'NEW' : code;
  }

  @override
  Future<ConsoleCourse> createCourse(Map<String, Object?> body) async {
    await _wait();
    sent.add({'action': 'createCourse', ...body});
    _refuseIfSet();
    final created = _courseFrom(null, body, id: 'course-new-${++_n}');
    courseRows.add(created);
    return created;
  }

  @override
  Future<ConsoleCourse> updateCourse(String id, Map<String, Object?> body) async {
    await _wait();
    sent.add({'action': 'updateCourse', 'id': id, ...body});
    _refuseIfSet();
    final i = courseRows.indexWhere((c) => c.id == id);
    if (i < 0) throw ApiError('Course not found', statusCode: 404);
    final next = _courseFrom(courseRows[i], body);
    courseRows[i] = next;
    return _withBatches(next);
  }

  @override
  Future<void> deleteCourse(String id) async {
    await _wait();
    sent.add({'action': 'deleteCourse', 'id': id});
    _refuseIfSet();
    courseRows.removeWhere((c) => c.id == id);
    batchRows.removeWhere((b) => b.courseId == id);
  }

  Future<ConsoleCourse> _setStatus(String id, String action, String status) async {
    await _wait();
    sent.add({'action': action, 'id': id});
    _refuseIfSet();
    final i = courseRows.indexWhere((c) => c.id == id);
    if (i < 0) throw ApiError('Course not found', statusCode: 404);
    if (action == 'submitCourse' && courseRows[i].status == 'PUBLISHED') {
      throw ApiError('This course is already published.', statusCode: 400);
    }
    if (action == 'withdrawCourse' && courseRows[i].status != 'PENDING_REVIEW') {
      throw ApiError('Only a course awaiting review can be withdrawn.', statusCode: 400);
    }
    final next = _courseFrom(courseRows[i], {'status': status});
    courseRows[i] = next;
    return _withBatches(next);
  }

  @override
  Future<ConsoleCourse> submitCourse(String id) => _setStatus(id, 'submitCourse', 'PENDING_REVIEW');

  @override
  Future<ConsoleCourse> withdrawCourse(String id) => _setStatus(id, 'withdrawCourse', 'DRAFT');

  @override
  Future<List<ConsoleBatch>> batches({String? courseId}) async {
    await _wait();
    if (failList) throw ApiError('Could not load batches.');
    return [
      for (final b in batchRows)
        if (courseId == null || courseId.isEmpty || b.courseId == courseId) b,
    ];
  }

  ConsoleBatch _batchFrom(ConsoleBatch? base, Map<String, Object?> body, {String? id, ConsoleCourse? course}) {
    final startsAt = DateTime.tryParse('${body['startsAt'] ?? ''}') ?? base?.startsAt ?? DateTime.now();
    final endsAt = body.containsKey('endsAt') ? DateTime.tryParse('${body['endsAt']}') : base?.endsAt;
    final days = body['classDays'] is List
        ? [for (final d in body['classDays'] as List) (d as num).toInt()]
        : base?.classDays ?? const <int>[];
    final start = body.containsKey('classStartTime') ? body['classStartTime'] as String? : base?.classStartTime;
    final end = body.containsKey('classEndTime') ? body['classEndTime'] as String? : base?.classEndTime;
    final typed = '${body['title'] ?? ''}'.trim();
    final monthName = const [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ][startsAt.toUtc().add(const Duration(minutes: 330)).month - 1];
    final year = startsAt.toUtc().add(const Duration(minutes: 330)).year;
    final courseCode = course?.code ?? base?.courseCode ?? 'NEW';
    final places = body['trainerIds'] is List
        ? [for (final tid in body['trainerIds'] as List) _placeFor(base, '$tid')]
        : base?.trainerPlaces ?? const <TrainerPlace>[];
    final specialistId = body.containsKey('enrolmentSpecialistId')
        ? body['enrolmentSpecialistId'] as String?
        : base?.enrolmentSpecialistId;
    return ConsoleBatch(
      id: id ?? base!.id,
      courseId: course?.id ?? base!.courseId,
      title: typed.isNotEmpty ? typed : (base == null ? '$monthName $year' : base.title),
      code:
          base?.code ??
          '$courseCode-$year${startsAt.toUtc().add(const Duration(minutes: 330)).month.toString().padLeft(2, '0')}',
      status: '${body['status'] ?? base?.status ?? 'OPEN'}',
      mode: '${body['mode'] ?? base?.mode ?? 'VIRTUAL'}',
      startsAt: startsAt,
      endsAt: endsAt,
      enrollmentClosesAt: body.containsKey('enrollmentClosesAt')
          ? DateTime.tryParse('${body['enrollmentClosesAt']}')
          : base?.enrollmentClosesAt,
      classDays: days,
      classStartTime: start,
      classEndTime: end,
      timezone: '${body['timezone'] ?? base?.timezone ?? 'Asia/Kolkata'}',
      location: body.containsKey('location') ? body['location'] as String? : base?.location,
      maxSeats: body.containsKey('maxSeats') ? (body['maxSeats'] as num?)?.toInt() : base?.maxSeats,
      seatsTaken: base?.seatsTaken ?? 0,
      seatsCapacity: body.containsKey('maxSeats') ? (body['maxSeats'] as num?)?.toInt() : base?.seatsCapacity,
      priceAmount: body.containsKey('priceAmount') ? (body['priceAmount'] as num?)?.toInt() : base?.priceAmount,
      discountPercent: (body['discountPercent'] as num?)?.toInt() ?? base?.discountPercent ?? 0,
      discountEndsOn: body.containsKey('discountEndsOn') ? body['discountEndsOn'] as String? : base?.discountEndsOn,
      notes: base?.notes,
      trainerPlaces: places,
      enrolmentSpecialistId: specialistId,
      enrolmentSpecialistName: specialistId == null ? null : _facultyName(specialistId),
      courseCode: course?.code ?? base?.courseCode,
      courseTitle: course?.title ?? base?.courseTitle,
      durationLabel: base?.durationLabel,
      schedule: base?.schedule,
    );
  }

  String _facultyName(String id) => facultyRows.where((f) => f.id == id).firstOrNull?.name ?? id;

  /// A trainer named on the batch keeps their answer; a newly named one is asked when the batch is saved.
  TrainerPlace _placeFor(ConsoleBatch? base, String trainerId) =>
      base?.trainerPlaces.where((p) => p.trainerId == trainerId).firstOrNull ??
      TrainerPlace(trainerId: trainerId, name: _facultyName(trainerId), status: 'INVITED');

  @override
  Future<ConsoleBatch> createBatch(String courseId, Map<String, Object?> body) async {
    await _wait();
    sent.add({'action': 'createBatch', 'courseId': courseId, ...body});
    _refuseIfSet();
    final course = courseRows.firstWhere(
      (c) => c.id == courseId,
      orElse: () => throw ApiError('Course not found', statusCode: 404),
    );
    final created = _batchFrom(null, body, id: 'batch-new-${++_n}', course: course);
    batchRows.add(created);
    return created;
  }

  @override
  Future<ConsoleBatch> updateBatch(String id, Map<String, Object?> body) async {
    await _wait();
    sent.add({'action': 'updateBatch', 'id': id, ...body});
    _refuseIfSet();
    final i = batchRows.indexWhere((b) => b.id == id);
    if (i < 0) throw ApiError('Batch not found', statusCode: 404);
    final next = _batchFrom(batchRows[i], body);
    batchRows[i] = next;
    return next;
  }

  @override
  Future<void> deleteBatch(String id) async {
    await _wait();
    sent.add({'action': 'deleteBatch', 'id': id});
    _refuseIfSet();
    batchRows.removeWhere((b) => b.id == id);
  }

  @override
  Future<void> reinviteTrainer(String batchId, String trainerId) async {
    await _wait();
    sent.add({'action': 'reinviteTrainer', 'batchId': batchId, 'trainerId': trainerId});
    _refuseIfSet();
    final i = batchRows.indexWhere((b) => b.id == batchId);
    if (i < 0) throw ApiError('Batch not found', statusCode: 404);
    final b = batchRows[i];
    batchRows[i] = _batchFrom(b, {
      'trainerIds': [for (final p in b.trainerPlaces) p.trainerId],
    });
  }

  @override
  Future<List<FacultyMember>> faculty() async {
    await _wait();
    return facultyRows;
  }

  @override
  Future<EnrolmentsPage> enrolments({String? courseId, String? status, int page = 1}) async {
    await _wait();
    if (lockEnrolments != null) throw ApiError(lockEnrolments!, statusCode: 403);
    if (failList) throw ApiError('Could not load enrolments.');
    final shown = [
      for (final e in enrolmentRows)
        if ((courseId == null || courseId.isEmpty || e.courseId == courseId) &&
            (status == null || status.isEmpty || e.status == status))
          e,
    ];
    return EnrolmentsPage(rows: shown, page: 1, totalPages: 1, total: shown.length);
  }

  @override
  Future<ConsoleEnrolment> setEnrolmentStatus(String id, String status) async {
    await _wait();
    sent.add({'action': 'setEnrolmentStatus', 'id': id, 'status': status});
    _refuseIfSet();
    final i = enrolmentRows.indexWhere((e) => e.id == id);
    if (i < 0) throw ApiError('Enrolment not found', statusCode: 404);
    final next = enrolmentRows[i].copyWith(status: status, decidedAt: DateTime.now());
    enrolmentRows[i] = next;
    return next;
  }

  @override
  Future<List<CourseCategory>> categories() async {
    await _wait();
    return sampleCategories();
  }

  @override
  Future<String> upload(UploadFile file) async {
    await _wait();
    sent.add({'action': 'upload', 'name': file.name, 'mimeType': file.mimeType, 'size': file.size});
    _refuseIfSet();
    return '/uploads/demo/${file.name}';
  }
}

/// The empty bytes a test hands a picker.
final emptyBytes = Uint8List(0);
