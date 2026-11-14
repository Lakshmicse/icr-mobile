import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/api/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/util/links.dart' show showMessage;
import '../../account/companies/create_company_controller.dart' show documentMaxBytes, documentUploadFailed;
import '../../account/profile/profile_kit.dart' show PillAction;
import '../../account/widgets/account_kit.dart';
import '../../account/widgets/photo_picker.dart' show PhotoPicker;
import '../../site/site_kit.dart';
import '../company_controller.dart';
import '../company_models.dart';
import '../company_words.dart';
import '../supplier_checklist.dart';
import 'company_kit.dart';

/// The Certifications tab, as the website's: for a company that sells, the supplier trust levels (the request card
/// with the same checklist the reviewer judges by, and the listing's review history), then the certificates'
/// renewals and the certifications themselves; for one that does not, the notice that they come with the listing.
class CertificationsTab extends StatelessWidget {
  const CertificationsTab({
    super.key,
    required this.controller,
    required this.onEditCompany,
    required this.pickDocument,
    this.onStartSelling,
    this.certificationsKey,
  });

  final CompanyController controller;
  final VoidCallback onEditCompany;
  final PhotoPicker pickDocument;
  final VoidCallback? onStartSelling;

  /// On the certifications section's title, so the request card's "Add Certification" can scroll to it.
  final Key? certificationsKey;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (!c.sells) return _SupplierListingNotice(controller: c, onStartSelling: onStartSelling);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(CompanyWords.supplierLevelsTitle, style: SiteText.heading),
              const SizedBox(height: 4),
              Text(CompanyWords.supplierLevelsCaption, style: SiteText.secondary),
            ],
          ),
        ),
        SupplierLevelCard(
          controller: c,
          onEditCompany: onEditCompany,
          pickDocument: pickDocument,
          onAddCertification: () {
            final target = certificationsKey;
            final ctx = target is GlobalKey ? target.currentContext : null;
            if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300));
          },
        ),
        VerificationHistoryCard(events: c.history),
        RenewalsCard(certifications: c.certifications ?? const [], now: c.now()),
        CertificationsCard(controller: c, pickDocument: pickDocument, titleKey: certificationsKey),
      ],
    );
  }
}

/// The supplier's side of the trust ladder: the current level, and the same checklist the reviewer judges a request
/// by, with live status from the company profile, the listing and the evidence already uploaded.
class SupplierLevelCard extends StatelessWidget {
  const SupplierLevelCard({
    super.key,
    required this.controller,
    required this.onEditCompany,
    required this.pickDocument,
    required this.onAddCertification,
  });

  final CompanyController controller;
  final VoidCallback onEditCompany;
  final PhotoPicker pickDocument;
  final VoidCallback onAddCertification;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final access = c.access;
    final vendor = c.profile?.vendor;
    final current = access?.verificationLevel ?? vendor?.verificationLevel ?? 'REGISTERED';
    final next = nextLevel(current);
    final canSelfRequest = next != null && levelRank(next) <= levelRank(maxSelfRequestLevel);
    final docsRequested = access?.docsRequested ?? false;
    final pending = access?.pendingLevel;
    final submitLevel = docsRequested ? pending : next;
    final target = pending ?? next;
    final items = target == null
        ? const <ChecklistItem>[]
        : checklistFor(
            company: c.company,
            documents: c.evidence,
            certifications: [
              for (final x in c.certifications ?? const <CompanyCertification>[])
                (
                  name: x.name,
                  status: x.status,
                  hasDocument: x.documentUrls.isNotEmpty,
                  expiresAt: x.expiresAt,
                  supersededAt: x.supersededAt,
                ),
            ],
            yearsExperience: vendor?.yearsExperience,
            ratingCount: access?.ratingCount ?? vendor?.ratingCount ?? 0,
            now: c.now(),
          ).where((i) => i.requiredAtRank <= levelRank(target)).toList();
    final done = items.where((i) => i.status == ChecklistStatus.verified).length;
    final uploadsMissing = [
      for (final i in items)
        if (i.fix == ChecklistFix.upload && i.status == ChecklistStatus.missing) i,
    ];

    Future<void> openRequest() async {
      if (submitLevel == null) return;
      final refusal = await showLevelRequestSheet(
        context,
        controller: c,
        level: submitLevel,
        resubmitting: docsRequested,
        stillMissing: uploadsMissing,
        pickDocument: pickDocument,
      );
      if (refusal != null && context.mounted) showMessage(context, refusal);
    }

