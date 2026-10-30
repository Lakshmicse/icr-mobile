import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import '../chapters/community_kit.dart';
import 'document_controller.dart';
import 'library_format.dart';
import 'library_handoffs.dart';
import 'library_models.dart';
import 'library_repository.dart';
import 'screen_security.dart';
import 'upload_document_screen.dart';
import 'widgets/document_card.dart';
import 'widgets/document_viewer_screen.dart';
import 'widgets/report_sheet.dart';
import 'library_device.dart' show LibraryDeviceSite;

/// A document's page with its own [DocumentController] on [repository]: what the shell pushes for a
/// document named by its id (a notification, a card). [initial] is the document when the caller already
/// holds it (the list does), so the page opens at once; without it the library is read for it, since the
/// API has no `GET /documents/:id`. [onChanged] and [onRemoved] tell the list behind it.
Widget documentPage({
  required LibraryRepository repository,
  required String documentId,
  LibraryDocument? initial,
  LibraryHandoffs handoffs = const LibraryHandoffs(),
  VoidCallback? onBack,
  ValueChanged<LibraryDocument>? onChanged,
  ValueChanged<String>? onRemoved,
}) {
  return ChangeNotifierProvider<DocumentController>(
    create: (_) => DocumentController(
      repository: repository,
      documentId: documentId,
      initial: initial,
      onChanged: onChanged,
      onRemoved: onRemoved,
    ),
    child: Builder(
      builder: (context) => DocumentScreen(
        repository: repository,
        handoffs: handoffs,
        onBack: onBack ?? () => Navigator.of(context).pop(),
      ),
    ),
  );
}

/// Pushes a document's page over the current screen.
Future<void> openDocumentPage(
  BuildContext context, {
  required LibraryRepository repository,
  required String documentId,
  LibraryDocument? initial,
  LibraryHandoffs handoffs = const LibraryHandoffs(),
  ValueChanged<LibraryDocument>? onChanged,
  ValueChanged<String>? onRemoved,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (route) => documentPage(
        repository: repository,
        documentId: documentId,
        initial: initial,
        handoffs: handoffs,
        onChanged: onChanged,
        onRemoved: onRemoved,
        onBack: () => Navigator.of(route).pop(),
      ),
    ),
  );
}

/// One document: who shared it and when, the numbers, its description, and each of its files with a
/// Preview that opens it in the app. **There is no Download**: the library is view-only on a phone (owner's
/// call, 28 Oct 2026), and the screen keeps the window out of screenshots and recordings while it is up. The
/// member who shared it (or a SUPER_ADMIN) may add files, drop one and delete it; anyone else may report it.
/// A refusal that says the plan does not open it is the lock card, in the server's own words.
///
/// Reads a [DocumentController] from Provider and starts it on first build.
class DocumentScreen extends StatefulWidget {
  const DocumentScreen({
    super.key,
    required this.repository,
    required this.onBack,
    this.handoffs = const LibraryHandoffs(),
  });

  final LibraryRepository repository;
  final VoidCallback onBack;
  final LibraryHandoffs handoffs;

  @override
  State<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends State<DocumentScreen> {
  @override
  void initState() {
    super.initState();
    final c = context.read<DocumentController>();
    if (!c.started) c.start();
  }

  void _bell() {
    final go = widget.handoffs.onBell;
    if (go != null) return go();
    widget.handoffs.device.openPage(context, AppConfig.sitePage('/notifications'));
  }

  LibraryHandoffs get _h => widget.handoffs;

  /// Reads one file and shows it in the app's own viewer. The bytes go to the viewer and nowhere else: they
  /// are never saved, shared or handed to another app.
  Future<void> _preview(DocumentController c, LibraryFile file) async {
    final kind = file.previewKind;
    if (kind == PreviewKind.none) return;
    final out = await c.preview(file);
    if (!mounted) return;
    final bytes = out.file;
    if (bytes == null) {
      if (!out.locked) showMessage(context, out.error ?? 'Could not open that file.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DocumentViewerScreen(file: bytes, kind: kind, pdf: _h.pdf, runner: _h.runner),
      ),
    );
  }

  Future<void> _report(DocumentController c) async {
    final d = c.document;
    if (d == null) return;
    await showReportSheet(
      context,
      title: d.title,
      send: (reason, note) => c.report(reason, note: note),
    );
  }

  Future<void> _delete(DocumentController c) async {
    final d = c.document;
    if (d == null) return;
    final sure = await confirmDialog(
      context,
      title: 'Delete “${d.title}”?',
      body: 'It leaves the library for everyone, and its ${filesLabel(d.fileCount)} with it. This cannot be undone.',
      action: 'Delete',
    );
    if (!sure || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final problem = await c.delete();
    if (!mounted) return;
    if (problem != null) return showMessage(context, problem);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('“${d.title}” was deleted.')));
    widget.onBack();
  }

