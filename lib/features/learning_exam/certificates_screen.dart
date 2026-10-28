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

/// The certificates the member has earned: each drawn as a card, opening the certificate itself,
/// with its credential number to copy, a verification link to share, and the PDF on the website.
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
                  title: 'My certificates',
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
          title: "Couldn't load your certificates",
          body: c.error!,
          action: 'Try again',
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
                title: 'No certificates yet',
                body:
                    'Pass a certifying assessment and its certificate is issued here, for good, whatever later attempts score.',
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
                          child: StatTile(value: '${c.all.length}', label: 'Earned', icon: LucideIcons.award),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatTile(
                            value: c.best == null ? '-' : '${c.best}%',
                            label: 'Best score',
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
                          _BodyChip(label: 'All certificates', on: c.body == null, onTap: () => c.setBody(null)),
                          for (final b in c.bodies) _BodyChip(label: b, on: c.body == b, onTap: () => c.setBody(b)),
                        ],
                      ),
                    ],
                    if (c.error != null) ...[
                      const SizedBox(height: 12),
                      Notice(tone: NoticeTone.error, text: c.error!, action: 'Try again', onAction: c.refresh),
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
                separatorBuilder: (_, _) => const SizedBox(height: 14),
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
          Text('Verification', style: ExamText.heading),
          const SizedBox(height: 6),
          Text(
            "Every certificate carries a number anyone can check against ICR's register, no account needed. Share hands over that link; the register confirms the holder, the credential and the date it was issued.",
            style: ExamText.body,
          ),
          const SizedBox(height: 12),
          ExamButton(
            label: 'Check a certificate number',
            icon: LucideIcons.shieldCheck,
            quiet: true,
            onPressed: onOpen,
          ),
        ],
      ),
    );
  }
}

/// One credential: a small stand-in for the certificate, its facts, and what can be done with it.
class CertificateCard extends StatelessWidget {
  const CertificateCard({super.key, required this.certificate, this.holder});

  final ExamCertificate certificate;

  /// Who the certificate is made out to; the signed-in person when not given.
  final String? holder;

  @override
  Widget build(BuildContext context) {
    final c = certificate;
    final holder = this.holder ?? holderNameOf(context, c);
    return ExamCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: AppColors.primary.withValues(alpha: 0.04),
            padding: const EdgeInsets.all(14),
            child: CertificateThumb(certificate: c, holder: holder),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(c.title, style: ExamText.heading)),
                    const SizedBox(width: 8),
                    const InfoPill(
                      label: 'Verified',
                      icon: LucideIcons.badgeCheck,
                      color: AppColors.emerald700,
                      fill: AppColors.emerald50,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(c.awardedBy, style: AppText.workSans(13.5, FontWeight.w700, AppColors.primary)),
                const SizedBox(height: 10),
                _CardFact('Issued', dayLabel(c.issuedAt)),
                _CardFact('Credential ID', c.certificateId, mono: true),
                const SizedBox(height: 12),
                ExamButton(
                  label: 'View certificate',
                  icon: LucideIcons.award,
                  onPressed: () => showCertificateSheet(context, c, holder: holder),
                ),
                const SizedBox(height: 10),
                CertificateActions(certificate: c, compact: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardFact extends StatelessWidget {
  const _CardFact(this.label, this.value, {this.mono = false});

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.slate100)),
      ),
      child: Row(
        children: [
          Text(label.toUpperCase(), style: ExamText.statLabel),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: mono
                  ? AppText.plexSans(12.5, FontWeight.w700, AppColors.onSurface).copyWith(letterSpacing: 0.3)
                  : ExamText.bodyStrong.copyWith(fontSize: 14),
            ),
          ),
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
