import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import 'event_format.dart';
import 'event_models.dart';
import 'events_styles.dart';
import 'widgets/qr_code.dart';

/// "Show Pass" / "View Pass & QR": the member's place at an event as a card
/// with a code to scan. ICR issues no ticket number or QR to a member, so the
/// pass carries the event's code and the QR leads to the event's page on the
/// website, where the seat is on the member's account.
Future<void> showEventPass(
  BuildContext context, {
  required EventSummary event,
  required EventPass pass,
  required Uri link,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => EventPassDialog(event: event, pass: pass, link: link),
  );
}

class EventPassDialog extends StatelessWidget {
  const EventPassDialog({super.key, required this.event, required this.pass, required this.link});

  final EventSummary event;
  final EventPass pass;
  final Uri link;

  @override
  Widget build(BuildContext context) {
    final code = QrCode.tryEncode(link.toString());
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  height: 17,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: EventsColors.activePill, borderRadius: BorderRadius.circular(8.5)),
                  child: Text('Active Pass', style: EventsText.activePill),
                ),
                const Spacer(),
                Semantics(
                  button: true,
                  label: 'Close',
                  child: InkResponse(
                    onTap: () => Navigator.of(context).maybePop(),
                    radius: 18,
                    child: const SizedBox(
                      width: 28,
                      height: 28,
                      child: Icon(LucideIcons.x, size: 18, color: AppColors.onSurface),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              event.title,
              textAlign: TextAlign.center,
              style: EventsText.barTitle.copyWith(fontSize: 14, height: 19 / 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${longDay(event.startsAt)} • ${timeRange(event)}',
              textAlign: TextAlign.center,
              style: EventsText.passHolder,
            ),
            const SizedBox(height: 14),
            Center(
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: EventsColors.border),
                ),
                child: code == null
                    ? const SizedBox(
                        width: 180,
                        height: 180,
                        child: Icon(LucideIcons.qrCode, size: 64, color: AppColors.outline),
                      )
                    : QrView(code: code, size: 180),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              pass.reference == null ? 'Your place' : 'Pass #${pass.reference}',
              textAlign: TextAlign.center,
              style: EventsText.passTitle.copyWith(fontSize: 13, height: 17 / 12.5),
            ),
            const SizedBox(height: 2),
            Text('${pass.role} • ${pass.holder}', textAlign: TextAlign.center, style: EventsText.passHolder),
            const SizedBox(height: 6),
            Text(
              "Scan to open the event's page, where your place is on your account.",
              textAlign: TextAlign.center,
              style: EventsText.attendeesNote.copyWith(color: AppColors.outline, height: 14 / 9.1),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => openUrl(context, link),
                    icon: const Icon(LucideIcons.externalLink, size: 14),
                    label: Text('Event page', style: EventsText.footerButton),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.onSurface,
                      minimumSize: const Size.fromHeight(38),
                      side: const BorderSide(color: EventsColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(38),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Done', style: EventsText.barPrimary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
