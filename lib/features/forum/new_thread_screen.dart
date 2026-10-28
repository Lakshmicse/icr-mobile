import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import '../../core/widgets/detail_sheet.dart';
import '../feed/feed_models.dart';
import 'composer_controller.dart';
import 'forum_file_picker.dart';
import 'forum_models.dart';
import 'forum_repository.dart';
import 'forum_styles.dart';
import 'widgets/forum_bits.dart';
import 'widgets/forum_sheets.dart';

/// Opens the composer over the screen that asked, for a new discussion or (with [editing]) to change one. Returns
/// what the forum stored, or null when the reader left without sending. [topicSlug] presets the topic of the page
/// the composer was opened from; [pickFile] stands in for the phone's file chooser.
Future<ForumThread?> openComposer(
  BuildContext context, {
  required ForumRepository repository,
  ForumThread? editing,
  ComposerMode mode = ComposerMode.discussion,
  String? topicSlug,
  String? initialTitle,
  String? initialBody,
  Future<ForumFile?> Function()? pickFile,
}) {
  return Navigator.of(context).push<ForumThread>(
    MaterialPageRoute<ForumThread>(
      fullscreenDialog: true,
      builder: (_) => NewThreadScreen(
        repository: repository,
        editing: editing,
        mode: mode,
        topicSlug: topicSlug,
        initialTitle: initialTitle,
        initialBody: initialBody,
        pickFile: pickFile,
      ),
    ),
  );
}

/// The composer: kind (a discussion or a poll), topic and sub-topic, title, a poll's options, details, tags and one
/// photo or PDF, validated as the API's DTO is, showing the API's own refusal, and keeping what was typed when a
/// send fails. The website's composer, on a phone.
class NewThreadScreen extends StatefulWidget {
  const NewThreadScreen({
    super.key,
    required this.repository,
    this.editing,
    this.mode = ComposerMode.discussion,
    this.topicSlug,
    this.initialTitle,
    this.initialBody,
    this.pickFile,
  });

  final ForumRepository repository;
  final ForumThread? editing;
  final ComposerMode mode;
  final String? topicSlug;

  /// A new post that starts from these words (a repost's quote).
  final String? initialTitle;
  final String? initialBody;

  /// Asks for a file to attach; the phone's chooser by default.
  final Future<ForumFile?> Function()? pickFile;

  @override
  State<NewThreadScreen> createState() => _NewThreadScreenState();
}

class _NewThreadScreenState extends State<NewThreadScreen> {
  late final ComposerController _c = ComposerController(
    repository: widget.repository,
    editing: widget.editing,
    mode: widget.mode,
    initialTitle: widget.initialTitle,
    initialBody: widget.initialBody,
  );
  late final TextEditingController _title = TextEditingController(text: _c.title);
  late final TextEditingController _body = TextEditingController(text: _c.body);
  final _tag = TextEditingController();
  final _options = <TextEditingController>[];
  final _scroll = ScrollController();
  String? _tagNote;

  @override
  void initState() {
    super.initState();
    for (final o in _c.pollOptions) {
      _options.add(TextEditingController(text: o));
    }
    _c.start().then((_) => _c.presetTopic(widget.topicSlug));
  }

