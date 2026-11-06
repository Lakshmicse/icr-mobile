import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/api/api_error.dart';
import '../account_models.dart';
import '../account_repository.dart';
import '../account_rules.dart';
import '../api_account_repository.dart';
import 'companies_controller.dart';
import 'company_lookups.dart';

/// The fields of the form, in the order it asks them: the error summary lists
/// them in this order and a refused Create scrolls to the first.
enum CompanyField { name, legalName, website, industry, city, size, legalStructure, authorised }

const _fieldNames = {
  CompanyField.name: 'Company name',
  CompanyField.legalName: 'Registered legal name',
  CompanyField.website: 'Website',
  CompanyField.industry: 'Industry',
  CompanyField.city: 'Head office',
  CompanyField.size: 'Company size',
  CompanyField.legalStructure: 'Organisation type',
  CompanyField.authorised: 'Confirmation',
};

extension CompanyFieldName on CompanyField {
  String get label => _fieldNames[this]!;
}

const logoMaxBytes = 2 * 1024 * 1024;
const _logoTypes = {'image/png', 'image/jpeg', 'image/webp'};

/// The logo limits the website's `LogoDropzone` enforces before it uploads, and its sentences.
const logoNotAnImage = 'That is not an image. Choose a PNG, JPG or WEBP file.';
const logoTooBig = 'That image is over 2MB. Compress it or choose a smaller one.';
const logoUploadFailed = 'Upload failed. Please try again.';

/// "GIF files are not accepted. Use PNG, JPG or WEBP." for a picture of another type.
String logoTypeNotAccepted(String contentType) =>
    '${contentType.replaceFirst('image/', '').toUpperCase()} files are not accepted. Use PNG, JPG or WEBP.';

/// What the page says when the API gave no sentence of its own (`errorOf(err, couldNotCreate)`).
const couldNotCreate = 'Could not create the company page.';

/// The sentence the website's page shows for a failed call: the API's own, else [fallback]. The app's client words a
/// refusal that came with no message as "Something went wrong (500)…", and a request that never arrived as "Can't
/// reach ICR…"; the page's `errorOf` has neither, so both read as [fallback]. A list of validation sentences is one
/// line, joined with a space as the website joins them.
String apiSentence(ApiError e, String fallback) {
  if (e.isOffline || e.message.startsWith('Something went wrong')) return fallback;
  return e.message.replaceAll('\n', ' ');
}

// --- the website field (`lib/url.ts`) -----------------------------------------------------------------------------

/// The longest website the API takes (`WEBSITE_MAX_LENGTH`).
const websiteMaxLength = 2084;

const websiteSentence = 'Enter a website like acme.com or https://acme.com';

final _scheme = RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false);
final _ipv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');
// The website's LABEL_RE, with any letter or digit allowed because its URL parser turns an international name into
// the ASCII `xn--` form before it looks.
final _hostLabel = RegExp(r'^[\p{L}\p{N}](?:[\p{L}\p{N}-]*[\p{L}\p{N}])?$', unicode: true);
final _topLevel = RegExp(r'^\p{L}{2,}$', unicode: true);

/// Would the API accept this as a website? The website's `isWebsiteUrl`, rule for rule: the API's `@IsUrl()` with the
/// scheme optional. A scheme is optional (acme.com is fine), http, https or ftp only, no whitespace anywhere, at most
/// 2,084 characters, a host of two or more dot-separated labels (letters, digits and inner hyphens) ending in a
/// letters-only top level, or an IPv4 address; no underscore in the host.
bool isWebsiteUrl(String value) {
  if (value.isEmpty || value.length > websiteMaxLength || RegExp(r'\s').hasMatch(value)) return false;
  final Uri? url = Uri.tryParse(_scheme.hasMatch(value) ? value : 'https://$value');
  if (url == null) return false;
  final protocol = url.scheme.toLowerCase();
  if (protocol != 'http' && protocol != 'https' && protocol != 'ftp') return false;
  if (url.hasPort && url.port > 65535) return false;
  // Dart writes an international host percent-encoded (b%C3%BCcher.de); the website's parser reads it as letters.
  final String host;
  try {
    host = Uri.decodeComponent(url.host);
  } on FormatException {
    return false;
  }
  if (host.isEmpty || host.contains('_')) return false;
  if (_ipv4.hasMatch(host)) return true;
  final labels = host.split('.');
  if (labels.length < 2 || !labels.every(_hostLabel.hasMatch)) return false;
  return _topLevel.hasMatch(labels.last) || labels.last.toLowerCase().startsWith('xn--');
}

