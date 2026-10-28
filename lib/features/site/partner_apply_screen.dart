import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart' show showMessage;
import 'site_kit.dart';

/// A company the member administers and where it stands as a learning partner (`GET /learning/partners/companies`).
class PartnerCompany {
  const PartnerCompany({
    required this.id,
    required this.name,
    this.providerName,
    this.applicationStatus,
    this.reviewNote,
  });

  final String id;
  final String name;

  /// Set once ICR approved the company: its partner institute.
  final String? providerName;
  final String? applicationStatus;
  final String? reviewNote;

  bool get isPartner => providerName != null;
  bool get pending =>
      applicationStatus == 'PENDING' || applicationStatus == 'SUBMITTED' || applicationStatus == 'IN_REVIEW';

  factory PartnerCompany.fromJson(Map<String, dynamic> json) {
    final provider = json['provider'] as Map<String, dynamic>?;
    final application = json['application'] as Map<String, dynamic>?;
    return PartnerCompany(
      id: json['companyId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      providerName: provider?['name'] as String?,
      applicationStatus: application?['status'] as String?,
      reviewNote: application?['reviewNote'] as String?,
    );
  }
}

abstract class PartnerApplyRepository {
  Future<List<PartnerCompany>> companies();

  Future<void> apply({
    required String companyId,
    required List<String> courseAreas,
    String? proposalNotes,
    String? accreditation,
  });
}

class ApiPartnerApplyRepository implements PartnerApplyRepository {
  ApiPartnerApplyRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<PartnerCompany>> companies() async {
    try {
      final res = await _api.dio.get<dynamic>('/learning/partners/companies');
      return [
        for (final r in (res.data as List? ?? const [])) PartnerCompany.fromJson((r as Map).cast<String, dynamic>()),
      ];
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  @override
  Future<void> apply({
    required String companyId,
    required List<String> courseAreas,
    String? proposalNotes,
    String? accreditation,
  }) async {
    try {
      await _api.dio.post<dynamic>(
        '/learning/partners/applications',
        data: {
          'companyId': companyId,
          if (courseAreas.isNotEmpty) 'courseAreas': courseAreas,
          if (proposalNotes != null && proposalNotes.trim().isNotEmpty) 'proposalNotes': proposalNotes.trim(),
          if (accreditation != null && accreditation.trim().isNotEmpty) 'accreditation': accreditation.trim(),
        },
      );
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

/// Apply to become a learning partner (`/learning/partners/apply`): a company the member administers, the areas it
/// would teach, and a note on its proposal and accreditation. ICR reviews it; once approved the company runs its own
/// catalogue.
class PartnerApplyScreen extends StatefulWidget {
  const PartnerApplyScreen({super.key, this.repository, this.onBack, this.onCreateCompany});

  final PartnerApplyRepository? repository;
  final VoidCallback? onBack;

  /// For a member who administers no company yet: founding one.
  final VoidCallback? onCreateCompany;

  @override
  State<PartnerApplyScreen> createState() => _PartnerApplyScreenState();
}

class _PartnerApplyScreenState extends State<PartnerApplyScreen> {
  late final PartnerApplyRepository _repo = widget.repository ?? ApiPartnerApplyRepository(context.read<ApiClient>());
  late Future<List<PartnerCompany>> _companies = _repo.companies();
  final _areas = TextEditingController();
  final _notes = TextEditingController();
  final _accreditation = TextEditingController();
  String? _companyId;
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _areas.dispose();
    _notes.dispose();
    _accreditation.dispose();
    super.dispose();
  }

  List<String> get _areaList => [
    for (final a in _areas.text.split(RegExp(r'[,\n]')))
      if (a.trim().isNotEmpty) a.trim(),
  ];

  Future<void> _send() async {
    final id = _companyId;
    if (id == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _repo.apply(
        companyId: id,
        courseAreas: _areaList,
        proposalNotes: _notes.text,
        accreditation: _accreditation.text,
      );
      if (!mounted) return;
      setState(() => _sent = true);
      showMessage(context, 'Application sent. ICR will review it.');
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SitePage(
      title: 'Become a partner',
      onBack: widget.onBack,
      canvas: true,
      child: FutureBuilder<List<PartnerCompany>>(
        future: _companies,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return SiteError(
              message: snapshot.error is ApiError
                  ? (snapshot.error! as ApiError).message
                  : "Couldn't read your companies.",
              onRetry: () => setState(() {
                _companies = _repo.companies();
              }),
            );
          }
          final companies = snapshot.data;
          if (companies == null) return const SiteLoading();
          if (companies.isEmpty) return _noCompany();
          _companyId ??= companies.first.id;
          final company = companies.firstWhere((c) => c.id == _companyId, orElse: () => companies.first);
          return ListView(
            key: const Key('partner.body'),
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            children: [
              SiteCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Teach on ICR', style: SiteText.heading),
                    const SizedBox(height: 4),
                    Text(
                      'Training institutes list their courses on the Learning Center. Tell us about your company; ICR reviews every application.',
                      style: SiteText.secondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (_sent)
                SiteCard(
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: AppColors.successInk, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('Application sent. ICR will review it and write to you.', style: SiteText.body),
                      ),
                    ],
                  ),
                )
              else if (company.isPartner)
                SiteCard(
                  child: Text(
                    '${company.name} is already a learning partner (${company.providerName}).',
                    style: SiteText.body,
                  ),
                )
              else if (company.pending)
                SiteCard(
                  child: Text(
                    '${company.name} has an application with ICR that is being reviewed.',
                    style: SiteText.body,
                  ),
                )
              else
                SiteCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (companies.length > 1) ...[
                        Text('Company', style: SiteText.meta),
                        DropdownButton<String>(
                          key: const Key('partner.company'),
                          isExpanded: true,
                          value: _companyId,
                          items: [
                            for (final c in companies)
                              DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name, style: SiteText.body),
                              ),
                          ],
                          onChanged: (v) => setState(() => _companyId = v),
                        ),
                        const SizedBox(height: 12),
                      ] else ...[
                        Text('Company', style: SiteText.meta),
                        Text(company.name, style: SiteText.strong),
                        const SizedBox(height: 12),
                      ],
                      if (company.reviewNote != null && company.applicationStatus == 'REJECTED') ...[
                        Text('ICR\'s note on your last application: ${company.reviewNote}', style: SiteText.meta),
                        const SizedBox(height: 12),
                      ],
                      _field(
                        _areas,
                        'Course areas',
                        'Facility management, HVAC, safety…',
                        hint: 'Separate areas with commas',
                      ),
                      const SizedBox(height: 12),
                      _field(_notes, 'Your proposal', 'What would you teach, to whom, and how?', lines: 4),
                      const SizedBox(height: 12),
                      _field(_accreditation, 'Accreditation', 'Approvals, affiliations, certifications', lines: 3),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          key: const Key('partner.error'),
                          style: SiteText.body.copyWith(color: AppColors.error),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SiteButton(
                        key: const Key('partner.send'),
                        label: 'Send application',
                        busy: _sending,
                        onPressed: _send,
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _field(TextEditingController c, String label, String hintText, {String? hint, int lines = 1}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: SiteText.meta),
      const SizedBox(height: 4),
      TextField(
        controller: c,
        minLines: lines,
        maxLines: lines == 1 ? 1 : lines + 2,
        maxLength: lines == 1 ? null : 4000,
        style: SiteText.body,
        decoration: InputDecoration(
          hintText: hintText,
          helperText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    ],
  );

  Widget _noCompany() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('A partner is a company', style: SiteText.heading, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'To apply you need to be an administrator of a company page on ICR. Create one first, then come back.',
            style: SiteText.secondary,
            textAlign: TextAlign.center,
          ),
          if (widget.onCreateCompany != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: 220,
              child: SiteButton(label: 'Create a company', onPressed: widget.onCreateCompany),
            ),
          ],
        ],
      ),
    ),
  );
}
