import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/config.dart';
import '../../../core/theme/app_colors.dart';
import '../../account/profile/profile_kit.dart' show PillAction;
import '../../site/site_kit.dart';
import '../company_controller.dart';
import '../company_models.dart';
import '../company_words.dart';
import '../supplier_checklist.dart';
import 'company_kit.dart';

/// Where a jump from the overview lands: a tab of this page, or a page of the website the app opens itself.
enum CompanyJump { details, verification, certifications }

/// The company at a glance, as the website's overview: how complete and trusted its page is, what it is made of,
/// its plans and its public address. One column, each card the page's width.
class OverviewTab extends StatelessWidget {
  const OverviewTab({
    super.key,
    required this.controller,
    required this.onJump,
    required this.onOpenSitePage,
    this.onOpenTeam,
    this.onOpenCompanyPage,
    this.onStartSelling,
    this.onCopyLink,
  });

  final CompanyController controller;
  final ValueChanged<CompanyJump> onJump;

  /// A page of the website the app has its own screen for (`/manage/locations`, `/pricing/corporate`…).
  final ValueChanged<String> onOpenSitePage;
  final VoidCallback? onOpenTeam;
  final VoidCallback? onOpenCompanyPage;
  final VoidCallback? onStartSelling;
  final ValueChanged<String>? onCopyLink;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final company = c.company;
    final hasCompany = c.hasCompany;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CompletenessCard(
          completeness: hasCompany ? c.profile?.companyCompleteness : null,
          company: company?.name ?? '',
          onJump: onJump,
          onOpenSitePage: onOpenSitePage,
        ),
        if (hasCompany) ...[
          _TrustCard(controller: c, onJump: onJump, onStartSelling: onStartSelling),
          _GlancePanel(
            controller: c,
            onOpenTeam: onOpenTeam,
            onOpenSitePage: onOpenSitePage,
            onCertifications: () => onJump(CompanyJump.certifications),
          ),
          _PlanCard(controller: c, onOpenSitePage: onOpenSitePage),
          _PublicPageCard(company: company!, onOpen: onOpenCompanyPage, onCopy: onCopyLink),
        ],
      ],
    );
  }
}

/// How much of the company's page is filled in, and each missing item with the way to where it is filled.
class _CompletenessCard extends StatelessWidget {
  const _CompletenessCard({
    required this.completeness,
    required this.company,
    required this.onJump,
    required this.onOpenSitePage,
  });

  static const shown = 4;

  final Completeness? completeness;
  final String company;
  final ValueChanged<CompanyJump> onJump;
  final ValueChanged<String> onOpenSitePage;

  /// Where a missing item is completed (`resolveCompanyTask`): the map pin is the one item edited off this page.
  void _finish(String label) {
    final l = label.toLowerCase();
    if (l.contains('verif')) return onJump(CompanyJump.verification);
    if (l.contains('map') || l.contains('location')) return onOpenSitePage('/manage/locations');
    onJump(CompanyJump.details);
  }

  @override
  Widget build(BuildContext context) {
    final c = completeness;
    final score = c?.score ?? 0;
    final missing = c?.missing ?? const <String>[];
    final extra = missing.length - shown;
    return CompanySection(
      key: const ValueKey('completeness-card'),
      title: CompanyWords.completenessTitle,
      caption: CompanyWords.completenessCaption,
      icon: Symbols.fact_check,
      trailing: c == null
          ? null
          : Text(
              CompanyWords.percentComplete(score),
              key: const ValueKey('completeness-score'),
              style: CompanyText.score,
            ),
      children: [
        if (c != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 6,
                backgroundColor: AppColors.slate100,
                color: score >= 100 ? AppColors.success : AppColors.primary,
              ),
            ),
          ),
        if (c == null)
          CompanyRow(
            child: Row(
              children: [
                Expanded(child: Text(CompanyWords.completenessNoCompany, style: SiteText.secondary)),
                const SizedBox(width: 8),
                PillAction(label: CompanyWords.addDetails, filled: true, onPressed: () => onJump(CompanyJump.details)),
              ],
            ),
          )
        else if (missing.isEmpty)
          CompanyRow(
            child: Row(
              children: [
                const Icon(Symbols.task_alt, size: 20, color: AppColors.success),
                const SizedBox(width: 10),
                Expanded(child: Text(CompanyWords.completenessComplete, style: SiteText.secondary)),
              ],
            ),
          )
        else ...[
          for (final label in missing.take(shown))
            CompanyRow(
              key: ValueKey('completeness-item-$label'),
              padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
              child: Row(
                children: [
                  Expanded(child: Text(label, style: SiteText.body)),
                  const SizedBox(width: 8),
                  LinkButton(CompanyWords.add, onPressed: () => _finish(label)),
                ],
              ),
            ),
          if (extra > 0)
            CompanyRow(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Text(CompanyWords.more(extra), style: SiteText.meta),
            ),
        ],
        if (c != null)
          CompanyRow(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: LinkButton(
                CompanyWords.editCompanyProfile,
                key: const ValueKey('completeness-edit'),
                onPressed: () => onJump(CompanyJump.details),
              ),
            ),
          ),
      ],
    );
  }
}

