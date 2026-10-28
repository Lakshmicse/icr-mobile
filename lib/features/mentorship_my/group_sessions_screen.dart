import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import 'group_session_controller.dart';
import 'mentoring_format.dart';
import 'mentoring_links.dart';
import 'mentoring_models.dart';
import 'mentoring_repository.dart';
import 'purchases_flows.dart';
import 'widgets/forms.dart';
import 'widgets/kit.dart';

/// Pushes the group sessions browser (the website's `/mentorship/groups`).
Future<void> openGroupSessions(
  BuildContext context, {
  MentorshipLinks? links,
  bool registeredOnly = false,
  String? programId,
  OpenConversation? onOpenConversation,
  void Function(BuildContext context, String mentorProfileId)? onOpenMentor,
  void Function(BuildContext context)? onBell,
  OpenSitePath? onOpenWebsite,
}) {
  final resolved = MentorshipLinks.resolve(
    context,
    links,
    onOpenConversation: onOpenConversation,
    onOpenMentor: onOpenMentor,
    onBell: onBell,
    onOpenWebsite: onOpenWebsite,
  );
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => GroupSessionsScreen(links: resolved, registeredOnly: registeredOnly, programId: programId),
    ),
  );
}

/// Pushes one group session (`/mentorship/groups/<id>`).
Future<void> openGroupSession(
  BuildContext context,
  String id, {
  MentorshipLinks? links,
  OpenConversation? onOpenConversation,
  void Function(BuildContext context, String mentorProfileId)? onOpenMentor,
  void Function(BuildContext context)? onBell,
  OpenSitePath? onOpenWebsite,
}) {
  final resolved = MentorshipLinks.resolve(
    context,
    links,
    onOpenConversation: onOpenConversation,
    onOpenMentor: onOpenMentor,
    onBell: onBell,
    onOpenWebsite: onOpenWebsite,
  );
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => GroupSessionScreen(id: id, links: resolved),
    ),
  );
}

String seatLine(GroupSession s) {
  final price = s.paid ? '${inr(s.pricePaisa!)} a seat' : 'Free';
  if (s.capacity == null) return '$price · ${countLabel(s.seatsTaken, 'seat')} taken';
  if (s.full) return s.paid ? '$price · Sold out' : '$price · Full, with a waitlist (${s.waitlistCount} waiting)';
  return '$price · ${s.seatsLeft} of ${s.capacity} seats left';
}

String whenSeries(GroupSession s) {
  if (s.occurrences.length <= 1) return '${whenLabel(s.scheduledAt)} · ${minutesLabel(s.durationMin)}';
  final first = s.occurrences.first.scheduledAt;
  final last = s.occurrences.last.scheduledAt;
  return '${dayLabel(first)} to ${dayLabel(last)} · ${s.occurrences.length} days · ${minutesLabel(s.occurrences.first.durationMin)} each';
}

// ---------------------------------------------------------------------------
// The browser
// ---------------------------------------------------------------------------

/// Open group sessions (and the ones the member holds a seat at), filtered by how they meet and by free seats.
class GroupSessionsScreen extends StatefulWidget {
  const GroupSessionsScreen({
    super.key,
    this.onBack,
    this.links,
    this.repository,
    this.registeredOnly = false,
    this.programId,
    this.onOpenConversation,
    this.onOpenMentor,
    this.onBell,
    this.onOpenWebsite,
  });

  final VoidCallback? onBack;
  final MentorshipLinks? links;
  final MentoringRepository? repository;
  final bool registeredOnly;
  final String? programId;
  final OpenConversation? onOpenConversation;
  final void Function(BuildContext context, String mentorProfileId)? onOpenMentor;
  final void Function(BuildContext context)? onBell;
  final OpenSitePath? onOpenWebsite;

  @override
  State<GroupSessionsScreen> createState() => _GroupSessionsScreenState();
}

