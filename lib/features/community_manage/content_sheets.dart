import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_error.dart';
import '../../core/theme/app_colors.dart';
import '../account/widgets/account_kit.dart';
import '../workspaces/page_kit.dart';
import 'community_manage_kit.dart';
import 'community_manage_models.dart';
import 'community_manage_repository.dart';
import 'community_manage_rules.dart';

/// The small forms of a record's content (the website's `ChapterContentDrawer`, `CouncilContentDrawer` and
/// `LeadershipEditor`) and the decision on a member's request (`ApplicationsTab`'s `DecideDialog`). Each opens as a
/// sheet, is held to the API's rule before it sends, and shows the API's own words when it still refuses. A sheet
/// answers true when what it sent was taken.

typedef SubmitBody = Future<String?> Function(Map<String, Object?> body);

/// The shared part of these sheets: run the rule, send, close on success or show the refusal.
mixin _Submits<T extends StatefulWidget> on State<T> {
  bool saving = false;
  bool dirty = false;
  String? error;

  void touch([VoidCallback? change]) => setState(() {
    change?.call();
    dirty = true;
  });

  Future<void> send(String? problem, Future<String?> Function() submit) async {
    if (problem != null) {
      setState(() => error = problem);
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final refusal = await submit();
    if (!mounted) return;
    if (refusal == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      saving = false;
      error = refusal;
    });
  }
}

// --- sponsor ---------------------------------------------------------------------------------------------------------

/// Add a sponsor to a chapter: its name, a logo (a link, or a picture from the phone), its tier and its website.
Future<bool> showSponsorSheet(
  BuildContext context, {
  required CommunityManageRepository repository,
  required SubmitBody onSubmit,
  ManagePickers pickers = const ManagePickers(),
}) async =>
    await showEditSheet<bool>(
      context,
      builder: (_) => _SponsorSheet(repository: repository, onSubmit: onSubmit, pickers: pickers),
    ) ??
    false;

class _SponsorSheet extends StatefulWidget {
  const _SponsorSheet({required this.repository, required this.onSubmit, required this.pickers});

  final CommunityManageRepository repository;
  final SubmitBody onSubmit;
  final ManagePickers pickers;

  @override
  State<_SponsorSheet> createState() => _SponsorSheetState();
}

class _SponsorSheetState extends State<_SponsorSheet> with _Submits {
  final _name = TextEditingController();
  final _logo = TextEditingController();
  final _tier = TextEditingController();
  final _url = TextEditingController();
  bool _uploading = false;
  String? _logoError;

