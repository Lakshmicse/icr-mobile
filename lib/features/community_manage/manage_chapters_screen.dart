import 'package:flutter/material.dart';

import '../../core/api/api_error.dart';
import '../../core/util/links.dart' show showMessage;
import '../shell/app_shell.dart';
import 'community_manage_controllers.dart';
import 'community_manage_kit.dart';
import 'community_manage_models.dart';
import 'community_manage_repository.dart';
import 'content_sheets.dart';
import 'manage_chapter_screen.dart';
import 'org_list_parts.dart';
import 'org_sheets.dart';

/// Manage Chapters — the website's `/admin/community` for staff holding `chapters:manage` (Chapters Admin,
/// Community Manager, Super Admin): the **Chapters** tab is every chapter, unpublished included, searched by name
/// or city and paged by twenty, each row opening the chapter's manage page; **Applications** is members asking to
/// start a chapter or to lead one, approved (a note optional) or declined (the reason required). "New Chapter"
/// is drawn only when the key is held [everywhere]: the API lets a role over some chapters create none.
class ManageChaptersScreen extends StatefulWidget {
  const ManageChaptersScreen({
    super.key,
    required this.repository,
    required this.everywhere,
    required this.onBack,
    this.onBell,
    this.unread = 0,
    this.initialSearch,
    this.initialTab,
    this.focusApplicationId,
    this.pageWrap,
    this.pickers = const ManagePickers(),
    this.searchDelay = const Duration(milliseconds: 350),
  });

  final CommunityManageRepository repository;
  final bool everywhere;
  final VoidCallback onBack;
  final VoidCallback? onBell;
  final int unread;

  /// Prefills the list's search (the website's `?search=`).
  final String? initialSearch;

  /// `'applications'` opens on that tab (the website's `?tab=applications`).
  final String? initialTab;

  /// An application a notification named (`?application=<id>`): tinted and scrolled to.
  final String? focusApplicationId;

  /// Puts each page this screen pushes into the app's frame (the bottom bar under it).
  final Widget Function(Widget page)? pageWrap;
  final ManagePickers pickers;
  final Duration searchDelay;

  @override
  State<ManageChaptersScreen> createState() => _ManageChaptersScreenState();
}

class _ManageChaptersScreenState extends State<ManageChaptersScreen> {
  late final _searchText = TextEditingController(text: widget.initialSearch ?? '');
  late final OrgListController<AdminChapter> _list = OrgListController<AdminChapter>(
    fetch: (page, search) => widget.repository.chapters(page: page, search: search),
    initialSearch: widget.initialSearch ?? '',
    searchDelay: widget.searchDelay,
  );
  late final RequestsController<ChapterApplication> _requests = RequestsController<ChapterApplication>(
    fetch: (status, page) => widget.repository.chapterApplications(status: status, page: page),
    decide: (id, decision, reason) =>
        widget.repository.decide(OrgKind.chapter, id, decision: decision, reason: reason),
  );
  late int _tab = widget.initialTab == 'applications' || widget.focusApplicationId != null ? 1 : 0;

  @override
  void initState() {
    super.initState();
    _list.start();
    if (_tab == 1) _requests.start();
  }

  @override
  void dispose() {
    _searchText.dispose();
    _list.dispose();
    _requests.dispose();
    super.dispose();
  }

  void _showTab(int tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    if (tab == 1 && !_requests.started) _requests.start(announce: true);
  }

  Future<void> _new() async {
    final created = await showChapterSheet(
      context,
      repository: widget.repository,
      pickers: widget.pickers,
      searchDelay: widget.searchDelay,
      onSubmit: (draft) async {
        try {
          await widget.repository.createChapter(draft.body());
          return null;
        } catch (e) {
          return ApiError.from(e).message;
        }
      },
    );
    if (!created || !mounted) return;
    showMessage(context, 'Chapter created.');
    await _list.refresh();
  }

  Future<void> _open(AdminChapter chapter) async {
    final wrap = widget.pageWrap ?? (Widget page) => page;
    await AppShell.push<void>(
      context,
      (page) => wrap(
        ManageChapterScreen(
          repository: widget.repository,
          chapterId: chapter.id,
          initial: chapter,
          everywhere: widget.everywhere,
          onBack: () => Navigator.of(page).maybePop(),
          onBell: widget.onBell,
          unread: widget.unread,
          pageWrap: widget.pageWrap,
          pickers: widget.pickers,
          searchDelay: widget.searchDelay,
        ),
      ),
    );
    // Whatever was edited or retired there shows here.
    if (mounted) await _list.refresh();
  }

  Future<void> _decide(RequestView request, {required bool declining}) async {
    final decided = await showDecideSheet(
      context,
      kind: OrgKind.chapter,
      title: request.title,
      declining: declining,
      onSubmit: (reason) => _requests.decide(
        request.id,
        decision: declining ? RequestStatus.declined : RequestStatus.approved,
        reason: reason,
      ),
    );
    if (!decided || !mounted) return;
    showMessage(context, declining ? 'Application declined.' : 'Application approved.');
    // An approval may have set up a new chapter.
    if (!declining) await _list.refresh();
  }

  /// An approval's "Find It": the Chapters tab, searched by the chapter's name.
  void _find(String name) {
    _searchText.text = name;
    setState(() => _tab = 0);
    _list.searchNow(name);
  }

  @override
  Widget build(BuildContext context) {
    return ManageFrame(
      title: 'Manage Chapters',
      onBack: widget.onBack,
      onBell: widget.onBell,
      unread: widget.unread,
      tabs: const ['Chapters', 'Applications'],
      tab: _tab,
      onTab: _showTab,
      child: _tab == 0
          ? OrgListTab<AdminChapter>(
              key: const ValueKey('chapters-tab'),
              controller: _list,
              searchText: _searchText,
              searchHint: 'Search chapters by name or city',
              emptyTitle: 'No Chapters',
              newLabel: widget.everywhere ? 'New Chapter' : null,
              onNew: widget.everywhere ? _new : null,
              rowBuilder: (c) => OrgRow(
                key: ValueKey('chapter-row-${c.id}'),
                title: c.name,
                subtitle: [c.scopeLabel, c.place].where((v) => v.isNotEmpty).join(' · '),
                meta: _sizeLine(c.memberCount, c.upcomingEventCount),
                published: c.published,
                onTap: () => _open(c),
              ),
            )
          : RequestsTab<ChapterApplication>(
              key: const ValueKey('applications-tab'),
              controller: _requests,
              viewOf: RequestView.ofApplication,
              emptyTitle: 'No Chapter Applications',
              focusId: widget.focusApplicationId,
              onDecide: _decide,
              onFind: _find,
            ),
    );
  }
}

String _sizeLine(int members, int events) =>
    '$members ${members == 1 ? 'member' : 'members'} · $events upcoming ${events == 1 ? 'event' : 'events'}';