  @override
  void dispose() {
    _c.dispose();
    _title.dispose();
    _body.dispose();
    _tag.dispose();
    _scroll.dispose();
    for (final o in _options) {
      o.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    // A tag typed and not yet added counts: the reader meant it.
    if (_tag.text.trim().isNotEmpty) _addTag();
    final saved = await _c.send();
    if (!mounted) return;
    if (saved != null) {
      Navigator.of(context).pop(saved);
    } else if (_c.error != null) {
      // The refusal sits at the top: bring it into view, the form stays as typed.
      _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _addTag() {
    final note = _c.addTags(_tag.text);
    _tag.clear();
    setState(() => _tagNote = note);
  }

  Future<void> _attach() async {
    final picker = widget.pickFile ?? pickForumFile;
    final file = await picker();
    if (file == null || !mounted) return;
    final message = await _c.attach(file);
    if (message != null && mounted) showMessage(context, message);
  }

  Future<bool> _confirmLeave() async {
    if (!_c.hasUnsentWork) return true;
    return confirm(
      context,
      title: _c.isEdit ? 'Discard your changes?' : 'Discard this draft?',
      body: _c.isEdit ? 'What you changed will not be saved.' : 'What you wrote will be lost.',
      action: 'Discard',
    );
  }

  Future<void> _chooseTopic() async {
    final picked = await showModalBottomSheet<TaxonomyNode>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      barrierColor: AppColors.sheetScrim,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      clipBehavior: Clip.antiAlias,
      builder: (_) => _TopicSheet(nodes: _c.taxonomy, selectedKey: _c.topicKey, title: 'Choose a topic'),
    );
    if (picked != null) _c.setTopic(picked);
  }

  Future<void> _chooseSubtopic() async {
    final picked = await showModalBottomSheet<_SubChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      barrierColor: AppColors.sheetScrim,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      clipBehavior: Clip.antiAlias,
      builder: (_) =>
          _TopicSheet(nodes: _c.subtopics, selectedKey: _c.subtopicKey, title: 'Choose a sub-topic', allowNone: true),
    );
    if (picked != null) _c.setSubtopic(picked.node);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final c = _c;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final leave = await _confirmLeave();
            if (leave && context.mounted) Navigator.of(context).pop();
          },
          child: Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _Bar(
                    title: c.isEdit ? 'Edit discussion' : (c.isPoll ? 'New poll' : 'New discussion'),
                    action: c.isEdit ? 'Save' : 'Post',
                    sending: c.sending,
                    onClose: () async {
                      final leave = await _confirmLeave();
                      if (leave && context.mounted) Navigator.of(context).pop();
                    },
                    onAction: _send,
                    enabled: !c.sending && !c.uploading,
                  ),
                  Expanded(
                    child: ListView(
                      controller: _scroll,
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(ForumDesign.gutter, 14, ForumDesign.gutter, 28),
                      children: [
                        if (c.error != null) ...[
                          ForumNotice(
                            key: const ValueKey('composer-error'),
                            warn: true,
                            icon: LucideIcons.circleAlert,
                            title: "It couldn't be saved",
                            text: c.error!,
                          ),
                          const SizedBox(height: 14),
                        ],
                        if (c.access.requiresApproval && !c.isEdit) ...[
                          const ForumNotice(
                            key: ValueKey('composer-approval'),
                            icon: LucideIcons.clock,
                            text:
                                'Your first few posts are read by a moderator before they go public. Once a couple are approved, everything you write publishes straight away.',
                          ),
                          const SizedBox(height: 14),
                        ],
                        if (!c.isEdit) ...[_Modes(controller: c), const SizedBox(height: 18)],
                        _Label('TOPIC'),
                        _TopicField(controller: c, onTopic: _chooseTopic, onSubtopic: _chooseSubtopic),
                        const SizedBox(height: 18),
                        _Label(c.isPoll ? 'YOUR POLL' : 'YOUR POST'),
                        _Field(
                          fieldKey: const ValueKey('composer-title'),
                          controller: _title,
                          hint: c.isPoll
                              ? 'Ask the question'
                              : (c.kind == ThreadKind.question ? 'What is your question?' : 'Give it a clear title'),
                          maxLength: ForumLimits.titleMax,
                          error: c.touched ? c.titleProblem : null,
                          helper: 'At least ${ForumLimits.titleMin} characters.',
                          onChanged: c.setTitle,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                        if (c.isPoll && !c.isEdit) ...[
                          const SizedBox(height: 16),
                          _PollEditor(controller: c, fields: _options, onChanged: () => setState(() {})),
                        ],
                        const SizedBox(height: 16),
                        _Field(
                          fieldKey: const ValueKey('composer-body'),
                          controller: _body,
                          hint: c.bodyOptional
                              ? 'Details (optional): say more about the poll'
                              : 'Give enough context that someone can answer',
                          minLines: 6,
                          maxLines: 14,
                          maxLength: ForumLimits.bodyMax,
                          error: c.touched ? c.bodyProblem : null,
                          label: c.bodyOptional ? 'Details (optional)' : 'Details',
                          onChanged: c.setBody,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                        if (c.isEdit && c.editing!.hasRichBody && !c.bodyUnchanged)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'This post has formatting from the website (bold, links, lists). Changing its words here replaces the formatting.',
                              key: const ValueKey('composer-rich-note'),
                              style: ForumDesign.meta,
                            ),
                          ),
                        const SizedBox(height: 18),
                        _Label('TAGS'),
                        _Tags(controller: c, field: _tag, note: _tagNote, onAdd: _addTag),
                        const SizedBox(height: 18),
                        _Label('FILE'),
                        _FileRow(controller: c, onAttach: _attach),
                        const SizedBox(height: 22),
                        if (c.attempted && c.problems.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              c.problems.first,
                              key: const ValueKey('composer-problem'),
                              style: ForumDesign.notice.copyWith(color: AppColors.error),
                            ),
                          ),
                        SizedBox(
                          height: 48,
                          child: FilledButton(
                            key: const ValueKey('composer-send'),
                            onPressed: c.sending || c.uploading ? null : _send,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: c.sending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    c.isEdit ? 'Save changes' : (c.isPoll ? 'Post poll' : 'Post to the community'),
                                    style: ForumDesign.button,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.title,
    required this.action,
    required this.sending,
    required this.onClose,
    required this.onAction,
    required this.enabled,
  });

  final String title;
  final String action;
  final bool sending;
  final VoidCallback onClose;
  final VoidCallback onAction;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Close',
            child: InkResponse(
              key: const ValueKey('composer-close'),
              onTap: onClose,
              radius: 24,
              child: const SizedBox(
                width: 56,
                height: 56,
                child: Icon(LucideIcons.x, size: 22, color: AppColors.onSurfaceVariant),
              ),
            ),
          ),
          Expanded(
            child: Text(title, style: ForumDesign.sheetTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          TextButton(
            key: const ValueKey('composer-bar-send'),
            onPressed: enabled ? onAction : null,
            child: Text(
              action,
              style: ForumDesign.chip.copyWith(
                color: enabled ? AppColors.primary : AppColors.outline,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: ForumDesign.fieldLabel),
  );
}

class _Modes extends StatelessWidget {
  const _Modes({required this.controller});

  final ComposerController controller;

  @override
  Widget build(BuildContext context) {
    Widget tile(ComposerMode mode, IconData icon, String label, String hint) {
      final on = controller.mode == mode;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          child: Material(
            color: on ? AppColors.chipEmphasis : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: on ? AppColors.primary : AppColors.outlineVariant, width: on ? 1.5 : 1),
            ),
            child: InkWell(
              key: ValueKey('mode:${mode.name}'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => controller.setMode(mode),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 20, color: on ? AppColors.primary : AppColors.icon),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: ForumDesign.author.copyWith(color: on ? AppColors.primary : AppColors.onSurface),
                    ),
                    Text(hint, style: ForumDesign.headline),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tile(ComposerMode.discussion, LucideIcons.messagesSquare, 'Discussion', 'Ask or share'),
        const SizedBox(width: 10),
        tile(ComposerMode.poll, LucideIcons.chartBar, 'Poll', 'Let people vote'),
      ],
    );
  }
}

class _TopicField extends StatelessWidget {
  const _TopicField({required this.controller, required this.onTopic, required this.onSubtopic});

  final ComposerController controller;
  final VoidCallback onTopic;
  final VoidCallback onSubtopic;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    Widget row(Key key, String? value, String placeholder, VoidCallback onTap, {String? error}) {
      return Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: error != null ? AppColors.error : AppColors.outlineVariant),
        ),
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value ?? placeholder,
                    style: value == null ? ForumDesign.fieldHint : ForumDesign.field,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.outline),
              ],
            ),
          ),
        ),
      );
    }

    if (c.taxonomyLoading && c.taxonomy.isEmpty && c.editing == null) {
      return const SizedBox(
        height: 46,
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    if (c.taxonomyError != null && c.taxonomy.isEmpty) {
      return Row(
        children: [
          Expanded(
            child: Text(
              "Couldn't load the topics: ${c.taxonomyError}",
              style: ForumDesign.notice.copyWith(color: AppColors.error),
            ),
          ),
          TextButton(
            key: const ValueKey('topics-retry'),
            onPressed: c.readTaxonomy,
            child: Text('Try again', style: ForumDesign.metaLink),
          ),
        ],
      );
    }
    final problem = c.touched ? c.topicProblem : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row(const ValueKey('composer-topic'), c.topicName, 'Choose a topic', onTopic, error: problem),
        if (problem != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(problem, style: ForumDesign.notice.copyWith(color: AppColors.error)),
          ),
        if (c.subtopics.isNotEmpty) ...[
          const SizedBox(height: 8),
          row(const ValueKey('composer-subtopic'), c.subtopicName, 'Sub-topic (optional)', onSubtopic),
        ],
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.fieldKey,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.maxLength,
    this.minLines = 1,
    this.maxLines = 3,
    this.error,
    this.helper,
    this.label,
    this.textCapitalization = TextCapitalization.none,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final int? maxLength;
  final int minLines;
  final int maxLines;
  final String? error;
  final String? helper;
  final String? label;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(label!, style: ForumDesign.author.copyWith(fontSize: 13)),
          ),
        TextField(
          key: fieldKey,
          controller: controller,
          onChanged: onChanged,
          minLines: minLines,
          maxLines: maxLines,
          maxLength: maxLength,
          textCapitalization: textCapitalization,
          style: ForumDesign.field,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: ForumDesign.fieldHint,
            counterStyle: ForumDesign.count,
            errorText: error,
            errorStyle: ForumDesign.notice.copyWith(color: AppColors.error),
            helperText: error == null ? helper : null,
            helperStyle: ForumDesign.meta,
            contentPadding: const EdgeInsets.all(12),
            border: border(AppColors.outlineVariant),
            enabledBorder: border(AppColors.outlineVariant),
            focusedBorder: border(AppColors.primary),
            errorBorder: border(AppColors.error),
            focusedErrorBorder: border(AppColors.error),
          ),
        ),
      ],
    );
  }
}

