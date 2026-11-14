import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/search_field.dart';
import '../../core/widgets/title_bar.dart';
import '../learning/learning_controller.dart';
import '../learning/widgets/course_card.dart';
import '../../core/widgets/section_heading.dart' show SectionHeading;
import 'hub_controller.dart';
import 'hub_factory.dart';
import 'hub_models.dart';
import 'hub_styles.dart';
import 'learning_doors.dart';
import 'partner_screen.dart';
import 'widgets/hub_parts.dart';
import 'widgets/institute_card.dart';
import '../notifications/notifications_screen.dart';

/// Partner Courses: the institutes that award certifications through ICR, and
/// the way to become one. The website's `/learning/partners` is deliberately a
/// directory of institutes rather than a list of partner courses: whose course
/// it is changes what you sign up to, so the institute is the choice that comes
/// first. Opening one shows its own catalogue ([PartnerScreen]).
///
/// [hub] is what the Learning hub passes so the institutes it has loaded are
/// not read again; without it the screen builds its own.
class PartnerCoursesScreen extends StatefulWidget {
  const PartnerCoursesScreen({super.key, required this.onBack, this.hub});

  final VoidCallback onBack;
  final LearningHubController? hub;

  @override
  State<PartnerCoursesScreen> createState() => _PartnerCoursesScreenState();
}

