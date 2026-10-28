import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import '../../core/widgets/section_heading.dart';
import '../feed/feed_models.dart';
import '../feed/widgets/home_header.dart';
import 'find_mentors_screen.dart';
import 'mentorship_controller.dart';
import 'mentorship_models.dart';
import 'mentorship_styles.dart';
import 'widgets/category_chips.dart';
import 'widgets/landing_blocks.dart';
import 'widgets/mentor_card.dart';
import 'widgets/notice.dart';

/// The Mentorship tab: the landing from the Mentorship design. Reads its
/// [MentorshipController] from Provider; the mentor cards call [onOpenMentor]
/// (the mentor profile lives in another feature), "View More" and the topic
/// chips open [FindMentorsScreen].
class MentorshipScreen extends StatefulWidget {
  const MentorshipScreen({
    super.key,
    required this.onBack,
    required this.onOpenMentor,
    required this.viewer,
    required this.onAccount,
    this.openSite = openSitePage,
  });

  /// The shell's way back to Home. The tab has no arrow of its own (it wears
  /// the Home header), so nothing in the screen calls it; it is kept so the
  /// tab takes the same constructor as its siblings.
  final VoidCallback onBack;

  /// Opens a mentor's profile.
  final void Function(BuildContext context, String mentorId) onOpenMentor;

  /// The signed-in person, as the header draws them.
  final FeedAuthor viewer;
  final VoidCallback onAccount;

  /// Opens a page of the website: the browser by default, a recorder in tests.
  /// "Apply as Mentor", the cohort's "Know More" and the bell go through it.
  final OpenSite openSite;

  @override
  State<MentorshipScreen> createState() => _MentorshipScreenState();
}

