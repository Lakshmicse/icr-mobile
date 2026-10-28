import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../mentorship_my/widgets/forms.dart';
import '../mentorship_my/widgets/kit.dart';
import 'become_mentor_controller.dart';
import 'become_mentor_models.dart';
import 'become_mentor_rules.dart';
import 'become_mentor_widgets.dart';

typedef SaveProfile = Future<String?> Function(Map<String, dynamic> patch);

/// "How you mentor": plain paragraphs, stored as HTML. A draft saves with any length under the limit; the
/// 100 characters are needed to submit.
class BioForm extends StatefulWidget {
  const BioForm({super.key, required this.initialHtml, required this.onSave});

  final String? initialHtml;
  final SaveProfile onSave;

  @override
  State<BioForm> createState() => _BioFormState();
}

class _BioFormState extends State<BioForm> with SheetState<BioForm> {
  late final _text = TextEditingController(text: bioToText(widget.initialHtml));

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String get _html => bioToHtml(_text.text);

  @override
  Widget build(BuildContext context) {
    final chars = htmlToPlainText(_html).length;
    final under = mentorProfileProblems(MentorProfileFacts(bioHtml: _html));
    return frame(
      title: 'How you mentor',
      subtitle:
          'What you are good at, who you tend to help, and how you like to work. This is the first thing a mentee reads on your card.',
      submitLabel: 'Save',
      onSubmit: busy
          ? null
          : () => send(
              () => under.isEmpty ? null : under.first.message,
              () => widget.onSave({'bioHtml': _html.isEmpty ? null : _html}),
            ),
      children: [
        FieldBlock(
          label: 'How you mentor',
          help: chars < MentorLimits.bioMin
              ? '$chars of the ${MentorLimits.bioMin} characters needed to submit. Blank lines start a new paragraph.'
              : 'Blank lines start a new paragraph.',
          child: TextField(
            key: const ValueKey('bio-text'),
            controller: _text,
            minLines: 8,
            maxLines: 16,
            onChanged: (_) => setState(() {}),
            style: MentoringText.formInput,
            decoration: fieldDecoration('I help people who...'),
          ),
        ),
      ],
    );
  }
}

/// Areas of expertise (the domains the directory filters on) and the conversations a mentor is happy to have.
class ExpertiseForm extends StatefulWidget {
  const ExpertiseForm({super.key, required this.competencies, required this.topics, required this.onSave});

  final List<String> competencies;
  final List<String> topics;
  final SaveProfile onSave;

  @override
  State<ExpertiseForm> createState() => _ExpertiseFormState();
}

class _ExpertiseFormState extends State<ExpertiseForm> with SheetState<ExpertiseForm> {
  late List<String> _competencies = [...widget.competencies];
  late List<String> _topics = [...widget.topics];

  @override
  Widget build(BuildContext context) {
    final problems = mentorProfileProblems(MentorProfileFacts(competencies: _competencies, topics: _topics));
    String? of(MentorProfileField f) => problems.where((p) => p.field == f).firstOrNull?.message;
    return frame(
      title: 'Expertise',
      submitLabel: 'Save',
      onSubmit: busy
          ? null
          : () => send(
              () => problems.isEmpty ? null : problems.first.message,
              () => widget.onSave({'competencies': _competencies, 'topics': _topics}),
            ),
      children: [
        FieldBlock(
          label: 'Areas of expertise *',
          help: 'It is how mentees find you. Up to ${MentorLimits.competenciesMax}.',
          child: OptionPicker(
            options: competencyDomains,
            selected: _competencies,
            max: MentorLimits.competenciesMax,
            searchHint: 'Search areas',
            error: of(MentorProfileField.competencies),
            onChanged: (v) => setState(() => _competencies = v),
          ),
        ),
        FieldBlock(
          label: 'Happy to talk about',
          help: 'Concrete conversations, e.g. “Managing your first team”. Up to ${MentorLimits.topicsMax}.',
          child: TextChipEditor(
            fieldKey: const ValueKey('topic-text'),
            items: _topics,
            max: MentorLimits.topicsMax,
            hint: 'Type a topic',
            error: of(MentorProfileField.topics),
            onChanged: (v) => setState(() => _topics = v),
          ),
        ),
      ],
    );
  }
}

