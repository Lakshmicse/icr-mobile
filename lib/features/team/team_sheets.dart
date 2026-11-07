import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/api/api_error.dart';
import '../../core/theme/app_colors.dart';
import '../account/account_labels.dart';
import '../account/widgets/account_kit.dart';
import 'team_models.dart';
import 'team_rules.dart';
import 'team_words.dart';

// --- shared pickers ------------------------------------------------------------------------------------------------

/// A role from [roles], in a sheet; null when the person backs out.
Future<String?> pickTeamRole(
  BuildContext context, {
  required List<String> roles,
  required String selected,
  String Function(String role) labelOf = roleLabel,
}) => showAccountPicker<String>(context, title: TeamWords.role, items: roles, labelOf: labelOf, selected: selected);

/// A role as the invite form words it: a Member is "Member (learning roles only)" there, as the website's invite
/// select; the other forms keep the plain role names.
String inviteRoleLabel(String role) => role == 'PROFESSIONAL' ? TeamWords.memberLearningOnly : roleLabel(role);

/// An office from [offices] (or "Company-wide"), indented under the one it sits in; null when the person backs out.
Future<Office?> pickTeamOffice(BuildContext context, {required List<Office> offices, required Office selected}) =>
    showAccountPicker<Office>(
      context,
      title: TeamWords.office,
      items: [Office.companyWide, ...offices],
      labelOf: (o) => '${'    ' * o.depth}${o.name}',
      selected: selected,
    );

/// The role field of a form: a labelled field that opens the list.
class RoleSelect extends StatelessWidget {
  const RoleSelect({
    super.key,
    required this.label,
    required this.role,
    required this.roles,
    required this.onPicked,
    this.labelOf = roleLabel,
  });

  final String label;
  final String role;
  final List<String> roles;
  final ValueChanged<String> onPicked;

  /// How a role reads in the field and the list.
  final String Function(String role) labelOf;

  @override
  Widget build(BuildContext context) {
    return AccountSelectField(
      label: label,
      hint: 'Choose a role',
      value: labelOf(role),
      onTap: () async {
        final picked = await pickTeamRole(context, roles: roles, selected: role, labelOf: labelOf);
        if (picked != null) onPicked(picked);
      },
    );
  }
}

/// The office field of a form.
class OfficeSelect extends StatelessWidget {
  const OfficeSelect({
    super.key,
    required this.label,
    required this.office,
    required this.offices,
    required this.onPicked,
    this.helper,
  });

  final String label;
  final Office office;
  final List<Office> offices;
  final ValueChanged<Office> onPicked;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return AccountSelectField(
      label: label,
      hint: TeamWords.companyWide,
      value: office.id.isEmpty ? null : office.name,
      helper: helper,
      onTap: () async {
        final picked = await pickTeamOffice(context, offices: offices, selected: office);
        if (picked != null) onPicked(picked);
      },
    );
  }
}

Office _officeFor(List<Office> offices, String? id) {
  for (final o in offices) {
    if (o.id == id) return o;
  }
  return Office.companyWide;
}

/// A tinted note in a form: information, or (amber) something to look at before sending.
/// The learning roles a form gives with the main role, at a learning-partner company: the website's
/// `LearningRolesField` — a heading, its hint, one tick per role, and the problem under them.
class LearningRolesField extends StatelessWidget {
  const LearningRolesField({super.key, required this.value, required this.onChanged, this.error});

  final List<String> value;
  final ValueChanged<List<String>> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(TeamWords.learningRoles, style: AccountText.label),
          const SizedBox(height: 2),
          Text(TeamWords.pickAnyNumber, style: AccountText.meta),
          const SizedBox(height: 6),
          for (final role in TeamViewer.learningStaffRoles)
            AccountCheck(
              key: Key('learning.$role'),
              value: value.contains(role),
              label: learningRoleLabel(role),
              onChanged: (on) => onChanged([
                for (final r in TeamViewer.learningStaffRoles)
                  if (r == role ? on : value.contains(r)) r,
              ]),
            ),
          if (error != null) Text(error!, key: const Key('learning.error'), style: AccountText.error),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text, {super.key, this.warn = false});

  final String text;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: warn ? AppColors.amber50 : AppColors.chipEmphasis,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(warn ? Symbols.warning : Symbols.info, size: 16, color: warn ? AppColors.amber800 : AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AccountText.body)),
        ],
      ),
    );
  }
}

