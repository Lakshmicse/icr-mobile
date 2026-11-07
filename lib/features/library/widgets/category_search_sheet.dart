import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../chapters/community_kit.dart';
import '../upload_controller.dart';

/// The category box of the upload form: a sheet that searches the whole category tree, as the website's
/// category box does (typing "Housekeeping" finds the sub-category under its category).
///
/// Empty, it lists the categories and "Other (add your own)". Typed, it lists every node whose path holds each
/// word, the categories first and the deeper ones under their category's name, with "Other" kept last. Pops
/// with the path of the node picked ([category], [category, sub] or [category, sub, specialization]).
Future<List<String>?> showCategorySearch(
  BuildContext context, {
  required List<CategoryPath> Function(String input) search,
  String? selected,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    builder: (sheet) => CategorySearchSheet(search: search, selected: selected),
  );
}

class CategorySearchSheet extends StatefulWidget {
  const CategorySearchSheet({super.key, required this.search, this.selected});

  final List<CategoryPath> Function(String input) search;

  /// The category already chosen, ticked in the list.
  final String? selected;

  @override
  State<CategorySearchSheet> createState() => _CategorySearchSheetState();
}

class _CategorySearchSheetState extends State<CategorySearchSheet> {
  final _input = TextEditingController();
  late List<CategoryPath> _results = widget.search('');

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _typed(String text) => setState(() => _results = widget.search(text));

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: size.height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Category', style: CommunityText.sheetTitle),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  key: const Key('category-search'),
                  controller: _input,
                  autofocus: true,
                  style: CommunityText.fieldInput,
                  textInputAction: TextInputAction.search,
                  onChanged: _typed,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Type a category, sub-category or specialization',
                    hintStyle: CommunityText.fieldHint,
                    prefixIcon: const Icon(LucideIcons.search, size: 16, color: AppColors.slate400),
                    prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: _outline(CommunityColors.border),
                    focusedBorder: _outline(AppColors.primary),
                  ),
                ),
              ),
              Flexible(
                child: ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 8), children: _rows(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static OutlineInputBorder _outline(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: c),
  );

  List<Widget> _rows(BuildContext sheet) {
    final rows = <Widget>[];
    String? group;
    for (final p in _results) {
      if (p.isOther) {
        rows
          ..add(const Divider(height: 1, thickness: 1, color: CommunityColors.tileRule))
          ..add(
            InkWell(
              onTap: () => Navigator.pop(sheet, p.path),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(
                  children: [
                    const Icon(LucideIcons.plus, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(p.label, style: CommunityText.sheetRow.copyWith(color: AppColors.primary)),
                  ],
                ),
              ),
            ),
          );
        continue;
      }
      if (p.isCategory) {
        rows.add(
          ListTile(
            dense: true,
            title: Text(p.label, style: CommunityText.sheetRow),
            trailing: p.label == widget.selected
                ? const Icon(LucideIcons.check, size: 18, color: AppColors.primary)
                : null,
            onTap: () => Navigator.pop(sheet, p.path),
          ),
        );
        continue;
      }
      // A deeper hit sits under its category's name, which says where it is; only what lies between shows.
      if (p.path.first != group) {
        group = p.path.first;
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
            child: Text(group, style: CommunityText.sheetLabel.copyWith(fontWeight: FontWeight.w700)),
          ),
        );
      }
      final between = p.path.length > 2 ? '${p.path.sublist(1, p.path.length - 1).join(' › ')} › ' : '';
      rows.add(
        InkWell(
          onTap: () => Navigator.pop(sheet, p.path),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 9, 16, 9),
            child: Text.rich(
              TextSpan(
                children: [
                  if (between.isNotEmpty)
                    TextSpan(
                      text: between,
                      style: CommunityText.sheetRow.copyWith(color: AppColors.slate500),
                    ),
                  TextSpan(
                    text: p.label,
                    style: CommunityText.sheetRow.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return rows;
  }
}
