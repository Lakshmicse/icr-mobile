import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../rfq_format.dart';
import '../rfq_models.dart';
import '../rfq_rules.dart';
import '../rfq_styles.dart';
import '../rfq_uploads.dart';
import 'composer_parts.dart' show AttachmentsPanel, ToggleChip;
import 'requirement_parts.dart' show FileThumb;
import 'rfq_widgets.dart';
import 'supplier_parts.dart' show RfqSmallButton, leadTimeLabel, myBidStatusLabel, myBidTone;

/// The card the supplier's response lives in: an icon, a title that says what they can do now, and its words.
class ResponseCard extends StatelessWidget {
  const ResponseCard({super.key, required this.title, required this.child, this.caption, this.icon = LucideIcons.send});

  final String title;
  final String? caption;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RfqCard(
      key: const ValueKey('response-card'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: AppColors.chipEmphasis, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, key: const ValueKey('response-title'), style: RfqText.section),
              ),
            ],
          ),
          if (caption != null) ...[const SizedBox(height: 6), Text(caption!, style: RfqText.formHelp)],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// A plain paragraph in the response card (closed, declined, being screened).
class ResponseNote extends StatelessWidget {
  const ResponseNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: RfqText.body);
}

/// Whether a refusal is about the plan (a bid allowance or a plan feature): the words "See plans" are offered.
bool mentionsPlan(String? message) =>
    message != null && RegExp(r'\b(plan|bids?|upgrade|tier)\b', caseSensitive: false).hasMatch(message);

// ---- The reply -------------------------------------------------------------------------------------------

/// The supplier's reply: an enquiry reply is a message with an optional indicative price (and never uses the
/// monthly allowance), an RFQ quote needs a price. Every rule the API holds is said here before sending, and
/// whatever it still refuses (a used-up plan, an unverified listing, a closed requirement) is shown in the API's
/// own words with the form kept as typed.
class ReplyForm extends StatefulWidget {
  const ReplyForm({
    super.key,
    required this.enquiry,
    required this.uploader,
    required this.onSend,
    required this.onPick,
    this.initial,
    this.editing = false,
    this.allowance,
    this.blocker,
    this.invited = false,
    this.onDecline,
    this.onCancel,
    this.onSeePlans,
    this.stageNote,
  });

  final bool enquiry;
  final AttachmentUploader uploader;

  /// Sends the draft; answers the API's sentence when it refuses, null when it went.
  final Future<String?> Function(BidDraft draft) onSend;

  /// Opens the phone's file picker and hands the files to the uploader.
  final Future<void> Function() onPick;

  /// The bid being changed: the form starts from it.
  final BidDraft? initial;
  final bool editing;
  final String? allowance;

  /// Why it cannot be sent yet (not verified, no bids left), known before the API says so.
  final String? blocker;
  final bool invited;
  final Future<void> Function()? onDecline;
  final VoidCallback? onCancel;
  final VoidCallback? onSeePlans;

  /// A line above the form ("You've been shortlisted: submit your detailed quote below.").
  final String? stageNote;

  @override
  State<ReplyForm> createState() => _ReplyFormState();
}

class _ReplyFormState extends State<ReplyForm> {
  late final BidDraft _draft = widget.initial ?? BidDraft();
  bool _tried = false;
  bool _busy = false;
  String? _error;

