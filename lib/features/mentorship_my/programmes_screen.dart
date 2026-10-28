import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import 'group_sessions_screen.dart';
import 'loader.dart';
import 'mentoring_format.dart';
import 'mentoring_links.dart';
import 'mentoring_models.dart';
import 'mentoring_repository.dart';
import 'widgets/forms.dart';
import 'widgets/intent_form.dart';
import 'widgets/kit.dart';

/// Pushes the programmes browser (`/mentorship/programmes`).
Future<void> openProgrammes(
  BuildContext context, {
  MentorshipLinks? links,
  OpenConversation? onOpenConversation,
  void Function(BuildContext context, String mentorProfileId)? onOpenMentor,
  void Function(BuildContext context)? onBell,
  OpenSitePath? onOpenWebsite,
  void Function(BuildContext context)? onBecomeMentor,
}) {
  final resolved = MentorshipLinks.resolve(
    context,
    links,
    onOpenConversation: onOpenConversation,
    onOpenMentor: onOpenMentor,
    onBell: onBell,
    onOpenWebsite: onOpenWebsite,
  );
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ProgrammesScreen(links: resolved, onBecomeMentor: onBecomeMentor),
    ),
  );
}

/// Pushes one programme.
Future<void> openProgramme(
  BuildContext context,
  String slug, {
  MentorshipLinks? links,
  OpenConversation? onOpenConversation,
  void Function(BuildContext context, String mentorProfileId)? onOpenMentor,
  void Function(BuildContext context)? onBell,
  OpenSitePath? onOpenWebsite,
  void Function(BuildContext context)? onBecomeMentor,
}) {
  final resolved = MentorshipLinks.resolve(
    context,
    links,
    onOpenConversation: onOpenConversation,
    onOpenMentor: onOpenMentor,
    onBell: onBell,
    onOpenWebsite: onOpenWebsite,
  );
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ProgrammeScreen(slug: slug, links: resolved, onBecomeMentor: onBecomeMentor),
    ),
  );
}

// ---------------------------------------------------------------------------
// Controllers
// ---------------------------------------------------------------------------

/// The programmes the member can apply to (or already took part in).
class ProgrammesController extends ChangeNotifier {
  ProgrammesController(this.repository) {
    list = Loader(() => repository.programmes(status: _status), _notify);
    mine = Loader(repository.myProgrammes, _notify);
  }

  final MentoringRepository repository;
  late final Loader<List<Programme>> list;
  late final Loader<List<ProgrammeEnrolment>> mine;
  String? _status = 'OPEN';
  bool _disposed = false;

  /// OPEN (applications open), RUNNING, or null for every programme.
  String? get status => _status;

  Future<void> load() => Future.wait([list.load(), mine.load()]);

  Future<void> filter(String? status) {
    _status = status;
    return list.load();
  }

  /// The member's live application to [p], from the `mine` list.
  ProgrammeEnrolment? mineIn(Programme p) =>
      (mine.data ?? const <ProgrammeEnrolment>[]).where((e) => e.programId == p.id && e.live).firstOrNull;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// One programme: its detail, the group sessions inside it, and applying or withdrawing.
class ProgrammeController extends ChangeNotifier {
  ProgrammeController(this.repository, this.slug) {
    programme = Loader(() => repository.programme(slug), _notify);
    sessions = Loader(_loadSessions, _notify);
  }

  final MentoringRepository repository;
  final String slug;
  late final Loader<Programme> programme;
  late final Loader<List<GroupSession>> sessions;
  bool _busy = false;
  bool _disposed = false;

  bool get busy => _busy;

  Future<List<GroupSession>> _loadSessions() async {
    final p = programme.data ?? await repository.programme(slug);
    final page = await repository.groupSessions(programId: p.id, limit: 20);
    return page.items;
  }

  Future<void> load() async {
    await programme.load();
    if (programme.data != null) await sessions.load();
  }

