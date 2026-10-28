import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart' show showMessage;
import '../../core/widgets/buttons.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/section_heading.dart';
import '../../core/widgets/title_bar.dart';
import '../jobs/job_detail_sheet.dart';
import '../jobs/job_links.dart';
import '../jobs/jobs_navigation.dart';
import '../jobs/jobs_repository.dart';
import '../jobs/widgets/job_row.dart';
import 'career_factory.dart';
import 'career_format.dart';
import 'career_models.dart';
import 'career_repository.dart';
import 'career_styles.dart';
import 'company_insights_controller.dart';
import 'insight_forms.dart';

/// Opens a company's reviews, salaries, interviews, people and jobs over
/// whatever is showing: the job sheet's "Reviews, salaries and interviews",
/// a career screen's company line. [repository] reads and writes them; given
/// only the [jobs] source of the screen that opened it, the matching career
/// source is made (the API's, or the designs' sample content).
Future<void> openCompanyInsights(
  BuildContext context, {
  required JobCompany company,
  JobLinks? links,
  JobsNavigation? navigation,
  CareerRepository? repository,
  JobsRepository? jobs,
  InsightsTab tab = InsightsTab.reviews,
}) async {
  final links0 = links ?? const SystemJobLinks();
  final source = repository ?? (jobs == null ? null : careerRepositoryFor(jobs));
  if (source == null || company.id.isEmpty) {
    // Nothing to read it from (a company the API did not name): the website's page.
    await links0.openSite(context, company.id.isEmpty ? '/companies' : '/companies/${company.id}?tab=reviews');
    return;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => CompanyInsightsScreen(
        repository: source,
        company: company,
        links: links0,
        navigation: navigation ?? JobsNavigationScope.of(context),
        tab: tab,
      ),
    ),
  );
}

/// Opens a company's careers page knowing only its id (a notification, a link,
/// a row that carries no company block).
Future<void> openCompanyInsightsById(
  BuildContext context, {
  required String companyId,
  JobLinks? links,
  JobsNavigation? navigation,
  CareerRepository? repository,
  JobsRepository? jobs,
  InsightsTab tab = InsightsTab.jobs,
}) => openCompanyInsights(
  context,
  company: JobCompany(id: companyId, name: ''),
  links: links,
  navigation: navigation,
  repository: repository,
  jobs: jobs,
  tab: tab,
);

/// A company as a candidate weighs it: what people say about working there,
/// what it pays, how its interviews go, who works there and what it is hiring
/// for. Everything is read from the company's public pages; a member adds a
/// review, a salary or an interview experience from here.
class CompanyInsightsScreen extends StatefulWidget {
  const CompanyInsightsScreen({
    super.key,
    required this.repository,
    required this.company,
    this.links = const SystemJobLinks(),
    this.navigation = JobsNavigation.none,
    this.tab = InsightsTab.reviews,
    this.onBack,
  });

  /// A company known only by its id: the header reads its name, logo and size from the API.
  CompanyInsightsScreen.forId({
    super.key,
    required this.repository,
    required String companyId,
    this.links = const SystemJobLinks(),
    this.navigation = JobsNavigation.none,
    this.tab = InsightsTab.jobs,
    this.onBack,
  }) : company = JobCompany(id: companyId, name: '');

  final CareerRepository repository;
  final JobCompany company;
  final JobLinks links;

  /// Where a person or the company's own page opens.
  final JobsNavigation navigation;
  final InsightsTab tab;

  /// The arrow at the top left; the route pops when null.
  final VoidCallback? onBack;

  @override
  State<CompanyInsightsScreen> createState() => _CompanyInsightsScreenState();
}

