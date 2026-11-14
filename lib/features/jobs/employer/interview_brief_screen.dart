import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/section_heading.dart' show Hairline;
import '../../career/career_format.dart';
import '../../career/career_styles.dart';
import '../../career/career_widgets.dart';
import '../../career/career_models.dart' show MatchSignal;
import '../job_links.dart';
import '../jobs_navigation.dart';
import 'applicants_controller.dart' show stageWord;
import 'applicants_screen.dart' show stageTone;
import 'hiring_repository.dart';
import 'hiring_sheets.dart' show hiringDecoration;
import 'interview_brief_controller.dart';
import 'interview_brief_models.dart';
import 'resume_viewer.dart';

/// An interview's page, as the website's `/manage/interviews/:id`: what a panelist needs before the round and
/// where they score it after. The candidate and their résumé, the recruiter's notes for the panel, when and
/// how the round runs, what screening found, the hiring team's notes, the rounds before this one, and the
/// scorecards — the viewer's own first; the rest of the panel's open once theirs is in. A recruiter off the
/// panel just reads them. Opened by an `interview.panel` notification ("You're on an interview panel").
class InterviewBriefScreen extends StatefulWidget {
  const InterviewBriefScreen({
    super.key,
    required this.repository,
    required this.interviewId,
    this.links = const SystemJobLinks(),
    this.navigation = JobsNavigation.none,
    this.onOpened,
    this.clock,
  });

  final HiringRepository repository;
  final String interviewId;
  final JobLinks links;
  final JobsNavigation navigation;

  /// Called once the page is open: the app marks what told the person about this round as read.
  final void Function(BuildContext context)? onOpened;
  final DateTime Function()? clock;

  @override
  State<InterviewBriefScreen> createState() => _InterviewBriefScreenState();
}

