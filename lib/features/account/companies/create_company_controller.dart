import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/api/api_error.dart';
import '../account_models.dart';
import '../account_repository.dart';
import '../account_rules.dart';
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

/// The logo limits the website's `LogoDropzone` enforces before it uploads.
const logoMaxBytes = 2 * 1024 * 1024;
const _logoTypes = {'image/png', 'image/jpeg', 'image/webp'};

/// "Create a company page", one screen like a LinkedIn page: who the company
/// is (name, industry, size, organisation type, head-office city), a tick that
/// the person may act for it, and optionally a website, logo, tagline and the
/// registered legal name. Any member may; they become its admin and act for it.
///
/// It never asks a tax ID, a document, an address or a contact: those are
/// proof, asked by the company check the first time an action needs trust.
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
    industryOptions = await loadIndustries(repository);
    _notify();
    await _askLookalikes();
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
    if (!_logoTypes.contains(photo.contentType)) {
      logoError = 'That file is not accepted. Use a PNG, JPG or WEBP image.';
      _notify();
      return;
    }
    if (photo.bytes.length > logoMaxBytes) {
      logoError = 'That image is over 2MB. Compress it or choose a smaller one.';
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
      logoError = ApiError.from(e).message;
    } finally {
      logoBusy = false;
      _notify();
    }
  }

  void removeLogo() {
    logoUrl = null;
    logoPreview = null;
    logoError = null;
    _notify();
  }

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
      website: website,
      industry: industry,
      size: size,
      legalStructure: legalStructure,
      city: city?.name,
      authorised: authorised,
    );
    return {
      for (final f in CompanyField.values)
        if (found[f.name] != null) f: found[f.name]!,
    };
  }

  CompanyDraft get draft => CompanyDraft(
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
      submitError = error.statusCode == 429
          ? 'You have created several companies in the last hour. Try again a little later.'
          : error.message;
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
