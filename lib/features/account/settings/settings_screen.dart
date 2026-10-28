import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/util/links.dart';
import '../../contact/contact_screen.dart';
import '../account_models.dart';
import '../account_repository.dart';
import '../api_account_repository.dart';
import '../companies/my_companies_screen.dart';
import '../demo_account_repository.dart';
import '../profile/my_profile_screen.dart';
import '../saved/saved_items_screen.dart';
import '../widgets/account_kit.dart';
import '../widgets/account_session.dart';
import 'notification_preferences_screen.dart';
import 'security_screen.dart';
import 'settings_sheets.dart';

/// Settings: the account's own controls in one list, as the profile menu's
/// "Settings" row opens it.
///
/// * **Account**: Sign-in & security (email, mobile number, password, links),
///   Your companies (which one the person acts for, switching, leaving, creating),
///   Saved items;
/// * **Preferences**: Language (of ICR's emails, notifications and replies),
///   Notifications (per kind of update, in the app and by email);
/// * **Privacy & data**: Download my data, Delete my account;
/// * **About ICR**: Contact us, the Terms of Service and the Privacy Policy
///   (the only pages that open the website);
/// * **Sign out**.
///
/// Every row opens one of this feature's own screens unless the lead passes a
/// callback to take the person somewhere else in the app.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.repository,
    this.onBack,
    this.onOpenProfile,
    this.onOpenCompanies,
    this.onOpenSaved,
    this.onContact,
    this.onSessionChanged,
    this.opener = openUrl,
    this.share = shareWithPhone,
  });

  final AccountRepository? repository;
  final VoidCallback? onBack;

  /// The person's own profile (`MyProfileScreen`).
  final VoidCallback? onOpenProfile;

  /// "Your companies": the app's own screen when left out.
  final VoidCallback? onOpenCompanies;
  final VoidCallback? onOpenSaved;

  /// "Contact us".
  final VoidCallback? onContact;

  /// The company being acted for changed (see `MyCompaniesScreen.onSessionChanged`).
  final VoidCallback? onSessionChanged;
  final Future<void> Function(BuildContext context, Uri uri) opener;
  final ShareText share;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final AccountRepository _repository;
  String? _locale;
  MyCompanies? _companies;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? (AppConfig.demo ? DemoAccountRepository() : ApiAccountRepository(api: context.read<ApiClient>()));
    _read();
  }

  /// What the rows summarise; a failure leaves the row without its summary.
  Future<void> _read() async {
    try {
      final locale = await _repository.accountLocale();
      if (mounted) setState(() => _locale = locale);
    } catch (_) {}
    try {
      final companies = await _repository.myCompanies();
      if (mounted) setState(() => _companies = companies);
    } catch (_) {}
  }

  void _push(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  void _openProfile() {
    final open = widget.onOpenProfile;
    if (open != null) {
      open();
    } else {
      _push(MyProfileScreen(repository: widget.repository));
    }
  }

  Future<void> _openCompanies() async {
    final open = widget.onOpenCompanies;
    if (open != null) {
      open();
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MyCompaniesScreen(repository: _repository, onSessionChanged: widget.onSessionChanged),
        ),
      );
    }
    // A switch, a leave or a create changed what the row says.
    _read();
  }

  void _openSaved() {
    final open = widget.onOpenSaved;
    if (open != null) {
      open();
    } else {
      _push(const SavedItemsScreen());
    }
  }

  void _contact() {
    final open = widget.onContact;
    if (open != null) {
      open();
    } else {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (c) => contactRoute(c)));
    }
  }

  Future<void> _language() async {
    final saved = await showLanguageSheet(context, repository: _repository, current: _locale);
    if (saved != null && mounted) {
      setState(() => _locale = saved == 'en' ? null : saved);
      showMessage(context, 'Language saved.');
    }
  }

  Future<void> _signOut() async {
    final ok = await confirmAction(
      context,
      title: 'Sign out of ICR?',
      message: 'You will need to sign in again on this phone.',
      confirm: 'Sign out',
      danger: false,
    );
    if (!ok || !mounted) return;
    final navigator = Navigator.of(context);
    final auth = maybeAuth(context);
    await auth?.signOut();
    navigator.popUntil((route) => route.isFirst);
  }

  Future<void> _delete() async {
    final done = await showDeleteAccountSheet(context, repository: _repository);
    if (!done || !mounted) return;
    final navigator = Navigator.of(context);
    // The API ended every session; this phone's tokens are dead too.
    await maybeAuth(context)?.forgetSession();
    navigator.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final session = watchAuth(context)?.user;
    final name = session?.fullName ?? 'Your account';
    final active = _companies?.active;
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AccountBar(title: 'Settings', onBack: widget.onBack),
      body: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 32),
        children: [
          AccountCard(
            child: Row(
              children: [
                AccountAvatar(url: session?.avatarUrl, initials: session?.initials ?? '?', size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AccountText.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (session != null) Text(session.email, style: AccountText.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
                      TextButton(
                        key: const Key('settings.profile'),
                        onPressed: _openProfile,
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32), alignment: Alignment.centerLeft),
                        child: Text('View profile', style: AccountText.link),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _Group(
            title: 'Account',
            rows: [
              _Row(
                key: const Key('settings.security'),
                icon: Symbols.shield_lock,
                title: 'Sign-in & security',
                subtitle: 'Email, mobile number, password, links',
                onTap: () => _push(SignInSecurityScreen(repository: widget.repository)),
              ),
              _Row(
                key: const Key('settings.companies'),
                icon: Symbols.apartment,
                title: 'Your companies',
                subtitle: active == null ? 'Acting as yourself' : 'Acting for ${active.name}',
                onTap: _openCompanies,
              ),
              _Row(key: const Key('settings.saved'), icon: Symbols.bookmark, title: 'Saved items', onTap: _openSaved),
            ],
          ),
          _Group(
            title: 'Preferences',
            rows: [
              _Row(
                key: const Key('settings.language'),
                icon: Symbols.translate,
                title: 'Language',
                subtitle: languageName(_locale),
                onTap: _language,
              ),
              _Row(
                key: const Key('settings.notifications'),
                icon: Symbols.notifications,
                title: 'Notifications',
                subtitle: 'In the app and by email',
                onTap: () => _push(NotificationPreferencesScreen(repository: widget.repository)),
              ),
            ],
          ),
          _Group(
            title: 'Privacy & data',
            rows: [
              _Row(
                key: const Key('settings.export'),
                icon: Symbols.download,
                title: 'Download my data',
                onTap: () => showExportSheet(context, repository: _repository, share: widget.share),
              ),
              _Row(
                key: const Key('settings.delete'),
                icon: Symbols.delete_forever,
                title: 'Delete my account',
                danger: true,
                onTap: _delete,
              ),
            ],
          ),
          _Group(
            title: 'About ICR',
            rows: [
              _Row(key: const Key('settings.contact'), icon: Symbols.mail, title: 'Contact us', onTap: _contact),
              _Row(
                key: const Key('settings.terms'),
                icon: Symbols.description,
                title: 'Terms of Service',
                onTap: () => widget.opener(context, AppConfig.sitePage('/terms')),
              ),
              _Row(
                key: const Key('settings.privacy'),
                icon: Symbols.privacy_tip,
                title: 'Privacy Policy',
                onTap: () => widget.opener(context, AppConfig.sitePage('/privacy')),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: AccountButton(
              key: const Key('settings.signOut'),
              label: 'Sign out',
              icon: Symbols.logout,
              outlined: true,
              danger: true,
              onPressed: _signOut,
            ),
          ),
        ],
      ),
    );
  }

}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
          child: Text(title.toUpperCase(), style: AccountText.meta.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.6, fontSize: 13)),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.slate200),
          ),
          child: Column(
            children: [
              for (final (i, r) in rows.indexed) ...[
                if (i > 0) const Divider(height: 1, thickness: 1, indent: 54, color: AppColors.slate100),
                r,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({super.key, required this.icon, required this.title, required this.onTap, this.subtitle, this.danger = false});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final ink = danger ? AppColors.rose600 : AppColors.slate900;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 22, color: danger ? AppColors.rose600 : AppColors.slate600),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AccountText.itemTitle.copyWith(color: ink)),
                  if (subtitle != null) Text(subtitle!, style: AccountText.meta),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 24, color: AppColors.slate400),
          ],
        ),
      ),
    );
  }
}
