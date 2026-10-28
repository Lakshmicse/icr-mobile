import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/util/links.dart' show showMessage;
import '../../core/widgets/buttons.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/detail_sheet.dart';
import '../../core/widgets/section_heading.dart';
import 'apply_sheet.dart';
import 'job_detail_controller.dart';
import 'job_format.dart';
import 'job_links.dart';
import 'job_models.dart';
import 'jobs_controller.dart';
import 'jobs_navigation.dart';
import 'jobs_repository.dart';
import 'jobs_styles.dart';
import '../career/company_insights_controller.dart' show InsightsTab;
import '../career/company_insights_screen.dart';
import 'widgets/job_row.dart';

/// Opens a job over the board, as the Job Details design. The board's own
/// controller follows what the member does in it (a bookmark, an application,
/// a job hidden); the hand-overs (a company, a conversation, a person) are the
/// screen's [JobsNavigationScope].
Future<void> showJobSheet(BuildContext context, Job job) async {
  final jobs = context.read<JobsController>();
  await showJobDetail(
    context,
    job,
    repository: jobs.repository,
    links: jobs.links,
    onChanged: jobs.update,
    onApplied: jobs.applied,
    onHidden: jobs.hidden,
  );
}

/// The same sheet from anywhere else (the career screens, an alert's matches):
/// [repository] reads the job and sends what the member does; the callbacks
/// tell the screen underneath.
Future<void> showJobDetail(
  BuildContext context,
  Job job, {
  required JobsRepository repository,
  JobLinks? links,
  JobsNavigation? navigation,
  ValueChanged<Job>? onChanged,
  ValueChanged<Job>? onApplied,
  ValueChanged<Job>? onHidden,
}) async {
  final controller = JobDetailController(
    repository: repository,
    seed: job,
    onChanged: onChanged,
    onApplied: onApplied,
    onHidden: onHidden,
    links: links,
    navigation: navigation ?? JobsNavigationScope.of(context),
  )..load();
  await showDetailSheet<void>(
    context,
    body: (_) => ChangeNotifierProvider.value(value: controller, child: const JobSheetBody()),
    bottomBar: (_) => ChangeNotifierProvider.value(value: controller, child: const JobSheetBar()),
  );
  controller.dispose();
}

