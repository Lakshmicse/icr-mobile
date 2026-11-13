import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart' show showMessage;
import '../../core/widgets/chips.dart';
import '../../core/widgets/title_bar.dart';
import '../account/widgets/account_kit.dart' show confirmAction, showAccountPicker;
import '../notifications/notifications_screen.dart';
import '../site/site_kit.dart';
import 'batch_sheet.dart';
import 'batch_view_sheet.dart';
import 'courses_screen.dart' show partnerConsoleRepositoryOf;
import 'partner_console_controllers.dart';
import 'partner_console_kit.dart';
import 'partner_console_models.dart';
import 'partner_console_repository.dart';
import 'partner_console_rules.dart';

/// The partner institute's Manage Batches (the website's `/admin/learning/batches`, `BatchesPanel`): every run of
/// every course, soonest first, narrowed to one course by the filter (a course row's batch count opens it so);
/// each row the name, start, seats and status as the dates give it today, opening the whole batch; "New batch"
/// opens the sheet with the website's fields. Viewers (a Trainer, Finance…) see the batches; Batch Admins and the
/// company admin change them.
class ManageBatchesScreen extends StatefulWidget {
  const ManageBatchesScreen({
    super.key,
    required this.onBack,
    this.courseId,
    this.repository,
    this.viewer,
    this.pickers = const ConsolePickers(),
    this.now,
  });

  final VoidCallback onBack;

  /// Opens narrowed to one course (the website's `?course=`).
  final String? courseId;
  final PartnerConsoleRepository? repository;
  final PartnerConsoleViewer? viewer;
  final ConsolePickers pickers;

  /// The clock the status chips and the sheet's date rules read (tests).
  final DateTime Function()? now;

  @override
  State<ManageBatchesScreen> createState() => _ManageBatchesScreenState();
}

class _ManageBatchesScreenState extends State<ManageBatchesScreen> {
  late final PartnerConsoleRepository _repo;
  late final PartnerConsoleViewer _viewer;
  late final BatchesController _c;

