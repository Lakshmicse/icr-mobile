import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../mentorship_models.dart';
import '../mentorship_styles.dart';

/// The glyph in front of a category chip, picked from the domain's words
/// (building for Operations & FM, a leaf for Sustainability & ESG, a signal
/// for Smart Buildings & IoT, as in the designs, which draw Material's).
/// [size] is the box that makes the glyph's ink about 13 dp wide; [filled] says
/// whether the design draws it solid (the building) or as an outline.
({IconData icon, double size, bool filled}) domainGlyph(String label) {
  final l = label.toLowerCase();
  bool has(String pattern) => RegExp(pattern).hasMatch(l);
  if (has(r'operation|facility|building operations|maintenance')) {
    return (icon: Symbols.domain, size: 16, filled: true);
  }
  if (has(r'sustainab|esg|energy|green')) return (icon: Symbols.eco, size: 16, filled: false);
  if (has(r'smart|iot|technolog|digital|data|\bai\b')) return (icon: Symbols.sensors, size: 16, filled: false);
  if (has(r'real estate|portfolio|property|capital')) return (icon: Symbols.account_balance, size: 16, filled: false);
  if (has(r'procure|vendor|contract')) return (icon: Symbols.handshake, size: 16, filled: false);
  if (has(r'safety|risk|security|continuity')) return (icon: Symbols.shield, size: 16, filled: false);
  if (has(r'financ|budget')) return (icon: Symbols.account_balance_wallet, size: 16, filled: false);
  if (has(r'workplace|experience|customer')) return (icon: Symbols.chair, size: 16, filled: false);
  if (has(r'leader|strateg|govern|ethic')) return (icon: Symbols.workspace_premium, size: 16, filled: false);
  return (icon: Symbols.grid_view, size: 16, filled: false);
}

/// The domain chips: the selected one in blue, the rest outlined; a row that
/// scrolls sideways, and brings the selected chip into view when it is out of
/// it (Find Mentors can open on a domain far down the list).
class CategoryChipRow extends StatefulWidget {
  const CategoryChipRow({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelect,
    this.height = 26.6,
    this.fontSize = 12.6,
    this.gap = 4.2,
    this.padding = 9,
    this.iconScale = 1,
    this.leftPad = 9,
    this.rightPad = 10.5,
    this.iconGap = 5.5,
  });

  final List<MentorCategory> categories;
  final String? selected;
  final ValueChanged<String> onSelect;
  final double height;
  final double fontSize;
  final double gap;
  final double padding;

  /// The landing draws the same chips a little smaller.
  final double iconScale;

  /// Inside a chip: before the glyph, after the words, between the two.
  final double leftPad;
  final double rightPad;
  final double iconGap;

  @override
  State<CategoryChipRow> createState() => _CategoryChipRowState();
}

class _CategoryChipRowState extends State<CategoryChipRow> {
  final _scroll = ScrollController();
  final _keys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _revealSoon();
  }

  @override
  void didUpdateWidget(CategoryChipRow old) {
    super.didUpdateWidget(old);
    // The chips arrive after the screen does (Find Mentors reads them as it opens).
    if (old.selected != widget.selected || old.categories.length != widget.categories.length) _revealSoon();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _revealSoon() => WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());

  /// Scrolls just far enough to show the selected chip in full, plus a margin.
  void _reveal() {
    final label = widget.selected;
    final target = label == null ? null : _keys[label]?.currentContext;
    if (!mounted || target == null || !target.mounted || !_scroll.hasClients) return;
    final box = target.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    final viewport = RenderAbstractViewport.of(box);
    final atStart = viewport.getOffsetToReveal(box, 0).offset - widget.padding;
    final atEnd = viewport.getOffsetToReveal(box, 1).offset + widget.padding;
    final position = _scroll.position;
    final offset = position.pixels;
    final to = offset > atStart ? atStart : (offset < atEnd ? atEnd : offset);
    if (to == offset) return;
    _scroll.jumpTo(to.clamp(position.minScrollExtent, position.maxScrollExtent));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: widget.padding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, c) in widget.categories.indexed) ...[
              if (i > 0) SizedBox(width: widget.gap),
              KeyedSubtree(key: _keys.putIfAbsent(c.label, GlobalKey.new), child: _chip(c)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(MentorCategory c) {
    final on = c.label == widget.selected;
    final glyph = domainGlyph(c.label);
    final style = MentorshipText.categoryChip(selected: on, size: widget.fontSize);
    final shape = StadiumBorder(side: on ? BorderSide.none : const BorderSide(color: AppColors.outlineVariant));
    return Semantics(
      button: true,
      selected: on,
      child: Material(
        color: on ? AppColors.primary : Colors.white,
        shape: shape,
        elevation: on ? 0 : 0.5,
        shadowColor: const Color(0x14000000),
        child: InkWell(
          customBorder: shape,
          onTap: () => widget.onSelect(c.label),
          child: SizedBox(
            height: widget.height,
            child: Padding(
              padding: EdgeInsets.only(left: widget.leftPad, right: widget.rightPad),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    glyph.icon,
                    size: glyph.size * widget.iconScale,
                    fill: glyph.filled ? 1 : 0,
                    weight: glyph.filled ? 400 : 500,
                    color: style.color,
                  ),
                  SizedBox(width: widget.iconGap),
                  Text(c.label, style: style),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
