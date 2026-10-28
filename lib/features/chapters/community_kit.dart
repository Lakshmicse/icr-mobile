/// The pieces the association and community screens share (Chapters, the
/// Digital Library, Get Involved, Network and Contact): none of them has a
/// design, so each is drawn in the Councils and Events designs' language, and
/// these are those designs' patterns copied once (the Councils card border and
/// radius, its search box, stat tiles, pills, section headings and notices).
///
/// They live here, in the chapters folder, because the five screens are one
/// builder's; the councils and events folders are left untouched.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/title_bar.dart';
import '../feed/feed_models.dart' show FeedPicture;

export '../feed/feed_models.dart' show FeedPicture;

/// Colours sampled from the Councils and Events designs.
class CommunityColors {
  CommunityColors._();

  /// Card and field borders (Councils' card border).
  static const border = Color(0xFFE2E8F0);

  /// The grey stat tiles and soft fills.
  static const tile = Color(0xFFF8FAFC);
  static const tileRule = Color(0xFFE9EDF2);
  static const greyPill = Color(0xFFF1F5F9);

  static const green50 = Color(0xFFECFDF5);
  static const green100 = Color(0xFFD1FAE5);
  static const green200 = Color(0xFFA7F3D0);
  static const green700 = Color(0xFF047857);
  static const green900 = Color(0xFF064E3B);
  static const blue50 = Color(0xFFEFF6FF);
  static const blue700 = Color(0xFF1D4ED8);
  static const amber50 = Color(0xFFFFF7E6);
  static const amber700 = Color(0xFFB45309);
  static const red50 = Color(0xFFFEF2F2);
  static const red600 = Color(0xFFDC2626);
  static const slate800 = Color(0xFF1E293B);

  /// The hashtag pills.
  static const tagFill = Color(0xFFE8F1FA);

  /// Councils' "Join Council": a deeper blue than the primary.
  static const action = Color(0xFF004B83);

  /// Events' link navy (Manage & View, Overview, View Network).
  static const link = Color(0xFF0B4272);

  /// The In-Person Summits footer and the meetup card.
  static const navy = Color(0xFF144174);
  static const navyDeep = Color(0xFF0B2138);
  static const navyTile = Color(0xFF1E4A7B);
  static const navyTileBorder = Color(0xFF2C5A8C);
  static const navyCopy = Color(0xFFC3D0DF);

  /// Events' host card ("Host or Propose an Event").
  static const hostFill = AppColors.chipEmphasis;

  /// Over a cover photo.
  static const coverScrimTop = Color(0x1A0B1329);
  static const coverScrimBottom = Color(0x660B1329);
}

/// Type for the community screens, at the Councils and Events designs' sizes.
class CommunityText {
  CommunityText._();

  // Stat tiles.
  static final statLabel = AppText.plexSans(8, FontWeight.w500, AppColors.slate500, lineHeight: 11);
  static final statValue = AppText.workSans(14, FontWeight.w700, AppColors.slate900, lineHeight: 18);
  static final statValueBlue = AppText.workSans(14, FontWeight.w700, AppColors.primary, lineHeight: 18);
  static final statNote = AppText.plexSans(8.5, FontWeight.w600, AppColors.slate500, lineHeight: 11);

  // Section headings.
  static final sectionTitle = AppText.workSans(12, FontWeight.w700, AppColors.slate900, lineHeight: 16);
  static final sectionPill = AppText.plexSans(10.5, FontWeight.w600, AppColors.slate700, lineHeight: 14);
  static final sectionLink = AppText.plexSans(10.5, FontWeight.w700, AppColors.primary, lineHeight: 14);
  static final sectionCaption = AppText.plexSans(10.5, FontWeight.w500, AppColors.slate400, lineHeight: 14);
  static final sectionSubtitle = AppText.plexSans(10, FontWeight.w400, AppColors.slate500, lineHeight: 14);
  static final kicker = AppText.plexSans(9.5, FontWeight.w700, AppColors.success, lineHeight: 13, spacing: 0.8);

  // Search and chips.
  static final searchHint = AppText.plexSans(10.5, FontWeight.w600, AppColors.slate500, lineHeight: 14);
  static final searchInput = AppText.plexSans(10.5, FontWeight.w500, AppColors.onSurface, lineHeight: 14);
  static final chip = AppText.plexSans(11.5, FontWeight.w600, AppColors.slate700, lineHeight: 14);