/// What ICR has checked about the company, as the two separate answers they are: the company check, and the
/// supplier level a company that sells climbs above it.
class _TrustCard extends StatelessWidget {
  const _TrustCard({required this.controller, required this.onJump, this.onStartSelling});

  final CompanyController controller;
  final ValueChanged<CompanyJump> onJump;
  final VoidCallback? onStartSelling;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final name = c.company?.name ?? '';
    final gate = c.gate;
    final sells = c.sells;
    final access = c.access;
    final reverify = gate != null && gate.verified && gate.reverify != null && gate.reverify!.open
        ? gate.reverify
        : null;

    // The company check's label, sentence and button, by status (`CHECK` on the website).
    String? label;
    String sentence;
    String action;
    bool urgent;
    Color labelColor = SiteColors.ink;
    if (gate == null) {
      label = null;
      sentence = c.gateFailed ? CompanyWords.checkUnavailable : '';
      action = '';
      urgent = false;
    } else if (reverify != null) {
      label = 'Verified';
      sentence = CompanyWords.checkReverify(dayOf(reverify.dueAt));
      action = CompanyWords.actionRespond;
      urgent = true;
      labelColor = AppColors.emerald700;
    } else if (gate.verified) {
      label = 'Verified';
      sentence = CompanyWords.checkVerified;
      action = CompanyWords.actionView;
      urgent = false;
      labelColor = AppColors.emerald700;
    } else {
      switch (gate.status) {
        case 'SUBMITTED':
          label = 'Under Review';
          sentence = CompanyWords.checkInReview;
          action = CompanyWords.actionView;
          urgent = false;
        case 'DOCS_REQUESTED':
          label = 'More Information Needed';
          sentence = CompanyWords.checkDocsRequested;
          action = CompanyWords.actionRespond;
          urgent = true;
        case 'REJECTED':
          label = 'Not Approved';
          sentence = CompanyWords.checkRejected;
          action = CompanyWords.actionResubmit;
          urgent = true;
        case 'SUSPENDED':
          label = 'Verification Withdrawn';
          sentence = CompanyWords.checkSuspended;
          action = CompanyWords.actionResubmit;
          urgent = true;
        default:
          label = CompanyWords.notFiledLabel;
          sentence = CompanyWords.checkNotFiled(name);
          action = CompanyWords.actionVerify;
          urgent = true;
      }
      if (urgent) labelColor = AppColors.amber800;
    }
    // Someone who cannot file the check is only ever shown where it stands.
    if (!c.files && action.isNotEmpty) action = CompanyWords.actionView;

    final level = c.profile?.vendor?.verificationLevel ?? 'REGISTERED';
    final docsAsked = access?.docsRequested ?? false;
    final trust = access?.trustScore;