/// A person with their photo, name and (when known) headline.
class _PersonLine extends StatelessWidget {
  const _PersonLine({required this.person, this.trailing});

  final TeamPerson person;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AccountAvatar(url: person.avatarUrl, initials: teamInitials(person.firstName, person.lastName), size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(person.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AccountText.itemTitle),
              if (person.headline != null)
                Text(person.headline!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AccountText.meta),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

// --- approve a request ---------------------------------------------------------------------------------------------

/// Sends the approval; null when it went, else the API's sentence.
typedef SendApproval = Future<String?> Function(String role, String? branchId);

/// Approving a request: the admin names the role the person joins with, and the office when the company has some.
/// True when approved.
Future<bool> showApproveSheet(
  BuildContext context, {
  required TeamRequest request,
  required List<Office> offices,
  required SendApproval send,
}) async =>
    await showEditSheet<bool>(
      context,
      builder: (_) => ApproveSheet(request: request, offices: offices, send: send),
    ) ??
    false;

class ApproveSheet extends StatefulWidget {
  const ApproveSheet({super.key, required this.request, required this.offices, required this.send});

  final TeamRequest request;
  final List<Office> offices;
  final SendApproval send;

  @override
  State<ApproveSheet> createState() => _ApproveSheetState();
}

class _ApproveSheetState extends State<ApproveSheet> {
  late String _role = widget.request.role;
  Office _office = Office.companyWide;
  bool _sending = false;
  String? _error;

  List<String> get _roles => TeamViewer.approveRoles.contains(widget.request.role)
      ? TeamViewer.approveRoles
      : [widget.request.role, ...TeamViewer.approveRoles];

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final failure = await widget.send(_role, _office.id.isEmpty ? null : _office.id);
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _sending = false;
      _error = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    return EditSheet(
      title: 'Approve ${r.name}',
      subtitle: 'Asked as ${roleLabel(r.role)}. You name the role they join with.',
      saveLabel: TeamWords.approve,
      saving: _sending,
      error: _error,
      dirty: _role != r.role || _office.id.isNotEmpty,
      onSave: _send,
      children: [
        if (r.note != null) ...[
          Text('“${r.note}”', style: AccountText.body.copyWith(fontStyle: FontStyle.italic)),
          const SizedBox(height: 14),
        ],
        RoleSelect(
          key: const Key('approve.role'),
          label: TeamWords.joinAs,
          role: _role,
          roles: _roles,
          onPicked: (v) => setState(() => _role = v),
        ),
        if (widget.offices.isNotEmpty)
          OfficeSelect(
            key: const Key('approve.office'),
            label: TeamWords.officeOptional,
            office: _office,
            offices: widget.offices,
            onPicked: (v) => setState(() => _office = v),
          ),
      ],
    );
  }
}

// --- edit a member -------------------------------------------------------------------------------------------------

/// Sends the change (only what changed); null when it went, else the API's sentence.
typedef SendMemberChange = Future<String?> Function(Map<String, Object?> patch);

/// A member's role and office. True when saved.
Future<bool> showEditMemberSheet(
  BuildContext context, {
  required TeamMember member,
  required TeamViewer viewer,
  required List<Office> offices,
  required SendMemberChange send,
}) async =>
    await showEditSheet<bool>(
      context,
      builder: (_) => EditMemberSheet(member: member, viewer: viewer, offices: offices, send: send),
    ) ??
    false;

class EditMemberSheet extends StatefulWidget {
  const EditMemberSheet({
    super.key,
    required this.member,
    required this.viewer,
    required this.offices,
    required this.send,
  });

  final TeamMember member;
  final TeamViewer viewer;
  final List<Office> offices;
  final SendMemberChange send;

