import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/util/time_ago.dart';
import '../../../core/widgets/detail_sheet.dart';
import '../../feed/feed_models.dart';
import '../../feed/widgets/feed_avatar.dart';
import '../../feed/widgets/post_card.dart';
import '../forum_models.dart';
import '../forum_styles.dart';
import 'forum_bits.dart';

/// One row of an action sheet.
class SheetAction {
  const SheetAction({required this.label, required this.icon, required this.onTap, this.destructive = false, this.key});

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;
  final Key? key;
}

Future<T?> _sheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    barrierColor: AppColors.sheetScrim,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    clipBehavior: Clip.antiAlias,
    builder: builder,
  );
}

/// The three dots on a discussion or a reply: what the reader may do with it.
Future<void> showActionSheet(BuildContext context, {String? title, required List<SheetAction> actions}) {
  return _sheet<void>(
    context,
    (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHandle(top: 11, height: 28, rule: false),
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: Text(title, style: ForumDesign.sheetHint, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          for (final action in actions)
            ListTile(
              key: action.key,
              dense: true,
              leading: Icon(action.icon, size: 20, color: action.destructive ? AppColors.rose600 : AppColors.icon),
              title: Text(
                action.label,
                style: ForumDesign.sheetRow.copyWith(color: action.destructive ? AppColors.rose600 : null),
              ),
              onTap: () {
                Navigator.pop(sheet);
                action.onTap();
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// "Report this post": a reason from the forum's list and a note, sent through [onSend], which answers with the
/// API's refusal (shown in the sheet, with what was typed kept) or null once it went. The sheet closes on success.
Future<bool> showReportSheet(
  BuildContext context, {
  required bool reply,
  required Future<String?> Function(ReportReason reason, String? note) onSend,
}) async {
  final sent = await _sheet<bool>(context, (sheet) => _ReportSheet(reply: reply, onSend: onSend));
  return sent == true;
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.reply, required this.onSend});

  final bool reply;
  final Future<String?> Function(ReportReason reason, String? note) onSend;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _note = TextEditingController();
  ReportReason _reason = ReportReason.spam;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final note = _note.text.trim();
    final message = await widget.onSend(_reason, note.isEmpty ? null : note);
    if (!mounted) return;
    if (message == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _sending = false;
        _error = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHandle(top: 11, height: 28, rule: false),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.reply ? 'Report This Reply' : 'Report This Discussion', style: ForumDesign.sheetTitle),
                    const SizedBox(height: 4),
                    Text('A moderator will review it. Select the reason.', style: ForumDesign.sheetHint),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              RadioGroup<ReportReason>(
                groupValue: _reason,
                onChanged: (value) {
                  if (!_sending && value != null) setState(() => _reason = value);
                },
                child: Column(
                  children: [
                    for (final reason in ReportReason.values)
                      RadioListTile<ReportReason>(
                        key: ValueKey('report-reason:${reason.api}'),
                        value: reason,
                        dense: true,
                        title: Text(reason.label, style: ForumDesign.sheetRow),
                        activeColor: AppColors.primary,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: TextField(
                  key: const ValueKey('report-note'),
                  controller: _note,
                  enabled: !_sending,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: ForumLimits.noteMax,
                  style: ForumDesign.field,
                  decoration: InputDecoration(
                    hintText: 'Additional details for the moderator (Optional)',
                    hintStyle: ForumDesign.fieldHint,
                    counterStyle: ForumDesign.count,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.outlineVariant),
                    ),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    _error!,
                    key: const ValueKey('report-error'),
                    style: ForumDesign.notice.copyWith(color: AppColors.error),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: SizedBox(
                  height: 46,
                  child: FilledButton(
                    key: const ValueKey('report-send'),
                    onPressed: _sending ? null : _send,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text('Send Report', style: ForumDesign.button),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Who reacted to a discussion, newest first, as the owner's reference draws it (13 Nov 2026): a row of tabs —
/// "All 175", then each reaction with its count — and under it the people, each photo wearing the reaction it gave,
/// the name and the headline, a hairline between rows.
Future<void> showReactorsSheet(
  BuildContext context, {
  required Future<List<ForumReactor>> Function() load,
  ValueChanged<String>? onOpenMember,
}) {
  return _sheet<void>(context, (sheet) => _ReactorsSheet(load: load, onOpenMember: onOpenMember));
}

class _ReactorsSheet extends StatefulWidget {
  const _ReactorsSheet({required this.load, this.onOpenMember});

  final Future<List<ForumReactor>> Function() load;
  final ValueChanged<String>? onOpenMember;

  @override
  State<_ReactorsSheet> createState() => _ReactorsSheetState();
}

class _ReactorsSheetState extends State<_ReactorsSheet> {
  List<ForumReactor>? _items;
  String? _error;

  /// The tab that is on: one reaction, or null for All.
  ReactionKind? _kind;

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    setState(() {
      _items = null;
      _error = null;
    });
    try {
      final items = await widget.load();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = _sentence(e));
    }
  }

  Widget _tab({required ReactionKind? kind, required int count}) {
    final on = _kind == kind;
    return InkWell(
      key: ValueKey('reactors-tab:${kind?.name ?? 'all'}'),
      onTap: () => setState(() => _kind = kind),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: on ? AppColors.primary : Colors.transparent, width: 2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (kind != null) ...[ReactionBadge(kind: kind, size: 20), const SizedBox(width: 6)],
            Text(
              kind == null ? 'All $count' : '$count',
              style: ForumDesign.author.copyWith(
                fontSize: 14,
                color: on ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final shown = [
      for (final r in items ?? const <ForumReactor>[])
        if (_kind == null || r.reaction == _kind) r,
    ];
    return SizedBox(
      height: _peopleSheetHeight(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHandle(top: 11, height: 28, rule: false),
          if (_error != null)
            ForumMessage(
              icon: LucideIcons.cloudOff,
              title: 'Unable to Load',
              body: _error!,
              action: 'Try Again',
              onAction: _read,
            )
          else if (items == null)
            const Padding(padding: EdgeInsets.all(32), child: ForumSpinner())
          else if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Text('Nobody has reacted yet.', style: ForumDesign.sheetHint),
            )
          else ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  _tab(kind: null, count: items.length),
                  for (final kind in ReactionKind.values)
                    if (items.any((r) => r.reaction == kind))
                      _tab(kind: kind, count: items.where((r) => r.reaction == kind).length),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: AppColors.outlineVariant),
            Expanded(
              child: ListView.separated(
                key: const ValueKey('reactors-list'),
                padding: EdgeInsets.only(bottom: _bottomRoom(context)),
                itemCount: shown.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, thickness: 1, indent: 20, endIndent: 20, color: AppColors.outlineVariant),
                itemBuilder: (context, i) {
                  final r = shown[i];
                  final open = widget.onOpenMember;
                  return _ReactorRow(reactor: r, onTap: open == null ? null : () => open(r.person.id));
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One person who reacted: the photo with their reaction at its corner, the name and the headline.
class _ReactorRow extends StatelessWidget {
  const _ReactorRow({required this.reactor, this.onTap});

  final ForumReactor reactor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final person = reactor.person;
    final headline = person.headline;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 52,
              height: 50,
              child: Stack(
                children: [
                  FeedAvatar(photo: person.photo, initials: person.initials, size: 46, label: person.name),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: ReactionBadge(kind: reactor.reaction, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    person.name,
                    style: ForumDesign.author.copyWith(fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (headline != null && headline.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(headline, style: ForumDesign.headline, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Who voted in a poll and for what, newest vote first — the website's voters dialog, with the option each person
/// picked under their name. The API opens it to the poll's voters, its author and staff (and to everyone once
/// the discussion is closed); for anyone else its sentence shows ("Vote in the poll to see who voted.").
Future<void> showPollVotersSheet(
  BuildContext context, {
  required FeedPoll poll,
  required Future<List<ForumPollVoter>> Function() load,
  ValueChanged<String>? onOpenMember,
}) {
  final labels = {for (final o in poll.options) o.id: o.label};
  return _sheet<void>(
    context,
    (sheet) => _PeopleSheet<ForumPollVoter>(
      title: 'Votes',
      load: load,
      emptyText: 'No votes yet.',
      rowOf: (v) => _PersonRow(
        person: v.person,
        caption: labels[v.optionId] ?? timeAgo(v.votedAt),
        onTap: onOpenMember == null ? null : () => onOpenMember(v.person.id),
      ),
    ),
  );
}

/// Who read a discussion, most recent first.
Future<void> showViewersSheet(
  BuildContext context, {
  required Future<ForumViewersPage> Function() load,
  ValueChanged<String>? onOpenMember,
}) {
  return _sheet<void>(context, (sheet) => _ViewersSheet(load: load, onOpenMember: onOpenMember));
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, this.caption, this.onTap});

  final FeedAuthor person;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            FeedAvatar(photo: person.photo, initials: person.initials, size: 36, label: person.name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(person.name, style: ForumDesign.author, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (person.headline != null && person.headline!.isNotEmpty)
                    Text(person.headline!, style: ForumDesign.headline, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (caption != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(caption!, style: ForumDesign.meta),
              ),
          ],
        ),
      ),
    );
  }
}

class _PeopleSheet<T> extends StatefulWidget {
  const _PeopleSheet({required this.title, required this.load, required this.rowOf, required this.emptyText});

  final String title;
  final Future<List<T>> Function() load;
  final Widget Function(T) rowOf;
  final String emptyText;

  @override
  State<_PeopleSheet<T>> createState() => _PeopleSheetState<T>();
}

class _PeopleSheetState<T> extends State<_PeopleSheet<T>> {
  List<T>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    setState(() {
      _items = null;
      _error = null;
    });
    try {
      final items = await widget.load();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = _sentence(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return SizedBox(
      height: _peopleSheetHeight(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHandle(top: 11, height: 28, rule: false),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(widget.title, style: ForumDesign.sheetTitle),
          ),
          if (_error != null)
            ForumMessage(
              icon: LucideIcons.cloudOff,
              title: 'Unable to Load',
              body: _error!,
              action: 'Try Again',
              onAction: _read,
            )
          else if (items == null)
            const Padding(padding: EdgeInsets.all(32), child: ForumSpinner())
          else if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Text(widget.emptyText, style: ForumDesign.sheetHint),
            )
          else
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(bottom: _bottomRoom(context)),
                children: [for (final item in items) widget.rowOf(item)],
              ),
            ),
        ],
      ),
    );
  }
}

class _ViewersSheet extends StatefulWidget {
  const _ViewersSheet({required this.load, this.onOpenMember});

  final Future<ForumViewersPage> Function() load;
  final ValueChanged<String>? onOpenMember;

  @override
  State<_ViewersSheet> createState() => _ViewersSheetState();
}

class _ViewersSheetState extends State<_ViewersSheet> {
  ForumViewersPage? _page;
  String? _error;

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    setState(() {
      _page = null;
      _error = null;
    });
    try {
      final page = await widget.load();
      if (mounted) setState(() => _page = page);
    } catch (e) {
      if (mounted) setState(() => _error = _sentence(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    return SizedBox(
      height: _peopleSheetHeight(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHandle(top: 11, height: 28, rule: false),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Who Viewed', style: ForumDesign.sheetTitle),
          ),
          if (_error != null)
            ForumMessage(
              icon: LucideIcons.cloudOff,
              title: 'Unable to Load',
              body: _error!,
              action: 'Try Again',
              onAction: _read,
            )
          else if (page == null)
            const Padding(padding: EdgeInsets.all(32), child: ForumSpinner())
          else
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(bottom: _bottomRoom(context)),
                children: [
                  if (page.viewers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: Text('No members visible to you have viewed this yet.', style: ForumDesign.sheetHint),
                    ),
                  for (final v in page.viewers)
                    _PersonRow(
                      person: v.person,
                      caption: timeAgo(v.viewedAt),
                      onTap: widget.onOpenMember == null ? null : () => widget.onOpenMember!(v.person.id),
                    ),
                  if (page.hidden > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                      child: Text(
                        '${page.hidden} ${page.hidden == 1 ? 'other member' : 'other members'} viewed it with a private profile.',
                        key: const ValueKey('viewers-hidden'),
                        style: ForumDesign.sheetHint,
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

/// The people sheets (who reacted, voted, viewed) open at three quarters of the screen whatever the count, as
/// LinkedIn's do: sized to their rows, two people made a sliver of a sheet (owner, 14 Nov 2026).
double _peopleSheetHeight(BuildContext context) => MediaQuery.sizeOf(context).height * 0.75;

/// Room under a people sheet's last row: the phone's navigation bar, which the sheet's white runs behind, and a gap
/// above it, so the last person sits clear of the bar instead of under it.
double _bottomRoom(BuildContext context) => MediaQuery.viewPaddingOf(context).bottom + 24;

String _sentence(Object e) {
  final text = e.toString();
  return text.isEmpty ? 'Something went wrong. Try again.' : text;
}

/// The five reactions in a pill above the Like button; [anchor] is the button's place on screen. Returns the
/// reaction picked, or null when the reader dismissed it.
Future<ReactionKind?> showReactionPicker(BuildContext context, {required Rect anchor, ReactionKind? current}) {
  return showGeneralDialog<ReactionKind>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close reactions',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 120),
    transitionBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child),
    pageBuilder: (dialog, _, _) {
      final width = MediaQuery.sizeOf(dialog).width;
      const pillWidth = 5 * 44.0 + 16;
      final left = (anchor.center.dx - pillWidth / 2).clamp(8.0, width - pillWidth - 8);
      final top = (anchor.top - 60).clamp(MediaQuery.paddingOf(dialog).top + 8, double.infinity);
      return Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            child: Material(
              elevation: 6,
              shadowColor: Colors.black38,
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final kind in reactionLabels.keys)
                      Semantics(
                        button: true,
                        selected: kind == current,
                        label: reactionLabels[kind],
                        excludeSemantics: true,
                        child: InkResponse(
                          key: ValueKey('reaction:${reactionKindToApi(kind)}'),
                          onTap: () => Navigator.pop(dialog, kind),
                          radius: 24,
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: Center(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                padding: EdgeInsets.all(kind == current ? 3 : 0),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: kind == current ? AppColors.primary : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: ReactionBadge(kind: kind, size: 30),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// "Delete your reply?" and its like: the ask before something is taken away.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
}) async {
  final sure = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text(title, style: AppText.postTitle.copyWith(fontSize: 16, height: 1.3)),
      content: Text(body, style: AppText.small),
      actions: [
        TextButton(
          key: const ValueKey('confirm-cancel'),
          onPressed: () => Navigator.pop(dialog, false),
          child: Text('Cancel', style: AppText.link),
        ),
        TextButton(
          key: const ValueKey('confirm-yes'),
          onPressed: () => Navigator.pop(dialog, true),
          child: Text(action, style: AppText.link.copyWith(color: AppColors.rose600)),
        ),
      ],
    ),
  );
  return sure == true;
}
