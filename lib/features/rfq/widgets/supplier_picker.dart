import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../rfq_models.dart';
import '../rfq_styles.dart';
import 'rfq_widgets.dart';

/// A rating as the Supplier design draws it: a gold star, 4.8, and how many reviews stand behind it.
class RatingLine extends StatelessWidget {
  const RatingLine({super.key, required this.rating, this.count = 0});

  final double rating;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (rating <= 0) return Text('No ratings yet', style: RfqText.small);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(LucideIcons.star, size: 12, color: AppColors.amber500),
        const SizedBox(width: 3),
        Text(rating.toStringAsFixed(1), style: RfqText.metaStrong.copyWith(fontSize: 12)),
        if (count > 0) Text('  ($count)', style: RfqText.small),
      ],
    );
  }
}

/// Choose suppliers by name, with the ones that fit suggested first. Tapping a row selects it; the button sends
/// the choice to [onConfirm], which answers an error sentence to show in the sheet (the sheet stays open and the
/// choice is kept) or null when it is done.
Future<void> showSupplierPicker(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required Future<List<SupplierHit>> Function(String query) search,
  required Future<String?> Function(List<SupplierRef> chosen) onConfirm,
  Future<List<SupplierHit>> Function()? suggested,
  List<SupplierRef> selected = const [],
  Set<String> excluded = const {},
  int max = 50,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (context) => _SupplierPicker(
      title: title,
      confirmLabel: confirmLabel,
      search: search,
      suggested: suggested,
      onConfirm: onConfirm,
      selected: selected,
      excluded: excluded,
      max: max,
    ),
  );
}

class _SupplierPicker extends StatefulWidget {
  const _SupplierPicker({
    required this.title,
    required this.confirmLabel,
    required this.search,
    required this.onConfirm,
    required this.selected,
    required this.excluded,
    required this.max,
    this.suggested,
  });

  final String title;
  final String confirmLabel;
  final Future<List<SupplierHit>> Function(String query) search;
  final Future<List<SupplierHit>> Function()? suggested;
  final Future<String?> Function(List<SupplierRef> chosen) onConfirm;
  final List<SupplierRef> selected;
  final Set<String> excluded;
  final int max;

  @override
  State<_SupplierPicker> createState() => _SupplierPickerState();
}

class _SupplierPickerState extends State<_SupplierPicker> {
  final _query = TextEditingController();
  Timer? _debounce;
  late final List<SupplierRef> _chosen = List.of(widget.selected);
  List<SupplierHit> _suggested = const [];
  List<SupplierHit> _found = const [];
  bool _loading = true;
  bool _searching = false;
  bool _sending = false;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _loadSuggested();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _loadSuggested() async {
    try {
      final hits = await (widget.suggested?.call() ?? widget.search(''));
      if (!mounted) return;
      setState(() => _suggested = [for (final h in hits) if (!widget.excluded.contains(h.supplier.vendorId)) h]);
    } catch (_) {
      // Suggestions are a courtesy; the search below still works.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changed(String text) {
    _debounce?.cancel();
    if (text.trim().isEmpty) {
      setState(() {
        _found = const [];
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(text));
  }

  Future<void> _run(String text) async {
    final generation = ++_generation;
    setState(() => _searching = true);
    try {
      final hits = await widget.search(text);
      if (!mounted || generation != _generation) return;
      setState(() => _found = [for (final h in hits) if (!widget.excluded.contains(h.supplier.vendorId)) h]);
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() => _found = const []);
    } finally {
      if (mounted && generation == _generation) setState(() => _searching = false);
    }
  }

  bool _on(SupplierRef s) => _chosen.any((c) => c.vendorId == s.vendorId);

  void _toggle(SupplierRef s) {
    setState(() {
      _error = null;
      if (_on(s)) {
        _chosen.removeWhere((c) => c.vendorId == s.vendorId);
      } else if (_chosen.length >= widget.max) {
        _error = 'You can choose at most ${widget.max} suppliers at once.';
      } else {
        _chosen.add(s);
      }
    });
  }

  Future<void> _confirm() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final error = await widget.onConfirm(List.of(_chosen));
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _sending = false;
      _error = error;
    });
  }

  Widget _row(SupplierHit hit) {
    final s = hit.supplier;
    final on = _on(s);
    return InkWell(
      key: ValueKey('supplier-${s.vendorId}'),
      onTap: _sending ? null : () => _toggle(s),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            LogoTile(name: s.name, logoUrl: s.logoUrl, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name, style: RfqText.metaStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Row(
                    children: [
                      RatingLine(rating: s.rating, count: s.ratingCount),
                      if (s.city != null) Text('  ·  ${s.city}', style: RfqText.small),
                    ],
                  ),
                ],
              ),
            ),
            if (hit.matchScore != null) ...[TonePill('fit ${hit.matchScore}', tone: Tone.green), const SizedBox(width: 8)],
            Icon(on ? LucideIcons.squareCheck : LucideIcons.square, size: 22, color: on ? AppColors.primary : AppColors.slate300),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final typed = _query.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(widget.title, style: RfqText.sheetTitle),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  key: const ValueKey('supplier-search'),
                  controller: _query,
                  onChanged: _changed,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _run,
                  style: RfqText.formInput,
                  decoration: rfqInputDecoration(hint: 'Search suppliers by name', prefix: LucideIcons.search),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    if (_loading || _searching) const Padding(padding: EdgeInsets.all(14), child: RfqSpinner(size: 20)),
                    if (typed) ...[
                      for (final h in _found) _row(h),
                      if (!_searching && _found.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('No supplier by that name', textAlign: TextAlign.center, style: RfqText.meta),
                        ),
                    ] else ...[
                      if (_suggested.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                          child: Text(
                            widget.suggested == null ? 'Suppliers' : 'Suggested for this requirement',
                            style: RfqText.metaStrong,
                          ),
                        ),
                      for (final h in _suggested) _row(h),
                      if (!_loading && _suggested.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('Search a supplier by name to invite it.', textAlign: TextAlign.center, style: RfqText.meta),
                        ),
                    ],
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: RfqBanner(_error!),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  key: const ValueKey('supplier-confirm'),
                  onPressed: _sending || _chosen.isEmpty && widget.selected.isEmpty ? null : _confirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_chosen.isEmpty ? widget.confirmLabel : '${widget.confirmLabel} (${_chosen.length})'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
