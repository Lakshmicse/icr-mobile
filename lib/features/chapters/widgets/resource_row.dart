import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_text.dart';
import '../chapter_models.dart';
import '../community_kit.dart';
import '../resource_download.dart';

/// The coloured tag of a resource's kind (PPTX, PDF, XLSX, MP4, FILE), as the website draws it.
Color resourceTagColor(String tag) => switch (tag) {
  'PPTX' => const Color(0xFFB7472A),
  'PDF' => const Color(0xFFC0392B),
  'XLSX' => const Color(0xFF1D6F42),
  'MP4' => const Color(0xFF6B4EA8),
  _ => const Color(0xFF32629E),
};

/// One resource of a chapter or a council (a deck, a whitepaper, a template, a recording), as the website's
/// "Resources & decks" row: the kind's tag, the title with "Whitepaper · 2.4 MB", and an outlined **Download**.
///
/// Download saves the file to the phone through [downloader] (the system "Save as" sheet), where the website's
/// button opens the file's address in a new tab. What the address is decides the rest:
///  * a file: saved, with "Saved" and its name after;
///  * a web page: a recording is a link, and the website opens its address, so [opener] does; any other kind is
///    said to be a page rather than a file, with an "Open page" action for a member who wants it anyway;
///  * anything else (a missing file, an unreachable host, no address): the reason, in the app.
class ResourceRow extends StatefulWidget {
  const ResourceRow({super.key, required this.resource, required this.downloader, required this.opener});

  final ChapterResource resource;
  final ResourceDownloader downloader;

  /// Hands a web page to the browser or the app's web view. Tests give their own.
  final Future<void> Function(BuildContext context, Uri uri) opener;

  @override
  State<ResourceRow> createState() => _ResourceRowState();
}

class _ResourceRowState extends State<ResourceRow> {
  bool _busy = false;

  void _say(ScaffoldMessengerState messenger, String text, {Uri? open, String action = 'Open'}) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          action: open == null
              ? null
              : SnackBarAction(
                  label: action,
                  onPressed: () {
                    if (mounted) widget.opener(context, open);
                  },
                ),
        ),
      );
  }

  Future<void> _download() async {
    if (_busy) return;
    // Kept before the first wait: the member may leave the page while the file is coming.
    final messenger = ScaffoldMessenger.of(context);
    final r = widget.resource;
    setState(() => _busy = true);
    try {
      final outcome = await widget.downloader.fetch(r);
      switch (outcome) {
        case ResourceFileOutcome(:final file):
          final saved = await widget.downloader.save(file);
          if (saved) _say(messenger, 'Saved ${file.fileName}.');
        case ResourcePageOutcome(:final page):
          if (r.kind == 'RECORDING') {
            if (mounted) await widget.opener(context, page);
          } else {
            _say(messenger, '"${r.title}" is a web page, not a file you can save.', open: page, action: 'Open Page');
          }
      }
    } on ResourceDownloadException catch (e) {
      _say(messenger, e.message, open: e.openInstead);
    } catch (_) {
      _say(messenger, 'Unable to download "${r.title}". Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.resource;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: resourceTagColor(r.tag), borderRadius: BorderRadius.circular(8)),
            child: Text(r.tag, style: AppText.plexSans(9, FontWeight.w700, Colors.white, lineHeight: 11)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title, style: CommunityText.personName, maxLines: 2, overflow: TextOverflow.ellipsis),
                Text([r.kindLabel, if (r.sizeLabel != null) r.sizeLabel!].join(' · '), style: CommunityText.personLine),
              ],
            ),
          ),
          const SizedBox(width: 10),
          CommunityButton(
            key: ValueKey('resource-download-${r.id}'),
            label: 'Download',
            icon: LucideIcons.download,
            outlined: true,
            height: 30,
            busy: _busy,
            onPressed: _download,
          ),
        ],
      ),
    );
  }
}