  Map<String, String> get _problems => _tried ? _draft.problems(enquiry: widget.enquiry) : const {};

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _tried = true;
      _error = null;
    });
    _draft.attachments = widget.uploader.files;
    if (_draft.problems(enquiry: widget.enquiry).isNotEmpty) return;
    setState(() => _busy = true);
    final error = await widget.onSend(_draft);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final enquiry = widget.enquiry;
    final problems = _problems;
    final u = widget.uploader;
    return ListenableBuilder(
      listenable: u,
      builder: (context, _) {
        // An unverified listing or a used-up plan is said up front, but the button stays: what the API answers is the
        // sentence that names the plan and the way on, and stale numbers here must never be what stops a reply.
        final blocked = widget.blocker != null;
        final disabled = _busy || u.uploading;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.stageNote != null) ...[
              RfqBanner(widget.stageNote!, tone: Tone.green, icon: LucideIcons.circleCheck),
              const SizedBox(height: 12),
            ],
            if (widget.invited && widget.onDecline != null) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                decoration: BoxDecoration(color: rfqPanelColor, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        enquiry
                            ? 'You\'ve been invited to reply to this enquiry.'
                            : 'You\'ve been invited to quote on this requirement.',
                        style: RfqText.meta,
                      ),
                    ),
                    TextButton(
                      key: const ValueKey('reply-decline'),
                      onPressed: _busy ? null : () => widget.onDecline!(),
                      child: Text('Decline', style: RfqText.link.copyWith(color: AppColors.slate600)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (widget.allowance != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(LucideIcons.info, size: 14, color: AppColors.slate500),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(widget.allowance!, key: const ValueKey('reply-allowance'), style: RfqText.small),
                    ),
                  ],
                ),
              ),
            if (blocked) ...[
              RfqBanner(
                widget.blocker!,
                tone: Tone.amber,
                icon: LucideIcons.triangleAlert,
                action: widget.onSeePlans != null && mentionsPlan(widget.blocker) ? 'See plans' : null,
                onAction: widget.onSeePlans,
              ),
              const SizedBox(height: 12),
            ],
            if (enquiry) ...[
              _message(
                problems,
                label: 'Your reply',
                hint: 'How you would handle it, availability, anything you need to know…',
                lines: 5,
              ),
              const SizedBox(height: 14),
            ],
            RfqField(
              fieldKey: const ValueKey('reply-amount'),
              label: enquiry ? 'Indicative price' : 'Your price',
              value: _draft.amount,
              prefixText: '₹ ',
              optional: enquiry,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              help: enquiry ? 'Optional.' : 'Your total for the work as described.',
              error: problems['amount'],
              onChanged: (v) => setState(() => _draft.amount = v),
            ),
            const SizedBox(height: 14),
            RfqField(
              fieldKey: const ValueKey('reply-lead'),
              label: 'Lead time',
              value: _draft.leadTime,
              suffixText: 'days',
              optional: true,
              keyboardType: TextInputType.number,
              error: problems['leadTime'],
              onChanged: (v) => setState(() => _draft.leadTime = v),
            ),
            if (!enquiry) ...[
              const SizedBox(height: 14),
              _message(
                problems,
                label: 'Message to buyer',
                hint: 'What is included, assumptions, how long the price holds…',
                lines: 3,
                optional: true,
              ),
            ],
            const SizedBox(height: 14),
            FieldLabel(enquiry ? 'Supporting files' : 'Quotation & supporting files', optional: true),
            const SizedBox(height: 2),
            Text(
              enquiry
                  ? 'Photos, a brochure or anything that helps your reply. Only this buyer can open them.'
                  : 'Your priced quotation, compliance certificates or reference photos. Only this buyer can open them.',
              style: RfqText.formHelp,
            ),
            const SizedBox(height: 8),
            AttachmentsPanel(
              files: u.files,
              uploads: u.uploads,
              max: u.max,
              busy: u.uploading,
              error: problems['attachments'],
              notice: u.notice,
              onDismissNotice: u.dismissNotice,
              onPick: widget.onPick,
              onTitle: u.setTitle,
              onRemove: u.remove,
              onRetry: u.retry,
              onDismiss: u.dismiss,
              help: 'PDF, Office, text, zip or images, up to 10 MB each, ${u.max} files at most.',
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              RfqBanner(
                _error!,
                key: const ValueKey('reply-error'),
                action: widget.onSeePlans != null && mentionsPlan(_error) ? 'See plans' : null,
                onAction: widget.onSeePlans,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('reply-send'),
              onPressed: disabled ? null : _send,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(LucideIcons.send, size: 16),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              label: Text(
                _busy ? 'Sending…' : (widget.editing ? 'Save changes' : (enquiry ? 'Send reply' : 'Submit quote')),
              ),
            ),
            if (widget.onCancel != null)
              TextButton(
                key: const ValueKey('reply-cancel'),
                onPressed: _busy ? null : widget.onCancel,
                child: Text('Keep the bid as it is', style: RfqText.link),
              ),
            const SizedBox(height: 6),
            Text(
              u.uploading
                  ? 'Wait for your files to finish uploading.'
                  : 'Only the buyer\'s team sees your reply and files.',
              textAlign: TextAlign.center,
              style: RfqText.small,
            ),
          ],
        );
      },
    );
  }

  Widget _message(
    Map<String, String> problems, {
    required String label,
    required String hint,
    required int lines,
    bool optional = false,
  }) {
    final over = _draft.message.length;
    return RfqField(
      fieldKey: const ValueKey('reply-message'),
      label: label,
      value: _draft.message,
      hint: hint,
      optional: optional,
      minLines: lines,
      maxLines: lines + 6,
      maxLength: RfqLimits.bidMessage,
      keyboardType: TextInputType.multiline,
      help: widget.enquiry
          ? 'Say how you would do the work and when you could start. ($over / ${RfqLimits.bidMessage})'
          : null,
      error: problems['message'],
      onChanged: (v) => setState(() => _draft.message = v),
    );
  }
}

