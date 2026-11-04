import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_error.dart';
import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import '../../core/widgets/section_heading.dart' show Hairline;
import '../learning_exam/certificate_view.dart' show showCertificateSheet;
import '../learning_exam/open_paper.dart';
import 'assess_format.dart';
import 'assess_models.dart';
import '../payments/checkout_start.dart';
import 'assess_styles.dart';
import 'catalogue_controller.dart';
import 'assess_types.dart';
import 'group_controller.dart';
import 'widgets/assess_bar.dart';
import 'widgets/bundle_offer.dart';
import 'widgets/confirm_sheet.dart';
import 'widgets/knowledge_areas.dart';
import 'widgets/open_plan_card.dart';
import 'widgets/paper_card.dart';
import 'widgets/states.dart';

/// A programme's levels (Assess Your Knowledge) or a subject's sets (Mock Exams): the cover and its name, what
/// the programme covers, what the member's plan opens, then one card per level or set, and the bundle offer.
///
/// It is pushed from the landing, which hands over the group it already read and its own controller (so what the
/// member opens here shows on the grid at once).
class GroupScreen extends StatelessWidget {
  const GroupScreen({
    super.key,
    required this.seed,
    required this.onBack,
    required this.opener,
    this.launcher = openUrl,
    this.payLauncher = openExternal,
    this.share = shareAssessLink,
  });

  final PaperGroup seed;
  final VoidCallback onBack;
  final PaperOpener opener;

  /// Hands a page of the website that the app may draw itself (the plans, the invitation page) to the app.
  final SiteLauncher launcher;

  /// Hands a payment page to the phone's browser: a "Pay on the website" button never opens the app's own screen
  /// for the same address (it would land back on this page), and the app cannot run the payment.
  final SiteLauncher payLauncher;

  /// Opens the phone's share sheet with the exam's or a set's page on the website.
  final ShareLink share;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GroupController>(
      create: (c) {
        final catalogue = c.read<CatalogueController>();
        return GroupController(repository: catalogue.repository, catalogue: catalogue, seed: seed);
      },
      child: _GroupView(onBack: onBack, opener: opener, launcher: launcher, payLauncher: payLauncher, share: share),
    );
  }
}

class _GroupView extends StatefulWidget {
  const _GroupView({
    required this.onBack,
    required this.opener,
    required this.launcher,
    required this.payLauncher,
    required this.share,
  });

  final VoidCallback onBack;
  final PaperOpener opener;
  final SiteLauncher launcher;
  final SiteLauncher payLauncher;
  final ShareLink share;

  @override
  State<_GroupView> createState() => _GroupViewState();
}

