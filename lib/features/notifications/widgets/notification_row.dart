import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/util/time_ago.dart';
import '../../messaging/widgets/chat_avatar.dart';
import '../notification_models.dart';
import '../notification_styles.dart';

/// One notification, as the Android LinkedIn list draws it: a 48 dp photo (the company's logo when it wrote as a
/// company, the category's tinted glyph when the platform did) with the category's glyph on its corner, the
/// sentence at 14 sp with the person's or company's name in bold, the detail at 12 sp under it, the short age
/// ("3h", "2d", "1w") and a ⋮ at the right. Unread rows sit on a pale-blue tint with a dot.
class NotificationRow extends StatelessWidget {
  const NotificationRow({
    super.key,
    required this.notification,
    required this.onTap,
    this.onMenu,
    this.showCompany = false,
    this.now,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  /// The ⋮ button: the row's sheet (mark as read, turn the category off). Null draws no button.
  final VoidCallback? onMenu;

  /// Which company the row is for: shown only to someone who works for more than one.
  final bool showCompany;
  final DateTime? now;

  static const avatarSize = 48.0;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final unread = n.unread;
    final category = n.category;
    final name = n.actorName;
    final age = compactAge(n.createdAt, now: now);
    return Semantics(
      button: true,
      label: unread ? 'Unread' : null,
      child: Material(
        color: unread ? NoteLook.unreadRow : NoteLook.page,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                n.actorCompany != null
                    ? _WithBadge(
                        category: category,
                        child: ChatAvatar(picture: n.actorCompany!.logo, name: name, size: avatarSize, company: true),
                      )
                    : n.actor != null
                    ? _WithBadge(
                        category: category,
                        child: ChatAvatar(picture: n.actor!.photo, name: name, size: avatarSize),
                      )
                    : Container(
                        width: avatarSize,
                        height: avatarSize,
                        decoration: BoxDecoration(color: category.tint, shape: BoxShape.circle),
                        child: Icon(category.icon, size: 22, color: category.ink),
                      ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Sentence(title: n.title, name: name),
                      if (n.body != null) ...[
                        const SizedBox(height: 2),
                        Text(n.body!, maxLines: 2, overflow: TextOverflow.ellipsis, style: NoteType.body),
                      ],
                      if (showCompany && n.company != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(LucideIcons.building2, size: 12, color: NoteLook.soft),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'For ${n.company!.name}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: NoteType.company,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1, right: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (unread) ...[
                            Container(
                              key: const ValueKey('unread-dot'),
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(color: NoteLook.blue, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(age, style: unread ? NoteType.ageUnread : NoteType.age),
                        ],
                      ),
                    ),
                    if (onMenu != null)
                      Semantics(
                        button: true,
                        label: 'More about this notification',
                        child: InkResponse(
                          key: ValueKey('notification-menu-${n.id}'),
                          onTap: onMenu,
                          radius: 22,
                          child: const SizedBox(
                            width: 40,
                            height: 36,
                            child: Icon(Icons.more_vert, size: 22, color: NoteLook.soft),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The stored title already carries the name; this only makes it bold.
class _Sentence extends StatelessWidget {
  const _Sentence({required this.title, required this.name});

  final String title;
  final String name;

  @override
  Widget build(BuildContext context) {
    if (name.isEmpty || !title.contains(name)) {
      return Text(title, style: NoteType.sentence, maxLines: 4, overflow: TextOverflow.ellipsis);
    }
    final parts = title.split(name);
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < parts.length; i++) ...[
            TextSpan(text: parts[i]),
            if (i < parts.length - 1) TextSpan(text: name, style: NoteType.sentenceBold),
          ],
        ],
      ),
      style: NoteType.sentence,
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// A person's photo with their notification's category glyph on its corner.
class _WithBadge extends StatelessWidget {
  const _WithBadge({required this.category, required this.child});

  final NotificationCategory category;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: NotificationRow.avatarSize + 2,
    height: NotificationRow.avatarSize + 2,
    child: Stack(
      children: [
        child,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: category.tint,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Icon(category.icon, size: 11, color: category.ink),
          ),
        ),
      ],
    ),
  );
}
