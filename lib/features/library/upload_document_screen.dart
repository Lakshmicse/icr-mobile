import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../chapters/community_kit.dart';
import 'library_format.dart';
import 'library_handoffs.dart';
import 'library_models.dart';
import 'library_repository.dart';
import 'upload_controller.dart';
import 'widgets/document_card.dart';
import 'library_device.dart' show LibraryDeviceSite;

/// Share a document with the library, or (with [target]) add files to one the member shared.
///
/// The form of the website's upload dialog: choose the files first, then describe them. The title starts
/// as the first file's name; a category is required, a sub-category and a specialisation are offered from
/// the platform's own tree with "Other" at the foot of each; files are renamed (the extension stays) and
/// removed in the list; one to ten files of at most 10 MB. Sending uploads each file, then files the
/// document. A refusal is shown and everything typed stays. Pops with the [LibraryDocument] the API
/// answered with, or null when the person backed out.
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
    _c.addListener(_syncTitle);
    _loadTaxonomy();
  }

  Future<void> _loadTaxonomy() async {
    if (_c.appending) return;
    try {
      _c.setOptions(taxonomy: await widget.repository.taxonomy());
    } catch (_) {
      // The tree is a nicety: without it the category is typed.
    }
  }

  /// The title starts as the first file's name, set by the controller: the box follows it.
  void _syncTitle() {
    if (_title.text != _c.title) {
      _title.value = TextEditingValue(
        text: _c.title,
        selection: TextSelection.collapsed(offset: _c.title.length),
      );
    }
  }

  @override
  void dispose() {
    _c.removeListener(_syncTitle);
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

  bool get _dirty => _c.entries.isNotEmpty || _c.title.isNotEmpty || _c.description.isNotEmpty;

  Future<void> _back() async {
    if (_c.busy) return;
    if (_dirty && !_c.appending) {
      final sure = await confirmDialog(
        context,
        title: 'Discard this upload?',
        body: 'The files and words you added will not be kept.',
        action: 'Discard',
      );
      if (!sure || !mounted) return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pick() async {
    final files = await widget.handoffs.device.pickFiles();
    if (files.isEmpty) return;
    _c.pick(files);
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
            title: _c.appending ? 'Add files' : 'Share a document',
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Uploading ${c.uploadingIndex} of ${c.entries.length}…',
                    style: CommunityText.meta.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(percentLabel(c.progress), style: CommunityText.meta),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: c.progress,
                minHeight: 5,
                color: AppColors.primary,
                backgroundColor: CommunityColors.greyPill,
              ),
            ),
            const SizedBox(height: 10),
          ],
          CommunityButton(
            label: c.appending ? 'Add to “${c.target!.title}”' : 'Share with the library',
            icon: LucideIcons.upload,
            expand: true,
            height: 42,
            busy: c.busy,
            onPressed: c.busy ? null : _submit,
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
              Text('They join “${c.target!.title}”', style: CommunityText.body),
              const SizedBox(height: 12),
            ],
            _FilesBox(
              entries: c.entries,
              room: c.room,
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
                help: c.entries.length > 1 ? 'One title for the whole set.' : null,
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
                help: 'What it is and when to reach for it.',
                error: c.problemFor('description'),
                enabled: !c.busy,
                onChanged: c.setDescription,
                fieldKey: const Key('upload-description'),
              ),
              const SizedBox(height: 14),
              _PickerField(
                label: 'Category *',
                hint: 'Choose a category',
                value: c.category,
                options: c.categoryOptions,
                error: c.problemFor('category'),
                enabled: !c.busy,
                onPick: c.setCategory,
              ),
              if (c.category == otherOption) ...[
                const SizedBox(height: 8),
                CommunityField(
                  label: 'Your category',
                  controller: _categoryOther,
                  maxLength: LibraryLimits.category,
                  enabled: !c.busy,
                  onChanged: c.setCategoryOther,
                  fieldKey: const Key('upload-category-other'),
                ),
              ],
              if (c.resolvedCategory.isNotEmpty) ...[
                const SizedBox(height: 14),
                if (c.subcategoryOptions.isNotEmpty) ...[
                  _PickerField(
                    label: 'Sub-category',
                    hint: 'Optional',
                    value: c.subcategory,
                    options: c.subcategoryOptions,
                    error: c.problemFor('subcategory'),
                    enabled: !c.busy,
                    onPick: c.setSubcategory,
                  ),
                  if (c.subcategory == otherOption) ...[
                    const SizedBox(height: 8),
                    CommunityField(
                      label: 'Your sub-category',
                      controller: _subOther,
                      maxLength: LibraryLimits.subcategory,
                      enabled: !c.busy,
                      onChanged: c.setSubcategoryOther,
                    ),
                  ],
                ] else
                  CommunityField(
                    label: 'Sub-category',
                    controller: _subOther,
                    hint: 'Optional',
                    maxLength: LibraryLimits.subcategory,
                    error: c.problemFor('subcategory'),
                    enabled: !c.busy,
                    onChanged: c.setSubcategoryOther,
                    fieldKey: const Key('upload-subcategory-text'),
                  ),
              ],
              if (c.resolvedSubcategory.isNotEmpty) ...[
                const SizedBox(height: 14),
                if (c.specializationOptions.isNotEmpty) ...[
                  _PickerField(
                    label: 'Specialisation',
                    hint: 'Optional',
                    value: c.specialization,
                    options: c.specializationOptions,
                    error: c.problemFor('specialization'),
                    enabled: !c.busy,
                    onPick: c.setSpecialization,
                  ),
                  if (c.specialization == otherOption) ...[
                    const SizedBox(height: 8),
                    CommunityField(
                      label: 'Your specialisation',
                      controller: _specOther,
                      maxLength: LibraryLimits.specialization,
                      enabled: !c.busy,
                      onChanged: c.setSpecializationOther,
                    ),
                  ],
                ] else
                  CommunityField(
                    label: 'Specialisation',
                    controller: _specOther,
                    hint: 'Optional',
                    maxLength: LibraryLimits.specialization,
                    error: c.problemFor('specialization'),
                    enabled: !c.busy,
                    onChanged: c.setSpecializationOther,
                  ),
              ],
            ],
            if (c.error != null) ...[
              const SizedBox(height: 14),
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
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    ];
  }
}

