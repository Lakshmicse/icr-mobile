import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../account/widgets/account_kit.dart';
import 'support_controller.dart' show refusalOf;
import 'support_models.dart';
import 'support_repository.dart';
import 'support_session.dart';
import 'support_widgets.dart';
import 'support_words.dart';

/// "Get help from ICR": the website's `RaiseTicketDialog` as a sheet. Resolves to the request logged (its id and
/// number), or null when closed unsent.
///
/// [category], [contextType], [contextId] and [contextLabel] name what the request is about when it is raised from a
/// record (a pairing, a purchase), so staff land on the right one; the person sees the label as "About …".
Future<SupportTicketRaised?> showRaiseTicketSheet(
  BuildContext context, {
  SupportRepository? repository,
  String? category,
  String? contextType,
  String? contextId,
  String? contextLabel,
  String? subject,
  FilePickFn? pickFiles,
}) {
  final repo = repository ?? supportRepositoryOf(context);
  return showEditSheet<SupportTicketRaised>(
    context,
    builder: (_) => RaiseTicketSheet(
      repository: repo,
      category: category,
      contextType: contextType,
      contextId: contextId,
      contextLabel: contextLabel,
      subject: subject,
      pickFiles: pickFiles,
    ),
  );
}

class RaiseTicketSheet extends StatefulWidget {
  const RaiseTicketSheet({
    super.key,
    required this.repository,
    this.category,
    this.contextType,
    this.contextId,
    this.contextLabel,
    this.subject,
    this.pickFiles,
  });

  final SupportRepository repository;
  final String? category;
  final String? contextType;
  final String? contextId;
  final String? contextLabel;
  final String? subject;
  final FilePickFn? pickFiles;

  @override
  State<RaiseTicketSheet> createState() => _RaiseTicketSheetState();
}

class _RaiseTicketSheetState extends State<RaiseTicketSheet> {
  late final TextEditingController _subject;
  final _body = TextEditingController();
  late String _category;
  List<SupportAttachmentDraft> _files = const [];
  List<SupportFaq> _faqs = const [];
  final Set<String> _helpful = {};
  final Set<String> _viewed = {};
  var _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subject = TextEditingController(text: widget.subject ?? '');
    _category = SupportWords.categories.any((c) => c.$1 == widget.category) ? widget.category! : 'OTHER';
    unawaited(_loadFaqs());
  }

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  /// Answers for whatever was picked: the last moment a ticket is still dearer than an article.
  Future<void> _loadFaqs() async {
    final category = _category;
    try {
      final rows = await widget.repository.faqs(category: category, limit: 3);
      if (mounted && category == _category) setState(() => _faqs = rows);
    } catch (_) {
      if (mounted && category == _category) setState(() => _faqs = const []);
    }
  }

  bool get _tooShort => _subject.text.trim().length < 5 || _body.text.trim().length < 10;

  bool get _dirty => _subject.text.trim().isNotEmpty || _body.text.trim().isNotEmpty || _files.isNotEmpty;

  Future<void> _pickCategory() async {
    final picked = await showAccountPicker<String>(
      context,
      title: SupportWords.whatIsThisAbout,
      items: [for (final c in SupportWords.categories) c.$1],
      labelOf: SupportWords.category,
      subtitleOf: SupportWords.categoryHint,
      selected: _category,
    );
    if (picked == null || picked == _category || !mounted) return;
    setState(() {
      _category = picked;
      _faqs = const [];
    });
    unawaited(_loadFaqs());
  }

  Future<void> _send() async {
    if (_tooShort || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final raised = await widget.repository.raise(
        RaiseDraft(
          subject: _subject.text,
          category: _category,
          body: _body.text,
          contextType: widget.contextType,
          contextId: widget.contextId,
          attachments: _files,
        ),
      );
      if (mounted) Navigator.of(context).pop(raised);
    } catch (e) {
      // What was typed stays; the sentence says why it was not logged.
      if (mounted) {
        setState(() {
          _sending = false;
          _error = refusalOf(e, SupportWords.couldNotLog);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return EditSheet(
      title: SupportWords.raiseTitle,
      saveLabel: SupportWords.sendRequest,
      saving: _sending,
      error: _error,
      dirty: _dirty,
      onSave: _tooShort ? null : _send,
      children: [
        if (widget.contextLabel != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              key: const Key('raise.context'),
              children: [
                Text(SupportWords.about, style: AccountText.meta),
                const SizedBox(width: 8),
                Flexible(child: AccountChip(label: widget.contextLabel!)),
              ],
            ),
          ),
        AccountSelectField(
          key: const Key('raise.category'),
          label: SupportWords.whatIsThisAbout,
          hint: SupportWords.whatIsThisAbout,
          value: SupportWords.category(_category),
          helper: SupportWords.categoryHint(_category),
          onTap: _sending ? null : _pickCategory,
        ),
        if (_faqs.isNotEmpty) ...[
          Container(
            key: const Key('raise.faqs'),
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(SupportWords.beforeYouWrite, style: AccountText.meta.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                for (final (i, f) in _faqs.indexed)
                  SupportFaqTile(
                    faq: f,
                    compact: true,
                    first: i == 0,
                    helpful: _helpful.contains(f.id),
                    onOpened: () {
                      if (_viewed.add(f.id)) unawaited(widget.repository.markFaqViewed(f.id));
                    },
                    onHelpful: () {
                      if (_helpful.add(f.id)) unawaited(widget.repository.markFaqHelpful(f.id));
                      setState(() {});
                    },
                  ),
              ],
            ),
          ),
        ],
        AccountField(
          label: SupportWords.subject,
          controller: _subject,
          fieldKey: const Key('raise.subject'),
          hint: SupportWords.subjectHint,
          maxLength: 160,
          enabled: !_sending,
          onChanged: (_) => setState(() {}),
        ),
        AccountField(
          label: SupportWords.whatHappened,
          controller: _body,
          fieldKey: const Key('raise.body'),
          hint: SupportWords.whatHappenedHint,
          maxLength: 8000,
          maxLines: 8,
          minLines: 5,
          enabled: !_sending,
          onChanged: (_) => setState(() {}),
        ),
        AttachmentTray(
          repository: widget.repository,
          files: _files,
          pickFiles: widget.pickFiles,
          enabled: !_sending,
          onChanged: (f) => setState(() => _files = f),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
