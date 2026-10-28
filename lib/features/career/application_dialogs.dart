import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'career_format.dart';
import 'career_models.dart';
import 'career_styles.dart';
import 'application_widgets.dart';

/// "Withdraw your application?" — true when the member confirms.
Future<bool> confirmWithdraw(BuildContext context, CareerApplication app) async {
  final who = app.companyName ?? 'The employer';
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      key: const ValueKey('withdraw-dialog'),
      title: const Text('Withdraw your application?'),
      content: Text(
        '$who will no longer see your application for ${app.jobTitle}. You can apply again while the job is open.',
      ),
      actions: [
        TextButton(
          key: const ValueKey('withdraw-keep'),
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Keep application'),
        ),
        TextButton(
          key: const ValueKey('withdraw-confirm'),
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Withdraw'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// What the member decided about an offer.
typedef OfferDecision = ({bool confirmed, String? note});

/// "Accept this offer?" / "Decline this offer?" with the terms and a note to the employer.
Future<OfferDecision> askOfferDecision(BuildContext context, CareerOffer offer, {required bool accept}) async {
  final decision = await showDialog<OfferDecision>(
    context: context,
    builder: (_) => _OfferDialog(offer: offer, accept: accept),
  );
  return decision ?? (confirmed: false, note: null);
}

class _OfferDialog extends StatefulWidget {
  const _OfferDialog({required this.offer, required this.accept});

  final CareerOffer offer;
  final bool accept;

  @override
  State<_OfferDialog> createState() => _OfferDialogState();
}

class _OfferDialogState extends State<_OfferDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _done(bool confirmed) {
    final text = _note.text.trim();
    Navigator.pop<OfferDecision>(context, (confirmed: confirmed, note: text.isEmpty ? null : text));
  }

  @override
  Widget build(BuildContext context) {
    final accept = widget.accept;
    final offer = widget.offer;
    return AlertDialog(
      key: ValueKey(accept ? 'accept-dialog' : 'decline-dialog'),
      title: Text(accept ? 'Accept this offer?' : 'Decline this offer?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${offer.jobTitle ?? 'The role'} • ${offerAmount(offer)}'
            '${offer.joiningDate == null ? '' : ' • joining ${formatDay(offer.joiningDate!)}'}',
            style: CareerText.bodyStrong,
          ),
          const SizedBox(height: 8),
          Text(
            accept
                ? 'The employer is told straight away and the application moves to Hired. This cannot be undone here.'
                : 'The employer is told, and the application moves to Archived. This cannot be undone here.',
            style: CareerText.body,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('offer-note'),
            controller: _note,
            minLines: 2,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: accept ? 'A note for the employer (optional)' : 'Why you are declining (optional)',
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(key: const ValueKey('offer-cancel'), onPressed: () => _done(false), child: const Text('Not yet')),
        TextButton(
          key: const ValueKey('offer-confirm'),
          onPressed: () => _done(true),
          style: TextButton.styleFrom(foregroundColor: accept ? AppColors.primary : AppColors.error),
          child: Text(accept ? 'Accept offer' : 'Decline offer'),
        ),
      ],
    );
  }
}

/// "Can't make it" → the time the member suggests; null when they back out.
Future<String?> askForAnotherTime(BuildContext context, CareerInterview iv) {
  return showDialog<String>(
    context: context,
    builder: (_) => _AnotherTimeDialog(interview: iv),
  );
}

class _AnotherTimeDialog extends StatefulWidget {
  const _AnotherTimeDialog({required this.interview});

  final CareerInterview interview;

  @override
  State<_AnotherTimeDialog> createState() => _AnotherTimeDialogState();
}

class _AnotherTimeDialogState extends State<_AnotherTimeDialog> {
  final _text = TextEditingController();
  String? _problem;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send() {
    final t = _text.text.trim();
    if (t.isEmpty) {
      setState(() => _problem = 'Say when you could do instead.');
      return;
    }
    Navigator.pop(context, t);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('another-time-dialog'),
      title: const Text('Ask for another time'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.interview.name} is on ${formatWhen(widget.interview.scheduledAt)}. '
            'Your message goes to the hiring team.',
            style: CareerText.body,
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('another-time-text'),
            controller: _text,
            minLines: 2,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'For example: Thursday after 3 pm, or any morning',
              isDense: true,
              border: const OutlineInputBorder(),
              errorText: _problem,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(key: const ValueKey('another-time-send'), onPressed: _send, child: const Text('Send message')),
      ],
    );
  }
}

/// The message that confirms a round (the API has no RSVP for a candidate).
String confirmRoundMessage(CareerApplication app, CareerInterview iv) =>
    'Hello, I confirm I will attend ${iv.name} for ${app.jobTitle} on ${formatWhen(iv.scheduledAt)}.';

/// The message that asks for another time for a round.
String rescheduleRoundMessage(CareerApplication app, CareerInterview iv, String proposal) =>
    'Hello, I cannot make ${iv.name} for ${app.jobTitle} on ${formatWhen(iv.scheduledAt)}. $proposal';
