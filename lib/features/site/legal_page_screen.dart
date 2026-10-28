import 'package:flutter/material.dart';

import '../../core/util/links.dart';
import 'legal_page.dart';
import 'site_kit.dart';

/// The website's Privacy Policy and Terms of Service, drawn by the app from the words it bundles
/// (`assets/legal/*.json`): a title, when it was last updated, the introduction, then every numbered section.
class LegalPageScreen extends StatefulWidget {
  const LegalPageScreen({super.key, required this.page, this.onBack, this.load});

  /// `privacy` or `terms`.
  final String page;
  final VoidCallback? onBack;

  /// Where the page comes from; the bundled asset by default (tests).
  final Future<LegalPage> Function(String page)? load;

  @override
  State<LegalPageScreen> createState() => _LegalPageScreenState();
}

class _LegalPageScreenState extends State<LegalPageScreen> {
  late Future<LegalPage> _page = (widget.load ?? loadLegalPage)(widget.page);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LegalPage>(
      future: _page,
      builder: (context, snapshot) {
        final page = snapshot.data;
        final title = page?.title ?? (widget.page == 'terms' ? 'Terms of Service' : 'Privacy Policy');
        return SitePage(
          title: title,
          onBack: widget.onBack,
          child: snapshot.hasError
              ? SiteError(
                  message: "This page couldn't be read.",
                  onRetry: () => setState(() {
                    _page = (widget.load ?? loadLegalPage)(widget.page);
                  }),
                )
              : page == null
              ? const SiteLoading()
              : _Body(page: page),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.page});

  final LegalPage page;

  static const _dot = SizedBox(
    width: 5,
    height: 5,
    child: DecoratedBox(
      decoration: BoxDecoration(color: SiteColors.secondary, shape: BoxShape.circle),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('legal.body'),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        Text(page.title, style: SiteText.title),
        const SizedBox(height: 4),
        Text('Last updated ${page.updated}', style: SiteText.meta),
        const SizedBox(height: 12),
        Text(page.intro, style: SiteText.secondary),
        for (final (i, section) in page.sections.indexed) ...[
          const SizedBox(height: 24),
          Text('${i + 1}. ${section.heading}', style: SiteText.heading),
          const SizedBox(height: 8),
          ..._blocks(section),
          for (final sub in section.subsections) ...[
            const SizedBox(height: 8),
            Text(sub.heading, style: SiteText.subheading),
            const SizedBox(height: 6),
            ..._blocks(sub),
          ],
        ],
        const SizedBox(height: 28),
        const Divider(color: SiteColors.hairline, height: 1),
        const SizedBox(height: 16),
        Text('Questions about this ${page.page == 'terms' ? 'agreement' : 'policy'}?', style: SiteText.strong),
        const SizedBox(height: 4),
        GestureDetector(
          key: const Key('legal.contact'),
          onTap: () => openUrl(context, Uri(scheme: 'mailto', path: page.contactEmail)),
          child: Text(page.contactEmail, style: SiteText.link),
        ),
      ],
    );
  }

  List<Widget> _blocks(LegalBlock b) => [
    for (final p in b.paragraphs)
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(p, style: SiteText.body),
      ),
    for (final bullet in b.bullets)
      Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(padding: EdgeInsets.only(top: 8, right: 10), child: _dot),
            Expanded(child: Text(bullet, style: SiteText.body)),
          ],
        ),
      ),
    if (b.table != null) _Table(table: b.table!),
  ];
}

/// The lawful-basis matrix: two columns, hairline borders, a tinted header, scrolling sideways on a narrow phone.
class _Table extends StatelessWidget {
  const _Table({required this.table});

  final LegalTable table;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const FixedColumnWidth(210),
          border: TableBorder.all(color: SiteColors.hairline),
          children: [
            TableRow(
              decoration: const BoxDecoration(color: SiteColors.blueTint),
              children: [for (final c in table.columns) _cell(c, SiteText.strong)],
            ),
            for (final row in table.rows) TableRow(children: [for (final c in row) _cell(c, SiteText.body)]),
          ],
        ),
      ),
    );
  }

  Widget _cell(String text, TextStyle style) => Padding(
    padding: const EdgeInsets.all(10),
    child: Text(text, style: style),
  );
}
