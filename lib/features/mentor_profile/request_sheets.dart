import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import '../../core/widgets/buttons.dart';
import 'mentor_profile_controller.dart';
import 'mentor_profile_format.dart';
import 'mentor_profile_models.dart';
import 'mentor_profile_styles.dart';

/// The limits the API enforces on these forms (`SERVICE_REQUEST_LIMITS`,
/// `CreateMentorshipRequestDto`), so a form refuses before the round trip.
const _minTopic = 20;
const _maxTopic = 1000;
const _minMessage = 30;
const _maxMessage = 2000;

/// The free mentoring request: a message to the mentor (`POST /mentorship/requests`).
/// Resolves true when it was sent.
Future<bool> showMentoringRequestSheet(BuildContext context, MentorProfileController controller) async {
  final needsPhone = await controller.needsPhone();
  if (!context.mounted) return false;
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => _MentoringRequestForm(controller: controller, needsPhone: needsPhone),
  );
  if (sent == true && context.mounted) {
    showMessage(
      context,
      'Request sent to ${controller.profile?.firstName ?? 'the mentor'}. They reply within a few days.',
    );
  }
  return sent == true;
}

/// A request for one 1:1 session; the mentor sets the time on accepting
/// (`POST /mentor-services/:id/request`). Resolves true when it was sent.
Future<bool> showSessionRequestSheet(
  BuildContext context,
  MentorProfileController controller,
  MentorOffering offering,
) async {
  final needsPhone = await controller.needsPhone();
  if (!context.mounted) return false;
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => _SessionRequestForm(controller: controller, offering: offering, needsPhone: needsPhone),
  );
  if (sent == true && context.mounted) {
    final name = controller.profile?.firstName ?? 'the mentor';
    showMessage(
      context,
      offering.free
          ? 'Request sent to $name. They set the time when they accept.'
          : 'Request sent to $name. You pay once they accept and set the time.',
    );
  }
  return sent == true;
}

/// Asks for the member's mobile number, which a plan or programme shares
/// with the mentor. Resolves the number, or null if dismissed.
Future<String?> showPhoneSheet(BuildContext context, {required String title, required String help}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => _PhoneForm(title: title, help: help),
  );
}

class _FormFrame extends StatelessWidget {
  const _FormFrame({
    required this.title,
    required this.subtitle,
    required this.children,
    required this.submitLabel,
    required this.onSubmit,
    this.problem,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final String submitLabel;
  final VoidCallback? onSubmit;
  final String? problem;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: MentorText.formTitle),
              const SizedBox(height: 4),
              Text(subtitle, style: MentorText.formHelp),
              const SizedBox(height: 16),
              ...children,
              if (problem != null) ...[
                const SizedBox(height: 8),
                Text(problem!, style: MentorText.formHelp.copyWith(color: AppColors.error)),
              ],
              const SizedBox(height: 16),
              PrimaryButton(label: submitLabel, icon: LucideIcons.send, onPressed: onSubmit),
            ],
          ),
        ),
      ),
    );
  }
}

class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child, this.help});

  final String label;
  final Widget child;
  final String? help;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: MentorText.formLabel),
        const SizedBox(height: 4),
        child,
        if (help != null) ...[const SizedBox(height: 4), Text(help!, style: MentorText.formHelp)],
        const SizedBox(height: 14),
      ],
    );
  }
}

InputDecoration _decoration(String hint) =>
    InputDecoration(hintText: hint, isDense: true, border: const OutlineInputBorder());

class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _Labelled(
      label: 'Mobile number',
      help: 'The mentor needs a way to reach you. It is saved to your profile.',
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.phone,
        style: MentorText.formInput,
        decoration: _decoration('+91 98765 43210'),
      ),
    );
  }
}

class _MentoringRequestForm extends StatefulWidget {
  const _MentoringRequestForm({required this.controller, required this.needsPhone});

  final MentorProfileController controller;
  final bool needsPhone;

  @override
  State<_MentoringRequestForm> createState() => _MentoringRequestFormState();
}

class _MentoringRequestFormState extends State<_MentoringRequestForm> {
  final _message = TextEditingController();
  final _phone = TextEditingController();
  String? _problem;
  bool _sending = false;

  /// Asked for up front when the profile has no number, and also once the API says it is missing.
  late bool _needsPhone = widget.needsPhone;

