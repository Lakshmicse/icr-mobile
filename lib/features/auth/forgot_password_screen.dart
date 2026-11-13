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

/// "Forgot Password?", as the website's `/forgot-password`: the address, then
/// `POST /auth/forgot-password`, which emails a link when the address has an
/// account and answers the same either way. The new password is then chosen in
/// the app ([ResetPasswordScreen]: "I have the Link" takes the emailed link
/// pasted in, or the token itself); the same link also works in a browser.
///
/// On an API with no mail provider (local development) the answer carries the
/// link it would have emailed, and the screen offers it as "Test mode: no email
/// was sent. Use the Link", as the sign-up code does.
///
/// Signed in, Settings opens it with the account's address ([email]) to change
/// a password, which the API offers no other way: "Change Password".
///
/// The words are the client's (the marked-up manual, 13 Nov 2026), and the page
/// is one plain colour, white in light (`AuthScaffold(flat: true)`).
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.email,
    this.initialEmail,
    this.title = 'Reset Your Password',
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
    // Settings opened it to change a known password: Back is Settings, not Sign In.
    final changing = widget.email != null;
    return AuthScaffold(
      flat: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHeader(title: _sent ? 'Check Your Inbox' : widget.title),
          const SizedBox(height: 16),
          if (_sent) ...[
            Text(
              'If an ICR account exists for this email, we’ve sent a password reset link. The link expires in 1 hour.',
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
                    label: 'Use the Link',
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
                    child: Text('Open your email, copy the reset link and paste it here to create a new password.'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AuthOutlinedButton(
              key: const Key('forgot.haveLink'),
              label: 'I have the Link',
              onPressed: _chooseNewPassword,
            ),
            const SizedBox(height: 22),
            AuthPrimaryButton(
              key: const Key('forgot.back'),
              label: changing ? 'Go Back' : 'Back to Sign In',
              busyLabel: changing ? 'Go Back' : 'Back to Sign In',
              busy: false,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(height: 6),
            Center(
              child: AuthLink(
                key: const Key('forgot.again'),
                label: 'Resend Link',
                onTap: () => setState(() => _sent = false),
              ),
            ),
          ] else ...[
            Text(
              changing
                  ? 'Enter your work email to receive a password reset link.'
                  : 'Enter your email address to receive a password reset link.',
              style: AuthType.body(p).copyWith(color: p.text),
            ),
            const SizedBox(height: 14),
            AuthField(
              fieldKey: const Key('forgot.email'),
              label: changing ? 'Work Email' : 'Email',
              controller: _email,
              icon: Icons.mail_outline_rounded,
              hint: 'name@company.com',
              enabled: !_busy && !changing,
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
              label: 'Send Reset Link',
              busyLabel: 'Sending…',
              busy: _busy,
              onPressed: _send,
            ),
            const SizedBox(height: 12),
            // Recovery goes back to Sign In; a change from Settings goes back to Settings.
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(changing ? 'Changed your mind? ' : 'Remember your password? ', style: AuthType.body(p)),
                AuthLink(
                  key: const Key('forgot.signIn'),
                  label: changing ? 'Go Back' : 'Sign In',
                  style: AuthType.bodyLink(p),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Text(
            changing
                ? 'Registered with Google or LinkedIn? Sign in using the same account.'
                : _sent
                ? 'Registered with Google or LinkedIn? Sign in directly using the same account.'
                : 'Signed in with Google or LinkedIn? You can sign in directly without setting a password.',
            key: const Key('forgot.socialNote'),
            textAlign: TextAlign.center,
            style: AppText.workSans(12.5, FontWeight.w400, p.muted, lineHeight: 17),
          ),
        ],
      ),
    );
  }
}