  @override
  void dispose() {
    for (final c in [_name, _logo, _tier, _url]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _uploadLogo() async {
    setState(() => _logoError = null);
    final file = await widget.pickers.pickImage();
    if (file == null || !mounted) return;
    final problem = pictureProblem(file, maxBytes: ManageLimits.coverBytes);
    if (problem != null) {
      setState(() => _logoError = problem);
      return;
    }
    setState(() => _uploading = true);
    try {
      final url = await widget.repository.upload(file, purpose: 'chapter-sponsor');
      if (mounted) touch(() => _logo.text = url);
    } catch (e) {
      if (mounted) setState(() => _logoError = ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EditSheet(
      title: 'Add Sponsor',
      saving: saving,
      error: error,
      dirty: dirty,
      saveLabel: 'Add Sponsor',
      onSave: saving || _uploading
          ? null
          : () => send(
              sponsorProblem(name: _name.text, tier: _tier.text),
              () => widget.onSubmit({
                'name': _name.text.trim(),
                if (_logo.text.trim().isNotEmpty) 'logoUrl': _logo.text.trim(),
                if (_url.text.trim().isNotEmpty) 'url': _url.text.trim(),
                if (_tier.text.trim().isNotEmpty) 'tier': _tier.text.trim(),
              }),
            ),
      children: [
        AccountField(
          fieldKey: const Key('sponsor.name'),
          label: 'Name',
          required: true,
          controller: _name,
          maxLength: ManageLimits.sponsorName,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => touch(),
        ),
        AccountField(
          fieldKey: const Key('sponsor.logoUrl'),
          label: 'Logo URL',
          controller: _logo,
          keyboardType: TextInputType.url,
          textCapitalization: TextCapitalization.none,
          helper: _uploading ? 'Uploading…' : 'Paste a link, or upload the logo from this phone.',
          error: _logoError,
          suffix: IconButton(
            key: const Key('sponsor.logoUpload'),
            tooltip: 'Upload Logo',
            onPressed: _uploading ? null : _uploadLogo,
            icon: const Icon(LucideIcons.upload, size: 18, color: AppColors.primary),
          ),
          onChanged: (_) => touch(),
        ),
        AccountField(
          fieldKey: const Key('sponsor.tier'),
          label: 'Tier',
          controller: _tier,
          maxLength: ManageLimits.tier,
          hint: 'Gold',
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => touch(),
        ),
        AccountField(
          fieldKey: const Key('sponsor.url'),
          label: 'Website URL',
          controller: _url,
          keyboardType: TextInputType.url,
          textCapitalization: TextCapitalization.none,
          onChanged: (_) => touch(),
        ),
      ],
    );
  }
}

// --- resource --------------------------------------------------------------------------------------------------------

/// Add a resource: its title, kind, size label and the link it opens.
Future<bool> showResourceSheet(BuildContext context, {required SubmitBody onSubmit}) async =>
    await showEditSheet<bool>(context, builder: (_) => _ResourceSheet(onSubmit: onSubmit)) ?? false;

class _ResourceSheet extends StatefulWidget {
  const _ResourceSheet({required this.onSubmit});

  final SubmitBody onSubmit;

  @override
  State<_ResourceSheet> createState() => _ResourceSheetState();
}

class _ResourceSheetState extends State<_ResourceSheet> with _Submits {
  final _title = TextEditingController();
  final _size = TextEditingController();
  final _url = TextEditingController();
  String _kind = 'OTHER';

  @override
  void dispose() {
    for (final c in [_title, _size, _url]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickKind() async {
    final picked = await showAccountPicker<String>(
      context,
      title: 'Kind',
      items: resourceKinds,
      labelOf: resourceKindLabel,
      selected: _kind,
    );
    if (picked != null) touch(() => _kind = picked);
  }

  @override
  Widget build(BuildContext context) {
    return EditSheet(
      title: 'Add Resource',
      saving: saving,
      error: error,
      dirty: dirty,
      saveLabel: 'Add Resource',
      onSave: saving
          ? null
          : () => send(
              resourceProblem(title: _title.text, url: _url.text, sizeLabel: _size.text),
              () => widget.onSubmit({
                'title': _title.text.trim(),
                'kind': _kind,
                'url': _url.text.trim(),
                if (_size.text.trim().isNotEmpty) 'sizeLabel': _size.text.trim(),
              }),
            ),
      children: [
        AccountField(
          fieldKey: const Key('resource.title'),
          label: 'Title',
          required: true,
          controller: _title,
          maxLength: ManageLimits.resourceTitle,
          onChanged: (_) => touch(),
        ),
        AccountSelectField(
          key: const Key('resource.kind'),
          label: 'Kind',
          hint: 'Resource',
          value: resourceKindLabel(_kind),
          onTap: _pickKind,
        ),
        AccountField(
          fieldKey: const Key('resource.sizeLabel'),
          label: 'Size Label',
          controller: _size,
          maxLength: ManageLimits.sizeLabel,
          hint: '2 MB',
          textCapitalization: TextCapitalization.none,
          onChanged: (_) => touch(),
        ),
        AccountField(
          fieldKey: const Key('resource.url'),
          label: 'URL',
          required: true,
          controller: _url,
          keyboardType: TextInputType.url,
          textCapitalization: TextCapitalization.none,
          onChanged: (_) => touch(),
        ),
      ],
    );
  }
}

// --- update ----------------------------------------------------------------------------------------------------------

/// Post an update (the API's announcement): a title, the body, and whether it stays pinned at the top.
Future<bool> showAnnouncementSheet(BuildContext context, {required SubmitBody onSubmit}) async =>
    await showEditSheet<bool>(context, builder: (_) => _AnnouncementSheet(onSubmit: onSubmit)) ?? false;

class _AnnouncementSheet extends StatefulWidget {
  const _AnnouncementSheet({required this.onSubmit});

  final SubmitBody onSubmit;

  @override
  State<_AnnouncementSheet> createState() => _AnnouncementSheetState();
}

class _AnnouncementSheetState extends State<_AnnouncementSheet> with _Submits {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _pinned = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EditSheet(
      title: 'Post Announcement',
      saving: saving,
      error: error,
      dirty: dirty,
      saveLabel: 'Post Announcement',
      onSave: saving
          ? null
          : () => send(
              announcementProblem(title: _title.text, body: _body.text),
              () => widget.onSubmit({'title': _title.text.trim(), 'body': _body.text.trim(), 'pinned': _pinned}),
            ),
      children: [
        AccountField(
          fieldKey: const Key('announcement.title'),
          label: 'Title',
          required: true,
          controller: _title,
          maxLength: ManageLimits.announcementTitle,
          onChanged: (_) => touch(),
        ),
        AccountField(
          fieldKey: const Key('announcement.body'),
          label: 'Body',
          required: true,
          controller: _body,
          maxLines: 8,
          minLines: 3,
          maxLength: ManageLimits.announcementBody,
          counter: true,
          onChanged: (_) => touch(),
        ),
        SwitchField(
          switchKey: const Key('announcement.pinned'),
          label: 'Pinned',
          value: _pinned,
          onChanged: (v) => touch(() => _pinned = v),
        ),
      ],
    );
  }
}

// --- leadership ------------------------------------------------------------------------------------------------------

/// Add a leader to a chapter (the website's `AddLeaderForm`): find anyone on ICR by name or email, then their
/// title and LinkedIn link. Someone who has not joined the chapter is joined as they are made a leader.
Future<bool> showAddLeaderSheet(
  BuildContext context, {
  required CommunityManageRepository repository,
  required String chapterId,
  required List<String> existing,
  required SubmitBody onSubmit,
  Duration searchDelay = const Duration(milliseconds: 350),
}) async =>
    await showEditSheet<bool>(
      context,
      builder: (_) => _AddLeaderSheet(
        repository: repository,
        chapterId: chapterId,
        existing: existing,
        onSubmit: onSubmit,
        searchDelay: searchDelay,
      ),
    ) ??
    false;

class _AddLeaderSheet extends StatefulWidget {
  const _AddLeaderSheet({
    required this.repository,
    required this.chapterId,
    required this.existing,
    required this.onSubmit,
    required this.searchDelay,
  });

  final CommunityManageRepository repository;
  final String chapterId;

  /// The user ids of the leads the chapter already has; left out of what the search offers.
  final List<String> existing;
  final SubmitBody onSubmit;
  final Duration searchDelay;

  @override
  State<_AddLeaderSheet> createState() => _AddLeaderSheetState();
}

class _AddLeaderSheetState extends State<_AddLeaderSheet> with _Submits {
  final _search = TextEditingController();
  final _title = TextEditingController();
  final _linkedin = TextEditingController();
  List<LeadCandidate> _found = const [];
  LeadCandidate? _picked;
  bool _searching = false;
  String? _searchError;
  Timer? _settle;
  int _asked = 0;

  @override
  void dispose() {
    _settle?.cancel();
    for (final c in [_search, _title, _linkedin]) {
      c.dispose();
    }
    super.dispose();
  }

  void _typed(String v) {
    _settle?.cancel();
    final q = v.trim();
    if (q.length < 2) {
      setState(() {
        _found = const [];
        _searching = false;
        _searchError = null;
      });
      return;
    }
    setState(() => _searching = true);
    _settle = Timer(widget.searchDelay, () async {
      final asked = ++_asked;
      try {
        final found = await widget.repository.leadCandidates(widget.chapterId, q);
        if (!mounted || asked != _asked) return;
        setState(() {
          _found = [...found.where((c) => !widget.existing.contains(c.id))];
          _searchError = null;
        });
      } catch (e) {
        if (mounted && asked == _asked) setState(() => _searchError = ApiError.from(e).message);
      } finally {
        if (mounted && asked == _asked) setState(() => _searching = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final picked = _picked;
    final q = _search.text.trim();
    return EditSheet(
      title: 'Add a Leader',
      saving: saving,
      error: error,
      dirty: dirty,
      saveLabel: 'Add Leader',
      onSave: saving || picked == null
          ? null
          : () => send(
              leadProblem(title: _title.text, linkedinUrl: _linkedin.text),
              () => widget.onSubmit({
                'userId': picked.id,
                if (_title.text.trim().isNotEmpty) 'title': _title.text.trim(),
                if (_linkedin.text.trim().isNotEmpty) 'linkedinUrl': _linkedin.text.trim(),
              }),
            ),
      children: [
        if (picked == null) ...[
          AccountField(
            fieldKey: const Key('leader.search'),
            label: 'Search People by Name or Email',
            controller: _search,
            maxLength: ManageLimits.leadSearch,
            textCapitalization: TextCapitalization.none,
            helper: _searching
                ? 'Searching…'
                : (q.length < 2
                      ? 'Type at least 2 letters of a name or email'
                      : (_found.isEmpty && _searchError == null ? 'No one found' : null)),
            error: _searchError,
            onChanged: _typed,
          ),
          WsRows(
            children: [
              for (final c in _found)
                WsRow(
                  key: ValueKey('leader-option-${c.id}'),
                  title: c.name,
                  subtitle: c.email,
                  trailing: c.isMember ? const WsChip('Member') : null,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  onTap: () => touch(() => _picked = c),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ] else ...[
          WsRow(
            key: const ValueKey('leader-picked'),
            title: picked.name,
            subtitle: picked.email,
            trailing: ManageRowAction(
              icon: LucideIcons.x,
              label: 'Choose Someone Else',
              onPressed: () => setState(() => _picked = null),
            ),
            padding: const EdgeInsets.only(bottom: 10),
          ),
          if (!picked.isMember)
            ManageNote(
              '${picked.firstName.isEmpty ? picked.name : picked.firstName} is not a member of this chapter yet; '
              'adding them as a leader joins them.',
            ),
        ],
        AccountField(
          fieldKey: const Key('leader.title'),
          label: 'Title',
          controller: _title,
          maxLength: ManageLimits.leadTitle,
          hint: 'e.g. Chapter President',
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => touch(),
        ),
        AccountField(
          fieldKey: const Key('leader.linkedin'),
          label: 'LinkedIn URL (optional)',
          controller: _linkedin,
          maxLength: ManageLimits.linkedinUrl,
          keyboardType: TextInputType.url,
          textCapitalization: TextCapitalization.none,
          onChanged: (_) => touch(),
        ),
      ],
    );
  }
}

/// What the lead sheet did.
enum LeadSheetResult { saved, steppedDown }

/// One lead's title, LinkedIn link and term, and Step Down (asked first). A term with no end runs until staff
/// change it; once its end passes, the nightly sweep steps the lead down.
Future<LeadSheetResult?> showLeadSheet(
  BuildContext context, {
  required ContentLead lead,
  required SubmitBody onSave,
  required Future<String?> Function() onStepDown,
  ManagePickers pickers = const ManagePickers(),
}) => showEditSheet<LeadSheetResult>(
  context,
  builder: (_) => _LeadSheet(lead: lead, onSave: onSave, onStepDown: onStepDown, pickers: pickers),
);

class _LeadSheet extends StatefulWidget {
  const _LeadSheet({required this.lead, required this.onSave, required this.onStepDown, required this.pickers});

  final ContentLead lead;
  final SubmitBody onSave;
  final Future<String?> Function() onStepDown;
  final ManagePickers pickers;

  @override
  State<_LeadSheet> createState() => _LeadSheetState();
}

class _LeadSheetState extends State<_LeadSheet> {
  late final _title = TextEditingController(text: widget.lead.title ?? '');
  late final _linkedin = TextEditingController(text: widget.lead.linkedinUrl ?? '');
  late String _starts = widget.lead.termStartsOn ?? '';
  late String _ends = widget.lead.termEndsOn ?? '';
  bool _saving = false;
  bool _dirty = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _linkedin.dispose();
    super.dispose();
  }

  void _touch([VoidCallback? change]) => setState(() {
    change?.call();
    _dirty = true;
  });

  Future<void> _run(Future<String?> Function() action, LeadSheetResult done) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final refusal = await action();
    if (!mounted) return;
    if (refusal == null) {
      Navigator.of(context).pop(done);
      return;
    }
    setState(() {
      _saving = false;
      _error = refusal;
    });
  }

  Future<void> _save() async {
    final problem = leadProblem(
      title: _title.text,
      linkedinUrl: _linkedin.text,
      termStartsOn: _starts,
      termEndsOn: _ends,
    );
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    // As the website sends it: all four, an empty day clearing that end of the term.
    await _run(
      () => widget.onSave({
        'title': _title.text.trim(),
        'linkedinUrl': _linkedin.text.trim(),
        'termStartsOn': _starts,
        'termEndsOn': _ends,
      }),
      LeadSheetResult.saved,
    );
  }

  Future<void> _stepDown() async {
    final ok = await confirmAction(
      context,
      title: 'Step ${widget.lead.name} Down to Member?',
      message: 'They stay a member, and can be made a lead again.',
      confirm: 'Step Down',
    );
    if (!ok || !mounted) return;
    await _run(widget.onStepDown, LeadSheetResult.steppedDown);
  }

  @override
  Widget build(BuildContext context) {
    return EditSheet(
      title: widget.lead.name,
      subtitle: 'Lead',
      saving: _saving,
      error: _error,
      dirty: _dirty,
      onSave: _saving ? null : _save,
      onDelete: _stepDown,
      deleteLabel: 'Step Down',
      children: [
        AccountField(
          fieldKey: const Key('lead.title'),
          label: 'Title',
          controller: _title,
          maxLength: ManageLimits.leadTitle,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => _touch(),
        ),
        AccountField(
          fieldKey: const Key('lead.linkedin'),
          label: 'LinkedIn URL',
          controller: _linkedin,
          keyboardType: TextInputType.url,
          textCapitalization: TextCapitalization.none,
          onChanged: (_) => _touch(),
        ),
        DayField(
          key: const Key('lead.termStarts'),
          label: 'Term Starts',
          value: _starts,
          pickers: widget.pickers,
          onChanged: (v) => _touch(() => _starts = v),
        ),
        DayField(
          key: const Key('lead.termEnds'),
          label: 'Term Ends',
          value: _ends,
          hint: 'Open',
          helper: 'Leave empty for an open term',
          pickers: widget.pickers,
          onChanged: (v) => _touch(() => _ends = v),
        ),
      ],
    );
  }
}

/// Make a member a lead, with a term: the member, the day the term starts (today unless changed) and the day it
/// ends (empty for an open term).
Future<bool> showMakeLeadSheet(
  BuildContext context, {
  required List<ContentMember> members,
  required Future<String?> Function(String userId, String termStartsOn, String termEndsOn) onSubmit,
  ManagePickers pickers = const ManagePickers(),
  DateTime Function() now = DateTime.now,
}) async =>
    await showEditSheet<bool>(
      context,
      builder: (_) => _MakeLeadSheet(members: members, onSubmit: onSubmit, pickers: pickers, now: now),
    ) ??
    false;

class _MakeLeadSheet extends StatefulWidget {
  const _MakeLeadSheet({required this.members, required this.onSubmit, required this.pickers, required this.now});

  final List<ContentMember> members;
  final Future<String?> Function(String userId, String termStartsOn, String termEndsOn) onSubmit;
  final ManagePickers pickers;
  final DateTime Function() now;

  @override
  State<_MakeLeadSheet> createState() => _MakeLeadSheetState();
}

class _MakeLeadSheetState extends State<_MakeLeadSheet> with _Submits {
  ContentMember? _member;
  late String _starts = isoDay(widget.now());
  String _ends = '';

  Future<void> _pickMember() async {
    final picked = await showAccountPicker<ContentMember>(
      context,
      title: 'Member',
      items: widget.members,
      labelOf: (m) => m.name,
      searchable: widget.members.length > 8,
      selected: _member,
    );
    if (picked != null) touch(() => _member = picked);
  }

  @override
  Widget build(BuildContext context) {
    final member = _member;
    return EditSheet(
      title: 'Make a Member a Lead',
      saving: saving,
      error: error,
      dirty: dirty,
      saveLabel: 'Make Lead',
      onSave: saving || member == null
          ? null
          : () => send(
              leadProblem(termStartsOn: _starts, termEndsOn: _ends),
              () => widget.onSubmit(member.userId, _starts, _ends),
            ),
      children: [
        AccountSelectField(
          key: const Key('makeLead.member'),
          label: 'Member',
          required: true,
          hint: 'Choose a member',
          value: member?.name,
          onTap: _pickMember,
        ),
        DayField(
          key: const Key('makeLead.termStarts'),
          label: 'Term Starts',
          value: _starts,
          pickers: widget.pickers,
          onChanged: (v) => touch(() => _starts = v),
        ),
        DayField(
          key: const Key('makeLead.termEnds'),
          label: 'Term Ends',
          value: _ends,
          hint: 'Open',
          helper: 'Leave empty for an open term',
          pickers: widget.pickers,
          onChanged: (v) => touch(() => _ends = v),
        ),
      ],
    );
  }
}

// --- a decision on a request -------------------------------------------------------------------------------------------

/// Approve or decline a member's request (the website's `DecideDialog`): a note to the member when approving, the
/// reason — which they read — when declining.
Future<bool> showDecideSheet(
  BuildContext context, {
  required OrgKind kind,
  required String title,
  required bool declining,
  required Future<String?> Function(String? reason) onSubmit,
}) async =>
    await showEditSheet<bool>(
      context,
      builder: (_) => _DecideSheet(kind: kind, title: title, declining: declining, onSubmit: onSubmit),
    ) ??
    false;

class _DecideSheet extends StatefulWidget {
  const _DecideSheet({required this.kind, required this.title, required this.declining, required this.onSubmit});

  final OrgKind kind;
  final String title;
  final bool declining;
  final Future<String?> Function(String? reason) onSubmit;

  @override
  State<_DecideSheet> createState() => _DecideSheetState();
}

class _DecideSheetState extends State<_DecideSheet> with _Submits {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final declining = widget.declining;
    final lead = declining
        ? 'The member reads this reason in their notifications and on their application.'
        : widget.kind == OrgKind.chapter
        ? 'Approving makes the member lead from today. A new chapter is created unpublished: finish its page in '
              'the Chapters tab, then publish it.'
        : 'Approving creates the council unpublished with the member as lead: finish its page in the Councils '
              'tab, then publish it.';
    return EditSheet(
      title: declining ? 'Decline' : 'Approve',
      subtitle: widget.title,
      saving: saving,
      error: error,
      dirty: dirty,
      saveLabel: declining ? 'Decline' : 'Approve',
      danger: declining,
      onSave: saving
          ? null
          : () => send(decisionProblem(declining: declining, reason: _reason.text), () {
              final reason = _reason.text.trim();
              return widget.onSubmit(reason.isEmpty ? null : reason);
            }),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(lead, style: AccountText.body),
        ),
        AccountField(
          fieldKey: const Key('decide.reason'),
          label: declining ? 'Reason (required)' : 'Note to the Member (optional)',
          controller: _reason,
          maxLines: 6,
          minLines: 3,
          maxLength: ManageLimits.decisionReason,
          counter: true,
          onChanged: (_) => touch(),
        ),
      ],
    );
  }
}
