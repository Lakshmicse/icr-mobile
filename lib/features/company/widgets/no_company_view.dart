import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../site/site_kit.dart';
import '../company_fields.dart';
import '../company_models.dart';
import '../company_words.dart';

/// Shown in place of the workspace when the account acts for no company, as the website's `NoCompany`: someone
/// acting as themselves while they belong to companies is offered the switch; anyone else the invite or a new
/// company (ICR staff accounts are personal and cannot found one).
class NoCompanyView extends StatelessWidget {
  const NoCompanyView({
    super.key,
    required this.role,
    required this.onSwitch,
    required this.onCreate,
    required this.onSupport,
    this.standing,
    this.lead = CompanyWords.noCompanyLead,
  });

  final String role;
  final CompanyStanding? standing;
  final String lead;
  final VoidCallback onSwitch;
  final VoidCallback onCreate;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    final held = standing?.companiesHeld ?? 0;
    final canAdd = !platformRoles.contains(role) && (standing?.canJoinCompanies ?? true);
    final switching = held > 0;
    return ListView(
      key: const ValueKey('no-company'),
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
      children: [
        const Icon(Symbols.business, size: 44, color: AppColors.slate400),
        const SizedBox(height: 14),
        Text(
          switching ? CompanyWords.personalAccountTitle : CompanyWords.notLinkedTitle,
          style: SiteText.heading,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          switching
              ? CompanyWords.switchDescription(lead)
              : canAdd
              ? CompanyWords.inviteOrCreateDescription(lead)
              : CompanyWords.inviteDescription(lead),
          style: SiteText.secondary,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        if (switching)
          SiteButton(key: const ValueKey('no-company-switch'), label: CompanyWords.switchCompany, onPressed: onSwitch)
        else ...[
          if (canAdd)
            SiteButton(
              key: const ValueKey('no-company-create'),
              label: CompanyWords.createACompany,
              onPressed: onCreate,
            ),
          if (canAdd) const SizedBox(height: 10),
          SiteButton(
            key: const ValueKey('no-company-support'),
            label: CompanyWords.contactSupportPlain,
            onPressed: onSupport,
            outlined: canAdd,
          ),
        ],
      ],
    );
  }
}

/// A member whose role at the company does not edit its profile (a recruiter, an office admin): the website's
/// "Access denied" for `COMPANY_PROFILE_EDITORS`, said in words.
class NotAnEditorView extends StatelessWidget {
  const NotAnEditorView({super.key, required this.company});

  final String company;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('not-an-editor'),
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
      children: [
        const Icon(Symbols.lock, size: 44, color: AppColors.slate400),
        const SizedBox(height: 14),
        Text(CompanyWords.notAnEditorTitle, style: SiteText.heading, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(CompanyWords.notAnEditorBody(company), style: SiteText.secondary, textAlign: TextAlign.center),
      ],
    );
  }
}
