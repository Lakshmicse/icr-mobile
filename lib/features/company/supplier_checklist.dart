/// The supplier trust ladder's per-level checklist, defined once — the app's copy of
/// `packages/shared/src/verification-checklist.ts`, which the supplier's own request card and the reviewer's drawer
/// render alike. Nothing here draws.
library;

import 'company_models.dart';

/// The ladder, lowest first (`VERIFICATION_LEVELS`).
const verificationLevels = ['REGISTERED', 'VERIFIED', 'CERTIFIED', 'PREFERRED', 'ELITE'];

/// The rank of a level on the ladder, 1–5 (`LEVEL_RANK`); 1 for anything unknown.
int levelRank(String? level) {
  final i = verificationLevels.indexOf(level ?? '');
  return i < 0 ? 1 : i + 1;
}

/// "Certified" from `CERTIFIED` (`VERIFICATION_LEVEL_LABELS`).
String levelLabel(String? level) {
  if (level == null || level.isEmpty) return '';
  return level[0] + level.substring(1).toLowerCase().replaceAll('_', ' ');
}

/// Preferred and Elite are awarded by ICR on performance; a supplier may ask up to here.
const maxSelfRequestLevel = 'CERTIFIED';

/// The next rung above [level], or null at the top.
String? nextLevel(String? level) {
  final i = verificationLevels.indexOf(level ?? 'REGISTERED');
  return i >= 0 && i < verificationLevels.length - 1 ? verificationLevels[i + 1] : null;
}

enum ChecklistStatus { verified, pending, missing }

/// Where a MISSING item is put right.
enum ChecklistFix { profile, listing, upload, certifications, reviews }

class ChecklistItem {
  const ChecklistItem({
    required this.key,
    required this.label,
    required this.requiredAtRank,
    required this.status,
    required this.detail,
    this.fix,
  });

  final String key;
  final String label;

  /// Trust-ladder rank (1–5) at which this item becomes required.
  final int requiredAtRank;
  final ChecklistStatus status;
  final String detail;
  final ChecklistFix? fix;
}

/// A certification as the checklist reads it.
typedef ChecklistCertification = ({
  String name,
  String status,
  bool hasDocument,
  DateTime? expiresAt,
  DateTime? supersededAt,
});

/// Whether a certificate with this expiry is still held: all of its expiry day in India, lapsing as the next day
/// begins (`certificationHeld`).
bool certificationHeld(DateTime? expiresAt, [DateTime? now]) =>
    expiresAt == null || certificationDaysLeft(expiresAt, now) >= 0;

/// Whole days from India's today to the expiry's date: 0 on the expiry date itself, negative once it has passed.
int certificationDaysLeft(DateTime expiresAt, [DateTime? now]) =>
    _indiaDay(expiresAt) - _indiaDay(now ?? DateTime.now());

const _istOffset = Duration(hours: 5, minutes: 30);

int _indiaDay(DateTime at) => at.toUtc().add(_istOffset).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

