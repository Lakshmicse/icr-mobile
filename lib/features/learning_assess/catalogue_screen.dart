import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/search_field.dart';
import '../../core/widgets/section_heading.dart' show Hairline;
import '../../core/widgets/title_bar.dart';
import '../notifications/notification_scope.dart';
import '../notifications/notifications_screen.dart';
import '../shell/app_shell.dart';
import '../shell/icr_bottom_nav.dart';
import '../shell/shell_page.dart';
import 'api_assess_repository.dart';
import 'assess_format.dart';
import 'assess_models.dart';
import 'assess_repository.dart';
import 'assess_styles.dart';
import 'assess_types.dart';
import 'catalogue_controller.dart';
import 'demo_assess_repository.dart';
import 'group_screen.dart';
import 'widgets/group_card.dart';
import 'widgets/intro_banner.dart';
import 'widgets/states.dart';

/// The repository a door uses when its screen was not given one: the API, or the sample content.
AssessRepository defaultAssessRepository(BuildContext context) =>
    AppConfig.demo ? DemoAssessRepository() : ApiAssessRepository(api: context.read<ApiClient>());

/// One door's landing, shared by Assess Your Knowledge and Mock Exams: a search, the access facet, the door's
/// banner, then the grid of programmes or subjects. A card opens the group's page (its levels or sets).
class CatalogueScreen extends StatelessWidget {
  const CatalogueScreen({
    super.key,
    required this.kind,
    required this.onBack,
    required this.opener,
    this.launcher = openUrl,
    this.payLauncher = openExternal,
    this.repository,
  });

  final PaperKind kind;
  final VoidCallback onBack;
  final PaperOpener opener;
  final SiteLauncher launcher;

  /// Where a payment page goes: the phone's browser (the group pages' Pay buttons use it).
  final SiteLauncher payLauncher;
  final AssessRepository? repository;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CatalogueController>(
      create: (c) => CatalogueController(repository: repository ?? defaultAssessRepository(c), kind: kind),
      child: _CatalogueView(onBack: onBack, opener: opener, launcher: launcher, payLauncher: payLauncher),
    );
  }
}

class _CatalogueView extends StatefulWidget {
  const _CatalogueView({
    required this.onBack,
    required this.opener,
    required this.launcher,
    required this.payLauncher,
  });

  final VoidCallback onBack;
  final PaperOpener opener;
  final SiteLauncher launcher;
  final SiteLauncher payLauncher;

  @override
  State<_CatalogueView> createState() => _CatalogueViewState();
}

class _CatalogueViewState extends State<_CatalogueView> with WidgetsBindingObserver {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final catalogue = context.read<CatalogueController>();
    if (!catalogue.started) catalogue.start();
    // The grid narrows as the person types; the keyboard's search key and the clear button reach the same place.
    _search.addListener(() {
      if (mounted) context.read<CatalogueController>().setSearch(_search.text);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _search.dispose();
    super.dispose();
  }

  /// Back in front (a payment was made on the website): what the member holds is read again, so the grid's
  /// "open / locked" lines are the day's, not the moment's the person left.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) context.read<CatalogueController>().refreshMember();
  }

  void _openGroup(PaperGroup group) {
    final catalogue = context.read<CatalogueController>();
    // The pushed route sits above this screen's providers: the bell's count and router go with it.
    final scope = NotificationScope.of(context);
    AppShell.push<void>(
      context,
      (c) => scope.wrap(
        ShellPage(
          tab: AppTab.learning,
          child: ChangeNotifierProvider<CatalogueController>.value(
            value: catalogue,
            child: GroupScreen(
              seed: group,
              onBack: () => Navigator.of(c).pop(),
              opener: widget.opener,
              launcher: widget.launcher,
              payLauncher: widget.payLauncher,
            ),
          ),
        ),
      ),
    );
  }

  void _resetFilters() {
    _search.clear();
    context.read<CatalogueController>().reset();
  }

