import 'package:flutter/material.dart';

import '../../core/api/api_error.dart';
import '../account/widgets/account_kit.dart';
import '../site/site_kit.dart';
import 'partner_console_controllers.dart';
import 'partner_console_kit.dart';
import 'partner_console_models.dart';

/// Opens the course sheet (the website's `CourseDialog` for a partner's taught course); true when saved.
Future<bool> showCourseSheet(
  BuildContext context, {
  required CoursesController controller,
  ConsoleCourse? course,
  ConsolePickers pickers = const ConsolePickers(),
}) async =>
    await showEditSheet<bool>(
      context,
      builder: (_) => CourseSheet(controller: controller, course: course, pickers: pickers),
    ) ??
    false;

/// Create or edit a course: the name (its code and URL follow), the one-line summary, the category it is filed
/// under, a cover and a brochure, the overview, the key takeaways and who should attend, and Free or Paid. A
/// partner's course has no status field: Save keeps its state, and "Save and publish" appears once it has a batch
/// still going ahead (the API's own rule), unless ICR reviews this institute's courses.
class CourseSheet extends StatefulWidget {
  const CourseSheet({super.key, required this.controller, this.course, this.pickers = const ConsolePickers()});

  final CoursesController controller;
  final ConsoleCourse? course;
  final ConsolePickers pickers;

  @override
  State<CourseSheet> createState() => _CourseSheetState();
}

class _CourseSheetState extends State<CourseSheet> {
  late final CourseDraft _d = widget.course == null ? CourseDraft() : CourseDraft.fromCourse(widget.course!);
  late final _title = TextEditingController(text: _d.title);
  late final _summary = TextEditingController(text: _d.summary);
  late final _overview = TextEditingController(text: _d.description);
  List<CourseCategory> _categories = const [];
  bool _saving = false;
  bool _dirty = false;
  String? _error;
  bool _uploadingCover = false;
  bool _uploadingBrochure = false;
  String? _coverError;
  String? _brochureError;

  ConsoleCourse? get course => widget.course;
  bool get _live => course?.published ?? false;
  bool get _batchReady => course?.hasActiveBatch ?? false;
  bool get _underReview => widget.controller.underReview;
  bool get _canSaveAndPublish =>
      widget.controller.can('publish') && !_underReview && course != null && !_live && _batchReady;

