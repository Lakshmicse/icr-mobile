import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart' show showMessage;
import '../jobs/job_detail_sheet.dart';
import '../jobs/job_links.dart';
import '../jobs/jobs_navigation.dart';
import '../jobs/widgets/job_row.dart';
import 'application_dialogs.dart';
import 'application_logic.dart';
import 'application_widgets.dart';
import 'applications_controller.dart';
import 'career_base.dart';
import 'career_format.dart';
import 'career_models.dart';
import 'career_repository.dart';
import 'career_styles.dart';
import 'career_widgets.dart';
import 'my_applications_screen.dart' show LockedTimelineNotice;

/// One application, as the person who made it reads it (the website's
/// `/career/applications/:id`): where it stands, an offer to answer, the match, every
/// interview round, the answers and the résumé sent, and the timeline.
class ApplicationDetailScreen extends StatefulWidget {
  const ApplicationDetailScreen({
    super.key,
    required this.repository,
    required this.application,
    this.links = const SystemJobLinks(),
    this.navigation = JobsNavigation.none,
    this.onChanged,
    this.onBack,
    this.clock,
  });

  final CareerRepository repository;

  /// What the list knew; the page reads the whole application.
  final CareerApplication application;
  final JobLinks links;
  final JobsNavigation navigation;

  /// Tells the list a change (withdrawn, an offer answered).
  final void Function(CareerApplication app)? onChanged;
  final VoidCallback? onBack;
  final CareerClock? clock;

  @override
  State<ApplicationDetailScreen> createState() => _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState extends State<ApplicationDetailScreen> with WidgetsBindingObserver {
  late final ApplicationDetailController _c = ApplicationDetailController(
    widget.repository,
    seed: widget.application,
    onChanged: widget.onChanged,
    clock: widget.clock,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _c.start();
  }

  /// Back in front (the person moved to the website or another app and returned): the application is read
  /// again, so a stage the employer moved meanwhile shows without a pull.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _c.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _c.dispose();
    super.dispose();
  }

  DateTime get _now => _c.clock();

  void _openJob() => showJobDetail(
    context,
    _c.app.job,
    repository: widget.repository.jobs,
    links: widget.links,
    navigation: widget.navigation,
  );

  Future<void> _message({String? message}) async {
    final result = await _c.messageHiringTeam(message: message);
    if (!mounted) return;
    if (result.error != null) {
      showMessage(context, result.error!);
      return;
    }
    await widget.navigation.openConversation(context, widget.links, result.conversationId);
  }

  Future<void> _withdraw() async {
    if (!await confirmWithdraw(context, _c.app) || !mounted) return;
    final message = await _c.withdraw();
    if (!mounted) return;
    showMessage(context, message ?? 'Application withdrawn. It is now under Archived.');
  }

  Future<void> _respond(bool accept) async {
    final offer = _c.app.latestOffer;
    if (offer == null) return;
    final decision = await askOfferDecision(context, offer, accept: accept);
    if (!decision.confirmed || !mounted) return;
    final message = await _c.respondToOffer(accept: accept, note: decision.note);
    if (!mounted) return;
    showMessage(
      context,
      message ?? (accept ? 'Offer accepted. Congratulations!' : 'Offer declined. The application is now archived.'),
    );
  }

  /// There is no RSVP for a candidate in the API: confirming, or asking for another time, is a
  /// message to the hiring team, in the thread that already holds the rest of the conversation.
  Future<void> _confirmRound(CareerInterview iv) => _message(message: confirmRoundMessage(_c.app, iv));

