import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../messaging/messaging_styles.dart';
import '../../messaging/widgets/states.dart';
import '../notification_models.dart';
import '../notifications_controller.dart';

/// Which categories reach the person in the app and by email. A switch moves
/// at once and saves on its own; a refusal puts it back and says why. The
/// locked ones (payments, security, support) are on and disabled.
class PreferencesView extends StatelessWidget {
  const PreferencesView({super.key, required this.controller});

  final NotificationsController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final prefs = c.preferences;
    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text('Notification preferences', style: ChatText.sheetTitle),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Text(
          'Choose what reaches you in the app and by email. Payments, account security and support replies are always sent.',
          style: ChatText.hint.copyWith(fontSize: 12, height: 17 / 12),
        ),
      ),
      if (c.saveError != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            decoration: BoxDecoration(color: AppColors.errorContainer, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Expanded(
                  child: Text(c.saveError!, style: ChatText.lead.copyWith(color: AppColors.onErrorContainer)),
                ),
                IconButton(
                  tooltip: 'Dismiss',
                  visualDensity: VisualDensity.compact,
                  onPressed: c.clearSaveError,
                  icon: const Icon(LucideIcons.x, size: 16, color: AppColors.onErrorContainer),
                ),
              ],
            ),
          ),
        ),
    ];
    if (prefs == null) {
      children.add(
        c.preferencesError != null
            ? ChatNotice(
                icon: LucideIcons.bellOff,
                title: c.preferencesError!,
                action: 'Retry',
                onAction: c.loadPreferences,
              )
            : const Padding(padding: EdgeInsets.all(40), child: ChatSpinner()),
      );
    } else {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Row(
            children: [
              Expanded(child: Text('Category', style: ChatText.noteMeta)),
              SizedBox(
                width: 58,
                child: Center(child: Text('In-app', style: ChatText.noteMeta)),
              ),
              SizedBox(
                width: 58,
                child: Center(child: Text('Email', style: ChatText.noteMeta)),
              ),
            ],
          ),
        ),
      );
      children.add(const Divider(height: 1, thickness: 1, color: ChatColors.rule));
      for (final p in prefs) {
        children.add(_PreferenceRow(preference: p, controller: c));
        children.add(const Divider(height: 1, thickness: 1, color: ChatColors.rule, indent: 16));
      }
      children.add(const SizedBox(height: 24));
    }
    return ListView(physics: const AlwaysScrollableScrollPhysics(), children: children);
  }
}

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({required this.preference, required this.controller});

  final NotificationPreference preference;
  final NotificationsController controller;

  @override
  Widget build(BuildContext context) {
    final p = preference;
    Widget toggle(String channel, bool value, ValueChanged<bool> onChanged) => SizedBox(
      width: 58,
      child: Center(
        child: Semantics(
          label: '${p.category.label}: $channel',
          child: Transform.scale(
            scale: 0.8,
            child: Switch(
              key: ValueKey('pref-${p.category.id}-$channel'),
              value: p.locked || value,
              onChanged: p.locked ? null : onChanged,
              activeTrackColor: AppColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(p.category.label, style: ChatText.label),
                    if (p.locked)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.slate200),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.lock, size: 10, color: AppColors.slate500),
                            const SizedBox(width: 3),
                            Text('Always sent', style: ChatText.kindBadge.copyWith(fontSize: 9.5)),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(p.category.hint, style: ChatText.hint),
              ],
            ),
          ),
          toggle('In-app', p.inApp, (on) => controller.setChannel(p, inApp: on)),
          toggle('Email', p.email, (on) => controller.setChannel(p, email: on)),
        ],
      ),
    );
  }
}
