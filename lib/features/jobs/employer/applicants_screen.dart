import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/util/links.dart' show showMessage;
import '../../career/career_format.dart';
import '../../career/career_styles.dart';
import '../../career/career_widgets.dart';
import '../job_links.dart';
import '../jobs_navigation.dart';
import 'applicant_detail_screen.dart';
import 'applicants_controller.dart';
import 'hiring_models.dart';
import 'hiring_repository.dart';
import 'hiring_sheets.dart';

/// One job's pipeline: the applicants by stage, ranked and filtered, each movable from the list.
/// A row opens the whole application. Opening an application is what marks it viewed.
class ApplicantsScreen extends StatefulWidget {
  const ApplicantsScreen({
    super.key,
    required this.repository,
    required this.jobId,
    this.jobTitle,
    this.stage,
    this.links = const SystemJobLinks(),
    this.navigation = JobsNavigation.none,
    this.onBack,
    this.clock,
  });

  final HiringRepository repository;
  final String jobId;
  final String? jobTitle;

  /// The stage it opens on; null is every stage.
  final String? stage;
  final JobLinks links;
  final JobsNavigation navigation;
  final VoidCallback? onBack;
  final DateTime Function()? clock;

  @override
  State<ApplicantsScreen> createState() => _ApplicantsScreenState();
}

class _ApplicantsScreenState extends State<ApplicantsScreen> {
  late final ApplicantsController _c = ApplicantsController(
    widget.repository,
    jobId: widget.jobId,
    jobTitle: widget.jobTitle,
    stage: widget.stage,
    clock: widget.clock,
  );

  DateTime get _now => (widget.clock ?? DateTime.now)();

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

  Future<void> _open(Applicant a) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ApplicantDetailScreen(
          repository: widget.repository,
          applicant: a,
          jobTitle: _c.jobTitle,
          links: widget.links,
          navigation: widget.navigation,
          onChanged: _c.changed,
          clock: widget.clock,
        ),
      ),
    );
    if (mounted) _c.refresh();
  }

  Future<void> _move(Applicant a, String to) async {
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
    final error = await _c.move(a, to, note: note);
    if (!mounted) return;
    showMessage(context, error ?? '${a.name} moved to ${stageWord(to).toLowerCase()}.');
  }

  Future<void> _rate(Applicant a, int stars) async {
    if (stars == 0) return;
    final error = await _c.rate(a, stars);
    if (!mounted) return;
    if (error != null) showMessage(context, error);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) => CareerScaffold(
        title: 'Applicants',
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
    final title = _c.jobTitle;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null && title.isNotEmpty)
              Text(title, key: const ValueKey('applicants-job'), style: CareerText.companyName),
            if (_c.loaded)
              Text(
                _c.total == 0
                    ? 'No applicants yet'
                    : '${_c.total} ${_c.total == 1 ? 'applicant' : 'applicants'}${_c.unviewed == 0 ? '' : ' • ${_c.unviewed} not viewed'}',
                key: const ValueKey('applicants-total'),
                style: CareerText.meta,
              ),
          ],
        ),
      ),
      SizedBox(
        height: 30,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          children: [
            for (final s in <String?>[null, ...pipelineStages])
              Padding(
                padding: const EdgeInsets.only(right: 5),
                child: _StageChip(
                  key: ValueKey('stage-${s ?? 'all'}'),
                  label: '${s == null ? 'All' : stageWord(s)} ${_c.count(s)}',
                  selected: _c.stage == s,
                  onTap: () => _c.selectStage(s),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            PopupMenuButton<ApplicantSort>(
              key: const ValueKey('applicants-sort'),
              tooltip: 'Sort by',
              onSelected: _c.setSort,
              itemBuilder: (_) => [
                for (final s in ApplicantSort.values)
                  CheckedPopupMenuItem(value: s, checked: s == _c.sort, child: Text(s.label)),
              ],
              child: _Pill(icon: LucideIcons.arrowDownUp, label: _c.sort.label),
            ),
            const SizedBox(width: 6),
            PopupMenuButton<int>(
              key: const ValueKey('applicants-rating'),
              tooltip: 'Filter by rating',
              onSelected: (v) => _c.setMinRating(v == 0 ? null : v),
              itemBuilder: (_) => [
                CheckedPopupMenuItem(value: 0, checked: _c.minRating == null, child: const Text('Any rating')),
                for (final n in const [3, 4, 5])
                  CheckedPopupMenuItem(value: n, checked: _c.minRating == n, child: Text('$n stars and up')),
              ],
              child: _Pill(
                icon: LucideIcons.star,
                label: _c.minRating == null ? 'Rating' : '${_c.minRating}+ stars',
                on: _c.minRating != null,
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              key: const ValueKey('applicants-qualified'),
              onTap: () => _c.setQualifiedOnly(!_c.qualifiedOnly),
              child: _Pill(icon: LucideIcons.listChecks, label: 'Qualified', on: _c.qualifiedOnly),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      const Divider(height: 1, color: AppColors.blockRule),
      if (_c.error != null && _c.applicants.isEmpty)
        CareerNotice(
          key: const ValueKey('applicants-error'),
          icon: LucideIcons.cloudOff,
          title: "Couldn't load the applicants",
          body: _c.error!,
          action: 'Try again',
          onAction: _c.refresh,
        )
      else if (!_c.loaded)
        const CareerLoading()
      else if (_c.applicants.isEmpty)
        CareerNotice(
          key: const ValueKey('applicants-empty'),
          icon: LucideIcons.users,
          title: _c.stage != null || _c.minRating != null || _c.qualifiedOnly ? 'No one matches' : 'No applicants yet',
          body: _c.stage != null || _c.minRating != null || _c.qualifiedOnly
              ? 'Try another stage, or clear the filters.'
              : 'People who apply show up here, best match first if you sort that way.',
          action: _c.stage != null || _c.minRating != null || _c.qualifiedOnly ? 'Show everyone' : null,
          onAction: () async {
            await _c.setMinRating(null);
            await _c.setQualifiedOnly(false);
            await _c.selectStage(null);
          },
        )
      else
        for (final a in _c.applicants)
          ApplicantRow(
            applicant: a,
            now: _now,
            busy: _c.busy(a.id),
            onOpen: () => _open(a),
            onMove: (to) => _move(a, to),
            onRate: (n) => _rate(a, n),
          ),
    ];
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.primary : Colors.white,
        shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.primary : AppColors.outlineVariant)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Center(
              child: Text(label, style: CareerText.tabLabel.copyWith(color: selected ? Colors.white : null)),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, this.on = false});

  final IconData icon;
  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: on ? AppColors.chipEmphasis : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: on ? AppColors.primary : AppColors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: on ? AppColors.primary : AppColors.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(label, style: CareerText.tabLabel.copyWith(fontSize: 12, color: on ? AppColors.primary : null)),
        ],
      ),
    );
  }
}

