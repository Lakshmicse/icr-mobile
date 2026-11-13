import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/title_bar.dart';
import 'api_exam_repository.dart';
import 'certificate_view.dart';
import 'certificates_controller.dart';
import 'demo_exam_repository.dart';
import 'exam_format.dart';
import 'exam_models.dart';
import 'exam_repository.dart';
import 'exam_styles.dart';
import 'exam_widgets.dart';
import 'verify_sheet.dart';
import '../notifications/notifications_screen.dart';

/// The certificates the member has earned: each a row, as the attempts are listed, opening the certificate
/// itself, with its credential number to copy, a verification link to share, and the PDF on the website.
///
/// Reads `GET /learning/me/certificates`. [repository] is a seam for tests.
class CertificatesScreen extends StatefulWidget {
  const CertificatesScreen({super.key, required this.onBack, this.repository, this.holder});

  final VoidCallback onBack;
  final ExamRepository? repository;

  /// Who the certificates are made out to; the signed-in person when not given (a seam for tests).
  final String? holder;

  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen> {
  late final ExamRepository _repo;
  late final CertificatesController _controller;

  @override
  void initState() {
    super.initState();
    _repo =
        widget.repository ??
        (AppConfig.demo ? DemoExamRepository() : ApiExamRepository(api: context.read<ApiClient>()));
    _controller = CertificatesController(_repo)..start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final c = _controller;
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                TitleBar(
                  title: 'My Certificates',
                  onBack: widget.onBack,
                  unread: c.unread,
                  onBell: () => openNotifications(context),
                ),
                Expanded(child: _body(c)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _body(CertificatesController c) {
    if (c.loading && c.all.isEmpty) return const ExamSpinner();
    if (c.error != null && c.all.isEmpty) {
      return SingleChildScrollView(
        child: ScreenNotice(
          icon: LucideIcons.award,
          title: 'Unable to Load Your Certificates',
          body: c.error!,
          action: 'Try Again',
          onAction: c.refresh,
        ),
      );
    }
    final rows = c.shown;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: c.refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (c.all.isEmpty)
            SliverToBoxAdapter(
              child: ScreenNotice(
                icon: LucideIcons.award,
                title: 'No Certificates Yet',
                body:
                    'Complete and pass a qualifying assessment to earn your ICR certificate. Your certificate will be available '
                    'here for future access and verification.',
                action: 'Back to Learning',
                onAction: widget.onBack,
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            value: '${c.all.length}',
                            label: 'Certificates Earned',
                            icon: LucideIcons.award,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatTile(
                            value: c.best == null ? '-' : '${c.best}%',
                            label: 'Best Assessment Score',
                            icon: LucideIcons.trophy,
                            color: AppColors.amber500,
                          ),
                        ),
                      ],
                    ),
                    if (c.bodies.length > 1) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _BodyChip(label: 'All Certificates', on: c.body == null, onTap: () => c.setBody(null)),
                          for (final b in c.bodies) _BodyChip(label: b, on: c.body == b, onTap: () => c.setBody(b)),
                        ],
                      ),
                    ],
                    if (c.error != null) ...[
                      const SizedBox(height: 12),
                      Notice(tone: NoticeTone.error, text: c.error!, action: 'Try Again', onAction: c.refresh),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.separated(
                itemCount: rows.length,
                // Rows parted by a hairline, as the attempts are (owner, 9 Nov 2026).
                separatorBuilder: (_, _) => const Divider(height: 1, thickness: 1, color: AppColors.slate100),
                itemBuilder: (context, i) => CertificateCard(certificate: rows[i], holder: widget.holder),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                child: _VerifyCard(onOpen: () => showVerifySheet(context, _repo)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BodyChip extends StatelessWidget {
  const _BodyChip({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // An awarding body can have a long name: the chip gives up width before the row overflows.
    final shape = StadiumBorder(side: on ? BorderSide.none : const BorderSide(color: AppColors.outlineVariant));
    return Semantics(
      button: true,
      selected: on,
      label: label,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 32),
        child: Material(
          color: on ? AppColors.primary : Colors.white,
          shape: shape,
          child: InkWell(
            onTap: onTap,
            customBorder: shape,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.workSans(13, FontWeight.w600, on ? Colors.white : AppColors.onSurface, lineHeight: 18),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// How someone else checks a credential: the register, no account needed.
class _VerifyCard extends StatelessWidget {
  const _VerifyCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return ExamCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Verify Your Credentials', style: ExamText.heading),
          const SizedBox(height: 6),
          Text(
            'Every ICR certificate has a unique verification number. Anyone can verify its authenticity through the ICR '
            'Certificate Register. No account is required.',
            style: ExamText.body,
          ),
          const SizedBox(height: 12),
          ExamButton(label: 'Verify a Certificate', icon: LucideIcons.shieldCheck, quiet: true, onPressed: onOpen),
        ],
      ),
    );
  }
}

/// A certificate as a row of the list, drawn as an attempt is (owner, 9 Nov 2026: "how the list of attempts is
/// showing, the certificates also show like that"): the title and its Verified pill, the credential number and the
/// day it was issued, then the score, the pass mark and who awarded it, with a chevron. A tap opens the certificate
/// itself, where Share and Copy number live.
class CertificateCard extends StatelessWidget {
  const CertificateCard({super.key, required this.certificate, this.holder});

  final ExamCertificate certificate;

  /// Who the certificate is made out to; the signed-in person when not given.
  final String? holder;

  @override
  Widget build(BuildContext context) {
    final c = certificate;
    final holder = this.holder ?? holderNameOf(context, c);
    final issued = c.issuedAt == null ? '' : ' · Issued ${dayLabel(c.issuedAt)}';
    return Semantics(
      button: true,
      label: '${c.title}, ${c.certificateId}, awarded by ${c.awardedBy}$issued. Opens the certificate.',
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('certificate-${c.id}'),
        onTap: () => showCertificateSheet(context, c, holder: holder),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      c.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ExamText.subheading.copyWith(fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const InfoPill(
                    label: 'Verified',
                    icon: LucideIcons.badgeCheck,
                    color: AppColors.emerald700,
                    fill: AppColors.emerald50,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('${c.certificateId}$issued', style: ExamText.small),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Figure('${c.percentage}%', 'Score', big: true),
                  _Figure('${c.passPercentage}%', 'Pass Mark'),
                  _Figure(c.awardedBy, 'Awarded By'),
                  const Icon(LucideIcons.chevronRight, size: 20, color: AppColors.slate400),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A figure of the row: the value over its small label, as the attempts draw theirs.
class _Figure extends StatelessWidget {
  const _Figure(this.value, this.label, {this.big = false});

  final String value;
  final String label;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.workSans(big ? 20 : 15, FontWeight.w800, big ? AppColors.primary : AppColors.onSurface),
          ),
          Text(label.toUpperCase(), style: ExamText.statLabel),
        ],
      ),
    );
  }
}

/// A small stand-in for the certificate itself, as the website's cards draw it: a double frame, the holder's
/// name in italics, the credential and its level.
class CertificateThumb extends StatelessWidget {
  const CertificateThumb({super.key, required this.certificate, required this.holder});

  final ExamCertificate certificate;
  final String holder;

  @override
  Widget build(BuildContext context) {
    final level = certificate.levelLabel;
    return Container(
      height: 148,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: ExamColors.navy, width: 2),
      ),
      child: Container(
        margin: const EdgeInsets.all(5),
        decoration: BoxDecoration(border: Border.all(color: AppColors.outlineVariant)),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'CERTIFICATE OF ACHIEVEMENT',
              style: AppText.plexSans(8, FontWeight.w800, AppColors.primary, spacing: 1.7),
            ),
            const SizedBox(height: 6),
            Text(
              holder,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.workSans(
                19,
                FontWeight.w700,
                ExamColors.navy,
                lineHeight: 22,
              ).copyWith(fontStyle: FontStyle.italic),
            ),
            Container(
              width: 44,
              height: 1,
              margin: const EdgeInsets.symmetric(vertical: 6),
              color: AppColors.outlineVariant,
            ),
            Text(
              certificate.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppText.plexSans(10.5, FontWeight.w700, ExamColors.navy, lineHeight: 14),
            ),
            if (level != null) ...[
              const SizedBox(height: 2),
              Text('$level level', style: AppText.plexSans(9, FontWeight.w700, AppColors.inkMuted)),
            ],
          ],
        ),
      ),
    );
  }
}
