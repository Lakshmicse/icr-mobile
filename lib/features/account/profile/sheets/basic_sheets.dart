import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../account_labels.dart';
import '../../account_models.dart';
import '../../account_rules.dart';
import '../../settings/contact_sheet.dart';
import '../../widgets/account_kit.dart';
import '../../widgets/photo_picker.dart';
import '../intro_line.dart';
import '../profile_controller.dart';
import '../profile_fields.dart';
import '../profile_kit.dart' show PillAction;
import 'career_sheets.dart';

/// The sheets that edit the person themselves: the intro, the photo, the cover,
/// About, Skills and Languages. Each is opened the way the website opens a
/// `SectionDialog` (a title, the form, Cancel and Save, "Discard your changes?"
/// when leaving with edits) and keeps what was typed when the API refuses.

// --- intro ---------------------------------------------------------------------------------------------------

/// Name, headline, years in the profession, where they are, and — as LinkedIn's
/// Edit intro has them — the Organisation and Education shown under the
/// headline, then a way into Contact Info. True when saved.
Future<bool> showIntroSheet(BuildContext context, MyProfileController controller) async =>
    await showEditSheet<bool>(context, builder: (_) => IntroSheet(controller: controller)) ?? false;

class IntroSheet extends StatefulWidget {
  const IntroSheet({super.key, required this.controller});

  final MyProfileController controller;

  @override
  State<IntroSheet> createState() => _IntroSheetState();
}

class _IntroSheetState extends State<IntroSheet> {
  late final MyProfile _me = widget.controller.profile.value!;
  late final _first = TextEditingController(text: _me.firstName);
  late final _last = TextEditingController(text: _me.lastName);
  late final _headline = TextEditingController(text: _me.headline ?? '');
  late final _years = TextEditingController(text: _me.yearsExperience?.toString() ?? '');
  late String _location = _me.location ?? '';
  late final String _initial = _snapshot();
  late final IntroChoice _saved = widget.controller.introChoice;

  /// What Organisation and Education showed when the sheet opened ('' for none).
  late final String _initialOrg;
  late final String _initialSchool;

