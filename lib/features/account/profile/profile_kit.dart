import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../account_labels.dart';
import '../account_models.dart';
import '../widgets/account_kit.dart';

/// The parts the person's own profile and a member's public page share: the
/// header with its cover and photo, section cards, the rows of a career, and
/// the small pieces (clamped text, chips, a section that failed to load).

const double _coverHeight = 108;
const double _avatarSize = 84;

/// The head of a profile: a cover, the photo across its edge, then the name
/// with the tick of a confirmed address, the headline, where they are, and the
/// buttons the page puts under it.
///
/// The edit callbacks draw their own controls (a camera on the cover, a camera
/// badge on a photo-less avatar, a pencil beside the name); a member's page
/// passes none.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.name,
    required this.initials,
    this.avatarUrl,
    this.coverImage,
    this.verified = false,
    this.roleLabel,
    this.headline,
    this.place,
    this.facts = const [],
    this.onEditCover,
    this.onEditPhoto,
    this.onEditIntro,
    this.onAvatarTap,
    this.chips = const [],
    this.actions = const [],
  });

  final String name;
  final String initials;
  final String? avatarUrl;
  final String? coverImage;
  final bool verified;

  /// "Professional", "Company Admin": a quiet chip beside the name.
  final String? roleLabel;
  final String? headline;

  /// "Bengaluru, Karnataka · TechCorp".
  final String? place;

  /// "12 years in the profession", "Joined Oct 2026".
  final List<String> facts;
  final VoidCallback? onEditCover;
  final VoidCallback? onEditPhoto;
  final VoidCallback? onEditIntro;

  /// The photo opens bigger on a member's page.
  final VoidCallback? onAvatarTap;

  /// Extra chips (mentor, ready for my next role) under the facts.
  final List<Widget> chips;

  /// The pill buttons under the header (Follow, Message, Share).
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final editsPhoto = onEditPhoto != null;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _coverHeight + _avatarSize / 2,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: _coverHeight,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                    child: CoverBand(cover: coverImage),
                  ),
                ),
                if (onEditCover != null)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _RoundButton(
                      key: const Key('profile.editCover'),
                      icon: Symbols.photo_camera,
                      tooltip: 'Change cover',
                      onPressed: onEditCover!,
                    ),
                  ),
                Positioned(
                  left: 16,
                  top: _coverHeight - _avatarSize / 2,
                  child: GestureDetector(
                    key: const Key('profile.avatar'),
                    onTap: editsPhoto ? onEditPhoto : onAvatarTap,
                    behavior: HitTestBehavior.opaque,
                    child: Semantics(
                      button: editsPhoto || onAvatarTap != null,
                      label: editsPhoto ? (avatarUrl == null ? 'Add a profile photo' : 'Change profile photo') : 'Profile photo',
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AccountAvatar(url: avatarUrl, initials: initials, size: _avatarSize, ring: true),
                          if (editsPhoto && avatarUrl == null)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Symbols.photo_camera, size: 15, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (onEditIntro != null)
                  Positioned(
                    right: 6,
                    top: _coverHeight + 2,
                    child: CardIconButton(
                      key: const Key('profile.editIntro'),
                      icon: Symbols.edit,
                      tooltip: 'Edit intro',
                      onPressed: onEditIntro,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: Text(name, style: AccountText.name)),
                        if (verified) ...[
                          const SizedBox(width: 6),
                          const Icon(Symbols.verified, fill: 0, weight: 600, size: 20, color: AppColors.primary, semanticLabel: 'Email confirmed'),
                        ],
                      ],
                    ),
                    if (roleLabel != null) AccountChip(label: roleLabel!),
                  ],
                ),
                if (headline != null) ...[
                  const SizedBox(height: 4),
                  Text(headline!, style: AccountText.headline),
                ],
                if (place != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2, right: 3),
                        child: Icon(Symbols.location_on, fill: 1, size: 14, color: AppColors.slate400),
                      ),
                      Expanded(child: Text(place!, style: AccountText.meta)),
                    ],
                  ),
                ],
                if (facts.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(facts.join(' · '), style: AccountText.meta),
                ],
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6, children: chips),
                ],
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 8, children: actions),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({super.key, required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(width: 36, height: 36, child: Icon(icon, size: 19, color: AppColors.primary)),
        ),
      ),
    );
  }
}

