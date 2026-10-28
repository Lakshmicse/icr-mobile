import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/title_bar.dart';

/// A centred message for an empty or failed screen, with one action.
class ChatNotice extends StatelessWidget {
  const ChatNotice({
    super.key,
    required this.title,
    this.body,
    this.icon = LucideIcons.messageCircle,
    this.action,
    this.onAction,
  });

  final String title;
  final String? body;
  final IconData icon;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: AppColors.slate100, shape: BoxShape.circle),
            child: Icon(icon, size: 26, color: AppColors.slate500),
          ),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: AppText.postTitle.copyWith(fontSize: 16, height: 1.3)),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(body!, textAlign: TextAlign.center, style: AppText.small),
          ],
          if (action != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.outlineVariant),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(action!, style: AppText.link),
            ),
          ],
        ],
      ),
    );
  }
}

/// The small spinner a loading list shows.
class ChatSpinner extends StatelessWidget {
  const ChatSpinner({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(width: size, height: size, child: const CircularProgressIndicator(strokeWidth: 2.4)),
  );
}

/// The section screens' title bar (`TitleBar`'s size, shadow, arrow and
/// title), with the screen's own actions where the bell would be.
class ChatTitleBar extends StatelessWidget {
  const ChatTitleBar({super.key, required this.title, this.onBack, this.actions = const []});

  final String title;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: TitleBar.height,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Row(
        children: [
          const SizedBox(width: 17.75),
          Semantics(
            button: true,
            label: 'Back',
            child: InkResponse(
              onTap: onBack ?? () => Navigator.maybePop(context),
              radius: 24,
              child: const SizedBox(
                width: 24,
                height: 56,
                child: Icon(Symbols.arrow_back, size: 24, color: AppColors.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(width: 18.75),
          Expanded(
            child: Text(title, style: AppText.barTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          ...actions,
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
