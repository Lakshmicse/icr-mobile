import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/util/time_ago.dart';
import '../rfq_format.dart';
import '../rfq_links.dart';
import '../rfq_models.dart';
import '../rfq_rules.dart' show statutoryCompliance;
import '../rfq_styles.dart';
import 'requirement_parts.dart' show FileThumb;
import 'rfq_widgets.dart';
import 'supplier_parts.dart' show RfqSmallButton, leadTimeLabel;
import 'supplier_picker.dart' show RatingLine;

/// The words of a bid's status on the owner's side ("Awarded" for an RFQ, "Selected" for an enquiry).
String ownerBidLabel(Bid b, {required bool enquiry}) => switch (b.status) {
  BidStatus.awarded => enquiry ? 'Selected' : 'Awarded',
  BidStatus.pending => 'New',
  BidStatus.shortlisted => 'Shortlisted',
  BidStatus.rejected => 'Declined',
};

/// One supplier's response, with what the owner can decide about it: message, shortlist (and take it back),
/// decline (and restore), award or select. The files are private uploads, opened through the session.
class BidResponseCard extends StatefulWidget {
  const BidResponseCard({
    super.key,
    required this.bid,
    required this.enquiry,
    required this.canAct,
    required this.best,
    required this.topRated,
    required this.focused,
    required this.busy,
    required this.messaging,
    required this.onMessage,
    required this.onShortlist,
    required this.onRestore,
    required this.onDecline,
    required this.onAward,
    required this.onOpenFile,
    this.onOpenSupplier,
    this.now,
  });

  final Bid bid;
  final bool enquiry;

  /// The requirement still takes decisions (live, or an enquiry closed on its date).
  final bool canAct;
  final bool best;
  final bool topRated;

  /// A notification opened the page on this bid: it is ringed.
  final bool focused;
  final bool busy;
  final bool messaging;
  final VoidCallback onMessage;
  final VoidCallback onShortlist;
  final VoidCallback onRestore;
  final VoidCallback onDecline;
  final VoidCallback onAward;
  final ValueChanged<RfqFile> onOpenFile;
  final VoidCallback? onOpenSupplier;
  final DateTime? now;

  @override
  State<BidResponseCard> createState() => _BidResponseCardState();
}