class _InterviewBriefScreenState extends State<InterviewBriefScreen> {
  late final InterviewBriefController _c = InterviewBriefController(widget.repository, widget.interviewId);
  final _strengths = TextEditingController();
  final _concerns = TextEditingController();
  int _rating = 0;
  String? _recommendation;
  String? _problem;
  bool _openingResume = false;

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    unawaited(_c.load());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onOpened?.call(context);
    });
  }

  @override
  void dispose() {
    _strengths.dispose();
    _concerns.dispose();
    _c.dispose();
    super.dispose();
  }

  Future<void> _open(String? url) async {
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null) return;
    await widget.links.openUri(context, uri);
  }

  Future<void> _openResume() async {
    final url = _c.brief?.application.resumeUrl;
    if (url == null || _openingResume) return;
    setState(() => _openingResume = true);
    await openApplicantResume(context, repository: widget.repository, url: url, links: widget.links);
    if (mounted) setState(() => _openingResume = false);
  }

  Future<void> _submit() async {
    final draft = ScorecardDraft(
      rating: _rating,
      recommendation: _recommendation,
      strengths: _strengths.text,
      concerns: _concerns.text,
    );
    if (!draft.ready) return;
    setState(() => _problem = null);
    final error = await _c.submit(draft);
    if (!mounted) return;
    setState(() => _problem = error);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) => CareerScaffold(
        title: 'Interview',
        unread: _c.unread,
        onBell: () => widget.navigation.openNotifications(context, widget.links),
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _c.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: _children(),
          ),
        ),
      ),
    );
  }

  List<Widget> _children() {
    final iv = _c.brief;
    if (iv == null && _c.error != null) {
      return [
        CareerNotice(
          key: const ValueKey('brief-error'),
          icon: LucideIcons.calendarX,
          title: 'Unable to Open This Interview',
          body: _c.error!,
          action: _c.canRetry ? 'Try Again' : null,
          onAction: _c.canRetry ? _c.load : null,
        ),
      ];
    }
    if (iv == null) return const [CareerLoading()];
    return [
      _CandidateHeader(
        brief: iv,
        now: _now,
        openingResume: _openingResume,
        onResume: _openResume,
        onLinkedIn: () => _open(iv.application.linkedinUrl),
      ),
      if (iv.notes != null) ...[const SizedBox(height: 12), _PanelNote(iv.notes!)],
      _Section(
        key: const ValueKey('brief-this-interview'),
        title: 'This Interview',
        child: _ThisInterview(brief: iv, now: _now, onOpen: _open),
      ),
      _Section(
        key: const ValueKey('brief-screening'),
        title: 'From Screening',
        child: _FromScreening(app: iv.application),
      ),
      _Section(
        key: const ValueKey('brief-notes'),
        title: 'Hiring Team Notes',
        child: _TeamNotes(notes: iv.teamNotes, now: _now),
      ),
      _Section(
        key: const ValueKey('brief-earlier-rounds'),
        title: 'Earlier Rounds',
        child: _EarlierRounds(rounds: iv.earlierRounds, now: _now),
      ),
      _Section(
        key: const ValueKey('brief-scorecard'),
        title: iv.isPanelist ? 'Your Scorecard' : 'Panel Scorecards',
        child: iv.isPanelist ? _yourScorecard(iv) : _ScorecardList(iv.panelScorecards, now: _now),
      ),
    ];
  }

  Widget _yourScorecard(InterviewBrief iv) {
    final mine = iv.myScorecard;
    final upcoming = iv.scheduledAt.isAfter(_now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mine != null) ...[
          const StatusPill('Feedback Submitted', key: ValueKey('scorecard-submitted'), tone: PillTone.success),
          const SizedBox(height: 8),
          _ScorecardList([mine], now: _now),
          const SizedBox(height: 14),
          Text('Rest of the Panel', style: CareerText.bodyStrong),
          const SizedBox(height: 6),
          if (iv.panelScorecards.isEmpty)
            Text('No one else on the panel has scored yet.', style: CareerText.body)
          else
            _ScorecardList(iv.panelScorecards, now: _now),
        ] else ...[
          if (iv.cancelled)
            Text(
              'This interview was cancelled. No scorecard is needed.',
              key: const ValueKey('scorecard-cancelled'),
              style: CareerText.body,
            )
          else if (upcoming)
            Text(
              'Your scorecard opens when the interview starts, ${_when(iv.scheduledAt, _now)}.',
              key: const ValueKey('scorecard-not-yet'),
              style: CareerText.body,
            )
          else
            _form(),
          if (iv.panelSubmittedCount > 0) ...[
            const SizedBox(height: 10),
            Text(
              '${iv.panelSubmittedCount} ${iv.panelSubmittedCount == 1 ? 'panelist has' : 'panelists have'} scored '
              'this round. You will see their scorecards once yours is in.',
              key: const ValueKey('panel-hidden'),
              style: CareerText.meta,
            ),
          ],
        ],
      ],
    );
  }

  Widget _form() {
    final ready = _rating > 0 && _recommendation != null;
    return Column(
      key: const ValueKey('scorecard-form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Overall'),
        StarPicker(value: _rating, onChanged: (n) => setState(() => _rating = n), keyPrefix: 'scorecard-star'),
        _label('Recommendation'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final r in scorecardRecommendations)
              ChoiceChip(
                key: ValueKey('scorecard-rec-$r'),
                label: Text(recommendationWord(r)),
                selected: _recommendation == r,
                showCheckmark: false,
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                backgroundColor: AppColors.surfaceContainer,
                selectedColor: AppColors.chipEmphasis,
                labelStyle: CareerText.bodyStrong.copyWith(
                  color: _recommendation == r ? AppColors.primary : AppColors.onSurfaceVariant,
                ),
                onSelected: (_) => setState(() => _recommendation = r),
              ),
          ],
        ),
        _label('Strengths'),
        TextField(
          key: const ValueKey('scorecard-strengths'),
          controller: _strengths,
          minLines: 2,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: hiringDecoration(),
        ),
        _label('Concerns'),
        TextField(
          key: const ValueKey('scorecard-concerns'),
          controller: _concerns,
          minLines: 2,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: hiringDecoration(),
        ),
        if (_problem != null) FormProblem(_problem!),
        const SizedBox(height: 12),
        FilledButton(
          key: const ValueKey('scorecard-submit'),
          onPressed: ready && !_c.submitting ? _submit : null,
          child: Text(_c.submitting ? 'Submitting…' : 'Submit Scorecard'),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 6),
    child: Text(text, style: CareerText.metaStrong),
  );
}

/// "4 Nov 2026, 3:30 PM", as the website's medium date and short time.
String _when(DateTime at, DateTime now) => '${formatDay(at, now: now, year: true)}, ${formatTime(at)}';

