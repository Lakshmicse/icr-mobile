import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import '../mentorship_my/mentoring_format.dart';
import '../mentorship_my/mentoring_links.dart';
import '../mentorship_my/widgets/forms.dart';
import '../mentorship_my/widgets/kit.dart';
import 'become_mentor_controller.dart';
import 'become_mentor_forms.dart';
import 'become_mentor_models.dart';
import 'become_mentor_person_forms.dart';
import 'become_mentor_repository.dart';
import 'become_mentor_rules.dart';
import 'become_mentor_widgets.dart';

/// Pushes [BecomeMentorScreen].
Future<void> openBecomeMentor(
  BuildContext context, {
  MentorshipLinks? links,
  VoidCallback? onBack,
  OpenConversation? onOpenConversation,
  void Function(BuildContext context, String mentorProfileId)? onOpenMentor,
  void Function(BuildContext context)? onBell,
  OpenSitePath? onOpenWebsite,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => BecomeMentorScreen(
      onBack: onBack,
      links: MentorshipLinks.resolve(
        context,
        links,
        onOpenConversation: onOpenConversation,
        onOpenMentor: onOpenMentor,
        onBell: onBell,
        onOpenWebsite: onOpenWebsite,
      ),
    ),
  ),
);

/// "Become a mentor" and, once there is a profile, "My mentor profile" (the website's `/mentorship/become-a-mentor`).
///
/// Two halves, as the website says out loud: the PERSON's (photo, current role, years, languages, career history),
/// shared with the member's own profile, and the MENTORING half (how you mentor, expertise, who you mentor,
/// availability). Each card is read-only and edited in a sheet from its button; each sheet saves on its own
/// (`PUT /mentorship/mentors/me` is a partial patch, and the first save creates the DRAFT). Above them sits the
/// application: where it stands, what is still needed (each line opens the sheet that fixes it), the code of conduct
/// and Submit.
///
/// Callbacks (all optional; every one has a working default): [onOpenMentor] shows the public profile of a listed
/// mentor, [onBell] the notifications, [onOpenWebsite] a page of the website (the learning centre for a training
/// module, the credentials page), [onOpenConversation] is carried for the messaging links of the family.
class BecomeMentorScreen extends StatefulWidget {
  const BecomeMentorScreen({
    super.key,
    this.onBack,
    this.links,
    this.repository,
    this.onOpenConversation,
    this.onOpenMentor,
    this.onBell,
    this.onOpenWebsite,
    this.pickPhoto = pickPhotoFromDevice,
    this.pickDocument = pickEvidenceFromDevice,
  });

  final VoidCallback? onBack;
  final MentorshipLinks? links;

  /// A seam for tests; the API by default.
  final BecomeMentorRepository? repository;
  final OpenConversation? onOpenConversation;
  final void Function(BuildContext context, String mentorProfileId)? onOpenMentor;
  final void Function(BuildContext context)? onBell;
  final OpenSitePath? onOpenWebsite;

  /// How a photo and a piece of evidence are chosen (the phone's pickers by default).
  final FilePick pickPhoto;
  final FilePick pickDocument;

  @override
  State<BecomeMentorScreen> createState() => _BecomeMentorScreenState();
}

class _BecomeMentorScreenState extends State<BecomeMentorScreen> {
  late final BecomeMentorController _c;
  late final MentorshipLinks _links;

