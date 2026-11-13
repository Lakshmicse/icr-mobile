import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../account/account_labels.dart' as labels show industries;
import '../account/account_models.dart' show CityOption, PickedPhoto, UploadedFile;
import '../account/companies/company_lookups.dart' show IndustryOption;
import 'company_models.dart';

/// Everything the company workspace reads and changes — the website's `/company` page, call for call.
abstract class CompanyRepository {
  /// `GET /users/me/profile`: the company acted for, its listing and the company's completeness.
  Future<CompanyProfile> profile();

  /// `GET /employer-verification/gate`.
  Future<EmployerGate> gate();

  /// `GET /employer-verification/me`: the dossier, null before the company ever filed.
  Future<EmployerDossier?> dossier();

  /// `GET /vendors/me/access`: the supplier listing's standing; null for a role the route refuses.
  Future<SupplierAccess?> supplierAccess();

  /// `GET /subscriptions/me?audience=COMPANY|SUPPLIER`.
  Future<CompanyPlan> plan(String audience);

  /// `GET /me/companies`: the active company's member count and how many companies the person belongs to.
  Future<CompanyStanding> standing();

  /// `GET <path>?companyId=&limit=1`, its `meta.total`.
  Future<int> count(String path, String companyId);

  /// `GET /branches?companyId=`: how many offices.
  Future<int> officeCount(String companyId);

  /// `GET /certifications/me` (the workspace roles' own records), else `GET /certifications/verified?companyId=`.
  Future<List<CompanyCertification>> certifications({required bool own, required String companyId});

  /// `GET /certifications/types`.
  Future<List<CertificationType>> certificationTypes();

  /// `GET /vendors/:id/verification-documents`.
  Future<List<VerificationDocument>> verificationDocuments(String vendorId);

  /// `GET /vendors/:id/verification-history`.
  Future<List<VerificationEvent>> verificationHistory(String vendorId);

  /// `GET /masters`, the industries; the seeded list when it cannot be read.
  Future<List<IndustryOption>> industries();

  /// `GET /locations/states`.
  Future<List<StateOption>> states();

  /// `GET /locations/cities`.
  Future<List<CityOption>> cities();

  /// `PATCH /companies/me` with only the fields that changed. Returns the row as saved.
  Future<CompanyDetails> updateCompany(Map<String, Object?> patch);

  /// `POST /uploads` (multipart `file`, `?purpose=`).
  Future<UploadedFile> upload(PickedPhoto file, {required String purpose});

  /// `POST /employer-verification/submit`: files the company check.
  Future<EmployerDossier> submitCheck(EmployerDossierDraft draft);

  /// `PATCH /vendors/:id/request-upgrade`: asks for the next supplier level.
  Future<void> requestLevel(String vendorId, LevelRequest request);

  /// `POST /certifications/me`: records a certification the company holds.
  Future<CompanyCertification> recordCertification(CertificationDraft draft);

  /// `POST /vendors { companyId }`: switches selling on, the listing filled from the company.
  Future<void> startSelling(String companyId);
}

class ApiCompanyRepository implements CompanyRepository {
  ApiCompanyRepository({required this.api});

  final ApiClient api;

