/// A company's identity, defined once — the app's copy of `packages/shared/src/company-fields.ts`,
/// `company-documents.ts` and `employer-kyc.ts`: what each field is called, which section it sits in, whether the
/// company check needs it, whether a verified company may still change it (and the sentence the API refuses with),
/// and what the check still needs from the profile.
library;

import '../account/companies/create_company_controller.dart' show CompanyDocument, needsIncorporationProof;
import 'company_models.dart';

enum CompanyFieldKey {
  name,
  legalName,
  legalStructure,
  incorporationDoc,
  industry,
  size,
  foundedYear,
  gstNumber,
  gstDoc,
  panNumber,
  panDoc,
  description,
  logoUrl,
  website,
  addressLine,
  city,
  state,
  postalCode,
  country,
  presence,
  email,
  phone,
  contactName,
  contactDesignation,
  contactAltPhone,
}

/// The wizard's step order; the identity tab renders in it too.
enum CompanyFieldSection { details, registration, location, contact }

/// How a field behaves once a reviewer has approved the company's identity: freely editable, frozen (GST, PAN), or
/// frozen only once a value is recorded (the registered name, the organisation type).
enum CompanyFieldLock { never, always, onceSet }

class CompanyFieldSpec {
  const CompanyFieldSpec({
    required this.key,
    required this.label,
    required this.section,
    this.helper,
    this.requiredAtOnboarding = false,
    this.requiredForKyc = false,
    this.lock = CompanyFieldLock.never,
    this.lockedMessage,
  });

  final CompanyFieldKey key;

  /// The one label every surface uses.
  final String label;
  final String? helper;
  final CompanyFieldSection section;
  final bool requiredAtOnboarding;
  final bool requiredForKyc;
  final CompanyFieldLock lock;

  /// The sentence the API refuses with, so the form can disable with the same words.
  final String? lockedMessage;
}

const lockedTaxIdsMessage = 'GST and PAN are locked once your company is verified. Contact support to change them.';