/// The message under the website field, or null: blank is "not set", not an error.
String? websiteProblem(String value) {
  final s = value.trim();
  if (s.isEmpty) return null;
  return isWebsiteUrl(s) ? null : websiteSentence;
}

// --- the documents (`CompanyDocumentsPanel`) -----------------------------------------------------------------------

/// The three files a company may file as it is created, each beside the fact it proves. All optional: each is a
/// PRIVATE `employer-kyc` upload that the company check later finds already on file.
enum CompanyDocument { incorporationDoc, panDoc, gstDoc }

/// What the registration certificate is called for the organisation types that have one
/// (`INCORPORATION_PROOF_LABELS`); the other types have none.
const _certificateNames = {
  'PRIVATE_LIMITED': 'Certificate of Incorporation',
  'PUBLIC_LIMITED': 'Certificate of Incorporation',
  'LLP': 'LLP Incorporation Certificate',
  'PARTNERSHIP': 'Partnership deed or registration certificate',
  'TRUST_NGO': 'Trust deed or Societies Act registration certificate',
};

bool needsIncorporationProof(String? legalStructure) => _certificateNames.containsKey(legalStructure);

/// The documents the organisation type is offered, in the order the form lists them: the registration certificate only
/// for a type that has one, then the PAN card, then the GST certificate.
List<CompanyDocument> documentsFor(String? legalStructure) => [
  if (legalStructure != null) ...[
    if (needsIncorporationProof(legalStructure)) CompanyDocument.incorporationDoc,
    CompanyDocument.panDoc,
    CompanyDocument.gstDoc,
  ],
];

/// What the document is called for this organisation type (`employerDocumentLabel`).
String documentLabel(CompanyDocument doc, String? legalStructure) => switch (doc) {
  CompanyDocument.incorporationDoc => _certificateNames[legalStructure] ?? 'Registration certificate',
  CompanyDocument.panDoc => 'PAN card',
  CompanyDocument.gstDoc => 'GST certificate',
};

/// Why the document is asked, in the panel's words.
String documentWhy(CompanyDocument doc, String? legalStructure) => switch (doc) {
  CompanyDocument.incorporationDoc => switch (legalStructure) {
    'PARTNERSHIP' => 'The registered deed, or the Registrar of Firms certificate.',
    'TRUST_NGO' => 'The registered deed, or the certificate under the Societies Act.',
    _ => 'Issued by the Registrar of Companies (MCA).',
  },
  CompanyDocument.panDoc =>
    legalStructure == 'SOLE_PROPRIETORSHIP' ? 'The proprietor’s own PAN card.' : 'Issued in the organisation’s name.',
  CompanyDocument.gstDoc => 'Only if the business is registered for GST.',
};

/// The small tag beside a document's name: what the company check will need, said up front.
String documentNeed(CompanyDocument doc) => doc == CompanyDocument.gstDoc ? 'If registered' : 'Needed to verify';

/// The panel's heading for an organisation type.
String documentsHeading(String legalStructure) => switch (legalStructure) {
  'PRIVATE_LIMITED' => 'Documents for a private limited company',
  'PUBLIC_LIMITED' => 'Documents for a public limited company',
  'LLP' => 'Documents for an LLP',
  'PARTNERSHIP' => 'Documents for a partnership firm',
  'SOLE_PROPRIETORSHIP' => 'Documents for a sole proprietorship',
  'GOVERNMENT' => 'Documents for a government body or PSU',
  'TRUST_NGO' => 'Documents for a trust, NGO or society',
  _ => 'Documents for your organisation',
};

