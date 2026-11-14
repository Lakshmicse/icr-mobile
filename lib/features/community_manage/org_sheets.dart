import 'package:flutter/material.dart';

import '../../core/api/api_error.dart';
import '../account/widgets/account_kit.dart';
import 'community_manage_kit.dart';
import 'community_manage_models.dart';
import 'community_manage_repository.dart';
import 'community_manage_rules.dart';

/// The two record forms of the console (the website's `OrgUnitDialogs.tsx`): create or edit a chapter, create or
/// edit a council. Each opens as a sheet over everything, holds the form to the API's own rules before it sends,
/// and shows the API's words when it still refuses.

/// Opens the chapter form; true when saved. [onSubmit] sends the draft and answers null, or the API's refusal.
Future<bool> showChapterSheet(
  BuildContext context, {
  required CommunityManageRepository repository,
  required Future<String?> Function(ChapterDraft draft) onSubmit,
  AdminChapter? chapter,
  ManagePickers pickers = const ManagePickers(),
  Duration searchDelay = const Duration(milliseconds: 350),
}) async =>
    await showEditSheet<bool>(
      context,
      builder: (_) => ChapterSheet(
        repository: repository,
        onSubmit: onSubmit,
        chapter: chapter,
        pickers: pickers,
        searchDelay: searchDelay,
      ),
    ) ??
    false;

/// The About's fields, one per section, each with the website's helper.
class _AboutFields extends StatelessWidget {
  const _AboutFields({
    required this.sections,
    required this.controllers,
    required this.hasExtra,
    required this.onChanged,
    this.error,
  });

  final List<AboutSection> sections;
  final Map<String, TextEditingController> controllers;
  final bool hasExtra;
  final VoidCallback onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FormHeading('About'),
        for (final s in sections)
          AccountField(
            fieldKey: Key('about.${s.key}'),
            label: s.heading,
            controller: controllers[s.key]!,
            maxLines: 6,
            minLines: s.list ? 3 : 2,
            helper: s.helper,
            onChanged: (_) => onChanged(),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(error!, style: AccountText.error),
          ),
        if (hasExtra)
          const ManageNote(
            'This About section also has text outside these fields (added earlier). It is kept as it is and still shows on '
            'the public page.',
          ),
      ],
    );
  }
}

/// Create or edit a chapter (the website's `ChapterDialog`): the name; whether it covers a country or a city, and
/// which (the city's state and country come with the pick); the founded year; the short description; the About as
/// one field per heading; the banner and the chapter's picture (the chapter page's own dialog on the website); the
/// gallery; the contact email; and whether it is listed publicly. The address is the API's to make, from the name.
class ChapterSheet extends StatefulWidget {
  const ChapterSheet({
    super.key,
    required this.repository,
    required this.onSubmit,
    this.chapter,
    this.pickers = const ManagePickers(),
    this.searchDelay = const Duration(milliseconds: 350),
  });

  final CommunityManageRepository repository;
  final Future<String?> Function(ChapterDraft draft) onSubmit;
  final AdminChapter? chapter;
  final ManagePickers pickers;
  final Duration searchDelay;

  @override
  State<ChapterSheet> createState() => _ChapterSheetState();
}

class _ChapterSheetState extends State<ChapterSheet> {
  late final ChapterDraft _d = widget.chapter == null ? ChapterDraft() : ChapterDraft.of(widget.chapter!);
  late final _name = TextEditingController(text: _d.name);
  late final _year = TextEditingController(text: _d.foundedYear);
  late final _description = TextEditingController(text: _d.description);
  late final _email = TextEditingController(text: _d.contactEmail);
  late final Map<String, TextEditingController> _about = {
    for (final s in chapterAboutSections) s.key: TextEditingController(text: _d.about[s.key] ?? ''),
  };
  Map<String, String> _problems = const {};
  bool _saving = false;
  bool _dirty = false;
  String? _error;
  String? _uploading;
  final Map<String, String> _uploadErrors = {};

  @override
  void dispose() {
    for (final c in [_name, _year, _description, _email, ..._about.values]) {
      c.dispose();
    }
    super.dispose();
  }

  void _touch([VoidCallback? change]) => setState(() {
    change?.call();
    _dirty = true;
  });

  void _read() {
    _d.name = _name.text;
    _d.foundedYear = _year.text;
    _d.description = _description.text;
    _d.contactEmail = _email.text;
    _d.about = {for (final e in _about.entries) e.key: e.value.text};
  }

