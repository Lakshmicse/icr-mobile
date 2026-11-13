import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/api/api_error.dart';
import '../../core/theme/app_colors.dart';
import '../account/account_models.dart' show PickedPhoto;
import '../account/widgets/account_kit.dart';
import '../site/site_kit.dart';
import 'catalog_models.dart';
import 'catalog_parts.dart';
import 'catalog_photo_picker.dart';
import 'catalog_words.dart';

/// Sends the draft; null when it went, else the API's sentence.
typedef SendProduct = Future<String?> Function(ProductDraft draft, {required bool categoryChanged});

/// Uploads a photo and answers the `/uploads/...` path the product stores.
typedef UploadPhoto = Future<String> Function(PickedPhoto photo);

/// The website's `ProductSlideOver` as a sheet: the photo, the basic details, the pricing and the supplier's terms,
/// in that order, with the listing-strength checklist the cards score by. True when saved.
Future<bool> showProductSheet(
  BuildContext context, {
  required ProductItem? editing,
  required List<CatalogCategory> tops,
  required CatalogPhotoPicker picker,
  required UploadPhoto upload,
  required SendProduct send,
}) async =>
    await showEditSheet<bool>(
      context,
      builder: (_) => ProductSheet(editing: editing, tops: tops, picker: picker, upload: upload, send: send),
    ) ??
    false;

class ProductSheet extends StatefulWidget {
  const ProductSheet({
    super.key,
    required this.editing,
    required this.tops,
    required this.picker,
    required this.upload,
    required this.send,
  });

  final ProductItem? editing;
  final List<CatalogCategory> tops;
  final CatalogPhotoPicker picker;
  final UploadPhoto upload;
  final SendProduct send;