/// Derives the checklist from real profile and evidence data: an item is VERIFIED when the fact is confirmed, PENDING
/// when evidence exists but has not been approved, MISSING otherwise. Supplier uploads carry no kind, so the document
/// items match on the file's name, as the reviewer's own list does.
List<ChecklistItem> checklistFor({
  required CompanyDetails? company,
  required List<VerificationDocument> documents,
  List<ChecklistCertification> certifications = const [],
  int? yearsExperience,
  int ratingCount = 0,
  DateTime? now,
}) {
  VerificationDocument? docMatch(RegExp pattern) {
    for (final d in documents) {
      if (pattern.hasMatch(d.name)) return d;
    }
    return null;
  }

  (ChecklistStatus, String) fromDoc(RegExp pattern) {
    final doc = docMatch(pattern);
    if (doc == null) return (ChecklistStatus.missing, 'No document uploaded');
    if (doc.status == 'APPROVED') return (ChecklistStatus.verified, doc.name);
    if (doc.status == 'REJECTED') return (ChecklistStatus.missing, '${doc.name} was rejected');
    return (ChecklistStatus.pending, '${doc.name} awaiting review');
  }

  (ChecklistStatus, String) present(bool ok, String yes, String no) =>
      ok ? (ChecklistStatus.verified, yes) : (ChecklistStatus.missing, no);

  (ChecklistStatus, String) certificationsItem() {
    final current = certifications.where((c) => c.supersededAt == null).toList();
    final held = current.where((c) => c.status == 'VERIFIED' && certificationHeld(c.expiresAt, now)).toList();
    if (held.isNotEmpty) {
      final rest = held.length - 1;
      return (ChecklistStatus.verified, rest > 0 ? '${held.first.name} +$rest more' : '${held.first.name} · on file');
    }
    final pending = current.where((c) => c.status == 'PENDING').toList();
    if (pending.isNotEmpty) return (ChecklistStatus.missing, '${pending.first.name} – Certificate pending upload');
    // A file pushed through the request dialog still counts, unless its name says it is the registration, GST or PAN
    // proof — "GST Certificate.pdf" is not an ISO.
    VerificationDocument? doc;
    for (final d in documents) {
      if (RegExp(r'iso|certificat', caseSensitive: false).hasMatch(d.name) &&
          !RegExp(r'gst|\bpan\b|regist|incorp|udyam', caseSensitive: false).hasMatch(d.name)) {
        doc = d;
        break;
      }
    }
    if (doc == null) return (ChecklistStatus.missing, 'No certification recorded yet');
    if (doc.status == 'APPROVED') return (ChecklistStatus.verified, doc.name);
    if (doc.status == 'REJECTED') return (ChecklistStatus.missing, '${doc.name} was rejected');
    return (ChecklistStatus.pending, '${doc.name} awaiting review');
  }

  final years = yearsExperience ?? 0;
  final c = company;
  final registration = c?.incorporationDocUrl != null
      ? (ChecklistStatus.verified, '${c!.incorporationDocName ?? 'Registration certificate'} · from onboarding')
      : fromDoc(RegExp(r'regist|incorp|udyam', caseSensitive: false));
  final gst = present(c?.gstNumber != null, c?.gstNumber ?? '', 'No GSTIN on the company profile');
  final pan = present(c?.panNumber != null, c?.panNumber ?? '', 'No PAN on the company profile');
  final website = present(c?.website != null, c?.website ?? '', 'No website on the company profile');
  final office = present(c?.city != null, [?c?.city, ?c?.state].join(', '), 'No city on the company profile');
  final certs = certificationsItem();
  final insurance = fromDoc(RegExp(r'insur', caseSensitive: false));
  final financials = fromDoc(RegExp(r'financ|balance|audit|itr', caseSensitive: false));

  return [
    ChecklistItem(
      key: 'gst',
      label: 'GSTIN',
      requiredAtRank: 2,
      fix: ChecklistFix.profile,
      status: gst.$1,
      detail: gst.$2,
    ),
    ChecklistItem(
      key: 'pan',
      label: 'PAN',
      requiredAtRank: 2,
      fix: ChecklistFix.profile,
      status: pan.$1,
      detail: pan.$2,
    ),
    ChecklistItem(
      key: 'registration',
      label: 'Company Registration',
      requiredAtRank: 2,
      fix: c?.incorporationDocUrl != null ? ChecklistFix.profile : ChecklistFix.upload,
      status: registration.$1,
      detail: registration.$2,
    ),
    ChecklistItem(
      key: 'website',
      label: 'Company Website',
      requiredAtRank: 2,
      fix: ChecklistFix.profile,
      status: website.$1,
      detail: website.$2,
    ),
    ChecklistItem(
      key: 'office',
      label: 'Business Locations',
      requiredAtRank: 2,
      fix: ChecklistFix.profile,
      status: office.$1,
      detail: office.$2,
    ),
    ChecklistItem(
      key: 'certifications',
      label: 'Quality & ISO Certifications',
      requiredAtRank: 3,
      fix: ChecklistFix.certifications,
      status: certs.$1,
      detail: certs.$2,
    ),
    ChecklistItem(
      key: 'insurance',
      label: 'Insurance',
      requiredAtRank: 3,
      fix: ChecklistFix.upload,
      status: insurance.$1,
      detail: insurance.$2,
    ),
    ChecklistItem(
      key: 'experience',
      label: 'Business Experience',
      requiredAtRank: 3,
      fix: ChecklistFix.listing,
      status: years >= 3
          ? ChecklistStatus.verified
          : years >= 1
          ? ChecklistStatus.pending
          : ChecklistStatus.missing,
      detail: years > 0 ? '$years Years' : 'Not stated on the listing',
    ),
    ChecklistItem(
      key: 'references',
      label: 'Client References',
      requiredAtRank: 4,
      fix: ChecklistFix.reviews,
      status: ratingCount >= 3
          ? ChecklistStatus.verified
          : ratingCount >= 1
          ? ChecklistStatus.pending
          : ChecklistStatus.missing,
      detail: ratingCount > 0 ? '$ratingCount marketplace reviews' : 'No reviews yet',
    ),
    ChecklistItem(
      key: 'financials',
      label: 'Financial Documents',
      requiredAtRank: 4,
      fix: ChecklistFix.upload,
      status: financials.$1,
      detail: financials.$2,
    ),
  ];
}
