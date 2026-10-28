import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_error.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart' show showMessage;
import '../jobs/job_links.dart';
import '../jobs/jobs_navigation.dart';
import 'application_detail_screen.dart';
import 'application_dialogs.dart';
import 'application_logic.dart';
import 'applications_controller.dart';
import 'career_base.dart';
import 'career_format.dart';
import 'career_models.dart';
import 'career_repository.dart';
import 'career_styles.dart';
import 'career_widgets.dart';

enum InterviewsTab {
  upcoming('Upcoming'),
  past('Past');

  const InterviewsTab(this.label);
  final String label;
}

/// One round and the application it belongs to.
typedef InterviewEntry = ({CareerApplication app, CareerInterview interview});

/// "Interviews": every round to come, soonest first, and the rounds already held. A
/// candidate has no interviews list of their own in the API (`/interviews/mine` is the
/// hiring panel's), so the rounds come from the member's applications: the list carries
/// the rounds still to come, and each application's own page carries them all.
class InterviewsController extends CareerController {
  InterviewsController(super.repository, {super.clock});

  /// The most applications the Past shelf reads one by one.
  static const pastMax = 12;

  List<CareerApplication> _apps = const [];
  final Map<String, CareerApplication> _detail = {};
  InterviewsTab _tab = InterviewsTab.upcoming;
  bool _loading = false;
  bool _loaded = false;
  bool _pastLoading = false;
  bool _pastLoaded = false;
  String? _error;
  String? _pastError;
  DateTime? _now;

  InterviewsTab get tab => _tab;
  bool get loading => _loading;
  bool get loaded => _loaded;
  bool get pastLoading => _pastLoading;
  bool get pastLoaded => _pastLoaded;
  String? get error => _error;
  String? get pastError => _pastError;
  DateTime get now => _now ??= clock();
  List<CareerApplication> get apps => _apps;

  List<InterviewEntry> get upcoming {
    final rows = <InterviewEntry>[
      for (final app in _apps.where((a) => !isArchived(a)))
        for (final iv in upcomingInterviews(app, now)) (app: app, interview: iv),
    ];
    return rows..sort((a, b) => a.interview.scheduledAt.compareTo(b.interview.scheduledAt));
  }

  List<InterviewEntry> get past {
    final rows = <InterviewEntry>[
      for (final app in _detail.values)
        for (final iv in app.interviews)
          if (!(iv.live && !iv.scheduledAt.isBefore(now))) (app: app, interview: iv),
    ];
    return rows..sort((a, b) => b.interview.scheduledAt.compareTo(a.interview.scheduledAt));
  }

  Future<void> start() async {
    await Future.wait([_load(), loadUnread()]);
  }

  Future<void> refresh() async {
    _now = null;
    _detail.clear();
    _pastLoaded = false;
    await Future.wait([_load(), loadUnread()]);
    if (_tab == InterviewsTab.past) await _loadPast();
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _apps = await repository.applications();
      _loaded = true;
    } catch (e) {
      _error = ApiError.from(e).message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> select(InterviewsTab tab) async {
    if (tab == _tab) return;
    _tab = tab;
    notifyListeners();
    if (tab == InterviewsTab.past && !_pastLoaded && !_pastLoading) await _loadPast();
  }

  /// The applications that have had (or may have had) a round: read whole, a few at a time.
  Future<void> _loadPast() async {
    _pastLoading = true;
    _pastError = null;
    notifyListeners();
    try {
      final wanted = _apps
          .where(
            (a) =>
                a.stage != 'WITHDRAWN' &&
                (a.interviews.isNotEmpty ||
                    const {'INTERVIEW', 'OFFER', 'HIRED', 'REJECTED'}.contains(a.stage) ||
                    a.events.any((e) => e.type == 'INTERVIEW_SCHEDULED')),
          )
          .take(pastMax)
          .toList();
      for (var i = 0; i < wanted.length; i += 4) {
        final batch = wanted.skip(i).take(4);
        final got = await Future.wait(batch.map((a) => repository.application(a.id)));
        for (final app in got) {
          _detail[app.id] = app;
        }
      }
      _pastLoaded = true;
    } catch (e) {
      _pastError = ApiError.from(e).message;
    } finally {
      _pastLoading = false;
      notifyListeners();
    }
  }

  Future<MessageResult> messageHiringTeam(CareerApplication app, {String? message}) async {
    try {
      final id = await repository.messageHiringTeam(app.jobId, message: message);
      return (conversationId: id, error: null);
    } catch (e) {
      return (conversationId: null, error: ApiError.from(e).message);
    }
  }
}

/// The "Interviews" screen: Upcoming and Past, each round with its way in.
class InterviewsScreen extends StatefulWidget {
  const InterviewsScreen({
    super.key,
    required this.repository,
    this.links = const SystemJobLinks(),
    this.navigation = JobsNavigation.none,
    this.onBack,
    this.clock,
  });

  final CareerRepository repository;
  final JobLinks links;
  final JobsNavigation navigation;
  final VoidCallback? onBack;
  final CareerClock? clock;

  @override
  State<InterviewsScreen> createState() => _InterviewsScreenState();
}

class _InterviewsScreenState extends State<InterviewsScreen> {
  late final InterviewsController _c = InterviewsController(widget.repository, clock: widget.clock);

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

