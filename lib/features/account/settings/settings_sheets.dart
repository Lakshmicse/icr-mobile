import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/api/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../account_repository.dart';
import '../phone/phone_sheets.dart';
import '../widgets/account_kit.dart';

/// The languages ICR speaks that are ready: `SUPPORTED_LOCALES` of `@icr/shared`
/// with how each names itself. English is the default and is saved as none.
const accountLanguages = <(String, String, String)>[
  ('en', 'English', 'English'),
  ('hi', 'हिन्दी', 'Hindi'),
  ('kn', 'ಕನ್ನಡ', 'Kannada'),
];

String languageName(String? code) {
  for (final (c, native, _) in accountLanguages) {
    if (c == (code ?? 'en')) return native;
  }
  return code ?? 'English';
}

// --- language ------------------------------------------------------------------------------------------------

/// Chooses the language of ICR's emails, notifications and replies, saved on
/// the account (`PATCH /users/me {locale}`). The app's own screens are in
/// English for now, and the sheet says so. Returns the code saved, or null.
Future<String?> showLanguageSheet(BuildContext context, {required AccountRepository repository, required String? current}) =>
    showEditSheet<String>(context, builder: (_) => _LanguageSheet(repository: repository, current: current ?? 'en'));

class _LanguageSheet extends StatefulWidget {
  const _LanguageSheet({required this.repository, required this.current});

  final AccountRepository repository;
  final String current;

  @override
  State<_LanguageSheet> createState() => _LanguageSheetState();
}

class _LanguageSheetState extends State<_LanguageSheet> {
  late String _picked = widget.current;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_saving) return;
    if (_picked == widget.current) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // English is the default: saving it clears the choice, so ICR follows the phone again.
      await widget.repository.updateMe({'locale': _picked == 'en' ? null : _picked});
      if (mounted) Navigator.of(context).pop(_picked);
    } catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EditSheet(
      title: 'Language',
      subtitle: 'The language of ICR’s emails, notifications and replies. The app’s screens stay in English for now.',
      saving: _saving,
      error: _error,
      dirty: _picked != widget.current,
      onSave: _save,
      children: [
        RadioGroup<String>(
          groupValue: _picked,
          onChanged: (v) => setState(() => _picked = v ?? _picked),
          child: Column(
            children: [
              for (final (code, native, english) in accountLanguages)
                RadioListTile<String>(
                  key: Key('language.$code'),
                  value: code,
                  title: Text(native, style: AccountText.itemTitle),
                  subtitle: native == english ? null : Text(english, style: AccountText.meta),
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.primary,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- download my data ----------------------------------------------------------------------------------------

/// "Download my data": reads what ICR holds for the account (`GET /users/me/export`)
/// and offers it to copy or share as JSON.
Future<void> showExportSheet(BuildContext context, {required AccountRepository repository, required Future<void> Function(String text, String subject) share}) =>
    showEditSheet<void>(context, builder: (_) => _ExportSheet(repository: repository, share: share));

class _ExportSheet extends StatefulWidget {
  const _ExportSheet({required this.repository, required this.share});

  final AccountRepository repository;
  final Future<void> Function(String text, String subject) share;

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  String? _json;
  bool _busy = false;
  String? _error;

  Future<void> _read() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await widget.repository.exportData();
      if (mounted) setState(() => _json = const JsonEncoder.withIndent('  ').convert(data));
    } catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final json = _json;
    return EditSheet(
      title: 'Download my data',
      subtitle: 'The personal data ICR holds for your account, as a file you can keep.',
      saveLabel: 'Done',
      onSave: () => Navigator.of(context).pop(),
      error: _error,
      children: [
        if (json == null)
          AccountButton(
            key: const Key('export.read'),
            label: 'Get my data',
            icon: Icons.download_rounded,
            busy: _busy,
            onPressed: _read,
          )
        else ...[
          Container(
            key: const Key('export.preview'),
            height: 180,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.slate50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.slate200),
            ),
            child: SingleChildScrollView(child: Text(json, style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: AppColors.slate700))),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AccountButton(
                  key: const Key('export.copy'),
                  label: 'Copy',
                  icon: Icons.copy_rounded,
                  outlined: true,
                  onPressed: () => copyWithNotice(context, json, 'Your data was copied.'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AccountButton(
                  key: const Key('export.share'),
                  label: 'Share',
                  icon: Icons.ios_share_rounded,
                  onPressed: () => widget.share(json, 'My ICR data'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// --- delete my account ---------------------------------------------------------------------------------------

/// "Delete my account": says what happens, asks for the word DELETE, then
/// `DELETE /users/me`, which anonymises and closes the account and ends every
/// session. True when it was done (the caller signs the phone out).
Future<bool> showDeleteAccountSheet(BuildContext context, {required AccountRepository repository}) async =>
    await showEditSheet<bool>(context, builder: (_) => _DeleteSheet(repository: repository)) ?? false;

class _DeleteSheet extends StatefulWidget {
  const _DeleteSheet({required this.repository});

  final AccountRepository repository;

  @override
  State<_DeleteSheet> createState() => _DeleteSheetState();
}

class _DeleteSheetState extends State<_DeleteSheet> {
  final _word = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _word.dispose();
    super.dispose();
  }

  bool get _ready => _word.text.trim().toUpperCase() == 'DELETE';

  Future<void> _delete() async {
    if (_busy || !_ready) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.deleteAccount();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EditSheet(
      title: 'Delete my account',
      saving: _busy,
      error: _error,
      saveLabel: 'Delete my account',
      danger: true,
      onSave: _ready ? _delete : null,
      children: [
        Text(
          'This removes your name, photo, phone number and what you told ICR about your career, closes your account and signs you out everywhere. '
          'What you posted for others (discussions, reviews) stays, without your name. It cannot be undone.',
          style: AccountText.body,
        ),
        const SizedBox(height: 16),
        AccountField(
          fieldKey: const Key('delete.word'),
          label: 'Type DELETE to confirm',
          controller: _word,
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }
}
