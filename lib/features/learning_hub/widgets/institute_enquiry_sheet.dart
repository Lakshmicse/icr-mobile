import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/util/links.dart';
import '../../../core/widgets/buttons.dart';
import '../../learning/learning_styles.dart';
import '../hub_controller.dart';
import '../hub_models.dart';

/// "Ask the institute": a message to a partner institute, sent as the member
/// (`POST /learning/providers/:slug/enquire`; their name and email go with it).
/// Tells the member it was sent, or why it was not.
Future<void> showInstituteEnquirySheet(BuildContext context, LearningHubController hub, Institute institute) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => InstituteEnquiryForm(hub: hub, institute: institute),
  );
  if (sent == true && context.mounted) {
    showMessage(context, 'Sent to ${institute.name}. They will reply by email.');
  }
}

class InstituteEnquiryForm extends StatefulWidget {
  const InstituteEnquiryForm({super.key, required this.hub, required this.institute});

  final LearningHubController hub;
  final Institute institute;

  @override
  State<InstituteEnquiryForm> createState() => _InstituteEnquiryFormState();
}

class _InstituteEnquiryFormState extends State<InstituteEnquiryForm> {
  final _message = TextEditingController();
  String? _problem;
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_message.text.trim().length < 10) {
      setState(() => _problem = 'Say a little more about what you would like to know.');
      return;
    }
    setState(() {
      _sending = true;
      _problem = null;
    });
    final problem = await widget.hub.enquireInstitute(widget.institute, _message.text.trim());
    if (!mounted) return;
    if (problem != null) {
      setState(() {
        _sending = false;
        _problem = problem;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.institute.name;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ask $name', style: LearningText.formTitle),
              const SizedBox(height: 4),
              Text(
                'About its courses, dates or fees. Your name and email go with the message.',
                style: LearningText.formHelp,
              ),
              const SizedBox(height: 16),
              Text('Your question', style: LearningText.formLabel),
              const SizedBox(height: 4),
              TextField(
                key: const ValueKey('institute-enquiry-message'),
                controller: _message,
                minLines: 3,
                maxLines: 6,
                maxLength: 3900,
                style: LearningText.formInput,
                decoration: const InputDecoration(
                  hintText: 'Dates, fees, what the courses cover…',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              if (_problem != null) ...[
                const SizedBox(height: 8),
                Text(_problem!, style: LearningText.formHelp.copyWith(color: AppColors.error)),
              ],
              const SizedBox(height: 16),
              PrimaryButton(
                key: const ValueKey('institute-enquiry-send'),
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
