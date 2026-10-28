import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart' show showMessage;
import '../../core/util/time_ago.dart';
import 'rfq_links.dart';
import 'rfq_models.dart';
import 'rfq_navigation.dart';
import 'rfq_repository.dart';
import 'rfq_scope.dart';
import 'rfq_styles.dart';
import 'supplier_controllers.dart';
import 'widgets/rfq_widgets.dart';

/// "Alerts" on the Marketplace's chips: what ICR told the member about their
/// requirements and bids (a match, an invitation, a bid in, an outcome), newest
/// first, with unread ones marked. A tap reads the alert and opens the
/// requirement it is about, on the owner's page or the supplier's.
class RfqAlertsScreen extends StatefulWidget {
  const RfqAlertsScreen({
    super.key,
    this.repository,
    this.links,
    this.onBack,
    this.onBell,
    this.onOpenConversation,
    this.onOpenSupplier,
  });

  final RfqRepository? repository;
  final RfqLinks? links;

  /// The arrow at the top left; by default it pops the route.
  final VoidCallback? onBack;

  /// The bell; by default it reads the alerts again.
  final VoidCallback? onBell;
  final ValueChanged<String>? onOpenConversation;
  final ValueChanged<String>? onOpenSupplier;

  @override
  State<RfqAlertsScreen> createState() => _RfqAlertsScreenState();
}

class _RfqAlertsScreenState extends State<RfqAlertsScreen> {
  late final RfqHooks _hooks;
  late final RfqAlertsController _alerts;

  @override
  void initState() {
    super.initState();
    _hooks = rfqHooksFor(
      context,
      repository: widget.repository,
      links: widget.links,
      onOpenConversation: widget.onOpenConversation,
      onOpenSupplier: widget.onOpenSupplier,
    );
    _alerts = RfqAlertsController(_hooks.repository)..start();
  }

  @override
  void dispose() {
    _alerts.dispose();
    super.dispose();
  }

  Future<void> _say(Future<String?> action) async {
    final message = await action;
    if (message != null && mounted) showMessage(context, message);
  }

  Future<void> _open(RfqAlert alert) async {
    unawaited(_say(_alerts.markRead(alert)));
    final id = alert.rfqId;
    if (id == null) return;
    if (alert.side == AlertSide.owner) {
      await pushRfqDetail(context, _hooks, id, section: alert.section, focusBid: alert.bidId);
    } else {
      await pushOpportunity(context, _hooks, id, section: alert.section);
    }
    if (mounted) await _alerts.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _alerts,
      builder: (context, _) => RfqScaffold(
        title: 'Alerts',
        onBack: widget.onBack ?? () => Navigator.maybePop(context),
        unread: _alerts.unread,
        onBell: widget.onBell ?? _alerts.refresh,
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _alerts.refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [SliverToBoxAdapter(child: _toolbar()), ..._body()],
          ),
        ),
      ),
    );
  }

  Widget _toolbar() {
    final a = _alerts;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          PillTabsRow(
            labels: const ['All', 'Unread'],
            selected: a.unreadOnly ? 1 : 0,
            counts: [null, a.newCount == 0 ? null : a.newCount],
            onSelect: (i) => a.setUnreadOnly(i == 1),
          ),
          const Spacer(),
          if (a.newCount > 0)
            TextButton(
              key: const ValueKey('alerts-read-all'),
              onPressed: () => _say(a.markAllRead()),
              child: Text('Mark all read', style: RfqText.link),
            ),
        ],
      ),
    );
  }

  List<Widget> _body() {
    final a = _alerts;
    Widget fill(Widget child) => SliverFillRemaining(hasScrollBody: false, child: child);
    if (a.loading && a.alerts.isEmpty) return [fill(const RfqSpinner())];
    if (a.error != null && a.alerts.isEmpty) {
      return [
        fill(
          RfqNotice(
            icon: LucideIcons.cloudOff,
            title: "Couldn't load your alerts",
            body: a.error,
            action: 'Try again',
            onAction: a.refresh,
          ),
        ),
      ];
    }
    if (a.alerts.isEmpty) {
      return [
        fill(
          RfqNotice(
            icon: LucideIcons.bellOff,
            title: a.unreadOnly ? 'No new alerts' : 'No alerts yet',
            body: a.unreadOnly
                ? 'You are all caught up. Matches, invitations and bids show here as they come in.'
                : 'When a requirement matches your services, a bid comes in or a decision is made, it shows here.',
            action: a.unreadOnly ? 'Show all alerts' : null,
            onAction: a.unreadOnly ? () => a.setUnreadOnly(false) : null,
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        sliver: SliverList.separated(
          itemCount: a.alerts.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final alert = a.alerts[i];
            return AlertTile(key: ValueKey('alert-${alert.id}'), alert: alert, onTap: () => _open(alert));
          },
        ),
      ),
    ];
  }
}

