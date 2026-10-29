import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../post_rfq_controller.dart';
import '../rfq_checklist.dart';
import '../rfq_format.dart';
import '../rfq_links.dart' show RfqClock;
import '../rfq_models.dart';
import '../rfq_rules.dart';
import '../rfq_styles.dart';
import 'rfq_widgets.dart';

/// One numbered block of the composer: a step circle (a tick once it is complete), its title and what it is for.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.step,
    required this.title,
    required this.child,
    this.caption,
    this.done = false,
    this.optional = false,
  });

  final int step;
  final String title;
  final String? caption;
  final Widget child;
  final bool done;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return RfqCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? AppColors.emerald700 : AppColors.primary,
                ),
                child: done
                    ? const Icon(LucideIcons.check, size: 13, color: Colors.white)
                    : Text('$step', style: RfqText.step),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: RfqText.section)),
              if (optional) Text('Optional', style: RfqText.small),
            ],
          ),
          if (caption != null) ...[const SizedBox(height: 4), Text(caption!, style: RfqText.formHelp)],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Enquiry or RFQ: two cards, the one chosen outlined in blue. Locked while editing (a requirement keeps its kind).
class KindPicker extends StatelessWidget {
  const KindPicker({super.key, required this.value, required this.onChanged, this.locked = false});

  final RfqKind value;
  final ValueChanged<RfqKind> onChanged;
  final bool locked;

  static const _words = {
    RfqKind.enquiry: (
      short: 'ENQUIRY',
      title: 'Quick supplier matching',
      body: 'Get responses, questions and indicative pricing from matched suppliers.',
      best: 'the quickest response',
    ),
    RfqKind.rfq: (
      short: 'RFQ',
      title: 'Formal quotation process',
      body: 'Suppliers pre-qualify against your criteria, then your shortlist sends detailed quotes.',
      best: 'larger or formal procurement',
    ),
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final kind in RfqKind.values) ...[
          if (kind != RfqKind.values.first) const SizedBox(height: 10),
          Builder(
            builder: (context) {
              final on = kind == value;
              final w = _words[kind]!;
              return Semantics(
                button: true,
                selected: on,
                inMutuallyExclusiveGroup: true,
                label: kind.label,
                child: Material(
                  color: on ? AppColors.chipEmphasis.withValues(alpha: 0.5) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: on ? AppColors.primary : AppColors.slate200, width: on ? 1.5 : 1),
                  ),
                  child: InkWell(
                    key: ValueKey('kind-${kind.wire.toLowerCase()}'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: locked && !on ? null : () => onChanged(kind),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  w.short,
                                  style: RfqText.kicker.copyWith(color: on ? AppColors.primary : AppColors.slate500),
                                ),
                                const SizedBox(height: 3),
                                Text(w.title, style: RfqText.cardTitle),
                                const SizedBox(height: 6),
                                Text(w.body, style: RfqText.body),
                                const SizedBox(height: 6),
                                Text.rich(
                                  TextSpan(
                                    text: 'Best for: ',
                                    style: RfqText.metaStrong,
                                    children: [TextSpan(text: w.best, style: RfqText.meta)],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            on ? LucideIcons.circleCheck : LucideIcons.circle,
                            size: 20,
                            color: on ? AppColors.primary : AppColors.slate300,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

/// "What suppliers usually ask": each detail ticks itself once the text mentions it, and an unticked one offers
/// to add a labelled line for the buyer to complete.
class DescriptionChecklist extends StatelessWidget {
  const DescriptionChecklist({super.key, required this.text, required this.onAdd});

  final String text;
  final ValueChanged<String> onAdd;

  @override
  Widget build(BuildContext context) {
    final items = checklistFor(text);
    final covered = items.where((i) => i.done).length;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
      decoration: BoxDecoration(
        color: rfqPanelColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('What suppliers usually ask', style: RfqText.bodyStrong)),
              Text('$covered of ${items.length} covered', key: const ValueKey('checklist-count'), style: RfqText.small),
            ],
          ),
          const SizedBox(height: 2),
          Text('Answering these up front saves a round of questions.', style: RfqText.formHelp),
          const SizedBox(height: 4),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                key: ValueKey('check-${item.id.name}'),
                children: [
                  Icon(
                    item.done ? LucideIcons.circleCheck : LucideIcons.circle,
                    size: 17,
                    color: item.done ? AppColors.emerald700 : AppColors.slate300,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.id.label,
                          style: RfqText.meta.copyWith(color: item.done ? AppColors.slate500 : AppColors.slate900),
                        ),
                        if (!item.done) Text(item.id.hint, style: RfqText.small),
                      ],
                    ),
                  ),
                  if (!item.done)
                    TextButton(
                      key: ValueKey('check-add-${item.id.name}'),
                      onPressed: () => onAdd(item.id.label),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Text('Add', style: RfqText.link),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---- Places ---------------------------------------------------------------------------------

/// The service locations: one chip each, and a button that opens the place search.
class PlacesField extends StatelessWidget {
  const PlacesField({super.key, required this.places, required this.onAdd, required this.onRemove, this.error});

  final List<RfqPlace> places;
  final VoidCallback onAdd;
  final ValueChanged<RfqPlace> onRemove;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final full = places.length >= RfqLimits.maxLocations;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('Service locations'),
        const SizedBox(height: 6),
        if (places.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in places)
                  Container(
                    key: ValueKey('place-chip-${p.label}'),
                    padding: const EdgeInsets.only(left: 10, right: 2),
                    decoration: BoxDecoration(color: AppColors.chipEmphasis, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(p.label, style: RfqText.pill.copyWith(color: AppColors.primary)),
                        ),
                        IconButton(
                          tooltip: 'Remove ${p.label}',
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          padding: EdgeInsets.zero,
                          onPressed: () => onRemove(p),
                          icon: const Icon(LucideIcons.x, size: 14, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        InkWell(
          key: const ValueKey('places-add'),
          onTap: onAdd,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            constraints: const BoxConstraints(minHeight: 46),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: error != null ? AppColors.error : AppColors.slate200),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.mapPin, size: 18, color: AppColors.slate400),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    full ? 'The most places (${RfqLimits.maxLocations}) are added' : 'Search a city or a place',
                    style: RfqText.formHint,
                  ),
                ),
                const Icon(LucideIcons.search, size: 18, color: AppColors.slate500),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        if (error != null)
          Text(error!, style: RfqText.error)
        else
          Text('Each place keeps its own state and country. Add every city the work covers.', style: RfqText.formHelp),
      ],
    );
  }
}

/// The place search, in a sheet: type, tap a result to add it (the sheet stays open for the next), or add what
/// was typed as it stands. Places already added show a tick.
Future<void> showPlaceSheet(BuildContext context, PostRfqController controller) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (context) => _PlaceSheet(controller: controller),
  );
}

class _PlaceSheet extends StatefulWidget {
  const _PlaceSheet({required this.controller});

