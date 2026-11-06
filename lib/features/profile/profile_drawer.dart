import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:lucide_icons_flutter/lucide_icons_500.dart';
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
import '../shell/icr_bottom_nav.dart';
import '../workspaces/role_workspaces.dart';
import '../workspaces/workspaces.dart';
import 'profile_drawer_data.dart';

/// The profile menu that slides in from the left when the header photo is
/// tapped: a banner with the member's photo over it, their name and headline
/// (one tap target: the full profile), two counts, up to three of their
/// companies, the three association rows, "My activity", and Settings / Sign
/// out at the foot.
///
/// With [workspaces] the menu is the owner's drawer design (6 Nov 2026): under the header, the member's rows (Company,
/// Marketplace, Mentorship, Learning, Jobs — each opening its pages as tabs, the one for the tab on screen filled in
/// blue, with what is live beside it), then "Account": My Account, Saved Items, Referrals and Settings. Sign Out is in
/// Settings, not here.
class ProfileDrawer extends StatefulWidget {
  const ProfileDrawer({
    super.key,
    this.screens = const {},
    this.companiesRepository,
    this.onOpenCompany,
    this.onSessionChanged,
    this.workspaces,
    this.account = const AccountMenu(),
    this.onOpenSection,
    this.mentorStatus,
    this.currentWorkspace,
    this.doors = const [],
  });

  static const width = 307.0;

  /// How many of the member's companies the menu lists; "See all" opens the rest.
  static const companiesShown = 3;

  /// Screens the app has for some of the rows, keyed by the row's website path
  /// (`/councils`). A row with no entry opens the website.
  final Map<String, WidgetBuilder> screens;

  /// Where "My companies" is read from and a switch goes (`GET /me/companies`, `POST /me/companies/switch`).
  /// The API through the app's client by default (the sample member in demo mode); without either the block is
  /// not drawn.
  final AccountRepository? companiesRepository;

  /// Opens a company's page in the app. Without it the website's page opens (through the app's routing).
  final void Function(BuildContext context, String companyId)? onOpenCompany;

  /// The company being acted for changed (a switch): reset what the app cached for the previous one.
  final VoidCallback? onSessionChanged;

  /// The member's rows ([workspacesFor]); null keeps the menu's companies, association rows and "My activity".
  final List<Workspace>? workspaces;

  /// With [workspaces]: which Account rows the member has ([accountMenuFor]).
  final AccountMenu account;

  /// Opens a row's pages as tabs, on one of them (by index), the menu already closed.
  final void Function(WorkspaceSection section, int index)? onOpenSection;

  /// The member's mentor profile's state (`SessionUser.mentorStatus`): a listed mentor's Mentorship row reads
  /// "Available", a paused one's "Paused".
  final String? mentorStatus;

  /// The row drawn as the one the member is in; by default the row of the tab on screen (Learning on the Learning
  /// tab), none on Home.
  final String? currentWorkspace;

  /// With [workspaces]: the website's "Do more on ICR" doors for a member acting as themselves ([startDoorsFor]) —
  /// create a company (to hire, sell or buy), become a mentor. Empty for anyone else.
  final List<StartDoor> doors;

  @override
  State<ProfileDrawer> createState() => _ProfileDrawerState();
}

class _ProfileDrawerState extends State<ProfileDrawer> {
  CompaniesController? _companies;
  AccountRepository? _repository;
  ProfileDrawerController? _drawerData;

  /// The row whose pages are dropped down under it (one at a time); a tap on a page opens the module on that tab
  /// (owner, 6 Nov 2026).
  String? _expanded;

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

  /// A page of a row opens its module on that tab. Through the workspace screen even for one page, since some
  /// pages are built only there (My Jobs, Help & support…).
  void _openSectionAt(WorkspaceSection section, int index) {
    final open = widget.onOpenSection;
    if (open == null) {
      _open(section.items[index].path);
      return;
    }
    Navigator.of(context).pop();
    open(section, index);
  }

  /// The bottom bar's tabs that have a row of their own.
  static const _rowOfTab = {
    AppTab.learning: 'learning',
    AppTab.mentorship: 'mentorship',
    AppTab.marketplace: 'marketplace',
    AppTab.jobs: 'jobs',
  };

