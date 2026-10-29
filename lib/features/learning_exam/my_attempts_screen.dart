import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/title_bar.dart';
import 'api_exam_repository.dart';
import 'attempts_controller.dart';
import 'demo_exam_repository.dart';
import 'exam_format.dart';
import 'exam_models.dart';
import 'exam_repository.dart';
import 'exam_styles.dart';
import 'exam_widgets.dart';
import 'open_paper.dart';
import 'result_screen.dart';
import '../notifications/notifications_screen.dart';

/// The member's sittings, newest first, each opening its result again, with the right answers.
///
/// Reads `GET /learning/me/attempts`, and `/me/attempts/:id` for a result. [repository] is a seam for tests.
class MyAttemptsScreen extends StatefulWidget {
  const MyAttemptsScreen({super.key, required this.onBack, this.repository});

  final VoidCallback onBack;
  final ExamRepository? repository;

  @override
  State<MyAttemptsScreen> createState() => _MyAttemptsScreenState();
}

class _MyAttemptsScreenState extends State<MyAttemptsScreen> {
  late final ExamRepository _repo;
  late final AttemptsController _controller;

  @override
  void initState() {
    super.initState();
    _repo =
        widget.repository ??
        (AppConfig.demo ? DemoExamRepository() : ApiExamRepository(api: context.read<ApiClient>()));
    _controller = AttemptsController(_repo)..start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open(Attempt a) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AttemptResultLoader(
          attempt: a,
          repository: _repo,
          onRetake: a.paper == null
              ? null
              : () {
                  if (mounted) {
                    openPaper(context, a.paper!.ref, repository: widget.repository).then((_) {
                      // A new sitting is a new row in the history.
                      if (mounted) _controller.refresh();
                    });
                  }
                },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final c = _controller;
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                TitleBar(
                  title: 'My attempts',
                  onBack: widget.onBack,
                  unread: c.unread,
                  onBell: () => openNotifications(context),
                ),
                Expanded(child: _body(c)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _body(AttemptsController c) {
    if (c.loading && c.all.isEmpty) return const ExamSpinner();
    if (c.error != null && c.all.isEmpty) {
      return SingleChildScrollView(
        child: ScreenNotice(
          icon: LucideIcons.clipboardCheck,
          title: "Couldn't load your attempts",
          body: c.error!,
          action: 'Try again',
          onAction: c.refresh,
        ),
      );
    }
    final rows = c.shown;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: c.refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (c.all.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            value: '${c.all.length}',
                            label: 'Attempts',
                            icon: LucideIcons.clipboardCheck,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatTile(
                            value: '${c.passed}',
                            label: 'Passed',
                            icon: LucideIcons.badgeCheck,
                            color: AppColors.tertiary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatTile(
                            value: c.best == null ? '-' : '${c.best}%',
                            label: 'Best',
                            icon: LucideIcons.trophy,
                            color: AppColors.amber500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FilterChip(
                          label: 'All',
                          on: c.filter == AttemptsFilter.all,
                          onTap: () => c.setFilter(AttemptsFilter.all),
                        ),
                        _FilterChip(
                          label: 'Assessments',
                          on: c.filter == AttemptsFilter.assessments,
                          onTap: () => c.setFilter(AttemptsFilter.assessments),
                        ),
                        _FilterChip(
                          label: 'Mock exams',
                          on: c.filter == AttemptsFilter.mocks,
                          onTap: () => c.setFilter(AttemptsFilter.mocks),
                        ),
                      ],
                    ),
                    if (c.error != null) ...[
                      const SizedBox(height: 12),
                      Notice(tone: NoticeTone.error, text: c.error!, action: 'Try again', onAction: c.refresh),
                    ],
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
          if (c.all.isEmpty)
            SliverToBoxAdapter(
              child: ScreenNotice(
                icon: LucideIcons.clipboardCheck,
                title: 'No attempts yet',
                body: 'Papers you sit show up here, with your score and the right answers.',
                action: 'Back to Learning',
                onAction: widget.onBack,
              ),
            )
          else if (rows.isEmpty)
            SliverToBoxAdapter(
              child: ScreenNotice(
                icon: LucideIcons.clipboardCheck,
                title: 'Nothing under this filter',
                body: 'You have not sat a paper of this kind yet.',
                action: 'Show all',
                onAction: () => c.setFilter(AttemptsFilter.all),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              sliver: SliverList.separated(
                itemCount: rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => AttemptCard(attempt: rows[i], onTap: () => _open(rows[i])),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IcrChip(
      label: label,
      tone: on ? ChipTone.primary : ChipTone.outlined,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      textStyle: AppText.workSans(13, FontWeight.w600, AppColors.onSurface, lineHeight: 18),
      onTap: onTap,
    );
  }
}

/// One sitting in the history.
class AttemptCard extends StatelessWidget {
  const AttemptCard({super.key, required this.attempt, required this.onTap});

  final Attempt attempt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = attempt;
    final name = a.paper?.name ?? 'Paper';
    final mock = a.paper?.kind == PaperKind.mock;
    final when = dateTimeLabel(a.submittedAt);
    return Semantics(
      button: true,
      label:
          '$name, attempt ${a.attempt}, ${a.percentage} percent, ${a.passed ? 'passed' : 'not passed'}. Opens the result.',
      excludeSemantics: true,
      child: ExamCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ExamText.subheading.copyWith(fontSize: 16),
                  ),
                ),
                const SizedBox(width: 8),
                a.passed
                    ? const InfoPill(label: 'Pass', icon: LucideIcons.check, color: AppColors.tertiary)
                    : InfoPill(
                        label: mock ? 'Below pass mark' : 'Fail',
                        icon: LucideIcons.x,
                        color: mock ? AppColors.amber800 : AppColors.error,
                      ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Attempt #${a.attempt}${when.isEmpty ? '' : ' · $when'}', style: ExamText.small),
            const SizedBox(height: 12),
            Row(
              children: [
                _Figure('${a.percentage}%', 'Score', big: true),
                _Figure('${a.correct} / ${a.totalQuestions}', 'Correct'),
                _Figure(takenLabel(a.timeTaken), 'Time'),
                const Icon(LucideIcons.chevronRight, size: 20, color: AppColors.slate400),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.value, this.label, {this.big = false});

  final String value;
  final String label;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppText.workSans(big ? 20 : 15, FontWeight.w800, big ? AppColors.primary : AppColors.onSurface),
          ),
          Text(label.toUpperCase(), style: ExamText.statLabel),
        ],
      ),
    );
  }
}

/// A past sitting's result: loads `GET /learning/me/attempts/:id`, then shows it as the result of a fresh one.
class AttemptResultLoader extends StatefulWidget {
  const AttemptResultLoader({super.key, required this.attempt, required this.repository, this.onRetake});

  final Attempt attempt;
  final ExamRepository repository;
  final VoidCallback? onRetake;

  @override
  State<AttemptResultLoader> createState() => _AttemptResultLoaderState();
}

class _AttemptResultLoaderState extends State<AttemptResultLoader> {
  AttemptResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_error != null) setState(() => _error = null);
    try {
      final r = await widget.repository.attempt(widget.attempt.id);
      if (mounted) setState(() => _result = r);
    } catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    if (result != null) {
      final paper = result.attempt.paper ?? widget.attempt.paper;
      return ResultScreen(
        result: result,
        paperName: paper?.name ?? 'Your sitting',
        certificateEnabled: paper?.certificateEnabled ?? false,
        onRetake: widget.onRetake,
        eyebrowSuffix: result.attempt.submittedAt == null ? null : ' · ${dayLabel(result.attempt.submittedAt)}',
        setName: paper?.title,
        repository: widget.repository,
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ExamTitleBar(title: 'Test Results', onBack: () => popOnce(context)),
            Expanded(
              child: _error == null
                  ? const ExamSpinner()
                  : SingleChildScrollView(
                      child: ScreenNotice(
                        icon: LucideIcons.clipboardCheck,
                        title: "Couldn't open this result",
                        body: _error!,
                        action: 'Try again',
                        onAction: _load,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