class _PollEditor extends StatelessWidget {
  const _PollEditor({required this.controller, required this.fields, required this.onChanged});

  final ComposerController controller;
  final List<TextEditingController> fields;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final problem = c.touched || c.filledOptions.isNotEmpty ? c.pollProblem : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Options', style: ForumDesign.author.copyWith(fontSize: 13)),
            const Spacer(),
            Text('${c.pollOptions.length} of ${ForumLimits.pollMax}', style: ForumDesign.meta),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < c.pollOptions.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.outline, width: 2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    key: ValueKey('poll-field:$i'),
                    controller: fields[i],
                    maxLength: ForumLimits.optionChars,
                    onChanged: (v) => c.setPollOption(i, v),
                    style: ForumDesign.field,
                    decoration: InputDecoration(
                      hintText: 'Option ${i + 1}',
                      hintStyle: ForumDesign.fieldHint,
                      counterText: '',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.outlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.outlineVariant),
                      ),
                    ),
                  ),
                ),
                if (c.pollOptions.length > ForumLimits.pollMin)
                  InkResponse(
                    key: ValueKey('poll-remove:$i'),
                    onTap: () {
                      c.removePollOption(i);
                      fields.removeAt(i).dispose();
                      onChanged();
                    },
                    radius: 18,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(LucideIcons.x, size: 18, color: AppColors.outline),
                    ),
                  ),
              ],
            ),
          ),
        Row(
          children: [
            if (c.pollOptions.length < ForumLimits.pollMax)
              TextButton.icon(
                key: const ValueKey('poll-add'),
                onPressed: () {
                  c.addPollOption();
                  fields.add(TextEditingController());
                  onChanged();
                },
                icon: const Icon(LucideIcons.plus, size: 16),
                label: Text('Add option', style: ForumDesign.chip.copyWith(color: AppColors.primary, fontSize: 13)),
              ),
            const Spacer(),
          ],
        ),
        if (problem != null)
          Text(
            problem,
            key: const ValueKey('poll-problem'),
            style: ForumDesign.notice.copyWith(color: ForumDesign.noticeWarnInk),
          ),
      ],
    );
  }
}

