import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';

/// The bar over a programme's page and a mock exam's: the back arrow and the door's name, with a share glyph at the
/// right when the page has something to share. The kit's `TitleBar` always draws the bell, which these two designs
/// (29 Oct 2026) leave out; this is the same bar (56 dp, white, the same shadow, the arrow and the title where
/// the kit puts them) without it.
class AssessBar extends StatelessWidget {
  const AssessBar({super.key, required this.title, required this.onBack, this.onShare, this.shareLabel = 'Share'});

  static const height = 56.0;

  final String title;
  final VoidCallback onBack;

  /// The share glyph's action; no glyph when null.
  final VoidCallback? onShare;
  final String shareLabel;

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
          const SizedBox(width: 17.75),
          Semantics(
            button: true,
            label: 'Back',
            child: InkResponse(
              onTap: onBack,
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
          if (onShare != null)
            Semantics(
              button: true,
              label: shareLabel,
              child: InkResponse(
                onTap: onShare,
                radius: 24,
                child: const SizedBox(
                  width: 24,
                  height: 56,
                  child: Icon(Symbols.share, size: 24, color: AppColors.onSurfaceVariant),
                ),
              ),
            ),
          SizedBox(width: onShare == null ? 13 : 12),
        ],
      ),
    );
  }
}