  Future<void> _removeFile(DocumentController c, LibraryFile file) async {
    final sure = await confirmDialog(
      context,
      title: 'Remove ${file.fileName}?',
      body: 'The rest of the document stays.',
      action: 'Remove',
    );
    if (!sure || !mounted) return;
    final problem = await c.removeFile(file);
    if (problem != null && mounted) showMessage(context, problem);
  }

  Future<void> _addFiles(DocumentController c) async {
    final d = c.document;
    if (d == null) return;
    final doc = await Navigator.of(context).push<LibraryDocument>(
      MaterialPageRoute(
        builder: (_) => UploadDocumentScreen(repository: widget.repository, target: d, handoffs: _h),
      ),
    );
    if (doc != null) c.filesAdded(doc);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DocumentController>();
    return ScreenGuard(
      child: CommunityPage(
        title: 'Document',
        onBack: widget.onBack,
        onBell: _bell,
        onRefresh: c.refresh,
        children: _body(c),
      ),
    );
  }

  List<Widget> _body(DocumentController c) {
    final d = c.document;
    if (d == null) {
      if (c.loading || !c.started) return const [CommunityLoading()];
      return [
        CommunityNotice(
          icon: LucideIcons.fileX,
          title: "Couldn't load this document",
          body: c.error ?? 'Something went wrong.',
          action: 'Try again',
          onAction: c.refresh,
        ),
      ];
    }
    final first = d.first;
    final room = LibraryLimits.maxFiles - d.fileCount;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FilePlate(glyph: first?.glyph ?? FileGlyph.fallback, size: 52, count: d.fileCount),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.title, style: CommunityText.cardTitleLarge),
                      const SizedBox(height: 4),
                      if (d.categoryPath != null) Text(d.categoryPath!, style: CommunityText.personRole),
                    ],
                  ),
                ),
              ],
            ),
            if (d.uploader != null) ...[
              const SizedBox(height: 14),
              _UploaderRow(
                document: d,
                mine: c.isMine,
                onOpen: _h.onOpenMember == null ? null : () => _h.onOpenMember!(d.uploaderId),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 14),
      CommunityStatGrid(
        tiles: [
          CommunityStatTile(label: 'Views', value: groupThousands(d.viewCount)),
          CommunityStatTile(label: 'Downloads', value: groupThousands(d.downloadCount), blue: true),
          CommunityStatTile(label: 'Size', value: fileSizeLabel(d.totalSizeBytes)),
          CommunityStatTile(label: 'Files', value: '${d.fileCount}', note: d.formats.join(', ')),
        ],
      ),
      if (c.lockMessage != null) ...[
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _LockCard(message: c.lockMessage!, onPlans: _h.onOpenPlans),
        ),
      ],
      const SizedBox(height: 14),
      const Divider(height: 1, thickness: 1, color: CommunityColors.tileRule),
      const SizedBox(height: 14),
      const CommunitySectionHeading(title: 'About this document'),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          d.description ?? 'The person who shared this did not add a description.',
          style: d.description == null ? CommunityText.small : CommunityText.body,
        ),
      ),
      const SizedBox(height: 16),
      const Divider(height: 1, thickness: 1, color: CommunityColors.tileRule),
      const SizedBox(height: 14),
      CommunitySectionHeading(title: d.isPack ? 'Files' : 'File', pill: d.isPack ? '${d.fileCount}' : null),
      const SizedBox(height: 8),
      for (final f in d.files)
        _FileRow(
          file: f,
          busy: c.isBusy(f.id),
          canRemove: c.mayChange && d.fileCount > 1,
          onPreview: () => _preview(c, f),
          onRemove: () => _removeFile(c, f),
        ),
      if (c.mayChange && room > 0)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: CommunityButton(
            label: 'Add files',
            icon: LucideIcons.filePlus,
            outlined: true,
            expand: true,
            height: 38,
            onPressed: () => _addFiles(c),
          ),
        ),
      const SizedBox(height: 18),
      const Divider(height: 1, thickness: 1, color: CommunityColors.tileRule),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            CommunityButton(
              label: 'Share',
              icon: LucideIcons.share2,
              outlined: true,
              height: 36,
              onPressed: () => _h.share(d.title, widget.repository.link()),
            ),
            if (!c.isMine)
              CommunityButton(
                label: c.reported ? 'Reported' : 'Report',
                icon: LucideIcons.flag,
                outlined: true,
                height: 36,
                busy: c.isBusy('report'),
                onPressed: c.reported ? null : () => _report(c),
              ),
            if (c.mayChange)
              CommunityButton(
                label: 'Delete',
                icon: LucideIcons.trash2,
                outlined: true,
                color: AppColors.error,
                height: 36,
                busy: c.isBusy('delete'),
                onPressed: () => _delete(c),
              ),
          ],
        ),
      ),
      const SizedBox(height: 28),
    ];
  }
}

