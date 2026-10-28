import 'package:flutter/material.dart';

import '../../core/theme/app_text.dart';
import '../../core/widgets/title_bar.dart';
import '../notifications/notifications_bell.dart';
import '../notifications/notifications_screen.dart';

/// Stands in for a Learning screen whose builder has not landed yet. Each
/// screen's own file replaces its use of this.
class LearningComingSoon extends StatelessWidget {
  const LearningComingSoon({super.key, required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TitleBar(
              title: title,
              onBack: onBack,
              unread: bellUnread(context),
              onBell: () => openNotifications(context),
            ),
            Expanded(
              child: Center(child: Text('$title is on its way', style: AppText.screenLead)),
            ),
          ],
        ),
      ),
    );
  }
}
