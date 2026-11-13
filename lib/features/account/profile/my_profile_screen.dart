import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/util/links.dart';
import '../account_labels.dart';
import '../account_models.dart';
import '../account_repository.dart';
import '../account_rules.dart';
import '../api_account_repository.dart';
import '../demo_account_repository.dart';
import '../phone/phone_sheets.dart';
import '../settings/settings_screen.dart';
import '../widgets/account_kit.dart';
import '../widgets/account_session.dart';
import '../widgets/photo_picker.dart';
import 'profile_controller.dart';
import 'profile_kit.dart';
import 'sheets/basic_sheets.dart';
import 'sheets/career_sheets.dart';
import 'sheets/credential_sheet.dart';

/// Hands a profile link to the phone's share sheet.
typedef ShareText = Future<void> Function(String text, String subject);

Future<void> shareWithPhone(String text, String subject) =>
    SharePlus.instance.share(ShareParams(text: text, subject: subject)).then((_) {});

/// The person's own profile, laid out like LinkedIn's: one page of read-only
/// section cards (the header with its cover and photo, About, Experience,
/// Education, Credentials, Skills, Languages), each edited in a sheet from its
/// pencil or its plus. Nothing on the page itself is a form.
///
/// Everything here belongs to the PERSON and follows them between companies.
/// Their company's identity and listing live on the company pages.
///
/// What the lead wires:
///
/// * [onOpenPublicProfile]: "View public profile", the member page (`MemberProfileScreen`);
/// * [onOpenSettings]: the gear (this feature's `SettingsScreen` when left out), where Sign-In and Security lives —
///   the profile has no row of its own for it (owner, 12 Nov 2026);
/// * [onOpenCertificate]: a credential ICR issued opens its certificate (the
///   Learning Center's, or the mentoring one); the website page when left out;
/// * [onProfileChanged]: call `ProfileDrawerController.refresh()` here, so the menu shows the new
///   name, photo, headline and cover.
class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({
    super.key,
    this.repository,
    this.onBack,
    this.onOpenPublicProfile,
    this.onOpenSettings,
    this.onOpenCertificate,
    this.onProfileChanged,
    this.initialSection,
    this.pickPhoto = pickImageFromDevice,
    this.pickEvidence = pickEvidenceFromDevice,
    this.share = shareWithPhone,
    this.now,
  });

  /// Instead of the API (tests, and the sample member in demo mode).
  final AccountRepository? repository;

  /// The bar's Back; pops the route when left out.
  final VoidCallback? onBack;

  /// "View public profile": the member page for this person's id.
  final void Function(String userId)? onOpenPublicProfile;

  /// The gear in the bar: Settings (`SettingsScreen` when left out).
  final VoidCallback? onOpenSettings;

  /// A credential ICR issued: its certificate page path (`/learning/certificates/…`).
  final void Function(Credential credential)? onOpenCertificate;

  /// The name, photo, headline or cover changed: the profile menu (which keeps its own copy) reads them again.
  final VoidCallback? onProfileChanged;

  /// A section to bring into view and open on arrival (`?tab=experience`).
  final ProfileSection? initialSection;

  final PhotoPicker pickPhoto;
  final PhotoPicker pickEvidence;
  final ShareText share;

  /// The clock the durations and career gaps read.
  final DateTime? now;

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

/// The sections `?tab=` can name.
enum ProfileSection { about, experience, education, credentials, skills, languages }

