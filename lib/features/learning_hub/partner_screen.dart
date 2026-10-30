import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/search_field.dart';
import '../../core/widgets/title_bar.dart';
import '../learning/course_sheet.dart';
import '../learning/learning_controller.dart';
import '../learning/learning_models.dart';
import '../learning/widgets/course_card.dart';
import '../../core/widgets/section_heading.dart' show SectionHeading;
import 'hub_controller.dart';
import 'hub_factory.dart';
import 'hub_models.dart';
import 'hub_styles.dart';
import 'widgets/hub_parts.dart';
import 'widgets/institute_card.dart';
import 'widgets/institute_enquiry_sheet.dart';
import '../notifications/notifications_screen.dart';

/// One partner institute: who it is, its courses and programmes as the same
/// cards the ICR Courses grid uses (each opening the course sheet), and "Ask
/// the institute", a message to it sent as the member.
///
/// The website's `/learning/partners/[slug]`. [hub] is what the directory passes
/// so the loaded courses are shared; without it the screen builds its own.
class PartnerScreen extends StatefulWidget {
  const PartnerScreen({super.key, required this.institute, required this.onBack, this.hub});

  final Institute institute;
  final VoidCallback onBack;
  final LearningHubController? hub;

  @override
  State<PartnerScreen> createState() => _PartnerScreenState();
}

class _PartnerScreenState extends State<PartnerScreen> {
  final _search = TextEditingController();
  late final LearningHubController _hub;
  late final bool _ownsHub;
  String _query = '';

  Institute get _institute => widget.institute;

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

  /// The institute's published courses and programmes.
  List<Course> get _courses => [
    for (final c in _hub.learning.courses)
      if (c.provider?.id == _institute.id) c,
  ];

  bool _matches(Course c) =>
      _query.isEmpty ||
      c.title.toLowerCase().contains(_query) ||
      (c.summary?.toLowerCase().contains(_query) ?? false) ||
      c.code.toLowerCase().contains(_query);

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
                      onRefresh: _hub.learning.refresh,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: _Header(institute: _institute, onAsk: _ask),
                          ),
                          SliverList(delegate: SliverChildListDelegate(_courseList(context))),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: TitleBar(
                      title: 'Partner institute',
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

  void _ask() => showInstituteEnquirySheet(context, _hub, _institute);

  List<Widget> _courseList(BuildContext context) {
    final learning = _hub.learning;
    if (learning.loading && learning.courses.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))),
        ),
      ];
    }
    if (learning.error != null && learning.courses.isEmpty) {
      return [
        HubNotice(
          title: "Couldn't load courses",
          body: learning.error!,
          action: 'Try again',
          onAction: learning.refresh,
        ),
      ];
    }
    final all = _courses;
    if (all.isEmpty) {
      return [
        HubNotice(
          title: 'No courses published yet',
          body: '${_institute.name} has not published a course on ICR yet. Ask them what is coming.',
          action: _institute.canEnquire ? 'Ask the institute' : null,
          onAction: _ask,
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 40),
        ),
      ];
    }
    final shown = [
      for (final c in all)
        if (_matches(c)) c,
    ];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
        child: IcrSearchField(controller: _search, hint: 'Search ${_institute.name}...', onSubmitted: (_) {}),
      ),
      if (shown.isEmpty)
        HubNotice(
          title: 'No courses match',
          body: 'Try other words, or clear the search.',
          action: 'Clear search',
          onAction: _search.clear,
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 40),
        )
      else
        for (final kind in CourseKind.values)
          ..._section(context, kind, [
            for (final c in shown)
              if (c.kind == kind) c,
          ]),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _section(BuildContext context, CourseKind kind, List<Course> courses) {
    if (courses.isEmpty) return const [];
    return [
      const SizedBox(height: 12),
      SectionHeading(title: kind.sectionTitle),
      const SizedBox(height: 11.5),
      for (var i = 0; i < courses.length; i += 2) ...[
        if (i > 0) const SizedBox(height: CourseGridRow.rowGap),
        CourseGridRow(
          left: courses[i],
          right: i + 1 < courses.length ? courses[i + 1] : null,
          onOpen: (course) => showCourseSheet(context, course),
        ),
      ],
      const SizedBox(height: 12.5),
    ];
  }
}

/// The institute's identity: its mark, name, whether ICR has verified it, how
/// many courses it has, what it says about itself, and the two things a member
/// can do: ask it a question, or visit its website.
class _Header extends StatelessWidget {
  const _Header({required this.institute, required this.onAsk});

  final Institute institute;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    final website = institute.website;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              InstituteMark(institute: institute, size: 60),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(institute.name, style: HubText.instituteName, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (institute.verified) ...[
                          const Icon(LucideIcons.badgeCheck, size: 13, color: AppColors.successInk),
                          const SizedBox(width: 3),
                          Text(
                            'Verified by ICR',
                            style: HubText.tileNote.copyWith(color: AppColors.successInk, fontWeight: FontWeight.w600),
                          ),
                          Text('  •  ', style: HubText.tileNote),
                        ],
                        Flexible(
                          child: Text(
                            institute.courseCountLabel,
                            style: HubText.tileNote,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (institute.summary != null) ...[
            const SizedBox(height: 10),
            Text(institute.summary!, style: HubText.instituteBody),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (institute.canEnquire)
                Expanded(
                  child: PrimaryButton(
                    key: const ValueKey('ask-the-institute'),
                    label: 'Ask the institute',
                    icon: LucideIcons.messageSquare,
                    height: 44,
                    onPressed: onAsk,
                  ),
                ),
              if (institute.canEnquire && website != null) const SizedBox(width: 10),
              if (website != null)
                OutlinePillButton(
                  key: const ValueKey('institute-website'),
                  label: 'Website',
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  textStyle: HubText.instituteLink.copyWith(color: AppColors.onSurface),
                  onPressed: () => openUrl(context, Uri.parse(website)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
