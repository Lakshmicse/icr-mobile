import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart' show showMessage;
import '../../core/widgets/title_bar.dart';
import '../account/widgets/account_kit.dart' show confirmAction;
import '../notifications/notifications_screen.dart';
import '../workspaces/page_kit.dart';
import 'community_manage_controllers.dart';
import 'community_manage_kit.dart';
import 'community_manage_models.dart';
import 'community_manage_repository.dart';
import 'community_manage_rules.dart';
import 'content_sheets.dart';
import 'org_sheets.dart';

/// One chapter's or council's manage page — what the website splits between a row's Edit dialog, its "Manage
/// content" drawer and its Retire button: the details with Edit, then Sponsors (a chapter's), Resources, Updates,
/// Leadership and Members, each with its add and its remove, and Retire at the foot for a role that holds the key
/// everywhere. `ManageChapterScreen` and `ManageCouncilScreen` are this page for their kind.
class OrgRecordPage extends StatefulWidget {
  const OrgRecordPage({
    super.key,
    required this.repository,
    required this.kind,
    required this.id,
    required this.everywhere,
    required this.onBack,
    this.onBell,
    this.unread = 0,
    this.initialChapter,
    this.initialCouncil,
    this.pickers = const ManagePickers(),
    this.searchDelay = const Duration(milliseconds: 350),
    this.now = DateTime.now,
  });

  final CommunityManageRepository repository;
  final OrgKind kind;
  final String id;

  /// The reader holds the key over every record: Retire and (a chapter's) Add Leader need that.
  final bool everywhere;
  final VoidCallback onBack;
  final VoidCallback? onBell;
  final int unread;
  final AdminChapter? initialChapter;
  final AdminCouncil? initialCouncil;
  final ManagePickers pickers;
  final Duration searchDelay;
  final DateTime Function() now;

  @override
  State<OrgRecordPage> createState() => _OrgRecordPageState();
}

class _OrgRecordPageState extends State<OrgRecordPage> {
  late final OrgRecordController _c = OrgRecordController(
    widget.repository,
    kind: widget.kind,
    id: widget.id,
    chapter: widget.initialChapter,
    council: widget.initialCouncil,
  );

  bool get _isChapter => widget.kind == OrgKind.chapter;
  String get _noun => _isChapter ? 'Chapter' : 'Council';