  // Cards.
  static final cardTitle = AppText.workSans(12, FontWeight.w700, AppColors.slate900, lineHeight: 16);
  static final cardTitleLarge = AppText.workSans(15, FontWeight.w700, AppColors.slate900, lineHeight: 20);
  static final cardCopy = AppText.plexSans(12, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 15.5);
  static final body = AppText.plexSans(10.5, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 16);
  static final meta = AppText.plexSans(8.5, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 12);
  static final metaGreen = AppText.plexSans(8.5, FontWeight.w600, AppColors.tertiary, lineHeight: 12);
  static final metaStrong = AppText.plexSans(10, FontWeight.w700, AppColors.slate900, lineHeight: 13);
  static final pill = AppText.plexSans(8, FontWeight.w700, Colors.white, lineHeight: 10, spacing: 0.4);
  static final tag = AppText.plexSans(9.3, FontWeight.w700, AppColors.primary, lineHeight: 11);
  static final small = AppText.plexSans(9.5, FontWeight.w500, AppColors.slate500, lineHeight: 13);
  static final link = AppText.plexSans(10.5, FontWeight.w700, AppColors.primary, lineHeight: 14);

  // Buttons.
  static final buttonPrimary = AppText.plexSans(10, FontWeight.w700, Colors.white, lineHeight: 13);
  static final buttonOutline = AppText.plexSans(10, FontWeight.w700, AppColors.primary, lineHeight: 13);
  static final buttonQuiet = AppText.plexSans(10, FontWeight.w600, AppColors.slate500, lineHeight: 13);

  // People rows.
  static final personName = AppText.workSans(12, FontWeight.w700, AppColors.slate900, lineHeight: 16);
  static final personLine = AppText.plexSans(10, FontWeight.w500, AppColors.slate500, lineHeight: 13);
  static final personRole = AppText.plexSans(10, FontWeight.w600, AppColors.primary, lineHeight: 13);
  static final initials = AppText.plexSans(11, FontWeight.w700, Colors.white, lineHeight: 13);

  // Navy cards.
  static final navyTitle = AppText.workSans(13, FontWeight.w700, Colors.white, lineHeight: 17);
  static final navyCopy = AppText.plexSans(10, FontWeight.w400, CommunityColors.navyCopy, lineHeight: 15);

  // Forms.
  static final fieldLabel = AppText.plexSans(10.5, FontWeight.w700, AppColors.slate700, lineHeight: 14);
  static final fieldInput = AppText.plexSans(12, FontWeight.w500, AppColors.onSurface, lineHeight: 17);
  static final fieldHint = AppText.plexSans(12, FontWeight.w400, AppColors.slate400, lineHeight: 17);
  static final fieldHelp = AppText.plexSans(9.5, FontWeight.w400, AppColors.slate500, lineHeight: 13);
  static final fieldError = AppText.plexSans(9.5, FontWeight.w500, AppColors.error, lineHeight: 13);

  // Sheets.
  static final sheetTitle = AppText.workSans(14, FontWeight.w700, AppColors.slate900, lineHeight: 20);
  static final sheetRow = AppText.plexSans(13, FontWeight.w400, AppColors.onSurface, lineHeight: 18);
  static final sheetLabel = AppText.plexSans(11, FontWeight.w600, AppColors.onSurface, lineHeight: 16);
}

// ---------------------------------------------------------------------------
// Words and numbers
// ---------------------------------------------------------------------------

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// India Standard Time, which every date on these screens is read in (the
/// Councils and Events screens do the same).
const istOffset = Duration(hours: 5, minutes: 30);

DateTime inIst(DateTime t) => t.toUtc().add(istOffset);

/// "Apr 18".
String monthDay(DateTime t) {
  final d = inIst(t);
  return '${_months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}';
}

/// "APR".
String monthCaps(DateTime t) => _months[inIst(t).month - 1].toUpperCase();

/// "18".
String dayOfMonth(DateTime t) => inIst(t).day.toString().padLeft(2, '0');