  /// What is live beside a row: open requirements, the member's mentor listing, the jobs on the board.
  Widget? _status(Workspace w, ProfileDrawerData data, bool selected) {
    switch (w.key) {
      case 'marketplace':
        final n = data.liveRfqs;
        return n != null && n > 0 ? const _Pill(text: 'LIVE RFQS', tone: _PillTone.green, caps: true) : null;
      case 'mentorship':
        return switch (widget.mentorStatus) {
          'APPROVED' => _Presence(text: 'Available', dot: _Presence.green, ink: _Presence.greenInk, selected: selected),
          'PAUSED' => _Presence(text: 'Paused', dot: AppColors.slate400, ink: AppColors.slate500, selected: selected),
          _ => null,
        };
      case 'jobs':
        final n = data.openJobs;
        return n != null && n > 0 ? _Pill(text: _count(n), tone: _PillTone.blue) : null;
      case 'account':
        // A referral earns ICR credits (the website's Refer page), and Refer & Earn is a page of this row.
        return const _Pill(text: 'Earn credits', tone: _PillTone.green);
    }
    return null;
  }

  /// A count as a pill shows it: "14", "1,240", "12k".
  static String _count(int n) {
    if (n >= 10000) return '${n ~/ 1000}k';
    return n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  }

  static const _sectionGrey = Color(0xFF727781);