    Widget? fixAction(ChecklistItem item) {
      if (item.status != ChecklistStatus.missing) return null;
      return switch (item.fix) {
        ChecklistFix.profile => LinkButton(
          CompanyWords.addDetailsFix,
          key: ValueKey('checklist-fix-${item.key}'),
          onPressed: onEditCompany,
        ),
        ChecklistFix.listing => LinkButton(
          CompanyWords.editListing,
          key: ValueKey('checklist-fix-${item.key}'),
          onPressed: onEditCompany,
        ),
        ChecklistFix.certifications => LinkButton(
          CompanyWords.addCertificationFix,
          key: ValueKey('checklist-fix-${item.key}'),
          onPressed: onAddCertification,
        ),
        ChecklistFix.upload =>
          canSelfRequest || docsRequested
              ? LinkButton(
                  CompanyWords.uploadDocument,
                  key: ValueKey('checklist-fix-${item.key}'),
                  onPressed: openRequest,
                )
              : null,
        _ => null,
      };
    }

    return CompanySection(
      key: const ValueKey('supplier-level-card'),
      title: CompanyWords.verificationStatus,
      caption: CompanyWords.verificationStatusCaption,
      icon: Symbols.verified_user,
      children: [
        CompanyRow(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LevelBadge(level: current, caption: true),
              const SizedBox(height: 10),
              if (docsRequested)
                PillAction(
                  key: const ValueKey('level-upload-requested'),
                  label: CompanyWords.uploadRequestedDocuments,
                  icon: Symbols.upload,
                  filled: true,
                  onPressed: openRequest,
                )
              else if (pending != null)
                Row(
                  children: [
                    const Icon(Symbols.hourglass_top, size: 16, color: AppColors.amber800),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        CompanyWords.upgradeUnderReview(levelLabel(pending)),
                        style: SiteText.strong.copyWith(color: AppColors.amber800),
                      ),
                    ),
                  ],
                )
              else if (canSelfRequest)
                PillAction(
                  key: const ValueKey('level-request'),
                  label: CompanyWords.applyFor(levelLabel(next)),
                  icon: Symbols.upgrade,
                  filled: true,
                  onPressed: openRequest,
                ),
            ],
          ),
        ),
        if (docsRequested)
          NoticeStrip(
            tone: StatusTone.warning,
            text:
                '${CompanyWords.reviewTeamNeeds(levelLabel(pending))} '
                '${access?.docsRequestMessage ?? CompanyWords.pleaseUploadRequested}',
          ),
        if (target != null && items.isNotEmpty) ...[
          CompanyRow(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    pending != null
                        ? CompanyWords.underReviewFor(levelLabel(target))
                        : CompanyWords.requirementsFor(levelLabel(target)),
                    style: SiteText.strong,
                  ),
                ),
                Text(CompanyWords.doneOfTotal(done, items.length), style: SiteText.meta),
              ],
            ),
          ),
          if (!canSelfRequest && pending == null) NoticeStrip(text: CompanyWords.awardedByIcr),
          for (final item in items) _ChecklistRow(item: item, action: fixAction(item)),
        ] else if (next == null)
          CompanyRow(
            child: Text(CompanyWords.topLevelReached, style: SiteText.strong.copyWith(color: AppColors.emerald700)),
          ),
        CompanyRow(
          rule: false,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(CompanyWords.reviewsTheList, style: SiteText.meta),
        ),
      ],
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.item, this.action});

  final ChecklistItem item;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final (icon, color, chip, tone) = switch (item.status) {
      ChecklistStatus.verified => (
        Symbols.check_circle,
        AppColors.success,
        CompanyWords.statusCompleted,
        StatusTone.success,
      ),
      ChecklistStatus.pending => (
        Symbols.schedule,
        AppColors.amber800,
        CompanyWords.statusUnderReview,
        StatusTone.warning,
      ),
      ChecklistStatus.missing => (
        Symbols.radio_button_unchecked,
        AppColors.slate300,
        item.fix == ChecklistFix.upload || item.fix == ChecklistFix.certifications
            ? CompanyWords.statusPendingUpload
            : CompanyWords.statusPending,
        StatusTone.neutral,
      ),
    };
    return CompanyRow(
      key: ValueKey('checklist-${item.key}'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color, fill: item.status == ChecklistStatus.verified ? 1 : 0),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: SiteText.strong),
                Text(item.detail, style: SiteText.meta, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (action != null) Align(alignment: Alignment.centerLeft, child: action),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusChip(chip, tone: tone),
        ],
      ),
    );
  }
}

