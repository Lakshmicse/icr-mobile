import 'dart:async' show FutureOr;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/theme/app_colors.dart';
import '../account/widgets/account_kit.dart' show AccountField;
import '../shell/app_shell.dart';
import '../shell/icr_bottom_nav.dart' show AppTab;
import 'site_kit.dart';

/// The website's words for the partner application, `learnResources.PartnerApplyDialog` in `messages/en`.
abstract final class PartnerApplyWords {
  static const title = 'Apply to Become a Learning Partner';
  static const intro =
      'Partners apply as a company. Choose a company you run on ICR, or register a new one. Once ICR approves it, you add and publish your courses from your dashboard.';
  static const companyLabel = 'Apply As';
  static const adminsOnly = 'Only companies you are an admin of are listed.';
  static const noCompanies = 'You are not an admin of any company on ICR yet. Register your company to apply.';
  static const loadFailed = 'Unable to load your companies. Try again.';
  static const statusPartner = 'Partner';
  static const statusWaiting = 'With ICR';
  static const statusInfo = 'More Info Requested';
  static const statusDeclined = 'Declined';
  static const notesLabel = 'What courses would you like to offer? (Optional)';
  static const notesPlaceholder = 'Subjects, accreditations, the courses you run today…';
  static const registerCompany = 'Register a New Company';
  static const submit = 'Submit Application';
  static const failed = 'Unable to send the application.';
  static const sentTitle = 'Application Sent';
  static const sentNext =
      'Our team reviews every application. Once it is approved, your dashboard opens the partner console, where you add and publish courses.';
  static const close = 'Close';
  static const goToDashboard = 'Go to Dashboard';

  /// `sentBody`: "{company}'s application is with ICR."
  static String sentBody(String company) => "$company's application is with ICR.";

  /// The most the notes take (`ApplyAsPartnerDto.proposalNotes`; the website's box cuts at the same length).
  static const notesMax = 4000;
}

/// A company the member administers and where it stands as a learning partner (`GET /learning/partners/companies`).
class PartnerCompany {
  const PartnerCompany({
    required this.id,
    required this.name,
    this.providerName,
    this.applicationStatus,
    this.reviewNote,
    this.active = false,
  });

  final String id;
  final String name;

  /// Set once ICR approved the company: its partner institute.
  final String? providerName;
  final String? applicationStatus;
  final String? reviewNote;

  /// The company the member is acting for right now.
  final bool active;

  bool get isPartner => providerName != null;

  /// The application is with ICR: the API's waiting states, `LearningPartnerApplicationStatus.PENDING` and
  /// `UNDER_REVIEW` (the website's `WAITING`).
  bool get pending => applicationStatus == 'PENDING' || applicationStatus == 'UNDER_REVIEW';

  /// Whether this company can apply now (the website's `blockOf` is null): it is no partner yet and nothing of its
  /// is with ICR. A declined application, or one ICR asked more of, can be sent again.
  bool get eligible => !isPartner && !pending;

  /// The chip beside the company, in the website's words (`PartnerApplyDialog`); null when it never applied.
  String? get statusLabel {
    if (isPartner) return PartnerApplyWords.statusPartner;
    if (pending) return PartnerApplyWords.statusWaiting;
    return switch (applicationStatus) {
      'INFO_REQUESTED' => PartnerApplyWords.statusInfo,
      'REJECTED' => PartnerApplyWords.statusDeclined,
      _ => null,
    };
  }

  /// ICR's note on an application it declined or asked more of (the website's dashboard card shows it for both).
  String? get noteToShow {
    final note = reviewNote?.trim();
    if (note == null || note.isEmpty) return null;
    return applicationStatus == 'REJECTED' || applicationStatus == 'INFO_REQUESTED' ? note : null;
  }

  factory PartnerCompany.fromJson(Map<String, dynamic> json) {
    final provider = json['provider'] as Map<String, dynamic>?;
    final application = json['application'] as Map<String, dynamic>?;
    return PartnerCompany(
      id: json['companyId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      providerName: provider?['name'] as String?,
      applicationStatus: application?['status'] as String?,
      reviewNote: application?['reviewNote'] as String?,
      active: json['active'] == true,
    );
  }
}

/// The company the form opens on, as the website's dialog preselects: the one being acted for when it can apply,
/// else the first that can. Null when none can (every one is a partner or has its application with ICR).
PartnerCompany? defaultPartnerCompany(List<PartnerCompany> companies) {
  final eligible = [
    for (final c in companies)
      if (c.eligible) c,
  ];
  for (final c in eligible) {
    if (c.active) return c;
  }
  return eligible.isEmpty ? null : eligible.first;
}

abstract class PartnerApplyRepository {
  Future<List<PartnerCompany>> companies();