  @override
  void initState() {
    super.initState();
    final repo = widget.repository ?? BecomeMentorRepository(api: context.read<ApiClient>());
    _links = MentorshipLinks.resolve(
      context,
      widget.links,
      onOpenConversation: widget.onOpenConversation,
      onOpenMentor: widget.onOpenMentor,
      onBell: widget.onBell,
      onOpenWebsite: widget.onOpenWebsite,
    );
    _c = BecomeMentorController(repo)..start();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        return MentoringPage(
          title: _c.hasProfile ? 'My mentor profile' : 'Become a mentor',
          onBack: widget.onBack,
          onBell: () => _links.notifications(context),
          body: LoadedList(
            loading: _c.loading,
            error: _c.error,
            errorTitle: "Couldn't load your mentor profile",
            onRefresh: _c.refresh,
            children: _c.loading || _c.error != null ? const [] : _content(context),
          ),
        );
      },
    );
  }

  // --- the page ---------------------------------------------------------------------

  List<Widget> _content(BuildContext context) {
    final c = _c;
    final m = c.mentor;
    final ready = c.readiness.data;
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text('An hour a month, and someone gets to skip a mistake you already made.', style: MentoringText.body),
      ),
      _StatusBanner(status: c.status, hasProfile: c.hasProfile, reviewNote: m?.reviewNote),
      if (ready?.renewalDue ?? false)
        Callout(
          key: const ValueKey('renewal'),
          tone: PillTone.amber,
          text:
              'Your listing is due for renewal. Mentor approval runs for two years. Tick the code of conduct agreement in '
              'Your application to stay listed in the directory.'
              '${ready?.approvalExpiresAt == null ? '' : ' It expires on ${dayLabel(ready!.approvalExpiresAt!)}.'}',
        ),
      const SizedBox(height: 10),
      _ApplicationCard(
        controller: c,
        onFix: (n) => _fix(context, n.target),
        onReadConduct: () => _conduct(context),
        onAgree: () async {
          final refusal = await c.agreeToConduct();
          if (context.mounted) showMessage(context, refusal ?? 'Agreed. Thank you.');
        },
        onSubmit: () async {
          final refusal = await c.submit();
          if (context.mounted) {
            showMessage(
              context,
              refusal ?? 'Sent to the ICR review team — we will let you know when your profile is live.',
            );
          }
        },
      ),
      const _GroupHeading('Your ICR profile', 'Shared with your profile. A change here is reflected there too.'),
      _photoCard(context),
      _introCard(context),
      _languagesCard(context),
      _experienceCard(context),
      const _GroupHeading('Mentoring', 'Only on your mentor card: how you mentor, who you help and when you are free.'),
      _bioCard(context),
      _expertiseCard(context),
      _certificationsCard(context),
      _audienceCard(context),
      _availabilityCard(context),
      _hoursCard(context),
      if (c.trainingRequired) _trainingCard(context),
      if (c.hasProfile) _documentsCard(context),
      if (c.hasProfile) _listingCard(context),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
        child: Text(
          'Worried about something in a mentoring relationship? You can raise it with ICR from any pairing — '
          'the other person is never told.',
          style: MentoringText.meta,
        ),
      ),
    ];
  }

  /// Opens a sheet; says so when it saved.
  Future<void> _sheet(BuildContext context, WidgetBuilder builder, {String done = 'Saved.'}) async {
    final saved = await showFormSheet(context, builder);
    if (saved && context.mounted) showMessage(context, done);
  }

  void _fix(BuildContext context, FixTarget t) {
    switch (t) {
      case FixTarget.photo:
        _photo(context);
      case FixTarget.intro:
        _intro(context);
      case FixTarget.languages:
        _languages(context);
      case FixTarget.experience:
        _addRole(context);
      case FixTarget.bio:
        _bio(context);
      case FixTarget.expertise:
        _expertise(context);
      case FixTarget.audience:
        _audience(context);
      case FixTarget.availability:
        _availability(context);
      case FixTarget.certifications:
        _certifications(context);
      case FixTarget.training:
        _training(context);
      case FixTarget.conduct:
        _conduct(context);
    }
  }

  // --- the person -------------------------------------------------------------------

  Widget _photoCard(BuildContext context) {
    final p = _c.person.data;
    final url = AppConfig.absoluteUrl(p?.avatarUrl, apiBase: _c.repository.api.dio.options.baseUrl);
    return SectionCard(
      cardKey: const ValueKey('card-photo'),
      title: 'Profile photo',
      editLabel: url == null ? 'Add' : 'Change',
      onEdit: () => _photo(context),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 56,
              height: 56,
              child: url == null
                  ? InitialsTile(name: p?.name ?? '')
                  : Image.network(
                      url,
                      key: const ValueKey('avatar'),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => InitialsTile(name: p?.name ?? ''),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              url == null
                  ? 'No photo yet. It is the first thing a mentee sees, and it is needed to submit.'
                  : 'Mentees see this first.',
              key: const ValueKey('photo-line'),
              style: MentoringText.body,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _photo(BuildContext context) => _sheet(
    context,
    (_) => PhotoSheet(
      hasPhoto: _c.person.data?.avatarUrl != null,
      pick: widget.pickPhoto,
      onUpload: _c.uploadPhoto,
      onRemove: _c.removePhoto,
    ),
    done: 'Photo saved.',
  );

  Widget _introCard(BuildContext context) {
    final p = _c.person.data;
    return SectionCard(
      cardKey: const ValueKey('card-intro'),
      title: 'Role and experience',
      editLabel: p?.designation == null && p?.yearsExperience == null ? 'Add' : 'Edit',
      onEdit: () => _intro(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FactLine(
            'Current role',
            Text(
              p?.designation ?? 'Not added yet — needed to submit.',
              key: const ValueKey('role-line'),
              style: MentoringText.body,
            ),
          ),
          FactLine(
            'Years in the profession',
            Text(
              p?.yearsExperience == null ? 'Not added yet — needed to submit.' : '${p!.yearsExperience} years',
              key: const ValueKey('years-line'),
              style: MentoringText.body,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _intro(BuildContext context) async {
    await _c.jobTitles.ensure();
    if (!context.mounted) return;
    await _sheet(
      context,
      (_) => IntroForm(
        designation: _c.person.data?.designation,
        years: _c.person.data?.yearsExperience,
        jobTitles: _c.jobTitles.data ?? const [],
        onSave: _c.savePerson,
      ),
    );
  }

  Widget _languagesCard(BuildContext context) {
    final langs = _c.person.data?.languages ?? const <String>[];
    return SectionCard(
      cardKey: const ValueKey('card-languages'),
      title: 'Languages',
      editLabel: langs.isEmpty ? 'Add' : 'Edit',
      onEdit: () => _languages(context),
      child: langs.isEmpty
          ? Text(
              'The languages you can mentor in — add at least one to submit.',
              key: const ValueKey('languages-line'),
              style: MentoringText.body,
            )
          : Wrap(spacing: 6, runSpacing: 6, children: [for (final l in langs) StatusPill(l, tone: PillTone.blue)]),
    );
  }

  Future<void> _languages(BuildContext context) =>
      _sheet(context, (_) => LanguagesForm(languages: _c.person.data?.languages ?? const [], onSave: _c.savePerson));

  Widget _experienceCard(BuildContext context) {
    final rows = _c.experience.data ?? const <ExperienceRow>[];
    return SectionCard(
      cardKey: const ValueKey('card-experience'),
      title: 'Career history',
      editLabel: 'Add a role',
      onEdit: rows.length >= ExperienceLimits.rowsMax ? null : () => _addRole(context),
      child: rows.isEmpty
          ? Text(
              'Add at least one role to your career history to submit.',
              key: const ValueKey('experience-line'),
              style: MentoringText.body,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, r) in rows.indexed)
                  InkWell(
                    key: ValueKey('role-$i'),
                    onTap: () => _editRole(context, i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.title, style: MentoringText.bodyStrong),
                                Text('${r.organisation} · ${r.span}', style: MentoringText.meta),
                              ],
                            ),
                          ),
                          const Icon(LucideIcons.pencil, size: 14, color: AppColors.outline),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _addRole(BuildContext context) => _sheet(
    context,
    (_) => ExperienceForm(onSave: (row) => _c.saveExperience([...?_c.experience.data, row])),
    done: 'Role added.',
  );

  Future<void> _editRole(BuildContext context, int i) {
    final rows = [...?_c.experience.data];
    return _sheet(
      context,
      (_) => ExperienceForm(
        row: rows[i],
        onSave: (row) => _c.saveExperience([...rows]..[i] = row),
        onRemove: () => _c.saveExperience([...rows]..removeAt(i)),
      ),
    );
  }

  // --- the mentoring half -----------------------------------------------------------

  Widget _bioCard(BuildContext context) {
    final text = bioToText(_c.mentor?.bioHtml);
    return SectionCard(
      cardKey: const ValueKey('card-bio'),
      title: 'How you mentor',
      editLabel: text.isEmpty ? 'Add' : 'Edit',
      onEdit: () => _bio(context),
      child: text.isEmpty
          ? Text(
              'What you are good at, who you tend to help and how you like to work. Mentees read this first — at least '
              '${MentorLimits.bioMin} characters.',
              key: const ValueKey('bio-line'),
              style: MentoringText.body,
            )
          : Text(text, key: const ValueKey('bio-line'), style: MentoringText.body),
    );
  }

  Future<void> _bio(BuildContext context) =>
      _sheet(context, (_) => BioForm(initialHtml: _c.mentor?.bioHtml, onSave: _c.saveProfile));

  Widget _expertiseCard(BuildContext context) {
    final m = _c.mentor;
    final areas = m?.competencies ?? const <String>[];
    return SectionCard(
      cardKey: const ValueKey('card-expertise'),
      title: 'Expertise',
      editLabel: areas.isEmpty && (m?.topics.isEmpty ?? true) ? 'Add' : 'Edit',
      onEdit: () => _expertise(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FactLine(
            'Areas of expertise',
            areas.isEmpty
                ? Text(
                    'None yet — add at least one to submit.',
                    key: const ValueKey('areas-line'),
                    style: MentoringText.body,
                  )
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final a in areas) StatusPill(a, tone: PillTone.blue)],
                  ),
          ),
          if (m != null && m.topics.isNotEmpty)
            FactLine(
              'Happy to talk about',
              Wrap(spacing: 6, runSpacing: 6, children: [for (final t in m.topics) StatusPill(t)]),
            ),
        ],
      ),
    );
  }

  Future<void> _expertise(BuildContext context) => _sheet(
    context,
    (_) => ExpertiseForm(
      competencies: _c.mentor?.competencies ?? const [],
      topics: _c.mentor?.topics ?? const [],
      onSave: _c.saveProfile,
    ),
  );

  Widget _certificationsCard(BuildContext context) {
    final certs = _c.mentor?.certifications ?? const <String>[];
    final stale = _c.staleCertifications;
    return SectionCard(
      cardKey: const ValueKey('card-certifications'),
      title: 'Certifications on your card',
      subtitle: 'Mentees filter the directory on these.',
      editLabel: certs.isEmpty ? 'Choose' : 'Edit',
      onEdit: () => _certifications(context),
      child: certs.isEmpty
          ? Text(
              (_c.credentials.data ?? const []).isEmpty
                  ? 'Optional. Record a certification under your credentials and you can show it here.'
                  : 'Optional. Show the certifications you hold — mentees working toward the same one look for them.',
              key: const ValueKey('certs-line'),
              style: MentoringText.body,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in certs) StatusPill(c, tone: stale.contains(c) ? PillTone.amber : PillTone.mint),
                  ],
                ),
                if (stale.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${stale.join(', ')} ${stale.length == 1 ? 'is' : 'are'} no longer on your profile — remove '
                      '${stale.length == 1 ? 'it' : 'them'} before you submit.',
                      style: MentoringText.error,
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _certifications(BuildContext context) async {
    await _c.credentials.ensure();
    if (!context.mounted) return;
    await _sheet(
      context,
      (_) => CertificationsForm(
        codes: _c.mentor?.certifications ?? const [],
        held: _c.credentials.data ?? const [],
        onSave: _c.saveProfile,
        onManage: () => _links.openSite(context, '/profile?tab=credentials&code=1'),
      ),
    );
  }

  Widget _audienceCard(BuildContext context) {
    final m = _c.mentor;
    final audiences = [for (final a in m?.targetAudiences ?? const <String>[]) ?MentorAudience.fromApi(a)?.label];
    return SectionCard(
      cardKey: const ValueKey('card-audience'),
      title: 'Who you mentor',
      editLabel: audiences.isEmpty ? 'Choose' : 'Edit',
      onEdit: () => _audience(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FactLine(
            'Who you want to mentor',
            audiences.isEmpty
                ? Text(
                    'Not chosen yet — needed to submit.',
                    key: const ValueKey('audience-line'),
                    style: MentoringText.body,
                  )
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final a in audiences) StatusPill(a, tone: PillTone.blue)],
                  ),
          ),
          if (m != null && m.targetRoles.isNotEmpty)
            FactLine(
              'Roles you can help people reach',
              Wrap(spacing: 6, runSpacing: 6, children: [for (final r in m.targetRoles) StatusPill(r)]),
            ),
        ],
      ),
    );
  }

  Future<void> _audience(BuildContext context) async {
    await _c.jobTitles.ensure();
    if (!context.mounted) return;
    await _sheet(
      context,
      (_) => AudienceForm(
        audiences: _c.mentor?.targetAudiences ?? const [],
        roles: _c.mentor?.targetRoles ?? const [],
        jobTitles: _c.jobTitles.data ?? const [],
        onSave: _c.saveProfile,
      ),
    );
  }

  Widget _availabilityCard(BuildContext context) {
    final m = _c.mentor;
    final modes = [for (final x in m?.preferredModes ?? const <String>[]) mentorModes[x] ?? x];
    return SectionCard(
      cardKey: const ValueKey('card-availability'),
      title: 'Availability',
      editLabel: 'Edit',
      onEdit: () => _availability(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FactLine(
            'Mentees at a time',
            Text(
              '${m?.capacity ?? MentorLimits.capacityDefault}',
              key: const ValueKey('capacity-line'),
              style: MentoringText.body,
            ),
          ),
          FactLine("How you'll meet", Text(modes.isEmpty ? 'Not set' : modes.join(' · '), style: MentoringText.body)),
          FactLine(
            'Cadence',
            Text(
              m?.cadence == null ? 'No preference' : mentorCadences[m!.cadence] ?? m.cadence!,
              style: MentoringText.body,
            ),
          ),
          FactLine(
            "When you're free",
            Text(
              m?.availabilityNote ?? 'Not said — e.g. weekday evenings after 7pm IST',
              key: const ValueKey('note-line'),
              style: MentoringText.body,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _availability(BuildContext context) =>
      _sheet(context, (_) => AvailabilityForm(profile: _c.mentor, onSave: _c.saveProfile));

  Widget _hoursCard(BuildContext context) {
    final m = _c.mentor;
    final blocks = [...?m?.availability]
      ..sort((a, b) => ((a.weekday + 6) % 7 * 1440 + a.startMin).compareTo((b.weekday + 6) % 7 * 1440 + b.startMin));
    const names = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return SectionCard(
      cardKey: const ValueKey('card-hours'),
      title: 'Weekly hours',
      subtitle: 'When mentees can book you.',
      editLabel: blocks.isEmpty ? 'Set hours' : 'Edit hours',
      // Hours belong to the mentor profile row, which the first save of any card creates.
      onEdit: m == null ? null : () => _hours(context),
      child: blocks.isEmpty
          ? Text(
              m == null
                  ? 'Save any section above first: your hours belong to your mentor profile.'
                  : 'No weekly hours set: a mentee asks you for a time instead of picking a free one.',
              key: const ValueKey('hours-line'),
              style: MentoringText.body,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final b in blocks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${names[b.weekday]}  ${minutesOfDay(b.startMin)} – ${minutesOfDay(b.endMin)}',
                      style: MentoringText.body,
                    ),
                  ),
                Text(m!.timezone.replaceAll('_', ' '), style: MentoringText.meta),
              ],
            ),
    );
  }

  Future<void> _hours(BuildContext context) => _sheet(
    context,
    (_) => WeeklyHoursForm(
      blocks: _c.mentor?.availability ?? const [],
      timezone: _c.mentor?.timezone ?? 'Asia/Kolkata',
      onSave: _c.saveHours,
    ),
    done: 'Hours saved.',
  );

  // --- the gates --------------------------------------------------------------------

  Widget _trainingCard(BuildContext context) {
    final t = _c.training;
    return SectionCard(
      cardKey: const ValueKey('card-training'),
      title: 'Mentor training',
      subtitle:
          'Short modules on how ICR mentoring works — boundaries, feedback, and what to do when something goes wrong. Finish them before your profile goes to review.',
      editLabel: '',
      onEdit: null,
      trailing: StatusPill(
        '${t.completedCount} of ${t.requiredCount} complete',
        tone: t.allComplete ? PillTone.mint : PillTone.grey,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: t.completedCount / (t.requiredCount == 0 ? 1 : t.requiredCount),
              minHeight: 6,
              backgroundColor: AppColors.surfaceContainer,
              color: MentoringColors.green,
            ),
          ),
          const SizedBox(height: 10),
          for (final course in t.required)
            Padding(
              key: ValueKey('course-${course.code}'),
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: GateRow(
                      done: course.completed,
                      label: course.title,
                      caption:
                          '${course.durationLabel == null ? '' : '${course.durationLabel} · '}${course.statusLabel}',
                    ),
                  ),
                  if (!course.completed)
                    QuietButton(
                      label: course.notEnrolled ? 'Enrol' : 'Open',
                      onPressed: () => _links.openSite(context, '/learning/professional-development/${course.code}'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _training(BuildContext context) {
    final next = _c.training.required.where((c) => !c.completed).firstOrNull;
    if (next != null) _links.openSite(context, '/learning/professional-development/${next.code}');
  }

  Future<void> _conduct(BuildContext context) async {
    await _c.conduct.ensure();
    final conduct = _c.conduct.data;
    if (!context.mounted) return;
    if (conduct == null) {
      showMessage(context, _c.conduct.error ?? 'The code of conduct has not loaded yet — try again in a moment.');
      return;
    }
    final agreed = await showFormSheet(
      context,
      (_) => ConductSheet(conduct: conduct, accepted: _c.conductAccepted, onAgree: _c.agreeToConduct),
    );
    if (agreed && context.mounted) showMessage(context, 'Agreed. Thank you.');
  }

  Widget _documentsCard(BuildContext context) {
    final docs = _c.documents.data ?? const <MentorDocument>[];
    return SectionCard(
      cardKey: const ValueKey('card-documents'),
      title: 'Supporting documents',
      subtitle: 'Optional evidence for ICR\'s review team: a certificate, proof of where you work, a reference.',
      editLabel: 'Add',
      onEdit: docs.length >= MentorLimits.documentsMax ? null : () => _addDocument(context),
      child: docs.isEmpty
          ? Text('Nothing attached yet.', key: const ValueKey('documents-line'), style: MentoringText.body)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final d in docs)
                  Padding(
                    key: ValueKey('doc-${d.id}'),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(d.label ?? d.fileName ?? d.kindLabel, style: MentoringText.bodyStrong),
                            ),
                            StatusPill(
                              d.statusLabel,
                              tone: switch (d.status) {
                                'VERIFIED' => PillTone.mint,
                                'REJECTED' => PillTone.red,
                                _ => PillTone.amber,
                              },
                            ),
                          ],
                        ),
                        Text(
                          '${d.kindLabel}${d.fileSize == null ? '' : ' · ${fileSizeLabel(d.fileSize!)}'} · ${dayLabel(d.createdAt)}',
                          style: MentoringText.meta,
                        ),
                        if (d.reviewNote != null) Text(d.reviewNote!, style: MentoringText.quote),
                        if (d.removable)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: QuietButton(
                              label: 'Remove',
                              icon: LucideIcons.trash2,
                              danger: true,
                              onPressed: () async {
                                final refusal = await _c.removeDocument(d);
                                if (context.mounted) showMessage(context, refusal ?? 'Removed.');
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _addDocument(BuildContext context) => _sheet(
    context,
    (_) => DocumentForm(
      pick: widget.pickDocument,
      onSave: (file, kind, label) => _c.addDocument(file, kind: kind, label: label),
    ),
    done: 'Attached. ICR\'s review team will read it.',
  );

  // --- the listing ------------------------------------------------------------------

  Widget _listingCard(BuildContext context) {
    final m = _c.mentor!;
    return SectionCard(
      cardKey: const ValueKey('card-listing'),
      title: 'Your listing',
      editLabel: '',
      onEdit: null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile.adaptive(
            key: const ValueKey('visibility'),
            contentPadding: EdgeInsets.zero,
            value: m.discoverable,
            onChanged: _c.busy
                ? null
                : (on) async {
                    final refusal = await _c.setVisibility(on);
                    if (context.mounted) {
                      showMessage(
                        context,
                        refusal ?? (on ? 'You are taking new requests.' : 'Hidden: you are not taking new requests.'),
                      );
                    }
                  },
            title: Text('Accepting new requests', style: MentoringText.bodyStrong),
            subtitle: Text(
              m.discoverable
                  ? 'Mentees can find you and ask.'
                  : 'Your profile is hidden. Existing mentorships are unaffected.',
              style: MentoringText.meta,
            ),
          ),
          ActionWrap(
            top: 6,
            children: [
              if (m.status == MentorStatus.approved)
                SolidButton(
                  label: 'View public profile',
                  icon: LucideIcons.externalLink,
                  onPressed: () => _links.mentor(context, m.id),
                ),
              QuietButton(
                label: 'Withdraw my profile',
                icon: LucideIcons.userMinus,
                danger: true,
                onPressed: () => _withdraw(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _withdraw(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Withdraw your mentor profile?'),
        content: const Text(
          'It leaves the directory and stops taking requests. Your history is kept, and you can start again later. '
          'You cannot withdraw while a mentorship is under way: pause your profile instead.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Keep it')),
          TextButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Withdraw')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final refusal = await _c.withdraw();
    if (context.mounted) showMessage(context, refusal ?? 'Withdrawn. You can start again any time.');
  }
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

class _GroupHeading extends StatelessWidget {
  const _GroupHeading(this.title, this.subtitle);

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 14, 2, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: MentoringText.section),
        const SizedBox(height: 2),
        Text(subtitle, style: MentoringText.meta),
      ],
    ),
  );
}

/// Where the mentor stands: the one line that says what happens next.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status, required this.hasProfile, this.reviewNote});

  final MentorStatus status;
  final bool hasProfile;
  final String? reviewNote;

  @override
  Widget build(BuildContext context) {
    final (tone, title, body) = switch (status) {
      MentorStatus.approved => (
        PillTone.mint,
        status.label,
        'Members can find you in the directory. Edits stay live; only a rejected profile is reviewed again.',
      ),
      MentorStatus.pending => (
        PillTone.blue,
        status.label,
        'A member of the ICR team is reading your profile. We vet mentors because your name will carry the '
            'association\'s to someone early in their career.',
      ),
      MentorStatus.rejected => (PillTone.amber, status.label, reviewNote ?? 'The review team asked for changes.'),
      MentorStatus.paused => (
        PillTone.amber,
        status.label,
        'Your profile is hidden from the directory and is not taking new requests. Existing mentorships are unaffected.',
      ),
      MentorStatus.draft => (
        PillTone.blue,
        'Draft — not yet visible',
        'Fill in each section, agree to the code of conduct and send your profile to the ICR team. Review usually takes a couple of days.',
      ),
    };
    return Callout(key: ValueKey('banner-${status.api}'), tone: tone, text: '$title\n$body');
  }
}

/// The application: where it stands, what is still needed (each line opens the sheet that fixes it), the code of
/// conduct agreement beside Submit (what the mentor is signing), and Submit.
class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.controller,
    required this.onFix,
    required this.onReadConduct,
    required this.onAgree,
    required this.onSubmit,
  });

  final BecomeMentorController controller;
  final ValueChanged<Need> onFix;
  final VoidCallback onReadConduct;
  final VoidCallback onAgree;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final steps = c.steps;
    final done = steps.where((s) => s.done).length;
    final needed = c.needed;
    final canSubmit = c.status.canSubmit;
    final listed = c.status.listed;
    final version = c.conduct.data?.version;
    return MentoringCard(
      key: const ValueKey('application'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Your application', style: MentoringText.cardTitle)),
              StatusPill(
                c.hasProfile ? c.status.label : 'Not started',
                tone: switch (c.status) {
                  MentorStatus.approved => PillTone.mint,
                  MentorStatus.pending => PillTone.blue,
                  MentorStatus.paused || MentorStatus.rejected => PillTone.amber,
                  MentorStatus.draft => PillTone.grey,
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '$done of ${steps.length} steps done',
              key: const ValueKey('steps-done'),
              style: MentoringText.meta,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: done / steps.length,
              minHeight: 8,
              backgroundColor: AppColors.surfaceContainer,
              color: listed ? MentoringColors.green : AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          for (final s in steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GateRow(done: s.done, label: s.label),
            ),
          if (needed.isNotEmpty) ...[
            const Divider(height: 22),
            Text(
              canSubmit ? 'Still needed to submit' : 'Still missing from your card',
              style: MentoringText.bodyStrong,
            ),
            const SizedBox(height: 4),
            for (final (i, n) in needed.indexed)
              InkWell(
                key: ValueKey('need-$i'),
                onTap: () => onFix(n),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.circle, size: 16, color: AppColors.outline),
                      const SizedBox(width: 8),
                      Expanded(child: Text(n.message, style: MentoringText.body)),
                      const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.outline),
                    ],
                  ),
                ),
              ),
          ],
          const Divider(height: 22),
          Row(
            children: [
              Expanded(child: Text('Code of conduct', style: MentoringText.bodyStrong)),
              if (c.conductAccepted)
                StatusPill('Accepted — ${c.readiness.data?.conductVersion ?? ''}', tone: PillTone.mint),
            ],
          ),
          CheckboxListTile(
            key: const ValueKey('conduct-check'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            value: c.conductAccepted,
            onChanged: c.conductAccepted || c.busy || version == null ? null : (on) => on == true ? onAgree() : null,
            title: Text(
              version == null
                  ? 'I have read and agree to the ICR Mentor Code of Conduct.'
                  : 'I have read and agree to the ICR Mentor Code of Conduct (version $version).',
              style: MentoringText.body,
            ),
          ),
          InkWell(
            key: const ValueKey('read-conduct'),
            onTap: onReadConduct,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('Read the code of conduct', style: MentoringText.buttonQuiet),
            ),
          ),
          if (canSubmit && !c.conductAccepted)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Tick this to send your profile for review.', style: MentoringText.meta),
            ),
          if (canSubmit) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SolidButton(
                key: const ValueKey('submit'),
                label: c.busy
                    ? 'Sending…'
                    : c.status == MentorStatus.rejected
                    ? 'Resubmit for review'
                    : 'Submit for review',
                icon: LucideIcons.send,
                onPressed: c.busy || !c.ready ? null : onSubmit,
              ),
            ),
            if (!c.ready)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  needed.isNotEmpty ? 'Finish the items above to submit.' : 'Agree to the code of conduct to submit.',
                  key: const ValueKey('submit-hint'),
                  style: MentoringText.meta,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
