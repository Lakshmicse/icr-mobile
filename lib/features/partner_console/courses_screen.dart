import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart' show showMessage;
import '../../core/widgets/title_bar.dart';
import '../account/widgets/account_kit.dart' show confirmAction;
import '../notifications/notifications_screen.dart';
import '../site/site_kit.dart';
import 'batches_screen.dart';
import 'course_sheet.dart';
import 'enrolments_screen.dart';
import 'partner_console_controllers.dart';
import 'partner_console_kit.dart';
import 'partner_console_models.dart';
import 'partner_console_repository.dart';
import 'partner_console_rules.dart';

/// The repository a console screen reads: the one handed in, else the API (or the sample institute in demo mode).
PartnerConsoleRepository partnerConsoleRepositoryOf(BuildContext context, PartnerConsoleRepository? given) =>
    given ??
    (AppConfig.demo ? DemoPartnerConsoleRepository() : ApiPartnerConsoleRepository(api: context.read<ApiClient>()));

/// The partner institute's Manage Courses (the website's `/admin/learning/courses` for a partner: `DevelopmentPanel`
/// with its `CoursesTable` and `CourseStatusCell`): every taught course of the institute, drafts included, each
/// with its status and the one action that moves it — Publish, Submit for review (an institute ICR reviews),
/// Withdraw, Unpublish, or "Add a batch to publish" — its batches and enrolments, Edit and Delete; "New course"
/// opens the sheet with the website's fields.
///
/// A member who is not the institute's staff is told the console is the institute's. Rows the whole width,
/// hairlines between. [repository], [viewer] and [pickers] are seams for tests.
class ManageCoursesScreen extends StatefulWidget {
  const ManageCoursesScreen({
    super.key,
    required this.onBack,
    this.repository,
    this.viewer,
    this.pickers = const ConsolePickers(),
    this.now,
  });

  final VoidCallback onBack;
  final PartnerConsoleRepository? repository;

  /// Who is looking; read from the signed-in session when null.
  final PartnerConsoleViewer? viewer;
  final ConsolePickers pickers;

  /// The clock the "next batch" column and the batches page read (tests).
  final DateTime Function()? now;

  @override
  State<ManageCoursesScreen> createState() => _ManageCoursesScreenState();
}

class _ManageCoursesScreenState extends State<ManageCoursesScreen> {
  late final PartnerConsoleRepository _repo;
  late final PartnerConsoleViewer _viewer;
  late final CoursesController _c;

  @override
  void initState() {
    super.initState();
    _repo = partnerConsoleRepositoryOf(context, widget.repository);
    _viewer = consoleViewerOf(context, widget.viewer);
    _c = CoursesController(_repo, viewer: _viewer);
    if (_viewer.isPartnerStaff) _c.start();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _newCourse() async {
    final saved = await showCourseSheet(context, controller: _c, pickers: widget.pickers);
    if (saved && mounted) showMessage(context, 'Saved as a draft.');
  }

  Future<void> _edit(ConsoleCourse c) async {
    final saved = await showCourseSheet(context, controller: _c, course: c, pickers: widget.pickers);
    if (saved && mounted) showMessage(context, 'Course saved.');
  }

  Future<void> _delete(ConsoleCourse c) async {
    final ok = await confirmAction(
      context,
      title: 'Delete "${c.code} — ${c.title}"?',
      message: 'The course and its batches are removed from the console and the public catalogue.',
      confirm: 'Delete',
    );
    if (!ok || !mounted) return;
    final refusal = await _c.delete(c);
    if (refusal != null && mounted) showMessage(context, refusal);
  }

  Future<void> _act(Future<String?> Function() run) async {
    final refusal = await run();
    if (refusal != null && mounted) showMessage(context, refusal);
  }

  void _openBatches(ConsoleCourse c) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (ctx) => ManageBatchesScreen(
              onBack: () => Navigator.of(ctx).pop(),
              courseId: c.id,
              repository: _repo,
              viewer: _viewer,
              pickers: widget.pickers,
              now: widget.now,
            ),
          ),
        )
        .then((_) {
          if (mounted) _c.refresh();
        });
  }

  void _openEnrolments(ConsoleCourse c) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) =>
            EnrolmentsScreen(onBack: () => Navigator.of(ctx).pop(), courseId: c.id, repository: _repo, viewer: _viewer),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TitleBar(title: 'Manage Courses', onBack: widget.onBack, onBell: () => openNotifications(context)),
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
      return SiteError(key: const ValueKey('courses-error'), message: c.error!, onRetry: c.refresh);
    }
    final canEdit = c.can('courses');
    final canPublish = c.can('publish');
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: c.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${plural(c.courses.length, 'course')} · ${plural(c.batchCount, 'batch', 'batches')}',
                        key: const ValueKey('courses-count'),
                        style: SiteText.secondary,
                      ),
                    ),
                    if (canEdit)
                      FilledButton.icon(
                        key: const ValueKey('courses-new'),
                        onPressed: _newCourse,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: const StadiumBorder(),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('New Course'),
                      ),
                  ],
                ),
                if (c.unpublished > 0) ...[
                  const SizedBox(height: 10),
                  Text(
                    '${c.unpublished} course${c.unpublished == 1 ? ' is' : 's are'} not published. A draft is only visible '
                    'here. It reaches the public catalogue and your institute page when you select Publish beside its '
                    'status.',
                    key: const ValueKey('courses-unpublished'),
                    style: SiteText.meta,
                  ),
                ],
                if (c.error != null) ...[
                  const SizedBox(height: 10),
                  Text(c.error!, key: const ValueKey('courses-inline-error'), style: SiteText.secondary),
                ],
                const SizedBox(height: 10),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: SiteColors.hairline),
          if (c.courses.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: Text(
                'No development courses yet. Create a course, such as Facility Management Fundamentals, '
                'then schedule its batches.',
                key: const ValueKey('courses-empty'),
                style: SiteText.secondary,
              ),
            )
          else
            for (final course in c.courses) ...[
              _CourseRow(
                key: ValueKey('course-${course.id}'),
                course: course,
                busy: c.busy(course.id),
                canEdit: canEdit,
                canPublish: canPublish,
                needsBatch: c.needsBatch(course),
                underReview: c.underReview,
                now: (widget.now ?? DateTime.now)(),
                onPublish: () => _act(() => c.publish(course)),
                onUnpublish: () => _act(() => c.unpublish(course)),
                onSubmit: () => _act(() => c.submit(course)),
                onWithdraw: () => _act(() => c.withdraw(course)),
                onBatches: () => _openBatches(course),
                onEnrolments: () => _openEnrolments(course),
                onEdit: () => _edit(course),
                onDelete: () => _delete(course),
              ),
              const Divider(height: 1, thickness: 1, color: SiteColors.hairline),
            ],
        ],
      ),
    );
  }
}

