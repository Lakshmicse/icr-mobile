import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart' show showMessage;
import '../../core/widgets/section_heading.dart';
import '../jobs/job_detail_sheet.dart';
import '../jobs/job_links.dart';
import '../jobs/jobs_navigation.dart';
import 'application_detail_screen.dart';
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
import 'job_alerts_screen.dart';

/// "My applications": every application, how far it has come, and what it waits on.
/// The website's tracker (`/career/applications`): the figures, what is up next, the
/// tabs (Active, Interviews, Offers, Archived, All) with search and sort, and each
/// application's own page.
class MyApplicationsScreen extends StatefulWidget {
  const MyApplicationsScreen({
    super.key,
    required this.repository,
    this.links = const SystemJobLinks(),
    this.navigation = JobsNavigation.none,
    this.tab,
    this.onBack,
    this.clock,
  });

  final CareerRepository repository;
  final JobLinks links;

  /// Where a company, a conversation, a member, the job board and the bell open.
  final JobsNavigation navigation;

  /// The tab it opens on; with none, Active (All when nothing is in play).
  final ApplicationsTab? tab;
  final VoidCallback? onBack;

  /// Pins "now" (a test, a golden).
  final CareerClock? clock;

  @override
  State<MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<MyApplicationsScreen> with WidgetsBindingObserver {
  late final ApplicationsController _c = ApplicationsController(
    widget.repository,
    clock: widget.clock,
    tab: widget.tab,
  );
  final _search = TextEditingController();
  String? _busyId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _c.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _c.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _search.dispose();
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
          onChanged: _c.replace,
        ),
      ),
    );
  }

  void _openJob(CareerApplication app) => showJobDetail(
    context,
    app.job,
    repository: widget.repository.jobs,
    links: widget.links,
    navigation: widget.navigation,
  );

  Future<void> _message(CareerApplication app) async {
    final result = await _c.messageHiringTeam(app);
    if (!mounted) return;
    if (result.error != null) {
      showMessage(context, result.error!);
      return;
    }
    await widget.navigation.openConversation(context, widget.links, result.conversationId);
  }

  Future<void> _withdraw(CareerApplication app) async {
    if (!await confirmWithdraw(context, app) || !mounted) return;
    final message = await _c.withdraw(app);
    if (!mounted) return;
    showMessage(context, message ?? 'Application withdrawn. It is now under Archived.');
  }

  Future<void> _respond(CareerApplication app, bool accept) async {
    final offer = app.latestOffer;
    if (offer == null) return;
    final decision = await askOfferDecision(context, offer, accept: accept);
    if (!decision.confirmed || !mounted) return;
    setState(() => _busyId = app.id);
    final message = await _c.respondToOffer(app, accept: accept, note: decision.note);
    if (!mounted) return;
    setState(() => _busyId = null);
    showMessage(
      context,
      message ??
          (accept
              ? 'Offer accepted. Congratulations! It is now under Offers.'
              : 'Offer declined. It is now under Archived.'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) => CareerScaffold(
        title: 'My applications',
        onBack: widget.onBack,
        unread: _c.unread,
        onBell: () => widget.navigation.openNotifications(context, widget.links),
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _c.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 32),
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
          key: const ValueKey('applications-error'),
          icon: LucideIcons.cloudOff,
          title: "Couldn't load your applications",
          body: _c.error!,
          action: 'Try again',
          onAction: _c.refresh,
        ),
      ];
    }
    if (!_c.loaded) return const [CareerLoading()];
    if (_c.apps.isEmpty) {
      return [
        CareerNotice(
          key: const ValueKey('applications-first'),
          icon: LucideIcons.clipboardCheck,
          title: 'Start tracking your job search',
          body: 'Every job you apply to appears here with its status, interviews and offers.',
          action: 'Find jobs',
          onAction: () => widget.navigation.findJobs(context, widget.links),
          secondary: 'Set up a job alert',
          onSecondary: () =>
              openJobAlerts(context, repository: widget.repository, links: widget.links, navigation: widget.navigation),
        ),
      ];
    }
    final rows = _c.rows;
    final query = _c.search.trim();
    return [
      const SizedBox(height: 12),
      _Summary(controller: _c, links: widget.links),
      if (_c.upNextItems.isNotEmpty) ...[
        const SizedBox(height: 16),
        _UpNext(
          controller: _c,
          links: widget.links,
          onOpen: _openApplication,
          onOffers: () => _c.selectTab(ApplicationsTab.offers),
        ),
      ],
      const SizedBox(height: 16),
      CountTabs<ApplicationsTab>(
        values: ApplicationsTab.values,
        selected: _c.tab,
        label: (t) => t.label,
        count: (t) => _c.counts[t] ?? 0,
        keyPrefix: 'applications-tab',
        onSelect: _c.selectTab,
      ),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Expanded(
              child: _SearchBox(
                controller: _search,
                onChanged: _c.setSearch,
                onClear: () {
                  _search.clear();
                  _c.setSearch('');
                },
              ),
            ),
            const SizedBox(width: 8),
            _SortMenu(sort: _c.sort, onSelect: _c.setSort),
          ],
        ),
      ),
      if (_c.locked)
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
          child: LockedTimelineNotice(onUpgrade: () => widget.links.openSite(context, '/career/plans')),
        ),
      const SizedBox(height: 10),
      const Hairline(color: AppColors.blockRule),
      if (rows.isEmpty)
        _empty(query)
      else
        for (final app in rows)
          ApplicationRow(
            app: app,
            now: _c.now,
            links: widget.links,
            busy: _busyId == app.id,
            onOpen: () => _openApplication(app),
            onOpenJob: () => _openJob(app),
            onMessage: () => _message(app),
            onWithdraw: () => _withdraw(app),
            onRespond: (accept) => _respond(app, accept),
            onFindSimilar: () => widget.navigation.findJobs(context, widget.links, query: app.jobTitle),
          ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Text(
          'Showing ${rows.length} of ${_c.counts[ApplicationsTab.all]} application${_c.counts[ApplicationsTab.all] == 1 ? '' : 's'}',
          key: const ValueKey('showing'),
          style: CareerText.meta,
        ),
      ),
    ];
  }

  Widget _empty(String query) {
    if (query.isNotEmpty) {
      return CareerNotice(
        key: const ValueKey('applications-search-empty'),
        icon: LucideIcons.search,
        title: 'No applications match “$query”',
        body: 'Try another job title, company or city, or clear the search.',
        action: 'Clear search',
        onAction: () {
          _search.clear();
          _c.setSearch('');
        },
      );
    }
    final (title, text) = switch (_c.tab) {
      ApplicationsTab.active => ('Nothing in progress', 'Applications you send appear here until they close.'),
      ApplicationsTab.interviews => (
        'No interviews yet',
        'When an employer schedules an interview, it appears here with the time and how to join.',
      ),
      ApplicationsTab.offers => ('No offers yet', 'Offers you receive appear here, ready to accept or decline.'),
      ApplicationsTab.archived => (
        'Nothing archived',
        'Applications that are not taken forward, that you withdraw, or whose offer you decline move here.',
      ),
      ApplicationsTab.all => ('No applications yet', 'Find a job you like and apply. You can follow it here.'),
    };
    return CareerNotice(
      key: const ValueKey('applications-tab-empty'),
      icon: LucideIcons.clipboardList,
      title: title,
      body: text,
      action: _c.tab == ApplicationsTab.all ? null : 'View all applications',
      onAction: () => _c.selectTab(ApplicationsTab.all),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller, required this.onChanged, required this.onClear});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          const SizedBox(width: 9),
          const Icon(LucideIcons.search, size: 16, color: AppColors.outline),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              key: const ValueKey('applications-search'),
              controller: controller,
              onChanged: onChanged,
              style: CareerText.body.copyWith(color: AppColors.onSurface),
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Job title, company or city',
                hintStyle: CareerText.body.copyWith(color: AppColors.outline),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox(width: 10)
                : IconButton(
                    key: const ValueKey('applications-search-clear'),
                    tooltip: 'Clear search',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    iconSize: 15,
                    onPressed: onClear,
                    icon: const Icon(LucideIcons.x, color: AppColors.outline),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.sort, required this.onSelect});

  final ApplicationsSort sort;
  final ValueChanged<ApplicationsSort> onSelect;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ApplicationsSort>(
      key: const ValueKey('applications-sort'),
      tooltip: 'Sort by',
      onSelected: onSelect,
      itemBuilder: (_) => [
        for (final s in ApplicationsSort.values)
          CheckedPopupMenuItem(value: s, checked: s == sort, child: Text(s.label)),
      ],
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.arrowDownUp, size: 14, color: AppColors.onSurfaceVariant),
            const SizedBox(width: 5),
            Text(sort.label, style: CareerText.tabLabel),
          ],
        ),
      ),
    );
  }
}

