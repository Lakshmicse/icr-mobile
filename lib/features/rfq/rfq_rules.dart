/// The rules a requirement, a bid and a pre-qualification answer are held to,
/// mirroring the API (`CreateRfqDto`, `assertRequirementLogic`, `CreateBidDto`,
/// `SubmitPreQualDto`, the shared `REQUIREMENT_LIMITS` and phone rules), so the
/// forms say what is wrong before anything is sent. The API checks the same
/// things again and its own sentence is shown when it still refuses.
library;

import 'rfq_checklist.dart' show withoutEmptyPrompts;
import 'rfq_models.dart';

/// `REQUIREMENT_LIMITS` and the DTOs' other bounds.
class RfqLimits {
  RfqLimits._();

  static const title = 200;
  static const companyName = 120;
  static const contactName = 80;
  static const place = 120;
  static const descriptionMin = 20;
  static const descriptionMax = 5000;
  static const maxYearsInBusiness = 100;
  static const maxTurnover = 100000000000.0;
  static const maxItems = 50;
  static const maxQuantity = 1000000;
  static const itemName = 200;
  static const unit = 40;
  static const specification = 1000;
  static const maxInvites = 50;
  static const maxLocations = 10;
  static const maxAttachments = 10;
  static const maxBidAttachments = 10;
  static const attachmentTitle = 120;
  static const maxUploadBytes = 10 * 1024 * 1024;
  static const deadlineHorizonDays = 730;
  static const phoneMax = 30;
  static const bidMessage = 4000;

  /// A quote's price column holds 12 digits before the point (`Decimal(14, 2)`); beyond that the API cannot store it.
  static const maxBidAmount = 999999999999.0;

  /// A lead time is a 32-bit number of days; nobody quotes a hundred years.
  static const maxLeadTimeDays = 36500;
}

/// Facility types a buyer picks from (`FACILITY_TYPES`), in the website's order.
const facilityTypes = [
  'IT & ITES',
  'Data Centers',
  'Telecom',
  'Semiconductor',
  'Manufacturing',
  'Automotive',
  'Industrial Parks',
  'Food Processing',
  'Oil & Gas',
  'Power & Utilities',
  'Defense & Aerospace',
  'Healthcare',
  'Hospitals',
  'Pharmaceuticals',
  'Life Sciences',
  'Retail',
  'Shopping Malls',
  'Banking & Financial Services',
  'Hotels',
  'Hospitality',
  'Media & Entertainment',
  'Airports',
  'Aviation',
  'Railways & Metro',
  'Ports',
  'Warehousing & Logistics',
  'Education',
  'Universities',
  'Government',
  'Smart Cities',
  'Residential Communities',
  'Mixed-Use Developments',
  'Other',
];

/// Values stored before the sector list replaced the original one, still accepted when an old requirement is
/// edited (`LEGACY_FACILITY_TYPES`; "Corporate Offices" was retired on 24 Oct 2026 and is no longer offered).
const legacyFacilityTypes = [
  'Office',
  'Warehouse',
  'Hospital',
  'Hotel',
  'Industrial',
  'Residential complex',
  'Corporate Offices',
];

/// Countries a requirement may be in (`COUNTRIES`).
const countries = [
  'India',
  'United Arab Emirates',
  'Saudi Arabia',
  'Qatar',
  'Oman',
  'Kuwait',
  'Bahrain',
  'Singapore',
  'Hong Kong',
  'Malaysia',
  'Australia',
  'USA',
  'UK',
];

/// Employee-count buckets (`COMPANY_SIZES`), smallest first.
const companySizes = ['1-10', '11-50', '51-200', '201-500', '500+'];

/// Statutory-compliance items and their names (`STATUTORY_COMPLIANCE_LABELS`).
const statutoryCompliance = {
  'GST': 'GST',
  'PF': 'Provident Fund (PF)',
  'ESI': 'ESI',
  'PT': 'Professional Tax',
  'LABOUR_LICENSE': 'Labour Licence',
  'PSARA': 'PSARA',
  'ISO_9001': 'ISO 9001',
  'SHOPS_ESTABLISHMENT': 'Shops & Establishment',
  'MSME_UDYAM': 'MSME / Udyam',
};

// ---- Phones ------------------------------------------------------------------------

