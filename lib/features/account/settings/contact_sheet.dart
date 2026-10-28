import 'package:flutter/material.dart';

import '../../../core/api/api_error.dart';
import '../account_models.dart';
import '../account_rules.dart';
import '../phone/phone_field.dart';
import '../profile/profile_controller.dart';
import '../widgets/account_kit.dart';

/// Contact info: the work email, a second number and the five links, saved
/// together the way the website's Contact info dialog does. The sign-in email
/// and the main mobile number are not here: the email is the login, and the
/// number is confirmed in its own sheet. True when something was saved.
Future<bool> showContactSheet(BuildContext context, MyProfileController controller) async =>
    await showEditSheet<bool>(context, builder: (_) => ContactSheet(controller: controller)) ?? false;

class ContactSheet extends StatefulWidget {
  const ContactSheet({super.key, required this.controller});

  final MyProfileController controller;

  @override
  State<ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends State<ContactSheet> {
  late final MyProfile _me = widget.controller.profile.value!;
  late final ProfileLinks? _links = widget.controller.links.value;
  late final _email = TextEditingController(text: _me.email);
  late final _workEmail = TextEditingController(text: _me.workEmail ?? '');
  late String _altPhone = _me.altPhone ?? '';
  late final Map<String, TextEditingController> _link = {
    for (final key in ProfileLinks.labels.keys) key: TextEditingController(text: _links?.toMap()[key] ?? ''),
  };
  late final String _initial = _snapshot();
  bool _saving = false;
  bool _tried = false;
  String? _error;

  String _snapshot() => [_workEmail.text, _altPhone, for (final c in _link.values) c.text].join('\u0001');

  @override
  void dispose() {
    _email.dispose();
    _workEmail.dispose();
    for (final c in _link.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// A link is judged as the API judges it: LinkedIn must be on LinkedIn only
  /// when it is being changed.
  Map<String, String> get _linkProblems {
    final out = <String, String>{};
    for (final e in _link.entries) {
      final changed = e.value.text.trim() != (_links?.toMap()[e.key] ?? '');
      final problem = linkError(e.key, e.value.text, changed: changed);
      if (problem != null) out[e.key] = problem;
    }
    return out;
  }

  String? get _emailProblem => workEmailError(_workEmail.text);
  String? get _altProblem => altPhoneError(_altPhone);

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _tried = true);
    if (_emailProblem != null || _altProblem != null || _linkProblems.isNotEmpty) return;
    if (_snapshot() == _initial) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final linksChanged = _links != null && _link.entries.any((e) => normalizeLink(e.value.text) != (_links.toMap()[e.key] ?? ''));
      await widget.controller.saveContact(
        workEmail: _workEmail.text,
        altPhone: _altPhone,
        // Every link goes with the save; a blank one clears it. Without the links read, they stay out of it.
        changedLinks: linksChanged ? {for (final e in _link.entries) e.key: normalizeLink(e.value.text)} : null,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lp = _linkProblems;
    final showAll = _tried;
    return EditSheet(
      title: 'Contact info',
      saving: _saving,
      error: _error,
      dirty: _snapshot() != _initial,
      onSave: _save,
      children: [
        AccountField(
          fieldKey: const Key('contact.email'),
          label: 'Email',
          controller: _email,
          enabled: false,
          helper: 'Your sign-in. Contact support to change it.',
        ),
        AccountField(
          fieldKey: const Key('contact.workEmail'),
          label: 'Work email',
          controller: _workEmail,
          keyboardType: TextInputType.emailAddress,
          textCapitalization: TextCapitalization.none,
          maxLength: 255,
          error: showAll || _workEmail.text.isNotEmpty ? _emailProblem : null,
          helper: 'Optional. Different from your sign-in email.',
          onChanged: (_) => setState(() {}),
        ),
        AccountPhoneField(
          fieldKey: const Key('contact.altPhone'),
          countryKey: const Key('contact.altPhone.country'),
          label: 'Alternative contact number',
          value: _altPhone,
          error: _altProblem,
          helper: 'Optional. A second number; your main one is confirmed separately.',
          onChanged: (v) => setState(() => _altPhone = v),
        ),
        const Divider(height: 24, color: Color(0xFFF1F5F9)),
        Text('Links', style: AccountText.cardTitle),
        const SizedBox(height: 2),
        Text('Optional. Paste the address as it appears in your browser.', style: AccountText.meta),
        const SizedBox(height: 12),
        for (final e in ProfileLinks.labels.entries)
          AccountField(
            fieldKey: Key('contact.${e.key}'),
            label: e.value,
            controller: _link[e.key]!,
            keyboardType: TextInputType.url,
            textCapitalization: TextCapitalization.none,
            hint: linkExamples[e.key],
            maxLength: 500,
            error: showAll || _link[e.key]!.text.trim().isNotEmpty ? lp[e.key] : null,
            onChanged: (_) => setState(() {}),
          ),
      ],
    );
  }
}