/// What the panel says for a type with no registration certificate; null for a type that has one.
String? noCertificateNote(String legalStructure) => switch (legalStructure) {
  'SOLE_PROPRIETORSHIP' => 'A sole proprietorship has no registration certificate, so none is asked.',
  'GOVERNMENT' => 'A government body or PSU has no registrar’s certificate, so none is asked.',
  'OTHER' =>
    'There is no set certificate for this type. ICR’s reviewer asks for the right proof when the company is verified.',
  _ => null,
};

const documentsOptionalNow =
    'Optional now. Add them and the company check starts with them on file. Skip, and we ask the first time you post a '
    'job, bid or sell.';
const documentsPrivate = 'Kept private, never shown on the company page. PDF, JPG, PNG or WebP, up to 10 MB each.';
const documentUploadFailed = 'Upload failed. Use a PDF or image under 10 MB.';

/// The most the upload endpoint takes (`MAX_BYTES` in `uploads.controller.ts`).
const documentMaxBytes = 10 * 1024 * 1024;
const _documentTypes = {'application/pdf', 'image/png', 'image/jpeg', 'image/webp'};

/// An uploaded file: its `/uploads/...` path and the name it had.
typedef UploadedDocument = ({String url, String name});

// --- places beyond ICR's city list (`usePlaceSearch`) --------------------------------------------------------------

/// A place anywhere in the world (`GET /locations/search`): the website's head-office search finds these beyond ICR's
/// own city list. A foreign place has no city row, so its id only tells it apart.
CityOption? placeOption(Map<String, dynamic> p) {
  final label = (p['label'] as String?)?.trim();
  if (label == null || label.isEmpty) return null;
  final id = 'place:${label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}';
  final state = p['state'];
  return CityOption(
    id: id.length > 40 ? id.substring(0, 40) : id,
    name: label,
    // A foreign label already carries its state and country; only an Indian place passes its state on.
    state: state is String && state.isNotEmpty && p['countryCode'] == 'IN' ? state : null,
  );
}

/// The draft with the documents the form holds, as `POST /me/companies` takes them. [CompanyDraft] carries the answers
/// every company has; these three are optional and only offered by organisation type.
class FoundingDraft extends CompanyDraft {
  const FoundingDraft({
    required super.name,
    required super.industry,
    required super.size,
    required super.legalStructure,
    required super.city,
    super.state,
    super.legalName,
    super.website,
    super.description,
    super.logoUrl,
    this.documents = const {},
  });

  final Map<CompanyDocument, UploadedDocument> documents;

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    for (final e in documents.entries) ...{'${e.key.name}Url': e.value.url, '${e.key.name}Name': e.value.name},
  };
}

/// "Create a company page", one screen like a LinkedIn page: who the company
/// is (name, industry, size, organisation type, head-office city), a tick that
/// the person may act for it, and optionally a website, logo, tagline and the
/// registered legal name, plus the optional documents the organisation type files. Any member may (ICR staff accounts are
/// personal and cannot: [canJoinCompanies]); they become its admin and act for it, and a person already acting for
/// another company may found one more.
///
/// It never demands a tax ID, a document, an address or a contact: those are
/// proof, asked by the company check the first time an action needs trust. The
/// documents it offers are optional.
class CreateCompanyController extends ChangeNotifier {
  CreateCompanyController({
    required this.repository,
    required this.adopt,
    this.onSessionChanged,
    this.lookalikeDelay = const Duration(milliseconds: 400),
  });

  final AccountRepository repository;
  final SessionAdopter adopt;
  final VoidCallback? onSessionChanged;

  /// How long typing settles before companies that look alike are asked for.
  final Duration lookalikeDelay;

  // --- the answers ---------------------------------------------------------------------------------------------

  String name = '';
  bool legalNameDiffers = false;
  String legalName = '';
  String website = '';
  String? industry;
  CityOption? city;
  String? size;
  String? legalStructure;
  String description = '';
  bool authorised = false;

  /// The optional documents, by kind. Only the ones the organisation type is offered are sent ([documentsFor]).
  final Map<CompanyDocument, UploadedDocument> documents = {};
  final Set<CompanyDocument> documentsBusy = {};
  final Map<CompanyDocument, String> documentErrors = {};

  /// The uploaded logo's `/uploads/...` path, and the bytes shown as its preview.
  String? logoUrl;
  Uint8List? logoPreview;
  bool logoBusy = false;
  String? logoError;