/// The four figures above the tracker.
class _Summary extends StatelessWidget {
  const _Summary({required this.controller, required this.links});

  final ApplicationsController controller;
  final JobLinks links;

  @override
  Widget build(BuildContext context) {
    final s = controller.summary;
    Widget tile(String key, String label, Widget figure, String hint, VoidCallback onTap, {Color? hintColor}) =>
        InkWell(
          key: ValueKey(key),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: CareerText.label),
                const SizedBox(height: 2),
                figure,
                const SizedBox(height: 2),
                Text(hint, style: CareerText.meta.copyWith(color: hintColor), maxLines: 2),
              ],
            ),
          ),
        );
    final viewed = s.viewed;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DecoratedBox(
        decoration: cardDecoration(),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: tile(
                    'summary-active',
                    'Active',
                    Text('${s.active}', style: CareerText.bigNumber),
                    s.sentThisWeek == 0 ? 'None sent this week' : '${s.sentThisWeek} sent this week',
                    () => controller.selectTab(ApplicationsTab.active),
                  ),
                ),
                const SizedBox(height: 86, child: VerticalDivider(width: 1, color: AppColors.cardRule)),
                Expanded(
                  child: viewed == null
                      ? tile(
                          'summary-viewed-locked',
                          'Viewed by recruiters',
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Icon(LucideIcons.lock, size: 20, color: AppColors.outline),
                          ),
                          'See plans to know when they open yours',
                          () => links.openSite(context, '/career/plans'),
                          hintColor: AppColors.primary,
                        )
                      : tile(
                          'summary-viewed',
                          'Viewed by recruiters',
                          Text('$viewed', style: CareerText.bigNumber),
                          viewed == 0 ? 'Not opened yet' : 'Opened by a recruiter',
                          () {},
                        ),
                ),
              ],
            ),
            const Divider(height: 1, color: AppColors.cardRule),
            Row(
              children: [
                Expanded(
                  child: tile(
                    'summary-interviews',
                    'Interviews',
                    Text('${s.interviews}', style: CareerText.bigNumber),
                    s.nextInterviewAt == null ? 'None scheduled' : 'Next: ${formatWeekday(s.nextInterviewAt!)}',
                    () => controller.selectTab(ApplicationsTab.interviews),
                  ),
                ),
                const SizedBox(height: 86, child: VerticalDivider(width: 1, color: AppColors.cardRule)),
                Expanded(
                  child: tile(
                    'summary-offers',
                    'Offers',
                    Text('${s.offers}', style: CareerText.bigNumber),
                    s.awaitingReply == 0 ? 'Nothing waiting' : '${s.awaitingReply} awaiting your reply',
                    () => controller.selectTab(ApplicationsTab.offers),
                    hintColor: s.awaitingReply == 0 ? null : AppColors.amber800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// What waits on the member across every application: rounds coming up, offers to answer.
class _UpNext extends StatelessWidget {
  const _UpNext({required this.controller, required this.links, required this.onOpen, required this.onOffers});

  final ApplicationsController controller;
  final JobLinks links;
  final void Function(CareerApplication app) onOpen;
  final VoidCallback onOffers;

  @override
  Widget build(BuildContext context) {
    final items = controller.upNextItems;
    final now = controller.now;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DecoratedBox(
        key: const ValueKey('up-next'),
        decoration: cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('Up next', style: CareerText.heading),
                  const SizedBox(width: 6),
                  Text('Things waiting on you', style: CareerText.meta),
                ],
              ),
            ),
            for (final item in items) ...[
              const Divider(height: 1, color: AppColors.cardRule),
              item.interview != null
                  ? _UpNextInterview(item: item, links: links, onOpen: onOpen)
                  : _UpNextOffer(item: item, now: now, onReview: onOffers),
            ],
          ],
        ),
      ),
    );
  }
}

