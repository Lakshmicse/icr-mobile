import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart' show openSitePage, showMessage;
import '../../core/widgets/chips.dart';
import '../chapters/community_kit.dart' show pickFromSheet;
import '../site/site_kit.dart';
import 'candidate_row.dart';
import 'talent_controller.dart';
import 'talent_labels.dart';
import 'talent_models.dart';
import 'talent_repository.dart';

/// Opens a candidate's quick view (the website's `CandidateQuickView` drawer) as a sheet.
Future<void> showCandidateQuickView(
  BuildContext context, {
  required TalentRepository repository,
  required Candidate candidate,
  required bool hasCompany,
  TalentAccess? access,
  TalentViewer? viewer,
  List<JobOption> jobs = const [],
  void Function(String userId)? onOpenMember,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (sheet) => CandidateQuickView(
      controller: CandidateQuickViewController(repository, candidate.userId, hasCompany: hasCompany, card: candidate),
      access: access,
      viewer: viewer,
      jobs: jobs,
      onOpenMember: onOpenMember,
    ),
  );
}

/// The candidate's quick view: who they are, what they want, their skills and summary; then, for a company's hiring
/// team, the contact behind the paywall, an invitation to one of its jobs, a first message, and the team's private
/// notes and tags. Why contact or messaging is closed is said in the website's words, with its one step.
class CandidateQuickView extends StatefulWidget {
  const CandidateQuickView({
    super.key,
    required this.controller,
    this.access,
    this.viewer,
    this.jobs = const [],
    this.onOpenMember,
  });

  final CandidateQuickViewController controller;
  final TalentAccess? access;
  final TalentViewer? viewer;
  final List<JobOption> jobs;

  /// The name opens the member's public profile, when the profile is public.
  final void Function(String userId)? onOpenMember;

  @override
  State<CandidateQuickView> createState() => _CandidateQuickViewState();
}

class _CandidateQuickViewState extends State<CandidateQuickView> {
  final _message = TextEditingController();
  final _tag = TextEditingController();
  final _note = TextEditingController();
  JobOption? _inviteJob;
  String? _toast;

