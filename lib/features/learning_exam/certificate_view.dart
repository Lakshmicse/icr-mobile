import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/util/links.dart';
import '../../core/widgets/detail_sheet.dart';
import 'exam_format.dart';
import 'exam_models.dart';
import 'exam_services.dart';
import 'exam_styles.dart';
import 'exam_widgets.dart';
import 'qr_code.dart';

/// Printed when the account has no name: English in every language, as the website's.
const certificateFallbackHolder = 'ICR Candidate';

/// The signatory every assessment certificate carries (the website's constant).
const certificateSignatory = (
  name: 'VINAY KUMAR SHETTY',
  title: 'DIRECTOR, PROFESSIONAL DEVELOPMENT',
  organisation: 'INSTITUTE FOR CORPORATE REAL ESTATE',
);

/// Who the certificate is made out to: the signed-in person, else the name the
/// verification page returned, else the fallback.
String holderNameOf(BuildContext context, [ExamCertificate? certificate]) {
  try {
    final name = Provider.of<AuthController>(context, listen: false).user?.fullName;
    if (name != null && name.trim().isNotEmpty) return name.trim();
  } catch (_) {
    // No session in this tree (a test, a preview).
  }
  return certificate?.holder ?? certificateFallbackHolder;
}

/// The public page that proves a certificate: anyone can check the number there.
Uri verifyUri(String certificateId) =>
    AppConfig.sitePage('/learning/verify?id=${Uri.encodeQueryComponent(certificateId)}');

/// LinkedIn's "add to profile" hand-off, with the verification page as the credential's URL.
Uri linkedInUri(ExamCertificate c) {
  final issued = (c.issuedAt ?? DateTime.now()).toLocal();
  return Uri.https('www.linkedin.com', '/profile/add', {
    'startTask': 'CERTIFICATION_NAME',
    'name': c.title,
    'organizationName': c.providerName ?? 'ICR — Institute for Corporate Real Estate',
    'issueYear': '${issued.year}',
    'issueMonth': '${issued.month}',
    'certId': c.certificateId,
    'certUrl': verifyUri(c.certificateId).toString(),
  });
}

/// Opens one certificate over the screen: drawn as the website draws it, with its facts
/// and what can be done with it.
Future<void> showCertificateSheet(BuildContext context, ExamCertificate certificate, {String? holder}) {
  final name = holder ?? holderNameOf(context, certificate);
  return showDetailSheet<void>(
    context,
    topInset: 48,
    body: (_) => CertificateDetail(certificate: certificate, holder: name),
  );
}

/// The sheet's body: the certificate (pinch to read it close), its facts, and the actions.
class CertificateDetail extends StatelessWidget {
  const CertificateDetail({super.key, required this.certificate, required this.holder});

  final ExamCertificate certificate;
  final String holder;

  @override
  Widget build(BuildContext context) {
    final c = certificate;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        Text('Certificate of Knowledge Assessment', style: ExamText.heading),
        const SizedBox(height: 4),
        Text('Pinch to zoom in and read it close.', style: ExamText.small),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: DecoratedBox(
            decoration: BoxDecoration(border: Border.all(color: ExamColors.cardBorder)),
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: CertificateSheetView(certificate: c, holder: holder),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ExamCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            children: [
              _Fact('Credential', c.title),
              _Fact('Awarded by', c.providerName ?? 'Institute for Corporate Real Estate'),
              if (c.levelLabel != null) _Fact('Level', c.levelLabel!),
              _Fact('Result', '${c.percentage}% against a ${c.passPercentage}% pass standard'),
              _Fact('Cleared on', longDayLabel(c.clearedAt ?? c.issuedAt)),
              _Fact('Issued', dayLabel(c.issuedAt)),
              _Fact('Credential ID', c.certificateId, mono: true, last: true),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Issued once, on attempt #${c.attempt}. Later attempts update your history but never reissue or restate this certificate.',
          style: ExamText.small,
        ),
        const SizedBox(height: 16),
        CertificateActions(certificate: c),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value, {this.mono = false, this.last = false});

  final String label;
  final String value;
  final bool mono;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: AppColors.slate100)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 104, child: Text(label.toUpperCase(), style: ExamText.statLabel.copyWith(height: 1.5))),
          Expanded(
            child: Text(
              value,
              style: mono
                  ? AppText.plexSans(
                      13,
                      FontWeight.w700,
                      AppColors.onSurface,
                      lineHeight: 18,
                    ).copyWith(letterSpacing: 0.3)
                  : ExamText.bodyStrong,
            ),
          ),
        ],
      ),
    );
  }
}

/// Copy the number, share the verification link, open the PDF page, add to LinkedIn.
class CertificateActions extends StatelessWidget {
  const CertificateActions({super.key, required this.certificate, this.compact = false});

  final ExamCertificate certificate;

