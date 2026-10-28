import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_error.dart';
import '../../core/theme/app_colors.dart';
import '../jobs/job_links.dart';
import '../jobs/jobs_navigation.dart';
import 'application_logic.dart';
import 'application_widgets.dart';
import 'career_base.dart';
import 'career_format.dart';
import 'career_models.dart';
import 'career_repository.dart';
import 'career_routes.dart';
import 'career_styles.dart';
import 'career_widgets.dart';
import 'saved_jobs_controller.dart';

/// The one page behind "Your career": the search at a glance, what waits on the
/// member, how visible they are, and the way to each part of it. The website's `/career`.
class CareerHubController extends CareerController {
  CareerHubController(super.repository, {super.clock});

  List<CareerApplication> _apps = const [];
  List<JobInvite> _invites = const [];
  ({int saved, int hidden}) _shelves = (saved: 0, hidden: 0);
  SeekerQuota? _quota;
  ResumeInsights? _insights;
  ProfilePerformance? _performance;
  bool _loaded = false;
  bool _loading = false;
  String? _error;
  DateTime? _now;

  List<CareerApplication> get apps => _apps;
  List<JobInvite> get invites => _invites;
  int get saved => _shelves.saved;
  int get hidden => _shelves.hidden;
  SeekerQuota? get quota => _quota;
  ResumeInsights? get insights => _insights;
  ProfilePerformance? get performance => _performance;
  bool get loaded => _loaded;
  bool get loading => _loading;
  String? get error => _error;
  DateTime get now => _now ??= clock();

  /// Applications still in play.
  int get active => _apps.where((a) => inTab(a, ApplicationsTab.active, now)).length;
  int get viewed => _apps.where((a) => inTab(a, ApplicationsTab.active, now) && a.viewedAt != null).length;
  List<InterviewRef> get interviews => [
    for (final a in _apps.where((a) => !isArchived(a)))
      for (final iv in upcomingInterviews(a, now)) InterviewRef(a, iv),
  ]..sort((a, b) => a.interview.scheduledAt.compareTo(b.interview.scheduledAt));

  /// Invitations still waiting on the member.
  List<JobInvite> get openInvites => _invites.where((i) => i.status == 'SENT' || i.status == 'VIEWED').toList();

  /// An offer waiting on a reply, per application.
  List<CareerApplication> get offersWaiting => _apps.where((a) => a.latestOffer?.status == 'SENT').toList();

