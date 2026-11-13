import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart' show openExternal;
import '../account/widgets/account_kit.dart';
import 'events_manage_controllers.dart';
import 'events_manage_kit.dart';
import 'events_manage_models.dart';
import 'events_manage_rules.dart';

/// The sheets one event's manage page and the Event partners tab open over everything: each is a form or a
/// decision of the website's Programme, Tickets and host-request dialogs. A refusal stays in the sheet, in the
/// API's own words, with what was typed kept.

// --- guest list ------------------------------------------------------------------------------------------------------

/// "Invite by email"; the result sentence when members were asked, null when backed out of.
Future<String?> showInviteByEmailSheet(BuildContext context, {required ManageEventController controller}) =>
    showEditSheet<String>(context, builder: (_) => _InviteByEmailSheet(controller: controller));

class _InviteByEmailSheet extends StatefulWidget {
  const _InviteByEmailSheet({required this.controller});

  final ManageEventController controller;

  @override
  State<_InviteByEmailSheet> createState() => _InviteByEmailSheetState();
}

class _InviteByEmailSheetState extends State<_InviteByEmailSheet> {
  final _emails = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _emails.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final list = splitEmails(_emails.text);
    final problem = inviteEmailsProblem(list);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final out = await widget.controller.invite(list);
    if (!mounted) return;
    if (out.result != null) {
      Navigator.of(context).pop(inviteResultLine(out.result!));
      return;
    }
    setState(() {
      _saving = false;
      _error = out.refusal ?? 'Could not invite.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return EditSheet(
      title: 'Invite by Email',
      saving: _saving,
      error: _error,
      dirty: _emails.text.trim().isNotEmpty,
      saveLabel: 'Invite',
      onSave: _saving || _emails.text.trim().isEmpty ? null : _send,
      children: [
        AccountField(
          fieldKey: const Key('invite.emails'),
          label: 'Email Addresses',
          controller: _emails,
          maxLines: 4,
          minLines: 3,
          textCapitalization: TextCapitalization.none,
          hint: 'one@x.com, two@y.com',
          helper: 'ICR members only; others are reported back.',
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }
}

/// "Invite by tier"; the result sentence, or null.
Future<String?> showInviteByTierSheet(BuildContext context, {required ManageEventController controller}) =>
    showEditSheet<String>(context, builder: (_) => _InviteByTierSheet(controller: controller));

class _InviteByTierSheet extends StatefulWidget {
  const _InviteByTierSheet({required this.controller});

  final ManageEventController controller;

  @override
  State<_InviteByTierSheet> createState() => _InviteByTierSheetState();
}

class _InviteByTierSheetState extends State<_InviteByTierSheet> {
  String _tier = 'GOLD';
  bool _saving = false;
  String? _error;

  Future<void> _pick() async {
    final picked = await showAccountPicker<String>(
      context,
      title: 'Invite by Tier',
      items: inviteTiers,
      labelOf: (t) => '${tierLabel(t)} and above',
      selected: _tier,
    );
    if (picked != null) setState(() => _tier = picked);
  }

  Future<void> _send() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final out = await widget.controller.inviteByTier(_tier);
    if (!mounted) return;
    if (out.result != null) {
      Navigator.of(context).pop(tierResultLine(out.result!, _tier));
      return;
    }
    setState(() {
      _saving = false;
      _error = out.refusal ?? 'Could not invite.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return EditSheet(
      title: 'Invite by Tier',
      saving: _saving,
      error: _error,
      saveLabel: 'Invite Everyone on the Tier',
      onSave: _saving ? null : _send,
      children: [
        AccountSelectField(
          key: const Key('invite.tier'),
          label: 'Tier',
          hint: 'Select a tier',
          value: '${tierLabel(_tier)} and above',
          onTap: _pick,
        ),
        Text(
          'A tier sweep reaches personal plans and every member of a company on the plan. It writes one invite per '
          'person and tells only the new ones; run it again after plans change.',
          style: AccountText.meta,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// --- speakers --------------------------------------------------------------------------------------------------------

/// One talk proposal in full, with Accept and Decline while it is under review; true when decided.
Future<bool> showProposalSheet(
  BuildContext context, {
  required ManageEventController controller,
  required EventProposal proposal,
}) async =>
    await showEditSheet<bool>(
      context,
      builder: (_) => _DecisionSheet(
        kicker: 'Talk proposal',
        title: proposal.title,
        statusLabel: proposalStatusLabel(proposal.status),
        statusTone: proposalTone(proposal.status),
        lines: [
          [proposal.speaker, proposal.email, if (proposal.bio != null) proposal.bio!].join(' · '),
        ],
        body: proposal.abstract,
        decidedNote: proposal.reviewNote,
        open: proposal.pending,
        noteLabel: 'Note to the Speaker',
        noteHint: 'Required to decline; they read it',
        acceptLabel: 'Accept',
        onAccept: (note) => controller.decideProposal(proposal, 'ACCEPTED', note: note),
        onDecline: (note) => controller.decideProposal(proposal, 'DECLINED', note: note),
      ),
    ) ??
    false;

EmTone proposalTone(String status) => switch (status) {
  'ACCEPTED' => EmTone.good,
  'DECLINED' => EmTone.muted,
  _ => EmTone.info,
};

// --- sponsors --------------------------------------------------------------------------------------------------------

/// One sponsorship request, with Confirm and Decline while it waits; true when decided.
Future<bool> showSponsorshipSheet(
  BuildContext context, {
  required ManageEventController controller,
  required SponsorshipRequest request,
}) async =>
    await showEditSheet<bool>(
      context,
      builder: (_) => _DecisionSheet(
        kicker: 'Sponsorship request',
        title: '${request.company} — ${request.package}',
        statusLabel: sponsorshipStatusLabel(request.status),
        statusTone: sponsorshipTone(request.status),
        lines: ['${request.contact} · ${request.email}'],
        body: request.note,
        decidedNote: request.decisionNote,
        open: request.open,
        noteLabel: 'Note to the Sponsor',
        noteHint: 'Required to decline; they read it',
        acceptLabel: 'Confirm',
        onAccept: (note) => controller.decideSponsorship(request, 'CONFIRMED', note: note),
        onDecline: (note) => controller.decideSponsorship(request, 'DECLINED', note: note),
      ),
    ) ??
    false;

EmTone sponsorshipTone(String status) => switch (status) {
  'CONFIRMED' => EmTone.good,
  'DECLINED' => EmTone.muted,
  _ => EmTone.info,
};

/// A proposal or a sponsorship request read in full, and decided: the note the other side reads, the main button
/// (Accept / Confirm) and Decline, which needs the note first.
class _DecisionSheet extends StatefulWidget {
  const _DecisionSheet({
    required this.kicker,
    required this.title,
    required this.statusLabel,
    required this.statusTone,
    required this.lines,
    required this.body,
    required this.decidedNote,
    required this.open,
    required this.noteLabel,
    required this.noteHint,
    required this.acceptLabel,
    required this.onAccept,
    required this.onDecline,
  });

  final String kicker;
  final String title;
  final String statusLabel;
  final EmTone statusTone;
  final List<String> lines;
  final String? body;
  final String? decidedNote;

  /// Still to be decided.
  final bool open;
  final String noteLabel;
  final String noteHint;
  final String acceptLabel;
  final Future<String?> Function(String? note) onAccept;
  final Future<String?> Function(String? note) onDecline;

  @override
  State<_DecisionSheet> createState() => _DecisionSheetState();
}

class _DecisionSheetState extends State<_DecisionSheet> {
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _decide(Future<String?> Function(String? note) send, {required bool needsNote}) async {
    final note = _note.text.trim();
    if (needsNote && note.isEmpty) {
      setState(() => _error = 'Write the reason first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final refusal = await send(note.isEmpty ? null : note);
    if (!mounted) return;
    if (refusal == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error = refusal;
    });
  }

  @override
  Widget build(BuildContext context) {
    return EmSheet(
      kicker: widget.kicker,
      title: widget.title,
      error: _error,
      actions: widget.open
          ? [
              AccountButton(
                key: const Key('decision.decline'),
                label: 'Decline',
                outlined: true,
                danger: true,
                expand: false,
                onPressed: _busy ? null : () => _decide(widget.onDecline, needsNote: true),
              ),
              AccountButton(
                key: const Key('decision.accept'),
                label: widget.acceptLabel,
                busy: _busy,
                expand: false,
                onPressed: _busy ? null : () => _decide(widget.onAccept, needsNote: false),
              ),
            ]
          : const [],
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: EmStatus(label: widget.statusLabel, tone: widget.statusTone),
          ),
        ),
        for (final line in widget.lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(line, style: EmText.secondary),
          ),
        if (widget.body != null && widget.body!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Text(widget.body!, style: EmText.body),
          ),
        if (widget.decidedNote != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Note: ${widget.decidedNote}', style: EmText.secondary),
          ),
        if (widget.open)
          AccountField(
            fieldKey: const Key('decision.note'),
            label: widget.noteLabel,
            controller: _note,
            maxLines: 4,
            minLines: 2,
            maxLength: decisionNoteMax,
            hint: widget.noteHint,
          ),
      ],
    );
  }
}

/// Add or edit a sponsorship package; `'saved'` or `'removed'`, null when backed out of.
Future<String?> showPackageSheet(
  BuildContext context, {
  required ManageEventController controller,
  SponsorPackage? package,
}) => showEditSheet<String>(
  context,
  builder: (_) => _PackageSheet(controller: controller, package: package),
);

class _PackageSheet extends StatefulWidget {
  const _PackageSheet({required this.controller, this.package});

  final ManageEventController controller;
  final SponsorPackage? package;

  @override
  State<_PackageSheet> createState() => _PackageSheetState();
}

class _PackageSheetState extends State<_PackageSheet> {
  late final PackageDraft _d = PackageDraft.of(widget.package);
  late final _name = TextEditingController(text: _d.name);
  late final _price = TextEditingController(text: _d.price);
  late final _slots = TextEditingController(text: _d.slots);
  late final _benefits = TextEditingController(text: _d.benefits);
  bool _saving = false;
  bool _dirty = false;
  bool _checked = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _slots.dispose();
    _benefits.dispose();
    super.dispose();
  }

  void _touch(VoidCallback change) => setState(() {
    change();
    _dirty = true;
  });

  Future<void> _save() async {
    final problems = _d.problems();
    if (problems.isNotEmpty) {
      setState(() {
        _checked = true;
        _error = problems.length == 1 ? problems.values.first : 'Check the fields marked in red.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final refusal = await widget.controller.savePackage(widget.package, _d.toJson());
    if (!mounted) return;
    if (refusal == null) {
      Navigator.of(context).pop('saved');
      return;
    }
    setState(() {
      _saving = false;
      _error = refusal;
    });
  }

  Future<void> _remove() async {
    final p = widget.package!;
    final ok = await confirmAction(
      context,
      title: 'Remove This Package?',
      message: '"${p.name}" is no longer offered. Requests already made for it stay as they are.',
      confirm: 'Remove',
    );
    if (!ok || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final refusal = await widget.controller.removePackage(p);
    if (!mounted) return;
    if (refusal == null) {
      Navigator.of(context).pop('removed');
      return;
    }
    setState(() {
      _saving = false;
      _error = refusal;
    });
  }

  @override
  Widget build(BuildContext context) {
    final problems = _checked ? _d.problems() : const <String, String>{};
    final editing = widget.package != null;
    return EditSheet(
      title: editing ? 'Edit Package' : 'Add a Package',
      saving: _saving,
      error: _error,
      dirty: _dirty,
      saveLabel: editing ? 'Save Changes' : 'Add',
      onSave: _saving ? null : _save,
      onDelete: editing ? _remove : null,
      deleteLabel: 'Remove',
      children: [
        AccountField(
          fieldKey: const Key('package.name'),
          label: 'Name',
          required: true,
          controller: _name,
          maxLength: packageNameMax,
          hint: 'Gold partner',
          error: problems['name'],
          onChanged: (v) => _touch(() => _d.name = v),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AccountField(
                fieldKey: const Key('package.price'),
                label: 'Price (₹)',
                required: true,
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                error: problems['price'],
                onChanged: (v) => _touch(() => _d.price = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AccountField(
                fieldKey: const Key('package.slots'),
                label: 'Slots',
                controller: _slots,
                keyboardType: TextInputType.number,
                helper: 'Blank: no cap',
                error: problems['slots'],
                onChanged: (v) => _touch(() => _d.slots = v),
              ),
            ),
          ],
        ),
        AccountField(
          fieldKey: const Key('package.benefits'),
          label: 'Benefits, One per Line',
          controller: _benefits,
          maxLines: 8,
          minLines: 2,
          error: problems['benefits'],
          onChanged: (v) => _touch(() => _d.benefits = v),
        ),
      ],
    );
  }
}

// --- tickets ---------------------------------------------------------------------------------------------------------

/// Records a refund made in the gateway (the website's "Mark refunded"); the outcome, or null when backed out of.
Future<RefundOutcome?> showRefundSheet(
  BuildContext context, {
  required ManageEventController controller,
  required TicketRow ticket,
}) => showEditSheet<RefundOutcome>(
  context,
  builder: (_) => _RefundSheet(controller: controller, ticket: ticket),
);

class _RefundSheet extends StatefulWidget {
  const _RefundSheet({required this.controller, required this.ticket});

  final ManageEventController controller;
  final TicketRow ticket;

  @override
  State<_RefundSheet> createState() => _RefundSheetState();
}

class _RefundSheetState extends State<_RefundSheet> {
  final _ref = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _ref.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final out = await widget.controller.refund(widget.ticket, refundRef: _ref.text.trim());
    if (!mounted) return;
    if (out.outcome != null) {
      Navigator.of(context).pop(out.outcome);
      return;
    }
    setState(() {
      _saving = false;
      _error = out.refusal ?? 'Could not record the refund.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    final problem = refundRefProblem(_ref.text);
    return EditSheet(
      title: 'Refund Ticket',
      subtitle: '${t.name} · ${moneyLabel(t.totalPaisa)}',
      saving: _saving,
      error: _error,
      dirty: _ref.text.trim().isNotEmpty,
      saveLabel: 'Mark Refunded',
      onSave: _saving || problem != null ? null : _send,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            'Refund ${moneyLabel(t.totalPaisa)} to ${t.firstName.isEmpty ? t.name : t.firstName} in the PayU '
            'dashboard first, then record it. Their seat is given up.',
            style: AccountText.body,
          ),
        ),
        AccountField(
          fieldKey: const Key('refund.ref'),
          label: 'Refund Reference',
          controller: _ref,
          maxLength: refundRefMax,
          textCapitalization: TextCapitalization.none,
          helper: approvalReferenceHelp,
          error: problem,
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }
}

// --- attendance ------------------------------------------------------------------------------------------------------

/// Tick who came; the result sentence, or null when backed out of.
Future<String?> showAttendanceSheet(BuildContext context, {required ManageEventController controller}) =>
    showEditSheet<String>(context, builder: (_) => _AttendanceSheet(controller: controller));

class _AttendanceSheet extends StatefulWidget {
  const _AttendanceSheet({required this.controller});

  final ManageEventController controller;

  @override
  State<_AttendanceSheet> createState() => _AttendanceSheetState();
}

class _AttendanceSheetState extends State<_AttendanceSheet> {
  late final _people = widget.controller.attendanceCandidates;
  final Set<String> _picked = {};
  bool _saving = false;
  String? _error;

  Future<void> _send() async {
    if (_picked.length > attendanceMax) {
      setState(() => _error = 'Mark $attendanceMax people at most at a time.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final out = await widget.controller.markAttendance(_picked.toList());
    if (!mounted) return;
    if (out.result != null) {
      Navigator.of(context).pop(attendanceResultLine(out.result!, _picked.length));
      return;
    }
    setState(() {
      _saving = false;
      _error = out.refusal ?? 'Could not mark attendance.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final all = _picked.length == _people.length && _people.isNotEmpty;
    return EditSheet(
      title: 'Mark Attendance',
      subtitle: 'Tick everyone who was present.',
      saving: _saving,
      error: _error,
      dirty: _picked.isNotEmpty,
      saveLabel: _picked.isEmpty ? 'Mark Present' : 'Mark ${_picked.length} Present',
      onSave: _saving || _picked.isEmpty ? null : _send,
      children: [
        if (_people.length > 1)
          AccountCheck(
            key: const Key('attendance.all'),
            value: all,
            label: 'Everyone (${_people.length})',
            onChanged: (on) => setState(() {
              _picked.clear();
              if (on) _picked.addAll(_people.map((p) => p.userId));
            }),
          ),
        for (final p in _people)
          AccountCheck(
            key: ValueKey('attendance.${p.userId}'),
            value: _picked.contains(p.userId),
            label: p.email.isEmpty ? p.name : '${p.name}\n${p.email}',
            onChanged: (on) => setState(() => on ? _picked.add(p.userId) : _picked.remove(p.userId)),
          ),
      ],
    );
  }
}

// --- companies asking to host ----------------------------------------------------------------------------------------

EmTone hostTone(String status) => switch (status) {
  'PENDING' => EmTone.warn,
  'APPROVED' => EmTone.good,
  'REJECTED' => EmTone.bad,
  _ => EmTone.muted,
};

/// One request to host events in full, with the decision: approve, reject (with a reason) or, once approved,
/// revoke. `'approve'`, `'reject'` or `'revoke'` when decided.
Future<String?> showHostRequestSheet(
  BuildContext context, {
  required HostRequestsController controller,
  required HostApplication request,
}) => showEditSheet<String>(
  context,
  builder: (_) => _HostRequestSheet(controller: controller, request: request),
);

class _HostRequestSheet extends StatefulWidget {
  const _HostRequestSheet({required this.controller, required this.request});

  final HostRequestsController controller;
  final HostApplication request;

  @override
  State<_HostRequestSheet> createState() => _HostRequestSheetState();
}

class _HostRequestSheetState extends State<_HostRequestSheet> {
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _act(String action) async {
    final note = _note.text.trim();
    if (action != 'approve' && note.isEmpty) {
      setState(() => _error = 'Give the company a reason — they will see it.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final refusal = await widget.controller.decide(widget.request, action, note: note.isEmpty ? null : note);
    if (!mounted) return;
    if (refusal == null) {
      Navigator.of(context).pop(action);
      return;
    }
    setState(() {
      _busy = false;
      _error = refusal;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final pending = r.status == 'PENDING';
    final approved = r.status == 'APPROVED';
    return EmSheet(
      kicker: 'Request to host events',
      title: r.company,
      error: _error,
      actions: [
        if (pending) ...[
          AccountButton(
            key: const Key('host.reject'),
            label: 'Reject',
            outlined: true,
            danger: true,
            expand: false,
            onPressed: _busy ? null : () => _act('reject'),
          ),
          AccountButton(
            key: const Key('host.approve'),
            label: 'Approve',
            busy: _busy,
            expand: false,
            onPressed: _busy ? null : () => _act('approve'),
          ),
        ],
        if (approved)
          AccountButton(
            key: const Key('host.revoke'),
            label: 'Revoke Hosting',
            danger: true,
            busy: _busy,
            expand: false,
            onPressed: _busy ? null : () => _act('revoke'),
          ),
      ],
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: EmStatus(label: hostStatusLabel(r.status), tone: hostTone(r.status)),
          ),
        ),
        EmDetail(label: 'What they plan', value: r.about),
        EmDetail(label: 'Kinds of event', value: r.kindsLabel ?? '—'),
        EmDetail(label: 'How often', value: r.frequency ?? '—'),
        EmDetail(
          label: 'Website',
          child: r.website == null
              ? Text('—', style: EmText.body)
              : InkWell(
                  key: const Key('host.website'),
                  onTap: () {
                    final raw = r.website!.trim();
                    final uri = Uri.tryParse(raw.contains('://') ? raw : 'https://$raw');
                    if (uri != null) openExternal(context, uri);
                  },
                  child: Text(r.website!, style: EmText.body.copyWith(color: AppColors.primary)),
                ),
        ),
        EmDetail(
          label: 'Contact',
          value: [r.contactName, r.contactEmail, if (r.contactPhone != null) r.contactPhone!].join(' · '),
        ),
        EmDetail(label: 'Asked by', value: '${r.appliedBy} on ${dayLabel(r.createdAt)}'),
        if (r.hostedEventCount != null) EmDetail(label: 'Events hosted', value: '${r.hostedEventCount}'),
        if (r.reviewedAt != null)
          EmDetail(
            label: 'Decided',
            value: '${dayLabel(r.reviewedAt!)}${r.reviewNote != null ? ' — ${r.reviewNote}' : ''}',
          ),
        if (pending || approved) ...[
          const SizedBox(height: 14),
          AccountField(
            fieldKey: const Key('host.note'),
            label: pending ? 'Note to the Company' : 'Reason for Revoking',
            controller: _note,
            maxLines: 4,
            minLines: 2,
            maxLength: hostNoteMax,
            helper: pending ? 'Optional when approving; required to reject. They will see it.' : 'They will see it.',
          ),
        ],
      ],
    );
  }
}
