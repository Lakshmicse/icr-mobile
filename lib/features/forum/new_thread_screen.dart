import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/util/links.dart';
import '../../core/widgets/detail_sheet.dart';
import '../feed/feed_models.dart';
import 'composer_controller.dart';
import 'forum_file_picker.dart';
import 'forum_models.dart';
import 'forum_repository.dart';
import 'forum_styles.dart';
import 'rich_text_controller.dart';
import 'widgets/forum_bits.dart';
import 'widgets/forum_sheets.dart';
import 'widgets/rich_editor.dart';

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

/// The composer, laid out as the website's "Create a post" form (`ThreadComposer`): the two kinds, Category and
/// Sub-category (optional), Title (or Poll question), a poll's options, Details in a rich-text editor (bold, italic,
/// heading, lists, link), Tags and a file. Validated as the API's DTO is, showing the API's own refusal, and keeping
/// what was typed when a send fails. One control posts it: the Post in the title bar (Save on an edit).
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
  late final RichTextController _body = RichTextController(doc: _c.doc, maxChars: ForumLimits.bodyMax);
  final _tag = TextEditingController();
  final _options = <TextEditingController>[];
  final _scroll = ScrollController();
  String? _tagNote;
  int _bodyRevision = 0;

  @override
  void initState() {
    super.initState();
    for (final o in _c.pollOptions) {
      _options.add(TextEditingController(text: o));
    }
    _body.addListener(_bodyChanged);
    _bodyRevision = _body.revision;
    _c.start().then((_) => _c.presetTopic(widget.topicSlug));
  }

  @override
  void dispose() {
    _body.removeListener(_bodyChanged);
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

  /// The details changed (a word, a mark): the rules read the new document. A selection moving is not a change.
  void _bodyChanged() {
    if (_body.revision == _bodyRevision) return;
    _bodyRevision = _body.revision;
    _c.setDoc(_body.doc);
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
    final picked = await showModalBottomSheet<_TopicPick>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      barrierColor: AppColors.sheetScrim,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      clipBehavior: Clip.antiAlias,
      builder: (_) => _TopicSheet(nodes: _c.taxonomy, selectedKey: _c.topicKey, title: 'Category', searchAll: true),
    );
    if (picked == null) return;
    // A hit found under a category fills both boxes, as on the website.
    _c.setTopic(picked.category);
    if (picked.sub != null) _c.setSubtopic(picked.sub);
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
          _TopicSheet(nodes: _c.subtopics, selectedKey: _c.subtopicKey, title: 'Sub-category (optional)', allowNone: true),
    );
    if (picked != null) _c.setSubtopic(picked.node);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final c = _c;
        // The words the website's form uses, by kind: a new poll, a question being edited, a discussion.
        final poll = c.isPoll;
        final question = c.kind == ThreadKind.question;
        final newPoll = !c.isEdit && poll;
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
                        if (!c.isEdit) ...[_Modes(controller: c), const SizedBox(height: 20)],
                        _TopicField(controller: c, onTopic: _chooseTopic, onSubtopic: _chooseSubtopic),
                        const SizedBox(height: 16),
                        _Field(
                          fieldKey: const ValueKey('composer-title'),
                          controller: _title,
                          label: newPoll ? 'Poll question' : (question ? 'Your question' : 'Title'),
                          hint: newPoll
                              ? 'e.g. Which CAFM platform does your team use today?'
                              : (question
                                    ? 'e.g. How are you benchmarking soft services rates across cities?'
                                    : 'e.g. What actually moved the needle on your energy numbers?'),
                          helper: newPoll
                              ? 'One clear question. Members pick one option.'
                              : 'Specific titles get answered. "Pricing question" does not.',
                          maxLength: ForumLimits.titleMax,
                          error: c.touched ? c.titleProblem : null,
                          onChanged: c.setTitle,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                        if (newPoll) ...[
                          const SizedBox(height: 16),
                          _PollEditor(controller: c, fields: _options, onChanged: () => setState(() {})),
                        ],
                        const SizedBox(height: 16),
                        Text(c.bodyOptional ? 'Details (optional)' : 'Details', style: composerLabelStyle),
                        const SizedBox(height: 8),
                        RichEditor(
                          controller: _body,
                          placeholder: newPoll
                              ? 'Add context for voters — why you are asking, and anything the options leave out.'
                              : 'Give enough context that someone can actually help — portfolio size, what you have tried, what constraints you are under.',
                          error: c.touched && c.bodyProblem != null,
                        ),
                        if (c.editLosesFormatting && !c.bodyUnchanged)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'This post has a quote or code from the website that this editor cannot show. Changing its words turns them into plain paragraphs.',
                              key: const ValueKey('composer-rich-note'),
                              style: ForumDesign.meta,
                            ),
                          ),
                        const SizedBox(height: 20),
                        const Divider(height: 1, thickness: 1, color: AppColors.outlineVariant),
                        const SizedBox(height: 20),
                        _Tags(controller: c, field: _tag, note: _tagNote, onAdd: _addTag),
                        const SizedBox(height: 16),
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