  /// `POST /learning/partners/applications` with the company and, when written, the notes: the two things the
  /// website's dialog sends. (The API also takes course areas and accreditation; the website asks neither.)
  Future<void> apply({required String companyId, String? proposalNotes});
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
  Future<void> apply({required String companyId, String? proposalNotes}) async {
    try {
      await _api.dio.post<dynamic>(
        '/learning/partners/applications',
        data: {
          'companyId': companyId,
          if (proposalNotes != null && proposalNotes.trim().isNotEmpty) 'proposalNotes': proposalNotes.trim(),
        },
      );
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

/// Apply to become a learning partner (`/learning/partners/apply`, the website's "Apply to partner" dialog): a partner
/// applies as a company. The member picks one of the companies they are an admin of — one that is already a partner
/// or has its application with ICR is listed, marked and cannot be picked — says what courses they would offer
/// (optional) and sends it. ICR reviews every application by hand; once approved, the company's admins run the
/// partner console. Nothing else is asked: the application is written from the company page and the applicant's
/// profile.
class PartnerApplyScreen extends StatefulWidget {
  const PartnerApplyScreen({super.key, this.repository, this.onBack, this.onCreateCompany});

  final PartnerApplyRepository? repository;
  final VoidCallback? onBack;

  /// "Register a new company": founding one. When it returns the companies are read again, so the new one is there
  /// to apply as.
  final FutureOr<void> Function()? onCreateCompany;

  @override
  State<PartnerApplyScreen> createState() => _PartnerApplyScreenState();
}

class _PartnerApplyScreenState extends State<PartnerApplyScreen> {
  late final PartnerApplyRepository _repo = widget.repository ?? ApiPartnerApplyRepository(context.read<ApiClient>());
  late Future<List<PartnerCompany>> _companies = _repo.companies();
  final _notes = TextEditingController();
  String? _companyId;
  bool _sending = false;

  /// The company the application went for, once it is sent (the website's `sentFor`); null while the form shows.
  String? _sentFor;
  String? _error;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _send(List<PartnerCompany> companies) async {
    final id = _companyId;
    if (id == null || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final notes = _notes.text.trim();
      await _repo.apply(companyId: id, proposalNotes: notes.isEmpty ? null : notes);
      if (!mounted) return;
      setState(() => _sentFor = companies.where((c) => c.id == id).firstOrNull?.name ?? '');
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message.isEmpty ? PartnerApplyWords.failed : e.message);
    } catch (_) {
      if (mounted) setState(() => _error = PartnerApplyWords.failed);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _register() async {
    await widget.onCreateCompany?.call();
    if (!mounted) return;
    // The new company is the one acted for now: read the list again and open on it.
    setState(() {
      _companyId = null;
      _companies = _repo.companies();
    });
  }

  void _close() => (widget.onBack ?? () => Navigator.of(context).maybePop())();

  @override
  Widget build(BuildContext context) {
    return SitePage(
      title: 'Become a Partner',
      onBack: widget.onBack,
      canvas: true,
      child: FutureBuilder<List<PartnerCompany>>(
        future: _companies,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return SiteError(
              message: PartnerApplyWords.loadFailed,
              onRetry: () => setState(() {
                _companies = _repo.companies();
              }),
            );
          }
          final companies = snapshot.data;
          if (companies == null) return const SiteLoading();
          _companyId ??= defaultPartnerCompany(companies)?.id;
          // Nobody can apply when every company is a partner or has its application with ICR: the list says which.
          final picked = companies.where((c) => c.id == _companyId && c.eligible).firstOrNull;
          return ListView(
            key: const Key('partner.body'),
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            children: [SiteCard(child: _sentFor != null ? _sent(_sentFor!) : _form(companies, picked))],
          );
        },
      ),
    );
  }

  /// "Application sent": whose application is with ICR, what happens next, and the two ways on.
  Widget _sent(String company) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(PartnerApplyWords.sentTitle, style: SiteText.heading),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, color: AppColors.successInk, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(PartnerApplyWords.sentBody(company), key: const Key('partner.sent'), style: SiteText.body),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(PartnerApplyWords.sentNext, style: SiteText.secondary),
      const SizedBox(height: 16),
      SiteButton(
        key: const Key('partner.dashboard'),
        label: PartnerApplyWords.goToDashboard,
        onPressed: () => AppShell.goToTab(context, AppTab.home),
      ),
      const SizedBox(height: 8),
      SiteButton(key: const Key('partner.close'), label: PartnerApplyWords.close, outlined: true, onPressed: _close),
    ],
  );

