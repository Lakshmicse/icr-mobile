import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../chapters/community_kit.dart';
import 'library_device.dart' show LibraryDeviceSite;
import 'library_format.dart';
import 'library_handoffs.dart';
import 'library_models.dart';
import 'library_repository.dart';
import 'upload_controller.dart';
import 'widgets/category_search_sheet.dart';
import 'widgets/document_card.dart';

/// Upload a document to the library, or (with [target]) add files to one the member shared.
///
/// The website's `UploadDocumentDialog`, field for field: choose the files first, then describe them. The
/// title starts as the first file's name; a title and a category are required (the Upload button waits for
/// both); the category is found by typing any level of the platform's tree, and a sub-category and a
/// specialization are offered under it, each with "Other (add your own)" at the foot; each file has a
/// "File name" field (the extension stays) and a remove glyph; one to ten files of at most 10 MB. Sending
/// uploads each file, then files the document. A refusal is shown at the top and everything typed stays.
/// Pops with the [LibraryDocument] the API answered with, or null when the person backed out.
class UploadDocumentScreen extends StatefulWidget {
  const UploadDocumentScreen({
    super.key,
    required this.repository,
    this.target,
    this.handoffs = const LibraryHandoffs(),
    this.usedCategories = const [],
    this.controller,
  });

  final LibraryRepository repository;

  /// Set to add files to this document instead of filing a new one.
  final LibraryDocument? target;
  final LibraryHandoffs handoffs;

  /// The categories the library already uses (offered after the platform's own).
  final List<String> usedCategories;

  /// A controller the caller owns (tests); the screen makes its own otherwise.
  final UploadController? controller;

  @override
  State<UploadDocumentScreen> createState() => _UploadDocumentScreenState();
}