class _PartnerCoursesScreenState extends State<PartnerCoursesScreen> {
  final _search = TextEditingController();
  late final LearningHubController _hub;
  late final bool _ownsHub;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _ownsHub = widget.hub == null;
    _hub = widget.hub ?? createHubController(context);
    if (!_hub.started) _hub.start();
    // Where the member's companies stand as partners, so "Apply" is offered only to someone it is for.
    _hub.loadPartnerStanding();
    _search.addListener(() {
      final next = _search.text.trim().toLowerCase();
      if (next != _query) setState(() => _query = next);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    if (_ownsHub) _hub.dispose();
    super.dispose();
  }

  /// The institutes whose name or summary the search matches.
  List<Institute> get _shown {
    if (_query.isEmpty) return _hub.institutes;
    return [
      for (final i in _hub.institutes)
        if (i.name.toLowerCase().contains(_query) || (i.summary?.toLowerCase().contains(_query) ?? false)) i,
    ];
  }

  /// "Apply": the partner application, then the member's companies read again, so a company that has just applied
  /// (or been founded) shows its standing in place of the button.
  Future<void> _apply() async {
    await openSitePage(context, '/learning/partners/apply');
    if (mounted) await _hub.loadPartnerStanding();
  }

  void _openInstitute(Institute institute) {
    pushLearningPage<void>(context, (route, back) => PartnerScreen(institute: institute, onBack: back, hub: _hub));
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LearningController>.value(
      value: _hub.learning,
      child: ListenableBuilder(
        listenable: _hub,
        builder: (context, _) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.white),
          child: Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  Positioned.fill(
                    top: TitleBar.reserved(context),
                    child: RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () => Future.wait([_hub.reloadInstitutes(), _hub.loadPartnerStanding()]),
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(10, 5, 10, 12),
                              child: IcrSearchField(
                                controller: _search,
                                hint: 'Search institutes...',
                                onSubmitted: (_) {},
                              ),
                            ),
                          ),
                          ..._body(),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: TitleBar(
                      title: 'Partner Programmes',
                      onBack: widget.onBack,
                      unread: _hub.unread,
                      onBell: () => openNotifications(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Where the member stands as a partner: "Apply" for someone it is for, else the standing of each company they
  /// run. The website's heading carries Apply whether or not the directory has institutes, so every state of the
  /// list ends with this.
  List<Widget> _applySection() => [
    if (_hub.offerPartnerApplication)
      _ApplyBanner(onApply: _apply)
    else
      for (final company in _hub.partnerStanding) ...[_StandingBanner(company: company), const SizedBox(height: 8)],
  ];

  List<Widget> _body() {
    if (_hub.institutesLoading) {
      return [
        SliverList(
          delegate: SliverChildListDelegate([
            for (var i = 0; i < 2; i++) ...[
              if (i > 0) const SizedBox(height: CourseGridRow.rowGap),
              Padding(
                key: ValueKey('institutes-skeleton-$i'),
                padding: CourseGridRow.padding,
                child: const Row(
                  children: [
                    Expanded(child: HubSkeleton(height: 190)),
                    SizedBox(width: CourseGridRow.gap),
                    Expanded(child: HubSkeleton(height: 190)),
                  ],
                ),
              ),
            ],
          ]),
        ),
      ];
    }
    final error = _hub.institutesError;
    if (error != null) {
      return [
        SliverToBoxAdapter(
          child: HubNotice(
            title: 'Unable to Load Institutes',
            body: error,
            action: 'Try Again',
            onAction: _hub.reloadInstitutes,
            icon: LucideIcons.handshake,
          ),
        ),
        SliverList(delegate: SliverChildListDelegate(_applySection())),
      ];
    }
    final shown = _shown;
    if (shown.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: HubNotice(
            title: _query.isEmpty ? 'No Institutes Yet' : 'No Institutes Match',
            body: _query.isEmpty
                ? 'Partner institutes will appear here as ICR adds them.'
                : 'Try other words, or clear the search.',
            action: _query.isEmpty ? null : 'Clear Search',
            onAction: _search.clear,
            icon: LucideIcons.handshake,
          ),
        ),
        SliverList(delegate: SliverChildListDelegate(_applySection())),
      ];
    }
    return [
      SliverList(
        delegate: SliverChildListDelegate([
          SectionHeading(title: _query.isEmpty ? 'Learning Partners' : '${shown.length} found'),
          const SizedBox(height: 11.5),
          for (var i = 0; i < shown.length; i += 2) ...[
            if (i > 0) const SizedBox(height: CourseGridRow.rowGap),
            TwoUpRow(
              left: InstituteCard(institute: shown[i], onTap: () => _openInstitute(shown[i])),
              right: i + 1 < shown.length
                  ? InstituteCard(institute: shown[i + 1], onTap: () => _openInstitute(shown[i + 1]))
                  : null,
            ),
          ],
          const SizedBox(height: 16),
          ..._applySection(),
          const SizedBox(height: 24),
        ]),
      ),
    ];
  }
}

/// "Apply to become Partner Institute: [Apply]": the website's directory heading carries it on its right, and its
/// dialog opens with "Partners apply as a company…". A flat white row between hairlines, as the rest of the app.
class _ApplyBanner extends StatelessWidget {
  const _ApplyBanner({required this.onApply});

  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return _BannerRow(
      icon: LucideIcons.handshake,
      title: 'Become an ICR Learning Partner',
      body: 'Partners apply as a company. Select a company you run on ICR, or register a new one.',
      action: OutlinePillButton(
        key: const ValueKey('apply-to-partner'),
        label: 'Apply Now',
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        onPressed: onApply,
      ),
    );
  }
}

/// A banner under the directory: an icon, a title and a line, and optionally one button; white between two
/// hairlines, edge to edge (owner's standing rules: no boxes).
class _BannerRow extends StatelessWidget {
  const _BannerRow({super.key, required this.icon, required this.title, required this.body, this.action});

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border.symmetric(horizontal: BorderSide(color: AppColors.slate200)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: HubText.bannerTitle),
                const SizedBox(height: 2),
                Text(body, style: HubText.bannerBody),
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: 8), action!],
        ],
      ),
    );
  }
}

/// What stands in the place of "Apply" for a member whose company is already a partner or is with ICR, as the
/// website's dashboard card words it: an approved company's console (or how to reach it), or that ICR is reviewing.
/// The website's dialog disables such a company; the app shows the standing instead of a form that would refuse it.
class _StandingBanner extends StatelessWidget {
  const _StandingBanner({required this.company});

  final PartnerStanding company;

  @override
  Widget build(BuildContext context) {
    final partner = company.isPartner;
    final title = partner
        ? '${company.name} Is a Learning Partner'
        : "${company.name}'s Learning Partner Application Is with ICR";
    final body = !partner
        ? 'Our team reviews every application. You can add and publish courses here once it is approved.'
        : company.active
        ? 'Add your courses, modules, materials and batches in the partner console, and publish them when they are ready.'
        : 'Switch to this company in My Companies to add and publish its courses.';
    return _BannerRow(
      key: ValueKey('partner-standing-${company.companyId}'),
      icon: partner ? LucideIcons.badgeCheck : LucideIcons.clock,
      title: title,
      body: body,
      action: partner && company.active
          ? OutlinePillButton(
              key: const ValueKey('open-partner-console'),
              label: 'Open Console',
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              onPressed: () => openSitePage(context, '/admin/learning'),
            )
          : null,
    );
  }
}
