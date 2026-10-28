import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import '../../core/widgets/title_bar.dart';
import '../learning_exam/open_paper.dart';
import 'assess_format.dart';
import 'assess_models.dart';
import 'assess_styles.dart';
import 'catalogue_controller.dart';
import 'assess_types.dart';
import 'group_controller.dart';
import 'widgets/assess_picture.dart';
import 'widgets/bundle_offer.dart';
import 'widgets/confirm_sheet.dart';
import 'widgets/open_plan_card.dart';
import 'widgets/paper_card.dart';
import 'widgets/states.dart';
import '../notifications/notifications_screen.dart';

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
  });

  final PaperGroup seed;
  final VoidCallback onBack;
  final PaperOpener opener;

  /// Hands a page of the website that the app may draw itself (the plans, the invitation page) to the app.
  final SiteLauncher launcher;

  /// Hands a payment page to the phone's browser: a "Pay on the website" button never opens the app's own screen
  /// for the same address (it would land back on this page), and the app cannot run the payment.
  final SiteLauncher payLauncher;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GroupController>(
      create: (c) {
        final catalogue = c.read<CatalogueController>();
        return GroupController(repository: catalogue.repository, catalogue: catalogue, seed: seed);
      },
      child: _GroupView(onBack: onBack, opener: opener, launcher: launcher, payLauncher: payLauncher),
    );
  }
}

class _GroupView extends StatefulWidget {
  const _GroupView({required this.onBack, required this.opener, required this.launcher, required this.payLauncher});

  final VoidCallback onBack;
  final PaperOpener opener;
  final SiteLauncher launcher;
  final SiteLauncher payLauncher;

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

  /// A payment: the website's page, in the phone's browser.
  Future<void> _pay(Uri uri) => widget.payLauncher(context, uri);

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

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GroupController>();
    final group = g.group;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.white),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                top: TitleBar.height,
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
                child: TitleBar(
                  onBack: widget.onBack,
                  middle: Text(group.title, style: AssessText.section, maxLines: 1, overflow: TextOverflow.ellipsis),
                  unread: g.catalogue.unread,
                  onBell: () => openNotifications(context),
                ),
              ),
              if (g.loading)
                const Positioned(
                  top: TitleBar.height,
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

    children.add(_Hero(group: group));

    final blurb = group.summary;
    if (blurb != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(blurb, style: AssessText.setBody),
        ),
      );
    }

    if (g.error != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: _RefreshFailed(message: g.error!, onRetry: g.refresh),
        ),
      );
    }

    if (!isMock && group.knowledgeAreas.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
          child: _KnowledgeAreas(
            areas: group.knowledgeAreas,
            showAll: _allAreas,
            onToggle: () => setState(() => _allAreas = !_allAreas),
          ),
        ),
      );
    }

    // The heading of the choice.
    children.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
        child: Text(isMock ? 'Exam sets' : 'Select your proficiency level', style: AssessText.section),
      ),
    );
    if (isMock) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
          child: Text(
            group.papers.isEmpty
                ? 'No sets are published under this subject yet.'
                : '${plural(group.papers.length, 'set')}, each with its own questions.',
            style: AssessText.sectionHint,
          ),
        ),
      );
    }

    if (g.showDiscount) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: _DiscountStrip(percent: g.pricing.discountPercent),
        ),
      );
    }

    if (access != null && state != null && group.papers.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: OpenPlanCard(
            kind: g.kind,
            access: access,
            state: state,
            opening: g.openingWithPlan,
            anyPriced: g.anyPriced,
            allPriced: g.allPriced,
            onOpen: _openWithPlan,
            onSeePlans: () => _site(repo.plansLink()),
            onEarnMore: () => _site(AppConfig.sitePage('/refer')),
          ),
        ),
      );
    }
    final redeemed = g.redeemedPapers;
    if (redeemed.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: RedeemedNote(group: group, papers: redeemed),
        ),
      );
    }

    // Every level or set still closed, together, cheaper: above the cards, where a member choosing one sees it.
    // A programme's offer is for a member whose plan has not opened the whole course; a mock exam's the website
    // draws only while the exam is closed to the plan (`locked`), not while a plan place could open it all.
    final bundle = g.bundle;
    final bundleSeen = access != null && state != null && (isMock ? state == PlaceState.locked : state != PlaceState.open);
    if (bundle != null && bundle.hasOffer && bundleSeen) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
          child: BundleOffer(
            quote: bundle,
            heldCredits: access.icrCredits,
            redeeming: g.redeemingBundle,
            onPay: () => _pay(repo.groupLink(group)),
            onRedeem: _redeemBundle,
            onEarnMore: () => _site(AppConfig.sitePage('/refer')),
          ),
        ),
      );
    }

    // The cards.
    final cards = isMock ? _setCards(g) : _levelCards(g);
    for (final card in cards) {
      children.add(Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 0), child: card));
    }
    return children;
  }

  PaperActions _actions(GroupController g, PaperEntry e) => PaperActions(
    onStart: () => _start(e.paper),
    onRedeem: () => _redeem(e),
    onOpenWithPlan: _openWithPlan,
    onBuy: () => _pay(g.repository.paperLink(g.group, e.paper)),
    onSeePlans: () => _site(g.repository.plansLink()),
  );

  /// The website's three rungs in its order (Foundation, Advanced, Professional), a rung with no paper greyed
  /// as "Coming soon", then any paper filed without a level.
  List<Widget> _levelCards(GroupController g) {
    final group = g.group;
    final held = g.member.access?.icrCredits;
    final out = <Widget>[];
    final used = <String>{};
    for (final level in assessCardOrder) {
      final paper = group.papers.where((p) => p.level == level).firstOrNull;
      if (paper == null) {
        out.add(ComingSoonLevelCard(level: level));
        continue;
      }
      used.add(paper.id);
      final entry = g.entry(paper);
      out.add(
        PaperCard(entry: entry, index: out.length, actions: _actions(g, entry), heldCredits: held, canPlan: true),
      );
    }
    for (final paper in group.papers) {
      if (used.contains(paper.id) || assessLadder.contains(paper.level)) continue;
      final entry = g.entry(paper);
      out.add(
        PaperCard(entry: entry, index: out.length, actions: _actions(g, entry), heldCredits: held, canPlan: true),
      );
    }
    return out;
  }

  List<Widget> _setCards(GroupController g) {
    final held = g.member.access?.icrCredits;
    // A mock exam's page offers no plan link when no plan on sale opens more of them.
    final canPlan = g.member.access?.mockUpgradePlan != null || g.member.access == null;
    return [
      for (final (i, paper) in g.group.sets.indexed)
        PaperCard(
          entry: g.entry(paper),
          index: i,
          actions: _actions(g, g.entry(paper)),
          heldCredits: held,
          canPlan: canPlan,
        ),
    ];
  }
}

