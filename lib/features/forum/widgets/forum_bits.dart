import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../feed/feed_models.dart';
import '../forum_models.dart';
import '../forum_styles.dart';

/// A small outlined pill: a topic, a kind, a status.
class ForumChip extends StatelessWidget {
  const ForumChip({
    super.key,
    required this.label,
    this.icon,
    this.fill,
    this.border,
    this.ink,
    this.onTap,
    this.height = 24,
  });

  final String label;
  final IconData? icon;
  final Color? fill;
  final Color? border;
  final Color? ink;
  final VoidCallback? onTap;
  final double height;

  /// The green "Answered" chip.
  const ForumChip.success({super.key, required this.label, this.icon, this.onTap, this.height = 24})
    : fill = ForumDesign.successFill,
      border = ForumDesign.successBorder,
      ink = ForumDesign.successInk;

  @override
  Widget build(BuildContext context) {
    final color = ink ?? AppColors.onSurfaceVariant;
    final shape = StadiumBorder(side: BorderSide(color: border ?? AppColors.outlineVariant));
    return Semantics(
      button: onTap != null,
      child: Material(
        color: fill ?? Colors.white,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
                  Text(label, style: ForumDesign.chip.copyWith(color: color)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A banner over a page: moderation, a locked discussion, a refusal.
class ForumNotice extends StatelessWidget {
  const ForumNotice({
    super.key,
    required this.text,
    this.title,
    this.icon,
    this.warn = false,
    this.action,
    this.onAction,
  });

  final String? title;
  final String text;
  final IconData? icon;
  final bool warn;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: warn ? ForumDesign.noticeWarnFill : ForumDesign.noticeInfoFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: warn ? ForumDesign.noticeWarnBorder : AppColors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 15, color: warn ? ForumDesign.noticeWarnInk : AppColors.icon),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) Text(title!, style: ForumDesign.noticeTitle),
                Text(text, style: ForumDesign.notice),
                if (action != null)
                  GestureDetector(
                    onTap: onAction,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(action!, style: AppText.link.copyWith(fontSize: 12)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A centred message with an optional button: empty lists and failed reads.
class ForumMessage extends StatelessWidget {
  const ForumMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: AppColors.outline),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: AppText.postTitle.copyWith(fontSize: 16, height: 1.3)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: AppText.small),
          if (action != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              key: const ValueKey('message-action'),
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.outlineVariant),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(action!, style: AppText.link),
            ),
          ],
        ],
      ),
    );
  }
}

/// The spinner a page shows while it first reads.
class ForumSpinner extends StatelessWidget {
  const ForumSpinner({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4)));
}

/// The file a discussion carries, or one the composer is about to send: a document glyph, the name and the size.
class AttachmentTile extends StatelessWidget {
  const AttachmentTile({super.key, required this.attachment, this.onTap, this.onRemove});

  final ForumAttachment attachment;
  final VoidCallback? onTap;

  /// The x in the composer; absent on a discussion's page.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
          child: Row(
            children: [
              Icon(attachment.isPicture ? LucideIcons.image : LucideIcons.fileText, size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  attachment.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ForumDesign.chip.copyWith(color: AppColors.onSurface),
                ),
              ),
              if (onRemove != null)
                InkResponse(
                  key: const ValueKey('attachment-remove'),
                  onTap: onRemove,
                  radius: 16,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(LucideIcons.x, size: 16, color: AppColors.outline),
                  ),
                )
              else if (onTap != null)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Symbols.open_in_new, size: 16, color: AppColors.outline),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A discussion's photo, a bundled one in the sample content.
class ForumPicture extends StatelessWidget {
  const ForumPicture({super.key, required this.picture, this.fit = BoxFit.cover});

  final FeedPicture picture;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (picture.asset != null) return Image.asset(picture.asset!, fit: fit);
    return CachedNetworkImage(
      imageUrl: picture.url!,
      fit: fit,
      placeholder: (_, _) => const ColoredBox(color: AppColors.surfaceContainer),
      errorWidget: (_, _, _) => const ColoredBox(
        color: AppColors.surfaceContainer,
        child: Center(child: Icon(LucideIcons.imageOff, color: AppColors.outline)),
      ),
    );
  }
}

/// Opens [pictures] full screen, swiping between them and pinching to zoom; [initial] is the one shown first.
Future<void> showImageViewer(BuildContext context, List<FeedPicture> pictures, {int initial = 0}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _ImageViewer(pictures: pictures, initial: initial),
    ),
  );
}

class _ImageViewer extends StatefulWidget {
  const _ImageViewer({required this.pictures, required this.initial});

  final List<FeedPicture> pictures;
  final int initial;

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  late final PageController _controller = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('${_index + 1} of ${widget.pictures.length}', style: AppText.small.copyWith(color: Colors.white)),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.pictures.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: ForumPicture(picture: widget.pictures[i], fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