  /// What was picked from the two lists; null while untouched, '' for "Please Select".
  String? _pickedOrg;
  String? _pickedSchool;
  List<String>? _titles;
  bool _saving = false;
  bool _tried = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialOrg = _org;
    _initialSchool = _school;
  }

  String _snapshot() => [_first.text, _last.text, _headline.text, _years.text, _location].join('\u0001');

  /// The organisation the field shows: the pick, else the saved choice, else LinkedIn's default.
  String get _org =>
      introRoleFor(widget.controller.introRoleOptions, _pickedOrg ?? _saved.organisation)?.organisation.trim() ?? '';

  String get _school =>
      introSchoolFor(widget.controller.introSchoolOptions, _pickedSchool ?? _saved.school)?.institution.trim() ?? '';

  bool get _orgChanged => _pickedOrg != null && _org != _initialOrg;
  bool get _schoolChanged => _pickedSchool != null && _school != _initialSchool;
  bool get _dirty => _snapshot() != _initial || _orgChanged || _schoolChanged;

  Future<void> _pickOrganisation() async {
    final options = widget.controller.introRoleOptions;
    final picked = await showAccountPicker<String>(
      context,
      title: 'Organisation',
      items: ['', for (final r in options) r.organisation.trim()],
      labelOf: (o) => o.isEmpty ? 'Please Select' : o,
      subtitleOf: (o) => o.isEmpty ? '' : options.firstWhere((r) => r.organisation.trim() == o).title,
      selected: _org,
    );
    if (picked != null && mounted) setState(() => _pickedOrg = picked);
  }

  Future<void> _pickSchool() async {
    final options = widget.controller.introSchoolOptions;
    final picked = await showAccountPicker<String>(
      context,
      title: 'Education',
      items: ['', for (final e in options) e.institution.trim()],
      labelOf: (s) => s.isEmpty ? 'Please Select' : s,
      subtitleOf: (s) {
        if (s.isEmpty) return '';
        final e = options.firstWhere((e) => e.institution.trim() == s);
        return [?e.degree, ?e.fieldOfStudy].join(', ');
      },
      selected: _school,
    );
    if (picked != null && mounted) setState(() => _pickedSchool = picked);
  }

  /// "Add New Position" / "Add New Education": the career sheet over this one;
  /// the new row is in the list when it closes.
  Future<void> _addRole() async {
    await showExperienceSheet(context, widget.controller);
    if (mounted) setState(() {});
  }

  Future<void> _addSchool() async {
    await showEducationSheet(context, widget.controller);
    if (mounted) setState(() {});
  }

  Future<void> _editContact() async {
    await showContactSheet(context, widget.controller);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [_first, _last, _headline, _years]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<List<String>> _suggest(String q) async {
    _titles ??= await widget.controller.repository.jobTitles();
    final lower = q.toLowerCase();
    return [
      for (final t in _titles!)
        if (t.toLowerCase().contains(lower) && t.toLowerCase() != lower) t,
    ];
  }

  ({String? firstName, String? headline, String? years}) get _problems =>
      introProblems(firstName: _first.text, headline: _headline.text, years: _years.text);

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _tried = true);
    final p = _problems;
    if (p.firstName != null || p.headline != null || p.years != null) return;
    if (!_dirty) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_snapshot() != _initial) {
        final years = _years.text.trim();
        await widget.controller.saveIntro(
          firstName: _first.text,
          lastName: _last.text,
          headline: _headline.text,
          years: years.isEmpty ? null : int.parse(years),
          location: _location,
        );
      }
      if (_orgChanged || _schoolChanged) {
        await widget.controller.saveIntroChoice(
          IntroChoice(
            organisation: _orgChanged ? _org : _saved.organisation,
            school: _schoolChanged ? _school : _saved.school,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _problems;
    final c = widget.controller;
    final roles = c.introRoleOptions;
    final schools = c.introSchoolOptions;
    return EditSheet(
      title: 'Edit Intro',
      saving: _saving,
      error: _error,
      dirty: _dirty,
      onSave: _save,
      children: [
        Text('* Required', style: AccountText.meta),
        const SizedBox(height: 10),
        AccountField(
          fieldKey: const Key('intro.firstName'),
          label: 'First Name',
          controller: _first,
          required: true,
          maxLength: 100,
          error: _tried ? p.firstName : null,
          onChanged: (_) => setState(() {}),
        ),
        AccountField(
          fieldKey: const Key('intro.lastName'),
          label: 'Last Name',
          controller: _last,
          maxLength: 100,
          onChanged: (_) => setState(() {}),
        ),
        SuggestField<String>(
          fieldKey: const Key('intro.headline'),
          label: 'Headline',
          controller: _headline,
          maxLength: 100,
          suggest: _suggest,
          labelOf: (t) => t,
          error: _tried || _headline.text.isNotEmpty ? p.headline : null,
          helper: 'Your current role. It appears under your name.',
          onChanged: (_) => setState(() {}),
        ),
        AccountField(
          fieldKey: const Key('intro.years'),
          label: 'Years of Experience',
          controller: _years,
          keyboardType: TextInputType.number,
          maxLength: 2,
          error: p.years,
          helper: p.years == null ? 'Whole years in the profession, 0–60.' : null,
          textCapitalization: TextCapitalization.none,
          onChanged: (_) => setState(() {}),
        ),
        if (_me.hasResume)
          CityPickerField(
            fieldKey: const Key('intro.location'),
            label: 'Location',
            value: _location,
            loadCities: widget.controller.repository.cities,
            labelOfCity: (c) => c.label,
            helper: 'The city you work from.',
            onChanged: (c) => setState(() => _location = c?.label ?? ''),
          ),
        AccountSelectField(
          key: const Key('intro.organisation'),
          label: 'Organisation',
          hint: 'Please Select',
          value: _org.isEmpty ? null : _org,
          onTap: roles.isEmpty ? null : _pickOrganisation,
          helper: roles.isEmpty
              ? 'Add your current role to show your company under your headline.'
              : 'Your current company. It appears under your headline.',
        ),
        if (c.experience.ready)
          _AddLink(linkKey: const Key('intro.addPosition'), label: 'Add New Position', onTap: _addRole),
        AccountSelectField(
          key: const Key('intro.education'),
          label: 'Education',
          hint: 'Please Select',
          value: _school.isEmpty ? null : _school,
          onTap: schools.isEmpty ? null : _pickSchool,
          helper: schools.isEmpty
              ? 'Add your education to show your school under your headline.'
              : 'Your school. It appears under your headline.',
        ),
        if (c.education.ready)
          _AddLink(linkKey: const Key('intro.addEducation'), label: 'Add New Education', onTap: _addSchool),
        const SizedBox(height: 6),
        Text('Contact Information', style: AccountText.itemTitle),
        const SizedBox(height: 2),
        Text('Add or edit your profile links, email and more.', style: AccountText.meta),
        const SizedBox(height: 10),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: PillAction(
            key: const Key('intro.contactInfo'),
            label: 'Edit Contact Information',
            icon: Symbols.edit,
            onPressed: _editContact,
          ),
        ),
      ],
    );
  }
}