/// "23 Oct 2026".
String fullDate(DateTime t) {
  final d = inIst(t);
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// "15:30".
String clock(DateTime t) {
  final d = inIst(t);
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// "Sat, Nov 01 · 11:00 IST".
String eventWhen(DateTime start) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final d = inIst(start);
  return '${days[d.weekday - 1]}, ${monthDay(start)} · ${clock(start)} IST';
}

/// 2530 → "2,530".
String groupThousands(int n) => n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

/// "1 member" / "9 members".
String plural(int n, String one, [String? many]) => '${groupThousands(n)} ${n == 1 ? one : (many ?? '${one}s')}';

/// 2457600 → "2.3 MB", 48000 → "47 KB", 900 → "900 B".
String fileSizeLabel(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  final mb = bytes / (1024 * 1024);
  return '${mb >= 10 ? mb.round() : mb.toStringAsFixed(1)} MB';
}

/// The two letters a person's circle shows.
String initialsOf(String first, [String last = '']) {
  final both = '${first.trim().isEmpty ? '' : first.trim()[0]}${last.trim().isEmpty ? '' : last.trim()[0]}';
  return both.isEmpty ? '?' : both.toUpperCase();
}

/// The text of an HTML fragment as paragraphs and bullet points, for the
/// "About" sections the API writes in HTML (`aboutHtml`). Headings become
/// paragraphs of their own; list items keep a bullet.
List<String> htmlParagraphs(String? html) {
  if (html == null || html.trim().isEmpty) return const [];
  var s = html
      .replaceAll(RegExp(r'<\s*li[^>]*>', caseSensitive: false), '\n• ')
      .replaceAll(RegExp(r'<\s*br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</\s*(p|h[1-6]|li|ul|ol|div)\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '');
  s = s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&rsquo;', '’')
      .replaceAll('&mdash;', '—');
  return s.split('\n').map((l) => l.replaceAll(RegExp(r'\s+'), ' ').trim()).where((l) => l.isNotEmpty).toList();
}

/// One block of a rich "About" text.
enum AboutKind { heading, paragraph, bullet }

class AboutBlock {
  const AboutBlock(this.kind, this.text);

  final AboutKind kind;
  final String text;

  @override
  bool operator ==(Object other) => other is AboutBlock && other.kind == kind && other.text == text;

  @override
  int get hashCode => Object.hash(kind, text);

  @override
  String toString() => '${kind.name}: $text';
}

/// The headings, paragraphs and bullet points of an HTML fragment, in order
/// (`aboutHtml`). Anything else (a stray `<div>`) falls back to a paragraph of
/// its text, so a fragment the website would show is never dropped.
List<AboutBlock> htmlBlocks(String? html) {
  if (html == null || html.trim().isEmpty) return const [];
  final blocks = <AboutBlock>[];
  final tag = RegExp(r'<\s*(h[1-6]|p|li)\b[^>]*>(.*?)<\s*/\s*\1\s*>', caseSensitive: false, dotAll: true);
  var found = false;
  for (final m in tag.allMatches(html)) {
    found = true;
    final name = m.group(1)!.toLowerCase();
    final text = _decode(m.group(2)!);
    if (text.isEmpty) continue;
    final kind = name.startsWith('h') ? AboutKind.heading : (name == 'li' ? AboutKind.bullet : AboutKind.paragraph);
    blocks.add(AboutBlock(kind, text));
  }
  if (!found) {
    for (final line in htmlParagraphs(html)) {
      blocks.add(
        line.startsWith('• ') ? AboutBlock(AboutKind.bullet, line.substring(2)) : AboutBlock(AboutKind.paragraph, line),
      );
    }
  }
  return blocks;
}

String _decode(String html) => html
    .replaceAll(RegExp(r'<\s*br\s*/?>', caseSensitive: false), ' ')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&rsquo;', '’')
    .replaceAll('&mdash;', '—')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

// ---------------------------------------------------------------------------
// The screen frame
// ---------------------------------------------------------------------------

/// The Councils screen's frame: a white page, the 56 dp [TitleBar] pinned at
/// the top, and the body as one pull-to-refresh list under it.
class CommunityPage extends StatelessWidget {
  const CommunityPage({
    super.key,
    required this.title,
    required this.onBack,
    required this.onBell,
    required this.onRefresh,
    required this.children,
    this.unread = 0,
    this.controller,
    this.bottomBar,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onBell;
  final Future<void> Function() onRefresh;
  final List<Widget> children;
  final int unread;
  final ScrollController? controller;

  /// Pinned under the list (a form's send button).
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.white),
      child: Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: bottomBar,
        body: SafeArea(
          bottom: bottomBar == null ? false : true,
          child: Stack(
            children: [
              Positioned.fill(
                top: TitleBar.height,
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: onRefresh,
                  child: ListView(
                    controller: controller,
                    padding: EdgeInsets.zero,
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: children,
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: TitleBar(title: title, onBack: onBack, unread: unread, onBell: onBell),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The spinner a list shows while it loads for the first time.
class CommunityLoading extends StatelessWidget {
  const CommunityLoading({super.key, this.height = 400});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))),
    );
  }
}

/// The empty and error states, as the Councils screen draws them: a glyph, a
/// title, a sentence and, when there is something to do, an outlined button.
class CommunityNotice extends StatelessWidget {
  const CommunityNotice({
    super.key,
    required this.title,
    required this.body,
    this.icon = LucideIcons.inbox,
    this.action,
    this.onAction,
    this.secondary,
    this.onSecondary,
    this.padding = const EdgeInsets.fromLTRB(32, 40, 32, 40),
  });

  final String title;
  final String body;
  final IconData icon;
  final String? action;
  final VoidCallback? onAction;
  final String? secondary;
  final VoidCallback? onSecondary;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 34, color: AppColors.outline),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: AppText.postTitle.copyWith(fontSize: 16, height: 1.3)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: AppText.small),
          if (action != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.outlineVariant),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(action!, style: AppText.link),
            ),
          ],
          if (secondary != null) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: onSecondary,
              child: Text(secondary!, style: AppText.link),
            ),
          ],
        ],
      ),
    );
  }
}