class _GroupViewState extends State<_GroupView> with WidgetsBindingObserver {
  bool _allAreas = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final group = context.read<GroupController>();
    if (!group.started) group.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back in front (the person paid on the website, or earned credits, and came back): what the member holds and
  /// the quotes are read again, so a level they bought shows open without a pull.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _group.refresh();
  }

  GroupController get _group => context.read<GroupController>();

  Future<void> _site(Uri uri) => widget.launcher(context, uri);

  /// Buys a level or set in the app (owner's call, 2 Nov 2026 — every payment used to hand the website's page to
  /// the phone's browser): the rail's checkout, then the gateway in the app's own payment view, then what the
  /// member holds read again, so what they paid for shows open without a pull.
  Future<void> _buy(PaperEntry entry) async {
    final g = _group;
    CheckoutStart start;
    try {
      start = await g.repository.checkout(entry.paper);
    } catch (e) {
      if (mounted) showMessage(context, ApiError.from(e).message);
      return;
    }
    if (!mounted) return;
    final outcome = await runCheckout(context, start, title: 'Pay for ${entry.paper.title}');
    if (!mounted) return;
    await g.refresh();
    if (mounted) showMessage(context, paymentMessage(outcome, what: '${g.group.title} – ${entry.paper.title}'));
  }

  /// Buys every closed level or set together, the same way.
  Future<void> _buyBundle() async {
    final g = _group;
    final quote = g.bundle;
    if (quote == null) return;
    CheckoutStart start;
    try {
      start = await g.repository.checkoutBundle(g.group.kind, g.group.key);
    } catch (e) {
      if (mounted) showMessage(context, ApiError.from(e).message);
      return;
    }
    if (!mounted) return;
    final outcome = await runCheckout(context, start, title: 'Pay for ${g.group.title}');
    if (!mounted) return;
    await g.refresh();
    if (mounted) {
      showMessage(context, paymentMessage(outcome, what: 'Every ${quote.mock ? 'set' : 'level'} of ${g.group.title}'));
    }
  }

  Future<void> _start(AssessPaper paper) async {
    final g = _group;
    final ref = PaperRef(
      slug: paper.slug,
      title: paperName(paper, g.group),
      id: paper.id,
      isMock: paper.kind == PaperKind.mock,
      courseCode: paper.kind == PaperKind.assessment ? g.group.key : null,
    );
    await widget.opener(context, ref);
    // The sitting changed the attempts and the best score: read them again.
    if (mounted) await g.afterSitting();
  }

  Future<void> _redeem(PaperEntry entry) async {
    final g = _group;
    final held = g.member.access?.icrCredits ?? 0;
    final credits = entry.credits;
    if (credits == null) return;
    final noun = entry.paper.kind == PaperKind.mock ? 'set' : 'level';
    final ok = await showConfirmSheet(
      context,
      title: '${creditsLabel(credits)} for “${g.group.title}” – ${entry.paper.title}?',
      body: 'This $noun opens for good. You will have ${creditsLabel((held - credits).clamp(0, held))} left.',
      confirmLabel: 'Redeem ${creditsShort(credits)}',
      color: AssessColors.rung(entry.paper.level).main,
    );
    if (!ok || !mounted) return;
    final message = await g.redeem(entry.paper);
    if (!mounted) return;
    showMessage(context, message ?? '${entry.paper.title} is open. ${creditsLabel(credits)} spent.');
  }

  /// Redeems every closed level or set together: asks first (what opens, what is left), then the API's word.
  Future<void> _redeemBundle() async {
    final g = _group;
    final quote = g.bundle;
    final credits = quote?.inCredits;
    if (quote == null || credits == null) return;
    final held = g.member.access?.icrCredits ?? 0;
    final noun = quote.mock ? 'set' : 'level';
    final count = quote.count;
    final ok = await showConfirmSheet(
      context,
      title: '${creditsLabel(credits)} for “${quote.programmeTitle.isEmpty ? g.group.title : quote.programmeTitle}”?',
      body:
          '${count == 1 ? 'This $noun opens' : 'All $count ${noun}s open'} for good. '
          'You will have ${creditsLabel((held - credits).clamp(0, held))} left.',
      confirmLabel: 'Redeem ${creditsShort(credits)}',
    );
    if (!ok || !mounted) return;
    final outcome = await g.redeemBundle();
    if (!mounted) return;
    showMessage(
      context,
      outcome.error ??
          (outcome.ok
              ? '${plural(outcome.opened, noun)} opened with ${creditsLabel(outcome.spent)}.'
              : 'Nothing was left to open.'),
    );
  }

  Future<void> _openWithPlan() async {
    final g = _group;
    final access = g.member.access;
    final places = access?.places(g.kind);
    final noun = g.kind == PaperKind.mock ? 'mock exam' : 'course';
    final what = g.kind == PaperKind.mock ? 'set' : 'level';
    final limit = places?.limit ?? 0;
    final after = ((places?.left ?? 1) - 1).clamp(0, 9999);
    final ok = await showConfirmSheet(
      context,
      title: 'Open “${g.group.title}” with your plan?',
      body:
          'It takes one of the ${plural(limit, noun, '${noun}s')} your plan includes, and every $what opens. '
          '${after == 0 ? 'None will be left.' : '$after will be left.'}',
      confirmLabel: 'Open it',
    );
    if (!ok || !mounted) return;
    final message = await g.openWithPlan();
    if (!mounted) return;
    showMessage(context, message ?? '${g.group.title} is open with your plan.');
  }

  /// The phone's share sheet with the exam's page on the website (the bar's glyph).
  void _shareGroup() {
    final g = _group;
    widget.share(g.group.title, g.repository.groupLink(g.group));
  }

  /// The phone's share sheet with one set's page on the website (the glyph beside Start Test).
  void _shareSet(AssessPaper paper) {
    final g = _group;
    widget.share(paperName(paper, g.group), g.repository.paperLink(g.group, paper));
  }

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GroupController>();
    final group = g.group;
    final isMock = g.kind == PaperKind.mock;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.white),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                top: AssessBar.height,
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: g.refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 32),
                    children: g.notFound ? [_notFound(g)] : _content(g),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AssessBar(
                  title: isMock ? 'Mock Exam' : 'Assess Your Knowledge',
                  onBack: widget.onBack,
                  onShare: isMock && !g.notFound ? _shareGroup : null,
                  shareLabel: 'Share ${group.title}',
                ),
              ),
              if (g.loading)
                const Positioned(
                  top: AssessBar.height,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: AppColors.primary,
                    backgroundColor: Colors.transparent,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notFound(GroupController g) {
    final isMock = g.kind == PaperKind.mock;
    return AssessNotice(
      title: isMock ? 'Subject not found' : 'Programme not found',
      body: 'Nothing is published at “${g.group.key}”.',
      action: isMock ? 'All subjects' : 'All programmes',
      onAction: widget.onBack,
    );
  }

  List<Widget> _content(GroupController g) {
    final group = g.group;
    final isMock = group.kind == PaperKind.mock;
    final access = g.member.access;
    final state = g.placeState;
    final repo = g.repository;
    final children = <Widget>[];
    // The blocks follow each other with a thin line between them, never a box around one (owner, 3 Nov 2026).
    void rule() => children.add(const Hairline(color: AppColors.cardRule));

    if (isMock) {
      children.add(_SetsHeader(group: group));
    } else {
      children.add(_ProgrammeHeader(group: group));
      if (group.knowledgeAreas.isNotEmpty) {
        // The topics are the programme's own; with none, the section is left out rather than invented.
        rule();
        children.add(const SizedBox(height: 16));
        children.add(
          KnowledgeAreas(
            areas: group.knowledgeAreas,
            blurb: group.summary ?? defaultAreasBlurb,
            showAll: _allAreas,
            onToggle: () => setState(() => _allAreas = !_allAreas),
          ),
        );
        children.add(const SizedBox(height: 4));
      } else if (group.summary != null) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(group.summary!, style: AssessText.sectionHint, maxLines: 3, overflow: TextOverflow.ellipsis),
          ),
        );
      }
    }
    rule();

    if (g.error != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: _RefreshFailed(message: g.error!, onRetry: g.refresh),
        ),
      );
    }

    children.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Text(isMock ? 'Sets' : 'Select Your Proficiency Level', style: AssessText.section),
      ),
    );

    if (g.showDiscount) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: _DiscountStrip(percent: g.pricing.discountPercent),
        ),
      );
    }

    // The member's credits once, above the rows, rather than under every Redeem button.
    final redeemable = group.papers.any((p) {
      final e = g.entry(p);
      return e.access == PaperAccess.closed && e.credits != null;
    });
    if (access != null && !access.allOpen && redeemable) {
      children.add(
        _CreditsLine(
          credits: access.icrCredits,
          rupeesPerCredit: access.rupeesPerCredit,
          onEarnMore: () => _site(AppConfig.sitePage('/refer')),
        ),
      );
    }

    // The levels or sets first (the owner's rule, 30 Oct 2026: they are what the page is for, and they stay in the
    // first view): one row each, a thin line between them. Each closed row carries its own way in — Redeem, Pay,
    // Open with my plan — so the bundle and the plan line below add the wider offers, not the only ones.
    final papers = isMock ? group.sets : group.levelCards;
    if (papers.isEmpty && !isMock) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Text('No levels are published under this programme yet.', style: AssessText.sectionHint),
        ),
      );
    } else {
      children.add(const SizedBox(height: 4));
      children.add(_paperRows(g, papers));
    }

    // Every level or set still closed, together, cheaper. A programme's offer is for a member whose plan has not
    // opened the whole course; a mock exam's the website draws only while the exam is closed to the plan
    // (`locked`), not while a plan place could open it all.
    final bundle = g.bundle;
    final bundleSeen =
        access != null && state != null && (isMock ? state == PlaceState.locked : state != PlaceState.open);
    if (bundle != null && bundle.hasOffer && bundleSeen) {
      rule();
      children.add(
        BundleOffer(
          quote: bundle,
          heldCredits: access.icrCredits,
          redeeming: g.redeemingBundle,
          onPay: _buyBundle,
          onRedeem: _redeemBundle,
        ),
      );
    }

    // What the member's plan does here, in a line. Nothing for staff and for a plan that opens every course or exam.
    if (access != null &&
        state != null &&
        group.papers.isNotEmpty &&
        !access.allOpen &&
        access.places(g.kind).limit != null) {
      rule();
      children.add(
        OpenPlanCard(
          kind: g.kind,
          access: access,
          state: state,
          opening: g.openingWithPlan,
          onOpen: _openWithPlan,
          onSeePlans: () => _site(repo.plansLink()),
        ),
      );
    }
    return children;
  }

  PaperActions _actions(GroupController g, PaperEntry e) => PaperActions(
    onStart: () => _start(e.paper),
    onRedeem: () => _redeem(e),
    onOpenWithPlan: _openWithPlan,
    onBuy: () => _buy(e),
    onSeePlans: () => _site(g.repository.plansLink()),
    // A set is shared on its own (its row carries the glyph); a level is shared with its programme.
    onShare: g.kind == PaperKind.mock ? () => _shareSet(e.paper) : null,
    // The certificate in the app, as My certificates draws it: pinch to read, Download PDF, Share, LinkedIn.
    onViewCertificate: e.certificate == null ? null : () => showCertificateSheet(context, e.certificate!),
  );

  /// The levels or sets as list rows, a thin line between them inset to the text (no card around any).
  Widget _paperRows(GroupController g, List<AssessPaper> papers) {
    final held = g.member.access?.icrCredits;
    // A mock exam's page offers no plan link when no plan on sale opens more of them.
    final canPlan = g.kind != PaperKind.mock || g.member.access?.mockUpgradePlan != null || g.member.access == null;
    return Column(
      key: const ValueKey('level-cards'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, paper) in papers.indexed) ...[
          if (i > 0) const Hairline(color: AppColors.cardRule, indent: 68),
          PaperCard(
            entry: g.entry(paper),
            index: i,
            actions: _actions(g, g.entry(paper)),
            heldCredits: held,
            canPlan: canPlan,
          ),
        ],
      ],
    );
  }
}

