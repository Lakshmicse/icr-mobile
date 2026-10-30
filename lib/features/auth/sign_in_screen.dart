import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_error.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/auth/social_sign_in.dart';
import '../../core/util/links.dart';
import 'auth_widgets.dart';
import 'forgot_password_screen.dart';
import 'linkedin_style.dart';
import 'sign_up_screen.dart';
import 'social_signup_screen.dart';

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Sign-in, laid out as LinkedIn's own sign-in page is (`linkedin_style.dart`),
/// in ICR's colours and following the phone's light or dark setting: the logo,
/// a big "Sign in" with a line under it, email and password
/// (`POST /auth/login`) with "Show" inside the password field, "Forgot
/// password?", one pill button, "or", then "Continue with LinkedIn" and
/// "Continue with Google" through the API's own OAuth flow, and "New to ICR?
/// Join now" at the foot. "Join now" opens the three sign-up screens and "Forgot
/// password?" asks for the reset email, both in the app; someone new arriving
/// through Google or LinkedIn finishes joining in the app too.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _rememberMe = false;
  bool _showPassword = false;
  bool _submitting = false;
  SocialProvider? _socialBusy;
  Set<SocialProvider> _available = const {};
  String? _error;

  bool get _busy => _submitting || _socialBusy != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final auth = context.read<AuthController>();
      if (auth.takeExpiredNotice()) {
        setState(() => _error = 'Your session has ended. Sign in again to continue.');
      }
      final available = await auth.configuredProviders();
      if (mounted) setState(() => _available = available);
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<AuthController>().signIn(
        email: _email.text,
        password: _password.text,
        rememberMe: _rememberMe,
      );
      TextInput.finishAutofillContext();
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _continueWith(SocialProvider provider) async {
    if (!_available.contains(provider)) {
      showMessage(context, '${provider.label} sign-in is not available yet');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _socialBusy = provider;
      _error = null;
    });
    try {
      final signup = await context.read<AuthController>().signInWith(provider);
      if (signup != null && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SocialSignupScreen(signup: signup, provider: provider),
          ),
        );
      }
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _socialBusy = null);
    }
  }

  /// The three sign-up screens. Coming back with an address (an account that
  /// already exists) fills it in here.
  Future<void> _join() async {
    FocusScope.of(context).unfocus();
    final email = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute<String>(builder: (_) => const SignUpScreen()));
    if (!mounted || email == null || email.isEmpty) return;
    setState(() {
      _email.text = email;
      _error = null;
    });
    _passwordFocus.requestFocus();
  }

  void _forgot() {
    FocusScope.of(context).unfocus();
    final typed = _email.text.trim();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        // The address typed on the page, still editable.
        builder: (_) => ForgotPasswordScreen(initialEmail: _emailPattern.hasMatch(typed) ? typed : null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = LiColors.of(context);
    return AutofillGroup(
      child: Form(
        key: _form,
        child: LiScaffold(
          footer: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('New to ICR? ', style: LiType.body(c)),
              LiLink(
                key: const Key('signIn.create'),
                label: 'Join now',
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
                onTap: _join,
              ),
            ],
          ),
          children: [
            Text('Sign in', style: LiType.title(c)),
            const SizedBox(height: 6),
            Text('Stay updated on your professional world.', style: LiType.subtitle(c)),
            const SizedBox(height: 28),
            LiTextField(
              fieldKey: const Key('signIn.email'),
              label: 'Email',
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email, AutofillHints.username],
              autocorrect: false,
              onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return 'Please enter your email address.';
                if (!_emailPattern.hasMatch(email)) return 'Please enter a valid email address.';
                return null;
              },
            ),
            const SizedBox(height: 16),
            LiTextField(
              fieldKey: const Key('signIn.password'),
              label: 'Password',
              controller: _password,
              focusNode: _passwordFocus,
              enabled: !_busy,
              obscureText: !_showPassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              autocorrect: false,
              suffix: LiShowButton(shown: _showPassword, onPressed: () => setState(() => _showPassword = !_showPassword)),
              onFieldSubmitted: (_) => _submit(),
              validator: (value) => (value ?? '').isEmpty ? 'Please enter your password.' : null,
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: LiLink(key: const Key('signIn.forgot'), label: 'Forgot password?', onTap: _forgot),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: AuthCheckbox(
                key: const Key('signIn.remember'),
                label: 'Remember me',
                value: _rememberMe,
                onChanged: _busy ? null : (v) => setState(() => _rememberMe = v),
              ),
            ),
            if (_error != null) ...[const SizedBox(height: 8), AuthErrorLine(message: _error!)],
            SizedBox(height: _error == null ? 16 : 14),
            LiPrimaryButton(
              key: const Key('signIn.submit'),
              label: 'Sign in',
              busyLabel: 'Signing in…',
              busy: _submitting,
              onPressed: _socialBusy == null ? _submit : null,
            ),
            const SizedBox(height: 22),
            const LiOrDivider(),
            const SizedBox(height: 22),
            for (final (i, provider) in SocialProvider.values.indexed) ...[
              if (i > 0) const SizedBox(height: 12),
              LiSocialButton(
                key: Key('signIn.${provider.name}'),
                provider: provider,
                available: _available.contains(provider),
                busy: _socialBusy == provider,
                onPressed: _busy ? null : () => _continueWith(provider),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
