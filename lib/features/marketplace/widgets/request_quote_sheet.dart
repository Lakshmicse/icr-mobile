import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../catalog_models.dart';
import '../marketplace_controller.dart';
import '../marketplace_models.dart';
import '../marketplace_navigation.dart';
import '../marketplace_styles.dart';
import '../quote_controller.dart';
import '../quote_models.dart';
import 'market_sheets.dart';

/// "Request for Quote (RFQ)": the form the website's profile card and quote
/// dialog are, as a sheet. It creates the same private requirement, addressed to
/// this supplier only (`POST /rfq`), and lands on a confirmation with the way
/// to the requirement.
///
/// [service] or [product] is what the request is about (a row's Get Quote);
/// [services] are the supplier's services when the profile already has them.
Future<void> showRequestQuoteSheet(
  BuildContext context,
  Supplier supplier, {
  CatalogService? service,
  CatalogProduct? product,
  List<CatalogService>? services,
}) async {
  final controller = QuoteController(
    repository: context.read<MarketplaceController>().repository,
    supplier: supplier,
    service: service,
    product: product,
    services: services,
  )..load();
  await showMartSheet<void>(
    context,
    builder: (_) => ChangeNotifierProvider<QuoteController>.value(value: controller, child: const RequestQuoteSheet()),
  );
  controller.dispose();
}

class RequestQuoteSheet extends StatelessWidget {
  const RequestQuoteSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final q = context.watch<QuoteController>();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: q.sent == null ? 0.92 : 0.5,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) => q.sent == null ? _Form(scroll: scroll) : _Sent(sent: q.sent!),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({required this.scroll});

  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final q = context.watch<QuoteController>();
    final supplier = q.supplier;
    final product = q.product;
    final options = q.options;
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: scroll,
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12 + MediaQuery.viewInsetsOf(context).bottom),
            children: [
              Text('Request a quote', style: MartText.sheetTitle),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(LucideIcons.lock, size: 12, color: AppColors.outline),
                  const SizedBox(width: 5),
                  Expanded(child: Text('Sent privately to ${supplier.name}.', style: MartText.sheetRowMuted)),
                ],
              ),
              const SizedBox(height: 16),
              if (product != null) ...[
                _ProductSummary(product: product),
                const SizedBox(height: 12),
                _Field(
                  label: 'Quantity',
                  child: TextField(
                    key: const ValueKey('quote-quantity'),
                    controller: q.quantity,
                    enabled: !q.sending,
                    keyboardType: TextInputType.number,
                    style: MartText.sheetRow.copyWith(fontSize: 14),
                    decoration: _decoration(hint: '1', error: q.quantityProblem, suffix: product.unit),
                  ),
                ),
              ] else if (options == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                )
              else if (options.isNotEmpty || q.service != null)
                _Field(
                  label: 'Required service',
                  child: InputDecorator(
                    decoration: _decoration(),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        key: const ValueKey('quote-service'),
                        isExpanded: true,
                        isDense: true,
                        value: q.service?.id,
                        style: MartText.sheetRow.copyWith(fontSize: 14),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Not sure: a general enquiry', style: MartText.sheetRow.copyWith(fontSize: 14)),
                          ),
                          for (final s in _optionsWith(options, q.service))
                            DropdownMenuItem<String?>(
                              value: s.id,
                              child: Text(
                                s.name,
                                overflow: TextOverflow.ellipsis,
                                style: MartText.sheetRow.copyWith(fontSize: 14),
                              ),
                            ),
                        ],
                        onChanged: q.sending
                            ? null
                            : (id) => q.pickService(
                                id == null ? null : _optionsWith(options, q.service).firstWhere((s) => s.id == id),
                              ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              if (product == null)
                _Field(
                  label: 'Project scope / area',
                  child: TextField(
                    key: const ValueKey('quote-scope'),
                    controller: q.scope,
                    enabled: !q.sending,
                    maxLength: QuoteLimits.scope,
                    style: MartText.sheetRow.copyWith(fontSize: 14),
                    decoration: _decoration(hint: 'e.g. 50,000 sq ft, 14 towers'),
                  ),
                ),
              const SizedBox(height: 4),
              _Field(
                label: 'Target timeline',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in QuoteTimeline.values)
                      _Choice(
                        key: ValueKey('timeline-${t.name}'),
                        label: t.label,
                        on: q.timeline == t,
                        onTap: q.sending ? null : () => q.pickTimeline(t),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _Field(
                label: 'Brief project notes',
                child: TextField(
                  key: const ValueKey('quote-notes'),
                  controller: q.notes,
                  enabled: !q.sending,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: QuoteLimits.notes,
                  style: MartText.sheetRow.copyWith(fontSize: 14),
                  decoration: _decoration(hint: 'Add specific requirements: building height, access, working hours...'),
                ),
              ),
              if (q.needsPhone) ...[
                const SizedBox(height: 4),
                _Field(
                  label: 'Your mobile number',
                  child: TextField(
                    key: const ValueKey('quote-phone'),
                    controller: q.phone,
                    enabled: !q.sending,
                    keyboardType: TextInputType.phone,
                    style: MartText.sheetRow.copyWith(fontSize: 14),
                    decoration: _decoration(
                      hint: '+91 98765 43210',
                      error: q.phoneProblem,
                      helper:
                          '${supplier.name} may answer by phone. It is saved to your profile, not shown on the request.',
                    ),
                  ),
                ),
              ],
              if (q.error != null) ...[
                const SizedBox(height: 8),
                Container(
                  key: const ValueKey('quote-error'),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    q.error!,
                    style: MartText.sheetRow.copyWith(color: AppColors.onErrorContainer, fontSize: 13),
                  ),
                ),
                if (q.needsCompany) ...[
                  const SizedBox(height: 8),
                  // A requirement is a company's: the way out is to found one, in the app, with this form kept.
                  OutlinedButton.icon(
                    key: const ValueKey('quote-create-company'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => MarketplaceScope.navigationOf(context).createCompany(context),
                    icon: const Icon(LucideIcons.building2, size: 16),
                    label: Text('Create a company', style: MartText.sheetButton.copyWith(color: AppColors.primary)),
                  ),
                ],
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                key: const ValueKey('quote-send'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: q.sending ? null : q.submit,
                icon: q.sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(LucideIcons.send, size: 16),
                label: Text(q.sending ? 'Sending...' : 'Submit quote request', style: MartText.sheetButton),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The supplier's services, with the one the request names added when the
/// supplier's own list does not hold it.
List<CatalogService> _optionsWith(List<CatalogService> options, CatalogService? chosen) => [
  ...options,
  if (chosen != null && !options.any((s) => s.id == chosen.id)) chosen,
];

InputDecoration _decoration({String? hint, String? error, String? helper, String? suffix}) => InputDecoration(
  hintText: hint,
  hintStyle: MartText.sheetRowMuted.copyWith(fontSize: 14),
  errorText: error,
  helperText: helper,
  helperMaxLines: 3,
  suffixText: suffix,
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: AppColors.outlineVariant),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: AppColors.outlineVariant),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
  ),
);

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(label, style: MartText.sheetSection),
      ),
      child,
    ],
  );
}

