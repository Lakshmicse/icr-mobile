import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/util/links.dart';
import '../account/account_labels.dart';
import '../account/account_models.dart';
import '../account/account_repository.dart';
import '../account/api_account_repository.dart';
import '../account/companies/companies_controller.dart';
import '../account/companies/company_words.dart';
import '../account/companies/my_companies_screen.dart';
import '../account/demo_account_repository.dart';
import '../account/widgets/account_kit.dart' show CompanyLogo;
import '../shell/app_shell.dart';
import 'profile_drawer_data.dart';

/// The profile menu that slides in from the left when the header photo is
/// tapped: a banner with the member's photo over it, their name and headline
/// (one tap target: the full profile), two counts, up to three of their
/// companies, the three association rows, "My activity", and Settings / Sign
/// out at the foot.
class ProfileDrawer extends StatefulWidget {
  const ProfileDrawer({
    super.key,
    this.screens = const {},
    this.companiesRepository,
    this.onOpenCompany,
    this.onSessionChanged,
  });

  static const width = 307.0;

  /// How many of the member's companies the menu lists; "See all" opens the rest.
  static const companiesShown = 3;

  /// Screens the app has for some of the rows, keyed by the row's website path
  /// (`/councils`). A row with no entry opens the website.
  final Map<String, WidgetBuilder> screens;

  /// Where "Your companies" is read from and a switch goes (`GET /me/companies`, `POST /me/companies/switch`).
  /// The API through the app's client by default (the sample member in demo mode); without either the block is
  /// not drawn.
  final AccountRepository? companiesRepository;

  /// Opens a company's page in the app. Without it the website's page opens (through the app's routing).
  final void Function(BuildContext context, String companyId)? onOpenCompany;

  /// The company being acted for changed (a switch): reset what the app cached for the previous one.
  final VoidCallback? onSessionChanged;

  @override
  State<ProfileDrawer> createState() => _ProfileDrawerState();
}

class _ProfileDrawerState extends State<ProfileDrawer> {
  CompaniesController? _companies;
  AccountRepository? _repository;
  ProfileDrawerController? _drawerData;