PillTone _statusTone(String status) => switch (status) {
  'COMPLETED' => PillTone.success,
  'CANCELLED' || 'NO_SHOW' => PillTone.danger,
  'RESCHEDULED' => PillTone.warning,
  _ => PillTone.brand,
};

/// A titled block of the page, set off from the one above by a thin line (no boxes: owner's rule, 3 Nov 2026).
class _Section extends StatelessWidget {
  const _Section({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Hairline(),
          const SizedBox(height: 14),
          Text(title, style: CareerText.heading.copyWith(fontSize: 14)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// Who the candidate is, from their résumé and what they sent with the application.
class _CandidateHeader extends StatelessWidget {
  const _CandidateHeader({
    required this.brief,
    required this.now,
    required this.openingResume,
    required this.onResume,
    required this.onLinkedIn,
  });

  final InterviewBrief brief;
  final DateTime now;
  final bool openingResume;
  final VoidCallback onResume;
  final VoidCallback onLinkedIn;

  @override
  Widget build(BuildContext context) {
    final app = brief.application;
    final facts = app.facts;
    return Column(
      key: const ValueKey('brief-candidate'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Avatar(name: app.applicantName, url: app.photoUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(app.applicantName, key: const ValueKey('brief-name'), style: CareerText.companyName),
                  if (facts.isNotEmpty) Text(facts.join(' · '), style: CareerText.companyMeta),
                  const SizedBox(height: 3),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'For '),
                        TextSpan(text: app.jobTitle, style: CareerText.bodyStrong),
                      ],
                    ),
                    key: const ValueKey('brief-job'),
                    style: CareerText.body,
                  ),
                  Text('Applied ${formatDay(app.appliedAt, now: now, year: true)}', style: CareerText.meta),
                ],
              ),
            ),
            const SizedBox(width: 8),
            KeyedSubtree(
              key: const ValueKey('brief-stage'),
              child: StatusPill(stageWord(app.stage), tone: stageTone(app.stage)),
            ),
          ],
        ),
        if (app.skills.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in app.skills.take(10))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(10)),
                  child: Text(s, style: CareerText.meta.copyWith(color: AppColors.onSurfaceVariant)),
                ),
            ],
          ),
        ],
        if (app.resumeUrl != null || app.linkedinUrl != null) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (app.resumeUrl != null)
                FilledButton.tonalIcon(
                  key: const ValueKey('brief-resume'),
                  onPressed: openingResume ? null : onResume,
                  icon: openingResume
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(LucideIcons.eye, size: 15),
                  label: const Text('Open Résumé'),
                ),
              if (app.linkedinUrl != null)
                TextButton.icon(
                  key: const ValueKey('brief-linkedin'),
                  onPressed: onLinkedIn,
                  icon: const Icon(LucideIcons.link, size: 15),
                  label: const Text('LinkedIn'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.url});

  final String name;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty ? '?' : '${parts.first[0]}${parts.length > 1 ? parts.last[0] : ''}'.toUpperCase();
    return CircleAvatar(
      radius: 26,
      backgroundColor: AppColors.chipEmphasis,
      backgroundImage: url == null ? null : CachedNetworkImageProvider(url!),
      child: url == null ? Text(initials, style: CareerText.bodyStrong.copyWith(color: AppColors.primary)) : null,
    );
  }
}

/// The recruiter's notes for the panel, on a tint.
class _PanelNote extends StatelessWidget {
  const _PanelNote(this.note);

  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('panel-note'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.chipEmphasis, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Notes for the Panel', style: CareerText.bodyStrong.copyWith(color: AppColors.primary)),
          const SizedBox(height: 3),
          Text(note, style: CareerText.body.copyWith(color: AppColors.onSurface)),
        ],
      ),
    );
  }
}

/// When, how and where, and who else is on the panel.
class _ThisInterview extends StatelessWidget {
  const _ThisInterview({required this.brief, required this.now, required this.onOpen});

  final InterviewBrief brief;
  final DateTime now;
  final Future<void> Function(String? url) onOpen;