/// A pill button under the header: outlined, or the blue one that is on.
class PillAction extends StatelessWidget {
  const PillAction({super.key, required this.label, required this.onPressed, this.icon, this.filled = false, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool filled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final ink = filled ? Colors.white : AppColors.primary;
    final shape = StadiumBorder(side: BorderSide(color: filled ? AppColors.primary : AppColors.slate300));
    return Opacity(
      opacity: onPressed == null && !busy ? 0.5 : 1,
      child: Material(
        color: filled ? AppColors.primary : Colors.white,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: busy ? null : onPressed,
          child: SizedBox(
            height: 36,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busy)
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: ink))
                  else if (icon != null)
                    Icon(icon, size: 17, color: ink),
                  if (busy || icon != null) const SizedBox(width: 6),
                  Text(label, style: AppText.workSans(13, FontWeight.w600, ink, lineHeight: 18)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A section card: a title, an add (+) and a pencil when the person may edit,
/// and the section's content or its loading and failed states.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.onAdd,
    this.addLabel,
    this.onEdit,
    this.editLabel,
    this.loading = false,
    this.extraAction,
  });

  final String title;
  final Widget child;
  final VoidCallback? onAdd;
  final String? addLabel;
  final VoidCallback? onEdit;
  final String? editLabel;
  final bool loading;

  /// Another icon button beside the plus (add a career break).
  final Widget? extraAction;

  @override
  Widget build(BuildContext context) {
    return AccountCard(
      title: title,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?extraAction,
          if (onAdd != null) CardIconButton(icon: Icons.add_rounded, tooltip: addLabel ?? 'Add', onPressed: onAdd),
          if (onEdit != null) CardIconButton(icon: Symbols.edit, tooltip: editLabel ?? 'Edit', onPressed: onEdit),
        ],
      ),
      child: loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          : child,
    );
  }
}

/// "Couldn't load your experience. Try again."
class SectionLoadError extends StatelessWidget {
  const SectionLoadError({super.key, required this.what, required this.message, required this.onRetry});

  final String what;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Couldn't load your $what.", style: AccountText.error),
        const SizedBox(height: 2),
        Text(message, style: AccountText.meta),
        TextButton(
          key: Key('retry.$what'),
          onPressed: onRetry,
          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36), alignment: Alignment.centerLeft),
          child: Text('Try again', style: AccountText.link),
        ),
      ],
    );
  }
}

/// One row of a list section: something on the left, the text, and a pencil.
class ItemRow extends StatelessWidget {
  const ItemRow({super.key, required this.child, this.leading, this.onEdit, this.editLabel, this.onTap, this.divider = true});

  final Widget child;
  final Widget? leading;
  final VoidCallback? onEdit;
  final String? editLabel;

  /// The whole row opens something (a certificate).
  final VoidCallback? onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(child: child),
          if (onEdit != null)
            CardIconButton(icon: Symbols.edit, tooltip: editLabel ?? 'Edit', onPressed: onEdit)
          else if (onTap != null)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Icon(Icons.chevron_right_rounded, color: AppColors.slate400),
            ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (divider) const Divider(height: 1, thickness: 1, color: AppColors.slate100),
        onTap == null ? row : InkWell(onTap: onTap, child: row),
      ],
    );
  }
}

/// Text that stops at [maxLines] with "See more" / "See less" when it is longer.
class ClampedText extends StatefulWidget {
  const ClampedText(this.text, {super.key, this.maxLines = 4, this.style});

  final String text;
  final int maxLines;
  final TextStyle? style;

  @override
  State<ClampedText> createState() => _ClampedTextState();
}

class _ClampedTextState extends State<ClampedText> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? AccountText.body;
    return LayoutBuilder(
      builder: (context, box) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: widget.maxLines,
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: box.maxWidth);
        final overflows = painter.didExceedMaxLines;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: style,
              maxLines: _open ? null : widget.maxLines,
              overflow: _open ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            if (overflows)
              GestureDetector(
                key: const Key('clamp.toggle'),
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _open = !_open),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 2),
                  child: Text(_open ? 'See less' : 'See more', style: AccountText.link),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A row of outlined chips (skills, languages).
class ChipWrap extends StatelessWidget {
  const ChipWrap(this.items, {super.key});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.slate300),
            ),
            child: Text(s, style: AccountText.chip.copyWith(fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}

/// "Shown on your public profile": under a section the public page also shows.
class PublicNote extends StatelessWidget {
  const PublicNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          const Icon(Symbols.public, size: 15, color: AppColors.slate500),
          const SizedBox(width: 5),
          Expanded(child: Text(text, style: AccountText.meta.copyWith(fontSize: 13))),
        ],
      ),
    );
  }
}

// --- career rows ---------------------------------------------------------------------------------------------

/// A role: the employer's logo, the title, "Organisation · Full-time", the
/// dates with how long, the place, and what they did.
class ExperienceTile extends StatelessWidget {
  const ExperienceTile({super.key, required this.role, this.now});

  final Experience role;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final kind = employmentTypeLabel(role.employmentType);
    final employer = [role.organisation, ?kind].join(' · ');
    final range = careerRange(
      startYear: role.startYear,
      startMonth: role.startMonth,
      endYear: role.endYear,
      endMonth: role.endMonth,
      current: role.isCurrent,
      now: now,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CompanyLogo(url: role.logoUrl, name: role.organisation, size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(role.title, style: AccountText.itemTitle),
              const SizedBox(height: 1),
              Text(employer, style: AccountText.body.copyWith(fontWeight: FontWeight.w500)),
              const SizedBox(height: 1),
              Text(range, style: AccountText.meta),
              if (role.city != null) Text(role.city!, style: AccountText.meta),
              if (role.description != null) ...[const SizedBox(height: 6), ClampedText(role.description!, maxLines: 3)],
            ],
          ),
        ),
      ],
    );
  }
}

