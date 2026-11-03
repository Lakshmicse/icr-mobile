import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/title_bar.dart';
import '../notifications/notifications_screen.dart';
import 'learning_doors.dart';
import 'widgets/door_tile.dart';
import 'widgets/learn_card.dart' show LearnGridRow;

/// "Catalogue · View More": the Learning Center's six doors as tiles, two to a row — the categories, not the
/// courses (owner's call, 2 Nov 2026: the row's View More opened the ICR Courses list, which is one door of six).
/// A tile opens its door as the hub's rail does.
class CatalogueScreen extends StatelessWidget {
  const CatalogueScreen({super.key, required this.onBack, required this.onOpen, this.unread = 0, this.onBell});

  final VoidCallback onBack;
  final ValueChanged<LearningDoor> onOpen;
  final int unread;

  /// The bell; the app's notifications when left out.
  final VoidCallback? onBell;

  @override
  Widget build(BuildContext context) {
    const doors = LearningDoor.values;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.white),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              TitleBar(
                title: 'Catalogue',
                onBack: onBack,
                unread: unread,
                onBell: onBell ?? () => openNotifications(context),
              ),
              Expanded(
                child: ListView(
                  key: const ValueKey('catalogue-doors'),
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
                  children: [
                    for (var i = 0; i < doors.length; i += 2) ...[
                      if (i > 0) const SizedBox(height: 12),
                      LearnGridRow(
                        left: DoorTile(door: doors[i], onTap: () => onOpen(doors[i])),
                        right: i + 1 < doors.length
                            ? DoorTile(door: doors[i + 1], onTap: () => onOpen(doors[i + 1]))
                            : null,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