  // --- lookups -------------------------------------------------------------------------------------------------

  List<IndustryOption> industryOptions = const [];
  List<CityOption> cities = const [];
  bool citiesLoading = false;
  String? citiesError;

  /// Companies already on ICR that look like this one: a suggestion, never a block.
  List<CompanyLookalike> lookalikes = const [];

  /// Companies the person has already asked to join from here.
  final Set<String> askedToJoin = {};

  /// Whether the person may found a company at all: false for ICR staff, whose accounts are personal. Unknown (null)
  /// until `GET /me/companies` answers, and the form is drawn meanwhile, as the website does.
  bool? canJoinCompanies;

  /// Companies the person has a request waiting at, from before this screen opened.
  Set<String> requestedBefore = const {};

  /// Companies whose admin has already added the person (an invitation waits on Your companies).
  Set<String> invitedBy = const {};

  // --- state ---------------------------------------------------------------------------------------------------

  Map<CompanyField, String> errors = {};
  bool submitting = false;

  /// What the API refused with; the answers stay as typed.
  String? submitError;

  /// Set once the company exists: the screen turns into the welcome state.
  MyCompany? created;

  Timer? _lookalikeTimer;
  String _lookalikeAsked = '';
  bool _disposed = false;

  /// Something has been typed or chosen: leaving asks first.
  bool get dirty =>
      created == null &&
      (name.trim().isNotEmpty ||
          website.trim().isNotEmpty ||
          description.trim().isNotEmpty ||
          legalName.trim().isNotEmpty ||
          industry != null ||
          city != null ||
          size != null ||
          legalStructure != null ||
          logoUrl != null ||
          documents.isNotEmpty ||
          authorised);

  /// The answers still missing, in the form's order, for the "Ready to create" count.
  int get requiredCount => 6;

