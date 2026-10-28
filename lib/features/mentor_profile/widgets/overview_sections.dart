import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/section_heading.dart';
import '../mentor_profile_format.dart';
import '../mentor_profile_models.dart';
import '../mentor_profile_styles.dart';
import 'mentor_picture.dart';

const _cellFill = Color(0xFFFAFAFA);

/// A rule across the page (between the big sections) or inset to the cards' margin.
class SectionRule extends StatelessWidget {
  const SectionRule({super.key, this.inset = false});

  final bool inset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: inset ? 10.2 : 0),
      child: const Hairline(color: AppColors.cardRule),
    );
  }
}

/// Sessions, mentees and languages: three soft cells under the tabs.
class StatsCard extends StatelessWidget {
  const StatsCard({super.key, required this.profile});

  final MentorProfile profile;

  @override
  Widget build(BuildContext context) {
    final s = profile.stats;
    final languages = profile.languages.take(4).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(9.1, 9, 10.2, 0),
      child: SizedBox(
        height: 98,
        child: Row(
          children: [
            Expanded(
              flex: 1103,
              child: _Cell(
                children: [
                  Text(s.sessions, style: MentorText.statValue),
                  const SizedBox(height: 3.3),
                  Text('Sessions Conducted', style: MentorText.statCaption),
                  if (s.sessionsBadge != null) ...[
                    const SizedBox(height: 3.7),
                    Container(
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 3.4),

                      decoration: BoxDecoration(color: MentorColors.mint, borderRadius: BorderRadius.circular(2)),
                      child: Center(widthFactor: 1, child: Text(s.sessionsBadge!, style: MentorText.statBadge)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4.5),
            Expanded(
              flex: 1034,
              child: _Cell(
                children: [
                  Text(s.mentees, style: MentorText.statValue),
                  const SizedBox(height: 3.3),
                  Text(s.menteesCaption, style: MentorText.statCaption),
                  if (s.menteesNote != null) ...[
                    const SizedBox(height: 9.5),
                    Text(s.menteesNote!, style: MentorText.statCaption, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            if (languages.isNotEmpty) ...[
              const SizedBox(width: 4.5),
              Expanded(
                flex: 1478,
                child: _Cell(
                  top: 9.9,
                  left: 22,
                  children: [
                    Text('Languages', style: MentorText.statLabel),
                    const SizedBox(height: 7),
                    Wrap(spacing: 7, runSpacing: 9.6, children: [for (final l in languages) _LanguageChip(label: l)]),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.children, this.top = 10.2, this.left = 11.4});

  final List<Widget> children;
  final double top;
  final double left;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.hardEdge,
      padding: EdgeInsets.fromLTRB(left, top, 6, 0),
      decoration: BoxDecoration(
        color: _cellFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF3F4F5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 13.7,
      padding: const EdgeInsets.symmetric(horizontal: 6),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.cardRule, width: 0.8),
      ),
      child: Center(widthFactor: 1, child: Text(label, style: MentorText.language)),
    );
  }
}

/// "About Srikanth": the bio folded to six lines with a "...read more".
class AboutSection extends StatelessWidget {
  const AboutSection({
    super.key,
    required this.firstName,
    required this.bioHtml,
    required this.expanded,
    required this.onExpand,
  });

  final String firstName;
  final String? bioHtml;
  final bool expanded;
  final VoidCallback onExpand;

  static const _width = 305.0;

  @override
  Widget build(BuildContext context) {
    final paragraphs = bioParagraphs(bioHtml);
    if (paragraphs.isEmpty) return const SizedBox.shrink();
    final lead = paragraphs.length > 1 ? 4 : 6;
    final folds = !expanded;
    final shown = folds ? paragraphs.take(2).toList() : paragraphs;
    var more = folds && paragraphs.length > 2;
    if (folds) {
      for (final (i, text) in shown.indexed) {
        more = more || _overflows(text, i == 0 ? lead : 2);
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(22.7, 15.9, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About $firstName', style: MentorText.section),
          const SizedBox(height: 11.5),
          for (final (i, text) in shown.indexed) ...[
            if (i > 0) const SizedBox(height: 9),
            SizedBox(
              width: _width,
              child: Text(folds ? _clampWords(text, i == 0 ? lead : 2) : text, style: MentorText.body),
            ),
          ],
          if (more) ...[
            const SizedBox(height: 12.9),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onExpand,
              child: SizedBox(
                height: 14,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('...read more', style: MentorText.readMore),
                    const SizedBox(width: 2),
                    const Icon(LucideIcons.chevronDown, size: 11, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 15.2),
        ],
      ),
    );
  }

  /// The text cut at a word so that it and "..." fit in [maxLines]; the whole
  /// text when it already fits.
  static String _clampWords(String text, int maxLines) {
    if (!_overflows(text, maxLines)) return text;
    final words = text.split(' ');
    var low = 0;
    var high = words.length;
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      if (_overflows('${words.take(mid).join(' ')}...', maxLines)) {
        high = mid - 1;
      } else {
        low = mid;
      }
    }
    return '${words.take(low).join(' ')}...';
  }

  static bool _overflows(String text, int maxLines) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: MentorText.body),
      maxLines: maxLines,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _width);
    return painter.didExceedMaxLines;
  }
}

/// "Career Journey": the roles on a blue timeline.
class CareerSection extends StatelessWidget {
  const CareerSection({super.key, required this.roles, this.yearsLabel});

  final List<MentorRole> roles;
  final String? yearsLabel;

  /// Roles drawn with a blue dot; older ones fade.
  static const _recent = 2;

  @override
  Widget build(BuildContext context) {
    if (roles.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(10.2, 20.8, 11.4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 16,
            child: Row(
              children: [
                Text('Career Journey', style: MentorText.sectionWide),
                const Spacer(),
                if (yearsLabel != null) Text(yearsLabel!, style: MentorText.sectionNote.copyWith(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 24.3),
          for (final (i, role) in roles.indexed) _RoleTile(role: role, index: i, last: i == roles.length - 1),
        ],
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({required this.role, required this.index, required this.last});

  /// The timeline's axis, from the section's left padding, and its two dot sizes (from the design).
  static const _axis = 18.8;
  static const _ringSize = 14.6;
  static const _fadedSize = 13.0;

  final MentorRole role;
  final int index;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final months = monthsBetween(role.startYear, role.startMonth, role.endYear, role.endMonth);
    final length = role.durationLabel ?? durationLabel(months);
    final short = role.durationLabel ?? durationShort(months);
    // The row is as tall as its title line at the app's size (the design's 16 dp was for 11 sp type), and the
    // "Present" pill's 27 dp when the role is current.
    final titleLine = (MentorText.roleTitle.fontSize ?? 12) * (MentorText.roleTitle.height ?? 1.3);
    final rowHeight = role.isCurrent ? 27.0 : (titleLine > 16 ? titleLine : 16.0);
    final recent = index < CareerSection._recent;
    final meta = [role.years, if (role.isCurrent) length, ?role.place].join(' • ');
    final description = role.description?.trim();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Each row's line is its own: it starts just under its dot and ends with the row's text,
        // leaving the gap above the next dot (measured on the design: 2 dp wide, 1.3 dp under the dot).
        if (!last && recent)
          Positioned(
            left: _axis - 1,
            top: rowHeight / 2 + _ringSize / 2 + 1.3,
            bottom: 17.8,
            width: 2,
            child: const ColoredBox(color: MentorColors.timeline),
          ),
        Positioned(
          left: _axis - (recent ? _ringSize : _fadedSize) / 2,
          top: rowHeight / 2 - (recent ? _ringSize : _fadedSize) / 2,
          child: recent
              ? Container(
                  width: _ringSize,
                  height: _ringSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 4.2),
                  ),
                )
              : Container(
                  // An earlier role: a faint disc with a pale core.
                  width: _fadedSize,
                  height: _fadedSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFF7F8F8)),
                  ),
                  child: Container(
                    width: 6.1,
                    height: 6.1,
                    decoration: const BoxDecoration(color: MentorColors.timeline, shape: BoxShape.circle),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 35.3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: rowHeight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10.8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          role.title,
                          style: MentorText.roleTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (role.isCurrent)
                        // The design hangs the pill 2.5 dp below the title's centre, not on it.
                        Transform.translate(
                          offset: const Offset(0, 2.5),
                          child: Container(
                            // 41 dp wide at the design's size; wider when its word is, and never wrapped.
                            constraints: const BoxConstraints(minWidth: 41),
                            height: 27,
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: MentorColors.mint, borderRadius: BorderRadius.circular(3)),
                            child: Text('Present', style: MentorText.presentBadge, maxLines: 1, softWrap: false),
                          ),
                        )
                      else
                        Text(short, style: MentorText.roleYears),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 9),
              Text(
                role.organisation,
                style: role.organisationLinked ? MentorText.roleOrgLink : MentorText.roleOrg,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(meta, style: MentorText.roleMeta, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (description != null && description.isNotEmpty) ...[
                const SizedBox(height: 10.4),
                SizedBox(
                  // The design's longest line is 307 dp (Medium weight); the next word would not fit under 331.
                  width: 310,
                  child: Text(description, style: MentorText.body, maxLines: 4, overflow: TextOverflow.ellipsis),
                ),
              ],
              SizedBox(height: last ? 11.8 : 17.8),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Education & Academic": a round tile, the school, the degree in blue, the batch.
class EducationSection extends StatelessWidget {
  const EducationSection({super.key, required this.education});

  final List<MentorEducation> education;

  @override
  Widget build(BuildContext context) {
    if (education.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(10.2, 12.7, 10.2, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Education & Academic', style: MentorText.sectionWide),
          const SizedBox(height: 16.2),
          for (final (i, e) in education.indexed) ...[
            if (i > 0) ...[const Hairline(color: AppColors.cardRule), const SizedBox(height: 21.7)],
            _EducationRow(education: e, first: i == 0),
            const SizedBox(height: 16.6),
          ],
        ],
      ),
    );
  }
}

class _EducationRow extends StatelessWidget {
  const _EducationRow({required this.education, required this.first});

  final MentorEducation education;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final e = education;
    final batch = [?e.batch, ?e.field].join(' • ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 11.4),
        Container(
          width: 31.8,
          height: 31.8,
          decoration: const BoxDecoration(color: AppColors.surfaceContainer, shape: BoxShape.circle),
          child: Icon(
            first ? LucideIcons.graduationCap : LucideIcons.landmark,
            size: 15,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 10.5),
        SizedBox(
          width: 241,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.institution, style: MentorText.school, maxLines: 3, overflow: TextOverflow.ellipsis),
              if (e.degree != null) ...[
                const SizedBox(height: 4),
                Text(e.degree!, style: MentorText.degree, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
              if (batch.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(batch, style: MentorText.batch, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// "Technical Mastery & Tools": the two chip groups in a soft card.
class SkillsSection extends StatelessWidget {
  const SkillsSection({super.key, required this.profile});

  final MentorProfile profile;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    if (p.competencies.isEmpty && p.topics.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(10.2, 14.6, 10.2, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Technical Mastery & Tools', style: MentorText.sectionWide),
          const SizedBox(height: 7.2),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(11.8, 4.2, 11.4, 11.4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF1F2F3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (p.competencies.isNotEmpty) ..._group(p.competenciesLabel, p.competencies, first: true),
                if (p.topics.isNotEmpty) ..._group(p.topicsLabel, p.topics, first: p.competencies.isEmpty),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _group(String label, List<String> items, {required bool first}) => [
    if (!first) const SizedBox(height: 17.1),
    SizedBox(height: 11, child: Text(label, style: MentorText.skillLabel)),
    SizedBox(height: first ? 11.0 : 11.0),
    Wrap(
      spacing: 6.3,
      runSpacing: 5.4,
      children: [
        for (final item in items)
          Container(
            height: 28.4,
            padding: const EdgeInsets.symmetric(horizontal: 8.55),

            decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(14.2)),
            child: Center(widthFactor: 1, child: Text(item, style: MentorText.skill)),
          ),
      ],
    ),
  ];
}

/// "Recommendations ★ 5.0" and the reviews under it, with a link to the rest.
class RecommendationsSection extends StatelessWidget {
  const RecommendationsSection({
    super.key,
    required this.profile,
    required this.reviews,
    required this.onViewAll,
    this.limit = 1,
  });

  final MentorProfile profile;
  final List<MentorReview> reviews;
  final VoidCallback onViewAll;

  /// How many reviews to draw.
  final int limit;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final shown = reviews.take(limit).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12.5, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11.4),
            child: SizedBox(
              height: 16,
              child: Row(
                children: [
                  Text('Recommendations', style: MentorText.sectionWide),
                  const Spacer(),
                  if (p.ratingCount > 0) ...[
                    const Icon(Symbols.star, fill: 1, size: 11, color: MentorColors.star),
                    const SizedBox(width: 4.5),
                    Text(p.rating.toStringAsFixed(1), style: MentorText.ratingValue.copyWith(fontSize: 13)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 9.1),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(22.7, 6, 22.7, 16),
              child: Text(
                'No written recommendations yet. Mentees can leave one once a mentorship is complete.',
                style: MentorText.body,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(9.1, 0, 10.2, 0),
              child: Column(
                children: [
                  for (final (i, r) in shown.indexed)
                    _ReviewCard(
                      review: r,
                      footer: i == shown.length - 1 && p.ratingCount > 0
                          ? _ViewAll(
                              label: 'View all ${p.ratingCount} verified review${p.ratingCount == 1 ? '' : 's'}',
                              onTap: onViewAll,
                            )
                          : null,
                      gap: i == shown.length - 1 ? 0 : 8,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, this.footer, this.gap = 0});

  final MentorReview review;
  final Widget? footer;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final r = review;
    final subline = [?r.subline, ?(r.agoLabel ?? (r.createdAt == null ? null : reviewAgo(r.createdAt!)))].join(' • ');
    final stars = r.rating ?? 0;
    return Padding(
      padding: EdgeInsets.only(bottom: gap),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFF1F2F3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(12.5, 7.8, 0, 11.9),
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 34,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 33,
                            height: 33,
                            decoration: const BoxDecoration(shape: BoxShape.circle),
                            clipBehavior: Clip.antiAlias,
                            child: MentorPicture(
                              picture: r.photo,
                              fallback: InitialsTile(name: r.name),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2.2),
                                SizedBox(
                                  height: 16,
                                  child: Text(
                                    r.name,
                                    style: MentorText.reviewer,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(height: 3.2),
                                SizedBox(
                                  height: 10,
                                  child: Text(
                                    subline,
                                    style: MentorText.reviewerLine,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (stars > 0)
                            Padding(
                              padding: const EdgeInsets.only(right: 12.7),
                              child: Row(
                                children: [
                                  for (var s = 1; s <= 5; s++)
                                    Icon(Symbols.star, fill: s <= stars ? 1 : 0, size: 9, color: MentorColors.star),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 7.2),
                    SizedBox(width: 317, child: Text('"${r.quote}"', style: MentorText.quote)),
                  ],
                ),
              ),
              ?footer,
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewAll extends StatelessWidget {
  const _ViewAll({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 32.4,
        color: AppColors.surfaceContainer,
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: MentorText.viewAll),
            const SizedBox(width: 3),
            const Icon(LucideIcons.chevronRight, size: 11, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
