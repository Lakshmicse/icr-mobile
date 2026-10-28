import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/util/links.dart';
import '../../../core/util/time_ago.dart';
import '../account_labels.dart';
import '../account_models.dart';
import '../account_repository.dart';
import '../account_rules.dart' show displayLink;
import '../api_account_repository.dart';
import '../demo_account_repository.dart';
import '../profile/my_profile_screen.dart' show ShareText, shareWithPhone;
import '../profile/profile_kit.dart';
import '../widgets/account_kit.dart';
import 'member_profile_controller.dart';

/// Another member's public page (`/members/<id or slug>`): their cover and
/// photo, headline and place, who follows them, and what they chose to show:
/// About, Experience, Education, Credentials, Skills, Languages, links, the
/// chapters and councils they are in, and their community activity.
///
/// What the lead wires (each falls back to the website's page when left out):
///
/// * [onMessage]: opens the conversation by id (`POST /messaging/conversations`
///   reuses the plain thread, so it is the same one each time);
/// * [onOpenMentor]: the mentor profile (`mentorProfileId`), for a member who mentors;
/// * [onOpenCompany], [onOpenChapter], [onOpenCouncil], [onOpenThread]: a linked company
///   page, a chapter or council (by slug), a discussion (by slug);
/// * [onEditProfile]: on the person's own page, "Edit profile" (`MyProfileScreen`).
class MemberProfileScreen extends StatefulWidget {
  const MemberProfileScreen({
    super.key,
    required this.userId,
    this.repository,
    this.onBack,
    this.onMessage,
    this.onOpenMentor,
    this.onOpenCompany,
    this.onOpenChapter,
    this.onOpenCouncil,
    this.onOpenThread,
    this.onEditProfile,
    this.opener = openUrl,
    this.share = shareWithPhone,
    this.now,
  });

  /// The member's id or profile slug.
  final String userId;

  /// Instead of the API (tests, demo mode).
  final AccountRepository? repository;
  final VoidCallback? onBack;

  /// The conversation to open, by its id.
  final void Function(String conversationId, MemberProfile member)? onMessage;

  /// The mentor profile id.
  final void Function(String mentorProfileId)? onOpenMentor;
  final void Function(String companyId)? onOpenCompany;
  final void Function(String slug)? onOpenChapter;
  final void Function(String slug)? onOpenCouncil;
  final void Function(String slug)? onOpenThread;
  final VoidCallback? onEditProfile;

