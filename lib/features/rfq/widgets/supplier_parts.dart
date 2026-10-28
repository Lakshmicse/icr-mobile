import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/util/time_ago.dart';
import '../rfq_format.dart';
import '../rfq_links.dart';
import '../rfq_models.dart';
import '../rfq_styles.dart';
import '../supplier_controllers.dart';
import 'rfq_widgets.dart';

/// A small outlined (or filled) button for a card's actions.
class RfqSmallButton extends StatelessWidget {
  const RfqSmallButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.filled = false,
    this.danger = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool filled;
  final bool danger;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final ink = filled ? Colors.white : (danger ? AppColors.error : AppColors.primary);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: filled ? AppColors.primary : (danger ? AppColors.errorContainer : AppColors.slate200)),
    );
    return Material(
      color: filled ? AppColors.primary : Colors.white,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: ink))
              else if (icon != null)
                Icon(icon, size: 13, color: ink),
              if (busy || icon != null) const SizedBox(width: 6),
              Text(label, style: RfqText.tab.copyWith(fontSize: 12, color: ink)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Why a supplier screen cannot show its list yet: the account is not a
/// supplier's, or the company has no supplier listing (one tap starts it).
class SupplierGateView extends StatelessWidget {
  const SupplierGateView({super.key, required this.gate, required this.what, this.onStartSelling, this.note});

  final SupplierGate gate;

  /// What the screen is for, in a phrase: "bid on requirements".
  final String what;
  final VoidCallback? onStartSelling;

  /// Replaces the sentence under "Start selling" (a verified company is told it can quote right away).
  final String? note;

  @override
  Widget build(BuildContext context) {
    return switch (gate) {
      SupplierGate.role => RfqNotice(
        icon: LucideIcons.building2,
        title: 'This is for supplier accounts',
        body:
            'Your account is not a supplier\'s, so it cannot $what. A company that sells on ICR has supplier accounts; ask your company admin to add you as one.',
      ),
      SupplierGate.noListing => RfqNotice(
        icon: LucideIcons.store,
        title: 'Start selling to $what',
        body: note ?? 'Your company has no supplier listing yet. One tap creates it from your company profile.',
        action: 'Start selling',
        onAction: onStartSelling,
      ),
    };
  }
}

/// What a supplier's bid reads as on their own list.
String myBidStatusLabel(MyBid b) {
  final enquiry = b.requirement?.isEnquiry ?? false;
  if (b.isAwarded) return enquiry ? 'Selected' : 'Won';
  final ended = b.requirement?.status == RfqStatus.closed || b.requirement?.status == RfqStatus.cancelled;
  return switch (b.status) {
    BidStatus.pending => ended ? 'Closed' : (enquiry ? 'Replied' : 'Submitted'),
    BidStatus.shortlisted => 'Shortlisted',
    BidStatus.rejected => 'Not selected',
    BidStatus.awarded => enquiry ? 'Selected' : 'Won',
  };
}

Tone myBidTone(MyBid b) {
  if (b.isAwarded) return Tone.green;
  final ended = b.requirement?.status == RfqStatus.closed || b.requirement?.status == RfqStatus.cancelled;
  if (b.status == BidStatus.pending && ended) return Tone.slate;
  return bidTone(b.status);
}

/// "3 days" / "1 day".
String leadTimeLabel(int days) => days == 0 ? 'Same day' : plural(days, 'day');

/// One of the supplier's own bids on their list.
class MyBidCard extends StatelessWidget {
  const MyBidCard({
    super.key,
    required this.bid,
    required this.onOpen,
    required this.onMessage,
    this.busy = false,
    this.now,
  });

  final MyBid bid;
  final VoidCallback onOpen;
  final VoidCallback onMessage;

  /// The thread with the buyer is being opened.
  final bool busy;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final clock = now ?? RfqClock.now();
    final rfq = bid.requirement;
    final buyer = rfq?.buyer;
    final deadline = rfq == null ? null : deadlineOf(rfq, clock);
    final enquiry = rfq?.isEnquiry ?? false;
    final where = [?buyer?.displayName, ?rfq?.city].join(' · ');
    return RfqCard(
      onTap: onOpen,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LogoTile(name: buyer?.displayName ?? rfq?.title ?? '?', logoUrl: buyer?.logoUrl, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rfq?.title ?? 'Requirement', style: RfqText.cardTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (where.isNotEmpty) ...[const SizedBox(height: 2), Text(where, style: RfqText.small)],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TonePill(myBidStatusLabel(bid), tone: myBidTone(bid)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bid.amount == null ? 'No price given' : formatInr(bid.amount!), style: RfqText.amount),
                    Text(
                      [
                        if (bid.amount != null && enquiry) 'Indicative',
                        if (bid.leadTimeDays != null) '${leadTimeLabel(bid.leadTimeDays!)} lead time',
                      ].join(' · '),
                      style: RfqText.small,
                    ),
                  ],
                ),
              ),
              if (bid.createdAt != null) Text('Sent ${timeAgo(bid.createdAt!, now: clock)}', style: RfqText.small),
            ],
          ),
          if (bid.poNumber != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(LucideIcons.receipt, size: 13, color: AppColors.emerald700),
                const SizedBox(width: 6),
                Text('Purchase order ${bid.poNumber}', style: RfqText.metaStrong.copyWith(color: AppColors.emerald700)),
              ],
            ),
          ],
          if (deadline != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  LucideIcons.clock,
                  size: 12,
                  color: deadline.urgency == Urgency.urgent ? AppColors.error : AppColors.slate500,
                ),
                const SizedBox(width: 5),
                Text(
                  '${deadline.label} ${deadline.relative}',
                  style: RfqText.small.copyWith(
                    color: deadline.urgency == Urgency.urgent ? AppColors.error : null,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              RfqSmallButton(label: 'View requirement', icon: LucideIcons.fileText, onTap: onOpen),
              const SizedBox(width: 8),
              RfqSmallButton(label: 'Message buyer', icon: LucideIcons.messageSquare, onTap: onMessage, busy: busy),
            ],
          ),
        ],
      ),
    );
  }
}