/// A contact phone on a requirement (`CONTACT_PHONE_PATTERN`): 10 to 15 digits,
/// an optional leading +, spaces, brackets or dashes between.
final contactPhonePattern = RegExp(r'^\+?[ ()-]*(?:[0-9][ ()-]*){10,15}$');

const _phoneCountries = <(String dial, int min, int max)>[
  ('91', 10, 10),
  ('971', 9, 9),
  ('966', 9, 9),
  ('974', 8, 8),
  ('968', 8, 8),
  ('965', 8, 8),
  ('973', 8, 8),
  ('65', 8, 8),
  ('852', 8, 8),
  ('60', 9, 10),
  ('61', 9, 9),
  ('1', 10, 10),
  ('44', 10, 10),
];

final _indianMobile = RegExp(r'^[6-9]\d{9}$');
final _e164 = RegExp(r'^[1-9]\d{6,14}$');

/// A person's own mobile in E.164, or null when it cannot be read as one
/// (`normalizePhone` in `packages/shared/src/phone.ts`): an Indian mobile may be
/// typed bare or with 91, anything else needs its country code.
String? normalizePhone(String? raw) {
  if (raw == null) return null;
  var s = raw.trim().replaceAll(RegExp(r'[\s().-]'), '');
  if (s.isEmpty) return null;
  if (s.startsWith('00')) s = '+${s.substring(2)}';
  if (!s.startsWith('+')) {
    if (_indianMobile.hasMatch(s)) return '+91$s';
    if (RegExp(r'^91[6-9]\d{9}$').hasMatch(s)) return '+$s';
    return null;
  }
  final digits = s.substring(1);
  if (!_e164.hasMatch(digits)) return null;
  if (digits.startsWith('91') && !_indianMobile.hasMatch(digits.substring(2))) return null;
  (String, int, int)? best;
  for (final c in _phoneCountries) {
    if (digits.startsWith(c.$1) && (best == null || c.$1.length > best.$1.length)) best = c;
  }
  if (best != null) {
    final n = digits.length - best.$1.length;
    if (n < best.$2 || n > best.$3) return null;
  }
  return '+$digits';
}

/// Why a person's own mobile is refused, or null.
String? ownPhoneProblem(String raw) {
  if (raw.trim().isEmpty) return 'Add the mobile number suppliers can reach you on.';
  if (normalizePhone(raw) != null) return null;
  final s = raw.trim().replaceAll(RegExp(r'[\s().-]'), '');
  if (!s.startsWith('+') && !s.startsWith('00')) {
    return 'Add the country code, like +44 7700 900123. Indian mobiles can be typed without +91.';
  }
  if (RegExp(r'^(\+|00)?91').hasMatch(s)) return 'Enter a 10-digit Indian mobile number.';
  return 'Enter a mobile number with its country code.';
}

/// Whether an API refusal is "add a mobile number" (`PHONE_NEEDED.supplier`):
/// the form then asks for one and sends it again.
bool isPhoneRefusal(String? message) =>
    message != null && (message.contains('mobile number') || message.toLowerCase().contains('phone'));

// ---- Amounts and days -------------------------------------------------------------------

/// An amount as typed: "50,00,000", "5000000", "₹ 50 00 000". Null when blank,
/// NaN when it is not a number once the grouping is taken out.
double? parseRupees(String raw) {
  final plain = raw.replaceAll(RegExp(r'[,\s₹]'), '');
  if (plain.isEmpty) return null;
  return RegExp(r'^-?\d+(\.\d+)?$').hasMatch(plain) ? double.parse(plain) : double.nan;
}

/// A rupee amount: zero or more, under the cap, or blank.
String? rupeeProblem(String raw) {
  final n = parseRupees(raw);
  if (n == null) return null;
  if (n.isNaN) return 'Enter an amount in rupees, like 50,00,000';
  if (n < 0) return 'Cannot be negative';
  if (n > RfqLimits.maxTurnover) return 'That amount is too large';
  return null;
}

/// India's offset: deadlines are days on the Indian calendar.
const istOffset = Duration(hours: 5, minutes: 30);

/// Today on the Indian calendar, as a date with no time.
DateTime todayIst([DateTime? now]) {
  final t = (now ?? DateTime.now()).toUtc().add(istOffset);
  return DateTime(t.year, t.month, t.day);
}