  /// Applies on one side. Returns the API's refusal (and its `code`) rather than throwing.
  Future<ApiError?> apply(ProgrammeRole role, {String? motivation}) async {
    _busy = true;
    _notify();
    try {
      await repository.enrol(slug, role, motivation: motivation);
      await programme.load();
      return null;
    } catch (e) {
      return ApiError.from(e);
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<String?> withdraw(ProgrammeEnrolment e) async {
    _busy = true;
    _notify();
    try {
      await repository.withdrawEnrolment(e.id);
      await programme.load();
      return null;
    } catch (err) {
      return ApiError.from(err).message;
    } finally {
      _busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// The browser
// ---------------------------------------------------------------------------

class ProgrammesScreen extends StatefulWidget {
  const ProgrammesScreen({
    super.key,
    this.onBack,
    this.links,
    this.repository,
    this.onBecomeMentor,
    this.onOpenConversation,
    this.onOpenMentor,
    this.onBell,
    this.onOpenWebsite,
  });

  final VoidCallback? onBack;
  final MentorshipLinks? links;
  final MentoringRepository? repository;

  /// Where "Set up my mentor profile" leads (the become-a-mentor flow); the website's page by default.
  final void Function(BuildContext context)? onBecomeMentor;
  final OpenConversation? onOpenConversation;
  final void Function(BuildContext context, String mentorProfileId)? onOpenMentor;
  final void Function(BuildContext context)? onBell;
  final OpenSitePath? onOpenWebsite;

  @override
  State<ProgrammesScreen> createState() => _ProgrammesScreenState();
}

class _ProgrammesScreenState extends State<ProgrammesScreen> {
  late final ProgrammesController _c;
  late final MentorshipLinks _links;

  @override
  void initState() {
    super.initState();
    final repo = widget.repository ?? MentoringRepository(api: context.read<ApiClient>());
    _links = MentorshipLinks.resolve(
      context,
      widget.links,
      onOpenConversation: widget.onOpenConversation,
      onOpenMentor: widget.onOpenMentor,
      onBell: widget.onBell,
      onOpenWebsite: widget.onOpenWebsite,
    );
    _c = ProgrammesController(repo)..load();
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
        final loading = _c.list.loading && !_c.list.loaded;
        final failed = !_c.list.loaded ? _c.list.error : null;
        final rows = _c.list.data ?? const <Programme>[];
        return MentoringPage(
          title: 'Programmes',
          onBack: widget.onBack,
          onBell: () => _links.notifications(context),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: SegmentTabs(
                  labels: const ['Open for applications', 'Under way', 'All'],
                  selected: switch (_c.status) {
                    'OPEN' => 0,
                    'RUNNING' => 1,
                    _ => 2,
                  },
                  onSelect: (i) => _c.filter(const ['OPEN', 'RUNNING', null][i]),
                ),
              ),
              Expanded(
                child: LoadedList(
                  loading: loading,
                  error: failed,
                  errorTitle: "Couldn't load the programmes",
                  onRefresh: _c.load,
                  children: loading || failed != null
                      ? const []
                      : [
                          if (rows.isEmpty)
                            const EmptyNote(
                              icon: LucideIcons.layers,
                              title: 'No programmes here',
                              body: 'Cohort programmes open for applications from time to time. Look again soon.',
                            ),
                          for (final p in rows) _ProgrammeCard(programme: p, mine: _c.mineIn(p), onTap: () => _open(p)),
                        ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _open(Programme p) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProgrammeScreen(
          slug: p.slug,
          links: _links,
          repository: _c.repository,
          onBecomeMentor: widget.onBecomeMentor,
        ),
      ),
    );
    if (mounted) _c.load();
  }
}

class _ProgrammeCard extends StatelessWidget {
  const _ProgrammeCard({required this.programme, required this.onTap, this.mine});

  final Programme programme;
  final ProgrammeEnrolment? mine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = programme;
    return MentoringCard(
      key: ValueKey('programme-${p.slug}'),
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.cover != null)
            SizedBox(
              height: 110,
              width: double.infinity,
              child: Photo(picture: p.cover),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(p.name, style: MentoringText.cardTitle)),
                    if (mine != null)
                      StatusPill(mine!.statusLabel, tone: mine!.status == 'APPLIED' ? PillTone.amber : PillTone.mint)
                    else
                      StatusPill(p.statusLabel, tone: p.open ? PillTone.mint : PillTone.grey),
                  ],
                ),
                MetaLine(icon: LucideIcons.user, text: 'Run by ${p.organiser.name}'),
                if (p.startsAt != null || p.applicationsCloseAt != null)
                  MetaLine(
                    icon: LucideIcons.calendarDays,
                    text: [
                      if (p.startsAt != null) 'Starts ${dayLabel(p.startsAt!)}',
                      if (p.applicationsCloseAt != null && p.open) 'apply by ${dayLabel(p.applicationsCloseAt!)}',
                    ].join(' · '),
                  ),
                MetaLine(icon: LucideIcons.users, text: '${countLabel(p.enrolmentCount, 'person', 'people')} so far'),
                if (p.summary != null && p.summary!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(p.summary!, maxLines: 3, overflow: TextOverflow.ellipsis, style: MentoringText.body),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// One programme
// ---------------------------------------------------------------------------

class ProgrammeScreen extends StatefulWidget {
  const ProgrammeScreen({
    super.key,
    required this.slug,
    this.onBack,
    this.links,
    this.repository,
    this.onBecomeMentor,
    this.onOpenConversation,
    this.onOpenMentor,
    this.onBell,
    this.onOpenWebsite,
  });

  final String slug;
  final VoidCallback? onBack;
  final MentorshipLinks? links;
  final MentoringRepository? repository;
  final void Function(BuildContext context)? onBecomeMentor;
  final OpenConversation? onOpenConversation;
  final void Function(BuildContext context, String mentorProfileId)? onOpenMentor;
  final void Function(BuildContext context)? onBell;
  final OpenSitePath? onOpenWebsite;

  @override
  State<ProgrammeScreen> createState() => _ProgrammeScreenState();
}

class _ProgrammeScreenState extends State<ProgrammeScreen> {
  late final ProgrammeController _c;
  late final MentorshipLinks _links;

  @override
  void initState() {
    super.initState();
    final repo = widget.repository ?? MentoringRepository(api: context.read<ApiClient>());
    _links = MentorshipLinks.resolve(
      context,
      widget.links,
      onOpenConversation: widget.onOpenConversation,
      onOpenMentor: widget.onOpenMentor,
      onBell: widget.onBell,
      onOpenWebsite: widget.onOpenWebsite,
    );
    _c = ProgrammeController(repo, widget.slug)..load();
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
        final p = _c.programme.data;
        return MentoringPage(
          title: 'Programme',
          onBack: widget.onBack,
          onBell: () => _links.notifications(context),
          body: LoadedList(
            loading: _c.programme.loading && p == null,
            error: p == null ? _c.programme.error : null,
            errorTitle: "Couldn't load this programme",
            onRefresh: _c.load,
            children: p == null ? const [] : _content(context, p),
          ),
        );
      },
    );
  }

  List<Widget> _content(BuildContext context, Programme p) {
    final detail = plainText(p.detailHtml);
    final sessions = _c.sessions.data ?? const <GroupSession>[];
    final mentee = p.enrolmentAs(ProgrammeRole.mentee);
    final mentor = p.enrolmentAs(ProgrammeRole.mentor);
    return [
      if (p.cover != null)
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 150,
            width: double.infinity,
            child: Photo(picture: p.cover),
          ),
        ),
      if (p.cover != null) const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: Text(p.name, style: MentoringText.hero)),
          StatusPill(p.statusLabel, tone: p.open ? PillTone.mint : PillTone.grey),
        ],
      ),
      const SizedBox(height: 8),
      PersonRow(person: p.organiser, subline: 'Run by'),
      if (p.startsAt != null || p.endsAt != null)
        MetaLine(
          icon: LucideIcons.calendarDays,
          text: [
            if (p.startsAt != null) 'Starts ${dayLabel(p.startsAt!)}',
            if (p.endsAt != null) 'ends ${dayLabel(p.endsAt!)}',
          ].join(' · '),
        ),
      if (p.applicationsCloseAt != null)
        MetaLine(
          icon: LucideIcons.hourglass,
          text: p.open
              ? 'Applications close ${dayLabel(p.applicationsCloseAt!)}'
              : 'Applications closed ${dayLabel(p.applicationsCloseAt!)}',
        ),
      MetaLine(
        icon: LucideIcons.users,
        key: const ValueKey('capacity-line'),
        text:
            'Mentees ${p.menteesTaken ?? 0}${p.menteeCapacity == null ? '' : ' of ${p.menteeCapacity}'} · '
            'Mentors ${p.mentorsTaken ?? 0}${p.mentorCapacity == null ? '' : ' of ${p.mentorCapacity}'}',
      ),
      if (p.summary != null && p.summary!.isNotEmpty) ...[
        const SectionTitle(title: 'About', top: 14),
        Text(p.summary!, style: MentoringText.body),
      ],
      if (detail.isNotEmpty) ...[
        const SectionTitle(title: 'The detail', top: 12),
        Text(detail, key: const ValueKey('programme-detail'), style: MentoringText.body),
      ],
      if (p.competencies.isNotEmpty || p.focusAreas.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in {...p.competencies, ...p.focusAreas}) StatusPill(c, tone: PillTone.blue),
            ],
          ),
        ),
      const SectionTitle(title: 'Your place', top: 16),
      ..._place(context, p, mentee, mentor),
      if (sessions.isNotEmpty) ...[
        const SectionTitle(title: 'Sessions in this programme', top: 16),
        for (final s in sessions)
          GroupSessionCard(
            session: s,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GroupSessionScreen(id: s.id, links: _links, repository: _c.repository),
              ),
            ),
          ),
      ],
    ];
  }

  List<Widget> _place(BuildContext context, Programme p, ProgrammeEnrolment? mentee, ProgrammeEnrolment? mentor) {
    Widget enrolled(ProgrammeEnrolment e) => Callout(
      key: ValueKey('enrolment-${e.role.api}'),
      tone: e.status == 'APPLIED' ? PillTone.amber : PillTone.mint,
      text:
          'You applied as ${e.role.label.toLowerCase()}: ${e.statusLabel.toLowerCase()}.'
          '${e.decisionNote == null || e.decisionNote!.isEmpty ? '' : ' “${e.decisionNote}”'}',
      actions: [
        if (e.status == 'APPLIED' || e.status == 'ACCEPTED')
          QuietButton(
            label: 'Withdraw',
            danger: true,
            onPressed: () async {
              final refusal = await _c.withdraw(e);
              if (context.mounted) showMessage(context, refusal ?? 'Application withdrawn.');
            },
          ),
      ],
    );
    return [
      if (mentee != null) enrolled(mentee),
      if (mentor != null) enrolled(mentor),
      if (p.open && (mentee == null || mentor == null))
        ActionWrap(
          top: mentee != null || mentor != null ? 8 : 0,
          children: [
            SolidButton(
              label: mentee == null && mentor == null ? 'Apply to join' : 'Apply on the other side',
              icon: LucideIcons.send,
              onPressed: () => _apply(
                context,
                p,
                mentee == null && mentor == null
                    ? ProgrammeRole.mentee
                    : (mentee == null ? ProgrammeRole.mentee : ProgrammeRole.mentor),
              ),
            ),
          ],
        ),
      if (!p.open && mentee == null && mentor == null)
        Text(
          p.status == 'OPEN' ? 'Applications have closed.' : 'This programme is not taking applications.',
          style: MentoringText.body,
        ),
    ];
  }

  Future<void> _apply(BuildContext context, Programme p, ProgrammeRole role) async {
    final sent = await showFormSheet(
      context,
      (_) => _ApplyForm(
        controller: _c,
        programme: p,
        initialRole: role,
        links: _links,
        onBecomeMentor: widget.onBecomeMentor,
      ),
    );
    if (sent && context.mounted) showMessage(context, 'Application sent. The organisers will be in touch.');
  }
}