  Map<String, int> get stageCounts {
    final counts = <String, int>{};
    for (final a in _apps) {
      counts[a.stage] = (counts[a.stage] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> start() async {
    _now = null;
    _loading = true;
    _error = null;
    notifyListeners();
    // The applications are the page; every other part is left out when it cannot be read.
    final results = await Future.wait<Object?>([
      _try(repository.applications),
      _try(repository.invites),
      _try(repository.shelfCounts),
      _try(repository.quota),
      _try(repository.resumeInsights),
      _try(repository.profilePerformance),
      loadUnread(),
    ]);
    final apps = results[0];
    if (apps is ApiError) {
      _error = apps.message;
    } else {
      _apps = apps as List<CareerApplication>;
      _loaded = true;
    }
    if (results[1] is List<JobInvite>) _invites = results[1] as List<JobInvite>;
    if (results[2] is ({int saved, int hidden})) _shelves = results[2] as ({int saved, int hidden});
    _quota = results[3] is SeekerQuota ? results[3] as SeekerQuota : null;
    _insights = results[4] is ResumeInsights ? results[4] as ResumeInsights : null;
    _performance = results[5] is ProfilePerformance ? results[5] as ProfilePerformance : null;
    _loading = false;
    notifyListeners();
  }

  Future<void> refresh() => start();

  Future<Object?> _try<T>(Future<T> Function() read) async {
    try {
      return await read();
    } catch (e) {
      return ApiError.from(e);
    }
  }
}

/// A round with the application it belongs to.
class InterviewRef {
  const InterviewRef(this.app, this.interview);

  final CareerApplication app;
  final CareerInterview interview;
}

class CareerHubScreen extends StatefulWidget {
  const CareerHubScreen({
    super.key,
    required this.repository,
    this.links = const SystemJobLinks(),
    this.navigation = JobsNavigation.none,
    this.onBack,
    this.clock,
    this.onChanged,
    this.postedJobs,
  });

  final CareerRepository repository;
  final JobLinks links;
  final JobsNavigation navigation;
  final VoidCallback? onBack;
  final CareerClock? clock;

  /// Tells the board that a count it shows may have changed (alerts seen).
  final VoidCallback? onChanged;

  /// Opens "Jobs you posted"; given only for a member on a company's hiring team.
  final Future<void> Function()? postedJobs;

  @override
  State<CareerHubScreen> createState() => _CareerHubScreenState();
}

class _CareerHubScreenState extends State<CareerHubScreen> {
  late final CareerHubController _c = CareerHubController(widget.repository, clock: widget.clock);

  @override
  void initState() {
    super.initState();
    _c.start();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Opens a part, then reads the hub again: what was done there changes its figures.
  Future<void> _go(Future<void> Function(CareerRoutes routes) open) async {
    await open(_routes);
    if (mounted) _c.refresh();
  }

  CareerRoutes get _routes => CareerRoutes(
    context: context,
    repository: widget.repository,
    links: widget.links,
    navigation: widget.navigation,
    clock: widget.clock,
    onChanged: widget.onChanged,
    postedJobs: widget.postedJobs,
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) => CareerScaffold(
        title: 'Your career',
        onBack: widget.onBack,
        unread: _c.unread,
        onBell: () => widget.navigation.openNotifications(context, widget.links),
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _c.refresh,
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
    if (_c.error != null && !_c.loaded) {
      return [
        CareerNotice(
          key: const ValueKey('hub-error'),
          icon: LucideIcons.cloudOff,
          title: "Couldn't load your career hub",
          body: _c.error!,
          action: 'Try again',
          onAction: _c.refresh,
        ),
      ];
    }
    if (!_c.loaded) return const [CareerLoading()];
    return [
      _Snapshot(controller: _c, onGo: _go),
      if (_c.quota?.limit != null) ...[const SizedBox(height: 10), _Quota(quota: _c.quota!, links: widget.links)],
      const SizedBox(height: 14),
      _NextSteps(controller: _c, onGo: _go, links: widget.links, navigation: widget.navigation),
      const SizedBox(height: 14),
      _Visibility(controller: _c, links: widget.links, navigation: widget.navigation),
      const SizedBox(height: 14),
      _Pipeline(controller: _c, onGo: _go),
      const SizedBox(height: 14),
      _Shortcuts(controller: _c, onGo: _go, showPosted: widget.postedJobs != null),
    ];
  }
}

typedef _Go = Future<void> Function(Future<void> Function(CareerRoutes routes) open);

class _Snapshot extends StatelessWidget {
  const _Snapshot({required this.controller, required this.onGo});

  final CareerHubController controller;
  final _Go onGo;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final next = c.interviews.isEmpty ? null : c.interviews.first.interview.scheduledAt;
    Widget tile(String key, String label, int n, String hint, VoidCallback onTap) => InkWell(
      key: ValueKey(key),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: CareerText.label),
            const SizedBox(height: 2),
            Text('$n', style: CareerText.bigNumber),
            const SizedBox(height: 2),
            Text(hint, style: CareerText.meta, maxLines: 2),
          ],
        ),
      ),
    );
    return DecoratedBox(
      key: const ValueKey('snapshot'),
      decoration: cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: tile(
                  'hub-active',
                  'Active',
                  c.active,
                  c.viewed == 0 ? 'None opened yet' : '${c.viewed} viewed by employers',
                  () => onGo((r) => r.applications(tab: ApplicationsTab.active)),
                ),
              ),
              const SizedBox(height: 86, child: VerticalDivider(width: 1, color: AppColors.cardRule)),
              Expanded(
                child: tile(
                  'hub-interviews',
                  'Interviews',
                  c.interviews.length,
                  next == null ? 'None scheduled' : 'Next: ${formatWeekday(next)}',
                  () => onGo((r) => r.interviews()),
                ),
              ),
            ],
          ),
          const Divider(height: 1, color: AppColors.cardRule),
          Row(
            children: [
              Expanded(
                child: tile('hub-saved', 'Saved', c.saved, 'Jobs you bookmarked', () => onGo((r) => r.savedJobs())),
              ),
              const SizedBox(height: 86, child: VerticalDivider(width: 1, color: AppColors.cardRule)),
              Expanded(
                child: tile(
                  'hub-invitations',
                  'Invitations',
                  c.openInvites.length,
                  'Roles recruiters invited you to',
                  () => onGo((r) => r.invitations()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Quota extends StatelessWidget {
  const _Quota({required this.quota, required this.links});

  final SeekerQuota quota;
  final JobLinks links;

  @override
  Widget build(BuildContext context) {
    final limit = quota.limit!;
    return Container(
      key: const ValueKey('quota'),
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${quota.used} of $limit applications used this month', style: CareerText.bodyStrong),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (quota.used / limit).clamp(0, 1),
                    minHeight: 6,
                    color: AppColors.primary,
                    backgroundColor: AppColors.surfaceContainer,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            key: const ValueKey('quota-plans'),
            onPressed: () => links.openSite(context, '/career/plans'),
            child: Text('Go unlimited', style: CareerText.link),
          ),
        ],
      ),
    );
  }
}

class _NextSteps extends StatelessWidget {
  const _NextSteps({required this.controller, required this.onGo, required this.links, required this.navigation});

  final CareerHubController controller;
  final _Go onGo;
  final JobLinks links;
  final JobsNavigation navigation;

  static const _max = 4;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final rows = <Widget>[];
    for (final i in c.interviews) {
      rows.add(
        _StepRow(
          key: ValueKey('step-${i.interview.id}'),
          lead: DateBlock(month: monthShort(i.interview.scheduledAt), day: '${i.interview.scheduledAt.toLocal().day}'),
          title: 'Round ${i.interview.round} interview • ${i.app.jobTitle}',
          detail: [?i.app.companyName, formatWhen(i.interview.scheduledAt), i.interview.mode.label].join(' • '),
          action: 'Details',
          onTap: () => onGo((r) => r.application(i.app)),
        ),
      );
    }
    for (final a in c.offersWaiting) {
      rows.add(
        _StepRow(
          key: ValueKey('step-offer-${a.id}'),
          lead: _IconBlock(icon: LucideIcons.fileText, warn: true),
          title: 'An offer is waiting for your reply',
          detail: '${a.jobTitle} • ${a.companyName ?? ''}',
          action: 'Review',
          onTap: () => onGo((r) => r.applications(tab: ApplicationsTab.offers)),
        ),
      );
    }
    for (final inv in c.openInvites) {
      rows.add(
        _StepRow(
          key: ValueKey('step-${inv.id}'),
          lead: _IconBlock(icon: LucideIcons.mailOpen),
          title:
              '${inv.invitedBy ?? 'A recruiter'} invited you${inv.companyName == null ? '' : ' • ${inv.companyName}'}',
          detail: [inv.jobTitle, ?inv.city].join(' • '),
          action: 'View',
          onTap: () => onGo((r) => r.invitations()),
        ),
      );
    }
    final missing = c.insights?.missing.isEmpty ?? true ? null : c.insights!.missing.first;
    if (missing != null) {
      rows.add(
        _StepRow(
          key: const ValueKey('step-profile'),
          lead: _IconBlock(icon: LucideIcons.filePen),
          title: missing,
          detail: 'A fuller résumé gets more from recruiters.',
          action: 'Update',
          onTap: () => navigation.editProfile(context, links),
        ),
      );
    }
    return Container(
      key: const ValueKey('next-steps'),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 2),
            child: Row(
              children: [
                Expanded(child: Text('Next steps', style: CareerText.heading.copyWith(fontSize: 14))),
                TextButton(
                  key: const ValueKey('tracker-link'),
                  onPressed: () => onGo((r) => r.applications()),
                  child: Text('Open tracker', style: CareerText.link),
                ),
              ],
            ),
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: Row(
                key: const ValueKey('caught-up'),
                children: [
                  const Icon(LucideIcons.circleCheck, size: 22, color: AppColors.success),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("You're all caught up", style: CareerText.bodyStrong),
                        Text('Nothing is waiting on you right now.', style: CareerText.body),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            for (final r in rows.take(_max)) ...[const Divider(height: 1, color: AppColors.cardRule), r],
        ],
      ),
    );
  }
}