/// The heading over a group of controls that is not a field (Details, Options): the website's bold subtitle.
final composerLabelStyle = AppText.plexSans(14, FontWeight.w600, const Color(0xE6000000), lineHeight: 18);

/// An outlined field of the composer, as the website's (Material's) text field: the label sits in the box and
/// floats onto its border, the helper under it is grey, and a field that is missing something is drawn with a red
/// border, never a red line of words.
InputDecoration composerDecoration({
  required String label,
  String? helper,
  String? hint,
  bool error = false,
  bool enabled = true,
  Widget? suffix,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: color, width: width),
  );
  final idle = error ? AppColors.error : AppColors.composerBorder;
  final labelColor = enabled ? const Color(0x99000000) : const Color(0x61000000);
  return InputDecoration(
    labelText: label,
    labelStyle: composerFieldStyle.copyWith(color: labelColor),
    floatingLabelStyle: error ? composerFieldStyle.copyWith(color: AppColors.error) : null,
    hintText: hint,
    hintMaxLines: 1,
    hintStyle: composerFieldStyle.copyWith(color: AppColors.outline),
    helperText: helper,
    helperMaxLines: 3,
    helperStyle: AppText.plexSans(12, FontWeight.w400, const Color(0x99000000), lineHeight: 16),
    counterStyle: ForumDesign.count,
    enabled: enabled,
    suffixIcon: suffix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    border: border(idle),
    enabledBorder: border(idle, error ? 1.5 : 1),
    focusedBorder: border(error ? AppColors.error : AppColors.primary, 1.5),
    disabledBorder: border(AppColors.outlineVariant),
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

    // Side by side, as the composer first drew them.
    return Row(
      children: [
        tile(ComposerMode.discussion, LucideIcons.messagesSquare, 'Discussion', 'Ask or share'),
        const SizedBox(width: 10),
        tile(ComposerMode.poll, LucideIcons.chartBar, 'Poll', 'Let people vote'),
      ],
    );
  }
}

/// Category (required) and Sub-category (optional): both always on the form, as the website's. The sub-category
/// stays greyed until there is a category with sub-categories to pick from.
class _TopicField extends StatelessWidget {
  const _TopicField({required this.controller, required this.onTopic, required this.onSubtopic});