/// A white card with the Councils design's 1 dp border and 10 dp corners.
class CommunityCard extends StatelessWidget {
  const CommunityCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.onTap,
    this.color = Colors.white,
    this.borderColor = CommunityColors.border,
    this.radius = 10,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color color;
  final Color borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor),
    );
    return Material(
      color: color,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A small stadium pill with a word in it (the Councils design's pills).
class CommunityPill extends StatelessWidget {
  const CommunityPill({
    super.key,
    required this.label,
    required this.fill,
    required this.style,
    this.icon,
    this.dot,
    this.height = 17,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
    this.border,
  });

  final String label;
  final Color fill;
  final TextStyle style;
  final IconData? icon;
  final Color? dot;
  final double height;
  final EdgeInsets padding;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(height / 2),
        border: border == null ? null : Border.all(color: border!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
          ],
          if (icon != null) ...[Icon(icon, size: 10, color: style.color), const SizedBox(width: 4)],
          Flexible(
            child: Text(label, style: style, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

/// A person's photo in a circle, or their initials on a tinted disc.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.initials, this.photo, this.size = 36, this.color});

  final String initials;
  final FeedPicture? photo;
  final double size;

  /// The disc behind the initials; the primary blue by default.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color ?? AppColors.primary, shape: BoxShape.circle),
      child: Text(initials, style: CommunityText.initials.copyWith(fontSize: size * 0.33)),
    );
    final p = photo;
    if (p == null) return fallback;
    final image = p.asset != null
        ? Image.asset(p.asset!, width: size, height: size, fit: BoxFit.cover)
        : CachedNetworkImage(
            imageUrl: p.url!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => fallback,
            placeholder: (_, _) => fallback,
          );
    return ClipOval(
      child: SizedBox(width: size, height: size, child: image),
    );
  }
}

/// The Councils design's search box: 32 dp, a stadium with a light border, the
/// glyph, the hint, and the sliders glyph that opens the sort and filters.
class CommunitySearchField extends StatelessWidget {
  const CommunitySearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.hint,
    this.onFilters,
    this.filtersLabel = 'Sort and filter',
    this.filtersActive = false,
    this.submitOnly = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;
  final VoidCallback? onFilters;
  final String filtersLabel;

  /// A dot on the sliders glyph while a filter is on.
  final bool filtersActive;

  /// Report only on submit (and on clear), for a search the API runs.
  final bool submitOnly;

  static const height = 32.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: CommunityColors.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 13),
          const Icon(LucideIcons.search, size: 15, color: AppColors.slate400),
          const SizedBox(width: 9),
          Expanded(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => TextField(
                controller: controller,
                style: CommunityText.searchInput,
                textAlignVertical: TextAlignVertical.center,
                textInputAction: TextInputAction.search,
                onChanged: submitOnly ? null : onChanged,
                onSubmitted: onChanged,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: CommunityText.searchHint,
                  hintMaxLines: 1,
                  suffixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  suffixIcon: value.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          padding: EdgeInsets.zero,
                          iconSize: 14,
                          onPressed: () {
                            controller.clear();
                            onChanged('');
                          },
                          icon: const Icon(LucideIcons.x, color: AppColors.outline),
                        ),
                ),
              ),
            ),
          ),
          if (onFilters != null)
            Semantics(
              button: true,
              label: filtersLabel,
              child: InkResponse(
                onTap: onFilters,
                radius: 18,
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        LucideIcons.slidersHorizontal,
                        size: 14,
                        color: filtersActive ? AppColors.primary : AppColors.slate400,
                      ),
                      if (filtersActive)
                        Positioned(
                          right: 5,
                          top: 6,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(width: 2),
        ],
      ),
    );
  }
}