  CandidateQuickViewController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.load();
  }

  @override
  void dispose() {
    _c.dispose();
    _message.dispose();
    _tag.dispose();
    _note.dispose();
    super.dispose();
  }

  void _say(String? refusal, String done) {
    if (!mounted) return;
    if (refusal != null) {
      showMessage(context, refusal);
    } else {
      setState(() => _toast = done);
    }
  }

  Future<void> _pickJob() async {
    final picked = await pickFromSheet<JobOption>(
      context,
      title: 'Select a Job',
      options: widget.jobs,
      label: (j) => j.title,
      selected: _inviteJob,
    );
    if (picked != null && mounted) setState(() => _inviteJob = picked);
  }

  Future<void> _invite() async {
    final job = _inviteJob;
    if (job == null) return;
    _say(await _c.invite(job.id), 'Invitation sent.');
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty) return;
    final result = await _c.send(text, jobTitle: _inviteJob?.title);
    if (!mounted) return;
    if (result.error != null) {
      showMessage(context, result.error!);
      return;
    }
    _message.clear();
    setState(() => _toast = 'Message sent. The conversation is in your Messages.');
  }

  Future<void> _addTag() async {
    final label = _tag.text.trim();
    if (label.isEmpty) return;
    final refusal = await _c.addTag(label);
    if (!mounted) return;
    if (refusal != null) {
      showMessage(context, refusal);
    } else {
      _tag.clear();
    }
  }

  Future<void> _saveNote() async {
    final body = _note.text.trim();
    if (body.isEmpty) return;
    final refusal = await _c.addNote(body);
    if (!mounted) return;
    if (refusal != null) {
      showMessage(context, refusal);
    } else {
      _note.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final c = _c.candidate;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.92,
            child: Column(
              children: [
                _header(c),
                const Divider(height: 1, thickness: 1, color: SiteColors.hairline),
                Expanded(
                  child: ListView(
                    key: const ValueKey('qv-list'),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      if (_toast != null) ...[
                        Container(
                          key: const ValueKey('qv-toast'),
                          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                          color: AppColors.emerald50,
                          child: Row(
                            children: [
                              const Icon(LucideIcons.circleCheck, size: 16, color: AppColors.emerald700),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_toast!, style: SiteText.body)),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => setState(() => _toast = null),
                                icon: const Icon(LucideIcons.x, size: 16, color: AppColors.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_c.loading && c == null) Text('Loading…', style: SiteText.secondary),
                      if (_c.error != null && _c.detail == null)
                        Text(_c.error!, key: const ValueKey('qv-error'), style: SiteText.secondary),
                      if (c != null) ..._body(c),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header(Candidate? c) {
    final opens = c != null && c.profilePublic && widget.onOpenMember != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (c != null)
            CandidateAvatar(candidate: c, size: 52)
          else
            const SizedBox(
              width: 52,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(color: AppColors.surfaceContainer, shape: BoxShape.circle),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  key: const ValueKey('qv-name'),
                  onTap: opens ? () => widget.onOpenMember!(c.userId) : null,
                  child: Text(
                    c?.fullName ?? 'Candidate',
                    style: opens ? SiteText.subheading.copyWith(color: AppColors.primary) : SiteText.subheading,
                  ),
                ),
                if (c?.headline != null) Text(c!.headline!, style: SiteText.secondary),
                if (c?.nextRole != null) ...[const SizedBox(height: 6), NextRoleChip(nextRole: c!.nextRole!)],
                if (opens)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'View Profile',
                      key: const ValueKey('qv-view-profile'),
                      style: SiteText.meta.copyWith(color: AppColors.primary),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('qv-close'),
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(LucideIcons.x, size: 22, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  List<Widget> _body(Candidate c) {
    final detail = _c.detail;
    final wanted = c.nextRole;
    final masters = const TalentMasters();
    // What they said they want next — never a salary, which only its owner sees.
    final wants = wanted == null
        ? const <String>[]
        : [
            for (final m in wanted.workModes) workModeLabels[m] ?? m,
            for (final k in wanted.employmentTypes) employmentTypeLabels[k] ?? k,
            for (final k in wanted.industries) masters.industryLabel(k),
            for (final k in wanted.functions) masters.functionLabel(k),
            if (wanted.shift != null) shiftLabels[wanted.shift] ?? wanted.shift!,
            if (wanted.willingToRelocate) 'Open to Relocating',
          ];
    final facts = [
      if (c.experienceYears != null) '${c.experienceYears} yrs experience',
      ?c.currentLocation,
      if (c.currentCompany != null) 'at ${c.currentCompany}',
      if (c.expectedSalary != null) 'Expects ${rupees(c.expectedSalary!)} a year',
      ?c.availability(card: false),
    ];
    final hasCompany = _c.hasCompany;
    final access = widget.access;
    return [
      if (facts.isNotEmpty) Text(facts.join(' · '), key: const ValueKey('qv-facts'), style: SiteText.secondary),
      if (wants.isNotEmpty) ...[
        const SizedBox(height: 14),
        _SectionTitle('What They Want'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final w in wants)
              IcrChip(
                label: w,
                tone: ChipTone.tinted,
                fill: AppColors.emerald50,
                border: AppColors.emerald200,
                height: 26,
                textStyle: SiteText.meta.copyWith(color: AppColors.emerald700, fontWeight: FontWeight.w600),
              ),
          ],
        ),
      ],
      if (c.skills.isNotEmpty) ...[
        const SizedBox(height: 14),
        _SectionTitle('Skills'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [for (final s in c.skills) IcrChip(label: s, tone: ChipTone.outlined, height: 26)],
        ),
      ],
      if (detail?.summary != null) ...[
        const SizedBox(height: 14),
        _SectionTitle('Summary'),
        const SizedBox(height: 6),
        Text(detail!.summary!, style: SiteText.body),
      ],
      const SizedBox(height: 16),
      const Divider(height: 1, thickness: 1, color: SiteColors.hairline),
      if (!hasCompany) ...[
        const SizedBox(height: 12),
        _Notice(
          key: const ValueKey('qv-no-company'),
          text: 'A company is required to contact this candidate, invite them to apply or keep notes on them.',
        ),
      ],
      if (hasCompany) ...[
        // Contact reveal — tier gated.
        const SizedBox(height: 14),
        _SectionTitle('Contact'),
        const SizedBox(height: 8),
        if (_c.contact != null)
          Column(
            key: const ValueKey('qv-contact'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.mail, size: 16, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(child: SelectableText(_c.contact!.email, style: SiteText.body)),
                ],
              ),
              if (_c.contact!.phone != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(LucideIcons.phone, size: 16, color: AppColors.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(child: SelectableText(_c.contact!.phone!, style: SiteText.body)),
                  ],
                ),
              ],
            ],
          )
        else if (access != null && !access.canRevealContact)
          _LockedNotice(key: const ValueKey('qv-locked-contact'), access: access, viewer: widget.viewer, contact: true)
        else
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('qv-reveal'),
              onPressed: _c.revealing ? null : () async => _say(await _c.reveal(), 'Contact revealed.'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                shape: const StadiumBorder(),
                foregroundColor: AppColors.primary,
              ),
              icon: const Icon(LucideIcons.lock, size: 16),
              label: Text(_c.revealing ? 'Revealing…' : 'Reveal Contact', style: SiteText.link),
            ),
          ),
        const SizedBox(height: 16),
        const Divider(height: 1, thickness: 1, color: SiteColors.hairline),
        // Invite to apply — free.
        const SizedBox(height: 14),
        _SectionTitle('Invite to Apply'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: IcrChip(
                key: const ValueKey('qv-invite-job'),
                label: _inviteJob?.title ?? 'Select a Job',
                tone: ChipTone.outlined,
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: SiteText.body,
                trailing: const Icon(Icons.expand_more, size: 18, color: AppColors.onSurfaceVariant),
                onTap: widget.jobs.isEmpty ? null : _pickJob,
              ),
            ),
          ],
        ),
        if (widget.jobs.isEmpty) ...[
          const SizedBox(height: 4),
          Text('No jobs to invite candidates to yet. Post a job first.', style: SiteText.meta),
        ],
        const SizedBox(height: 8),
        SiteButton(
          key: const ValueKey('qv-invite'),
          label: _c.inviting ? 'Inviting…' : 'Invite to Apply',
          busy: _c.inviting,
          onPressed: _inviteJob == null ? null : _invite,
        ),
        const SizedBox(height: 16),
        const Divider(height: 1, thickness: 1, color: SiteColors.hairline),
        // Message — tier gated.
        const SizedBox(height: 14),
        _SectionTitle('Message'),
        const SizedBox(height: 8),
        if (access != null && !access.canMessage)
          _LockedNotice(key: const ValueKey('qv-locked-message'), access: access, viewer: widget.viewer, contact: false)
        else ...[
          TextField(
            key: const ValueKey('qv-message'),
            controller: _message,
            minLines: 2,
            maxLines: 5,
            maxLength: 4000,
            style: SiteText.body,
            decoration: _underlined('Your message'),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _message,
            builder: (context, value, _) => SiteButton(
              key: const ValueKey('qv-send'),
              label: _c.sending ? 'Sending…' : 'Send Message',
              busy: _c.sending,
              onPressed: value.text.trim().isEmpty ? null : _send,
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Divider(height: 1, thickness: 1, color: SiteColors.hairline),
        // Private to the hiring team — never shown to the candidate.
        const SizedBox(height: 14),
        _SectionTitle('Notes & Tags'),
        const SizedBox(height: 8),
        if (_c.tags.isEmpty)
          Text('No tags yet.', key: const ValueKey('qv-no-tags'), style: SiteText.meta)
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in _c.tags)
                IcrChip(
                  key: ValueKey('tag-$t'),
                  label: t,
                  tone: ChipTone.filled,
                  height: 28,
                  trailing: GestureDetector(
                    key: ValueKey('tag-remove-$t'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      final refusal = await _c.removeTag(t);
                      if (refusal != null && mounted) showMessage(context, refusal);
                    },
                    child: const Icon(LucideIcons.x, size: 14, color: AppColors.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('qv-tag-input'),
                controller: _tag,
                maxLength: 40,
                style: SiteText.body,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addTag(),
                decoration: _underlined('Add a tag'),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              key: const ValueKey('qv-tag-add'),
              onPressed: _c.savingTag ? null : _addTag,
              child: Text('Add', style: SiteText.link),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_c.notes.isEmpty)
          Text('No notes yet.', key: const ValueKey('qv-no-notes'), style: SiteText.meta)
        else
          for (final (i, n) in _c.notes.indexed) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: SiteColors.hairline),
            Padding(
              key: ValueKey('note-${n.id}'),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.body, style: SiteText.body),
                  const SizedBox(height: 2),
                  Text([?n.authorName, dayMonthLabel(n.createdAt)].join(' · '), style: SiteText.meta),
                ],
              ),
            ),
          ],
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('qv-note-input'),
          controller: _note,
          minLines: 2,
          maxLines: 5,
          maxLength: 4000,
          style: SiteText.body,
          decoration: _underlined('Add a private note for your team'),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const ValueKey('qv-note-save'),
            onPressed: _c.savingNote ? null : _saveNote,
            child: Text('Save Note', style: SiteText.link),
          ),
        ),
      ],
    ];
  }

  static InputDecoration _underlined(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: SiteText.secondary,
    counterText: '',
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(vertical: 8),
    border: const UnderlineInputBorder(borderSide: BorderSide(color: SiteColors.hairline)),
    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: SiteColors.hairline)),
    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: SiteText.meta.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.5));
}