  @override
  void initState() {
    super.initState();
    _repo = partnerConsoleRepositoryOf(context, widget.repository);
    _viewer = consoleViewerOf(context, widget.viewer);
    _c = BatchesController(_repo, viewer: _viewer, courseId: widget.courseId);
    if (_viewer.isPartnerStaff) _c.start();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  DateTime get _now => (widget.now ?? DateTime.now)();

  Future<void> _pickCourse() async {
    const all = ConsoleCourse(id: '', code: 'All Courses', title: '', status: 'PUBLISHED');
    final picked = await showAccountPicker<ConsoleCourse>(
      context,
      title: 'Course',
      items: [all, ..._c.courses],
      labelOf: (c) => c.id.isEmpty ? c.code : '${c.code} — ${c.title}',
      searchable: _c.courses.length > 8,
      selected: _c.selectedCourse ?? all,
    );
    if (picked != null) _c.setCourse(picked.id);
  }

  /// With one course in view, "New batch" is for it; otherwise ask which course.
  Future<void> _newBatch() async {
    var course = _c.selectedCourse;
    if (course == null && _c.courses.length == 1) course = _c.courses.first;
    if (course == null) {
      course = await showAccountPicker<ConsoleCourse>(
        context,
        title: 'Select a Course',
        items: _c.courses,
        labelOf: (c) => '${c.code} — ${c.title}',
        searchable: _c.courses.length > 8,
      );
      if (course == null || !mounted) return;
    }
    final saved = await showBatchSheet(
      context,
      controller: _c,
      course: course,
      pickers: widget.pickers,
      now: widget.now,
    );
    if (saved && mounted) showMessage(context, 'Batch saved.');
  }

  Future<void> _edit(ConsoleCourse course, ConsoleBatch b) async {
    final saved = await showBatchSheet(
      context,
      controller: _c,
      course: course,
      batch: b,
      pickers: widget.pickers,
      now: widget.now,
    );
    if (saved && mounted) showMessage(context, 'Batch saved.');
  }

  Future<void> _delete(ConsoleBatch b) async {
    final ok = await confirmAction(
      context,
      title: 'Delete the Batch "${b.name}"?',
      message: 'Its timetable and registers are deleted too. Enrolled candidates lose their place.',
      confirm: 'Delete',
    );
    if (!ok || !mounted) return;
    final refusal = await _c.delete(b);
    if (refusal != null && mounted) showMessage(context, refusal);
  }

  Future<void> _open(ConsoleBatch b) async {
    final course = _c.courseOf(b);
    if (course == null) return;
    final action = await showBatchViewSheet(context, course: course, batch: b, canEdit: _c.can('batches'), now: _now);
    if (!mounted || action == null) return;
    switch (action) {
      case BatchViewAction.edit:
        await _edit(course, b);
      case BatchViewAction.delete:
        await _delete(b);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TitleBar(title: 'Manage Batches', onBack: widget.onBack, onBell: () => openNotifications(context)),
            Expanded(
              child: !_viewer.isPartnerStaff
                  ? const ConsoleNotice(
                      key: Key('partner-console-notice'),
                      title: notPartnerTitle,
                      text: notPartnerText,
                    )
                  : ListenableBuilder(listenable: _c, builder: (context, _) => _body()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final c = _c;
    if (c.loading && !c.loaded && c.error == null) return const SiteLoading();
    if (c.error != null && !c.loaded) {
      return SiteError(key: const ValueKey('batches-error'), message: c.error!, onRetry: c.refresh);
    }
    final canEdit = c.can('batches');
    final rows = c.rows;
    final selected = c.selectedCourse;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: c.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IcrChip(
                      key: const ValueKey('batches-course-filter'),
                      label: selected == null ? 'All Courses' : selected.code,
                      tone: selected == null ? ChipTone.outlined : ChipTone.primary,
                      height: 32,
                      padding: const EdgeInsets.only(left: 12, right: 8),
                      trailing: const Icon(Icons.expand_more, size: 16),
                      textStyle: SiteText.meta.copyWith(fontWeight: FontWeight.w600, color: AppColors.onSurface),
                      onTap: c.courses.isEmpty ? null : _pickCourse,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        plural(rows.length, 'batch', 'batches'),
                        key: const ValueKey('batches-count'),
                        style: SiteText.secondary,
                      ),
                    ),
                    if (canEdit)
                      FilledButton.icon(
                        key: const ValueKey('batches-new'),
                        onPressed: c.courses.isEmpty ? null : _newBatch,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: const StadiumBorder(),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('New Batch'),
                      ),
                  ],
                ),
                if (c.error != null) ...[
                  const SizedBox(height: 10),
                  Text(c.error!, key: const ValueKey('batches-inline-error'), style: SiteText.secondary),
                ],
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: SiteColors.hairline),
          if (c.courses.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: Text(
                'No courses yet. Create one on Manage Courses, then schedule its batches here.',
                key: const ValueKey('batches-empty'),
                style: SiteText.secondary,
              ),
            )
          else if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: Text(
                'No batches scheduled${selected != null ? ' for ${selected.code}' : ''}. Candidates cannot enrol until a '
                'course has an open batch with a start date.',
                key: const ValueKey('batches-empty'),
                style: SiteText.secondary,
              ),
            )
          else
            for (final b in rows) ...[
              _BatchRow(key: ValueKey('batch-${b.id}'), batch: b, now: _now, busy: c.busy(b.id), onTap: () => _open(b)),
              const Divider(height: 1, thickness: 1, color: SiteColors.hairline),
            ],
        ],
      ),
    );
  }
}

/// One batch, as the website's row: just the name, its course, when it starts, the seats and the status the
/// dates give today — the timetable, mode and length are in the view it opens.
class _BatchRow extends StatelessWidget {
  const _BatchRow({super.key, required this.batch, required this.now, required this.busy, required this.onTap});

  final ConsoleBatch batch;
  final DateTime now;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = batch;
    final status = shownBatchStatus(b, now: now);
    final seats = b.seatsCapacity == null ? 'Uncapped' : '${b.seatsTaken}/${b.seatsCapacity} seats';
    return ConsoleRow(
      onTap: busy ? null : onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.name, style: SiteText.strong),
                const SizedBox(height: 2),
                Text(
                  [if (b.courseCode != null) b.courseCode!, 'Starts ${batchDayLabel(b.startsAt)}', seats].join(' · '),
                  style: b.full ? SiteText.meta.copyWith(color: AppColors.error) : SiteText.meta,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 2),
            child: busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : ConsoleChip(
                    key: ValueKey('batch-status-${b.id}'),
                    label: batchStatusLabel(status),
                    tone: batchStatusTone(status),
                    filled: status == 'OPEN',
                  ),
          ),
        ],
      ),
    );
  }
}