class _CompanyInsightsScreenState extends State<CompanyInsightsScreen> {
  late final CompanyInsightsController _controller = CompanyInsightsController(
    repository: widget.repository,
    company: widget.company,
    tab: widget.tab,
  );

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
    _controller.start();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> action) async {
    final message = await action;
    if (message != null && mounted) showMessage(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              top: TitleBar.height,
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: c.refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    _Header(controller: c, links: widget.links, navigation: widget.navigation),
                    const SizedBox(height: 12),
                    ChipRow(
                      height: 30,
                      children: [
                        for (final tab in InsightsTab.values)
                          IcrChip(
                            key: ValueKey('tab-${tab.name}'),
                            label: tab.label,
                            height: 30,
                            tone: c.tab == tab ? ChipTone.primary : ChipTone.outlined,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            textStyle: CareerText.tabLabel,
                            onTap: () => c.select(tab),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Hairline(color: AppColors.blockRule),
                    Padding(padding: const EdgeInsets.fromLTRB(10, 14, 10, 0), child: _body(c)),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: TitleBar(
                title: 'Company',
                onBack: widget.onBack,
                unread: c.unread,
                onBell: () => widget.navigation.openNotifications(context, widget.links),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(CompanyInsightsController c) => switch (c.tab) {
    InsightsTab.reviews => _ReviewsTab(controller: c),
    InsightsTab.salaries => _SalariesTab(controller: c),
    InsightsTab.interviews => _InterviewsTab(controller: c),
    InsightsTab.people => _PeopleTab(controller: c, links: widget.links, navigation: widget.navigation),
    InsightsTab.jobs => _JobsTab(
      controller: c,
      links: widget.links,
      navigation: widget.navigation,
      onSave: (job) => _run(c.toggleSave(job)),
    ),
  };
}

/// The company, its rating and the ways onward.
class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.links, required this.navigation});

  final CompanyInsightsController controller;
  final JobLinks links;
  final JobsNavigation navigation;

  @override
  Widget build(BuildContext context) {
    final company = controller.company;
    final summary = controller.summary;
    final meta = [?company.kind, ?company.size, ?company.city].join(' • ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CompanyLogoTile(company: company, width: 57, height: 61),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  company.name.isEmpty ? 'Company' : company.name,
                  style: CareerText.companyName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(meta, style: CareerText.companyMeta, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 6),
                if (summary != null && summary.count > 0 && summary.average != null)
                  Row(
                    key: const ValueKey('header-rating'),
                    children: [
                      Text(summary.average!.toStringAsFixed(1), style: CareerText.bodyStrong),
                      const SizedBox(width: 6),
                      StarRow(value: summary.average!, size: 14),
                      const SizedBox(width: 6),
                      Text('${summary.count} review${summary.count == 1 ? '' : 's'}', style: CareerText.meta),
                    ],
                  )
                else if (summary != null)
                  Text('No reviews yet', style: CareerText.meta),
                const SizedBox(height: 8),
                InkWell(
                  key: const ValueKey('company-page'),
                  onTap: () => navigation.openCompany(context, links, company.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('See the company page', style: CareerText.link),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- shared bits ---------------------------------------------------------------

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 40),
    child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
    this.keyName,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;
  final String? keyName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: keyName == null ? null : ValueKey<String>(keyName!),
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 20),
      child: Column(
        children: [
          Icon(icon, size: 32, color: AppColors.outline),
          const SizedBox(height: 10),
          Text(title, textAlign: TextAlign.center, style: CareerText.cardTitle.copyWith(fontSize: 14)),
          const SizedBox(height: 4),
          Text(body, textAlign: TextAlign.center, style: CareerText.body),
          if (action != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.outlineVariant),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(action!, style: CareerText.link),
            ),
          ],
        ],
      ),
    );
  }
}

/// A tab's own loading, error and "no more" rows around its content.
class _Paged<T> extends StatelessWidget {
  const _Paged({
    required this.list,
    required this.onRetry,
    required this.onMore,
    required this.empty,
    required this.builder,
    this.lead = const [],
  });

  final InsightList<T> list;
  final VoidCallback onRetry;
  final VoidCallback onMore;
  final Widget empty;
  final Widget Function(T item) builder;

  /// Above the rows: the form's button, a summary.
  final List<Widget> lead;

  @override
  Widget build(BuildContext context) {
    if (list.error != null && list.items.isEmpty) {
      return _Notice(
        keyName: 'tab-error',
        icon: LucideIcons.cloudOff,
        title: "Couldn't load this",
        body: list.error!,
        action: 'Try again',
        onAction: onRetry,
      );
    }
    if (!list.loaded) return const _Loading();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...lead,
        if (list.items.isEmpty)
          empty
        else
          for (final item in list.items) ...[builder(item), const SizedBox(height: 10)],
        if (list.hasMore)
          Center(
            child: list.loadingMore
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : TextButton(
                    key: const ValueKey('view-more'),
                    onPressed: onMore,
                    child: Text('View More', style: CareerText.link),
                  ),
          ),
      ],
    );
  }
}

