import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "4 Nov 2026".
String _day(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  return d == null ? '' : '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// A mentoring certificate checked by its printed number (`GET /mentorship/certificates/:number`, public): the
/// website's `/mentorship/certificates/<number>`, as a sheet of the app's own (since 4 Nov 2026 the app opens no
/// website page). Says whether it is valid, whose it is, what it is for and when it was issued.
Future<void> showMentoringCertificateCheck(BuildContext context, String certificateId) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
  builder: (_) => _CertificateCheck(certificateId: certificateId, api: context.read<ApiClient>()),
);

class _CertificateCheck extends StatefulWidget {
  const _CertificateCheck({required this.certificateId, required this.api});

  final String certificateId;
  final ApiClient api;

  @override
  State<_CertificateCheck> createState() => _CertificateCheckState();
}

class _CertificateCheckState extends State<_CertificateCheck> {
  late final Future<Map<String, dynamic>> _result = _load();

  Future<Map<String, dynamic>> _load() async {
    try {
      final res = await widget.api.dio.get<Map<String, dynamic>>(
        '/mentorship/certificates/${Uri.encodeComponent(widget.certificateId)}',
      );
      return res.data ?? const {};
    } on DioException catch (e) {
      throw ApiError.from(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _result,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
            }
            final c = snap.data ?? const <String, dynamic>{};
            final valid = !snap.hasError && c['valid'] == true;
            final hours = (c['hours'] as num?)?.toDouble() ?? 0;
            final sessions = (c['sessionsCount'] as num?)?.toInt() ?? 0;
            final headline = valid
                ? 'Valid ICR Mentoring Certificate'
                : snap.hasError
                ? (snap.error is ApiError ? (snap.error! as ApiError).message : 'Certificate Not Found')
                : 'This Certificate Is No Longer Valid';
            final rows = <(String, String)>[
              if (c['holderName'] is String) ('Awarded To', c['holderName'] as String),
              if (c['title'] is String) ('Certificate', c['title'] as String),
              if (c['programName'] is String) ('Programme', c['programName'] as String),
              if (sessions > 0) ('Sessions', '$sessions'),
              if (hours > 0) ('Hours', hours == hours.roundToDouble() ? '${hours.round()}' : hours.toStringAsFixed(2)),
              if (c['issuedAt'] is String) ('Issued', _day(c['issuedAt'] as String)),
              ('Number', widget.certificateId),
            ];
            return Column(
              key: const ValueKey('certificate-check'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: AppColors.outlineVariant, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      valid ? Icons.verified : Icons.error_outline,
                      size: 28,
                      color: valid ? AppColors.tertiary : AppColors.error,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(headline, style: AppText.plexSans(17, FontWeight.w600, AppColors.onSurface))),
                  ],
                ),
                const SizedBox(height: 14),
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const Divider(height: 1, thickness: 1, color: AppColors.outlineVariant),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 104,
                          child: Text(
                            rows[i].$1,
                            style: AppText.plexSans(13, FontWeight.w400, AppColors.onSurfaceVariant),
                          ),
                        ),
                        Expanded(
                          child: Text(rows[i].$2, style: AppText.plexSans(14, FontWeight.w500, AppColors.onSurface)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
