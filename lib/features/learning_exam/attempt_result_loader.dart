import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_error.dart';
import 'exam_format.dart';
import 'exam_models.dart';
import 'exam_repository.dart';
import 'exam_widgets.dart';
import 'result_screen.dart';

/// A past sitting's result: loads `GET /learning/me/attempts/:id`, then shows it as the result of a fresh one.
class AttemptResultLoader extends StatefulWidget {
  const AttemptResultLoader({super.key, required this.attempt, required this.repository, this.onRetake});

  final Attempt attempt;
  final ExamRepository repository;
  final VoidCallback? onRetake;

  @override
  State<AttemptResultLoader> createState() => _AttemptResultLoaderState();
}

class _AttemptResultLoaderState extends State<AttemptResultLoader> {
  AttemptResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_error != null) setState(() => _error = null);
    try {
      final r = await widget.repository.attempt(widget.attempt.id);
      if (mounted) setState(() => _result = r);
    } catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    if (result != null) {
      final paper = result.attempt.paper ?? widget.attempt.paper;
      return ResultScreen(
        result: result,
        paperName: paper?.name ?? 'Your attempt',
        certificateEnabled: paper?.certificateEnabled ?? false,
        onRetake: widget.onRetake,
        eyebrowSuffix: result.attempt.submittedAt == null ? null : ' · ${dayLabel(result.attempt.submittedAt)}',
        setName: paper?.title,
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ExamTitleBar(title: 'Test Results', onBack: () => popOnce(context)),
            Expanded(
              child: _error == null
                  ? const ExamSpinner()
                  : SingleChildScrollView(
                      child: ScreenNotice(
                        icon: LucideIcons.clipboardCheck,
                        title: 'Unable to Open This Result',
                        body: _error!,
                        action: 'Try Again',
                        onAction: _load,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