    return CompanySection(
      key: const ValueKey('trust-card'),
      title: CompanyWords.trustTitle,
      caption: CompanyWords.trustCaption,
      icon: Symbols.verified_user,
      children: [
        CompanyRow(
          key: const ValueKey('trust-company-check'),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(CompanyWords.companyVerification, style: SiteText.strong),
                    const SizedBox(height: 2),
                    if (gate == null && !c.gateFailed)
                      const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      Text.rich(
                        TextSpan(
                          style: SiteText.secondary,
                          children: [
                            if (label != null) ...[
                              TextSpan(
                                text: label,
                                style: SiteText.strong.copyWith(color: labelColor),
                              ),
                              const TextSpan(text: ' · '),
                            ],
                            TextSpan(text: sentence),
                          ],
                        ),
                        key: const ValueKey('trust-check-sentence'),
                      ),
                  ],
                ),
              ),
              if (action.isNotEmpty) ...[
                const SizedBox(width: 8),
                PillAction(
                  key: const ValueKey('trust-check-action'),
                  label: action,
                  filled: urgent && c.files,
                  onPressed: () => onJump(CompanyJump.verification),
                ),
              ],
            ],
          ),
        ),
        CompanyRow(
          key: const ValueKey('trust-supplier-level'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(CompanyWords.supplierTrustLevel, style: SiteText.strong),
                        const SizedBox(height: 2),
                        if (sells)
                          Text(
                            [
                              CompanyWords.levelOf(levelLabel(level), levelRank(level)),
                              if (trust != null) CompanyWords.trustScore(trust.round()),
                            ].join(' · '),
                            style: SiteText.secondary,
                          )
                        else
                          Text(CompanyWords.notSelling(name.isEmpty ? 'the company' : name), style: SiteText.secondary),
                        if (sells) ...[
                          const SizedBox(height: 2),
                          Text(CompanyWords.supplierLevelHint, style: SiteText.meta),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (sells)
                    PillAction(
                      key: const ValueKey('trust-raise-level'),
                      label: docsAsked ? CompanyWords.actionRespond : CompanyWords.upgradeTrustLevel,
                      filled: docsAsked,
                      onPressed: () => onJump(CompanyJump.certifications),
                    )
                  else if (c.canStartSelling && onStartSelling != null)
                    PillAction(
                      key: const ValueKey('trust-start-selling'),
                      label: CompanyWords.startSelling,
                      icon: Symbols.storefront,
                      onPressed: onStartSelling,
                    ),
                ],
              ),
              if (!sells && !c.canStartSelling) ...[
                const SizedBox(height: 6),
                Text(CompanyWords.askAdminToSell, style: SiteText.meta),
              ],
              if (sells) ...[
                const SizedBox(height: 12),
                LevelLadder(level: level),
                if (docsAsked) ...[
                  const SizedBox(height: 10),
                  Text(
                    access?.docsRequestMessage ?? CompanyWords.docsRequestedSupplier,
                    style: SiteText.body.copyWith(color: AppColors.amber800),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The figures: members, offices, open jobs, the catalogue, the certificates — each the way to its page.
class _GlancePanel extends StatelessWidget {
  const _GlancePanel({
    required this.controller,
    required this.onOpenSitePage,
    required this.onCertifications,
    this.onOpenTeam,
  });

  final CompanyController controller;
  final ValueChanged<String> onOpenSitePage;
  final VoidCallback onCertifications;
  final VoidCallback? onOpenTeam;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final certs = c.certifications;
    final certificateCount = certs == null
        ? null
        : c.runsWorkspace
        ? certs
              .where((x) => x.status == 'VERIFIED' && x.supersededAt == null && certificationHeld(x.expiresAt, c.now()))
              .length
        : certs.length;
    final figures = <(String, String, int?, VoidCallback?)>[
      (
        'members',
        CompanyWords.figureMembers,
        c.standing?.memberCount,
        onOpenTeam ??
            (c.runsWorkspace ? () => onOpenSitePage('/manage/team') : () => onOpenSitePage('/account/companies')),
      ),
      if (c.runsWorkspace)
        ('offices', CompanyWords.figureOffices, c.glance.offices, () => onOpenSitePage('/manage/locations')),
      if (c.hires) ('open-jobs', CompanyWords.figureOpenJobs, c.glance.openJobs, () => onOpenSitePage('/manage/jobs')),
      if (c.sells && c.runsWorkspace) ...[
        ('products', CompanyWords.figureProducts, c.glance.products, () => onOpenSitePage('/manage/products')),
        ('services', CompanyWords.figureServices, c.glance.services, () => onOpenSitePage('/manage/services')),
      ],
      ('certificates', CompanyWords.figureCertificates, certificateCount, onCertifications),
    ];
    return CompanySection(
      key: const ValueKey('glance-panel'),
      title: CompanyWords.overviewTitle,
      caption: CompanyWords.overviewCaption,
      icon: Symbols.apartment,
      children: [
        hairline,
        // Two figures a row, the same height, a hairline between them.
        for (var i = 0; i < figures.length; i += 2)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _Figure(figures[i], rule: i > 0)),
                if (i + 1 < figures.length)
                  Expanded(child: _Figure(figures[i + 1], rule: i > 0, left: true))
                else
                  const Spacer(),
              ],
            ),
          ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.figure, {required this.rule, this.left = false});

  final (String, String, int?, VoidCallback?) figure;
  final bool rule;
  final bool left;

  @override
  Widget build(BuildContext context) {
    final (id, label, value, onTap) = figure;
    return InkWell(
      key: ValueKey('figure-$id'),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: rule ? const BorderSide(color: SiteColors.hairline) : BorderSide.none,
            left: left ? const BorderSide(color: SiteColors.hairline) : BorderSide.none,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: CompanyText.label),
                  const SizedBox(height: 2),
                  Text(value == null ? '—' : '$value', style: CompanyText.figure),
                ],
              ),
            ),
            if (onTap != null) const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.slate400),
          ],
        ),
      ),
    );
  }
}

