import 'package:flutter/material.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../account_labels.dart';
import '../../account_models.dart';
import '../../account_rules.dart';
import '../../widgets/account_kit.dart';
import '../../widgets/photo_picker.dart';
import '../profile_controller.dart';
import '../profile_fields.dart';

/// The sheets that edit the person themselves: the intro, the photo, the cover,
/// About, Skills and Languages. Each is opened the way the website opens a
/// `SectionDialog` (a title, the form, Cancel and Save, "Discard your changes?"
/// when leaving with edits) and keeps what was typed when the API refuses.

// --- intro ---------------------------------------------------------------------------------------------------

/// Name, headline, years in the profession and where they are. True when saved.
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
  List<String>? _titles;
  bool _saving = false;
  bool _tried = false;
  String? _error;

  String _snapshot() => [_first.text, _last.text, _headline.text, _years.text, _location].join('\u0001');

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
    if (_snapshot() == _initial) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final years = _years.text.trim();
      await widget.controller.saveIntro(
        firstName: _first.text,
        lastName: _last.text,
        headline: _headline.text,
        years: years.isEmpty ? null : int.parse(years),
        location: _location,
      );
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
    return EditSheet(
      title: 'Edit intro',
      saving: _saving,
      error: _error,
      dirty: _snapshot() != _initial,
      onSave: _save,
      children: [
        Text('* Required', style: AccountText.meta),
        const SizedBox(height: 10),
        AccountField(
          fieldKey: const Key('intro.firstName'),
          label: 'First name',
          controller: _first,
          required: true,
          maxLength: 100,
          error: _tried ? p.firstName : null,
          onChanged: (_) => setState(() {}),
        ),
        AccountField(
          fieldKey: const Key('intro.lastName'),
          label: 'Last name',
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
          helper: 'Your current role. It shows under your name.',
          onChanged: (_) => setState(() {}),
        ),
        AccountField(
          fieldKey: const Key('intro.years'),
          label: 'Years of experience',
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
      ],
    );
  }
}

// --- photo ---------------------------------------------------------------------------------------------------

/// The profile photo. It saves the moment it is uploaded; "Remove photo" takes it off.
Future<void> showPhotoSheet(BuildContext context, MyProfileController controller, {PhotoPicker pick = pickImageFromDevice}) =>
    showEditSheet<void>(context, builder: (_) => PhotoSheet(controller: controller, pick: pick));

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
      setState(() => _error = "Couldn't open your photos. Check that ICR may read them and try again.");
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
      title: 'Remove your profile photo?',
      message: 'Your initials will show instead.',
      confirm: 'Remove photo',
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
          title: 'Profile photo',
          saveLabel: 'Done',
          onSave: () => Navigator.of(context).pop(),
          error: _error,
          onDelete: url == null || _saving ? null : _remove,
          deleteLabel: 'Remove photo',
          children: [
            Center(child: AccountAvatar(url: url, initials: me?.initials ?? '?', size: 140)),
            const SizedBox(height: 16),
            AccountButton(
              key: const Key('photo.choose'),
              label: url == null ? 'Upload photo' : 'Change photo',
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
Future<void> showCoverSheet(BuildContext context, MyProfileController controller, {PhotoPicker pick = pickImageFromDevice}) =>
    showEditSheet<void>(context, builder: (_) => CoverSheet(controller: controller, pick: pick));

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
      setState(() => _error = "Couldn't open your photos. Check that ICR may read them and try again.");
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
          deleteLabel: 'Remove cover',
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
              label: own == null ? 'Upload your own' : 'Replace your picture',
              icon: Icons.photo_camera_outlined,
              outlined: true,
              busy: _busyOn == '@upload',
              onPressed: _upload,
            ),
            const SizedBox(height: 8),
            Text('A wide picture works best. PNG, JPG or WebP, up to 5 MB.', textAlign: TextAlign.center, style: AccountText.meta),
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
            border: Border.all(color: selected ? AppColors.primary : AppColors.slate200, width: selected ? 2 : 1),
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
                  const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                else if (selected)
                  const Positioned(top: 6, right: 6, child: Icon(Icons.check_circle_rounded, size: 20, color: Colors.white)),
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
      title: 'Edit about',
      saving: _saving,
      error: _error,
      dirty: _text.text != _initial,
      onSave: _save,
      children: [
        Text('Your experience, your strengths and what you are looking for. Recruiters read this first.', style: AccountText.meta),
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
        title: 'Edit skills',
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
        title: 'Edit languages',
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