/// A programme's name — "Capital Planning Assessment" — and its levels in a line.
class _ProgrammeHeader extends StatelessWidget {
  const _ProgrammeHeader({required this.group});

  final PaperGroup group;

  @override
  Widget build(BuildContext context) {
    final title = RegExp(r'assessment$', caseSensitive: false).hasMatch(group.title.trim())
        ? group.title
        : '${group.title} Assessment';
    final names = [for (final p in group.levelCards) p.levelName ?? p.title];
    return _Header(
      title: title,
      line: names.isEmpty ? null : '${plural(names.length, 'level')}: ${names.join(', ')}',
    );
  }
}

/// A mock exam's name, and how many sets it has.
class _SetsHeader extends StatelessWidget {
  const _SetsHeader({required this.group});

  final PaperGroup group;

  @override
  Widget build(BuildContext context) {
    final sets = group.papers.length;
    // The sentence promises unlimited attempts only while no set limits them.
    final unlimited = group.papers.every((p) => p.attemptLimit == null);
    final line = sets == 0
        ? 'No sets are published under this subject yet.'
        : '${plural(sets, 'Set')} ${sets == 1 ? 'with' : 'each with'} its own questions'
              '${unlimited ? ' and unlimited attempts' : ''}';
    return _Header(title: group.title, line: line, summary: group.summary);
  }
}