/// The file list: a "Choose files" box while empty, then a row per file (its plate, its editable name,
/// its size, a remove glyph) and "Add more" while there is room.
class _FilesBox extends StatelessWidget {
  const _FilesBox({
    required this.entries,
    required this.room,
    required this.busy,
    required this.uploading,
    required this.problem,
    required this.onPick,
    required this.onRemove,
    required this.onRename,
  });

  final List<UploadEntry> entries;
  final int room;
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
            label: 'Choose files',
            child: InkWell(
              onTap: busy ? null : onPick,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
                decoration: BoxDecoration(
                  color: CommunityColors.tile,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: problem == null ? CommunityColors.border : AppColors.error),
                ),
                child: Column(
                  children: [
                    const Icon(LucideIcons.cloudUpload, size: 30, color: AppColors.primary),
                    const SizedBox(height: 8),
                    Text('Choose files', style: CommunityText.cardTitle),
                    const SizedBox(height: 4),
                    Text(
                      'PDF, Word, Excel, PowerPoint, CSV, text, ZIP or images · up to 10 MB each · up to $room files',
                      textAlign: TextAlign.center,
                      style: CommunityText.personLine,
                    ),
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
        for (final (i, e) in entries.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _FileRow(
              key: ValueKey(e.id),
              entry: e,
              busy: busy,
              active: busy && uploading == i + 1,
              onRemove: () => onRemove(e.id),
              onRename: (n) => onRename(e.id, n),
            ),
          ),
        if (entries.length >= room)
          Text(
            'That is as many files as this document can hold (${LibraryLimits.maxFiles}).',
            style: CommunityText.personLine,
          ),
        if (problem != null) Text(problem!, style: CommunityText.fieldError),
      ],
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final glyph = FileGlyph.of(e.file.mimeType ?? '', e.file.name);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: widget.active ? AppColors.primary : CommunityColors.border),
      ),
      child: Row(
        children: [
          FilePlate(glyph: glyph, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _name,
                        enabled: !widget.busy,
                        style: AppText.plexSans(11.5, FontWeight.w600, AppColors.onSurface, lineHeight: 16),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                        ),
                        onChanged: widget.onRename,
                      ),
                    ),
                    Text(e.extension, style: CommunityText.personLine),
                  ],
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
    );
  }
}

/// A field that opens a list of choices in a sheet: the category pickers.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.hint,
    required this.value,
    required this.options,
    required this.onPick,
    this.error,
    this.enabled = true,
  });

  final String label;
  final String hint;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onPick;
  final String? error;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final shown = value == null ? null : (value == otherOption ? 'Other (add your own)' : value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: CommunityText.fieldLabel),
        const SizedBox(height: 5),
        Semantics(
          button: true,
          label: label,
          child: InkWell(
            onTap: !enabled
                ? null
                : () async {
                    final picked = await pickFromSheet<String>(
                      context,
                      title: label.replaceAll(' *', ''),
                      options: options,
                      label: (o) => o,
                      selected: value,
                    );
                    if (picked != null) onPick(picked);
                  },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
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
                  const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.slate400),
                ],
              ),
            ),
          ),
        ),
        if (error != null) ...[const SizedBox(height: 4), Text(error!, style: CommunityText.fieldError)],
      ],
    );
  }
}
