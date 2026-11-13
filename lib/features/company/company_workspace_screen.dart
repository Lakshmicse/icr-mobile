import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart' show openSitePage, showMessage;
import '../../core/widgets/title_bar.dart';
import '../account/phone/phone_sheets.dart' show copyWithNotice;
import '../account/widgets/photo_picker.dart' show PhotoPicker, pickEvidenceFromDevice, pickImageFromDevice;
import '../notifications/notifications_screen.dart';
import '../site/site_kit.dart';
import 'company_controller.dart';
import 'company_fields.dart';
import 'company_repository.dart';
import 'company_words.dart';
import 'widgets/certifications_tab.dart';
import 'widgets/company_header.dart';
import 'widgets/company_kit.dart';
import 'widgets/identity_sheets.dart';
import 'widgets/identity_tab.dart';
import 'widgets/no_company_view.dart';
import 'widgets/overview_tab.dart';
import 'widgets/verification_card.dart';

/// The company workspace — the website's `/company` page ("Dashboard" under Company in the app's drawer): the
/// ACTIVE company's details, its company check and supplier level, and its certifications, as the website draws
/// them. The header names the company and says the changes are every member's; the tabs are the website's
/// (Overview, Company Details, Certifications); `verification` is not a tab but a place on Company Details, so the
/// website's `?tab=verification` opens that tab at the company check.
///
/// The sections of Company Details are read-only and edited in sheets (the person's profile does the same); each
/// sheet sends only the fields that changed (`PATCH /companies/me`), disables what a verified company may no longer
/// change with the sentence the API would refuse with, and the company check files the company as saved.
///
/// A member acting for no company gets the website's `NoCompany` notice and the way on; a role that may not edit the
/// company profile is told so. The lead wires [onOpenCompanyPage] (the company's public page) and [onOpenTeam] (the
/// team page); [repository] is a seam for tests.
class CompanyWorkspaceScreen extends StatefulWidget {
  const CompanyWorkspaceScreen({
    super.key,
    required this.onBack,
    this.tab,
    this.onOpenCompanyPage,
    this.onOpenTeam,
    this.repository,
    this.pickPhoto,
    this.pickDocument,
    this.now,
  });

  final VoidCallback onBack;

  /// The website's `?tab=`: `overview`, `identity`, `verification`, `certifications`; null is the overview.
  final String? tab;

  /// The company's public page in the app.
  final void Function(String id)? onOpenCompanyPage;

  /// The team page in the app.
  final VoidCallback? onOpenTeam;
  final CompanyRepository? repository;

  /// Chooses a logo on the phone; the phone's own picture chooser when null.
  final PhotoPicker? pickPhoto;

  /// Chooses a PDF or a picture of a document; the phone's own file chooser when null.
  final PhotoPicker? pickDocument;

  /// The clock the renewals and the "still held" checks read (tests).
  final DateTime? now;

  @override
  State<CompanyWorkspaceScreen> createState() => _CompanyWorkspaceScreenState();
}

enum _Tab { overview, details, certifications }