class _Tags extends StatelessWidget {
  const _Tags({required this.controller, required this.field, required this.note, required this.onAdd});

  final ComposerController controller;
  final TextEditingController field;
  final String? note;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (c.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in c.tags)
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 5, 4, 5),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('#$tag', style: ForumDesign.tag),
                        InkResponse(
                          key: ValueKey('tag-remove:$tag'),
                          onTap: () => c.removeTag(tag),
                          radius: 14,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(LucideIcons.x, size: 13, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        if (c.tags.length < ForumLimits.tags)
          TextField(
            key: const ValueKey('composer-tag'),
            controller: field,
            onSubmitted: (_) => onAdd(),
            onChanged: (v) {
              // A comma ends a tag, as it does on the website.
              if (v.contains(',')) onAdd();
            },
            textInputAction: TextInputAction.done,
            style: ForumDesign.field,
            decoration: InputDecoration(
              hintText: 'Add up to ${ForumLimits.tags} tags: hvac, retrofit',
              hintStyle: ForumDesign.fieldHint,
              helperText: 'Tags are how someone finds this.',
              helperStyle: ForumDesign.meta,
              prefixText: '#',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              suffixIcon: InkResponse(
                key: const ValueKey('tag-add'),
                onTap: onAdd,
                radius: 18,
                child: const Icon(LucideIcons.plus, size: 18, color: AppColors.primary),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.outlineVariant),
              ),
            ),
          )
        else
          Text('That is the most a discussion can carry (${ForumLimits.tags}).', style: ForumDesign.meta),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              note!,
              key: const ValueKey('tag-note'),
              style: ForumDesign.notice.copyWith(color: AppColors.error),
            ),
          ),
      ],
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.controller, required this.onAttach});

  final ComposerController controller;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final file = c.attachment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (file != null)
          AttachmentTile(
            key: const ValueKey('composer-file'),
            attachment: file,
            onRemove: c.canRemoveAttachment ? c.removeAttachment : null,
          ),
        if (file != null) const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              key: const ValueKey('composer-attach'),
              onPressed: c.uploading ? null : onAttach,
              icon: const Icon(LucideIcons.paperclip, size: 16),
              label: Text(
                file == null ? 'Attach a photo or PDF' : 'Replace the file',
                style: ForumDesign.chip.copyWith(fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.outlineVariant),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(width: 12),
            if (c.uploading) ...[
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 8),
              Text('Uploading...', style: ForumDesign.meta),
            ],
          ],
        ),
      ],
    );
  }
}

