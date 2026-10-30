import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/section_heading.dart' show Hairline;
import '../../core/widgets/title_bar.dart';
import '../contact/contact_models.dart' show ContactTopic;
import '../contact/contact_screen.dart' show contactRoute;
import '../notifications/notifications_bell.dart';
import '../notifications/notifications_screen.dart';
import 'api_membership_repository.dart';
import 'demo_membership_repository.dart';
import 'membership_controller.dart';
import 'membership_format.dart';
import 'membership_models.dart';
import 'membership_repository.dart';
import 'membership_styles.dart';

/// The repository the screens use when not handed one: the API, or the sample content.
MembershipRepository defaultMembershipRepository(BuildContext context) =>
    AppConfig.demo ? DemoMembershipRepository() : ApiMembershipRepository(api: context.read<ApiClient>());

/// The website's plans pages (`/pricing/<audience>`, `/career/plans`, `/membership`)
/// as one screen: a chip per ladder, what the member holds on it, and the plans
/// to choose from, each card listing what the plan's own values give. Choosing a
/// plan starts the checkout; the API activates it on the spot where there is no
/// gateway (test mode, ₹0), and otherwise the payment continues on the website.
///
/// There is no design for this screen: it is drawn in the language of the
/// designed ones. [repository] and [controller] are for tests.
class MembershipScreen extends StatefulWidget {
  const MembershipScreen({
    super.key,
    this.audience = MembershipAudience.seeker,
    this.onBack,
    this.repository,
    this.controller,
  });

  final MembershipAudience audience;
  final VoidCallback? onBack;
  final MembershipRepository? repository;
  final MembershipController? controller;

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  late final MembershipController _c;
  late final bool _owns;

  @override
  void initState() {
    super.initState();
    _owns = widget.controller == null;
    _c =
        widget.controller ??
        MembershipController(widget.repository ?? defaultMembershipRepository(context), audience: widget.audience);
    if (!_c.started) _c.start();
    _c.addListener(_onChange);
  }

  @override
  void dispose() {
    _c.removeListener(_onChange);
    if (_owns) _c.dispose();
    super.dispose();
  }

  /// A checkout the gateway must finish: the website's plans page takes it (the
  /// app has no gateway leg), never the app's own screen for that page.
  void _onChange() {
    final gateway = _c.gateway;
    if (gateway == null || !mounted) return;
    _c.gatewayHandled();
    openUrl(context, AppConfig.sitePage('/pricing/${_c.audience.slug}'), inApp: false);
  }

  /// "Talk to us": the app's contact form, set to membership and naming the plan (the website's `talkToUsHref`).
  void _talkToUs(MembershipPlan plan) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (route) => contactRoute(
          route,
          subject: '${_c.audience.label} ${plan.name} plan',
          topic: ContactTopic.membership,
          onBell: () => openNotifications(route),
        ),
      ),
    );
  }

  void _history() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MembershipHistoryScreen(audience: _c.audience, repository: _c.repository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.white),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: ListenableBuilder(
            listenable: _c,
            builder: (context, _) => Column(
              children: [
                TitleBar(
                  title: 'Membership',
                  onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
                  unread: bellUnread(context),
                  onBell: () => openNotifications(context),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _c.refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 32),
                      children: _body(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context) {
    final mine = _c.mine;
    final canBuy = mine?.canBuy ?? true;
    return [
      _AudienceChips(tabs: _c.tabs, current: _c.audience, onPick: _c.setAudience),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_c.audience.tagline, style: MembershipText.tagline),
            const SizedBox(height: 4),
            Text('${_c.audience.description} Prices are per year, before GST.', style: MembershipText.lead),
          ],
        ),
      ),
      if (_c.message != null)
        _Notice(key: const ValueKey('membership-message'), text: _c.message!, onDismiss: _c.dismissMessage),
      if (mine != null && !canBuy && mine.reason != null)
        _Notice(key: const ValueKey('membership-eligibility'), text: mine.reason!),
      if (mine != null && canBuy)
        _YourPlanCard(mine: mine, busy: _c.busyPriceId != null, onRenew: _c.renew, onHistory: _history),
      if (_c.loading && _c.plans.isEmpty)
        for (var i = 0; i < 3; i++) const _PlanSkeleton()
      else if (_c.error != null && _c.plans.isEmpty)
        _Empty(title: "Couldn't load the plans", body: _c.error!, action: 'Try again', onAction: _c.refresh)
      else if (_c.plans.isEmpty)
        _Empty(
          title: 'No plans on sale yet',
          body: '${_c.audience.label} plans will appear here when ICR puts them on sale.',
        )
      else
        for (final plan in _c.plans)
          _PlanCard(
            key: ValueKey('plan-${plan.id}'),
            plan: plan,
            current: _c.isCurrent(plan),
            canBuy: canBuy,
            busy: _c.busyPriceId != null && _c.busyPriceId == plan.headlineTerm?.id,
            anyBusy: _c.busyPriceId != null,
            onChoose: () => _c.choose(plan),
            onTalkToUs: () => _talkToUs(plan),
          ),
    ];
  }
}

