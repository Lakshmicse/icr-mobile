import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../core/config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/section_heading.dart';
import '../employer/hiring_routes.dart';
import '../job_links.dart';
import '../job_models.dart';
import '../jobs_controller.dart';
import '../jobs_navigation.dart';
import '../jobs_styles.dart';
import 'job_filters_sheet.dart';
import 'my_jobs_sheet.dart';

/// Under the title bar: the search, the member's own chips, the search the
/// board is scoped to, and the filters; then the rule the list hangs from.
class JobsToolbar extends StatelessWidget {
  const JobsToolbar({super.key, required this.searchController, required this.onAlerts});

  final TextEditingController searchController;

  /// "Alerts": the screen runs the saved search and scrolls to its section.
  final VoidCallback onAlerts;

  @override
  Widget build(BuildContext context) {
    final jobs = context.watch<JobsController>();
    final filters = jobs.filters;
    final scope = jobs.context;
    final posted = filters.postedWithinDays != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 5),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: IcrSearchField(controller: searchController, onSubmitted: jobs.setSearch),
        ),
        const SizedBox(height: 6.5),
        ChipRow(
          children: [
            IcrChip(
              label: 'Post a job',
              tone: ChipTone.tinted,
              fill: AppColors.surfaceContainer,
              border: AppColors.outlineVariant,
              icon: LucideIcons.circlePlus,
              iconSize: 14.4,
              padding: const EdgeInsets.only(left: 11.5, right: 13),
              gap: 5.5,
              onTap: () => _postAJob(context, jobs),
            ),
            IcrChip(
              label: 'My jobs',
              tone: ChipTone.outlined,
              icon: LucideIcons.bookmark,
              iconSize: 11.5,
              padding: const EdgeInsets.only(left: 10.5, right: 12.5),
              gap: 4.7,
              trailing: jobs.myJobs > 0 ? _CountCircle(jobs.myJobs) : null,
              trailingGap: 7.8,
              onTap: () => showMyJobs(context),
            ),
            IcrChip(
              label: 'Alerts',
              tone: ChipTone.outlined,
              icon: LucideIcons.bellRing,
              iconSize: 12,
              padding: const EdgeInsets.only(left: 11.5, right: 12.5),
              gap: 5.5,
              trailing: jobs.newAlerts > 0 ? _NewPill('${jobs.newAlerts} new') : null,
              trailingGap: 8,
              onTap: onAlerts,
            ),
            IcrChip(
              label: 'Demonstrate skills',
              tone: ChipTone.outlined,
              icon: LucideIcons.badgeCheck,
              iconSize: 12.5,
              padding: const EdgeInsets.only(left: 11.5, right: 12),
              gap: 5.7,
              onTap: () => JobsNavigationScope.of(context).demonstrateSkills(context, jobs.links),
            ),
          ],
        ),
        if (scope != null) ...[
          const SizedBox(height: 6.5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ScopeBar(scope: scope, onClear: jobs.clearContext),
          ),
        ],
        const SizedBox(height: 9),
        _FilterChips(
          children: [
            IcrChip(
              label: jobs.filterCount > 0 ? 'Filters (${jobs.filterCount})' : 'Filters',
              tone: ChipTone.tinted,
              fill: AppColors.surfaceContainer,
              border: AppColors.outlineVariant,
              icon: LucideIcons.slidersHorizontal,
              iconSize: 9.8,
              padding: const EdgeInsets.only(left: 11.1, right: 12.5),
              gap: 3.3,
              height: 25,
              textStyle: JobsText.filterChip.copyWith(wordSpacing: 0.7),
              onTap: () => showJobFilters(context),
            ),
            IcrChip(
              label: 'Easy Apply',
              tone: filters.easyApply ? ChipTone.primary : ChipTone.outlined,
              icon: LucideIcons.zap,
              iconSize: 10.5,
              trailing: filters.easyApply ? const Icon(LucideIcons.check, size: 12, color: Colors.white) : null,
              trailingGap: 5,
              padding: const EdgeInsets.only(left: 10.75, right: 10.25),
              gap: 3.5,
              height: 25,
              textStyle: JobsText.filterChip,
              onTap: jobs.toggleEasyApply,
            ),
            IcrChip(
              label: postedLabel(filters.postedWithinDays),
              tone: posted ? ChipTone.primary : ChipTone.outlined,
              trailing: Icon(Icons.arrow_drop_down, size: 13, color: posted ? Colors.white : AppColors.outline),
              trailingGap: 0.5,
              padding: const EdgeInsets.only(left: 12.2, right: 8.75),
              height: 25,
              textStyle: JobsText.filterChip,
              onTap: () => pickPosted(context),
            ),
            IcrChip(
              label: 'In my network',
              tone: ChipTone.outlined,
              icon: LucideIcons.users,
              iconSize: 12.4,
              iconColor: AppColors.tertiary,
              padding: const EdgeInsets.only(left: 11.1, right: 12),
              gap: 3.4,
              height: 25,
              textStyle: JobsText.filterChip,
              onTap: () => _network(context, jobs.links),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Hairline(color: AppColors.blockRule),
      ],
    );
  }

  /// "Post a job": the composer for a member on a company's hiring team; for anyone else, the way
  /// to a company of their own.
  static Future<void> _postAJob(BuildContext context, JobsController jobs) async {
    final navigation = JobsNavigationScope.of(context);
    final access = await jobs.hiringAccess();
    if (!context.mounted) return;
    if (access == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text("Couldn't check your account. Try again in a moment.")));
      return;
    }
    if (access.canManage) {
      await hiringRoutesOf(context).postJob();
      return;
    }
    await showHirersOnly(context, navigation: navigation, links: jobs.links);
  }

  /// The API has no "in my network" (no connections, and no job filter that
  /// follows people), so the chip says so and offers the website's network.
  static void _network(BuildContext context, JobLinks links) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text("Jobs at companies in your network aren't in the app yet."),
          action: SnackBarAction(
            label: 'Open network',
            onPressed: () => links.openUri(context, AppConfig.sitePage('/network')),
          ),
        ),
      );
  }
}