const companyFields = <CompanyFieldKey, CompanyFieldSpec>{
  // ---- Company details --------------------------------------------------
  CompanyFieldKey.name: CompanyFieldSpec(
    key: CompanyFieldKey.name,
    label: 'Company Name',
    section: CompanyFieldSection.details,
    helper: 'The brand buyers and candidates know you by.',
    requiredAtOnboarding: true,
  ),
  CompanyFieldKey.website: CompanyFieldSpec(
    key: CompanyFieldKey.website,
    label: 'Company Website',
    section: CompanyFieldSection.details,
    helper: 'Optional — acme.com or https://acme.com',
  ),
  CompanyFieldKey.industry: CompanyFieldSpec(
    key: CompanyFieldKey.industry,
    label: 'Industry',
    section: CompanyFieldSection.details,
    requiredAtOnboarding: true,
  ),
  CompanyFieldKey.size: CompanyFieldSpec(
    key: CompanyFieldKey.size,
    label: 'Company Size',
    section: CompanyFieldSection.details,
    requiredAtOnboarding: true,
  ),
  CompanyFieldKey.foundedYear: CompanyFieldSpec(
    key: CompanyFieldKey.foundedYear,
    label: 'Year of Establishment',
    section: CompanyFieldSection.details,
  ),
  CompanyFieldKey.description: CompanyFieldSpec(
    key: CompanyFieldKey.description,
    label: 'Short description about your company',
    section: CompanyFieldSection.details,
    helper: 'Buyers and candidates read this first.',
  ),
  CompanyFieldKey.logoUrl: CompanyFieldSpec(
    key: CompanyFieldKey.logoUrl,
    label: 'Company Logo',
    section: CompanyFieldSection.details,
  ),

  // ---- Legal identity ---------------------------------------------------
  CompanyFieldKey.legalName: CompanyFieldSpec(
    key: CompanyFieldKey.legalName,
    label: 'Registered Legal Name',
    section: CompanyFieldSection.registration,
    helper: 'The legal entity, exactly as on the PAN card. Leave blank if it is the same as the company name.',
    requiredForKyc: true,
    lock: CompanyFieldLock.onceSet,
    lockedMessage: 'The registered name is locked once your company is verified. Contact support to change it.',
  ),
  CompanyFieldKey.legalStructure: CompanyFieldSpec(
    key: CompanyFieldKey.legalStructure,
    label: 'Organisation Type',
    section: CompanyFieldSection.registration,
    helper: 'How the organisation is incorporated. It decides which registration certificate we ask for.',
    requiredAtOnboarding: true,
    requiredForKyc: true,
    lock: CompanyFieldLock.onceSet,
    lockedMessage: 'The organisation type is locked once your company is verified. Contact support to change it.',
  ),
  CompanyFieldKey.incorporationDoc: CompanyFieldSpec(
    key: CompanyFieldKey.incorporationDoc,
    label: 'Registration Certificate',
    section: CompanyFieldSection.registration,
    helper: 'Only ICR’s review team and your own company admins can open it.',
  ),
  CompanyFieldKey.panNumber: CompanyFieldSpec(
    key: CompanyFieldKey.panNumber,
    label: 'PAN',
    section: CompanyFieldSection.registration,
    helper: 'The company’s Permanent Account Number, as printed on the PAN card.',
    requiredForKyc: true,
    lock: CompanyFieldLock.always,
    lockedMessage: lockedTaxIdsMessage,
  ),
  CompanyFieldKey.panDoc: CompanyFieldSpec(
    key: CompanyFieldKey.panDoc,
    label: 'PAN Card',
    section: CompanyFieldSection.registration,
    helper: 'Required with the PAN. Only ICR’s review team and your own company admins can open it.',
    lock: CompanyFieldLock.always,
    lockedMessage: lockedTaxIdsMessage,
  ),
  CompanyFieldKey.gstNumber: CompanyFieldSpec(
    key: CompanyFieldKey.gstNumber,
    label: 'GSTIN',
    section: CompanyFieldSection.registration,
    helper: 'Optional here — a business below the threshold has none. Needed to verify the company.',
    requiredForKyc: true,
    lock: CompanyFieldLock.always,
    lockedMessage: lockedTaxIdsMessage,
  ),
  CompanyFieldKey.gstDoc: CompanyFieldSpec(
    key: CompanyFieldKey.gstDoc,
    label: 'GST Certificate',
    section: CompanyFieldSection.registration,
    helper: 'Required once a GSTIN is entered. Only ICR’s review team and your own company admins can open it.',
    lock: CompanyFieldLock.always,
    lockedMessage: lockedTaxIdsMessage,
  ),

  // ---- Location & reach -------------------------------------------------
  CompanyFieldKey.addressLine: CompanyFieldSpec(
    key: CompanyFieldKey.addressLine,
    label: 'Street Address',
    section: CompanyFieldSection.location,
    requiredForKyc: true,
  ),
  CompanyFieldKey.city: CompanyFieldSpec(
    key: CompanyFieldKey.city,
    label: 'City',
    section: CompanyFieldSection.location,
    helper: 'Where the head office is.',
    requiredAtOnboarding: true,
    requiredForKyc: true,
  ),
  CompanyFieldKey.state: CompanyFieldSpec(
    key: CompanyFieldKey.state,
    label: 'State',
    section: CompanyFieldSection.location,
  ),
  CompanyFieldKey.postalCode: CompanyFieldSpec(
    key: CompanyFieldKey.postalCode,
    label: 'PIN Code',
    section: CompanyFieldSection.location,
  ),
  CompanyFieldKey.country: CompanyFieldSpec(
    key: CompanyFieldKey.country,
    label: 'Country',
    section: CompanyFieldSection.location,
  ),
  CompanyFieldKey.presence: CompanyFieldSpec(
    key: CompanyFieldKey.presence,
    label: 'Where you operate',
    section: CompanyFieldSection.location,
  ),

  // ---- Who to contact ---------------------------------------------------
  CompanyFieldKey.email: CompanyFieldSpec(
    key: CompanyFieldKey.email,
    label: 'Work Email',
    section: CompanyFieldSection.contact,
    helper: 'On your company’s own domain. Verification and billing correspondence goes here.',
    requiredForKyc: true,
  ),
  CompanyFieldKey.phone: CompanyFieldSpec(
    key: CompanyFieldKey.phone,
    label: 'Phone',
    section: CompanyFieldSection.contact,
  ),
  CompanyFieldKey.contactName: CompanyFieldSpec(
    key: CompanyFieldKey.contactName,
    label: 'Contact Person',
    section: CompanyFieldSection.contact,
  ),
  CompanyFieldKey.contactDesignation: CompanyFieldSpec(
    key: CompanyFieldKey.contactDesignation,
    label: 'Designation',
    section: CompanyFieldSection.contact,
  ),
  CompanyFieldKey.contactAltPhone: CompanyFieldSpec(
    key: CompanyFieldKey.contactAltPhone,
    label: 'Alternative Contact Number',
    section: CompanyFieldSection.contact,
    helper: 'A second number, if the main line is busy.',
  ),
};