/// The Indian calendar day a stored moment falls on.
DateTime istDayOf(DateTime moment) {
  final t = moment.toUtc().add(istOffset);
  return DateTime(t.year, t.month, t.day);
}

/// A deadline picked as a day means the whole of that day in India: the last
/// instant before the next IST midnight (`deadlineIso` on the website).
String deadlineIso(DateTime day) => DateTime.utc(day.year, day.month, day.day, 18, 29, 59, 999).toIso8601String();

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

// ---- The composer -------------------------------------------------------------------------

/// Who can respond: everyone on the board, or only the suppliers invited.
enum Audience { open, invited }

/// What the composer holds while it is filled in. One draft for both kinds:
/// switching between an enquiry and an RFQ keeps everything typed.
class RequirementDraft {
  RfqKind kind = RfqKind.enquiry;

  /// Empty means "use the suggested title" ([suggestedTitle]).
  String title = '';
  String companyName = '';
  String contactName = '';
  String contactPhone = '';
  String email = '';
  String facilityType = '';

  /// Every service location, as the place search returned it (at most [RfqLimits.maxLocations]).
  List<RfqPlace> places = [];
  String category = '';
  String subcategory = '';
  String service = '';
  String text = '';
  String budget = '';
  List<RfqItem> items = [];
  Audience audience = Audience.open;
  List<SupplierRef> invited = [];

  /// Photos, drawings and spec sheets, each with the title the buyer gave it.
  List<RfqFile> attachments = [];

  /// RFQ: the supplier criteria and the two deadlines.
  String minYears = '';
  String minEmployees = '';
  String minAnnualTurnover = '';
  String minLast3YrTurnover = '';
  Presence? presence;
  Set<String> compliance = {};
  DateTime? preQualEndDate;

  /// The RFQ's quote deadline, or the enquiry's optional reply-by day.
  DateTime? dueDate;

  RequirementDraft();

  /// "Post a similar requirement", or the requirement being edited: its kind,
  /// where, what service, the text and the criteria. A copy never takes the
  /// dates (they are picked anew) or the files (they stay with their requirement).
  factory RequirementDraft.from(Requirement r, {bool copy = false}) {
    final d = RequirementDraft()
      ..kind = r.kind
      ..title = copy ? '' : r.title
      ..companyName = r.companyName ?? ''
      ..contactName = r.contactName ?? ''
      ..contactPhone = r.contactPhone ?? ''
      ..email = r.contactEmail ?? ''
      ..facilityType = r.facilityType ?? ''
      ..places = r.serviceLocations.isNotEmpty
          ? List.of(r.serviceLocations)
          : [for (final name in r.places) RfqPlace(label: name, city: name, state: r.state, country: r.country)]
      ..category = r.category ?? ''
      ..subcategory = r.subcategory ?? ''
      ..service = r.service ?? ''
      ..text = r.text ?? ''
      ..budget = r.budget == null ? '' : _plainNumber(r.budget!)
      ..minYears = r.criteria.minYearsInBusiness?.toString() ?? ''
      ..minEmployees = r.criteria.minEmployees ?? ''
      ..minAnnualTurnover = r.criteria.minAnnualTurnover == null ? '' : _plainNumber(r.criteria.minAnnualTurnover!)
      ..minLast3YrTurnover = r.criteria.minLast3YrTurnover == null ? '' : _plainNumber(r.criteria.minLast3YrTurnover!)
      ..presence = r.criteria.requiredPresence
      ..compliance = r.criteria.statutoryCompliance.toSet();
    if (!copy) {
      d
        ..items = List.of(r.items)
        ..attachments = List.of(r.files)
        ..audience = r.visibility == RfqVisibility.targeted ? Audience.invited : Audience.open
        ..preQualEndDate = r.preQualEndDate == null ? null : istDayOf(r.preQualEndDate!)
        ..dueDate = r.dueDate == null ? null : istDayOf(r.dueDate!);
    }
    return d;
  }

  bool get isRfq => kind == RfqKind.rfq;

  /// The title the website would generate: "IT & ITES — Housekeeping"
  /// for an enquiry, "Acme — Housekeeping RFQ" for an RFQ.
  String suggestedTitle({required String serviceLabel, String? company}) {
    final what = serviceLabel.isEmpty ? 'Services' : serviceLabel;
    if (isRfq) {
      final who = (company ?? companyName).trim();
      return who.isEmpty ? '$what RFQ' : '$who — $what RFQ';
    }
    return facilityType.isEmpty ? what : '$facilityType — $what';
  }

