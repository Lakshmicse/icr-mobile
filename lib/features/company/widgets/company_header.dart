import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../account/account_labels.dart' show industryLabel;
import '../../account/profile/profile_kit.dart' show PillAction;
import '../../account/widgets/account_kit.dart' show CompanyLogo;
import '../../site/site_kit.dart';
import '../company_fields.dart';
import '../company_models.dart';
import '../company_words.dart';
import 'company_kit.dart';

/// The company the page edits, named once at the top: its logo (a camera on it for whoever may change it), the
/// eyebrow, its name, its trust mark, the facts a visitor reads first, and the way out to its public page.
///
/// Trust reads two separate answers, as the website's header does: a company that sells shows its supplier level
/// (the listing's, never the company row's, which the company check writes through to); one that does not sell
/// shows the company check, when it has passed.
class CompanyHeader extends StatelessWidget {
  const CompanyHeader({
    super.key,
    required this.profile,
    this.gate,
    this.standing,
    this.onViewPublic,
    this.onSwitch,
    this.onEditLogo,
    this.logoBusy = false,
  });

  final CompanyProfile profile;
  final EmployerGate? gate;
  final CompanyStanding? standing;
  final VoidCallback? onViewPublic;
  final VoidCallback? onSwitch;
  final VoidCallback? onEditLogo;
  final bool logoBusy;

  @override
  Widget build(BuildContext context) {
    final company = profile.company;
    final sells = profile.sells;
    final level = sells ? profile.vendor?.verificationLevel : null;
    final verified = !sells && (gate?.verified ?? false);
    final facts = <String>[
      ?industryLabel(company?.industry),
      ?companySizeLabel(company?.size),
      ?company?.city,
      if (company?.website case final w?) bareHost(w),
    ];
    final others = (standing?.companiesHeld ?? 0) > 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Logo(company: company, onEdit: onEditLogo, busy: logoBusy),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(CompanyWords.eyebrow, style: CompanyText.eyebrow),
                    const SizedBox(height: 2),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(company?.name ?? CompanyWords.yourCompany, style: SiteText.title),
                        if (level != null) LevelBadge(level: level, small: true),
                        if (verified)
                          const StatusChip(CompanyWords.verifiedChip, tone: StatusTone.success, icon: Symbols.verified),
                      ],
                    ),
                    if (facts.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(facts.join(' · '), key: const ValueKey('company-facts'), style: SiteText.secondary),
                    ],
                    const SizedBox(height: 4),
                    Text(company == null ? CompanyWords.createNote : CompanyWords.sharedNote, style: SiteText.meta),
                  ],
                ),
              ),
            ],
          ),
          if ((company != null && onViewPublic != null) || (others && onSwitch != null)) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (company != null && onViewPublic != null)
                  PillAction(
                    key: const ValueKey('company-view-public'),
                    label: CompanyWords.viewPublicProfile,
                    icon: Symbols.open_in_new,
                    onPressed: onViewPublic,
                  ),
                if (others && onSwitch != null)
                  PillAction(
                    key: const ValueKey('company-switch'),
                    label: CompanyWords.switchCompany,
                    icon: Symbols.swap_horiz,
                    onPressed: onSwitch,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.company, required this.onEdit, required this.busy});

  final CompanyDetails? company;
  final VoidCallback? onEdit;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final logo = CompanyLogo(url: company?.logoUrl, name: company?.name ?? '', size: 64);
    if (onEdit == null) return logo;
    return Semantics(
      button: true,
      label: company?.logoUrl == null ? CompanyWords.addLogo : CompanyWords.changeLogo,
      child: GestureDetector(
        key: const ValueKey('company-logo'),
        onTap: busy ? null : onEdit,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            logo,
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: busy
                    ? const Padding(
                        padding: EdgeInsets.all(5),
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Symbols.photo_camera, size: 12, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