class _BidResponseCardState extends State<BidResponseCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.bid;
    final enquiry = widget.enquiry;
    final rejected = b.status == BidStatus.rejected;
    final awarded = b.status == BidStatus.awarded;
    final clock = widget.now ?? RfqClock.now();
    final message = b.message;
    final long = message != null && (message.length > 200 || '\n'.allMatches(message).length > 3);
    final id = b.id;
    return Opacity(
      opacity: rejected ? 0.7 : 1,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: awarded ? AppColors.emerald50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.focused ? AppColors.primary : (awarded ? AppColors.emerald200 : AppColors.slate200),
            width: widget.focused ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LogoTile(name: b.supplier.name, logoUrl: b.supplier.logoUrl, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: widget.onOpenSupplier,
                        child: Text(
                          b.supplier.name,
                          key: ValueKey('bid-name-$id'),
                          style: RfqText.cardTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 2),
                      RatingLine(rating: b.supplier.rating, count: b.supplier.ratingCount),
                      if (b.createdAt != null) Text('Sent ${timeAgo(b.createdAt!, now: clock)}', style: RfqText.small),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TonePill(ownerBidLabel(b, enquiry: enquiry), tone: bidTone(b.status)),
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
                      Text(
                        b.amount == null ? 'No price given' : formatInr(b.amount!),
                        key: ValueKey('bid-price-$id'),
                        style: b.amount == null ? RfqText.meta : RfqText.amount,
                      ),
                      Text(
                        [
                          if (enquiry && b.amount != null) 'Indicative',
                          if (b.leadTimeDays != null) '${leadTimeLabel(b.leadTimeDays!)} lead time',
                        ].join(' · '),
                        style: RfqText.small,
                      ),
                    ],
                  ),
                ),
                if (widget.best) const TonePill('Best price', tone: Tone.green),
                if (widget.best && widget.topRated) const SizedBox(width: 6),
                if (widget.topRated) const TonePill('Top rated', tone: Tone.blue),
              ],
            ),
            if (message != null) ...[
              const SizedBox(height: 10),
              Text(
                message,
                key: ValueKey('bid-message-text-$id'),
                maxLines: long && !_expanded ? 4 : null,
                overflow: long && !_expanded ? TextOverflow.ellipsis : null,
                style: RfqText.body,
              ),
              if (long)
                GestureDetector(
                  key: ValueKey('bid-more-$id'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_expanded ? 'Show less' : 'Show more', style: RfqText.link),
                  ),
                ),
            ],
            if (b.files.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in b.files)
                    InkWell(
                      key: ValueKey('bid-file-${f.id}'),
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => widget.onOpenFile(f),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 230),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.slate200),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FileThumb(file: f, size: 30),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(f.title, style: RfqText.metaStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                RfqSmallButton(
                  key: ValueKey('bid-message-$id'),
                  label: 'Message',
                  icon: LucideIcons.messageSquare,
                  onTap: widget.onMessage,
                  busy: widget.messaging,
                ),
                if (widget.canAct && !awarded && !rejected) ...[
                  if (b.status == BidStatus.shortlisted)
                    RfqSmallButton(
                      key: ValueKey('bid-unshortlist-$id'),
                      label: 'Remove shortlist',
                      icon: LucideIcons.starOff,
                      onTap: widget.busy ? null : widget.onRestore,
                    )
                  else
                    RfqSmallButton(
                      key: ValueKey('bid-shortlist-$id'),
                      label: 'Shortlist',
                      icon: LucideIcons.star,
                      onTap: widget.busy ? null : widget.onShortlist,
                    ),
                  RfqSmallButton(
                    key: ValueKey('bid-decline-$id'),
                    label: 'Decline',
                    icon: LucideIcons.ban,
                    danger: true,
                    onTap: widget.busy ? null : widget.onDecline,
                  ),
                  RfqSmallButton(
                    key: ValueKey('bid-award-$id'),
                    label: enquiry ? 'Select' : 'Award',
                    icon: LucideIcons.trophy,
                    filled: true,
                    onTap: widget.busy ? null : widget.onAward,
                  ),
                ],
                if (widget.canAct && rejected)
                  RfqSmallButton(
                    key: ValueKey('bid-restore-$id'),
                    label: 'Restore',
                    icon: LucideIcons.undo2,
                    onTap: widget.busy ? null : widget.onRestore,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Compare ----------------------------------------------------------------------------------------

/// The live bids side by side: price (and how far above the lowest), lead time, rating and status, with the best
/// of each marked. A column's name opens that bid.
Future<void> showCompareSheet(
  BuildContext context, {
  required List<Bid> bids,
  required bool enquiry,
  required ValueChanged<Bid> onOpenBid,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (context) => _CompareSheet(bids: bids, enquiry: enquiry, onOpenBid: onOpenBid),
  );
}

class _CompareSheet extends StatelessWidget {
  const _CompareSheet({required this.bids, required this.enquiry, required this.onOpenBid});

  final List<Bid> bids;
  final bool enquiry;
  final ValueChanged<Bid> onOpenBid;

  @override
  Widget build(BuildContext context) {
    final priced = [for (final b in bids) if (b.amount != null) b.amount!];
    final lowest = priced.isEmpty ? null : priced.reduce((a, b) => a < b ? a : b);
    final leads = [for (final b in bids) if (b.leadTimeDays != null) b.leadTimeDays!];
    final fastest = leads.isEmpty ? null : leads.reduce((a, b) => a < b ? a : b);
    final topRating = bids.map((b) => b.supplier.rating).fold<double>(0, (a, b) => a > b ? a : b);
    const labelWidth = 92.0;
    const columnWidth = 132.0;

    TableRow row(String label, Widget Function(Bid) cell) => TableRow(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.slate100))),
      children: [
        Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(label, style: RfqText.meta)),
        for (final b in bids) Padding(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6), child: cell(b)),
      ],
    );

    Text good(String text, bool on) =>
        Text(text, style: (on ? RfqText.metaStrong.copyWith(color: AppColors.emerald700) : RfqText.metaStrong));

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(enquiry ? 'Compare the replies' : 'Compare the quotes', style: RfqText.sheetTitle),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text('The best in each row is green. Tap a name to open that bid.', style: RfqText.formHelp),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  key: const ValueKey('compare-scroll'),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Table(
                    key: const ValueKey('compare-table'),
                    defaultVerticalAlignment: TableCellVerticalAlignment.top,
                    columnWidths: {
                      0: const FixedColumnWidth(labelWidth),
                      for (var i = 1; i <= bids.length; i++) i: const FixedColumnWidth(columnWidth),
                    },
                    children: [
                      TableRow(
                        children: [
                          const SizedBox(),
                          for (final b in bids)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
                              child: InkWell(
                                key: ValueKey('compare-open-${b.id}'),
                                onTap: () {
                                  Navigator.pop(context);
                                  onOpenBid(b);
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    LogoTile(name: b.supplier.name, logoUrl: b.supplier.logoUrl, size: 30),
                                    const SizedBox(height: 4),
                                    Text(
                                      b.supplier.name,
                                      style: RfqText.metaStrong.copyWith(color: AppColors.primary),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      row(
                        enquiry ? 'Indicative price' : 'Price',
                        (b) => b.amount == null
                            ? Text('Not given', style: RfqText.small)
                            : good(formatInr(b.amount!), lowest != null && priced.length > 1 && b.amount == lowest),
                      ),
                      if (lowest != null && priced.length > 1)
                        row('Against the lowest', (b) {
                          if (b.amount == null) return Text('-', style: RfqText.small);
                          final over = lowest == 0 ? 0 : ((b.amount! - lowest) / lowest * 100);
                          return Text(
                            over <= 0 ? 'Lowest' : '+${over.toStringAsFixed(over < 10 ? 1 : 0)}%',
                            style: RfqText.meta,
                          );
                        }),
                      row(
                        'Lead time',
                        (b) => b.leadTimeDays == null
                            ? Text('Not given', style: RfqText.small)
                            : good(leadTimeLabel(b.leadTimeDays!), fastest != null && leads.length > 1 && b.leadTimeDays == fastest),
                      ),
                      row(
                        'Rating',
                        (b) => b.supplier.rating <= 0
                            ? Text('None yet', style: RfqText.small)
                            : good(
                                '${b.supplier.rating.toStringAsFixed(1)} (${b.supplier.ratingCount})',
                                bids.length > 1 && b.supplier.rating == topRating,
                              ),
                      ),
                      row('Status', (b) => TonePill(ownerBidLabel(b, enquiry: enquiry), tone: bidTone(b.status))),
                      row('Files', (b) => Text(b.files.isEmpty ? 'None' : '${b.files.length}', style: RfqText.meta)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ---- Pre-qualification ------------------------------------------------------------------------------

/// One supplier's pre-qualification answers on a staged RFQ, against the criteria, with the owner's decisions.
class PreQualCard extends StatelessWidget {
  const PreQualCard({
    super.key,
    required this.response,
    required this.busy,
    required this.canAct,
    required this.canShortlist,
    required this.messaging,
    required this.onMessage,
    required this.onQualify,
    required this.onReject,
    required this.onShortlist,
    this.now,
  });

  final PreQualResponse response;
  final bool busy;

  /// The requirement is live: decisions may be taken.
  final bool canAct;

  /// The RFQ is at the shortlisting stage: only then may a qualified supplier be shortlisted.
  final bool canShortlist;
  final bool messaging;
  final VoidCallback onMessage;
  final VoidCallback onQualify;
  final VoidCallback onReject;
  final VoidCallback onShortlist;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final r = response;
    final id = r.supplier.vendorId;
    final fact = <(String, String)>[
      ('Years in business', r.yearsInBusiness?.toString() ?? '-'),
      ('Annual turnover', r.annualTurnover == null ? '-' : compactInr(r.annualTurnover!)),
      if (r.last3YrTurnover != null) ('Last 3 years', compactInr(r.last3YrTurnover!)),
      ('Employees', r.employeeCount ?? '-'),
      ('Presence', r.presence?.label ?? '-'),
    ];
    final statusTone = switch (r.status) {
      PreQualStatus.qualified => Tone.green,
      PreQualStatus.rejected => Tone.slate,
      PreQualStatus.pending => Tone.amber,
    };
    return RfqCard(
      key: ValueKey('prequal-$id'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LogoTile(name: r.supplier.name, logoUrl: r.supplier.logoUrl, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.supplier.name, style: RfqText.cardTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                    RatingLine(rating: r.supplier.rating, count: r.supplier.ratingCount),
                    if (r.submittedAt != null)
                      Text('Sent ${timeAgo(r.submittedAt!, now: now ?? RfqClock.now())}', style: RfqText.small),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TonePill(r.status.label, tone: statusTone),
                  if (r.shortlisted) ...[const SizedBox(height: 4), const TonePill('Shortlisted', tone: Tone.blue)],
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              for (final (label, value) in fact)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [Text(label, style: RfqText.small), Text(value, style: RfqText.metaStrong)],
                ),
            ],
          ),
          if (r.statutoryCompliance.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final c in r.statutoryCompliance) TonePill(statutoryCompliance[c] ?? prettyKey(c))],
            ),
          ],
          const SizedBox(height: 10),
          if (r.meetsCriteria)
            Row(
              key: ValueKey('prequal-verdict-$id'),
              children: [
                const Icon(LucideIcons.circleCheck, size: 15, color: AppColors.emerald700),
                const SizedBox(width: 6),
                Text('Meets all your criteria', style: RfqText.metaStrong.copyWith(color: AppColors.emerald700)),
              ],
            )
          else
            Row(
              key: ValueKey('prequal-verdict-$id'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(padding: EdgeInsets.only(top: 1), child: Icon(LucideIcons.triangleAlert, size: 15, color: AppColors.amber800)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    r.failures.isEmpty ? 'Does not meet your criteria' : '${r.failures.length} unmet: ${r.failures.join(', ')}',
                    style: RfqText.metaStrong.copyWith(color: AppColors.amber800),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              RfqSmallButton(
                key: ValueKey('prequal-message-$id'),
                label: 'Message',
                icon: LucideIcons.messageSquare,
                onTap: onMessage,
                busy: messaging,
              ),
              if (canAct && r.status != PreQualStatus.qualified)
                RfqSmallButton(
                  key: ValueKey('prequal-qualify-$id'),
                  label: 'Qualify',
                  icon: LucideIcons.circleCheck,
                  onTap: busy ? null : onQualify,
                ),
              if (canAct && r.status != PreQualStatus.rejected)
                RfqSmallButton(
                  key: ValueKey('prequal-reject-$id'),
                  label: 'Not qualified',
                  icon: LucideIcons.ban,
                  danger: true,
                  onTap: busy ? null : onReject,
                ),
              if (canAct && r.status == PreQualStatus.qualified && !r.shortlisted)
                RfqSmallButton(
                  key: ValueKey('prequal-shortlist-$id'),
                  label: 'Shortlist',
                  icon: LucideIcons.star,
                  filled: true,
                  onTap: busy || !canShortlist ? null : onShortlist,
                ),
            ],
          ),
          if (canAct && r.status == PreQualStatus.qualified && !r.shortlisted && !canShortlist) ...[
            const SizedBox(height: 6),
            Text('Move the RFQ on to "Screening & shortlist" to shortlist qualified suppliers.', style: RfqText.small),
          ],
        ],
      ),
    );
  }
}

// ---- The tender's stages ---------------------------------------------------------------------------

/// The staged RFQ's five stages as a timeline, today's marked, with the owner's button to move it on.
class TenderStageCard extends StatelessWidget {
  const TenderStageCard({super.key, required this.rfq, required this.busy, this.onAdvance, this.owner = true});

  final Requirement rfq;
  final bool busy;

  /// The owner's reading of it (with the button and the closing words); a supplier's is the timeline alone.
  final bool owner;

  /// Moves the RFQ to its next stage; null when it has none or is not live.
  final VoidCallback? onAdvance;

  @override
  Widget build(BuildContext context) {
    final current = rfq.status == RfqStatus.awarded ? RfqStage.completed : (rfq.stage ?? RfqStage.prequalification);
    final index = RfqStage.values.indexOf(current);
    String? dateFor(RfqStage s) {
      if (s == RfqStage.prequalification && rfq.preQualEndDate != null) return 'Until ${shortDay(rfq.preQualEndDate!)}';
      if (s == RfqStage.quotation && rfq.dueDate != null) return 'By ${shortDay(rfq.dueDate!)}';
      return null;
    }

    return RfqCard(
      key: const ValueKey('stage-card'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tender stage', style: RfqText.section),
          const SizedBox(height: 10),
          for (final (i, s) in RfqStage.values.indexed)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 24,
                    child: Column(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i < index ? AppColors.emerald700 : (i == index ? AppColors.primary : AppColors.slate100),
                          ),
                          child: i < index
                              ? const Icon(LucideIcons.check, size: 13, color: Colors.white)
                              : Text('${i + 1}', style: RfqText.step.copyWith(color: i == index ? Colors.white : AppColors.slate500)),
                        ),
                        if (i < RfqStage.values.length - 1)
                          Expanded(child: Container(width: 1.5, color: i < index ? AppColors.emerald700 : AppColors.slate200)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              text: s.label,
                              style: RfqText.metaStrong.copyWith(
                                fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                                color: i > index ? AppColors.slate500 : AppColors.slate900,
                              ),
                              children: [
                                if (i == index) TextSpan(text: '  Now', style: RfqText.small.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          if (dateFor(s) != null) Text(dateFor(s)!, style: RfqText.small),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (!owner)
            const SizedBox.shrink()
          else if (rfq.live && rfq.stage?.nextAction != null)
            RfqSmallButton(
              key: const ValueKey('stage-advance'),
              label: busy ? 'Updating…' : rfq.stage!.nextAction!,
              filled: true,
              icon: LucideIcons.arrowRight,
              onTap: busy ? null : onAdvance,
            )
          else if (rfq.live && rfq.stage == RfqStage.evaluation)
            Text('Review the quotes and award one.', style: RfqText.small)
          else if (rfq.stage == RfqStage.completed || rfq.status == RfqStatus.awarded)
            Text('Tender complete.', style: RfqText.small),
        ],
      ),
    );
  }
}

// ---- Invitations and messages ---------------------------------------------------------------------

/// A supplier asked to quote, with what they did about it and a button to message them.
class InvitedRow extends StatelessWidget {
  const InvitedRow({super.key, required this.invite, required this.onMessage, required this.messaging});

  final SupplierInvite invite;
  final VoidCallback onMessage;
  final bool messaging;

  @override
  Widget build(BuildContext context) {
    final s = invite.supplier;
    final tone = switch (invite.status) {
      InviteStatus.invited => Tone.blue,
      InviteStatus.responded => Tone.green,
      InviteStatus.declined => Tone.slate,
    };
    return Padding(
      key: ValueKey('invited-${s.vendorId}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          LogoTile(name: s.name, logoUrl: s.logoUrl, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name, style: RfqText.metaStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                RatingLine(rating: s.rating, count: s.ratingCount),
              ],
            ),
          ),
          TonePill(invite.status.label, tone: tone),
          IconButton(
            key: ValueKey('invited-message-${s.vendorId}'),
            tooltip: 'Message ${s.name}',
            onPressed: messaging ? null : onMessage,
            icon: messaging
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(LucideIcons.messageSquare, size: 18, color: AppColors.slate600),
          ),
        ],
      ),
    );
  }
}

/// One supplier's thread about the requirement: the last thing said, when, and how much is unread.
class ThreadRow extends StatelessWidget {
  const ThreadRow({super.key, required this.thread, required this.onOpen, this.now});

  final SupplierThread thread;
  final VoidCallback onOpen;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final t = thread;
    final unread = t.unread > 0;
    return InkWell(
      key: ValueKey('thread-${t.conversationId}'),
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        color: unread ? AppColors.chipEmphasis.withValues(alpha: 0.35) : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LogoTile(name: t.companyName, size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.companyName,
                          style: RfqText.metaStrong.copyWith(fontWeight: unread ? FontWeight.w700 : FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (t.lastAt != null) Text(timeAgo(t.lastAt!, now: now ?? RfqClock.now()), style: RfqText.small),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.lastMessage ?? 'No messages yet',
                          style: unread ? RfqText.meta.copyWith(color: AppColors.slate900) : RfqText.small,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unread)
                        Container(
                          key: ValueKey('thread-unread-${t.conversationId}'),
                          margin: const EdgeInsets.only(left: 8),
                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(9)),
                          child: Text('${t.unread}', style: RfqText.step.copyWith(fontSize: 12)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
