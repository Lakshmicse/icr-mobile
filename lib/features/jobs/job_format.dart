import 'job_models.dart';

/// "₹18L - ₹25L / yr", as the design writes a salary; null when hidden.
String? salaryLabel(Job job) {
  if (!job.salaryVisible) return null;
  final values = [?job.salaryMin, ?job.salaryMax].where((v) => v > 0).toList();
  if (values.isEmpty) return null;
  final period = switch (job.salaryPeriod) {
    'MONTHLY' => '/ mo',
    'HOURLY' => '/ hr',
    _ => '/ yr',
  };
  return '${values.map(_short).join(' - ')} $period';
}

String _short(double n) {
  String trim(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  if (n >= 1e7) return '₹${trim(n / 1e7)}Cr';
  if (n >= 1e5) return '₹${trim(n / 1e5)}L';
  if (n >= 1e3) return '₹${trim(n / 1e3)}K';
  return '₹${n.round()}';
}

/// "Posted 3d ago", as the website's board.
String? postedAgo(DateTime? at, [DateTime? now]) {
  if (at == null) return null;
  final days = (now ?? DateTime.now()).difference(at).inDays;
  if (days <= 0) return 'Posted today';
  if (days == 1) return 'Posted yesterday';
  if (days < 30) return 'Posted ${days}d ago';
  return 'Posted ${days ~/ 30}mo ago';
}

/// The count after "Posted 3d ago": "142 applicants" or "310 views" when the
/// API tells (only the job's own team gets either), else "2 openings".
String? applicantsOrOpenings(Job job) {
  if (job.applicants != null) return '${job.applicants} applicant${job.applicants == 1 ? '' : 's'}';
  if (job.views != null) return '${job.views} view${job.views == 1 ? '' : 's'}';
  if (job.openings != null && job.openings! > 0) return '${job.openings} opening${job.openings == 1 ? '' : 's'}';
  return null;
}

/// "8+ years" / "3–7 years" for a requirement line.
String? experienceLabel(Job job) {
  final min = job.experienceMin;
  final max = job.experienceMax;
  if (min == null && max == null) return null;
  if (min != null && max != null && max > min) return '$min–$max years';
  if (min != null && min > 0) return '$min+ years';
  if (max != null) return 'Up to $max years';
  return null;
}

/// "8,400+ employees" from the API's size bucket.
String? companySizeLabel(String? size) => switch (size) {
  null || '' => null,
  '500+' => '500+ employees',
  _ => '$size employees',
};

/// A company type as the design words it ("Real Estate").
String? companyKindLabel(String? type) => switch (type) {
  'CORPORATE' => 'Corporate Occupier',
  'FACILITY_MANAGEMENT' => 'Facility Management',
  'SUPPLIER' => 'Supplier',
  'CONSULTANT' => 'Consultancy',
  'REAL_ESTATE' => 'Real Estate',
  'TRAINING_INSTITUTE' => 'Training Institute',
  _ => null,
};

/// A company's industry (`Company.industry`, a `JOB_INDUSTRIES` key) as the
/// design words a tagline: "Commercial Real Estate Services".
String? companyIndustryLabel(String? key) => switch (key) {
  'CRE_SERVICES' => 'Commercial Real Estate Services',
  'FM_SERVICES' => 'Facility Management Services',
  'CORPORATE_OCCUPIER' => 'Corporate Occupier',
  'DEVELOPER' => 'Developer & Builder',
  'REIT_INVESTOR' => 'REIT & Investor',
  'COWORKING' => 'Coworking & Flexible Space',
  'RETAIL_MALL' => 'Retail & Malls',
  'HOSPITALITY' => 'Hospitality',
  'HEALTHCARE' => 'Healthcare',
  'DATA_CENTRE' => 'Data Centres',
  'MANUFACTURING' => 'Manufacturing & Industrial',
  'LOGISTICS' => 'Logistics & Warehousing',
  'EDUCATION' => 'Education',
  'BFSI' => 'Banking & Financial Services',
  'TECHNOLOGY' => 'Technology',
  'PUBLIC_SECTOR' => 'Government & Public Sector',
  _ => null,
};

/// The first sentence of a company's description, when it is short enough to
/// stand as a tagline under the name (one line of the sheet's header).
String? shortFirstSentence(String? text, {int maxChars = 56}) {
  final plain = text?.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (plain == null || plain.isEmpty) return null;
  final end = RegExp(r'[.!?](\s|$)').firstMatch(plain)?.start;
  final sentence = (end == null ? plain : plain.substring(0, end)).trim();
  return sentence.isEmpty || sentence.length > maxChars ? null : sentence;
}

/// Numbers with thousands separators: 8400 → "8,400".
String groupThousands(int n) => n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

/// A job description's HTML, as blocks the sheet can draw: paragraphs,
/// headings and list items.
class DescriptionBlock {
  const DescriptionBlock.paragraph(this.text) : kind = BlockKind.paragraph;
  const DescriptionBlock.heading(this.text) : kind = BlockKind.heading;
  const DescriptionBlock.item(this.text) : kind = BlockKind.item;

  final BlockKind kind;
  final String text;
}

enum BlockKind { paragraph, heading, item }

List<DescriptionBlock> descriptionBlocks(String? html) {
  if (html == null || html.trim().isEmpty) return const [];
  final blocks = <DescriptionBlock>[];
  final tag = RegExp(r'<(/?)(p|li|h[1-6]|div|br|ul|ol)\b[^>]*>', caseSensitive: false);
  var buffer = StringBuffer();
  var kind = BlockKind.paragraph;
  void flush() {
    final text = _plain(buffer.toString());
    if (text.isNotEmpty) {
      blocks.add(switch (kind) {
        BlockKind.heading => DescriptionBlock.heading(text),
        BlockKind.item => DescriptionBlock.item(text),
        BlockKind.paragraph => DescriptionBlock.paragraph(text),
      });
    }
    buffer = StringBuffer();
  }

  var last = 0;
  for (final m in tag.allMatches(html)) {
    buffer.write(html.substring(last, m.start));
    last = m.end;
    final closing = m[1] == '/';
    final name = m[2]!.toLowerCase();
    if (name == 'br') {
      buffer.write('\n');
      continue;
    }
    if (name == 'ul' || name == 'ol') {
      flush();
      kind = BlockKind.paragraph;
      continue;
    }
    flush();
    if (closing) {
      kind = BlockKind.paragraph;
    } else {
      kind = name == 'li' ? BlockKind.item : (name.startsWith('h') ? BlockKind.heading : BlockKind.paragraph);
    }
  }
  buffer.write(html.substring(last));
  flush();
  // A plain-text description with blank lines between paragraphs.
  if (blocks.length == 1 && blocks.single.kind == BlockKind.paragraph && blocks.single.text.contains('\n\n')) {
    return blocks.single.text.split(RegExp(r'\n{2,}')).map((p) => DescriptionBlock.paragraph(p.trim())).toList();
  }
  return blocks;
}

String _plain(String html) => html
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll(RegExp(r'[ \t]+'), ' ')
    .replaceAll(RegExp(r' *\n *'), '\n')
    .trim();