  /// The dialog's body: its title and introduction, then the companies and the notes — or, for a member who runs no
  /// company, the way to register one.
  Widget _form(List<PartnerCompany> companies, PartnerCompany? picked) {
    final register = widget.onCreateCompany;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(PartnerApplyWords.title, style: SiteText.heading),
        const SizedBox(height: 4),
        Text(PartnerApplyWords.intro, style: SiteText.secondary),
        const SizedBox(height: 16),
        if (companies.isEmpty) ...[
          Text(PartnerApplyWords.noCompanies, key: const Key('partner.noCompanies'), style: SiteText.body),
          if (register != null) ...[
            const SizedBox(height: 16),
            SiteButton(
              key: const Key('partner.register'),
              label: PartnerApplyWords.registerCompany,
              onPressed: _register,
            ),
          ],
        ] else ...[
          Text(PartnerApplyWords.companyLabel, style: SiteText.strong),
          const SizedBox(height: 2),
          for (final (i, c) in companies.indexed)
            _CompanyRow(
              company: c,
              selected: c.id == picked?.id,
              first: i == 0,
              onTap: c.eligible ? () => setState(() => _companyId = c.id) : null,
            ),
          const SizedBox(height: 6),
          Text(PartnerApplyWords.adminsOnly, style: SiteText.meta),
          if (picked?.noteToShow != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 18, color: SiteColors.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(picked!.noteToShow!, key: const Key('partner.note'), style: SiteText.secondary),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          AccountField(
            fieldKey: const Key('partner.notes'),
            label: PartnerApplyWords.notesLabel,
            hint: PartnerApplyWords.notesPlaceholder,
            controller: _notes,
            minLines: 3,
            maxLines: 6,
            maxLength: PartnerApplyWords.notesMax,
          ),
          if (_error != null) ...[
            Text(
              _error!,
              key: const Key('partner.error'),
              style: SiteText.body.copyWith(color: AppColors.error),
            ),
            const SizedBox(height: 12),
          ],
          SiteButton(
            key: const Key('partner.send'),
            label: PartnerApplyWords.submit,
            busy: _sending,
            onPressed: picked == null ? null : () => _send(companies),
          ),
          if (register != null) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              key: const Key('partner.register'),
              onPressed: _register,
              icon: const Icon(Icons.add_business_outlined, size: 20),
              label: Text(PartnerApplyWords.registerCompany, style: SiteText.link),
            ),
          ],
        ],
      ],
    );
  }
}

/// One company to apply as: a flat row between hairlines, with the status the website's chip gives it. A partner, or a
/// company whose application is with ICR, shows faded and takes no tap.
class _CompanyRow extends StatelessWidget {
  const _CompanyRow({required this.company, required this.selected, required this.first, required this.onTap});

  final PartnerCompany company;
  final bool selected;
  final bool first;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final status = company.statusLabel;
    final (fill, ink) = switch (status) {
      PartnerApplyWords.statusPartner => (AppColors.successTint, AppColors.successInk),
      PartnerApplyWords.statusWaiting => (AppColors.chipEmphasis, AppColors.primary),
      PartnerApplyWords.statusInfo => (AppColors.amber100, AppColors.amber800),
      _ => (AppColors.slate100, AppColors.slate600),
    };
    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: selected,
      label: '${company.name}${status == null ? '' : ', $status'}',
      excludeSemantics: true,
      child: Opacity(
        opacity: onTap == null ? 0.7 : 1,
        child: InkWell(
          key: Key('partner.company.${company.id}'),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: first ? null : const Border(top: BorderSide(color: SiteColors.hairline)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  size: 20,
                  color: onTap == null ? AppColors.slate400 : AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(company.name, style: SiteText.strong)),
                if (status != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(999)),
                    child: Text(
                      status,
                      style: SiteText.meta.copyWith(color: ink, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
