import 'package:flutter/material.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../account_models.dart';
import '../../account_rules.dart';
import '../../widgets/account_kit.dart';
import '../../widgets/photo_picker.dart';
import '../profile_controller.dart';
import '../profile_fields.dart';

/// Adds a certificate or licence, or edits an external [credential] (and can
/// delete it). The ones ICR issued are read-only and open their certificate.
/// True when something was saved.
Future<bool> showCredentialSheet(
  BuildContext context,
  MyProfileController controller, {
  Credential? credential,
  PhotoPicker pickEvidence = pickEvidenceFromDevice,
}) async =>
    await showEditSheet<bool>(
      context,
      builder: (_) => CredentialSheet(controller: controller, credential: credential, pickEvidence: pickEvidence),
    ) ??
    false;

class CredentialSheet extends StatefulWidget {
  const CredentialSheet({super.key, required this.controller, this.credential, required this.pickEvidence, this.now});

  final MyProfileController controller;
  final Credential? credential;
  final PhotoPicker pickEvidence;
  final DateTime? now;

  @override
  State<CredentialSheet> createState() => _CredentialSheetState();
}

class _CredentialSheetState extends State<CredentialSheet> {
  late final Credential? _c = widget.credential;
  late final _name = TextEditingController(text: _c?.name ?? '');
  late final _code = TextEditingController(text: _c?.code ?? '');
  late final _issuer = TextEditingController(text: _c?.issuer ?? '');
  late final _url = TextEditingController(text: _c?.credentialUrl ?? '');
  late DateTime? _issued = _day(_c?.issuedAt);
  late DateTime? _expires = _day(_c?.expiresAt);
  late String? _fileUrl = _c?.fileUrl;
  late String? _fileName = _c?.fileName;
  late final String _initial = _snapshot();
  bool _saving = false;
  bool _uploading = false;
  bool _tried = false;
  String? _error;

  static DateTime? _day(String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso);
    return d == null ? null : DateTime(d.toUtc().year, d.toUtc().month, d.toUtc().day);
  }

  String _snapshot() => [_name.text, _code.text, _issuer.text, _url.text, _issued, _expires, _fileUrl].join('\u0001');

  @override
  void dispose() {
    for (final c in [_name, _code, _issuer, _url]) {
      c.dispose();
    }
    super.dispose();
  }

  CredentialDraft _draft() => CredentialDraft(
    name: _name.text,
    code: _code.text.trim().toUpperCase(),
    issuer: _issuer.text,
    issuedOn: _issued,
    expiresOn: _expires,
    credentialUrl: _url.text,
    fileUrl: _fileUrl,
    fileName: _fileName,
  );

  Future<void> _attach() async {
    if (_uploading || _saving) return;
    final PickedPhoto? file;
    try {
      file = await widget.pickEvidence();
    } catch (_) {
      setState(() => _error = "Couldn't open your files. Check that ICR may read them and try again.");
      return;
    }
    if (file == null || !mounted) return;
    final problem = photoProblem(file, max: maxEvidenceBytes);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final up = await widget.controller.uploadEvidence(file);
      if (mounted) {
        setState(() {
          _fileUrl = up.url;
          _fileName = up.name;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _uploading) return;
    setState(() => _tried = true);
    if (credentialProblems(_draft(), now: widget.now).isNotEmpty) return;
    if (_c != null && _snapshot() == _initial) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final existing = _c;
      if (existing == null) {
        await widget.controller.addCredential(_draft());
      } else {
        await widget.controller.updateCredential(existing.id, _draft());
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final credential = _c!;
    final ok = await confirmAction(
      context,
      title: 'Delete this credential?',
      message: '${credential.name} will be taken off your profile. Its certificate is deleted with it.',
      confirm: 'Delete',
    );
    if (!ok || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final alsoMentor = await widget.controller.deleteCredential(credential.id);
      if (!mounted) return;
      if (alsoMentor != null) {
        setState(() => _saving = false);
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Removed from your mentor profile', style: AccountText.cardTitle),
            content: Text('$alsoMentor was also taken off your mentor profile, since it is no longer on your credentials.', style: AccountText.body),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
          ),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _tried ? credentialProblems(_draft(), now: widget.now) : const <String, String>{};
    final today = DateTime.now();
    return EditSheet(
      title: _c == null ? 'Add credential' : 'Edit credential',
      subtitle: 'A certificate or licence you hold. ICR’s own are added for you.',
      saving: _saving,
      error: _error,
      dirty: _snapshot() != _initial,
      onSave: _save,
      onDelete: _c == null ? null : _delete,
      children: [
        AccountField(
          fieldKey: const Key('cred.name'),
          label: 'Name',
          controller: _name,
          required: true,
          maxLength: 160,
          hint: 'e.g. Certified Facility Manager',
          error: p['name'],
          onChanged: (_) => setState(() {}),
        ),
        AccountField(
          fieldKey: const Key('cred.code'),
          label: 'Short code',
          controller: _code,
          maxLength: 32,
          hint: 'e.g. CFM',
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) => setState(() {}),
        ),
        AccountField(
          fieldKey: const Key('cred.issuer'),
          label: 'Issued by',
          controller: _issuer,
          maxLength: 160,
          hint: 'e.g. IFMA',
          onChanged: (_) => setState(() {}),
        ),
        DateSelectField(
          fieldKey: const Key('cred.issued'),
          label: 'Issue date',
          value: _issued,
          last: today,
          error: p['issuedOn'],
          onChanged: (d) => setState(() => _issued = d),
        ),
        DateSelectField(
          fieldKey: const Key('cred.expires'),
          label: 'Expiry date',
          value: _expires,
          error: p['expiresOn'],
          helper: 'Leave blank if it does not expire.',
          onChanged: (d) => setState(() => _expires = d),
        ),
        AccountField(
          fieldKey: const Key('cred.url'),
          label: 'Verification link',
          controller: _url,
          maxLength: 500,
          keyboardType: TextInputType.url,
          textCapitalization: TextCapitalization.none,
          hint: 'https://issuer.org/verify/12345',
          error: p['credentialUrl'],
          onChanged: (_) => setState(() {}),
        ),
        Text('Certificate', style: AccountText.label),
        const SizedBox(height: 6),
        if (_fileUrl != null)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.slate50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.slate200),
            ),
            child: Row(
              children: [
                const Icon(Icons.description_outlined, color: AppColors.slate500),
                const SizedBox(width: 8),
                Expanded(child: Text(_fileName ?? 'Certificate on file', maxLines: 1, overflow: TextOverflow.ellipsis, style: AccountText.body)),
                TextButton(
                  key: const Key('cred.removeFile'),
                  onPressed: () => setState(() {
                    _fileUrl = null;
                    _fileName = null;
                  }),
                  child: const Text('Remove'),
                ),
              ],
            ),
          )
        else
          AccountButton(
            key: const Key('cred.attach'),
            label: 'Attach certificate',
            icon: Icons.attach_file_rounded,
            outlined: true,
            busy: _uploading,
            onPressed: _attach,
          ),
        const SizedBox(height: 6),
        Text('A PDF or picture, up to 10 MB. Only you and ICR’s reviewers can open it.', style: AccountText.meta),
      ],
    );
  }
}
