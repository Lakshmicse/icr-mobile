import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/title_bar.dart';
import '../account/widgets/account_kit.dart' show showAccountPicker;
import '../learning_exam/exam_format.dart' show dayLabel;
import '../notifications/notifications_screen.dart';
import '../site/site_kit.dart';
import 'courses_screen.dart' show partnerConsoleRepositoryOf;
import 'enrolment_sheet.dart';
import 'partner_console_controllers.dart';
import 'partner_console_kit.dart';
import 'partner_console_models.dart';
import 'partner_console_repository.dart';
import 'partner_console_rules.dart';

/// The partner institute's Enrolment (the website's `/admin/learning/enrolments`, `EnrollmentsTable`): who has
/// enrolled on its courses, newest first, narrowed by course and status, each row opening the enrolment in full
/// with Confirm place and Cancel enrolment for those who may decide (the company admin, an Enrolment Admin, a
/// Batch Admin). Confirming into a full batch is refused by the API, and the refusal is shown above the list as
/// the website shows it. An institute whose plan leaves participant management out sees the plan's sentence.
class EnrolmentsScreen extends StatefulWidget {
  const EnrolmentsScreen({super.key, required this.onBack, this.repository, this.courseId, this.viewer});

  final VoidCallback onBack;
  final PartnerConsoleRepository? repository;

  /// Opens narrowed to one course (a course row's Enrolments).
  final String? courseId;
  final PartnerConsoleViewer? viewer;

  @override
  State<EnrolmentsScreen> createState() => _EnrolmentsScreenState();
}

class _EnrolmentsScreenState extends State<EnrolmentsScreen> {
  late final PartnerConsoleRepository _repo;
  late final PartnerConsoleViewer _viewer;
  late final EnrolmentsController _c;

  @override
  void initState() {
    super.initState();
    _repo = partnerConsoleRepositoryOf(context, widget.repository);
    _viewer = consoleViewerOf(context, widget.viewer);
    _c = EnrolmentsController(_repo, viewer: _viewer, courseId: widget.courseId);
    if (_viewer.isPartnerStaff) _c.start();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

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

  Future<void> _open(ConsoleEnrolment e) async {
    final decision = await showEnrolmentSheet(context, enrolment: e, canEdit: _c.can('enrolments'));
    if (decision == null || !mounted) return;
    // The refusal is shown above the list, so the sheet closes to reveal it.
    await _c.decide(e, decision);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TitleBar(title: 'Enrolment', onBack: widget.onBack, onBell: () => openNotifications(context)),
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
      return SiteError(key: const ValueKey('enrolments-error'), message: c.error!, onRetry: c.refresh);
    }
    final selected = c.selectedCourse;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: c.refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) c.loadMore();
          return false;
        },
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
                      if (widget.courseId == null)
                        IcrChip(
                          key: const ValueKey('enrolments-course-filter'),
                          label: selected == null ? 'All Courses' : selected.code,
                          tone: selected == null ? ChipTone.outlined : ChipTone.primary,
                          height: 32,
                          padding: const EdgeInsets.only(left: 12, right: 8),
                          trailing: const Icon(Icons.expand_more, size: 16),
                          textStyle: SiteText.meta.copyWith(fontWeight: FontWeight.w600, color: AppColors.onSurface),
                          onTap: c.courses.isEmpty ? null : _pickCourse,
                        )
                      else if (selected != null)
                        Text('${selected.code} — ${selected.title}', style: SiteText.strong),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          plural(c.total, 'enrolment'),
                          key: const ValueKey('enrolments-count'),
                          style: SiteText.secondary,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // The website's Status select, as chips.
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FilterChip(label: 'All Statuses', on: c.status.isEmpty, onTap: () => c.setStatus('')),
                      for (final s in enrolmentStatuses)
                        _FilterChip(
                          key: ValueKey('filter-$s'),
                          label: enrolmentStatusLabel(s),
                          on: c.status == s,
                          onTap: () => c.setStatus(s),
                        ),
                    ],
                  ),
                  if (c.error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      c.error!,
                      key: const ValueKey('enrolments-inline-error'),
                      style: SiteText.secondary.copyWith(color: AppColors.error),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: SiteColors.hairline),
            if (c.lock != null)
              ConsoleNotice(
                key: const ValueKey('enrolments-lock'),
                icon: Symbols.lock,
                title: 'Participant Management',
                text: '${c.lock} A larger Institution plan includes it.',
              )
            else if (c.rows.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                child: Text(
                  'No enrolments match these filters.',
                  key: const ValueKey('enrolments-empty'),
                  style: SiteText.secondary,
                ),
              )
            else ...[
              for (final e in c.rows) ...[
                _EnrolmentRow(
                  key: ValueKey('enrolment-${e.id}'),
                  enrolment: e,
                  busy: c.busy(e.id),
                  onTap: () => _open(e),
                ),
                const Divider(height: 1, thickness: 1, color: SiteColors.hairline),
              ],
              if (c.loadingMore) const Padding(padding: EdgeInsets.all(16), child: SiteLoading()),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({super.key, required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IcrChip(
      label: label,
      tone: on ? ChipTone.primary : ChipTone.outlined,
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      textStyle: AppText.workSans(13, FontWeight.w600, AppColors.onSurface, lineHeight: 18),
      onTap: onTap,
    );
  }
}

/// One enrolment, as the website's row: name and course only, when they applied and the status; the email, batch,
/// note and the decision are in the view.
class _EnrolmentRow extends StatelessWidget {
  const _EnrolmentRow({super.key, required this.enrolment, required this.busy, required this.onTap});

  final ConsoleEnrolment enrolment;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = enrolment;
    return ConsoleRow(
      onTap: busy ? null : onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.name, style: SiteText.strong),
                const SizedBox(height: 2),
                Text('${e.courseCode} · Applied ${dayLabel(e.createdAt)}', style: SiteText.meta),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 2),
            child: busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : ConsoleChip(
                    key: ValueKey('enrolment-status-${e.id}'),
                    label: enrolmentStatusLabel(e.status),
                    tone: enrolmentStatusTone(e.status),
                    filled: true,
                  ),
          ),
        ],
      ),
    );
  }
}