/// The scrolling part of the sheet.
class JobSheetBody extends StatelessWidget {
  const JobSheetBody({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<JobDetailController>();
    final job = controller.job;
    final blocks = descriptionBlocks(job.descriptionHtml);
    final intro = blocks.takeWhile((b) => b.kind == BlockKind.paragraph).toList();
    final rest = blocks.skip(intro.length).toList();
    final skills = [...job.skills, ...job.preferredSkills.where((s) => !job.skills.contains(s))];
    final match = controller.match;
    final people = controller.people;
    final posted = postedAgo(job.postedAt);
    final count = applicantsOrOpenings(job);
    final salary = salaryLabel(job);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Toolbar(job: job, onSave: () => _run(context, controller.toggleSave())),
              const SizedBox(height: 13.5),
              _CompanyRow(company: job.company, onOpen: () => _company(context, controller)),
              const SizedBox(height: 7.5),
              Text(job.title, style: JobsText.title),
              if (job.highlight != null) ...[
                const SizedBox(height: 6),
                Text(job.highlight!, style: JobsText.highlight, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 8.5),
              _MetaRow(job: job),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    width: 7.5,
                    height: 7.5,
                    decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5.5),
                  Flexible(
                    child: Text(
                      job.statusLine ?? (job.applied ? 'You have applied' : 'Accepting applications'),
                      style: JobsText.status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // The design spaces the three pieces of this line unevenly.
                  if (posted != null) ...[
                    const _Dot(before: 17.5, after: 10),
                    Text(posted, style: JobsText.statusMeta),
                  ],
                  if (count != null) ...[
                    _Dot(before: posted != null ? 27.5 : 17.5, after: 10),
                    Text(count, style: JobsText.statusMeta),
                  ],
                ],
              ),
              if (salary != null || job.matchScore != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (salary != null)
                      IcrChip(
                        label: salary,
                        height: 27,
                        icon: LucideIcons.banknote,
                        iconSize: 16,
                        iconColor: AppColors.onSurfaceVariant,
                        padding: const EdgeInsets.only(left: 12, right: 11),
                        gap: 7,
                        textStyle: JobsText.chip,
                      ),
                    if (salary != null && job.matchScore != null) const SizedBox(width: 9),
                    if (job.matchScore != null)
                      IcrChip(
                        label: '${job.matchScore}% Profile Match',
                        tone: ChipTone.tinted,
                        fill: AppColors.successTint,
                        height: 27,
                        leading: const Icon(Symbols.stars, fill: 1, size: 14, color: AppColors.tertiary),
                        padding: const EdgeInsets.only(left: 13, right: 13),
                        gap: 7,
                        textStyle: JobsText.chipMatch,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 7),
            ],
          ),
        ),
        const Hairline(color: AppColors.blockRule),
        if (controller.loading && job.descriptionHtml == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2))),
          )
        else if (controller.error != null && job.descriptionHtml == null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(controller.error!, style: JobsText.body),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 9, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('About the job', style: JobsText.section),
                const SizedBox(height: 12),
                if (intro.isEmpty)
                  Text('The employer has not written a description yet.', style: JobsText.body)
                else
                  for (final (i, block) in intro.indexed) ...[
                    if (i > 0) const SizedBox(height: 8),
                    Text(block.text, style: JobsText.body),
                  ],
                const SizedBox(height: 7.5),
                ..._sections(rest),
                if (job.qualifications.isNotEmpty) ...[
                  const SizedBox(height: 6.5),
                  const Hairline(color: AppColors.cardRule),
                  const SizedBox(height: 15),
                  Text('Qualifications', style: JobsText.section),
                  const SizedBox(height: 8),
                  for (final (i, q) in job.qualifications.indexed) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _Bullet(text: q),
                  ],
                ],
                if (skills.isNotEmpty) ...[
                  const SizedBox(height: 6.5),
                  const Hairline(color: AppColors.cardRule),
                  const SizedBox(height: 18),
                  Text('Desired Qualifications', style: JobsText.section),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 20,
                    runSpacing: 6,
                    children: [
                      for (final skill in skills)
                        IcrChip(
                          label: skill,
                          height: 24,
                          padding: const EdgeInsets.symmetric(horizontal: 11),
                          textStyle: JobsText.skill,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 9.5),
              ],
            ),
          ),
          if (match != null && match.checks.isNotEmpty) ...[
            const Hairline(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 9, 16, 0),
              child: _MatchCard(
                match: match,
                onInsights: () => controller.links.openUri(context, controller.repository.link(job)),
              ),
            ),
            const SizedBox(height: 10),
            const Hairline(color: AppColors.blockRule),
          ],
          if (job.contact != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 19.5, 16, 0),
              child: _HiringTeam(
                contact: job.contact!,
                people: people,
                onMessage: () => _message(context, controller),
                onPeople: () => _company(context, controller, tab: InsightsTab.people),
                onContact: job.contact!.memberId == null
                    ? null
                    : () => controller.navigation.openProfile(context, controller.links, job.contact!.memberId!),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 34.5, 16, 24),
            child: _AboutCompany(
              company: job.company,
              onFollow: () => _follow(context, controller),
              onOpen: () => _company(context, controller),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _sections(List<DescriptionBlock> blocks) {
    final out = <Widget>[];
    var itemCount = 0;
    for (final block in blocks) {
      switch (block.kind) {
        case BlockKind.heading:
          out.add(const Hairline(color: AppColors.cardRule));
          out.add(const SizedBox(height: 13.5));
          out.add(Text(block.text, style: JobsText.section));
          out.add(const SizedBox(height: 8.5));
          itemCount = 0;
        case BlockKind.item:
          if (itemCount > 0) out.add(const SizedBox(height: 8));
          out.add(_Bullet(text: block.text));
          itemCount++;
        case BlockKind.paragraph:
          out.add(const SizedBox(height: 8));
          out.add(Text(block.text, style: JobsText.body));
      }
    }
    return out;
  }

  static Future<void> _run(BuildContext context, Future<String?> action) async {
    final message = await action;
    if (message != null && context.mounted) showMessage(context, message);
  }

  /// "Message": opens the conversation with the job's contact, in the app's
  /// messaging (the website's thread until that is wired).
  static Future<void> _message(BuildContext context, JobDetailController controller) async {
    final result = await controller.messageContact();
    if (!context.mounted) return;
    if (result.error != null) {
      showMessage(context, result.error!);
      return;
    }
    await controller.navigation.openConversation(context, controller.links, result.conversationId);
  }

  /// "+ Follow": ICR has no following for companies (members follow members),
  /// so this says so and opens the company's page instead.
  static Future<void> _follow(BuildContext context, JobDetailController controller) async {
    showMessage(context, followNotice);
    await _company(context, controller);
  }

  static const followNotice = "Companies can't be followed on ICR yet. Here is the company's page.";

  /// The company's name or logo, "+ Follow" and the strip of faces: the company's
  /// careers page in the app (its jobs, people, reviews, salaries and interviews).
  /// Its own "See the company page" hands over to [JobsNavigation.openCompany].
  static Future<void> _company(
    BuildContext context,
    JobDetailController controller, {
    InsightsTab tab = InsightsTab.jobs,
  }) => openCompanyInsights(
    context,
    company: controller.job.company,
    links: controller.links,
    navigation: controller.navigation,
    jobs: controller.repository,
    tab: tab,
  );
}