/// One chip for each ladder the member has (`MembershipController.tabs`), as the
/// website's `/membership` page draws its tabs: nothing for a ladder with no plan
/// on sale or that they cannot buy on.
class _AudienceChips extends StatelessWidget {
  const _AudienceChips({required this.tabs, required this.current, required this.onPick});

  final List<MembershipAudience> tabs;
  final MembershipAudience current;
  final ValueChanged<MembershipAudience> onPick;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          for (final a in tabs)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: IcrChip(
                key: ValueKey('audience-${a.slug}'),
                label: a.label,
                height: 32,
                tone: a == current ? ChipTone.primary : ChipTone.outlined,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: MembershipText.chip,
                onTap: () => onPick(a),
              ),
            ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({super.key, required this.text, this.onDismiss});

  final String text;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: MembershipColors.noticeFill,
        border: Border.all(color: MembershipColors.noticeBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(text, style: MembershipText.notice)),
          if (onDismiss != null)
            IconButton(
              tooltip: 'Dismiss',
              visualDensity: VisualDensity.compact,
              onPressed: onDismiss,
              icon: const Icon(LucideIcons.x, size: 16, color: AppColors.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

/// "Your plan" above the cards: what is held, when it ends, and renewing it at today's price.
class _YourPlanCard extends StatelessWidget {
  const _YourPlanCard({required this.mine, required this.busy, required this.onRenew, required this.onHistory});

  final MyPlan mine;
  final bool busy;
  final VoidCallback onRenew;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final sub = mine.subscription;
    final renewal = mine.renewal;
    final canRenew = sub != null && renewal != null && mine.nextTermPlanName == null && !mine.planRetired;
    return Container(
      key: const ValueKey('membership-your-plan'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MembershipColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('YOUR ${mine.audience.label.toUpperCase()} PLAN', style: MembershipText.yourPlanLabel),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: Text(sub?.planName ?? 'Free', style: MembershipText.yourPlanName)),
              if (sub != null && sub.cancelAtPeriodEnd && mine.nextTermPlanName == null)
                const IcrChip(label: 'Not renewing', height: 22, tone: ChipTone.filled),
            ],
          ),
          if (sub?.currentPeriodEnd != null)
            Text(
              // Nothing is charged automatically until auto-renew exists, so the date is when the plan ends unless renewed.
              '${sub!.autoRenew && !sub.cancelAtPeriodEnd ? 'Renews' : 'Ends'} ${dayLabel(sub.currentPeriodEnd!)}',
              style: MembershipText.yourPlanNote,
            ),
          if (mine.nextTermPlanName != null)
            Text('Your next term on ${mine.nextTermPlanName} is paid for.', style: MembershipText.yourPlanNote),
          if (mine.scheduledChangePlanName != null && mine.nextTermPlanName == null)
            Text(
              'Changes to ${mine.scheduledChangePlanName}${mine.scheduledChangeAt != null ? ' on ${dayLabel(mine.scheduledChangeAt!)}' : ' at renewal'}.',
              style: MembershipText.yourPlanNote,
            ),
          if (renewal != null && renewal.priceChanged)
            Text('The plan\'s price has changed since you bought it.', style: MembershipText.yourPlanWarning),
          if (sub != null && mine.planRetired)
            Text(
              '${sub.planName} is no longer sold: choose another plan below before this term ends.',
              style: MembershipText.yourPlanWarning,
            ),
          if (sub != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (canRenew)
                  Expanded(
                    child: PrimaryButton(
                      key: const ValueKey('membership-renew'),
                      label: busy ? 'Starting renewal…' : 'Renew for ${rupees(renewal.totalPaisa)}',
                      height: 40,
                      radius: 10,
                      onPressed: busy ? null : onRenew,
                    ),
                  ),
                if (canRenew) const SizedBox(width: 10),
                InkWell(
                  key: const ValueKey('membership-history'),
                  onTap: onHistory,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                    child: Text('Plan history & receipts', style: MembershipText.link),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    super.key,
    required this.plan,
    required this.current,
    required this.canBuy,
    required this.busy,
    required this.anyBusy,
    required this.onChoose,
    required this.onTalkToUs,
  });

  final MembershipPlan plan;
  final bool current;
  final bool canBuy;
  final bool busy;
  final bool anyBusy;
  final VoidCallback onChoose;
  final VoidCallback onTalkToUs;

  @override
  Widget build(BuildContext context) {
    final term = plan.headlineTerm;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: current ? MembershipColors.currentRing : MembershipColors.cardBorder,
          width: current ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(plan.name, style: MembershipText.planName, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (current)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                  child: Text('YOURS', style: MembershipText.current),
                ),
            ],
          ),
          const SizedBox(height: 6),
          _price(term),
          if (plan.description != null && plan.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(plan.description!, style: MembershipText.description),
          ],
          const SizedBox(height: 10),
          const Hairline(),
          const SizedBox(height: 8),
          for (final b in plan.features) _benefit(LucideIcons.circleCheck, MembershipColors.benefitTick, b.text),
          if (plan.terms.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('SERVICE TERMS', style: MembershipText.termsHeading),
            const SizedBox(height: 2),
            for (final b in plan.terms) _benefit(LucideIcons.handshake, MembershipColors.termGlyph, b.text),
          ],
          ..._button(term),
        ],
      ),
    );
  }

  Widget _price(PlanPrice? term) {
    if (term == null) return Text('Custom pricing', style: MembershipText.planName);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (plan.contactSales) ...[Text('From ', style: MembershipText.priceNote)],
            Text(rupees(term.pricePaisa), style: MembershipText.price),
            if (term.pricePaisa > 0) ...[
              const SizedBox(width: 4),
              Text('${term.suffix} + GST', style: MembershipText.priceNote),
            ],
            if (term.compareAtPaisa != null && term.compareAtPaisa! > term.pricePaisa) ...[
              const SizedBox(width: 6),
              Text(rupees(term.compareAtPaisa!), style: MembershipText.compareAt),
            ],
          ],
        ),
        if (term.validUntil != null && term.pricePaisa > 0)
          Text('Price valid till ${dayLabel(term.validUntil!)}', style: MembershipText.yourPlanWarning),
        if (plan.availableUntil != null)
          Text('Available until ${dayLabel(plan.availableUntil!)}', style: MembershipText.yourPlanWarning),
      ],
    );
  }

  Widget _benefit(IconData icon, Color color, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: MembershipText.benefit)),
      ],
    ),
  );

  List<Widget> _button(PlanPrice? term) {
    final key = ValueKey('plan-choose-${plan.id}');
    if (plan.contactSales) {
      return [
        const SizedBox(height: 12),
        PrimaryButton(
          key: key,
          label: current ? 'Current plan' : 'Talk to us',
          height: 42,
          radius: 10,
          color: current ? AppColors.surfaceContainer : AppColors.primary,
          textStyle: current ? MembershipText.chip : null,
          onPressed: current ? null : onTalkToUs,
        ),
      ];
    }
    if (!canBuy) return const [];
    final String label;
    VoidCallback? onPressed;
    if (current) {
      label = 'Current plan';
    } else if (plan.isFree) {
      label = 'Free';
    } else if (term == null) {
      label = 'Custom pricing';
    } else if (busy) {
      label = 'Starting checkout…';
    } else {
      label = 'Choose ${plan.name}';
      onPressed = anyBusy ? null : onChoose;
    }
    final quiet = current || plan.isFree || term == null;
    return [
      const SizedBox(height: 12),
      PrimaryButton(
        key: key,
        label: label,
        height: 42,
        radius: 10,
        color: quiet ? AppColors.surfaceContainer : AppColors.primary,
        textStyle: quiet ? MembershipText.chip : null,
        onPressed: onPressed,
      ),
    ];
  }
}

