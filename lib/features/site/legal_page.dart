import 'dart:convert';

import 'package:flutter/services.dart';

/// The words of one of the website's legal pages (`/privacy`, `/terms`), as the app bundles them
/// (`assets/legal/<page>.json`, written from the website's own source by `tool/legal/extract.cjs`).
class LegalTable {
  const LegalTable({required this.columns, required this.rows});

  final List<String> columns;
  final List<List<String>> rows;

  factory LegalTable.fromJson(Map<String, dynamic> json) => LegalTable(
    columns: [for (final c in json['columns'] as List) c as String],
    rows: [
      for (final r in json['rows'] as List) [for (final cell in r as List) cell as String],
    ],
  );
}

/// What a section or a sub-section holds, in the order the website draws it: paragraphs, bullets, a table.
class LegalBlock {
  const LegalBlock({this.paragraphs = const [], this.bullets = const [], this.table});

  final List<String> paragraphs;
  final List<String> bullets;
  final LegalTable? table;
}

class LegalSection extends LegalBlock {
  const LegalSection({
    required this.heading,
    super.paragraphs,
    super.bullets,
    super.table,
    this.subsections = const [],
  });

  final String heading;
  final List<LegalSection> subsections;

  factory LegalSection.fromJson(Map<String, dynamic> json) => LegalSection(
    heading: json['heading'] as String? ?? '',
    paragraphs: [for (final p in (json['paragraphs'] as List? ?? const [])) p as String],
    bullets: [for (final b in (json['bullets'] as List? ?? const [])) b as String],
    table: json['table'] is Map<String, dynamic> ? LegalTable.fromJson(json['table'] as Map<String, dynamic>) : null,
    subsections: [
      for (final s in (json['subsections'] as List? ?? const [])) LegalSection.fromJson(s as Map<String, dynamic>),
    ],
  );
}

class LegalPage {
  const LegalPage({
    required this.page,
    required this.title,
    required this.updated,
    required this.intro,
    required this.contactEmail,
    required this.sections,
  });

  final String page;
  final String title;
  final String updated;
  final String intro;
  final String contactEmail;
  final List<LegalSection> sections;

  factory LegalPage.fromJson(Map<String, dynamic> json) => LegalPage(
    page: json['page'] as String? ?? '',
    title: json['title'] as String? ?? '',
    updated: json['updated'] as String? ?? '',
    intro: json['intro'] as String? ?? '',
    contactEmail: json['contactEmail'] as String? ?? 'info@icr.org.in',
    sections: [
      for (final s in (json['sections'] as List? ?? const [])) LegalSection.fromJson(s as Map<String, dynamic>),
    ],
  );
}

/// The pages the app has: the website's path to its asset name.
const legalPages = {'/privacy': 'privacy', '/terms': 'terms'};

Future<LegalPage> loadLegalPage(String page, {AssetBundle? bundle}) async {
  final text = await (bundle ?? rootBundle).loadString('assets/legal/$page.json');
  return LegalPage.fromJson(jsonDecode(text) as Map<String, dynamic>);
}