  /// For a card in a list: the two quick actions only.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = certificate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: ExamButton(
                label: 'Share',
                icon: LucideIcons.share2,
                quiet: compact,
                height: 44,
                onPressed: () => ExamServices.share('${c.title}\n${verifyUri(c.certificateId)}', subject: c.title),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ExamButton(
                label: 'Copy number',
                icon: LucideIcons.copy,
                quiet: true,
                height: 44,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: c.certificateId));
                  if (context.mounted) showMessage(context, 'Number copied');
                },
              ),
            ),
          ],
        ),
        if (!compact) ...[
          const SizedBox(height: 10),
          ExamButton(
            label: 'Download PDF on the website',
            icon: LucideIcons.download,
            quiet: true,
            height: 44,
            // The website draws the PDF; the app's own certificate sheet is the page this would otherwise open.
            onPressed: () => ExamServices.openExternal(
              context,
              AppConfig.sitePage('/learning/certificates/${c.paperSlug ?? c.paperId}'),
            ),
          ),
          const SizedBox(height: 10),
          ExamButton(
            label: 'Check it in the register',
            icon: LucideIcons.shieldCheck,
            quiet: true,
            height: 44,
            onPressed: () => ExamServices.openUrl(context, verifyUri(c.certificateId)),
          ),
          const SizedBox(height: 10),
          ExamButton(
            label: 'Add to LinkedIn',
            icon: LucideIcons.briefcase,
            quiet: true,
            height: 44,
            onPressed: () => ExamServices.openUrl(context, linkedInUri(c)),
          ),
        ],
      ],
    );
  }
}

// --- the certificate itself ----------------------------------------------------------------------------

/// Certificate of Knowledge Assessment, drawn as the website's: two panels on an A4 landscape sheet, the
/// marks on the left and the attestation on the right. The sheet holds its 1.4142 shape and scales with the
/// width it is given, as a document does.
class CertificateSheetView extends StatelessWidget {
  const CertificateSheetView({super.key, required this.certificate, required this.holder});

  final ExamCertificate certificate;
  final String holder;

  /// The sheet is drawn on a 1000 by 707 canvas and scaled; 10 units here are the website's 1 cqw.
  static const canvasWidth = 1000.0;
  static const canvasHeight = 707.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label:
          'Certificate of knowledge assessment. ${certificate.title}${certificate.levelLabel == null ? '' : ', ${certificate.levelLabel} level'}, awarded to $holder. Certificate number ${certificate.certificateId}.',
      excludeSemantics: true,
      child: AspectRatio(
        aspectRatio: canvasWidth / canvasHeight,
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: canvasWidth,
            height: canvasHeight,
            child: Stack(
              children: [
                const Positioned.fill(child: ColoredBox(color: ExamColors.azure)),
                Positioned(
                  left: 11.5,
                  top: 11.5,
                  right: 11.5,
                  bottom: 11.5,
                  child: ColoredBox(
                    color: Colors.white,
                    child: Row(
                      children: [
                        _MarksPanel(certificate: certificate),
                        Expanded(
                          child: _Attestation(certificate: certificate, holder: holder),
                        ),
                      ],
                    ),
                  ),
                ),
                const Positioned(left: 0, top: 130, child: _Wedge(topLeft: true)),
                const Positioned(right: 0, bottom: 130, child: _Wedge(topLeft: false)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The fold where the frame cuts back into the sheet.
class _Wedge extends StatelessWidget {
  const _Wedge({required this.topLeft});

  final bool topLeft;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _WedgeClip(topLeft),
      child: const SizedBox(width: 31, height: 47, child: ColoredBox(color: ExamColors.azure)),
    );
  }
}

class _WedgeClip extends CustomClipper<Path> {
  _WedgeClip(this.topLeft);

  final bool topLeft;

  @override
  Path getClip(Size s) => topLeft
      ? (Path()
          ..moveTo(0, 0)
          ..lineTo(s.width, s.height * .3)
          ..lineTo(s.width, s.height * .7)
          ..lineTo(0, s.height)
          ..close())
      : (Path()
          ..moveTo(s.width, 0)
          ..lineTo(0, s.height * .3)
          ..lineTo(0, s.height * .7)
          ..lineTo(s.width, s.height)
          ..close());

  @override
  bool shouldReclip(_WedgeClip old) => old.topLeft != topLeft;
}

const _ink = Color(0xFF1A1A1A);
const _muted = Color(0xFF4A5866);

TextStyle _t(double size, FontWeight w, Color c, {double? spacing, double? height}) =>
    AppText.plexSans(size, w, c, spacing: spacing, lineHeight: height == null ? null : size * height);

class _MarksPanel extends StatelessWidget {
  const _MarksPanel({required this.certificate});

  final ExamCertificate certificate;

  @override
  Widget build(BuildContext context) {
    final logo = certificate.providerLogoUrl == null ? null : AppConfig.absoluteUrl(certificate.providerLogoUrl);
    return SizedBox(
      width: 365,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    begin: Alignment(-0.3, -1),
                    end: Alignment(0.3, 1),
                    colors: [Color(0xFFF7FAFD), Color(0xFFEAF2F9)],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Image.asset('assets/images/brand/icr-logo.png', width: 240, height: 90, fit: BoxFit.contain),
                    Image.asset('assets/images/demo/learning/cert_seal.png', width: 210, height: 210),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (certificate.providerName != null) ...[
                          if (logo != null)
                            SizedBox(
                              width: 140,
                              height: 40,
                              child: CachedNetworkImage(
                                imageUrl: logo,
                                fit: BoxFit.contain,
                                errorWidget: (_, _, _) => const SizedBox.shrink(),
                                placeholder: (_, _) => const SizedBox.shrink(),
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            certificate.providerName!.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: _t(10, FontWeight.w700, _muted, spacing: 1.4),
                          ),
                          Text('AWARDING BODY', style: _t(10, FontWeight.w700, _muted, spacing: 1.4)),
                          const SizedBox(height: 8),
                        ],
                        Image.asset('assets/images/demo/learning/cert_partner.png', width: 150, height: 45),
                        const SizedBox(height: 4),
                        Text('KNOWLEDGE PARTNER', style: _t(10, FontWeight.w700, _muted, spacing: 1.4)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '* This certificate is issued upon successful completion of the knowledge assessment & does not constitute a professional license or statutory certification unless specifically stated.',
              style: _t(11, FontWeight.w400, ExamColors.navy, height: 1.55),
            ),
          ],
        ),
      ),
    );
  }
}

class _Attestation extends StatelessWidget {
  const _Attestation({required this.certificate, required this.holder});

