import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/detail_sheet.dart';
import '../forum_models.dart';
import '../forum_styles.dart';

/// "Filter discussions": the order, the kind, the topic and sub-topic, and a tag. Returns the question the reader
/// ended on (their view and their search kept), or null when they dismissed the sheet.
Future<ForumQuery?> showForumFilters(
  BuildContext context, {
  required ForumQuery query,
  required List<ForumTopic> topics,
  required List<TaxonomyNode> taxonomy,
}) {
  return showModalBottomSheet<ForumQuery>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    barrierColor: AppColors.sheetScrim,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    clipBehavior: Clip.antiAlias,
    builder: (_) => _FiltersSheet(query: query, topics: topics, taxonomy: taxonomy),
  );
}

class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({required this.query, required this.topics, required this.taxonomy});

  final ForumQuery query;
  final List<ForumTopic> topics;
  final List<TaxonomyNode> taxonomy;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late ForumQuery _q = widget.query;
  late final TextEditingController _tag = TextEditingController(text: widget.query.tag ?? '');

  @override
  void dispose() {
    _tag.dispose();
    super.dispose();
  }

  List<TaxonomyNode> get _subtopics {
    final topic = _q.category;
    if (topic == null) return const [];
    for (final node in widget.taxonomy) {
      if (node.slug == topic.slug) return node.children;
    }
    return const [];
  }

  /// The tag as a forum tag: no "#", no spaces, lower case, at most 32 characters (the forum stores them so).
  String? get _tagValue {
    final text = _tag.text.trim().replaceFirst(RegExp(r'^#+'), '').toLowerCase().replaceAll(RegExp(r'\s+'), '-');
    if (text.isEmpty) return null;
    return text.length > ForumLimits.tagChars ? text.substring(0, ForumLimits.tagChars) : text;
  }

  ForumQuery get _result {
    final tag = _tagValue;
    return tag == null ? _q.copyWith(clearTag: true) : _q.copyWith(tag: tag);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(top: 11, height: 28, rule: false),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text('Filter discussions', style: ForumDesign.sheetTitle),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                children: [
                  _Label(_q.sortable ? 'SORT BY' : 'SORT BY (SET BY THE VIEW)'),
                  _Options<ForumSort>(
                    keyPrefix: 'filter-sort',
                    values: const [ForumSort.latest, ForumSort.newest, ForumSort.top],
                    selected: _q.sort,
                    enabled: _q.sortable,
                    labelOf: (v) => v.label,
                    idOf: (v) => v.name,
                    onPick: (v) => setState(() => _q = _q.copyWith(sort: v)),
                  ),
                  const SizedBox(height: 18),
                  const _Label('TYPE'),
                  _Options<ForumKindFilter>(
                    keyPrefix: 'filter-kind',
                    values: ForumKindFilter.values,
                    selected: _q.kind,
                    labelOf: (v) => v.label,
                    idOf: (v) => v.name,
                    onPick: (v) => setState(() => _q = _q.copyWith(kind: v)),
                  ),
                  const SizedBox(height: 18),
                  const _Label('TOPIC'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _Pill(
                        key: const ValueKey('filter-topic:all'),
                        label: 'All topics',
                        selected: _q.category == null,
                        onTap: () => setState(() => _q = _q.copyWith(clearCategory: true)),
                      ),
                      for (final t in widget.topics)
                        _Pill(
                          key: ValueKey('filter-topic:${t.slug}'),
                          label: t.name,
                          selected: _q.category?.slug == t.slug,
                          onTap: () => setState(() => _q = _q.copyWith(category: t, clearSubcategory: true)),
                        ),
                    ],
                  ),
                  if (_subtopics.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const _Label('SUB-TOPIC'),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Pill(
                          key: const ValueKey('filter-sub:all'),
                          label: 'Any',
                          selected: _q.subcategory == null,
                          onTap: () => setState(() => _q = _q.copyWith(clearSubcategory: true)),
                        ),
                        for (final n in _subtopics)
                          _Pill(
                            key: ValueKey('filter-sub:${n.slug}'),
                            label: n.name,
                            selected: _q.subcategory?.slug == n.slug,
                            onTap: () => setState(() => _q = _q.copyWith(subcategory: n)),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  const _Label('TAG'),
                  TextField(
                    key: const ValueKey('filter-tag'),
                    controller: _tag,
                    style: ForumDesign.field,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: 'A tag, like hvac',
                      hintStyle: ForumDesign.fieldHint,
                      prefixText: '#',
                      prefixStyle: ForumDesign.field.copyWith(color: AppColors.outline),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.outlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.outlineVariant),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  TextButton(
                    key: const ValueKey('filters-clear'),
                    onPressed: () =>
                        Navigator.pop(context, ForumQuery(view: widget.query.view, search: widget.query.search)),
                    child: Text('Clear all', style: ForumDesign.chip.copyWith(color: AppColors.primary, fontSize: 13)),
                  ),
                  const Spacer(),
                  FilledButton(
                    key: const ValueKey('filters-apply'),
                    onPressed: () => Navigator.pop(context, _result),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(140, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Show results', style: ForumDesign.button),
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

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: ForumDesign.fieldLabel),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.label, required this.selected, required this.onTap, this.enabled = true});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final shape = StadiumBorder(side: BorderSide(color: selected ? AppColors.primary : AppColors.outlineVariant));
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.primary : Colors.white,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              label,
              style: ForumDesign.chip.copyWith(
                fontSize: 13,
                color: selected
                    ? Colors.white
                    : enabled
                    ? AppColors.onSurfaceVariant
                    : AppColors.outlineVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Options<T> extends StatelessWidget {
  const _Options({
    required this.keyPrefix,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.idOf,
    required this.onPick,
    this.enabled = true,
  });

  final String keyPrefix;
  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final String Function(T) idOf;
  final ValueChanged<T> onPick;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final v in values)
          _Pill(
            key: ValueKey('$keyPrefix:${idOf(v)}'),
            label: labelOf(v),
            selected: v == selected,
            enabled: enabled,
            onTap: () => onPick(v),
          ),
      ],
    );
  }
}

/// The filter glyph for a search box, with a count of what is set.
class FilterButton extends StatelessWidget {
  const FilterButton({super.key, required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: count == 0 ? 'Filters' : 'Filters, $count set',
      excludeSemantics: true,
      child: InkResponse(
        key: const ValueKey('forum-filters'),
        onTap: onTap,
        radius: 18,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(LucideIcons.slidersHorizontal, size: 16, color: count == 0 ? AppColors.outline : AppColors.primary),
              if (count > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 13,
                    height: 13,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    child: Text(
                      '$count',
                      style: ForumDesign.count.copyWith(color: Colors.white, fontSize: 12, height: 1),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