/// Every review decision on the listing (`VerificationTimeline`); nothing when there is none yet.
class VerificationHistoryCard extends StatelessWidget {
  const VerificationHistoryCard({super.key, required this.events});

  final List<VerificationEvent> events;

  static String _label(VerificationEvent e) => switch (e.type) {
    'SUBMITTED' => 'Submitted for ${levelLabel(e.toLevel)} review',
    'DOCS_REQUESTED' => 'More documents requested',
    'APPROVED' => 'Approved: ${levelLabel(e.toLevel)}',
    'REJECTED' => 'Request declined',
    'REVALIDATION_FLAGGED' => 'Annual re-validation due',
    'REVOKED' => 'Verification withdrawn',
    _ =>
      e.status == 'VERIFIED'
          ? 'Approved: ${levelLabel(e.toLevel)}'
          : e.status == 'REJECTED'
          ? 'Request declined'
          : 'Requested: ${levelLabel(e.toLevel)}',
  };

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    return CompanySection(
      key: const ValueKey('verification-history'),
      title: CompanyWords.historyTitle,
      caption: CompanyWords.historyCaption,
      icon: Symbols.history,
      children: [
        for (final e in events)
          CompanyRow(
            key: ValueKey('history-${e.id}'),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: switch (e.status) {
                        'VERIFIED' => AppColors.success,
                        'REJECTED' => AppColors.rose600,
                        'DOCS_REQUESTED' => AppColors.primary,
                        _ => AppColors.amber500,
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_label(e), style: SiteText.strong),
                      Text(
                        '${levelLabel(e.status).replaceAll('_', ' ')} · ${dayOf(e.createdAt)}',
                        style: SiteText.meta,
                      ),
                      if (e.note != null) ...[const SizedBox(height: 2), Text(e.note!, style: SiteText.secondary)],
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Certificate validity and renewal reminders (`CertificationExpiryCard`): each verified certificate with an expiry
/// that no renewal has replaced — lapsed ones included, because warning about those is the card's whole job.
class RenewalsCard extends StatelessWidget {
  const RenewalsCard({super.key, required this.certifications, required this.now});

  static const soonDays = 60;

  final List<CompanyCertification> certifications;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final c in certifications)
        if (c.status == 'VERIFIED' && c.supersededAt == null && c.expiresAt != null)
          (c, certificationDaysLeft(c.expiresAt!, now)),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    final expired = rows.where((r) => r.$2 < 0).length;
    final soon = rows.where((r) => r.$2 >= 0 && r.$2 <= soonDays).length;
    return CompanySection(
      key: const ValueKey('renewals-card'),
      title: CompanyWords.renewalsTitle,
      caption: CompanyWords.renewalsCaption,
      icon: Symbols.event_busy,
      children: [
        if (rows.isEmpty)
          CompanyRow(child: Text(CompanyWords.renewalsEmpty, style: SiteText.secondary))
        else ...[
          if (expired > 0)
            NoticeStrip(tone: StatusTone.error, text: CompanyWords.expiredAlert(expired))
          else if (soon > 0)
            NoticeStrip(tone: StatusTone.warning, text: CompanyWords.soonAlert(soon, soonDays)),
          for (final (c, days) in rows)
            CompanyRow(
              key: ValueKey('renewal-${c.id}'),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name, style: SiteText.strong),
                        Text('Expires ${dayOf(c.expiresAt)}', style: SiteText.meta),
                      ],
                    ),
                  ),
                  StatusChip(
                    days < 0
                        ? CompanyWords.chipExpired
                        : days == 0
                        ? CompanyWords.chipExpiresToday
                        : CompanyWords.chipDaysLeft(days),
                    tone: days < 0
                        ? StatusTone.error
                        : days <= soonDays
                        ? StatusTone.warning
                        : StatusTone.success,
                    filled: days <= soonDays,
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// A company's certifications: what it holds, what buyers see, and the sheet to record another. ICR never awards a
/// certification, which is why nothing here says "apply".
class CertificationsCard extends StatelessWidget {
  const CertificationsCard({super.key, required this.controller, required this.pickDocument, this.titleKey});

  final CompanyController controller;
  final PhotoPicker pickDocument;
  final Key? titleKey;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final apps = c.certifications ?? const <CompanyCertification>[];
    final now = c.now();
    final current = apps.where((a) => a.status == 'VERIFIED' && a.supersededAt == null).toList();
    final replaced = apps.where((a) => a.status == 'VERIFIED' && a.supersededAt != null).toList();
    final onProfile = current.where((a) => a.shownPublicly).toList();
    final lapsed = current.where((a) => !a.shownPublicly && !certificationHeld(a.expiresAt, now)).toList();
    final awaiting = current.where((a) => !a.shownPublicly && certificationHeld(a.expiresAt, now)).toList();
    final needsCertificate = apps.where((a) => a.status == 'PENDING').toList();
    final rejected = apps.where((a) => a.status == 'REJECTED').toList();

    Future<void> add([String? typeId]) async {
      final saved = await showCertificationSheet(context, controller: c, pickDocument: pickDocument, typeId: typeId);
      if (saved && context.mounted) showMessage(context, 'Certification recorded.');
    }

    String withExpiry(CompanyCertification a) => a.expiresAt == null ? a.name : '${a.name} · exp ${dayOf(a.expiresAt)}';

    return CompanySection(
      key: const ValueKey('certifications-card'),
      titleKey: titleKey,
      title: CompanyWords.certificationsTitle,
      caption: CompanyWords.certificationsBlurb,
      icon: Symbols.workspace_premium,
      trailing: c.runsWorkspace
          ? PillAction(
              key: const ValueKey('add-certification'),
              label: CompanyWords.addCertification,
              icon: Icons.add_rounded,
              filled: true,
              onPressed: add,
            )
          : null,
      children: [
        if (c.certificationsFailed)
          CompanyRow(child: Text('Unable to load your certifications.', style: SiteText.secondary))
        else if (c.certifications == null)
          const CompanyRow(
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          )
        else if (apps.isEmpty)
          CompanyRow(child: Text(CompanyWords.nothingRecorded, style: SiteText.secondary))
        else ...[
          if (onProfile.isNotEmpty)
            _Group(
              title: CompanyWords.onYourProfile,
              chips: [
                for (final a in onProfile)
                  StatusChip(
                    withExpiry(a),
                    key: ValueKey('cert-${a.id}'),
                    tone: StatusTone.success,
                    icon: Symbols.workspace_premium,
                    filled: true,
                  ),
              ],
            ),
          if (awaiting.isNotEmpty)
            _Group(
              title: CompanyWords.showsOnceVerified,
              help: CompanyWords.showsOnceVerifiedHelp,
              chips: [
                for (final a in awaiting)
                  StatusChip(
                    withExpiry(a),
                    key: ValueKey('cert-${a.id}'),
                    tone: StatusTone.neutral,
                    icon: Symbols.hourglass_empty,
                  ),
              ],
            ),
          if (lapsed.isNotEmpty)
            _Group(
              title: CompanyWords.expired,
              help: CompanyWords.expiredHelp,
              chips: [
                for (final a in lapsed)
                  InkWell(
                    key: ValueKey('cert-${a.id}'),
                    onTap: c.runsWorkspace ? () => add(a.certificationTypeId) : null,
                    child: StatusChip(
                      '${a.name} · ${CompanyWords.validTo(dayOf(a.expiresAt))}',
                      tone: StatusTone.warning,
                      icon: Symbols.event_busy,
                    ),
                  ),
              ],
            ),
          if (needsCertificate.isNotEmpty)
            _Group(
              title: CompanyWords.pendingUpload,
              help: CompanyWords.pendingUploadHelp,
              chips: [
                for (final a in needsCertificate)
                  PillAction(
                    key: ValueKey('cert-${a.id}'),
                    label: '${a.name}: ${CompanyWords.uploadCertificate}',
                    icon: Symbols.upload_file,
                    onPressed: c.runsWorkspace ? () => add(a.certificationTypeId) : null,
                  ),
              ],
            ),
          if (replaced.isNotEmpty)
            _Group(
              title: CompanyWords.replacedByRenewal,
              chips: [
                for (final a in replaced)
                  Row(
                    key: ValueKey('cert-${a.id}'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusChip(a.name, tone: StatusTone.neutral, icon: Symbols.history),
                      const SizedBox(width: 6),
                      Text(
                        CompanyWords.supersededLine(
                          a.expiresAt == null ? CompanyWords.noExpiry : CompanyWords.validTo(dayOf(a.expiresAt)),
                          dayOf(a.supersededAt),
                        ),
                        style: SiteText.meta,
                      ),
                    ],
                  ),
              ],
            ),
          if (rejected.isNotEmpty)
            _Group(
              title: CompanyWords.notAccepted,
              chips: [
                for (final a in rejected)
                  Row(
                    key: ValueKey('cert-${a.id}'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusChip(a.name, tone: StatusTone.error, icon: Symbols.cancel),
                      if (a.reviewNote != null) ...[
                        const SizedBox(width: 6),
                        Flexible(child: Text('${a.reviewNote}', style: SiteText.meta)),
                      ],
                    ],
                  ),
              ],
            ),
        ],
        CompanyRow(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(CompanyWords.certificationsNote, style: SiteText.meta),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(Symbols.lock, size: 13, color: AppColors.slate400),
                  ),
                  const SizedBox(width: 5),
                  Expanded(child: Text(CompanyWords.certificationsPrivacy, style: SiteText.meta)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.chips, this.help});

  final String title;
  final String? help;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return CompanyRow(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: CompanyText.overline),
          if (help != null) ...[const SizedBox(height: 2), Text(help!, style: SiteText.meta)],
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      ),
    );
  }
}

/// A company that does not sell yet: the certifications come with the supplier listing (`SupplierListingNotice`).
class _SupplierListingNotice extends StatefulWidget {
  const _SupplierListingNotice({required this.controller, this.onStartSelling});

  final CompanyController controller;
  final VoidCallback? onStartSelling;

  @override
  State<_SupplierListingNotice> createState() => _SupplierListingNoticeState();
}

class _SupplierListingNoticeState extends State<_SupplierListingNotice> {
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Padding(
      key: const ValueKey('supplier-listing-notice'),
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
      child: Column(
        children: [
          const Icon(Symbols.storefront, size: 44, color: AppColors.slate400),
          const SizedBox(height: 14),
          Text(CompanyWords.noListingTitle, style: SiteText.heading, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(CompanyWords.noListingBody, style: SiteText.secondary, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          if (c.canStartSelling && widget.onStartSelling != null)
            SiteButton(
              key: const ValueKey('listing-start-selling'),
              label: CompanyWords.startSelling,
              onPressed: widget.onStartSelling,
            )
          else
            Text(CompanyWords.askAdminToSell, style: SiteText.meta, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// --- the level request ------------------------------------------------------------------------------------------

/// Asks for the next supplier level with the evidence uploaded here. Null when sent, else the sentence to show.
Future<String?> showLevelRequestSheet(
  BuildContext context, {
  required CompanyController controller,
  required String level,
  required bool resubmitting,
  required List<ChecklistItem> stillMissing,
  required PhotoPicker pickDocument,
}) => showEditSheet<String?>(
  context,
  builder: (_) => _LevelRequestSheet(
    controller: controller,
    level: level,
    resubmitting: resubmitting,
    stillMissing: stillMissing,
    pickDocument: pickDocument,
  ),
);

const _evidenceTypes = {'application/pdf', 'image/png', 'image/jpeg', 'image/webp'};

class _LevelRequestSheet extends StatefulWidget {
  const _LevelRequestSheet({
    required this.controller,
    required this.level,
    required this.resubmitting,
    required this.stillMissing,
    required this.pickDocument,
  });

  final CompanyController controller;
  final String level;
  final bool resubmitting;
  final List<ChecklistItem> stillMissing;
  final PhotoPicker pickDocument;

  @override
  State<_LevelRequestSheet> createState() => _LevelRequestSheetState();
}

class _LevelRequestSheetState extends State<_LevelRequestSheet> {
  final List<UploadedEvidence> _docs = [];
  bool _uploading = false;
  bool _saving = false;
  String? _error;

  Future<void> _upload() async {
    final file = await widget.pickDocument();
    if (file == null || !mounted) return;
    if (!_evidenceTypes.contains(file.contentType) || file.bytes.length > documentMaxBytes) {
      setState(() => _error = documentUploadFailed);
      return;
    }
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final uploaded = await widget.controller.upload(file, purpose: 'verification');
      if (mounted) {
        setState(
          () => _docs.add(
            UploadedEvidence(
              url: uploaded.url,
              name: uploaded.name,
              mimeType: file.contentType,
              size: file.bytes.length,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (_docs.isEmpty) {
      setState(() => _error = CompanyWords.uploadAtLeastOne);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final refusal = await widget.controller.requestLevel(widget.level, List.of(_docs));
    if (!mounted) return;
    if (refusal != null) {
      setState(() {
        _saving = false;
        _error = refusal;
      });
      return;
    }
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    final level = levelLabel(widget.level);
    return EditSheet(
      title: widget.resubmitting ? 'Submit Requested Documents: $level Review' : CompanyWords.applyFor(level),
      saving: _saving,
      error: _error,
      dirty: _docs.isNotEmpty,
      saveLabel: CompanyWords.submitForReview,
      onSave: _submit,
      children: [
        if (widget.stillMissing.isNotEmpty) ...[
          Text(CompanyWords.stillMissing, style: AccountText.label),
          for (final i in widget.stillMissing) Text('• ${i.label}', style: AccountText.body),
          const SizedBox(height: 10),
        ],
        Text(CompanyWords.uploadTheDocuments, style: AccountText.meta),
        const SizedBox(height: 12),
        for (final (i, d) in _docs.indexed)
          Row(
            key: ValueKey('evidence-$i'),
            children: [
              const Icon(Symbols.task, size: 18, color: AppColors.emerald700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(d.name, style: AccountText.body, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              TextButton(onPressed: () => setState(() => _docs.removeAt(i)), child: const Text(CompanyWords.remove)),
            ],
          ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: AccountButton(
            key: const ValueKey('evidence-upload'),
            label: _uploading ? CompanyWords.uploading : CompanyWords.uploadDocument,
            icon: Icons.upload_file_outlined,
            outlined: true,
            expand: false,
            busy: _uploading,
            onPressed: _uploading ? null : _upload,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// --- recording a certification ---------------------------------------------------------------------------------

/// Records a certification the company holds (`POST /certifications/me`). True when saved.
Future<bool> showCertificationSheet(
  BuildContext context, {
  required CompanyController controller,
  required PhotoPicker pickDocument,
  String? typeId,
}) async =>
    await showEditSheet<bool>(
      context,
      builder: (_) => _CertificationSheet(controller: controller, pickDocument: pickDocument, initialTypeId: typeId),
    ) ??
    false;

const certificationLimits = (
  issuerMin: 2,
  issuerMax: 120,
  certificateNumberMax: 80,
  documentsMax: 5,
  expiryYearsAhead: 25,
);

/// Everything wrong with the facts, one problem per field (`certificationFactProblems`): whether what was given can
/// be true, not whether enough was given. Days are India's calendar days.
Map<String, String> certificationProblems({
  required String issuer,
  required String certificateNumber,
  required DateTime? issuedOn,
  required DateTime? expiresAt,
  required int documents,
  required DateTime now,
}) {
  const l = certificationLimits;
  final out = <String, String>{};
  final i = issuer.trim();
  if (i.isNotEmpty && i.length < l.issuerMin) {
    out['issuer'] = 'Enter the issuing body’s full name (at least ${l.issuerMin} characters).';
  } else if (i.length > l.issuerMax) {
    out['issuer'] = 'Keep the issuing body under ${l.issuerMax} characters.';
  }
  if (documents > l.documentsMax) out['documentUrls'] = 'Attach at most ${l.documentsMax} files.';
  if (certificateNumber.trim().length > l.certificateNumberMax) {
    out['certificateNumber'] = 'Keep the certificate number under ${l.certificateNumberMax} characters.';
  }
  int day(DateTime d) =>
      d.toUtc().add(const Duration(hours: 5, minutes: 30)).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  final today = day(now);
  final horizon = DateTime.utc(now.year + l.expiryYearsAhead, now.month, now.day);
  if (expiresAt != null) {
    final e = day(expiresAt);
    if (e < today) {
      out['expiresAt'] = 'The expiry date must be today or later. An expired certificate cannot be added.';
    } else if (e > day(horizon)) {
      out['expiresAt'] = 'Check the expiry date. It is more than ${l.expiryYearsAhead} years away.';
    }
  }
  if (issuedOn != null) {
    final s = day(issuedOn);
    if (s > today) {
      out['issuedOn'] = 'The issue date cannot be in the future.';
    } else if (expiresAt != null && s > day(expiresAt)) {
      out['issuedOn'] = 'The issue date is after the expiry date.';
    }
  }
  return out;
}

class _CertificationSheet extends StatefulWidget {
  const _CertificationSheet({required this.controller, required this.pickDocument, this.initialTypeId});

  final CompanyController controller;
  final PhotoPicker pickDocument;
  final String? initialTypeId;

  @override
  State<_CertificationSheet> createState() => _CertificationSheetState();
}

class _CertificationSheetState extends State<_CertificationSheet> {
  late String? _typeId = widget.initialTypeId;
  final List<UploadedEvidence> _docs = [];
  final _issuer = TextEditingController();
  final _number = TextEditingController();
  final _note = TextEditingController();
  bool _issuerAuto = false;
  DateTime? _issuedOn;
  DateTime? _expiresAt;
  bool _uploading = false;
  bool _tried = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_typeId != null) _fillIssuer(_typeId!);
  }

  @override
  void dispose() {
    _issuer.dispose();
    _number.dispose();
    _note.dispose();
    super.dispose();
  }

  CertificationType? get _type => widget.controller.types.where((t) => t.id == _typeId).firstOrNull;

  /// Fill the issuing body in when ICR knows of exactly one, never over one the member typed.
  void _fillIssuer(String typeId) {
    if (_issuer.text.isNotEmpty && !_issuerAuto) return;
    final sole = widget.controller.types.where((t) => t.id == typeId).firstOrNull?.soleIssuer;
    _issuer.text = sole ?? '';
    _issuerAuto = sole != null;
  }

  bool get _dirty =>
      _typeId != widget.initialTypeId ||
      _docs.isNotEmpty ||
      _number.text.isNotEmpty ||
      _note.text.isNotEmpty ||
      _issuedOn != null ||
      _expiresAt != null ||
      (_issuer.text.isNotEmpty && !_issuerAuto);

  /// The API refuses a second record while an unexpired one is held; saying so here means the member reads it beside
  /// the certification they picked, instead of as a server error after pressing Save.
  String? get _alreadyRecorded {
    final id = _typeId;
    if (id == null) return null;
    final held = (widget.controller.certifications ?? const <CompanyCertification>[]).where(
      (a) =>
          a.certificationTypeId == id &&
          a.supersededAt == null &&
          a.status == 'VERIFIED' &&
          certificationHeld(a.expiresAt, widget.controller.now()),
    );
    final h = held.firstOrNull;
    if (h == null) return null;
    return h.expiresAt == null ? CompanyWords.alreadyHeld : CompanyWords.alreadyHeldValidTo(dayOf(h.expiresAt));
  }

  Map<String, String> get _problems => certificationProblems(
    issuer: _issuer.text,
    certificateNumber: _number.text,
    issuedOn: _issuedOn,
    expiresAt: _expiresAt,
    documents: _docs.length,
    now: widget.controller.now(),
  );

  Future<void> _pickType() async {
    final types = widget.controller.types;
    final picked = await showAccountPicker<CertificationType>(
      context,
      title: CompanyWords.certificationField,
      items: types,
      labelOf: (t) => t.name,
      searchable: types.length > 8,
      selected: _type,
    );
    if (picked == null) return;
    setState(() {
      _typeId = picked.id;
      _fillIssuer(picked.id);
    });
  }

  Future<void> _pickDate(bool expiry) async {
    final now = widget.controller.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: expiry ? (_expiresAt ?? now) : (_issuedOn ?? now),
      firstDate: expiry ? DateTime(now.year, now.month, now.day) : DateTime(1950),
      lastDate: expiry ? DateTime(now.year + certificationLimits.expiryYearsAhead, now.month, now.day) : now,
    );
    if (picked == null) return;
    setState(() {
      if (expiry) {
        _expiresAt = picked;
      } else {
        _issuedOn = picked;
      }
    });
  }

  Future<void> _upload() async {
    final file = await widget.pickDocument();
    if (file == null || !mounted) return;
    if (!_evidenceTypes.contains(file.contentType) || file.bytes.length > documentMaxBytes) {
      setState(() => _error = documentUploadFailed);
      return;
    }
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final uploaded = await widget.controller.upload(file, purpose: 'certification');
      if (mounted) setState(() => _docs.add(UploadedEvidence(url: uploaded.url, name: uploaded.name)));
    } catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _tried = true);
    if (_typeId == null || _docs.isEmpty || _problems.isNotEmpty || _alreadyRecorded != null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.recordCertification(
        CertificationDraft(
          certificationTypeId: _typeId!,
          documentUrls: [for (final d in _docs) d.url],
          issuer: _issuer.text.trim().isEmpty ? null : _issuer.text.trim(),
          certificateNumber: _number.text.trim().isEmpty ? null : _number.text.trim(),
          issuedOn: _issuedOn == null ? null : _iso(_issuedOn!),
          expiresAt: _expiresAt == null ? null : _iso(_expiresAt!),
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      final message = ApiError.from(e).message;
      if (mounted) setState(() => _error = message.isEmpty ? CompanyWords.thatDidNotSave : message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final problems = _tried ? _problems : const <String, String>{};
    final type = _type;
    final issuers = type?.issuers ?? const <String>[];
    final already = _alreadyRecorded;
    return EditSheet(
      title: CompanyWords.addCertification,
      saving: _saving,
      error: _error,
      dirty: _dirty,
      onSave: already == null ? _save : null,
      children: [
        AccountSelectField(
          key: const ValueKey('certification-type'),
          label: CompanyWords.certificationField,
          required: true,
          hint: 'Select a certification',
          value: type?.name,
          error: _tried && _typeId == null ? CompanyWords.chooseACertification : null,
          onTap: _pickType,
        ),
        if (already != null) NoticeStrip(text: already, textKey: const ValueKey('certification-already')),
        Text(CompanyWords.certificateField, style: AccountText.label),
        const SizedBox(height: 6),
        for (final (i, d) in _docs.indexed)
          Row(
            key: ValueKey('certificate-$i'),
            children: [
              const Icon(Symbols.task, size: 18, color: AppColors.emerald700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(d.name, style: AccountText.body, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              TextButton(onPressed: () => setState(() => _docs.removeAt(i)), child: const Text(CompanyWords.remove)),
            ],
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: AccountButton(
            key: const ValueKey('certificate-upload'),
            label: _uploading ? CompanyWords.uploading : CompanyWords.uploadCertificate,
            icon: Icons.upload_file_outlined,
            outlined: true,
            expand: false,
            busy: _uploading,
            onPressed: _uploading || _docs.length >= certificationLimits.documentsMax ? null : _upload,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 5, bottom: 14),
          child: Text(
            _tried && _docs.isEmpty
                ? CompanyWords.attachTheCertificate
                : (problems['documentUrls'] ?? CompanyWords.uploadCertificateHelp),
            style: _tried && (_docs.isEmpty || problems['documentUrls'] != null) ? AccountText.error : AccountText.meta,
          ),
        ),
        AccountField(
          fieldKey: const ValueKey('certification-issuer'),
          label: CompanyWords.issuingBody,
          controller: _issuer,
          helper: issuers.length == 1
              ? CompanyWords.issuerFilledIn
              : issuers.length > 1
              ? CompanyWords.issuerAnyAccredited
              : CompanyWords.issuerWho,
          error: problems['issuer'],
          maxLength: certificationLimits.issuerMax,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() => _issuerAuto = false),
        ),
        if (issuers.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final body in issuers)
                  ActionChip(
                    label: Text(body, style: AccountText.chip),
                    onPressed: () => setState(() {
                      _issuer.text = body;
                      _issuerAuto = false;
                    }),
                  ),
              ],
            ),
          ),
        AccountField(
          fieldKey: const ValueKey('certification-number'),
          label: CompanyWords.certificateNumber,
          controller: _number,
          helper: CompanyWords.certificateNumberHelp,
          error: problems['certificateNumber'],
          maxLength: certificationLimits.certificateNumberMax,
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) => setState(() {}),
        ),
        AccountSelectField(
          key: const ValueKey('certification-issued'),
          label: CompanyWords.issueDate,
          hint: 'Select a date',
          value: _issuedOn == null ? null : dayOf(_issuedOn),
          helper: CompanyWords.issuedOnHelp,
          error: problems['issuedOn'],
          onTap: () => _pickDate(false),
          onClear: () => setState(() => _issuedOn = null),
        ),
        AccountSelectField(
          key: const ValueKey('certification-expiry'),
          label: CompanyWords.expiryDate,
          hint: 'Select a date',
          value: _expiresAt == null ? null : dayOf(_expiresAt),
          helper: CompanyWords.expiresAtHelp,
          error: problems['expiresAt'],
          onTap: () => _pickDate(true),
          onClear: () => setState(() => _expiresAt = null),
        ),
        AccountField(
          fieldKey: const ValueKey('certification-note'),
          label: CompanyWords.noteField,
          controller: _note,
          maxLines: 3,
          maxLength: 1000,
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }
}