class _UploadDocumentScreenState extends State<UploadDocumentScreen> {
  late final UploadController _c;
  late final bool _ownsController;
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _categoryOther = TextEditingController();
  final _subOther = TextEditingController();
  final _specOther = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _c =
        widget.controller ??
        UploadController(repository: widget.repository, target: widget.target, usedCategories: widget.usedCategories);
    _c.addListener(_syncFields);
    _loadTaxonomy();
  }

  Future<void> _loadTaxonomy() async {
    if (_c.appending) return;
    try {
      _c.setOptions(taxonomy: await widget.repository.taxonomy());
    } catch (_) {
      // The tree is a nicety: without it the category is the library's own list and "Other".
    }
  }

  /// The title starts as the first file's name, and a pick from the category box clears what was typed under
  /// the old one: both are set by the controller, so the boxes follow it.
  void _syncFields() {
    _follow(_title, _c.title);
    _follow(_description, _c.description);
    _follow(_categoryOther, _c.categoryOther);
    _follow(_subOther, _c.subcategoryOther);
    _follow(_specOther, _c.specializationOther);
  }

  static void _follow(TextEditingController box, String text) {
    if (box.text == text) return;
    box.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  void dispose() {
    _c.removeListener(_syncFields);
    if (_ownsController) _c.dispose();
    _title.dispose();
    _description.dispose();
    _categoryOther.dispose();
    _subOther.dispose();
    _specOther.dispose();
    super.dispose();
  }

  void _bell() {
    final go = widget.handoffs.onBell;
    if (go != null) return go();
    widget.handoffs.device.openPage(context, AppConfig.sitePage('/notifications'));
  }

  /// Never mid-upload: the request would be orphaned (the website's dialog does the same).
  void _back() {
    if (_c.busy) return;
    Navigator.of(context).pop();
  }

  Future<void> _pick() async {
    final files = await widget.handoffs.device.pickFiles();
    if (files.isEmpty) return;
    _c.pick(files);
  }

  Future<void> _pickCategory() async {
    final path = await showCategorySearch(context, search: _c.searchCategories, selected: _c.category);
    if (path != null) _c.chooseCategory(path);
  }

  Future<void> _pickFrom(String title, List<String> options, String? selected, ValueChanged<String?> onPick) async {
    final picked = await pickFromSheet<String>(
      context,
      title: title,
      options: options,
      label: (o) => o,
      selected: selected,
    );
    if (picked != null) onPick(picked);
  }

  Future<void> _submit() async {
    final doc = await _c.submit();
    if (doc != null && mounted) Navigator.of(context).pop(doc);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _back();
          },
          child: CommunityPage(
            title: _c.appending ? 'Add files' : 'Upload a document',
            onBack: _back,
            onBell: _bell,
            onRefresh: () async {},
            bottomBar: _sendBar(),
            children: _body(),
          ),
        );
      },
    );
  }

  /// The website's words for how far the send is.
  static String _progressText(UploadController c) {
    if (c.starting) return 'Starting…';
    if (c.saving) return 'Saving…';
    final percent = percentLabel(c.progress);
    return c.entries.length > 1
        ? 'Uploading ${c.uploadingName} — $percent (${c.uploadingIndex} of ${c.entries.length})'
        : 'Uploading ${c.uploadingName} — $percent';
  }

  Widget _sendBar() {
    final c = _c;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: CommunityColors.tileRule)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (c.busy) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                // Indeterminate until the first byte, and again while the document is being filed.
                value: c.starting || c.saving ? null : c.progress,
                minHeight: 5,
                color: AppColors.primary,
                backgroundColor: CommunityColors.greyPill,
              ),
            ),
            const SizedBox(height: 5),
            Text(_progressText(c), style: CommunityText.meta.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
          ],
          CommunityButton(
            label: c.appending ? (c.entries.isEmpty ? 'Add files' : 'Add ${filesLabel(c.entries.length)}') : 'Upload',
            icon: LucideIcons.upload,
            expand: true,
            height: 42,
            busy: c.busy,
            // Like the website's button: it waits for a file, and for a title and a category on a new document.
            onPressed: c.canSubmit ? _submit : null,
          ),
        ],
      ),
    );
  }

  List<Widget> _body() {
    final c = _c;
    return [
      const SizedBox(height: 14),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (c.appending) ...[
              Text(
                'They join “${c.target!.title}”, under the same description and category.',
                style: CommunityText.body,
              ),
              const SizedBox(height: 12),
            ],
            if (c.error != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: CommunityColors.red50, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(LucideIcons.circleAlert, size: 15, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(child: Text(c.error!, style: CommunityText.fieldError)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            _FilesBox(
              entries: c.entries,
              room: c.room,
              appending: c.appending,
              busy: c.busy,
              uploading: c.uploadingIndex,
              problem: c.problemFor('files'),
              onPick: _pick,
              onRemove: c.remove,
              onRename: c.rename,
            ),
            if (!c.appending) ...[
              const SizedBox(height: 16),
              CommunityField(
                label: 'Title *',
                controller: _title,
                maxLength: LibraryLimits.title,
                help: c.entries.length > 1 ? 'One title for the whole set — what someone would search for.' : null,
                error: c.problemFor('title'),
                enabled: !c.busy,
                textInputAction: TextInputAction.next,
                onChanged: c.setTitle,
                fieldKey: const Key('upload-title'),
              ),
              const SizedBox(height: 14),
              CommunityField(
                label: 'Description',
                controller: _description,
                minLines: 3,
                maxLines: 6,
                maxLength: LibraryLimits.description,
                help: 'What it is and when someone would reach for it.',
                error: c.problemFor('description'),
                enabled: !c.busy,
                onChanged: c.setDescription,
                fieldKey: const Key('upload-description'),
              ),
              const SizedBox(height: 14),
              _PickerField(
                label: 'Category *',
                hint: 'Type a category, sub-category or specialization',
                help: 'Groups the document under a filter chip.',
                value: c.category,
                error: c.problemFor('category'),
                enabled: !c.busy,
                onOpen: _pickCategory,
                onClear: () => c.setCategory(null),
              ),
              if (c.category == otherOption) ...[
                const SizedBox(height: 8),
                CommunityField(
                  label: 'Your category *',
                  controller: _categoryOther,
                  hint: 'e.g. Board papers',
                  maxLength: LibraryLimits.category,
                  enabled: !c.busy,
                  onChanged: c.setCategoryOther,
                  fieldKey: const Key('upload-category-other'),
                ),
              ],
              // Offered only once a category is chosen: a sub-category with no parent cannot be placed in the tree.
              if (c.resolvedCategory.isNotEmpty) ...[
                const SizedBox(height: 14),
                _PickerField(
                  label: 'Sub-category (optional)',
                  hint: c.hasSubcategories ? 'Narrow it down' : 'Nothing listed under this category',
                  value: c.subcategory,
                  error: c.problemFor('subcategory'),
                  enabled: !c.busy,
                  onOpen: () => _pickFrom('Sub-category', c.subcategoryOptions, c.subcategory, c.setSubcategory),
                  onClear: () => c.setSubcategory(null),
                ),
                if (c.subcategory == otherOption) ...[
                  const SizedBox(height: 8),
                  CommunityField(
                    label: 'Your sub-category',
                    controller: _subOther,
                    maxLength: LibraryLimits.subcategory,
                    enabled: !c.busy,
                    onChanged: c.setSubcategoryOther,
                    fieldKey: const Key('upload-subcategory-other'),
                  ),
                ],
              ],
              if (c.resolvedSubcategory.isNotEmpty) ...[
                const SizedBox(height: 14),
                _PickerField(
                  label: 'Specialization (optional)',
                  hint: c.hasSpecializations ? 'Narrow it further' : 'Nothing listed under this sub-category',
                  value: c.specialization,
                  error: c.problemFor('specialization'),
                  enabled: !c.busy,
                  onOpen: () =>
                      _pickFrom('Specialization', c.specializationOptions, c.specialization, c.setSpecialization),
                  onClear: () => c.setSpecialization(null),
                ),
                if (c.specialization == otherOption) ...[
                  const SizedBox(height: 8),
                  CommunityField(
                    label: 'Your specialization',
                    controller: _specOther,
                    maxLength: LibraryLimits.specialization,
                    enabled: !c.busy,
                    onChanged: c.setSpecializationOther,
                    fieldKey: const Key('upload-specialization-other'),
                  ),
                ],
              ],
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    ];
  }
}

/// The file list: a "Choose files" panel while empty, then a row per file (its plate, its name and size, a
/// remove glyph, and a "File name" field to rename it) and "Add more" while there is room.
class _FilesBox extends StatelessWidget {
  const _FilesBox({
    required this.entries,
    required this.room,
    required this.appending,
    required this.busy,
    required this.uploading,
    required this.problem,
    required this.onPick,
    required this.onRemove,
    required this.onRename,
  });

  final List<UploadEntry> entries;
  final int room;
  final bool appending;
  final bool busy;
  final int uploading;
  final String? problem;
  final VoidCallback onPick;
  final ValueChanged<int> onRemove;
  final void Function(int id, String name) onRename;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            label: room == 1 ? 'Choose a file' : 'Choose files',
            child: InkWell(
              onTap: busy ? null : onPick,
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
                decoration: BoxDecoration(
                  color: problem == null ? CommunityColors.tile : CommunityColors.red50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(LucideIcons.cloudUpload, size: 30, color: AppColors.primary),
                    const SizedBox(height: 8),
                    Text(room == 1 ? 'Choose a file' : 'Choose files', style: CommunityText.cardTitle),
                    const SizedBox(height: 4),
                    Text(
                      'PDF, Word, Excel, PowerPoint, CSV, images or a ZIP — up to 10 MB each',
                      textAlign: TextAlign.center,
                      style: CommunityText.personLine,
                    ),
                    if (room > 1) ...[
                      const SizedBox(height: 3),
                      Text('Pick several to file them under one title.', style: CommunityText.meta),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (problem != null) ...[const SizedBox(height: 4), Text(problem!, style: CommunityText.fieldError)],
        ],
      );
    }
    final total = entries.fold<int>(0, (n, e) => n + e.file.size);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('${filesLabel(entries.length)} · ${fileSizeLabel(total)}', style: CommunityText.fieldLabel),
            ),
            if (entries.length < room)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: busy ? null : onPick,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.plus, size: 13, color: AppColors.primary),
                      const SizedBox(width: 3),
                      Text('Add more', style: CommunityText.link),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (final (i, e) in entries.indexed) ...[
          if (i > 0) const Divider(height: 1, thickness: 1, color: CommunityColors.tileRule),
          _FileRow(
            key: ValueKey(e.id),
            entry: e,
            busy: busy,
            active: busy && uploading == i + 1,
            onRemove: () => onRemove(e.id),
            onRename: (n) => onRename(e.id, n),
          ),
        ],
        if (entries.length >= room) ...[
          const SizedBox(height: 6),
          Text(
            appending
                ? 'That is the ${LibraryLimits.maxFiles}-file limit for one document.'
                : 'A document holds up to ${LibraryLimits.maxFiles} files.',
            style: CommunityText.personLine,
          ),
        ],
        if (problem != null) Text(problem!, style: CommunityText.fieldError),
      ],
    );
  }
}