  @override
  void initState() {
    super.initState();
    widget.controller.repository.categories().then((list) {
      if (mounted) setState(() => _categories = list);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _overview.dispose();
    super.dispose();
  }

  void _touch(VoidCallback change) => setState(() {
    change();
    _dirty = true;
  });

  CourseCategory? get _category => _categories.where((c) => c.key == _d.category).firstOrNull;
  CourseCategory? get _subcategory => _category?.children.where((c) => c.key == _d.subcategory).firstOrNull;

  Future<void> _pickCategory() async {
    final picked = await showAccountPicker<CourseCategory>(
      context,
      title: 'Category',
      items: _categories,
      labelOf: (c) => c.name,
      searchable: _categories.length > 8,
      selected: _category,
    );
    if (picked == null) return;
    _touch(() {
      if (picked.key != _d.category) _d.subcategory = null;
      _d.category = picked.key;
    });
  }

  Future<void> _pickSubcategory() async {
    final parent = _category;
    if (parent == null) return;
    final picked = await showAccountPicker<CourseCategory>(
      context,
      title: 'Sub-category',
      items: parent.children,
      labelOf: (c) => c.name,
      searchable: parent.children.length > 8,
      selected: _subcategory,
    );
    if (picked == null) return;
    _touch(() => _d.subcategory = picked.key);
  }

  Future<void> _pickAccess() async {
    final picked = await showAccountPicker<String>(
      context,
      title: 'Access',
      items: const ['FREE', 'PAID'],
      labelOf: (a) => a == 'PAID' ? 'Paid' : 'Free',
      selected: _d.access,
    );
    if (picked == null) return;
    _touch(() => _d.access = picked);
  }

  Future<void> _pickCover() async {
    setState(() => _coverError = null);
    final file = await widget.pickers.pickImage();
    if (file == null || !mounted) return;
    if (file.size > maxCoverBytes) {
      setState(() => _coverError = 'This file is over 2MB. Select a smaller image and try again.');
      return;
    }
    setState(() => _uploadingCover = true);
    try {
      final url = await widget.controller.repository.upload(file);
      _touch(() => _d.imageUrl = url);
    } catch (e) {
      setState(() => _coverError = ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _uploadingCover = false);
    }
  }

  Future<void> _pickBrochure() async {
    setState(() => _brochureError = null);
    final file = await widget.pickers.pickPdf();
    if (file == null || !mounted) return;
    if (file.mimeType != 'application/pdf') {
      setState(() => _brochureError = 'The brochure must be a PDF.');
      return;
    }
    if (file.size > maxBrochureBytes) {
      setState(() => _brochureError = 'This file is over 10MB. Compress the PDF and try again.');
      return;
    }
    setState(() => _uploadingBrochure = true);
    try {
      final url = await widget.controller.repository.upload(file);
      _touch(() => _d.brochureUrl = url);
    } catch (e) {
      setState(() => _brochureError = ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _uploadingBrochure = false);
    }
  }

  Future<void> _save({bool publish = false}) async {
    _d.title = _title.text;
    _d.summary = _summary.text;
    _d.description = _overview.text;
    setState(() {
      _saving = true;
      _error = null;
    });
    final refusal = await widget.controller.save(course, _d, publish: publish);
    if (!mounted) return;
    if (refusal == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _error = refusal;
    });
  }

  @override
  Widget build(BuildContext context) {
    final complete = _title.text.trim().isNotEmpty && (_d.category ?? '').isNotEmpty;
    final caption = course == null
        ? 'Saved as a draft. Add a batch from the list, then publish it.'
        : !_live && !_batchReady
        ? 'Add a batch to publish this course.'
        : null;
    return EditSheet(
      title: course == null ? 'New Course' : 'Edit Course',
      subtitle: 'Describe the course here. Its dates, duration and seats are set on each batch.',
      saving: _saving,
      error: _error,
      dirty: _dirty,
      onSave: complete && !_saving ? () => _save() : null,
      children: [
        if (_underReview && _live)
          const ConsoleNote(
            'ICR reviews this institute’s courses. Changing the title, summary, description, '
            'price, duration, outcomes or audience sends this course back for review. It leaves the '
            'catalogue until ICR approves it.',
          ),
        AccountField(
          key: const Key('course.title'),
          label: 'Course Name',
          required: true,
          controller: _title,
          hint: 'Facility Management Fundamentals',
          helper: 'Its code and URL are generated from this.',
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => _touch(() {}),
        ),
        AccountField(
          key: const Key('course.summary'),
          label: 'Summary',
          required: true,
          controller: _summary,
          maxLines: 2,
          helper: 'One line, shown on the card. Required before a course can be submitted for review.',
          onChanged: (_) => _touch(() {}),
        ),
        AccountSelectField(
          key: const Key('course.category'),
          label: 'Category',
          required: true,
          hint: 'Select a category',
          value: _category?.name ?? _d.category,
          onTap: _categories.isEmpty ? null : _pickCategory,
        ),
        AccountSelectField(
          key: const Key('course.subcategory'),
          label: 'Sub-category',
          hint: 'None',
          value: _subcategory?.name ?? _d.subcategory,
          helper: 'Candidates filter the course catalogue by it.',
          onTap: _category == null || _category!.children.isEmpty ? null : _pickSubcategory,
          onClear: _d.subcategory == null ? null : () => _touch(() => _d.subcategory = null),
        ),
        UploadField(
          label: 'Cover Image',
          helper: 'PNG, JPG or WEBP, up to 2MB. Shown on the course card and its page.',
          value: _d.imageUrl,
          uploading: _uploadingCover,
          error: _coverError,
          onPick: _pickCover,
          onRemove: () => _touch(() => _d.imageUrl = null),
        ),
        UploadField(
          label: 'Brochure',
          pdf: true,
          helper: 'PDF, up to 10MB. Offered on the course page to everyone, signed in or not.',
          value: _d.brochureUrl,
          uploading: _uploadingBrochure,
          error: _brochureError,
          onPick: _pickBrochure,
          onRemove: () => _touch(() => _d.brochureUrl = null),
        ),
        AccountField(
          key: const Key('course.overview'),
          label: 'Course Overview',
          controller: _overview,
          maxLines: 6,
          minLines: 3,
          helper: 'The opening section of the course page. What the programme is and why it is worth taking.',
          onChanged: (_) => _touch(() {}),
        ),
        const SectionLabel('Course Content'),
        ListEditor(
          label: 'Key Takeaways',
          value: _d.learningOutcomes,
          hint: 'Apply FM best practices across operations and maintenance',
          addLabel: 'Add Another Takeaway',
          helper: 'What a candidate can do once they finish. Shown as a numbered list.',
          onChanged: (v) => _touch(() => _d.learningOutcomes = v),
        ),
        ListEditor(
          label: 'Who Should Attend',
          value: _d.audience,
          numbered: false,
          hint: 'Facility managers moving into a strategic role',
          addLabel: 'Add Another Audience',
          helper: 'One line per audience. Order is not shown to candidates.',
          onChanged: (v) => _touch(() => _d.audience = v),
        ),
        const SectionLabel('Publication'),
        AccountSelectField(
          key: const Key('course.access'),
          label: 'Access',
          hint: 'Free',
          value: _d.access == 'PAID' ? 'Paid' : 'Free',
          onTap: _pickAccess,
        ),
        if (caption != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(caption, key: const Key('course.caption'), style: SiteText.meta),
          ),
        if (_canSaveAndPublish)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SiteButton(
              key: const Key('course.saveAndPublish'),
              label: 'Save and Publish',
              busy: _saving,
              onPressed: complete ? () => _save(publish: true) : null,
            ),
          ),
      ],
    );
  }
}