/// Who the mentor wants to hear from, and the roles they can help people reach.
class AudienceForm extends StatefulWidget {
  const AudienceForm({
    super.key,
    required this.audiences,
    required this.roles,
    required this.jobTitles,
    required this.onSave,
  });

  final List<String> audiences;
  final List<String> roles;

  /// ICR's list of job titles, offered as suggestions (any text is accepted).
  final List<String> jobTitles;
  final SaveProfile onSave;

  @override
  State<AudienceForm> createState() => _AudienceFormState();
}

class _AudienceFormState extends State<AudienceForm> with SheetState<AudienceForm> {
  late List<String> _audiences = [...widget.audiences];
  late List<String> _roles = [...widget.roles];

  @override
  Widget build(BuildContext context) {
    final problems = mentorProfileProblems(MentorProfileFacts(targetAudiences: _audiences, targetRoles: _roles));
    String? of(MentorProfileField f) => problems.where((p) => p.field == f).firstOrNull?.message;
    return frame(
      title: 'Who you mentor',
      submitLabel: 'Save',
      onSubmit: busy
          ? null
          : () => send(
              () => problems.isEmpty ? null : problems.first.message,
              () => widget.onSave({'targetAudiences': _audiences, 'targetRoles': _roles}),
            ),
      children: [
        FieldBlock(
          label: 'Who you want to mentor *',
          help: 'Pick everyone you are happy to hear from.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kept in the enum's order, so the card lists them the same way every time.
              for (final a in MentorAudience.values)
                CheckboxListTile(
                  key: ValueKey('audience-${a.api}'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _audiences.contains(a.api),
                  onChanged: (on) => setState(
                    () => _audiences = [
                      for (final x in MentorAudience.values)
                        if (x == a ? on == true : _audiences.contains(x.api)) x.api,
                    ],
                  ),
                  title: Text(a.label, style: MentoringText.bodyStrong),
                  subtitle: Text(a.note, style: MentoringText.meta),
                ),
              if (of(MentorProfileField.targetAudiences) != null)
                Text(of(MentorProfileField.targetAudiences)!, style: MentoringText.error),
            ],
          ),
        ),
        FieldBlock(
          label: 'Roles you can help people reach',
          help: 'Pick from the list or type your own. Up to ${MentorLimits.targetRolesMax}.',
          child: TextChipEditor(
            fieldKey: const ValueKey('role-text'),
            items: _roles,
            max: MentorLimits.targetRolesMax,
            suggestions: widget.jobTitles,
            hint: 'Pick or type a role',
            error: of(MentorProfileField.targetRoles),
            onChanged: (v) => setState(() => _roles = v),
          ),
        ),
      ],
    );
  }
}

/// How many mentees at once, how they will meet, how often, and a line on when the mentor is free.
class AvailabilityForm extends StatefulWidget {
  const AvailabilityForm({super.key, required this.profile, required this.onSave});

  final MyMentorProfile? profile;
  final SaveProfile onSave;

  @override
  State<AvailabilityForm> createState() => _AvailabilityFormState();
}

