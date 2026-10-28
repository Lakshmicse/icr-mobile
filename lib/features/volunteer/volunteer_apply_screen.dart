import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import '../chapters/community_kit.dart';
import '../contact/contact_models.dart';
import 'volunteer_controller.dart';

/// "Volunteer with ICR": tell the team how you would like to help. Optional role and chapter (each chosen
/// from a sheet), your name, email and phone (filled in from your account), and what you bring. It goes to
/// the ICR team through the website's contact endpoint with topic Volunteer, so the form follows the
/// contact form's rules (a valid email, a message of at most 4,000 characters that already holds the role
/// and chapter lines). A refusal is shown and what was typed stays. Pops with true once the team has it.
class VolunteerApplyScreen extends StatefulWidget {
  const VolunteerApplyScreen({super.key, required this.controller, this.onBell, this.opener = openUrl, this.onDone});

  final VolunteerFormController controller;

  /// The bell. The website's notifications page when null.
  final VoidCallback? onBell;
  final Future<void> Function(BuildContext context, Uri uri) opener;

  /// "Done" on the thank-you view; pops the screen when null.
  final VoidCallback? onDone;

  @override
  State<VolunteerApplyScreen> createState() => _VolunteerApplyScreenState();
}

class _VolunteerApplyScreenState extends State<VolunteerApplyScreen> {
  late final TextEditingController _name = TextEditingController(text: widget.controller.name);
  late final TextEditingController _email = TextEditingController(text: widget.controller.email);
  late final TextEditingController _phone = TextEditingController(text: widget.controller.phone);
  final _message = TextEditingController();