class _PlanSkeleton extends StatelessWidget {
  const _PlanSkeleton();

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('plan-skeleton'),
    height: 180,
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(12)),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.body, this.action, this.onAction});

  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
      child: Column(
        children: [
          const Icon(LucideIcons.badgeCheck, size: 36, color: AppColors.outline),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: MembershipText.planName),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: MembershipText.lead),
          if (action != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size(48, 48),
                side: const BorderSide(color: AppColors.outlineVariant),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(action!, style: MembershipText.link),
            ),
          ],
        ],
      ),
    );
  }
}

/// The member's terms on one ladder, newest first (`/membership/history`).
class MembershipHistoryScreen extends StatefulWidget {
  const MembershipHistoryScreen({super.key, required this.audience, this.repository, this.onBack});

  final MembershipAudience audience;
  final MembershipRepository? repository;
  final VoidCallback? onBack;

  @override
  State<MembershipHistoryScreen> createState() => _MembershipHistoryScreenState();
}

class _MembershipHistoryScreenState extends State<MembershipHistoryScreen> {
  late final MembershipRepository _repository;
  MembershipHistory? _history;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? defaultMembershipRepository(context);
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final history = await _repository.history(widget.audience);
      if (mounted) setState(() => _history = history);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TitleBar(
              title: 'Plan history',
              onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
              unread: bellUnread(context),
              onBell: () => openNotifications(context),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final history = _history;
    if (_error != null) {
      return _Empty(title: "Couldn't load the history", body: _error!, action: 'Try again', onAction: _load);
    }
    if (history == null) {
      return const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4)));
    }
    if (history.reason != null && history.terms.isEmpty) {
      return _Empty(title: 'No plan here', body: history.reason!);
    }
    if (history.terms.isEmpty) {
      return _Empty(
        title: 'No terms yet',
        body: 'Your ${widget.audience.label} plans will be listed here, with their receipts.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: history.terms.length,
      separatorBuilder: (_, _) => const Hairline(),
      itemBuilder: (_, i) => _TermRow(term: history.terms[i]),
    );
  }
}

class _TermRow extends StatelessWidget {
  const _TermRow({required this.term});

  final MembershipTerm term;

  @override
  Widget build(BuildContext context) {
    final dates = [
      if (term.startsAt != null) dayLabel(term.startsAt!),
      if (term.endsAt != null) dayLabel(term.endsAt!),
    ].join(' – ');
    final state = term.running ? 'Running' : termEndLabel(term.end) ?? term.status;
    final amount = term.complimentary
        ? 'Complimentary'
        : term.totalPaisa == 0
        ? 'Free'
        : rupees(term.totalPaisa);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(term.planName, style: MembershipText.termPlan),
                const SizedBox(height: 2),
                Text([state, if (dates.isNotEmpty) dates].join(' · '), style: MembershipText.termMeta),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(amount, style: MembershipText.termAmount),
        ],
      ),
    );
  }
}