  @override
  void initState() {
    super.initState();
    _repository = widget.companiesRepository ?? _repositoryFromContext();
    final repository = _repository;
    if (repository != null) {
      final auth = context.read<AuthController>();
      _companies = CompaniesController(
        repository: repository,
        adopt: (t) => auth.adoptSession(accessToken: t.accessToken, refreshToken: t.refreshToken, user: t.user),
        onSessionChanged: widget.onSessionChanged,
      );
      // What the menu last read shows at once; the list is read again behind it.
      _drawerData = context.read<ProfileDrawerController>();
      final cached = _drawerData!.cachedCompanies;
      if (cached != null) {
        _companies!
          ..data = cached
          ..loading = false;
      }
      _companies!.addListener(_remember);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProfileDrawerController>().ensureLoaded();
      _companies?.load(refresh: _companies?.data != null);
    });
  }

  void _remember() {
    final data = _companies?.data;
    if (data != null) _drawerData?.cachedCompanies = data;
  }

  AccountRepository? _repositoryFromContext() {
    if (AppConfig.demo) return DemoAccountRepository();
    final api = Provider.of<ApiClient?>(context, listen: false);
    return api == null ? null : ApiAccountRepository(api: api);
  }

  @override
  void dispose() {
    _companies?.removeListener(_remember);
    _companies?.dispose();
    super.dispose();
  }

  void _open(String path) {
    final screen = widget.screens[path];
    Navigator.of(context).pop();
    if (screen != null) {
      AppShell.push<void>(context, screen);
      return;
    }
    openSitePage(context, path);
  }

  /// The member's own profile is an app screen (`/profile`). A signed-in member's `profilePath` is the website's
  /// public page (`/members/<slug>`), which no door maps, so it would leave the app.
  void _openProfile(ProfileDrawerData data) =>
      _open(widget.screens.containsKey('/profile') ? '/profile' : data.profilePath);

  void _openCompanyPage(String companyId) {
    final open = widget.onOpenCompany;
    if (open != null) {
      open(context, companyId);
    } else {
      openSitePage(context, '/companies/$companyId');
    }
  }

  /// A company's row: the one being acted for opens its page; any other becomes the one acted for (the same
  /// switch "My companies" makes, which hands back a fresh session), and the menu closes behind it.
  Future<void> _tapCompany(MyCompany company) async {
    final controller = _companies;
    if (controller == null || controller.busy) return;
    if (company.active) {
      Navigator.of(context).pop();
      _openCompanyPage(company.companyId);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final drawerData = context.read<ProfileDrawerController>();
    final ok = await controller.switchTo(company.companyId);
    if (!mounted) return;
    if (!ok) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(controller.actionError ?? 'Could not switch company.')));
      controller.dismissError();
      return;
    }
    // The headline names the company the member works for.
    unawaited(drawerData.refresh());
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Now working as ${company.name}.')));
  }

  Future<void> _seeAllCompanies() async {
    final repository = _repository;
    Navigator.of(context).pop();
    await AppShell.push<void>(
      context,
      (_) => MyCompaniesScreen(
        repository: repository,
        onSessionChanged: widget.onSessionChanged,
        onOpenCompany: _openCompanyPage,
      ),
    );
    if (mounted) unawaited(_companies?.load(refresh: true));
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<ProfileDrawerController>().data;
    return Drawer(
      width: ProfileDrawer.width,
      backgroundColor: Colors.white,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(right: BorderSide(color: AppColors.slate200, width: 1)),
          boxShadow: [BoxShadow(color: Color(0x40000000), offset: Offset(0, 25), blurRadius: 50, spreadRadius: -12)],
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _Header(data: data, onOpenProfile: () => _openProfile(data)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(15, 10, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_companies != null)
                            _CompaniesBlock(
                              controller: _companies!,
                              onTapCompany: _tapCompany,
                              onSeeAll: _seeAllCompanies,
                            ),
                          _AssociationRow(
                            icon: Image.asset('assets/images/icons/chapters.png', width: 48, height: 48),
                            title: 'Regional Chapters',
                            subtitle: data.chaptersLine ?? 'Bengaluru, Mumbai, Delhi & more',
                            trailing: data.chapterCode != null ? _Badge(text: data.chapterCode!) : const _Chevron(),
                            onTap: () => _open('/chapters'),
                          ),
                          const SizedBox(height: 4),
                          _AssociationRow(
                            icon: Image.asset('assets/images/icons/councils.png', width: 48, height: 48),
                            title: 'Working Councils',
                            subtitle: data.councilsLine ?? 'Sustainability, ESG & Smart PropTech',
                            trailing: const _Chevron(),
                            onTap: () => _open('/councils'),
                          ),
                          const SizedBox(height: 4),
                          _AssociationRow(
                            icon: Image.asset('assets/images/icons/volunteer.png', width: 48, height: 48),
                            title: 'Get Involved & Volunteer',
                            subtitle: 'Earn certified CPD credits',
                            trailing: data.cpdLabel != null ? _CpdPill(label: data.cpdLabel!) : const _Chevron(),
                            onTap: () => _open('/get-involved'),
                          ),
                          const SizedBox(height: 15),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text('MY ACTIVITY', style: AppText.drawerSection),
                          ),
                          const SizedBox(height: 8),
                          _ActivityLink(
                            icon: const Icon(LucideIcons.bookmark, size: 14, color: AppColors.slate500),
                            label: 'Saved Items & Jobs',
                            onTap: () => _open('/career/saved'),
                          ),
                          const SizedBox(height: 2),
                          _ActivityLink(
                            icon: const Icon(LucideIcons.filePlus2, size: 14, color: AppColors.slate500),
                            label: 'My RFQ Requirements',
                            onTap: () => _open('/manage/requirements'),
                          ),
                          const SizedBox(height: 2),
                          _ActivityLink(
                            icon: const Icon(LucideIcons.award, size: 15, color: AppColors.slate500),
                            label: 'Certificates & Badges',
                            onTap: () => _open('/learning/certificates'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _Footer(
                onSettings: () => _open('/profile?tab=security'),
                onSignOut: () {
                  final auth = context.read<AuthController>();
                  Navigator.of(context).pop();
                  auth.signOut();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The banner, the photo, and the name, headline and place under it are one button: the member's full profile
/// (there is no separate "View Full Profile"). The two counts under them are plain.
class _Header extends StatelessWidget {
  const _Header({required this.data, required this.onOpenProfile});

  final ProfileDrawerData data;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final location = data.locationLine;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: 'Open your profile. ${data.name}',
          excludeSemantics: true,
          child: Material(
            color: Colors.white,
            child: InkWell(
              key: const ValueKey('drawer-profile'),
              onTap: onOpenProfile,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 94.5,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 2.5,
                          top: 12,
                          width: 296,
                          height: 52,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            child: _Cover(url: data.coverUrl, asset: data.coverAsset),
                          ),
                        ),
                        Positioned(left: 20, top: 26, child: _Avatar(data: data)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 14, right: 26),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            data.name,
                            style: AppText.drawerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (data.verified) ...[
                          const SizedBox(width: 6),
                          const Icon(Symbols.verified, fill: 0, weight: 600, size: 17, color: AppColors.primary),
                        ],
                      ],
                    ),
                  ),
                  if (data.headline != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 14, right: 26, top: 1),
                      child: Text(
                        data.headline!,
                        style: AppText.drawerHeadline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (location != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 14, right: 26),
                      child: SizedBox(
                        height: 34.5,
                        child: Row(
                          children: [
                            const Icon(Symbols.location_on, fill: 1, size: 12, color: AppColors.slate400),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                location,
                                style: AppText.drawerLocation,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 1, 26, 0),
          child: Container(
            padding: const EdgeInsets.all(10.8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outlineVariant, width: 0.8),
            ),
            child: Row(
              children: [
                Expanded(child: _Metric(value: data.profileViews, label: 'Profile Views')),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(left: 11),
                    decoration: const BoxDecoration(
                      border: Border(left: BorderSide(color: AppColors.slate200, width: 1)),
                    ),
                    child: _Metric(value: data.postImpressions, label: 'Post Impressions'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Divider(height: 1, thickness: 1, color: AppColors.slate100),
      ],
    );
  }
}

/// "Your companies": up to three of the companies the member belongs to, the one they are acting for marked, each
/// a tap away from its page (or from becoming the one they act for). A member with none sees no block at all (no
/// "Create a company" row: the owner's call, 28 Oct 2026), and neither does a read that failed, never an error in
/// the menu.
class _CompaniesBlock extends StatelessWidget {
  const _CompaniesBlock({required this.controller, required this.onTapCompany, required this.onSeeAll});

  final CompaniesController controller;
  final ValueChanged<MyCompany> onTapCompany;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final data = controller.data;
        if (data == null) {
          // Still reading: two grey rows. A failed first read leaves the block out.
          return controller.loading
              ? const _CompaniesFrame(children: [_SkeletonRow(), _SkeletonRow()])
              : const SizedBox.shrink();
        }
        // ICR staff accounts are personal: they have no companies and cannot create one.
        if (!data.canJoinCompanies) return const SizedBox.shrink();
        // No company: nothing to list, so no heading and no way to create one here.
        if (data.companies.isEmpty) return const SizedBox.shrink();
        final all = [...data.companies]..sort((a, b) => (b.active ? 1 : 0) - (a.active ? 1 : 0));
        final shown = all.take(ProfileDrawer.companiesShown).toList();
        return _CompaniesFrame(
          onSeeAll: all.length > ProfileDrawer.companiesShown ? onSeeAll : null,
          children: [
            for (final c in shown)
              _CompanyRow(company: c, switching: controller.switching == c.companyId, onTap: () => onTapCompany(c)),
          ],
        );
      },
    );
  }
}

class _CompaniesFrame extends StatelessWidget {
  const _CompaniesFrame({required this.children, this.onSeeAll});

  final List<Widget> children;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(child: Text('YOUR COMPANIES', style: AppText.drawerSection)),
              if (onSeeAll != null)
                InkWell(
                  key: const ValueKey('drawer-companies-all'),
                  onTap: onSeeAll,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text('See all', style: AppText.workSans(12, FontWeight.w600, AppColors.primary)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        ...children,
        const SizedBox(height: 8),
        const Divider(height: 1, thickness: 1, color: AppColors.slate100),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _CompanyRow extends StatelessWidget {
  const _CompanyRow({required this.company, required this.switching, required this.onTap});

  final MyCompany company;
  final bool switching;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = company.active ? CompanyWords.active : 'Tap to work as this company';
    return Semantics(
      button: true,
      label: '${company.name}. ${roleLabel(company.role)}. $state',
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('drawer-company:${company.companyId}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              CompanyLogo(url: company.logoUrl, name: company.name, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      company.name,
                      style: AppText.workSans(16, FontWeight.w600, const Color(0xE6000000)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      roleLabel(company.role),
                      style: AppText.workSans(12, FontWeight.w400, const Color(0x99000000)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (switching)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else if (company.active)
                Container(
                  key: ValueKey('drawer-company-active:${company.companyId}'),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: const ShapeDecoration(color: Color(0xFFEDF3F8), shape: StadiumBorder()),
                  child: Text(CompanyWords.active, style: AppText.workSans(12, FontWeight.w600, AppColors.primary)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    const grey = ColoredBox(color: AppColors.slate100, child: SizedBox(height: 12));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.slate100, borderRadius: BorderRadius.circular(8.8)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(widthFactor: 0.6, child: grey),
                SizedBox(height: 6),
                FractionallySizedBox(widthFactor: 0.35, child: grey),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({this.url, this.asset});

  final String? url;
  final String? asset;

  @override
  Widget build(BuildContext context) {
    // The spec's banner, for a member with no cover photo.
    const fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1C2B45), Color(0xFF3B5A7D), Color(0xFFA9764A), Color(0xFF5A4634)],
          stops: [0, 0.45, 0.8, 1],
        ),
      ),
    );
    if (asset != null) return Image.asset(asset!, fit: BoxFit.cover);
    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url!,
        fit: BoxFit.cover,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      );
    }
    return fallback;
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.data});

  final ProfileDrawerData data;

  @override
  Widget build(BuildContext context) {
    final initials = Container(
      color: const Color(0xFFDCE6F2),
      alignment: Alignment.center,
      child: Text(
        data.initials,
        style: TextStyle(fontFamily: AppText.work, fontWeight: FontWeight.w600, fontSize: 22, color: AppColors.primary),
      ),
    );
    final Widget photo;
    if (data.photoAsset != null) {
      photo = Image.asset(data.photoAsset!, fit: BoxFit.cover);
    } else if (data.photoUrl != null) {
      photo = CachedNetworkImage(
        imageUrl: data.photoUrl!,
        fit: BoxFit.cover,
        placeholder: (_, _) => initials,
        errorWidget: (_, _, _) => initials,
      );
    } else {
      photo = initials;
    }
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(color: AppColors.avatarFocusRing, spreadRadius: 2),
                BoxShadow(color: Color(0x1A000000), offset: Offset(0, 4), blurRadius: 6, spreadRadius: -1),
                BoxShadow(color: Color(0x1A000000), offset: Offset(0, 2), blurRadius: 4, spreadRadius: -2),
              ],
            ),
            child: ClipOval(child: photo),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.online,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final int? value;
  final String label;

  static String _group(int n) => n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value == null ? '—' : _group(value!), style: AppText.drawerMetric),
        Text(label, style: AppText.drawerMetricLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _AssociationRow extends StatelessWidget {
  const _AssociationRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  final Widget icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              SizedBox(width: 48, height: 48, child: Center(child: icon)),
              const SizedBox(width: 5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // A wider pill beside it ("+8.5 CPD") must not cut the title short: it shrinks to fit.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(title, style: AppText.drawerRowTitle, maxLines: 1),
                    ),
                    Text(subtitle, style: AppText.drawerRowSubtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.emerald50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.emerald200, width: 1),
      ),
      child: Text(text, style: AppText.drawerBadge),
    );
  }
}

class _CpdPill extends StatelessWidget {
  const _CpdPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: const ShapeDecoration(color: AppColors.amber100, shape: StadiumBorder()),
      child: Text(label, style: AppText.drawerCpd),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(right: 2),
    child: Icon(LucideIcons.chevronRight, size: 13, color: AppColors.slate400),
  );
}

class _ActivityLink extends StatelessWidget {
  const _ActivityLink({required this.icon, required this.label, required this.onTap});

  final Widget icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.25),
        child: Row(
          children: [
            SizedBox(width: 15, child: Center(child: icon)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: AppText.drawerLink, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.onSettings, required this.onSignOut});

  final VoidCallback onSettings;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 13, 12, 12),
      decoration: const BoxDecoration(
        color: AppColors.slate50,
        border: Border(top: BorderSide(color: AppColors.slate100, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: onSettings,
            borderRadius: BorderRadius.circular(6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.settings, size: 13.5, color: AppColors.slate600),
                const SizedBox(width: 6),
                Text('Settings', style: AppText.drawerFooter),
              ],
            ),
          ),
          InkWell(
            onTap: onSignOut,
            borderRadius: BorderRadius.circular(6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.logOut, size: 12, color: AppColors.rose600),
                const SizedBox(width: 4),
                Text('Sign Out', style: AppText.drawerFooter.copyWith(color: AppColors.rose600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
