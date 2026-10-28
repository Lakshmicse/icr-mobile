import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/section_heading.dart';
import '../../feed/widgets/feed_avatar.dart';
import '../mentorship_models.dart';
import '../mentorship_styles.dart';

/// A section's heading row, 20 dp tall: the title, and whatever sits at the
/// right ("8+ Domains", "View More").
class LandingHeading extends StatelessWidget {
  const LandingHeading({super.key, required this.title, this.trailing, this.left = 10, this.right = 10.6});

  final String title;
  final Widget? trailing;
  final double left;
  final double right;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Padding(
        padding: EdgeInsets.only(left: left, right: right),
        child: Row(
          children: [
            Expanded(
              child: Text(title, style: MentorshipText.heading, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// The light-blue "8+ Domains" pill.
class DomainsPill extends StatelessWidget {
  const DomainsPill(this.label, {super.key, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 19.5,
        padding: const EdgeInsets.symmetric(horizontal: 10.25),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: MentorshipColors.domainsPill, borderRadius: BorderRadius.circular(10)),
        child: Text(label, style: MentorshipText.domainsPill),
      ),
    );
  }
}

/// "View More" at the right of a heading.
class ViewMore extends StatelessWidget {
  const ViewMore({super.key, required this.onTap, this.label = 'View More'});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Text(label, style: MentorshipText.headingAction),
    );
  }
}

/// Two rows of four outlined tiles, each a company's wordmark.
class CompanyTiles extends StatelessWidget {
  const CompanyTiles({super.key, required this.companies, required this.onOpen});

  static const tileHeight = 42.2;

  final List<MentorCompany> companies;
  final void Function(MentorCompany) onOpen;

  @override
  Widget build(BuildContext context) {
    final shown = companies.take(8).toList();
    final rows = (shown.length + 3) ~/ 4;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: Column(
        children: [
          for (var r = 0; r < rows; r++) ...[
            if (r > 0) const SizedBox(height: 9.8),
            Row(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: r * 4 + i < shown.length
                        ? _Tile(company: shown[r * 4 + i], onTap: () => onOpen(shown[r * 4 + i]))
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.company, required this.onTap});

  final MentorCompany company;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final logo = company.logo;
    Widget mark;
    if (logo?.url != null) {
      mark = CachedNetworkImage(
        imageUrl: logo!.url!,
        height: 24,
        fit: BoxFit.contain,
        errorWidget: (_, _, _) => _name(),
      );
    } else if (logo?.asset != null) {
      mark = Image.asset(logo!.asset!, height: 24, fit: BoxFit.contain);
    } else {
      mark = _name();
    }
    return Semantics(
      button: true,
      label: company.name,
      child: Container(
        height: CompanyTiles.tileHeight,
        // The design's tiles have no outline at all, only a whisper of shadow.
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 6, offset: Offset(0, 1))],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Center(
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: mark),
            ),
          ),
        ),
      ),
    );
  }

  /// The name as a wordmark, in the company's brand colour: the one the source
  /// gives, else the palette's by name (JLL red, CBRE blue, ink for the rest).
  Widget _name() {
    final given = company.brandColor;
    final color = given == null ? MentorshipBrand.wordmark(company.name) : Color(given);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(company.name, maxLines: 1, style: MentorshipText.wordmark.copyWith(color: color)),
    );
  }
}

/// "Learn from top topics": outlined chips, three to a row.
class TopicGrid extends StatelessWidget {
  const TopicGrid({super.key, required this.topics, required this.onOpen});

  static const chipHeight = 33.0;

  final List<MentorTopic> topics;
  final void Function(MentorTopic) onOpen;