  VolunteerFormController get _c => widget.controller;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _message.dispose();
    super.dispose();
  }

  void _bell() {
    final go = widget.onBell;
    if (go != null) return go();
    widget.opener(context, AppConfig.sitePage('/notifications'));
  }

  Future<void> _submit() async {
    final ok = await _c.submit();
    if (ok && mounted) FocusScope.of(context).unfocus();
  }

  Future<void> _pickRole() async {
    const none = 'Not sure yet: any role';
    final picked = await pickFromSheet<String>(
      context,
      title: 'Which role?',
      options: [none, for (final r in _c.roles) r.title],
      label: (o) => o,
      selected: _c.role?.title ?? none,
    );
    if (picked == null) return;
    _c.setRole(picked == none ? null : _c.roles.firstWhere((r) => r.title == picked));
  }

  Future<void> _pickChapter() async {
    const none = 'No chapter in particular';
    final names = [for (final c in _c.chapters) c.name];
    final current = _c.chapter;
    final options = [none, if (current != null && !names.contains(current)) current, ...names];
    final picked = await pickFromSheet<String>(
      context,
      title: 'Which chapter?',
      options: options,
      label: (o) => o,
      selected: current ?? none,
    );
    if (picked == null) return;
    _c.setChapter(picked == none ? null : picked);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        if (_c.sent) return _thanks();
        return CommunityPage(
          title: 'Volunteer with ICR',
          onBack: () => Navigator.of(context).maybePop(),
          onBell: _bell,
          onRefresh: () async {},
          bottomBar: _bar(),
          children: _form(),
        );
      },
    );
  }

  Widget _bar() => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: CommunityColors.tileRule)),
    ),
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
    child: CommunityButton(
      label: 'Send to the ICR team',
      icon: LucideIcons.send,
      expand: true,
      height: 42,
      busy: _c.busy,
      onPressed: _c.busy ? null : _submit,
    ),
  );

  List<Widget> _form() {
    final c = _c;
    return [
      const SizedBox(height: 14),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tell the ICR team how you would like to help. They read every message and reply by email.',
              style: CommunityText.body,
            ),
            const SizedBox(height: 16),
            _Picker(
              label: 'Role',
              value: c.role?.title,
              hint: 'Not sure yet: any role',
              icon: LucideIcons.heartHandshake,
              enabled: !c.busy,
              onTap: _pickRole,
            ),
            if (c.role != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(LucideIcons.clock, size: 12, color: AppColors.slate400),
                  const SizedBox(width: 5),
                  Text(c.role!.commitment, style: CommunityText.personLine),
                ],
              ),
            ],
            const SizedBox(height: 14),
            _Picker(
              label: 'Chapter',
              value: c.chapter,
              hint: 'No chapter in particular',
              icon: LucideIcons.mapPin,
              enabled: !c.busy,
              onTap: _pickChapter,
            ),
            const SizedBox(height: 14),
            CommunityField(
              label: 'Your name *',
              controller: _name,
              maxLength: ContactLimits.name,
              error: c.problemFor(ContactField.name),
              enabled: !c.busy,
              textInputAction: TextInputAction.next,
              onChanged: c.setName,
              fieldKey: const Key('volunteer-name'),
            ),
            const SizedBox(height: 10),
            CommunityField(
              label: 'Email *',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              error: c.problemFor(ContactField.email),
              help: 'Where the team will reply.',
              enabled: !c.busy,
              textInputAction: TextInputAction.next,
              onChanged: c.setEmail,
              fieldKey: const Key('volunteer-email'),
            ),
            const SizedBox(height: 14),
            CommunityField(
              label: 'Phone',
              controller: _phone,
              keyboardType: TextInputType.phone,
              hint: 'Optional',
              maxLength: ContactLimits.phone,
              error: c.problemFor(ContactField.phone),
              enabled: !c.busy,
              onChanged: c.setPhone,
              fieldKey: const Key('volunteer-phone'),
            ),
            const SizedBox(height: 10),
            CommunityField(
              label: 'About you *',
              controller: _message,
              minLines: 5,
              maxLines: 10,
              maxLength: c.messageRoom < 0 ? 0 : c.messageRoom,
              hint: 'Your experience, why this role, and how much time you can give',
              error: c.problemFor(ContactField.message),
              enabled: !c.busy,
              onChanged: c.setMessage,
              fieldKey: const Key('volunteer-message'),
            ),
            if (c.error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: CommunityColors.red50, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(LucideIcons.circleAlert, size: 15, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(child: Text(c.error!, style: CommunityText.fieldError)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    ];
  }

  Widget _thanks() {
    final c = _c;
    final first = c.name.trim().split(RegExp(r'\s+')).first;
    return CommunityPage(
      title: 'Volunteer with ICR',
      onBack: () => Navigator.of(context).maybePop(),
      onBell: _bell,
      onRefresh: () async {},
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
          child: Column(
            children: [
              const Icon(LucideIcons.circleCheck, size: 44, color: AppColors.success),
              const SizedBox(height: 14),
              Text(
                'Thank you${first.isEmpty ? '' : ', $first'}',
                textAlign: TextAlign.center,
                style: CommunityText.cardTitleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '${c.role == null ? 'Your interest in volunteering' : 'Your interest in ${c.role!.title}'}'
                '${c.chapter == null ? '' : ' with ${c.chapter}'} reached the ICR team. '
                'They will write to ${c.email.trim()}.',
                textAlign: TextAlign.center,
                style: CommunityText.body,
              ),
              const SizedBox(height: 20),
              CommunityButton(
                label: 'Done',
                expand: true,
                height: 40,
                onPressed: widget.onDone ?? () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A field that opens a list of choices in a sheet.
class _Picker extends StatelessWidget {
  const _Picker({
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final String? value;
  final String hint;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: CommunityText.fieldLabel),
        const SizedBox(height: 5),
        Semantics(
          button: true,
          label: label,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: enabled ? Colors.white : CommunityColors.tile,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CommunityColors.border),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 15, color: AppColors.slate400),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      value ?? hint,
                      style: value == null ? CommunityText.fieldHint : CommunityText.fieldInput,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.slate400),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