/// The Councils design's grey stat tile: a small label over a bold figure,
/// 56 dp tall; two to a row.
class CommunityStatTile extends StatelessWidget {
  const CommunityStatTile({
    super.key,
    required this.label,
    required this.value,
    this.blue = false,
    this.note,
    this.trailing,
    this.onTap,
  });

  final String label;
  final String value;
  final bool blue;

  /// The small words after the figure ("3 on committee").
  final String? note;
  final Widget? trailing;
  final VoidCallback? onTap;

  static const height = 56.0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CommunityColors.tile,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned(
                left: 10,
                top: 11,
                right: 24,
                child: Text(label, style: CommunityText.statLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Positioned(
                left: 10,
                top: 27.5,
                right: 10,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(value, style: blue ? CommunityText.statValueBlue : CommunityText.statValue),
                    if (note != null) ...[
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(note!, style: CommunityText.statNote, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) Positioned(right: 10.5, top: 8, child: trailing!),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiles two to a row, 7 dp apart, inside the screen's 16 dp margins.
class CommunityStatGrid extends StatelessWidget {
  const CommunityStatGrid({super.key, required this.tiles, this.padding = const EdgeInsets.symmetric(horizontal: 16)});

  final List<Widget> tiles;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 4));
      rows.add(
        Row(
          children: [
            Expanded(child: tiles[i]),
            const SizedBox(width: 7),
            Expanded(child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox.shrink()),
          ],
        ),
      );
    }
    return Padding(
      padding: padding,
      child: Column(children: rows),
    );
  }
}

/// "● Your Chapters  [3 Joined] ........ Directory →": a section's heading in
/// the Councils design's type, with an optional pill, caption or link.
class CommunitySectionHeading extends StatelessWidget {
  const CommunitySectionHeading({
    super.key,
    required this.title,
    this.dot,
    this.pill,
    this.action,
    this.onAction,
    this.caption,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final String title;
  final Color? dot;
  final String? pill;
  final String? action;
  final VoidCallback? onAction;
  final String? caption;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: SizedBox(
        height: 18,
        child: Row(
          children: [
            if (dot != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
            ],
            Flexible(
              child: Text(title, style: CommunityText.sectionTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (pill != null) ...[
              const SizedBox(width: 10),
              Container(
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 9),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: CommunityColors.greyPill, borderRadius: BorderRadius.circular(9)),
                child: Text(pill!, style: CommunityText.sectionPill),
              ),
            ],
            const Spacer(),
            if (caption != null) Text(caption!, style: CommunityText.sectionCaption),
            if (action != null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onAction,
                child: Row(
                  children: [
                    Text(action!, style: CommunityText.sectionLink),
                    const SizedBox(width: 2),
                    const Icon(LucideIcons.arrowRight, size: 12, color: AppColors.primary),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The Councils design's "Join Council" button: a deep blue, 6 dp corners.
class CommunityButton extends StatelessWidget {
  const CommunityButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.outlined = false,
    this.height = 30,
    this.expand = false,
    this.busy = false,
    this.color = CommunityColors.action,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool outlined;
  final double height;
  final bool expand;
  final bool busy;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final style = outlined
        ? CommunityText.buttonOutline.copyWith(color: color == CommunityColors.action ? AppColors.primary : color)
        : CommunityText.buttonPrimary;
    final fill = outlined ? Colors.white : (enabled ? color : color.withValues(alpha: 0.6));
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),
      side: outlined ? const BorderSide(color: CommunityColors.border) : BorderSide.none,
    );
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.6, color: style.color))
        else if (icon != null)
          Icon(icon, size: 11, color: style.color),
        if (busy || icon != null) const SizedBox(width: 6),
        Flexible(
          child: Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: fill,
        shape: shape,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          customBorder: shape,
          child: SizedBox(
            height: height,
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: content),
          ),
        ),
      ),
    );
  }
}

/// A list of choices in a bottom sheet (sort orders, report reasons); null when
/// the sheet is dismissed.
Future<T?> pickFromSheet<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required String Function(T) label,
  T? selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title, style: CommunityText.sheetTitle),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final option in options)
                    ListTile(
                      title: Text(label(option), style: CommunityText.sheetRow),
                      trailing: option == selected
                          ? const Icon(LucideIcons.check, size: 18, color: AppColors.primary)
                          : null,
                      onTap: () => Navigator.pop(sheet, option),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A labelled text field in the community forms' style.
class CommunityField extends StatelessWidget {
  const CommunityField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.help,
    this.error,
    this.maxLength,
    this.minLines = 1,
    this.maxLines = 1,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.enabled = true,
    this.fieldKey,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? help;
  final String? error;
  final int? maxLength;
  final int minLines;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  /// The key of the [TextField] itself, for tests.
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: c),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: CommunityText.fieldLabel),
        const SizedBox(height: 5),
        TextField(
          key: fieldKey,
          controller: controller,
          enabled: enabled,
          style: CommunityText.fieldInput,
          minLines: minLines,
          maxLines: maxLines,
          maxLength: maxLength,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onChanged: onChanged,
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: CommunityText.fieldHint,
            counterStyle: CommunityText.fieldHelp,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: enabled ? Colors.white : CommunityColors.tile,
            enabledBorder: border(error == null ? CommunityColors.border : AppColors.error),
            focusedBorder: border(error == null ? AppColors.primary : AppColors.error),
            disabledBorder: border(CommunityColors.border),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(error!, style: CommunityText.fieldError),
        ] else if (help != null) ...[
          const SizedBox(height: 4),
          Text(help!, style: CommunityText.fieldHelp),
        ],
      ],
    );
  }
}

