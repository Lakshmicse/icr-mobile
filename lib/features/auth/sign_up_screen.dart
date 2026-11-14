import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_error.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/auth/social_sign_in.dart';
import '../../core/config.dart';
import '../account/account_repository.dart';
import '../account/account_rules.dart' show canTextPhone, normalizePhone;
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
/// 2. **About you** — first and last name, the mobile number (required by the
///    API since 29 Oct 2026; an Indian number is proven with a texted OTP,
///    `/auth/phone/send-otp` + `verify-otp`, any other is saved as typed) and
///    the code (`/auth/email/verify-code`). "Continue" makes the account
///    (`POST /auth/register`) and signs in.
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

class _SignUpScreenState extends State<SignUpScreen> with WidgetsBindingObserver {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _code = TextEditingController();
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _passwordFocus = FocusNode();
  final _lastFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _otpFocus = FocusNode();
  final _codeFocus = FocusNode();

  late final AccountRepository _account;

  SignupStep _step = SignupStep.join;
  bool _showPassword = false;
  bool _agreed = false;
  bool _agreeError = false;
  ({String? email, String? password}) _joinErrors = (email: null, password: null);
  ({String? firstName, String? lastName, String? code}) _aboutErrors = (firstName: null, lastName: null, code: null);
  ({String? phone, String? otp}) _phoneErrors = (phone: null, otp: null);
  bool _busy = false;
  String? _error;
  bool _duplicate = false;
  String? _devCode;

  /// Once the code has matched, a retry of the account itself must not check
  /// it again: the API has already spent it.
  bool _codeAccepted = false;
  int _wait = 0;
  Timer? _ticker;

  // The mobile number (the website's `PhoneVerifyInline acceptUntextable`): an Indian number is proven with its
  // OTP before the account is made; any other passes its country's format check and is saved unconfirmed.
  String? _otpSentTo;
  String? _phoneVerified;
  String? _phoneDevCode;
  int _otpWait = 0;
  Timer? _otpTicker;

  String? get _e164 => normalizePhone(_phone.text);
  bool get _textable => canTextPhone(_phone.text);

  /// The number still needs its OTP: Indian, and not the one already proven.
  bool get _otpNeeded => _textable && _e164 != null && _phoneVerified != _e164;