class _Choice extends StatelessWidget {
  const _Choice({super.key, required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = StadiumBorder(side: BorderSide(color: on ? AppColors.primary : AppColors.outlineVariant));
    return Semantics(
      button: true,
      selected: on,
      child: Material(
        color: on ? AppColors.primary : Colors.white,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            child: Text(
              label,
              style: MartText.sheetRow.copyWith(color: on ? Colors.white : AppColors.onSurface, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductSummary extends StatelessWidget {
  const _ProductSummary({required this.product});

  final CatalogProduct product;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: MartColors.cardBorder, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Product', style: MartText.sheetRowMuted),
                const SizedBox(height: 2),
                Text(
                  product.name,
                  style: MartText.sheetRow.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (product.priceLabel != null) Text(product.priceLabel!, style: MartText.sheetRow),
        ],
      ),
    );
  }
}

class _Sent extends StatelessWidget {
  const _Sent({required this.sent});

  final QuoteSent sent;

  @override
  Widget build(BuildContext context) {
    final q = context.watch<QuoteController>();
    final nav = MarketplaceScope.navigationOf(context);
    final links = MarketplaceScope.linksOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: AppColors.successTint, shape: BoxShape.circle),
            child: const Icon(LucideIcons.check, size: 28, color: AppColors.successInk),
          ),
          const SizedBox(height: 14),
          Text('Request sent', key: const ValueKey('quote-sent'), style: MartText.sheetTitle),
          const SizedBox(height: 6),
          Text(
            '${q.supplier.name} has your request and will answer on it. You will be told when a quote comes in.',
            textAlign: TextAlign.center,
            style: MartText.sheetRowMuted.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              key: const ValueKey('quote-view'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(context);
                nav.openRfq(context, links, sent.id);
              },
              child: Text('View my request', style: MartText.sheetButton),
            ),
          ),
          TextButton(
            key: const ValueKey('quote-done'),
            onPressed: () => Navigator.pop(context),
            child: Text('Done', style: MartText.sheetLink),
          ),
        ],
      ),
    );
  }
}