  Future<T> _call<T>(Future<T> Function(Dio dio) body) async {
    try {
      return await body(api.dio);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Map<String, dynamic> _map(Object? v) => v is Map ? v.cast<String, dynamic>() : const {};

  List<Map<String, dynamic>> _rows(Object? data) {
    final list = data is List ? data : (data is Map ? data['data'] : null);
    return [
      for (final r in list is List ? list : const [])
        if (r is Map) r.cast<String, dynamic>(),
    ];
  }

  @override
  Future<CompanyProfile> profile() =>
      _call((dio) async => CompanyProfile.fromJson(_map((await dio.get<dynamic>('/users/me/profile')).data)));

  @override
  Future<EmployerGate> gate() =>
      _call((dio) async => EmployerGate.fromJson(_map((await dio.get<dynamic>('/employer-verification/gate')).data)));

  @override
  Future<EmployerDossier?> dossier() => _call((dio) async {
    final data = _map((await dio.get<dynamic>('/employer-verification/me')).data);
    final dossier = data['dossier'];
    return dossier is Map ? EmployerDossier.fromJson(dossier.cast<String, dynamic>()) : null;
  });

  @override
  Future<SupplierAccess?> supplierAccess() async {
    try {
      final res = await api.dio.get<dynamic>('/vendors/me/access');
      return SupplierAccess.fromJson(_map(res.data));
    } on DioException catch (e) {
      // The route answers the workspace roles only; anyone else is shown the listing without its standing.
      if (e.response?.statusCode == 403) return null;
      throw ApiError.from(e);
    }
  }

  @override
  Future<CompanyPlan> plan(String audience) => _call((dio) async {
    final res = await dio.get<dynamic>('/subscriptions/me', queryParameters: {'audience': audience});
    return CompanyPlan.fromJson(audience, _map(res.data));
  });

  @override
  Future<CompanyStanding> standing() =>
      _call((dio) async => CompanyStanding.fromJson(_map((await dio.get<dynamic>('/me/companies')).data)));

  @override
  Future<int> count(String path, String companyId) => _call((dio) async {
    final res = await dio.get<dynamic>(path, queryParameters: {'companyId': companyId, 'limit': 1});
    final total = _map(_map(res.data)['meta'])['total'];
    return total is num ? total.toInt() : 0;
  });

  @override
  Future<int> officeCount(String companyId) => _call((dio) async {
    final res = await dio.get<dynamic>('/branches', queryParameters: {'companyId': companyId});
    return _rows(res.data).length;
  });

  @override
  Future<List<CompanyCertification>> certifications({required bool own, required String companyId}) =>
      _call((dio) async {
        final res = own
            ? await dio.get<dynamic>('/certifications/me')
            : await dio.get<dynamic>('/certifications/verified', queryParameters: {'companyId': companyId});
        return [for (final r in _rows(res.data)) CompanyCertification.fromJson(r)];
      });

  @override
  Future<List<CertificationType>> certificationTypes() => _call((dio) async {
    final res = await dio.get<dynamic>('/certifications/types');
    return [for (final r in _rows(res.data)) CertificationType.fromJson(r)];
  });

  @override
  Future<List<VerificationDocument>> verificationDocuments(String vendorId) => _call((dio) async {
    final res = await dio.get<dynamic>('/vendors/${Uri.encodeComponent(vendorId)}/verification-documents');
    return [for (final r in _rows(res.data)) VerificationDocument.fromJson(r)];
  });

  @override
  Future<List<VerificationEvent>> verificationHistory(String vendorId) => _call((dio) async {
    final res = await dio.get<dynamic>('/vendors/${Uri.encodeComponent(vendorId)}/verification-history');
    return [for (final r in _rows(res.data)) VerificationEvent.fromJson(r)];
  });

  @override
  Future<List<IndustryOption>> industries() async {
    try {
      final res = await api.dio.get<dynamic>('/masters');
      final rows = <IndustryOption>[
        for (final row in _map(res.data)['industries'] is List ? _map(res.data)['industries'] as List : const [])
          if (row is Map && row['key'] is String && row['name'] is String)
            (row['key'] as String, row['name'] as String),
      ];
      return rows.isEmpty ? labels.industries : rows;
    } catch (_) {
      return labels.industries;
    }
  }

  @override
  Future<List<StateOption>> states() => _call((dio) async {
    final res = await dio.get<dynamic>('/locations/states');
    return [for (final r in _rows(res.data)) StateOption.fromJson(r)];
  });

  @override
  Future<List<CityOption>> cities() => _call((dio) async {
    final res = await dio.get<dynamic>('/locations/cities');
    return [for (final r in _rows(res.data)) CityOption.fromJson(r)];
  });

  @override
  Future<CompanyDetails> updateCompany(Map<String, Object?> patch) => _call((dio) async {
    final res = await dio.patch<dynamic>('/companies/me', data: patch);
    return CompanyDetails.fromJson(_map(res.data));
  });

  @override
  Future<UploadedFile> upload(PickedPhoto file, {required String purpose}) => _call((dio) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        file.bytes,
        filename: file.name,
        contentType: DioMediaType.parse(file.contentType),
      ),
    });
    final res = await dio.post<dynamic>('/uploads', data: form, queryParameters: {'purpose': purpose});
    final data = _map(res.data);
    return UploadedFile(url: '${data['url']}', name: data['name'] as String? ?? file.name);
  });

  @override
  Future<EmployerDossier> submitCheck(EmployerDossierDraft draft) => _call((dio) async {
    final res = await dio.post<dynamic>('/employer-verification/submit', data: draft.toJson());
    return EmployerDossier.fromJson(_map(res.data));
  });

  @override
  Future<void> requestLevel(String vendorId, LevelRequest request) => _call(
    (dio) => dio.patch<void>('/vendors/${Uri.encodeComponent(vendorId)}/request-upgrade', data: request.toJson()),
  );

  @override
  Future<CompanyCertification> recordCertification(CertificationDraft draft) => _call((dio) async {
    final res = await dio.post<dynamic>('/certifications/me', data: draft.toJson());
    return CompanyCertification.fromJson(_map(res.data));
  });

  @override
  Future<void> startSelling(String companyId) =>
      _call((dio) => dio.post<void>('/vendors', data: {'companyId': companyId}));
}