  @override
  State<ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends State<ProductSheet> {
  late final ProductDraft _initial = widget.editing == null
      ? const ProductDraft()
      : ProductDraft.of(widget.editing!, widget.tops);
  late ProductDraft _draft = _initial;
  late final _name = TextEditingController(text: _initial.name);
  late final _description = TextEditingController(text: _initial.description);
  late final _price = TextEditingController(text: _initial.price);
  late final _unit = TextEditingController(text: _initial.unit);
  late final _terms = {for (final t in ProductTerm.values) t: TextEditingController(text: _initial.term(t))};

  bool _categoryChanged = false;
  bool _touched = false;
  bool _saving = false;
  bool _uploading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _unit.dispose();
    for (final c in _terms.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _set(ProductDraft next) => setState(() => _draft = next);

  /// A category the tree cannot place — filed before the taxonomy changed — is kept unless another is picked.
  String? get _unplacedCategory {
    final was = widget.editing?.category;
    if (was == null || _categoryChanged || _draft.category.isNotEmpty) return null;
    return was.name;
  }

  String get _categoryName {
    final leaf = _draft.leaf;
    return leaf.isNotEmpty ? categoryLabelOf(widget.tops, leaf) : (_unplacedCategory ?? '');
  }

  /// The draft scored as the cards score a product (a kept, unplaced category counts).
  ProductItem get _asItem {
    final item = _draft.asItem;
    if (item.category != null || _unplacedCategory == null) return item;
    return ProductItem(
      id: item.id,
      name: item.name,
      description: item.description,
      price: item.price,
      unit: item.unit,
      imageUrl: item.imageUrl,
      category: widget.editing!.category,
    );
  }

  String? get _nameError => _touched && _draft.name.trim().isEmpty ? CatalogWords.productNameRequired : null;
  String? get _priceError => _draft.priceInvalid ? CatalogWords.priceInvalid : null;

  bool get _canSave =>
      _draft.name.trim().isNotEmpty && !_draft.priceInvalid && !_draft.termsInvalid && !_saving && !_uploading;

  Future<void> _save() async {
    setState(() => _touched = true);
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final refusal = await widget.send(_draft, categoryChanged: _categoryChanged);
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
    final unitWord = _draft.unit.trim().isEmpty ? CatalogWords.units : _draft.unit.trim();
    return EditSheet(
      title: editing ? CatalogWords.editProduct : CatalogWords.addAProduct,
      subtitle: editing ? CatalogWords.productEditSubtitle : CatalogWords.productAddSubtitle,
      saveLabel: editing ? CatalogWords.saveChanges : CatalogWords.publishProduct,
      saving: _saving,
      error: _error,
      dirty: _draft != _initial,
      onSave: _canSave ? _save : null,
      children: [
        SheetSection(
          icon: Symbols.photo_camera,
          title: CatalogWords.photo,
          hint: CatalogWords.theFirstThingBuyersSee,
          children: [
            ProductPhotoField(
              value: _draft.imageUrl,
              picker: widget.picker,
              upload: widget.upload,
              onChanged: (url) => _set(_draft.copyWith(imageUrl: url)),
              onBusy: (busy) => setState(() => _uploading = busy),
            ),
          ],
        ),
        const SheetRule(),
        SheetSection(
          icon: Symbols.info,
          title: CatalogWords.basicDetails,
          children: [
            AccountField(
              fieldKey: const Key('product.name'),
              label: CatalogWords.productName,
              controller: _name,
              required: true,
              hint: 'Taski R3 Cleaner 5L',
              helper: CatalogWords.nameHelper,
              error: _nameError,
              textCapitalization: TextCapitalization.words,
              onChanged: (v) => _set(_draft.copyWith(name: v)),
            ),
            CategoryCascadeField(
              tops: widget.tops,
              category: _draft.category,
              subcategory: _draft.subcategory,
              clearable: true,
              helper: _unplacedCategory != null
                  ? CatalogWords.filedUnder(_unplacedCategory!)
                  : CatalogWords.categoryHelper,
              onChanged: (category, subcategory) {
                _categoryChanged = true;
                _set(_draft.copyWith(category: category, subcategory: subcategory));
              },
            ),
            AccountField(
              fieldKey: const Key('product.description'),
              label: CatalogWords.description,
              controller: _description,
              minLines: 3,
              maxLines: 8,
              helper: CatalogWords.productDescriptionHelper,
              onChanged: (v) => _set(_draft.copyWith(description: v)),
            ),
          ],
        ),
        const SheetRule(),
        SheetSection(
          icon: Symbols.sell,
          title: CatalogWords.pricing,
          hint: CatalogWords.leaveThePriceBlank,
          children: [
            AccountField(
              fieldKey: const Key('product.price'),
              label: '${CatalogWords.price} (₹)',
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              helper: CatalogWords.beforeGst,
              error: _priceError,
              onChanged: (v) {
                final clean = v.replaceAll(RegExp(r'[^\d.]'), '');
                if (clean != v) {
                  _price.value = TextEditingValue(
                    text: clean,
                    selection: TextSelection.collapsed(offset: clean.length),
                  );
                }
                _set(_draft.copyWith(price: clean));
              },
            ),
            AccountField(
              fieldKey: const Key('product.unit'),
              label: CatalogWords.soldPer,
              controller: _unit,
              hint: CatalogWords.unitPlaceholder,
              helper: CatalogWords.pieceBoxLitre,
              textCapitalization: TextCapitalization.none,
              onChanged: (v) => _set(_draft.copyWith(unit: v)),
            ),
            SuggestionChips(
              options: productUnits,
              value: _draft.unit,
              onPick: (u) {
                _unit.text = u;
                _set(_draft.copyWith(unit: u));
              },
            ),
          ],
        ),
        const SheetRule(),
        SheetSection(
          icon: Symbols.local_shipping,
          title: CatalogWords.stockTerms,
          hint: CatalogWords.optionalSayOnlyWhatYou,
          children: [
            AccountSelectField(
              key: const Key('product.availability'),
              label: CatalogWords.availability,
              hint: CatalogWords.notStated,
              value: _draft.availability.isEmpty ? null : productAvailabilityLabel(_draft.availability),
              helper: CatalogWords.aBadgeOnTheProduct,
              onTap: () async {
                final picked = await showAccountPicker<String>(
                  context,
                  title: CatalogWords.availability,
                  items: ['', ...productAvailabilities],
                  labelOf: productAvailabilityLabel,
                  selected: _draft.availability,
                );
                if (picked != null) _set(_draft.copyWith(availability: picked));
              },
              onClear: _draft.availability.isEmpty ? null : () => _set(_draft.copyWith(availability: '')),
            ),
            for (final t in ProductTerm.values) _termField(t, unitWord),
          ],
        ),
        const SheetRule(),
        StrengthChecklist(item: _asItem, categoryName: _categoryName),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _termField(ProductTerm t, String unitWord) {
    final (label, end, blank) = switch (t) {
      ProductTerm.warrantyMonths => (CatalogWords.warranty, CatalogWords.months, CatalogWords.leaveBlank),
      ProductTerm.returnDays => (CatalogWords.returnsWithin, CatalogWords.days, CatalogWords.leaveBlank),
      ProductTerm.freeDeliveryOver => ('${CatalogWords.freeDeliveryOver} (₹)', null, CatalogWords.zeroShipsFree),
      ProductTerm.bulkPricingMinQty => (CatalogWords.bulkPricingFrom, unitWord, CatalogWords.bulkQuantity),
    };
    final raw = _draft.term(t);
    final error = productTermError(t, raw);
    final sentence = productTermSentence(t, raw, _draft.unit);
    return AccountField(
      fieldKey: Key('product.term.${t.name}'),
      label: label,
      controller: _terms[t]!,
      keyboardType: TextInputType.number,
      helper: sentence != null ? CatalogWords.buyersSee(sentence) : blank,
      error: error,
      suffix: end == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(right: 12, top: 13),
              child: Text(end, style: AccountText.meta),
            ),
      onChanged: (v) {
        final clean = v.replaceAll(RegExp(r'\D'), '');
        if (clean != v) {
          _terms[t]!.value = TextEditingValue(
            text: clean,
            selection: TextSelection.collapsed(offset: clean.length),
          );
        }
        _set(_draft.withTerm(t, clean));
      },
    );
  }
}

/// The product photo (`ProductPhotoField`): a 4:3 frame holding the picture, with Replace and Remove under it;
/// empty, the frame itself is the upload button. The file goes up through `/uploads?purpose=catalog` at once, and
/// what the product stores is the path that comes back.
class ProductPhotoField extends StatefulWidget {
  const ProductPhotoField({
    super.key,
    required this.value,
    required this.picker,
    required this.upload,
    required this.onChanged,
    this.onBusy,
  });

  /// The stored `/uploads/...` path or URL; '' for none.
  final String value;
  final CatalogPhotoPicker picker;
  final UploadPhoto upload;
  final ValueChanged<String> onChanged;

  /// Told while an upload is on its way, so the sheet holds its Save.
  final ValueChanged<bool>? onBusy;

  @override
  State<ProductPhotoField> createState() => _ProductPhotoFieldState();
}

class _ProductPhotoFieldState extends State<ProductPhotoField> {
  /// The picture just picked, drawn in place of a fetch of what was uploaded.
  Uint8List? _bytes;
  bool _uploading = false;
  String? _error;

  Future<void> _pick() async {
    setState(() => _error = null);
    final photo = await widget.picker.pick();
    if (photo == null || !mounted) return;
    final problem = catalogPhotoProblem(photo);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() => _uploading = true);
    widget.onBusy?.call(true);
    try {
      final url = await widget.upload(photo);
      if (!mounted) return;
      setState(() => _bytes = Uint8List.fromList(photo.bytes));
      widget.onChanged(url);
    } catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _uploading = false);
      widget.onBusy?.call(false);
    }
  }

  void _remove() {
    setState(() {
      _bytes = null;
      _error = null;
    });
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final has = widget.value.isNotEmpty;
    final Widget picture = has
        ? (_bytes != null
              ? Image.memory(_bytes!, fit: BoxFit.cover, errorBuilder: (_, _, _) => _empty())
              : AccountImage(source: widget.value, fallback: _empty(prompt: false)))
        : _empty();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: !has,
            label: has ? CatalogWords.replacePhoto : CatalogWords.uploadPhoto,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                key: const Key('product.photo'),
                height: 180,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  border: Border.all(color: SiteColors.hairline),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    has
                        ? picture
                        : InkWell(
                            key: const Key('product.photo.upload'),
                            onTap: _uploading ? null : _pick,
                            child: picture,
                          ),
                    if (_uploading)
                      Container(
                        color: const Color(0xB3FFFFFF),
                        alignment: Alignment.center,
                        child: const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (has)
            Row(
              children: [
                TextButton.icon(
                  key: const Key('product.photo.replace'),
                  onPressed: _uploading ? null : _pick,
                  icon: const Icon(Symbols.swap_horiz, size: 18),
                  label: Text(CatalogWords.replace),
                ),
                TextButton.icon(
                  key: const Key('product.photo.remove'),
                  onPressed: _uploading ? null : _remove,
                  style: TextButton.styleFrom(foregroundColor: AppColors.rose600),
                  icon: const Icon(Symbols.delete, size: 18),
                  label: Text(CatalogWords.remove),
                ),
              ],
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_error!, key: const Key('product.photo.error'), style: AccountText.error),
            ),
        ],
      ),
    );
  }

  Widget _empty({bool prompt = true}) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Symbols.add_photo_alternate, size: 36, color: AppColors.primary),
          if (prompt) ...[
            const SizedBox(height: 6),
            Text(CatalogWords.uploadPhoto, style: SiteText.strong, textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text(CatalogWords.photoHelper, style: SiteText.meta, textAlign: TextAlign.center),
          ],
        ],
      ),
    ),
  );
}

/// What is still missing, as a ticked list — the same six signals the rows score (`StrengthChecklist`).
class StrengthChecklist extends StatelessWidget {
  const StrengthChecklist({super.key, required this.item, required this.categoryName});

  final ProductItem item;
  final String categoryName;

  @override
  Widget build(BuildContext context) {
    final missing = item.missing;
    return Column(
      key: const Key('product.strength'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StrengthBar(score: item.score),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            for (final s in ProductSignal.values)
              SizedBox(
                width: 150,
                child: Row(
                  children: [
                    Icon(
                      missing.contains(s) ? Symbols.radio_button_unchecked : Symbols.check_circle,
                      size: 16,
                      color: missing.contains(s) ? AppColors.slate300 : AppColors.success,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        s == ProductSignal.category && categoryName.isNotEmpty ? categoryName : productSignalLabel(s),
                        style: missing.contains(s) ? SiteText.meta : SiteText.meta.copyWith(color: SiteColors.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