class _AvailabilityFormState extends State<AvailabilityForm> with SheetState<AvailabilityForm> {
  late double _capacity = (widget.profile?.capacity ?? MentorLimits.capacityDefault).toDouble().clamp(
    1,
    MentorLimits.capacityMax.toDouble(),
  );
  late final Set<String> _modes = {
    ...(widget.profile?.preferredModes ?? const ['VIDEO']),
  };
  late String? _cadence = widget.profile?.cadence;
  late final _note = TextEditingController(text: widget.profile?.availabilityNote ?? '');

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final problems = mentorProfileProblems(MentorProfileFacts(availabilityNote: _note.text));
    return frame(
      title: 'Availability',
      submitLabel: 'Save',
      onSubmit: busy
          ? null
          : () => send(
              () => problems.isEmpty ? null : problems.first.message,
              () => widget.onSave({
                'capacity': _capacity.round(),
                // Kept in the API's order, so the card lists them the same way every time.
                'preferredModes': [
                  for (final m in mentorModes.keys)
                    if (_modes.contains(m)) m,
                ],
                // Sent as null when emptied, so clearing a field clears it.
                'cadence': _cadence,
                'availabilityNote': _note.text.trim().isEmpty ? null : _note.text.trim(),
              }),
            ),
      children: [
        FieldBlock(
          label: 'Mentees at a time: ${_capacity.round()}',
          help: 'You stop appearing as available once you are full.',
          child: Slider(
            key: const ValueKey('capacity-slider'),
            value: _capacity,
            min: 1,
            max: MentorLimits.capacityMax.toDouble(),
            divisions: MentorLimits.capacityMax - 1,
            label: '${_capacity.round()}',
            onChanged: (v) => setState(() => _capacity = v),
          ),
        ),
        FieldBlock(
          label: "How you'll meet",
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final MapEntry(key: key, value: label) in mentorModes.entries)
                FilterChip(
                  key: ValueKey('mode-$key'),
                  label: Text(label),
                  selected: _modes.contains(key),
                  onSelected: (on) => setState(() => on ? _modes.add(key) : _modes.remove(key)),
                ),
            ],
          ),
        ),
        FieldBlock(
          label: 'Preferred cadence',
          help: 'Leave it empty for no preference.',
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final MapEntry(key: key, value: label) in mentorCadences.entries)
                ChoiceChip(
                  key: ValueKey('cadence-$key'),
                  label: Text(label),
                  selected: _cadence == key,
                  onSelected: (on) => setState(() => _cadence = on ? key : null),
                ),
            ],
          ),
        ),
        FieldBlock(
          label: "When you're free",
          help: '${_note.text.length} / ${MentorLimits.availabilityNoteMax}',
          child: TextField(
            key: const ValueKey('availability-note'),
            controller: _note,
            minLines: 2,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            style: MentoringText.formInput,
            decoration: fieldDecoration('Weekday evenings after 7pm IST'),
          ),
        ),
      ],
    );
  }
}

/// The weekly hours a mentee can book from (`PUT /mentorship/mentors/me/availability`, replace-all):
/// per weekday, any number of windows, in the profile's timezone.
class WeeklyHoursForm extends StatefulWidget {
  const WeeklyHoursForm({super.key, required this.blocks, required this.timezone, required this.onSave});

  final List<AvailabilityBlock> blocks;
  final String timezone;
  final Future<String?> Function(List<AvailabilityBlock> blocks) onSave;

  @override
  State<WeeklyHoursForm> createState() => _WeeklyHoursFormState();
}

class _Window {
  _Window(this.weekday, this.start, this.end);

  final int weekday;
  int start;
  int end;
}

const _weekdayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

/// "6:00 PM" for 1080 minutes after midnight; 1440 reads "12:00 AM".
String minutesOfDay(int m) {
  final h24 = (m ~/ 60) % 24;
  final h = h24 % 12 == 0 ? 12 : h24 % 12;
  return '$h:${(m % 60).toString().padLeft(2, '0')} ${h24 < 12 ? 'AM' : 'PM'}';
}

class _WeeklyHoursFormState extends State<WeeklyHoursForm> with SheetState<WeeklyHoursForm> {
  // Monday first, as the week reads in India; the API's weekday 0 is Sunday.
  static const _order = [1, 2, 3, 4, 5, 6, 0];
  static const _step = 30;
  late final List<_Window> _windows = [for (final b in widget.blocks) _Window(b.weekday, b.startMin, b.endMin)];

  /// What is wrong with the windows, as the API words it, or null.
  String? _check() {
    if (_windows.length > MentorLimits.availabilityBlocksMax) {
      return 'That is ${_windows.length} windows. Keep it to ${MentorLimits.availabilityBlocksMax}.';
    }
    for (final w in _windows) {
      if (w.end <= w.start) return 'Each window must end after it starts.';
    }
    for (final day in _order) {
      final list = _windows.where((w) => w.weekday == day).toList()..sort((a, b) => a.start.compareTo(b.start));
      for (var i = 1; i < list.length; i++) {
        if (list[i].start < list[i - 1].end) return 'Windows on the same day must not overlap.';
      }
    }
    return null;
  }