Widget _addButton(String label, IconData icon, VoidCallback onTap, {String? keyName}) => Padding(
  padding: const EdgeInsets.only(bottom: 14),
  child: PrimaryButton(
    key: keyName == null ? null : ValueKey(keyName),
    label: label,
    icon: icon,
    height: 40,
    radius: 10,
    onPressed: onTap,
  ),
);

// --- reviews -------------------------------------------------------------------

class _ReviewsTab extends StatelessWidget {
  const _ReviewsTab({required this.controller});

  final CompanyInsightsController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final mine = c.mine;
    final summary = c.summary;
    return _Paged<EmployerReview>(
      list: c.reviews,
      onRetry: c.retry,
      onMore: c.loadMore,
      empty: _Notice(
        keyName: 'reviews-empty',
        icon: LucideIcons.messageSquareText,
        title: 'No reviews yet',
        body: 'Be the first to say what it is like to work at ${c.company.name}.',
      ),
      lead: [
        if (summary != null && summary.count > 0) _RatingCard(summary: summary),
        if (summary != null && summary.count > 0) const SizedBox(height: 14),
        if (mine != null) _MyReviewNote(review: mine),
        _addButton(
          mine == null ? 'Write a review' : 'Update my review',
          LucideIcons.pencilLine,
          () => showReviewForm(context, c),
          keyName: 'write-review',
        ),
      ],
      builder: (r) => _ReviewCard(review: r),
    );
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({required this.summary});

  final RatingSummary summary;

  @override
  Widget build(BuildContext context) {
    final most = summary.distribution.values.fold<int>(1, (a, b) => b > a ? b : a);
    return Container(
      key: const ValueKey('rating-card'),
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 92,
                child: Column(
                  children: [
                    Text(summary.average?.toStringAsFixed(1) ?? '–', style: CareerText.bigNumber),
                    StarRow(value: summary.average ?? 0, size: 14),
                    const SizedBox(height: 2),
                    Text('${summary.count} review${summary.count == 1 ? '' : 's'}', style: CareerText.meta),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    for (final star in [5, 4, 3, 2, 1])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            SizedBox(width: 10, child: Text('$star', style: CareerText.meta)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: (summary.distribution[star] ?? 0) / most,
                                  minHeight: 6,
                                  color: AppColors.amber500,
                                  backgroundColor: AppColors.surfaceContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 22,
                              child: Text('${summary.distribution[star] ?? 0}', style: CareerText.meta),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (summary.subRatings.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Hairline(color: AppColors.cardRule),
            const SizedBox(height: 8),
            for (final e in summary.subRatings.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text(e.key, style: CareerText.body)),
                    Text(e.value.toStringAsFixed(1), style: CareerText.bodyStrong),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// The member's own review: where moderation has it.
class _MyReviewNote extends StatelessWidget {
  const _MyReviewNote({required this.review});

  final EmployerReview review;

  @override
  Widget build(BuildContext context) {
    final words = switch (review.status) {
      'APPROVED' => 'Your review is published.',
      'REJECTED' => 'ICR did not publish your review. You can write it again.',
      _ => 'Your review is waiting for ICR to read it. It shows once it is approved.',
    };
    return Container(
      key: const ValueKey('my-review'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: cardDecoration(color: AppColors.surfaceContainerLow),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.info, size: 16, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(words, style: CareerText.body)),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final EmployerReview review;

  @override
  Widget build(BuildContext context) {
    final who = [
      ?review.jobTitle,
      if (review.employmentStatus == 'CURRENT') 'Current employee',
      if (review.employmentStatus == 'FORMER') 'Former employee',
    ].join(' • ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StarRow(value: review.rating.toDouble(), size: 15),
              if (review.verifiedEmployee) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.successTint, borderRadius: BorderRadius.circular(6)),
                  child: Text('Verified employee', style: CareerText.pill),
                ),
              ],
              const Spacer(),
              Text(formatDay(review.createdAt, year: true), style: CareerText.meta),
            ],
          ),
          if (review.title != null && review.title!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.title!, style: CareerText.cardTitle),
          ],
          if (who.isNotEmpty) ...[const SizedBox(height: 2), Text(who, style: CareerText.meta)],
          if (review.pros != null && review.pros!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('PROS', style: CareerText.label),
            const SizedBox(height: 2),
            Text(review.pros!, style: CareerText.body),
          ],
          if (review.cons != null && review.cons!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('CONS', style: CareerText.label),
            const SizedBox(height: 2),
            Text(review.cons!, style: CareerText.body),
          ],
          if (review.advice != null && review.advice!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('ADVICE TO MANAGEMENT', style: CareerText.label),
            const SizedBox(height: 2),
            Text(review.advice!, style: CareerText.body),
          ],
        ],
      ),
    );
  }
}

// --- salaries ------------------------------------------------------------------

class _SalariesTab extends StatelessWidget {
  const _SalariesTab({required this.controller});