  @override
  void initState() {
    super.initState();
    _c.start();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Says what a change answered: the API's refusal, or that it is done.
  void _tell(String? refusal, String done) {
    if (mounted) showMessage(context, refusal ?? done);
  }

  Future<void> _edit() async {
    final bool saved;
    if (_isChapter) {
      saved = await showChapterSheet(
        context,
        repository: widget.repository,
        chapter: _c.chapter,
        pickers: widget.pickers,
        searchDelay: widget.searchDelay,
        onSubmit: _c.saveChapter,
      );
    } else {
      saved = await showCouncilSheet(
        context,
        repository: widget.repository,
        council: _c.council,
        pickers: widget.pickers,
        onSubmit: _c.saveCouncil,
      );
    }
    if (saved && mounted) showMessage(context, '$_noun saved.');
  }

  Future<void> _retire() async {
    final ok = await confirmAction(
      context,
      title: 'Retire “${_c.name}”?',
      message: 'It disappears from the public directory.',
      confirm: 'Retire',
    );
    if (!ok || !mounted) return;
    final refusal = await _c.retire();
    if (!mounted) return;
    if (refusal != null) {
      showMessage(context, refusal);
      return;
    }
    showMessage(context, '$_noun retired.');
    widget.onBack();
  }

  Future<void> _remove(String what, String name, Future<String?> Function() remove) async {
    final ok = await confirmAction(
      context,
      title: 'Remove “$name”?',
      message: 'This $what is taken off the ${_noun.toLowerCase()}’s page.',
      confirm: 'Remove',
    );
    if (!ok || !mounted) return;
    _tell(await remove(), 'Removed.');
  }

  Future<void> _addSponsor() async {
    final added = await showSponsorSheet(
      context,
      repository: widget.repository,
      pickers: widget.pickers,
      onSubmit: _c.addSponsor,
    );
    if (added && mounted) showMessage(context, 'Sponsor added.');
  }

  Future<void> _addResource() async {
    final added = await showResourceSheet(context, onSubmit: _c.addResource);
    if (added && mounted) showMessage(context, 'Resource added.');
  }

  Future<void> _addAnnouncement() async {
    final added = await showAnnouncementSheet(context, onSubmit: _c.addAnnouncement);
    if (added && mounted) showMessage(context, 'Announcement posted.');
  }

  Future<void> _addLeader() async {
    final added = await showAddLeaderSheet(
      context,
      repository: widget.repository,
      chapterId: widget.id,
      existing: [for (final l in _c.content.leads) l.userId],
      searchDelay: widget.searchDelay,
      onSubmit: _c.addLead,
    );
    if (added && mounted) showMessage(context, 'Leader added.');
  }

  Future<void> _openLead(ContentLead lead) async {
    final result = await showLeadSheet(
      context,
      lead: lead,
      pickers: widget.pickers,
      onSave: (body) => _c.saveLead(lead.userId, body),
      onStepDown: () => _c.stepDown(lead.userId),
    );
    if (result == null || !mounted) return;
    showMessage(context, result == LeadSheetResult.saved ? 'Lead saved.' : '${lead.name} is now a member.');
  }

  Future<void> _makeLead() async {
    final made = await showMakeLeadSheet(
      context,
      members: _c.content.members,
      pickers: widget.pickers,
      now: widget.now,
      onSubmit: (userId, starts, ends) => _c.makeLead(userId, termStartsOn: starts, termEndsOn: ends),
    );
    if (made && mounted) showMessage(context, 'Lead added.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TitleBar(
              title: 'Manage $_noun',
              onBack: widget.onBack,
              unread: widget.unread,
              onBell: widget.onBell ?? () => openNotifications(context),
            ),
            Expanded(
              child: ListenableBuilder(listenable: _c, builder: (context, _) => _body()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final c = _c;
    if (!c.hasRecord) {
      // Nothing to draw yet: still reading, refused, or not a record this reader's list holds.
      return WsScroll(
        onRefresh: c.refresh,
        loading: c.loading,
        error: c.error ?? (c.loaded ? '$_noun not found' : null),
        children: const [],
      );
    }
    return WsScroll(
      key: const ValueKey('record-page'),
      onRefresh: c.refresh,
      children: [
        _isChapter ? _chapterDetails(c.chapter!) : _councilDetails(c.council!),
        if (!c.loaded && c.error != null)
          WsSection(
            children: [ManageState.message(c.error!, key: const ValueKey('record-error'), onRetry: c.refresh)],
          )
        else if (!c.loaded)
          const WsSection(children: [ManageState.loading()])
        else ...[
          if (_isChapter) _sponsors(),
          _resources(),
          _updates(),
          _leadership(),
          _members(),
        ],
        if (widget.everywhere) _retireSection(),
      ],
    );
  }

  // --- details -------------------------------------------------------------------------------------------------------

  Widget _details({required String name, required bool published, required String line, required List<Widget> facts}) {
    return WsSection(
      key: const ValueKey('record-details'),
      title: name,
      trailing: WsLink(key: const ValueKey('record-edit'), label: 'Edit', onTap: _edit),
      children: [
        Row(
          children: [
            PublishPill(key: const ValueKey('record-published'), published: published),
            const SizedBox(width: 8),
            Expanded(
              child: Text(line, style: WsText.body, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        const SizedBox(height: 4),
        WsRows(children: facts),
      ],
    );
  }

  /// The About's headings that hold something, for the details' one line about it.
  String _aboutLine(String? html, List<AboutSection> sections) {
    final parsed = parseAbout(html, sections);
    return [
      for (final s in sections)
        if ((parsed.values[s.key] ?? '').isNotEmpty) s.heading,
      if (parsed.extra.isNotEmpty) 'Earlier text',
    ].join(', ');
  }

  String _picturesLine({required bool cover, bool logo = false, required int gallery}) => [
    if (cover) _isChapter ? 'Banner' : 'Cover',
    if (logo) 'Chapter picture',
    if (gallery > 0) '$gallery gallery ${gallery == 1 ? 'image' : 'images'}',
  ].join(', ');

  String _sizeLine(int members, int events) =>
      '$members ${members == 1 ? 'member' : 'members'} · $events upcoming ${events == 1 ? 'event' : 'events'}';

  Widget _chapterDetails(AdminChapter c) {
    final about = _aboutLine(c.aboutHtml, chapterAboutSections);
    final pictures = _picturesLine(cover: c.coverUrl != null, logo: c.logoUrl != null, gallery: c.galleryUrls.length);
    return _details(
      name: c.name,
      published: c.published,
      line: [c.scopeLabel, c.place].where((v) => v.isNotEmpty).join(' · '),
      facts: [
        ManageFact(label: 'Members and Events', value: _sizeLine(c.memberCount, c.upcomingEventCount)),
        if (c.foundedYear != null) ManageFact(label: 'Founded Year', value: '${c.foundedYear}'),
        if (c.contactEmail != null) ManageFact(label: 'Contact Email', value: c.contactEmail!),
        if (c.description != null) ManageFact(label: 'Short Description', value: c.description!),
        if (about.isNotEmpty) ManageFact(label: 'About', value: about),
        if (pictures.isNotEmpty) ManageFact(label: 'Pictures', value: pictures),
      ],
    );
  }

  Widget _councilDetails(AdminCouncil c) {
    final about = _aboutLine(c.aboutHtml, councilAboutSections);
    final pictures = _picturesLine(cover: c.coverUrl != null, gallery: c.galleryUrls.length);
    return _details(
      name: c.name,
      published: c.published,
      line: c.segments.isNotEmpty ? c.segments.join(' · ') : (c.focus ?? ''),
      facts: [
        ManageFact(label: 'Members and Events', value: _sizeLine(c.memberCount, c.upcomingEventCount)),
        if (c.focus != null) ManageFact(label: 'Focus Line', value: c.focus!),
        if (c.slug.isNotEmpty) ManageFact(label: 'Slug', value: c.slug),
        if (c.contactEmail != null) ManageFact(label: 'Contact Email', value: c.contactEmail!),
        if (c.description != null) ManageFact(label: 'Description', value: c.description!),
        if (about.isNotEmpty) ManageFact(label: 'About', value: about),
        if (pictures.isNotEmpty) ManageFact(label: 'Pictures', value: pictures),
      ],
    );
  }

  // --- content -------------------------------------------------------------------------------------------------------

  Widget _empty(String text, {Key? key}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(text, key: key, style: WsText.body),
  );

  Widget _bin(String key, VoidCallback onPressed) => ManageRowAction(
    key: ValueKey(key),
    icon: LucideIcons.trash2,
    label: 'Remove',
    color: AppColors.rose600,
    onPressed: onPressed,
  );

  Widget _sponsors() {
    final rows = _c.content.sponsors;
    return WsSection(
      key: const ValueKey('section-sponsors'),
      title: 'Sponsors',
      note: rows.isEmpty ? null : '${rows.length}',
      trailing: WsLink(key: const ValueKey('sponsor-add'), label: 'Add Sponsor', onTap: _addSponsor),
      children: [
        if (rows.isEmpty)
          _empty('No sponsors yet.')
        else
          WsRows(
            children: [
              for (final s in rows)
                WsRow(
                  key: ValueKey('sponsor-${s.id}'),
                  title: s.name,
                  subtitle: s.tier,
                  meta: s.url,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  trailing: _bin(
                    'sponsor-remove-${s.id}',
                    () => _remove('sponsor', s.name, () => _c.removeSponsor(s.id)),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _resources() {
    final rows = _c.content.resources;
    return WsSection(
      key: const ValueKey('section-resources'),
      title: 'Resources',
      note: rows.isEmpty ? null : '${rows.length}',
      trailing: WsLink(key: const ValueKey('resource-add'), label: 'Add Resource', onTap: _addResource),
      children: [
        if (rows.isEmpty)
          _empty('No resources yet.')
        else
          WsRows(
            children: [
              for (final r in rows)
                WsRow(
                  key: ValueKey('resource-${r.id}'),
                  title: r.title,
                  subtitle: [resourceKindLabel(r.kind), if (r.sizeLabel != null) r.sizeLabel!].join(' · '),
                  meta: r.url,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  trailing: _bin(
                    'resource-remove-${r.id}',
                    () => _remove('resource', r.title, () => _c.removeResource(r.id)),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _updates() {
    final rows = _c.content.announcements;
    return WsSection(
      key: const ValueKey('section-updates'),
      title: 'Updates',
      note: rows.isEmpty ? null : '${rows.length}',
      trailing: WsLink(key: const ValueKey('announcement-add'), label: 'Post Announcement', onTap: _addAnnouncement),
      children: [
        if (rows.isEmpty)
          _empty('No updates yet.')
        else
          WsRows(
            children: [
              for (final a in rows)
                WsRow(
                  key: ValueKey('announcement-${a.id}'),
                  title: a.title,
                  subtitle: a.body,
                  below: a.pinned
                      ? const Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: WsChip('Pinned', tone: WsTone.brand, icon: LucideIcons.pin),
                        )
                      : null,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  trailing: _bin(
                    'announcement-remove-${a.id}',
                    () => _remove('update', a.title, () => _c.removeAnnouncement(a.id)),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  String _term(ContentLead l) {
    final start = dayLabel(l.termStartsOn);
    final end = dayLabel(l.termEndsOn);
    if (start.isEmpty && end.isEmpty) return 'Open term';
    if (start.isEmpty) return 'Term ends $end';
    return 'Term: $start – ${end.isEmpty ? 'open' : end}';
  }

  Widget _leadership() {
    final leads = _c.content.leads;
    final today = isoDay(widget.now());
    // Finding anyone on ICR and making them a lead is a chapter's, and the API keeps it to a role held everywhere.
    final canAddLeader = _isChapter && widget.everywhere;
    return WsSection(
      key: const ValueKey('section-leadership'),
      title: 'Leadership',
      note: leads.isEmpty ? null : '${leads.length}',
      trailing: canAddLeader
          ? WsLink(key: const ValueKey('leader-add'), label: 'Add Leader', onTap: _addLeader)
          : null,
      children: [
        if (leads.isEmpty)
          _empty('No leads yet. Make a member a lead below.', key: const ValueKey('leads-empty'))
        else
          WsRows(
            children: [
              for (final l in leads)
                WsRow(
                  key: ValueKey('lead-${l.userId}'),
                  title: l.name,
                  subtitle: l.title,
                  meta: _term(l),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (leadTermEnded(l.termEndsOn, today)) const WsChip('Term ended', tone: WsTone.warn),
                      const SizedBox(width: 4),
                      const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.outline),
                    ],
                  ),
                  onTap: () => _openLead(l),
                ),
            ],
          ),
      ],
    );
  }

  Widget _members() {
    final members = _c.content.members;
    return WsSection(
      key: const ValueKey('section-members'),
      title: 'Members',
      note: members.isEmpty ? null : '${members.length}',
      trailing: members.isEmpty
          ? null
          : WsLink(key: const ValueKey('member-make-lead'), label: 'Make Lead', onTap: _makeLead),
      children: [
        _empty(
          members.isEmpty
              ? 'No members to choose from yet.'
              : 'Make a member a lead: choose who, and the term they serve.',
          key: const ValueKey('members-note'),
        ),
      ],
    );
  }

  Widget _retireSection() {
    return WsSection(
      key: const ValueKey('section-retire'),
      children: [
        Text(
          'Retiring takes the ${_noun.toLowerCase()} out of the public directory. Its members and history are kept.',
          style: WsText.body,
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const ValueKey('record-retire'),
            onPressed: _retire,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.rose600,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('Retire $_noun', style: WsText.link.copyWith(color: AppColors.rose600)),
          ),
        ),
      ],
    );
  }
}