  @override
  Widget build(BuildContext context) {
    final upcoming = brief.scheduledAt.isAfter(now);
    final map = brief.mapUri;
    final showLinks = !brief.cancelled && upcoming && (brief.meetingLink != null || map != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(brief.roundLabel, style: CareerText.bodyStrong.copyWith(fontSize: 13))),
            StatusPill(interviewStatusWord(brief.status), tone: _statusTone(brief.status)),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          '${_when(brief.scheduledAt, now)} · ${brief.durationMins} min · ${interviewModeWord(brief.mode)}',
          key: const ValueKey('brief-when'),
          style: CareerText.body,
        ),
        if (brief.address != null) Text(brief.address!, style: CareerText.body),
        if (showLinks) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              if (brief.meetingLink != null)
                FilledButton(
                  key: const ValueKey('brief-join'),
                  onPressed: () => onOpen(brief.meetingLink),
                  child: const Text('Join Meeting'),
                ),
              if (map != null)
                TextButton(
                  key: const ValueKey('brief-map'),
                  onPressed: () => onOpen(map.toString()),
                  child: const Text('Open in Google Maps'),
                ),
            ],
          ),
        ],
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Panel: ', style: CareerText.meta),
              TextSpan(
                text: brief.panel.join(', '),
                style: CareerText.body.copyWith(color: AppColors.onSurface),
              ),
            ],
          ),
          key: const ValueKey('brief-panel'),
        ),
      ],
    );
  }
}

/// What the candidate sent and what screening made of it.
class _FromScreening extends StatelessWidget {
  const _FromScreening({required this.app});

  final BriefApplication app;

  @override
  Widget build(BuildContext context) {
    if (app.nothingFromScreening) {
      return Text(
        'This job asked no screening questions, and the AI screening has not run yet.',
        style: CareerText.body,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (app.coverNote != null) ...[
          Container(
            key: const ValueKey('brief-cover-note'),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cover Note', style: CareerText.metaStrong),
                const SizedBox(height: 3),
                Text(app.coverNote!, style: CareerText.body.copyWith(color: AppColors.onSurface)),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (app.answers.isNotEmpty) ...[_Answers(app: app), const SizedBox(height: 12)],
        if (app.matchScore != null)
          _AiScreening(score: app.matchScore!, signals: app.signals, summary: app.aiSummary)
        else if (app.unscorable)
          Column(
            key: const ValueKey('match-insufficient'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AI Screening', style: CareerText.bodyStrong),
              Text(
                'Not enough information to score: the résumé and profile have no skills, years of experience, '
                'city or expected salary to compare with this job.',
                style: CareerText.body,
              ),
            ],
          ),
      ],
    );
  }
}

/// The answers to the employer's questions, each with its verdict when the question is graded.
class _Answers extends StatelessWidget {
  const _Answers({required this.app});

  final BriefApplication app;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('screening-answers'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Employer Questions', style: CareerText.bodyStrong)),
            if (app.hasQualification)
              StatusPill(
                '${app.qualificationMet ?? 0} / ${app.qualificationTotal} met',
                key: const ValueKey('answers-met'),
              ),
            if (app.hasQualification && !app.qualified) ...[
              const SizedBox(width: 6),
              const StatusPill('Unqualified', tone: PillTone.danger),
            ],
          ],
        ),
        for (final (i, a) in app.answers.indexed)
          Padding(
            key: ValueKey('answer-$i'),
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.prompt, style: CareerText.meta),
                      if (a.mustHave)
                        const Padding(
                          padding: EdgeInsets.only(top: 2, bottom: 2),
                          child: StatusPill('Must-Have', tone: PillTone.danger),
                        ),
                      Text(a.display.isEmpty ? '—' : a.display, style: CareerText.bodyStrong),
                      if (a.graded && a.needed != null) Text('Needed: ${a.needed}', style: CareerText.meta),
                    ],
                  ),
                ),
                if (a.graded) ...[
                  const SizedBox(width: 8),
                  StatusPill(
                    a.meetsIdeal ? 'Met' : 'Not Met',
                    tone: a.meetsIdeal ? PillTone.success : PillTone.neutral,
                    icon: a.meetsIdeal ? LucideIcons.check : LucideIcons.x,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// The AI screening's match ring, its summary and the signals behind it (the website shows the signals on
/// hovering the ring; a phone has no hover, so they are listed).
class _AiScreening extends StatelessWidget {
  const _AiScreening({required this.score, required this.signals, this.summary});

  final int score;
  final List<MatchSignal> signals;
  final String? summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('ai-screening'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 5,
                      color: score >= 70 ? AppColors.success : AppColors.primary,
                      backgroundColor: AppColors.surfaceContainer,
                    ),
                  ),
                  Text('$score%', key: const ValueKey('match-score'), style: CareerText.cardTitle),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('AI Screening', style: CareerText.bodyStrong)),
          ],
        ),
        if (summary != null) ...[const SizedBox(height: 8), Text(summary!, style: CareerText.body)],
        for (final s in signals)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(s.label, style: CareerText.bodyStrong)),
                    Text('${(s.score * 100).round()}%', style: CareerText.meta),
                  ],
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: s.score.clamp(0, 1).toDouble(),
                    minHeight: 6,
                    color: s.score >= 0.7
                        ? AppColors.success
                        : s.score >= 0.4
                        ? AppColors.primary
                        : AppColors.amber500,
                    backgroundColor: AppColors.surfaceContainer,
                  ),
                ),
                if (s.detail != null) ...[const SizedBox(height: 3), Text(s.detail!, style: CareerText.meta)],
              ],
            ),
          ),
      ],
    );
  }
}