  void _add(int day) {
    final last = _windows.where((w) => w.weekday == day).fold<int?>(null, (m, w) => m == null || w.end > m ? w.end : m);
    final start = last == null ? 18 * 60 : (last + 60).clamp(0, 22 * 60);
    setState(() => _windows.add(_Window(day, start, (start + 90).clamp(_step, 1440))));
  }

  @override
  Widget build(BuildContext context) {
    final slots = [for (var m = 0; m < 1440; m += _step) m];
    return frame(
      title: 'Weekly hours',
      subtitle: 'When mentees can book you, in ${widget.timezone.replaceAll('_', ' ')}. Saving replaces your hours.',
      submitLabel: 'Save hours',
      onSubmit: busy
          ? null
          : () => send(
              _check,
              () => widget.onSave([
                for (final w in _windows) AvailabilityBlock(weekday: w.weekday, startMin: w.start, endMin: w.end),
              ]),
            ),
      children: [
        for (final day in _order) ...[
          Row(
            children: [
              Expanded(child: Text(_weekdayNames[day], style: MentoringText.bodyStrong)),
              InkWell(
                key: ValueKey('add-window-$day'),
                onTap: () => _add(day),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text('Add window', style: MentoringText.buttonQuiet),
                ),
              ),
            ],
          ),
          if (_windows.every((w) => w.weekday != day))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('Not available', style: MentoringText.meta),
            ),
          for (final (i, w) in _windows.indexed)
            if (w.weekday == day)
              Padding(
                key: ValueKey('window-$i'),
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey('start-$i'),
                        initialValue: w.start,
                        isDense: true,
                        decoration: fieldDecoration(''),
                        items: [
                          for (final m in slots)
                            DropdownMenuItem(
                              value: m,
                              child: Text(minutesOfDay(m), style: MentoringText.body),
                            ),
                        ],
                        onChanged: (v) => setState(() => w.start = v ?? w.start),
                      ),
                    ),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('to')),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey('end-$i'),
                        initialValue: w.end,
                        isDense: true,
                        decoration: fieldDecoration(''),
                        items: [
                          for (final m in [...slots.skip(1), 1440])
                            DropdownMenuItem(
                              value: m,
                              child: Text(minutesOfDay(m), style: MentoringText.body),
                            ),
                        ],
                        onChanged: (v) => setState(() => w.end = v ?? w.end),
                      ),
                    ),
                    IconButton(
                      key: ValueKey('remove-window-$i'),
                      tooltip: 'Remove this window',
                      icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.outline),
                      onPressed: () => setState(() => _windows.removeAt(i)),
                    ),
                  ],
                ),
              ),
        ],
        Text('${_windows.length} of ${MentorLimits.availabilityBlocksMax} windows', style: MentoringText.meta),
      ],
    );
  }
}

/// The credentials on the mentor card: picked from what the member has recorded, never typed. A code the member
/// no longer holds stays visible so it can be removed, and cannot be chosen again.
class CertificationsForm extends StatefulWidget {
  const CertificationsForm({super.key, required this.codes, required this.held, required this.onSave, this.onManage});

  final List<String> codes;
  final List<HeldCredential> held;
  final SaveProfile onSave;

  /// Opens the profile's credentials page (a website handoff).
  final VoidCallback? onManage;

  /// The most the card shows.
  static const max = 12;

  @override
  State<CertificationsForm> createState() => _CertificationsFormState();
}

class _CertificationsFormState extends State<CertificationsForm> with SheetState<CertificationsForm> {
  late List<String> _codes = [...widget.codes];