  /// The supplier criteria set, for the review and the closed disclosure.
  int get criteriaCount =>
      [minYears, minEmployees, minAnnualTurnover, minLast3YrTurnover].where((v) => v.trim().isNotEmpty).length +
      (presence == null ? 0 : 1) +
      (compliance.isEmpty ? 0 : 1);

  /// The cities as sent (`locations`): each place's city, else its label, blanks and repeats dropped.
  List<String> get cleanLocations => [
    ...{for (final p in places) (p.city ?? p.label).trim()}.where((c) => c.isNotEmpty),
  ];

  /// The state, when every place names one and they agree (the website's `derivedLocation`, which also lets a
  /// place with no state through: a typed name would then be given its neighbour's).
  String get derivedState {
    // Every place must name it: a place typed by hand says nothing, and Pune's state is not Dubai's.
    if (places.isEmpty || places.any((p) => p.state == null)) return '';
    final states = {for (final p in places) p.state!};
    return states.length == 1 ? states.first : '';
  }

  /// The country, when it is one ICR lists and every place is in it.
  String get derivedCountry {
    if (places.isEmpty || places.any((p) => p.country == null)) return '';
    final names = {for (final p in places) p.country!.toLowerCase()};
    if (names.length != 1) return '';
    return countries.where((c) => c.toLowerCase() == names.first).firstOrNull ?? '';
  }

  /// Whether the facility type picked is one the API takes: offered, or kept from an older requirement.
  bool get facilityTypeAccepted => facilityTypes.contains(facilityType) || legacyFacilityTypes.contains(facilityType);