/// The bar under the sheet: bookmark, and Easy Apply.
class JobSheetBar extends StatelessWidget {
  const JobSheetBar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<JobDetailController>();
    final job = controller.job;
    final label = job.applied ? 'Applied' : (job.externalApply ? 'Apply on company site' : 'Easy Apply');
    return BottomActionBar(
      gap: 13,
      children: [
        SoftIconButton(
          icon: job.saved ? LucideIcons.bookmarkCheck : LucideIcons.bookmark,
          label: job.saved ? 'Remove bookmark' : 'Save job',
          selected: job.saved,
          iconColor: job.saved ? AppColors.primary : AppColors.onSurface,
          onPressed: () => JobSheetBody._run(context, controller.toggleSave()),
        ),
        Expanded(
          child: PrimaryButton(
            label: label,
            icon: job.applied ? LucideIcons.check : (job.externalApply ? LucideIcons.externalLink : LucideIcons.zap),
            onPressed: job.applied || controller.applying ? null : () => startApplication(context, controller),
          ),
        ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.job, required this.onSave});

  final Job job;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<JobDetailController>();
    final link = controller.repository.link(job);
    return Row(
      children: [
        Container(
          height: 20,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(6)),
          child: Text('JOB DETAILS', style: JobsText.kicker),
        ),
        const Spacer(),
        _ToolIcon(
          icon: LucideIcons.share2,
          size: 18,
          label: 'Share',
          onTap: () => controller.links.share(text: '${job.title}\n$link', subject: job.title),
        ),
        const SizedBox(width: 16),
        _ToolIcon(
          icon: job.saved ? LucideIcons.bookmarkCheck : LucideIcons.bookmark,
          size: 20,
          label: job.saved ? 'Remove bookmark' : 'Save job',
          color: job.saved ? AppColors.primary : AppColors.onSurfaceVariant,
          onTap: onSave,
        ),
        const SizedBox(width: 16),
        _ToolIcon(
          icon: LucideIcons.ellipsis,
          size: 18,
          label: 'More',
          onTap: () => showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            backgroundColor: Colors.white,
            builder: (sheet) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Symbols.link),
                    title: Text('Copy link', style: AppText.small.copyWith(color: AppColors.onSurface, fontSize: 14)),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: link.toString()));
                      Navigator.pop(sheet);
                      showMessage(context, 'Link copied');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Symbols.open_in_new),
                    title: Text(
                      'Open on the ICR website',
                      style: AppText.small.copyWith(color: AppColors.onSurface, fontSize: 14),
                    ),
                    onTap: () {
                      Navigator.pop(sheet);
                      controller.links.openUri(context, link);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Symbols.reviews),
                    title: Text(
                      'Reviews, salaries and interviews',
                      style: AppText.small.copyWith(color: AppColors.onSurface, fontSize: 14),
                    ),
                    onTap: () {
                      Navigator.pop(sheet);
                      openCompanyInsights(
                        context,
                        company: job.company,
                        links: controller.links,
                        navigation: controller.navigation,
                        jobs: controller.repository,
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Symbols.visibility_off),
                    title: Text(
                      'Not interested',
                      style: AppText.small.copyWith(color: AppColors.onSurface, fontSize: 14),
                    ),
                    subtitle: Text('Hide this job from your board', style: AppText.small.copyWith(fontSize: 13)),
                    onTap: () async {
                      Navigator.pop(sheet);
                      final refusal = await controller.hide();
                      if (!context.mounted) return;
                      if (refusal != null) {
                        showMessage(context, refusal);
                        return;
                      }
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.maybePop(context);
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(const SnackBar(content: Text(hiddenNotice)));
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 6.5),
      ],
    );
  }
}

