import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import '../contact/contact_models.dart';
import 'volunteer_data.dart';
import 'volunteer_models.dart';
import 'volunteer_repository.dart';

/// The Get Involved screen's state: the opportunities (searchable, each opening to its
/// responsibilities), the member's CPD ledger as the API gives it, who they are (for the form) and the
/// chapters the form offers. The API keeps no list of applications, so which roles the member has sent
/// interest for is remembered for this visit only.
class VolunteerController extends ChangeNotifier {
  VolunteerController(this.repository, {List<VolunteerRole>? roles}) : roles = roles ?? volunteerRoles;

  final VolunteerRepository repository;
  final List<VolunteerRole> roles;

  CpdSummary? _cpd;
  bool _signedIn = false;
  bool _started = false;
  bool _cpdLoading = false;
  bool _disposed = false;
  String? _cpdError;
  ContactSender? _sender;
  List<ChapterChoice> _chapters = const [];
  int _unread = 0;
  String _search = '';
  final Set<String> _open = {};
  final Set<String> _sent = {};

  bool get started => _started;
  bool get cpdLoading => _cpdLoading;

  /// The CPD card could not be read (the rest of the screen stands).
  String? get cpdError => _cpdError;

  /// The member's ledger; null signed out or before it was read.
  CpdSummary? get cpd => _cpd;

  /// Someone is signed in (the API answered `GET /auth/me`).
  bool get signedIn => _signedIn;
  ContactSender? get sender => _sender;
  List<ChapterChoice> get chapters => _chapters;
  int get unread => _unread;
  String get search => _search;

  /// The roles the search leaves.
  List<VolunteerRole> get visibleRoles => [
    for (final r in roles)
      if (r.matches(_search)) r,
  ];

  bool isOpen(VolunteerRole r) => _open.contains(r.key);

  /// Interest for [role] (null: the general one) was sent during this visit.
  bool isSent(VolunteerRole? role) => _sent.contains(role?.key ?? '*');

  VolunteerRole? roleByKey(String? key) {
    for (final r in roles) {
      if (r.key == key) return r;
    }
    return null;
  }

  Future<void>? _starting;

  /// Reads the ledger, the person, the chapters and the bell, once: a second call (the screen asking
  /// again for the form's sake) waits for the first.
  Future<void> start() => _starting ??= _begin();

  Future<void> _begin() async {
    _started = true;
    await Future.wait([_loadCpd(notify: false), _loadWho(), _loadUnread()]);
  }

  /// Pull to refresh: the ledger, the person and the bell again.
  Future<void> refresh() => Future.wait([_loadCpd(notify: true), _loadWho(), _loadUnread()]);

  Future<void> _loadCpd({required bool notify}) async {
    _cpdLoading = true;
    _cpdError = null;
    if (notify) _notify();
    try {
      _cpd = await repository.cpd();
    } catch (e) {
      _cpdError = ApiError.from(e).message;
    } finally {
      _cpdLoading = false;
      _notify();
    }
  }

  Future<void> _loadWho() async {
    try {
      _sender = await repository.sender();
      _signedIn = _sender != null;
    } catch (_) {
      // The form still works: it is simply not filled in.
    }
    try {
      _chapters = await repository.chapters();
    } catch (_) {}
    _notify();
  }

  Future<void> _loadUnread() async {
    try {
      _unread = await repository.unreadNotifications();
      _notify();
    } catch (_) {}
  }

  void setSearch(String text) {
    if (text.trim() == _search) return;
    _search = text.trim();
    _notify();
  }

  void toggle(VolunteerRole r) {
    if (!_open.remove(r.key)) _open.add(r.key);
    _notify();
  }

  /// Remembers that interest for [role] (null: the general one) went to the ICR team.
  void markSent(VolunteerRole? role) {
    _sent.add(role?.key ?? '*');
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The apply form: the fields, the API's rules (`CreateContactDto`: a name of 1 to 120 characters, an
/// email the API accepts, a phone of at most 30, a message of at most 4,000 that already holds the role
/// and chapter lines), what is wrong with each, and the send.
class VolunteerFormController extends ChangeNotifier {
  VolunteerFormController({
    required this.repository,
    this.roles = const [],
    this.chapters = const [],
    ContactSender? sender,
    VolunteerRole? role,
    String? chapterName,
  }) : name = sender?.name ?? '',
       email = sender?.email ?? '',
       phone = sender?.phone ?? '',
       _role = role,
       chapter = chapterName;

  final VolunteerRepository repository;
  final List<VolunteerRole> roles;
  final List<ChapterChoice> chapters;

  String name;
  String email;
  String phone;
  String message = '';
  VolunteerRole? _role;

  /// The chapter's name the person chose or arrived with; null for none.
  String? chapter;

  bool _busy = false;
  bool _disposed = false;
  bool _showErrors = false;
  bool _sent = false;
  String? _error;

  VolunteerRole? get role => _role;
  bool get busy => _busy;
  bool get sent => _sent;

  /// The API's refusal, in its own words.
  String? get error => _error;

  /// How many characters the message may have: the API's 4,000 less the role and chapter lines.
  int get messageRoom => VolunteerApplication.messageRoom(role: _role, chapter: chapter);

  void setRole(VolunteerRole? r) {
    _role = r;
    _notify();
  }

  void setChapter(String? c) {
    chapter = c;
    _notify();
  }

  void setName(String v) {
    name = v;
    _notify();
  }

  void setEmail(String v) {
    email = v;
    _notify();
  }

  void setPhone(String v) {
    phone = v;
    _notify();
  }

  void setMessage(String v) {
    message = v;
    _notify();
  }

  /// What is wrong, by field.
  Map<ContactField, String> get problems {
    final p = <ContactField, String>{};
    final n = ContactRules.name(name);
    if (n != null) p[ContactField.name] = n;
    final e = ContactRules.email(email);
    if (e != null) p[ContactField.email] = e;
    final ph = ContactRules.phone(phone);
    if (ph != null) p[ContactField.phone] = ph;
    final t = message.trim();
    if (t.isEmpty) {
      p[ContactField.message] = 'Tell us a little about you and the time you can give.';
    } else if (t.length > messageRoom) {
      p[ContactField.message] = 'Use ${messageRoom < 0 ? 0 : messageRoom} characters or fewer here.';
    }
    return p;
  }

  /// The problem to show under [field]: only once a send was tried.
  String? problemFor(ContactField field) => _showErrors ? problems[field] : null;

  /// Sends the interest; true when the API took it. A refusal is [error], and everything typed stays.
  Future<bool> submit() async {
    if (_busy) return false;
    _showErrors = true;
    if (problems.isNotEmpty) {
      _error = null;
      _notify();
      return false;
    }
    _busy = true;
    _error = null;
    _notify();
    try {
      await repository.apply(
        VolunteerApplication(
          name: name,
          email: email,
          phone: phone.trim().isEmpty ? null : phone,
          message: message,
          role: _role,
          chapter: chapter,
        ),
      );
      _sent = true;
      return true;
    } catch (e) {
      _error = ApiError.from(e).message;
      return false;
    } finally {
      _busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