class _UpNextInterview extends StatelessWidget {
  const _UpNextInterview({required this.item, required this.links, required this.onOpen});

  final UpNextItem item;
  final JobLinks links;
  final void Function(CareerApplication app) onOpen;

  @override
  Widget build(BuildContext context) {
    final iv = item.interview!;
    final join = iv.joinUrl;
    final map = iv.mapUrl;
    return Padding(
      key: ValueKey('up-next-${iv.id}'),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          DateBlock(month: monthShort(iv.scheduledAt), day: '${iv.scheduledAt.toLocal().day}'),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Round ${iv.round} interview • ${item.app.jobTitle}', style: CareerText.bodyStrong, maxLines: 2),
                Text(
                  [?item.app.companyName, formatWhen(iv.scheduledAt), iv.mode.label].join(' • '),
                  style: CareerText.meta,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (join != null)
                StripButton(
                  label: 'Join',
                  icon: LucideIcons.video,
                  filled: true,
                  onTap: () => links.openUri(context, join),
                )
              else if (map != null)
                StripButton(label: 'Maps', icon: LucideIcons.mapPin, onTap: () => links.openUri(context, map)),
              const SizedBox(height: 4),
              StripButton(label: 'Details', onTap: () => onOpen(item.app)),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpNextOffer extends StatelessWidget {
  const _UpNextOffer({required this.item, required this.now, required this.onReview});

  final UpNextItem item;
  final DateTime now;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final offer = item.offer!;
    final by = replyBy(offer, now);
    return Padding(
      key: ValueKey('up-next-${offer.id}'),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.amber100, borderRadius: BorderRadius.circular(8)),
            child: const Icon(LucideIcons.fileText, size: 20, color: AppColors.amber800),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.app.companyName == null
                      ? 'An offer is waiting for your reply'
                      : 'Offer from ${item.app.companyName}',
                  style: CareerText.bodyStrong,
                  maxLines: 2,
                ),
                Text(
                  [item.app.jobTitle, offerAmount(offer), if (by.isNotEmpty) by].join(' • '),
                  style: CareerText.meta,
                  maxLines: 3,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          StripButton(label: 'Review offer', onTap: onReview),
        ],
      ),
    );
  }
}

/// Where the plan hides the timeline and the viewed receipts: what to do about it.
class LockedTimelineNotice extends StatelessWidget {
  const LockedTimelineNotice({super.key, required this.onUpgrade});

  /// The plans: a payment, so the website's page.
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('locked-timeline'),
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      decoration: BoxDecoration(color: AppColors.chipEmphasis, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          const Icon(LucideIcons.lock, size: 15, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'The full application timeline and recruiter viewed-receipts are part of Career Plus.',
              style: CareerText.body.copyWith(color: AppColors.onSurface),
            ),
          ),
          TextButton(
            key: const ValueKey('locked-upgrade'),
            onPressed: onUpgrade,
            child: Text('Upgrade', style: CareerText.link),
          ),
        ],
      ),
    );
  }
}