  final ComposerController controller;
  final VoidCallback onTopic;
  final VoidCallback onSubtopic;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    Widget picker(Key key, String label, String? value, VoidCallback onTap, {bool error = false, bool enabled = true}) {
      return InkWell(
        key: key,
        borderRadius: BorderRadius.circular(10),
        onTap: enabled ? onTap : null,
        child: InputDecorator(
          isEmpty: value == null,
          isFocused: false,
          decoration: composerDecoration(
            label: label,
            error: error,
            enabled: enabled,
            suffix: Icon(
              LucideIcons.chevronDown,
              size: 18,
              color: enabled ? AppColors.outline : AppColors.outlineVariant,
            ),
          ),
          child: Text(value ?? '', style: composerFieldStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
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
              "Couldn't load the categories: ${c.taxonomyError}",
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
    final problem = c.touched && c.topicProblem != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        picker(const ValueKey('composer-topic'), 'Category *', c.topicName, onTopic, error: problem),
        const SizedBox(height: 16),
        picker(
          const ValueKey('composer-subtopic'),
          'Sub-category (optional)',
          c.subtopicName,
          onSubtopic,
          enabled: c.subtopics.isNotEmpty,
        ),
      ],
    );
  }
}

/// A text field of the composer: floating label, the website's helper under it, a count only near the limit, and a
/// red border (no red words) while [error] is set.
class _Field extends StatelessWidget {
  const _Field({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.onChanged,
    this.hint,
    this.helper,
    this.maxLength,
    this.error,
    this.textCapitalization = TextCapitalization.none,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helper;
  final ValueChanged<String> onChanged;
  final int? maxLength;
  final String? error;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      onChanged: onChanged,
      maxLength: maxLength,
      // A count appears only near the limit (LinkedIn's does the same): 0/160 under an empty field is noise.
      buildCounter: (context, {required currentLength, required isFocused, required maxLength}) =>
          maxLength != null && currentLength >= maxLength * 0.8
          ? Text('$currentLength/$maxLength', style: ForumDesign.count)
          : null,
      textCapitalization: textCapitalization,
      // A title can run to 160 characters: it wraps on a phone rather than scrolling sideways.
      minLines: 1,
      maxLines: 3,
      textInputAction: TextInputAction.next,
      style: composerFieldStyle,
      decoration: composerDecoration(label: label, hint: hint, helper: helper, error: error != null),
    );
  }
}

/// The poll's options, drawn like the votes they become: a ring and the text in a bordered row, "Add option" under
/// them and the website's hint beside it.
class _PollEditor extends StatelessWidget {
  const _PollEditor({required this.controller, required this.fields, required this.onChanged});

