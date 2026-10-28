import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../rfq_format.dart';
import '../rfq_links.dart';
import '../rfq_models.dart';
import '../rfq_styles.dart';
import 'requirement_parts.dart';
import 'rfq_widgets.dart';
import '../rfq_rules.dart' show parseRupees;

/// One requirement on the supplier's board: what is wanted, who is buying
/// (verified or not), how well it fits, where, how much and by when.
class OpportunityCard extends StatelessWidget {
  const OpportunityCard({super.key, required this.rfq, required this.nameOf, required this.onOpen, this.now});

  final Requirement rfq;
  final CategoryNamer nameOf;
  final VoidCallback onOpen;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final clock = now ?? RfqClock.now();
    final deadline = deadlineOf(rfq, clock);
    final buyer = rfq.buyer;
    final places = rfq.places;
    final score = rfq.matchScore;
    final invited = rfq.inviteStatus == InviteStatus.invited;
    return RfqCard(
      onTap: onOpen,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kicker(rfq, serviceLabelOf(rfq, nameOf)),
                      style: RfqText.kicker,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(rfq.title, style: RfqText.cardTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (score != null) ...[const SizedBox(width: 10), MatchRing(score: score, size: 38)],
            ],
          ),
          if (buyer != null) ...[const SizedBox(height: 10), BuyerLine(buyer: buyer, size: 28)],
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 5,
            children: [
              if (places.isNotEmpty)
                _Fact(
                  icon: LucideIcons.mapPin,
                  text: places.length > 2 ? '${places.take(2).join(', ')} +${places.length - 2}' : places.join(', '),
                ),
              if (rfq.budget != null) _Fact(icon: LucideIcons.wallet, text: compactInr(rfq.budget!)),
              if (deadline != null)
                _Fact(
                  icon: LucideIcons.clock,
                  text: '${deadline.label} ${deadline.relative}',
                  color: switch (deadline.urgency) {
                    Urgency.urgent => AppColors.error,
                    Urgency.soon => AppColors.amber800,
                    _ => null,
                  },
                ),
              if (rfq.createdAt != null) _Fact(icon: LucideIcons.calendar, text: postedAgo(rfq.createdAt, clock)),
            ],
          ),
          if (rfq.hasBid || invited || rfq.visibility == RfqVisibility.targeted || rfq.inviteStatus == InviteStatus.declined) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (rfq.hasBid) const TonePill('Bid sent', tone: Tone.green, icon: LucideIcons.check),
                if (invited) const TonePill('Invited to quote', tone: Tone.blue, icon: LucideIcons.mailPlus),
                if (rfq.inviteStatus == InviteStatus.declined) const TonePill('You declined'),
                if (rfq.visibility == RfqVisibility.targeted && !invited) const TonePill('Invite only', icon: LucideIcons.lock),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: color ?? AppColors.slate500),
      const SizedBox(width: 4),
      Flexible(child: Text(text, style: RfqText.small.copyWith(color: color))),
    ],
  );
}

/// What the Filters sheet answers: nulls are "no limit".
class BoardFilterValues {
  const BoardFilterValues({this.city, this.minBudget, this.maxBudget});

  final String? city;
  final double? minBudget;
  final double? maxBudget;
}

/// The board's filters (city, budget range) in a sheet; answers the values to
/// apply, or null when dismissed.
Future<BoardFilterValues?> showBoardFilters(BuildContext context, BoardQuery current) {
  return showModalBottomSheet<BoardFilterValues>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (context) => _BoardFilters(current: current),
  );
}

class _BoardFilters extends StatefulWidget {
  const _BoardFilters({required this.current});

  final BoardQuery current;

  @override
  State<_BoardFilters> createState() => _BoardFiltersState();
}

class _BoardFiltersState extends State<_BoardFilters> {
  late final _city = TextEditingController(text: widget.current.city ?? '');
  late final _min = TextEditingController(text: _plain(widget.current.minBudget));
  late final _max = TextEditingController(text: _plain(widget.current.maxBudget));
  String? _minError;
  String? _maxError;

  static String _plain(double? v) => v == null ? '' : (v == v.roundToDouble() ? v.round().toString() : v.toString());

  @override
  void dispose() {
    _city.dispose();
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  /// A rupee amount typed in the box, null when blank; sets the box's error.
  double? _amount(String raw, void Function(String?) setError) {
    final n = parseRupees(raw);
    if (n == null) {
      setError(null);
      return null;
    }
    if (n.isNaN || n < 0) {
      setError('Enter an amount in rupees');
      return null;
    }
    setError(null);
    return n;
  }

  void _apply() {
    final min = _amount(_min.text, (e) => _minError = e);
    final max = _amount(_max.text, (e) => _maxError = e);
    if (min != null && max != null && max < min) _maxError = 'The most cannot be below the least';
    if (_minError != null || _maxError != null) {
      setState(() {});
      return;
    }
    Navigator.pop(
      context,
      BoardFilterValues(city: _city.text.trim().isEmpty ? null : _city.text.trim(), minBudget: min, maxBudget: max),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Filters', style: RfqText.sheetTitle),
            const SizedBox(height: 14),
            RfqField(
              fieldKey: const ValueKey('filter-city'),
              label: 'City',
              value: _city.text,
              hint: 'Pune, Mumbai...',
              onChanged: (v) => _city.text = v,
              optional: true,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: RfqField(
                    fieldKey: const ValueKey('filter-min'),
                    label: 'Budget from',
                    value: _min.text,
                    prefixText: '₹ ',
                    keyboardType: TextInputType.number,
                    error: _minError,
                    onChanged: (v) => _min.text = v,
                    optional: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RfqField(
                    fieldKey: const ValueKey('filter-max'),
                    label: 'to',
                    value: _max.text,
                    prefixText: '₹ ',
                    keyboardType: TextInputType.number,
                    error: _maxError,
                    onChanged: (v) => _max.text = v,
                    optional: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('filters-clear'),
                    onPressed: () => Navigator.pop(context, const BoardFilterValues()),
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('filters-apply'),
                    onPressed: _apply,
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    child: const Text('Show requirements'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