/// One course, as the website's row: code and name, the status chip (with ICR's note when changes were asked
/// for), the format, duration, next batch, batch count and CPD, then the status action and the row's tools.
class _CourseRow extends StatelessWidget {
  const _CourseRow({
    super.key,
    required this.course,
    required this.busy,
    required this.canEdit,
    required this.canPublish,
    required this.needsBatch,
    required this.underReview,
    required this.now,
    required this.onPublish,
    required this.onUnpublish,
    required this.onSubmit,
    required this.onWithdraw,
    required this.onBatches,
    required this.onEnrolments,
    required this.onEdit,
    required this.onDelete,
  });

  final ConsoleCourse course;
  final bool busy;
  final bool canEdit;
  final bool canPublish;
  final bool needsBatch;
  final bool underReview;
  final DateTime now;
  final VoidCallback onPublish;
  final VoidCallback onUnpublish;
  final VoidCallback onSubmit;
  final VoidCallback onWithdraw;
  final VoidCallback onBatches;
  final VoidCallback onEnrolments;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Widget? _statusAction() {
    if (!canPublish) return null;
    final c = course;
    if (c.published) return _textAction('Unpublish', onUnpublish);
    if (c.pendingReview) return _textAction('Withdraw', onWithdraw);
    if (needsBatch) {
      return Text('Add a batch to publish', key: ValueKey('needs-batch-${c.id}'), style: SiteText.meta);
    }
    if (underReview) return _mainAction('Submit for Review', onSubmit, key: ValueKey('submit-${c.id}'));
    return _mainAction('Publish', onPublish, key: ValueKey('publish-${c.id}'));
  }

  Widget _textAction(String label, VoidCallback onTap) => TextButton(
    key: ValueKey('${label.toLowerCase()}-${course.id}'),
    onPressed: busy ? null : onTap,
    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
    child: Text(label),
  );

  Widget _mainAction(String label, VoidCallback onTap, {Key? key}) => FilledButton(
    key: key,
    onPressed: busy ? null : onTap,
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.primary,
      shape: const StadiumBorder(),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 14),
    ),
    child: Text(label),
  );

  @override
  Widget build(BuildContext context) {
    final c = course;
    final next = c.nextBatchStart(now);
    final facts = [
      c.deliveryMode ?? '—',
      c.durationLabel ?? '—',
      next == null ? 'Not scheduled' : 'Next batch ${batchDayLabel(next)}',
      plural(c.batches.length, 'batch', 'batches'),
      '${c.cpdCredits} CPD',
    ].join(' · ');
    final action = _statusAction();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.code, style: SiteText.strong),
                    Text(c.title, style: SiteText.secondary),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ConsoleChip(
                  key: ValueKey('status-${c.id}'),
                  label: courseStatusLabel(c.status),
                  tone: courseStatusTone(c.status),
                  filled: c.published,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(facts, style: SiteText.meta),
          if (c.status == 'REJECTED' && c.reviewNote != null) ...[
            const SizedBox(height: 4),
            Text(
              'ICR asked for changes: ${c.reviewNote}',
              style: SiteText.meta.copyWith(color: AppColors.onErrorContainer),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              ?action,
              if (busy) ...[
                const SizedBox(width: 8),
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
              const Spacer(),
              RowAction(icon: Icons.event_note_outlined, label: 'Batches', onPressed: onBatches),
              RowAction(icon: Icons.groups_outlined, label: 'Enrolments', onPressed: onEnrolments),
              if (canEdit) ...[
                RowAction(
                  key: ValueKey('edit-${c.id}'),
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  onPressed: busy ? null : onEdit,
                ),
                RowAction(
                  key: ValueKey('delete-${c.id}'),
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete',
                  color: AppColors.rose600,
                  onPressed: busy ? null : onDelete,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