class _MyProfileScreenState extends State<MyProfileScreen> {
  late final MyProfileController _c;
  late final AccountRepository _repository;
  final _keys = {for (final s in ProfileSection.values) s: GlobalKey()};

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        (AppConfig.demo ? DemoAccountRepository() : ApiAccountRepository(api: context.read<ApiClient>()));
    final auth = maybeAuth(context);
    _c =
        MyProfileController(
            _repository,
            onIdentityChanged: () async {
              await auth?.refreshUser();
              widget.onProfileChanged?.call();
            },
            clock: widget.now == null ? null : () => widget.now!,
          )
          ..load().then((_) {
            final section = widget.initialSection;
            if (section != null && mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final ctx = _keys[section]!.currentContext;
                if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250));
              });
            }
          });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _say(String message) => showMessage(context, message);

  // --- opening the sheets --------------------------------------------------------------------------------------

  Future<void> _afterSave(Future<bool> sheet, String saved) async {
    if (await sheet && mounted) _say(saved);
  }

  bool _needs(Section<Object?> section, String what) {
    if (section.ready) return true;
    _say('Your $what is still loading. Try again in a moment.');
    return false;
  }

  void _editIntro() {
    if (_c.profile.ready) _afterSave(showIntroSheet(context, _c), 'Intro saved.');
  }

  void _editAbout() {
    if (_c.profile.ready) _afterSave(showAboutSheet(context, _c), 'About saved.');
  }

  void _editSkills() {
    if (_c.profile.ready) _afterSave(showSkillsSheet(context, _c), 'Skills saved.');
  }

  void _editLanguages() {
    if (_c.profile.ready) _afterSave(showLanguagesSheet(context, _c), 'Languages saved.');
  }

  void _editRole([Experience? role]) {
    if (_needs(_c.experience, 'experience')) {
      _afterSave(showExperienceSheet(context, _c, role: role), 'Experience saved.');
    }
  }

  void _editDegree([Education? degree]) {
    if (_needs(_c.education, 'education')) {
      _afterSave(showEducationSheet(context, _c, degree: degree), 'Education saved.');
    }
  }

  void _editBreak({CareerBreak? pause, CareerGap? gap}) {
    if (_needs(_c.breaks, 'career breaks')) {
      _afterSave(showCareerBreakSheet(context, _c, pause: pause, prefill: gap), 'Career break saved.');
    }
  }

  void _editCredential([Credential? credential]) {
    _afterSave(
      showCredentialSheet(context, _c, credential: credential, pickEvidence: widget.pickEvidence),
      'Credential saved.',
    );
  }

  void _openCredential(Credential c) {
    final open = widget.onOpenCertificate;
    if (open != null) {
      open(c);
    } else if (c.href != null) {
      openSitePage(context, c.href!);
    }
  }

  Future<void> _editPhone() async {
    final me = _c.profile.value;
    if (me == null) return;
    final changed = await showPhoneSheet(context, repository: _repository, phone: me.phone, verified: me.phoneVerified);
    if (changed) await _c.refresh();
  }

  // --- the completeness checklist ------------------------------------------------------------------------------

  /// Which sheet finishes a missing item (`resolvePersonalTask`).
  void _finish(String label) {
    final l = label.toLowerCase();
    if (l.contains('work history')) return _editRole();
    if (l.contains('education')) return _editDegree();
    if (l.contains('phone')) {
      _editPhone();
      return;
    }
    if (l.contains('photo')) {
      showPhotoSheet(context, _c, pick: widget.pickPhoto);
      return;
    }
    if (l.contains('summary')) return _editAbout();
    if (l.contains('skills')) return _editSkills();
    _editIntro();
  }

  // --- the page ------------------------------------------------------------------------------------------------

  Future<void> _share() async {
    final me = _c.profile.value;
    if (me == null) return;
    final url = AppConfig.sitePage(me.publicPath).toString();
    await widget.share('${me.fullName} on ICR\n$url', '${me.fullName} on ICR');
  }

  Future<void> _addSection() async {
    final me = _c.profile.value;
    if (me == null) return;
    final choice = await showAccountPicker<String>(
      context,
      title: 'Add Profile Section',
      items: [
        if (me.hasResume) 'about',
        'experience',
        'education',
        'break',
        'credential',
        if (me.hasResume) 'skills',
        'languages',
      ],
      labelOf: (k) => switch (k) {
        'about' => 'About',
        'experience' => 'Experience',
        'education' => 'Education',
        'break' => 'Career Break',
        'credential' => 'Credential',
        'skills' => 'Skills',
        _ => 'Languages',
      },
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 'about':
        _editAbout();
      case 'experience':
        _editRole();
      case 'education':
        _editDegree();
      case 'break':
        _editBreak();
      case 'credential':
        _editCredential();
      case 'skills':
        _editSkills();
      default:
        _editLanguages();
    }
  }

  /// What the gear does when the lead wires nothing: this feature's own screen.
  void _openSettings() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => SettingsScreen(repository: widget.repository)));

  void _openPublic(MyProfile me) {
    final open = widget.onOpenPublicProfile;
    if (open != null) {
      open(me.id);
    } else {
      openSitePage(context, me.publicPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AccountBar(
        title: 'Profile',
        onBack: widget.onBack,
        actions: [
          IconButton(
            key: const Key('profile.share'),
            tooltip: 'Share Profile',
            onPressed: _share,
            icon: const Icon(Symbols.ios_share, size: 22, color: AppColors.onSurfaceVariant),
          ),
          IconButton(
            key: const Key('profile.settings'),
            tooltip: 'Settings',
            onPressed: widget.onOpenSettings ?? _openSettings,
            icon: const Icon(Symbols.settings, size: 23, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _c,
        builder: (context, _) {
          final me = _c.profile.value;
          if (me == null) {
            if (_c.profile.loading) return const AccountLoading();
            return AccountError(
              message: _c.profile.error ?? 'Try again in a moment.',
              onRetry: () => _c.retry(_c.profile),
            );
          }
          return RefreshIndicator(
            onRefresh: _c.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 28),
              children: [
                _header(me),
                if (me.completeness.score < 100) _completion(me),
                if (me.hasResume) _about(me),
                _experience(),
                _education(),
                _credentials(),
                if (me.hasResume) _skills(me),
                _languages(me),
                _publicCard(me),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- sections ------------------------------------------------------------------------------------------------

  Widget _header(MyProfile me) {
    final current = _c.experience.value?.where((r) => r.isCurrent).firstOrNull;
    final place = [if (me.hasResume) ?me.location, ?(current?.organisation ?? me.companyName)].join(' · ');
    final years = me.yearsExperience;
    return ProfileHeader(
      name: me.fullName,
      initials: me.initials,
      avatarUrl: me.avatarUrl,
      coverImage: me.coverImage,
      verified: emailConfirmed(context),
      roleLabel: roleLabel(me.role),
      headline: me.headline,
      place: place.isEmpty ? null : place,
      facts: [if (years != null) '$years ${years == 1 ? 'year' : 'years'} in the profession'],
      onEditCover: () => showCoverSheet(context, _c, pick: widget.pickPhoto),
      onEditPhoto: () => showPhotoSheet(context, _c, pick: widget.pickPhoto),
      onEditIntro: _editIntro,
      actions: [
        PillAction(
          key: const Key('profile.addSection'),
          label: 'Add Section',
          icon: Icons.add_rounded,
          onPressed: _addSection,
        ),
        PillAction(
          key: const Key('profile.viewPublic'),
          label: 'View Public Profile',
          icon: Symbols.visibility,
          onPressed: () => _openPublic(me),
        ),
      ],
    );
  }

  Widget _completion(MyProfile me) {
    final c = me.completeness;
    return AccountCard(
      key: const Key('profile.completion'),
      title: 'Profile Strength ${c.score}%',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: c.score / 100,
              minHeight: 8,
              backgroundColor: AppColors.slate100,
              color: c.score >= 80 ? AppColors.success : AppColors.primary,
            ),
          ),
          if (c.missing.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Finish Your Profile', style: AccountText.meta.copyWith(fontWeight: FontWeight.w600)),
            for (final item in c.missing)
              InkWell(
                key: Key('missing.$item'),
                onTap: () => _finish(item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      const Icon(Icons.radio_button_unchecked_rounded, size: 18, color: AppColors.slate400),
                      const SizedBox(width: 8),
                      Expanded(child: Text(completionTaskLabel(item), style: AccountText.body)),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.slate400),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _about(MyProfile me) {
    final summary = me.summary;
    return KeyedSubtree(
      key: _keys[ProfileSection.about],
      child: SectionCard(
        title: 'About',
        onEdit: summary == null ? null : _editAbout,
        editLabel: 'Edit About',
        child: summary == null
            ? AccountEmpty(
                text:
                    'You can write about your years of professional experience, industry or skills, achievements etc.',
                action: 'Add a Summary',
                onAction: _editAbout,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [ClampedText(summary), const PublicNote('Shown on your public profile.')],
              ),
      ),
    );
  }

  Widget _experience() {
    final s = _c.experience;
    final entries = _c.timeline;
    final full = (s.value?.length ?? 0) >= maxExperienceRows;
    final breaksFull = (_c.breaks.value?.length ?? 0) >= maxCareerBreakRows;
    return KeyedSubtree(
      key: _keys[ProfileSection.experience],
      child: SectionCard(
        title: 'Experience',
        loading: s.loading && !s.ready,
        onAdd: s.error != null || full ? null : _editRole,
        addLabel: 'Add Experience',
        extraAction: s.error != null || breaksFull
            ? null
            : CardIconButton(icon: Symbols.more_time, tooltip: 'Add a Career Break', onPressed: _editBreak),
        child: s.error != null && !s.ready
            ? SectionLoadError(what: 'experience', message: s.error!, onRetry: () => _c.retry(s))
            : entries.isEmpty
            ? AccountEmpty(
                text: 'Add your work experience including career break if applicable.',
                action: 'Add Experience',
                onAction: _editRole,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, e) in entries.indexed)
                    if (e.gap != null)
                      _GapRow(
                        gap: e.gap!,
                        onBreak: () => _editBreak(gap: e.gap),
                        onRole: _editRole,
                      )
                    else if (e.pause != null)
                      ItemRow(
                        key: Key('break.${e.pause!.id}'),
                        divider: i > 0 && entries[i - 1].gap == null,
                        editLabel: 'Edit Career Break',
                        onEdit: () => _editBreak(pause: e.pause),
                        child: CareerBreakTile(pause: e.pause!, now: widget.now),
                      )
                    else
                      ItemRow(
                        key: Key('role.${e.role!.id}'),
                        divider: i > 0 && entries[i - 1].gap == null,
                        editLabel: 'Edit ${e.role!.title} at ${e.role!.organisation}',
                        onEdit: () => _editRole(e.role),
                        child: ExperienceTile(role: e.role!, now: widget.now),
                      ),
                  if (full) Text('You have added the maximum number of roles.', style: AccountText.meta),
                ],
              ),
      ),
    );
  }

  Widget _education() {
    final s = _c.education;
    final rows = _c.educationOrdered;
    return KeyedSubtree(
      key: _keys[ProfileSection.education],
      child: SectionCard(
        title: 'Education',
        loading: s.loading && !s.ready,
        onAdd: s.error != null || rows.length >= maxEducationRows ? null : _editDegree,
        addLabel: 'Add Education',
        child: s.error != null && !s.ready
            ? SectionLoadError(what: 'education', message: s.error!, onRetry: () => _c.retry(s))
            : rows.isEmpty
            ? AccountEmpty(
                text: 'Your Education, field of study and year of passing.',
                action: 'Add Education',
                onAction: _editDegree,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, e) in rows.indexed)
                    ItemRow(
                      key: Key('degree.${e.id}'),
                      divider: i > 0,
                      editLabel: 'Edit ${e.institution}',
                      onEdit: () => _editDegree(e),
                      child: EducationTile(education: e),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _credentials() {
    final s = _c.credentials;
    final rows = s.value ?? const <Credential>[];
    return KeyedSubtree(
      key: _keys[ProfileSection.credentials],
      child: SectionCard(
        title: 'Licenses and Certifications',
        loading: s.loading && !s.ready,
        onAdd: s.error != null && !s.ready ? null : _editCredential,
        addLabel: 'Add Credential',
        child: s.error != null && !s.ready
            ? SectionLoadError(what: 'credentials', message: s.error!, onRetry: () => _c.retry(s))
            : rows.isEmpty
            ? AccountEmpty(
                text: 'Add your professional certifications and licenses.',
                action: 'Add Credential',
                onAction: _editCredential,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, c) in rows.indexed)
                    ItemRow(
                      key: Key('credential.${c.id}'),
                      divider: i > 0,
                      editLabel: 'Edit ${c.name}',
                      onEdit: c.editable ? () => _editCredential(c) : null,
                      onTap: c.editable || (c.href == null && widget.onOpenCertificate == null)
                          ? null
                          : () => _openCredential(c),
                      child: CredentialTile(credential: c),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _skills(MyProfile me) {
    return KeyedSubtree(
      key: _keys[ProfileSection.skills],
      child: SectionCard(
        title: 'Skills',
        onEdit: me.skills.isEmpty ? null : _editSkills,
        editLabel: 'Edit Skills',
        child: me.skills.isEmpty
            ? AccountEmpty(
                text: 'Add the skills you want to be found for.',
                action: 'Add Skills',
                onAction: _editSkills,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [ChipWrap(me.skills), const PublicNote('Shown on your public profile.')],
              ),
      ),
    );
  }

  Widget _languages(MyProfile me) {
    return KeyedSubtree(
      key: _keys[ProfileSection.languages],
      child: SectionCard(
        title: 'Languages',
        onEdit: me.languages.isEmpty ? null : _editLanguages,
        editLabel: 'Edit Languages',
        child: me.languages.isEmpty
            ? AccountEmpty(text: 'Add the languages you speak.', action: 'Add Languages', onAction: _editLanguages)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [ChipWrap(me.languages), const PublicNote('Shown on your public profile.')],
              ),
      ),
    );
  }

  Widget _publicCard(MyProfile me) {
    final link = AppConfig.sitePage(me.publicPath).toString();
    return AccountCard(
      title: 'Your Public Profile',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            link.replaceFirst(RegExp(r'^https?://'), ''),
            style: AccountText.body.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: 4),
          Text('This is the address people can open without signing in.', style: AccountText.meta),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AccountButton(
                  key: const Key('profile.copyLink'),
                  label: 'Copy Link',
                  icon: Icons.copy_rounded,
                  outlined: true,
                  onPressed: () => copyWithNotice(context, link, 'Link copied.'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AccountButton(
                  key: const Key('profile.openPublic'),
                  label: 'View',
                  icon: Symbols.visibility,
                  onPressed: () => _openPublic(me),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A stretch no role or break covers, in its place on the timeline, with a way
/// to account for it. Only the person sees it.
class _GapRow extends StatelessWidget {
  const _GapRow({required this.gap, required this.onBreak, required this.onRole});

  final CareerGap gap;
  final VoidCallback onBreak;
  final VoidCallback onRole;

  @override
  Widget build(BuildContext context) {
    final range = gap.ongoing
        ? '${careerDate(gap.fromYear, gap.fromMonth)} — Present'
        : '${careerDate(gap.fromYear, gap.fromMonth)} — ${careerDate(gap.toYear, gap.toMonth)}';
    return Container(
      key: const Key('career.gap'),
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              style: AccountText.body.copyWith(fontWeight: FontWeight.w700, color: AppColors.slate900),
              children: [
                TextSpan(text: 'A gap of ${careerDuration(gap.months)}'),
                TextSpan(
                  text: ' · $range',
                  style: AccountText.body.copyWith(fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text('Only you see this.', style: AccountText.meta.copyWith(fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              PillAction(key: const Key('gap.addBreak'), label: 'Add a Career Break', onPressed: onBreak),
              PillAction(key: const Key('gap.addRole'), label: 'Add a Role', onPressed: onRole),
            ],
          ),
        ],
      ),
    );
  }
}
