import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../forum/mentions/mention_controller.dart';
import '../../forum/mentions/mention_widgets.dart';
import '../feed_models.dart';
import '../feed_styles.dart';
import 'feed_avatar.dart';

/// What is left of the old reply section now that a comment is drawn as LinkedIn's (`comment_widgets.dart`,
/// 13 Nov 2026): the worded action beside a comment's glyphs (Accept answer) and the box a comment is typed in.

/// An icon and a word under a reply: Like (with its count) and Reply.
class ReplyAction extends StatelessWidget {
  const ReplyAction({
    super.key,
    required this.icon,
    required this.label,
    required this.semantics,
    required this.onTap,
    this.active = false,
    this.color,
    this.compact = false,
    this.iconSize,
    this.gap,
  });

  final IconData icon;
  final String label;
  final String semantics;
  final VoidCallback? onTap;
  final bool active;
  final Color? color;

  /// The Home feed's LinkedIn-style word under a comment (12 sp Roboto, 60 % black).
  final bool compact;
  final double? iconSize;
  final double? gap;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? (active ? AppColors.primary : (compact ? HomeLook.soft : AppColors.outline));
    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: compact ? 28 : ReplyDesign.actionsHeight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: iconSize ?? (compact ? 16 : 14), color: tint),
              SizedBox(width: gap ?? (compact ? 4 : 3.3)),
              Text(label, style: (compact ? HomeType.replyAction : ReplyDesign.action).copyWith(color: tint)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The reply box: the reader's photo, a pale pill to type in, and the send arrow. [hint] says whom the reply
/// goes to ("Reply to Priya Nambiar...").
class ReplyBox extends StatelessWidget {
  const ReplyBox({
    super.key,
    required this.viewer,
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.hint,
    required this.onSend,
    this.enabled = true,
    this.look = ReplyLook.section,
    this.newlines = false,
    this.mentions,
  });

  /// The "@" picker for this box: its list opens above the box while a name is being typed, and a pick puts
  /// "@First Last " in the words. Absent, "@" is just a character.
  final MentionController? mentions;

  final FeedAuthor viewer;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final String hint;
  final VoidCallback onSend;
  final bool enabled;
  final ReplyLook look;

  /// The keyboard's Enter writes a new line (the send arrow sends), as a page where replies run to paragraphs
  /// wants; off, Enter sends, as the Home feed's one-line box does.
  final bool newlines;

  Widget _field(bool home) {
    final field = TextField(
      key: const ValueKey('reply-input'),
      controller: controller,
      focusNode: focusNode,
      enabled: enabled && !sending,
      minLines: 1,
      maxLines: 4,
      style: home ? HomeType.replyInput : ReplyDesign.input,
      textInputAction: newlines ? TextInputAction.newline : TextInputAction.send,
      keyboardType: newlines ? TextInputType.multiline : null,
      textCapitalization: TextCapitalization.sentences,
      onSubmitted: newlines ? null : (_) => onSend(),
      decoration: InputDecoration(
        isCollapsed: true,
        border: InputBorder.none,
        hintText: hint,
        hintStyle: home ? HomeType.replyHint : ReplyDesign.hint,
        hintMaxLines: 1,
        contentPadding: EdgeInsets.symmetric(vertical: home ? 9 : 6),
      ),
    );
    return mentions == null ? field : MentionEscape(controller: mentions!, child: field);
  }

  @override
  Widget build(BuildContext context) {
    final box = _box(context);
    final picker = mentions;
    if (picker == null) return box;
    // The list opens above the box: the box sits over the keyboard (or at the foot of a card), so there is no room under it.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MentionSuggestions(controller: picker, margin: const EdgeInsets.only(bottom: 6)),
        box,
      ],
    );
  }

  Widget _box(BuildContext context) {
    final home = look == ReplyLook.home;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: home ? 4 : 3.5),
          child: FeedAvatar(photo: viewer.photo, initials: viewer.initials, size: home ? HomeReplyDesign.avatar : 24),
        ),
        SizedBox(width: home ? HomeReplyDesign.bubbleGap : 7),
        Expanded(
          child: Container(
            constraints: BoxConstraints(minHeight: home ? HomeReplyDesign.boxHeight : 31),
            decoration: BoxDecoration(
              color: home ? Colors.white : ReplyDesign.pillFill,
              borderRadius: BorderRadius.circular(home ? 20 : 15.5),
              border: Border.all(color: home ? HomeReplyDesign.inputBorder : ReplyDesign.inputBorder, width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(width: home ? 16 : 12.2),
                Expanded(child: _field(home)),
                Semantics(
                  button: true,
                  label: 'Send reply',
                  excludeSemantics: true,
                  child: InkResponse(
                    key: const ValueKey('reply-send'),
                    onTap: sending || !enabled ? null : onSend,
                    radius: 18,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(6, 5, home ? 12 : 10.75, 5),
                      child: sending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: Padding(
                                padding: EdgeInsets.all(1),
                                child: CircularProgressIndicator(strokeWidth: 1.6),
                              ),
                            )
                          : home
                          // The arrow is grey until there is something to send.
                          ? ListenableBuilder(
                              listenable: controller,
                              builder: (context, _) => Icon(
                                LucideIcons.send,
                                size: 20,
                                color: enabled && controller.text.trim().isNotEmpty ? AppColors.primary : HomeLook.soft,
                              ),
                            )
                          : Icon(Symbols.send, size: 16, color: enabled ? AppColors.primary : AppColors.outline),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
