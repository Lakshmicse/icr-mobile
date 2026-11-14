import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/util/links.dart';
import '../../../../core/widgets/detail_sheet.dart';
import '../../account_models.dart';
import '../../account_rules.dart';
import '../../widgets/account_kit.dart';
import '../profile_controller.dart';
import '../profile_kit.dart';

/// What the person chose in Contact Information that the profile page carries out once the sheet is closed.
enum ContactInfoChoice {
  /// The pencil, or "Add Your Work Email": the work email, second number and links.
  edit,

  /// "Add Your Mobile Number", or Edit / Verify beside it: the number's own sheet.
  phone,

  /// The profile address: the public member page.
  publicProfile,
}

/// "Contact Information" from the profile's header: the website's read-only pop-up
/// (`ContactInfoDialog`), as LinkedIn shows it. The profile address, the
/// sign-in email, the work email and mobile number with whether each is
/// verified, a second number, the birthday and the links; an email, a number
/// or a link opens on the phone. The pencil swaps it for the edit sheet.
Future<ContactInfoChoice?> showContactInfoSheet(BuildContext context, MyProfileController controller) {
  return Navigator.of(context).push(
    BlurredSheetRoute<ContactInfoChoice>(
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ContactInfoSheet(controller: controller),
    ),
  );
}

class ContactInfoSheet extends StatelessWidget {
  const ContactInfoSheet({super.key, required this.controller});

  final MyProfileController controller;

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// "26 October", as the website writes it; nothing when either half is missing.
  static String? birthday(int? month, int? day) {
    if (month == null || day == null || month < 1 || month > 12) return null;
    return '$day ${_months[month - 1]}';
  }

  void _choose(BuildContext context, ContactInfoChoice choice) => Navigator.of(context).pop(choice);

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Material(
          color: Colors.white,
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final me = controller.profile.value;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SheetHandle(height: 24, top: 10, rule: false),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 8, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Contact Information',
                            style: AppText.workSans(18, FontWeight.w700, AppColors.slate900, lineHeight: 24),
                          ),
                        ),
                        IconButton(
                          key: const Key('contactInfo.edit'),
                          tooltip: 'Edit Contact Information',
                          onPressed: () => _choose(context, ContactInfoChoice.edit),
                          icon: const Icon(Symbols.edit, size: 22, color: AppColors.slate700),
                        ),
                        IconButton(
                          key: const Key('contactInfo.close'),
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded, color: AppColors.slate500),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 1, color: AppColors.slate100),
                  Flexible(
                    child: me == null
                        ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
                        : SafeArea(
                            top: false,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: _rows(context, me),
                              ),
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _rows(BuildContext context, MyProfile me) {
    final profileLink = AppConfig.sitePage(me.publicPath).toString();
    final first = me.firstName.trim().isEmpty ? 'Your' : '${me.firstName.trim()}’s';
    final links = controller.links;
    final present = links.value?.present ?? const <String, String>{};
    final day = birthday(me.birthMonth, me.birthDay);
    final textable = canTextPhone(me.phone);
    return [
      _InfoRow(
        key: const Key('contactInfo.profile'),
        icon: Symbols.person,
        label: '$first Profile',
        child: _Value(displayLink(profileLink), onTap: () => _choose(context, ContactInfoChoice.publicProfile)),
      ),
      _InfoRow(
        key: const Key('contactInfo.email'),
        icon: Symbols.mail,
        label: 'Email',
        child: _Value(
          me.email,
          onTap: () => openUrl(context, Uri(scheme: 'mailto', path: me.email), inApp: false),
        ),
      ),
      _InfoRow(
        key: const Key('contactInfo.workEmail'),
        icon: Symbols.work,
        label: 'Work Email',
        child: me.workEmail == null
            ? _Value(
                'Add Your Work Email',
                key: const Key('contactInfo.addWorkEmail'),
                onTap: () => _choose(context, ContactInfoChoice.edit),
              )
            : _Valued(
                value: _Value(
                  me.workEmail!,
                  onTap: () => openUrl(context, Uri(scheme: 'mailto', path: me.workEmail), inApp: false),
                ),
                chip: _verifiedChip(me.workEmailVerified),
              ),
      ),
      _InfoRow(
        key: const Key('contactInfo.phone'),
        icon: Symbols.smartphone,
        label: 'Mobile Number',
        trailing: me.phone == null
            ? null
            : TextButton(
                key: const Key('contactInfo.editPhone'),
                onPressed: () => _choose(context, ContactInfoChoice.phone),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                child: Text(!me.phoneVerified && textable ? 'Verify' : 'Edit', style: AccountText.link),
              ),
        child: me.phone == null
            ? _Value(
                'Add Your Mobile Number',
                key: const Key('contactInfo.addPhone'),
                onTap: () => _choose(context, ContactInfoChoice.phone),
              )
            : _Valued(
                value: _Value(
                  formatPhone(me.phone),
                  onTap: () => openUrl(context, Uri(scheme: 'tel', path: me.phone), inApp: false),
                ),
                // Only a number a code can reach is ever "not verified".
                chip: me.phoneVerified || textable ? _verifiedChip(me.phoneVerified) : null,
              ),
      ),
      if (me.altPhone != null)
        _InfoRow(
          key: const Key('contactInfo.altPhone'),
          icon: Symbols.call,
          label: 'Alternate Mobile Number',
          child: _Value(
            formatPhone(me.altPhone),
            onTap: () => openUrl(context, Uri(scheme: 'tel', path: me.altPhone), inApp: false),
          ),
        ),
      if (day != null)
        _InfoRow(
          key: const Key('contactInfo.birthday'),
          icon: Symbols.cake,
          label: 'Birthday',
          child: Text(day, style: AccountText.body),
        ),
      for (final e in present.entries)
        _InfoRow(
          key: Key('contactInfo.${e.key}'),
          icon: Symbols.link,
          label: ProfileLinks.labels[e.key] ?? 'Link',
          child: _Value(
            displayLink(e.value),
            onTap: () {
              final uri = Uri.tryParse(e.value);
              if (uri != null) openUrl(context, uri);
            },
          ),
        ),
      if (links.loading && !links.ready)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
        )
      else if (links.error != null && !links.ready)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SectionLoadError(what: 'links', message: links.error!, onRetry: () => controller.retry(links)),
        ),
    ];
  }

  static Widget _verifiedChip(bool verified) => verified
      ? AccountChip(label: 'Verified', color: AccountChip.green.$1, ink: AccountChip.green.$2, icon: Symbols.verified)
      : AccountChip(label: 'Not Verified', color: AccountChip.amber.$1, ink: AccountChip.amber.$2);
}

/// One line of LinkedIn's contact pop-up: a dark icon, a bold label, the value under it.
class _InfoRow extends StatelessWidget {
  const _InfoRow({super.key, required this.icon, required this.label, required this.child, this.trailing});

  final IconData icon;
  final String label;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 22, color: AppColors.slate900),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AccountText.itemTitle),
                const SizedBox(height: 2),
                child,
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A value that opens something: blue and semi-bold, the website's link.
class _Value extends StatelessWidget {
  const _Value(this.text, {super.key, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          text,
          style: AccountText.body.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// A value with its Verified / Not Verified chip beside it, wrapping under it on a narrow phone.
class _Valued extends StatelessWidget {
  const _Valued({required this.value, this.chip});

  final Widget value;
  final Widget? chip;

  @override
  Widget build(BuildContext context) {
    if (chip == null) return value;
    return Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [value, chip!]);
  }
}