  final CompanyInsightsController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final info = c.salaries;
    final reach = c.salaryState.items.fold<double>(1, (m, r) => r.p75 > m ? r.p75 : m);
    return _Paged<SalaryRole>(
      list: c.salaryState,
      onRetry: c.retry,
      onMore: () {},
      empty: _Notice(
        keyName: 'salaries-empty',
        icon: LucideIcons.banknote,
        title: 'Not enough salary reports yet',
        body: info == null
            ? 'Pay shows once enough people report it.'
            : 'A role shows once ${info.minSample} people have reported it, so no one can be picked out. '
                  '${info.totalReports == 0 ? 'None so far.' : '${info.totalReports} so far.'}',
      ),
      lead: [
        _addButton(
          'Share your salary',
          LucideIcons.banknote,
          () => showSalaryForm(context, c),
          keyName: 'share-salary',
        ),
      ],
      builder: (r) => _SalaryCard(role: r, reach: reach),
    );
  }
}

class _SalaryCard extends StatelessWidget {
  const _SalaryCard({required this.role, required this.reach});

  final SalaryRole role;

  /// The largest 75th percentile across the roles, so the bars share a scale.
  final double reach;

  @override
  Widget build(BuildContext context) {
    final lo = (role.p25 / reach).clamp(0.0, 1.0);
    final hi = (role.p75 / reach).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(role.jobTitle, style: CareerText.cardTitle)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatMoneyShort(role.median), style: CareerText.money),
                  Text('a year, typical', style: CareerText.meta),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 8,
            child: LayoutBuilder(
              builder: (context, box) => Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Positioned(
                    left: box.maxWidth * lo,
                    width: (box.maxWidth * (hi - lo)).clamp(4.0, box.maxWidth),
                    top: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${formatMoneyShort(role.p25)} to ${formatMoneyShort(role.p75)} for the middle half of '
            '${role.count} reports'
            '${role.avgExperience == null ? '' : ', ${role.avgExperience!.toStringAsFixed(1)} years of experience on average'}.',
            style: CareerText.meta,
          ),
        ],
      ),
    );
  }
}

// --- interviews ----------------------------------------------------------------

class _InterviewsTab extends StatelessWidget {
  const _InterviewsTab({required this.controller});

  final CompanyInsightsController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final averages = c.interviews.averages;
    return _Paged<InterviewReview>(
      list: c.interviews,
      onRetry: c.retry,
      onMore: c.loadMore,
      empty: _Notice(
        keyName: 'interviews-empty',
        icon: LucideIcons.messagesSquare,
        title: 'No interview experiences yet',
        body: 'Sat an interview at ${c.company.name}? Tell the next person how it went.',
      ),
      lead: [
        if (averages.isNotEmpty) ...[
          Row(
            key: const ValueKey('interview-averages'),
            children: [
              if (averages['difficulty'] != null)
                Expanded(
                  child: _Average(label: 'Difficulty', value: averages['difficulty']!),
                ),
              if (averages['difficulty'] != null && averages['experience'] != null) const SizedBox(width: 10),
              if (averages['experience'] != null)
                Expanded(
                  child: _Average(label: 'Experience', value: averages['experience']!),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        _addButton(
          'Share your interview',
          LucideIcons.messagesSquare,
          () => showInterviewForm(context, c),
          keyName: 'share-interview',
        ),
      ],
      builder: (r) => _InterviewCard(review: r),
    );
  }
}

class _Average extends StatelessWidget {
  const _Average({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: cardDecoration(color: AppColors.surfaceContainerLow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: CareerText.label),
          const SizedBox(height: 2),
          Text('${value.toStringAsFixed(1)} / 5', style: CareerText.money),
        ],
      ),
    );
  }
}

class _InterviewCard extends StatelessWidget {
  const _InterviewCard({required this.review});