  final ComposerController controller;
  final List<TextEditingController> fields;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('Options', style: composerLabelStyle),
            const Spacer(),
            Text(
              '${c.pollOptions.length} of ${ForumLimits.pollMax}',
              style: AppText.plexSans(12, FontWeight.w400, const Color(0x99000000), lineHeight: 16),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < c.pollOptions.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _OptionRow(
              index: i,
              field: fields[i],
              onChanged: (v) => c.setPollOption(i, v),
              onRemove: c.pollOptions.length > ForumLimits.pollMin
                  ? () {
                      c.removePollOption(i);
                      fields.removeAt(i).dispose();
                      onChanged();
                    }
                  : null,
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
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
                label: Text('Add option', style: composerLabelStyle.copyWith(color: AppColors.primary)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
              ),
            Expanded(
              child: Text(
                'Members pick one; results show once they have voted.',
                textAlign: TextAlign.right,
                style: AppText.plexSans(12, FontWeight.w400, const Color(0x99000000), lineHeight: 16),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OptionRow extends StatefulWidget {
  const _OptionRow({required this.index, required this.field, required this.onChanged, required this.onRemove});

  final int index;
  final TextEditingController field;
  final ValueChanged<String> onChanged;
  final VoidCallback? onRemove;

  @override
  State<_OptionRow> createState() => _OptionRowState();
}

class _OptionRowState extends State<_OptionRow> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_focus, widget.field]),
      builder: (context, _) {
        final left = ForumLimits.optionChars - widget.field.text.length;
        return Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.only(left: 14, right: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _focus.hasFocus ? AppColors.primary : AppColors.composerBorder,
              width: _focus.hasFocus ? 1.5 : 1,
            ),
          ),
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
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: ValueKey('poll-field:${widget.index}'),
                  controller: widget.field,
                  focusNode: _focus,
                  maxLength: ForumLimits.optionChars,
                  onChanged: widget.onChanged,
                  textCapitalization: TextCapitalization.sentences,
                  style: composerFieldStyle,
                  decoration: InputDecoration(
                    hintText: 'Option ${widget.index + 1}',
                    hintStyle: composerFieldStyle.copyWith(color: AppColors.outline),
                    counterText: '',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
              if (left < 20) Text('$left', style: ForumDesign.count),
              if (widget.onRemove != null)
                InkResponse(
                  key: ValueKey('poll-remove:${widget.index}'),
                  onTap: widget.onRemove,
                  radius: 18,
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(LucideIcons.x, size: 18, color: AppColors.outline),
                  ),
                )
              else
                const SizedBox(width: 10),
            ],
          ),
        );
      },
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
            padding: const EdgeInsets.only(bottom: 10),
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
            style: composerFieldStyle,
            decoration: composerDecoration(
              label: 'Tags',
              hint: 'Add up to ${ForumLimits.tags}',
              helper: 'Tags are how someone finds this in six months.',
              suffix: InkResponse(
                key: const ValueKey('tag-add'),
                onTap: onAdd,
                radius: 18,
                child: const Icon(LucideIcons.plus, size: 18, color: AppColors.primary),
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
                file == null ? 'Attach a file' : 'Replace attachment',
                style: ForumDesign.chip.copyWith(fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.composerBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(width: 12),
            if (c.uploading) ...[
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 8),
              Text('Uploading…', style: ForumDesign.meta),
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

/// What the Category sheet hands back: the category, and the sub-category when the search found one under it.
class _TopicPick {
  const _TopicPick(this.category, [this.sub]);

  final TaxonomyNode category;
  final TaxonomyNode? sub;
}

class _TopicSheet extends StatefulWidget {
  const _TopicSheet({
    required this.nodes,
    required this.selectedKey,
    required this.title,
    this.allowNone = false,
    this.searchAll = false,
  });

  final List<TaxonomyNode> nodes;
  final String? selectedKey;
  final String title;
  final bool allowNone;

  /// The Category box's rule on the website: an empty box lists the categories, typing matches anywhere in a node's
  /// path (category › sub-category), the deeper hits grouped under their category, and picking one fills both.
  final bool searchAll;

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

  void _pick(TaxonomyNode? node, {TaxonomyNode? under}) {
    // The category sheet returns a pick; a sub-category sheet returns a wrapper, so "none" can be told from a dismissal.
    if (widget.allowNone) {
      Navigator.pop(context, _SubChoice(node));
    } else if (under != null) {
      Navigator.pop(context, _TopicPick(under, node));
    } else {
      Navigator.pop(context, _TopicPick(node!));
    }
  }

  List<String> get _words => _query.text.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  /// Every word typed sits somewhere in the path (the website's `filterPaths`).
  bool _matches(List<String> words, List<String> path) {
    final haystack = path.join(' ').toLowerCase();
    return words.every(haystack.contains);
  }

  @override
  Widget build(BuildContext context) {
    final words = _words;
    final nodes = [
      for (final n in widget.nodes)
        if (_matches(words, [n.name])) n,
    ];
    // The deeper hits, each category's together under its name.
    final groups = <({TaxonomyNode top, List<TaxonomyNode> subs})>[
      if (widget.searchAll && words.isNotEmpty)
        for (final top in widget.nodes)
          if (top.children.any((s) => _matches(words, [top.name, s.name])))
            (top: top, subs: [for (final s in top.children) if (_matches(words, [top.name, s.name])) s]),
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
            if (widget.searchAll || widget.nodes.length > 8)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: TextField(
                  key: const ValueKey('topic-search'),
                  controller: _query,
                  onChanged: (_) => setState(() {}),
                  style: ForumDesign.field,
                  decoration: InputDecoration(
                    hintText: widget.searchAll ? 'Type a category or sub-category' : 'Search categories',
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
                  for (final g in groups) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
                      child: Text(
                        g.top.name,
                        key: ValueKey('topic-group:${g.top.key}'),
                        style: ForumDesign.sheetRow.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    for (final s in g.subs)
                      ListTile(
                        key: ValueKey('topic-hit:${g.top.key}:${s.key}'),
                        dense: true,
                        contentPadding: const EdgeInsets.only(left: 28, right: 16),
                        title: Text(s.name, style: ForumDesign.sheetRow),
                        onTap: () => _pick(s, under: g.top),
                      ),
                  ],
                  if (nodes.isEmpty && groups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        widget.searchAll ? 'No matching categories' : 'Nothing matches that.',
                        style: ForumDesign.sheetHint,
                      ),
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
