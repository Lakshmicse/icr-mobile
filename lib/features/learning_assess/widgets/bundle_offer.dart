import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../assess_format.dart';
import '../assess_models.dart';
import '../assess_styles.dart';

/// "Get all 3 levels together" (or "all 2 sets") on a programme's page and on a mock subject's page: the levels or
/// sets this member does not hold yet, offered together, the website's `BundleOffer` for a phone.
///
/// Two offers share the strip, each shown only while the API says it is on offer (`BundleQuote`):
///  * **In money**, when two or more priced ones are still closed and the bundle discount beats buying them one by
///    one: the list price struck through, the bundle price + GST, what it saves. The payment is made on the website
///    (the app has no gateway leg), so its button opens the page in the phone's browser.
///  * **In ICR credits** (owner's rule, 27 Oct 2026), when two or more are closed, each can be redeemed, and it saves
///    something: every closed one at its own credits, summed, less the bundle discount (10), never below the dearest
///    one. Redeemed in the app, after a confirmation. Beside the price when both are on offer, alone when nothing
///    here is priced.
///
/// The figures are the API's, shown as they come.
class BundleOffer extends StatelessWidget {
  const BundleOffer({
    super.key,
    required this.quote,
    required this.onPay,
    this.heldCredits = 0,
    this.redeeming = false,
    this.onRedeem,
    this.onEarnMore,
  });

  final BundleQuote quote;

  /// The money bundle's button: the paper's or programme's page on the website, in the browser.
  final VoidCallback onPay;

  /// The member's ICR credits.
  final int heldCredits;

  /// A redemption is in flight.
  final bool redeeming;

  /// Redeems the bundle in credits (the screen asks first). Absent: the credit offer is not drawn.
  final VoidCallback? onRedeem;

  /// "Invite colleagues to earn more", under a balance that falls short.
  final VoidCallback? onEarnMore;

  @override
  Widget build(BuildContext context) {
    final inCredits = onRedeem == null ? null : quote.inCredits;
    final money = quote.offered;
    if (!money && inCredits == null) return const SizedBox.shrink();
    final mock = quote.mock;
    final count = money ? quote.levels.length : quote.creditLevels.length;
    final noun = mock ? 'set' : 'level';
    final percent = quote.discountBps ~/ 100;
    final String kicker = money
        ? 'BUNDLE · $percent% OFF'
        : 'BUNDLE · ${quote.creditsSaved} ${quote.creditsSaved == 1 ? 'CREDIT' : 'CREDITS'} OFF';
    final String title = money
        ? (count == 1 ? 'Get the last $noun' : 'Get all $count ${noun}s together')
        : (count == 1
              ? 'Open the last $noun with ICR credits'
              : 'Open all $count ${noun}s with ICR credits');
    final String subtitle = money
        ? (mock
              ? 'Every set of the ${quote.programmeTitle} mock exam, unlocked in one payment.'
              : 'The complete ${quote.programmeTitle} certification, unlocked in one payment.')
        : (mock
              ? 'Every set of the ${quote.programmeTitle} mock exam, opened with one redemption.'
              : 'The complete ${quote.programmeTitle} certification, opened with one redemption.');
    final titles = money ? quote.levels : [for (final l in quote.creditLevels) l.title];

    return Container(
      key: const ValueKey('bundle-offer'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AssessColors.navy, AssessColors.navyMid, AssessColors.navyLight],
        ),
        boxShadow: const [BoxShadow(color: Color(0x400B1F3A), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AssessColors.gold, borderRadius: BorderRadius.circular(6)),
                child: Text('BEST VALUE', style: AssessText.bundleKicker.copyWith(color: AssessColors.goldInk)),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(kicker, style: AssessText.bundleKicker, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.package, size: 26, color: AssessColors.gold),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, key: const ValueKey('bundle-title'), style: AssessText.bundleTitle),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: AssessText.bundleBody),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in titles)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0x1FFFFFFF), borderRadius: BorderRadius.circular(999)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.check, size: 14, color: AssessColors.gold),
                      const SizedBox(width: 4),
                      Text(name, style: AssessText.bundleChip),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: !money && inCredits != null
                ? _CreditsOnly(
                    quote: quote,
                    credits: inCredits,
                    heldCredits: heldCredits,
                    busy: redeeming,
                    onRedeem: onRedeem!,
                    onEarnMore: onEarnMore,
                  )
                : _MoneyPanel(
                    quote: quote,
                    count: count,
                    noun: noun,
                    credits: inCredits,
                    heldCredits: heldCredits,
                    busy: redeeming,
                    onPay: onPay,
                    onRedeem: onRedeem,
                    onEarnMore: onEarnMore,
                  ),
          ),
        ],
      ),
    );
  }
}

/// The bundle in money: the separate price struck through, the bundle price, what it saves, the pay button; and,
/// when the same bundle is on offer in credits, that beneath a rule.
class _MoneyPanel extends StatelessWidget {
  const _MoneyPanel({
    required this.quote,
    required this.count,
    required this.noun,
    required this.credits,
    required this.heldCredits,
    required this.busy,
    required this.onPay,
    required this.onRedeem,
    required this.onEarnMore,
  });