/// "+ Add New Position" under its list, as LinkedIn's Edit intro has it.
class _AddLink extends StatelessWidget {
  const _AddLink({required this.linkKey, required this.label, required this.onTap});

  /// On the words themselves, which are all that can be tapped.
  final Key linkKey;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Semantics(
          button: true,
          child: InkWell(
            key: linkKey,
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(label, style: AccountText.link),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- photo ---------------------------------------------------------------------------------------------------

/// The profile photo. It saves the moment it is uploaded; "Remove photo" takes it off.
Future<void> showPhotoSheet(
  BuildContext context,
  MyProfileController controller, {
  PhotoPicker pick = pickImageFromDevice,
}) => showEditSheet<void>(
  context,
  builder: (_) => PhotoSheet(controller: controller, pick: pick),
);

class PhotoSheet extends StatefulWidget {
  const PhotoSheet({super.key, required this.controller, required this.pick});

  final MyProfileController controller;
  final PhotoPicker pick;

  @override
  State<PhotoSheet> createState() => _PhotoSheetState();
}

class _PhotoSheetState extends State<PhotoSheet> {
  bool _saving = false;
  String? _error;

  Future<void> _choose() async {
    if (_saving) return;
    final PickedPhoto? file;
    try {
      file = await widget.pick();
    } catch (_) {
      setState(() => _error = 'Unable to open your photos. Allow ICR to access them and try again.');
      return;
    }
    if (file == null || !mounted) return;
    final problem = photoProblem(file);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.uploadPhoto(file);
    } catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove() async {
    final ok = await confirmAction(
      context,
      title: 'Remove Your Profile Photo?',
      message: 'Your initials will appear instead.',
      confirm: 'Remove Photo',
    );
    if (!ok || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.removePhoto();
    } catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final me = widget.controller.profile.value;
        final url = me?.avatarUrl;
        return EditSheet(
          title: 'Profile Photo',
          saveLabel: 'Done',
          onSave: () => Navigator.of(context).pop(),
          error: _error,
          onDelete: url == null || _saving ? null : _remove,
          deleteLabel: 'Remove Photo',
          children: [
            Center(
              child: AccountAvatar(url: url, initials: me?.initials ?? '?', size: 140),
            ),
            const SizedBox(height: 16),
            AccountButton(
              key: const Key('photo.choose'),
              label: url == null ? 'Upload Photo' : 'Change Photo',
              icon: Icons.photo_camera_outlined,
              busy: _saving,
              outlined: true,
              onPressed: _choose,
            ),
            const SizedBox(height: 12),
            Text(
              'A clear photo of your face helps people recognise you. PNG, JPG or WebP, up to 5 MB.',
              textAlign: TextAlign.center,
              style: AccountText.meta,
            ),
          ],
        );
      },
    );
  }
}

// --- cover ---------------------------------------------------------------------------------------------------

/// The banner: a ready-made cover, or the person's own picture.
Future<void> showCoverSheet(
  BuildContext context,
  MyProfileController controller, {
  PhotoPicker pick = pickImageFromDevice,
}) => showEditSheet<void>(
  context,
  builder: (_) => CoverSheet(controller: controller, pick: pick),
);

class CoverSheet extends StatefulWidget {
  const CoverSheet({super.key, required this.controller, required this.pick});