/// The photo of an applicant, or their initials.
class ApplicantAvatar extends StatelessWidget {
  const ApplicantAvatar({super.key, required this.applicant, this.radius = 22});

  final Applicant applicant;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = applicant.photoUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.chipEmphasis,
      backgroundImage: url == null ? null : CachedNetworkImageProvider(url),
      child: url == null
          ? Text(applicant.initials, style: CareerText.bodyStrong.copyWith(color: AppColors.primary))
          : null,
    );
  }
}

/// The tone a stage wears.
PillTone stageTone(String stage) => switch (stage) {
  'HIRED' => PillTone.success,
  'OFFER' => PillTone.warning,
  'INTERVIEW' => PillTone.brand,
  'REJECTED' || 'WITHDRAWN' => PillTone.danger,
  _ => PillTone.neutral,
};

/// One applicant on the pipeline.
class ApplicantRow extends StatelessWidget {
  const ApplicantRow({
    super.key,
    required this.applicant,
    required this.now,
    required this.busy,
    required this.onOpen,
    required this.onMove,
    required this.onRate,
  });

  final Applicant applicant;
  final DateTime now;
  final bool busy;
  final VoidCallback onOpen;
  final ValueChanged<String> onMove;
  final ValueChanged<int> onRate;

  @override
  Widget build(BuildContext context) {
    final a = applicant;
    final moves = stageMoves[a.stage] ?? const [];
    final facts = [
      if (a.headline != null && a.headline!.isNotEmpty) a.headline!,
      if (a.currentCompany != null && a.currentCompany!.isNotEmpty) a.currentCompany!,
      if (a.experienceYears != null) '${_years(a.experienceYears!)} yrs',
    ];
    return Container(
      key: ValueKey('applicant-${a.id}'),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.cardRule)),
      ),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ApplicantAvatar(applicant: a),
                      if (!a.viewed && a.stage == 'APPLIED')
                        Positioned(
                          right: -1,
                          top: -1,
                          child: Container(
                            key: ValueKey('unviewed-${a.id}'),
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.name,
                          style: CareerText.cardTitle.copyWith(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (facts.isNotEmpty)
                          Text(
                            facts.join(' • '),
                            style: CareerText.companyMeta,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            KeyedSubtree(
                              key: ValueKey('stage-pill-${a.id}'),
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
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else if (moves.isNotEmpty)
                    PopupMenuButton<String>(
                      key: ValueKey('applicant-menu-${a.id}'),
                      tooltip: 'Move ${a.name}',
                      icon: const Icon(LucideIcons.ellipsisVertical, size: 18, color: AppColors.onSurfaceVariant),
                      onSelected: onMove,
                      itemBuilder: (_) => [
                        for (final to in moves)
                          PopupMenuItem(
                            key: ValueKey('move-${a.id}-$to'),
                            value: to,
                            child: Text(
                              moveVerb(to),
                              style: TextStyle(color: to == 'REJECTED' ? AppColors.error : null),
                            ),
                          ),
                      ],
                    )
                  else
                    const SizedBox(width: 12),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 54, right: 8),
                child: Row(
                  children: [
                    StarPicker(value: a.rating ?? 0, size: 20, keyPrefix: 'rate-${a.id}', onChanged: onRate),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        _line(a),
                        key: ValueKey('applicant-line-${a.id}'),
                        style: CareerText.meta,
                        textAlign: TextAlign.right,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _line(Applicant a) {
    if (a.nextInterviewAt != null && a.stage == 'INTERVIEW') return 'Interview ${formatWhen(a.nextInterviewAt!)}';
    if (a.offerStatus != null && a.stage == 'OFFER') {
      return switch (a.offerStatus) {
        'SENT' => 'Offer sent, awaiting reply',
        'ACCEPTED' => 'Offer accepted',
        'DECLINED' => 'Offer declined',
        'DRAFT' => 'Offer drafted',
        _ => 'Offer ${a.offerStatus!.toLowerCase()}',
      };
    }
    return 'Applied ${formatDay(a.appliedAt, now: now)}';
  }

  static String _years(double y) => y == y.roundToDouble() ? y.toInt().toString() : y.toStringAsFixed(1);
}
