import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../account_models.dart';
import '../widgets/account_kit.dart';
import 'company_words.dart';

/// Confirms leaving a company. [leave] returns null when it worked, or the
/// API's sentence, which stays in the dialog beside the button that caused it
/// (the website's `LeaveCompanyDialog`), so a refusal is read where it happened.
/// Resolves to true once the person has left.
Future<bool> showLeaveCompanyDialog(
  BuildContext context, {
  required MyCompany company,
  required Future<String?> Function() leave,
}) async {
  final left = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => LeaveCompanyDialog(company: company, leave: leave),
  );
  return left ?? false;
}

class LeaveCompanyDialog extends StatefulWidget {
  const LeaveCompanyDialog({super.key, required this.company, required this.leave});

  final MyCompany company;
  final Future<String?> Function() leave;

  @override
  State<LeaveCompanyDialog> createState() => _LeaveCompanyDialogState();
}

class _LeaveCompanyDialogState extends State<LeaveCompanyDialog> {
  bool _pending = false;
  String? _error;

  Future<void> _confirm() async {
    if (_pending) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    final failure = await widget.leave();
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _pending = false;
      _error = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Leave ${widget.company.name}?', style: AccountText.cardTitle, maxLines: 3, overflow: TextOverflow.ellipsis),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final point in CompanyWords.leavePoints(widget.company))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 7, right: 10),
                      child: CircleAvatar(radius: 2.5, backgroundColor: AppColors.slate400),
                    ),
                    Expanded(child: Text(point, style: AccountText.body)),
                  ],
                ),
              ),
            if (_error != null)
              Container(
                key: const Key('leave.error'),
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECDD3)),
                ),
                child: Text(_error!, style: AccountText.error.copyWith(fontSize: 14)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('leave.cancel'),
          onPressed: _pending ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('leave.confirm'),
          onPressed: _pending ? null : _confirm,
          style: TextButton.styleFrom(foregroundColor: AppColors.rose600),
          child: _pending
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Leave company'),
        ),
      ],
    );
  }
}