/// Which side, and why: sent to the organisers. Eligibility refusals (a mentor profile, a mentee profile) are
/// shown as the API words them with the way to fix them, read from the API's `code`.
class _ApplyForm extends StatefulWidget {
  const _ApplyForm({
    required this.controller,
    required this.programme,
    required this.initialRole,
    required this.links,
    this.onBecomeMentor,
  });

  final ProgrammeController controller;
  final Programme programme;
  final ProgrammeRole initialRole;
  final MentorshipLinks links;
  final void Function(BuildContext context)? onBecomeMentor;

  @override
  State<_ApplyForm> createState() => _ApplyFormState();
}

class _ApplyFormState extends State<_ApplyForm> {
  final _why = TextEditingController();
  late ProgrammeRole _role = widget.initialRole;
  ApiError? _error;
  bool _busy = false;

  @override
  void dispose() {
    _why.dispose();
    super.dispose();
  }

  bool get _full {
    final p = widget.programme;
    return _role == ProgrammeRole.mentor
        ? p.mentorCapacity != null && (p.mentorsTaken ?? 0) >= p.mentorCapacity!
        : p.menteeCapacity != null && (p.menteesTaken ?? 0) >= p.menteeCapacity!;
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await widget.controller.apply(_role, motivation: _why.text);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  Future<void> _fixMentee() async {
    final repo = widget.controller.repository;
    final options = await repo.focusOptions().catchError((_) => const <String>[]);
    final current = await repo.menteeIntent().catchError((_) => null);
    if (!mounted) return;
    final saved = await showIntentSheet(
      context,
      current: current,
      focusOptions: options,
      onSave: (intent) async {
        try {
          await repo.saveMenteeIntent(intent);
          return null;
        } catch (e) {
          return ApiError.from(e).message;
        }
      },
    );
    if (saved && mounted) setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final code = _error?.code;
    final needsMentor = code == 'PROGRAMME_NEEDS_MENTOR_PROFILE';
    final needsMentee = code == 'PROGRAMME_NEEDS_MENTEE_PROFILE';
    return MentoringForm(
      title: 'Apply to ${widget.programme.name}',
      subtitle: 'The organisers read this when they match the cohort.',
      submitLabel: 'Send application',
      busy: _busy,
      problem: needsMentor || needsMentee ? null : _error?.message,
      onSubmit: _full ? null : _submit,
      children: [
        FieldBlock(
          label: 'Which side are you applying on?',
          child: Wrap(
            spacing: 6,
            children: [
              for (final r in ProgrammeRole.values)
                ChoiceChip(
                  key: ValueKey('role-${r.api}'),
                  label: Text(r.label),
                  selected: _role == r,
                  onSelected: (_) => setState(() {
                    _role = r;
                    _error = null;
                  }),
                ),
            ],
          ),
        ),
        if (_full) Callout(tone: PillTone.amber, text: 'The ${_role.label.toLowerCase()} side is full.'),
        FieldBlock(
          label: 'Why this cohort? (optional)',
          help: '${_why.text.length}/2000',
          child: TextField(
            key: const ValueKey('apply-motivation'),
            controller: _why,
            minLines: 4,
            maxLines: 8,
            maxLength: 2000,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            onChanged: (_) => setState(() {}),
            style: MentoringText.formInput,
            decoration: fieldDecoration('What you want out of it'),
          ),
        ),
        if (needsMentor || needsMentee)
          Callout(
            key: const ValueKey('apply-fix'),
            tone: PillTone.amber,
            text: _error!.message,
            actions: [
              if (needsMentor)
                SolidButton(
                  label: 'Set up my mentor profile',
                  onPressed: () {
                    final go = widget.onBecomeMentor;
                    if (go != null) {
                      go(context);
                    } else {
                      widget.links.openSite(context, '/mentorship/become-a-mentor');
                    }
                  },
                ),
              if (needsMentee) SolidButton(label: 'Tell us what you are after', onPressed: _fixMentee),
            ],
          ),
      ],
    );
  }
}

/// A colour for a programme's status word, shared with the cards.
Color programmeInk(Programme p) => p.open ? MentoringColors.mintInk : AppColors.onSurfaceVariant;