// ---- What was sent ------------------------------------------------------------------------------------------

/// What the supplier sent, read back: the price, the lead time, the message, the files and where it stands, with
/// the buttons to change or withdraw it where the API allows.
class MyReplySummary extends StatelessWidget {
  const MyReplySummary({
    super.key,
    required this.bid,
    required this.enquiry,
    required this.onOpenFile,
    this.justSent = false,
    this.onEdit,
    this.onWithdraw,
    this.busy = false,
    this.onSeeBids,
    this.changesNeedBuyer = false,
  });

  final MyBid bid;
  final bool enquiry;
  final ValueChanged<RfqFile> onOpenFile;
  final bool justSent;

  /// Null where the API has no call to change a bid (or it can no longer be changed).
  final VoidCallback? onEdit;
  final VoidCallback? onWithdraw;
  final bool busy;
  final VoidCallback? onSeeBids;

  /// The bid could still be corrected but the API has no call for it: say so, and that the buyer is the way.
  final bool changesNeedBuyer;

  @override
  Widget build(BuildContext context) {
    final statusBid = bid;
    return Column(
      key: const ValueKey('my-reply'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (justSent) ...[
          RfqBanner(
            enquiry ? 'Your reply was sent.' : 'Your quote was submitted.',
            tone: Tone.green,
            icon: LucideIcons.circleCheck,
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(child: Text(bid.createdAt == null ? '' : 'Sent ${fullDay(bid.createdAt!)}', style: RfqText.small)),
            TonePill(myBidStatusLabel(statusBid), tone: myBidTone(statusBid)),
          ],
        ),
        const SizedBox(height: 10),
        if (bid.amount != null) _row(enquiry ? 'Indicative price' : 'Your price', formatInr(bid.amount!), strong: true),
        if (bid.leadTimeDays != null) _row('Lead time', leadTimeLabel(bid.leadTimeDays!)),
        if (bid.poNumber != null) _row('Purchase order', bid.poNumber!, strong: true),
        if (bid.message != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.only(left: 10),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: AppColors.slate200, width: 3)),
            ),
            child: Text(bid.message!, key: const ValueKey('my-reply-message'), style: RfqText.body),
          ),
        ],
        if (bid.files.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final f in bid.files)
            InkWell(
              key: ValueKey('my-reply-file-${f.id}'),
              onTap: () => onOpenFile(f),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    FileThumb(file: f, size: 30),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(f.title, style: RfqText.link, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ),
        ],
        if (onEdit != null || onWithdraw != null) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onEdit != null)
                RfqSmallButton(
                  key: const ValueKey('reply-edit'),
                  label: 'Edit bid',
                  icon: LucideIcons.pencil,
                  onTap: busy ? null : onEdit,
                ),
              if (onWithdraw != null)
                RfqSmallButton(
                  key: const ValueKey('reply-withdraw'),
                  label: 'Withdraw',
                  icon: LucideIcons.undo2,
                  danger: true,
                  busy: busy,
                  onTap: onWithdraw,
                ),
            ],
          ),
        ],
        if (changesNeedBuyer) ...[
          const SizedBox(height: 12),
          Row(
            key: const ValueKey('bid-changes-note'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(LucideIcons.info, size: 14, color: AppColors.slate500),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'A sent ${enquiry ? 'reply' : 'quote'} cannot be changed or withdrawn on ICR yet. To correct it, message the buyer.',
                  style: RfqText.small,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(
            text: 'One reply per requirement. ',
            style: RfqText.small,
            children: [
              if (onSeeBids != null)
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    key: const ValueKey('see-all-bids'),
                    onTap: onSeeBids,
                    child: Text('See all your bids', style: RfqText.link.copyWith(fontSize: 12)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(String label, String value, {bool strong = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label, style: RfqText.meta)),
        Text(value, style: strong ? RfqText.amount.copyWith(fontSize: 14) : RfqText.metaStrong),
      ],
    ),
  );
}

// ---- Pre-qualification --------------------------------------------------------------------------------------

/// A supplier's answers to a staged RFQ's criteria (years, turnover, size, reach, compliance), checked as the API
/// checks them and sent for the buyer to screen.
class PreQualForm extends StatefulWidget {
  const PreQualForm({super.key, required this.onSend, required this.onPickEmployees, this.blocker});

  final Future<String?> Function(PreQualDraft draft) onSend;

  /// Picks an employee-count bucket (a sheet over [companySizes]); answers the bucket, '' for none, null to leave it.
  final Future<String?> Function(String current) onPickEmployees;
  final String? blocker;

  @override
  State<PreQualForm> createState() => _PreQualFormState();
}

class _PreQualFormState extends State<PreQualForm> {
  final _draft = PreQualDraft();
  bool _tried = false;
  bool _busy = false;
  String? _error;

  Map<String, String> get _problems => _tried ? _draft.problems() : const {};

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _tried = true;
      _error = null;
    });
    if (_draft.problems().isNotEmpty) return;
    setState(() => _busy = true);
    final error = await widget.onSend(_draft);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = _problems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.blocker != null) ...[
          RfqBanner(widget.blocker!, tone: Tone.amber, icon: LucideIcons.triangleAlert),
          const SizedBox(height: 12),
        ],
        RfqField(
          fieldKey: const ValueKey('pq-years'),
          label: 'Years in business',
          value: _draft.yearsInBusiness,
          optional: true,
          keyboardType: TextInputType.number,
          suffixText: 'years',
          error: p['yearsInBusiness'],
          onChanged: (v) => setState(() => _draft.yearsInBusiness = v),
        ),
        const SizedBox(height: 14),
        RfqField(
          fieldKey: const ValueKey('pq-turnover'),
          label: 'Annual turnover',
          value: _draft.annualTurnover,
          optional: true,
          prefixText: '₹ ',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          error: p['annualTurnover'],
          onChanged: (v) => setState(() => _draft.annualTurnover = v),
        ),
        const SizedBox(height: 14),
        RfqField(
          fieldKey: const ValueKey('pq-turnover-3'),
          label: 'Turnover over the last 3 years',
          value: _draft.last3YrTurnover,
          optional: true,
          prefixText: '₹ ',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          error: p['last3YrTurnover'],
          onChanged: (v) => setState(() => _draft.last3YrTurnover = v),
        ),
        const SizedBox(height: 14),
        PickerField(
          key: const ValueKey('pq-employees'),
          label: 'Employees',
          optional: true,
          value: _draft.employeeCount.isEmpty ? null : sizeLabel(_draft.employeeCount),
          hint: 'Select a size',
          onTap: () async {
            final picked = await widget.onPickEmployees(_draft.employeeCount);
            if (picked != null && mounted) setState(() => _draft.employeeCount = picked);
          },
        ),
        const SizedBox(height: 14),
        const FieldLabel('Presence', optional: true),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final presence in Presence.values)
              ToggleChip(
                key: ValueKey('pq-presence-${presence.wire}'),
                label: presence.label,
                on: _draft.presence == presence,
                onTap: () => setState(() => _draft.presence = _draft.presence == presence ? null : presence),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const FieldLabel('Statutory compliance', optional: true),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in statutoryCompliance.entries)
              ToggleChip(
                key: ValueKey('pq-compliance-${e.key}'),
                label: e.value,
                on: _draft.compliance.contains(e.key),
                onTap: () => setState(() {
                  final next = {..._draft.compliance};
                  if (!next.remove(e.key)) next.add(e.key);
                  _draft.compliance = next;
                }),
              ),
          ],
        ),
        if (_error != null) ...[const SizedBox(height: 14), RfqBanner(_error!, key: const ValueKey('pq-error'))],
        const SizedBox(height: 16),
        FilledButton(
          key: const ValueKey('pq-send'),
          onPressed: _busy || widget.blocker != null ? null : _send,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Send pre-qualification response'),
        ),
        const SizedBox(height: 6),
        Text('Only the buyer\'s team sees your answers.', textAlign: TextAlign.center, style: RfqText.small),
      ],
    );
  }
}