/// A tinted line of information (the website's info `Alert`).
class _Notice extends StatelessWidget {
  const _Notice({super.key, required this.text, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      color: SiteColors.blueTint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(LucideIcons.info, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: SiteText.body)),
            ],
          ),
          if (action != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onAction,
                child: Text(action!, style: SiteText.link),
              ),
            ),
        ],
      ),
    );
  }
}

/// Why contact or messaging is closed, and the one step that opens it (the website's `LockedNotice`). Both need
/// a verified company AND a plan, so a plan is no answer to an unverified company. Only those who may buy the
/// Corporate plans are told to subscribe; the rest ask whoever can.
class _LockedNotice extends StatelessWidget {
  const _LockedNotice({super.key, required this.access, required this.contact, this.viewer});

  final TalentAccess access;
  final TalentViewer? viewer;
  final bool contact;

  /// `MEMBERSHIP_AUDIENCE_BUYERS[COMPANY]`: who may buy a Corporate plan.
  static const corporateBuyers = {'COMPANY_ADMIN', 'BUYER'};

  @override
  Widget build(BuildContext context) {
    if (!access.verified) {
      return _Notice(
        text: contact
            ? 'Verify your company to reveal candidate contact details.'
            : 'Verify your company to message candidates.',
        action: 'Verify Company',
        onAction: () => openSitePage(context, '/company?tab=verification'),
      );
    }
    final canBuy = corporateBuyers.contains(viewer?.role);
    return _Notice(
      text: contact
          ? canBuy
                ? 'Subscribe to reveal candidate contact details.'
                : "Your company's plan doesn't include candidate contact details. Ask your company admin to upgrade."
          : canBuy
          ? 'Subscribe to message candidates directly.'
          : "Your company's plan doesn't include messaging candidates. Ask your company admin to upgrade.",
      action: canBuy ? 'Upgrade' : 'View Plans',
      onAction: () => openSitePage(context, '/pricing/corporate'),
    );
  }
}