/// A sample company for the demo and for tests, kept in memory and changed in place. Every write lands in [sent],
/// in order, as `{'call': …, …}`.
class DemoCompanyRepository implements CompanyRepository {
  DemoCompanyRepository({
    this.role = 'COMPANY_ADMIN',
    this.noCompany = false,
    this.sells = true,
    this.checkStatus = 'VERIFIED',
    this.companiesHeld = 2,
    this.delay = Duration.zero,
    this.failProfile = false,
    CompanyDetails? company,
    List<CompanyCertification>? records,
    Completeness? completeness,
  }) : company = company ?? sampleCompany(verified: checkStatus == 'VERIFIED'),
       records = records ?? sampleCertifications(),
       completeness = completeness ?? sampleCompleteness();

  final String role;

  /// The person acts for no company: the page shows the way on instead.
  final bool noCompany;
  bool sells;

  /// The company check: null when never filed, else `SUBMITTED`, `DOCS_REQUESTED`, `VERIFIED`, `REJECTED`,
  /// `SUSPENDED`.
  String? checkStatus;
  final int companiesHeld;
  final Duration delay;
  final bool failProfile;

  CompanyDetails company;

  /// The company's certification records, changed in place by [recordCertification].
  final List<CompanyCertification> records;
  Completeness completeness;
  String supplierLevel = 'VERIFIED';
  String? pendingLevel;
  final List<VerificationDocument> evidence = [
    const VerificationDocument(
      id: 'doc-1',
      name: 'Insurance policy 2026.pdf',
      status: 'PENDING',
      url: '/uploads/acme-insurance.pdf',
    ),
  ];
  final List<VerificationEvent> history = [
    VerificationEvent(
      id: 'ev-2',
      type: 'APPROVED',
      status: 'VERIFIED',
      toLevel: 'VERIFIED',
      createdAt: DateTime(2026, 10, 6),
    ),
    VerificationEvent(
      id: 'ev-1',
      type: 'SUBMITTED',
      status: 'PENDING',
      toLevel: 'VERIFIED',
      createdAt: DateTime(2026, 10, 2),
      note: 'GST certificate and PAN card attached.',
    ),
  ];

  /// Every change sent, in order (tests).
  final sent = <Map<String, Object?>>[];
  int _uploads = 0;

  static const sampleCompanyId = 'company-acme';
  static const sampleVendorId = 'vendor-acme';

  static CompanyDetails sampleCompany({bool verified = true}) => CompanyDetails({
    'id': sampleCompanyId,
    'name': 'Acme Facility Services',
    'legalName': 'Acme Facility Services Private Limited',
    'legalStructure': 'PRIVATE_LIMITED',
    'incorporationDocUrl': '/uploads/acme-coi.pdf',
    'incorporationDocName': 'Certificate of Incorporation.pdf',
    'gstDocUrl': '/uploads/acme-gst.pdf',
    'gstDocName': 'GST certificate.pdf',
    'panDocUrl': '/uploads/acme-pan.pdf',
    'panDocName': 'PAN card.pdf',
    'contactName': 'Ranga Yesminds',
    'contactDesignation': 'Head of Operations',
    'contactAltPhone': null,
    'description': 'Integrated facility management for corporate campuses across South India.',
    'logoUrl': null,
    'website': 'https://acme-fm.example',
    'email': 'ops@acme-fm.example',
    'phone': '+91 80 4000 1234',
    'gstNumber': '27AAACZ1234C1ZR',
    'panNumber': 'AAACZ1234C',
    'addressLine': '14 Residency Road',
    'city': 'Bengaluru',
    'state': 'Karnataka',
    'country': 'India',
    'postalCode': '560025',
    'size': '51-200',
    'industry': 'FM_SERVICES',
    'foundedYear': null,
    'presence': 'PAN_INDIA',
    'verificationStatus': verified ? 'VERIFIED' : 'PENDING',
    'verificationLevel': verified ? 'VERIFIED' : 'REGISTERED',
  });

  static Completeness sampleCompleteness() =>
      const Completeness(score: 85, missing: ['Add the year of establishment', 'Pin the head office on the map']);

