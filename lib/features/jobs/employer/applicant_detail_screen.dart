import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/util/links.dart' show showMessage;
import '../../career/career_format.dart';
import '../../career/career_styles.dart';
import '../../career/career_widgets.dart';
import '../job_links.dart';
import '../jobs_navigation.dart';
import 'applicants_controller.dart';
import 'applicants_screen.dart' show ApplicantAvatar, stageTone;
import 'hiring_models.dart';
import 'hiring_repository.dart';
import 'hiring_sheets.dart';

/// One application read whole by the hiring team: who applied, their answers marked against your bar,
/// the rounds and the offer, your notes and rating, and everything done to it so far. From here the
/// team moves it on, books an interview, makes an offer or messages the applicant.
class ApplicantDetailScreen extends StatefulWidget {
  const ApplicantDetailScreen({
    super.key,
    required this.repository,
    required this.applicant,
    this.jobTitle,
    this.links = const SystemJobLinks(),
    this.navigation = JobsNavigation.none,
    this.onChanged,
    this.onBack,
    this.clock,
  });

  final HiringRepository repository;

  /// The pipeline row this opened from; the whole application loads under it.
  final Applicant applicant;
  final String? jobTitle;
  final JobLinks links;
  final JobsNavigation navigation;

  /// Tells the pipeline an application changed, so its row follows.
  final void Function(Applicant applicant)? onChanged;
  final VoidCallback? onBack;
  final DateTime Function()? clock;

  @override
  State<ApplicantDetailScreen> createState() => _ApplicantDetailScreenState();
}