// ---- The buyer ---------------------------------------------------------------------------------------------------

/// Reaching the buyer outside the reply: a chat about this requirement in the app, and the buyer's contact details
/// where the plan includes them (a supplier who has not bid is refused, and the API says so).
class ContactBuyerCard extends StatefulWidget {
  const ContactBuyerCard({super.key, required this.onMessage, required this.onReveal, this.contact, this.onSeePlans});

  /// Opens the thread with the buyer; answers the API's sentence when it cannot.
  final Future<String?> Function() onMessage;

  /// Reveals the contact details; answers the API's sentence when it refuses.
  final Future<String?> Function() onReveal;
  final BuyerContact? contact;
  final VoidCallback? onSeePlans;

  @override
  State<ContactBuyerCard> createState() => _ContactBuyerCardState();
}

class _ContactBuyerCardState extends State<ContactBuyerCard> {
  bool _messaging = false;
  bool _revealing = false;
  String? _error;

  Future<void> _message() async {
    setState(() {
      _messaging = true;
      _error = null;
    });
    final error = await widget.onMessage();
    if (!mounted) return;
    setState(() {
      _messaging = false;
      _error = error;
    });
  }

  Future<void> _reveal() async {
    setState(() {
      _revealing = true;
      _error = null;
    });
    final error = await widget.onReveal();
    if (!mounted) return;
    setState(() {
      _revealing = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final contact = widget.contact;
    return RfqCard(
      key: const ValueKey('contact-buyer'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Contact the buyer', style: RfqText.section),
          const SizedBox(height: 6),
          Text(
            'Ask about the scope, the site or the timeline. The buyer\'s replies arrive in your messages.',
            style: RfqText.formHelp,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('contact-message'),
            onPressed: _messaging ? null : _message,
            icon: _messaging
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(LucideIcons.messageSquare, size: 16),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            label: const Text('Message the buyer'),
          ),
          const SizedBox(height: 8),
          if (contact == null)
            OutlinedButton.icon(
              key: const ValueKey('contact-reveal'),
              onPressed: _revealing ? null : _reveal,
              icon: const Icon(LucideIcons.eye, size: 16),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              label: const Text('Show contact details'),
            )
          else
            Container(
              key: const ValueKey('contact-details'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: rfqPanelColor, borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contact.name, style: RfqText.bodyStrong),
                  if (contact.companyName != null) Text(contact.companyName!, style: RfqText.meta),
                  if (contact.email != null) _detail(LucideIcons.mail, contact.email!),
                  if (contact.phone != null) _detail(LucideIcons.phone, contact.phone!),
                ],
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            RfqBanner(
              _error!,
              key: const ValueKey('contact-error'),
              tone: Tone.amber,
              icon: LucideIcons.info,
              action: widget.onSeePlans != null && mentionsPlan(_error) ? 'See plans' : null,
              onAction: widget.onSeePlans,
            ),
          ],
        ],
      ),
    );
  }