/// A pause in a career, drawn quieter than a role.
class CareerBreakTile extends StatelessWidget {
  const CareerBreakTile({super.key, required this.pause, this.now});

  final CareerBreak pause;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final range = careerRange(
      startYear: pause.startYear,
      startMonth: pause.startMonth,
      endYear: pause.endYear,
      endMonth: pause.endMonth,
      current: pause.isCurrent,
      now: now,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.slate200)),
          child: const Icon(Symbols.more_time, size: 22, color: AppColors.slate500),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Career break · ${careerBreakLabel(pause.reason)}', style: AccountText.itemTitle.copyWith(color: AppColors.slate600)),
              const SizedBox(height: 1),
              Text(range, style: AccountText.meta),
              if (pause.description != null) ...[const SizedBox(height: 6), ClampedText(pause.description!, maxLines: 3)],
            ],
          ),
        ),
      ],
    );
  }
}

/// A qualification: the institution, "B.Tech · Mechanical Engineering", the years.
class EducationTile extends StatelessWidget {
  const EducationTile({super.key, required this.education});

  final Education education;

  @override
  Widget build(BuildContext context) {
    final e = education;
    final line = [?e.degree, ?e.fieldOfStudy].join(' · ');
    final years = e.startYear == null && e.endYear == null
        ? null
        : [if (e.startYear != null) '${e.startYear}', if (e.endYear != null) '${e.endYear}' else if (e.startYear != null) 'Present']
              .join(' – ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.slate200)),
          child: const Icon(Symbols.school, size: 22, color: AppColors.slate500),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.institution, style: AccountText.itemTitle),
              if (e.university != null) Text(e.university!, style: AccountText.body.copyWith(fontWeight: FontWeight.w500)),
              if (line.isNotEmpty) Text(line, style: AccountText.body.copyWith(fontWeight: FontWeight.w500)),
              if (years != null) Text(years, style: AccountText.meta),
              if (e.grade != null) Text('Grade: ${e.grade}', style: AccountText.meta),
            ],
          ),
        ),
      ],
    );
  }
}

/// The chip a credential wears: who vouches for it.
(Color, Color)? credentialTone(Credential c) {
  if (!c.editable) return AccountChip.green;
  return switch (c.status) {
    'VERIFIED' => AccountChip.green,
    'PENDING' => AccountChip.amber,
    'REJECTED' => AccountChip.red,
    _ => null,
  };
}

/// A certificate or licence: the name and code, the issuer and date, and a chip
/// for who vouches for it.
class CredentialTile extends StatelessWidget {
  const CredentialTile({super.key, required this.credential});

  final Credential credential;

  @override
  Widget build(BuildContext context) {
    final c = credential;
    final issued = monthYear(c.issuedAt);
    final expires = monthYear(c.expiresAt);
    final tone = credentialTone(c);
    final label = c.editable ? c.statusLabel : c.sourceLabel;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: c.editable ? AppColors.slate50 : AppColors.emerald50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.editable ? AppColors.slate200 : AppColors.emerald200),
          ),
          child: Icon(Symbols.workspace_premium, size: 23, color: c.editable ? AppColors.slate500 : AppColors.emerald700),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.code == null ? c.name : '${c.name} (${c.code})', style: AccountText.itemTitle),
              if (c.issuer != null) Text(c.issuer!, style: AccountText.body.copyWith(fontWeight: FontWeight.w500)),
              if (issued.isNotEmpty)
                Text(
                  expires.isEmpty ? 'Issued $issued' : 'Issued $issued · ${c.expired ? 'Expired' : 'Expires'} $expires',
                  style: AccountText.meta,
                ),
              if (label != null || c.expired) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (label != null)
                      AccountChip(
                        label: label,
                        color: tone?.$1 ?? AppColors.slate100,
                        ink: tone?.$2 ?? AppColors.slate700,
                        icon: tone == AccountChip.green ? Symbols.verified : null,
                      ),
                    if (c.expired) const AccountChip(label: 'Expired', color: Color(0xFFFFE4E6), ink: Color(0xFFBE123C)),
                  ],
                ),
              ],
              if (c.reviewNote != null && c.status == 'REJECTED') ...[
                const SizedBox(height: 6),
                Text(c.reviewNote!, style: AccountText.error),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A person's initials from their names.
String initialsOfPerson(String first, String last, {String fallback = '?'}) {
  final f = first.isNotEmpty ? first.characters.first : '';
  final l = last.isNotEmpty ? last.characters.first : '';
  final both = '$f$l'.toUpperCase();
  return both.isEmpty ? fallback : both;
}
