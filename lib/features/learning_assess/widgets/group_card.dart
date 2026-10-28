import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../assess_format.dart';
import '../assess_models.dart';
import '../assess_styles.dart';
import '../catalogue_controller.dart';
import 'assess_picture.dart';
import 'status_pill.dart';

/// One programme (Assess Your Knowledge) or mock subject (Mock Exams) in the landing's grid: the cover with a
/// small pill of what is inside ("3 levels", "2 sets"), the name (two lines), the second line (the levels in
/// the order a candidate climbs them, or how many sets and questions), and a foot that says where the member
/// stands: how much of it is open to them and how they did.
///
/// The frame is the Learning catalogue card's (white, a 1 dp slate edge, a soft shadow, 12 dp corners). Text is
/// sized for a phone, not measured from a design: there is no PNG for this screen.
class GroupCard extends StatelessWidget {
  const GroupCard({super.key, required this.group, required this.summary, required this.onTap});

  /// The cover's shape: 3:2.
  static const coverAspect = 1.5;

  final PaperGroup group;
  final GroupSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isMock = group.kind == PaperKind.mock;
    final count = group.papers.length;
    final meta = isMock ? setsLine(group) : levelsLine(group);
    return Semantics(
      button: true,
      label: '${group.title}, $meta',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AssessColors.cardBorder),
          boxShadow: const [BoxShadow(color: Color(0x0F0F172A), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: coverAspect,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AssessPicture(
                        picture: group.cover,
                        child: Center(
                          child: Icon(isMock ? LucideIcons.timer : LucideIcons.award, color: Colors.white54, size: 34),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        top: 8,
                        child: _CoverPill(isMock ? plural(count, 'set') : plural(count, 'level')),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(group.title, style: AssessText.cardTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(meta, style: AssessText.cardMeta, maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        const Spacer(),
                        _Foot(group: group, summary: summary),
                      ],
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
}

/// The foot: what is open to the member, then how they did. With the member's unlocks unknown it falls back to
/// the catalogue's own facts (a free or paid paper inside).
class _Foot extends StatelessWidget {
  const _Foot({required this.group, required this.summary});

  final PaperGroup group;
  final GroupSummary summary;

  @override
  Widget build(BuildContext context) {
    final pills = <Widget>[];
    if (!summary.known) {
      pills.add(
        StatusPill(
          label: group.anyFree && group.anyPaid ? 'Free + paid' : (group.anyPaid ? 'Paid' : 'Free'),
          tone: group.anyPaid && !group.anyFree ? PillTone.info : PillTone.success,
        ),
      );
    } else if (summary.allOpen) {
      pills.add(const StatusPill(label: 'Open', tone: PillTone.success, icon: LucideIcons.lockOpen));
    } else if (summary.planWouldOpen) {
      pills.add(const StatusPill(label: 'In your plan', tone: PillTone.info, icon: LucideIcons.award));
    } else if (summary.noneOpen) {
      pills.add(const StatusPill(label: 'Locked', icon: LucideIcons.lock));
    } else {
      pills.add(
        StatusPill(label: '${summary.open} of ${summary.total} open', tone: PillTone.info, icon: LucideIcons.lockOpen),
      );
    }
    if (summary.passed > 0) {
      pills.add(
        StatusPill(
          label: summary.passed == summary.total ? 'All passed' : '${summary.passed} passed',
          tone: PillTone.solidSuccess,
          icon: LucideIcons.check,
        ),
      );
    } else if (summary.started > 0 && summary.bestPercent != null) {
      pills.add(StatusPill(label: 'Best ${summary.bestPercent}%', tone: PillTone.warn, icon: LucideIcons.target));
    }
    return Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: pills);
  }
}

class _CoverPill extends StatelessWidget {
  const _CoverPill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: const Color(0x99081422), borderRadius: BorderRadius.circular(5)),
      child: Center(
        widthFactor: 1,
        child: Text(text.toUpperCase(), style: AssessText.coverPill, maxLines: 1, softWrap: false),
      ),
    );
  }
}

/// Two cards side by side, 12 dp in from the screen's edges with 10 dp between, as tall as the taller of the two.
/// A lone last card sits at the left, half width.
class GroupGridRow extends StatelessWidget {
  const GroupGridRow({super.key, required this.left, this.right});

  static const padding = EdgeInsets.symmetric(horizontal: 12);
  static const gap = 10.0;
  static const rowGap = 10.0;

  final Widget left;
  final Widget? right;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: left),
            const SizedBox(width: gap),
            Expanded(child: right ?? const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}