/// The sections' titles and blurbs (`COMPANY_FIELD_SECTIONS`), in the wizard's order.
const companyFieldSections = <(CompanyFieldSection, String, String)>[
  (
    CompanyFieldSection.details,
    'Company details',
    'The basics about the organisation — what buyers and candidates read first.',
  ),
  (
    CompanyFieldSection.registration,
    'Legal identity',
    'How the company is registered, exactly as on the PAN card. Verification reads these.',
  ),
  (CompanyFieldSection.location, 'Location & reach', 'Where the head office is and where the company operates.'),
  (
    CompanyFieldSection.contact,
    'Who to contact',
    'The person ICR and buyers should reach. Never shown on your public profile.',
  ),
];

String sectionTitle(CompanyFieldSection s) => companyFieldSections.firstWhere((x) => x.$1 == s).$2;
String sectionBlurb(CompanyFieldSection s) => companyFieldSections.firstWhere((x) => x.$1 == s).$3;

/// The fields of one section, in display order.
List<CompanyFieldSpec> companyFieldsIn(CompanyFieldSection section) => [
  for (final f in companyFields.values)
    if (f.section == section) f,
];

/// The documents, each the field key it is listed under, the two columns it is stored in, and the KYC slot it fills.
const companyDocuments = <(CompanyDocument, CompanyFieldKey, String, String, String)>[
  (
    CompanyDocument.incorporationDoc,
    CompanyFieldKey.incorporationDoc,
    'incorporationDocUrl',
    'incorporationDocName',
    'INCORPORATION_PROOF',
  ),
  (CompanyDocument.gstDoc, CompanyFieldKey.gstDoc, 'gstDocUrl', 'gstDocName', 'GST_CERTIFICATE'),
  (CompanyDocument.panDoc, CompanyFieldKey.panDoc, 'panDocUrl', 'panDocName', 'PAN_CARD'),
];

CompanyDocument? documentOf(CompanyFieldKey key) {
  for (final d in companyDocuments) {
    if (d.$2 == key) return d.$1;
  }
  return null;
}

CompanyFieldKey fieldOfDocument(CompanyDocument doc) => companyDocuments.firstWhere((d) => d.$1 == doc).$2;
String documentUrlColumn(CompanyDocument doc) => companyDocuments.firstWhere((d) => d.$1 == doc).$3;
String documentNameColumn(CompanyDocument doc) => companyDocuments.firstWhere((d) => d.$1 == doc).$4;
String documentKind(CompanyDocument doc) => companyDocuments.firstWhere((d) => d.$1 == doc).$5;

CompanyDocument? documentForKind(String kind) {
  for (final d in companyDocuments) {
    if (d.$5 == kind) return d.$1;
  }
  return null;
}

/// The `Company` column a field key reads and writes: its own name, except a document, which is looked up by its URL.
String companyFieldColumn(CompanyFieldKey key) {
  final doc = documentOf(key);
  return doc == null ? key.name : documentUrlColumn(doc);
}