/// One chosen file, before it goes anywhere: the file as picked (read-only, so it is always clear what was
/// chosen), and the name it will be saved under as a "File name" field of its own.
class _FileRow extends StatefulWidget {
  const _FileRow({
    super.key,
    required this.entry,
    required this.busy,
    required this.active,
    required this.onRemove,
    required this.onRename,
  });

  final UploadEntry entry;
  final bool busy;
  final bool active;
  final VoidCallback onRemove;
  final ValueChanged<String> onRename;

  @override
  State<_FileRow> createState() => _FileRowState();
}

class _FileRowState extends State<_FileRow> {
  late final TextEditingController _name = TextEditingController(text: widget.entry.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// An emptied name goes back to the original rather than uploading as ".pdf": blank is never what someone
  /// meant to save.
  void _focusChanged(bool focused) {
    if (focused || _name.text.trim().isNotEmpty) return;
    final base = UploadEntry.baseOf(widget.entry.file.name);
    _name.text = base;
    widget.onRename(base);
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final glyph = FileGlyph.of(e.file.mimeType ?? '', e.file.name);
    final base = UploadEntry.baseOf(e.file.name);
    final typed = _name.text.trim();
    final renamed = typed.isNotEmpty && typed != base;
    OutlineInputBorder outline(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: c),
    );
    return Container(
      color: widget.active ? CommunityColors.blue50 : Colors.transparent,
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FilePlate(glyph: glyph, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.file.name,
                      style: AppText.plexSans(11.5, FontWeight.w600, AppColors.onSurface, lineHeight: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(fileSizeLabel(e.file.size), style: CommunityText.meta),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove ${e.file.name}',
                visualDensity: VisualDensity.compact,
                icon: const Icon(LucideIcons.x, size: 16, color: AppColors.slate500),
                onPressed: widget.busy ? null : widget.onRemove,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('File name', style: CommunityText.fieldLabel),
          const SizedBox(height: 5),
          Focus(
            onFocusChange: _focusChanged,
            child: TextField(
              controller: _name,
              enabled: !widget.busy,
              maxLength: 200,
              style: CommunityText.fieldInput,
              onChanged: (v) {
                widget.onRename(v);
                setState(() {});
              },
              decoration: InputDecoration(
                isDense: true,
                counterText: '',
                hintText: base,
                hintStyle: CommunityText.fieldHint,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: widget.busy ? CommunityColors.tile : Colors.white,
                prefixIcon: const Icon(LucideIcons.pencil, size: 15, color: AppColors.slate400),
                prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                suffixIcon: e.extension.isEmpty
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Center(widthFactor: 1, child: Text(e.extension, style: CommunityText.personLine)),
                      ),
                suffixIconConstraints: const BoxConstraints(minHeight: 36),
                enabledBorder: outline(CommunityColors.border),
                focusedBorder: outline(AppColors.primary),
                disabledBorder: outline(CommunityColors.border),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            renamed
                ? 'Will be saved as “$typed${e.extension}”'
                : 'Rename it if you like — this is the name members see and download.',
            style: CommunityText.fieldHelp,
          ),
        ],
      ),
    );
  }
}

/// A field that opens a choice in a sheet: the category search and the sub-category and specialization lists.
/// Shown like a text box (a text-input outline), with a clear glyph once something is chosen.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.hint,
    required this.value,
    required this.onOpen,
    required this.onClear,
    this.help,
    this.error,
    this.enabled = true,
  });

  final String label;
  final String hint;
  final String? help;
  final String? value;
  final VoidCallback onOpen;
  final VoidCallback onClear;
  final String? error;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final shown = value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: CommunityText.fieldLabel),
        const SizedBox(height: 5),
        Semantics(
          button: true,
          label: label,
          child: InkWell(
            onTap: enabled ? onOpen : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 42,
              padding: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                color: enabled ? Colors.white : CommunityColors.tile,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: error == null ? CommunityColors.border : AppColors.error),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      shown ?? hint,
                      style: shown == null ? CommunityText.fieldHint : CommunityText.fieldInput,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (shown != null && enabled)
                    IconButton(
                      tooltip: 'Clear ${label.replaceAll(' *', '')}',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(LucideIcons.x, size: 15, color: AppColors.slate400),
                      onPressed: onClear,
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Icon(LucideIcons.chevronDown, size: 16, color: AppColors.slate400),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(error!, style: CommunityText.fieldError),
        ] else if (help != null) ...[
          const SizedBox(height: 4),
          Text(help!, style: CommunityText.fieldHelp),
        ],
      ],
    );
  }
}
