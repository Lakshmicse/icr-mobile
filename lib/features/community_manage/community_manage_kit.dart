import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_error.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/detail_sheet.dart';
import '../account/widgets/account_kit.dart';
import '../account/widgets/photo_picker.dart' show fitForUpload, pickImageFromDevice;
import '../workspaces/page_kit.dart';
import 'community_manage_models.dart';
import 'community_manage_repository.dart';
import 'community_manage_rules.dart';

/// The small parts the console's screens and sheets share: the phone's pickers behind one seam, the two tabs, the
/// Published pill, the pager, the states of a list, and the form fields the website's dialogs have that the app's
/// kits do not (a choice of two, a switch, a picture, a gallery, typed segments, a city or country search).

/// Where the sheets reach the phone: a picture and a day. Behind one seam so a test can hand in what the pickers
/// would have given.
class ManagePickers {
  const ManagePickers();

  /// A PNG, JPG or WEBP from the phone, shrunk to [maxBytes] when the picture is heavier (the website crops and
  /// shrinks before it sends; the app keeps the whole picture).
  Future<UploadFile?> pickImage({int maxBytes = ManageLimits.coverBytes}) async {
    final picked = await pickImageFromDevice();
    if (picked == null) return null;
    final fitted = await fitForUpload(picked, max: maxBytes);
    return UploadFile(
      name: fitted.name,
      bytes: fitted.bytes is Uint8List ? fitted.bytes as Uint8List : Uint8List.fromList(fitted.bytes),
      mimeType: fitted.contentType,
    );
  }

  Future<DateTime?> pickDay(BuildContext context, {required DateTime initial, String? help}) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
    helpText: help,
  );
}

/// The picture types the uploads endpoint takes for these fields.
const _imageTypes = {'image/png', 'image/jpeg', 'image/webp'};

/// Why a picked picture cannot be sent, in the website's words; null when it can.
String? pictureProblem(UploadFile file, {required int maxBytes}) {
  if (!_imageTypes.contains(file.mimeType)) return 'Only PNG, JPG or WEBP images are supported.';
  if (file.size > maxBytes) {
    final mb = maxBytes ~/ (1024 * 1024);
    return 'Each image must be $mb MB or smaller. Compress it or choose a smaller one.';
  }
  return null;
}

/// The page's two tabs: words with a line under the open one, a hairline under the row.
class ManageTabs extends StatelessWidget {
  const ManageTabs({super.key, required this.labels, required this.selected, required this.onSelect});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                for (final (i, label) in labels.indexed)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: i == selected,
                      child: InkWell(
                        key: ValueKey('manage-tab-$i'),
                        onTap: () => onSelect(i),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: i == selected ? AppColors.primary : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: i == selected
                                ? WsText.title.copyWith(color: AppColors.primary)
                                : WsText.title.copyWith(color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const WsDivider(),
        ],
      ),
    );
  }
}

/// "Published" in green or "Hidden" in grey, as the website's list.
class PublishPill extends StatelessWidget {
  const PublishPill({super.key, required this.published});

  final bool published;

  @override
  Widget build(BuildContext context) =>
      published ? const WsChip('Published', tone: WsTone.good) : const WsChip('Hidden', tone: WsTone.grey);
}

/// Earlier and later pages of a list, drawn only when there is more than one.
class ManagePager extends StatelessWidget {
  const ManagePager({super.key, required this.page, required this.totalPages, required this.onPage});

  final int page;
  final int totalPages;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    if (totalPages < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            key: const ValueKey('manage-page-prev'),
            tooltip: 'Previous Page',
            onPressed: page > 1 ? () => onPage(page - 1) : null,
            icon: const Icon(LucideIcons.chevronLeft, size: 20),
          ),
          Flexible(
            child: Text(
              'Page $page of $totalPages',
              key: const ValueKey('manage-page-label'),
              style: WsText.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            key: const ValueKey('manage-page-next'),
            tooltip: 'Next Page',
            onPressed: page < totalPages ? () => onPage(page + 1) : null,
            icon: const Icon(LucideIcons.chevronRight, size: 20),
          ),
        ],
      ),
    );
  }
}

/// A list's quiet states: still reading, nothing here, or the API's refusal with a way to ask again.
class ManageState extends StatelessWidget {
  const ManageState.loading({super.key}) : message = null, onRetry = null, loading = true;

  const ManageState.message(String this.message, {super.key, this.onRetry}) : loading = false;