bool _blank(String? v) => v == null || v.trim().isEmpty;

/// Whether a verified company may no longer change this field. Mirrors `CompaniesService.upsertMine`, which refuses
/// the save with the field's `lockedMessage`; the form disables the input with the same sentence so nobody finds out
/// after typing everything else. [unlocked]: the documents an open re-verification request lets through.
bool isCompanyFieldLocked(
  CompanyFieldKey key,
  CompanyDetails? company, {
  Iterable<CompanyFieldKey> unlocked = const [],
}) {
  if (company == null || company.verificationStatus != 'VERIFIED') return false;
  if (unlocked.contains(key)) return false;
  final spec = companyFields[key]!;
  return switch (spec.lock) {
    CompanyFieldLock.never => false,
    CompanyFieldLock.always => true,
    CompanyFieldLock.onceSet => !_blank(company.text(companyFieldColumn(key))),
  };
}

/// The company-profile fields the check snapshots, in the order the summary shows them.
const kycProfileFields = <CompanyFieldKey>[
  CompanyFieldKey.legalName,
  CompanyFieldKey.legalStructure,
  CompanyFieldKey.panNumber,
  CompanyFieldKey.gstNumber,
  CompanyFieldKey.addressLine,
  CompanyFieldKey.city,
  CompanyFieldKey.state,
  CompanyFieldKey.postalCode,
  CompanyFieldKey.country,
  CompanyFieldKey.email,
  CompanyFieldKey.phone,
  CompanyFieldKey.website,
];

/// Which KYC-required fields the profile does not hold yet. GSTIN drops out when the company attests it is not
/// registered for GST.
List<CompanyFieldKey> missingKycFields(CompanyDetails? company, {bool gstNotRegistered = false}) => [
  for (final key in kycProfileFields)
    if (companyFields[key]!.requiredForKyc &&
        !(key == CompanyFieldKey.gstNumber && gstNotRegistered) &&
        _blank(company?.text(companyFieldColumn(key))))
      key,
];

/// Whether this company must have the document on file: a GST certificate only once there is a GSTIN, a PAN card
/// whenever there is a PAN, the registration certificate only for a structure that has one.
bool companyDocumentRequired(CompanyDocument doc, {String? legalStructure, String? gstNumber, String? panNumber}) =>
    switch (doc) {
      CompanyDocument.incorporationDoc => needsIncorporationProof(legalStructure),
      CompanyDocument.gstDoc => !_blank(gstNumber),
      CompanyDocument.panDoc => !_blank(panNumber),
    };

/// The document kinds this dossier must carry, in the order the form shows them (`requiredEmployerDocuments`).
List<String> requiredEmployerDocuments(String? legalStructure, {bool gstNotRegistered = false}) => [
  'PAN_CARD',
  if (!gstNotRegistered) 'GST_CERTIFICATE',
  if (needsIncorporationProof(legalStructure)) 'INCORPORATION_PROOF',
];

/// The document fields an open re-verification request unlocks on a verified company (`reverifyUnlockedFields`).
List<CompanyFieldKey> reverifyUnlockedFields(ReverifyRequest? reverify) {
  if (reverify == null || !reverify.open) return const [];
  return [
    for (final kind in reverify.documents)
      if (documentForKind(kind) case final doc?) fieldOfDocument(doc),
  ];
}

/// One thing the company check reads, in the order the form shows it.
class KycChecklistItem {
  const KycChecklistItem({required this.key, required this.done, this.documentKind});

  /// A company field (`legalName`) or document (`panDoc`): the form's own key, so a row can open its section.
  final CompanyFieldKey key;

  /// For a document, the dossier slot it fills.
  final String? documentKind;
  final bool done;

  bool get isDocument => documentKind != null;
}

