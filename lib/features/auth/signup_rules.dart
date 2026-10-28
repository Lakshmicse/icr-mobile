/// The website's sign-up rules (`frontend/src/features/auth/registerSchema.ts`,
/// `features/auth/email.ts`), word for word, so the app refuses what the
/// website refuses and nothing else. The API's own checks (`RegisterDto`) are
/// the last word; these only save a round trip.
library;

/// Characters an email never holds, which a paste drags along: spaces, tabs,
/// line breaks, NBSP, and the invisible zero-width ones.
final _notInAnEmail = RegExp('[\\s​-‍⁠﻿]');

/// The address with whatever a copy-paste dragged in removed (`cleanEmail`).
String cleanEmail(String raw) => raw.replaceAll(_notInAnEmail, '');

/// What is wrong with an address, in the website's words, or null when it
/// looks like one (`emailIssue` + `EN_EMAIL_WORDS`). Expects [cleanEmail] output.
String? emailProblem(String email) {
  if (email.isEmpty) return 'Enter your email';
  final at = '@'.allMatches(email).length;
  if (at == 0) return 'Your email is missing an "@". It should look like name@company.com';
  if (at > 1) return 'An email can have only one "@". It should look like name@company.com';
  final parts = email.split('@');
  final name = parts[0];
  final domain = parts[1];
  if (name.isEmpty) return 'Add your name before the "@", like name@company.com';
  if (domain.isEmpty) return 'Add your email provider after the "@", like name@company.com';
  if (RegExp(r'[<>()[\]\\,;:"]').hasMatch(email)) {
    return 'Remove characters an email can\'t contain, such as , ; : " < > ( ) [ ]';
  }
  if (!domain.contains('.')) return 'The part after the "@" needs a dot, like company.com or gmail.com';
  if (domain.split('.').any((part) => part.isEmpty)) {
    return 'Check the part after the "@". It should look like company.com';
  }
  return null;
}

/// Screen 1's problems (`joinErrors`). Eight characters is the only blocking
/// password rule, as on the API (`@MinLength(8)`); the rest is the advisory
/// meter. A password that holds the address's name is refused, as the website
/// refuses it.
({String? email, String? password}) joinProblems({required String email, required String password}) {
  final address = cleanEmail(email);
  final emailIssue = emailProblem(address);
  String? passwordIssue;
  if (password.length < 8) {
    passwordIssue = 'At least 8 characters';
  } else {
    final local = address.split('@').first.toLowerCase();
    if (local.length > 2 && password.toLowerCase().contains(local)) {
      passwordIssue = "Don't reuse your email address as your password";
    }
  }
  return (email: emailIssue, password: passwordIssue);
}

/// Screen 2's problems (`aboutErrors`); the code only when one is asked for.
({String? firstName, String? lastName, String? code}) aboutProblems({
  required String firstName,
  required String lastName,
  required String code,
  required bool needsCode,
}) => (
  firstName: firstName.trim().isEmpty ? 'Enter your first name' : null,
  lastName: lastName.trim().isEmpty ? 'Enter your last name' : null,
  code: needsCode && !RegExp(r'^\d{6}$').hasMatch(code) ? 'Enter the 6-digit code from the email' : null,
);

/// One line of the password meter (`PASSWORD_RULES`).
class PasswordRule {
  const PasswordRule(this.id, this.label, this.test);

  final String id;
  final String label;
  final bool Function(String) test;
}

final passwordRules = <PasswordRule>[
  PasswordRule('len', 'At least 8 characters', (v) => v.length >= 8),
  PasswordRule('long', '12 or more characters', (v) => v.length >= 12),
  PasswordRule('case', 'Upper and lower case', (v) => RegExp('[a-z]').hasMatch(v) && RegExp('[A-Z]').hasMatch(v)),
  PasswordRule('digit', 'A number or symbol', (v) => RegExp(r'[\d\W_]').hasMatch(v)),
];

enum PasswordStrengthLevel { weak, fair, good, strong }

/// How many rules a password passes and the bucket it lands in (`passwordScore`).
({int passed, PasswordStrengthLevel level, String label}) passwordScore(String value) {
  final passed = value.isEmpty ? 0 : passwordRules.where((r) => r.test(value)).length;
  return switch (passed) {
    <= 1 => (passed: passed, level: PasswordStrengthLevel.weak, label: 'Weak'),
    2 => (passed: passed, level: PasswordStrengthLevel.fair, label: 'Fair'),
    3 => (passed: passed, level: PasswordStrengthLevel.good, label: 'Good'),
    _ => (passed: passed, level: PasswordStrengthLevel.strong, label: 'Strong'),
  };
}

/// The years a role can start in, newest first: this year in India back to
/// 1950 (`careerYears` in `@icr/shared`).
List<int> careerYears([DateTime? now]) {
  final india = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 5, minutes: 30));
  return [for (var y = india.year; y >= 1950; y--) y];
}

/// Screen 3's problems (`YourWorkStep.validate`): only someone working is
/// asked for all three.
({String? title, String? company, String? since}) workProblems({
  required bool working,
  required String title,
  required String company,
  required int? since,
}) {
  if (!working) return (title: null, company: null, since: null);
  return (
    title: title.trim().length < 2 ? 'Enter your job title' : null,
    company: company.trim().length < 2 ? 'Enter where you work' : null,
    since: since == null ? 'Choose the year you started' : null,
  );
}
