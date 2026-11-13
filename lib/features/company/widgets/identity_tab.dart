import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../account/account_labels.dart' show industryLabel, legalStructures;
import '../../account/companies/create_company_controller.dart'
    show CompanyDocument, documentLabel, needsIncorporationProof;
import '../../account/profile/profile_kit.dart' show PillAction;
import '../../account/widgets/account_kit.dart' show CardIconButton, CompanyLogo;
import '../../site/site_kit.dart';
import '../company_controller.dart';
import '../company_fields.dart';
import '../company_models.dart';
import '../company_words.dart';
import 'company_kit.dart';

/// The company's identity — everything the create-company page asked, in its own sections, read-only and edited in a
/// sheet from each section's pencil (the person's profile does the same). Shared by every member of the company.
/// Labels, the verified-lock rule and the check's needs come from the field table, so this page, the wizard and the
/// company check cannot disagree.
class IdentityTab extends StatelessWidget {
  const IdentityTab({
    super.key,
    required this.controller,
    required this.onEditSection,
    required this.verificationCard,
    this.missingStrip,
    this.onUploadLogo,
    this.logoBusy = false,
  });

  final CompanyController controller;
  final ValueChanged<CompanyFieldSection> onEditSection;

  /// The company check, drawn above the details (the website's order).
  final Widget? verificationCard;

  /// "N details are missing from the company page."
  final Widget? missingStrip;