  final String? message;
  final VoidCallback? onRetry;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
      child: Column(
        children: [
          Text(message ?? '', style: WsText.body, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            WsButton(label: 'Try Again', onPressed: onRetry),
          ],
        ],
      ),
    );
  }
}

/// One label over its value, in a record's details.
class ManageFact extends StatelessWidget {
  const ManageFact({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: WsText.meta),
        const SizedBox(height: 2),
        Text(value, style: WsText.bodyStrong),
      ],
    ),
  );
}

/// A row's bin (or any one icon action), 36 dp.
class ManageRowAction extends StatelessWidget {
  const ManageRowAction({super.key, required this.icon, required this.label, required this.onPressed, this.color});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onPressed,
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    icon: Icon(icon, size: 18, color: onPressed == null ? AppColors.slate300 : (color ?? AppColors.onSurfaceVariant)),
  );
}

/// A tinted note in a form or under a row: information, or (amber) something to look at first.
class ManageNote extends StatelessWidget {
  const ManageNote(this.text, {super.key, this.warn = false});

  final String text;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: warn ? WsColors.warnTint : WsColors.tint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dropped to the middle of the first line of the words beside it.
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              warn ? LucideIcons.triangleAlert : LucideIcons.info,
              size: 16,
              color: warn ? WsColors.warn : AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AccountText.body)),
        ],
      ),
    );
  }
}

// --- form fields -----------------------------------------------------------------------------------------------------

/// A heading inside a form ("About").
class FormHeading extends StatelessWidget {
  const FormHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 10),
    child: Text(text, style: AccountText.itemTitle),
  );
}

/// One of a few choices, each on its own line (the website's radio group).
class ChoiceField extends StatelessWidget {
  const ChoiceField({super.key, required this.label, required this.options, required this.value, required this.onChanged});

  final String label;

  /// Value → words.
  final Map<String, String> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: AccountText.label),
          const SizedBox(height: 2),
          for (final e in options.entries)
            Semantics(
              button: true,
              selected: e.key == value,
              child: InkWell(
                key: ValueKey('choice-${e.key}'),
                onTap: () => onChanged(e.key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        e.key == value ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        size: 20,
                        color: e.key == value ? AppColors.primary : AppColors.slate400,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(e.value, style: AccountText.body)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A switch with its words beside it ("Published (listed publicly)").
class SwitchField extends StatelessWidget {
  const SwitchField({super.key, required this.label, required this.value, required this.onChanged, this.switchKey});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Key? switchKey;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Expanded(child: Text(label, style: AccountText.body)),
        const SizedBox(width: 12),
        Switch(key: switchKey, value: value, onChanged: onChanged, activeTrackColor: AppColors.primary),
      ],
    ),
  );
}

/// A picture stored at a path: shown small, with Upload or Replace and Remove beside it.
class PictureField extends StatelessWidget {
  const PictureField({
    super.key,
    required this.label,
    required this.helper,
    required this.value,
    required this.onPick,
    required this.onRemove,
    this.round = false,
    this.uploading = false,
    this.error,
  });

  final String label;
  final String helper;

  /// The stored path, or '' when there is none.
  final String value;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  /// A round picture (a chapter's own) rather than a banner.
  final bool round;
  final bool uploading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final has = value.isNotEmpty;
    const empty = ColoredBox(
      color: AppColors.slate100,
      child: Center(child: Icon(LucideIcons.image, size: 22, color: AppColors.slate400)),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: AccountText.label),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(round ? 32 : 8),
                child: SizedBox(
                  width: round ? 64 : 112,
                  height: 64,
                  child: has ? AccountImage(source: value, fallback: empty) : empty,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    WsButton(
                      key: ValueKey('picture-pick-$label'),
                      label: uploading ? 'Uploading…' : (has ? 'Replace' : 'Upload Image'),
                      icon: LucideIcons.upload,
                      onPressed: uploading ? null : onPick,
                    ),
                    if (has)
                      TextButton(
                        key: ValueKey('picture-remove-$label'),
                        onPressed: uploading ? null : onRemove,
                        style: TextButton.styleFrom(foregroundColor: AppColors.rose600),
                        child: const Text('Remove'),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(error ?? helper, style: error != null ? AccountText.error : AccountText.meta),
        ],
      ),
    );
  }
}

/// The record's gallery (the website's `GalleryUploadField`): its pictures small, each with its own remove, and
/// one button that adds another — up to eight.
class GalleryField extends StatelessWidget {
  const GalleryField({
    super.key,
    required this.value,
    required this.onAdd,
    required this.onRemoveAt,
    this.uploading = false,
    this.error,
  });