/// What the sheet says once the member hid its job.
const hiddenNotice = 'Hidden. Bring it back from Hidden jobs in your career hub.';

class _ToolIcon extends StatelessWidget {
  const _ToolIcon({required this.icon, required this.size, required this.label, required this.onTap, this.color});

  final IconData icon;
  final double size;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        child: SizedBox(
          width: 24,
          height: 24,
          child: Icon(icon, size: size, color: color ?? AppColors.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _CompanyRow extends StatelessWidget {
  const _CompanyRow({required this.company, required this.onOpen});

  final JobCompany company;

  /// The logo or the name: the company's page.
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open ${company.name}',
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onOpen, child: _row()),
    );
  }

  Widget _row() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CompanyLogoTile(company: company, width: 46, height: 47, radius: 8, color: AppColors.surfaceContainer),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        company.name,
                        style: JobsText.companyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (company.verified) ...[
                      const SizedBox(width: 5),
                      const Icon(Symbols.verified, fill: 1, size: 13, color: AppColors.primary),
                    ],
                  ],
                ),
                if (company.tagline != null || company.kind != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    company.tagline ?? company.kind!,
                    style: JobsText.companyTagline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final pieces = <Widget>[
      if (job.cityState != null)
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 10 × 12 dp of ink, drawn 1.7 dp left of its box as the design sets it.
              Transform.translate(
                offset: const Offset(-1.7, 0),
                child: const Icon(LucideIcons.mapPin, size: 13.3, color: AppColors.linkIcon),
              ),
              const SizedBox(width: 0.4),
              Flexible(
                child: Text(job.cityState!, style: JobsText.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      if (job.workMode != null) Text(job.workMode!.label, style: JobsText.meta),
      if (job.employmentType != null) Text(job.employmentType!.label, style: JobsText.metaSoft),
    ];
    if (pieces.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        for (final (i, piece) in pieces.indexed) ...[
          // The design's gaps: 9 | dot | 17.5 before and after the middle piece, then 17.5 | dot | 10.
          if (i == 1) const _Dot(before: 9, after: 17.5),
          if (i == 2) const _Dot(before: 17.5, after: 10),
          piece,
        ],
      ],
    );
  }
}

/// " • " between the pieces of a line, with the room the design leaves on each side.
class _Dot extends StatelessWidget {
  const _Dot({this.before = 8, this.after = 8});