  @override
  Widget build(BuildContext context) {
    final shown = topics.take(9).toList();
    final rows = (shown.length + 2) ~/ 3;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (var r = 0; r < rows; r++) ...[
            if (r > 0) const SizedBox(height: 6.4),
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: r * 3 + i < shown.length
                        ? _TopicChip(topic: shown[r * 3 + i], onTap: () => onOpen(shown[r * 3 + i]))
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({required this.topic, required this.onTap});

  final MentorTopic topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (topic.tone) {
      TopicTone.neutral => AppColors.onSurfaceVariant,
      TopicTone.blue => MentorshipColors.topicBlue,
      TopicTone.red => MentorshipColors.topicRed,
    };
    return Semantics(
      button: true,
      label: topic.label,
      child: Container(
        height: TopicGrid.chipHeight,
        decoration: BoxDecoration(
          color: topic.selected ? MentorshipColors.topicOn : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: MentorshipColors.tileBorder),
          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 2, offset: Offset(0, 1))],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: onTap,
            child: Center(
              child: Padding(
                padding: EdgeInsets.zero,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(topic.label, maxLines: 1, style: MentorshipText.topicChip(color)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The dark-blue "Become an ICR Mentor" band with its photo.
class BecomeMentorBanner extends StatelessWidget {
  const BecomeMentorBanner({super.key, required this.banner, required this.onApply});

  static const photoWidth = 120.3;

  final MentorBanner banner;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [MentorshipColors.bannerStart, MentorshipColors.bannerEnd],
              ),
            ),
          ),
        ),
        if (banner.photo != null)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: photoWidth,
            child: _BannerPhoto(photo: banner.photo!),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20.3, 14.5, 0, 14.1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 236),
                child: Text(banner.title, style: MentorshipText.bannerTitle, maxLines: 3),
              ),
              const SizedBox(height: 4.5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 250),
                child: Text(banner.body, style: MentorshipText.bannerBody, maxLines: 4),
              ),
              const SizedBox(height: 10.2),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(7),
                child: InkWell(
                  borderRadius: BorderRadius.circular(7),
                  onTap: onApply,
                  child: SizedBox(
                    width: 151,
                    height: 32.3,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(banner.cta, style: MentorshipText.bannerButton),
                        const SizedBox(width: 7),
                        const Icon(LucideIcons.arrowRight, size: 14, color: MentorshipColors.bannerInk),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BannerPhoto extends StatelessWidget {
  const _BannerPhoto({required this.photo});

  final FeedPicture photo;

  @override
  Widget build(BuildContext context) {
    final Widget image = photo.asset != null
        ? Image.asset(photo.asset!, fit: BoxFit.cover)
        : CachedNetworkImage(imageUrl: photo.url!, fit: BoxFit.cover, errorWidget: (_, _, _) => const SizedBox());
    // The photo fades in from the band's own colour, so there is no seam.
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) =>
          const LinearGradient(colors: [Colors.transparent, Colors.black], stops: [0, 0.3]).createShader(rect),
      child: image,
    );
  }
}

/// "● UPCOMING COHORT": the next programme open for applications.
class CohortCard extends StatelessWidget {
  const CohortCard({super.key, required this.cohort, required this.onOpen});

  final MentorCohort cohort;
  final VoidCallback onOpen;

  static const _avatarSize = 19.3;
  static const _avatarStep = 14.5;
  static const _avatarColors = [AppColors.primary, AppColors.tertiary, Color(0xFF4B5563)];