/// The cover with the name over its foot.
class _Hero extends StatelessWidget {
  const _Hero({required this.group});

  final PaperGroup group;

  @override
  Widget build(BuildContext context) {
    final isMock = group.kind == PaperKind.mock;
    final title = isMock || RegExp(r'assessment$', caseSensitive: false).hasMatch(group.title.trim())
        ? group.title
        : '${group.title} Assessment';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 16 / 8,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AssessPicture(
                picture: group.cover,
                child: Center(
                  child: Icon(isMock ? LucideIcons.timer : LucideIcons.award, color: Colors.white54, size: 44),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00081422), Color(0xB3081422)],
                    stops: [0.35, 1],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Text(
                  title,
                  key: const ValueKey('hero-title'),
                  style: AssessText.pageTitle.copyWith(color: Colors.white),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Knowledge areas covered": what the programme's papers test, as chips; folded after four.
class _KnowledgeAreas extends StatelessWidget {
  const _KnowledgeAreas({required this.areas, required this.showAll, required this.onToggle});

  static const folded = 4;

  final List<String> areas;
  final bool showAll;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final shown = showAll || areas.length <= folded ? areas : areas.take(folded).toList();
    return Container(
      key: const ValueKey('knowledge-areas'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AssessColors.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Knowledge areas covered', style: AssessText.section),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final area in shown)
                Container(
                  constraints: const BoxConstraints(minHeight: 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Text(area, style: AssessText.cardMeta.copyWith(color: AppColors.onSurface)),
                ),
            ],
          ),
          if (areas.length > folded) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: onToggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(showAll ? 'Show fewer' : 'Show all ${areas.length}', style: AssessText.noteLink),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The offer above the ladder: one bold strip, so the discount reads before the prices do.
class _DiscountStrip extends StatelessWidget {
  const _DiscountStrip({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('discount-strip'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(colors: [Color(0xFF0B5E3B), Color(0xFF0E8A55), Color(0xFF19A974)]),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AssessColors.gold, shape: BoxShape.circle),
            child: Text(
              '$percent%\nOFF',
              textAlign: TextAlign.center,
              style: AssessText.coverPill.copyWith(color: AssessColors.goldInk, fontSize: 14, height: 1.1),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$percent% off every assessment level',
                  style: AssessText.bundleTitle.copyWith(fontSize: 16, height: 1.25),
                ),
                const SizedBox(height: 2),
                Text('Applied automatically at checkout. No code needed.', style: AssessText.bundleBody),
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