class _GroupSessionsScreenState extends State<GroupSessionsScreen> {
  late final GroupSessionsController _c;
  late final MentorshipLinks _links;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    final repo = widget.repository ?? MentoringRepository(api: context.read<ApiClient>());
    _links = MentorshipLinks.resolve(
      context,
      widget.links,
      onOpenConversation: widget.onOpenConversation,
      onOpenMentor: widget.onOpenMentor,
      onBell: widget.onBell,
      onOpenWebsite: widget.onOpenWebsite,
    );
    _c = GroupSessionsController(repo, programId: widget.programId, registeredOnly: widget.registeredOnly)..load();
  }

  @override
  void dispose() {
    _c.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final first = _c.first;
        final loading = first.loading && !first.loaded;
        final failed = !first.loaded ? first.error : null;
        final items = _c.items;
        return MentoringPage(
          title: 'Group sessions',
          onBack: widget.onBack,
          onBell: () => _links.notifications(context),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Column(
                  children: [
                    SegmentTabs(
                      labels: const ['Open sessions', 'My seats'],
                      selected: _c.registeredOnly ? 1 : 0,
                      onSelect: (i) => _c.apply(registeredOnly: i == 1),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      key: const ValueKey('groups-search'),
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (v) => _c.apply(search: v),
                      style: MentoringText.formInput.copyWith(fontSize: 14),
                      decoration: fieldDecoration('Search by title or topic').copyWith(
                        prefixIcon: const Icon(LucideIcons.search, size: 16),
                        suffixIcon: _c.search.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(LucideIcons.x, size: 16),
                                onPressed: () {
                                  _search.clear();
                                  _c.apply(search: '');
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final MapEntry(key: key, value: label) in {
                            'VIDEO': 'Video',
                            'PHONE': 'Phone',
                            'IN_PERSON': 'In person',
                          }.entries)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: FilterChip(
                                key: ValueKey('mode-$key'),
                                label: Text(label),
                                selected: _c.mode == key,
                                onSelected: (on) => on ? _c.apply(mode: key) : _c.apply(clearMode: true),
                              ),
                            ),
                          FilterChip(
                            key: const ValueKey('seats-free'),
                            label: const Text('Seats free'),
                            selected: _c.availableOnly,
                            onSelected: (on) => _c.apply(availableOnly: on),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LoadedList(
                  loading: loading,
                  error: failed,
                  errorTitle: "Couldn't load the sessions",
                  onRefresh: _c.load,
                  children: loading || failed != null
                      ? const []
                      : [
                          if (items.isEmpty)
                            EmptyNote(
                              icon: LucideIcons.users,
                              title: _c.registeredOnly ? 'No seats held' : 'No sessions match',
                              body: _c.registeredOnly
                                  ? 'Reserve a seat at an open session and it shows up here.'
                                  : 'Try another filter, or look again later: hosts add sessions all the time.',
                            ),
                          for (final s in items) GroupSessionCard(session: s, onTap: () => _open(s)),
                          if (_c.hasNext)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: QuietButton(
                                key: const ValueKey('groups-more'),
                                label: _c.loadingMore ? 'Loading…' : 'Load more sessions',
                                onPressed: _c.loadingMore ? null : _c.loadMore,
                              ),
                            ),
                          if (_c.moreError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(_c.moreError!, style: MentoringText.error),
                            ),
                        ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _open(GroupSession s) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GroupSessionScreen(id: s.id, links: _links, repository: _c.repository),
      ),
    );
    if (mounted) _c.load();
  }
}

class GroupSessionCard extends StatelessWidget {
  const GroupSessionCard({super.key, required this.session, required this.onTap});

  final GroupSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = session;
    return MentoringCard(
      key: ValueKey('group-${s.id}'),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(s.title, style: MentoringText.cardTitle)),
              if (s.myStatus != null && s.holdsSeat)
                StatusPill(
                  s.myStatus == 'WAITLISTED' ? 'Waitlisted' : (s.myStatus == 'ATTENDED' ? 'Attended' : 'Seat held'),
                  tone: s.myStatus == 'WAITLISTED' ? PillTone.amber : PillTone.mint,
                )
              else if (s.status != 'SCHEDULED')
                StatusPill(_statusLabel(s.status), tone: PillTone.grey),
            ],
          ),
          MetaLine(icon: LucideIcons.calendarClock, text: whenSeries(s)),
          MetaLine(icon: LucideIcons.user, text: '${s.host.name} · ${modeLabel(s.mode)}'),
          MetaLine(icon: LucideIcons.armchair, text: seatLine(s), color: s.full ? AppColors.amber800 : null),
          if (s.summary != null && s.summary!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(s.summary!, maxLines: 3, overflow: TextOverflow.ellipsis, style: MentoringText.body),
            ),
        ],
      ),
    );
  }
}

