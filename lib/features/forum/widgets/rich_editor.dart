import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../forum_styles.dart';
import '../rich_document.dart';
import '../rich_text_controller.dart';

/// The text of the composer's fields: one size and weight for a post and a poll alike (Roboto 16, 90 % black).
final composerFieldStyle = AppText.plexSans(16, FontWeight.w400, const Color(0xE6000000), lineHeight: 22);

/// The website's rich-text editor on a phone (`RichTextEditor`): a frame with the toolbar (bold, italic, heading,
/// bulleted and numbered lists, link) over the writing area, and "0 / 20,000" under it. What is written shows as
/// it will read: bold is bold, a heading is larger, lists carry their markers, a link is blue.
class RichEditor extends StatefulWidget {
  const RichEditor({
    super.key,
    required this.controller,
    required this.placeholder,
    this.fieldKey = const ValueKey('composer-body'),
    this.error = false,
    this.minLines = 6,
  });

  final RichTextController controller;
  final String placeholder;

  /// The writing area's key (the composer's tests type into it).
  final Key fieldKey;

  /// The frame is drawn red: what is required is missing.
  final bool error;
  final int minLines;

  @override
  State<RichEditor> createState() => _RichEditorState();
}

class _RichEditorState extends State<RichEditor> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    final c = widget.controller;
    final current = c.currentLink;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      barrierColor: AppColors.sheetScrim,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      clipBehavior: Clip.antiAlias,
      builder: (_) => _LinkSheet(address: current),
    );
    if (!mounted) return;
    if (result != null) c.setLink(result);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return AnimatedBuilder(
      animation: Listenable.merge([c, _focus]),
      builder: (context, _) {
        final focused = _focus.hasFocus;
        final color = widget.error ? AppColors.error : (focused ? AppColors.primary : AppColors.composerBorder);
        final length = c.plainLength;
        final limit = c.maxChars;
        return Container(
          key: const ValueKey('rich-editor'),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color, width: focused || widget.error ? 1.5 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFieldTapRegion(
                child: _Toolbar(controller: c, onLink: _link),
              ),
              const Divider(height: 1, thickness: 1, color: AppColors.outlineVariant),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: TextField(
                  key: widget.fieldKey,
                  controller: c,
                  focusNode: _focus,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: widget.minLines,
                  maxLines: null,
                  style: composerFieldStyle,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: widget.placeholder,
                    hintMaxLines: 5,
                    hintStyle: composerFieldStyle.copyWith(color: AppColors.outline),
                  ),
                ),
              ),
              const Divider(height: 1, thickness: 1, color: AppColors.outlineVariant),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${_grouped(length)} / ${_grouped(limit)}',
                    key: const ValueKey('rich-count'),
                    style: ForumDesign.count.copyWith(
                      fontWeight: FontWeight.w400,
                      color: length > limit * 0.95 ? AppColors.amber800 : const Color(0x99000000),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 20000 → "20,000".
String _grouped(int n) {
  final s = n.toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.controller, required this.onLink});

  final RichTextController controller;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    Widget rule() => Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: AppColors.outlineVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: [
          _Tool(
            toolKey: 'rich-bold',
            label: 'Bold',
            icon: Icons.format_bold,
            active: c.isBold,
            onTap: c.toggleBold,
          ),
          _Tool(
            toolKey: 'rich-italic',
            label: 'Italic',
            icon: Icons.format_italic,
            active: c.isItalic,
            onTap: c.toggleItalic,
          ),
          _Tool(
            toolKey: 'rich-heading',
            label: 'Heading',
            icon: Icons.title,
            active: c.isHeading,
            onTap: c.toggleHeading,
          ),
          rule(),
          _Tool(
            toolKey: 'rich-bullets',
            label: 'Bullet list',
            icon: Icons.format_list_bulleted,
            active: c.isBulleted,
            onTap: c.toggleBullets,
          ),
          _Tool(
            toolKey: 'rich-numbers',
            label: 'Numbered list',
            icon: Icons.format_list_numbered,
            active: c.isNumbered,
            onTap: c.toggleNumbers,
          ),
          rule(),
          _Tool(
            toolKey: 'rich-link',
            label: c.canLink ? 'Link' : 'Select text to link',
            icon: Icons.link,
            active: c.currentLink != null,
            enabled: c.canLink,
            onTap: onLink,
          ),
        ],
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({
    required this.toolKey,
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    this.enabled = true,
  });

  final String toolKey;
  final String label;
  final IconData icon;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = !enabled ? const Color(0x42000000) : (active ? AppColors.primary : const Color(0x99000000));
    return Semantics(
      button: true,
      selected: active,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        key: ValueKey(toolKey),
        // The toolbar must not take the keyboard (nor the selection) from the writing area.
        canRequestFocus: false,
        onTap: enabled ? onTap : null,
        radius: 22,
        child: Container(
          width: 44,
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: active ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 22, color: color),
        ),
      ),
    );
  }
}

/// The Link button's sheet: an address (the website's popover). Apply attaches it; Remove, shown when the words
/// are linked already and the field is emptied, takes the link off. An address with no scheme gets `https://`.
class _LinkSheet extends StatefulWidget {
  const _LinkSheet({required this.address});

  final String? address;

  @override
  State<_LinkSheet> createState() => _LinkSheetState();
}

class _LinkSheetState extends State<_LinkSheet> {
  late final _field = TextEditingController(text: widget.address ?? '');

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  String? get _normalised => normaliseLink(_field.text);
  bool get _empty => _field.text.trim().isEmpty;
  bool get _canApply => _normalised != null || (_empty && widget.address != null);

  void _apply() {
    if (!_canApply) return;
    Navigator.of(context).pop(_empty ? '' : _normalised);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Link', style: ForumDesign.sheetTitle),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('link-url'),
              controller: _field,
              autofocus: true,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _apply(),
              style: composerFieldStyle,
              decoration: InputDecoration(
                labelText: 'Link URL',
                hintText: 'https://…',
                labelStyle: composerFieldStyle.copyWith(color: const Color(0x99000000)),
                hintStyle: composerFieldStyle.copyWith(color: AppColors.outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              key: const ValueKey('link-apply'),
              onPressed: _canApply ? _apply : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(_empty && widget.address != null ? 'Remove' : 'Apply', style: ForumDesign.button),
            ),
          ],
        ),
      ),
    );
  }
}
