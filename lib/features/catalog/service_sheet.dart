import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../account/widgets/account_kit.dart';
import '../site/site_kit.dart';
import 'catalog_models.dart';
import 'catalog_parts.dart';
import 'catalog_words.dart';

/// Sends the draft; null when it went, else the API's sentence.
typedef SendService = Future<String?> Function(ServiceDraft draft);

/// The website's `ServiceSlideOver` as a sheet: the basic details (name, the category pair, description), the
/// pricing, the delivery and, on a new service, the marketplace-visibility switch. [focus] puts the cursor in the
/// field a row's "Add …" chip named. True when saved.
Future<bool> showServiceSheet(
  BuildContext context, {
  required ServiceItem? editing,
  required List<CatalogCategory> tops,
  required SendService send,
  ServiceSignal? focus,
}) async =>
    await showEditSheet<bool>(
      context,
      builder: (_) => ServiceSheet(editing: editing, tops: tops, send: send, focus: focus),
    ) ??
    false;

class ServiceSheet extends StatefulWidget {
  const ServiceSheet({super.key, required this.editing, required this.tops, required this.send, this.focus});

  final ServiceItem? editing;
  final List<CatalogCategory> tops;
  final SendService send;
  final ServiceSignal? focus;

  @override
  State<ServiceSheet> createState() => _ServiceSheetState();
}

class _ServiceSheetState extends State<ServiceSheet> {
  late final ServiceDraft _initial = widget.editing == null ? const ServiceDraft() : ServiceDraft.of(widget.editing!);
  late ServiceDraft _draft = _initial;
  late final _name = TextEditingController(text: _initial.name);
  late final _description = TextEditingController(text: _initial.description);
  late final _rate = TextEditingController(text: _initial.rate);
  late final _rateUnit = TextEditingController(text: _initial.rateUnit);
  late final _turnaround = TextEditingController(text: _initial.turnaroundTime);
  final _focusNodes = {
    for (final s in [
      ServiceSignal.name,
      ServiceSignal.description,
      ServiceSignal.rate,
      ServiceSignal.rateUnit,
      ServiceSignal.turnaroundTime,
    ])
      s: FocusNode(),
  };

