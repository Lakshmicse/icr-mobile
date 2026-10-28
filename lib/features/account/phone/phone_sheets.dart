import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../account_repository.dart';
import '../account_rules.dart';
import '../widgets/account_kit.dart';
import 'phone_field.dart';

/// "Test mode: your code is 123456  Use code": what a non-production API's
/// answer shows under the code field, since it sends nothing (the website's
/// `DevCodeNote`).
class TestCodeNote extends StatelessWidget {
  const TestCodeNote({super.key, required this.code, required this.onUse});

  final String? code;
  final ValueChanged<String> onUse;

  @override
  Widget build(BuildContext context) {
    final value = code;
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    final style = AccountText.meta.copyWith(color: const Color(0xFFB45309));
    return Padding(
      key: const Key('testCode'),
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Flexible(
            child: Text.rich(
              TextSpan(
                style: style,
                children: [
                  const TextSpan(text: 'Test mode: your code is '),
                  TextSpan(text: value, style: style.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.6)),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
          TextButton(
            key: const Key('testCode.use'),
            onPressed: () => onUse(value),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: Text('Use code', style: AccountText.link.copyWith(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

/// A 6-digit code box under a field.
class CodeField extends StatelessWidget {
  const CodeField({
    super.key,
    required this.controller,
    this.error,
    this.helper,
    this.label = '6-digit code',
    this.fieldKey,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? error;
  final String? helper;
  final String label;
  final Key? fieldKey;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => AccountField(
    fieldKey: fieldKey,
    label: label,
    controller: controller,
    keyboardType: TextInputType.number,
    maxLength: 6,
    error: error,
    helper: helper,
    onChanged: onChanged,
    textCapitalization: TextCapitalization.none,
  );
}

/// Adds, confirms or removes the person's mobile number (the website's
/// `PhoneVerifyInline` inside Contact info):
///
/// * a number a code can reach (+91) is confirmed: **Send code**, then the six
///   digits, then **Verify**. A non-production API hands the code back and it
///   is shown ("Test mode: your code is …", **Use code**);
/// * any other country's number is kept as typed with **Save number**; no
///   "Not verified" mark is drawn for a number no code can reach;
/// * **Remove number** clears it.
///
/// Returns true when the number on the account changed.
Future<bool> showPhoneSheet(
  BuildContext context, {
  required AccountRepository repository,
  String? phone,
  bool verified = false,
}) async {
  final changed = await showEditSheet<bool>(
    context,
    builder: (_) => _PhoneSheet(repository: repository, phone: phone, verified: verified),
  );
  return changed ?? false;
}

class _PhoneSheet extends StatefulWidget {
  const _PhoneSheet({required this.repository, required this.phone, required this.verified});

  final AccountRepository repository;
  final String? phone;
  final bool verified;

  @override
  State<_PhoneSheet> createState() => _PhoneSheetState();
}

class _PhoneSheetState extends State<_PhoneSheet> {
  late String _phone = widget.phone ?? '';
  final _code = TextEditingController();
  bool _codeStep = false;
  bool _busy = false;
  String? _error;
  String? _codeError;
  String? _devCode;
  bool _shown = false;

  bool get _unchanged => samePhone(_phone, widget.phone);
  bool get _verifiedNow => widget.verified && _unchanged;
  String? get _unreadable => _phone.trim().isEmpty ? null : phoneError(_phone);
  bool get _textable => _phone.trim().isNotEmpty && _unreadable == null && canTextPhone(_phone);
  bool get _untextable => _phone.trim().isNotEmpty && _unreadable == null && !canTextPhone(_phone);

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() body) async {
    setState(() {
      _busy = true;
      _error = null;
      _codeError = null;
    });
    try {
      await body();
    } catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() => _run(() async {
    final code = await widget.repository.sendPhoneCode(normalizePhone(_phone) ?? _phone.trim());
    if (!mounted) return;
    setState(() {
      _devCode = code;
      _codeStep = true;
      _code.clear();
    });
  });

  Future<void> _verify() async {
    if (_busy) return;
    final code = _code.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _codeError = 'Enter the 6-digit code.');
      return;
    }
    await _run(() async {
      try {
        await widget.repository.verifyPhoneCode(normalizePhone(_phone) ?? _phone.trim(), code);
      } on ApiError catch (e) {
        if (mounted) setState(() => _codeError = e.message);
        return;
      }
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  Future<void> _saveWithoutCode() => _run(() async {
    await widget.repository.updateMe({'phone': _phone.trim()});
    if (mounted) Navigator.of(context).pop(true);
  });

  Future<void> _remove() async {
    final ok = await confirmAction(
      context,
      title: 'Remove your number?',
      message: 'Employers and mentors you contact will be asked for a number again.',
      confirm: 'Remove',
    );
    if (!ok || !mounted) return;
    await _run(() async {
      await widget.repository.updateMe({'phone': ''});
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final String saveLabel;
    final VoidCallback? onSave;
    if (_codeStep) {
      saveLabel = 'Verify';
      onSave = _code.text.trim().length == 6 ? _verify : null;
    } else if (_verifiedNow) {
      saveLabel = 'Verified';
      onSave = null;
    } else if (_untextable) {
      saveLabel = 'Save number';
      onSave = _saveWithoutCode;
    } else {
      saveLabel = 'Send code';
      onSave = _textable ? _send : null;
    }
    return EditSheet(
      title: 'Mobile number',
      subtitle: 'Employers, mentors and suppliers you contact on ICR use it to reach you.',
      saving: _busy,
      error: _error,
      dirty: false,
      saveLabel: saveLabel,
      onSave: onSave,
      onDelete: (widget.phone != null && !_busy) ? _remove : null,
      deleteLabel: 'Remove number',
      children: [
        AccountPhoneField(
          fieldKey: const Key('phone.number'),
          countryKey: const Key('phone.country'),
          label: 'Mobile number',
          value: _phone,
          enabled: !_busy,
          error: _shown || _phone.trim().isNotEmpty ? _unreadable : null,
          helper: _verifiedNow
              ? 'This number is verified.'
              : _untextable
              ? 'We can only text codes to +91 numbers, so this one is saved as typed.'
              : phoneHelp,
          suffix: _verifiedNow
              ? const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                )
              : null,
          onChanged: (v) => setState(() {
            _shown = true;
            _phone = v;
            _codeStep = false;
            _devCode = null;
            _error = null;
          }),
        ),
        if (_codeStep) ...[
          CodeField(
            fieldKey: const Key('phone.code'),
            controller: _code,
            error: _codeError,
            helper: 'We sent a code to ${formatPhone(_phone)}.',
            onChanged: (_) => setState(() => _codeError = null),
          ),
          TestCodeNote(
            code: _devCode,
            onUse: (c) {
              _code.text = c;
              setState(() => _codeError = null);
            },
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('phone.resend'),
              onPressed: _busy ? null : _send,
              child: Text('Send a new code', style: AccountText.link),
            ),
          ),
        ],
      ],
    );
  }
}

/// A number typed into a form field, the way a form that needs one reads it.
///
/// "Mobile number" for an action that needs it (applying for a job, asking a
/// mentor, contacting a supplier) is asked **only while the profile has none**
/// (owner's call, 29 Sep 2026): the action sends it as `phone`, the API saves
/// it to the profile with the action and refuses the action when there is still
/// no number. Once saved it is never asked again.
///
/// Use [askForPhone] for a stand-alone question, or this controller with
/// [PhoneNeededField] to put the field inside the form that sends the action.
class PhoneNeededController extends ChangeNotifier {
  PhoneNeededController({required this.lookup});

  /// The number the profile holds, or null for none. Throws when it cannot be read.
  final Future<String?> Function() lookup;

  bool loaded = false;

  /// The profile has no number (or the read failed, so the question is asked:
  /// the API keeps the number on file over the one sent).
  bool needed = false;
  String phone = '';
  bool tried = false;

  /// The number on file, when there is one.
  String? onFile;

  Future<void> load() async {
    try {
      onFile = await lookup();
      needed = onFile == null || onFile!.trim().isEmpty;
    } catch (_) {
      onFile = null;
      needed = true;
    }
    loaded = true;
    notifyListeners();
  }

  void setPhone(String value) {
    phone = value;
    notifyListeners();
  }

  /// The sentence under the field, or null when it is fine (or not asked).
  String? get error {
    if (!needed) return null;
    if (phone.trim().isEmpty) return 'Add your mobile number.';
    return phoneError(phone);
  }

  /// True when the action may go ahead; shows the field's problem otherwise.
  bool check() {
    tried = true;
    notifyListeners();
    return error == null;
  }

  bool get showError => tried || phone.trim().isNotEmpty;

  /// What to send with the action: the typed number, only while one is needed.
  Map<String, String> get payload => needed && phone.trim().isNotEmpty ? {'phone': phone.trim()} : const {};
}

/// The field a form shows while the profile has no number. Draws nothing
/// otherwise. [reason] says who needs it: "So the employer can call you."
class PhoneNeededField extends StatelessWidget {
  const PhoneNeededField({super.key, required this.controller, required this.reason, this.enabled = true});

  final PhoneNeededController controller;
  final String reason;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.needed) return const SizedBox.shrink();
        return AccountPhoneField(
          fieldKey: const Key('phoneNeeded.number'),
          countryKey: const Key('phoneNeeded.country'),
          label: 'Mobile number',
          required: true,
          value: controller.phone,
          enabled: enabled,
          error: controller.showError ? controller.error : null,
          helper: '$reason $phoneHelp',
          onChanged: controller.setPhone,
        );
      },
    );
  }
}

/// Asks for the mobile number an action needs, in a sheet, **only while the
/// profile has none**. Returns:
///
/// * `''` when the profile already has a number: send nothing, the API uses it;
/// * the number the person typed, to send with the action as `phone` (the API
///   saves it to their profile with the action);
/// * `null` when they backed out: do not run the action.
///
///     final phone = await askForPhone(context, repository: repo, reason: 'So the employer can call you.');
///     if (phone == null) return;
///     await api.post('/jobs/$id/apply', data: {..., if (phone.isNotEmpty) 'phone': phone});
Future<String?> askForPhone(
  BuildContext context, {
  required AccountRepository repository,
  required String reason,
  String title = 'Add your mobile number',
  String actionLabel = 'Continue',
}) async {
  final controller = PhoneNeededController(lookup: () async => (await repository.myProfile()).phone);
  await controller.load();
  if (!controller.needed) return '';
  if (!context.mounted) return null;
  final result = await showEditSheet<String>(
    context,
    builder: (_) => _AskForPhoneSheet(controller: controller, reason: reason, title: title, actionLabel: actionLabel),
  );
  return result;
}

class _AskForPhoneSheet extends StatefulWidget {
  const _AskForPhoneSheet({required this.controller, required this.reason, required this.title, required this.actionLabel});

  final PhoneNeededController controller;
  final String reason;
  final String title;
  final String actionLabel;

  @override
  State<_AskForPhoneSheet> createState() => _AskForPhoneSheetState();
}

class _AskForPhoneSheetState extends State<_AskForPhoneSheet> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => EditSheet(
        title: widget.title,
        subtitle: widget.reason,
        saveLabel: widget.actionLabel,
        dirty: widget.controller.phone.trim().isNotEmpty,
        onSave: () {
          if (!widget.controller.check()) return;
          Navigator.of(context).pop(widget.controller.phone.trim());
        },
        children: [PhoneNeededField(controller: widget.controller, reason: 'It is saved to your profile.')],
      ),
    );
  }
}

/// Copies [text] and says so (a snackbar), for links and codes.
Future<void> copyWithNotice(BuildContext context, String text, String notice) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(notice)));
}