/// A short row of pills where one is on, with an optional count on each.
class PillTabsRow extends StatelessWidget {
  const PillTabsRow({super.key, required this.labels, required this.selected, required this.onSelect, this.counts});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  final List<int?>? counts;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, label) in labels.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          _Pill(
            label: counts?[i] == null ? label : '$label ${counts![i]}',
            on: i == selected,
            onTap: () => onSelect(i),
          ),
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = StadiumBorder(side: BorderSide(color: on ? AppColors.primary : AppColors.slate200));
    return Semantics(
      selected: on,
      button: true,
      child: Material(
        color: on ? AppColors.primary : Colors.white,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: Container(
            height: 30,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(label, style: RfqText.tab.copyWith(color: on ? Colors.white : AppColors.slate700)),
          ),
        ),
      ),
    );
  }
}

/// What an alert looks like by its type: a glyph and the tone behind it.
({IconData icon, Tone tone}) alertLook(String type) => switch (type) {
  'bid_received' => (icon: LucideIcons.inbox, tone: Tone.blue),
  'bid_awarded' => (icon: LucideIcons.trophy, tone: Tone.green),
  'bid_rejected' => (icon: LucideIcons.circleX, tone: Tone.slate),
  'rfq_invite' => (icon: LucideIcons.mailPlus, tone: Tone.blue),
  'rfq_match' || 'enquiry_match' => (icon: LucideIcons.sparkles, tone: Tone.amber),
  'enquiry_expired' => (icon: LucideIcons.clock, tone: Tone.slate),
  'prequal_submitted' => (icon: LucideIcons.clipboardCheck, tone: Tone.blue),
  'prequal_result' => (icon: LucideIcons.badgeCheck, tone: Tone.green),
  'shortlisted' => (icon: LucideIcons.star, tone: Tone.green),
  'rfq_quotes_open' => (icon: LucideIcons.fileText, tone: Tone.blue),
  _ => (icon: LucideIcons.bell, tone: Tone.slate),
};

/// One alert: its glyph, what it says, when and for which company, and a dot
/// while it is unread.
class AlertTile extends StatelessWidget {
  const AlertTile({super.key, required this.alert, required this.onTap, this.now});

  final RfqAlert alert;
  final VoidCallback onTap;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final look = alertLook(alert.type);
    final when = alert.createdAt == null ? null : timeAgo(alert.createdAt!, now: now ?? RfqClock.now());
    return RfqCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: look.tone.fill, shape: BoxShape.circle),
            child: Icon(look.icon, size: 18, color: look.tone.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: alert.unread ? RfqText.cardTitle : RfqText.cardTitle.copyWith(fontWeight: FontWeight.w500),
                ),
                if (alert.body != null) ...[
                  const SizedBox(height: 3),
                  Text(alert.body!, style: RfqText.body, maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 5),
                Text(
                  [?when, ?alert.companyName].join(' · '),
                  style: RfqText.small,
                ),
              ],
            ),
          ),
          if (alert.unread)
            Container(
              key: const ValueKey('alert-unread-dot'),
              margin: const EdgeInsets.only(left: 8, top: 4),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }
}