String _statusLabel(String s) => switch (s) {
  'COMPLETED' => 'Held',
  'CANCELLED' => 'Cancelled',
  'DRAFT' => 'Draft',
  _ => 'Open',
};

// ---------------------------------------------------------------------------
// One session
// ---------------------------------------------------------------------------

/// One group session (`/mentorship/groups/<id>`): when, who hosts it, the agenda, who is going, and the one
/// thing to do next: take a free seat, join the waitlist, buy a seat (the API's quote first, then the website's
/// payment page for real money), join the call, rate it once it is held.
class GroupSessionScreen extends StatefulWidget {
  const GroupSessionScreen({
    super.key,
    required this.id,
    this.onBack,
    this.links,
    this.repository,
    this.onOpenConversation,
    this.onOpenMentor,
    this.onBell,
    this.onOpenWebsite,
  });

  final String id;
  final VoidCallback? onBack;
  final MentorshipLinks? links;
  final MentoringRepository? repository;
  final OpenConversation? onOpenConversation;
  final void Function(BuildContext context, String mentorProfileId)? onOpenMentor;
  final void Function(BuildContext context)? onBell;
  final OpenSitePath? onOpenWebsite;

  @override
  State<GroupSessionScreen> createState() => _GroupSessionScreenState();
}

class _GroupSessionScreenState extends State<GroupSessionScreen> {
  late final GroupSessionController _c;
  late final MentorshipLinks _links;
  final _question = TextEditingController();

  @override
  void initState() {
    super.initState();
    final repo = widget.repository ?? MentoringRepository(api: context.read<ApiClient>());
    _links = MentorshipLinks.resolve(
      context,
      widget.links,
      onOpenConversation: widget.onOpenConversation,
      onOpenMentor: widget.onOpenMentor,
      onBell: widget.onBell,
      onOpenWebsite: widget.onOpenWebsite,
    );
    _c = GroupSessionController(repo, widget.id)..load();
  }

  @override
  void dispose() {
    _c.dispose();
    _question.dispose();
    super.dispose();
  }

