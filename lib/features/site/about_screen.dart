import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import '../../core/widgets/chips.dart';
import 'site_kit.dart';

/// One module of ICR on the About page's "One Integrated Ecosystem" (the website's `ICR_MODULES`, in its order):
/// the name, its tagline and a line on what it is for, and the page it opens.
class AboutModule {
  const AboutModule(this.label, this.tagline, this.blurb, this.route, this.icon);

  final String label;
  final String tagline;
  final String blurb;
  final String route;
  final IconData icon;
}

/// The website's nine modules, word for word (`packages/shared/src/modules.ts`).
const aboutModules = [
  AboutModule(
    'Mentorship',
    'Connect. Learn. Grow. Lead.',
    'Find the right mentor or mentee and build meaningful professional relationships through knowledge, guidance '
        'and experience sharing.',
    '/mentorship',
    Icons.people_outline,
  ),
  AboutModule(
    'Jobs',
    'Your CRE & FM Career Hub.',
    'Discover exclusive industry-focused opportunities and connect with employers looking for CRE, FM and Workplace '
        'talent.',
    '/jobs',
    Icons.work_outline,
  ),
  AboutModule(
    'Supplier Mart',
    'Connect with Trusted Solutions.',
    'Discover suppliers and solutions, submit requirements and connect with qualified providers — or showcase your '
        'services and generate business leads.',
    '/vendors',
    Icons.storefront_outlined,
  ),
  AboutModule(
    'Community',
    'Ask. Share. Collaborate. Solve.',
    'Exchange ideas, discuss operational challenges and learn from the collective experience of the global CRE & FM '
        'community.',
    '/community',
    Icons.forum_outlined,
  ),
  AboutModule(
    'Documents',
    'Knowledge at Your Fingertips.',
    'Access practical toolkits, templates, research, case studies, standards and professional resources.',
    '/documents',
    Icons.menu_book_outlined,
  ),
  AboutModule(
    'Learning',
    'Assess. Learn. Certify. Grow.',
    'Assess your knowledge, practise with mock exams and flash cards, and earn certifications and courses from ICR '
        'Partner Institutions.',
    '/learning',
    Icons.school_outlined,
  ),
  AboutModule(
    'Chapters & Councils',
    'Connect Locally. Collaborate Globally.',
    'Engage with regional chapters, industry councils and specialist communities to exchange knowledge and build '
        'professional networks.',
    '/chapters',
    Icons.hub_outlined,
  ),
  AboutModule(
    'Events',
    'Learn. Network. Engage.',
    'Discover conferences, webinars, workshops, masterclasses, roundtables and networking opportunities across the '
        'CRE & FM ecosystem.',
    '/events',
    Icons.event_outlined,
  ),
  AboutModule(
    'Get Involved',
    'Be Part of the Movement.',
    'Become a mentor, speaker, trainer, contributor, volunteer, chapter leader or council member and help shape the '
        'profession.',
    '/get-involved',
    Icons.volunteer_activism_outlined,
  ),
];