  final PostRfqController controller;

  @override
  State<_PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends State<_PlaceSheet> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<RfqPlace> _results = const [];
  bool _searching = false;
  String? _error;
  int _generation = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _changed(String text) {
    _debounce?.cancel();
    if (text.trim().length < 2) {
      setState(() {
        _results = const [];
        _searching = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(text));
  }

  Future<void> _search(String text) async {
    final generation = ++_generation;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final found = await widget.controller.searchPlaces(text);
      if (!mounted || generation != _generation) return;
      setState(() => _results = found);
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _results = const [];
        _error = 'The place search is not available right now. You can still add what you typed.';
      });
    } finally {
      if (mounted && generation == _generation) setState(() => _searching = false);
    }
  }

  void _add(RfqPlace place) {
    final c = widget.controller;
    if (!c.addPlace(place)) {
      setState(() => _error = 'You can add at most ${RfqLimits.maxLocations} places.');
      return;
    }
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final typed = _query.text.trim();
    final exact = _results.any((p) => p.label.toLowerCase() == typed.toLowerCase());
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Row(
                    children: [
                      Expanded(child: Text('Service locations', style: RfqText.sheetTitle)),
                      Text('${c.draft.places.length} of ${RfqLimits.maxLocations}', style: RfqText.small),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    key: const ValueKey('place-search'),
                    controller: _query,
                    autofocus: true,
                    onChanged: _changed,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _search,
                    style: RfqText.formInput,
                    decoration: rfqInputDecoration(hint: 'Search a city or a place', prefix: LucideIcons.search),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                    child: Text(_error!, style: RfqText.error),
                  ),
                Expanded(
                  child: ListView(
                    children: [
                      if (_searching) const Padding(padding: EdgeInsets.all(16), child: RfqSpinner(size: 20)),
                      for (final p in _results)
                        ListTile(
                          key: ValueKey('place-option-${p.label}'),
                          title: Text(p.label, style: RfqText.bodyStrong),
                          subtitle: p.hint.isEmpty ? null : Text(p.hint, style: RfqText.small),
                          trailing: c.draft.places.contains(p)
                              ? const Icon(LucideIcons.check, size: 18, color: AppColors.primary)
                              : const Icon(LucideIcons.plus, size: 18, color: AppColors.slate500),
                          onTap: () => c.draft.places.contains(p) ? c.removePlace(p) : _add(p),
                        ),
                      if (typed.length >= 2 && !_searching && !exact)
                        ListTile(
                          key: const ValueKey('place-typed'),
                          leading: const Icon(LucideIcons.pencil, size: 18, color: AppColors.slate500),
                          title: Text('Add "$typed"', style: RfqText.bodyStrong),
                          subtitle: Text('As typed, without a state or country', style: RfqText.small),
                          onTap: () => _add(RfqPlace.typed(typed)),
                        ),
                      if (typed.length < 2 && c.draft.places.isNotEmpty)
                        for (final p in c.draft.places)
                          ListTile(
                            title: Text(p.label, style: RfqText.body),
                            subtitle: p.hint.isEmpty ? null : Text(p.hint, style: RfqText.small),
                            trailing: IconButton(
                              tooltip: 'Remove ${p.label}',
                              onPressed: () => c.removePlace(p),
                              icon: const Icon(LucideIcons.x, size: 18, color: AppColors.slate500),
                            ),
                          ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                  child: FilledButton(
                    key: const ValueKey('place-done'),
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Done'),
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

// ---- Line items -----------------------------------------------------------------------------

/// A line of what is wanted, to add or change: name, quantity, unit and specification, checked as the API does.
Future<RfqItem?> showItemSheet(BuildContext context, {RfqItem? item}) {
  return showModalBottomSheet<RfqItem>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (context) => _ItemSheet(item: item),
  );
}

class _ItemSheet extends StatefulWidget {
  const _ItemSheet({this.item});

  final RfqItem? item;

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  late String _name = widget.item?.name ?? '';
  late String _quantity = '${widget.item?.quantity ?? 1}';
  late String _unit = widget.item?.unit ?? '';
  late String _spec = widget.item?.specification ?? '';
  String? _problem;

  void _save() {
    final q = int.tryParse(_quantity.trim());
    final item = RfqItem(
      name: _name,
      quantity: q ?? 0,
      unit: _unit.trim().isEmpty ? null : _unit.trim(),
      specification: _spec.trim().isEmpty ? null : _spec.trim(),
    );
    final issue = RegExp(r'^\d+$').hasMatch(_quantity.trim()) ? itemProblem(item) : 'quantity must be a whole number';
    if (issue != null) {
      setState(() => _problem = '${issue[0].toUpperCase()}${issue.substring(1)}');
      return;
    }
    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.item == null ? 'Add a line item' : 'Change the line item', style: RfqText.sheetTitle),
              const SizedBox(height: 14),
              RfqField(
                fieldKey: const ValueKey('item-name'),
                label: 'Item',
                value: _name,
                hint: 'Floor scrubber machine',
                maxLength: RfqLimits.itemName,
                onChanged: (v) => _name = v,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: RfqField(
                      fieldKey: const ValueKey('item-quantity'),
                      label: 'Quantity',
                      value: _quantity,
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _quantity = v,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RfqField(
                      fieldKey: const ValueKey('item-unit'),
                      label: 'Unit',
                      value: _unit,
                      hint: 'units',
                      optional: true,
                      maxLength: RfqLimits.unit,
                      onChanged: (v) => _unit = v,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              RfqField(
                fieldKey: const ValueKey('item-spec'),
                label: 'Specification',
                value: _spec,
                hint: 'Battery-powered, 20-inch deck',
                optional: true,
                maxLines: 3,
                minLines: 2,
                maxLength: RfqLimits.specification,
                onChanged: (v) => _spec = v,
              ),
              if (_problem != null) ...[const SizedBox(height: 8), Text(_problem!, style: RfqText.error)],
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey('item-save'),
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(widget.item == null ? 'Add item' : 'Save item'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The line items, one row each, with a button to add another.
class ItemsList extends StatelessWidget {
  const ItemsList({
    super.key,
    required this.items,
    required this.onAdd,
    required this.onEdit,
    required this.onRemove,
    this.error,
  });

  final List<RfqItem> items;
  final VoidCallback onAdd;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onRemove;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, item) in items.indexed)
          Container(
            key: ValueKey('item-row-$i'),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.slate200),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => onEdit(i),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: RfqText.bodyStrong),
                        Text(
                          [
                            '${item.quantity}${item.unit == null ? '' : ' ${item.unit}'}',
                            if (item.specification != null) item.specification!,
                          ].join(' · '),
                          style: RfqText.small,
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove ${item.name}',
                  onPressed: () => onRemove(i),
                  icon: const Icon(LucideIcons.trash2, size: 17, color: AppColors.slate500),
                ),
              ],
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(error!, style: RfqText.error),
          ),
        if (items.length < RfqLimits.maxItems)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('item-add'),
              onPressed: onAdd,
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add a line item'),
            ),
          ),
      ],
    );
  }
}

// ---- Files ------------------------------------------------------------------------------------

/// A file's glyph: an image, a PDF or any other document.
IconData fileIconFor(String? mimeType) {
  if (mimeType == null) return LucideIcons.fileText;
  if (mimeType.startsWith('image/')) return LucideIcons.image;
  if (mimeType == 'application/pdf') return LucideIcons.fileText;
  return LucideIcons.file;
}

/// "820 KB", "1.4 MB".
String fileSizeLabel(int? bytes) {
  if (bytes == null) return '';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Attachments: each with the title the person gives it (what suppliers read), the ones still going up, the
/// ones the API refused (with a retry), and the button that opens the phone's file picker.
class AttachmentsPanel extends StatelessWidget {
  const AttachmentsPanel({
    super.key,
    required this.files,
    required this.uploads,
    required this.max,
    required this.onPick,
    required this.onTitle,
    required this.onRemove,
    required this.onRetry,
    required this.onDismiss,
    this.notice,
    this.onDismissNotice,
    this.error,
    this.busy = false,
    this.help,
  });

  final List<RfqFile> files;
  final List<PendingUpload> uploads;
  final int max;
  final VoidCallback onPick;
  final void Function(int index, String title) onTitle;
  final ValueChanged<int> onRemove;
  final ValueChanged<PendingUpload> onRetry;
  final ValueChanged<PendingUpload> onDismiss;
  final String? notice;
  final VoidCallback? onDismissNotice;
  final String? error;
  final bool busy;
  final String? help;

  @override
  Widget build(BuildContext context) {
    final full = files.length + uploads.length >= max;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, f) in files.indexed)
          Container(
            key: ValueKey('file-row-$i'),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.slate200),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: AppColors.chipEmphasis, borderRadius: BorderRadius.circular(8)),
                  child: Icon(fileIconFor(f.mimeType), size: 17, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RfqField(
                        fieldKey: ValueKey('file-title-$i'),
                        label: 'Title',
                        value: f.title,
                        hint: 'Site layout, ground floor',
                        maxLength: RfqLimits.attachmentTitle,
                        error: f.title.trim().isEmpty ? 'Give this file a title' : null,
                        onChanged: (v) => onTitle(i, v),
                      ),
                      Text(
                        [if (f.name != null) f.name!, fileSizeLabel(f.size)].where((s) => s.isNotEmpty).join(' · '),
                        style: RfqText.small,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: ValueKey('file-remove-$i'),
                  tooltip: 'Remove ${f.title.isEmpty ? (f.name ?? 'file') : f.title}',
                  onPressed: () => onRemove(i),
                  icon: const Icon(LucideIcons.trash2, size: 17, color: AppColors.slate500),
                ),
              ],
            ),
          ),
        for (final u in uploads)
          Container(
            key: ValueKey('upload-${u.name}'),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
            decoration: BoxDecoration(
              color: u.error == null ? Colors.white : AppColors.errorContainer.withValues(alpha: 0.4),
              border: Border.all(color: u.error == null ? AppColors.slate200 : AppColors.errorContainer),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                if (u.error == null)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  const Icon(LucideIcons.circleAlert, size: 20, color: AppColors.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.name, style: RfqText.metaStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        u.error ?? 'Uploading ${fileSizeLabel(u.file.size)}',
                        style: u.error == null ? RfqText.small : RfqText.error,
                      ),
                    ],
                  ),
                ),
                if (u.error != null) ...[
                  TextButton(
                    key: ValueKey('upload-retry-${u.name}'),
                    onPressed: () => onRetry(u),
                    child: Text('Retry', style: RfqText.link),
                  ),
                  IconButton(
                    tooltip: 'Remove ${u.name}',
                    onPressed: () => onDismiss(u),
                    icon: const Icon(LucideIcons.x, size: 17, color: AppColors.slate500),
                  ),
                ],
              ],
            ),
          ),
        if (notice != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: RfqBanner(notice!, action: 'Dismiss', onAction: onDismissNotice),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(error!, style: RfqText.error),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const ValueKey('attach-add'),
            onPressed: full ? null : onPick,
            icon: Icon(busy ? LucideIcons.loader : LucideIcons.paperclip, size: 16),
            label: Text(full ? 'The most ($max) files are attached' : 'Add photos or documents'),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          help ?? 'PDF, Office, text, zip or images, up to 10 MB each, $max files at most.',
          style: RfqText.formHelp,
        ),
      ],
    );
  }
}