  Future<void> _report(Future<String?> Function() action, {String? done}) async {
    final refusal = await action();
    if (!mounted) return;
    if (refusal != null) {
      showMessage(context, refusal);
    } else if (done != null) {
      showMessage(context, done);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final s = _c.session;
        return MentoringPage(
          title: 'Group session',
          onBack: widget.onBack,
          onBell: () => _links.notifications(context),
          body: LoadedList(
            loading: _c.loading && s == null,
            error: s == null ? _c.error : null,
            errorTitle: "Couldn't load this session",
            onRefresh: _c.load,
            children: s == null ? const [] : _content(context, s),
          ),
        );
      },
    );
  }

  List<Widget> _content(BuildContext context, GroupSession s) {
    final link = meetingUri(s.meetingLink);
    final agenda = plainText(s.agendaHtml);
    final held = s.status == 'COMPLETED';
    return [
      if (s.cover != null)
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 150,
            width: double.infinity,
            child: Photo(picture: s.cover),
          ),
        ),
      if (s.cover != null) const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: Text(s.title, style: MentoringText.hero)),
          if (s.status != 'SCHEDULED')
            StatusPill(_statusLabel(s.status), tone: s.status == 'CANCELLED' ? PillTone.red : PillTone.grey),
        ],
      ),
      const SizedBox(height: 10),
      PersonRow(person: s.host, subline: s.host.subline == null ? 'Host' : 'Host · ${s.host.subline}'),
      MetaLine(icon: LucideIcons.calendarClock, text: whenSeries(s)),
      MetaLine(icon: LucideIcons.video, text: '${modeLabel(s.mode)}${s.location == null ? '' : ' · ${s.location}'}'),
      MetaLine(icon: LucideIcons.armchair, text: seatLine(s), color: s.full ? AppColors.amber800 : null),
      if (s.programName != null) MetaLine(icon: LucideIcons.layers, text: 'Part of ${s.programName}'),
      if (s.status == 'CANCELLED' && s.cancelReason != null)
        Callout(tone: PillTone.red, text: 'Cancelled: ${s.cancelReason}'),
      if (s.occurrences.length > 1) ...[
        const SectionTitle(title: 'The days', top: 14),
        for (final o in s.occurrences)
          Padding(
            key: ValueKey('day-${o.id}'),
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Day ${o.seq}: ${whenLabel(o.scheduledAt)} · ${minutesLabel(o.durationMin)}${o.title == null ? '' : ' · ${o.title}'}',
                    style: MentoringText.body,
                  ),
                ),
                if (o.status != 'SCHEDULED') StatusPill(_statusLabel(o.status)),
              ],
            ),
          ),
      ],
      if (s.summary != null && s.summary!.isNotEmpty) ...[
        const SectionTitle(title: 'About', top: 14),
        Text(s.summary!, style: MentoringText.body),
      ],
      if (agenda.isNotEmpty) ...[
        const SectionTitle(title: 'Agenda', top: 14),
        Text(agenda, key: const ValueKey('agenda'), style: MentoringText.body),
      ],
      if (s.competencies.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final c in s.competencies) StatusPill(c, tone: PillTone.blue)],
          ),
        ),
      ..._seatPanel(context, s, link),
      if (s.attendees.isNotEmpty) ...[
        SectionTitle(title: 'Who is going (${s.attendees.where((a) => a.status != 'CANCELLED').length})', top: 16),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            for (final a in s.attendees.where((a) => a.status != 'CANCELLED'))
              SizedBox(
                width: 64,
                child: Column(
                  children: [
                    PersonAvatar(person: a.person, size: 40),
                    const SizedBox(height: 4),
                    Text(a.person.firstName, maxLines: 1, overflow: TextOverflow.ellipsis, style: MentoringText.meta),
                  ],
                ),
              ),
          ],
        ),
        if (s.rosterHiddenCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('and ${s.rosterHiddenCount} more who keep their seat private', style: MentoringText.meta),
          ),
      ],
      if (held && s.myStatus == 'ATTENDED') ..._ratingPanel(context, s),
      if (s.holdsSeat || s.isHost)
        ActionWrap(
          top: 16,
          children: [
            QuietButton(
              label: 'Report a concern',
              icon: LucideIcons.flag,
              onPressed: () async {
                final sent = await showFormSheet(
                  context,
                  (_) => _GroupConcernForm(
                    onSend: (c, d, u) => _c.raiseConcern(category: c, detail: d, urgent: u),
                  ),
                );
                if (sent && context.mounted) {
                  showMessage(context, 'Sent to ICR. Someone will look into it and reply to you.');
                }
              },
            ),
          ],
        ),
    ];
  }

  List<Widget> _seatPanel(BuildContext context, GroupSession s, Uri? link) {
    if (s.isHost) {
      return [
        const SectionTitle(title: 'Your seat', top: 16),
        const Callout(tone: PillTone.blue, text: 'You host this session. Manage it from the mentor desk.'),
      ];
    }
    final out = <Widget>[const SectionTitle(title: 'Your seat', top: 16)];
    if (s.holdsSeat && s.myStatus != 'WAITLISTED') {
      out.add(
        Callout(
          key: const ValueKey('seat-held'),
          tone: PillTone.mint,
          text: s.myStatus == 'ATTENDED' ? 'You attended this session.' : 'You have a seat.',
          actions: [
            if (link != null && s.upcoming)
              SolidButton(label: 'Join the session', icon: LucideIcons.video, onPressed: () => openUrl(context, link)),
            QuietButton(
              label: 'Room chat',
              icon: LucideIcons.messageSquare,
              onPressed: () => _links.messageGroup(context, _c.repository, s.id),
            ),
            if (!s.paid && s.upcoming)
              QuietButton(
                label: 'Give up my seat',
                danger: true,
                onPressed: () => _report(_c.leave, done: 'You gave up your seat.'),
              ),
          ],
        ),
      );
      if (s.paid && s.upcoming) {
        out.add(
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('A paid seat is cancelled from your purchases.', style: MentoringText.meta),
          ),
        );
      }
      return out;
    }
    if (s.myStatus == 'WAITLISTED') {
      out.add(
        Callout(
          key: const ValueKey('seat-waitlisted'),
          tone: PillTone.amber,
          text: 'You are on the waitlist. You get a seat if one frees up, and the host tells you.',
          actions: [
            QuietButton(
              label: 'Leave the waitlist',
              danger: true,
              onPressed: () => _report(_c.leave, done: 'You left the waitlist.'),
            ),
          ],
        ),
      );
      return out;
    }
    if (!s.upcoming) {
      out.add(
        Text(
          s.status == 'COMPLETED' ? 'This session has been held.' : 'This session is not open for seats.',
          style: MentoringText.body,
        ),
      );
      return out;
    }
    if (s.seatForSale) {
      final q = _c.seatQuote!;
      out.add(
        MentoringCard(
          key: const ValueKey('seat-for-sale'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              QuoteBlock(quote: q),
              ActionWrap(
                children: [
                  SolidButton(
                    label: q.chargedPaisa == 0 ? 'Reserve a seat' : 'Reserve a seat · ${inr(q.chargedPaisa)}',
                    icon: LucideIcons.ticket,
                    onPressed: () async {
                      final done = await showFormSheet(context, (_) => _SeatForm(controller: _c, links: _links));
                      if (done && mounted) _c.load();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      return out;
    }
    if (s.canRegister) {
      out.add(
        MentoringCard(
          key: const ValueKey('seat-free'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.full
                    ? 'It is full, but you can join the waitlist.'
                    : 'A free seat. Tell the host what you want out of it.',
                style: MentoringText.body,
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('seat-question'),
                controller: _question,
                minLines: 2,
                maxLines: 4,
                maxLength: 1000,
                style: MentoringText.formInput,
                decoration: fieldDecoration('A question for the host (optional)'),
              ),
              ActionWrap(
                top: 4,
                children: [
                  SolidButton(
                    label: s.full ? 'Join the waitlist' : 'Reserve my seat',
                    icon: LucideIcons.ticket,
                    busy: _c.busy,
                    onPressed: () => _report(
                      () => _c.register(question: _question.text),
                      done: s.full ? 'You are on the waitlist.' : 'Your seat is booked.',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      return out;
    }
    out.add(
      Callout(
        key: const ValueKey('seat-blocked'),
        tone: PillTone.grey,
        text: s.blockedReason ?? 'You cannot take a seat at this session.',
      ),
    );
    return out;
  }

  List<Widget> _ratingPanel(BuildContext context, GroupSession s) {
    final f = _c.feedback;
    final reviewed = s.paid ? s.myPurchaseHasReview : f != null;
    return [
      const SectionTitle(title: 'Your rating', top: 16),
      if (reviewed)
        MentoringCard(
          key: const ValueKey('my-group-rating'),
          child: Row(
            children: [
              if (f != null)
                for (var i = 1; i <= 5; i++)
                  Icon(
                    i <= f.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 18,
                    color: i <= f.rating ? MentoringColors.star : AppColors.outline,
                  )
              else
                Text('You reviewed this seat. Thank you.', style: MentoringText.body),
              if (f?.comment != null) ...[
                const SizedBox(width: 10),
                Expanded(child: Text(f!.comment!, style: MentoringText.quote)),
              ],
            ],
          ),
        )
      else
        Callout(
          text: 'How was it? Your rating helps others choose.',
          actions: [
            SolidButton(
              label: 'Rate this session',
              icon: LucideIcons.star,
              onPressed: () => showReviewSheet(
                context,
                title: 'Rate ${s.title}',
                subtitle: 'Shown on the session page.',
                flagLabel: 'Hide my name on the rating',
                flagDefault: false,
                minComment: minReviewComment,
                onSend: (rating, comment, hide) => s.paid
                    ? _c.rateSeat(rating: rating, comment: comment, anonymous: hide)
                    : _c.rate(rating: rating, comment: comment, anonymous: hide),
              ),
            ),
          ],
        ),
    ];
  }
}

/// A paid seat: the quote, a question for the host, and the button that takes the payment (in the app when
/// nothing is left to pay, on the website's payment page for real money).
class _SeatForm extends StatefulWidget {
  const _SeatForm({required this.controller, required this.links});

  final GroupSessionController controller;
  final MentorshipLinks links;

  @override
  State<_SeatForm> createState() => _SeatFormState();
}

class _SeatFormState extends State<_SeatForm> {
  final _question = TextEditingController();
  String? _problem;
  bool _busy = false;
  bool? _live;

  @override
  void initState() {
    super.initState();
    widget.controller.repository.paymentsLive().then((v) {
      if (mounted) setState(() => _live = v);
    });
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _buy() async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      final outcome = await widget.controller.buySeat(question: _question.text);
      if (!mounted) return;
      Navigator.pop(context, true);
      await finishPayment(context, widget.links, outcome);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _problem = ApiError.from(e).message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.controller.session!;
    final q = widget.controller.seatQuote!;
    final onSite = q.chargedPaisa > 0 && _live == true;
    return MentoringForm(
      title: 'Reserve your seat',
      subtitle: s.title,
      submitLabel: q.chargedPaisa == 0
          ? 'Reserve a seat'
          : (onSite ? 'Pay ${inr(q.chargedPaisa)} on the website' : 'Pay ${inr(q.chargedPaisa)}'),
      busy: _busy,
      problem: _problem,
      onSubmit: _buy,
      children: [
        Text('One seat', style: MentoringText.body),
        const SizedBox(height: 4),
        QuoteBlock(quote: q),
        const SizedBox(height: 12),
        FieldBlock(
          label: 'A question for the host (optional)',
          child: TextField(
            key: const ValueKey('seat-sheet-question'),
            controller: _question,
            minLines: 2,
            maxLines: 4,
            maxLength: 1000,
            style: MentoringText.formInput,
            decoration: fieldDecoration('What you want out of it'),
          ),
        ),
        if (onSite)
          Text(
            'The payment itself is made on ICR\'s secure PayU page on the website: the button opens it.',
            key: const ValueKey('pay-handoff'),
            style: MentoringText.meta,
          ),
      ],
    );
  }
}

/// A concern about a session the member attended: category and what happened, private to ICR.
class _GroupConcernForm extends StatefulWidget {
  const _GroupConcernForm({required this.onSend});

  final Future<String?> Function(ConcernCategory category, String detail, bool urgent) onSend;

  @override
  State<_GroupConcernForm> createState() => _GroupConcernFormState();
}

class _GroupConcernFormState extends State<_GroupConcernForm> {
  final _detail = TextEditingController();
  ConcernCategory _category = ConcernCategory.conduct;
  bool _urgent = false;
  String? _problem;
  bool _busy = false;

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_detail.text.trim().length < 10) {
      setState(() => _problem = 'Tell ICR what happened: at least 10 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final refusal = await widget.onSend(_category, _detail.text, _urgent || _category == ConcernCategory.safety);
    if (!mounted) return;
    if (refusal != null) {
      setState(() {
        _busy = false;
        _problem = refusal;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return MentoringForm(
      title: 'Report a concern',
      subtitle: 'Goes to ICR\'s safeguarding team, not to the host.',
      submitLabel: 'Send to ICR',
      busy: _busy,
      problem: _problem,
      onSubmit: _submit,
      children: [
        FieldBlock(
          label: 'What is it about?',
          help: _category.hint,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in ConcernCategory.values)
                ChoiceChip(
                  label: Text(c.label),
                  selected: c == _category,
                  onSelected: (_) => setState(() => _category = c),
                ),
            ],
          ),
        ),
        FieldBlock(
          label: 'What happened',
          child: TextField(
            key: const ValueKey('group-concern-detail'),
            controller: _detail,
            minLines: 4,
            maxLines: 8,
            maxLength: 4000,
            style: MentoringText.formInput,
            decoration: fieldDecoration('What happened, and when'),
          ),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _urgent || _category == ConcernCategory.safety,
          onChanged: _category == ConcernCategory.safety ? null : (v) => setState(() => _urgent = v),
          title: Text('This is urgent', style: MentoringText.formLabel),
        ),
      ],
    );
  }
}