  final InterviewReview review;

  @override
  Widget build(BuildContext context) {
    final facts = [
      ?review.difficultyLabel,
      ?review.experienceLabel,
      ?review.outcomeLabel,
      if (review.durationDays != null) '${review.durationDays} days',
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(review.jobTitle ?? 'Interview', style: CareerText.cardTitle)),
              Text(formatDay(review.createdAt, year: true), style: CareerText.meta),
            ],
          ),
          if (facts.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final f in facts)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(f, style: CareerText.metaStrong),
                  ),
              ],
            ),
          ],
          if (review.process != null && review.process!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('THE PROCESS', style: CareerText.label),
            const SizedBox(height: 2),
            Text(review.process!, style: CareerText.body),
          ],
          if (review.questions != null && review.questions!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('QUESTIONS ASKED', style: CareerText.label),
            const SizedBox(height: 2),
            Text(review.questions!, style: CareerText.body),
          ],
        ],
      ),
    );
  }
}

// --- people --------------------------------------------------------------------

class _PeopleTab extends StatelessWidget {
  const _PeopleTab({required this.controller, required this.links, required this.navigation});

  final CompanyInsightsController controller;
  final JobLinks links;
  final JobsNavigation navigation;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return _Paged<CompanyPerson>(
      list: c.people,
      onRetry: c.retry,
      onMore: c.loadMore,
      empty: _Notice(
        keyName: 'people-empty',
        icon: LucideIcons.users,
        title: 'No one to show yet',
        body: 'No one at ${c.company.name} has a public profile on ICR yet.',
      ),
      lead: [
        if (c.people.total != null && c.people.total! > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '${c.people.total} ${c.people.total == 1 ? 'person' : 'people'} from ${c.company.name} on ICR',
              style: CareerText.meta,
            ),
          ),
      ],
      builder: (p) => _PersonRow(person: p, onTap: () => navigation.openProfile(context, links, p.id)),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, required this.onTap});

  final CompanyPerson person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final photo = person.photo;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: cardDecoration(),
        child: Row(
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: AppColors.surfaceContainer,
              backgroundImage: photo?.url == null ? null : CachedNetworkImageProvider(photo!.url!),
              child: photo?.url == null
                  ? Text(person.initials, style: CareerText.bodyStrong.copyWith(color: AppColors.outline))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(person.name, style: CareerText.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (person.headline != null && person.headline!.isNotEmpty)
                    Text(person.headline!, style: CareerText.meta, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.outline),
          ],
        ),
      ),
    );
  }
}

// --- jobs ----------------------------------------------------------------------

class _JobsTab extends StatelessWidget {
  const _JobsTab({required this.controller, required this.links, required this.navigation, required this.onSave});

  final CompanyInsightsController controller;
  final JobLinks links;
  final JobsNavigation navigation;
  final void Function(Job job) onSave;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return _Paged<Job>(
      list: c.jobs,
      onRetry: c.retry,
      onMore: c.loadMore,
      empty: _Notice(
        keyName: 'jobs-empty',
        icon: LucideIcons.briefcaseBusiness,
        title: 'No open jobs',
        body: '${c.company.name} has no open jobs right now.',
      ),
      builder: (job) => DecoratedBox(
        decoration: cardDecoration(),
        child: JobRow(
          key: ValueKey('job-${job.id}'),
          job: job,
          onSave: () => onSave(job),
          onTap: () => showJobDetail(
            context,
            job,
            repository: c.repository.jobs,
            links: links,
            navigation: navigation,
            onChanged: c.jobChanged,
            onApplied: c.jobChanged,
          ),
        ),
      ),
    );
  }
}