  static List<CompanyCertification> sampleCertifications() => [
    CompanyCertification(
      id: 'cert-1',
      certificationTypeId: 'type-iso-9001',
      typeName: 'ISO 9001',
      status: 'VERIFIED',
      documentUrls: const ['/uploads/acme-iso9001.pdf'],
      issuer: 'BSI',
      certificateNumber: 'FS 612345',
      issuedOn: DateTime(2024, 4, 1),
      expiresAt: DateTime(2027, 3, 31),
      shownPublicly: true,
    ),
    const CompanyCertification(
      id: 'cert-2',
      certificationTypeId: 'type-iso-14001',
      typeName: 'ISO 14001',
      status: 'PENDING',
    ),
  ];

  static final sampleTypes = <CertificationType>[
    const CertificationType(id: 'type-iso-9001', name: 'ISO 9001', issuers: ['BSI', 'TUV SUD', 'Bureau Veritas']),
    const CertificationType(id: 'type-iso-14001', name: 'ISO 14001', issuers: ['BSI', 'TUV SUD']),
    const CertificationType(
      id: 'type-msme',
      name: 'MSME / Udyam Registration',
      issuers: ['Ministry of Micro, Small and Medium Enterprises (Udyam)'],
    ),
  ];

  Future<void> _wait() => delay > Duration.zero ? Future<void>.delayed(delay) : Future.value();

  @override
  Future<CompanyProfile> profile() async {
    await _wait();
    if (failProfile) throw ApiError('Could not load your company.');
    if (noCompany) return CompanyProfile(role: role);
    return CompanyProfile(
      role: role,
      activeCompanyId: company.id,
      company: company,
      vendor: sells
          ? SupplierListing(
              id: sampleVendorId,
              headline: 'Acme — full-service facility management',
              categories: const ['HOUSEKEEPING', 'SECURITY'],
              serviceAreas: const ['Bengaluru', 'Chennai'],
              yearsExperience: 8,
              verificationLevel: supplierLevel,
              rating: 4.7,
              ratingCount: 12,
            )
          : null,
      companyCompleteness: completeness,
    );
  }

  @override
  Future<EmployerGate> gate() async {
    await _wait();
    return EmployerGate(
      verified: checkStatus == 'VERIFIED',
      status: checkStatus,
      canPublishJobs: checkStatus == 'VERIFIED',
      decisionNote: checkStatus == 'DOCS_REQUESTED'
          ? 'The PAN card scan is unreadable. Please upload a clear copy.'
          : null,
    );
  }

  @override
  Future<EmployerDossier?> dossier() async {
    await _wait();
    final status = checkStatus;
    if (status == null) return null;
    return EmployerDossier(
      id: 'dossier-1',
      status: status,
      legalName: company.legalName ?? company.name,
      legalStructure: company.legalStructure,
      panNumber: company.panNumber ?? '',
      gstNotRegistered: false,
      gstNumber: company.gstNumber,
      submittedAt: DateTime(2026, 10, 2),
      attemptCount: 1,
      reviewedAt: status == 'VERIFIED' ? DateTime(2026, 10, 6) : null,
      decisionNote: status == 'DOCS_REQUESTED' ? 'The PAN card scan is unreadable. Please upload a clear copy.' : null,
      documents: [
        if (company.panDocUrl != null)
          DossierDocument(kind: 'PAN_CARD', url: company.panDocUrl, name: company.panDocName),
        if (company.gstDocUrl != null)
          DossierDocument(kind: 'GST_CERTIFICATE', url: company.gstDocUrl, name: company.gstDocName),
      ],
    );
  }

  @override
  Future<SupplierAccess?> supplierAccess() async {
    await _wait();
    if (!sells) return const SupplierAccess();
    return SupplierAccess(
      vendorId: sampleVendorId,
      verificationLevel: supplierLevel,
      pendingLevel: pendingLevel,
      verificationStatus: pendingLevel == null ? 'VERIFIED' : 'PENDING',
      ratingCount: 12,
    );
  }

  @override
  Future<CompanyPlan> plan(String audience) async {
    await _wait();
    return audience == 'SUPPLIER'
        ? CompanyPlan(
            audience: audience,
            planName: 'Business',
            tier: 'GOLD',
            currentPeriodEnd: DateTime(2027, 10, 6),
            autoRenew: true,
          )
        : CompanyPlan(audience: audience, planName: 'Talent', tier: 'GOLD', currentPeriodEnd: DateTime(2027, 10, 6));
  }

  @override
  Future<CompanyStanding> standing() async {
    await _wait();
    return CompanyStanding(
      memberCount: noCompany ? null : 6,
      companiesHeld: companiesHeld,
      canJoinCompanies: !{'SUPER_ADMIN', 'LEARNING_ADMIN', 'PARTNER_ADMIN'}.contains(role),
    );
  }