class _IconBlock extends StatelessWidget {
  const _IconBlock({required this.icon, this.warn = false});

  final IconData icon;
  final bool warn;

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: warn ? AppColors.amber100 : AppColors.chipEmphasis,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(icon, size: 20, color: warn ? AppColors.amber800 : AppColors.primary),
  );
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    super.key,
    required this.lead,
    required this.title,
    required this.detail,
    required this.action,
    required this.onTap,
  });

  final Widget lead;
  final String title;
  final String detail;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          lead,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: CareerText.bodyStrong, maxLines: 2, overflow: TextOverflow.ellipsis),
                Text(detail, style: CareerText.meta, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 6),
          StripButton(label: action, onTap: onTap),
        ],
      ),
    );
  }
}

class _Visibility extends StatelessWidget {
  const _Visibility({required this.controller, required this.links, required this.navigation});

  final CareerHubController controller;
  final JobLinks links;
  final JobsNavigation navigation;

  @override
  Widget build(BuildContext context) {
    final perf = controller.performance;
    final insights = controller.insights;
    final score = insights?.score;
    Widget metric(String label, int n) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$n', style: CareerText.money.copyWith(fontSize: 22)),
            const SizedBox(height: 2),
            Text(label, style: CareerText.meta, maxLines: 2),
          ],
        ),
      ),
    );
    return Container(
      key: const ValueKey('visibility'),
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('How visible you are', style: CareerText.heading.copyWith(fontSize: 14))),
              Text('LAST 30 DAYS', style: CareerText.label),
            ],
          ),
          if (perf != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                metric('Search appearances', perf.searchAppearances30d),
                const SizedBox(width: 6),
                metric('Recruiters viewed you', perf.profileViews30d),
                const SizedBox(width: 6),
                metric('Recruiter actions', perf.recruiterActions),
              ],
            ),
          ],
          if (score != null) ...[
            const SizedBox(height: 12),
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
                          color: score >= 70
                              ? AppColors.success
                              : (score >= 40 ? AppColors.primary : AppColors.amber500),
                          backgroundColor: AppColors.surfaceContainer,
                        ),
                      ),
                      Text('$score%', key: const ValueKey('resume-score'), style: CareerText.bodyStrong),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Résumé strength', style: CareerText.bodyStrong),
                      Text(
                        insights!.missing.isEmpty
                            ? 'Your résumé is complete.'
                            : 'Missing: ${insights.missing.take(3).join(', ')}',
                        style: CareerText.body,
                      ),
                      GestureDetector(
                        onTap: () => navigation.editProfile(context, links),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('Improve', key: const ValueKey('improve'), style: CareerText.link),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (perf == null && score == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Nothing to show yet.', style: CareerText.body),
            ),
        ],
      ),
    );
  }
}