  final List<String> value;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemoveAt;
  final bool uploading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final full = value.length >= ManageLimits.galleryImages;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gallery Images', style: AccountText.label),
          const SizedBox(height: 6),
          if (value.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (i, url) in value.indexed)
                    SizedBox(
                      key: ValueKey('gallery-$i'),
                      width: 96,
                      height: 72,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: AccountImage(
                              source: url,
                              fallback: const ColoredBox(
                                color: AppColors.slate100,
                                child: Center(child: Icon(LucideIcons.image, size: 20, color: AppColors.slate400)),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Semantics(
                              button: true,
                              label: 'Remove Image',
                              child: InkWell(
                                key: ValueKey('gallery-remove-$i'),
                                onTap: uploading ? null : () => onRemoveAt(i),
                                customBorder: const CircleBorder(),
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(color: Color(0x8C000000), shape: BoxShape.circle),
                                  child: const Icon(LucideIcons.x, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          WsButton(
            key: const ValueKey('gallery-add'),
            label: uploading ? 'Uploading…' : 'Add Image',
            icon: LucideIcons.imagePlus,
            onPressed: uploading || full ? null : onAdd,
          ),
          const SizedBox(height: 6),
          Text(
            error ??
                (full
                    ? 'Maximum of ${ManageLimits.galleryImages} images reached.'
                    : 'PNG, JPG or WEBP, up to 10 MB each.'),
            style: error != null ? AccountText.error : AccountText.meta,
          ),
        ],
      ),
    );
  }
}

/// A council's member segments (the website's free-typed chips): each one a pill with its own remove, added from
/// the field with the keyboard's Done or a comma.
class SegmentsField extends StatelessWidget {
  const SegmentsField({super.key, required this.value, required this.input, required this.onChanged});

  final List<String> value;

  /// What is being typed; the form owns it, so whatever is still there on Save counts too ([merge]).
  final TextEditingController input;
  final ValueChanged<List<String>> onChanged;

  /// [value] with the segments typed in [raw] (commas between them) added, each once.
  static List<String> merge(List<String> value, String raw) {
    final next = [...value];
    for (final piece in raw.split(',')) {
      final s = piece.trim();
      if (s.isNotEmpty && !next.contains(s)) next.add(s);
    }
    return next;
  }

  void _add(String raw) {
    final next = merge(value, raw);
    input.clear();
    if (next.length != value.length) onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (value.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in value)
                  Container(
                    padding: const EdgeInsets.only(left: 10, right: 2),
                    decoration: BoxDecoration(color: WsColors.grey, borderRadius: BorderRadius.circular(999)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(s, style: AccountText.chip, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        InkWell(
                          key: ValueKey('segment-remove-$s'),
                          customBorder: const CircleBorder(),
                          onTap: () => onChanged([...value.where((v) => v != s)]),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(LucideIcons.x, size: 14, color: AppColors.slate500),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        AccountField(
          fieldKey: const Key('council.segment'),
          label: 'Member Segments',
          controller: input,
          hint: 'Hospitals',
          helper: 'Press Done after each segment (e.g. Hospitals, Pharma).',
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onSubmitted: _add,
          onChanged: (v) {
            if (v.contains(',')) _add(v);
          },
        ),
      ],
    );
  }
}

/// A day of a lead's term: the chosen day or "Open", opening the phone's calendar; the cross clears it.
class DayField extends StatelessWidget {
  const DayField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.pickers,
    this.helper,
    this.hint = 'Not set',
  });

  final String label;

  /// `YYYY-MM-DD`, or '' when unset.
  final String value;
  final ValueChanged<String> onChanged;
  final ManagePickers pickers;
  final String? helper;
  final String hint;

  @override
  Widget build(BuildContext context) => AccountSelectField(
    label: label,
    hint: hint,
    value: value.isEmpty ? null : dayLabel(value),
    helper: helper,
    onClear: value.isEmpty ? null : () => onChanged(''),
    onTap: () async {
      final picked = await pickers.pickDay(
        context,
        initial: DateTime.tryParse(value) ?? DateTime.now(),
        help: label,
      );
      if (picked != null) onChanged(isoDay(picked));
    },
  );
}

// --- the place search ------------------------------------------------------------------------------------------------

/// The city search (the website's `ChapterPlaceFields`): ICR's own cities as you type, then cities anywhere once
/// typing rests; the pick carries its state and country.
Future<PlaceOption?> showCitySheet(
  BuildContext context, {
  required CommunityManageRepository repository,
  Duration delay = const Duration(milliseconds: 350),
}) => showModalBottomSheet<PlaceOption>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
  builder: (_) => _CitySheet(repository: repository, delay: delay),
);

class _CitySheet extends StatefulWidget {
  const _CitySheet({required this.repository, required this.delay});

