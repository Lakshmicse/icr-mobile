import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_error.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/detail_sheet.dart';
import 'exam_format.dart';
import 'exam_models.dart';
import 'exam_repository.dart';
import 'exam_styles.dart';
import 'exam_widgets.dart';

/// The register, in the app: anyone's certificate number is looked up and says what it certifies, whose it is
/// and when it was issued. The answer is the API's public one, the same the website's verify page shows.
Future<void> showVerifySheet(BuildContext context, ExamRepository repository, {String initial = ''}) {
  return showDetailSheet<void>(
    context,
    topInset: 48,
    body: (_) => VerifyBody(repository: repository, initial: initial),
  );
}

/// An example of the form a certificate number takes.
const sampleCertificateNumber = 'ICR-CCREA-2026-8ZQ4R1KD';

class VerifyBody extends StatefulWidget {
  const VerifyBody({super.key, required this.repository, this.initial = ''});

  final ExamRepository repository;
  final String initial;

  @override
  State<VerifyBody> createState() => _VerifyBodyState();
}

class _VerifyBodyState extends State<VerifyBody> {
  late final TextEditingController _number = TextEditingController(text: widget.initial);
  bool _busy = false;
  bool _checked = false;
  ExamCertificate? _found;
  String? _error;

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final value = _number.text.trim();
    if (value.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _found = null;
    });
    try {
      final found = await widget.repository.verifyCertificate(value);
      if (!mounted) return;
      setState(() {
        _found = found;
        _checked = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final found = _found;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Text('CERTIFICATE VERIFICATION', style: ExamText.eyebrow),
        const SizedBox(height: 4),
        Text('Check a certificate number', style: ExamText.heroTitle.copyWith(fontSize: 22)),
        const SizedBox(height: 6),
        Text(
          'Every ICR certificate carries a unique number in the form $sampleCertificateNumber. Enter it below to see what it certifies.',
          style: ExamText.body,
        ),
        const SizedBox(height: 16),
        ListenableBuilder(
          listenable: _number,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _number,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.search,
                autocorrect: false,
                enableSuggestions: false,
                onSubmitted: (_) => _verify(),
                style: AppText.plexSans(16, FontWeight.w600, AppColors.onSurface, spacing: 0.3),
                decoration: InputDecoration(
                  labelText: 'Certificate number',
                  hintText: sampleCertificateNumber,
                  hintStyle: AppText.plexSans(16, FontWeight.w400, AppColors.slate400),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.slate300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ExamButton(
                label: _busy ? 'Checking…' : 'Verify',
                icon: LucideIcons.shieldCheck,
                busy: _busy,
                onPressed: _number.text.trim().isEmpty ? null : _verify,
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Notice(tone: NoticeTone.error, text: _error!, action: 'Try again', onAction: _verify),
        ] else if (_checked && !_busy && found == null) ...[
          const SizedBox(height: 16),
          const Notice(
            tone: NoticeTone.warning,
            text: 'No certificate was found with that number. Check the number and try again.',
          ),
        ],
        if (found != null && !_busy) ...[const SizedBox(height: 16), _Verified(certificate: found)],
        const SizedBox(height: 8),
      ],
    );
  }
}

class _Verified extends StatelessWidget {
  const _Verified({required this.certificate});

  final ExamCertificate certificate;

  @override
  Widget build(BuildContext context) {
    final c = certificate;
    final rows = <(String, String, bool)>[
      ('Certificate number', c.certificateId, true),
      if (c.holder != null) ('Issued to', c.holder!, false),
      ('Credential', c.title, false),
      ('Awarded by', c.providerName ?? 'Institute for Corporate Real Estate', false),
      if (c.levelLabel != null) ('Level', c.levelLabel!, false),
      if (c.passPercentage > 0) ('Result', '${c.percentage}% against a ${c.passPercentage}% pass standard', false),
      ('Issued', longDayLabel(c.issuedAt), false),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.circleCheck, size: 22, color: AppColors.success),
              const SizedBox(width: 10),
              Expanded(child: Text('Certificate verified', style: ExamText.heading)),
              const InfoPill(label: 'Genuine', color: AppColors.emerald700, fill: AppColors.emerald50),
            ],
          ),
          const SizedBox(height: 12),
          for (final (i, r) in rows.indexed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: i == 0 ? null : const Border(top: BorderSide(color: AppColors.slate100)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.$1.toUpperCase(), style: ExamText.statLabel),
                  const SizedBox(height: 2),
                  Text(
                    r.$2,
                    style: r.$3
                        ? AppText.plexSans(14, FontWeight.w700, AppColors.onSurface).copyWith(letterSpacing: 0.3)
                        : ExamText.bodyStrong,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
