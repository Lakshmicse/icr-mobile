import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/buttons.dart';
import '../../account/account_rules.dart' show phoneError, normalizePhone;
import '../course_sheet_controller.dart';
import '../learning_models.dart';
import '../learning_styles.dart';

/// "Get the brochure": the lead form a member fills before a course's brochure is handed over (the owner's
/// rule of 30 Oct 2026, after the reference sites' "Send brochure" forms). Name, email and phone are asked —
/// prefilled from the account — and the company is optional. Two ways out: **View brochure** reads the PDF in
/// the app, **Download** hands it to the phone. Either sends the lead first; a refusal is shown in the API's words
/// and nothing opens. Returns what the member chose, or null when they closed the sheet.
Future<BrochureIntent?> showBrochureSheet(BuildContext context, CourseSheetController controller) {
  return showModalBottomSheet<BrochureIntent>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => BrochureForm(controller: controller),
  );
}

class BrochureForm extends StatefulWidget {
  const BrochureForm({super.key, required this.controller});

  final CourseSheetController controller;

  @override
  State<BrochureForm> createState() => _BrochureFormState();
}

class _BrochureFormState extends State<BrochureForm> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _company = TextEditingController();
  String? _problem;
  BrochureIntent? _sending;
  bool _prefilled = false;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  /// Fills the form from the account. The read is a convenience: one that fails or dawdles (2 Nov 2026, the
  /// owner's phone: "the form is not opening" — the buttons waited on it for good) leaves the fields blank for
  /// the person to type, and the buttons live either way.
  Future<void> _prefill() async {
    BrochureLead lead;
    try {
      lead =
          widget.controller.brochureLead ??
          await widget.controller.repository.brochureContact().timeout(const Duration(seconds: 6));
    } on Object {
      lead = const BrochureLead(name: '', email: '', phone: '');
    }
    if (!mounted) return;
    setState(() {
      if (lead.name.isNotEmpty) _name.text = lead.name;
      if (lead.email.isNotEmpty) _email.text = lead.email;
      if (lead.phone.isNotEmpty) _phone.text = lead.phone;
      if (lead.company.isNotEmpty) _company.text = lead.company;
      _prefilled = true;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _company.dispose();
    super.dispose();
  }

  BrochureLead get _lead => BrochureLead(
    name: _name.text.trim(),
    email: _email.text.trim(),
    phone: normalizePhone(_phone.text) ?? _phone.text.trim(),
    company: _company.text.trim(),
  );

  /// Why the form cannot be sent yet, in one sentence; null when it can.
  static String? problemOf(BrochureLead lead, String rawPhone) {
    if (lead.name.length < 2) return 'Your name, please.';
    final at = lead.email.indexOf('@');
    if (at < 1 || !lead.email.substring(at).contains('.') || lead.email.endsWith('.')) {
      return 'Enter the email address the brochure goes to.';
    }
    if (rawPhone.trim().isEmpty) return 'Your phone number, so the institute can call you back.';
    return phoneError(rawPhone);
  }

  Future<void> _submit(BrochureIntent intent) async {
    final lead = _lead;
    final problem = problemOf(lead, _phone.text);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    setState(() {
      _sending = intent;
      _problem = null;
    });
    final refusal = await widget.controller.sendBrochureLead(lead, intent: intent);
    if (!mounted) return;
    if (refusal != null) {
      setState(() {
        _sending = null;
        _problem = refusal;
      });
      return;
    }
    Navigator.pop(context, intent);
  }

  Widget _field(String label, TextEditingController c, String key, {String? hint, TextInputType? type}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: LearningText.formLabel),
        const SizedBox(height: 4),
        TextField(
          key: ValueKey(key),
          controller: c,
          keyboardType: type,
          textInputAction: TextInputAction.next,
          style: LearningText.formInput,
          decoration: InputDecoration(hintText: hint, isDense: true, border: const OutlineInputBorder()),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final course = widget.controller.course;
    final busy = _sending != null;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            key: const ValueKey('brochure-form'),
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Get the brochure', style: LearningText.formTitle),
              const SizedBox(height: 4),
              Text(
                '${course.title}. Tell us who you are and the brochure is yours to read here or keep on your phone.',
                style: LearningText.formHelp,
              ),
              const SizedBox(height: 16),
              _field('Your name', _name, 'brochure-name', type: TextInputType.name),
              _field('Email', _email, 'brochure-email', type: TextInputType.emailAddress),
              _field('Phone', _phone, 'brochure-phone', hint: '+91 98765 43210', type: TextInputType.phone),
              _field('Company (optional)', _company, 'brochure-company', type: TextInputType.text),
              if (_problem != null) ...[
                Text(
                  _problem!,
                  key: const ValueKey('brochure-problem'),
                  style: LearningText.formHelp.copyWith(color: AppColors.error),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 4),
              PrimaryButton(
                key: const ValueKey('brochure-view'),
                label: _sending == BrochureIntent.view ? 'Opening…' : 'View brochure',
                icon: LucideIcons.bookOpen,
                onPressed: busy || !_prefilled ? null : () => _submit(BrochureIntent.view),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  key: const ValueKey('brochure-download'),
                  onPressed: busy || !_prefilled ? null : () => _submit(BrochureIntent.download),
                  icon: const Icon(LucideIcons.download, size: 16),
                  label: Text(_sending == BrochureIntent.download ? 'Sending…' : 'Download instead'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