  void _openApplication(CareerApplication app) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ApplicationDetailScreen(
          repository: widget.repository,
          application: app,
          links: widget.links,
          navigation: widget.navigation,
          clock: widget.clock,
        ),
      ),
    );
  }

  Future<void> _message(CareerApplication app, String message) async {
    final result = await _c.messageHiringTeam(app, message: message);
    if (!mounted) return;
    if (result.error != null) {
      showMessage(context, result.error!);
      return;
    }
    await widget.navigation.openConversation(context, widget.links, result.conversationId);
  }

  Future<void> _reschedule(InterviewEntry e) async {
    final proposal = await askForAnotherTime(context, e.interview);
    if (proposal == null || !mounted) return;
    await _message(e.app, rescheduleRoundMessage(e.app, e.interview, proposal));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) => CareerScaffold(
        title: 'Interviews',
        onBack: widget.onBack,
        unread: _c.unread,
        onBell: () => widget.navigation.openNotifications(context, widget.links),
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _c.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const SizedBox(height: 10),
              CountTabs<InterviewsTab>(
                values: InterviewsTab.values,
                selected: _c.tab,
                label: (t) => t.label,
                keyPrefix: 'interviews-tab',
                count: (t) => t == InterviewsTab.upcoming ? (_c.loaded ? _c.upcoming.length : -1) : -1,
                onSelect: _c.select,
              ),
              const SizedBox(height: 10),
              ..._body(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body() {
    if (_c.error != null && !_c.loaded) {
      return [
        CareerNotice(
          key: const ValueKey('interviews-error'),
          icon: LucideIcons.cloudOff,
          title: "Couldn't load your interviews",
          body: _c.error!,
          action: 'Try again',
          onAction: _c.refresh,
        ),
      ];
    }
    if (!_c.loaded) return const [CareerLoading()];
    final upcoming = _c.tab == InterviewsTab.upcoming;
    if (!upcoming) {
      if (_c.pastError != null && !_c.pastLoaded) {
        return [
          CareerNotice(
            key: const ValueKey('past-error'),
            icon: LucideIcons.cloudOff,
            title: "Couldn't load your past interviews",
            body: _c.pastError!,
            action: 'Try again',
            onAction: _c.refresh,
          ),
        ];
      }
      if (!_c.pastLoaded) return const [CareerLoading()];
    }
    final rows = upcoming ? _c.upcoming : _c.past;
    if (rows.isEmpty) {
      return [
        CareerNotice(
          key: ValueKey(upcoming ? 'upcoming-empty' : 'past-empty'),
          icon: LucideIcons.calendarX,
          title: upcoming ? 'No interviews coming up' : 'No past interviews',
          body: upcoming
              ? 'When an employer schedules an interview, it appears here with the time and how to join.'
              : 'Rounds you have been to appear here.',
        ),
      ];
    }
    return [
      for (final e in rows)
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: InterviewCard(
            entry: e,
            upcoming: upcoming,
            links: widget.links,
            onOpen: () => _openApplication(e.app),
            onConfirm: () => _message(e.app, confirmRoundMessage(e.app, e.interview)),
            onReschedule: () => _reschedule(e),
          ),
        ),
    ];
  }
}

/// One round: when it is, which job, how to join, and how to answer it.
class InterviewCard extends StatelessWidget {
  const InterviewCard({
    super.key,
    required this.entry,
    required this.upcoming,
    required this.links,
    required this.onOpen,
    required this.onConfirm,
    required this.onReschedule,
  });

  final InterviewEntry entry;
  final bool upcoming;
  final JobLinks links;
  final VoidCallback onOpen;
  final VoidCallback onConfirm;
  final VoidCallback onReschedule;

  @override
  Widget build(BuildContext context) {
    final iv = entry.interview;
    final app = entry.app;
    final join = upcoming ? iv.joinUrl : null;
    final map = upcoming ? iv.mapUrl : null;
    final address = iv.mode == InterviewMode.inPerson ? iv.location?.trim() : null;
    return TapCard(
      key: ValueKey('interview-${iv.id}'),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DateBlock(month: monthShort(iv.scheduledAt), day: '${iv.scheduledAt.toLocal().day}'),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      iv.title == null ? 'Round ${iv.round}' : 'Round ${iv.round} • ${iv.title}',
                      style: CareerText.bodyStrong,
                      maxLines: 2,
                    ),
                    Text(app.jobTitle, style: CareerText.cardTitle, maxLines: 2),
                    Text([?app.companyName, ?app.city].join(' • '), style: CareerText.companyMeta, maxLines: 1),
                  ],
                ),
              ),
              if (!upcoming)
                StatusPill(
                  iv.statusLabel,
                  tone: switch (iv.status) {
                    'COMPLETED' => PillTone.success,
                    'CANCELLED' || 'NO_SHOW' => PillTone.danger,
                    _ => PillTone.neutral,
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(LucideIcons.clock, size: 13, color: AppColors.outline),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '${formatWhen(iv.scheduledAt)} • ${iv.durationMins} min • ${iv.mode.label}',
                  style: CareerText.body.copyWith(color: AppColors.onSurface),
                ),
              ),
            ],
          ),
          if (address != null && address.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.mapPin, size: 13, color: AppColors.outline),
                const SizedBox(width: 5),
                Expanded(child: Text(address, style: CareerText.body)),
              ],
            ),
          ],
          if (upcoming) ...[
            const SizedBox(height: 10),
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
                  label: 'Confirm',
                  icon: LucideIcons.check,
                  onTap: onConfirm,
                ),
                StripButton(
                  key: ValueKey('reschedule-${iv.id}'),
                  label: 'Ask for another time',
                  icon: LucideIcons.calendarClock,
                  onTap: onReschedule,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