const _kycOrder = <CompanyFieldKey>[
  CompanyFieldKey.legalName,
  CompanyFieldKey.legalStructure,
  CompanyFieldKey.incorporationDoc,
  CompanyFieldKey.panNumber,
  CompanyFieldKey.panDoc,
  CompanyFieldKey.gstNumber,
  CompanyFieldKey.gstDoc,
  CompanyFieldKey.addressLine,
  CompanyFieldKey.city,
  CompanyFieldKey.email,
];

/// Every fact and document the company check needs, each marked done or not — `missingKycFields` for the facts,
/// `requiredEmployerDocuments` for the documents, read from the profile's own uploads.
List<KycChecklistItem> kycChecklist(CompanyDetails? company, {bool gstNotRegistered = false}) {
  final missing = missingKycFields(company, gstNotRegistered: gstNotRegistered).toSet();
  final items = <KycChecklistItem>[
    for (final key in kycProfileFields)
      if (companyFields[key]!.requiredForKyc && !(key == CompanyFieldKey.gstNumber && gstNotRegistered))
        KycChecklistItem(key: key, done: !missing.contains(key)),
    for (final kind in requiredEmployerDocuments(company?.legalStructure, gstNotRegistered: gstNotRegistered))
      if (documentForKind(kind) case final doc?)
        KycChecklistItem(
          key: fieldOfDocument(doc),
          documentKind: kind,
          done: !_blank(company?.text(documentUrlColumn(doc))),
        ),
  ];
  items.sort((a, b) => _kycOrder.indexOf(a.key).compareTo(_kycOrder.indexOf(b.key)));
  return items;
}

/// What a re-verification request still needs: only the documents ICR asked for, each done once the profile holds a
/// different file from the one on the dossier — the API refuses the same file sent again.
List<KycChecklistItem> reverifyChecklist(
  CompanyDetails? company,
  ReverifyRequest reverify,
  List<DossierDocument> filed,
) => [
  for (final kind in reverify.documents)
    if (documentForKind(kind) case final doc?)
      KycChecklistItem(
        key: fieldOfDocument(doc),
        documentKind: kind,
        done: () {
          final url = company?.text(documentUrlColumn(doc));
          final before = filed.where((d) => d.kind == kind).firstOrNull?.url;
          return url != null && url != before;
        }(),
      ),
];

/// The dossier the API files, composed from the company profile (`dossierFromCompany`).
EmployerDossierDraft dossierFromCompany(CompanyDetails? company, {bool gstNotRegistered = false}) {
  String? read(String column) => company?.text(column);
  return EmployerDossierDraft(
    legalName: read('legalName') ?? '',
    legalStructure: read('legalStructure') ?? '',
    panNumber: read('panNumber')?.toUpperCase() ?? '',
    gstNotRegistered: gstNotRegistered,
    gstNumber: gstNotRegistered ? null : read('gstNumber')?.toUpperCase(),
    addressLine: read('addressLine') ?? '',
    city: read('city') ?? '',
    state: read('state'),
    postalCode: read('postalCode'),
    country: read('country') ?? 'India',
    website: read('website'),
    contactEmail: read('email') ?? '',
    contactPhone: read('phone'),
    documents: [
      for (final kind in requiredEmployerDocuments(company?.legalStructure, gstNotRegistered: gstNotRegistered))
        if (documentForKind(kind) case final doc?)
          if (read(documentUrlColumn(doc)) case final url?)
            DossierDocument(kind: kind, url: url, name: read(documentNameColumn(doc))),
    ],
  );
}

/// The filing that answers a re-verification: the profile's documents and contact details, with the verified facts
/// taken from the approved dossier, since they are locked and the API checks they did not change.
EmployerDossierDraft dossierForReverification(CompanyDetails? company, EmployerDossier dossier) {
  final base = dossierFromCompany(company, gstNotRegistered: dossier.gstNotRegistered);
  return EmployerDossierDraft(
    legalName: dossier.legalName,
    legalStructure: dossier.legalStructure ?? '',
    panNumber: dossier.panNumber,
    gstNotRegistered: dossier.gstNotRegistered,
    gstNumber: dossier.gstNotRegistered ? null : dossier.gstNumber,
    addressLine: base.addressLine,
    city: base.city,
    state: base.state,
    postalCode: base.postalCode,
    country: base.country,
    website: base.website,
    contactEmail: base.contactEmail,
    contactPhone: base.contactPhone,
    documents: base.documents,
  );
}

