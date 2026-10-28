import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../feed_models.dart';
import '../feed_styles.dart';

/// The placement between posts, drawn as LinkedIn's promoted card: a white card with the label and an info
/// button on its first line, the title and the copy, the picture across the card, and an outlined blue button.
class SponsoredCardView extends StatelessWidget {
  const SponsoredCardView({super.key, required this.card, required this.onOpen, required this.onInfo});

  final SponsoredCard card;
  final VoidCallback onOpen;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: HomeLook.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(HomeLook.pad, 10, HomeLook.pad, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(card.label, style: HomeType.promoted)),
                    Semantics(
                      button: true,
                      label: 'About this placement',
                      excludeSemantics: true,
                      child: InkResponse(
                        key: const ValueKey('sponsored-info'),
                        onTap: onInfo,
                        radius: 18,
                        child: const SizedBox(
                          width: 28,
                          height: 24,
                          child: Icon(LucideIcons.info, size: 16, color: HomeLook.soft),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(card.title, style: HomeType.promoTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(card.body, style: HomeType.promoBody, maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 390 / 160,
            child: Image.asset(card.background, fit: BoxFit.cover, alignment: Alignment.centerRight),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(HomeLook.pad, 10, HomeLook.pad, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Material(
                color: HomeLook.card,
                shape: const StadiumBorder(side: BorderSide(color: HomeLook.blue, width: 1)),
                child: InkWell(
                  key: const ValueKey('sponsored-cta'),
                  onTap: onOpen,
                  customBorder: const StadiumBorder(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Text(card.cta, style: HomeType.promoCta),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