/// The page's name and a line under it, the same on a programme's page and an exam's.
class _Header extends StatelessWidget {
  const _Header({required this.title, this.line, this.summary});

  final String title;
  final String? line;
  final String? summary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            key: const ValueKey('hero-title'),
            style: AssessText.examTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (line != null) ...[const SizedBox(height: 4), Text(line!, style: AssessText.sectionHint)],
          if (summary != null) ...[
            const SizedBox(height: 4),
            Text(summary!, style: AssessText.sectionHint, maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}

/// The member's ICR credits, once, over the rows: "You have 0 ICR credits · 1 credit = ₹100", and Earn more.
class _CreditsLine extends StatelessWidget {
  const _CreditsLine({required this.credits, required this.rupeesPerCredit, required this.onEarnMore});

  final int credits;
  final int rupeesPerCredit;
  final VoidCallback onEarnMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
      child: Row(
        children: [
          const Icon(LucideIcons.coins, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'You have ${creditsLabel(credits)} · 1 credit = ${rupees(rupeesPerCredit * 100)}',
              key: const ValueKey('credits-line'),
              style: AssessText.progressNote,
            ),
          ),
          TextButton(
            onPressed: onEarnMore,
            child: Text('Earn more', style: AssessText.noteLink),
          ),
        ],
      ),
    );
  }
}

/// The offer over the rows, in one line: the discount reads before the prices do.
class _DiscountStrip extends StatelessWidget {
  const _DiscountStrip({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('discount-strip'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AssessColors.successWash, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          const Icon(LucideIcons.badgePercent, size: 18, color: AppColors.successInk),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$percent% off every assessment level',
                  style: AssessText.progressTitle.copyWith(color: AppColors.successInk),
                ),
                Text('Applied automatically at checkout. No code needed.', style: AssessText.progressNote),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A refresh that failed while the grid's copy stays on show.
class _RefreshFailed extends StatelessWidget {
  const _RefreshFailed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('refresh-failed'),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.amber50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.amber100),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.circleAlert, size: 18, color: AppColors.amber800),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: AssessText.noticeBody.copyWith(color: AppColors.amber800)),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text('Try again', style: AssessText.noteLink),
          ),
        ],
      ),
    );
  }
}