  final MyProfileController controller;
  final PhotoPicker pick;

  @override
  State<CoverSheet> createState() => _CoverSheetState();
}

class _CoverSheetState extends State<CoverSheet> {
  String? _busyOn;
  String? _error;

  Future<void> _set(String? cover) async {
    if (_busyOn != null) return;
    setState(() {
      _busyOn = cover ?? '@none';
      _error = null;
    });
    try {
      await widget.controller.setCover(cover);
    } catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _busyOn = null);
    }
  }

  Future<void> _upload() async {
    if (_busyOn != null) return;
    final PickedPhoto? file;
    try {
      file = await widget.pick();
    } catch (_) {
      setState(() => _error = 'Unable to open your photos. Allow ICR to access them and try again.');
      return;
    }
    if (file == null || !mounted) return;
    final problem = photoProblem(file);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busyOn = '@upload';
      _error = null;
    });
    try {
      await widget.controller.uploadCover(file);
    } catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _busyOn = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final current = widget.controller.profile.value?.coverImage;
        final own = current != null && current.startsWith('/uploads/') ? current : null;
        return EditSheet(
          title: 'Cover',
          saveLabel: 'Done',
          onSave: () => Navigator.of(context).pop(),
          error: _error,
          onDelete: current == null || _busyOn != null ? null : () => _set(null),
          deleteLabel: 'Remove Cover',
          children: [
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.4,
              children: [
                if (own != null) _tile('Your picture', own, selected: true),
                for (final id in coverIds) _tile(profileCovers[id]!.$1, id, selected: current == id),
              ],
            ),
            const SizedBox(height: 12),
            AccountButton(
              key: const Key('cover.upload'),
              label: own == null ? 'Upload Your Own' : 'Replace Your Picture',
              icon: Icons.photo_camera_outlined,
              outlined: true,
              busy: _busyOn == '@upload',
              onPressed: _upload,
            ),
            const SizedBox(height: 8),
            Text(
              'A wide picture works best. PNG, JPG or WebP, up to 5 MB.',
              textAlign: TextAlign.center,
              style: AccountText.meta,
            ),
          ],
        );
      },
    );
  }

  Widget _tile(String name, String value, {required bool selected}) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Cover: $name',
      child: GestureDetector(
        key: Key('cover.$value'),
        onTap: selected ? null : () => _set(value),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            // The ring marks the chosen cover; the others carry no frame.
            border: selected ? Border.all(color: AppColors.primary, width: 2) : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CoverBand(cover: value),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    color: const Color(0x99000000),
                    child: Text(name, style: AccountText.chip.copyWith(color: Colors.white, fontSize: 13)),
                  ),
                ),
                if (_busyOn == value)
                  const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                  )
                else if (selected)
                  const Positioned(
                    top: 6,
                    right: 6,
                    child: Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- about ---------------------------------------------------------------------------------------------------

/// The professional summary recruiters read first.
Future<bool> showAboutSheet(BuildContext context, MyProfileController controller) async =>
    await showEditSheet<bool>(context, builder: (_) => AboutSheet(controller: controller)) ?? false;

class AboutSheet extends StatefulWidget {
  const AboutSheet({super.key, required this.controller});

  final MyProfileController controller;

  @override
  State<AboutSheet> createState() => _AboutSheetState();
}

class _AboutSheetState extends State<AboutSheet> {
  late final String _initial = widget.controller.profile.value?.summary ?? '';
  late final _text = TextEditingController(text: _initial);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_text.text == _initial) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.saveAbout(_text.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EditSheet(
      title: 'Edit About',
      saving: _saving,
      error: _error,
      dirty: _text.text != _initial,
      onSave: _save,
      children: [
        Text(
          'Your experience, your strengths and what you are looking for. Recruiters read this first.',
          style: AccountText.meta,
        ),
        const SizedBox(height: 12),
        AccountField(
          fieldKey: const Key('about.summary'),
          label: 'Summary',
          controller: _text,
          maxLength: maxAboutLength,
          minLines: 6,
          maxLines: 10,
          counter: true,
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }
}

// --- skills and languages ------------------------------------------------------------------------------------

/// The skills on the résumé: the ones the website's sign-up offers, or any typed.
Future<bool> showSkillsSheet(BuildContext context, MyProfileController controller) async =>
    await showEditSheet<bool>(
      context,
      builder: (_) => _ChipsSheet(
        key: const Key('skillsSheet'),
        title: 'Edit Skills',
        label: 'Skills',
        hint: 'e.g. HVAC, Vendor management',
        initial: controller.profile.value?.skills ?? const [],
        suggestions: skillSuggestions,
        max: maxSkills,
        maxLength: maxSkillLength,
        save: controller.saveSkills,
      ),
    ) ??
    false;

/// The languages they speak. If they mentor, mentees see these.
Future<bool> showLanguagesSheet(BuildContext context, MyProfileController controller) async =>
    await showEditSheet<bool>(
      context,
      builder: (_) => _ChipsSheet(
        key: const Key('languagesSheet'),
        title: 'Edit Languages',
        label: 'Languages',
        hint: 'e.g. English, Hindi',
        initial: controller.profile.value?.languages ?? const [],
        suggestions: languageSuggestions,
        max: maxLanguages,
        maxLength: maxLanguageLength,
        helperNote: 'Up to $maxLanguages. If you mentor, mentees see these.',
        save: controller.saveLanguages,
      ),
    ) ??
    false;

class _ChipsSheet extends StatefulWidget {
  const _ChipsSheet({
    super.key,
    required this.title,
    required this.label,
    required this.hint,
    required this.initial,
    required this.suggestions,
    required this.max,
    required this.maxLength,
    required this.save,
    this.helperNote,
  });

  final String title;
  final String label;
  final String hint;
  final List<String> initial;
  final List<String> suggestions;
  final int max;
  final int maxLength;
  final String? helperNote;
  final Future<void> Function(List<String>) save;

  @override
  State<_ChipsSheet> createState() => _ChipsSheetState();
}

class _ChipsSheetState extends State<_ChipsSheet> {
  late List<String> _items = [...widget.initial];
  bool _saving = false;
  String? _error;

  bool get _dirty => _items.join('\u0001') != widget.initial.join('\u0001');

  Future<void> _save() async {
    if (_saving) return;
    if (!_dirty) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.save(_items);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EditSheet(
      title: widget.title,
      saving: _saving,
      error: _error,
      dirty: _dirty,
      onSave: _save,
      children: [
        ChipEditor(
          label: widget.label,
          items: _items,
          suggestions: widget.suggestions,
          max: widget.max,
          maxLength: widget.maxLength,
          hint: widget.hint,
          helper: widget.helperNote,
          onChanged: (v) => setState(() => _items = v),
        ),
      ],
    );
  }
}