  Future<void> _pickCity() async {
    final picked = await showCitySheet(context, repository: widget.repository, delay: widget.searchDelay);
    if (picked == null) return;
    final country = countryOfPlace(picked);
    _touch(() {
      _d.city = picked.city ?? picked.label;
      _d.region = picked.state ?? '';
      if (country.isNotEmpty) _d.country = country;
    });
  }

  Future<void> _pickCountry() async {
    final picked = await showCountrySheet(context, selected: _d.country);
    if (picked == null) return;
    _touch(() {
      _d.country = picked;
      _d.city = '';
      _d.region = '';
    });
  }

  /// Picks a picture, checks it as the website does, uploads it under [purpose] and hands back its path.
  Future<void> _upload(String field, String purpose, int maxBytes, void Function(String url) done) async {
    setState(() => _uploadErrors.remove(field));
    final file = await widget.pickers.pickImage(maxBytes: maxBytes);
    if (file == null || !mounted) return;
    final problem = pictureProblem(file, maxBytes: maxBytes);
    if (problem != null) {
      setState(() => _uploadErrors[field] = problem);
      return;
    }
    setState(() => _uploading = field);
    try {
      final url = await widget.repository.upload(file, purpose: purpose);
      if (mounted) _touch(() => done(url));
    } catch (e) {
      if (mounted) setState(() => _uploadErrors[field] = ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  Future<void> _save() async {
    _read();
    final problems = _d.problems();
    if (problems.isNotEmpty) {
      setState(() {
        _problems = problems;
        _error = problems.values.first;
      });
      return;
    }
    setState(() {
      _problems = const {};
      _saving = true;
      _error = null;
    });
    final refusal = await widget.onSubmit(_d);
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
    final editing = widget.chapter != null;
    final place = [_d.region, _d.country].where((v) => v.trim().isNotEmpty).join(' · ');
    return EditSheet(
      title: editing ? 'Edit Chapter' : 'Create Chapter',
      subtitle: editing ? widget.chapter!.name : null,
      saving: _saving,
      error: _error,
      dirty: _dirty,
      saveLabel: editing ? 'Save Changes' : 'Create Chapter',
      onSave: _saving || _uploading != null ? null : _save,
      children: [
        AccountField(
          fieldKey: const Key('chapter.name'),
          label: 'Name',
          required: true,
          controller: _name,
          maxLength: ManageLimits.name,
          textCapitalization: TextCapitalization.words,
          error: _problems['name'],
          onChanged: (_) => _touch(),
        ),
        ChoiceField(
          label: 'Chapter Type',
          options: const {
            ChapterScope.country: 'Country Chapter',
            ChapterScope.regional: 'Regional Chapter (City)',
          },
          value: _d.scope,
          onChanged: (scope) => _touch(() {
            _d.scope = scope;
            if (scope == ChapterScope.country) {
              _d.city = '';
              _d.region = '';
            }
          }),
        ),
        if (_d.countryWide)
          AccountSelectField(
            key: const Key('chapter.country'),
            label: 'Country',
            required: true,
            hint: 'Search a country',
            value: _d.country.isEmpty ? null : _d.country,
            helper: 'The chapter covers the whole country.',
            error: _problems['country'],
            onTap: _pickCountry,
          )
        else
          AccountSelectField(
            key: const Key('chapter.city'),
            label: 'City',
            required: true,
            hint: 'Search a city anywhere',
            value: _d.city.isEmpty ? null : [_d.city, if (place.isNotEmpty) place].join(' · '),
            helper: 'Select the city from the list. Its state and country are filled in.',
            error: _problems['city'],
            onTap: _pickCity,
          ),
        AccountField(
          fieldKey: const Key('chapter.foundedYear'),
          label: 'Founded Year',
          controller: _year,
          maxLength: 4,
          keyboardType: TextInputType.number,
          error: _problems['foundedYear'],
          onChanged: (_) => _touch(),
        ),
        AccountField(
          fieldKey: const Key('chapter.description'),
          label: 'Short Description',
          controller: _description,
          maxLines: 5,
          minLines: 2,
          maxLength: ManageLimits.description,
          counter: true,
          error: _problems['description'],
          onChanged: (_) => _touch(),
        ),
        _AboutFields(
          sections: chapterAboutSections,
          controllers: _about,
          hasExtra: _d.aboutExtra.isNotEmpty,
          error: _problems['about'],
          onChanged: _touch,
        ),
        PictureField(
          label: 'Banner',
          helper: 'PNG, JPG or WEBP, up to 5 MB. Shown across the top of the chapter page.',
          value: _d.coverUrl,
          uploading: _uploading == 'cover',
          error: _uploadErrors['cover'],
          onPick: () => _upload('cover', 'chapter-cover', ManageLimits.coverBytes, (url) => _d.coverUrl = url),
          onRemove: () => _touch(() => _d.coverUrl = ''),
        ),
        PictureField(
          label: 'Chapter Picture',
          helper: 'PNG, JPG or WEBP, up to 5 MB. Shown as a circle. The city’s initial is shown when there is none.',
          round: true,
          value: _d.logoUrl,
          uploading: _uploading == 'logo',
          error: _uploadErrors['logo'],
          onPick: () => _upload('logo', 'chapter-logo', ManageLimits.coverBytes, (url) => _d.logoUrl = url),
          onRemove: () => _touch(() => _d.logoUrl = ''),
        ),
        GalleryField(
          value: _d.galleryUrls,
          uploading: _uploading == 'gallery',
          error: _uploadErrors['gallery'],
          onAdd: () => _upload(
            'gallery',
            'chapter-gallery',
            ManageLimits.galleryBytes,
            (url) => _d.galleryUrls = [..._d.galleryUrls, url],
          ),
          onRemoveAt: (i) => _touch(() => _d.galleryUrls = [..._d.galleryUrls]..removeAt(i)),
        ),
        AccountField(
          fieldKey: const Key('chapter.contactEmail'),
          label: 'Contact Email',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textCapitalization: TextCapitalization.none,
          error: _problems['contactEmail'],
          onChanged: (_) => _touch(),
        ),
        SwitchField(
          switchKey: const Key('chapter.published'),
          label: _d.published ? 'Published (Listed Publicly)' : 'Unpublished (Hidden)',
          value: _d.published,
          onChanged: (v) => _touch(() => _d.published = v),
        ),
      ],
    );
  }
}

/// Opens the council form; true when saved.
Future<bool> showCouncilSheet(
  BuildContext context, {
  required CommunityManageRepository repository,
  required Future<String?> Function(CouncilDraft draft) onSubmit,
  AdminCouncil? council,
  ManagePickers pickers = const ManagePickers(),
}) async =>
    await showEditSheet<bool>(
      context,
      builder: (_) => CouncilSheet(repository: repository, onSubmit: onSubmit, council: council, pickers: pickers),
    ) ??
    false;

/// Create or edit a council (the website's `CouncilDialog`): the name and its slug (made from the name on a new
/// council until it is typed by hand), the member segments, the focus line (the segments when left empty), the
/// description, the About as one field per heading, a cover, the gallery, the contact email, and whether it is
/// listed publicly.
class CouncilSheet extends StatefulWidget {
  const CouncilSheet({
    super.key,
    required this.repository,
    required this.onSubmit,
    this.council,
    this.pickers = const ManagePickers(),
  });

  final CommunityManageRepository repository;
  final Future<String?> Function(CouncilDraft draft) onSubmit;
  final AdminCouncil? council;
  final ManagePickers pickers;

  @override
  State<CouncilSheet> createState() => _CouncilSheetState();
}

class _CouncilSheetState extends State<CouncilSheet> {
  late final CouncilDraft _d = widget.council == null ? CouncilDraft() : CouncilDraft.of(widget.council!);
  late final _name = TextEditingController(text: _d.name);
  late final _slug = TextEditingController(text: _d.slug);
  late final _focus = TextEditingController(text: _d.focus);
  late final _description = TextEditingController(text: _d.description);
  late final _email = TextEditingController(text: _d.contactEmail);
  final _segment = TextEditingController();
  late final Map<String, TextEditingController> _about = {
    for (final s in councilAboutSections) s.key: TextEditingController(text: _d.about[s.key] ?? ''),
  };

  /// A new council's slug follows its name until the slug is typed by hand.
  late bool _slugFollowsName = widget.council == null;
  Map<String, String> _problems = const {};
  bool _saving = false;
  bool _dirty = false;
  String? _error;
  String? _uploading;
  final Map<String, String> _uploadErrors = {};

  @override
  void dispose() {
    for (final c in [_name, _slug, _focus, _description, _email, _segment, ..._about.values]) {
      c.dispose();
    }
    super.dispose();
  }

  void _touch([VoidCallback? change]) => setState(() {
    change?.call();
    _dirty = true;
  });

  void _read() {
    _d.name = _name.text;
    _d.slug = slugify(_slug.text);
    _d.focus = _focus.text;
    _d.description = _description.text;
    _d.contactEmail = _email.text;
    _d.segments = SegmentsField.merge(_d.segments, _segment.text);
    _d.about = {for (final e in _about.entries) e.key: e.value.text};
  }

  Future<void> _upload(String field, String purpose, int maxBytes, void Function(String url) done) async {
    setState(() => _uploadErrors.remove(field));
    final file = await widget.pickers.pickImage(maxBytes: maxBytes);
    if (file == null || !mounted) return;
    final problem = pictureProblem(file, maxBytes: maxBytes);
    if (problem != null) {
      setState(() => _uploadErrors[field] = problem);
      return;
    }
    setState(() => _uploading = field);
    try {
      final url = await widget.repository.upload(file, purpose: purpose);
      if (mounted) _touch(() => done(url));
    } catch (e) {
      if (mounted) setState(() => _uploadErrors[field] = ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  Future<void> _save() async {
    _read();
    _segment.clear();
    _slug.text = _d.slug;
    final problems = _d.problems();
    if (problems.isNotEmpty) {
      setState(() {
        _problems = problems;
        _error = problems.values.first;
      });
      return;
    }
    setState(() {
      _problems = const {};
      _saving = true;
      _error = null;
    });
    final refusal = await widget.onSubmit(_d);
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
    final editing = widget.council != null;
    return EditSheet(
      title: editing ? 'Edit Council' : 'Create Council',
      subtitle: editing ? widget.council!.name : null,
      saving: _saving,
      error: _error,
      dirty: _dirty,
      saveLabel: editing ? 'Save Changes' : 'Create Council',
      onSave: _saving || _uploading != null ? null : _save,
      children: [
        AccountField(
          fieldKey: const Key('council.name'),
          label: 'Name',
          required: true,
          controller: _name,
          maxLength: ManageLimits.name,
          textCapitalization: TextCapitalization.words,
          error: _problems['name'],
          onChanged: (v) => _touch(() {
            if (_slugFollowsName) _slug.text = slugify(v);
          }),
        ),
        AccountField(
          fieldKey: const Key('council.slug'),
          label: 'Slug',
          required: true,
          controller: _slug,
          maxLength: ManageLimits.slug,
          textCapitalization: TextCapitalization.none,
          helper: 'Lower-case words joined by hyphens. This is the council’s address on ICR.',
          error: _problems['slug'],
          onChanged: (_) => _touch(() => _slugFollowsName = false),
        ),
        SegmentsField(
          value: _d.segments,
          input: _segment,
          onChanged: (v) => _touch(() => _d.segments = v),
        ),
        AccountField(
          fieldKey: const Key('council.focus'),
          label: 'Focus Line',
          controller: _focus,
          maxLength: ManageLimits.councilFocus,
          helper: 'Optional. Defaults to the segments.',
          error: _problems['focus'],
          onChanged: (_) => _touch(),
        ),
        AccountField(
          fieldKey: const Key('council.description'),
          label: 'Description',
          controller: _description,
          maxLines: 6,
          minLines: 3,
          maxLength: ManageLimits.description,
          counter: true,
          error: _problems['description'],
          onChanged: (_) => _touch(),
        ),
        _AboutFields(
          sections: councilAboutSections,
          controllers: _about,
          hasExtra: _d.aboutExtra.isNotEmpty,
          error: _problems['about'],
          onChanged: _touch,
        ),
        PictureField(
          label: 'Cover',
          helper: 'PNG, JPG or WEBP, up to 5 MB. Shown behind the council’s card and page heading.',
          value: _d.coverUrl,
          uploading: _uploading == 'cover',
          error: _uploadErrors['cover'],
          onPick: () => _upload('cover', 'council-cover', ManageLimits.coverBytes, (url) => _d.coverUrl = url),
          onRemove: () => _touch(() => _d.coverUrl = ''),
        ),
        GalleryField(
          value: _d.galleryUrls,
          uploading: _uploading == 'gallery',
          error: _uploadErrors['gallery'],
          onAdd: () => _upload(
            'gallery',
            'council-gallery',
            ManageLimits.galleryBytes,
            (url) => _d.galleryUrls = [..._d.galleryUrls, url],
          ),
          onRemoveAt: (i) => _touch(() => _d.galleryUrls = [..._d.galleryUrls]..removeAt(i)),
        ),
        AccountField(
          fieldKey: const Key('council.contactEmail'),
          label: 'Contact Email',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textCapitalization: TextCapitalization.none,
          error: _problems['contactEmail'],
          onChanged: (_) => _touch(),
        ),
        SwitchField(
          switchKey: const Key('council.published'),
          label: _d.published ? 'Published (Listed Publicly)' : 'Unpublished (Hidden)',
          value: _d.published,
          onChanged: (v) => _touch(() => _d.published = v),
        ),
      ],
    );
  }
}
