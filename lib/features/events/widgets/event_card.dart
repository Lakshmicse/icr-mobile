import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../event_format.dart';
import '../event_models.dart';
import '../events_styles.dart';
import 'pills.dart';

/// One event in the agenda grid: the photo with its two pills and the date
/// line over its foot, the title, the speaker or venue line, and the footer.
/// 184.5 dp wide in the design's two-column grid, as tall as its own content
/// (the design's cards in one row differ by a few dp).
class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    required this.onTap,
    required this.onSave,
    required this.onShare,
    required this.onAction,
    this.onDetails,
  });

  static const photoHeight = 114.0;

  /// Room for two title lines at the card title's size and line height.
  static double get titleHeight => 2 * (EventsText.cardTitle.fontSize ?? 14) * (EventsText.cardTitle.height ?? 1.3);

  /// The speaker or venue block never draws shorter than this, so cards with
  /// one line under the title are as tall as the design's.
  static const lineBlockMin = 23.0;

  final EventSummary event;
  final VoidCallback onTap;
  final VoidCallback onSave;
  final VoidCallback onShare;

  /// The footer's button.
  final VoidCallback onAction;

  /// The footer's "Details" word: the sheet, whatever the button does (the whole
  /// card opens it too). Defaults to a tap on the card.
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final tags = tagsFor(e);
    final line = lineFor(e);
    final footer = footerFor(e);
    final online = formatOf(e) == EventFormat.online;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: EventsColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: photoHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  EventCover(event: e),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.5, 1],
                        colors: [Color(0x00081422), Color(0xA6081422)],
                      ),
                    ),
                  ),
                  // The pills wrap onto a second row rather than run past the photo's edge.
                  Positioned(
                    left: 8,
                    right: 8,
                    top: 9.5,
                    child: Wrap(spacing: 4.5, runSpacing: 4, children: [for (final tag in tags) IntrinsicWidth(child: TagPill(tag))]),
                  ),
                  Positioned(
                    left: 10,
                    right: 3,
                    bottom: 14,
                    child: Row(
                      children: [
                        Icon(
                          online ? LucideIcons.clock : LucideIcons.calendar,
                          size: 11,
                          color: online ? AppColors.success : Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            dateLineFor(e),
                            style: EventsText.dateLine,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11.5, 6, 11.5, 5.5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: titleHeight),
                    child: Text(e.title, style: EventsText.cardTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(height: 4.5),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: lineBlockMin),
                    child: line == null
                        ? const SizedBox.shrink()
                        : _Line(text: line.$1, icon: line.$2, maxLines: e.lineMaxLines),
                  ),
                  const SizedBox(height: 3),
                  _Footer(
                    footer: footer,
                    saved: e.saved,
                    onSave: onSave,
                    onShare: onShare,
                    onAction: onAction,
                    onDetails: onDetails ?? onTap,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The glyph and the speaker, venue or audience. A single line runs to the
/// card's edge and is cut there, as the design's repeated cards are.
class _Line extends StatelessWidget {
  const _Line({required this.text, required this.icon, required this.maxLines});

  final String text;
  final LineIcon icon;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final speaker = icon == LineIcon.speaker;
    final style = speaker ? EventsText.cardSpeaker : EventsText.cardVenue;
    final glyph = Padding(
      padding: EdgeInsets.only(top: speaker ? 2.5 : 1.5),
      child: switch (icon) {
        LineIcon.speaker => const Icon(Symbols.record_voice_over, size: 13, color: AppColors.onSurfaceVariant),
        LineIcon.venue => const Icon(LucideIcons.mapPin, size: 12, color: AppColors.linkIcon),
        LineIcon.lock => const Icon(LucideIcons.lock, size: 12, color: AppColors.error),
        LineIcon.lab => const Icon(Symbols.handyman, size: 13, color: AppColors.tertiary),
      },
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        glyph,
        const SizedBox(width: 4),
        Expanded(
          child: Text(text, style: style, maxLines: maxLines, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

/// The card's bottom row. It may run past the card's edge, as the design's
/// "Request Invite" and "Get Tickets" do; the card clips it.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.footer,
    required this.saved,
    required this.onSave,
    required this.onShare,
    required this.onAction,
    required this.onDetails,
  });

  final EventFooter footer;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onAction;
  final VoidCallback onDetails;

  static const height = 28.5;

  @override
  Widget build(BuildContext context) {
    final f = footer;
    final items = <Widget>[];
    // A gap is the left margin of the next item, so a wrapped line does not begin with it.
    var pending = 0.0;
    void gap(double w) => pending = w;
    void add(Widget w) {
      items.add(pending == 0 ? w : Padding(padding: EdgeInsets.only(left: pending), child: w));
      pending = 0;
    }

    if (f.note != null) {
      // "18 / 25 Executive Seats Left  🔖  [Request Invite]": the note, the
      // glyphs close behind it, then the button.
      add(_note(f));
      if (f.details) {
        gap(5);
        add(
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDetails,
            child: Text('Details', style: EventsText.footerDetails),
          ),
        );
      }
      final glyphs = [if (f.bookmark) _bookmark(), if (f.share) _share()];
      for (final (i, g) in glyphs.indexed) {
        gap(i == 0 ? 3 : 4);
        add(g);
      }
      if (f.action != null) {
        gap(f.details ? 13 : 4);
        add(_button(f.action!));
      }
    } else {
      // "[Register Free]   ⤴   🔖": the button first, the glyphs spaced out.
      if (f.action != null) add(_button(f.action!));
      for (final g in [if (f.share) _share(), if (f.bookmark) _bookmark()]) {
        if (items.isNotEmpty) gap(items.length == 1 ? 21 : 17);
        add(g);
      }
    }
    // What does not fit on the first line wraps to the next, and a note wider than the card gives way to an
    // ellipsis: nothing runs past the card's edge.
    return LayoutBuilder(
      builder: (context, box) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: height),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 4,
          children: [
            for (final w in items) ConstrainedBox(constraints: BoxConstraints(maxWidth: box.maxWidth), child: w),
          ],
        ),
      ),
    );
  }

  Widget _note(EventFooter f) {
    final style = switch (f.noteTone) {
      NoteTone.grey => EventsText.footerNote,
      NoteTone.green => EventsText.footerNoteGreen,
      NoteTone.caps => EventsText.footerCaps,
    };
    final icon = switch (f.noteIcon) {
      NoteIcon.none => null,
      NoteIcon.ticket => LucideIcons.ticket,
      NoteIcon.zap => LucideIcons.zap,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 11, color: style.color), const SizedBox(width: 3)],
        Flexible(child: Text(f.note!, style: style, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _button(String label) {
    final shape = StadiumBorder(side: const BorderSide(color: EventsColors.border));
    return Material(
      color: Colors.white,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onAction,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11.5),
            child: Center(widthFactor: 1, child: Text(label, style: EventsText.footerButton, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ),
        ),
      ),
    );
  }

  Widget _share() => GlyphButton(icon: LucideIcons.share2, label: 'Share event', size: 14.5, box: 18, onTap: onShare);

  Widget _bookmark() => GlyphButton(
    icon: saved ? LucideIcons.bookmarkCheck : LucideIcons.bookmark,
    label: saved ? 'Remove bookmark' : 'Save event',
    color: saved ? AppColors.primary : AppColors.outline,
    size: 16,
    box: 20,
    onTap: onSave,
  );
}
