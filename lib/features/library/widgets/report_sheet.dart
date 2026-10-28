import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../chapters/community_kit.dart';
import '../library_models.dart';

/// Sends a report; null when it went, the API's sentence when it refused.
typedef SendReport = Future<String?> Function(DocumentReportReason reason, String? note);

/// "Report this document": the reasons the API takes as a list, a note (required for "Something else",
/// at most 1,000 characters) and Send. The report goes to the ICR admin team; the uploader is never told
/// who sent it. The API's refusal (a second report while the first is open) is shown in the sheet, with
/// what was typed kept.
Future<void> showReportSheet(BuildContext context, {required String title, required SendReport send}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (sheet) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
      child: ReportSheet(title: title, send: send, onDone: () => Navigator.pop(sheet)),
    ),
  );
}

class ReportSheet extends StatefulWidget {
  const ReportSheet({super.key, required this.title, required this.send, required this.onDone});

  final String title;
  final SendReport send;
  final VoidCallback onDone;

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  final _note = TextEditingController();
  DocumentReportReason? _reason;
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _needsNote => _reason == DocumentReportReason.other;
  bool get _canSend => _reason != null && (!_needsNote || _note.text.trim().isNotEmpty) && !_busy;

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final problem = await widget.send(reason, _note.text.trim().isEmpty ? null : _note.text.trim());
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = problem;
      _sent = problem == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(LucideIcons.circleCheck, size: 34, color: AppColors.success),
            const SizedBox(height: 10),
            Text('Report sent', textAlign: TextAlign.center, style: CommunityText.sheetTitle),
            const SizedBox(height: 6),
            Text(
              'Thanks. Your report on “${widget.title}” is with the ICR admin team, who will look at it. '
              'The person who shared it is not told who reported it.',
              textAlign: TextAlign.center,
              style: CommunityText.body,
            ),
            const SizedBox(height: 16),
            CommunityButton(label: 'Done', expand: true, height: 38, onPressed: widget.onDone),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Report this document', style: CommunityText.sheetTitle),
          const SizedBox(height: 4),
          Text(
            'Tell the ICR admin team what is wrong with “${widget.title}”. The person who shared it is never told who reported it.',
            style: CommunityText.body,
          ),
          const SizedBox(height: 10),
          for (final r in DocumentReportReason.values)
            Semantics(
              button: true,
              selected: _reason == r,
              child: InkWell(
                onTap: _busy ? null : () => setState(() => _reason = r),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      Icon(
                        _reason == r ? LucideIcons.circleDot : LucideIcons.circle,
                        size: 18,
                        color: _reason == r ? AppColors.primary : AppColors.slate400,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(r.label, style: CommunityText.sheetRow)),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          CommunityField(
            label: _needsNote ? 'What is wrong? (required)' : 'Add a note (optional)',
            controller: _note,
            minLines: 3,
            maxLines: 5,
            maxLength: reportNoteLimit,
            hint: 'A page number, a link, anything that helps the admin check it',
            enabled: !_busy,
            onChanged: (_) => setState(() {}),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.circleAlert, size: 15, color: AppColors.error),
                const SizedBox(width: 6),
                Expanded(child: Text(_error!, style: CommunityText.fieldError)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CommunityButton(
                  label: 'Cancel',
                  outlined: true,
                  expand: true,
                  height: 38,
                  onPressed: _busy ? null : widget.onDone,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CommunityButton(
                  label: 'Send report',
                  expand: true,
                  height: 38,
                  busy: _busy,
                  onPressed: _canSend ? _submit : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