class _CompanyWorkspaceScreenState extends State<CompanyWorkspaceScreen> {
  late final CompanyController _c;
  late _Tab _tab;
  bool _toVerification = false;
  bool _teamOpened = false;
  bool _logoBusy = false;
  final _verificationKey = GlobalKey();
  final _certificationsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final repo =
        widget.repository ??
        (AppConfig.demo ? DemoCompanyRepository() : ApiCompanyRepository(api: context.read<ApiClient>()));
    _c = CompanyController(repo, clock: widget.now == null ? null : () => widget.now!)..start();
    _tab = switch (widget.tab) {
      'identity' || 'company' || 'listing' || 'verification' => _Tab.details,
      'certifications' => _Tab.certifications,
      _ => _Tab.overview,
    };
    _toVerification = widget.tab == 'verification';
    _c.addListener(_afterLoad);
  }

  @override
  void dispose() {
    _c.removeListener(_afterLoad);
    _c.dispose();
    super.dispose();
  }

  /// Once the page has drawn: the website's `?tab=verification` lands on the company check; `?tab=team` opens the
  /// team page the lead wired.
  void _afterLoad() {
    if (_c.profile == null) return;
    // The company check is drawn once the dossier has been read; scroll after the frame that draws it.
    if (_toVerification && (_c.dossierLoaded || !_c.hasCompany)) {
      _toVerification = false;
      _scrollTo(_verificationKey);
    }
    if (widget.tab == 'team' && !_teamOpened && widget.onOpenTeam != null) {
      _teamOpened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onOpenTeam!();
      });
    }
  }

  void _scrollTo(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx != null && mounted) {
        Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: 0.05);
      }
    });
  }

  void _jump(CompanyJump to) {
    setState(() {
      _tab = switch (to) {
        CompanyJump.details || CompanyJump.verification => _Tab.details,
        CompanyJump.certifications => _Tab.certifications,
      };
    });
    if (to == CompanyJump.verification) _scrollTo(_verificationKey);
  }

  // --- what the page does ----------------------------------------------------------------------------------------

  void _openSitePage(String path) => unawaited(openSitePage(context, path));

  void _openPublic() {
    final id = _c.company?.id;
    if (id == null) return;
    final open = widget.onOpenCompanyPage;
    if (open != null) {
      open(id);
    } else {
      _openSitePage('/companies/$id');
    }
  }

  Future<void> _editSection(CompanyFieldSection section) async {
    final saved = await showSectionSheet(
      context,
      _c,
      section,
      pickDocument: widget.pickDocument ?? pickEvidenceFromDevice,
    );
    if (saved && mounted) showMessage(context, CompanyWords.saved);
  }

  /// A missing item of the company check opens the section that holds it.
  void _openField(CompanyFieldKey key) => _editSection(companyFields[key]!.section);

  Future<void> _changeLogo() async {
    final photo = await (widget.pickPhoto ?? pickImageFromDevice)();
    if (photo == null || !mounted) return;
    setState(() => _logoBusy = true);
    final refusal = await changeLogo(_c, photo);
    if (!mounted) return;
    setState(() => _logoBusy = false);
    showMessage(context, refusal ?? 'Logo saved.');
  }

  Future<void> _fileCheck() async {
    final refusal = await _c.fileCheck();
    if (!mounted) return;
    if (refusal != null) {
      showMessage(context, refusal);
    } else {
      _scrollTo(_verificationKey);
    }
  }

  Future<void> _startSelling() async {
    final refusal = await _c.startSelling();
    if (refusal != null && mounted) showMessage(context, refusal);
  }

  // --- build -----------------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) => Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              TitleBar(title: CompanyWords.barTitle, onBack: widget.onBack, onBell: () => openNotifications(context)),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    final c = _c;
    if (c.profile == null) {
      if (c.loading) return const SiteLoading();
      return SiteError(
        key: const ValueKey('company-error'),
        message: c.error ?? 'Try again in a moment.',
        onRetry: c.refresh,
      );
    }
    if (c.lacksCompany) {
      return NoCompanyView(
        role: c.role,
        standing: c.standing,
        onSwitch: () => _openSitePage('/account/companies'),
        onCreate: () => _openSitePage('/account/companies/new'),
        onSupport: () => _openSitePage('/support'),
      );
    }
    if (!c.mayEdit) return NotAnEditorView(company: c.company?.name ?? 'this company');

    // The website's Team tab mounts its team manager; the app's team page is its own screen, so the tab opens it
    // (one team manager, never a second copy). Shown to the roles that run the team, as on the website.
    final team = widget.onOpenTeam != null && c.hasCompany && teamManagerRoles.contains(c.role);
    final labels = [
      CompanyWords.tabOverview,
      c.role == 'BUYER' ? CompanyWords.tabOrganizationDetails : CompanyWords.tabDetails,
      CompanyWords.tabCertifications,
      if (team) CompanyWords.tabTeam,
    ];
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: c.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          CompanyHeader(
            profile: c.profile!,
            gate: c.gate,
            standing: c.standing,
            onViewPublic: _openPublic,
            onSwitch: () => _openSitePage('/account/companies'),
            onEditLogo: c.hasCompany ? _changeLogo : null,
            logoBusy: _logoBusy,
          ),
          hairline,
          CompanyTabs(
            labels: labels,
            selected: _tab.index,
            onSelect: (i) => i < _Tab.values.length ? setState(() => _tab = _Tab.values[i]) : widget.onOpenTeam!(),
          ),
          switch (_tab) {
            _Tab.overview => OverviewTab(
              controller: c,
              onJump: _jump,
              onOpenSitePage: _openSitePage,
              onOpenTeam: widget.onOpenTeam,
              onOpenCompanyPage: _openPublic,
              onStartSelling: _startSelling,
              onCopyLink: (url) => unawaited(copyWithNotice(context, url, CompanyWords.linkCopied)),
            ),
            _Tab.details => IdentityTab(
              controller: c,
              onEditSection: _editSection,
              onUploadLogo: c.hasCompany ? _changeLogo : null,
              logoBusy: _logoBusy,
              verificationCard: c.hasCompany && c.dossierLoaded
                  ? KeyedSubtree(
                      key: _verificationKey,
                      child: CompanyVerificationCard(
                        controller: c,
                        onOpenField: _openField,
                        onFile: _fileCheck,
                        onSupport: () => _openSitePage('/support'),
                      ),
                    )
                  : null,
              missingStrip: (c.profile?.companyCompleteness?.missing ?? const []).isEmpty
                  ? null
                  : MissingDetailsStrip(
                      missing: c.profile!.companyCompleteness!.missing,
                      onJumpVerification: () => _jump(CompanyJump.verification),
                      onOpenSitePage: _openSitePage,
                    ),
            ),
            _Tab.certifications => CertificationsTab(
              controller: c,
              onEditCompany: () => _jump(CompanyJump.details),
              onStartSelling: _startSelling,
              pickDocument: widget.pickDocument ?? pickEvidenceFromDevice,
              certificationsKey: _certificationsKey,
            ),
          },
        ],
      ),
    );
  }
}
