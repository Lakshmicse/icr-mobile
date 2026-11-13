import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/chips.dart';
import '../account/widgets/account_kit.dart';
import '../account/widgets/account_session.dart';
import '../account/widgets/photo_picker.dart' show fitForUpload, pickImageFromDevice;
import '../site/site_kit.dart';
import 'partner_console_models.dart';
import 'partner_console_rules.dart';

/// The small parts the three console screens share: who is looking, the phone's pickers behind one seam, the
/// status chips, the dialogs' section labels and facts, the ordered-list editor and the upload fields.

/// Who is looking: an override (tests), else the signed-in person, else the admin's view (demo).
PartnerConsoleViewer consoleViewerOf(BuildContext context, PartnerConsoleViewer? override) =>
    override ?? PartnerConsoleViewer.of(maybeAuth(context)?.user);

/// Where the sheets reach the phone: a day, a time, a picture, a PDF. Behind one seam so a test can hand in what
/// the pickers would have given.
class ConsolePickers {
  const ConsolePickers();

  Future<DateTime?> pickDay(
    BuildContext context, {
    required DateTime initial,
    required DateTime first,
    required DateTime last,
    String? help,
  }) => showDatePicker(
    context: context,
    initialDate: initial.isBefore(first) ? first : (initial.isAfter(last) ? last : initial),
    firstDate: first,
    lastDate: last,
    helpText: help,
  );

  Future<TimeOfDay?> pickTime(BuildContext context, {required TimeOfDay initial, String? help}) =>
      showTimePicker(context: context, initialTime: initial, helpText: help);

  /// A PNG, JPG or WEBP, shrunk to the cover's 2 MB when the phone's picture is heavier.
  Future<UploadFile?> pickImage() async {
    final picked = await pickImageFromDevice();
    if (picked == null) return null;
    final fitted = await fitForUpload(picked, max: maxCoverBytes);
    return UploadFile(
      name: fitted.name,
      bytes: fitted.bytes is Uint8List ? fitted.bytes as Uint8List : Uint8List.fromList(fitted.bytes),
      mimeType: fitted.contentType,
    );
  }

  Future<UploadFile?> pickPdf() async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['pdf']);
    if (file == null) return null;
    return UploadFile(name: file.name, bytes: await file.readAsBytes(), mimeType: 'application/pdf');
  }
}

/// The website's limits: a cover image up to 2 MB, a brochure up to 10 MB.
const maxCoverBytes = 2 * 1024 * 1024;
const maxBrochureBytes = 10 * 1024 * 1024;

/// What a member who is not the institute's staff is told, and the plan lock on enrolments.
class ConsoleNotice extends StatelessWidget {
  const ConsoleNotice({super.key, required this.title, required this.text, this.icon = Symbols.lock});

