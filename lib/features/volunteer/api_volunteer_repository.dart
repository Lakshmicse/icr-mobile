import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../chapters/community_api.dart';
import '../contact/contact_models.dart';
import 'volunteer_models.dart';
import 'volunteer_repository.dart';

/// Get Involved from the API: `GET /mentorship/cpd/summary` and `/mentorship/cpd/target` (the CPD
/// ledger), `GET /auth/me` (the form's starting values), `GET /chapters` ("Which chapter?") and
/// `POST /contact` with topic `VOLUNTEER` (the website sends volunteer applications to the same contact
/// form: the portal has no endpoint of its own for them). `POST /contact` is public and throttled to 5 a
/// minute per IP; the API files the message as a CRM lead and tells the ICR inbox.
class ApiVolunteerRepository implements VolunteerRepository {
  ApiVolunteerRepository({required ApiClient api}) : _api = CommunityApi(api);

  final CommunityApi _api;

  @override
  Future<CpdSummary?> cpd() async {
    final Map<String, dynamic> summary;
    try {
      summary = await _api.getMap('/mentorship/cpd/summary');
    } on ApiError catch (e) {
      if (e.statusCode == 401) return null;
      rethrow;
    }
    Map<String, dynamic> target = const {};
    try {
      target = await _api.getMap('/mentorship/cpd/target');
    } on ApiError {
      // The target is a nicety: the ledger stands without it.
    }
    double hours(Object? v) => (v as num?)?.toDouble() ?? 0;
    return CpdSummary(
      totalHours: hours(summary['totalHours']),
      hoursThisYear: hours(summary['hoursThisYear']),
      bySource: [
        for (final r in (summary['bySource'] as List? ?? const []).cast<Map<String, dynamic>>())
          (source: r['source'] as String? ?? '', hours: hours(r['hours'])),
      ],
      recent: [
        for (final r in (summary['recent'] as List? ?? const []).cast<Map<String, dynamic>>())
          CpdEntry(
            id: r['id'] as String? ?? '',
            hours: hours(r['hours']),
            source: r['source'] as String? ?? '',
            description: CommunityApi.text(r['description']),
            awardedAt: CommunityApi.date(r['awardedAt']),
          ),
      ],
      year: (target['year'] as num?)?.toInt(),
      targetHours: (target['targetHours'] as num?)?.toDouble(),
      progress: (target['progress'] as num?)?.toDouble(),
      targetIsDefault: target['isDefault'] != false,
    );
  }

  @override
  Future<ContactSender?> sender() async {
    final me = await _api.viewer();
    if (me == null) return null;
    return ContactSender(name: me.name, email: me.email, phone: me.phone);
  }

  @override
  Future<List<ChapterChoice>> chapters() async {
    final (rows, _) = await _api.all('/chapters');
    final out = [
      for (final r in rows)
        ChapterChoice(id: r['id'] as String, name: r['name'] as String? ?? '', city: CommunityApi.text(r['city'])),
    ]..sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  @override
  Future<void> apply(VolunteerApplication a) async {
    await _api.send(
      'POST',
      '/contact',
      data: ContactMessage(
        name: a.name.trim(),
        email: a.email.trim(),
        phone: a.phone?.trim(),
        topic: ContactTopic.volunteer,
        message: a.composed,
      ).toJson(),
    );
  }

  @override
  Future<int> unreadNotifications() async {
    try {
      return await _api.unreadNotifications();
    } on ApiError {
      return 0;
    }
  }
}
