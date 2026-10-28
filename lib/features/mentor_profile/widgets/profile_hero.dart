import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/util/links.dart';
import '../mentor_profile_format.dart';
import '../mentor_profile_models.dart';
import '../mentor_profile_styles.dart';
import 'mentor_picture.dart';
import 'mentor_ring.dart';

/// What the hero's two buttons do for this viewer.
class HeroActions {
  const HeroActions({
    required this.primaryLabel,
    required this.barLabel,
    this.primaryIcon = LucideIcons.calendar,
    this.onPrimary,
    this.onMessage,
  });

  /// "Book Trial (₹0)".
  final String primaryLabel;

  /// "Book Free Trial", on the pinned bar.
  final String barLabel;
  final IconData primaryIcon;

  /// Null greys the button out (a request already in play).
  final VoidCallback? onPrimary;

  /// Null hides "Send Message" (the mentor's own profile).
  final VoidCallback? onMessage;
}

/// Cover, photo in its MENTOR ring, rating, name, role line, the facts, the
/// next free slot and the two asks: the top of the Mentor Profile design.
class ProfileHero extends StatelessWidget {
  const ProfileHero({super.key, required this.profile, required this.actions});

  static const coverHeight = 112.3;
  static const _gutter = 12.5;

  final MentorProfile profile;
  final HeroActions actions;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final slot = p.slotLabel ?? nextSlot(p.availability, p.timezone)?.label;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: coverHeight,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MentorPicture(picture: p.cover, alignment: Alignment.bottomCenter, fallback: const NavyFallback()),
                  if (p.verified) Positioned(right: 37.5, top: 5.4, child: _VerifiedPill(firstName: p.firstName)),
                ],
              ),
            ),
            const SizedBox(height: 3.4),
            SizedBox(
              height: 31.8,
              child: Padding(
                padding: const EdgeInsets.only(right: 13),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: p.ratingCount > 0 ? _RatingChip(rating: p.rating, count: p.ratingCount) : null,
                ),
              ),
            ),
            const SizedBox(height: 9.9),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _gutter),
              child: SizedBox(
                height: 20,
                child: Row(
                  children: [
                    Flexible(
                      child: Text(p.name, style: MentorText.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (p.verified) ...[
                      const SizedBox(width: 5),
                      const Icon(Symbols.verified, fill: 1, size: 14, color: AppColors.primary),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8.2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _gutter),
              child: Text.rich(
                TextSpan(style: MentorText.headline, children: roleLineSpans(p)),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 6.3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _gutter),
              child: Wrap(
                spacing: 5.7,
                runSpacing: 3.4,
                children: [
                  if (p.yearsExperience != null && p.yearsExperience! > 0)
                    _FactChip(icon: Symbols.work_history, label: '${p.yearsExperience}+ Yrs Exp'),
                  if (p.placeLabel != null) _FactChip(icon: LucideIcons.mapPin, label: p.placeLabel!),
                ],
              ),
            ),
            if (slot != null) ...[
              const SizedBox(height: 2.2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: _gutter),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _SlotPill(label: slot),
                ),
              ),
            ],
            const SizedBox(height: 11.4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 2035,
                    child: _HeroButton(
                      label: actions.primaryLabel,
                      icon: actions.primaryIcon,
                      onTap: actions.onPrimary,
                      primary: true,
                    ),
                  ),
                  if (actions.onMessage != null) ...[
                    const SizedBox(width: 9),
                    Expanded(
                      flex: 1535,
                      child: _HeroButton(
                        label: 'Send Message',
                        icon: LucideIcons.messageSquare,
                        onTap: actions.onMessage,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        Positioned(
          left: 13.5,
          top: 63.2,
          child: MentorRing(
            child: MentorPicture(
              picture: p.photo,
              alignment: Alignment.topCenter,
              fallback: InitialsTile(name: p.name),
            ),
          ),
        ),
      ],
    );
  }
}

/// The line under the name: "Supply Chain Leader at **Microsoft** • Ex-Tata
/// Aerospace • BITS Pilani • IIT KGP".
///
/// It is the current role ("title at organisation") followed by the mentor's
/// own headline. A headline that already says where they work is drawn alone,
/// with that organisation set in bold, rather than repeating "Microsoft" after
/// "at Microsoft".
List<InlineSpan> roleLineSpans(MentorProfile p) {
  final role = p.roleTitle;
  final org = p.roleOrganisation;
  final headline = p.headline?.trim();
  // A bullet stays with the word after it, so a line never ends on one.
  String tie(String text) => text.replaceAll(' • ', ' • ');
  if (org != null && org.isNotEmpty && headline != null && headline.isNotEmpty) {
    final at = headline.toLowerCase().indexOf(org.toLowerCase());
    if (at >= 0) {
      final end = at + org.length;
      return [
        if (at > 0) TextSpan(text: tie(headline.substring(0, at))),
        TextSpan(text: headline.substring(at, end), style: MentorText.headlineStrong),
        if (end < headline.length) TextSpan(text: tie(headline.substring(end))),
      ];
    }
  }
  return [
    if (role != null) TextSpan(text: '$role at '),
    if (org != null) TextSpan(text: org, style: MentorText.headlineStrong),
    if (headline != null && headline.isNotEmpty)
      TextSpan(text: tie(role == null && org == null ? headline : ' • $headline')),
  ];
}

/// "Verified Mentor": tapping it says what the badge stands for.
class _VerifiedPill extends StatelessWidget {
  const _VerifiedPill({required this.firstName});

  final String firstName;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Verified Mentor',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () =>
            showMessage(context, "Verified Mentor: ICR has reviewed and approved $firstName's mentor profile."),
        child: Container(
          height: 22.6,
          padding: const EdgeInsets.only(left: 7, right: 9.7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Symbols.verified, fill: 1, size: 10, color: AppColors.primary),
              const SizedBox(width: 6.4),
              Text('Verified Mentor', style: MentorText.verifiedPill),
            ],
          ),
        ),
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.rating, required this.count});

  final double rating;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 31.8,
      padding: const EdgeInsets.only(left: 8.5, right: 9),
      decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Symbols.star, fill: 1, size: 13, color: MentorColors.star),
          const SizedBox(width: 5),
          Text(rating.toStringAsFixed(1), style: MentorText.ratingValue),
          const SizedBox(width: 6),
          Text('($count review${count == 1 ? '' : 's'})', style: MentorText.ratingCount),
        ],
      ),
    );
  }
}

class _FactChip extends StatelessWidget {
  const _FactChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 23.9,
      padding: const EdgeInsets.only(left: 8, right: 8),
      decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label, style: MentorText.fact),
        ],
      ),
    );
  }
}

class _SlotPill extends StatelessWidget {
  const _SlotPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 25,
      padding: const EdgeInsets.only(left: 9.5, right: 9),
      decoration: BoxDecoration(color: MentorColors.mint, borderRadius: BorderRadius.circular(13)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.zap, size: 11, color: MentorColors.mintInk),
          const SizedBox(width: 3.2),
          Text(label, style: MentorText.slot),
        ],
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({required this.label, required this.icon, required this.onTap, this.primary = false});

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fill = primary
        ? (enabled ? AppColors.primary : AppColors.primary.withValues(alpha: 0.5))
        : AppColors.surfaceContainer;
    final style = primary ? MentorText.primaryButton : MentorText.softButton;
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 33,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 11.5, color: style.color),
              const SizedBox(width: 6.7),
              Flexible(
                child: Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