  @override
  void dispose() {
    _disposed = true;
    _lookalikeTimer?.cancel();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Reads the lists the pickers need and asks for look-alikes once, as the
  /// website does on opening: with nothing typed the API still looks for
  /// colleagues on the person's own corporate email domain.
  Future<void> start() async {
    // Who the person is decides whether the page is theirs to open, and which suggestions they have already answered.
    unawaited(_readStanding());
    industryOptions = await loadIndustries(repository);
    _notify();
    await _askLookalikes();
  }

  Future<void> _readStanding() async {
    try {
      final mine = await repository.myCompanies();
      if (_disposed) return;
      canJoinCompanies = mine.canJoinCompanies;
      requestedBefore = {for (final r in mine.requests) r.companyId};
      invitedBy = {for (final i in mine.invitations) i.companyId};
      _notify();
    } catch (_) {
      // The form carries on: the API itself refuses a staff account, in its own sentence.
    }
  }

  /// A fixed answer drops its own message rather than staying red.
  void _fixed(CompanyField field) {
    if (errors.isEmpty) return;
    errors = {...errors}..remove(field);
  }

  // --- the answers' setters -------------------------------------------------------------------------------------

  void setName(String v) {
    name = v;
    _fixed(CompanyField.name);
    _scheduleLookalikes();
    _notify();
  }

  void setLegalNameDiffers(bool v) {
    legalNameDiffers = v;
    _fixed(CompanyField.legalName);
    _notify();
  }

  void setLegalName(String v) {
    legalName = v;
    _fixed(CompanyField.legalName);
    _notify();
  }

  void setWebsite(String v) {
    website = v;
    _fixed(CompanyField.website);
    _scheduleLookalikes();
    _notify();
  }

  void setIndustry(String? v) {
    industry = v;
    _fixed(CompanyField.industry);
    _notify();
  }

  void setCity(CityOption? v) {
    city = v;
    _fixed(CompanyField.city);
    _notify();
  }

  void setSize(String? v) {
    size = v;
    _fixed(CompanyField.size);
    _notify();
  }

  void setLegalStructure(String? v) {
    legalStructure = v;
    _fixed(CompanyField.legalStructure);
    _notify();
  }

  void setDescription(String v) {
    description = v;
    _notify();
  }

  void setAuthorised(bool v) {
    authorised = v;
    _fixed(CompanyField.authorised);
    _notify();
  }

  // --- the city list -------------------------------------------------------------------------------------------

  /// The cities for the picker, read the first time it opens.
  Future<void> loadCities() async {
    if (cities.isNotEmpty || citiesLoading) return;
    citiesLoading = true;
    citiesError = null;
    _notify();
    try {
      cities = await repository.cities();
    } catch (e) {
      citiesError = ApiError.from(e).message;
    } finally {
      citiesLoading = false;
      _notify();
    }
  }

  /// Places anywhere in the world for what was typed, beyond ICR's own city list: the website's "Elsewhere" search.
  /// Two letters at least; a place ICR already lists by name is left out, as the website does. Empty without the API.
  Future<List<CityOption>> searchPlaces(String query) async {
    final q = query.trim();
    final repo = repository;
    if (q.length < 2 || repo is! ApiAccountRepository) return const [];
    try {
      final res = await repo.api.dio.get<dynamic>('/locations/search', queryParameters: {'q': q});
      final data = res.data;
      final rows = data is List ? data : (data is Map ? data['data'] as List? : null) ?? const [];
      final listed = {for (final c in cities) c.name.toLowerCase()};
      final found = <CityOption>[];
      for (final r in rows) {
        final place = r is Map ? placeOption(r.cast<String, dynamic>()) : null;
        if (place != null && !listed.contains(place.name.toLowerCase())) found.add(place);
      }
      return found;
    } catch (_) {
      // A suggestion list: when it cannot be read, the cities ICR lists are still there.
      return const [];
    }
  }

  // --- look-alikes ---------------------------------------------------------------------------------------------

  void _scheduleLookalikes() {
    _lookalikeTimer?.cancel();
    _lookalikeTimer = Timer(lookalikeDelay, _askLookalikes);
  }

  Future<void> _askLookalikes() async {
    final n = name.trim();
    final w = website.trim();
    final asked = '$n\u0000$w';
    _lookalikeAsked = asked;
    try {
      final found = await repository.lookalikes(name: n, website: w);
      // An older answer must not overwrite the one for what is typed now.
      if (_disposed || _lookalikeAsked != asked) return;
      lookalikes = found;
      _notify();
    } catch (_) {
      // A suggestion only: when it cannot be fetched the form carries on without it.
    }
  }

  /// Asks the admins of [company] to add the person. Null when sent, else the API's sentence.
  Future<String?> askToJoin(String companyId, String? note) async {
    try {
      await repository.requestToJoin(companyId, note: note);
    } catch (e) {
      return ApiError.from(e).message;
    }
    askedToJoin.add(companyId);
    _notify();
    return null;
  }

  // --- the logo ------------------------------------------------------------------------------------------------

  /// Uploads a logo the person chose. Nothing else on the form is touched when it fails.
  Future<void> setLogo(PickedPhoto photo) async {
    logoError = null;
    // The website's order: not a picture at all, then a picture of a type the API does not store, then its weight.
    if (!photo.contentType.startsWith('image/')) {
      logoError = logoNotAnImage;
      _notify();
      return;
    }
    if (!_logoTypes.contains(photo.contentType)) {
      logoError = logoTypeNotAccepted(photo.contentType);
      _notify();
      return;
    }
    if (photo.bytes.length > logoMaxBytes) {
      logoError = logoTooBig;
      _notify();
      return;
    }
    logoBusy = true;
    _notify();
    try {
      final file = await repository.upload(photo, purpose: 'company');
      logoUrl = file.url;
      logoPreview = Uint8List.fromList(photo.bytes);
    } catch (e) {
      logoError = _uploadSentence(e, logoUploadFailed);
    } finally {
      logoBusy = false;
      _notify();
    }
  }

  /// The API's sentence for a failed upload, "Can't reach ICR…" when nothing answered, else [fallback]
  /// (`errorMessage(e, fallback)` on the website).
  String _uploadSentence(Object e, String fallback) {
    final error = ApiError.from(e);
    return error.isOffline ? error.message : apiSentence(error, fallback);
  }

  void removeLogo() {
    logoUrl = null;
    logoPreview = null;
    logoError = null;
    _notify();
  }

  // --- the documents -------------------------------------------------------------------------------------------

  /// Uploads one document, PRIVATE (`employer-kyc`), a PDF or a picture up to 10 MB. Nothing else on the form moves.
  Future<void> setDocument(CompanyDocument kind, PickedPhoto file) async {
    if (documentsBusy.contains(kind)) return;
    documentErrors.remove(kind);
    if (!_documentTypes.contains(file.contentType) || file.bytes.length > documentMaxBytes) {
      documentErrors[kind] = documentUploadFailed;
      _notify();
      return;
    }
    documentsBusy.add(kind);
    _notify();
    try {
      final uploaded = await repository.upload(file, purpose: 'employer-kyc');
      documents[kind] = (url: uploaded.url, name: uploaded.name);
    } catch (e) {
      documentErrors[kind] = _uploadSentence(e, documentUploadFailed);
    } finally {
      documentsBusy.remove(kind);
      _notify();
    }
  }

  void removeDocument(CompanyDocument kind) {
    documents.remove(kind);
    documentErrors.remove(kind);
    _notify();
  }

  /// The documents the chosen type is offered and the person added: a certificate uploaded under "Private limited" is
  /// dropped when they then pick "Sole proprietorship", which has none.
  Map<CompanyDocument, UploadedDocument> get documentsToSend => {
    for (final kind in documentsFor(legalStructure)) kind: ?documents[kind],
  };

  // --- create --------------------------------------------------------------------------------------------------

  /// The first field that is wrong, or null.
  CompanyField? get firstProblem {
    for (final f in CompanyField.values) {
      if (errors.containsKey(f)) return f;
    }
    return null;
  }

  Map<CompanyField, String> validate() {
    final found = companyProblems(
      name: name,
      differentLegalName: legalNameDiffers,
      legalName: legalName,
      // Judged below by the website's own rule (`isWebsiteUrl`), which is stricter than `companyProblems`'s.
      website: '',
      industry: industry,
      size: size,
      legalStructure: legalStructure,
      city: city?.name,
      authorised: authorised,
    );
    return {for (final f in CompanyField.values) f: ?found[f.name], CompanyField.website: ?websiteProblem(website)};
  }

  CompanyDraft get draft => FoundingDraft(
    name: name,
    industry: industry!,
    size: size!,
    legalStructure: legalStructure!,
    city: city!.name,
    state: city!.state,
    legalName: legalNameDiffers ? legalName : null,
    website: website,
    description: description,
    logoUrl: logoUrl,
    documents: documentsToSend,
  );

  /// Creates the page. A second press while one is running does nothing, so a
  /// double tap founds one company, not two. False when the form is not
  /// complete (see [errors]) or the API refused (see [submitError]).
  Future<bool> submit() async {
    if (submitting || created != null) return false;
    submitError = null;
    errors = validate();
    if (errors.isNotEmpty) {
      _notify();
      return false;
    }
    submitting = true;
    _notify();
    try {
      final tokens = await repository.createCompany(draft);
      await adopt(tokens);
      onSessionChanged?.call();
      created = await _founded(tokens);
      return true;
    } catch (e) {
      final error = ApiError.from(e);
      // The API allows five new pages an hour; its limiter's own words ("Too Many Requests") say nothing to a member.
      submitError = error.statusCode == 429
          ? 'You have created several companies in the last hour. Try again a little later.'
          : apiSentence(error, couldNotCreate);
      return false;
    } finally {
      submitting = false;
      _notify();
    }
  }

  /// The company just founded, as the list reads it. The page exists whatever
  /// this read does, so a failed read never turns the success into an error.
  Future<MyCompany> _founded(SessionTokens tokens) async {
    final id = tokens.user?['companyId'] as String?;
    try {
      final mine = await repository.myCompanies();
      for (final c in mine.companies) {
        if (id != null ? c.companyId == id : c.active) return c;
      }
    } catch (_) {
      // Fall through to what the session itself says.
    }
    return MyCompany(
      companyId: id ?? '',
      name: name.trim(),
      role: 'COMPANY_ADMIN',
      logoUrl: logoUrl,
      active: true,
      city: city?.name,
      state: city?.state,
      industry: industry,
      soleAdmin: true,
    );
  }
}