  final String title;
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AppColors.slate500),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: SiteText.strong),
                const SizedBox(height: 4),
                Text(text, style: SiteText.secondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The not-partner sentence, one for all three screens.
const notPartnerTitle = 'This Console Is for Partner Institutes';
const notPartnerText =
    'Manage Courses, Manage Batches and Enrolment are for the admins and learning staff of a company ICR approved '
    'as a learning partner. Ask your company admin for a learning role if you should have one.';

/// MUI's chip colours as the console draws them: success, info, warning, error, default.
enum ConsoleTone { success, info, warning, error, muted }

/// A small status chip in one of the console's tones; `filled` draws it solid (MUI's filled variant).
class ConsoleChip extends StatelessWidget {
  const ConsoleChip({super.key, required this.label, required this.tone, this.filled = false, this.height = 24.0});

  final String label;
  final ConsoleTone tone;
  final bool filled;
  final double height;

  @override
  Widget build(BuildContext context) {
    final (fill, ink, border) = switch (tone) {
      ConsoleTone.success => (AppColors.successTint, AppColors.successInk, AppColors.successBadge),
      ConsoleTone.info => (SiteColors.blueTint, AppColors.primary, const Color(0xFFC9DCEE)),
      ConsoleTone.warning => (AppColors.amber50, AppColors.amber800, AppColors.amber100),
      ConsoleTone.error => (AppColors.errorContainer, AppColors.onErrorContainer, AppColors.errorContainer),
      ConsoleTone.muted => (Colors.white, AppColors.onSurfaceVariant, AppColors.outlineVariant),
    };
    return IcrChip(
      label: label,
      tone: filled ? ChipTone.tinted : ChipTone.outlined,
      fill: fill,
      border: filled ? fill : border,
      height: height,
      textStyle: SiteText.meta.copyWith(color: ink, fontWeight: FontWeight.w600),
    );
  }
}

ConsoleTone courseStatusTone(String status) => switch (status) {
  'PUBLISHED' => ConsoleTone.success,
  'PENDING_REVIEW' => ConsoleTone.info,
  'REJECTED' => ConsoleTone.error,
  _ => ConsoleTone.muted,
};

ConsoleTone batchStatusTone(String status) => switch (status) {
  'SCHEDULED' => ConsoleTone.info,
  'OPEN' => ConsoleTone.success,
  'RUNNING' => ConsoleTone.warning,
  'CANCELLED' => ConsoleTone.error,
  _ => ConsoleTone.muted,
};

ConsoleTone enrolmentStatusTone(String status) => switch (status) {
  'PENDING' => ConsoleTone.info,
  'CONFIRMED' || 'COMPLETED' => ConsoleTone.success,
  'WAITLISTED' => ConsoleTone.warning,
  _ => ConsoleTone.muted,
};

ConsoleTone trainerAnswerTone(String status) => switch (status) {
  'ACCEPTED' => ConsoleTone.success,
  'DECLINED' => ConsoleTone.error,
  'INVITED' => ConsoleTone.warning,
  _ => ConsoleTone.muted,
};

/// A dialog's section divider ("SCHEDULE", "COURSE CONTENT").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 14),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: SiteText.meta.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppColors.slate500),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(height: 1, thickness: 1, color: SiteColors.hairline)),
        ],
      ),
    );
  }
}

/// A view sheet's heading: small, bold, uppercase.
class ConsoleHeading extends StatelessWidget {
  const ConsoleHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text.toUpperCase(),
      style: SiteText.meta.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.slate500),
    ),
  );
}

/// One label and its value.
class Fact extends StatelessWidget {
  const Fact({super.key, required this.label, required this.value, this.strong = true});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: SiteText.meta),
      const SizedBox(height: 2),
      Text(value, style: strong ? SiteText.strong : SiteText.body),
    ],
  );
}

/// Facts two to a row.
class FactGrid extends StatelessWidget {
  const FactGrid({super.key, required this.facts});

  final List<Fact> facts;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < facts.length; i += 2) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: facts[i]),
              const SizedBox(width: 12),
              Expanded(child: i + 1 < facts.length ? facts[i + 1] : const SizedBox.shrink()),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

/// An ordered list of sentences, edited in place (the website's `ListEditor`): a plain field per row, moved up
/// or down when numbered, removed with the bin; blank rows are dropped on the way out, never blocked on the way in.
class ListEditor extends StatefulWidget {
  const ListEditor({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.helper,
    this.hint,
    this.addLabel = 'Add Another',
    this.numbered = true,
  });

  final String label;
  final List<String> value;
  final ValueChanged<List<String>> onChanged;
  final String? helper;
  final String? hint;
  final String addLabel;

  /// Numbered for takeaways; bulleted for audiences, which have no order.
  final bool numbered;

  @override
  State<ListEditor> createState() => _ListEditorState();
}

class _ListEditorState extends State<ListEditor> {
  late final List<TextEditingController> _rows = [for (final v in widget.value) TextEditingController(text: v)];

  @override
  void dispose() {
    for (final c in _rows) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit() => widget.onChanged([for (final c in _rows) c.text]);

  void _move(int i, int by) {
    final to = i + by;
    if (to < 0 || to >= _rows.length) return;
    setState(() {
      final c = _rows.removeAt(i);
      _rows.insert(to, c);
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label, style: AccountText.label),
          const SizedBox(height: 6),
          for (final (i, c) in _rows.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 22,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        widget.numbered ? '${i + 1}.' : '•',
                        style: SiteText.meta,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      key: ValueKey('list-${widget.label}-$i'),
                      controller: c,
                      maxLines: null,
                      style: AccountText.input,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => _emit(),
                      decoration: InputDecoration(
                        hintText: widget.hint,
                        hintStyle: AccountText.hint,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.slate300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                    ),
                  ),
                  if (widget.numbered)
                    Column(
                      children: [
                        _SmallIconButton(
                          icon: Icons.keyboard_arrow_up_rounded,
                          label: 'Move Up',
                          onPressed: i == 0 ? null : () => _move(i, -1),
                        ),
                        _SmallIconButton(
                          icon: Icons.keyboard_arrow_down_rounded,
                          label: 'Move Down',
                          onPressed: i == _rows.length - 1 ? null : () => _move(i, 1),
                        ),
                      ],
                    ),
                  _SmallIconButton(
                    icon: Icons.delete_outline_rounded,
                    label: 'Remove',
                    color: AppColors.rose600,
                    onPressed: () {
                      setState(() => _rows.removeAt(i).dispose());
                      _emit();
                    },
                  ),
                ],
              ),
            ),
          TextButton.icon(
            key: ValueKey('list-${widget.label}-add'),
            onPressed: () {
              setState(() => _rows.add(TextEditingController()));
              _emit();
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(_rows.isEmpty ? 'Add ${widget.label}' : widget.addLabel),
          ),
          if (widget.helper != null) Text(widget.helper!, style: AccountText.meta),
        ],
      ),
    );
  }
}

