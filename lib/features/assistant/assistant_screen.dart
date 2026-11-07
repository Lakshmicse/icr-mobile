import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/auth/session_user.dart';
import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/util/links.dart' show SiteRoutes, openSitePage;
import '../../core/widgets/section_heading.dart' show Hairline;
import '../career/career_format.dart' show formatTime;
import 'assistant_controller.dart';
import 'assistant_models.dart';

/// Saathi, ICR's assistant, as a page of its own (the website's chat panel, made for a phone): the conversation
/// as LinkedIn's messaging draws one — full-width rows on white, an avatar, the name and the time, the words in
/// dark grey, a thin line between turns, no bubbles — the pages a reply points to as small pills under it, the
/// page's suggestion chips above the composer, and the composer. Owner's rules (6 Nov 2026): white throughout,
/// dark and light grey text, line breaks instead of boxes, the whole width.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({
    super.key,
    required this.controller,
    required this.context,
    this.user,
    this.onOpenPage,
    this.opens,
    this.onBack,
  });

  final AssistantController controller;

  /// Where the person came from, sent with every question.
  final AssistantContext context;

  /// The signed-in person, for their own rows; null when signed out.
  final SessionUser? user;

  /// Opens a page a reply or a chip points to; the app's own screen for it by default.
  final void Function(BuildContext context, String href)? onOpenPage;

  /// Whether the app draws the page a reply or a chip points to. A page it does not is not offered at all (owner,
  /// 7 Nov 2026: Saathi's "About ICR" opened the website in the web view, and Back from it showed `/robots.txt` —
  /// "should not redirect to the website in any condition"). By default what the app's own routes say
  /// ([SiteRoutes.hasScreen]); everything while none are set (a test).
  final bool Function(String href)? opens;
  final VoidCallback? onBack;

  static bool _appDraws(String href) => SiteRoutes.hasScreen(AppConfig.sitePage(href)) ?? true;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  var _count = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.open();
    widget.controller.addListener(_onChange);
    _count = widget.controller.messages.length;
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// A new turn, or words arriving on the reply: the list follows them down.
  void _onChange() {
    final grew = widget.controller.messages.length != _count || widget.controller.streaming;
    _count = widget.controller.messages.length;
    if (grew) _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send([String? asked]) async {
    final text = (asked ?? _input.text).trim();
    if (text.isEmpty || widget.controller.streaming) return;
    if (asked == null) _input.clear();
    await widget.controller.send(text, widget.context);
  }

  bool _opens(String href) => (widget.opens ?? AssistantScreen._appDraws)(href);

  void _open(String href) {
    if (!_opens(href)) return;
    final open = widget.onOpenPage;
    if (open != null) return open(context, href);
    unawaited(openSitePage(context, href));
  }

  void _onSuggestion(AssistantSuggestion s) {
    if (s.isPage) {
      _open(s.href!);
    } else {
      unawaited(_send(s.ask));
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = [
      for (final s in suggestionsFor(widget.context))
        if (!s.isPage || _opens(s.href!)) s,
    ];
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(onBack: widget.onBack ?? () => Navigator.maybePop(context)),
            Expanded(
              child: ListenableBuilder(
                listenable: widget.controller,
                builder: (context, _) {
                  final messages = widget.controller.messages;
                  // The page's chips sit under the latest reply, where the eye is, rather than pinned above the
                  // composer with the page's empty middle between (owner, 6 Nov 2026: "a lot of space wasted").
                  final chips = suggestions.isNotEmpty && !widget.controller.streaming;
                  return ListView.separated(
                    key: const ValueKey('assistant-messages'),
                    controller: _scroll,
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    itemCount: messages.length + (chips ? 1 : 0),
                    separatorBuilder: (_, i) =>
                        i < messages.length - 1 ? const Hairline(indent: 16, endIndent: 16) : const SizedBox.shrink(),
                    itemBuilder: (context, i) {
                      if (i == messages.length) {
                        return _Suggestions(suggestions: suggestions, onPick: _onSuggestion);
                      }
                      final m = messages[i];
                      final typing = i == messages.length - 1 && widget.controller.awaitingFirstWord;
                      return _Turn(
                        key: ValueKey('turn-$i'),
                        message: m,
                        user: widget.user,
                        typing: typing,
                        onOpen: _open,
                        opens: _opens,
                      );
                    },
                  );
                },
              ),
            ),
            const Hairline(),
            ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) => _Composer(
                controller: _input,
                focus: _focus,
                canSend: _input.text.trim().isNotEmpty && !widget.controller.streaming,
                onSend: _send,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The 56 dp bar: back, Saathi's mark, the name and "Online".
class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Back',
            child: InkWell(
              key: const ValueKey('assistant-back'),
              onTap: onBack,
              child: const SizedBox(
                width: 56,
                height: 56,
                child: Icon(Symbols.arrow_back, size: 24, color: AppColors.onSurfaceVariant),
              ),
            ),
          ),
          const SaathiMark(size: 34),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(assistantName, style: AppText.barTitle),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(color: AppColors.online, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    AssistantCopy.online,
                    style: AppText.plexSans(11, FontWeight.w500, AppColors.outline, lineHeight: 14),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Saathi's mark: a brand-blue circle with a headset, as the website's `AssistantAvatar`.
class SaathiMark extends StatelessWidget {
  const SaathiMark({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: '$assistantName assistant',
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3B82C4), AppColors.primary],
          ),
        ),
        child: Icon(LucideIcons.headset, size: size * 0.52, color: Colors.white),
      ),
    );
  }
}