  /// The logo row's Upload Logo (the website's `ImageUploader` in Company details); no row without it.
  final VoidCallback? onUploadLogo;
  final bool logoBusy;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final company = c.company;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?verificationCard,
        ?missingStrip,
        _section(
          c,
          company,
          CompanyFieldSection.details,
          Symbols.business,
          CompanyWords.detailsTitle,
          CompanyWords.detailsBlurb,
        ),
        _section(
          c,
          company,
          CompanyFieldSection.registration,
          Symbols.gavel,
          CompanyWords.legalTitle,
          CompanyWords.legalBlurb,
        ),
        _section(
          c,
          company,
          CompanyFieldSection.location,
          Symbols.location_on,
          CompanyWords.locationTitle,
          CompanyWords.locationBlurb,
        ),
        _section(
          c,
          company,
          CompanyFieldSection.contact,
          Symbols.contact_mail,
          CompanyWords.contactTitle,
          CompanyWords.contactBlurb,
        ),
      ],
    );
  }

  Widget _section(
    CompanyController c,
    CompanyDetails? company,
    CompanyFieldSection section,
    IconData icon,
    String title,
    String blurb,
  ) {
    final private = section == CompanyFieldSection.registration || section == CompanyFieldSection.contact;
    return CompanySection(
      key: ValueKey('identity-${section.name}'),
      title: title,
      caption: blurb,
      icon: icon,
      trailing: CardIconButton(
        key: ValueKey('identity-edit-${section.name}'),
        icon: Symbols.edit,
        tooltip: 'Edit $title',
        onPressed: () => onEditSection(section),
      ),
      children: [
        if (section == CompanyFieldSection.details && onUploadLogo != null && company != null)
          CompanyRow(
            key: const ValueKey('identity-logo'),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                CompanyLogo(url: company.logoUrl, name: company.name, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(CompanyWords.companyLogo, style: CompanyText.label),
                      const SizedBox(height: 2),
                      Text(CompanyWords.logoHelp, style: SiteText.meta),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                PillAction(
                  key: const ValueKey('identity-upload-logo'),
                  label: logoBusy ? CompanyWords.uploading : CompanyWords.uploadLogo,
                  icon: Symbols.photo_camera,
                  busy: logoBusy,
                  onPressed: onUploadLogo,
                ),
              ],
            ),
          ),
        for (final spec in companyFieldsIn(section))
          if (spec.key != CompanyFieldKey.logoUrl && documentOf(spec.key) == null)
            DetailRow(
              key: ValueKey('identity-${spec.key.name}'),
              label: _label(spec.key),
              value: _value(company, spec.key),
              locked: c.locked(spec.key),
            ),
        if (section == CompanyFieldSection.registration)
          for (final doc in _documents(company?.legalStructure))
            _DocumentRow(controller: c, document: doc, company: company),
        if (section == CompanyFieldSection.registration && c.locked(CompanyFieldKey.panNumber))
          CompanyRow(
            key: const ValueKey('identity-tax-ids-locked'),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Symbols.lock, size: 14, color: AppColors.slate400),
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(CompanyWords.taxIdsLocked, style: SiteText.meta)),
              ],
            ),
          ),
        if (private)
          CompanyRow(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Row(
              children: [
                const Icon(Symbols.lock, size: 14, color: AppColors.slate400),
                const SizedBox(width: 6),
                Expanded(child: Text(CompanyWords.privateNote, style: SiteText.meta)),
              ],
            ),
          ),
      ],
    );
  }

  /// The owner's labels for the fields the review renamed; the field table's for the rest.
  static String _label(CompanyFieldKey key) => switch (key) {
    CompanyFieldKey.addressLine => 'Registered / Office Address',
    CompanyFieldKey.postalCode => 'PIN Code',
    CompanyFieldKey.presence => 'Operating Regions',
    CompanyFieldKey.description => 'Company Description',
    _ => companyFields[key]!.label,
  };

  static String? _value(CompanyDetails? company, CompanyFieldKey key) {
    if (company == null) return null;
    return switch (key) {
      CompanyFieldKey.industry => industryLabel(company.industry),
      CompanyFieldKey.size => companySizeLabel(company.size),
      CompanyFieldKey.legalStructure => legalStructures.where((o) => o.$1 == company.legalStructure).firstOrNull?.$2,
      CompanyFieldKey.presence => presenceLabel(company.presence),
      CompanyFieldKey.foundedYear => company.foundedYear?.toString(),
      _ => company.text(companyFieldColumn(key)),
    };
  }

  /// The documents the registration section lists: the certificate only for a type that has one, then the PAN card
  /// and the GST certificate, each beside the number it proves (the website's order).
  static List<CompanyDocument> _documents(String? structure) => [
    if (needsIncorporationProof(structure)) CompanyDocument.incorporationDoc,
    CompanyDocument.panDoc,
    CompanyDocument.gstDoc,
  ];
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({required this.controller, required this.document, required this.company});

  final CompanyController controller;
  final CompanyDocument document;
  final CompanyDetails? company;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final structure = company?.legalStructure;
    final url = company?.text(documentUrlColumn(document));
    final name = company?.text(documentNameColumn(document));
    final required = companyDocumentRequired(
      document,
      legalStructure: structure,
      gstNumber: company?.gstNumber,
      panNumber: company?.panNumber,
    );
    final key = fieldOfDocument(document);
    final locked = c.locked(key);
    return CompanyRow(
      key: ValueKey('identity-doc-${document.name}'),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            url == null ? Symbols.upload_file : Symbols.task,
            size: 20,
            color: url == null ? AppColors.slate400 : AppColors.emerald700,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(documentLabel(document, structure), style: CompanyText.label),
                const SizedBox(height: 2),
                Text(
                  url == null ? CompanyWords.notUploaded : (name ?? documentLabel(document, structure)),
                  style: url == null
                      ? SiteText.secondary.copyWith(color: required ? AppColors.amber800 : null)
                      : SiteText.body,
                ),
              ],
            ),
          ),
          if (locked)
            const Padding(
              padding: EdgeInsets.only(left: 8, top: 14),
              child: Icon(Symbols.lock, size: 16, color: AppColors.slate400),
            ),
        ],
      ),
    );
  }
}

/// Above the company's details: what its page still lacks, as chips.
class MissingDetailsStrip extends StatelessWidget {
  const MissingDetailsStrip({
    super.key,
    required this.missing,
    required this.onJumpVerification,
    required this.onOpenSitePage,
  });

  final List<String> missing;
  final VoidCallback onJumpVerification;
  final ValueChanged<String> onOpenSitePage;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('missing-details'),
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: SiteColors.blueTint, borderRadius: BorderRadius.circular(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Symbols.info, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(CompanyWords.missingLead(missing.length), style: SiteText.body),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final label in missing)
                      () {
                        final l = label.toLowerCase();
                        final VoidCallback? onTap = l.contains('verif')
                            ? onJumpVerification
                            : l.contains('map') || l.contains('location')
                            ? () => onOpenSitePage('/manage/locations')
                            : null;
                        return InkWell(
                          onTap: onTap,
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: SiteColors.hairline),
                            ),
                            child: Text(label, style: SiteText.meta.copyWith(color: SiteColors.ink)),
                          ),
                        );
                      }(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