  final double before;
  final double after;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: before, right: after),
      child: Container(
        width: 3.5,
        height: 3.5,
        decoration: const BoxDecoration(color: AppColors.onSurfaceVariant, shape: BoxShape.circle),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The design's tick breaks out of its ring (Material's "task alt"): 15 × 15 dp of ink in
        // the primary blue, in a 15 dp box so the words keep their place.
        const Padding(
          padding: EdgeInsets.only(top: 1.5),
          child: SizedBox(
            width: 15,
            height: 16,
            child: OverflowBox(
              maxWidth: 18,
              maxHeight: 18,
              child: Icon(Symbols.task_alt, size: 18, weight: 500, color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // The design keeps the words 23 dp short of the right margin, so a line breaks earlier.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 23),
            child: Text(text, style: JobsText.bullet),
          ),
        ),
      ],
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match, required this.onInsights});

  final JobMatch match;

  /// "Show comparative applicant insights": the job's page on the website,
  /// where the match and the applicants' comparison are.
  final VoidCallback onInsights;

  @override
  Widget build(BuildContext context) {
    final title = match.summary ?? 'Your profile matches ${match.met} of ${match.checks.length} requirements';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: JobsText.section)),
            const SizedBox(width: 8),
            Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(color: AppColors.successBadge, shape: BoxShape.circle),
              child: const Icon(LucideIcons.badgeCheck, size: 14, color: AppColors.tertiary),
            ),
          ],
        ),
        const SizedBox(height: 6.5),
        Container(
          decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11.5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, check) in match.checks.indexed) ...[
                if (i > 0) const SizedBox(height: 7.5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: check.met
                          ? Container(
                              width: 17,
                              height: 17,
                              decoration: const BoxDecoration(color: AppColors.tertiary, shape: BoxShape.circle),
                              child: const Icon(Symbols.check, size: 11, weight: 700, color: Colors.white),
                            )
                          : Container(
                              width: 17,
                              height: 17,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.outline, width: 1.5),
                              ),
                            ),
                    ),
                    const SizedBox(width: 10),
                    // The design centres the title on the circle, 5.5 dp below the top of the row.
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 5.5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(check.label, style: JobsText.checkTitle),
                            if (check.detail != null) ...[
                              const SizedBox(height: 1),
                              Text(check.detail!, style: JobsText.checkDetail),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 11),
        Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onInsights,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Show comparative applicant insights', style: JobsText.insights),
                const SizedBox(width: 3),
                const Icon(LucideIcons.chevronRight, size: 12, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HiringTeam extends StatelessWidget {
  const _HiringTeam({
    required this.contact,
    required this.people,
    required this.onMessage,
    required this.onPeople,
    this.onContact,
  });

  final JobContact contact;
  final CompanyPeople? people;
  final VoidCallback onMessage;

  /// The contact's photo or name: their profile, when the API names them.
  final VoidCallback? onContact;

  /// The strip of faces: the company's people, on the website.
  final VoidCallback onPeople;

  @override
  Widget build(BuildContext context) {
    final line = [contact.role, ?contact.activity].join(' • ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Meet the hiring team', style: JobsText.section),
        const SizedBox(height: 16.5),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The design sets the photo 3 dp below the top of the name.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onContact,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6.5),
                  child: _Avatar(picture: contact.photo, name: contact.name),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: contact.name,
                            style: JobsText.contactName,
                            recognizer: onContact == null ? null : (TapGestureRecognizer()..onTap = onContact),
                          ),
                          if (contact.degree != null)
                            TextSpan(text: '  •  ${contact.degree}', style: JobsText.contactDegree),
                        ],
                      ),
                    ),
                    if (contact.designation != null) ...[
                      const SizedBox(height: 2),
                      Text(contact.designation!, style: JobsText.contactLine),
                    ],
                    const SizedBox(height: 1),
                    Text(line, style: JobsText.contactLink),
                  ],
                ),
              ),
              // The design keeps the words well clear of the button.
              const SizedBox(width: 48),
              Padding(
                padding: const EdgeInsets.only(top: 18.5),
                child: OutlinePillButton(
                  label: 'Message',
                  onPressed: onMessage,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                ),
              ),
            ],
          ),
        ),
        if (people?.text != null) ...[
          const SizedBox(height: 10),
          Semantics(
            button: true,
            label: 'People who work at this company',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPeople,
              child: Container(
                height: 42,
                decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.only(left: 8, right: 58),
                child: Row(
                  children: [
                    SizedBox(
                      width: 76,
                      height: 32,
                      child: Stack(
                        children: [
                          for (final (i, face) in _faces(people!).indexed)
                            Positioned(
                              left: i * 22.0,
                              child: _Face(index: i, label: face.label, photo: face.photo, plus: face.plus),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(people!.text!, style: JobsText.network, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The faces in the strip: the first two people named, then "+4" for the rest.
List<({String label, FeedPicture? photo, bool plus})> _faces(CompanyPeople people) => [
  for (final (i, name) in people.names.take(2).indexed)
    (label: CompanyPeople.initialsOf(name), photo: i < people.photos.length ? people.photos[i] : null, plus: false),
  if (people.others > 0) (label: '+${people.others}', photo: null, plus: true),
];

/// One round face of the strip: the person's photo, or their initials on blue,
/// then green; "+4" on grey.
class _Face extends StatelessWidget {
  const _Face({required this.index, required this.label, required this.photo, required this.plus});

  final int index;
  final String label;
  final FeedPicture? photo;
  final bool plus;

  @override
  Widget build(BuildContext context) {
    final image = photo;
    Widget? picture;
    if (image?.asset != null) {
      picture = Image.asset(image!.asset!, fit: BoxFit.cover);
    } else if (image?.url != null) {
      picture = Image(
        image: CachedNetworkImageProvider(image!.url!),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: plus
            ? const Color(0xFF4B5563)
            : switch (index) {
                0 => AppColors.primary,
                _ => AppColors.tertiary,
              },
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surfaceContainer, width: 2),
      ),
      child: picture ?? Text(label, style: JobsText.networkInitials),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.picture, required this.name});

  final FeedPicture? picture;
  final String name;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (picture?.asset != null) {
      child = Image.asset(picture!.asset!, fit: BoxFit.cover);
    } else if (picture?.url != null) {
      child = CachedNetworkImage(imageUrl: picture!.url!, fit: BoxFit.cover);
    } else {
      child = Center(
        child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: JobsText.contactName.copyWith(fontSize: 16)),
      );
    }
    return Container(
      width: 46,
      height: 48,
      decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _AboutCompany extends StatelessWidget {
  const _AboutCompany({required this.company, required this.onFollow, required this.onOpen});

  final JobCompany company;

  /// The photo tile or the name: the company's page.
  final VoidCallback onOpen;

  /// "+ Follow": the API has no company follow; this goes to the company's page.
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final meta = [?company.kind, ?company.size].join(' • ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('About ${company.name}', style: JobsText.section),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 46 × 48 dp with its hairline drawn over the photo, as the design's tile (the photo
            // is the whole tile; a border outside it made it 2 dp bigger each way), 0.5 dp
            // below the top of the name.
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Container(
                width: 46,
                height: 48,
                foregroundDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE7EEFF)),
                ),
                child: CompanyLogoTile(
                  company: company,
                  picture: company.cover,
                  width: 46,
                  height: 48,
                  radius: 8,
                  color: const Color(0xFFE7EEFF),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // The design keeps the name and its line to 160 dp, so a long line wraps
            // ("Real Estate Facilities • 8,400+" / "employees").
            Expanded(
              child: Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 0.5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onOpen,
                          child: Text(company.legalName ?? company.name, style: JobsText.contactName),
                        ),
                        if (meta.isNotEmpty) ...[const SizedBox(height: 2.5), Text(meta, style: JobsText.aboutMeta)],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16.5, right: 17),
              child: Semantics(
                button: true,
                label: 'Follow ${company.name}',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onFollow,
                  child: Text('+ Follow', style: JobsText.follow),
                ),
              ),
            ),
          ],
        ),
        if (company.description != null) ...[
          const SizedBox(height: 7),
          Text(company.description!, style: JobsText.description, maxLines: 4, overflow: TextOverflow.ellipsis),
        ],
      ],
    );
  }
}
