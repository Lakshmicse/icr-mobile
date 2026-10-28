import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../feed/feed_models.dart';
import '../../feed/widgets/feed_avatar.dart';
import '../events_styles.dart';

/// The bar pinned above the Events board, as the design: the reader's photo
/// with its green dot, the title, and the bell with its red dot. 50 dp, with
/// the Home header's shadow. (The Home header puts a search box where the
/// title goes, so this is its own copy.)
class EventsHeader extends StatelessWidget {
  const EventsHeader({
    super.key,
    required this.photo,
    required this.initials,
    required this.unread,
    required this.onAvatarTap,
    required this.onBellTap,
    this.title = 'Events',
  });

  static const height = 50.0;

  final FeedPicture? photo;
  final String initials;
  final int unread;
  final VoidCallback onAvatarTap;
  final VoidCallback onBellTap;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Row(
        children: [
          const SizedBox(width: 13),
          Semantics(
            button: true,
            label: 'Your account',
            child: GestureDetector(
              onTap: onAvatarTap,
              child: _AccountAvatar(photo: photo, initials: initials),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(title, style: EventsText.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Semantics(
            button: true,
            label: unread > 0 ? 'Notifications, $unread unread' : 'Notifications',
            child: InkResponse(
              onTap: onBellTap,
              radius: 22,
              child: SizedBox(
                width: 36,
                height: height,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(LucideIcons.bell, size: 22, color: AppColors.onSurfaceVariant),
                    if (unread > 0)
                      Positioned(
                        left: 23.5,
                        top: 11,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.photo, required this.initials});

  final FeedPicture? photo;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 34,
            height: 34,
            padding: const EdgeInsets.all(1),
            decoration: const BoxDecoration(color: AppColors.avatarRing, shape: BoxShape.circle),
            child: FeedAvatar(photo: photo, initials: initials, size: 32),
          ),
          Positioned(
            left: 22,
            top: 22,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: AppColors.online,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.badgeRing, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