/// A topic (or sub-topic) chosen from a list that can be searched.
class _SubChoice {
  const _SubChoice(this.node);

  final TaxonomyNode? node;
}

class _TopicSheet extends StatefulWidget {
  const _TopicSheet({required this.nodes, required this.selectedKey, required this.title, this.allowNone = false});

  final List<TaxonomyNode> nodes;
  final String? selectedKey;
  final String title;
  final bool allowNone;

  @override
  State<_TopicSheet> createState() => _TopicSheetState();
}

class _TopicSheetState extends State<_TopicSheet> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _pick(TaxonomyNode? node) {
    // A topic sheet returns the node; a sub-topic sheet returns a wrapper, so "none" can be told from a dismissal.
    if (widget.allowNone) {
      Navigator.pop(context, _SubChoice(node));
    } else {
      Navigator.pop(context, node);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim().toLowerCase();
    final nodes = [
      for (final n in widget.nodes)
        if (q.isEmpty || n.name.toLowerCase().contains(q)) n,
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(top: 11, height: 28, rule: false),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(widget.title, style: ForumDesign.sheetTitle),
            ),
            if (widget.nodes.length > 8)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: TextField(
                  key: const ValueKey('topic-search'),
                  controller: _query,
                  onChanged: (_) => setState(() {}),
                  style: ForumDesign.field,
                  decoration: InputDecoration(
                    hintText: 'Search topics',
                    hintStyle: ForumDesign.fieldHint,
                    prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppColors.outline),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.outlineVariant),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: ListView(
                children: [
                  if (widget.allowNone)
                    ListTile(
                      key: const ValueKey('topic-none'),
                      dense: true,
                      title: Text('None', style: ForumDesign.sheetRow),
                      trailing: widget.selectedKey == null
                          ? const Icon(LucideIcons.check, size: 18, color: AppColors.primary)
                          : null,
                      onTap: () => _pick(null),
                    ),
                  for (final n in nodes)
                    ListTile(
                      key: ValueKey('topic-option:${n.key}'),
                      dense: true,
                      title: Text(n.name, style: ForumDesign.sheetRow),
                      trailing: n.key == widget.selectedKey
                          ? const Icon(LucideIcons.check, size: 18, color: AppColors.primary)
                          : null,
                      onTap: () => _pick(n),
                    ),
                  if (nodes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Nothing matches that.', style: ForumDesign.sheetHint),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
