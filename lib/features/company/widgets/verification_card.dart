import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../account/companies/create_company_controller.dart' show documentLabel;
import '../../account/profile/profile_kit.dart' show PillAction;
import '../../account/widgets/account_kit.dart' show AccountCheck;
import '../../site/site_kit.dart';
import '../company_controller.dart';
import '../company_fields.dart';
import '../company_words.dart';
import 'company_kit.dart';

/// The company check (employer KYC) at the top of Company Details, as the website's `CompanyVerificationCard`:
/// where it stands, what it still needs from the details below — each item a way to its section — what approval
/// unlocks, and the button that files it. The facts and documents are the company profile's, so nothing is asked
/// twice; the app's sections save as they close, so the button files the company as saved.
class CompanyVerificationCard extends StatefulWidget {
  const CompanyVerificationCard({
    super.key,
    required this.controller,
    required this.onOpenField,
    required this.onFile,
    required this.onSupport,
  });

  final CompanyController controller;

  /// Opens the section that holds a missing item.
  final ValueChanged<CompanyFieldKey> onOpenField;
  final VoidCallback onFile;
  final VoidCallback onSupport;

  @override
  State<CompanyVerificationCard> createState() => _CompanyVerificationCardState();
}

class _CompanyVerificationCardState extends State<CompanyVerificationCard> {
  bool _showUnlocks = false;

  static const _unlocks = <(String, List<String>)>[
    (
      'Hiring',
      [
        'Publish jobs to the public board',
        'Invite candidates to apply',
        'Boost jobs to reach more candidates',
        'Search the whole talent pool, not just the first $unverifiedTalentResultCap results',
        'See candidate contact details and message them',
      ],
    ),
    (
      'Selling',
      [
        'Bid on requirements and reply to enquiries',
        'A Verified supplier badge and higher placement in the Marketplace',
        'Rank higher for new requirement alerts',
      ],
    ),
    (
      'Team & Trust',
      [
        'Add more than $unverifiedTeamMemberCap team members',
        'A Verified badge on your jobs, careers page and directory listing',
        '"Verified buyer" on the requirements you post',
      ],
    ),
  ];

