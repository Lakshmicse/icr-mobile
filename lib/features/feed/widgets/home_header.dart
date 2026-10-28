import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/util/app_actions.dart';
import '../../notifications/notifications_bell.dart';
import '../feed_models.dart';
import '../feed_styles.dart';
import 'feed_avatar.dart';

/// The bar pinned above the feed, as LinkedIn's Android Home draws it: the reader's photo, an outlined pill that
/// opens the global search, a "+" that starts a post, Messages, and the bell, on white over a hairline.
///
/// The three actions default to the app-level [AppActions] (the shell fills them in), so Home, Learning and
/// Mentorship all show the same bar with no callback passed down.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.photo,
    required this.initials,
    required this.unread,
    required this.onAvatarTap,
    required this.onBellTap,
    this.onSearchTap,
    this.onCompose,
    this.onMessages,
    this.searchController,
    this.onSearch,
  });

  static const height = 52.0;

  final FeedPicture? photo;
  final String initials;
  final int unread;
  final VoidCallback onAvatarTap;
  final VoidCallback onBellTap;

  /// Defaults to [AppActions.openSearch].
  final VoidCallback? onSearchTap;

  /// "+": defaults to [AppActions.composePost].
  final VoidCallback? onCompose;

  /// Defaults to [AppActions.openMessages].
  final VoidCallback? onMessages;

  /// Ignored: kept so the screens that still pass them compile. The search field is a button now; a tap opens
  /// the global search, where the typing happens.
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: HomeLook.card,
        border: Border(bottom: BorderSide(color: HomeLook.hairline, width: 1)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Semantics(
            button: true,
            label: 'Your account',
            child: GestureDetector(
              key: const ValueKey('home-avatar'),
              onTap: onAvatarTap,
              child: _AccountAvatar(photo: photo, initials: initials),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: _SearchPill(onTap: onSearchTap ?? () => AppActions.openSearch?.call(context))),
          const SizedBox(width: 2),
          _HeaderButton(
            key: const ValueKey('home-compose'),
            label: 'Start a post',
            icon: Icons.add_box,
            onTap: onCompose ?? () => AppActions.composePost?.call(context),
          ),
          _HeaderButton(
            key: const ValueKey('home-messages'),
            label: 'Messages',
            icon: Icons.sms,
            dot: messagesUnread(context) > 0,
            onTap: onMessages ?? () => AppActions.openMessages?.call(context),
          ),
          _HeaderButton(
            key: const ValueKey('home-bell'),
            label: unread > 0 ? 'Notifications, $unread unread' : 'Notifications',
            icon: LucideIcons.bell,
            dot: unread > 0,
            onTap: onBellTap,
          ),
          const SizedBox(width: 2),
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
      width: 32,
      height: 32,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          FeedAvatar(photo: photo, initials: initials, size: 32),
          // The online dot, in the photo's bottom-right corner.
          Positioned(
            left: 21,
            top: 21,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.online,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// LinkedIn's search: an outlined full-radius pill, the magnifier at its left and the hint in 16 sp. It is a
/// button: it opens the search screen, where the typing happens.
class _SearchPill extends StatelessWidget {
  const _SearchPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const shape = StadiumBorder(side: BorderSide(color: HomeLook.soft, width: 1));
    return Semantics(
      button: true,
      label: 'Search ICR',
      excludeSemantics: true,
      child: Material(
        color: HomeLook.card,
        shape: shape,
        child: InkWell(
          key: const ValueKey('home-search'),
          customBorder: shape,
          onTap: onTap,
          child: SizedBox(
            height: 34,
            child: Row(
              children: [
                const SizedBox(width: 10),
                const Icon(Icons.search, size: 22, color: HomeLook.ink),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Search', style: HomeType.searchHint, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One of the bar's 24 dp glyphs in a 40 dp target, with a red dot when there is something unread.
class _HeaderButton extends StatelessWidget {
  const _HeaderButton({super.key, required this.label, required this.icon, required this.onTap, this.dot = false});

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: SizedBox(
          width: 40,
          height: HomeHeader.height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 24, color: HomeLook.soft),
              if (dot)
                Positioned(
                  left: 22,
                  top: 11,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
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