/// The light-blue call-to-action card at the foot of the Events board ("Host
/// or Propose an Event"): a glyph tile, a title and a line, and a white button.
class CommunityHostCard extends StatelessWidget {
  const CommunityHostCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 14, 11, 14),
      decoration: BoxDecoration(color: CommunityColors.hostFill, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.workSans(10.5, FontWeight.w700, AppColors.onSurface, lineHeight: 14)),
                const SizedBox(height: 4),
                Text(body, style: AppText.plexSans(9, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 13)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Text(
                  action,
                  style: AppText.workSans(9.5, FontWeight.w700, CommunityColors.link, lineHeight: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A row of choices where one is on: the sort and filter sheets' groups.
class CommunityChoiceWrap<T> extends StatelessWidget {
  const CommunityChoiceWrap({
    super.key,
    required this.title,
    required this.options,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  final String title;
  final List<T> options;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: CommunityText.sheetLabel),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final option in options)
              Semantics(
                button: true,
                selected: option == selected,
                child: GestureDetector(
                  onTap: () => onSelected(option),
                  child: Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: option == selected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: option == selected ? AppColors.primary : CommunityColors.border),
                    ),
                    child: Text(
                      label(option),
                      style: CommunityText.chip.copyWith(color: option == selected ? Colors.white : AppColors.slate700),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The dialog that asks before something is given up ("Leave this chapter?").
/// True when the person confirms.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text(title, style: CommunityText.sheetTitle),
      content: Text(body, style: CommunityText.body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: Text('Cancel', style: CommunityText.link),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialog, true),
          child: Text(action, style: CommunityText.link.copyWith(color: AppColors.error)),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// A bottom sheet with a title, a body that scrolls and a pinned footer.
Future<T?> showCommunitySheet<T>(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext sheet, void Function(void Function()) setState) body,
  Widget Function(BuildContext sheet)? footer,
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.85),
        child: StatefulBuilder(
          builder: (sheet, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(title, style: CommunityText.sheetTitle),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: body(sheet, setState),
                ),
              ),
              if (footer != null) footer(sheet),
            ],
          ),
        ),
      ),
    ),
  );
}