  String _itemLabel(KycChecklistItem item, String? structure) {
    final doc = documentOf(item.key);
    if (doc != null) return documentLabel(doc, structure);
    return companyFields[item.key]!.label;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final company = c.company;
    final name = company?.name ?? '';
    final dossier = c.dossier;
    final status = dossier?.status;
    final verified = status == 'VERIFIED';
    final reverify = c.reverify;
    final withdrawn = status == 'SUSPENDED';
    final editable = canFileInState(status, reverify);
    final checklist = c.checklist;
    final done = checklist.where((i) => i.done).length;
    final ready = done == checklist.length;
    final structure = company?.legalStructure;

    final (chipLabel, chipTone) = status != null
        ? (
            employerVerificationStatusLabels[status] ?? status,
            switch (status) {
              'VERIFIED' => StatusTone.success,
              'SUBMITTED' => StatusTone.info,
              'DOCS_REQUESTED' => StatusTone.warning,
              _ => StatusTone.error,
            },
          )
        : (
            ready ? CompanyWords.readyToSubmit : CompanyWords.notFiledLabel,
            ready ? StatusTone.info : StatusTone.warning,
          );

    final dueDate = reverify == null ? '' : dayOf(reverify.dueAt);
    final requested = (reverify?.documents ?? const [])
        .map((k) => documentForKind(k) == null ? k : documentLabel(documentForKind(k)!, structure))
        .join(', ');
    final note = reverify != null ? reverify.note : (!verified ? dossier?.decisionNote : null);
    final reason = reverify != null ? reverify.reason : (withdrawn ? dossier?.decisionReason : null);

    final sentence = status == null
        ? (ready ? (c.files ? CompanyWords.readyBody : CompanyWords.readyBodyMember) : CompanyWords.notFiledBody(name))
        : reverify != null
        ? (reverify.open
              ? CompanyWords.reverifyOpenBody(name, requested, dueDate)
              : CompanyWords.reverifySentBody(name, dayOf(reverify.submittedAt)))
        : withdrawn && reason == 'REVERIFY_OVERDUE'
        ? CompanyWords.suspendedOverdue
        : verified
        ? CompanyWords.verifiedOn(dayOf(dossier?.reviewedAt ?? dossier?.submittedAt))
        : status == 'SUBMITTED'
        ? CompanyWords.submittedOn(dayOf(dossier?.submittedAt))
        : switch (status) {
            'DOCS_REQUESTED' => CompanyWords.docsRequestedBody,
            'REJECTED' => CompanyWords.rejectedBody,
            'SUSPENDED' => CompanyWords.suspendedBody,
            _ => '',
          };

    final fileLabel = c.filing
        ? CompanyWords.submitting
        : c.reverifyOpen
        ? CompanyWords.sendToIcr
        : dossier != null
        ? CompanyWords.resubmit
        : CompanyWords.submitForVerification;

    return CompanySection(
      key: const ValueKey('company-check'),
      title: CompanyWords.companyVerification,
      caption: CompanyWords.verificationCaption,
      icon: Symbols.verified_user,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          StatusChip(
            chipLabel,
            key: const ValueKey('company-check-status'),
            tone: chipTone,
            filled: verified,
            icon: verified ? Symbols.verified : null,
          ),
          if (reverify != null) ...[
            const SizedBox(height: 4),
            StatusChip(
              reverify.open ? CompanyWords.reverifyChip(dueDate) : CompanyWords.reverifySentChip,
              key: const ValueKey('company-check-reverify'),
              tone: reverify.open ? StatusTone.warning : StatusTone.info,
            ),
          ],
        ],
      ),
      children: [
        // Where it stands.
        CompanyRow(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  style: verified ? SiteText.body : SiteText.secondary,
                  children: [
                    TextSpan(text: sentence),
                    if (dossier != null && dossier.attemptCount > 1 && !verified)
                      TextSpan(text: ' · ${CompanyWords.attempt(dossier.attemptCount)}', style: SiteText.secondary),
                  ],
                ),
                key: const ValueKey('company-check-sentence'),
              ),
              if (note != null) ...[
                const SizedBox(height: 10),
                Container(
                  key: const ValueKey('company-check-note'),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  decoration: const BoxDecoration(
                    color: AppColors.amber50,
                    border: Border(left: BorderSide(color: AppColors.amber500, width: 3)),
                    borderRadius: BorderRadius.horizontal(right: Radius.circular(8)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [
                          CompanyWords.reviewerNote,
                          if (reason != null && reason != 'REVERIFY_OVERDUE')
                            companyActionReasonLabels[reason] ?? reason,
                        ].join(' · '),
                        style: SiteText.meta,
                      ),
                      const SizedBox(height: 2),
                      Text(note, style: SiteText.body),
                    ],
                  ),
                ),
              ],
              if (status == 'SUBMITTED') ...[
                const SizedBox(height: 6),
                Text(CompanyWords.reviewSnapshot, style: SiteText.meta),
              ],
              if (!c.files && !verified) ...[
                const SizedBox(height: 6),
                Text(CompanyWords.filedByYourAdmin, style: SiteText.meta),
              ],
            ],
          ),
        ),

        // What the check still needs, while it can be (re)filed.
        if (editable)
          CompanyRow(
            key: const ValueKey('company-check-list'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(CompanyWords.progress(done, checklist.length), style: SiteText.meta),
                const SizedBox(height: 4),
                for (final item in checklist)
                  Row(
                    key: ValueKey('company-check-${item.key.name}'),
                    children: [
                      Icon(
                        item.done ? Symbols.check_circle : Symbols.radio_button_unchecked,
                        size: 18,
                        color: item.done ? AppColors.success : AppColors.slate300,
                        fill: item.done ? 1 : 0,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Text(
                            _itemLabel(item, structure),
                            style: item.done ? SiteText.secondary : SiteText.body,
                          ),
                        ),
                      ),
                      if (!item.done)
                        LinkButton(
                          CompanyWords.add,
                          key: ValueKey('company-check-add-${item.key.name}'),
                          onPressed: () => widget.onOpenField(item.key),
                        ),
                    ],
                  ),
                if (c.gstBlank && !c.reverifyOpen)
                  AccountCheck(
                    key: const ValueKey('company-check-gst-not-registered'),
                    value: c.gstNotRegistered,
                    onChanged: c.files ? c.setGstNotRegistered : null,
                    label: CompanyWords.notGstRegistered(name),
                  ),
              ],
            ),
          ),

        // What approval unlocks, folded away once it has been granted.
        if (!verified)
          CompanyRow(
            padding: const EdgeInsets.fromLTRB(8, 2, 16, 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinkButton(
                  CompanyWords.whatVerificationUnlocks,
                  key: const ValueKey('company-check-unlocks'),
                  icon: _showUnlocks ? Symbols.expand_less : Symbols.expand_more,
                  onPressed: () => setState(() => _showUnlocks = !_showUnlocks),
                ),
                if (_showUnlocks)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 0, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final (title, items) in _unlocks) ...[
                          Text(title, style: SiteText.strong),
                          const SizedBox(height: 4),
                          for (final item in items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 3),
                                    child: Icon(Symbols.verified, size: 14, color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(item, style: SiteText.secondary)),
                                ],
                              ),
                            ),
                          const SizedBox(height: 8),
                        ],
                        Text(CompanyWords.plansNote, style: SiteText.meta),
                      ],
                    ),
                  ),
              ],
            ),
          ),

        // The button that files it, for whoever may, in a state that allows it.
        if (c.mayFile)
          CompanyRow(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SiteButton(
                  key: const ValueKey('company-check-submit'),
                  label: fileLabel,
                  busy: c.filing,
                  onPressed: ready ? widget.onFile : null,
                ),
                if (!ready) ...[
                  const SizedBox(height: 6),
                  Text(
                    CompanyWords.completeToSubmit(checklist.length - done),
                    key: const ValueKey('company-check-remaining'),
                    style: SiteText.meta,
                  ),
                ],
              ],
            ),
          ),
        if (c.filed)
          NoticeStrip(
            text: CompanyWords.filed,
            tone: StatusTone.success,
            textKey: const ValueKey('company-check-filed'),
          ),

        // Verification is where people get most stuck, so the way to a person sits on the card.
        CompanyRow(
          padding: const EdgeInsets.fromLTRB(16, 2, 8, 2),
          child: Row(
            children: [
              Expanded(child: Text(CompanyWords.needHelp, style: SiteText.meta)),
              PillAction(label: CompanyWords.contactSupport, onPressed: widget.onSupport),
            ],
          ),
        ),
      ],
    );
  }
}
