/// What the Contact screen sends: the website's contact form (`POST /contact`,
/// `CreateContactDto` in the portal's marketing module).
library;

import 'dart:convert';

/// The form's topics, in the website's order (`CONTACT_TOPICS`, with the labels
/// of `ContactLanding`). The API takes `api`; the person reads `label`.
enum ContactTopic {
  membership('MEMBERSHIP', 'Membership & chapters'),
  vendor('VENDOR', 'Becoming a supplier'),
  volunteer('VOLUNTEER', 'Volunteering with ICR'),
  partnership('PARTNERSHIP', 'Partnerships & sponsorship'),
  press('PRESS', 'Press & media'),
  support('SUPPORT', 'Product support'),
  other('OTHER', 'Something else');

  const ContactTopic(this.api, this.label);

  /// The value the API takes.
  final String api;
  final String label;

  static ContactTopic? fromApi(String? v) {
    for (final t in values) {
      if (t.api == v) return t;
    }
    return null;
  }

  /// The topic a subject handed over by another screen most likely belongs to.
  /// With no subject it is the website's default (Membership & chapters); with
  /// one that says nothing about a topic it is "Something else".
  static ContactTopic guess(String? subject) {
    final s = (subject ?? '').trim().toLowerCase();
    if (s.isEmpty) return membership;
    if (RegExp(r'volunteer|committee').hasMatch(s)) return volunteer;
    if (RegExp(r'sponsor|\bpartner|\bhost\b|propose an event|exhibit').hasMatch(s)) return partnership;
    if (RegExp(r'\bplan\b|member|chapter|council').hasMatch(s)) return membership;
    if (RegExp(r'supplier|vendor|\bseller').hasMatch(s)) return vendor;
    if (RegExp(r'\bpress\b|\bmedia\b|journalis').hasMatch(s)) return press;
    if (RegExp(r"\bsupport\b|\bbug\b|problem|cannot|can't log|can.t sign").hasMatch(s)) return support;
    return other;
  }
}

/// The API's limits (`CreateContactDto`).
class ContactLimits {
  ContactLimits._();

  static const name = 120;
  static const phone = 30;
  static const message = 4000;
}

/// One message to the ICR team.
class ContactMessage {
  const ContactMessage({
    required this.name,
    required this.email,
    required this.topic,
    required this.message,
    this.phone,
  });

  final String name;
  final String email;
  final String? phone;
  final ContactTopic topic;
  final String message;

  /// The body of `POST /contact`. The phone is left out when empty (the API
  /// takes it as optional), and the honeypot (`website`) is never sent: it is
  /// a field only a bot fills in.
  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    if (phone != null && phone!.isNotEmpty) 'phone': phone,
    'topic': topic.api,
    'message': message,
  };
}

/// Who is writing, to fill the name, email and phone in for a signed-in member.
class ContactSender {
  const ContactSender({required this.name, required this.email, this.phone});

  final String name;
  final String email;
  final String? phone;
}

/// Where else to reach the team (the website's "Reach us directly" card).
const contactEmail = 'hello@icr.network';
const contactHours = 'Mon–Fri, 9:30–18:30 IST';

// ---------------------------------------------------------------------------
// The API's email check
// ---------------------------------------------------------------------------

// `@IsEmail()` is validator.js's `isEmail` with its defaults (display names
// off, UTF-8 local part on, a TLD required, underscores in a domain off). This
// is that function, line for line, so the form refuses what the API refuses
// and nothing else; `contact_test.dart` pins it to answers recorded from the
// portal's own `class-validator`.
final _localPart = RegExp(r"^[a-z\d!#\$%&'\*\+\-\/=\?\^_`{\|}~¡-퟿豈-﷏ﷰ-￯]+$", caseSensitive: false);
final _quotedLocalPart = RegExp(
  r'^([\s\x01-\x08\x0b\x0c\x0e-\x1f\x7f\x21\x23-\x5b\x5d-\x7e -퟿豈-﷏ﷰ-￯]'
  r'|(\\[\x01-\x09\x0b\x0c\x0d-\x7f -퟿豈-﷏ﷰ-￯]))*$',
  caseSensitive: false,
);
final _tld = RegExp(r'^([a-z¡-¨ª-퟿豈-﷏ﷰ-￯]{2,}|xn[a-z0-9-]{2,})$', caseSensitive: false);
final _domainLabel = RegExp(r'^[a-z_¡-￿0-9-]+$', caseSensitive: false);
final _fullWidth = RegExp(r'[！-～]');
final _space = RegExp(r'\s');
final _digits = RegExp(r'^\d+$');

bool _isFqdn(String domain) {
  final parts = domain.split('.');
  if (parts.length < 2) return false;
  final tld = parts.last;
  if (!_tld.hasMatch(tld) || _space.hasMatch(tld) || _digits.hasMatch(tld)) return false;
  return parts.every(
    (p) =>
        p.length <= 63 &&
        _domainLabel.hasMatch(p) &&
        !_fullWidth.hasMatch(p) &&
        !p.startsWith('-') &&
        !p.endsWith('-') &&
        !p.contains('_'),
  );
}

/// True when the API's `@IsEmail()` accepts [value] as it stands (no trimming).
bool isApiEmail(String value) {
  if (value.length > 254) return false;
  final parts = value.split('@');
  final domain = parts.removeLast();
  var user = parts.join('@');
  if (utf8.encode(user).length > 64 || utf8.encode(domain).length > 254) return false;
  if (!_isFqdn(domain)) return false;
  if (user.isNotEmpty && user.startsWith('"') && user.endsWith('"')) {
    user = user.length >= 2 ? user.substring(1, user.length - 1) : '';
    return _quotedLocalPart.hasMatch(user);
  }
  return user.split('.').every(_localPart.hasMatch);
}

/// The API's own checks (`CreateContactDto`), worded for the form; null when
/// the value passes. Each is applied to the value as it will be sent (trimmed).
class ContactRules {
  ContactRules._();

  static String? name(String v) {
    final t = v.trim();
    if (t.isEmpty) return 'Enter your name.';
    if (t.length > ContactLimits.name) return 'Use ${ContactLimits.name} characters or fewer for your name.';
    return null;
  }

  static String? email(String v) {
    final t = v.trim();
    if (t.isEmpty) return 'Enter your email address.';
    if (!isApiEmail(t)) return 'Enter a valid email address.';
    return null;
  }

  static String? phone(String v) => v.trim().length > ContactLimits.phone
      ? 'Use ${ContactLimits.phone} characters or fewer for the phone number.'
      : null;

  static String? message(String v) {
    final t = v.trim();
    if (t.isEmpty) return 'Write your message.';
    if (t.length > ContactLimits.message) return 'Use 4,000 characters or fewer for your message.';
    return null;
  }
}

/// The form's fields that can be refused, in the order they sit on the screen.
enum ContactField { name, email, phone, message }