  @override
  Future<int> count(String path, String companyId) async {
    await _wait();
    return switch (path) {
      '/jobs' => 3,
      '/services' => 4,
      _ => 0,
    };
  }

  @override
  Future<int> officeCount(String companyId) async {
    await _wait();
    return 2;
  }

  @override
  Future<List<CompanyCertification>> certifications({required bool own, required String companyId}) async {
    await _wait();
    return own
        ? List.of(records)
        : [
            for (final c in records)
              if (c.shownPublicly) c,
          ];
  }

  @override
  Future<List<CertificationType>> certificationTypes() async {
    await _wait();
    return sampleTypes;
  }

  @override
  Future<List<VerificationDocument>> verificationDocuments(String vendorId) async {
    await _wait();
    return List.of(evidence);
  }

  @override
  Future<List<VerificationEvent>> verificationHistory(String vendorId) async {
    await _wait();
    return List.of(history);
  }

  @override
  Future<List<IndustryOption>> industries() async => labels.industries;

  @override
  Future<List<StateOption>> states() async => const [
    StateOption(id: 'st-ka', name: 'Karnataka', code: 'KA'),
    StateOption(id: 'st-mh', name: 'Maharashtra', code: 'MH'),
    StateOption(id: 'st-tn', name: 'Tamil Nadu', code: 'TN'),
  ];

  @override
  Future<List<CityOption>> cities() async => const [
    CityOption(id: 'c-blr', name: 'Bengaluru', state: 'Karnataka'),
    CityOption(id: 'c-mys', name: 'Mysuru', state: 'Karnataka'),
    CityOption(id: 'c-mum', name: 'Mumbai', state: 'Maharashtra'),
    CityOption(id: 'c-pun', name: 'Pune', state: 'Maharashtra'),
    CityOption(id: 'c-che', name: 'Chennai', state: 'Tamil Nadu'),
  ];

  @override
  Future<CompanyDetails> updateCompany(Map<String, Object?> patch) async {
    await _wait();
    sent.add({'call': 'updateCompany', 'patch': Map<String, Object?>.from(patch)});
    company = company.merged(patch);
    return company;
  }

  @override
  Future<UploadedFile> upload(PickedPhoto file, {required String purpose}) async {
    await _wait();
    _uploads += 1;
    sent.add({'call': 'upload', 'purpose': purpose, 'name': file.name});
    return UploadedFile(url: '/uploads/demo-$_uploads-${file.name}', name: file.name);
  }

  @override
  Future<EmployerDossier> submitCheck(EmployerDossierDraft draft) async {
    await _wait();
    sent.add({'call': 'submitCheck', 'dossier': draft.toJson()});
    checkStatus = 'SUBMITTED';
    return (await dossier())!;
  }

  @override
  Future<void> requestLevel(String vendorId, LevelRequest request) async {
    await _wait();
    sent.add({'call': 'requestLevel', 'vendorId': vendorId, 'request': request.toJson()});
    pendingLevel = request.level;
    for (final d in request.documents) {
      evidence.insert(
        0,
        VerificationDocument(id: 'doc-${evidence.length + 1}', name: d.name, status: 'PENDING', url: d.url),
      );
    }
  }

  @override
  Future<CompanyCertification> recordCertification(CertificationDraft draft) async {
    await _wait();
    sent.add({'call': 'recordCertification', 'draft': draft.toJson()});
    final type = sampleTypes.where((t) => t.id == draft.certificationTypeId).firstOrNull;
    final row = CompanyCertification(
      id: 'cert-${records.length + 1}',
      certificationTypeId: draft.certificationTypeId,
      typeName: type?.name,
      status: 'VERIFIED',
      documentUrls: draft.documentUrls,
      issuer: draft.issuer,
      certificateNumber: draft.certificateNumber,
      issuedOn: draft.issuedOn == null ? null : DateTime.tryParse(draft.issuedOn!),
      expiresAt: draft.expiresAt == null ? null : DateTime.tryParse(draft.expiresAt!),
      shownPublicly: checkStatus == 'VERIFIED',
    );
    records.removeWhere((c) => c.certificationTypeId == draft.certificationTypeId && c.status == 'PENDING');
    records.add(row);
    return row;
  }

  @override
  Future<void> startSelling(String companyId) async {
    await _wait();
    sent.add({'call': 'startSelling', 'companyId': companyId});
    sells = true;
    supplierLevel = checkStatus == 'VERIFIED' ? 'VERIFIED' : 'REGISTERED';
  }
}