  /// What is wrong, by field: `title`, `companyName`, `contactName`,
  /// `contactPhone`, `facilityType`, `locations`, `category`, `text`,
  /// `budget`, `items`, `invited`, `attachments`, `minYears`, `minAnnualTurnover`,
  /// `minLast3YrTurnover`, `preQualEndDate`, `dueDate`.
  ///
  /// [goingLive] holds it to everything a live requirement needs; a draft is
  /// held only to the fields' own limits. [askCompany] when the poster acts
  /// for no company and so names one (ICR staff only: a member posts for a company).
  Map<String, String> problems({
    required bool goingLive,
    required bool askCompany,
    required String effectiveTitle,
    bool editing = false,
    DateTime? now,
  }) {
    final out = <String, String>{};
    final today = todayIst(now);
    final horizon = today.add(const Duration(days: RfqLimits.deadlineHorizonDays));

    final t = effectiveTitle.trim();
    if (t.isEmpty) {
      out['title'] = 'Give the requirement a title';
    } else if (t.length > RfqLimits.title) {
      out['title'] = 'Use at most ${RfqLimits.title} characters';
    }

    if (askCompany) {
      if (companyName.trim().isEmpty && goingLive) {
        out['companyName'] = 'Enter your company name';
      } else if (companyName.trim().length > RfqLimits.companyName) {
        out['companyName'] = 'Use at most ${RfqLimits.companyName} characters';
      }
    }
    if (contactName.trim().isEmpty && goingLive) {
      out['contactName'] = 'Enter the contact person';
    } else if (contactName.trim().length > RfqLimits.contactName) {
      out['contactName'] = 'Use at most ${RfqLimits.contactName} characters';
    }
    final phone = contactPhone.trim();
    if (phone.isEmpty && goingLive) {
      out['contactPhone'] = 'Enter a phone number';
    } else if (phone.isNotEmpty && (phone.length > RfqLimits.phoneMax || !contactPhonePattern.hasMatch(phone))) {
      out['contactPhone'] = 'Enter a phone number of 10 to 15 digits';
    }

    if (goingLive && facilityType.isEmpty) {
      out['facilityType'] = 'Select a facility type';
    } else if (facilityType.isNotEmpty && !facilityTypeAccepted) {
      out['facilityType'] = 'Select a facility type from the list';
    }
    if (goingLive && places.isEmpty) {
      out['locations'] = 'Pick at least one place';
    } else if (places.length > RfqLimits.maxLocations) {
      out['locations'] = 'At most ${RfqLimits.maxLocations} places';
    } else if (places.any((p) => p.label.length > RfqLimits.place || (p.city ?? '').length > RfqLimits.place)) {
      out['locations'] = 'A place name is too long';
    }
    if (goingLive && category.isEmpty) out['category'] = 'Select a service category';

    final n = withoutEmptyPrompts(text).length;
    if (goingLive && n == 0) {
      out['text'] = isRfq ? 'Describe the scope of services' : 'Describe what you need';
    } else if (goingLive && n < RfqLimits.descriptionMin) {
      out['text'] = 'Add a little more detail: at least ${RfqLimits.descriptionMin} characters ($n so far)';
    } else if (n > RfqLimits.descriptionMax) {
      out['text'] = 'Use at most ${RfqLimits.descriptionMax} characters ($n now)';
    }

    final budgetIssue = rupeeProblem(budget);
    if (budgetIssue != null) out['budget'] = budgetIssue;

    if (attachments.length > RfqLimits.maxAttachments) {
      out['attachments'] = 'At most ${RfqLimits.maxAttachments} files';
    } else if (attachments.any((a) => a.title.trim().isEmpty)) {
      out['attachments'] = 'Give every file a title';
    } else if (attachments.any((a) => a.title.trim().length > RfqLimits.attachmentTitle)) {
      out['attachments'] = 'A file title can have at most ${RfqLimits.attachmentTitle} characters';
    }

    if (!editing) {
      if (items.length > RfqLimits.maxItems) {
        out['items'] = 'At most ${RfqLimits.maxItems} line items';
      } else {
        for (final (i, item) in items.indexed) {
          final issue = itemProblem(item);
          if (issue != null) {
            out['items'] = 'Line ${i + 1}: $issue';
            break;
          }
        }
      }
      if (audience == Audience.invited && !isRfq) {
        if (invited.isEmpty) {
          out['invited'] = 'Choose at least one supplier to invite';
        } else if (invited.length > RfqLimits.maxInvites) {
          out['invited'] = 'Invite at most ${RfqLimits.maxInvites} suppliers at once';
        }
      }
    }

    if (isRfq) {
      final years = minYears.trim();
      if (years.isNotEmpty) {
        final y = int.tryParse(years);
        if (y == null) {
          out['minYears'] = 'Use a whole number of years';
        } else if (y < 0) {
          out['minYears'] = 'Cannot be negative';
        } else if (y > RfqLimits.maxYearsInBusiness) {
          out['minYears'] = 'At most ${RfqLimits.maxYearsInBusiness} years';
        }
      }
      final annualIssue = rupeeProblem(minAnnualTurnover);
      if (annualIssue != null) out['minAnnualTurnover'] = annualIssue;
      final last3Issue = rupeeProblem(minLast3YrTurnover);
      if (last3Issue != null) {
        out['minLast3YrTurnover'] = last3Issue;
      } else {
        final annual = parseRupees(minAnnualTurnover);
        final last3 = parseRupees(minLast3YrTurnover);
        if (annual != null && last3 != null && !annual.isNaN && last3 < annual) {
          out['minLast3YrTurnover'] = "The last 3 years' turnover cannot be less than one year's";
        }
      }
      final pq = preQualEndDate == null ? null : _dayOnly(preQualEndDate!);
      final due = dueDate == null ? null : _dayOnly(dueDate!);
      if (pq == null && goingLive) {
        out['preQualEndDate'] = 'Set a pre-qualification deadline';
      } else if (pq != null && pq.isBefore(today)) {
        out['preQualEndDate'] = 'The pre-qualification deadline cannot be in the past';
      } else if (pq != null && pq.isAfter(horizon)) {
        out['preQualEndDate'] = 'Pick a date within two years';
      }
      if (due == null && goingLive) {
        out['dueDate'] = 'Set a quote deadline';
      } else if (due != null && pq != null && !due.isAfter(pq)) {
        out['dueDate'] = 'The quote deadline must come after the pre-qualification deadline';
      } else if (due != null && due.isBefore(today)) {
        out['dueDate'] = 'The quote deadline cannot be in the past';
      } else if (due != null && due.isAfter(horizon)) {
        out['dueDate'] = 'Pick a date within two years';
      }
    } else if (dueDate != null) {
      final due = _dayOnly(dueDate!);
      if (due.isBefore(today)) {
        out['dueDate'] = 'That date has already passed';
      } else if (due.isAfter(horizon)) {
        out['dueDate'] = 'Pick a date within two years';
      }
    }
    return out;
  }