  Widget _detail(IconData icon, String value) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        Icon(icon, size: 14, color: AppColors.slate500),
        const SizedBox(width: 8),
        Expanded(child: SelectableText(value, style: RfqText.metaStrong)),
      ],
    ),
  );
}

// ---- The match ------------------------------------------------------------------------------------------------------

/// How well the requirement fits the supplier, from the breakdown the board ranks by: every line is a rule the API
/// scored.
class MatchCard extends StatelessWidget {
  const MatchCard({super.key, required this.score, required this.matched, required this.reasons});

  final int score;
  final bool matched;
  final List<MatchReason> reasons;

  static const _words = {
    'category': 'Your service category',
    'location': 'Your service area',
    'rating': 'Your buyer rating',
    'trust': 'Your verification level',
    'premium': 'Premium membership',
  };

  @override
  Widget build(BuildContext context) {
    final label = score >= 70 ? 'Strong match' : (score >= 40 ? 'Good match' : 'Partial match');
    final ordered = [for (final key in _words.keys) ?reasons.where((r) => r.key == key).firstOrNull];
    return RfqCard(
      key: const ValueKey('match-card'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How you match', style: RfqText.section),
          const SizedBox(height: 2),
          Text('Scored by the same rules the Find Work board ranks by.', style: RfqText.formHelp),
          const SizedBox(height: 12),
          Row(
            children: [
              MatchRing(score: score, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, key: const ValueKey('match-label'), style: RfqText.cardTitle),
                    Text(matched ? 'In a category you list' : 'Outside the categories you list', style: RfqText.small),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final r in ordered)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                key: ValueKey('match-${r.key}'),
                children: [
                  Icon(
                    r.hit ? LucideIcons.circleCheck : LucideIcons.circle,
                    size: 16,
                    color: r.hit ? AppColors.emerald700 : AppColors.slate300,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _words[r.key]!,
                      style: RfqText.meta.copyWith(color: r.hit ? AppColors.slate900 : AppColors.slate500),
                    ),
                  ),
                  if (r.hit && r.points > 0) Text('+${r.points}', style: RfqText.small),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---- Own requirement -----------------------------------------------------------------------------------------------

/// Their own company's requirement: the API refuses a bid on it, so the page says so rather than offering a form.
class OwnRequirementNotice extends StatelessWidget {
  const OwnRequirementNotice({super.key, required this.onOpenOwner});

  final VoidCallback onOpenOwner;

  @override
  Widget build(BuildContext context) {
    return RfqNotice(
      icon: LucideIcons.building2,
      title: 'This is your company\'s own requirement',
      body: 'A company cannot bid on its own requirement. Open it as its owner to see the responses and decide.',
      action: 'Open as owner',
      onAction: onOpenOwner,
    );
  }
}
