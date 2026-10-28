import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_error.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/auth/social_sign_in.dart';
import '../../core/config.dart';
import '../account/account_repository.dart';
import '../account/api_account_repository.dart';
import '../account/demo_account_repository.dart';
import 'auth_palette.dart';
import 'auth_widgets.dart';
import 'signup_rules.dart';
import 'signup_widgets.dart';
import 'your_work_step.dart';

enum SignupStep { join, about, work }

/// Joining ICR in three short screens, as the website's `/register` does
/// (`components/auth/register/RegisterForm.tsx`):
///
/// 1. **Join** — Google or LinkedIn, or an email and a password, and the tick
///    that accepts the Terms and Privacy Policy. "Join" emails a 6-digit code;
///    nothing is made yet.
/// 2. **About you** — first and last name and the code (`/auth/email/verify-code`).
///    "Continue" makes the account (`POST /auth/register`) and signs in.
/// 3. **Your work** — job title and company, or between roles, written to the
///    profile the way the website writes it. Skippable.
///
/// Someone new coming back from Google or LinkedIn starts on About you with
/// [social]: the provider's name is prefilled, and the code is asked only when
/// the provider would not vouch for the address.
///
/// Popping returns the email typed so far, so Sign in can fill it in ("That
/// email already has an ICR account").
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key, this.social, this.provider, this.account, this.resendCooldown = 60});

  /// A Google/LinkedIn round trip's sign-up token.
  final SocialSignup? social;
  final SocialProvider? provider;

  /// Where "Your work" reads and writes; the API (or the sample member) when null.
  final AccountRepository? account;

  /// Seconds before another code may be sent: the API's own per-address wait.
  final int resendCooldown;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _code = TextEditingController();
  final _passwordFocus = FocusNode();
  final _lastFocus = FocusNode();
  final _codeFocus = FocusNode();

  late final AccountRepository _account;

  SignupStep _step = SignupStep.join;
  bool _showPassword = false;
  bool _agreed = false;
  bool _agreeError = false;
  ({String? email, String? password}) _joinErrors = (email: null, password: null);
  ({String? firstName, String? lastName, String? code}) _aboutErrors = (firstName: null, lastName: null, code: null);
  bool _busy = false;
  String? _error;
  bool _duplicate = false;
  String? _devCode;

  /// Once the code has matched, a retry of the account itself must not check
  /// it again: the API has already spent it.
  bool _codeAccepted = false;
  int _wait = 0;
  Timer? _ticker;

  // Google / LinkedIn
  SocialSignup? _social;
  SocialProvider? _provider;
  PendingSocialProfile? _pending;
  String? _pendingError;
  Set<SocialProvider> _available = const {};
  SocialProvider? _socialBusy;

  bool get _isSocial => _social != null;
  bool get _needsCode => !_isSocial || _pending?.emailVerified == false;
  String get _address => cleanEmail(_pending?.email ?? _email.text).toLowerCase();

  @override
  void initState() {
    super.initState();
    _account = widget.account ?? _defaultAccount();
    _social = widget.social;
    _provider = widget.provider;
    if (_social != null) {
      _step = SignupStep.about;
      _loadPending();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final available = await context.read<AuthController>().configuredProviders();
        if (mounted) setState(() => _available = available);
      });
    }
  }

  AccountRepository _defaultAccount() =>
      AppConfig.demo ? DemoAccountRepository() : ApiAccountRepository(api: context.read<AuthController>().api);

  @override
  void dispose() {
    _ticker?.cancel();
    for (final c in [_email, _password, _first, _last, _code]) {
      c.dispose();
    }
    for (final f in [_passwordFocus, _lastFocus, _codeFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  void _startCooldown() {
    _ticker?.cancel();
    setState(() => _wait = widget.resendCooldown);
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _wait = _wait > 0 ? _wait - 1 : 0);
      if (_wait == 0) t.cancel();
    });
  }

  Future<void> _sendCode(String to) async {
    final code = await context.read<AuthController>().sendEmailCode(to);
    if (mounted) setState(() => _devCode = code);
  }

  // --- Google / LinkedIn ---------------------------------------------------------------------------------------

  Future<void> _loadPending() async {
    setState(() => _pendingError = null);
    final auth = context.read<AuthController>();
    try {
      final pending = await auth.readPending(_social!.token);
      if (!mounted) return;
      setState(() {
        _pending = pending;
        if (_first.text.isEmpty) _first.text = pending.firstName;
        if (_last.text.isEmpty) _last.text = pending.lastName;
      });
      if (!pending.emailVerified) {
        try {
          await _sendCode(pending.email);
          if (mounted) _startCooldown();
        } on ApiError catch (e) {
          if (mounted) setState(() => _error = e.message);
        }
      }
    } on ApiError catch (e) {
      if (mounted) setState(() => _pendingError = e.message);
    }
  }

  Future<void> _continueWith(SocialProvider provider) async {
    if (!_available.contains(provider)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('${provider.label} sign-in is not available yet')));
      return;
    }
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthController>();
    final navigator = Navigator.of(context);
    setState(() {
      _socialBusy = provider;
      _error = null;
    });
    try {
      final signup = await auth.signInWith(provider);
      if (!mounted) return;
      if (signup != null) {
        setState(() {
          _social = signup;
          _provider = provider;
          _step = SignupStep.about;
          _codeAccepted = false;
          _code.clear();
        });
        await _loadPending();
      } else if (auth.status == SessionStatus.signedIn) {
        // Someone who already had an account is simply signed in.
        navigator.popUntil((route) => route.isFirst);
      }
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _socialBusy = null);
    }
  }

  // --- Join ----------------------------------------------------------------------------------------------------

  Future<void> _submitJoin() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    _email.text = cleanEmail(_email.text);
    final problems = joinProblems(email: _email.text, password: _password.text);
    setState(() {
      _joinErrors = problems;
      _agreeError = !_agreed;
      _error = null;
      _duplicate = false;
    });
    if (problems.email != null || problems.password != null || !_agreed) return;
    setState(() => _busy = true);
    try {
      await _sendCode(_email.text);
      if (!mounted) return;
      setState(() {
        _codeAccepted = false;
        _code.clear();
        _step = SignupStep.about;
      });
      _startCooldown();
    } on ApiError catch (e) {
      if (mounted) _failed(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _failed(ApiError e) {
    setState(() {
      if (e.statusCode == 409) {
        _duplicate = true;
      } else {
        _error = e.message;
      }
    });
  }

  // --- About you -----------------------------------------------------------------------------------------------

  Future<void> _submitAbout() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final askCode = _needsCode && !_codeAccepted;
    final problems = aboutProblems(
      firstName: _first.text,
      lastName: _last.text,
      code: _code.text.trim(),
      needsCode: askCode,
    );
    setState(() {
      _aboutErrors = problems;
      _error = null;
      _duplicate = false;
    });
    if (problems.firstName != null || problems.lastName != null || problems.code != null) return;
    final auth = context.read<AuthController>();
    setState(() => _busy = true);
    try {
      if (askCode) {
        try {
          await auth.verifyEmailCode(_address, _code.text.trim());
          _codeAccepted = true;
        } on ApiError catch (e) {
          if (mounted) setState(() => _aboutErrors = (firstName: null, lastName: null, code: e.message));
          return;
        }
      }
      if (_isSocial) {
        await auth.completeSocialSignup(signup: _social!, firstName: _first.text, lastName: _last.text);
      } else {
        await auth.register(email: _address, password: _password.text, firstName: _first.text, lastName: _last.text);
      }
      TextInput.finishAutofillContext();
      if (mounted) setState(() => _step = SignupStep.work);
    } on ApiError catch (e) {
      if (mounted) _failed(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_busy || _wait > 0) return;
    setState(() => _error = null);
    try {
      await _sendCode(_address);
      if (mounted) _startCooldown();
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  // --- leaving -------------------------------------------------------------------------------------------------

  /// Back to Sign in with the address typed so far.
  void _toSignIn() => Navigator.of(context).maybePop(_isSocial ? _pending?.email : cleanEmail(_email.text));

  /// After the last screen: the app, signed in.
  void _finish() => Navigator.of(context).popUntil((route) => route.isFirst);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Once the account exists, Back finishes rather than returning to a
      // screen that would make it again.
      canPop: _step != SignupStep.work,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step == SignupStep.work) _finish();
      },
      child: AuthScaffold(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    final p = AuthPalette.of(context);
    if (_isSocial && _pending == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SignupHeader(step: 2, title: 'About you'),
          if (_pendingError == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: p.accent)),
            )
          else ...[
            const SizedBox(height: 22),
            AuthErrorLine(message: _pendingError!),
            const SizedBox(height: 8),
            Text('That sign-in has expired. Please start again from the sign-in page.', style: AuthType.small(p)),
            const SizedBox(height: 18),
            AuthOutlinedButton(label: 'Try again', onPressed: _loadPending),
            const SizedBox(height: 6),
            Center(
              child: AuthLink(key: const Key('signup.backToSignIn'), label: 'Back to sign in', onTap: _toSignIn),
            ),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SignupHeader(
          step: _step.index + 1,
          title: switch (_step) {
            SignupStep.join => 'Join ICR',
            SignupStep.about => 'About you',
            SignupStep.work => 'Your work',
          },
        ),
        const SizedBox(height: 18),
        if (_isSocial && _step == SignupStep.about) ...[
          AuthNotice(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 8),
                  child: SvgPicture.asset(_provider?.icon ?? SocialProvider.google.icon, width: 15, height: 15),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Continuing with '),
                        TextSpan(
                          text: _provider?.label ?? 'your account',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const TextSpan(text: ' as '),
                        TextSpan(
                          text: _pending!.email,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (_duplicate) ...[
          AuthErrorLine(message: 'That email already has an ICR account.'),
          Align(
            alignment: Alignment.centerLeft,
            child: AuthLink(key: const Key('signup.duplicateSignIn'), label: 'Sign in instead', onTap: _toSignIn),
          ),
          const SizedBox(height: 10),
        ],
        switch (_step) {
          SignupStep.join => _join(context),
          SignupStep.about => _about(context),
          SignupStep.work => YourWorkStep(account: _account, onDone: _finish),
        },
        if (_step != SignupStep.work) ...[
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Already have an account? ', style: AuthType.body(p)),
              AuthLink(
                key: const Key('signup.signIn'),
                label: 'Sign in',
                style: AuthType.bodyLink(p),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                onTap: _busy ? () {} : _toSignIn,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _join(BuildContext context) {
    final busy = _busy || _socialBusy != null;
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final (i, provider) in SocialProvider.values.indexed) ...[
                if (i > 0) const SizedBox(width: 43),
                SocialIconButton(
                  key: Key('signup.${provider.name}'),
                  provider: provider,
                  available: _available.contains(provider),
                  busy: _socialBusy == provider,
                  onPressed: busy ? null : () => _continueWith(provider),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          const AuthDivider(),
          const SizedBox(height: 14),
          AuthField(
            fieldKey: const Key('signup.email'),
            label: 'Work Email',
            controller: _email,
            icon: Icons.mail_outline_rounded,
            hint: 'name@company.com',
            enabled: !busy,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
          ),
          AuthHelperLine(error: _joinErrors.email, helper: "We'll email you a code to confirm it."),
          const SizedBox(height: 10),
          AuthField(
            fieldKey: const Key('signup.password'),
            label: 'Create Password',
            controller: _password,
            focusNode: _passwordFocus,
            icon: Icons.lock_outline_rounded,
            hint: '••••••••••••',
            enabled: !busy,
            obscureText: !_showPassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            autocorrect: false,
            trailing: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: AuthEyeButton(
                shown: _showPassword,
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
            onFieldSubmitted: (_) => _submitJoin(),
          ),
          AuthHelperLine(error: _joinErrors.password),
          ListenableBuilder(
            listenable: _password,
            builder: (context, _) => PasswordStrengthMeter(value: _password.text),
          ),
          const SizedBox(height: 12),
          AuthCheckLine(
            key: const Key('signup.agree'),
            value: _agreed,
            label: 'I agree to the Terms of Service and Privacy Policy',
            onChanged: busy
                ? null
                : (v) => setState(() {
                    _agreed = v;
                    if (v) _agreeError = false;
                  }),
            child: const TermsSentence(),
          ),
          if (_agreeError)
            const AuthHelperLine(error: 'Please agree to the Terms of Service and Privacy Policy to join.'),
          if (_error != null) ...[const SizedBox(height: 12), AuthErrorLine(message: _error!)],
          const SizedBox(height: 18),
          AuthPrimaryButton(
            key: const Key('signup.join'),
            label: 'Join',
            busyLabel: 'Sending your code…',
            busy: _busy,
            onPressed: _socialBusy == null ? _submitJoin : null,
          ),
        ],
      ),
    );
  }

  Widget _about(BuildContext context) {
    final p = AuthPalette.of(context);
    final askCode = _needsCode && !_codeAccepted;
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthField(
            fieldKey: const Key('signup.firstName'),
            label: 'First name',
            controller: _first,
            icon: Icons.person_outline_rounded,
            enabled: !_busy,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.givenName],
            onFieldSubmitted: (_) => _lastFocus.requestFocus(),
          ),
          AuthHelperLine(error: _aboutErrors.firstName),
          const SizedBox(height: 8),
          AuthField(
            fieldKey: const Key('signup.lastName'),
            label: 'Last name',
            controller: _last,
            focusNode: _lastFocus,
            icon: Icons.person_outline_rounded,
            enabled: !_busy,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
            textInputAction: askCode ? TextInputAction.next : TextInputAction.done,
            autofillHints: const [AutofillHints.familyName],
            onFieldSubmitted: (_) => askCode ? _codeFocus.requestFocus() : _submitAbout(),
          ),
          AuthHelperLine(error: _aboutErrors.lastName),
          if (askCode) ...[
            const SizedBox(height: 8),
            AuthField(
              fieldKey: const Key('signup.code'),
              label: 'Code from your email',
              controller: _code,
              focusNode: _codeFocus,
              icon: Icons.pin_outlined,
              hint: '6-digit code',
              enabled: !_busy,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: 6,
              letterSpacing: 4,
              headerTrailing: _isSocial
                  ? null
                  : AuthLink(
                      key: const Key('signup.changeEmail'),
                      label: 'Change email',
                      onTap: _busy
                          ? () {}
                          : () => setState(() {
                              _error = null;
                              _step = SignupStep.join;
                            }),
                    ),
              onFieldSubmitted: (_) => _submitAbout(),
            ),
            AuthHelperLine(error: _aboutErrors.code, helper: 'We sent a code to $_address. It expires in 10 minutes.'),
            DevCodeNote(
              code: _devCode,
              onUse: (code) {
                _code.text = code;
                setState(
                  () => _aboutErrors = (firstName: _aboutErrors.firstName, lastName: _aboutErrors.lastName, code: null),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('No email? Check spam, or ', style: AuthType.small(p)),
                  AuthLink(
                    key: const Key('signup.resend'),
                    label: _wait > 0 ? 'send a new one in ${_wait}s' : 'send a new one',
                    style: AuthType.link(p).copyWith(fontSize: 14, color: _wait > 0 || _busy ? p.muted : p.accent),
                    onTap: _wait > 0 || _busy ? () {} : _resend,
                  ),
                ],
              ),
            ),
          ],
          if (_error != null) ...[const SizedBox(height: 12), AuthErrorLine(message: _error!)],
          if (_isSocial) ...[
            const SizedBox(height: 18),
            const TermsSentence(lead: 'By selecting Agree & join, you agree to ICR’s', center: true),
          ],
          const SizedBox(height: 16),
          AuthPrimaryButton(
            key: const Key('signup.continue'),
            label: _isSocial ? 'Agree & join' : 'Continue',
            busyLabel: 'Creating your account…',
            busy: _busy,
            onPressed: _submitAbout,
          ),
        ],
      ),
    );
  }
}