  /// `POST /rfq` as the composer sends it.
  Map<String, dynamic> toCreate({
    required RfqStatus status,
    required String effectiveTitle,
    String? companyFromAccount,
  }) {
    final body = _fields(effectiveTitle: effectiveTitle, companyFromAccount: companyFromAccount);
    body['kind'] = kind.wire;
    body['status'] = status.wire;
    if (attachments.isNotEmpty) body['attachments'] = _attachmentsJson();
    if (items.isNotEmpty) body['items'] = [for (final i in items) i.toJson()];
    if (audience == Audience.invited && !isRfq) {
      body['visibility'] = RfqVisibility.targeted.wire;
      body['vendorIds'] = [for (final s in invited) s.vendorId];
    } else {
      body['visibility'] = RfqVisibility.public.wire;
    }
    return body;
  }

  /// `PATCH /rfq/:id`: the fields an edit may change (never the line items or
  /// the invitations, which have their own paths). The files go as the whole
  /// list, and only when [sendAttachments]: leaving the key out leaves them alone.
  Map<String, dynamic> toUpdate({
    required String effectiveTitle,
    String? companyFromAccount,
    bool sendAttachments = false,
  }) => {
    ..._fields(effectiveTitle: effectiveTitle, companyFromAccount: companyFromAccount),
    if (sendAttachments) 'attachments': _attachmentsJson(),
  };

  List<Map<String, dynamic>> _attachmentsJson() => [
    for (final a in attachments)
      {'title': a.title.trim(), 'url': a.url, 'name': ?a.name, 'mimeType': ?a.mimeType, 'size': ?a.size},
  ];

  Map<String, dynamic> _fields({required String effectiveTitle, String? companyFromAccount}) {
    final text = withoutEmptyPrompts(this.text);
    final company = (companyFromAccount ?? companyName).trim();
    final state = derivedState;
    final country = derivedCountry;
    final body = <String, dynamic>{
      'title': effectiveTitle.trim(),
      if (facilityType.isNotEmpty) 'facilityType': facilityType,
      if (country.isNotEmpty) 'country': country,
      if (state.isNotEmpty) 'state': state,
      'locations': cleanLocations,
      if (places.isNotEmpty) 'serviceLocations': [for (final p in places) p.toJson()],
      if (category.isNotEmpty) 'category': category,
      if (subcategory.isNotEmpty) 'subcategory': subcategory,
      if (service.isNotEmpty) 'service': service,
      if (company.isNotEmpty) 'companyName': company,
      if (contactName.trim().isNotEmpty) 'contactName': contactName.trim(),
      if (email.trim().isNotEmpty) 'contactEmail': email.trim(),
      if (contactPhone.trim().isNotEmpty) 'contactPhone': contactPhone.trim(),
    };
    final budget = parseRupees(this.budget);
    if (budget != null && !budget.isNaN) body['budget'] = budget;
    if (isRfq) {
      // Sent once: the API copies an RFQ's scope into its description.
      if (text.isNotEmpty) body['scope'] = text;
      if (minYears.trim().isNotEmpty) body['minYearsInBusiness'] = int.tryParse(minYears.trim());
      final annual = parseRupees(minAnnualTurnover);
      if (annual != null && !annual.isNaN) body['minAnnualTurnover'] = annual;
      final last3 = parseRupees(minLast3YrTurnover);
      if (last3 != null && !last3.isNaN) body['minLast3YrTurnover'] = last3;
      if (minEmployees.isNotEmpty) body['minEmployees'] = minEmployees;
      if (presence != null) body['requiredPresence'] = presence!.wire;
      body['statutoryCompliance'] = [
        for (final c in statutoryCompliance.keys)
          if (compliance.contains(c)) c,
      ];
      if (preQualEndDate != null) body['preQualEndDate'] = deadlineIso(preQualEndDate!);
      if (dueDate != null) body['dueDate'] = deadlineIso(dueDate!);
    } else {
      if (text.isNotEmpty) body['description'] = text;
      if (dueDate != null) body['dueDate'] = deadlineIso(dueDate!);
    }
    return body;
  }
}