// ---- Criteria and deadlines ----------------------------------------------------------------------

/// A statutory-compliance item, as a chip that toggles.
class ToggleChip extends StatelessWidget {
  const ToggleChip({super.key, required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = StadiumBorder(side: BorderSide(color: on ? AppColors.primary : AppColors.slate200));
    return Semantics(
      button: true,
      selected: on,
      child: Material(
        color: on ? AppColors.chipEmphasis : Colors.white,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (on) ...[
                  const Icon(LucideIcons.check, size: 13, color: AppColors.primary),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: RfqText.pill.copyWith(color: on ? AppColors.primary : AppColors.slate700, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A day, picked from the calendar: today to two years ahead (the API's horizon).
Future<DateTime?> pickDay(BuildContext context, {DateTime? current, DateTime? after, String? help}) {
  final today = todayIst(RfqClock.now());
  final first = after == null ? today : after.add(const Duration(days: 1));
  final last = today.add(const Duration(days: RfqLimits.deadlineHorizonDays));
  var initial = current ?? first;
  if (initial.isBefore(first)) initial = first;
  if (initial.isAfter(last)) initial = last;
  return showDatePicker(context: context, initialDate: initial, firstDate: first, lastDate: last, helpText: help);
}

/// A date box: shows the day (or its hint) and opens the calendar; a cross clears it.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
    this.error,
    this.help,
    this.optional = false,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final String? error;
  final String? help;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label, optional: optional),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            constraints: const BoxConstraints(minHeight: 46),
            padding: const EdgeInsets.only(left: 12, right: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: error != null ? AppColors.error : AppColors.slate200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value == null ? 'Pick a date' : pickedDay(value!),
                    style: value == null ? RfqText.formHint : RfqText.formInput,
                  ),
                ),
                if (value != null && onClear != null)
                  IconButton(
                    tooltip: 'Clear $label',
                    onPressed: onClear,
                    icon: const Icon(LucideIcons.x, size: 16, color: AppColors.slate500),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(LucideIcons.calendar, size: 18, color: AppColors.slate500),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        if (error != null)
          Text(error!, style: RfqText.error)
        else if (help != null)
          Text(help!, style: RfqText.formHelp),
      ],
    );
  }
}

// ---- The review and what follows a post -------------------------------------------------------------

/// One row of the review: what it is, what will be sent, and the section to go back to.
class ReviewRow {
  const ReviewRow({required this.label, required this.value, required this.section});

  final String label;
  final String value;
  final String section;
}

/// "This is what suppliers will read. Check it, then send." The sheet stays open when the API refuses, with its
/// sentence, so the person can send again or go back and change what it names.
Future<void> showReviewSheet(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required String note,
  required List<ReviewRow> rows,
  required Future<bool> Function() onConfirm,
  required String? Function() errorOf,
  required ValueChanged<String> onEdit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (context) => _ReviewSheet(
      title: title,
      confirmLabel: confirmLabel,
      note: note,
      rows: rows,
      onConfirm: onConfirm,
      errorOf: errorOf,
      onEdit: onEdit,
    ),
  );
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({
    required this.title,
    required this.confirmLabel,
    required this.note,
    required this.rows,
    required this.onConfirm,
    required this.errorOf,
    required this.onEdit,
  });

  final String title;
  final String confirmLabel;
  final String note;
  final List<ReviewRow> rows;
  final Future<bool> Function() onConfirm;
  final String? Function() errorOf;
  final ValueChanged<String> onEdit;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  bool _sending = false;
  String? _error;

  Future<void> _confirm() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final ok = await widget.onConfirm();
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _sending = false;
      _error = widget.errorOf();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(widget.title, style: RfqText.sheetTitle),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('This is what suppliers will read. Check it, then send.', style: RfqText.formHelp),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (final row in widget.rows)
                    Container(
                      key: ValueKey('review-${row.section}-${row.label}'),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppColors.slate100)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 96, child: Text(row.label, style: RfqText.meta)),
                          Expanded(
                            child: Text(
                              row.value.isEmpty ? 'Not given' : row.value,
                              style: row.value.isEmpty ? RfqText.small : RfqText.metaStrong,
                            ),
                          ),
                          TextButton(
                            key: ValueKey('review-edit-${row.section}'),
                            onPressed: _sending
                                ? null
                                : () {
                                    Navigator.pop(context);
                                    widget.onEdit(row.section);
                                  },
                            // As tall as its word, so it sits on the row's first line rather than hanging below it.
                            style: TextButton.styleFrom(
                              minimumSize: const Size(44, 20),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: Text('Edit', style: RfqText.link),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (_error != null) Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 0), child: RfqBanner(_error!)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Text(widget.note, style: RfqText.formHelp),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('review-keep'),
                      onPressed: _sending ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                      child: const Text('Keep editing'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('review-confirm'),
                      onPressed: _sending ? null : _confirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(widget.confirmLabel),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "N things to fix before sending", each a line that goes to its section.
class ProblemsCard extends StatelessWidget {
  const ProblemsCard({super.key, required this.problems, required this.onGo});

  /// Field name to sentence.
  final Map<String, String> problems;
  final ValueChanged<String> onGo;

  static const labels = {
    'title': 'Title',
    'companyName': 'Company name',
    'contactName': 'Contact person',
    'contactPhone': 'Phone',
    'facilityType': 'Facility type',
    'locations': 'Service locations',
    'category': 'Service category',
    'text': 'What you need',
    'budget': 'Budget',
    'items': 'Line items',
    'attachments': 'Files',
    'invited': 'Suppliers to invite',
    'minYears': 'Supplier criteria',
    'minAnnualTurnover': 'Supplier criteria',
    'minLast3YrTurnover': 'Supplier criteria',
    'preQualEndDate': 'Pre-qualification deadline',
    'dueDate': 'Deadline',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('problems'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.errorContainer),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.circleAlert, size: 16, color: AppColors.error),
              const SizedBox(width: 8),
              Text(
                problems.length == 1
                    ? '1 thing to fix before sending'
                    : '${problems.length} things to fix before sending',
                style: RfqText.bodyStrong.copyWith(color: AppColors.onErrorContainer),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final entry in problems.entries)
            InkWell(
              key: ValueKey('problem-${entry.key}'),
              onTap: () => onGo(entry.key),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: '${labels[entry.key] ?? entry.key}: ',
                          style: RfqText.metaStrong.copyWith(color: AppColors.onErrorContainer),
                          children: [
                            TextSpan(
                              text: entry.value,
                              style: RfqText.meta.copyWith(color: AppColors.onErrorContainer),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Icon(LucideIcons.chevronRight, size: 14, color: AppColors.onErrorContainer),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// After a post: what was done, how many suppliers it reached (the API's own count), and what follows.
class PostedPanel extends StatelessWidget {
  const PostedPanel({
    super.key,
    required this.result,
    required this.editing,
    required this.onView,
    required this.onPostAnother,
    required this.onDone,
    this.preQualEnd,
  });

  final PostResult result;
  final bool editing;
  final VoidCallback onView;
  final VoidCallback onPostAnother;
  final VoidCallback onDone;
  final DateTime? preQualEnd;

  @override
  Widget build(BuildContext context) {
    final enquiry = result.kind == RfqKind.enquiry;
    final draft = result.status == RfqStatus.draft;
    final now = result.alertedNow;
    final later = result.alertedLater;
    final reachedNone = now == 0 && (later ?? 0) == 0;
    final next = enquiry
        ? const [
            'Matched suppliers can reply with questions, a price or a visit to arrange.',
            'Their replies appear in My RFQ\'s, and you are notified of each.',
            'Compare the replies and select the supplier you want to work with.',
          ]
        : [
            preQualEnd == null
                ? 'Suppliers send pre-qualification responses against your criteria.'
                : 'Suppliers send pre-qualification responses until ${pickedDay(preQualEnd!)}.',
            'You shortlist the suppliers who qualify; only they are asked to quote.',
            'Compare the itemised quotes side by side and award.',
          ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: RfqCard(
        key: const ValueKey('posted'),
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(color: AppColors.emerald50, shape: BoxShape.circle),
                child: const Icon(LucideIcons.check, size: 26, color: AppColors.emerald700),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                editing
                    ? 'Changes saved'
                    : draft
                    ? 'Draft saved'
                    : (enquiry ? 'Enquiry posted' : 'RFQ created'),
                style: RfqText.pageTitle,
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'Ref ${result.id.length > 8 ? result.id.substring(result.id.length - 8).toUpperCase() : result.id.toUpperCase()}',
                style: RfqText.small,
              ),
            ),
            const SizedBox(height: 10),
            if (draft)
              Text(
                'Only your team can see it. Open it from My RFQ\'s to finish and publish it.',
                textAlign: TextAlign.center,
                style: RfqText.body,
              )
            else if (editing)
              Text('The requirement now reads as you saved it.', textAlign: TextAlign.center, style: RfqText.body)
            else if (now == null)
              Text('Matching suppliers are being alerted.', textAlign: TextAlign.center, style: RfqText.body)
            else
              Text(
                reachedNone
                    ? 'No supplier matches this service and location yet. It is listed on the requirements board, and you can widen the places or the category.'
                    : [
                        now == 1 ? 'Shared with 1 matched supplier.' : 'Shared with $now matched suppliers.',
                        if ((later ?? 0) > 0)
                          later == 1
                              ? '1 more is alerted when early access ends.'
                              : 'Up to $later more are alerted when early access ends.',
                      ].join(' '),
                key: const ValueKey('posted-reach'),
                textAlign: TextAlign.center,
                style: RfqText.body,
              ),
            if (!draft && !editing) ...[
              const SizedBox(height: 16),
              Text('What happens next', style: RfqText.section),
              const SizedBox(height: 6),
              for (final line in next)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(LucideIcons.check, size: 15, color: AppColors.emerald700),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(line, style: RfqText.body)),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              key: const ValueKey('posted-view'),
              onPressed: onView,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('View requirement'),
            ),
            const SizedBox(height: 8),
            if (!editing)
              OutlinedButton(
                key: const ValueKey('posted-another'),
                onPressed: onPostAnother,
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                child: const Text('Post another'),
              ),
            TextButton(
              key: const ValueKey('posted-done'),
              onPressed: onDone,
              child: Text('Back to My RFQ\'s', style: RfqText.link),
            ),
          ],
        ),
      ),
    );
  }
}

/// Number-only input for the amount boxes.
final rupeeInputFormatters = <TextInputFormatter>[FilteringTextInputFormatter.allow(RegExp(r'[0-9.,₹ ]'))];
