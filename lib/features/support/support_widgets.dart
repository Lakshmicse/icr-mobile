import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart' show showMessage;
import '../account/widgets/account_kit.dart';
import '../library/library_models.dart' show DocumentBytes, PreviewKind, previewKindFor;
import '../library/widgets/document_viewer_screen.dart';
import 'support_controller.dart' show refusalOf;
import 'support_models.dart';
import 'support_repository.dart';
import 'support_words.dart';

/// The status as a small chip: a request that waits on the member is amber, so it does not sit quietly beside the
/// ones ICR owes them (`STATUS_META` in the website's `model.ts`).
class SupportStatusChip extends StatelessWidget {
  const SupportStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (color, ink) = switch (status) {
      'NEW' => AccountChip.blue,
      'OPEN' => (AppColors.chipEmphasis, AppColors.primary),
      'AWAITING_USER' => AccountChip.amber,
      'RESOLVED' => AccountChip.green,
      _ => (AppColors.slate100, AppColors.slate600),
    };
    return AccountChip(key: Key('support.status.$status'), label: SupportWords.status(status), color: color, ink: ink);
  }
}

/// A hairline between the rows of a card.
class SupportHairline extends StatelessWidget {
  const SupportHairline({super.key, this.indent = 0});

  final double indent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: indent),
    child: const Divider(height: 1, thickness: 1, color: AppColors.slate200),
  );
}

/// A tinted note: info (blue) or "needs you" (amber).
class SupportNote extends StatelessWidget {
  const SupportNote({super.key, required this.text, this.amber = false, this.icon});

  final String text;
  final bool amber;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ink = amber ? AppColors.amber800 : AppColors.primary;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: amber ? AppColors.amber50 : AppColors.chipEmphasis,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon ?? (amber ? Symbols.error : Symbols.info), size: 18, color: ink),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: AccountText.body.copyWith(color: AppColors.slate900)),
          ),
        ],
      ),
    );
  }
}

/// One article of the knowledge base: the question, and under it (when opened) the answer with "This answered it".
/// An article is counted as read the first time it opens, not when it scrolls past.
class SupportFaqTile extends StatefulWidget {
  const SupportFaqTile({
    super.key,
    required this.faq,
    required this.helpful,
    required this.onOpened,
    required this.onHelpful,
    this.compact = false,
    this.first = false,
  });

  final SupportFaq faq;
  final bool helpful;
  final VoidCallback onOpened;
  final VoidCallback onHelpful;

  /// The inline form the raise sheet uses once a category is picked: no category chip.
  final bool compact;
  final bool first;

  @override
  State<SupportFaqTile> createState() => _SupportFaqTileState();
}