/// The hiring team's notes and ratings on the application, oldest first.
class _TeamNotes extends StatelessWidget {
  const _TeamNotes({required this.notes, required this.now});

  final List<BriefNote> notes;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) return Text('The hiring team has not added notes yet.', style: CareerText.body);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, n) in notes.indexed) ...[
          if (i > 0) const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Hairline()),
          Wrap(
            key: ValueKey('note-${n.id}'),
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(n.author ?? 'Hiring team', style: CareerText.bodyStrong),
              Text(formatDay(n.at, now: now, year: true), style: CareerText.meta),
              if (n.rating != null) StarRow(value: n.rating!.toDouble(), size: 13),
              if (n.isStageChange) ...[
                Text('moved to', style: CareerText.meta),
                StatusPill(stageWord(n.toStage!), tone: stageTone(n.toStage!)),
              ],
            ],
          ),
          if (n.note != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(n.note!, style: CareerText.body),
            ),
        ],
      ],
    );
  }
}

/// The rounds held before this one, with what their panels said.
class _EarlierRounds extends StatelessWidget {
  const _EarlierRounds({required this.rounds, required this.now});

  final List<BriefRound> rounds;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    if (rounds.isEmpty) return Text('This is the first round with this candidate.', style: CareerText.body);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, r) in rounds.indexed) ...[
          if (i > 0) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Hairline()),
          Row(
            key: ValueKey('round-${r.id}'),
            children: [
              Expanded(child: Text(r.roundLabel, style: CareerText.bodyStrong)),
              StatusPill(interviewStatusWord(r.status), tone: _statusTone(r.status)),
            ],
          ),
          Text('${_when(r.scheduledAt, now)} · ${r.panel.join(', ')}', style: CareerText.meta),
          const SizedBox(height: 6),
          if (r.scorecards.isEmpty)
            Text('No scorecards submitted.', style: CareerText.body)
          else
            _ScorecardList(r.scorecards, now: now),
        ],
      ],
    );
  }
}

/// Submitted scorecards: who, when, the rating and recommendation, and what they wrote. Thin lines between.
class _ScorecardList extends StatelessWidget {
  const _ScorecardList(this.cards, {required this.now});

  final List<Scorecard> cards;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return Text('No scorecards submitted.', style: CareerText.body);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, c) in cards.indexed) ...[
          if (i > 0) const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Hairline()),
          Column(
            key: ValueKey('scorecard-${c.id}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(c.interviewer ?? 'Former panelist', style: CareerText.bodyStrong)),
                  StarRow(value: c.rating.toDouble(), size: 13),
                  const SizedBox(width: 8),
                  StatusPill(
                    recommendationWord(c.recommendation),
                    tone: switch (c.recommendation) {
                      'STRONG_YES' || 'YES' => PillTone.success,
                      'NO' || 'STRONG_NO' => PillTone.danger,
                      _ => PillTone.neutral,
                    },
                  ),
                ],
              ),
              Text('Submitted ${formatDay(c.submittedAt, now: now, year: true)}', style: CareerText.meta),
              if (c.strengths != null) ...[
                const SizedBox(height: 6),
                Text('Strengths', style: CareerText.meta),
                Text(c.strengths!, style: CareerText.body.copyWith(color: AppColors.onSurface)),
              ],
              if (c.concerns != null) ...[
                const SizedBox(height: 6),
                Text('Concerns', style: CareerText.meta),
                Text(c.concerns!, style: CareerText.body.copyWith(color: AppColors.onSurface)),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