class _SmallIconButton extends StatelessWidget {
  const _SmallIconButton({required this.icon, required this.label, required this.onPressed, this.color});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onPressed,
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    icon: Icon(icon, size: 20, color: onPressed == null ? AppColors.slate300 : (color ?? AppColors.slate500)),
  );
}

/// A cover image or a brochure (the website's `CoverImageField` / `BrochureField`): a 64 dp frame, Upload or
/// Replace, Remove, the helper, and the upload's problem under it. The file goes to `POST /uploads` with the
/// `learning` purpose, which stores it publicly — a card image and a prospectus are read without a token.
class UploadField extends StatelessWidget {
  const UploadField({
    super.key,
    required this.label,
    required this.helper,
    required this.value,
    required this.onPick,
    required this.onRemove,
    this.pdf = false,
    this.uploading = false,
    this.error,
  });

  final String label;
  final String helper;
  final String? value;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final bool pdf;
  final bool uploading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AccountText.label),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: pdf ? 64 : 96,
                height: 64,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.slate50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: pdf
                    ? Icon(Icons.picture_as_pdf_outlined, color: value != null ? AppColors.rose600 : AppColors.slate300)
                    : value != null
                    ? const Icon(Icons.image, color: AppColors.slate500)
                    : const Icon(Icons.image_outlined, color: AppColors.slate300),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        OutlinedButton.icon(
                          key: ValueKey('upload-$label'),
                          onPressed: uploading ? null : onPick,
                          icon: const Icon(Icons.upload_file_outlined, size: 16),
                          label: Text(
                            uploading
                                ? 'Uploading…'
                                : value != null
                                ? 'Replace'
                                : pdf
                                ? 'Upload Brochure'
                                : 'Upload Image',
                          ),
                        ),
                        if (value != null)
                          TextButton.icon(
                            key: ValueKey('remove-$label'),
                            onPressed: uploading ? null : onRemove,
                            style: TextButton.styleFrom(foregroundColor: AppColors.rose600),
                            icon: const Icon(Icons.delete_outline_rounded, size: 16),
                            label: const Text('Remove'),
                          ),
                      ],
                    ),
                    Text(helper, style: AccountText.meta),
                  ],
                ),
              ),
            ],
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(error!, style: AccountText.error),
            ),
        ],
      ),
    );
  }
}

/// A tinted note in a form: information, or (amber) something to look at before saving.
class ConsoleNote extends StatelessWidget {
  const ConsoleNote(this.text, {super.key, this.warn = false});

  final String text;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: warn ? AppColors.amber50 : SiteColors.blueTint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(warn ? Symbols.warning : Symbols.info, size: 16, color: warn ? AppColors.amber800 : AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AccountText.body)),
        ],
      ),
    );
  }
}

/// The row of a console list: full width, 16 dp in, the hairline drawn by the list.
class ConsoleRow extends StatelessWidget {
  const ConsoleRow({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 8, 12), child: child),
  );
}

/// A row's icon action, 36 dp, in the website's colours.
class RowAction extends StatelessWidget {
  const RowAction({super.key, required this.icon, required this.label, required this.onPressed, this.color});

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
    icon: Icon(icon, size: 20, color: onPressed == null ? AppColors.slate300 : (color ?? AppColors.slate600)),
  );
}

/// The counts line under a title bar ("2 courses · 3 batches").
String plural(int n, String one, [String? many]) => '$n ${n == 1 ? one : (many ?? '${one}s')}';