class _SupportFaqTileState extends State<SupportFaqTile> {
  var _open = false;

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) widget.onOpened();
  }

  @override
  Widget build(BuildContext context) {
    final faq = widget.faq;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: widget.first ? BorderSide.none : const BorderSide(color: AppColors.slate200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: Key('support.faq.${faq.id}'),
            onTap: _toggle,
            child: Padding(
              padding: EdgeInsets.fromLTRB(widget.compact ? 0 : 16, 10, widget.compact ? 0 : 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(faq.question, style: widget.compact ? AccountText.label : AccountText.itemTitle),
                  ),
                  if (!widget.compact && faq.category != null) ...[
                    const SizedBox(width: 8),
                    AccountChip(label: SupportWords.category(faq.category!)),
                  ],
                  const SizedBox(width: 4),
                  Icon(_open ? Symbols.expand_less : Symbols.expand_more, size: 22, color: AppColors.slate500),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: EdgeInsets.fromLTRB(widget.compact ? 0 : 16, 0, widget.compact ? 0 : 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(faq.answer, key: Key('support.faq.answer.${faq.id}'), style: AccountText.body),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    key: Key('support.faq.helpful.${faq.id}'),
                    onPressed: widget.helpful ? null : widget.onHelpful,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 34),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Symbols.thumb_up, size: 16),
                    label: Text(widget.helpful ? SupportWords.helpThanks : SupportWords.helpAnswered),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The phone's own file chooser, for a request's attachments: a PDF or a picture. Empty when the person backs out.
Future<List<SupportPickedFile>> pickSupportFiles(int max) async {
  final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: SupportWords.fileExtensions);
  return [for (final f in files.take(max)) SupportPickedFile(bytes: await f.readAsBytes(), name: f.name)];
}

/// "Attach a file", with the files already attached as chips. A file is uploaded the moment it is chosen
/// (`POST /uploads?purpose=support`, stored private) and only its path rides on the message, as the website's
/// `AttachmentPicker` does. At most [SupportWords.maxAttachments], 10 MB each.
class AttachmentTray extends StatefulWidget {
  const AttachmentTray({
    super.key,
    required this.repository,
    required this.files,
    required this.onChanged,
    this.pickFiles,
    this.enabled = true,
  });

  final SupportRepository repository;
  final List<SupportAttachmentDraft> files;
  final ValueChanged<List<SupportAttachmentDraft>> onChanged;
  final FilePickFn? pickFiles;
  final bool enabled;

  @override
  State<AttachmentTray> createState() => _AttachmentTrayState();
}

class _AttachmentTrayState extends State<AttachmentTray> {
  var _uploading = false;
  String? _warning;

  Future<void> _pick() async {
    final room = SupportWords.maxAttachments - widget.files.length;
    if (room <= 0 || _uploading) return;
    List<SupportPickedFile> chosen;
    try {
      chosen = await (widget.pickFiles ?? pickSupportFiles)(room);
    } catch (_) {
      return;
    }
    if (chosen.isEmpty || !mounted) return;
    setState(() {
      _uploading = true;
      _warning = null;
    });
    final next = [...widget.files];
    for (final file in chosen.take(room)) {
      if (file.bytes.length > SupportWords.maxFileBytes) {
        _warning = SupportWords.couldNotUpload(file.name);
        continue;
      }
      try {
        next.add(await widget.repository.upload(file));
      } catch (_) {
        _warning = SupportWords.couldNotUpload(file.name);
      }
    }
    if (!mounted) return;
    setState(() => _uploading = false);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final full = widget.files.length >= SupportWords.maxAttachments;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AccountButton(
              key: const Key('support.attach'),
              label: _uploading ? SupportWords.uploading : SupportWords.attachAFile,
              icon: Symbols.attach_file,
              outlined: true,
              expand: false,
              height: 38,
              busy: _uploading,
              onPressed: widget.enabled && !full ? _pick : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(SupportWords.screenshotsHelp(SupportWords.maxAttachments), style: AccountText.meta)),
          ],
        ),
        if (widget.files.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (i, f) in widget.files.indexed)
                InputChip(
                  key: Key('support.attached.$i'),
                  label: Text(f.fileName, overflow: TextOverflow.ellipsis),
                  labelStyle: AccountText.chip,
                  backgroundColor: AppColors.slate100,
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                  deleteIconColor: AppColors.slate500,
                  onDeleted: widget.enabled
                      ? () => widget.onChanged([
                          for (final other in widget.files)
                            if (other.fileUrl != f.fileUrl) other,
                        ])
                      : null,
                ),
            ],
          ),
        ],
        if (_warning != null)
          Container(
            key: const Key('support.attach.warning'),
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.amber50, borderRadius: BorderRadius.circular(10)),
            child: Text(_warning!, style: AccountText.body.copyWith(color: AppColors.amber800)),
          ),
      ],
    );
  }
}

/// Opens a private attachment in the app: its bytes are read with the session (the phone's browser has none) and
/// drawn in the app's document viewer, as an applicant's résumé is. A type the viewer cannot show says so calmly.
Future<void> openSupportFile(BuildContext context, SupportRepository repository, SupportAttachment file) async {
  final Uint8List bytes;
  try {
    bytes = await repository.fileBytes(file.fileUrl);
  } catch (e) {
    if (context.mounted) showMessage(context, refusalOf(e, SupportWords.couldNotOpenFile));
    return;
  }
  if (!context.mounted) return;
  final kind = previewKindFor(file.mimeType ?? '', file.fileName);
  if (kind == PreviewKind.none) {
    showMessage(context, SupportWords.fileNotShown);
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => DocumentViewerScreen(
        file: DocumentBytes(bytes: bytes, fileName: file.fileName, mimeType: file.mimeType ?? ''),
        kind: kind,
      ),
    ),
  );
}

/// Five stars to give (or show) a score.
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.score, this.onPick, this.size = 30});

  final int score;
  final ValueChanged<int>? onPick;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var n = 1; n <= 5; n++)
          onPick == null
              ? Icon(
                  Symbols.star,
                  fill: n <= score ? 1 : 0,
                  size: size,
                  color: n <= score ? AppColors.amber500 : AppColors.slate300,
                )
              : IconButton(
                  key: Key('support.star.$n'),
                  tooltip: '$n ${n == 1 ? 'star' : 'stars'}',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: size + 8, minHeight: size + 8),
                  onPressed: () => onPick!(n),
                  icon: Icon(
                    Symbols.star,
                    fill: n <= score ? 1 : 0,
                    size: size,
                    color: n <= score ? AppColors.amber500 : AppColors.slate300,
                  ),
                ),
      ],
    );
  }
}
