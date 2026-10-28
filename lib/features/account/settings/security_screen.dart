import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/forgot_password_screen.dart';
import '../../auth/verify_email_screen.dart';
import '../account_models.dart';
import '../account_repository.dart';
import '../account_rules.dart';
import '../api_account_repository.dart';
import '../demo_account_repository.dart';
import '../phone/phone_sheets.dart';
import '../profile/profile_controller.dart';
import '../profile/profile_kit.dart';
import '../widgets/account_kit.dart';
import '../widgets/account_session.dart';
import 'contact_sheet.dart';

/// "Sign-in & security", the website's `/profile?tab=security`: how to reach
/// the person (email, mobile number with its confirmation, work email, second
/// number, links) and how they sign in (the password).
///
/// * the sign-in email is shown with whether it is confirmed; a confirmed one
///   needs nothing, an old account's opens the confirmation (`VerifyEmailScreen`);
/// * the mobile number opens its sheet: **Send code**, **Verify** for a +91
///   number, **Save number** for any other country's, **Remove number**;
/// * **Edit contact info** opens the work email, second number and links;
/// * **Change password** sends the reset link to the account's own address,
///   which is the only way the API changes a password (it also sets one for an
///   account that signed up with Google or LinkedIn).
class SignInSecurityScreen extends StatefulWidget {
  const SignInSecurityScreen({super.key, this.repository, this.onBack});

  final AccountRepository? repository;
  final VoidCallback? onBack;

  @override
  State<SignInSecurityScreen> createState() => _SignInSecurityScreenState();
}

class _SignInSecurityScreenState extends State<SignInSecurityScreen> {
  late final MyProfileController _c;
  late final AccountRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? (AppConfig.demo ? DemoAccountRepository() : ApiAccountRepository(api: context.read<ApiClient>()));
    _c = MyProfileController(_repository, onIdentityChanged: maybeAuth(context)?.refreshUser);
    _read();
  }

  Future<void> _read() => Future.wait([_c.retry(_c.profile), _c.retry(_c.links)]);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _editPhone(MyProfile me) async {
    final changed = await showPhoneSheet(context, repository: _repository, phone: me.phone, verified: me.phoneVerified);
    if (changed) {
      await _c.refresh();
      if (mounted) showMessage(context, 'Mobile number saved.');
    }
  }

  Future<void> _editContact() async {
    if (!_c.links.ready) {
      showMessage(context, 'Your links are still loading. Try again in a moment.');
      return;
    }
    if (await showContactSheet(context, _c) && mounted) showMessage(context, 'Contact info saved.');
  }

  void _changePassword(MyProfile me) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ForgotPasswordScreen(email: me.email, title: 'Change your password')),
    );
  }

  void _confirmEmail() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const VerifyEmailScreen()));
  }

  static void showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AccountBar(title: 'Sign-in & security', onBack: widget.onBack),
      body: ListenableBuilder(
        listenable: _c,
        builder: (context, _) {
          final me = _c.profile.value;
          if (me == null) {
            if (_c.profile.loading) return const AccountLoading();
            return AccountError(message: _c.profile.error ?? 'Try again in a moment.', onRetry: _read);
          }
          final links = _c.links.value?.present ?? const <String, String>{};
          final confirmed = emailConfirmed(context);
          final textable = canTextPhone(me.phone);
          return RefreshIndicator(
            onRefresh: _c.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 12, bottom: 28),
              children: [
                AccountCard(
                  title: 'Sign in',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Line(
                        icon: Symbols.mail,
                        label: 'Email',
                        value: me.email,
                        chip: confirmed
                            ? const AccountChip(label: 'Confirmed', color: Color(0xFFECFDF5), ink: Color(0xFF047857), icon: Symbols.verified)
                            : const AccountChip(label: 'Not confirmed', color: Color(0xFFFFF7E6), ink: Color(0xFF92400E)),
                        action: confirmed ? null : 'Confirm',
                        actionKey: const Key('security.confirmEmail'),
                        onAction: _confirmEmail,
                      ),
                      _Line(
                        icon: Symbols.lock,
                        label: 'Password',
                        value: 'Change it with a link sent to ${me.email}',
                        action: 'Change',
                        actionKey: const Key('security.changePassword'),
                        onAction: () => _changePassword(me),
                        divider: true,
                      ),
                    ],
                  ),
                ),
                AccountCard(
                  title: 'Contact info',
                  trailing: CardIconButton(
                    key: const Key('security.editContact'),
                    icon: Symbols.edit,
                    tooltip: 'Edit contact info',
                    onPressed: _editContact,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Line(
                        icon: Symbols.smartphone,
                        label: 'Mobile number',
                        value: me.phone == null ? 'Not added' : formatPhone(me.phone),
                        // Only a number a code can reach is ever "not verified".
                        chip: me.phone == null
                            ? null
                            : me.phoneVerified
                            ? const AccountChip(label: 'Verified', color: Color(0xFFECFDF5), ink: Color(0xFF047857), icon: Symbols.verified)
                            : textable
                            ? const AccountChip(label: 'Not verified', color: Color(0xFFFFF7E6), ink: Color(0xFF92400E))
                            : null,
                        subtitle: me.phone == null ? null : phoneCountryName(me.phone),
                        action: me.phone == null ? 'Add' : (me.phoneVerified || !textable ? 'Edit' : 'Verify'),
                        actionKey: const Key('security.phone'),
                        onAction: () => _editPhone(me),
                      ),
                      if (me.workEmail != null) _Line(icon: Symbols.work, label: 'Work email', value: me.workEmail!, divider: true),
                      if (me.altPhone != null)
                        _Line(icon: Symbols.call, label: 'Alternative number', value: formatPhone(me.altPhone), divider: true),
                      for (final e in links.entries)
                        _Line(
                          icon: Symbols.link,
                          label: ProfileLinks.labels[e.key] ?? 'Link',
                          value: displayLink(e.value),
                          divider: true,
                        ),
                      if (_c.links.error != null && !_c.links.ready)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: SectionLoadError(what: 'links', message: _c.links.error!, onRetry: () => _c.retry(_c.links)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.chip,
    this.action,
    this.actionKey,
    this.onAction,
    this.divider = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final Widget? chip;
  final String? action;
  final Key? actionKey;
  final VoidCallback? onAction;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (divider) const Divider(height: 1, thickness: 1, color: AppColors.slate100),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 20, color: AppColors.slate500),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AccountText.label),
                    const SizedBox(height: 2),
                    Text(value, style: AccountText.body),
                    if (subtitle != null) Text(subtitle!, style: AccountText.meta),
                    if (chip != null) ...[const SizedBox(height: 6), chip!],
                  ],
                ),
              ),
              if (action != null)
                TextButton(
                  key: actionKey,
                  onPressed: onAction,
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  child: Text(action!, style: AccountText.link),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
