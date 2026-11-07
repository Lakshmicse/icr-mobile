import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import 'enquiry_models.dart';

/// A partner institute's enquiries: the list the website's Enquiries console reads, and the two things it changes.
abstract class EnquiriesRepository {
  /// `GET /learning/admin/leads?status=&page=`, newest first.
  Future<EnquiriesPage> list({String? status, int page = 1});

  /// `PATCH /learning/admin/leads/:id`: a new status, a new note (null clears it). Returns the row as stored.
  Future<Enquiry> update(String id, {String? status, String? note, bool clearNote = false});
}

class ApiEnquiriesRepository implements EnquiriesRepository {
  ApiEnquiriesRepository({required this.api});

  final ApiClient api;

  Future<T> _call<T>(Future<T> Function(Dio dio) body) async {
    try {
      return await body(api.dio);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  @override
  Future<EnquiriesPage> list({String? status, int page = 1}) => _call((dio) async {
    final res = await dio.get<dynamic>(
      '/learning/admin/leads',
      queryParameters: {'page': page, 'limit': 25, if (status != null && status.isNotEmpty) 'status': status},
    );
    final data = res.data;
    return EnquiriesPage.fromJson(data is Map ? data.cast<String, dynamic>() : const {});
  });

  @override
  Future<Enquiry> update(String id, {String? status, String? note, bool clearNote = false}) => _call((dio) async {
    final res = await dio.patch<dynamic>(
      '/learning/admin/leads/${Uri.encodeComponent(id)}',
      data: {'status': ?status, if (clearNote) 'note': null else 'note': ?note},
    );
    final data = res.data;
    return Enquiry.fromJson(data is Map ? data.cast<String, dynamic>() : const {});
  });
}

/// Sample enquiries for the demo and for tests, kept in memory and changed in place.
class DemoEnquiriesRepository implements EnquiriesRepository {
  DemoEnquiriesRepository({List<Enquiry>? rows, this.reveal, this.delay = Duration.zero, this.failList = false})
    : rows = rows ?? sample();

  final List<Enquiry> rows;
  final EnquiryReveal? reveal;
  final Duration delay;
  final bool failList;

  /// Every change sent, in order (tests).
  final sent = <Map<String, Object?>>[];

  static List<Enquiry> sample() => [
    Enquiry(
      id: 'lead-1',
      name: 'Bindhya S',
      email: 'bindhya@example.com',
      phone: '+91 98450 12345',
      kind: 'INDIVIDUAL',
      status: 'NEW',
      revealed: true,
      message: 'Is the next CSF batch on weekends? I work full time.',
      courseCode: 'CSF',
      courseTitle: 'Certified Sustainability in Facilities',
      createdAt: DateTime(2026, 11, 6, 18, 40),
    ),
    Enquiry(
      id: 'lead-2',
      name: 'Priya Nair',
      email: 'priya.nair@acme.example',
      phone: '+91 98111 22333',
      company: 'Acme Workplace Services',
      headcount: 40,
      kind: 'CORPORATE',
      status: 'CONTACTED',
      revealed: true,
      message: 'We would like a private cohort for our facility leads across three cities.',
      note: 'Called 5 Nov; sending the corporate brochure.',
      courseCode: 'CFMP',
      courseTitle: 'Certified Facility Management Professional',
      createdAt: DateTime(2026, 11, 4, 11, 5),
    ),
    Enquiry(
      id: 'lead-3',
      name: 'Rahul Menon',
      email: 'r•••••@gmail.com',
      phone: '+91 9•••• •••21',
      kind: 'INDIVIDUAL',
      status: 'NEW',
      revealed: false,
      source: 'institute',
      createdAt: DateTime(2026, 11, 3, 9, 20),
    ),
  ];

  @override
  Future<EnquiriesPage> list({String? status, int page = 1}) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (failList) throw ApiError('Could not load enquiries.');
    final shown = [
      for (final r in rows)
        if (status == null || status.isEmpty || r.status == status) r,
    ];
    return EnquiriesPage(rows: shown, page: 1, totalPages: 1, reveal: reveal);
  }

  @override
  Future<Enquiry> update(String id, {String? status, String? note, bool clearNote = false}) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    sent.add({'id': id, 'status': ?status, if (clearNote) 'note': null else 'note': ?note});
    final i = rows.indexWhere((r) => r.id == id);
    if (i < 0) throw ApiError('Enquiry not found');
    final next = rows[i].copyWith(status: status, note: note, clearNote: clearNote);
    rows[i] = next;
    return next;
  }
}