/// One turn, as LinkedIn draws a message: the avatar, the name and the time, the words; a reply's pages under it.
class _Turn extends StatelessWidget {
  const _Turn({
    super.key,
    required this.message,
    required this.user,
    required this.typing,
    required this.onOpen,
    required this.opens,
  });

  final AssistantMessage message;
  final SessionUser? user;
  final bool typing;
  final ValueChanged<String> onOpen;

  /// Which of the reply's pages the app draws: only those get a pill.
  final bool Function(String href) opens;

  @override
  Widget build(BuildContext context) {
    final mine = !message.isAssistant;
    final name = mine ? 'You' : assistantName;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          mine ? _PersonAvatar(user: user) : const SaathiMark(size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: AppText.workSans(14, FontWeight.w600, AppColors.onSurface, lineHeight: 18)),
                    if (message.at != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        formatTime(message.at!),
                        style: AppText.plexSans(11, FontWeight.w500, AppColors.outline, lineHeight: 14),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                if (typing)
                  const _TypingDots(key: ValueKey('assistant-typing'))
                else
                  SelectableText(
                    message.content,
                    style: AppText.plexSans(14, FontWeight.w400, AppColors.onSurfaceVariant, lineHeight: 20),
                  ),
                if (message.actions.any((a) => opens(a.href))) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final a in message.actions)
                        if (opens(a.href))
                          _Pill(
                            key: ValueKey('action-${a.href}'),
                            label: a.label,
                            icon: LucideIcons.arrowUpRight,
                            onTap: () => onOpen(a.href),
                          ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The signed-in person's photo, or their initials; a visitor's plain glyph.
class _PersonAvatar extends StatelessWidget {
  const _PersonAvatar({required this.user});

  final SessionUser? user;

  @override
  Widget build(BuildContext context) {
    // The photo's address is stored root-relative (`/uploads/…`); their initials stand in while it loads or fails.
    final photo = AppConfig.absoluteUrl(user?.avatarUrl);
    final fallback = ColoredBox(
      color: AppColors.chipEmphasis,
      child: Center(
        child: user == null
            ? const Icon(LucideIcons.user, size: 18, color: AppColors.primary)
            : Text(user!.initials, style: AppText.workSans(13, FontWeight.w600, AppColors.primary, lineHeight: 16)),
      ),
    );
    return ClipOval(
      child: SizedBox(
        width: 36,
        height: 36,
        child: photo == null
            ? fallback
            : CachedNetworkImage(
                imageUrl: photo,
                fit: BoxFit.cover,
                placeholder: (_, _) => fallback,
                errorWidget: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

/// Three dots that fade in turn while the reply has no words yet.
class _TypingDots extends StatefulWidget {
  const _TypingDots({super.key});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Opacity(
                opacity: 0.3 + 0.7 * (0.5 + 0.5 * -((((_c.value - i * 0.15) % 1) * 2 - 1).abs() * 2 - 1)),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(color: AppColors.outline, shape: BoxShape.circle),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The page's chips, wrapped under the latest reply, aligned with its words.
class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.suggestions, required this.onPick});

  final List<AssistantSuggestion> suggestions;
  final ValueChanged<AssistantSuggestion> onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('assistant-suggestions'),
      padding: const EdgeInsets.fromLTRB(64, 2, 16, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in suggestions)
            _Pill(
              key: ValueKey('suggestion-${s.label}'),
              label: s.label,
              icon: s.isPage ? LucideIcons.arrowUpRight : LucideIcons.messageCircle,
              onTap: () => onPick(s),
            ),
        ],
      ),
    );
  }
}

/// A tinted pill, no outline: a page or a question.
class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.chipEmphasis,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(label, style: AppText.plexSans(12.5, FontWeight.w600, AppColors.primary, lineHeight: 16)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The composer: the field on white, and Send.
class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.focus, required this.canSend, required this.onSend});

  final TextEditingController controller;
  final FocusNode focus;
  final bool canSend;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final safe = inset > 0 ? 0.0 : MediaQuery.viewPaddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 6, 12, 6 + safe + inset),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('assistant-input'),
              controller: controller,
              focusNode: focus,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              style: AppText.plexSans(14, FontWeight.w400, AppColors.onSurface, lineHeight: 20),
              decoration: InputDecoration(
                hintText: AssistantCopy.placeholder,
                hintStyle: AppText.plexSans(14, FontWeight.w400, AppColors.outline, lineHeight: 20),
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: canSend ? AppColors.primary : AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(999),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const ValueKey('assistant-send'),
              onTap: canSend ? onSend : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                child: Text(
                  'Send',
                  style: AppText.plexSans(
                    13,
                    FontWeight.w600,
                    canSend ? Colors.white : AppColors.outline,
                    lineHeight: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