/// The company's membership: the hiring plan, and the supplier plan once it sells.
class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.controller, required this.onOpenSitePage});

  final CompanyController controller;
  final ValueChanged<String> onOpenSitePage;

  Widget _row(CompanyPlan? plan, String audienceLabel, String path, {required Key key}) {
    final ends = plan?.currentPeriodEnd;
    final free = plan == null || plan.free;
    return CompanyRow(
      key: key,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(audienceLabel, style: CompanyText.label),
                const SizedBox(height: 2),
                Text(plan?.planName ?? CompanyWords.freePlan, style: SiteText.strong),
                if (ends != null)
                  Text(
                    plan!.renews ? CompanyWords.renewsOn(dayOf(ends)) : CompanyWords.endsOn(dayOf(ends)),
                    style: SiteText.meta,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PillAction(
            label: free ? CompanyWords.seePlans : CompanyWords.managePlan,
            filled: free,
            onPressed: () => onOpenSitePage(path),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return CompanySection(
      key: const ValueKey('plan-card'),
      title: CompanyWords.membershipTitle,
      caption: CompanyWords.membershipCaption,
      icon: Symbols.workspace_premium,
      children: [
        if (c.role != 'VENDOR')
          _row(c.hiringPlan, CompanyWords.jobPortalPlan, '/pricing/corporate', key: const ValueKey('plan-company')),
        if (c.sells)
          _row(c.supplierPlan, CompanyWords.marketplacePlan, '/pricing/supplier', key: const ValueKey('plan-supplier')),
        CompanyRow(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: LinkButton(CompanyWords.plansAndReceipts, onPressed: () => onOpenSitePage('/membership')),
          ),
        ),
      ],
    );
  }
}

/// The company's public page — the one address its jobs, catalogue and reviews share — with a copyable link.
class _PublicPageCard extends StatelessWidget {
  const _PublicPageCard({required this.company, this.onOpen, this.onCopy});

  final CompanyDetails company;
  final VoidCallback? onOpen;
  final ValueChanged<String>? onCopy;

  @override
  Widget build(BuildContext context) {
    final path = '/companies/${company.id}';
    final url = AppConfig.sitePage(path).toString();
    return CompanySection(
      key: const ValueKey('public-page-card'),
      title: CompanyWords.publicPageTitle,
      caption: CompanyWords.publicPageCaption,
      icon: Symbols.public,
      children: [
        CompanyRow(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(CompanyWords.profileUrl, style: CompanyText.label),
              const SizedBox(height: 2),
              Text(url, key: const ValueKey('public-page-url'), style: SiteText.body),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PillAction(
                    key: const ValueKey('public-page-copy'),
                    label: CompanyWords.copyProfileLink,
                    icon: Symbols.content_copy,
                    onPressed: onCopy == null ? null : () => onCopy!(url),
                  ),
                  if (onOpen != null)
                    PillAction(
                      key: const ValueKey('public-page-open'),
                      label: CompanyWords.viewPublicProfile,
                      icon: Symbols.open_in_new,
                      onPressed: onOpen,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
