import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../council_format.dart';
import '../council_models.dart';
import '../councils_styles.dart';
import 'pills.dart';

/// A council in the directory: its cover with the glyph tile and the pills,
/// the name, the chair, two lines of copy, the hashtags, the members and
/// activity, then Join (or the member lounge) beside Preview.
class CouncilCard extends StatelessWidget {
  const CouncilCard({
    super.key,
    required this.council,
    required this.busy,
    required this.onJoin,
    required this.onLeave,
    required this.onOpen,
    required this.onPreview,
  });

  final Council council;
  final bool busy;
  final VoidCallback onJoin;
  final VoidCallback onLeave;
  final VoidCallback onOpen;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final c = council;
    final copy = c.description ?? c.focus;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outlineVariant, width: 0.75),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 3, offset: Offset(0, 1))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              CouncilCover(council: c),
              Positioned(
                left: 13,
                top: 11,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: CouncilsColors.coverTile, borderRadius: BorderRadius.circular(7)),
                  child: Center(child: IndustryGlyph(c.industry)),
                ),
              ),
              Positioned(right: 10, top: 13, child: _CoverPills(council: c)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name, style: CouncilsText.cardTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (c.chair != null) ...[
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Chair: '),
                        TextSpan(text: c.chair!.name, style: CouncilsText.chairName),
                        if (c.chair!.title != null) TextSpan(text: ', ${c.chair!.title}'),
                      ],
                    ),
                    style: CouncilsText.chair,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (copy != null) ...[
                  const SizedBox(height: 8.5),
                  Text(copy, style: CouncilsText.cardCopy, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                if (c.tags.isNotEmpty) ...[
                  const SizedBox(height: 11),
                  // The design wraps its hashtags inside about 243 dp, well
                  // short of the card's text width.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 243),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 3,
                      children: [
                        for (final tag in c.tags)
                          StatusPill(
                            label: tag,
                            fill: CouncilsColors.tagFill,
                            style: CouncilsText.tag,
                            height: 15,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                          ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: c.tags.isEmpty ? 14.7 : 15.7),
                _MetaRow(council: c),
                const SizedBox(height: 7.5),
              ],
            ),
          ),
          // The footer is a box of its own in the design: its top edge runs out into a small curve at both ends.
          CustomPaint(
            painter: const _FooterEdge(color: AppColors.outlineVariant),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10.5, 5, 19.25, 5),
              child: Row(
                children: [
                  c.joined
                      ? _LoungeButton(onTap: onOpen, onLongPress: onLeave)
                      : _JoinButton(busy: busy, onTap: onJoin),
                  const Spacer(),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onPreview,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text('Preview Chapter', style: CouncilsText.preview),
                    ),
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

/// The footer's top edge: a thin line whose ends turn down into the card's side edge in a 5 dp curve.
class _FooterEdge extends CustomPainter {
  const _FooterEdge({required this.color});

  final Color color;

  static const _radius = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, _radius)
      ..arcToPoint(const Offset(_radius, 0.4), radius: const Radius.circular(_radius))
      ..lineTo(size.width - _radius, 0.4)
      ..arcToPoint(Offset(size.width, _radius), radius: const Radius.circular(_radius));
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.75,
    );
  }

  @override
  bool shouldRepaint(_FooterEdge old) => old.color != color;
}

/// "OFFICIAL COUNCIL · Est. 2023", "CHARTERED 2024", or "✓ JOINED · Executive".
class _CoverPills extends StatelessWidget {
  const _CoverPills({required this.council});

  final Council council;

  @override
  Widget build(BuildContext context) {
    final c = council;
    const soft = CouncilsColors.coverPill;
    final pills = <Widget>[];
    if (c.joined) {
      pills.add(
        StatusPill(
          label: 'JOINED',
          icon: LucideIcons.check,
          fill: CouncilsColors.green700,
          style: CouncilsText.coverPill,
          height: 19,
          padding: const EdgeInsets.symmetric(horizontal: 7.5),
        ),
      );
      pills.add(
        StatusPill(
          label: c.membership!.short,
          fill: soft,
          style: CouncilsText.coverPillSoft,
          height: 19,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      );
    } else {
      pills.add(
        StatusPill(
          label: c.badge ?? 'OFFICIAL COUNCIL',
          fill: soft,
          style: CouncilsText.coverPill,
          height: 19,
          padding: const EdgeInsets.symmetric(horizontal: 7.5),
        ),
      );
      if (c.badge == null && c.established != null) {
        pills.add(
          StatusPill(
            label: c.established!,
            fill: soft,
            style: CouncilsText.coverPillSoft,
            height: 19,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        );
      }
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, pill) in pills.indexed) ...[if (i > 0) const SizedBox(width: 4), pill],
      ],
    );
  }
}

/// "642 Members • 3 Working Groups ........ Next: Apr 18".
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.council});

  final Council council;

  @override
  Widget build(BuildContext context) {
    final c = council;
    return Row(
      children: [
        // One Expanded for the left group, so "Next:" sits at the right edge (a Flexible beside a Spacer
        // would split the free space and leave a gap).
        Expanded(
          // The design's group starts a little left of the card's text column.
          child: Transform.translate(
            offset: const Offset(-0.25, 0),
            child: Row(
              children: [
                const Icon(Symbols.groups, size: 14.2, fill: 1, weight: 500, color: AppColors.primary),
                const SizedBox(width: 2.75),
                Text('${groupThousands(c.memberCount)} Members', style: CouncilsText.meta),
                if (c.activityLabel != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 9.25, right: 6.5),
                    child: Container(
                      width: 2.5,
                      height: 2.5,
                      decoration: const BoxDecoration(color: AppColors.slate500, shape: BoxShape.circle),
                    ),
                  ),
                  const Icon(Symbols.bolt, size: 14.5, weight: 500, color: AppColors.tertiary),
                  const SizedBox(width: 0.25),
                  Flexible(
                    child: Text(
                      c.activityLabel!,
                      style: CouncilsText.metaGreen,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (c.nextEventAt != null) ...[
          const SizedBox(width: 8),
          Text('Next: ${monthDay(c.nextEventAt!)}', style: CouncilsText.meta),
        ],
      ],
    );
  }
}

class _JoinButton extends StatelessWidget {
  const _JoinButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: busy ? CouncilsColors.joinButton.withValues(alpha: 0.6) : CouncilsColors.joinButton,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 154.5,
          height: 22.5,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.userPlus, size: 9, color: Colors.white),
              const SizedBox(width: 5),
              Text(busy ? 'Joining…' : 'Join Council', style: CouncilsText.joinButton),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Open Member Lounge", outlined; a long press offers to leave.
class _LoungeButton extends StatelessWidget {
  const _LoungeButton({required this.onTap, required this.onLongPress});

  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: CouncilsColors.cardBorder),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 174,
          height: 22.5,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.messagesSquare, size: 9, color: AppColors.primary),
              const SizedBox(width: 5),
              Text('Open Member Lounge', style: CouncilsText.loungeButton),
            ],
          ),
        ),
      ),
    );
  }
}
