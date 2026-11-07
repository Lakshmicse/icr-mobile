import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/util/link_spans.dart';
import '../forum_html.dart';

/// A post's body as the forum stores it (sanitised HTML), drawn in the app's type: paragraphs, headings, lists,
/// quotes, code, links, bold and italic. A link opens through [onLink]; the app hands the browser the address.
class ForumRichText extends StatefulWidget {
  const ForumRichText({super.key, required this.html, required this.style, this.onLink, this.paragraphGap = 8});

  final String html;

  /// The body's text style; marks and headings are derived from it.
  final TextStyle style;
  final ValueChanged<String>? onLink;
  final double paragraphGap;

  @override
  State<ForumRichText> createState() => _ForumRichTextState();
}

class _ForumRichTextState extends State<ForumRichText> {
  final _recognizers = <TapGestureRecognizer>[];

  /// The taps of web addresses typed as plain words (a body whose editor never made them links).
  final _typed = LinkSpans();
  late List<RichBlock> _blocks;

  @override
  void initState() {
    super.initState();
    _blocks = parseForumHtml(widget.html);
  }

  @override
  void didUpdateWidget(ForumRichText old) {
    super.didUpdateWidget(old);
    if (old.html != widget.html) _blocks = parseForumHtml(widget.html);
  }

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _typed.dispose();
    super.dispose();
  }

  TextSpan _span(BuildContext context, List<InlineRun> runs, TextStyle base) {
    return TextSpan(
      style: base,
      children: [
        for (final run in runs)
          // A web address typed as plain words is a link too (owner, 5 Nov 2026); code is left as written.
          if (run.href == null && !run.code && LinkSpans.hasLink(run.text))
            TextSpan(
              style: _runStyle(run),
              children: _typed.build(
                context,
                run.text,
                // The page's own opener, which hands an ICR address to the app and any other to the browser.
                onOpen: widget.onLink == null ? null : (uri) => widget.onLink!(uri.toString()),
                linkStyle: _runStyle(run).copyWith(
                  color: AppColors.primary,
                  decoration: TextDecoration.combine([
                    TextDecoration.underline,
                    if (run.strike) TextDecoration.lineThrough,
                  ]),
                ),
              ),
            )
          else
            TextSpan(
              text: run.text,
              style: _runStyle(run).copyWith(color: run.href != null ? AppColors.primary : null),
              recognizer: run.href == null ? null : _linkTap(run.href!),
            ),
      ],
    );
  }

  TextStyle _runStyle(InlineRun run) => TextStyle(
    fontWeight: run.bold ? FontWeight.w700 : null,
    fontStyle: run.italic ? FontStyle.italic : null,
    decoration: TextDecoration.combine([
      // A tagged member reads as blue "@Name", as on the cards; every other link is underlined.
      if (run.underline && !_isMember(run.href)) TextDecoration.underline,
      if (run.strike) TextDecoration.lineThrough,
    ]),
    fontFamily: run.code ? 'monospace' : null,
    backgroundColor: run.code ? AppColors.surfaceContainer : null,
  );

  static bool _isMember(String? href) => href != null && href.startsWith('/members/');

  TapGestureRecognizer _linkTap(String href) {
    // A page of the website without its address (a tagged member) is the website's page for the app's routes.
    final target = href.startsWith('/') ? AppConfig.sitePage(href).toString() : href;
    final recognizer = TapGestureRecognizer()..onTap = () => widget.onLink?.call(target);
    _recognizers.add(recognizer);
    return recognizer;
  }

  @override
  Widget build(BuildContext context) {
    // Recognizers belong to the spans built below; a rebuild makes new ones.
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    _typed.clear();
    final base = widget.style;
    final children = <Widget>[];
    for (final (i, block) in _blocks.indexed) {
      if (i > 0) {
        final tight = block.kind == BlockKind.listItem && _blocks[i - 1].kind == BlockKind.listItem;
        children.add(SizedBox(height: tight ? 3 : widget.paragraphGap));
      }
      children.add(switch (block.kind) {
        BlockKind.paragraph => Text.rich(_span(context, block.runs, base)),
        BlockKind.heading => Text.rich(
          _span(
            context,
            block.runs,
            base.copyWith(
              fontFamily: AppText.work,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
              fontSize: (base.fontSize ?? 12.5) + (block.level <= 2 ? 3 : 1.5),
              height: 1.35,
            ),
          ),
        ),
        BlockKind.listItem => Padding(
          padding: EdgeInsets.only(left: 4.0 + 14.0 * block.depth),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 18, child: Text(block.ordinal == null ? '•' : '${block.ordinal}.', style: base)),
              Expanded(child: Text.rich(_span(context, block.runs, base))),
            ],
          ),
        ),
        BlockKind.quote => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(6)),
          child: Text.rich(
            _span(context, block.runs, base.copyWith(color: AppColors.outline, fontStyle: FontStyle.italic)),
          ),
        ),
        BlockKind.codeBlock => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(6)),
          child: Text(
            block.text,
            style: base.copyWith(fontFamily: 'monospace', fontSize: (base.fontSize ?? 12.5) - 1),
          ),
        ),
      });
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}
