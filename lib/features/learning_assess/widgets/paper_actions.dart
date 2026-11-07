import 'package:flutter/foundation.dart';

/// What a paper card's buttons do; the screen owns them (a sheet to confirm, a call, the website).
class PaperActions {
  const PaperActions({
    required this.onStart,
    required this.onRedeem,
    required this.onOpenWithPlan,
    required this.onBuy,
    required this.onSeePlans,
    this.onShare,
    this.onViewCertificate,
  });

  /// Open the exam (the brief, the questions, the result).
  final VoidCallback onStart;

  /// Spend ICR credits to open this paper for good.
  final VoidCallback onRedeem;

  /// Open the whole course or exam with a plan place.
  final VoidCallback onOpenWithPlan;

  /// The website's page for this paper, where a payment is made.
  final VoidCallback onBuy;

  /// The plans that open more.
  final VoidCallback onSeePlans;

  /// The phone's share sheet with this paper's page; a set card draws its share glyph only when this is given.
  final VoidCallback? onShare;

  /// The certificate the member holds for this paper, drawn in the app with its PDF; a row offers "Certificate"
  /// only when this is given.
  final VoidCallback? onViewCertificate;
}