  @override
  Widget build(BuildContext context) {
    final count = cohort.avatars.length;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [MentorshipColors.cohortStart, MentorshipColors.cohortEnd]),
      ),
      child: Stack(
        children: [
          if (cohort.cover != null) Positioned.fill(child: _CohortBackdrop(photo: cohort.cover!)),
          Padding(
            padding: const EdgeInsets.fromLTRB(19.3, 16.7, 19.3, 13.4),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 14,
                    child: Row(
                      children: [
                        Container(
                          width: 8.2,
                          height: 8.2,
                          decoration: const BoxDecoration(color: MentorshipColors.liveDot, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6.3),
                        Text('UPCOMING COHORT', style: MentorshipText.cohortKicker),
                      ],
                    ),
                  ),
                  const SizedBox(height: 9.3),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 230),
                    child: Text(cohort.name, style: MentorshipText.cohortTitle, maxLines: 2),
                  ),
                  const SizedBox(height: 8.9),
                  SizedBox(
                    height: _avatarSize,
                    child: Row(
                      children: [
                        if (count > 0)
                          SizedBox(
                            width: _avatarStep * (count - 1) + _avatarSize,
                            child: Stack(
                              children: [
                                for (final (i, a) in cohort.avatars.indexed)
                                  Positioned(
                                    left: i * _avatarStep,
                                    child: _CohortAvatar(avatar: a, index: i),
                                  ),
                              ],
                            ),
                          ),
                        if (count > 0) const SizedBox(width: 5.9),
                        Text(cohort.registeredLabel, style: MentorshipText.cohortMeta),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 18.8,
            top: 45.8,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
              child: InkWell(
                borderRadius: BorderRadius.circular(5),
                onTap: onOpen,
                child: SizedBox(
                  width: 104.4,
                  height: 25.7,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Know More', style: MentorshipText.cohortButton),
                      const SizedBox(width: 5),
                      const Icon(LucideIcons.arrowRight, size: 13, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The programme's own cover behind the card, blurred and washed out the way the
/// design's city photo is, so the words over it stay as legible as on the flat
/// grey.
class _CohortBackdrop extends StatelessWidget {
  const _CohortBackdrop({required this.photo});

  final FeedPicture photo;

  @override
  Widget build(BuildContext context) {
    final Widget image = photo.asset != null
        ? Image.asset(photo.asset!, fit: BoxFit.cover)
        : CachedNetworkImage(imageUrl: photo.url!, fit: BoxFit.cover, errorWidget: (_, _, _) => const SizedBox());
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 2.2, sigmaY: 2.2, tileMode: TileMode.clamp),
            child: image,
          ),
          const ColoredBox(color: MentorshipColors.cohortWash),
        ],
      ),
    );
  }
}

class _CohortAvatar extends StatelessWidget {
  const _CohortAvatar({required this.avatar, required this.index});

  final CohortAvatar avatar;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: CohortCard._avatarSize,
      height: CohortCard._avatarSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: CohortCard._avatarColors[index % CohortCard._avatarColors.length],
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1),
      ),
      child: avatar.photo == null
          ? Text(avatar.initials, style: MentorshipText.cohortInitials)
          : FeedAvatar(photo: avatar.photo, initials: avatar.initials, size: CohortCard._avatarSize - 2),
    );
  }
}

/// "Featured Advisory Sessions": one card per offering, ruled apart.
class AdvisorySessions extends StatelessWidget {
  const AdvisorySessions({super.key, required this.services, required this.onOpen});

  final List<MentorService> services;
  final void Function(MentorService) onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final (i, s) in services.indexed) ...[
            if (i > 0) const Hairline(color: AppColors.cardRule),
            Padding(
              // The design rules its second divider closer to the card below.
              padding: EdgeInsets.fromLTRB(
                16,
                i == 0 ? 0 : (i == 1 ? 21 : 16.6),
                16,
                i == services.length - 1 ? 0 : 10.4,
              ),
              child: _SessionCard(service: s, onTap: () => onOpen(s)),
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.service, required this.onTap});

  final MentorService service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final featured = service.featured;
    final blurb = service.blurb;
    final glyph = switch (service.glyphOrDefault) {
      ServiceGlyph.diagnostic => const Icon(LucideIcons.briefcaseMedical, size: 20, color: AppColors.tertiary),
      ServiceGlyph.session => const Icon(Symbols.record_voice_over, size: 20, color: AppColors.primary),
      ServiceGlyph.query ||
      ServiceGlyph.resource => const Icon(LucideIcons.fileText, size: 20, color: AppColors.onSurface),
      ServiceGlyph.group => const Icon(LucideIcons.users, size: 20, color: AppColors.primary),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 21.7,
          child: Row(
            children: [
              Container(
                height: 21.7,
                padding: const EdgeInsets.symmetric(horizontal: 10.3),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: featured ? AppColors.successBadge : AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(service.pill, style: featured ? MentorshipText.pillFeatured : MentorshipText.pill),
              ),
              const Spacer(),
              glyph,
            ],
          ),
        ),
        const SizedBox(height: 9.1),
        Text(service.title, style: MentorshipText.serviceTitle, maxLines: 3),
        if (blurb != null && blurb.isNotEmpty) ...[
          const SizedBox(height: 7.9),
          Text(blurb, style: MentorshipText.serviceBody, maxLines: 4, overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: 13.5),
        Material(
          color: featured ? AppColors.primary : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4.5),
            side: featured ? BorderSide.none : const BorderSide(color: AppColors.cardRule),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(4.5),
            onTap: onTap,
            child: SizedBox(
              height: 29,
              width: double.infinity,
              child: Center(
                child: Text(
                  service.buttonLabel,
                  style: featured ? MentorshipText.serviceButton : MentorshipText.serviceButtonOutlined,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
