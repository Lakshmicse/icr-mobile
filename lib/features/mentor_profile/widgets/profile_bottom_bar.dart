import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../mentor_profile_styles.dart';
import 'profile_hero.dart';

/// The bar pinned under the profile: a chat button and the main ask. White
/// with a soft shadow above; 78 dp of 45 dp button and 16.5 dp margins.
class ProfileBottomBar extends StatelessWidget {
  const ProfileBottomBar({super.key, required this.actions});

  static const height = 78.0;

  final HeroActions actions;

  @override
  Widget build(BuildContext context) {
    final enabled = actions.onPrimary != null;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(actions.onMessage == null ? 13.6 : 19.2, 16.5, 13.6, 16.5),
          child: Row(
            children: [
              if (actions.onMessage != null) ...[
                Semantics(
                  button: true,
                  label: 'Message the mentor',
                  child: InkResponse(
                    onTap: actions.onMessage,
                    radius: 28,
                    child: const SizedBox(
                      width: 48,
                      height: 45,
                      child: Icon(LucideIcons.messageSquare, size: 18, color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
              ],
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: enabled
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.22),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Material(
                    color: enabled ? AppColors.primary : AppColors.primary.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: actions.onPrimary,
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 45,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(actions.primaryIcon, size: 16, color: Colors.white),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                actions.barLabel,
                                style: MentorText.barButton,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