/// The website's `/about` (`AboutLanding`), drawn by the app in its words: who ICR is, why the profession matters,
/// ICR's role, the nine modules of the ecosystem, and the way in. White, hairlines between sections, the whole width
/// (owner's rules). Saathi's "About ICR" opens it (7 Nov 2026: it opened the website, and Back from it showed
/// `/robots.txt`).
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key, this.onBack, this.signedIn = true, this.onOpenPage});

  final VoidCallback? onBack;

  /// Signed out, the page offers "Join ICR" and "Create your account" as the website does.
  final bool signedIn;

  /// Opens one of the pages the About page points to; the app's own screen for it by default.
  final void Function(BuildContext context, String href)? onOpenPage;

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final _ecosystem = GlobalKey();

  void _open(String href) {
    final open = widget.onOpenPage;
    if (open != null) return open(context, href);
    openSitePage(context, href);
  }

  /// "Explore the ecosystem": the website's `#ecosystem` anchor — the modules, further down this page.
  void _explore() {
    final target = _ecosystem.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 350), alignment: 0.05);
  }

  @override
  Widget build(BuildContext context) {
    return SitePage(
      title: 'About ICR',
      onBack: widget.onBack,
      // One column, built whole (a short page), so "Explore the ecosystem" can scroll to its section.
      child: SingleChildScrollView(
        key: const ValueKey('about-page'),
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Section(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Institute for Corporate Real Estate (ICR)', style: SiteText.title),
                  const SizedBox(height: 8),
                  Text(
                    'Shaping the Future of Corporate Real Estate, Workplace & Facility Management',
                    style: SiteText.secondary,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (!widget.signedIn) ...[
                        Expanded(
                          child: SiteButton(
                            key: const ValueKey('about-join'),
                            label: 'Join ICR',
                            onPressed: () => _open('/register'),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: SiteButton(
                          key: const ValueKey('about-explore'),
                          label: 'Explore the ecosystem',
                          onPressed: _explore,
                          outlined: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const _Stats(),
            const _Section(
              eyebrow: 'Who we are',
              title: 'A global professional association for the built workplace',
              paragraphs: [
                'The Institute for Corporate Real Estate (ICR) is a global professional association dedicated to '
                    'advancing the Corporate Real Estate (CRE), Workplace, Facility Management (FM), and Corporate '
                    'Services professions through education, professional certification, research, standards, '
                    'networking, and thought leadership.',
                'ICR brings together professionals, organizations, academia, technology innovators, service providers, '
                    'and industry leaders to build a stronger, smarter, and more sustainable workplace ecosystem. Our '
                    'purpose is to elevate the profession, empower individuals, and enable organizations to achieve '
                    'operational excellence through world-class workplace and real estate practices.',
              ],
            ),
            _Section(
              eyebrow: 'Why it matters',
              title: 'From cost centre to strategic business function',
              paragraphs: const [
                'As workplaces continue to evolve with digital transformation, hybrid work, sustainability, artificial '
                    'intelligence, employee experience, and changing business priorities, Corporate Real Estate and '
                    'Facility Management have become strategic business functions that directly influence '
                    'organizational performance, business resilience, employee wellbeing, and long-term value creation.',
              ],
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final trend in const [
                    'Digital transformation',
                    'Hybrid work',
                    'Sustainability',
                    'Artificial intelligence',
                    'Employee experience',
                  ])
                    IcrChip(label: trend, tone: ChipTone.outlined, height: 30),
                ],
              ),
            ),
            _Section(
              eyebrow: 'Our role',
              title: 'A trusted platform to learn, connect, collaborate, innovate, and lead',
              paragraphs: const [
                'ICR serves as a trusted platform where professionals can learn, connect, collaborate, innovate, and '
                    'lead. Through globally relevant certifications, continuous professional development, research, '
                    'knowledge sharing, and industry collaboration, we help individuals build successful careers while '
                    'supporting organizations in creating efficient, resilient, and future-ready workplaces.',
              ],
              child: Text('Learn · Connect · Collaborate · Innovate · Lead', style: SiteText.link),
            ),
            _Section(
              key: _ecosystem,
              eyebrow: 'Explore',
              title: 'One Integrated Ecosystem',
              padBottom: false,
              child: Column(
                children: [
                  for (final m in aboutModules)
                    _ModuleRow(key: ValueKey('about-module-${m.route}'), module: m, onTap: () => _open(m.route)),
                ],
              ),
            ),
            _Section(
              title: 'Join the ecosystem',
              paragraphs: const [
                "Whether you buy services, provide them, hire, or build your career — there's a place for you at ICR.",
              ],
              child: Row(
                children: [
                  if (!widget.signedIn) ...[
                    Expanded(
                      child: SiteButton(
                        key: const ValueKey('about-create-account'),
                        label: 'Create your account',
                        onPressed: () => _open('/register'),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: SiteButton(
                      key: const ValueKey('about-talk'),
                      label: 'Talk to us',
                      onPressed: () => _open('/contact'),
                      outlined: !widget.signedIn,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A block of the page: an eyebrow, a heading, its paragraphs and whatever else it holds, a hairline under it.
class _Section extends StatelessWidget {
  const _Section({super.key, this.eyebrow, this.title, this.paragraphs = const [], this.child, this.padBottom = true});

  final String? eyebrow;
  final String? title;
  final List<String> paragraphs;
  final Widget? child;
  final bool padBottom;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 20, 16, padBottom ? 20 : 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: SiteColors.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) ...[
            Text(
              eyebrow!.toUpperCase(),
              style: SiteText.meta.copyWith(letterSpacing: 0.6, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
          ],
          if (title != null) ...[Text(title!, style: SiteText.heading), const SizedBox(height: 10)],
          for (final p in paragraphs) ...[Text(p, style: SiteText.body), const SizedBox(height: 10)],
          ?child,
        ],
      ),
    );
  }
}

/// The website's four figures, two to a row, plain on white.
class _Stats extends StatelessWidget {
  const _Stats();

  static const _figures = [
    ('10,000+', 'businesses on ICR'),
    ('750+', 'service subcategories'),
    ('5-level', 'supplier verification ladder'),
    ('Global', 'chapters & coverage'),
  ];

  @override
  Widget build(BuildContext context) {
    Widget figure((String, String) f) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(f.$1, style: SiteText.title.copyWith(color: AppColors.primary)),
          Text(f.$2, style: SiteText.meta),
        ],
      ),
    );
    return Container(
      key: const ValueKey('about-stats'),
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: SiteColors.hairline)),
      ),
      child: Column(
        children: [
          Row(children: [figure(_figures[0]), figure(_figures[1])]),
          const SizedBox(height: 14),
          Row(children: [figure(_figures[2]), figure(_figures[3])]),
        ],
      ),
    );
  }
}

/// One module: its icon, name and tagline, the line on what it is for, and the arrow to its page.
class _ModuleRow extends StatelessWidget {
  const _ModuleRow({super.key, required this.module, required this.onTap});

  final AboutModule module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(module.icon, size: 24, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(module.label, style: SiteText.strong),
                  Text(module.tagline, style: SiteText.meta),
                  const SizedBox(height: 4),
                  Text(module.blurb, style: SiteText.secondary),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.chevron_right, size: 20, color: AppColors.slate400),
            ),
          ],
        ),
      ),
    );
  }
}