/// "Facilities & Real Estate • Bengaluru, IN", with the cross that drops it.
class ScopeBar extends StatelessWidget {
  const ScopeBar({super.key, required this.scope, required this.onClear});

  final JobContext scope;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [_softShadow],
      ),
      child: Row(
        children: [
          const SizedBox(width: 9.75),
          const Icon(Symbols.work_history, size: 17, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 6.25),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: scope.label, style: JobsText.contextLabel),
                  if (scope.place != null) ...[
                    // A 3 dp dot with 7 dp before it and 4 after, as the design sets it.
                    const WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: EdgeInsets.only(left: 7, right: 4, top: 5),
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: AppColors.outline, shape: BoxShape.circle),
                          child: SizedBox(width: 3, height: 3),
                        ),
                      ),
                    ),
                    TextSpan(text: scope.place, style: JobsText.contextPlace),
                  ],
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Semantics(
            button: true,
            label: 'Clear search scope',
            child: InkResponse(
              onTap: onClear,
              radius: 18,
              child: const SizedBox(
                width: 36,
                height: 28,
                child: Padding(
                  padding: EdgeInsets.only(left: 11),
                  child: Center(child: Icon(LucideIcons.x, size: 15.75, color: AppColors.onSurfaceVariant)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The count after "My jobs": a pale circle with the number in blue.
class _CountCircle extends StatelessWidget {
  const _CountCircle(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16.5,
      height: 16.5,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: AppColors.surfaceContainer, shape: BoxShape.circle),
      child: Text('$count', style: AppText.badgeCount),
    );
  }
}

/// "2 new" after Alerts: a blue pill.
class _NewPill extends StatelessWidget {
  const _NewPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 6.75),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: JobsText.pill),
    );
  }
}

/// The soft shadow under the design's filter chips and scope bar:
/// `0 1px 2px rgba(0,0,0,.05)`.
const _softShadow = BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1));

/// The row of filter chips: sideways scrolling like [ChipRow], with room under
/// the chips for their shadow (a list would clip it), and 5 dp between them.
class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.children});

  final List<Widget> children;

  /// What the shadow adds below the 25 dp chips.
  static const _shadowRoom = 3.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 25 + _shadowRoom,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Align(
          alignment: Alignment.topLeft,
          child: Row(
            children: [
              for (final (i, chip) in children.indexed) ...[
                if (i > 0) const SizedBox(width: 5),
                DecoratedBox(
                  decoration: const ShapeDecoration(shape: StadiumBorder(), shadows: [_softShadow]),
                  child: chip,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