  @override
  State<EditMemberSheet> createState() => _EditMemberSheetState();
}

class _EditMemberSheetState extends State<EditMemberSheet> {
  late String _role = widget.member.role;
  late Office _office = _officeFor(widget.offices, widget.member.branchId);
  late List<String> _learningRoles = List.of(widget.member.learningRoles);
  bool _sending = false;
  String? _error;

  bool get _roleChanged => _role != widget.member.role;
  bool get _officeChanged => _office.id != (widget.member.branchId ?? '');
  bool get _learningChanged =>
      widget.viewer.givesLearningRoles && !_sameRoles(_learningRoles, widget.member.learningRoles);
  bool get _changed => _roleChanged || _officeChanged || _learningChanged;

  /// A Member keeps at least one learning role (the website's `keepOne`); becoming one needs one picked.
  bool get _needsOne => widget.viewer.givesLearningRoles && TeamViewer.memberNeedsLearningRole(_role, _learningRoles);

  static bool _sameRoles(List<String> a, List<String> b) => a.length == b.length && a.toSet().containsAll(b);

  Future<void> _save() async {
    if (!_changed || _needsOne) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    // Only what changed goes: a null `branchId` clears the office.
    final failure = await widget.send({
      if (_roleChanged) 'role': _role,
      if (_officeChanged) 'branchId': _office.id.isEmpty ? null : _office.id,
      if (_learningChanged) 'learningRoles': _learningRoles,
    });
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _sending = false;
      _error = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    final showOffice = widget.viewer.picksOffice(_role) && widget.offices.isNotEmpty;
    return EditSheet(
      title: TeamWords.editTitle(m.name),
      subtitle: m.email,
      saving: _sending,
      error: _error,
      dirty: _changed,
      onSave: _changed && !_needsOne ? _save : null,
      children: [
        RoleSelect(
          key: const Key('edit.role'),
          label: TeamWords.role,
          role: _role,
          roles: widget.viewer.editRoles(m.role),
          onPicked: (v) => setState(() => _role = v),
        ),
        if (widget.viewer.givesLearningRoles)
          LearningRolesField(
            key: const Key('edit.learningRoles'),
            value: _learningRoles,
            onChanged: (v) => setState(() => _learningRoles = v),
            error: !_needsOne
                ? null
                : m.role == 'PROFESSIONAL'
                ? TeamWords.keepOne
                : TeamWords.pickALearningRole,
          ),
        if (showOffice)
          OfficeSelect(
            key: const Key('edit.office'),
            label: TeamWords.office,
            office: _office,
            offices: widget.offices,
            helper: TeamWords.officeHelp,
            onPicked: (v) => setState(() => _office = v),
          ),
      ],
    );
  }
}

// --- add someone already on ICR -----------------------------------------------------------------------------------

/// Sends the add; null when it went, else the API's sentence.
typedef SendAdd =
    Future<String?> Function(TeamPerson person, String role, String? branchId, List<String> learningRoles);

/// "Add someone on ICR": find a member by name, name their role (and office), and ask them. True when asked.
Future<bool> showAddPersonSheet(
  BuildContext context, {
  required TeamViewer viewer,
  required List<Office> offices,
  required Future<List<TeamPerson>> Function(String query) search,
  required SendAdd send,
  Duration searchDelay = const Duration(milliseconds: 300),
}) async =>
    await showEditSheet<bool>(
      context,
      builder: (_) =>
          AddPersonSheet(viewer: viewer, offices: offices, search: search, send: send, searchDelay: searchDelay),
    ) ??
    false;

class AddPersonSheet extends StatefulWidget {
  const AddPersonSheet({
    super.key,
    required this.viewer,
    required this.offices,
    required this.search,
    required this.send,
    this.searchDelay = const Duration(milliseconds: 300),
  });

  final TeamViewer viewer;
  final List<Office> offices;
  final Future<List<TeamPerson>> Function(String query) search;
  final SendAdd send;
  final Duration searchDelay;