class _ApplicantDetailScreenState extends State<ApplicantDetailScreen> {
  late final ApplicantDetailController _c = ApplicantDetailController(
    widget.repository,
    seed: widget.applicant,
    onChanged: widget.onChanged,
    clock: widget.clock,
  );
  final _note = TextEditingController();
  int _stars = 0;
  String? _noteProblem;

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _c.start();
  }

  @override
  void dispose() {
    _note.dispose();
    _c.dispose();
    super.dispose();
  }

  void _tell(String? error, String done) {
    if (!mounted) return;
    showMessage(context, error ?? done);
  }

  Future<void> _move(String to) async {
    final a = _c.applicant;
    String? note;
    if (to == 'REJECTED') {
      note = await askStageNote(
        context,
        title: 'Not selecting ${a.name}?',
        body: 'They are told their application was not selected. You can move them back later.',
        confirm: 'Reject',
        destructive: true,
        hint: 'Why (only your team sees this)',
      );
      if (note == null || !mounted) return;
    }
    final error = await _c.move(to, note: note);
    _tell(error, '${a.name} moved to ${stageWord(to).toLowerCase()}.');
  }

  Future<void> _addNote() async {
    final text = _note.text.trim();
    if (text.isEmpty && _stars == 0) {
      setState(() => _noteProblem = 'Write a note or give a rating.');
      return;
    }
    setState(() => _noteProblem = null);
    final error = await _c.addNote(note: text, rating: _stars == 0 ? null : _stars);
    if (!mounted) return;
    if (error == null) {
      _note.clear();
      setState(() => _stars = 0);
    } else {
      setState(() => _noteProblem = error);
    }
  }

  Future<void> _schedule({TeamInterview? existing}) async {
    await _c.loadTeam();
    String? me;
    try {
      me = (await widget.repository.access()).userId;
    } catch (_) {
      // The panel starts empty.
    }
    if (!mounted) return;
    await showInterviewSheet(
      context,
      team: _c.team,
      meId: me,
      existing: existing,
      applicantName: _c.applicant.name,
      clock: () => _now,
      onSubmit: (draft) => existing == null ? _c.schedule(draft) : _c.reschedule(existing, draft),
    );
  }

  Future<void> _interviewStatus(TeamInterview iv, String status) async {
    if (status == 'CANCELLED') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          key: const ValueKey('cancel-interview-dialog'),
          title: Text('Cancel ${iv.name}?'),
          content: Text('${_c.applicant.name} and the panel are told it is off.'),
          actions: [
            TextButton(
              key: const ValueKey('cancel-interview-keep'),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep it'),
            ),
            TextButton(
              key: const ValueKey('cancel-interview-confirm'),
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Cancel interview'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    final error = await _c.setInterviewStatus(iv, status);
    _tell(error, switch (status) {
      'CANCELLED' => '${iv.name} is cancelled.',
      'COMPLETED' => '${iv.name} is marked done.',
      _ => '${iv.name} is marked as a no-show.',
    });
  }

  Future<void> _offer({TeamOffer? existing}) async {
    await showOfferSheet(
      context,
      jobTitle: existing?.jobTitle ?? _c.detail?.jobTitle ?? widget.jobTitle,
      applicantName: _c.applicant.name,
      existing: existing,
      clock: () => _now,
      onSubmit: (draft, send) async {
        if (existing != null) {
          final error = await _c.editOffer(existing, draft);
          if (error != null) return error;
          if (send && existing.status == 'DRAFT') return _c.sendOffer(existing);
          return null;
        }
        return _c.makeOffer(draft, send: send);
      },
    );
  }

  Future<void> _sendDraft(TeamOffer offer) async {
    final error = await _c.sendOffer(offer);
    _tell(error, 'The offer was sent to ${_c.applicant.name}.');
  }

  Future<void> _message() async {
    final result = await _c.message();
    if (!mounted) return;
    if (result.error != null) {
      showMessage(context, result.error!);
      return;
    }
    await widget.navigation.openConversation(context, widget.links, result.conversationId);
  }

  Future<void> _open(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await widget.links.openUri(context, uri);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) => CareerScaffold(
        title: 'Applicant',
        onBack: widget.onBack,
        unread: _c.unread,
        onBell: () => widget.navigation.openNotifications(context, widget.links),
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _c.start,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 32),
            children: _children(),
          ),
        ),
      ),
    );
  }

  List<Widget> _children() {
    final a = _c.applicant;
    final d = _c.detail;
    if (_c.error != null && d == null) {
      return [
        CareerNotice(
          key: const ValueKey('detail-error'),
          icon: LucideIcons.cloudOff,
          title: "Couldn't open this application",
          body: _c.error!,
          action: 'Try again',
          onAction: _c.start,
        ),
      ];
    }
    return [
      _header(a),
      const SizedBox(height: 10),
      _actions(a, d),
      if (d == null)
        const CareerLoading()
      else ...[
        if (d.aiSummary != null && d.aiSummary!.trim().isNotEmpty)
          _card('summary', 'Summary', [Text(d.aiSummary!, style: CareerText.body)]),
        if (a.coverNote != null && a.coverNote!.trim().isNotEmpty)
          _card('cover-note', 'Cover note', [Text(a.coverNote!, style: CareerText.body)]),
        if (d.answers.isNotEmpty) _answers(d.answers),
        _interviews(d.interviews),
        if (d.offers.isNotEmpty) _offers(d.offers),
        _notes(),
        _activity(d.events),
      ],
    ];
  }

  Widget _header(Applicant a) {
    final facts = [
      if (a.currentCompany != null && a.currentCompany!.isNotEmpty) a.currentCompany!,
      if (a.location != null && a.location!.isNotEmpty) a.location!,
      if (a.experienceYears != null) '${_years(a.experienceYears!)} yrs experience',
      if (a.noticePeriodDays != null) '${a.noticePeriodDays} days notice',
    ];
    return Container(
      key: const ValueKey('detail-header'),
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ApplicantAvatar(applicant: a, radius: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.name, key: const ValueKey('detail-name'), style: CareerText.companyName),
                    if (a.headline != null && a.headline!.isNotEmpty) Text(a.headline!, style: CareerText.companyMeta),
                    if (facts.isNotEmpty) Text(facts.join(' • '), style: CareerText.meta),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        KeyedSubtree(
                          key: const ValueKey('detail-stage'),
                          child: StatusPill(stageWord(a.stage), tone: stageTone(a.stage)),
                        ),
                        if (a.matchScore != null) StatusPill('${a.matchScore}% match', tone: PillTone.brand),
                        if (a.qualificationsTotal != null && a.qualificationsTotal! > 0)
                          StatusPill(
                            '${a.qualificationsMet ?? 0} of ${a.qualificationsTotal} met',
                            tone: (a.qualificationsMet ?? 0) >= a.qualificationsTotal!
                                ? PillTone.success
                                : PillTone.neutral,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (a.skills.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in a.skills.take(8))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(s, style: CareerText.meta.copyWith(color: AppColors.onSurfaceVariant)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Applied ${formatDay(a.appliedAt, now: _now, year: true)}${a.source == null || a.source!.isEmpty ? '' : ' • via ${_sourceWord(a.source!)}'}',
            style: CareerText.meta,
          ),
          if (a.expectedSalary != null)
            Text(
              'Expects ${formatMoney(a.expectedSalary!)} a year',
              key: const ValueKey('detail-expected'),
              style: CareerText.meta,
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            children: [
              if (a.email != null && a.email!.isNotEmpty)
                _LinkChip(
                  key: const ValueKey('detail-email'),
                  icon: LucideIcons.mail,
                  label: a.email!,
                  onTap: () => _open('mailto:${a.email}'),
                ),
              if (a.resumeFileUrl != null)
                _LinkChip(
                  key: const ValueKey('detail-resume'),
                  icon: LucideIcons.fileText,
                  label: a.resumeTitle == null || a.resumeTitle!.isEmpty ? 'Résumé' : a.resumeTitle!,
                  onTap: () => _open(a.resumeFileUrl),
                ),
              if (a.linkedinUrl != null && a.linkedinUrl!.isNotEmpty)
                _LinkChip(
                  key: const ValueKey('detail-linkedin'),
                  icon: LucideIcons.link,
                  label: 'LinkedIn',
                  onTap: () => _open(a.linkedinUrl),
                ),
              if (a.profilePublic)
                _LinkChip(
                  key: const ValueKey('detail-profile'),
                  icon: LucideIcons.user,
                  label: 'Profile',
                  onTap: () => widget.navigation.openProfile(context, widget.links, a.userId),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actions(Applicant a, ApplicantDetail? d) {
    final moves = stageMoves[a.stage] ?? const <String>[];
    final forward = moves.where((s) => s != 'REJECTED').toList();
    final liveOffer =
        d?.offers.any((o) => o.status == 'DRAFT' || o.status == 'SENT' || o.status == 'ACCEPTED') ?? false;
    final canSchedule = const {'APPLIED', 'SCREENING', 'INTERVIEW'}.contains(a.stage);
    final canOffer = const {'SCREENING', 'INTERVIEW', 'OFFER'}.contains(a.stage) && !liveOffer && d != null;
    final busy = _c.busy;
    return Container(
      key: const ValueKey('detail-actions'),
      padding: const EdgeInsets.all(12),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Next step', style: CareerText.heading),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (i, to) in forward.indexed)
                i == 0
                    ? FilledButton(
                        key: ValueKey('detail-move-$to'),
                        onPressed: busy ? null : () => _move(to),
                        child: Text(moveVerb(to)),
                      )
                    : OutlinedButton(
                        key: ValueKey('detail-move-$to'),
                        onPressed: busy ? null : () => _move(to),
                        child: Text(moveVerb(to)),
                      ),
              if (canSchedule)
                OutlinedButton.icon(
                  key: const ValueKey('detail-schedule'),
                  onPressed: busy ? null : () => _schedule(),
                  icon: const Icon(LucideIcons.calendarPlus, size: 15),
                  label: const Text('Schedule interview'),
                ),
              if (canOffer)
                OutlinedButton.icon(
                  key: const ValueKey('detail-offer'),
                  onPressed: busy ? null : () => _offer(),
                  icon: const Icon(LucideIcons.handshake, size: 15),
                  label: const Text('Make an offer'),
                ),
              OutlinedButton.icon(
                key: const ValueKey('detail-message'),
                onPressed: busy ? null : _message,
                icon: const Icon(LucideIcons.messageSquare, size: 15),
                label: const Text('Message'),
              ),
              if (moves.contains('REJECTED'))
                OutlinedButton(
                  key: const ValueKey('detail-reject'),
                  onPressed: busy ? null : () => _move('REJECTED'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  child: const Text('Reject'),
                ),
            ],
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: LinearProgressIndicator(key: ValueKey('detail-busy'), minHeight: 2),
            ),
        ],
      ),
    );
  }

  Widget _card(String key, String title, List<Widget> children) => Container(
    key: ValueKey('section-$key'),
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(14),
    decoration: cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: CareerText.heading.copyWith(fontSize: 14)),
        const SizedBox(height: 8),
        ...children,
      ],
    ),
  );

  Widget _answers(List<GradedAnswer> answers) => _card('answers', 'Screening answers', [
    for (final (i, g) in answers.indexed)
      Padding(
        key: ValueKey('answer-$i'),
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                g.meetsIdeal == null
                    ? LucideIcons.circleHelp
                    : (g.meetsIdeal! ? LucideIcons.circleCheck : LucideIcons.circleX),
                size: 16,
                color: g.meetsIdeal == null
                    ? AppColors.outline
                    : (g.meetsIdeal! ? AppColors.successInk : AppColors.error),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(g.prompt, style: CareerText.bodyStrong),
                  Text(g.display.isEmpty ? 'No answer' : g.display, style: CareerText.body),
                  if (g.meetsIdeal == false)
                    Text(
                      g.mustHave ? 'Misses a must-have' : 'Below your bar',
                      style: CareerText.meta.copyWith(color: AppColors.error),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
  ]);

  Widget _interviews(List<TeamInterview> list) => _card('interviews', 'Interviews', [
    if (list.isEmpty) Text('No interview booked yet.', key: const ValueKey('no-interviews'), style: CareerText.meta),
    for (final iv in list) _interviewCard(iv),
  ]);

  Widget _interviewCard(TeamInterview iv) {
    final tone = switch (iv.status) {
      'COMPLETED' => PillTone.success,
      'CANCELLED' || 'NO_SHOW' => PillTone.danger,
      'RESCHEDULED' => PillTone.warning,
      _ => PillTone.brand,
    };
    final past = !iv.scheduledAt.isAfter(_now);
    return Container(
      key: ValueKey('interview-${iv.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(iv.name, style: CareerText.bodyStrong)),
              StatusPill(_ivStatus(iv.status), tone: tone),
            ],
          ),
          const SizedBox(height: 4),
          Text('${formatWhen(iv.scheduledAt)} • ${iv.durationMins} min • ${iv.modeLabel}', style: CareerText.body),
          if (iv.location != null && iv.location!.isNotEmpty) Text(iv.location!, style: CareerText.meta),
          if (iv.meetingLink != null && iv.meetingLink!.isNotEmpty)
            TextButton.icon(
              key: ValueKey('interview-link-${iv.id}'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 28),
                alignment: Alignment.centerLeft,
              ),
              onPressed: () => _open(iv.meetingLink),
              icon: const Icon(LucideIcons.video, size: 14),
              label: Text('Open the meeting link', style: CareerText.link),
            ),
          if (iv.panel.isNotEmpty) Text('Panel: ${iv.panel.map((p) => p.name).join(', ')}', style: CareerText.meta),
          if (iv.notes != null && iv.notes!.isNotEmpty) Text('Notes: ${iv.notes}', style: CareerText.meta),
          for (final f in iv.feedback)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${f.interviewer}: ${f.rating}/5, ${f.recommendationLabel}${f.strengths == null || f.strengths!.isEmpty ? '' : '. ${f.strengths}'}',
                style: CareerText.meta.copyWith(color: AppColors.onSurfaceVariant),
              ),
            ),
          if (iv.live)
            Wrap(
              spacing: 6,
              children: [
                TextButton(
                  key: ValueKey('interview-reschedule-${iv.id}'),
                  onPressed: _c.busy ? null : () => _schedule(existing: iv),
                  child: Text('Reschedule', style: CareerText.link),
                ),
                if (past)
                  TextButton(
                    key: ValueKey('interview-done-${iv.id}'),
                    onPressed: _c.busy ? null : () => _interviewStatus(iv, 'COMPLETED'),
                    child: Text('Mark done', style: CareerText.link),
                  ),
                if (past)
                  TextButton(
                    key: ValueKey('interview-noshow-${iv.id}'),
                    onPressed: _c.busy ? null : () => _interviewStatus(iv, 'NO_SHOW'),
                    child: Text('No-show', style: CareerText.link),
                  ),
                TextButton(
                  key: ValueKey('interview-cancel-${iv.id}'),
                  onPressed: _c.busy ? null : () => _interviewStatus(iv, 'CANCELLED'),
                  child: Text('Cancel', style: CareerText.link.copyWith(color: AppColors.error)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _offers(List<TeamOffer> offers) => _card('offers', 'Offer', [for (final o in offers) _offerCard(o)]);

  Widget _offerCard(TeamOffer o) {
    final tone = switch (o.status) {
      'ACCEPTED' => PillTone.success,
      'DECLINED' || 'WITHDRAWN' || 'EXPIRED' => PillTone.danger,
      'SENT' => PillTone.warning,
      _ => PillTone.neutral,
    };
    return Container(
      key: ValueKey('offer-${o.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${formatMoney(o.amount, currency: o.currency)} ${periodSuffix(o.period)}',
                  key: ValueKey('offer-amount-${o.id}'),
                  style: CareerText.money,
                ),
              ),
              StatusPill(_offerStatus(o.status), tone: tone),
            ],
          ),
          if (o.jobTitle != null && o.jobTitle!.isNotEmpty) Text(o.jobTitle!, style: CareerText.body),
          if (o.joiningDate != null)
            Text('Joining ${formatDay(o.joiningDate!, now: _now, year: true)}', style: CareerText.meta),
          if (o.expiresAt != null)
            Text('Reply by ${formatDay(o.expiresAt!, now: _now, year: true)}', style: CareerText.meta),
          if (o.candidateNote != null && o.candidateNote!.isNotEmpty)
            Text('They wrote: ${o.candidateNote}', style: CareerText.meta),
          if (o.status == 'DRAFT' || o.status == 'SENT')
            Wrap(
              spacing: 6,
              children: [
                if (o.status == 'DRAFT')
                  FilledButton(
                    key: ValueKey('offer-send-draft-${o.id}'),
                    onPressed: _c.busy ? null : () => _sendDraft(o),
                    child: const Text('Send offer'),
                  ),
                TextButton(
                  key: ValueKey('offer-edit-${o.id}'),
                  onPressed: _c.busy ? null : () => _offer(existing: o),
                  child: Text('Edit', style: CareerText.link),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _notes() => _card('notes', 'Your notes and rating', [
    Text('Only your hiring team sees these.', style: CareerText.meta),
    const SizedBox(height: 8),
    StarPicker(value: _stars, onChanged: (n) => setState(() => _stars = n), keyPrefix: 'note-star'),
    const SizedBox(height: 8),
    TextField(
      key: const ValueKey('note-input'),
      controller: _note,
      minLines: 2,
      maxLines: 5,
      maxLength: 1000,
      decoration: hiringDecoration(hint: 'What stood out, what to ask next'),
    ),
    if (_noteProblem != null) FormProblem(_noteProblem!),
    Align(
      alignment: Alignment.centerRight,
      child: FilledButton(
        key: const ValueKey('note-save'),
        onPressed: _c.busy ? null : _addNote,
        child: const Text('Add note'),
      ),
    ),
  ]);

  Widget _activity(List<ActivityEvent> events) => _card('activity', 'Activity', [
    if (events.isEmpty) Text('Nothing yet.', style: CareerText.meta),
    for (final (i, e) in events.indexed)
      Padding(
        key: ValueKey('activity-$i'),
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 3, right: 8),
              child: Icon(LucideIcons.circleDot, size: 11, color: AppColors.outline),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(activityWords(e), style: CareerText.body.copyWith(color: AppColors.onSurface)),
                  Text(
                    '${e.actor == null || e.actor!.isEmpty ? '' : '${e.actor} • '}${formatWhen(e.at)}',
                    style: CareerText.meta,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
  ]);

  static String _years(double y) => y == y.roundToDouble() ? y.toInt().toString() : y.toStringAsFixed(1);

  static String _sourceWord(String source) => switch (source) {
    'INVITE' => 'an invite',
    'EXTERNAL' => 'an external link',
    'CAMPAIGN' => 'a campaign',
    _ => source.toLowerCase().replaceAll('_', ' '),
  };

  static String _ivStatus(String s) => switch (s) {
    'SCHEDULED' => 'Scheduled',
    'RESCHEDULED' => 'Rescheduled',
    'COMPLETED' => 'Done',
    'CANCELLED' => 'Cancelled',
    'NO_SHOW' => 'No-show',
    _ => s,
  };

  static String _offerStatus(String s) => switch (s) {
    'DRAFT' => 'Draft',
    'SENT' => 'Sent',
    'ACCEPTED' => 'Accepted',
    'DECLINED' => 'Declined',
    'WITHDRAWN' => 'Withdrawn',
    'EXPIRED' => 'Expired',
    _ => s,
  };
}

/// One line of the activity trail in words.
String activityWords(ActivityEvent e) {
  final note = e.note == null || e.note!.trim().isEmpty ? '' : ': ${e.note}';
  return switch (e.type) {
    'STAGE_CHANGE' =>
      e.fromStage == null || e.fromStage == e.toStage
          ? 'Applied$note'
          : 'Moved from ${stageWord(e.fromStage!).toLowerCase()} to ${stageWord(e.toStage ?? '').toLowerCase()}$note',
    'NOTE' => 'Note$note',
    'RATING' => 'Rated ${e.rating ?? 0} ${e.rating == 1 ? 'star' : 'stars'}',
    'VIEWED' => 'Opened by the hiring team',
    'SCREENING_GRADED' => 'Screening answers marked',
    'AUTO_ARCHIVED' => 'Not selected automatically: a must-have answer was missed',
    'INTERVIEW_SCHEDULED' => 'Interview booked$note',
    'INTERVIEW_UPDATED' => 'Interview changed$note',
    'FEEDBACK_SUBMITTED' => 'Interview feedback added',
    'OFFER_CREATED' => 'Offer drafted',
    'OFFER_SENT' => 'Offer sent',
    'OFFER_RESPONDED' => 'Offer answered$note',
    'WITHDRAWN' => 'The applicant withdrew',
    _ => e.type.toLowerCase().replaceAll('_', ' '),
  };
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 14, color: AppColors.primary),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 190),
        child: Text(label, overflow: TextOverflow.ellipsis, style: CareerText.link),
      ),
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppColors.outlineVariant),
      onPressed: onTap,
    );
  }
}
