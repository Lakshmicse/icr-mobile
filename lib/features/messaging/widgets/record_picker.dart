import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/chips.dart';
import '../messaging_models.dart';
import '../messaging_repository.dart';
import '../messaging_styles.dart';
import 'record_card.dart';
import 'states.dart';

/// "Share an ICR record": pick a job, requirement, company, product, mentor or
/// event; the composer then carries its link, which the thread draws as a card.
/// Returns the record chosen, or null.
Future<RecordFacts?> showRecordPicker(BuildContext context, MessagingRepository repository) {
  return showModalBottomSheet<RecordFacts>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => FractionallySizedBox(heightFactor: 0.85, child: RecordPicker(repository: repository)),
  );
}

class RecordPicker extends StatefulWidget {
  const RecordPicker({super.key, required this.repository});

  final MessagingRepository repository;

  @override
  State<RecordPicker> createState() => _RecordPickerState();
}

class _RecordPickerState extends State<RecordPicker> {
  RecordType _type = RecordType.job;
  final _search = TextEditingController();
  Timer? _debounce;
  List<RecordFacts> _results = const [];
  bool _loading = true;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.repository.searchRecords(_type, _search.text);
      if (!mounted || generation != _generation) return;
      setState(() => _results = rows);
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _results = const [];
        _error = ApiError.from(e).message;
      });
    } finally {
      if (mounted && generation == _generation) setState(() => _loading = false);
    }
  }

  void _typed(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(color: AppColors.slate300, borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Share an ICR record', style: ChatText.sheetTitle),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            children: [
              for (final t in RecordType.values) ...[
                IcrChip(
                  key: ValueKey('picker-${t.name}'),
                  label: t.label,
                  tone: t == _type ? ChipTone.primary : ChipTone.outlined,
                  height: 28,
                  textStyle: ChatText.label.copyWith(color: t == _type ? Colors.white : AppColors.onSurface),
                  onTap: () {
                    if (t == _type) return;
                    setState(() => _type = t);
                    _load();
                  },
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            key: const ValueKey('picker-search'),
            controller: _search,
            onChanged: _typed,
            style: ChatText.composer,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search ${_type.label.toLowerCase()}s',
              hintStyle: ChatText.composerHint,
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: AppColors.slate200),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(_type.hint, style: ChatText.hint),
          ),
        ),
        const Divider(height: 1, color: ChatColors.rule),
        Expanded(
          child: _loading
              ? const ChatSpinner()
              : _error != null
              ? ChatNotice(
                  icon: LucideIcons.cloudOff,
                  title: "Couldn't load these.",
                  body: _error,
                  action: 'Retry',
                  onAction: _load,
                )
              : _results.isEmpty
              ? ChatNotice(
                  icon: recordIcon(_type),
                  title: 'Nothing found',
                  body: 'Try another word, or another kind of record.',
                )
              : ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, color: ChatColors.rule),
                  itemBuilder: (context, i) {
                    final f = _results[i];
                    return ListTile(
                      key: ValueKey('picker-row-${f.id}'),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.chipEmphasis,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(recordIcon(f.type), size: 18, color: AppColors.primary),
                      ),
                      title: Text(f.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: ChatText.cardTitle),
                      subtitle: recordLine(f).isEmpty
                          ? null
                          : Text(recordLine(f), maxLines: 1, overflow: TextOverflow.ellipsis, style: ChatText.cardMeta),
                      onTap: () => Navigator.of(context).pop(f),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
