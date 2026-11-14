import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../assess_format.dart';
import '../assess_models.dart';
import '../assess_styles.dart';
import 'paper_card.dart';

/// "Get all 3 levels together" (or "all 2 sets") on a programme's page and on a mock subject's page: the levels or
/// sets this member does not hold yet, offered together, the website's `BundleOffer` for a phone — as a section
/// of the page with a line above it, never a banner or a box (owner, 3 Nov 2026).
///
/// Two offers share it, each on one line beside its button, each shown only while the API says it is on offer
/// (`BundleQuote`):
///  * **In money**, when two or more priced ones are still closed and the bundle discount beats buying them one by
///    one: the separate price struck through, the bundle price + GST, what it saves — **Pay now**.
///  * **In ICR credits**, when two or more are closed, each can be redeemed, and it saves something: every closed
///    one's credits struck through, the bundle's, what it saves — **Redeem** (the screen asks first).
///
/// The figures are the API's, shown as they come (the bundle's credit rule is the portal's `bundleCreditCost`).
class BundleOffer extends StatelessWidget {
  const BundleOffer({
    super.key,
    required this.quote,
    required this.onPay,
    this.heldCredits = 0,
    this.redeeming = false,
    this.onRedeem,
  });

  final BundleQuote quote;

  /// The money bundle's button: the bundle's checkout, paid in the app.
  final VoidCallback onPay;

  /// The member's ICR credits.
  final int heldCredits;

  /// A redemption is in flight.
  final bool redeeming;

  /// Redeems the bundle in credits (the screen asks first). Absent: the credit offer is not drawn.
  final VoidCallback? onRedeem;

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
        : (count == 1 ? 'Open the last $noun with ICR credits' : 'Open all $count ${noun}s with ICR credits');
    final titles = money ? quote.levels : [for (final l in quote.creditLevels) l.title];
    const color = AssessColors.navy;

    return Padding(
      key: const ValueKey('bundle-offer'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AssessColors.gold, borderRadius: BorderRadius.circular(4)),
                child: Text('BEST VALUE', style: AssessText.bundleKicker.copyWith(color: AssessColors.goldInk)),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  kicker,
                  style: AssessText.bundleKicker.copyWith(color: AppColors.successInk),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(title, key: const ValueKey('bundle-title'), style: AssessText.panelTitle),
          if (titles.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(titles.join(' · '), style: AssessText.sectionHint, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          if (money) ...[
            const SizedBox(height: 12),
            _OfferLine(
              price: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: rupees(quote.separateSalePaisa, quote.currency), style: AssessText.strikeSmall),
                    const TextSpan(text: '  '),
                    TextSpan(
                      text: rupees(quote.salePaisa, quote.currency),
                      style: AssessText.priceBig.copyWith(color: color),
                    ),
                    TextSpan(text: ' + GST', style: AssessText.progressNote),
                  ],
                ),
                key: const ValueKey('bundle-price'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              notes: [
                Text(
                  'Save ${rupees(quote.savePaisa, quote.currency)} vs buying separately',
                  key: const ValueKey('bundle-separate'),
                  style: AssessText.saveSmall,
                ),
                if (quote.offerEndsOn != null)
                  Text(
                    'Offer valid until ${_day(quote.offerEndsOn!)}',
                    key: const ValueKey('bundle-offer-ends'),
                    style: AssessText.progressNote.copyWith(color: const Color(0xFFB5481F)),
                  ),
                if (!quote.payable) Text('Online payment is not available right now.', style: AssessText.progressNote),
              ],
              button: RowButton(
                key: const ValueKey('bundle-pay-now'),
                label: 'Pay Now',
                color: color,
                onPressed: quote.payable ? onPay : null,
              ),
            ),
          ],
          if (inCredits != null) ...[
            const SizedBox(height: 12),
            _OfferLine(
              price: Text.rich(
                TextSpan(
                  children: [
                    if ((quote.separateCredits ?? 0) > inCredits) ...[
                      TextSpan(text: creditsShort(quote.separateCredits ?? 0), style: AssessText.strikeSmall),
                      const TextSpan(text: '  '),
                    ],
                    TextSpan(
                      text: creditsLabel(inCredits),
                      style: AssessText.priceBig.copyWith(color: color),
                    ),
                  ],
                ),
                key: const ValueKey('bundle-credits'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              notes: [
                Text(
                  'Save ${creditsLabel(quote.creditsSaved)}${money ? '' : ' vs one at a time'}',
                  key: const ValueKey('bundle-credits-save'),
                  style: AssessText.saveSmall,
                ),
              ],
              button: RowButton(
                key: const ValueKey('bundle-redeem-credits'),
                label: redeeming ? 'Redeeming…' : 'Redeem',
                color: color,
                tonal: money,
                loading: redeeming,
                onPressed: heldCredits >= inCredits && !redeeming ? onRedeem : null,
              ),
            ),
          ],
        ],
      ),
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

/// One way to take the bundle: the price and what it saves on the left, its button on the right.
class _OfferLine extends StatelessWidget {
  const _OfferLine({required this.price, required this.notes, required this.button});

  final Widget price;
  final List<Widget> notes;
  final Widget button;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [price, ...notes]),
        ),
        const SizedBox(width: 12),
        button,
      ],
    );
  }
}