/// Where each application stands, as a count per stage, and the latest three.
class _Pipeline extends StatelessWidget {
  const _Pipeline({required this.controller, required this.onGo});

  final CareerHubController controller;
  final _Go onGo;

  static const _stages = [
    ('APPLIED', 'Applied'),
    ('SCREENING', 'In review'),
    ('INTERVIEW', 'Interview'),
    ('OFFER', 'Offer'),
    ('HIRED', 'Hired'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final recent = [...c.apps]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final counts = c.stageCounts;
    return Container(
      key: const ValueKey('pipeline'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Your applications', style: CareerText.heading.copyWith(fontSize: 14))),
              TextButton(
                key: const ValueKey('open-tracker'),
                onPressed: () => onGo((r) => r.applications(tab: ApplicationsTab.all)),
                child: Text('Open tracker', style: CareerText.link),
              ),
            ],
          ),
          if (c.apps.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('Jobs you apply to show up here, with where each one stands.', style: CareerText.body),
            )
          else ...[
            Row(
              children: [
                for (final (stage, label) in _stages) ...[
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                      decoration: BoxDecoration(
                        color: (counts[stage] ?? 0) > 0 ? AppColors.chipEmphasis : AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${counts[stage] ?? 0}',
                            key: ValueKey('stage-$stage'),
                            style: CareerText.cardTitle.copyWith(fontSize: 16),
                          ),
                          Text(label, style: CareerText.meta.copyWith(fontSize: 12), maxLines: 1),
                        ],
                      ),
                    ),
                  ),
                  if (stage != 'HIRED') const SizedBox(width: 4),
                ],
              ],
            ),
            const SizedBox(height: 6),
            for (final a in recent.take(3)) ...[
              const Divider(height: 1, color: AppColors.cardRule),
              InkWell(
                key: ValueKey('recent-${a.id}'),
                onTap: () => onGo((r) => r.application(a)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.jobTitle,
                              style: CareerText.bodyStrong,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(a.companyName ?? '', style: CareerText.meta, maxLines: 1),
                          ],
                        ),
                      ),
                      StatusPill(statusOf(a).label, tone: toneOf(statusOf(a))),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Each part of the career area, one tap away.
