import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/title_bar.dart';
import 'api_mentor_profile_repository.dart';
import 'demo_mentor_profile_repository.dart';
import 'mentor_profile_actions.dart';
import 'mentor_profile_controller.dart';
import 'mentor_profile_models.dart';
import 'mentor_profile_repository.dart';
import 'offering_sheet.dart';
import 'widgets/offerings_tab.dart';
import 'widgets/overview_sections.dart';
import 'widgets/plan_card.dart';
import 'widgets/profile_bottom_bar.dart';
import 'widgets/profile_hero.dart';
import 'widgets/profile_tabs.dart';

/// The Mentor Profile for one mentor, with its own controller: the API, or
/// the design's sample content under `--dart-define=FEED_SOURCE=demo`.
/// [mentorId] is the mentor profile's id (`MentorProfile.id`, what the
/// directory lists and a member's `mentorProfileId` carries).
///
/// The shell pushes it:
/// `Navigator.push(context, MaterialPageRoute(builder: (c) => mentorProfileRoute(c, id)))`.
Widget mentorProfileRoute(BuildContext context, String mentorId) {
  final MentorProfileRepository repository = AppConfig.demo
      ? DemoMentorProfileRepository()
      : ApiMentorProfileRepository(api: context.read<ApiClient>());
  return ChangeNotifierProvider<MentorProfileController>(
    create: (_) => MentorProfileController(repository: repository, mentorId: mentorId),
    child: Builder(
      builder: (inner) => MentorProfileScreen(mentorId: mentorId, onBack: () => Navigator.of(inner).maybePop()),
    ),
  );
}

/// The Mentor Profile: hero, tabs (Overview, Offerings, Recommendations), the
/// flagship plan and the pinned bar. Reads its [MentorProfileController] from
/// `Provider`.
class MentorProfileScreen extends StatefulWidget {
  const MentorProfileScreen({super.key, required this.mentorId, required this.onBack});

  final String mentorId;

  /// The arrow at the top left.
  final VoidCallback onBack;

  @override
  State<MentorProfileScreen> createState() => _MentorProfileScreenState();
}

class _MentorProfileScreenState extends State<MentorProfileScreen> {
  @override
  void initState() {
    super.initState();
    final controller = context.read<MentorProfileController>();
    // After this frame: load() notifies, which cannot happen while building.
    if (!controller.started) Future.microtask(controller.load);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<MentorProfileController>();
    final profile = c.profile;
    final actions = profile == null ? null : heroActionsFor(context, c);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.white),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                top: TitleBar.height,
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: c.load,
                  child: profile == null || actions == null
                      ? _Placeholder(controller: c)
                      : _Page(controller: c, profile: profile, actions: actions, bottomInset: bottom),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: TitleBar(
                  title: 'Mentor Profile',
                  onBack: widget.onBack,
                  unread: c.unread,
                  onBell: () => c.navigation.notifications(context),
                ),
              ),
              if (actions != null) Positioned(bottom: 0, left: 0, right: 0, child: ProfileBottomBar(actions: actions)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.controller, required this.profile, required this.actions, required this.bottomInset});

  final MentorProfileController controller;
  final MentorProfile profile;
  final HeroActions actions;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final p = profile;
    final plan = c.featuredPlan;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: ProfileBottomBar.height + 15.6 + bottomInset),
      children: [
        ProfileHero(profile: p, actions: actions),
        const SizedBox(height: 18.2),
        ProfileTabs(selected: c.tab, onSelect: c.selectTab),
        ...switch (c.tab) {
          ProfileTab.overview => [
            StatsCard(profile: p),
            AboutSection(firstName: p.firstName, bioHtml: p.bioHtml, expanded: c.bioExpanded, onExpand: c.expandBio),
            const SectionRule(inset: true),
            CareerSection(roles: p.experience, yearsLabel: p.yearsLabel),
            if (p.experience.isNotEmpty) const SectionRule(),
            EducationSection(education: p.education),
            if (p.education.isNotEmpty) const SectionRule(),
            SkillsSection(profile: p),
            RecommendationsSection(
              profile: p,
              reviews: c.reviews,
              onViewAll: () => c.selectTab(ProfileTab.recommendations),
            ),
          ],
          ProfileTab.offerings => [
            OfferingsTab(
              filters: c.filters,
              filter: c.filter,
              onFilter: c.selectFilter,
              rows: c.rows,
              onOpen: (o) => showOfferingSheet(context, o),
              onAction: (o) => runOfferingAction(context, c, o),
            ),
          ],
          ProfileTab.recommendations => [
            RecommendationsSection(
              profile: p,
              reviews: c.reviews,
              limit: c.reviews.length,
              onViewAll: () => c.selectTab(ProfileTab.recommendations),
            ),
            const SizedBox(height: 24),
          ],
        },
        if (plan != null) PlanCard(plan: plan, onApply: () => runOfferingAction(context, c, plan)),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.controller});

  final MentorProfileController controller;

  @override
  Widget build(BuildContext context) {
    final error = controller.error;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 420,
          child: error == null
              ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4)))
              : Padding(
                  padding: const EdgeInsets.fromLTRB(32, 48, 32, 48),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.userRound, size: 36, color: AppColors.outline),
                      const SizedBox(height: 12),
                      Text(
                        "Couldn't load this mentor",
                        textAlign: TextAlign.center,
                        style: AppText.postTitle.copyWith(fontSize: 16, height: 1.3),
                      ),
                      const SizedBox(height: 6),
                      Text(error, textAlign: TextAlign.center, style: AppText.small),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: controller.load,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.outlineVariant),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Try again', style: AppText.link),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
