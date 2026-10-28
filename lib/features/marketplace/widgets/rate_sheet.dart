import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/util/links.dart' show showMessage;
import '../marketplace_styles.dart';
import '../supplier_controller.dart';
import 'market_sheets.dart';

/// "Rate this supplier": one to five stars and, if the member likes, what they
/// thought. The API keeps one rating per member and replaces it on the next, and
/// refuses the supplier's own team; its sentence is shown as it is, and what was
/// typed stays while the member decides what to do.
Future<void> showRateSheet(BuildContext context) async {
  final controller = context.read<SupplierController>();
  final done = await showMartSheet<bool>(
    context,
    builder: (_) => ChangeNotifierProvider<SupplierController>.value(value: controller, child: const RateSheet()),
  );
  if (done == true && context.mounted) showMessage(context, 'Thanks, your rating is saved.');
}

/// The longest comment the sheet takes (the API sets no limit; a rating is a few lines).
const ratingCommentLimit = 1000;

class RateSheet extends StatefulWidget {
  const RateSheet({super.key});

  @override
  State<RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends State<RateSheet> {
  final _comment = TextEditingController();
  int _score = 0;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_score == 0) {
      setState(() => _error = 'Pick one to five stars first.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final message = await context.read<SupplierController>().rate(score: _score, comment: _comment.text);
    if (!mounted) return;
    if (message == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _sending = false;
        _error = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = context.read<SupplierController>().supplier.name;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Rate $name', style: MartText.sheetTitle),
              const SizedBox(height: 4),
              Text(
                'Your rating counts towards the supplier\'s average. It is shown as "Verified buyer", without your name.',
                style: MartText.sheetRowMuted,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (var i = 1; i <= 5; i++)
                    Semantics(
                      button: true,
                      selected: i == _score,
                      label: '$i ${i == 1 ? 'star' : 'stars'}',
                      child: InkResponse(
                        key: ValueKey('star-$i'),
                        onTap: _sending ? null : () => setState(() => _score = i),
                        radius: 24,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(
                            i <= _score ? Icons.star : Icons.star_border,
                            size: 38,
                            color: i <= _score ? MartColors.profileStar : AppColors.outline,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('rating-comment'),
                controller: _comment,
                enabled: !_sending,
                minLines: 3,
                maxLines: 5,
                maxLength: ratingCommentLimit,
                style: MartText.sheetRow,
                decoration: InputDecoration(
                  hintText: 'What went well, or what should change (optional)',
                  hintStyle: MartText.sheetRowMuted,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(
                  _error!,
                  key: const ValueKey('rating-error'),
                  style: MartText.sheetRow.copyWith(color: AppColors.error, fontSize: 13),
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  key: const ValueKey('rating-send'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _sending ? null : _send,
                  child: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text('Send rating', style: MartText.sheetButton),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