  Future<void> _rescheduleRound(CareerInterview iv) async {
    final proposal = await askForAnotherTime(context, iv);
    if (proposal == null || !mounted) return;
    await _message(message: rescheduleRoundMessage(_c.app, iv, proposal));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) => CareerScaffold(
        title: 'Your application',
        onBack: widget.onBack,
        unread: _c.unread,
        onBell: () => widget.navigation.openNotifications(context, widget.links),
        body: _body(),
      ),
    );
  }

  Widget _body() {
    if (_c.error != null) {
      return ListView(
        children: [
          CareerNotice(
            key: const ValueKey('application-error'),
            icon: LucideIcons.cloudOff,
            title: "Couldn't open this application",
            body: _c.error!,
            action: 'Try again',
            onAction: _c.start,
          ),
        ],
      );
    }
    final app = _c.app;
    final now = _now;
    final status = statusOf(app);
    final progress = progressOf(app);
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _c.start,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 32),
        children: [
          if (_c.loading) const LinearProgressIndicator(minHeight: 2),
          _Header(app: app, status: status, onOpenJob: _openJob),
          if (app.latestOffer != null) ...[
            const SizedBox(height: 10),
            _OfferPanel(offer: app.latestOffer!, now: now, busy: _c.busy, onRespond: _respond),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('view-job'),
                onPressed: _openJob,
                icon: const Icon(LucideIcons.briefcaseBusiness, size: 14),
                label: const Text('View job'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('message-team'),
                onPressed: _c.busy ? null : () => _message(),
                icon: const Icon(LucideIcons.messageSquare, size: 14),
                label: const Text('Message hiring team'),
              ),
              if (canWithdraw(app))
                TextButton.icon(
                  key: const ValueKey('withdraw'),
                  onPressed: _c.busy ? null : _withdraw,
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  icon: const Icon(LucideIcons.undo2, size: 14),
                  label: const Text('Withdraw'),
                ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 14),
            _Section(
              title: 'Where it stands',
              child: ApplicationProgress(steps: progress),
            ),
          ],
          const SizedBox(height: 10),
          _Match(app: app, onPlans: () => widget.links.openSite(context, '/career/plans')),
          if (app.interviews.isNotEmpty) ...[
            const SizedBox(height: 10),
            _Interviews(app: app, links: widget.links, onConfirm: _confirmRound, onReschedule: _rescheduleRound),
          ],
          if (app.answers.isNotEmpty) ...[
            const SizedBox(height: 10),
            _Section(
              title: 'Your answers',
              caption: 'What you told the employer when you applied.',
              child: Column(
                key: const ValueKey('my-answers'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, a) in app.answers.indexed) ...[
                    if (i > 0) const Divider(height: 18, color: AppColors.cardRule),
                    Text(a.prompt, style: CareerText.bodyStrong),
                    const SizedBox(height: 2),
                    Text(a.display, style: CareerText.body),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          _Sent(app: app),
          const SizedBox(height: 10),
          _Section(
            title: 'Timeline',
            child: app.visibilityLocked
                ? LockedTimelineNotice(onUpgrade: () => widget.links.openSite(context, '/career/plans'))
                : _Timeline(app: app),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.caption});

  final String title;
  final String? caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: CareerText.heading.copyWith(fontSize: 14)),
          if (caption != null) ...[const SizedBox(height: 2), Text(caption!, style: CareerText.meta)],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.app, required this.status, required this.onOpenJob});

  final CareerApplication app;
  final AppStatus status;
  final VoidCallback onOpenJob;

  @override
  Widget build(BuildContext context) {
    final company = JobCompany(id: app.companyId ?? '', name: app.companyName ?? app.jobTitle, logo: app.companyLogo);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CompanyLogoTile(company: company, width: 48, height: 52),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: onOpenJob,
                  child: Text(app.jobTitle, style: CareerText.cardTitle.copyWith(fontSize: 14), maxLines: 3),
                ),
                const SizedBox(height: 2),
                Text([?app.companyName, ?app.city].join(' • '), style: CareerText.companyMeta, maxLines: 2),
                Text('Applied ${formatDay(app.createdAt, year: true)}', style: CareerText.meta),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    KeyedSubtree(
                      key: const ValueKey('application-status'),
                      child: StatusPill(status.label, tone: toneOf(status)),
                    ),
                    if (app.viewedAt != null)
                      StatusPill('Viewed ${formatDay(app.viewedAt!)}', tone: PillTone.success, icon: LucideIcons.eye),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The offer, with its terms and, while it is open, Decline and Accept.
class _OfferPanel extends StatelessWidget {
  const _OfferPanel({required this.offer, required this.now, required this.busy, required this.onRespond});

  final CareerOffer offer;
  final DateTime now;
  final bool busy;
  final void Function(bool accept) onRespond;

  @override
  Widget build(BuildContext context) {
    if (offer.open) return OfferStrip(offer: offer, now: now, busy: busy, onRespond: onRespond);
    final accepted = offer.status == 'ACCEPTED';
    return NoteStrip(
      key: const ValueKey('offer-answered'),
      icon: accepted ? LucideIcons.circleCheck : LucideIcons.circleMinus,
      color: accepted ? AppColors.successInk : AppColors.outline,
      child: Text(
        accepted
            ? 'You accepted this offer: ${offerAmount(offer)}.'
            : 'You declined this offer: ${offerAmount(offer)}.',
        style: CareerText.body,
      ),
    );
  }
}

class _Match extends StatelessWidget {
  const _Match({required this.app, required this.onPlans});

  final CareerApplication app;
  final VoidCallback onPlans;