  /// The OTP went to the number as typed now, and waits to be entered.
  bool get _otpPending => _otpNeeded && _otpSentTo == _e164;

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
      WidgetsBinding.instance.addObserver(this);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _readProviders();
      });
    }
  }

  /// Which of Google and LinkedIn this server offers: only those are drawn. Asked when the page opens and again
  /// each time the app comes back to the front, so a provider the server gains shows without a new build.
  Future<void> _readProviders() async {
    final available = await context.read<AuthController>().configuredProviders();
    if (mounted && !setEquals(available, _available)) setState(() => _available = available);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isSocial && _socialBusy == null) _readProviders();
  }

  AccountRepository _defaultAccount() =>
      AppConfig.demo ? DemoAccountRepository() : ApiAccountRepository(api: context.read<AuthController>().api);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _otpTicker?.cancel();
    for (final c in [_email, _password, _first, _last, _code, _phone, _otp]) {
      c.dispose();
    }
    for (final f in [_passwordFocus, _lastFocus, _phoneFocus, _otpFocus, _codeFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  void _startOtpCooldown() {
    _otpTicker?.cancel();
    setState(() => _otpWait = widget.resendCooldown);
    _otpTicker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _otpWait = _otpWait > 0 ? _otpWait - 1 : 0);
      if (_otpWait == 0) t.cancel();
    });
  }

  /// Texts the OTP to the Indian number typed ("Send OTP"); a refused send shows under the number.
  Future<void> _sendOtp() async {
    if (_busy || _otpWait > 0) return;
    final phone = _e164;
    if (phone == null || !_textable) {
      setState(() => _phoneErrors = (phone: phoneProblem(_phone.text), otp: null));
      return;
    }
    setState(() {
      _phoneErrors = (phone: null, otp: null);
      _error = null;
    });
    try {
      final code = await context.read<AuthController>().sendPhoneOtp(phone);
      if (!mounted) return;
      setState(() {
        _otpSentTo = phone;
        _phoneDevCode = code;
        _otp.clear();
      });
      _startOtpCooldown();
      _otpFocus.requestFocus();
    } on ApiError catch (e) {
      if (mounted) setState(() => _phoneErrors = (phone: e.message, otp: null));
    }
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
    // The number: required; an Indian one proven with its OTP, sent first from the field's own link.
    final phoneIssue = phoneProblem(_phone.text);
    final otpIssue = phoneIssue != null || !_otpNeeded
        ? null
        : (_otpPending ? otpProblem(_otp.text.trim()) : 'Send the OTP to your mobile number first.');
    setState(() {
      _aboutErrors = problems;
      _phoneErrors = (phone: phoneIssue, otp: otpIssue);
      _error = null;
      _duplicate = false;
    });
    if (problems.firstName != null || problems.lastName != null || problems.code != null) return;
    if (phoneIssue != null || otpIssue != null) return;
    final auth = context.read<AuthController>();
    final phone = _e164!;
    setState(() => _busy = true);
    try {
      if (_otpNeeded) {
        try {
          await auth.verifyPhoneOtp(phone, _otp.text.trim());
          _phoneVerified = phone;
        } on ApiError catch (e) {
          if (mounted) setState(() => _phoneErrors = (phone: null, otp: e.message));
          return;
        }
      }
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
        await auth.completeSocialSignup(signup: _social!, firstName: _first.text, lastName: _last.text, phone: phone);
      } else {
        await auth.register(
          email: _address,
          password: _password.text,
          firstName: _first.text,
          lastName: _last.text,
          phone: phone,
        );
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
          const SignupHeader(step: 2, title: 'About You'),
          if (_pendingError == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: p.accent)),
            )
          else ...[
            const SizedBox(height: 22),
            AuthErrorLine(message: _pendingError!),
            const SizedBox(height: 8),
            Text('That sign-in has expired. Start again from the Sign In page.', style: AuthType.small(p)),
            const SizedBox(height: 18),
            AuthOutlinedButton(label: 'Try Again', onPressed: _loadPending),
            const SizedBox(height: 6),
            Center(
              child: AuthLink(key: const Key('signup.backToSignIn'), label: 'Back to Sign In', onTap: _toSignIn),
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
            SignupStep.about => 'About You',
            SignupStep.work => 'Your Work',
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
            child: AuthLink(key: const Key('signup.duplicateSignIn'), label: 'Sign In Instead', onTap: _toSignIn),
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
                label: 'Sign In',
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

  /// Email, password and the consent, then "Join"; under a hairline, "Sign Up
  /// Using" over the Google and LinkedIn pills (owner, 12 Nov 2026: the marks
  /// moved from the top of the card to under the form, headed, and larger).
  Widget _join(BuildContext context) {
    final p = AuthPalette.of(context);
    final busy = _busy || _socialBusy != null;
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthField(
            fieldKey: const Key('signup.email'),
            label: 'Email',
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
          AuthHelperLine(error: _joinErrors.email, helper: 'We will email you a verification code.'),
          const SizedBox(height: 10),
          AuthField(
            fieldKey: const Key('signup.password'),
            label: 'Password',
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
          if (_agreeError) const AuthHelperLine(error: 'Agree to the Terms of Service and Privacy Policy to join.'),
          if (_error != null) ...[const SizedBox(height: 12), AuthErrorLine(message: _error!)],
          const SizedBox(height: 18),
          AuthPrimaryButton(
            key: const Key('signup.join'),
            label: 'Join',
            busyLabel: 'Sending Code…',
            busy: _busy,
            onPressed: _socialBusy == null ? _submitJoin : null,
          ),
          SocialProvidersBlock(
            above: [
              const SizedBox(height: 20),
              Divider(color: p.rule, thickness: 1, height: 1),
              const SizedBox(height: 16),
            ],
            heading: 'Sign Up Using',
            headingStyle: AuthType.body(p).copyWith(color: p.text),
            keyPrefix: 'signup',
            style: SocialPillStyle.of(p),
            width: AuthScaffold.contentWidth(context),
            available: _available,
            busy: _socialBusy,
            enabled: !busy,
            onPressed: _continueWith,
          ),
        ],
      ),
    );
  }

  /// The mobile number and, for an Indian one, its OTP (the website's `PhoneVerifyInline acceptUntextable`).
  List<Widget> _phoneFields(BuildContext context, {required bool askCode}) {
    final p = AuthPalette.of(context);
    final verified = _e164 != null && _phoneVerified == _e164;
    final untextable = _e164 != null && !_textable;
    final String helper;
    if (verified) {
      helper = 'Number verified.';
    } else if (untextable) {
      helper = 'An OTP can be sent only to Indian (+91) numbers. This number is saved as entered.';
    } else if (_otpPending) {
      helper = 'OTP sent to ${_phone.text.trim()}.';
    } else {
      helper = 'Indian (+91) numbers receive an OTP by text. Other numbers are saved as entered.';
    }
    final Widget? trailing;
    if (_otpNeeded && !_otpPending) {
      trailing = AuthLink(key: const Key('signup.sendOtp'), label: 'Send OTP', onTap: _busy ? () {} : _sendOtp);
    } else if (_otpPending) {
      trailing = AuthLink(
        key: const Key('signup.resendOtp'),
        label: _otpWait > 0 ? 'Resend in ${_otpWait}s' : 'Resend OTP',
        style: AuthType.link(p).copyWith(fontSize: 14, color: _otpWait > 0 || _busy ? p.muted : p.accent),
        onTap: _otpWait > 0 || _busy ? () {} : _sendOtp,
      );
    } else {
      trailing = null;
    }
    return [
      AuthField(
        fieldKey: const Key('signup.phone'),
        label: 'Mobile Number',
        controller: _phone,
        focusNode: _phoneFocus,
        icon: Icons.smartphone_outlined,
        hint: '+91 98765 43210',
        enabled: !_busy,
        keyboardType: TextInputType.phone,
        textInputAction: _otpPending || askCode ? TextInputAction.next : TextInputAction.done,
        autofillHints: const [AutofillHints.telephoneNumber],
        autocorrect: false,
        headerTrailing: trailing,
        // The links and the helper follow the number as it is typed.
        onChanged: (_) => setState(() => _phoneErrors = (phone: null, otp: _phoneErrors.otp)),
        onFieldSubmitted: (_) => _otpPending
            ? _otpFocus.requestFocus()
            : askCode
            ? _codeFocus.requestFocus()
            : _submitAbout(),
      ),
      // Before the OTP was sent, its problem ("Send the OTP … first.") sits under the number itself.
      AuthHelperLine(error: _phoneErrors.phone ?? (_otpPending ? null : _phoneErrors.otp), helper: helper),
      if (_otpPending) ...[
        const SizedBox(height: 8),
        AuthField(
          fieldKey: const Key('signup.phoneCode'),
          label: 'Enter Mobile OTP',
          controller: _otp,
          focusNode: _otpFocus,
          icon: Icons.sms_outlined,
          hint: '6-digit OTP',
          enabled: !_busy,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          maxLength: 6,
          letterSpacing: 4,
          onFieldSubmitted: (_) => askCode ? _codeFocus.requestFocus() : _submitAbout(),
        ),
        AuthHelperLine(error: _phoneErrors.otp),
        DevCodeNote(
          code: _phoneDevCode,
          onUse: (code) {
            _otp.text = code;
            setState(() => _phoneErrors = (phone: _phoneErrors.phone, otp: null));
          },
        ),
      ],
    ];
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
            label: 'First Name',
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
            label: 'Last Name',
            controller: _last,
            focusNode: _lastFocus,
            icon: Icons.person_outline_rounded,
            enabled: !_busy,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.familyName],
            onFieldSubmitted: (_) => _phoneFocus.requestFocus(),
          ),
          AuthHelperLine(error: _aboutErrors.lastName),
          const SizedBox(height: 8),
          ..._phoneFields(context, askCode: askCode),
          if (askCode) ...[
            const SizedBox(height: 8),
            AuthField(
              fieldKey: const Key('signup.code'),
              label: 'Email Verification Code',
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
                      label: 'Change Email',
                      onTap: _busy
                          ? () {}
                          : () => setState(() {
                              _error = null;
                              _step = SignupStep.join;
                            }),
                    ),
              onFieldSubmitted: (_) => _submitAbout(),
            ),
            AuthHelperLine(error: _aboutErrors.code, helper: 'Code sent to $_address. It expires in 10 minutes.'),
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
                  Text('No email? Check your spam folder. ', style: AuthType.small(p)),
                  AuthLink(
                    key: const Key('signup.resend'),
                    label: _wait > 0 ? 'Resend in ${_wait}s' : 'Resend Code',
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
            const TermsSentence(lead: 'By selecting Agree & Join, you agree to ICR’s', center: true),
          ],
          const SizedBox(height: 16),
          AuthPrimaryButton(
            key: const Key('signup.continue'),
            label: _isSocial ? 'Agree & Join' : 'Continue',
            busyLabel: 'Creating Account…',
            busy: _busy,
            onPressed: _submitAbout,
          ),
        ],
      ),
    );
  }
}
