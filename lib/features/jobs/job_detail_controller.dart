import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'job_links.dart';
import 'job_models.dart';
import 'jobs_navigation.dart';
import 'jobs_repository.dart';

/// How an application went: sent, or refused with a sentence. A refusal that
/// asks for a mobile number says so, so the form can ask for it.
class ApplyResult {
  const ApplyResult.sent() : message = null, needsPhone = false;
  const ApplyResult.refused(String this.message, {this.needsPhone = false});

  final String? message;
  final bool needsPhone;

  bool get ok => message == null;
}

/// The API refuses an application from someone with no mobile number on file
/// (`PHONE_NEEDED`: "Add a mobile number so the employer can reach you."), and
/// one whose number it cannot read ("Enter a valid mobile number…").
bool isPhoneRefusal(ApiError error) =>
    error.statusCode == 400 && RegExp('mobile number|phone', caseSensitive: false).hasMatch(error.message);

/// What the apply form needs besides the job: whether to ask for a number, the
/// résumés to choose from and the month's allowance. A part that cannot be
/// read is left out (the API decides on submit regardless).
class ApplyContext {
  const ApplyContext({this.needsPhone = false, this.resumes = const [], this.quota});

  final bool needsPhone;
  final List<ResumeChoice> resumes;
  final SeekerQuota? quota;
}

/// One job's sheet: the full job, how well the member matches it, who else
/// works there, and the member's actions on it.
class JobDetailController extends ChangeNotifier {
  JobDetailController({
    required this.repository,
    required Job seed,
    this.onChanged,
    this.onApplied,
    this.onHidden,
    JobLinks? links,
    this.navigation = JobsNavigation.none,
  }) : _job = seed,
       links = links ?? const SystemJobLinks();

  final JobsRepository repository;

  /// Where a tap leaves the app (the website, the share sheet).
  final JobLinks links;

  /// Tells the board when the job's saved or applied state changes.
  final ValueChanged<Job>? onChanged;

  /// Tells the board an application was sent (its "My jobs" count grows).
  final ValueChanged<Job>? onApplied;

  /// Tells the board the member hid the job ("Not interested").
  final ValueChanged<Job>? onHidden;

  /// Where a company, a conversation or a person opens.
  final JobsNavigation navigation;

  Job _job;
  JobMatch? _match;
  CompanyPeople? _people;
  bool _loading = true;
  bool _applying = false;
  String? _error;
  bool _disposed = false;

  /// The sheet can be closed while a read or an application is still on its
  /// way; whatever arrives after that has nobody to tell.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Job get job => _job;
  JobMatch? get match => _match;
  CompanyPeople? get people => _people;
  bool get loading => _loading;
  bool get applying => _applying;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final full = await repository.detail(_job.id);
      // The detail has no score of its own; keep the one the board showed.
      _job = full.copyWith(
        saved: _job.saved || full.saved,
        applied: _job.applied || full.applied,
        matchScore: _job.matchScore,
      );
      _loading = false;
      notifyListeners();
      // Asides to the sheet: one that cannot be read is left out, and takes
      // neither the other aside nor the sheet with it.
      final results = await Future.wait([
        _aside(() => repository.match(_job)),
        _aside(() => repository.peopleAt(_job.company)),
      ]);
      _match = results[0] as JobMatch?;
      _people = results[1] as CompanyPeople?;
      if (_match?.score != null) _job = _job.copyWith(matchScore: _match!.score);
    } catch (e) {
      _error = ApiError.from(e).message;
      _loading = false;
    }
    notifyListeners();
  }

  Future<T?> _aside<T>(Future<T?> Function() read) async {
    try {
      return await read();
    } catch (_) {
      return null;
    }
  }

  Future<String?> toggleSave() async {
    final saved = !_job.saved;
    _set(_job.copyWith(saved: saved));
    try {
      await repository.setSaved(_job, saved);
      return null;
    } catch (e) {
      _set(_job.copyWith(saved: !saved));
      return ApiError.from(e).message;
    }
  }

  Future<bool> needsPhone() async {
    try {
      return !await repository.hasPhone();
    } catch (_) {
      return false;
    }
  }

  /// The number, the résumés and the allowance, read together for the form.
  Future<ApplyContext> applyContext() async {
    Future<T?> read<T>(Future<T> Function() f) async {
      try {
        return await f();
      } catch (_) {
        return null;
      }
    }

    final results = await Future.wait<Object?>([
      needsPhone(),
      read<List<ResumeChoice>>(repository.resumes),
      read<SeekerQuota?>(repository.quota),
    ]);
    return ApplyContext(
      needsPhone: results[0] as bool,
      resumes: (results[1] as List<ResumeChoice>?) ?? const [],
      quota: results[2] as SeekerQuota?,
    );
  }

  /// Sends the application.
  Future<ApplyResult> apply({
    String? phone,
    String? coverNote,
    String? resumeId,
    num? expectedSalary,
    Map<String, String>? answers,
    String? linkedinUrl,
    List<String>? diversityIdentities,
    String? gender,
  }) async {
    _applying = true;
    notifyListeners();
    try {
      await repository.apply(
        _job,
        phone: phone,
        coverNote: coverNote,
        resumeId: resumeId,
        expectedSalary: expectedSalary,
        answers: answers,
        linkedinUrl: linkedinUrl,
        diversityIdentities: diversityIdentities,
        gender: gender,
      );
      _job = _job.copyWith(applied: true);
      (onApplied ?? onChanged)?.call(_job);
      return const ApplyResult.sent();
    } catch (e) {
      final error = ApiError.from(e);
      return ApplyResult.refused(error.message, needsPhone: isPhoneRefusal(error));
    } finally {
      _applying = false;
      notifyListeners();
    }
  }

  /// "Message": opens a conversation with the job's contact. Returns its id
  /// (the app opens it) and the thread's page on the website (where it opens
  /// when the app has no messaging wired), or the sentence the API refused with.
  Future<({String? conversationId, Uri? thread, String? error})> messageContact({String? message}) async {
    try {
      final id = await repository.messageContact(_job, message: message);
      return (conversationId: id, thread: JobsNavigation.conversationLink(id), error: null);
    } catch (e) {
      return (conversationId: null, thread: null, error: ApiError.from(e).message);
    }
  }

  /// "Not interested": the job leaves the member's board. A sentence when refused.
  Future<String?> hide() async {
    try {
      await repository.setHidden(_job, true);
      onHidden?.call(_job);
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }

  void _set(Job job) {
    _job = job;
    onChanged?.call(job);
    notifyListeners();
  }
}