  final ExamCertificate certificate;
  final String holder;

  @override
  Widget build(BuildContext context) {
    final c = certificate;
    final level = c.levelLabel;
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 34, 30, 34),
      child: Column(
        children: [
          Text(
            'CERTIFICATE',
            textAlign: TextAlign.center,
            style: AppText.workSans(54, FontWeight.w800, ExamColors.navy, lineHeight: 54, spacing: 6.5),
          ),
          const SizedBox(height: 10),
          Text('OF KNOWLEDGE ASSESSMENT', style: _t(19, FontWeight.w700, _ink, spacing: 3.6)),
          Container(
            height: 1,
            margin: const EdgeInsets.only(top: 14, left: 10, right: 10),
            color: const Color(0xFFB9C6D4),
          ),
          const SizedBox(height: 22),
          Text('This is to certify that', style: _t(19, FontWeight.w400, _ink)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            child: Text(
              holder,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.workSans(
                holder.length > 26 ? 52 : 66,
                FontWeight.w700,
                ExamColors.gold,
                lineHeight: holder.length > 26 ? 56 : 70,
              ).copyWith(fontStyle: FontStyle.italic),
            ),
          ),
          Text('For successfully completing :', style: _t(19, FontWeight.w400, _ink)),
          const SizedBox(height: 10),
          Text(
            c.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _t(26, FontWeight.w800, _ink, height: 1.25),
          ),
          if (level != null) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _Stars(),
                const SizedBox(width: 10),
                Text('${level.toUpperCase()} LEVEL', style: _t(24, FontWeight.w800, ExamColors.azure, spacing: 1.9)),
                const SizedBox(width: 10),
                const _Stars(),
              ],
            ),
          ],
          const SizedBox(height: 18),
          Text.rich(
            textAlign: TextAlign.center,
            TextSpan(
              style: _t(16, FontWeight.w400, _ink),
              children: [
                const TextSpan(text: 'The assessment was successfully cleared on : '),
                TextSpan(text: longDayLabel(c.clearedAt ?? c.issuedAt), style: _t(16, FontWeight.w800, _ink)),
              ],
            ),
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      'assets/images/demo/learning/cert_signature.png',
                      height: 42,
                      alignment: Alignment.centerLeft,
                    ),
                    Container(height: 1, color: const Color(0xFF8C9AAA)),
                    const SizedBox(height: 5),
                    Text(certificateSignatory.name, style: _t(17, FontWeight.w800, _ink, height: 1.2)),
                    Text(certificateSignatory.title, style: _t(11, FontWeight.w400, _muted, height: 1.45)),
                    Text(
                      certificateSignatory.organisation,
                      style: _t(11, FontWeight.w400, const Color(0xFF7A8794), height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // The scannable route back to the register: the code carries this certificate's own number.
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  QrView(data: verifyUri(c.certificateId).toString(), size: 90),
                  const SizedBox(height: 5),
                  Text(
                    'Scan to authenticate\nthe certificate',
                    textAlign: TextAlign.center,
                    style: _t(11, FontWeight.w400, _muted, height: 1.3),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 190,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Issued Date:', style: _t(13, FontWeight.w400, _muted)),
                    Text(stampLabel(c.issuedAt), style: _t(15, FontWeight.w800, _ink)),
                    const SizedBox(height: 12),
                    Text('CERTIFICATE NO. :', style: _t(13, FontWeight.w400, _muted)),
                    Text(c.certificateId, maxLines: 1, style: _t(15, FontWeight.w800, _ink, spacing: 0.1)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The three gold stars either side of the level.
class _Stars extends StatelessWidget {
  const _Stars();

  @override
  Widget build(BuildContext context) => const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(LucideIcons.star, size: 19, color: ExamColors.gold),
      Icon(LucideIcons.star, size: 19, color: ExamColors.gold),
      Icon(LucideIcons.star, size: 19, color: ExamColors.gold),
    ],
  );
}