  final CommunityManageRepository repository;
  final Duration delay;

  @override
  State<_CitySheet> createState() => _CitySheetState();
}

class _CitySheetState extends State<_CitySheet> {
  List<PlaceOption> _cities = const [];
  List<PlaceOption> _world = const [];
  String _q = '';
  bool _searching = false;
  String? _error;
  Timer? _settle;
  int _asked = 0;

  @override
  void initState() {
    super.initState();
    widget.repository.cities().then(
      (list) {
        if (mounted) setState(() => _cities = list);
      },
      onError: (Object e) {
        if (mounted) setState(() => _error = ApiError.from(e).message);
      },
    );
  }

  @override
  void dispose() {
    _settle?.cancel();
    super.dispose();
  }

  void _typed(String v) {
    setState(() => _q = v);
    _settle?.cancel();
    final q = v.trim();
    if (q.length < 2) {
      setState(() {
        _world = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _settle = Timer(widget.delay, () async {
      final asked = ++_asked;
      try {
        final found = await widget.repository.searchPlaces(q);
        if (mounted && asked == _asked) setState(() => _world = found);
      } catch (_) {
        // A suggestion list: when it cannot be read, the cities ICR lists are still there.
      } finally {
        if (mounted && asked == _asked) setState(() => _searching = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final seen = <String>{};
    final shown = <PlaceOption>[
      for (final c in _cities)
        if (q.isNotEmpty && c.label.toLowerCase().contains(q) && seen.add(c.label.toLowerCase())) c,
      for (final p in _world)
        if (seen.add(p.label.toLowerCase())) p,
    ].take(30).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(rule: false, height: 24, top: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Text('City', style: AccountText.cardTitle),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                key: const Key('citySheet.search'),
                autofocus: true,
                onChanged: _typed,
                style: AccountText.input,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Search a city anywhere',
                  hintStyle: AccountText.hint,
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.slate100,
                  prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppColors.slate400),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ),
            if (_searching) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: shown.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error ??
                            (q.length < 2
                                ? 'Select the city from the list. Its state and country are filled in.'
                                : (_searching ? 'Searching…' : 'No city found for “${_q.trim()}”.')),
                        style: AccountText.meta,
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (context, i) {
                        final p = shown[i];
                        final hint = [p.state ?? '', countryOfPlace(p)].where((v) => v.isNotEmpty).join(' · ');
                        return ListTile(
                          key: ValueKey('city-${p.label}'),
                          title: Text(p.label, style: AccountText.input),
                          subtitle: hint.isEmpty ? null : Text(hint, style: AccountText.meta),
                          onTap: () => Navigator.of(context).pop(p),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The country a country-wise chapter covers: ICR's markets first, and any other country by typing its name.
Future<String?> showCountrySheet(BuildContext context, {String? selected}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
  builder: (_) => _CountrySheet(selected: selected),
);

class _CountrySheet extends StatefulWidget {
  const _CountrySheet({required this.selected});

  final String? selected;

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final typed = _q.trim();
    final q = typed.toLowerCase();
    final names = icrCountries.values.toList();
    final shown = [
      for (final n in names)
        if (q.isEmpty || n.toLowerCase().contains(q)) n,
    ];
    final other = typed.length >= 2 && !names.any((n) => n.toLowerCase() == q) && typed.length <= ManageLimits.place;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(rule: false, height: 24, top: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Text('Country', style: AccountText.cardTitle),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                key: const Key('countrySheet.search'),
                onChanged: (v) => setState(() => _q = v),
                style: AccountText.input,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Search a country',
                  hintStyle: AccountText.hint,
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.slate100,
                  prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppColors.slate400),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final n in shown)
                    ListTile(
                      key: ValueKey('country-$n'),
                      title: Text(n, style: AccountText.input),
                      trailing: n == widget.selected ? const Icon(Icons.check, color: AppColors.primary) : null,
                      onTap: () => Navigator.of(context).pop(n),
                    ),
                  if (other)
                    ListTile(
                      key: const ValueKey('country-other'),
                      title: Text('Use “$typed”', style: AccountText.input),
                      subtitle: Text('A country outside ICR’s markets.', style: AccountText.meta),
                      onTap: () => Navigator.of(context).pop(typed),
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