class _MentorshipScreenState extends State<MentorshipScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    final mentorship = context.read<MentorshipController>();
    if (!mentorship.started) mentorship.start();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _find({String? category, String search = '', String? company, bool companyOnAccount = false}) => openFindMentors(
    context,
    category: category,
    search: search,
    company: company,
    companyOnAccount: companyOnAccount,
    onOpenMentor: widget.onOpenMentor,
    openSite: widget.openSite,
  );

  @override
  Widget build(BuildContext context) {
    final mentorship = context.watch<MentorshipController>();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.white),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                top: HomeHeader.height,
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: mentorship.refresh,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: _body(context, mentorship),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: HomeHeader(
                  photo: widget.viewer.photo,
                  initials: widget.viewer.initials,
                  unread: mentorship.unread,
                  searchController: _search,
                  onSearch: (q) {
                    if (q.trim().isNotEmpty) _find(search: q.trim());
                  },
                  onAvatarTap: widget.onAccount,
                  onBellTap: () => widget.openSite(context, '/notifications'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, MentorshipController mentorship) {
    final overview = mentorship.overview;
    if (overview == null) {
      if (mentorship.error != null) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: MentorshipNotice(
              title: "Couldn't load mentors",
              body: mentorship.error!,
              action: 'Try again',
              onAction: mentorship.refresh,
            ),
          ),
        ];
      }
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))),
        ),
      ];
    }
    if (overview.shelves.every((s) => s.mentors.isEmpty) && overview.categories.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: MentorshipNotice(
            title: 'No mentors are listed yet',
            body: 'Be the first to guide the next generation of facility and real estate leaders.',
            action: 'Apply as Mentor',
            onAction: () => widget.openSite(context, '/become-a-mentor'),
          ),
        ),
      ];
    }
    return [SliverToBoxAdapter(child: _content(context, mentorship, overview))];
  }

  Widget _content(BuildContext context, MentorshipController mentorship, MentorshipOverview o) {
    final selected = mentorship.selectedCategory;
    final shelves = o.shelves.where((s) => s.mentors.isNotEmpty).toList();
    void openMentor(Mentor m) => widget.onOpenMentor(context, m.id);

    final pill = o.domainsBadge.isEmpty ? null : DomainsPill(o.domainsBadge, onTap: () => _find(category: selected));
    Widget chips() => CategoryChipRow(
      categories: o.categories,
      selected: selected,
      onSelect: mentorship.selectCategory,
      height: 24,
      fontSize: 13,
      gap: 6,
      padding: 10,
      leftPad: 8.7,
      rightPad: 10.5,
      iconGap: 5,
    );
    Widget lead(String text) => Padding(
      padding: const EdgeInsets.only(left: 16),
      child: SizedBox(height: 18, child: Text(text, style: MentorshipText.lead)),
    );
    Widget shelf(int i, MentorShelf s) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: i == 0 ? 16.3 : 15.3),
        LandingHeading(
          title: s.title,
          right: 27,
          trailing: ViewMore(onTap: () => _find(category: selected)),
        ),
        // The design's first grid hangs 1.3 dp nearer its heading than the second.
        SizedBox(height: i == 0 ? 12.2 : 12.5),
        MentorGrid(mentors: s.mentors, padding: 16, rowGap: 5.4, bottomPad: 8.8, onOpen: openMentor),
        SizedBox(height: i == 0 ? 18.6 : 20.9),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Explore by Companies.
        const SizedBox(height: 8),
        LandingHeading(title: 'Explore by Companies', trailing: pill),
        const SizedBox(height: 10.2),
        if (o.categories.isNotEmpty) chips(),
        if (o.companies.isNotEmpty) ...[
          const SizedBox(height: 19),
          lead('Learn from top leaders at top enterprises'),
          const SizedBox(height: 2.4),
          CompanyTiles(
            companies: o.companies,
            onOpen: (c) => _openCompany(c, category: selected),
          ),
        ],
        const SizedBox(height: 4.7),
        const Hairline(color: AppColors.blockRule),

        if (shelves.isNotEmpty) shelf(0, shelves.first),
        if (shelves.isNotEmpty) const Hairline(color: AppColors.blockRule),

        // Explore by Expertise.
        const SizedBox(height: 13.8),
        LandingHeading(title: 'Explore by Expertise', trailing: pill),
        const SizedBox(height: 10.2),
        if (o.categories.isNotEmpty) chips(),
        if (o.topics.isNotEmpty) ...[
          const SizedBox(height: 26.1),
          lead('Learn from top topics'),
          const SizedBox(height: 4.1),
          TopicGrid(
            topics: o.topics,
            onOpen: (t) => _find(category: t.label),
          ),
        ],
        const SizedBox(height: 21.3),
        const Hairline(color: AppColors.blockRule),

        for (final (i, s) in shelves.indexed.skip(1)) shelf(i, s),
        if (shelves.length < 2) const SizedBox(height: 20.5),

        if (o.banner != null)
          BecomeMentorBanner(
            banner: o.banner!,
            onApply: () => widget.openSite(context, o.banner!.link ?? '/become-a-mentor'),
          ),
        if (o.cohort != null)
          CohortCard(
            cohort: o.cohort!,
            onOpen: () => widget.openSite(context, o.cohort!.link ?? '/mentorship/programmes'),
          ),
        if (o.services.isNotEmpty) ...[
          const SizedBox(height: 8.2),
          const LandingHeading(title: 'Featured Advisory Sessions', left: 15.2),
          const SizedBox(height: 16.5),
          AdvisorySessions(services: o.services, onOpen: (s) => widget.onOpenMentor(context, s.mentorId)),
          const SizedBox(height: 11.7),
        ] else
          const SizedBox(height: 24),
      ],
    );
  }

  /// A company tile narrows the directory to that employer: Find Mentors opens
  /// with a removable "Company: JLL" chip and an empty search box, in the
  /// landing's selected domain (the tiles are counted within it).
  void _openCompany(MentorCompany company, {String? category}) =>
      _find(category: category, company: company.name, companyOnAccount: company.onAccount);
}