  final BundleQuote quote;
  final int count;
  final String noun;
  final int? credits;
  final int heldCredits;
  final bool busy;
  final VoidCallback onPay;
  final VoidCallback? onRedeem;
  final VoidCallback? onEarnMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(rupees(quote.separateSalePaisa, quote.currency), key: const ValueKey('bundle-separate'), style: AssessText.strike),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              rupees(quote.salePaisa, quote.currency),
              key: const ValueKey('bundle-price'),
              style: AssessText.bundleTitle.copyWith(color: AssessColors.navy),
            ),
            const SizedBox(width: 6),
            Text('+ GST', style: AssessText.panelNote),
          ],
        ),
        Text('Save ${rupees(quote.savePaisa, quote.currency)} vs buying separately', style: AssessText.save),
        if (quote.offerEndsOn != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Offer valid till ${_day(quote.offerEndsOn!)}',
              key: const ValueKey('bundle-offer-ends'),
              style: AssessText.panelNote.copyWith(color: const Color(0xFFB5481F), fontWeight: FontWeight.w700),
            ),
          ),
        const SizedBox(height: 12),
        _GoldButton(
          key: const ValueKey('bundle-pay-now'),
          label: count == 1 ? 'Unlock it on the website' : 'Unlock all $count ${noun}s on the website',
          icon: LucideIcons.externalLink,
          onPressed: quote.payable ? onPay : null,
        ),
        if (!quote.payable) ...[
          const SizedBox(height: 6),
          Text('Online payment is not available right now.', style: AssessText.buttonNote),
        ],
        if (credits != null && onRedeem != null) ...[
          const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Divider(height: 1)),
          Text(
            'Save ${creditsLabel(quote.creditsSaved)} vs redeeming them one at a time',
            key: const ValueKey('bundle-credits-save'),
            style: AssessText.save,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          _RedeemButton(
            credits: credits!,
            held: heldCredits,
            busy: busy,
            contained: false,
            onRedeem: onRedeem!,
            onEarnMore: onEarnMore,
          ),
        ],
      ],
    );
  }

  /// "2026-12-31" as "31 Dec 2026".
  static String _day(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

/// Nothing here is priced: the bundle is on offer in ICR credits alone.
class _CreditsOnly extends StatelessWidget {
  const _CreditsOnly({
    required this.quote,
    required this.credits,
    required this.heldCredits,
    required this.busy,
    required this.onRedeem,
    required this.onEarnMore,
  });

  final BundleQuote quote;
  final int credits;
  final int heldCredits;
  final bool busy;
  final VoidCallback onRedeem;
  final VoidCallback? onEarnMore;

  @override
  Widget build(BuildContext context) {
    final separate = quote.separateCredits ?? 0;
    return Column(
      children: [
        Text(
          '${creditsShort(separate)} one at a time',
          key: const ValueKey('bundle-separate-credits'),
          style: AssessText.strike,
        ),
        Text(
          creditsLabel(credits),
          key: const ValueKey('bundle-credits'),
          style: AssessText.bundleTitle.copyWith(color: AssessColors.navy),
        ),
        Text(
          'Save ${creditsLabel(quote.creditsSaved)} vs redeeming them one at a time',
          key: const ValueKey('bundle-credits-save'),
          style: AssessText.save,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        _RedeemButton(
          credits: credits,
          held: heldCredits,
          busy: busy,
          contained: true,
          onRedeem: onRedeem,
          onEarnMore: onEarnMore,
        ),
      ],
    );
  }
}

/// "Redeem N ICR credits" with the balance under it: off while the member holds fewer than the bundle takes.
class _RedeemButton extends StatelessWidget {
  const _RedeemButton({
    required this.credits,
    required this.held,
    required this.busy,
    required this.contained,
    required this.onRedeem,
    required this.onEarnMore,
  });

  final int credits;
  final int held;
  final bool busy;

  /// Filled gold, as the pay button is, when credits are the only way the bundle is offered.
  final bool contained;
  final VoidCallback onRedeem;
  final VoidCallback? onEarnMore;

  @override
  Widget build(BuildContext context) {
    final enough = held >= credits;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GoldButton(
          key: const ValueKey('bundle-redeem-credits'),
          label: busy ? 'Redeeming…' : '${contained ? 'Redeem' : 'Or redeem'} ${creditsLabel(credits)}',
          icon: LucideIcons.coins,
          filled: contained,
          loading: busy,
          onPressed: enough && !busy ? onRedeem : null,
        ),
        const SizedBox(height: 6),
        Text(
          enough ? 'You have ${creditsShort(held)}' : 'Needs $credits; you have $held.',
          key: const ValueKey('bundle-credits-balance'),
          style: AssessText.buttonNote.copyWith(color: enough ? AppColors.onSurfaceVariant : AppColors.amber800),
          textAlign: TextAlign.center,
        ),
        if (!enough && onEarnMore != null)
          Align(
            child: TextButton(
              onPressed: onEarnMore,
              child: Text('Invite colleagues to earn more', style: AssessText.noteLink),
            ),
          ),
      ],
    );
  }
}

/// A 48 dp button in the offer's gold: filled, or outlined in navy.
class _GoldButton extends StatelessWidget {
  const _GoldButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = true,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final ink = filled ? AssessColors.goldInk : AssessColors.navy;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: filled ? BorderSide.none : BorderSide(color: enabled ? AssessColors.navy : const Color(0x590B1F3A)),
    );
    return Opacity(
      opacity: enabled || loading ? 1 : 0.55,
      child: Material(
        color: filled ? AssessColors.gold : Colors.white,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onPressed,
          child: SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: ink))
                else
                  Icon(icon, size: 18, color: ink),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: AssessText.button.copyWith(color: ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