/// A line item's problem, or null.
String? itemProblem(RfqItem item) {
  if (item.name.trim().isEmpty) return 'name the item';
  if (item.name.trim().length > RfqLimits.itemName) return 'the name is too long';
  if (item.quantity < 1 || item.quantity > RfqLimits.maxQuantity) {
    return 'quantity must be 1 to ${RfqLimits.maxQuantity}';
  }
  if ((item.unit ?? '').trim().length > RfqLimits.unit) return 'the unit is too long';
  if ((item.specification ?? '').trim().length > RfqLimits.specification) return 'the specification is too long';
  return null;
}

/// "Request a quote" from one supplier: a private enquiry that goes out now
/// (`RequestQuoteDialog` on the website).
class QuoteRequestDraft {
  String title = '';
  String category = '';
  String city = '';
  String budget = '';
  DateTime? dueDate;
  String description = '';
  String quantity = '1';

  /// The sender's own mobile, asked when the profile has none.
  String phone = '';

  Map<String, String> problems({required bool hasItem, required bool askPhone, DateTime? now}) {
    final out = <String, String>{};
    final t = title.trim();
    if (t.isEmpty) {
      out['title'] = 'Say what you need';
    } else if (t.length > RfqLimits.title) {
      out['title'] = 'Use at most ${RfqLimits.title} characters';
    }
    if (hasItem) {
      final q = int.tryParse(quantity.trim());
      if (!RegExp(r'^\d+$').hasMatch(quantity.trim()) || q == null || q < 1 || q > RfqLimits.maxQuantity) {
        out['quantity'] = 'Enter a whole number from 1 to 10,00,000';
      }
    }
    if (city.trim().length > RfqLimits.place) out['city'] = 'A city name is too long';
    final b = parseRupees(budget);
    if (b != null && (b.isNaN || b < 0)) {
      out['budget'] = b.isNaN ? 'Enter an amount in rupees' : 'Cannot be negative';
    } else if (b != null && b > RfqLimits.maxTurnover) {
      out['budget'] = 'That amount is too large';
    }
    if (dueDate != null) {
      final today = todayIst(now);
      final due = _dayOnly(dueDate!);
      if (due.isBefore(today)) {
        out['dueDate'] = 'That date has already passed';
      } else if (due.isAfter(today.add(const Duration(days: RfqLimits.deadlineHorizonDays)))) {
        out['dueDate'] = 'Pick a date within two years';
      }
    }
    if (description.trim().length > RfqLimits.descriptionMax) {
      out['description'] = 'Use at most ${RfqLimits.descriptionMax} characters';
    }
    if (askPhone) {
      final issue = ownPhoneProblem(phone);
      if (issue != null) out['phone'] = issue;
    }
    return out;
  }

  /// `POST /rfq`: a TARGETED enquiry to [vendorId], published now.
  Map<String, dynamic> toCreate({required String vendorId, RfqItem? item, bool sendPhone = false}) {
    final b = parseRupees(budget);
    return {
      'title': title.trim(),
      'kind': RfqKind.enquiry.wire,
      'status': RfqStatus.published.wire,
      'visibility': RfqVisibility.targeted.wire,
      'vendorIds': [vendorId],
      if (description.trim().isNotEmpty) 'description': description.trim(),
      if (category.isNotEmpty) 'category': category,
      if (city.trim().isNotEmpty) 'city': city.trim(),
      if (b != null && !b.isNaN) 'budget': b,
      if (dueDate != null) 'dueDate': deadlineIso(dueDate!),
      if (item != null)
        'items': [
          RfqItem(name: item.name, quantity: int.tryParse(quantity.trim()) ?? item.quantity, unit: item.unit).toJson(),
        ],
      if (sendPhone && phone.trim().isNotEmpty) 'phone': normalizePhone(phone) ?? phone.trim(),
    };
  }
}

// ---- The supplier's reply -------------------------------------------------------------------

/// A bid on an RFQ (priced) or a reply to an enquiry (a message or an indicative price).
class BidDraft {
  BidDraft();

  /// An earlier bid, to change it: what the form starts from.
  factory BidDraft.from(MyBid b) => BidDraft()
    ..amount = b.amount == null ? '' : _plainNumber(b.amount!)
    ..leadTime = b.leadTimeDays?.toString() ?? ''
    ..message = b.message ?? ''
    ..attachments = List.of(b.files);

