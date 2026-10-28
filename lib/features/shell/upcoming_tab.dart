import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/util/links.dart';

/// A tab whose screens are not in the app yet: says so and opens the same
/// part of the website.
class UpcomingTab extends StatelessWidget {
  const UpcomingTab({
    super.key,
    required this.title,
    required this.icon,
    required this.summary,
    required this.sitePath,
  });

  final String title;
  final Widget icon;
  final String summary;
  final String sitePath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 56,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppColors.outlineVariant, width: 0.5)),
              ),
              child: Text(title, style: AppText.screenTitle.copyWith(fontSize: 22, height: 1.2)),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(color: Color(0xFFE8F1F8), shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: icon,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '$title is coming to the app',
                        textAlign: TextAlign.center,
                        style: AppText.postTitle.copyWith(fontSize: 18, height: 1.3),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        summary,
                        textAlign: TextAlign.center,
                        style: AppText.small.copyWith(fontSize: 14, height: 1.45),
                      ),
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed: () => openSitePage(context, sitePath),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                          textStyle: AppText.button,
                        ),
                        child: Text('Open $title on icr.org.in', style: AppText.button),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
