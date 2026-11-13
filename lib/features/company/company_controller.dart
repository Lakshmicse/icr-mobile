import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import '../account/account_models.dart' show CityOption, PickedPhoto, UploadedFile;
import '../account/companies/company_lookups.dart' show IndustryOption;
import 'company_fields.dart';
import 'company_models.dart';
import 'company_repository.dart';

/// The company workspace on screen: the profile read first (it decides every tab), then everything each card reads
/// on its own and fails on its own — the company check, the supplier standing, the plans, the team's size, the
/// figures, the certifications, the evidence and its history — and the changes the page makes.
class CompanyController extends ChangeNotifier {
  CompanyController(this.repository, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final CompanyRepository repository;
  final DateTime Function() _clock;

  CompanyProfile? profile;
  bool loading = false;
  String? error;

  EmployerGate? gate;
  bool gateFailed = false;
  EmployerDossier? dossier;
  bool dossierLoaded = false;
  SupplierAccess? access;
  CompanyPlan? hiringPlan;
  CompanyPlan? supplierPlan;
  CompanyStanding? standing;
  CompanyGlance glance = const CompanyGlance();
  List<CompanyCertification>? certifications;
  bool certificationsFailed = false;
  List<CertificationType> types = const [];
  List<VerificationDocument> evidence = const [];
  List<VerificationEvent> history = const [];
  List<IndustryOption>? industries;
  List<StateOption>? states;
  List<CityOption>? cities;

  /// The company declares it is not registered for GST — the dossier's fact, not the profile's; seeded from the one
  /// last filed, once it arrives.
  bool gstNotRegistered = false;
  bool _declarationSeeded = false;

  /// A check is on its way to ICR.
  bool filing = false;

  /// The check was just filed: the page says so once.
  bool filed = false;

  int _generation = 0;
  bool _disposed = false;

  DateTime now() => _clock();

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // --- what the page reads off the profile ---------------------------------------------------------------------

  CompanyDetails? get company => profile?.company;
  String get role => profile?.role ?? '';
  bool get sells => profile?.sells ?? false;
  bool get hasCompany => profile?.hasCompany ?? false;

  /// Acting for no company (ICR staff work across companies and never lack one).
  bool get lacksCompany => profile != null && profile!.activeCompanyId == null && role != 'SUPER_ADMIN';

  /// The role may edit the company profile: the page is never shown to someone whose every save the API refuses.
  bool get mayEdit => companyProfileEditors.contains(role);

  /// This member may file the company check.
  bool get files => kycFilers.contains(role);
  bool get runsWorkspace => workspaceRoles.contains(role);
  bool get hires => recruiterTier.contains(role);
  bool get canStartSelling => canStartSellingRoles.contains(role);

  /// An open re-verification request on a verified company.
  ReverifyRequest? get reverify => dossier?.status == 'VERIFIED' ? dossier?.reverify : null;
  bool get reverifyOpen => reverify?.open ?? false;

  /// The documents an open re-verification lets a verified company upload again.
  List<CompanyFieldKey> get unlocked => reverifyUnlockedFields(reverify);

  bool locked(CompanyFieldKey key) => isCompanyFieldLocked(key, company, unlocked: unlocked);

  bool get gstBlank => company?.gstNumber == null;
  bool get declared => gstNotRegistered && gstBlank;

  List<KycChecklistItem> get checklist => reverifyOpen
      ? reverifyChecklist(company, reverify!, dossier?.documents ?? const [])
      : kycChecklist(company, gstNotRegistered: declared);

  bool get ready => checklist.every((c) => c.done);

  /// The check may be filed now: by this member, in this state, with the dossier known.
  bool get mayFile => hasCompany && files && dossierLoaded && canFileInState(dossier?.status, reverify);

  // --- reading -------------------------------------------------------------------------------------------------

  Future<void> start() => refresh();

  Future<void> refresh() async {
    final generation = ++_generation;
    loading = true;
    error = null;
    _notify();
    try {
      final p = await repository.profile();
      if (generation != _generation) return;
      profile = p;
    } catch (e) {
      if (generation != _generation) return;
      error = ApiError.from(e).message;
    } finally {
      if (generation == _generation) {
        loading = false;
        _notify();
      }
    }
    if (profile == null) return;
    await _loadRest(generation);
  }

  Future<void> _loadRest(int generation) async {
    final p = profile!;
    final company = p.company;
    final companyId = p.activeCompanyId;
    bool live() => generation == _generation && !_disposed;

    Future<void> read(Future<void> Function() body, {void Function()? onFail}) async {
      try {
        await body();
      } catch (_) {
        if (live()) onFail?.call();
      }
      if (live()) _notify();
    }

    final jobs = <Future<void>>[read(() async => standing = await repository.standing())];
    if (company != null && companyId != null) {
      jobs.addAll([
        read(() async => gate = await repository.gate(), onFail: () => gateFailed = true),
        read(() async {
          dossier = await repository.dossier();
          dossierLoaded = true;
          if (!_declarationSeeded && dossier != null) {
            _declarationSeeded = true;
            gstNotRegistered = dossier!.gstNotRegistered;
          }
        }, onFail: () => dossierLoaded = true),
        if (role != 'VENDOR') read(() async => hiringPlan = await repository.plan('COMPANY')),
        if (p.sells) read(() async => supplierPlan = await repository.plan('SUPPLIER')),
        if (runsWorkspace)
          read(() async {
            // Awaited first: `glance` is read after the answer, so the parallel reads never overwrite each other.
            final n = await repository.officeCount(companyId);
            glance = glance.copyWith(offices: n);
          }),
        if (hires)
          read(() async {
            final n = await repository.count('/jobs', companyId);
            glance = glance.copyWith(openJobs: n);
          }),
        if (p.sells && runsWorkspace) ...[
          read(() async {
            final n = await repository.count('/products', companyId);
            glance = glance.copyWith(products: n);
          }),
          read(() async {
            final n = await repository.count('/services', companyId);
            glance = glance.copyWith(services: n);
          }),
        ],
        read(
          () async => certifications = await repository.certifications(own: runsWorkspace, companyId: companyId),
          onFail: () => certificationsFailed = true,
        ),
        if (p.sells && runsWorkspace) read(() async => types = await repository.certificationTypes()),
      ]);
      if (p.sells) {
        final vendorId = p.vendor!.id;
        jobs.addAll([
          read(() async => access = await repository.supplierAccess()),
          read(() async => evidence = await repository.verificationDocuments(vendorId)),
          read(() async => history = await repository.verificationHistory(vendorId)),
        ]);
      }
    }
    await Future.wait(jobs);
  }

  /// Re-reads the profile without blanking the page: the completeness and the row after a save.
  Future<void> _reloadProfile() async {
    try {
      final p = await repository.profile();
      if (_disposed) return;
      profile = p;
      _notify();
    } catch (_) {
      // The save stood; the figures catch up on the next refresh.
    }
  }

  Future<void> _reloadCheck() async {
    try {
      final results = await Future.wait([repository.gate(), repository.dossier()]);
      if (_disposed) return;
      gate = results[0] as EmployerGate;
      dossier = results[1] as EmployerDossier?;
      dossierLoaded = true;
      _notify();
    } catch (_) {
      // Shown as it was.
    }
  }

  // --- lookups the sheets need -----------------------------------------------------------------------------------

  Future<List<IndustryOption>> loadIndustries() async => industries ??= await repository.industries();

  Future<List<StateOption>> loadStates() async {
    try {
      return states ??= await repository.states();
    } catch (_) {
      return const [];
    }
  }

  Future<List<CityOption>> loadCities() async {
    try {
      return cities ??= await repository.cities();
    } catch (_) {
      return const [];
    }
  }

  // --- changes -------------------------------------------------------------------------------------------------

  void setGstNotRegistered(bool v) {
    gstNotRegistered = v;
    _notify();
  }

  /// Saves only the fields that changed. Throws the API's refusal; the sheet keeps what was typed.
  Future<void> saveDetails(Map<String, Object?> patch) async {
    if (patch.isEmpty) return;
    final saved = await repository.updateCompany(patch);
    if (_disposed) return;
    // The API's row is the truth; a partial answer still carries at least what was sent.
    final current = company;
    profile = profile?.copyWith(
      company: saved.raw.length > patch.length || current == null ? saved : current.merged(patch),
    );
    filed = false;
    _notify();
    await _reloadProfile();
  }

  /// `POST /uploads`, as a sheet's document or the logo picker needs it.
  Future<UploadedFile> upload(PickedPhoto file, {required String purpose}) => repository.upload(file, purpose: purpose);

  /// A new logo: uploaded, then saved on the company at once, as the website does.
  Future<void> saveLogo(PickedPhoto photo) async {
    final file = await repository.upload(photo, purpose: 'company');
    await saveDetails({'logoUrl': file.url});
  }

  /// Files the company check from the company as saved. Null when sent, else the API's sentence.
  Future<String?> fileCheck() async {
    if (filing) return null;
    final c = company;
    if (c == null) return 'Add the company’s details first.';
    filing = true;
    filed = false;
    _notify();
    try {
      final draft = reverifyOpen && dossier != null
          ? dossierForReverification(c, dossier!)
          : dossierFromCompany(c, gstNotRegistered: declared);
      dossier = await repository.submitCheck(draft);
      dossierLoaded = true;
      filed = true;
      await _reloadCheck();
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    } finally {
      filing = false;
      _notify();
    }
  }

  /// Asks for a supplier level with the evidence uploaded. Null when sent, else the API's sentence.
  Future<String?> requestLevel(String level, List<UploadedEvidence> documents) async {
    final vendorId = access?.vendorId ?? profile?.vendor?.id;
    if (vendorId == null) return 'Selling starts from a company page.';
    try {
      await repository.requestLevel(vendorId, LevelRequest(level: level, documents: documents));
    } catch (e) {
      return ApiError.from(e).message;
    }
    if (_disposed) return null;
    try {
      final results = await Future.wait([
        repository.supplierAccess(),
        repository.verificationDocuments(vendorId),
        repository.verificationHistory(vendorId),
      ]);
      if (_disposed) return null;
      access = results[0] as SupplierAccess?;
      evidence = results[1] as List<VerificationDocument>;
      history = results[2] as List<VerificationEvent>;
    } catch (_) {
      // Sent; the standing catches up on the next refresh.
    }
    _notify();
    return null;
  }

  /// Records a certification. Throws the API's refusal; the sheet keeps what was typed.
  Future<void> recordCertification(CertificationDraft draft) async {
    await repository.recordCertification(draft);
    if (_disposed) return;
    final companyId = profile?.activeCompanyId;
    if (companyId != null) {
      try {
        certifications = await repository.certifications(own: runsWorkspace, companyId: companyId);
      } catch (_) {
        // Recorded; the list catches up on the next refresh.
      }
    }
    _notify();
  }

  /// "Start selling": the company's supplier listing, one tap, as the website. Null when done, else the sentence.
  Future<String?> startSelling() async {
    final companyId = profile?.activeCompanyId;
    if (companyId == null) return 'Selling starts from a company page.';
    try {
      await repository.startSelling(companyId);
    } catch (e) {
      return ApiError.from(e).message;
    }
    await refresh();
    return null;
  }
}
