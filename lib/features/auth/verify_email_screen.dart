import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_error.dart';
import '../../core/auth/auth_controller.dart';
import 'auth_palette.dart';
import 'auth_widgets.dart';
import 'recovery_repository.dart';
import 'signup_widgets.dart';

/// "Confirm your email", the website's `/verify-email?token=`, finished in the
/// app. New accounts start confirmed (the sign-up code proves the address), so
/// this is for older accounts that never were.
///
/// With a [token] it confirms straight away (`POST /auth/verify-email`); without
/// one it asks for the link from the email, or sends a fresh one
/// (`POST /auth/resend-verification`, signed in). A confirmed address refreshes
/// the session so the "not confirmed" notice goes away everywhere.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, this.token, this.repository});

  final String? token;

  /// Where the calls go; the API when null.
  final RecoveryRepository? repository;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

enum _Phase { askForLink, confirming, confirmed, failed }

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _link = TextEditingController();
  late final RecoveryRepository _repository;
  _Phase _phase = _Phase.askForLink;
  bool _alreadyVerified = false;
  String? _message;
  String? _linkProblem;
  bool _resending = false;
  bool _resent = false;
  String? _testLink;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiRecoveryRepository(api: context.read<AuthController>().api);
    final token = widget.token?.trim();
    if (token != null && token.isNotEmpty) {
      _phase = _Phase.confirming;
      WidgetsBinding.instance.addPostFrameCallback((_) => _confirm(token));
    }
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _confirm(String token) async {
    final auth = context.read<AuthController>();
    setState(() {
      _phase = _Phase.confirming;
      _message = null;
    });
    try {
      final already = await _repository.verifyEmail(token);
      // Read the person again so the notice disappears for a signed-in user.
      if (auth.status == SessionStatus.signedIn) await auth.refreshUser();
      if (mounted) {
        setState(() {
          _alreadyVerified = already;
          _phase = _Phase.confirmed;
        });
      }
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _message = e.message;
          _phase = _Phase.failed;
        });
      }
    }
  }

  void _useLink() {
    FocusScope.of(context).unfocus();
    final token = tokenFromLink(_link.text);
    if (token == null) {
      setState(
        () => _linkProblem = _link.text.trim().isEmpty
            ? 'Paste the link from your email.'
            : 'That does not look like a confirmation link. Paste the whole link from the email.',
      );
      return;
    }
    setState(() => _linkProblem = null);
    _confirm(token);
  }

  Future<void> _resend() async {
    if (_resending) return;
    setState(() {
      _resending = true;
      _message = null;
    });
    try {
      final answer = await _repository.resendVerification();
      if (mounted) {
        setState(() {
          _resent = answer.sent;
          _testLink = answer.verifyUrl;
          // A confirmed address needs nothing more.
          if (!answer.sent) _message = 'This email is already confirmed.';
        });
      }
    } on ApiError catch (e) {
      if (mounted) setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _done() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final signedIn = context.watch<AuthController>().status == SessionStatus.signedIn;
    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHeader(
            title: switch (_phase) {
              _Phase.confirming => 'Confirming your email',
              _Phase.confirmed => _alreadyVerified ? 'Already confirmed' : 'Email confirmed',
              _Phase.failed => 'That link did not work',
              _Phase.askForLink => 'Confirm your email',
            },
          ),
          const SizedBox(height: 16),
          ...switch (_phase) {
            _Phase.confirming => [
              const SizedBox(height: 18),
              Center(
                key: const Key('verify.loading'),
                child: CircularProgressIndicator(strokeWidth: 2.4, color: p.accent),
              ),
              const SizedBox(height: 18),
            ],
            _Phase.confirmed => [
              Text(
                'Your address is confirmed. Thanks for keeping your account safe.',
                key: const Key('verify.confirmed'),
                style: AuthType.body(p).copyWith(color: p.text),
              ),
              const SizedBox(height: 22),
              AuthPrimaryButton(
                key: const Key('verify.done'),
                label: 'Done',
                busyLabel: 'Done',
                busy: false,
                onPressed: _done,
              ),
            ],
            _ => [
              Text(
                _phase == _Phase.failed
                    ? (_message ?? 'This confirmation link is not valid.')
                    : 'Paste the link from the confirmation email, or have a new one sent.',
                key: const Key('verify.message'),
                style: AuthType.body(p).copyWith(color: _phase == _Phase.failed ? p.error : p.text),
              ),
              const SizedBox(height: 14),
              AuthField(
                fieldKey: const Key('verify.link'),
                label: 'Confirmation link',
                controller: _link,
                icon: Icons.link_rounded,
                hint: 'https://icr.org.in/verify-email?token=…',
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                onChanged: (_) {
                  if (_linkProblem != null) setState(() => _linkProblem = null);
                },
                onFieldSubmitted: (_) => _useLink(),
              ),
              AuthHelperLine(error: _linkProblem),
              const SizedBox(height: 18),
              AuthPrimaryButton(
                key: const Key('verify.useLink'),
                label: 'Confirm my email',
                busyLabel: 'Confirming…',
                busy: false,
                onPressed: _useLink,
              ),
              const SizedBox(height: 10),
              if (signedIn) ...[
                if (_resent)
                  Text(
                    'A new link is on its way. Check your inbox.',
                    key: const Key('verify.resent'),
                    textAlign: TextAlign.center,
                    style: AuthType.small(p),
                  )
                else
                  AuthOutlinedButton(
                    key: const Key('verify.resend'),
                    label: _resending ? 'Sending…' : 'Send me a new link',
                    onPressed: _resending ? null : _resend,
                  ),
                if (_testLink != null)
                  Center(
                    child: AuthLink(
                      key: const Key('verify.useTestLink'),
                      label: 'Test mode: use the link',
                      onTap: () {
                        final token = tokenFromLink(_testLink!);
                        if (token != null) _confirm(token);
                      },
                    ),
                  ),
                if (_phase == _Phase.askForLink && _message != null) ...[
                  const SizedBox(height: 8),
                  AuthErrorLine(message: _message!),
                ],
              ] else
                Center(
                  child: AuthLink(
                    key: const Key('verify.signIn'),
                    label: 'Sign in to get a new link',
                    onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  ),
                ),
            ],
          },
        ],
      ),
    );
  }
}