  bool _touched = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final node = widget.focus == null ? null : _focusNodes[widget.focus];
    if (node != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) node.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _rate.dispose();
    _rateUnit.dispose();
    _turnaround.dispose();
    for (final n in _focusNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  void _set(ServiceDraft next) => setState(() => _draft = next);

  String? get _nameError => _touched && _draft.name.trim().isEmpty ? CatalogWords.serviceNameRequired : null;
  String? get _categoryError => _touched && _draft.category.isEmpty ? CatalogWords.categoryRequired : null;

  bool get _canSave => _draft.name.trim().isNotEmpty && _draft.category.isNotEmpty && !_draft.rateInvalid && !_saving;

  Future<void> _save() async {
    setState(() => _touched = true);
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final refusal = await widget.send(_draft);
    if (!mounted) return;
    if (refusal == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _error = refusal;
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing != null;
    return EditSheet(
      title: editing ? CatalogWords.editService : CatalogWords.addAService,
      subtitle: editing ? CatalogWords.serviceEditSubtitle : CatalogWords.serviceAddSubtitle,
      saveLabel: editing ? CatalogWords.saveChanges : CatalogWords.publishService,
      saving: _saving,
      error: _error,
      dirty: _draft != _initial,
      onSave: _canSave ? _save : null,
      children: [
        SheetSection(
          icon: Symbols.info,
          title: CatalogWords.basicDetails,
          children: [
            AccountField(
              fieldKey: const Key('service.name'),
              label: CatalogWords.serviceName,
              controller: _name,
              focusNode: _focusNodes[ServiceSignal.name],
              required: true,
              error: _nameError,
              textCapitalization: TextCapitalization.words,
              onChanged: (v) => _set(_draft.copyWith(name: v)),
            ),
            // Category, then an optional sub-category; both stored. The second box waits for the first.
            CategoryCascadeField(
              tops: widget.tops,
              category: _draft.category,
              subcategory: _draft.subcategory,
              required: true,
              error: _categoryError,
              onChanged: (category, subcategory) => _set(_draft.copyWith(category: category, subcategory: subcategory)),
            ),
            AccountField(
              fieldKey: const Key('service.description'),
              label: CatalogWords.description,
              controller: _description,
              focusNode: _focusNodes[ServiceSignal.description],
              minLines: 3,
              maxLines: 8,
              helper: CatalogWords.serviceDescriptionHelper,
              onChanged: (v) => _set(_draft.copyWith(description: v)),
            ),
          ],
        ),
        const SheetRule(),
        SheetSection(
          icon: Symbols.sell,
          title: CatalogWords.pricing,
          hint: CatalogWords.shownToBuyersAsThe,
          children: [
            AccountField(
              fieldKey: const Key('service.rate'),
              label: '${CatalogWords.startingPrice} (₹)',
              controller: _rate,
              focusNode: _focusNodes[ServiceSignal.rate],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              error: _draft.rateInvalid ? CatalogWords.priceInvalid : null,
              onChanged: (v) {
                final clean = v.replaceAll(RegExp(r'[^\d.]'), '');
                if (clean != v) {
                  _rate.value = TextEditingValue(
                    text: clean,
                    selection: TextSelection.collapsed(offset: clean.length),
                  );
                }
                _set(_draft.copyWith(rate: clean));
              },
            ),
            AccountField(
              fieldKey: const Key('service.rateUnit'),
              label: CatalogWords.pricingModel,
              controller: _rateUnit,
              focusNode: _focusNodes[ServiceSignal.rateUnit],
              hint: CatalogWords.perVisit,
              textCapitalization: TextCapitalization.none,
              onChanged: (v) => _set(_draft.copyWith(rateUnit: v)),
            ),
            SuggestionChips(
              options: pricingModels,
              value: _draft.rateUnit,
              onPick: (m) {
                _rateUnit.text = m;
                _set(_draft.copyWith(rateUnit: m));
              },
            ),
          ],
        ),
        const SheetRule(),
        SheetSection(
          icon: Symbols.local_shipping,
          title: CatalogWords.serviceDelivery,
          children: [
            AccountField(
              fieldKey: const Key('service.turnaround'),
              label: CatalogWords.turnaroundTime,
              controller: _turnaround,
              focusNode: _focusNodes[ServiceSignal.turnaroundTime],
              hint: CatalogWords.turnaroundPlaceholder,
              onChanged: (v) => _set(_draft.copyWith(turnaroundTime: v)),
            ),
          ],
        ),
        const SheetRule(),
        SheetSection(
          icon: Symbols.storefront,
          title: CatalogWords.marketplaceVisibility,
          hint: CatalogWords.controlHowThisServiceSurfaces,
          children: [
            if (!editing)
              // Names what the API will add: the sub-category, else the category.
              SwitchListTile.adaptive(
                key: const Key('service.addToListing'),
                contentPadding: EdgeInsets.zero,
                value: _draft.addToListing,
                activeTrackColor: AppColors.primary,
                title: Text(
                  _draft.subcategory.isNotEmpty ? CatalogWords.addSubCategoryToMy : CatalogWords.addCategoryToMy,
                  style: SiteText.strong,
                ),
                subtitle: Text(
                  _draft.subcategory.isNotEmpty
                      ? CatalogWords.helpsBuyersFindSubCategory
                      : CatalogWords.helpsBuyersFindCategory,
                  style: SiteText.meta,
                ),
                onChanged: (on) => _set(_draft.copyWith(addToListing: on)),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.visibility_outlined, size: 16, color: AppColors.slate500),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(CatalogWords.featuredPlacementSoon, style: SiteText.meta)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
