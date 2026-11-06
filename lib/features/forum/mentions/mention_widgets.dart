import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/util/link_spans.dart';
import '../../feed/feed_models.dart';
import '../../feed/widgets/feed_avatar.dart';
import 'mention_controller.dart';
import 'mention_text.dart';

/// The people the "@" being typed may mean: a list (photo, name, headline) of up to eight, a row saying it is
/// searching, or "No one found". Draws nothing while [MentionController.open] is false. Put it above the field it
/// belongs to (a reply bar sits over the keyboard, so the list reads upward) or docked above the keyboard.
class MentionSuggestions extends StatelessWidget {
  const MentionSuggestions({super.key, required this.controller, this.maxHeight = 236, this.margin = EdgeInsets.zero});

  final MentionController controller;

  /// The list scrolls past this height.
  final double maxHeight;
  final EdgeInsets margin;

  static final _name = AppText.plexSans(14, FontWeight.w600, AppColors.onSurface, lineHeight: 18);
  static final _headline = AppText.plexSans(12, FontWeight.w400, AppColors.outline, lineHeight: 16);
  static final _note = AppText.plexSans(13, FontWeight.w500, AppColors.outline, lineHeight: 18);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.open) return const SizedBox.shrink();
        final results = controller.results;
        final Widget body;
        if (results.isNotEmpty) {
          body = ListView(
            key: const ValueKey('mention-suggestions'),
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            children: [for (final person in results) _Row(person: person, onTap: () => controller.pick(person))],
          );
        } else if (controller.loading || controller.resultsFor == null) {
          body = const _Note(key: ValueKey('mention-loading'), text: 'Searching people…', spinner: true);
        } else if (controller.failed) {
          body = const _Note(key: ValueKey('mention-failed'), text: "Couldn't search people just now.");
        } else if ((controller.query?.search.length ?? 0) < 2) {
          body = const _Note(key: ValueKey('mention-hint'), text: 'Type a name to tag someone.');
        } else {
          body = const _Note(key: ValueKey('mention-empty'), text: 'No one found');
        }
        // Taps in the list belong to the field's own tap region, so the field keeps its focus (and the keyboard).
        return TextFieldTapRegion(
          child: Container(
            key: const ValueKey('mention-panel'),
            margin: margin,
            constraints: BoxConstraints(maxHeight: maxHeight),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 10, offset: Offset(0, 2))],
            ),
            clipBehavior: Clip.antiAlias,
            child: Material(color: Colors.transparent, child: body),
          ),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.person, required this.onTap});

  final MentionPerson person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final author = person.author;
    return Semantics(
      button: true,
      label: 'Tag ${author.name}',
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('mention-option:${person.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              FeedAvatar(photo: author.photo, initials: author.initials, size: 36, label: author.name),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(author.name, style: MentionSuggestions._name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (author.headline != null)
                      Text(
                        author.headline!,
                        style: MentionSuggestions._headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({super.key, required this.text, this.spinner = false});

  final String text;
  final bool spinner;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          if (spinner) ...[
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
          ],
          Expanded(child: Text(text, style: MentionSuggestions._note)),
        ],
      ),
    );
  }
}

/// Escape closes the picker while it is open (a hardware keyboard); every other key goes on to the field.
class MentionEscape extends StatelessWidget {
  const MentionEscape({super.key, required this.controller, required this.child});

  final MentionController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape && controller.open) {
          controller.dismiss();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}

/// The blue, tappable "@Name" of a tagged member, as a post or a reply prints it.
const mentionLinkStyle = TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600);

/// Builds the spans of a text whose tagged members open their profile, and owns the tap recognizers they need.
/// Call [clear] before building again, and [dispose] with the widget.
class MentionSpans {
  final _recognizers = <TapGestureRecognizer>[];

  /// [text] as spans: each of [mentions] still in it as a link to [onOpen] (plain, when [onOpen] is null).
  List<InlineSpan> build(String text, List<Mention> mentions, {ValueChanged<String>? onOpen}) {
    final found = onOpen == null ? const <MentionSpan>[] : mentionSpans(text, mentions);
    return spansFor(text, found, onOpen: onOpen);
  }

  /// [text] as spans, with the already-placed [found] mentions (offsets into [text]) as links to [onOpen].
  List<InlineSpan> spansFor(String text, List<MentionSpan> found, {ValueChanged<String>? onOpen}) {
    if (found.isEmpty || onOpen == null) return [TextSpan(text: text)];
    final spans = <InlineSpan>[];
    var at = 0;
    for (final s in found) {
      if (s.start > at) spans.add(TextSpan(text: text.substring(at, s.start)));
      final tap = TapGestureRecognizer()..onTap = () => onOpen(s.mention.id);
      _recognizers.add(tap);
      spans.add(TextSpan(text: text.substring(s.start, s.end), style: mentionLinkStyle, recognizer: tap));
      at = s.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return spans;
  }

  void clear() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  void dispose() => clear();
}

/// Words with the members tagged in them as links to their profile ([onOpen] gets the member's id), and every web
/// address typed in them a link that opens (owner, 5 Nov 2026): an ICR address in the app's own screen, any other in
/// the phone's browser (`openUrl`). With no [mentions] or no [onOpen], and no address, it is a plain [Text].
class MentionText extends StatefulWidget {
  const MentionText({
    super.key,
    required this.text,
    required this.style,
    this.mentions = const [],
    this.onOpen,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle style;
  final List<Mention> mentions;
  final ValueChanged<String>? onOpen;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  State<MentionText> createState() => _MentionTextState();
}

class _MentionTextState extends State<MentionText> {
  final _spans = MentionSpans();
  final _links = LinkSpans();

  @override
  void dispose() {
    _spans.dispose();
    _links.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _spans.clear();
    _links.clear();
    final text = widget.text;
    final tagged = widget.mentions.isNotEmpty && widget.onOpen != null;
    final linked = LinkSpans.hasLink(text);
    if (!tagged && !linked) {
      return Text(text, style: widget.style, maxLines: widget.maxLines, overflow: widget.overflow);
    }
    // Mentions are placed on the whole text (a namesake is told apart by order), then each plain run between
    // addresses takes the ones that fall inside it.
    final found = tagged ? mentionSpans(text, widget.mentions) : const <MentionSpan>[];
    final children = !linked
        ? _spans.spansFor(text, found, onOpen: widget.onOpen)
        : () {
            final starts = <int>[];
            var at = 0;
            for (final part in splitLinks(text)) {
              if (part.link == null) starts.add(at);
              at += part.text.length;
            }
            var run = 0;
            return _links.build(
              context,
              text,
              plain: (part) {
                final from = starts[run++];
                final inside = [
                  for (final s in found)
                    if (s.start >= from && s.end <= from + part.length)
                      (start: s.start - from, end: s.end - from, mention: s.mention),
                ];
                return _spans.spansFor(part, inside, onOpen: widget.onOpen);
              },
            );
          }();
    return Text.rich(
      TextSpan(style: widget.style, children: children),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}