  /// Hands a link (a member's own LinkedIn) to the phone.
  final Future<void> Function(BuildContext context, Uri uri) opener;
  final ShareText share;
  final DateTime? now;

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> {
  late final MemberProfileController _c;

  @override
  void initState() {
    super.initState();
    final repo = widget.repository ?? (AppConfig.demo ? DemoAccountRepository() : ApiAccountRepository(api: context.read<ApiClient>()));
    _c = MemberProfileController(repo, widget.userId)..load();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _site(String path) => openSitePage(context, path);

  Future<void> _message(MemberProfile m) async {
    final id = await _c.openConversation();
    if (id == null || !mounted) return;
    final open = widget.onMessage;
    if (open != null) {
      open(id, m);
    } else {
      _site('/messaging');
    }
  }

  Future<void> _share(MemberProfile m) =>
      widget.share('${m.fullName} on ICR\n${AppConfig.sitePage(m.sitePath)}', '${m.fullName} on ICR');

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final m = _c.member;
        return Scaffold(
          backgroundColor: AppColors.slate50,
          appBar: AccountBar(
            title: m?.fullName ?? 'Member',
            onBack: widget.onBack,
            actions: [
              if (m != null)
                IconButton(
                  key: const Key('member.share'),
                  tooltip: 'Share profile',
                  onPressed: () => _share(m),
                  icon: const Icon(Symbols.ios_share, size: 22, color: AppColors.onSurfaceVariant),
                ),
            ],
          ),
          body: _body(m),
        );
      },
    );
  }

  Widget _body(MemberProfile? m) {
    if (m == null) {
      if (_c.loading) return const AccountLoading();
      final gone = _c.loadStatus == 404;
      return AccountError(
        title: gone ? 'This profile is not available' : 'Something went wrong',
        message: gone ? 'It may be private, or the member may have left ICR.' : (_c.loadError ?? 'Try again in a moment.'),
        onRetry: _c.load,
      );
    }
    return RefreshIndicator(
      onRefresh: () => _c.load(refresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          if (_c.actionError != null) _ErrorBanner(message: _c.actionError!, onClose: _c.dismissError),
          _header(m),
          if (m.isOwner) _ownerNote(),
          if (m.about != null)
            AccountCard(
              title: 'About',
              child: ClampedText(m.about!),
            ),
          if (m.experience.isNotEmpty) _experience(m),
          if (m.education.isNotEmpty) _education(m),
          if (m.credentials.isNotEmpty) _credentials(m),
          if (m.skills.isNotEmpty) AccountCard(title: 'Skills', child: ChipWrap(m.skills)),
          if (m.languages.isNotEmpty) AccountCard(title: 'Languages', child: ChipWrap(m.languages)),
          if (m.links.present.isNotEmpty) _links(m),
          if (m.chapters.isNotEmpty || m.councils.isNotEmpty) _groups(m),
          _activity(m),
        ],
      ),
    );
  }

  Widget _header(MemberProfile m) {
    final place = [?m.city, ?m.companyName].join(' · ');
    final since = monthYear(m.memberSince);
    return ProfileHeader(
      name: m.fullName,
      initials: m.initials,
      avatarUrl: m.avatarUrl,
      coverImage: m.coverImage,
      headline: m.headline,
      place: place.isEmpty ? null : place,
      facts: [
        '${_count(m.follow.followers)} ${m.follow.followers == 1 ? 'follower' : 'followers'}',
        '${_count(m.follow.following)} following',
        if (since.isNotEmpty) 'Member since $since',
      ],
      chips: [
        if (m.mentorProfileId != null) const AccountChip(label: 'Mentor', color: Color(0xFFE7EEFF), ink: AppColors.primary, icon: Symbols.school),
        if (m.readyForNextRole) const AccountChip(label: 'Ready for a new role', color: Color(0xFFECFDF5), ink: Color(0xFF047857)),
        if (m.yearsExperience != null) AccountChip(label: '${m.yearsExperience} yrs experience'),
      ],
      actions: m.isOwner
          ? [
              if (widget.onEditProfile != null)
                PillAction(key: const Key('member.edit'), label: 'Edit profile', icon: Symbols.edit, filled: true, onPressed: widget.onEditProfile),
            ]
          : [
              PillAction(
                key: const Key('member.follow'),
                label: m.follow.viewerFollows ? 'Following' : 'Follow',
                icon: m.follow.viewerFollows ? Icons.check_rounded : Icons.add_rounded,
                filled: !m.follow.viewerFollows,
                busy: _c.following,
                onPressed: _c.toggleFollow,
              ),
              PillAction(
                key: const Key('member.message'),
                label: 'Message',
                icon: Symbols.chat_bubble,
                busy: _c.messaging,
                onPressed: () => _message(m),
              ),
              if (m.mentorProfileId != null)
                PillAction(
                  key: const Key('member.mentor'),
                  label: 'Mentor profile',
                  icon: Symbols.school,
                  onPressed: () {
                    final open = widget.onOpenMentor;
                    if (open != null) {
                      open(m.mentorProfileId!);
                    } else {
                      _site('/mentorship/mentors/${m.mentorProfileId}');
                    }
                  },
                ),
            ],
    );
  }

  static String _count(int n) => n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (g) => '${g[1]},');

  Widget _ownerNote() => Container(
    key: const Key('member.ownerNote'),
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFE7EEFF),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        const Icon(Symbols.visibility, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(child: Text('This is how other members see your profile.', style: AccountText.body.copyWith(color: AppColors.primary))),
      ],
    ),
  );

  Widget _experience(MemberProfile m) {
    final rows = m.experience;
    return AccountCard(
      title: 'Experience',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, r) in rows.indexed)
            ItemRow(
              key: Key('exp.${r.id}'),
              divider: i > 0,
              onTap: r.company == null
                  ? null
                  : () {
                      final open = widget.onOpenCompany;
                      if (open != null) {
                        open(r.company!.id);
                      } else {
                        _site('/companies/${r.company!.id}');
                      }
                    },
              child: ExperienceTile(role: r, now: widget.now),
            ),
        ],
      ),
    );
  }

  Widget _education(MemberProfile m) => AccountCard(
    title: 'Education',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, e) in m.education.indexed) ItemRow(divider: i > 0, child: EducationTile(education: e)),
      ],
    ),
  );

  Widget _credentials(MemberProfile m) => AccountCard(
    title: 'Licenses & certifications',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, c) in m.credentials.indexed)
          ItemRow(
            key: Key('cred.$i'),
            divider: i > 0,
            onTap: c.url == null ? null : () => widget.opener(context, Uri.parse(c.url!)),
            child: _PublicCredential(credential: c),
          ),
      ],
    ),
  );

  Widget _links(MemberProfile m) => AccountCard(
    title: 'Links',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, e) in m.links.present.entries.indexed)
          InkWell(
            key: Key('link.${e.key}'),
            onTap: () {
              final uri = Uri.tryParse(e.value);
              if (uri != null) widget.opener(context, uri);
            },
            child: Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 12, bottom: 2),
              child: Row(
                children: [
                  const Icon(Symbols.link, size: 18, color: AppColors.slate500),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ProfileLinks.labels[e.key] ?? 'Link', style: AccountText.label),
                        Text(displayLink(e.value), style: AccountText.body.copyWith(color: AppColors.primary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  Widget _groups(MemberProfile m) {
    void openGroup(MemberGroup g, {required bool chapter}) {
      final open = chapter ? widget.onOpenChapter : widget.onOpenCouncil;
      if (open != null) {
        open(g.slug);
      } else {
        _site(chapter ? '/chapters/${g.slug}' : '/councils/${g.slug}');
      }
    }

    return AccountCard(
      title: 'Chapters & councils',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, g) in m.chapters.indexed)
            ItemRow(
              key: Key('chapter.${g.slug}'),
              divider: i > 0,
              onTap: () => openGroup(g, chapter: true),
              leading: const Icon(Symbols.location_city, color: AppColors.slate500),
              child: Text(g.name, style: AccountText.itemTitle),
            ),
          for (final (i, g) in m.councils.indexed)
            ItemRow(
              key: Key('council.${g.slug}'),
              divider: i > 0 || m.chapters.isNotEmpty,
              onTap: () => openGroup(g, chapter: false),
              leading: const Icon(Symbols.groups, color: AppColors.slate500),
              child: Text(g.name, style: AccountText.itemTitle),
            ),
        ],
      ),
    );
  }

  Widget _activity(MemberProfile m) {
    if (m.threads == 0 && m.replies == 0 && _c.posts.isEmpty) return const SizedBox.shrink();
    return AccountCard(
      title: 'Community activity',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _stat('${m.reputation}', 'Reputation'),
              _stat('${m.threads}', 'Discussions'),
              _stat('${m.replies}', 'Replies'),
              _stat('${m.acceptedAnswers}', 'Answers'),
            ],
          ),
          if (_c.posts.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final p in _c.posts)
              ItemRow(
                key: Key('post.${p.id}'),
                divider: true,
                onTap: () {
                  final open = widget.onOpenThread;
                  if (open != null) {
                    open(p.slug);
                  } else {
                    _site('/community/${p.slug}');
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.title, style: AccountText.itemTitle),
                    const SizedBox(height: 2),
                    Text(
                      [
                        ?p.category,
                        '${p.replyCount} ${p.replyCount == 1 ? 'reply' : 'replies'}',
                        if (p.createdAt != null && DateTime.tryParse(p.createdAt!) != null) timeAgo(DateTime.parse(p.createdAt!), now: widget.now),
                      ].join(' · '),
                      style: AccountText.meta,
                    ),
                  ],
                ),
              ),
          ] else if (_c.postsFailed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text("Couldn't load their discussions.", style: AccountText.meta),
            ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) => Expanded(
    child: Column(
      children: [
        Text(value, style: AccountText.cardTitle),
        Text(label, style: AccountText.meta.copyWith(fontSize: 13)),
      ],
    ),
  );
}

class _PublicCredential extends StatelessWidget {
  const _PublicCredential({required this.credential});

  final PublicCredential credential;

  @override
  Widget build(BuildContext context) {
    final c = credential;
    final issued = monthYear(c.issuedAt);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: c.verified ? AppColors.emerald50 : AppColors.slate50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.verified ? AppColors.emerald200 : AppColors.slate200),
          ),
          child: Icon(Symbols.workspace_premium, size: 23, color: c.verified ? AppColors.emerald700 : AppColors.slate500),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.code == null ? c.name : '${c.name} (${c.code})', style: AccountText.itemTitle),
              if (c.issuer != null) Text(c.issuer!, style: AccountText.body.copyWith(fontWeight: FontWeight.w500)),
              if (issued.isNotEmpty) Text('Issued $issued', style: AccountText.meta),
              if (c.verified) ...[
                const SizedBox(height: 6),
                const AccountChip(label: 'Verified', color: Color(0xFFECFDF5), ink: Color(0xFF047857), icon: Symbols.verified),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('member.error'),
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(message, style: AccountText.error.copyWith(fontSize: 14))),
          IconButton(tooltip: 'Dismiss', onPressed: onClose, icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.slate500)),
        ],
      ),
    );
  }
}
