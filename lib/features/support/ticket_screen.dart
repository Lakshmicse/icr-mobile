import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/time_ago.dart';
import '../account/widgets/account_kit.dart';
import 'support_models.dart';
import 'support_repository.dart';
import 'support_session.dart';
import 'support_widgets.dart';
import 'support_words.dart';
import 'ticket_controller.dart';

/// One request and its thread: the website's `/support/[id]` (`TicketThread`). What was asked and answered, what the
/// request went through, a rating once it is resolved, and the reply box (or why there is none).
class TicketScreen extends StatefulWidget {
  const TicketScreen({
    super.key,
    required this.ticketId,
    this.repository,
    this.onBack,
    this.onOpenContext,
    this.pickFiles,
    this.onOpened,
  });

  final String ticketId;

  /// Where the calls go; the API (or the sample in demo mode) when null.
  final SupportRepository? repository;

  /// Back from the title bar; defaults to popping the route.
  final VoidCallback? onBack;

  /// Opens the page the request is about (`contextHref`, e.g. `/mentorship/my/<id>`). The label is a plain chip
  /// without it.
  final void Function(String href)? onOpenContext;

  /// The phone's file chooser for the reply's attachments; the system's when null.
  final FilePickFn? pickFiles;

  /// The request has been read: the caller reads what told the person about it (its notifications).
  final void Function(BuildContext context)? onOpened;

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  late final SupportRepository _repository;
  late final TicketController _controller;
  final _reply = TextEditingController();
  List<SupportAttachmentDraft> _files = const [];
  var _score = 0;
  var _told = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? supportRepositoryOf(context);
    _controller = TicketController(repository: _repository, ticketId: widget.ticketId);
    _controller.addListener(_onChanged);
    _controller.load();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _reply.dispose();
    super.dispose();
  }

  /// Once the request has been read, whoever opened it is told (a notification is read when its record opens).
  void _onChanged() {
    if (_told || _controller.ticket == null) return;
    _told = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onOpened?.call(context);
    });
  }

  Future<void> _send() async {
    final ok = await _controller.reply(_reply.text, _files);
    if (ok && mounted) {
      setState(() {
        _reply.clear();
        _files = const [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // The bar names the request once it has been read, so the whole page listens.
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final c = _controller;
        final t = c.ticket;
        return Scaffold(
          backgroundColor: AppColors.surfaceContainer,
          appBar: AccountBar(title: t == null ? 'Request' : SupportWords.reference(t.reference), onBack: widget.onBack),
          body: _body(c, t),
        );
      },
    );
  }

  Widget _body(TicketController c, SupportTicket? t) {
    if (c.loading && t == null) return const AccountLoading();
    if (t == null) {
      return AccountError(message: c.loadError ?? SupportWords.couldNotOpen, onRetry: c.load);
    }
    return RefreshIndicator(
      onRefresh: () => c.load(refresh: true),
      child: ListView(
        key: const Key('ticket.list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        children: [
          _Header(ticket: t, onOpenContext: widget.onOpenContext),
          if (t.firstRespondedAt == null && !t.closed)
            SupportNote(key: const Key('ticket.aim'), text: SupportWords.aimToReply(t.firstResponseHours)),
          if (t.waitingOnYou)
            const SupportNote(key: Key('ticket.waiting'), text: SupportWords.waitingOnYou, amber: true),
          _Thread(ticket: t, repository: _repository),
          if (t.events != null && t.events!.isNotEmpty) _History(events: t.events!),
          if (t.resolved && !t.rated) _Rating(controller: c, score: _score, onPick: (n) => setState(() => _score = n)),
          if (t.rated) _Rated(score: t.ratingScore!),
          if (t.closed)
            const SupportNote(key: Key('ticket.closed'), text: SupportWords.closedNote)
          else
            _ReplyBox(
              controller: c,
              text: _reply,
              repository: _repository,
              files: _files,
              pickFiles: widget.pickFiles,
              onFiles: (f) => setState(() => _files = f),
              onSend: _send,
              onChanged: () => setState(() {}),
            ),
        ],
      ),
    );
  }
}

/// The subject and status, "ICR-12 · Category · raised 3d ago", and what the request is about.
class _Header extends StatelessWidget {
  const _Header({required this.ticket, required this.onOpenContext});

  final SupportTicket ticket;
  final void Function(String href)? onOpenContext;

  @override
  Widget build(BuildContext context) {
    final t = ticket;
    final ago = t.createdAt == null ? '' : timeAgo(t.createdAt!.toLocal());
    final href = t.contextHref;
    final tappable = onOpenContext != null && href != null;
    return AccountCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(t.subject, key: const Key('ticket.subject'), style: AccountText.cardTitle),
              ),
              const SizedBox(width: 10),
              SupportStatusChip(status: t.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            SupportWords.raisedLine(SupportWords.reference(t.reference), SupportWords.category(t.category), ago),
            key: const Key('ticket.raised'),
            style: AccountText.meta,
          ),
          if (t.contextLabel != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: tappable
                  ? ActionChip(
                      key: const Key('ticket.context'),
                      avatar: const Icon(Symbols.open_in_new, size: 14, color: AppColors.primary),
                      label: Text(t.contextLabel!),
                      labelStyle: AccountText.chip.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                      backgroundColor: AppColors.chipEmphasis,
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onOpenContext!(href),
                    )
                  : AccountChip(key: const Key('ticket.context'), label: t.contextLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// The messages, oldest first, a hairline between them.
class _Thread extends StatefulWidget {
  const _Thread({required this.ticket, required this.repository});

  final SupportTicket ticket;
  final SupportRepository repository;

  @override
  State<_Thread> createState() => _ThreadState();
}

class _ThreadState extends State<_Thread> {
  String? _opening;

  Future<void> _open(SupportAttachment file) async {
    if (_opening != null) return;
    setState(() => _opening = file.id);
    await openSupportFile(context, widget.repository, file);
    if (mounted) setState(() => _opening = null);
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.ticket.messages ?? const <SupportMessage>[];
    if (messages.isEmpty) return const SizedBox.shrink();
    return Container(
      key: const Key('ticket.thread'),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, m) in messages.indexed)
              _MessageRow(message: m, first: i == 0, opening: _opening, onOpen: _open),
          ],
        ),
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message, required this.first, required this.opening, required this.onOpen});

  final SupportMessage message;
  final bool first;
  final String? opening;
  final ValueChanged<SupportAttachment> onOpen;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final a = m.author;
    return Container(
      key: Key('ticket.message.${m.id}'),
      decoration: BoxDecoration(
        border: Border(top: first ? BorderSide.none : const BorderSide(color: AppColors.slate200)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (a == null)
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: Text(
                'ICR',
                style: AccountText.chip.copyWith(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            )
          else
            AccountAvatar(url: a.avatarUrl, initials: a.initials, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        a == null || a.fullName.isEmpty ? 'ICR' : a.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AccountText.itemTitle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (m.createdAt != null) Text(timeAgo(m.createdAt!.toLocal()), style: AccountText.meta),
                  ],
                ),
                const SizedBox(height: 4),
                Text(m.body, style: AccountText.body.copyWith(color: AppColors.slate900)),
                if (m.attachments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final f in m.attachments)
                        ActionChip(
                          key: Key('ticket.file.${f.id}'),
                          avatar: opening == f.id
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Symbols.attach_file, size: 15, color: AppColors.slate600),
                          label: Text(f.fileName, overflow: TextOverflow.ellipsis),
                          labelStyle: AccountText.chip,
                          backgroundColor: AppColors.slate100,
                          side: BorderSide.none,
                          visualDensity: VisualDensity.compact,
                          onPressed: opening == null ? () => onOpen(f) : null,
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

/// "Raised · 3d ago", "Status changed → Resolved · 2d ago · note": the request's history.
class _History extends StatelessWidget {
  const _History({required this.events});

  final List<SupportEvent> events;

  @override
  Widget build(BuildContext context) {
    return AccountCard(
      title: SupportWords.history,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        key: const Key('ticket.history'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in events)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 16,
                    height: 18,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(color: AppColors.slate300, shape: BoxShape.circle),
                    ),
                  ),
                  Expanded(child: Text(_line(e), style: AccountText.meta.copyWith(fontSize: 13))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _line(SupportEvent e) {
    final to = e.toValue != null && e.type == 'STATUS_CHANGED' ? ' → ${SupportWords.status(e.toValue!)}' : '';
    final ago = e.createdAt == null ? '' : ' · ${timeAgo(e.createdAt!.toLocal())}';
    final note = e.note == null ? '' : ' — ${e.note}';
    return '${SupportWords.event(e.type)}$to$ago$note';
  }
}

/// "Did we get this right?": a score for a resolved request.
class _Rating extends StatelessWidget {
  const _Rating({required this.controller, required this.score, required this.onPick});

  final TicketController controller;
  final int score;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return AccountCard(
      key: const Key('ticket.rating'),
      title: SupportWords.didWeGetThisRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StarRow(score: score, onPick: controller.busy ? null : onPick),
          if (controller.ratingError != null) ...[
            const SizedBox(height: 6),
            Text(controller.ratingError!, key: const Key('ticket.rating.error'), style: AccountText.error),
          ],
          const SizedBox(height: 10),
          AccountButton(
            key: const Key('ticket.rate'),
            label: SupportWords.submitRating,
            expand: false,
            height: 40,
            busy: controller.rating,
            onPressed: score == 0 || controller.busy ? null : () => controller.rate(score),
          ),
        ],
      ),
    );
  }
}

class _Rated extends StatelessWidget {
  const _Rated({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('ticket.rated'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Text(SupportWords.youRatedThis, style: AccountText.meta.copyWith(fontSize: 13)),
          const SizedBox(width: 8),
          StarRow(score: score, size: 18),
        ],
      ),
    );
  }
}

/// The reply box, and (while it can still be done) the way to reopen a resolved request.
class _ReplyBox extends StatelessWidget {
  const _ReplyBox({
    required this.controller,
    required this.text,
    required this.repository,
    required this.files,
    required this.pickFiles,
    required this.onFiles,
    required this.onSend,
    required this.onChanged,
  });

  final TicketController controller;
  final TextEditingController text;
  final SupportRepository repository;
  final List<SupportAttachmentDraft> files;
  final FilePickFn? pickFiles;
  final ValueChanged<List<SupportAttachmentDraft>> onFiles;
  final VoidCallback onSend;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final t = c.ticket!;
    return AccountCard(
      key: const Key('ticket.replyBox'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AccountField(
            label: SupportWords.addAReply,
            fieldKey: const Key('ticket.reply'),
            controller: text,
            hint: SupportWords.replyHint,
            maxLength: 8000,
            maxLines: 6,
            minLines: 3,
            enabled: !c.sending,
            onChanged: (_) => onChanged(),
          ),
          AttachmentTray(
            repository: repository,
            files: files,
            onChanged: onFiles,
            pickFiles: pickFiles,
            enabled: !c.sending,
          ),
          if (c.replyError != null)
            Container(
              key: const Key('ticket.replyError'),
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(10)),
              child: Text(c.replyError!, style: AccountText.error.copyWith(fontSize: 14)),
            ),
          const SizedBox(height: 12),
          AccountButton(
            key: const Key('ticket.send'),
            label: c.sending ? SupportWords.sending : SupportWords.sendReply,
            busy: c.sending,
            onPressed: text.text.trim().isEmpty || c.busy ? null : onSend,
          ),
          if (t.reopenable) ...[
            const SizedBox(height: 8),
            AccountButton(
              key: const Key('ticket.reopen'),
              label: c.reopening ? SupportWords.reopening : SupportWords.reopen,
              outlined: true,
              busy: c.reopening,
              onPressed: c.busy ? null : c.reopen,
            ),
            if (c.reopenError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(c.reopenError!, key: const Key('ticket.reopenError'), style: AccountText.error),
              ),
          ],
        ],
      ),
    );
  }
}