  @override
  Widget build(BuildContext context) {
    final score = app.matchScore;
    final signals = app.signals;
    return _Section(
      title: 'Your match',
      child: score == null
          ? Text(
              'ICR is still scoring this application against your résumé. Check back soon.',
              key: const ValueKey('match-scoring'),
              style: CareerText.body,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 56,
                      height: 56,
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
                    Expanded(
                      child: Text('How closely your résumé fits what this job asks for.', style: CareerText.body),
                    ),
                  ],
                ),
                if (signals != null && signals.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Column(
                    key: const ValueKey('match-breakdown'),
                    children: [
                      for (final s in signals)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
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
                                  value: s.score.clamp(0, 1),
                                  minHeight: 6,
                                  color: s.score >= 0.7
                                      ? AppColors.success
                                      : s.score >= 0.4
                                      ? AppColors.primary
                                      : AppColors.amber500,
                                  backgroundColor: AppColors.surfaceContainer,
                                ),
                              ),
                              if (s.detail != null) ...[
                                const SizedBox(height: 3),
                                Text(s.detail!, style: CareerText.meta),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
                if (app.signalsLocked)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      key: const ValueKey('match-locked'),
                      children: [
                        const Icon(LucideIcons.lock, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'The breakdown behind your match is part of Career Plus.',
                            style: CareerText.body,
                          ),
                        ),
                        TextButton(
                          onPressed: onPlans,
                          child: Text('See plans', style: CareerText.link),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Interviews extends StatelessWidget {
  const _Interviews({required this.app, required this.links, required this.onConfirm, required this.onReschedule});

  final CareerApplication app;
  final JobLinks links;
  final void Function(CareerInterview) onConfirm;
  final void Function(CareerInterview) onReschedule;

  @override
  Widget build(BuildContext context) {
    final rounds = [...app.interviews]..sort((a, b) => a.round.compareTo(b.round));
    return _Section(
      title: 'Interviews',
      child: Column(
        key: const ValueKey('interviews'),
        children: [
          for (final (i, iv) in rounds.indexed) ...[
            if (i > 0) const Divider(height: 22, color: AppColors.cardRule),
            _Round(interview: iv, links: links, onConfirm: onConfirm, onReschedule: onReschedule),
          ],
        ],
      ),
    );
  }
}

class _Round extends StatelessWidget {
  const _Round({required this.interview, required this.links, required this.onConfirm, required this.onReschedule});

  final CareerInterview interview;
  final JobLinks links;
  final void Function(CareerInterview) onConfirm;
  final void Function(CareerInterview) onReschedule;

  @override
  Widget build(BuildContext context) {
    final iv = interview;
    final join = iv.joinUrl;
    final map = iv.mapUrl;
    final address = iv.mode == InterviewMode.inPerson ? iv.location?.trim() : null;
    return Column(
      key: ValueKey('round-${iv.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(iv.name, style: CareerText.bodyStrong)),
            StatusPill(
              iv.statusLabel,
              tone: switch (iv.status) {
                'COMPLETED' => PillTone.success,
                'CANCELLED' || 'NO_SHOW' => PillTone.danger,
                _ => PillTone.brand,
              },
            ),
          ],
        ),
        Text('${formatWhen(iv.scheduledAt)} • ${iv.mode.label} • ${iv.durationMins} min', style: CareerText.meta),
        if (address != null && address.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(address, style: CareerText.body),
        ],
        if (iv.live) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (join != null)
                StripButton(
                  key: ValueKey('join-${iv.id}'),
                  label: 'Join call',
                  icon: LucideIcons.video,
                  filled: true,
                  onTap: () => links.openUri(context, join),
                ),
              if (map != null)
                StripButton(
                  key: ValueKey('map-${iv.id}'),
                  label: 'Open in Maps',
                  icon: LucideIcons.mapPin,
                  onTap: () => links.openUri(context, map),
                ),
              StripButton(
                key: ValueKey('confirm-${iv.id}'),
                label: 'Confirm I will attend',
                icon: LucideIcons.check,
                onTap: () => onConfirm(iv),
              ),
              StripButton(
                key: ValueKey('reschedule-${iv.id}'),
                label: 'Ask for another time',
                icon: LucideIcons.calendarClock,
                onTap: () => onReschedule(iv),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Sent extends StatelessWidget {
  const _Sent({required this.app});

  final CareerApplication app;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, Widget value) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: CareerText.meta),
          value,
        ],
      ),
    );
    final expected = app.expectedSalary;
    return _Section(
      title: 'What you sent',
      child: Column(
        key: const ValueKey('sent'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row('Résumé', Text(app.resumeTitle ?? 'Your ICR profile', style: CareerText.body)),
          if (app.coverNote != null && app.coverNote!.isNotEmpty)
            row('Note to the hiring team', Text(app.coverNote!, style: CareerText.body)),
          if (app.linkedinUrl != null && app.linkedinUrl!.isNotEmpty)
            row('LinkedIn', Text(app.linkedinUrl!, style: CareerText.body)),
          if (expected != null) row('Expected salary', Text('${formatMoney(expected)} a year', style: CareerText.body)),
        ],
      ),
    );
  }
}

/// The application's history, newest last, in the member's words.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.app});

  final CareerApplication app;

  static String _stage(String? s) => switch (s) {
    'APPLIED' => 'applied',
    'SCREENING' => 'in review',
    'INTERVIEW' => 'interview',
    'OFFER' => 'offer',
    'HIRED' => 'hired',
    'REJECTED' => 'not selected',
    'WITHDRAWN' => 'withdrawn',
    _ => (s ?? '').toLowerCase(),
  };

  static String words(CareerEvent e) => switch (e.type) {
    'STAGE_CHANGE' when e.toStage == 'APPLIED' => 'You applied',
    'STAGE_CHANGE' => 'Moved to ${_stage(e.toStage)}${e.note == null || e.note!.isEmpty ? '' : ' • ${e.note}'}',
    'VIEWED' => 'A recruiter viewed your application',
    'INTERVIEW_SCHEDULED' => 'Interview scheduled${e.note == null || e.note!.isEmpty ? '' : ': ${e.note}'}',
    'INTERVIEW_UPDATED' => 'Interview updated${e.note == null || e.note!.isEmpty ? '' : ': ${e.note}'}',
    'OFFER_SENT' => 'An offer was sent to you',
    'OFFER_RESPONDED' => 'You responded to the offer${e.note == null || e.note!.isEmpty ? '' : ': ${e.note}'}',
    'WITHDRAWN' => 'You withdrew your application',
    _ => e.note ?? e.type.toLowerCase().replaceAll('_', ' '),
  };

  @override
  Widget build(BuildContext context) {
    final events = [...app.events]..sort((a, b) => a.at.compareTo(b.at));
    return Column(
      key: const ValueKey('timeline'),
      children: [
        _Stepper(stage: app.stage),
        const SizedBox(height: 14),
        if (events.isEmpty)
          Text(
            'Nothing has happened to this application yet.',
            key: const ValueKey('timeline-empty'),
            style: CareerText.body,
          ),
        for (final e in events)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 62, child: Text(formatDay(e.at), style: CareerText.meta)),
                Expanded(
                  child: Text(words(e), style: CareerText.body.copyWith(color: AppColors.onSurface)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The website's stepper (`jobs/ApplicationTimeline.tsx`): Applied · Screening · Interview · Offer · Hired, the
/// stages passed ticked, the one the application is at filled, the rest grey. An application that was not
/// selected, or withdrawn, shows that line instead.
class _Stepper extends StatelessWidget {
  const _Stepper({required this.stage});

  final String stage;

  static const flow = ['APPLIED', 'SCREENING', 'INTERVIEW', 'OFFER', 'HIRED'];
  static const labels = {
    'APPLIED': 'Applied',
    'SCREENING': 'Screening',
    'INTERVIEW': 'Interview',
    'OFFER': 'Offer',
    'HIRED': 'Hired',
  };

  @override
  Widget build(BuildContext context) {
    if (stage == 'REJECTED' || stage == 'WITHDRAWN') {
      final rejected = stage == 'REJECTED';
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          rejected ? 'Not selected' : 'You withdrew your application',
          key: ValueKey('stepper-${rejected ? 'rejected' : 'withdrawn'}'),
          style: CareerText.body.copyWith(
            fontWeight: FontWeight.w600,
            color: rejected ? AppColors.error : AppColors.onSurfaceVariant,
          ),
        ),
      );
    }
    final active = flow.indexOf(stage).clamp(0, flow.length - 1);
    return Row(
      key: ValueKey('stepper-$active'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, s) in flow.indexed) ...[
          if (i > 0)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 13),
                child: Container(height: 1, color: i <= active ? AppColors.primary : const Color(0xFFE0DFDC)),
              ),
            ),
          _Step(label: labels[s]!, index: i + 1, done: i < active, current: i == active),
        ],
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.index, required this.done, required this.current});

  final String label;
  final int index;
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final lit = done || current;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(shape: BoxShape.circle, color: lit ? AppColors.primary : const Color(0xFF9E9E9E)),
          alignment: Alignment.center,
          child: done
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : Text('$index', style: CareerText.meta.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: CareerText.meta.copyWith(
            color: lit ? AppColors.onSurface : AppColors.onSurfaceVariant,
            fontWeight: current ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
