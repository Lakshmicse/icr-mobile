import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_error.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_text.dart';
import 'auth_palette.dart';
import 'auth_widgets.dart';
import 'recovery_repository.dart';
import 'reset_password_screen.dart';
import 'signup_rules.dart';
import 'signup_widgets.dart';

/// "Forgot password?", as the website's `/forgot-password`: the address, then
/// `POST /auth/forgot-password`, which emails a link when the address has an
/// account and answers the same either way. The new password is then chosen in
/// the app ([ResetPasswordScreen]: "I have my link" takes the emailed link
/// pasted in, or the token itself); the same link also works in a browser.
///
/// On an API with no mail provider (local development) the answer carries the
/// link it would have emailed, and the screen offers it as "Test mode: use the
/// link", as the sign-up code does.
///
/// Signed in, Settings opens it with the account's address ([email]) to change
/// a password, which the API offers no other way.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.email,
    this.initialEmail,
    this.title = 'Reset your password',
    this.repository,
  });

  /// Where the call goes; the API when null.
  final RecoveryRepository? repository;

  /// The signed-in person's address: filled in and fixed.
  final String? email;

  /// An address to start from, still editable (what was typed on Sign in).
  final String? initialEmail;
  final String title;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _email = TextEditingController(text: widget.email ?? widget.initialEmail ?? '');
  late final RecoveryRepository _repository =
      widget.repository ?? ApiRecoveryRepository(api: context.read<AuthController>().api);
  String? _problem;
  String? _error;
  bool _busy = false;
  bool _sent = false;

  /// The link a mail-less API handed back (test mode).
  String? _testLink;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    // A second tap (or Enter) while the first is on its way sends nothing.
    if (_busy) return;
    FocusScope.of(context).unfocus();
    _email.text = cleanEmail(_email.text);
    final problem = emailProblem(_email.text);
    setState(() {
      _problem = problem;
      _error = null;
    });
    if (problem != null) return;
    setState(() => _busy = true);
    try {
      final answer = await _repository.requestReset(_email.text);
      if (mounted) {
        setState(() {
          _sent = true;
          _testLink = answer.resetUrl;
        });
      }
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _chooseNewPassword([String? token]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResetPasswordScreen(token: token, repository: widget.repository, startedFromForgot: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHeader(title: _sent ? 'Check your inbox' : widget.title),
          const SizedBox(height: 16),
          if (_sent) ...[
            Text(
              "If that address has an ICR account, we've sent a link to reset your password. It expires in an hour.",
              key: const Key('forgot.sent'),
              style: AuthType.body(p).copyWith(color: p.text),
            ),
            const SizedBox(height: 12),
            if (_testLink != null) ...[
              Row(
                key: const Key('forgot.testLink'),
                children: [
                  Flexible(
                    child: Text(
                      'Test mode: no email was sent.',
                      style: AuthType.small(p).copyWith(color: const Color(0xFFB45309)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  AuthLink(
                    key: const Key('forgot.useLink'),
                    label: 'Use the link',
                    onTap: () => _chooseNewPassword(tokenFromLink(_testLink!)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            AuthNotice(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1, right: 8),
                    child: Icon(Icons.mark_email_read_outlined, size: 18, color: p.text),
                  ),
                  const Expanded(
                    child: Text('Open the email on this phone, copy its link, and choose your new password here.'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AuthOutlinedButton(
              key: const Key('forgot.haveLink'),
              label: 'I have my link',
              onPressed: _chooseNewPassword,
            ),
            const SizedBox(height: 22),
            AuthPrimaryButton(
              key: const Key('forgot.back'),
              label: 'Back to sign in',
              busyLabel: 'Back to sign in',
              busy: false,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(height: 6),
            Center(
              child: AuthLink(
                key: const Key('forgot.again'),
                label: 'Send it again',
                onTap: () => setState(() => _sent = false),
              ),
            ),
          ] else ...[
            Text(
              "Enter your work email and we'll send you a link to set a new password.",
              style: AuthType.body(p).copyWith(color: p.text),
            ),
            const SizedBox(height: 14),
            AuthField(
              fieldKey: const Key('forgot.email'),
              label: 'Work email',
              controller: _email,
              icon: Icons.mail_outline_rounded,
              hint: 'name@company.com',
              enabled: !_busy && widget.email == null,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.send,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              onFieldSubmitted: (_) => _send(),
            ),
            AuthHelperLine(error: _problem),
            if (_error != null) ...[const SizedBox(height: 12), AuthErrorLine(message: _error!)],
            const SizedBox(height: 20),
            AuthPrimaryButton(
              key: const Key('forgot.send'),
              label: 'Send reset link',
              busyLabel: 'Sending…',
              busy: _busy,
              onPressed: _send,
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(widget.email == null ? 'Remembered it? ' : 'Changed your mind? ', style: AuthType.body(p)),
                AuthLink(
                  key: const Key('forgot.signIn'),
                  label: widget.email == null ? 'Sign in' : 'Go back',
                  style: AuthType.bodyLink(p),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Signed in with Google or LinkedIn and never set a password? This sets one.',
            textAlign: TextAlign.center,
            style: AppText.workSans(12.5, FontWeight.w400, p.muted, lineHeight: 17),
          ),
        ],
      ),
    );
  }
}
