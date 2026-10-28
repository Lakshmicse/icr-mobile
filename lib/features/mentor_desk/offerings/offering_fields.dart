import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../mentorship_my/mentoring_format.dart' show inr;
import '../../mentorship_my/widgets/forms.dart';
import '../../mentorship_my/widgets/kit.dart';
import 'offerings_files.dart';
import 'offerings_repository.dart';

/// The price block every offering shares: a Free switch, the price in rupees,
/// and an optional strikethrough price. Each field shows the API's own limit.
class PriceBlock extends StatelessWidget {
  const PriceBlock({
    super.key,
    required this.free,
    required this.onFree,
    required this.price,
    required this.compareAt,
    this.priceHelp,
    this.freeLabel = 'Free',
  });

  final bool free;
  final ValueChanged<bool> onFree;
  final TextEditingController price;
  final TextEditingController compareAt;
  final String? priceHelp;
  final String freeLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          key: const ValueKey('offering-free'),
          contentPadding: EdgeInsets.zero,
          value: free,
          onChanged: onFree,
          title: Text(freeLabel, style: MentoringText.formLabel),
        ),
        if (!free) ...[
          FieldBlock(
            label: 'Price (₹)',
            help: priceHelp,
            child: TextField(
              key: const ValueKey('offering-price'),
              controller: price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: MentoringText.formInput,
              decoration: fieldDecoration('1499'),
            ),
          ),
          FieldBlock(
            label: 'Strikethrough price (₹, optional)',
            help: 'Shown crossed out beside the price. It must be higher, and the price at least half of it.',
            child: TextField(
              key: const ValueKey('offering-compare'),
              controller: compareAt,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: MentoringText.formInput,
              decoration: fieldDecoration('1999'),
            ),
          ),
        ],
      ],
    );
  }
}

/// A file or a cover the mentor uploads: shows its name, picks a new one, and (for a cover) clears it.
class FileRow extends StatelessWidget {
  const FileRow({
    super.key,
    required this.label,
    required this.pickKey,
    required this.name,
    required this.onPick,
    this.size,
    this.busy = false,
    this.onClear,
    this.help,
    this.pickLabel,
  });

  final String label;
  final String pickKey;
  final String? name;
  final int? size;
  final bool busy;
  final VoidCallback onPick;
  final VoidCallback? onClear;
  final String? help;
  final String? pickLabel;

  @override
  Widget build(BuildContext context) {
    return FieldBlock(
      label: label,
      help: help,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (name != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(LucideIcons.file, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$name${size == null ? '' : ' · ${_size(size!)}'}',
                      key: ValueKey('$pickKey-name'),
                      style: MentoringText.bodyStrong,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ActionWrap(
            top: 0,
            children: [
              QuietButton(
                key: ValueKey(pickKey),
                label: busy ? 'Uploading…' : (pickLabel ?? (name == null ? 'Choose a file' : 'Replace the file')),
                icon: LucideIcons.upload,
                onPressed: busy ? null : onPick,
              ),
              if (onClear != null && name != null) QuietButton(label: 'Remove', danger: true, onPressed: onClear),
            ],
          ),
        ],
      ),
    );
  }

  static String _size(int bytes) => bytes >= 1024 * 1024
      ? '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB'
      : '${(bytes / 1024).round().clamp(1, 1 << 30)} KB';
}

/// Picks a file, checks it as the API would, and uploads it. Answers the stored file, or sets [problem] and answers null.
Future<StoredUpload?> pickAndUpload({
  required OfferingFilePicker pick,
  required Future<StoredUpload> Function(PickedUpload file) upload,
  required bool imageOnly,
  required void Function(String? problem) problem,
}) async {
  PickedUpload? file;
  try {
    file = await pick(imageOnly: imageOnly);
  } catch (_) {
    problem("Couldn't open your files. Try again.");
    return null;
  }
  if (file == null) return null;
  final bad = uploadProblem(file, imageOnly: imageOnly);
  if (bad != null) {
    problem(bad);
    return null;
  }
  try {
    final stored = await upload(file);
    problem(null);
    return stored;
  } catch (e) {
    problem(ApiError.from(e).message);
    return null;
  }
}

/// "₹1,499" for a price in paisa, "Free" for none.
String priceLine(int paisa, {int? compareAt}) {
  if (paisa == 0) return 'Free';
  return compareAt == null ? inr(paisa) : '${inr(paisa)} (was ${inr(compareAt)})';
}