/// Whether the company may (re)file in this state — never while ICR is reviewing, nor once verified, unless ICR asked
/// a verified company to re-verify and it has not sent the documents yet.
bool canFileInState(String? status, ReverifyRequest? reverify) =>
    status == 'VERIFIED' ? (reverify?.open ?? false) : status != 'SUBMITTED';

/// The roles the API's submit route takes: who may file the company check.
const kycFilers = {'COMPANY_ADMIN', 'SUPER_ADMIN'};

/// Who may edit the company profile (`COMPANY_PROFILE_EDITORS`): the same list `PATCH /companies/me` guards on.
const companyProfileEditors = {'SUPER_ADMIN', 'COMPANY_ADMIN', 'VENDOR', 'BUYER'};

/// The roles that run the company's team (`TEAM_MANAGER_ROLES`): the website shows them the Team tab.
const teamManagerRoles = {'COMPANY_ADMIN', 'BRANCH_ADMIN', 'VENDOR', 'SUPER_ADMIN'};

/// The roles that run the company's workspace pages (team, offices, catalogue).
const workspaceRoles = {'VENDOR', 'COMPANY_ADMIN', 'SUPER_ADMIN'};

/// The roles that hire for the company (`RECRUITER_TIER`).
const recruiterTier = {'SUPER_ADMIN', 'COMPANY_ADMIN', 'BRANCH_ADMIN', 'RECRUITER'};

/// The roles `POST /vendors` accepts: who may start selling.
const canStartSellingRoles = {'VENDOR', 'COMPANY_ADMIN', 'SUPER_ADMIN'};

/// ICR staff roles: personal accounts that neither create nor join companies.
const platformRoles = {'SUPER_ADMIN', 'LEARNING_ADMIN', 'PARTNER_ADMIN'};

/// `EMPLOYER_VERIFICATION_STATUS_LABELS`.
const employerVerificationStatusLabels = {
  'SUBMITTED': 'Under Review',
  'DOCS_REQUESTED': 'More Information Needed',
  'VERIFIED': 'Verified',
  'REJECTED': 'Not Approved',
  'SUSPENDED': 'Verification Withdrawn',
};

/// `COMPANY_ACTION_REASON_LABELS`.
const companyActionReasonLabels = {
  'DOCUMENT_EXPIRED': 'A document has expired',
  'DOCUMENT_UNREADABLE': 'A document could not be read',
  'DETAILS_MISMATCH': 'Details do not match the documents',
  'REPORTED': 'Reported by ICR members',
  'POLICY_BREACH': 'A breach of ICR’s terms',
  'OTHER': 'Another reason',
  'REVERIFY_OVERDUE': 'Re-verification not received in time',
};

/// `PRESENCE_LABELS`, in the order offered (`ONBOARDING_COVERAGE`).
const presenceOptions = <(String, String)>[('LOCAL', 'Local'), ('PAN_INDIA', 'Pan-India'), ('GLOBAL', 'Global')];

String? presenceLabel(String? key) {
  for (final (k, label) in presenceOptions) {
    if (k == key) return label;
  }
  return key;
}

/// `COMPANY_SIZE_LABELS`: "1–10 employees".
String? companySizeLabel(String? key) {
  if (key == null) return null;
  const sizes = {'1-10': '1–10', '11-50': '11–50', '51-200': '51–200', '201-500': '201–500', '500+': '500+'};
  final s = sizes[key];
  return s == null ? key : '$s employees';
}

/// `UNVERIFIED_TEAM_MEMBER_CAP` and `UNVERIFIED_TALENT_RESULT_CAP`: what an unverified company is held to.
const unverifiedTeamMemberCap = 3;
const unverifiedTalentResultCap = 20;
