import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/search_field.dart';
import '../../core/widgets/section_heading.dart';
import '../../core/widgets/title_bar.dart';
import '../learning/learning_controller.dart';
import '../learning/widgets/course_card.dart';
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
                    top: TitleBar.height,
                    child: RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _hub.reloadInstitutes,
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
                      title: 'Partner Courses',
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
        SliverFillRemaining(
          hasScrollBody: false,
          child: HubNotice(
            title: "Couldn't load institutes",
            body: error,
            action: 'Try again',
            onAction: _hub.reloadInstitutes,
            icon: LucideIcons.handshake,
          ),
        ),
      ];
    }
    final shown = _shown;
    if (shown.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: HubNotice(
            title: _query.isEmpty ? 'No institutes yet' : 'No institutes match',
            body: _query.isEmpty
                ? 'Partner institutes show up here as ICR takes them on.'
                : 'Try other words, or clear the search.',
            action: _query.isEmpty ? null : 'Clear search',
            onAction: _search.clear,
            icon: LucideIcons.handshake,
          ),
        ),
      ];
    }
    return [
      SliverList(
        delegate: SliverChildListDelegate([
          SectionHeading(title: _query.isEmpty ? 'Partner institutes' : '${shown.length} found'),
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
          const _ApplyBanner(),
          const SizedBox(height: 24),
        ]),
      ),
    ];
  }
}

/// "Run a training institute?": the website's partner application is the way in
/// for an institute that wants to be listed, so the banner opens it.
class _ApplyBanner extends StatelessWidget {
  const _ApplyBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: CourseGridRow.padding,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(color: AppColors.chipEmphasis, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            const Icon(LucideIcons.handshake, size: 22, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Run a training institute?', style: HubText.bannerTitle),
                  const SizedBox(height: 2),
                  Text('Apply to deliver your certifications through ICR.', style: HubText.bannerBody),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinePillButton(
              key: const ValueKey('apply-to-partner'),
              label: 'Apply',
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              onPressed: () => openSitePage(context, '/learning/partners/apply'),
            ),
          ],
        ),
      ),
    );
  }
}