  /// The member's rows, then Account (My Account, Saved Items, Referrals, Settings). No Sign Out here: it is in
  /// Settings (owner, 5 Nov 2026).
  List<Widget> _menu(List<Workspace> rows, ProfileDrawerData data) {
    final current = widget.currentWorkspace ?? _rowOfTab[AppShell.currentTab(context)];
    final account = widget.account;
    final saved = data.savedItems;
    // White throughout, a thin line between rows and a heading over each block, no tiles or fills (owner, 6 Nov
    // 2026: "white background, no borders like boxes, line breakers, like LinkedIn").
    return [
      // A row drops its pages down under it; a page opens the module on that tab. The row's own tap only opens or
      // closes the list, so the pages are what is tapped to go somewhere (owner, 6 Nov 2026).
      for (final (i, w) in rows.indexed) ...[
        if (i > 0) const _Rule(),
        _MenuRow(
          key: ValueKey('workspace-${w.key}'),
          icon: w.icon,
          label: w.label,
          selected: w.key == current,
          expanded: w.key == _expanded,
          trailing: _status(w, data, w.key == current),
          onTap: () => setState(() => _expanded = _expanded == w.key ? null : w.key),
        ),
        if (w.key == _expanded)
          for (final (j, item) in w.sections.single.items.indexed)
            _SubRow(
              key: ValueKey('workspace-${w.key}-$j'),
              label: item.label,
              first: j == 0,
              onTap: () => _openSectionAt(w.sections.single, j),
            ),
      ],
      if (widget.doors.isNotEmpty) ...[
        const _Rule(inset: 0, gap: 8),
        const _SectionHeading('Do more on ICR'),
        for (final (i, d) in widget.doors.indexed) ...[
          if (i > 0) const _Rule(),
          _DoorRow(
            key: ValueKey('door-${d.key}'),
            icon: d.icon,
            label: d.label,
            caption: d.caption,
            onTap: () => _open(d.path),
          ),
        ],
      ],
      // Under the rows: Saved Items and Settings (owner, 6 Nov 2026: "Saved Items leave as it is"; the plans and
      // Refer & Earn are pages of the Account row above, so the My Account and Referrals rows are gone).
      const _Rule(inset: 0, gap: 8),
      if (account.savedItems)
        _AccountRow(
          key: const ValueKey('account-saved'),
          icon: LucideIcons500.bookmark,
          label: 'Saved Items',
          trailing: saved != null && saved > 0 ? _Pill(text: _count(saved), tone: _PillTone.grey) : null,
          // Every kind the member bookmarked (jobs, mentors, suppliers, councils, discussions).
          onTap: () => _open('/career/saved'),
        ),
      _AccountRow(
        key: const ValueKey('account-settings'),
        icon: LucideIcons500.settings,
        label: 'Settings',
        onTap: () => _open('/profile?tab=security'),
      ),
    ];
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
                    _Header(
                      data: data,
                      onOpenProfile: () => _openProfile(data),
                      gapBelowCounts: widget.workspaces != null ? 11 : 16,
                    ),
                    Padding(
                      padding: widget.workspaces != null
                          ? const EdgeInsets.fromLTRB(0, 10, 0, 16)
                          : const EdgeInsets.fromLTRB(15, 10, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: widget.workspaces != null
                            ? _menu(widget.workspaces!, data)
                            : [
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
                                  trailing: data.chapterCode != null
                                      ? _Badge(text: data.chapterCode!)
                                      : const _Chevron(),
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
                                  label: 'Saved Jobs',
                                  onTap: () => _open('/career/saved'),
                                ),
                                const SizedBox(height: 2),
                                // Everything posted on ICR (owner, 3 Nov 2026: "whatever is posted needs to be seen"), with
                                // the member's own list one chip away on it. It was "My RFQ Requirements", the member's own
                                // only, which is empty, or refused, for most accounts.
                                _ActivityLink(
                                  icon: const Icon(LucideIcons.filePlus2, size: 14, color: AppColors.slate500),
                                  label: 'Requirements',
                                  onTap: () => _open('/rfq'),
                                ),
                                const SizedBox(height: 2),
                                // The supplier's side of the same board (the website's Find Work & Bid).
                                _ActivityLink(
                                  icon: const Icon(LucideIcons.compass, size: 14, color: AppColors.slate500),
                                  label: 'Find Work & Bid',
                                  onTap: () => _open('/manage/bids'),
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
              // A personal member signs out from Settings (owner, 5 Nov 2026), a row of their menu; the other menu
              // keeps Settings and Sign Out at its foot.
              if (widget.workspaces == null)
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
  const _Header({required this.data, required this.onOpenProfile, this.gapBelowCounts = 16});

  final ProfileDrawerData data;
  final VoidCallback onOpenProfile;

  /// The space between the counts and the line under them.
  final double gapBelowCounts;

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
        // The two counts, plain on white with a thin line between them: no box around them (owner, 6 Nov 2026).
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 26, 0),
          child: Row(
            children: [
              Expanded(
                child: _Metric(value: data.profileViews, label: 'Profile Views'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.only(left: 12),
                  decoration: const BoxDecoration(
                    border: Border(left: BorderSide(color: AppColors.outlineVariant, width: 1)),
                  ),
                  child: _Metric(value: data.postImpressions, label: 'Post Impressions'),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: gapBelowCounts),
        const Divider(height: 1, thickness: 1, color: AppColors.outlineVariant),
      ],
    );
  }
}

/// "My companies" (the owner's wording, 2 Nov 2026): up to three of the companies the member belongs to, the one they are acting for marked, each
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
              Expanded(child: Text('MY COMPANIES', style: AppText.drawerSection)),
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

  /// Null: no Settings here (it is a row of the menu).
  final VoidCallback? onSettings;
  final VoidCallback onSignOut;

  /// The old menu's foot: small Settings and Sign Out links.
  static const large = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: large ? const EdgeInsets.fromLTRB(12, 12, 12, 12) : const EdgeInsets.fromLTRB(12, 13, 12, 12),
      decoration: const BoxDecoration(
        color: AppColors.slate50,
        border: Border(top: BorderSide(color: AppColors.slate100, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: onSettings == null ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
        children: [
          if (onSettings != null)
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
            child: Padding(
              padding: large ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4) : EdgeInsets.zero,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.logOut, size: large ? 18 : 12, color: AppColors.rose600),
                  SizedBox(width: large ? 8 : 4),
                  Text(
                    'Sign Out',
                    style: large
                        ? AppText.plexSans(16, FontWeight.w600, AppColors.rose600)
                        : AppText.drawerFooter.copyWith(color: AppColors.rose600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The thin line between rows (inset to the rows' text by default) or between blocks (edge to edge, with a gap).
class _Rule extends StatelessWidget {
  const _Rule({this.inset = 20, this.gap = 0});

  final double inset;
  final double gap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(inset, gap, inset, gap),
    child: const ColoredBox(color: Color(0xFFE1E3E4), child: SizedBox(height: 1, width: double.infinity)),
  );
}

/// A block's heading: small capitals in light grey, as LinkedIn heads a group.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
    child: Text(text, style: AppText.workSans(11, FontWeight.w700, _ProfileDrawerState._sectionGrey, spacing: 0.4)),
  );
}

/// A row of the menu (6 Nov 2026, LinkedIn-like): a plain icon, its name, and what is live beside it or a chevron,
/// on white with no tile or fill. The row of the tab on screen reads in ICR blue.
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.selected = false,
    this.expanded = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool selected;

  /// The row's pages are dropped down under it: its chevron points down.
  final bool expanded;

  static const blue = Color(0xFF1D63A3);
  static const ink = Color(0xFF111C2D);
  static const iconGrey = Color(0xFF414750);

  @override
  Widget build(BuildContext context) {
    final chevron = Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Icon(
        expanded ? LucideIcons500.chevronDown : LucideIcons500.chevronRight,
        size: 16,
        color: selected || expanded ? blue : const Color(0xFFC1C7D2),
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      expanded: expanded,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 46,
          child: Padding(
            padding: const EdgeInsets.only(left: 20, right: 16),
            child: Row(
              children: [
                Icon(icon, size: 22, color: selected ? blue : iconGrey),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: AppText.plexSans(15, FontWeight.w600, selected ? blue : ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
                chevron,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One page of a dropped-down row, set in from the row's name: a tap opens the module on that tab.
class _SubRow extends StatelessWidget {
  const _SubRow({super.key, required this.label, required this.onTap, this.first = false});

  final String label;
  final VoidCallback onTap;

  /// The first page sits right under the row, with no line above it.
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!first) const _Rule(inset: 56),
        Semantics(
          button: true,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 38,
              child: Padding(
                padding: const EdgeInsets.only(left: 56, right: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    style: AppText.plexSans(14, FontWeight.w500, _MenuRow.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A door for a member acting as themselves: its name over a one-line caption, as the website's nudge puts it.
class _DoorRow extends StatelessWidget {
  const _DoorRow({super.key, required this.icon, required this.label, required this.caption, required this.onTap});

  final IconData icon;
  final String label;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
          child: Row(
            children: [
              Icon(icon, size: 22, color: _MenuRow.iconGrey),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppText.plexSans(14, FontWeight.w600, _MenuRow.ink, lineHeight: 18),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      caption,
                      style: AppText.plexSans(12, FontWeight.w400, _ProfileDrawerState._sectionGrey, lineHeight: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const _RowChevron(),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row of the menu's Account block: a plain icon, its name, and a count, a pill or a chevron.
class _AccountRow extends StatelessWidget {
  const _AccountRow({super.key, required this.icon, required this.label, required this.onTap, this.trailing});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 42,
          child: Padding(
            padding: const EdgeInsets.only(left: 20, right: 16),
            child: Row(
              children: [
                Icon(icon, size: 20, color: _MenuRow.iconGrey),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: AppText.plexSans(14, FontWeight.w500, _MenuRow.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                trailing ?? const _RowChevron(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RowChevron extends StatelessWidget {
  const _RowChevron();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(right: 4),
    child: Icon(LucideIcons500.chevronRight, size: 16, color: Color(0xFFC1C7D2)),
  );
}

enum _PillTone { green, blue, grey }

/// A small rounded label beside a row: "LIVE RFQS", a count, "Earn credits".
class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.tone, this.caps = false});

  final String text;
  final _PillTone tone;

  /// Capitals set a little apart, as the design sets "LIVE RFQS".
  final bool caps;

  @override
  Widget build(BuildContext context) {
    final (fill, ink) = switch (tone) {
      _PillTone.green => (const Color(0xFF9AF2C5), const Color(0xFF0C714D)),
      _PillTone.blue => (const Color(0xFFDEE8FF), const Color(0xFF004B83)),
      _PillTone.grey => (const Color(0xFFF0F3FF), const Color(0xFF414750)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: ShapeDecoration(color: fill, shape: const StadiumBorder()),
      child: Text(
        text,
        maxLines: 1,
        style: AppText.workSans(10, FontWeight.w700, ink, lineHeight: 15, spacing: caps ? 0.5 : 0),
      ),
    );
  }
}

/// A dot and a word: the member's mentor listing ("Available"), white on the blue row.
class _Presence extends StatelessWidget {
  const _Presence({required this.text, required this.dot, required this.ink, this.selected = false});

  final String text;
  final Color dot;
  final Color ink;
  final bool selected;

  static const green = Color(0xFF10B981);
  static const greenInk = Color(0xFF006C49);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text, style: AppText.workSans(11, FontWeight.w600, selected ? Colors.white : ink)),
        const SizedBox(width: 2),
      ],
    );
  }
}
