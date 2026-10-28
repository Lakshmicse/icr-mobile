import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/util/links.dart';
import '../../../core/widgets/buttons.dart';
import '../course_sheet_controller.dart';
import '../learning_models.dart';
import '../learning_styles.dart';

/// Writes to the institute that awards the course, in one of three guises
/// ([EnquiryKind]): a question, a date and location request, or an in-house
/// (corporate) request. The member's own name and email go with it
/// (`POST /learning/courses/:code/enquire`).
Future<void> showEnquirySheet(
  BuildContext context,
  CourseSheetController controller, {
  EnquiryKind kind = EnquiryKind.question,
}) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => EnquiryForm(controller: controller, kind: kind),
  );
  if (sent == true && context.mounted) {
    showMessage(context, 'Sent to ${controller.course.provider?.name ?? 'the institute'}. They will reply by email.');
  }
}

/// What the form says and prefixes for each kind of enquiry.
class EnquiryWords {
  const EnquiryWords({required this.title, required this.help, required this.label, required this.hint, this.prefix});

  final String Function(String institute) title;
  final String Function(String course, String institute) help;
  final String label;
  final String hint;

  /// Opening words of the message, so the institute sees what it is.
  final String? prefix;

  static EnquiryWords of(EnquiryKind kind) => switch (kind) {
    EnquiryKind.question => EnquiryWords(
      title: (i) => 'Ask $i',
      help: (c, i) => 'About $c. Your name and email go with the message.',
      label: 'Your question',
      hint: 'Dates, fees, what the course covers…',
    ),
    EnquiryKind.dateRequest => EnquiryWords(
      title: (_) => 'Suggest a date & location',
      help: (c, i) => 'Tell $i where and when you would like $c to run. Your name and email go with the message.',
      label: 'Where and when',
      hint: 'The city and month that suit you…',
      prefix: 'Date and location request: ',
    ),
    EnquiryKind.inHouse => EnquiryWords(
      title: (_) => 'Take this course in-house',
      help: (c, i) => 'Ask $i to deliver $c for your team. Your name and email go with the message.',
      label: 'What you need',
      hint: 'Where, when and what you want covered…',
      prefix: 'In-house delivery request: ',
    ),
  };
}

class EnquiryForm extends StatefulWidget {
  const EnquiryForm({super.key, required this.controller, this.kind = EnquiryKind.question});

  final CourseSheetController controller;
  final EnquiryKind kind;

  @override
  State<EnquiryForm> createState() => _EnquiryFormState();
}

class _EnquiryFormState extends State<EnquiryForm> {
  final _message = TextEditingController();
  final _company = TextEditingController();
  final _headcount = TextEditingController();
  String? _problem;
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    _company.dispose();
    _headcount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final words = EnquiryWords.of(widget.kind);
    if (_message.text.trim().length < 10) {
      setState(() => _problem = 'Say a little more about what you would like to know.');
      return;
    }
    final headcount = int.tryParse(_headcount.text.trim());
    if (widget.kind == EnquiryKind.inHouse && _headcount.text.trim().isNotEmpty && (headcount ?? 0) < 1) {
      setState(() => _problem = 'How many people? A whole number from 1.');
      return;
    }
    setState(() {
      _sending = true;
      _problem = null;
    });
    final message = await widget.controller.enquire(
      '${words.prefix ?? ''}${_message.text.trim()}',
      kind: widget.kind,
      company: _company.text,
      headcount: headcount,
    );
    if (!mounted) return;
    if (message != null) {
      setState(() {
        _sending = false;
        _problem = message;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.controller.course;
    final institute = course.provider?.name ?? 'the institute';
    final words = EnquiryWords.of(widget.kind);
    final inHouse = widget.kind == EnquiryKind.inHouse;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(words.title(institute), style: LearningText.formTitle),
              const SizedBox(height: 4),
              Text(words.help(course.title, institute), style: LearningText.formHelp),
              const SizedBox(height: 16),
              if (inHouse) ...[
                Text('Your company (optional)', style: LearningText.formLabel),
                const SizedBox(height: 4),
                TextField(
                  key: const ValueKey('enquiry-company'),
                  controller: _company,
                  maxLength: 160,
                  style: LearningText.formInput,
                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), counterText: ''),
                ),
                const SizedBox(height: 12),
                Text('People to train (optional)', style: LearningText.formLabel),
                const SizedBox(height: 4),
                TextField(
                  key: const ValueKey('enquiry-headcount'),
                  controller: _headcount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                  style: LearningText.formInput,
                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
              ],
              Text(words.label, style: LearningText.formLabel),
              const SizedBox(height: 4),
              TextField(
                key: const ValueKey('enquiry-message'),
                controller: _message,
                minLines: 3,
                maxLines: 6,
                maxLength: 3900,
                style: LearningText.formInput,
                decoration: InputDecoration(hintText: words.hint, isDense: true, border: const OutlineInputBorder()),
              ),
              if (_problem != null) ...[
                const SizedBox(height: 8),
                Text(_problem!, style: LearningText.formHelp.copyWith(color: AppColors.error)),
              ],
              const SizedBox(height: 16),
              PrimaryButton(
                key: const ValueKey('enquiry-send'),
                label: _sending ? 'Sending…' : 'Send',
                icon: LucideIcons.send,
                onPressed: _sending ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