  @override
  State<AddPersonSheet> createState() => _AddPersonSheetState();
}

class _AddPersonSheetState extends State<AddPersonSheet> {
  final _query = TextEditingController();
  Timer? _debounce;

  TeamPerson? _picked;
  List<TeamPerson> _found = const [];
  String _searched = '';
  bool _searching = false;
  String? _searchError;
  late String _role = widget.viewer.defaultRole;
  Office _office = Office.companyWide;
  List<String> _learningRoles = const [];
  bool _sending = false;
  String? _error;

  bool get _needsLearningRole =>
      widget.viewer.givesLearningRoles && TeamViewer.memberNeedsLearningRole(_role, _learningRoles);

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _typed(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      setState(() {
        _found = const [];
        _searched = '';
        _searching = false;
        _searchError = null;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(widget.searchDelay, () async {
      try {
        final hits = await widget.search(q);
        // A slower answer to an older query must not overwrite a newer one.
        if (!mounted || _query.text.trim() != q) return;
        setState(() {
          _found = hits;
          _searched = q;
          _searching = false;
          _searchError = null;
        });
      } catch (e) {
        if (!mounted || _query.text.trim() != q) return;
        setState(() {
          _searching = false;
          _searchError = ApiError.from(e).message;
        });
      }
    });
  }

  Future<void> _send() async {
    final person = _picked;
    if (person == null || _sending || _needsLearningRole) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final failure = await widget.send(person, _role, _office.id.isEmpty ? null : _office.id, _learningRoles);
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    // The choices stay as they were.
    setState(() {
      _sending = false;
      _error = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    final picked = _picked;
    return EditSheet(
      title: TeamWords.addSomeone,
      saveLabel: _sending ? TeamWords.asking : TeamWords.askToJoin,
      saving: _sending,
      error: _error,
      dirty: picked != null,
      onSave: picked == null || _needsLearningRole ? null : _send,
      children: picked == null ? _searchStep() : _roleStep(picked),
    );
  }

  List<Widget> _searchStep() {
    return [
      AccountField(
        label: TeamWords.searchMembers,
        controller: _query,
        fieldKey: const Key('add.search'),
        hint: TeamWords.typeAName,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.search,
        onChanged: _typed,
        suffix: _searching
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : const Icon(Icons.search_rounded, color: AppColors.slate400),
      ),
      if (_searchError != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(_searchError!, key: const Key('add.searchError'), style: AccountText.error),
        )
      else if (_searched.isNotEmpty && _found.isEmpty && !_searching)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(TeamWords.nobodyFound, key: const Key('add.none'), style: AccountText.meta),
        ),
      for (final p in _found)
        InkWell(
          key: Key('add.hit.${p.id}'),
          onTap: () => setState(() => _picked = p),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _PersonLine(
              person: p,
              trailing: Text(TeamWords.askToJoin, style: AccountText.link),
            ),
          ),
        ),
    ];
  }

  List<Widget> _roleStep(TeamPerson person) {
    final viewer = widget.viewer;
    return [
      _PersonLine(
        person: person,
        trailing: TextButton(
          key: const Key('add.change'),
          onPressed: _sending ? null : () => setState(() => _picked = null),
          child: const Text(TeamWords.change),
        ),
      ),
      const SizedBox(height: 14),
      if (!viewer.isSupplier)
        RoleSelect(
          key: const Key('add.role'),
          label: TeamWords.role,
          role: _role,
          roles: viewer.addRoles,
          onPicked: (v) => setState(() => _role = v),
        )
      else
        const _Note(TeamWords.joinSupplier),
      if (viewer.givesLearningRoles)
        LearningRolesField(
          key: const Key('add.learningRoles'),
          value: _learningRoles,
          onChanged: (v) => setState(() => _learningRoles = v),
          error: _needsLearningRole ? TeamWords.pickALearningRole : null,
        ),
      if (viewer.picksOffice(_role) && widget.offices.isNotEmpty)
        OfficeSelect(
          key: const Key('add.office'),
          label: TeamWords.officeOptional,
          office: _office,
          offices: widget.offices,
          onPicked: (v) => setState(() => _office = v),
        ),
      Text(TeamWords.addHelp, style: AccountText.meta),
    ];
  }
}

// --- invite by email -----------------------------------------------------------------------------------------------

/// Sends an email invite; null when it went, else the API's sentence.
typedef SendInvite = Future<String?> Function(String email, String role, String? branchId, List<String> learningRoles);

final _looksLikeEmail = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

/// "Invite by email". A company admin's form asks first whether the address is on ICR: someone with a public
/// profile is asked in the app (and joins once they accept), anyone else is sent the email. True when sent.
Future<bool> showInviteSheet(
  BuildContext context, {
  required TeamViewer viewer,
  required List<Office> offices,
  required Future<TeamLookup> Function(String email) lookup,
  required SendInvite sendInvite,
  required SendAdd sendAdd,
  Duration searchDelay = const Duration(milliseconds: 400),
  String? initialRole,
  List<String> initialLearningRoles = const [],
}) async =>
    await showEditSheet<bool>(
      context,
      builder: (_) => InviteSheet(
        viewer: viewer,
        offices: offices,
        lookup: lookup,
        sendInvite: sendInvite,
        sendAdd: sendAdd,
        searchDelay: searchDelay,
        initialRole: initialRole,
        initialLearningRoles: initialLearningRoles,
      ),
    ) ??
    false;

class InviteSheet extends StatefulWidget {
  const InviteSheet({
    super.key,
    required this.viewer,
    required this.offices,
    required this.lookup,
    required this.sendInvite,
    required this.sendAdd,
    this.searchDelay = const Duration(milliseconds: 400),
    this.initialRole,
    this.initialLearningRoles = const [],
  });

  final TeamViewer viewer;
  final List<Office> offices;
  final Future<TeamLookup> Function(String email) lookup;
  final SendInvite sendInvite;
  final SendAdd sendAdd;
  final Duration searchDelay;

  /// The role the form opens on (the viewer's default when null) and the learning roles already ticked — the
  /// menu's "Add a trainer" opens on Member with Trainer ticked.
  final String? initialRole;
  final List<String> initialLearningRoles;

  @override
  State<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<InviteSheet> {
  final _email = TextEditingController();
  Timer? _debounce;

  late String _role = widget.initialRole ?? widget.viewer.defaultRole;
  Office _office = Office.companyWide;
  late List<String> _learningRoles = List.of(widget.initialLearningRoles);

  /// The address the last lookup answered for, and its answer.
  String _lookedUp = '';
  TeamLookup? _found;
  bool _checking = false;
  bool _sending = false;
  String? _error;

  String get _typed => _email.text.trim().toLowerCase();

  @override
  void dispose() {
    _debounce?.cancel();
    _email.dispose();
    super.dispose();
  }

  void _changed(String _) {
    _debounce?.cancel();
    final address = _typed;
    if (!widget.viewer.canLookup || !_looksLikeEmail.hasMatch(address)) {
      setState(() {
        _found = null;
        _lookedUp = '';
        _checking = false;
      });
      return;
    }
    setState(() => _checking = true);
    _debounce = Timer(widget.searchDelay, () async {
      try {
        final answer = await widget.lookup(address);
        if (!mounted || _typed != address) return;
        setState(() {
          _found = answer;
          _lookedUp = address;
          _checking = false;
        });
      } catch (_) {
        // The lookup only decides how to ask; without it the invite goes by email.
        if (!mounted || _typed != address) return;
        setState(() {
          _found = null;
          _lookedUp = '';
          _checking = false;
        });
      }
    });
  }

  bool get _settled => _found != null && _lookedUp == _typed && !_checking;

  TeamPerson? get _person => _settled ? _found!.person : null;

  /// Someone on ICR with a public profile is asked in the app, except as Company Admin, which comes only from an
  /// invite they accept.
  bool get _addsDirectly => _person != null && _role != 'COMPANY_ADMIN';

  bool get _alreadyMember => _settled && _found!.alreadyMember;

  bool get _alreadyAdded => _settled && _found!.pendingAdd && !_found!.alreadyMember;

  bool get _needsLearningRole =>
      widget.viewer.givesLearningRoles && TeamViewer.memberNeedsLearningRole(_role, _learningRoles);

  bool get _canSend => _typed.isNotEmpty && !_sending && !_alreadyMember && !_alreadyAdded && !_needsLearningRole;

  Future<void> _send() async {
    if (!_canSend) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final branchId = _office.id.isEmpty ? null : _office.id;
    final person = _person;
    final failure = _addsDirectly && person != null
        ? await widget.sendAdd(person, _role, branchId, _learningRoles)
        : await widget.sendInvite(_email.text.trim(), _role, branchId, _learningRoles);
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    // The address and choices stay as typed.
    setState(() {
      _sending = false;
      _error = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewer = widget.viewer;
    final found = _settled ? _found : null;
    final person = _person;
    return EditSheet(
      title: 'Invite a team member',
      saveLabel: _sending
          ? (_addsDirectly ? TeamWords.asking : TeamWords.sending)
          : (_addsDirectly ? TeamWords.askToJoin : TeamWords.sendInvite),
      saving: _sending,
      error: _error,
      dirty: _email.text.trim().isNotEmpty,
      onSave: _canSend ? _send : null,
      children: [
        AccountField(
          label: TeamWords.email,
          controller: _email,
          fieldKey: const Key('invite.email'),
          keyboardType: TextInputType.emailAddress,
          textCapitalization: TextCapitalization.none,
          onChanged: _changed,
        ),
        if (_checking)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(TeamWords.checking, key: const Key('invite.checking'), style: AccountText.meta),
          ),
        if (found != null) ...[
          if (found.alreadyMember)
            const _Note(TeamWords.alreadyOnTeam, key: Key('invite.alreadyMember'))
          else if (person != null)
            Container(
              key: const Key('invite.person'),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(10)),
              child: _PersonLine(
                person: person,
                trailing: const AccountChip(
                  label: TeamWords.onIcr,
                  color: AppColors.emerald50,
                  ink: AppColors.emerald700,
                ),
              ),
            )
          else if (found.onIcr)
            const _Note(TeamWords.onIcrInvite, key: Key('invite.onIcr'))
          else
            const _Note(TeamWords.notOnIcr, key: Key('invite.notOnIcr')),
          if (_alreadyAdded) const _Note(TeamWords.pendingAdd, warn: true, key: Key('invite.alreadyAdded')),
          if (_addsDirectly && !_alreadyAdded) const _Note(TeamWords.addsPending, key: Key('invite.addsPending')),
          if (found.pendingInvite && !found.alreadyMember)
            const _Note(TeamWords.pendingInvite, warn: true, key: Key('invite.pendingInvite')),
          if (person != null && _role == 'COMPANY_ADMIN')
            const _Note(TeamWords.adminNeedsInvite, key: Key('invite.adminNeedsInvite')),
        ],
        if (!viewer.isSupplier)
          RoleSelect(
            key: const Key('invite.role'),
            label: TeamWords.role,
            role: _role,
            roles: viewer.inviteRoles,
            labelOf: inviteRoleLabel,
            onPicked: (v) => setState(() => _role = v),
          )
        else
          const _Note(TeamWords.joinSupplier),
        if (viewer.givesLearningRoles)
          LearningRolesField(
            key: const Key('invite.learningRoles'),
            value: _learningRoles,
            onChanged: (v) => setState(() => _learningRoles = v),
            error: _needsLearningRole ? TeamWords.pickALearningRole : null,
          ),
        if (viewer.picksOffice(_role) && widget.offices.isNotEmpty)
          OfficeSelect(
            key: const Key('invite.office'),
            label: TeamWords.officeOptional,
            office: _office,
            offices: widget.offices,
            helper: TeamWords.officeOptionalHelp,
            onPicked: (v) => setState(() => _office = v),
          ),
        if (viewer.isBranchAdmin) Text(TeamWords.joinYourOffice, style: AccountText.meta),
      ],
    );
  }
}