  @override
  Widget build(BuildContext context) {
    final catalogue = context.watch<CatalogueController>();
    final isMock = catalogue.kind == PaperKind.mock;
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
                  onRefresh: catalogue.refresh,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _Toolbar(search: _search, isMock: isMock),
                      ),
                      SliverToBoxAdapter(child: _banner(isMock)),
                      ..._body(catalogue, isMock),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: TitleBar(
                  title: isMock ? 'Mock Exams' : 'Assess Your Knowledge',
                  onBack: widget.onBack,
                  unread: catalogue.unread,
                  onBell: () => openNotifications(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _banner(bool isMock) => isMock
      ? const IntroBanner(
          eyebrow: 'Global Certification Mock Exams',
          headline: 'Practice · Prepare · Perform',
          body:
              'Experience full-length, exam-style mock papers that help you assess your readiness, identify '
              'knowledge gaps and build confidence before your professional certification exam.',
          steps: ['Assess', 'Improve', 'Practice'],
        )
      : const IntroBanner(
          eyebrow: 'Assess Your Knowledge.',
          headline: 'Validate Your Expertise.',
          body:
              'Test your competency across CRE & FM knowledge areas through ICR Knowledge Area Assessments. '
              'Choose your level, take the assessment, and earn an ICR Certificate upon successful completion.',
          steps: ['Foundation', 'Professional', 'Advanced'],
        );

  List<Widget> _body(CatalogueController catalogue, bool isMock) {
    final noun = isMock ? 'subjects' : 'certifications';
    if (catalogue.loading && catalogue.groups.isEmpty) {
      return const [SliverToBoxAdapter(child: GridSkeleton())];
    }
    if (catalogue.error != null && catalogue.groups.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: AssessNotice(
            title: isMock ? "Couldn't load the mock exams" : "Couldn't load the assessments",
            body: catalogue.error!,
            action: 'Try again',
            onAction: catalogue.refresh,
          ),
        ),
      ];
    }
    if (catalogue.groups.isEmpty) {
      final partnerOnly = !isMock && catalogue.hasPartner;
      return [
        SliverToBoxAdapter(
          child: AssessNotice(
            title: isMock ? 'No subjects are published yet' : 'No assessments are published yet',
            body: isMock
                ? 'Subjects show up here as ICR publishes their sets.'
                : partnerOnly
                ? 'ICR has no assessment of its own published yet. The certifications available to sit are awarded '
                      'by partner institutes and listed under Professional Development.'
                : 'Programmes show up here as ICR publishes an assessment for each of their levels.',
            action: partnerOnly ? 'Partner certifications' : null,
            onAction: partnerOnly
                ? () => widget.launcher(context, context.read<CatalogueController>().repository.partnerLink())
                : null,
          ),
        ),
      ];
    }
    final visible = catalogue.visible;
    if (visible.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: AssessNotice(
            title: isMock ? 'No subject matches' : 'No certification matches',
            body: 'Try other words, or clear the search and the filter.',
            action: 'Reset filters',
            onAction: _resetFilters,
          ),
        ),
      ];
    }
    final rows = (visible.length + 1) ~/ 2;
    Widget card(PaperGroup g) => GroupCard(group: g, summary: catalogue.summaryOf(g), onTap: () => _openGroup(g));
    return [
      SliverList.builder(
        itemCount: rows,
        itemBuilder: (context, i) => Padding(
          padding: EdgeInsets.only(bottom: i == rows - 1 ? 0 : GroupGridRow.rowGap),
          child: GroupGridRow(
            key: ValueKey('row-$i'),
            left: card(visible[i * 2]),
            right: i * 2 + 1 < visible.length ? card(visible[i * 2 + 1]) : null,
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (catalogue.narrowed)
                Text(
                  showingLine(visible.length, catalogue.groups.length, noun),
                  key: const ValueKey('showing'),
                  style: AssessText.sectionHint,
                ),
              if (!isMock && catalogue.hasPartner) ...[
                const SizedBox(height: 10),
                Text(
                  'Looking for a partner institute’s certification? Those are listed under Professional '
                  'Development, and are sat and issued through ICR just the same.',
                  style: AssessText.sectionHint,
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () => widget.launcher(context, catalogue.repository.partnerLink()),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Row(
                      children: [
                        Text('Partner certifications', style: AssessText.noteLink),
                        const SizedBox(width: 6),
                        const Icon(LucideIcons.externalLink, size: 14, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    ];
  }
}

/// Under the title bar: the search, then the access facet.
class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.search, required this.isMock});

  final TextEditingController search;
  final bool isMock;

  @override
  Widget build(BuildContext context) {
    final catalogue = context.watch<CatalogueController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: IcrSearchField(
            controller: search,
            height: 40,
            hint: isMock ? 'Search mock exams, e.g. energy, set 3' : 'Search certifications, e.g. contract',
            onSubmitted: catalogue.setSearch,
          ),
        ),
        // The chips are 36 dp; the touch target around each is 48.
        ChipRow(
          height: 48,
          children: [
            for (final f in AccessFilter.values)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => catalogue.setFilter(f),
                child: Center(
                  child: IcrChip(
                    label: f.label,
                    height: 36,
                    tone: catalogue.filter == f ? ChipTone.primary : ChipTone.outlined,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    textStyle: AssessText.progressTitle,
                    onTap: () => catalogue.setFilter(f),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        const Hairline(color: AppColors.blockRule),
      ],
    );
  }
}
