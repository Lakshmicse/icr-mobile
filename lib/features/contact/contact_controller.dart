import 'package:flutter/widgets.dart';

import '../../core/api/api_error.dart';
import 'contact_models.dart';
import 'contact_repository.dart';

/// The Contact screen's state: the fields (filled in for a signed-in member,
/// and kept exactly as typed when a send fails), the topic, and the send.
class ContactController extends ChangeNotifier {
  ContactController(this.repository, {String? subject, ContactTopic? topic})
    : _topic = topic ?? ContactTopic.membership,
      _topicChosen = topic != null {
    applySubject(subject);
  }

  final ContactRepository repository;

  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final message = TextEditingController();

  ContactTopic _topic;

  /// A topic the caller named, or the person picked: a subject does not guess over it.
  bool _topicChosen;
  String? _subject;
  ContactSender? _sender;
  bool _started = false;
  bool _loading = false;
  bool _loaded = false;
  bool _sending = false;
  bool _checked = false;
  bool _disposed = false;
  String? _senderError;
  String? _error;
  String? _sentId;
  String? _sentTo;
  int _unread = 0;

  /// What a 429 says here: the form keeps everything, so say so.
  static const throttledMessage =
      'You have sent a few messages in a short while. Wait a minute, then send again: what you wrote is kept.';

  /// What the screen that opened this one was about ("Host or propose an event").
  String? get subject => _subject;

  bool get started => _started;

  /// The sign-in check is in flight.
  bool get loading => _loading;

  /// The sign-in check has answered at least once (with a person, a visitor, or a failure).
  bool get loaded => _loaded;
  bool get sending => _sending;
  ContactTopic get topic => _topic;

  /// Signed in: the form says a support request would serve them better.
  bool get signedIn => _sender != null;
  ContactSender? get sender => _sender;

  /// Why the sign-in could not be checked (the API did not answer); null when it
  /// could, or has not been asked yet. The form works either way.
  String? get senderError => _senderError;

  /// The API's refusal of the last send, in its own words.
  String? get error => _error;

  /// The message went through.
  bool get sent => _sentId != null;
  String? get sentId => _sentId;

  /// The address the reply will go to, once it is sent.
  String? get sentTo => _sentTo;
  int get unread => _unread;

  // Field errors appear once a send has been tried, and then follow the typing.
  String? get nameError => _checked ? ContactRules.name(name.text) : null;
  String? get emailError => _checked ? ContactRules.email(email.text) : null;
  String? get phoneError => _checked ? ContactRules.phone(phone.text) : null;
  String? get messageError => _checked ? ContactRules.message(message.text) : null;

  /// The first field the screen would underline, top to bottom; null when none.
  ContactField? get firstInvalid {
    if (nameError != null) return ContactField.name;
    if (emailError != null) return ContactField.email;
    if (phoneError != null) return ContactField.phone;
    if (messageError != null) return ContactField.message;
    return null;
  }

  bool get valid =>
      ContactRules.name(name.text) == null &&
      ContactRules.email(email.text) == null &&
      ContactRules.phone(phone.text) == null &&
      ContactRules.message(message.text) == null;

  /// A subject handed over by another screen opens the message and picks the
  /// topic, as the website's `?plan=` and `?topic=` do. It leaves a message the
  /// person has already begun alone, and applies once.
  void applySubject(String? raw) {
    final s = raw?.trim();
    if (s == null || s.isEmpty || _subject != null || message.text.trim().isNotEmpty) return;
    _subject = s;
    final opening = '$s\n\n';
    message.value = TextEditingValue(
      text: opening,
      selection: TextSelection.collapsed(offset: opening.length),
    );
    if (!_topicChosen) _topic = ContactTopic.guess(s);
  }

  Future<void> start() async {
    _started = true;
    await _load(notify: false);
  }

  /// Pull to refresh (and the Retry): the sign-in and the bell again; never the fields typed.
  Future<void> refresh() => _load(notify: true);

  /// [notify] is false for the first load, which runs from `initState`.
  Future<void> _load({required bool notify}) async {
    if (_loading) return;
    _loading = true;
    if (notify) _notify();
    try {
      final (_, unread) = await (_readSender(), _readUnread()).wait;
      _unread = unread;
      final s = _sender;
      if (s != null) {
        if (name.text.trim().isEmpty) name.text = s.name;
        if (email.text.trim().isEmpty) email.text = s.email;
        final phoneOnFile = s.phone;
        if (phone.text.trim().isEmpty && phoneOnFile != null && phoneOnFile.isNotEmpty) phone.text = phoneOnFile;
      }
    } finally {
      _loading = false;
      _loaded = true;
      _notify();
    }
  }

  /// The person, a visitor (null), or a failure that keeps what was known.
  Future<void> _readSender() async {
    try {
      _sender = await repository.sender();
      _senderError = null;
    } catch (e) {
      _senderError = ApiError.from(e).message;
    }
  }

  Future<int> _readUnread() async {
    try {
      return await repository.unreadNotifications();
    } catch (_) {
      return _unread;
    }
  }

  void setTopic(ContactTopic topic) {
    _topicChosen = true;
    if (topic == _topic) return;
    _topic = topic;
    _notify();
  }

  /// A field changed: its error (once shown) follows it, and the last refusal
  /// goes, since the person is answering it.
  void edited() {
    if (_checked || _error != null) {
      _error = null;
      _notify();
    }
  }

  /// Sends the message; false (with the reasons on the fields, or the API's
  /// sentence in [error]) when it did not go. What was typed stays in every case.
  Future<bool> send() async {
    if (_sending || sent) return false;
    _checked = true;
    _error = null;
    if (!valid) {
      _notify();
      return false;
    }
    _sending = true;
    _notify();
    try {
      final to = email.text.trim();
      _sentId = await repository.send(
        ContactMessage(
          name: name.text.trim(),
          email: to,
          phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
          topic: _topic,
          message: message.text.trim(),
        ),
      );
      _sentTo = to;
      return true;
    } catch (e) {
      final refusal = ApiError.from(e);
      _error = refusal.statusCode == 429 ? throttledMessage : refusal.message;
      return false;
    } finally {
      _sending = false;
      _notify();
    }
  }

  /// Another message: the sender stays, the message and its state go.
  void another() {
    _sentId = null;
    _sentTo = null;
    _checked = false;
    _error = null;
    _subject = null;
    message.clear();
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    name.dispose();
    email.dispose();
    phone.dispose();
    message.dispose();
    super.dispose();
  }
}