  String amount = '';
  String leadTime = '';
  String message = '';

  /// Quotations, certificates or reference photos, each with the title the supplier gave it.
  List<RfqFile> attachments = [];

  Map<String, String> problems({required bool enquiry}) {
    final out = <String, String>{};
    final a = parseRupees(amount);
    if (a == null) {
      if (!enquiry) out['amount'] = 'Enter your price';
    } else if (a.isNaN) {
      out['amount'] = 'Enter an amount in rupees';
    } else if (a < 0) {
      out['amount'] = 'Cannot be negative';
    } else if (a > RfqLimits.maxBidAmount) {
      out['amount'] = 'That amount is too large';
    }
    final lead = leadTime.trim();
    if (lead.isNotEmpty) {
      final d = int.tryParse(lead);
      if (d == null || d < 0) {
        out['leadTime'] = 'Use whole days';
      } else if (d > RfqLimits.maxLeadTimeDays) {
        out['leadTime'] = 'That is too many days';
      }
    }
    if (message.length > RfqLimits.bidMessage) {
      out['message'] = 'Use at most ${RfqLimits.bidMessage} characters';
    } else if (enquiry && a == null && message.trim().isEmpty) {
      out['message'] = 'Write a reply, or give an indicative price';
    }
    if (attachments.length > RfqLimits.maxBidAttachments) {
      out['attachments'] = 'At most ${RfqLimits.maxBidAttachments} files';
    } else if (attachments.any((f) => f.title.trim().isEmpty)) {
      out['attachments'] = 'Give every file a title';
    } else if (attachments.any((f) => f.title.trim().length > RfqLimits.attachmentTitle)) {
      out['attachments'] = 'A file title can have at most ${RfqLimits.attachmentTitle} characters';
    }
    return out;
  }

  /// `POST /rfq/:id/bids`.
  Map<String, dynamic> toJson() {
    final a = parseRupees(amount);
    return {
      if (a != null && !a.isNaN) 'totalAmount': a,
      if (leadTime.trim().isNotEmpty) 'leadTimeDays': int.tryParse(leadTime.trim()),
      if (message.trim().isNotEmpty) 'message': message.trim(),
      if (attachments.isNotEmpty)
        'attachments': [
          for (final f in attachments)
            {'title': f.title.trim(), 'url': f.url, 'name': ?f.name, 'mimeType': ?f.mimeType, 'size': ?f.size},
        ],
    };
  }
}

/// A supplier's answers to an RFQ's pre-qualification criteria.
class PreQualDraft {
  String yearsInBusiness = '';
  String annualTurnover = '';
  String last3YrTurnover = '';
  String employeeCount = '';
  Presence? presence;
  Set<String> compliance = {};

  Map<String, String> problems() {
    final out = <String, String>{};
    final years = yearsInBusiness.trim();
    if (years.isNotEmpty) {
      final y = int.tryParse(years);
      if (y == null || y < 0) out['yearsInBusiness'] = 'Use a whole number of years';
    }
    final annual = rupeeProblem(annualTurnover);
    if (annual != null) out['annualTurnover'] = annual;
    final last3 = rupeeProblem(last3YrTurnover);
    if (last3 != null) out['last3YrTurnover'] = last3;
    return out;
  }

  /// `POST /rfq/:id/prequal`.
  Map<String, dynamic> toJson() {
    final annual = parseRupees(annualTurnover);
    final last3 = parseRupees(last3YrTurnover);
    return {
      if (yearsInBusiness.trim().isNotEmpty) 'yearsInBusiness': int.tryParse(yearsInBusiness.trim()),
      if (annual != null && !annual.isNaN) 'annualTurnover': annual,
      if (last3 != null && !last3.isNaN) 'last3YrTurnover': last3,
      if (employeeCount.isNotEmpty) 'employeeCount': employeeCount,
      if (presence != null) 'presence': presence!.wire,
      'statutoryCompliance': [
        for (final c in statutoryCompliance.keys)
          if (compliance.contains(c)) c,
      ],
    };
  }
}

String _plainNumber(double v) => v == v.roundToDouble() ? v.round().toString() : v.toString();
