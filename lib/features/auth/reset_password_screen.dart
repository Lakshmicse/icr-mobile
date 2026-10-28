import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_error.dart';
import '../../core/auth/auth_controller.dart';
import 'auth_palette.dart';
import 'auth_widgets.dart';
import 'forgot_password_screen.dart';
import 'recovery_repository.dart';
import 'signup_widgets.dart';

/// "Choose a new password", the website's `/reset-password?token=`, finished in
/// the app. It opens in two ways:
///
/// * with a [token] (a deep link, or "Use link" on the reset request in test
///   mode): straight to the two password fields;
/// * without one: the person pastes the link from their email first
///   ([tokenFromLink] takes the whole link, its query, or the bare token).
///
/// `POST /auth/reset-password` sets the password and revokes every session, so
/// a person who was signed in is signed out here (the API would refuse their
/// next refresh anyway) and goes back to Sign in with the new password. A link
/// the API refuses (used, expired) keeps what was typed and offers a new one.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.token, this.repository, this.startedFromForgot = false});

  /// The reset token, when the link arrived with one.
  final String? token;

  /// Where the call goes; the API when null.
  final RecoveryRepository? repository;

  /// Opened from the "Check your inbox" screen: "Request a new link" goes back to it.
  final bool startedFromForgot;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _link = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _confirmFocus = FocusNode();

  late final RecoveryRepository _repository;
  String? _token;
  bool _showPassword = false;
  bool _busy = false;
  bool _done = false;
  bool _linkRefused = false;
  String? _linkProblem;
  ({String? password, String? confirm}) _problems = (password: null, confirm: null);
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiRecoveryRepository(api: context.read<AuthController>().api);
    _token = widget.token?.trim().isEmpty ?? true ? null : widget.token!.trim();
  }

  @override
  void dispose() {
    _link.dispose();
    _password.dispose();
    _confirm.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _takeLink() {
    FocusScope.of(context).unfocus();
    final token = tokenFromLink(_link.text);
    if (token == null) {
      setState(
        () => _linkProblem = _link.text.trim().isEmpty
            ? 'Paste the link from your email.'
            : 'That does not look like a reset link. Paste the whole link from the email.',
      );
      return;
    }
    setState(() {
      _token = token;
      _linkProblem = null;
      _error = null;
    });
  }

  Future<void> _submit() async {
    // A second tap (or Enter) while the first is on its way sends nothing.
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final password = _password.text;
    final problems = (
      password: password.isEmpty
          ? 'Enter a new password'
          : password.length < 8
          ? 'At least 8 characters'
          : null,
      confirm: _confirm.text.isEmpty
          ? 'Re-enter your new password'
          : (password.isNotEmpty && _confirm.text != password ? 'The two passwords do not match.' : null),
    );
    setState(() {
      _problems = problems;
      _error = null;
      _linkRefused = false;
    });
    if (problems.password != null || problems.confirm != null) return;
    setState(() => _busy = true);
    final auth = context.read<AuthController>();
    try {
      await _repository.resetPassword(token: _token!, password: password);
      // Every session was revoked: this phone's is gone too.
      if (auth.status == SessionStatus.signedIn) await auth.forgetSession();
      if (mounted) setState(() => _done = true);
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          // A refused link cannot be saved by retyping the password.
          _linkRefused = e.statusCode == 400;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _requestNew() {
    final navigator = Navigator.of(context);
    if (widget.startedFromForgot && navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacement(MaterialPageRoute<void>(builder: (_) => const ForgotPasswordScreen()));
    }
  }

  void _toSignIn() => Navigator.of(context).popUntil((route) => route.isFirst);

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final eye = Padding(
      padding: const EdgeInsets.only(right: 6),
      child: AuthEyeButton(shown: _showPassword, onPressed: () => setState(() => _showPassword = !_showPassword)),
    );
    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHeader(
            title: _done ? 'Password updated' : (_token == null ? 'Use your reset link' : 'Choose a new password'),
          ),
          const SizedBox(height: 16),
          if (_done) ...[
            Text(
              'Your password has been changed and every device was signed out. Sign in with your new password.',
              key: const Key('reset.done'),
              style: AuthType.body(p).copyWith(color: p.text),
            ),
            const SizedBox(height: 22),
            AuthPrimaryButton(
              key: const Key('reset.signIn'),
              label: 'Sign in',
              busyLabel: 'Sign in',
              busy: false,
              onPressed: _toSignIn,
            ),
          ] else if (_token == null) ...[
            Text(
              'Paste the link from the password reset email, then choose your new password here.',
              style: AuthType.body(p).copyWith(color: p.text),
            ),
            const SizedBox(height: 14),
            AuthField(
              fieldKey: const Key('reset.link'),
              label: 'Reset link',
              controller: _link,
              icon: Icons.link_rounded,
              hint: 'https://icr.org.in/reset-password?token=…',
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              onChanged: (_) {
                if (_linkProblem != null) setState(() => _linkProblem = null);
              },
              onFieldSubmitted: (_) => _takeLink(),
            ),
            AuthHelperLine(error: _linkProblem),
            const SizedBox(height: 20),
            AuthPrimaryButton(
              key: const Key('reset.useLink'),
              label: 'Continue',
              busyLabel: 'Continue',
              busy: false,
              onPressed: _takeLink,
            ),
            const SizedBox(height: 6),
            Center(
              child: AuthLink(key: const Key('reset.requestNew'), label: 'Send me a new link', onTap: _requestNew),
            ),
          ] else ...[
            Text('At least 8 characters.', style: AuthType.body(p).copyWith(color: p.text)),
            const SizedBox(height: 14),
            AuthField(
              fieldKey: const Key('reset.password'),
              label: 'New password',
              controller: _password,
              icon: Icons.lock_outline_rounded,
              hint: '••••••••••••',
              enabled: !_busy,
              obscureText: !_showPassword,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              autocorrect: false,
              trailing: eye,
              onChanged: (_) => setState(() => _problems = (password: null, confirm: _problems.confirm)),
              onFieldSubmitted: (_) => _confirmFocus.requestFocus(),
            ),
            AuthHelperLine(error: _problems.password),
            ListenableBuilder(
              listenable: _password,
              builder: (context, _) => PasswordStrengthMeter(value: _password.text),
            ),
            const SizedBox(height: 10),
            AuthField(
              fieldKey: const Key('reset.confirm'),
              label: 'Confirm new password',
              controller: _confirm,
              focusNode: _confirmFocus,
              icon: Icons.lock_outline_rounded,
              hint: '••••••••••••',
              enabled: !_busy,
              obscureText: !_showPassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              autocorrect: false,
              trailing: eye,
              onChanged: (_) => setState(() => _problems = (password: _problems.password, confirm: null)),
              onFieldSubmitted: (_) => _submit(),
            ),
            AuthHelperLine(error: _problems.confirm),
            if (_error != null) ...[
              const SizedBox(height: 12),
              AuthErrorLine(message: _error!),
              if (_linkRefused)
                Align(
                  alignment: Alignment.centerLeft,
                  child: AuthLink(key: const Key('reset.requestNew'), label: 'Request a new link', onTap: _requestNew),
                ),
            ],
            const SizedBox(height: 20),
            AuthPrimaryButton(
              key: const Key('reset.submit'),
              label: 'Update password',
              busyLabel: 'Updating…',
              busy: _busy,
              onPressed: _submit,
            ),
          ],
        ],
      ),
    );
  }
}
