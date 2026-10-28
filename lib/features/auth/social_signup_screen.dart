import 'package:flutter/material.dart';

import '../../core/auth/social_sign_in.dart';
import '../account/account_repository.dart';
import 'sign_up_screen.dart';

/// Someone new to ICR came back from Google or LinkedIn: the sign-up's
/// "About you" (their name from the provider, and the emailed 6-digit code
/// only when the provider would not vouch for the address), "Agree & join"
/// makes the account (`POST /auth/register` with the provider's token), then
/// "Your work", as on the website, where a social sign-up joins the same three
/// screens at the second.
class SocialSignupScreen extends StatelessWidget {
  const SocialSignupScreen({super.key, required this.signup, required this.provider, this.account});

  final SocialSignup signup;
  final SocialProvider provider;

  /// Where "Your work" writes; the API when null.
  final AccountRepository? account;

  @override
  Widget build(BuildContext context) => SignUpScreen(social: signup, provider: provider, account: account);
}