class _Shortcuts extends StatelessWidget {
  const _Shortcuts({required this.controller, required this.onGo, this.showPosted = false});

  final CareerHubController controller;
  final _Go onGo;
  final bool showPosted;

  @override
  Widget build(BuildContext context) {
    Widget row(String key, IconData icon, String title, String? sub, Future<void> Function(CareerRoutes r) open) =>
        InkWell(
          key: ValueKey(key),
          onTap: () => onGo(open),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: CareerText.bodyStrong)),
                if (sub != null) Text(sub, style: CareerText.meta),
                const SizedBox(width: 6),
                const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.outline),
              ],
            ),
          ),
        );
    const rule = Divider(height: 1, color: AppColors.cardRule);
    return Container(
      key: const ValueKey('shortcuts'),
      decoration: cardDecoration(),
      child: Column(
        children: [
          row(
            'go-applications',
            LucideIcons.clipboardList,
            'My applications',
            '${controller.apps.length}',
            (r) => r.applications(),
          ),
          rule,
          row(
            'go-interviews',
            LucideIcons.calendarClock,
            'Interviews',
            '${controller.interviews.length}',
            (r) => r.interviews(),
          ),
          rule,
          row('go-saved', LucideIcons.bookmark, 'Saved jobs', '${controller.saved}', (r) => r.savedJobs()),
          rule,
          row(
            'go-hidden',
            LucideIcons.eyeOff,
            'Hidden jobs',
            '${controller.hidden}',
            (r) => r.savedJobs(tab: SavedTab.hidden),
          ),
          rule,
          row('go-alerts', LucideIcons.bellRing, 'Job alerts', null, (r) => r.alerts()),
          rule,
          row(
            'go-invitations',
            LucideIcons.mailOpen,
            'Invitations',
            '${controller.openInvites.length}',
            (r) => r.invitations(),
          ),
          if (showPosted) ...[
            rule,
            row(
              'go-posted',
              LucideIcons.briefcaseBusiness,
              'Jobs you posted',
              null,
              (r) => r.postedJobs?.call() ?? Future.value(),
            ),
          ],
        ],
      ),
    );
  }
}