  @override
  void dispose() {
    _message.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_message.text.trim().length < _minMessage) {
      setState(() => _problem = 'Tell the mentor a little more: at least $_minMessage characters.');
      return;
    }
    if (_needsPhone && _phone.text.trim().length < 8) {
      setState(() => _problem = 'Add the mobile number the mentor can reach you on.');
      return;
    }
    setState(() {
      _sending = true;
      _problem = null;
    });
    final message = await widget.controller.requestMentoring(message: _message.text, phone: _phone.text);
    if (!mounted) return;
    if (message != null) {
      setState(() {
        _sending = false;
        _problem = message;
        if (isPhoneRefusal(message)) _needsPhone = true;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.controller.profile?.firstName ?? 'the mentor';
    return _FormFrame(
      title: 'Ask $name to mentor you',
      subtitle: 'Free. $name reads this before answering, so say why them and what help you want.',
      submitLabel: _sending ? 'Sending…' : 'Send request',
      onSubmit: _sending ? null : _submit,
      problem: _problem,
      children: [
        _Labelled(
          label: 'Your message',
          child: TextField(
            controller: _message,
            minLines: 4,
            maxLines: 7,
            maxLength: _maxMessage,
            style: MentorText.formInput,
            decoration: _decoration('Why this mentor, and what help you want'),
          ),
        ),
        if (_needsPhone) _PhoneField(controller: _phone),
      ],
    );
  }
}

class _SessionRequestForm extends StatefulWidget {
  const _SessionRequestForm({required this.controller, required this.offering, required this.needsPhone});

  final MentorProfileController controller;
  final MentorOffering offering;
  final bool needsPhone;

  @override
  State<_SessionRequestForm> createState() => _SessionRequestFormState();
}

class _SessionRequestFormState extends State<_SessionRequestForm> {
  final _topic = TextEditingController();
  final _times = TextEditingController();
  final _phone = TextEditingController();
  late String _mode;
  String? _problem;
  bool _sending = false;

  /// Asked for up front when the profile has no number, and also once the API says it is missing.
  late bool _needsPhone = widget.needsPhone;

  List<String> get _modes {
    final keys = widget.controller.profile?.modeKeys ?? const [];
    return keys.isEmpty ? const ['VIDEO', 'PHONE', 'IN_PERSON', 'CHAT'] : keys;
  }

  @override
  void initState() {
    super.initState();
    _mode = _modes.first;
  }

  @override
  void dispose() {
    _topic.dispose();
    _times.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_topic.text.trim().length < _minTopic) {
      setState(() => _problem = 'Say what you want to discuss: at least $_minTopic characters.');
      return;
    }
    if (_needsPhone && _phone.text.trim().length < 8) {
      setState(() => _problem = 'Add the mobile number the mentor can reach you on.');
      return;
    }
    setState(() {
      _sending = true;
      _problem = null;
    });
    final message = await widget.controller.requestSession(
      widget.offering,
      topic: _topic.text,
      mode: _mode,
      preferredTimes: _times.text,
      phone: _phone.text,
    );
    if (!mounted) return;
    if (message != null) {
      setState(() {
        _sending = false;
        _problem = message;
        if (isPhoneRefusal(message)) _needsPhone = true;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.offering;
    final price = o.free ? 'Free' : inr(o.pricePaisa);
    return _FormFrame(
      title: 'Request ${o.title}',
      subtitle:
          '$price${o.durationMin == null ? '' : ' • ${o.durationMin} min'}. The mentor sets the time when they accept'
          '${o.free ? '.' : '; you pay only after that.'}',
      submitLabel: _sending ? 'Sending…' : 'Send request',
      onSubmit: _sending ? null : _submit,
      problem: _problem,
      children: [
        _Labelled(
          label: 'What do you want to discuss?',
          child: TextField(
            controller: _topic,
            minLines: 3,
            maxLines: 6,
            maxLength: _maxTopic,
            style: MentorText.formInput,
            decoration: _decoration('Your goal, and where you are stuck'),
          ),
        ),
        _Labelled(
          label: 'How would you like to meet?',
          child: Wrap(
            spacing: 8,
            children: [
              for (final m in _modes)
                ChoiceChip(
                  label: Text(modeLabel(m)),
                  selected: _mode == m,
                  onSelected: (_) => setState(() => _mode = m),
                ),
            ],
          ),
        ),
        _Labelled(
          label: 'Days and times that suit you (optional)',
          child: TextField(
            controller: _times,
            maxLength: 300,
            style: MentorText.formInput,
            decoration: _decoration('Weekday evenings, IST'),
          ),
        ),
        if (_needsPhone) _PhoneField(controller: _phone),
      ],
    );
  }
}

class _PhoneForm extends StatefulWidget {
  const _PhoneForm({required this.title, required this.help});

  final String title;
  final String help;

  @override
  State<_PhoneForm> createState() => _PhoneFormState();
}

class _PhoneFormState extends State<_PhoneForm> {
  final _phone = TextEditingController();
  String? _problem;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FormFrame(
      title: widget.title,
      subtitle: widget.help,
      submitLabel: 'Continue',
      problem: _problem,
      onSubmit: () {
        if (_phone.text.trim().length < 8) {
          setState(() => _problem = 'Add a mobile number the mentor can reach you on.');
          return;
        }
        Navigator.pop(context, _phone.text.trim());
      },
      children: [_PhoneField(controller: _phone)],
    );
  }
}