class _UploaderRow extends StatelessWidget {
  const _UploaderRow({required this.document, required this.mine, required this.onOpen});

  final LibraryDocument document;
  final bool mine;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final u = document.uploader!;
    return InkWell(
      onTap: onOpen,
      child: Row(
        children: [
          PersonAvatar(initials: u.initials, photo: u.photo, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Shared by ${u.name}',
                        style: CommunityText.personName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (mine) ...[
                      const SizedBox(width: 6),
                      CommunityPill(
                        label: 'YOU',
                        fill: CommunityColors.blue50,
                        style: CommunityText.pill.copyWith(color: CommunityColors.blue700),
                        height: 16,
                      ),
                    ],
                  ],
                ),
                Text(
                  [
                    if (u.title != null) u.title!,
                    if (document.createdAt != null) shortDate(document.createdAt!),
                  ].join(' · '),
                  style: CommunityText.personLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onOpen != null) const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.slate400),
        ],
      ),
    );
  }
}

/// The server's refusal when the plan does not open the document: its sentence, and the way to the plans
/// when the shell wired one.
class _LockCard extends StatelessWidget {
  const _LockCard({required this.message, required this.onPlans});

  final String message;
  final VoidCallback? onPlans;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CommunityColors.amber50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCD9A0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.lock, size: 18, color: CommunityColors.amber700),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Not included in your plan',
                  style: CommunityText.cardTitle.copyWith(color: CommunityColors.amber700),
                ),
                const SizedBox(height: 3),
                Text(message, style: CommunityText.body),
                if (onPlans != null) ...[
                  const SizedBox(height: 8),
                  CommunityButton(label: 'See plans', height: 32, onPressed: onPlans),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.file,
    required this.busy,
    required this.canRemove,
    required this.onPreview,
    required this.onRemove,
  });

  final LibraryFile file;
  final bool busy;
  final bool canRemove;
  final VoidCallback onPreview;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final f = file;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: CommunityCard(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                FilePlate(glyph: f.glyph, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.fileName, style: CommunityText.personName, maxLines: 2, overflow: TextOverflow.ellipsis),
                      Text(
                        '${f.fileType.label} · ${fileSizeLabel(f.sizeBytes)} · ${f.downloadCount == 1 ? '1 download' : '${groupThousands(f.downloadCount)} downloads'}',
                        style: CommunityText.personLine,
                      ),
                    ],
                  ),
                ),
                if (canRemove)
                  IconButton(
                    tooltip: 'Remove ${f.fileName}',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.slate500),
                    onPressed: busy ? null : onRemove,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (f.canPreview)
              CommunityButton(
                label: 'Preview',
                icon: LucideIcons.eye,
                expand: true,
                height: 34,
                busy: busy,
                onPressed: onPreview,
              )
            else
              // Word, Excel, PowerPoint and archives have no viewer in the app, and nothing can be saved, so
              // there is nothing to offer: say so rather than draw a button that does nothing.
              Row(
                children: [
                  const Icon(LucideIcons.eyeOff, size: 15, color: AppColors.slate500),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text("${f.fileType.label} files can't be previewed in the app.", style: CommunityText.small),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