  List<String> get _stale {
    final held = {for (final h in widget.held) h.code};
    return [
      for (final c in _codes)
        if (!held.contains(c.toUpperCase())) c,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final stale = _stale;
    final staleMessage = stale.isEmpty
        ? null
        : stale.length == 1
        ? '${stale.first} is no longer on your profile — remove it to save.'
        : '${stale.join(', ')} are no longer on your profile — remove them to save.';
    return frame(
      title: 'Certifications on your card',
      submitLabel: 'Save',
      onSubmit: busy ? null : () => send(() => staleMessage, () => widget.onSave({'certifications': _codes})),
      children: [
        FieldBlock(
          label: 'Certifications you hold',
          help: widget.held.isEmpty && stale.isEmpty
              ? 'Record a certification under your credentials and you can show it here.'
              : _codes.length >= CertificationsForm.max
              ? '${CertificationsForm.max} of ${CertificationsForm.max} — the most your mentor card shows.'
              : 'Only credentials you have recorded, by their short code.',
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final h in widget.held)
                FilterChip(
                  key: ValueKey('cert-${h.code}'),
                  label: Text(h.verified ? '${h.code} · verified' : h.code),
                  selected: _codes.any((c) => c.toUpperCase() == h.code),
                  onSelected: (on) => setState(() {
                    if (on) {
                      if (_codes.length < CertificationsForm.max) _codes = [..._codes, h.code];
                    } else {
                      _codes = [
                        for (final c in _codes)
                          if (c.toUpperCase() != h.code) c,
                      ];
                    }
                  }),
                ),
              for (final s in stale)
                InputChip(
                  key: ValueKey('stale-$s'),
                  label: Text(s),
                  onDeleted: () => setState(() => _codes = [..._codes]..remove(s)),
                  deleteButtonTooltipMessage: 'Remove $s',
                ),
            ],
          ),
        ),
        if (staleMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(staleMessage, style: MentoringText.error),
          ),
        if (widget.onManage != null)
          Align(
            alignment: Alignment.centerLeft,
            child: QuietButton(
              label: 'Manage my credentials',
              icon: LucideIcons.externalLink,
              onPressed: widget.onManage,
            ),
          ),
      ],
    );
  }
}

/// The code of conduct, read in full. "I agree" records the agreement, the same as ticking the box beside Submit.
class ConductSheet extends StatefulWidget {
  const ConductSheet({super.key, required this.conduct, required this.accepted, required this.onAgree});

  final CodeOfConduct conduct;
  final bool accepted;
  final Future<String?> Function() onAgree;

  @override
  State<ConductSheet> createState() => _ConductSheetState();
}

class _ConductSheetState extends State<ConductSheet> with SheetState<ConductSheet> {
  @override
  Widget build(BuildContext context) {
    final c = widget.conduct;
    return frame(
      title: 'Mentor code of conduct — version ${c.version}',
      subtitle:
          'You will be mentoring someone early in their career under ICR\'s name. These are the ${c.clauses.length} things we ask of every mentor.',
      submitLabel: widget.accepted ? 'Done' : 'I agree',
      onSubmit: busy
          ? null
          : widget.accepted
          ? () => Navigator.pop(context, false)
          : () => send(() => null, widget.onAgree),
      children: [
        for (final (i, clause) in c.clauses.indexed)
          Padding(
            key: ValueKey('clause-${clause.key}'),
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${i + 1}. ${clause.title}', style: MentoringText.bodyStrong),
                const SizedBox(height: 2),
                Text(clause.body, style: MentoringText.body),
              ],
            ),
          ),
        if (widget.accepted)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'You have agreed to this version.',
              style: MentoringText.bodyStrong.copyWith(color: MentoringColors.green),
            ),
          ),
      ],
    );
  }
}

/// "Where the pop-up for a checklist line is opened" lives in the screen; this names a line's button.
String fixLabel(FixTarget t) => switch (t) {
  FixTarget.photo => 'Add a photo',
  FixTarget.intro => 'Edit role and years',
  FixTarget.languages => 'Edit languages',
  FixTarget.experience => 'Add a role',
  FixTarget.bio => 'Edit how you mentor',
  FixTarget.expertise => 'Edit expertise',
  FixTarget.audience => 'Edit who you mentor',
  FixTarget.availability => 'Edit availability',
  FixTarget.certifications => 'Edit certifications',
  FixTarget.training => 'Open training',
  FixTarget.conduct => 'Read the code of conduct',
};
