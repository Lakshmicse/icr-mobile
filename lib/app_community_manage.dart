import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api/api_client.dart';
import 'core/auth/session_user.dart';
import 'core/config.dart';
import 'core/widgets/manage_pencil.dart';
import 'features/account/widgets/account_session.dart' show maybeAuth;
import 'features/community_manage/community_manage_repository.dart';
import 'features/community_manage/manage_chapter_screen.dart';
import 'features/community_manage/manage_chapters_screen.dart';
import 'features/community_manage/manage_council_screen.dart';
import 'features/community_manage/manage_councils_screen.dart';
import 'features/events_manage/events_manage_repository.dart';
import 'features/events_manage/manage_event_screen.dart';
import 'features/events_manage/manage_events_screen.dart';
import 'features/notifications/notifications_bell.dart' show bellUnread;
import 'features/notifications/notifications_screen.dart' show openNotifications;
import 'features/shell/app_shell.dart';
import 'features/shell/icr_bottom_nav.dart' show AppTab;
import 'features/shell/shell_page.dart';

/// Managing Chapters, Councils and Events from the app.
///
/// Who may, as on the website (`/admin/community`): the staff holding `chapters:manage`, `councils:manage` or
/// `events:manage` — a Super Admin, or anyone a Super Admin gave the Chapters Admin, Councils Admin, Events Admin
/// or Community Manager role on the website's Roles page. For them the Chapters, Councils and Events pages carry a
/// pencil left of the bell: on a board it opens that section's manage page, on one chapter's or council's page
/// that record's.

const chaptersManageKey = 'chapters:manage';
const councilsManageKey = 'councils:manage';
const eventsManageKey = 'events:manage';

/// The frame every Chapters, Councils and Events page stands in: the bottom bar under it, as Home's.
Widget communityFrame(Widget page) => ShellPage(tab: AppTab.home, child: page);

SessionUser? _user(BuildContext ctx) => maybeAuth(ctx)?.user;

/// The bundled sample content has nothing to manage: its chapters are not the API's.
bool _holds(BuildContext ctx, String key) => !AppConfig.demo && holdsPermission(_user(ctx), key);

bool _everywhere(BuildContext ctx, String key) => holdsPermissionEverywhere(_user(ctx), key);

CommunityManageRepository _community(BuildContext ctx) => ApiCommunityManageRepository(api: ctx.read<ApiClient>());

EventsManageRepository _events(BuildContext ctx) => ApiEventsManageRepository(api: ctx.read<ApiClient>());

// ---------------------------------------------------------------------------------------------------------------
// Chapters
// ---------------------------------------------------------------------------------------------------------------

/// The Chapters board's pencil; null for everyone who does not run chapters.
VoidCallback? manageChaptersDoor(BuildContext ctx) =>
    _holds(ctx, chaptersManageKey) ? () => openManageChapters(ctx) : null;

/// The pencil on one chapter's page. A role given over every chapter needs no asking; one given over some asks
/// the API whether this chapter is among them.
RecordManage? chapterManageDoor(BuildContext ctx) {
  if (!_holds(ctx, chaptersManageKey)) return null;
  final everywhere = _everywhere(ctx, chaptersManageKey);
  return RecordManage(
    may: (id) => everywhere ? Future.value(true) : _community(ctx).mayManageChapter(id),
    open: (c, id) => openManageChapter(c, id),
  );
}

/// The website's `/admin/community?tab=chapters` (and `?tab=applications`, on [focusApplicationId] when a
/// notification names one request).
Future<void> openManageChapters(BuildContext ctx, {String? tab, String? search, String? focusApplicationId}) =>
    AppShell.push<void>(
      ctx,
      (c) => communityFrame(
        ManageChaptersScreen(
          repository: _community(c),
          everywhere: _everywhere(c, chaptersManageKey),
          onBack: () => Navigator.of(c).pop(),
          onBell: () => openNotifications(c),
          unread: bellUnread(c),
          initialTab: tab,
          initialSearch: search,
          focusApplicationId: focusApplicationId,
          pageWrap: communityFrame,
        ),
      ),
    );

Future<void> openManageChapter(BuildContext ctx, String chapterId) => AppShell.push<void>(
  ctx,
  (c) => communityFrame(
    ManageChapterScreen(
      repository: _community(c),
      chapterId: chapterId,
      everywhere: _everywhere(c, chaptersManageKey),
      onBack: () => Navigator.of(c).pop(),
      onBell: () => openNotifications(c),
      unread: bellUnread(c),
      pageWrap: communityFrame,
    ),
  ),
);

// ---------------------------------------------------------------------------------------------------------------
// Councils
// ---------------------------------------------------------------------------------------------------------------

/// The Councils board's pencil; null for everyone who does not run councils.
VoidCallback? manageCouncilsDoor(BuildContext ctx) =>
    _holds(ctx, councilsManageKey) ? () => openManageCouncils(ctx) : null;

/// The pencil on one council's page.
RecordManage? councilManageDoor(BuildContext ctx) {
  if (!_holds(ctx, councilsManageKey)) return null;
  final everywhere = _everywhere(ctx, councilsManageKey);
  return RecordManage(
    may: (id) => everywhere ? Future.value(true) : _community(ctx).mayManageCouncil(id),
    open: (c, id) => openManageCouncil(c, id),
  );
}

/// The website's `/admin/community?tab=councils` (and its proposals, on [focusProposalId] when a notification
/// names one).
Future<void> openManageCouncils(BuildContext ctx, {String? tab, String? search, String? focusProposalId}) =>
    AppShell.push<void>(
      ctx,
      (c) => communityFrame(
        ManageCouncilsScreen(
          repository: _community(c),
          everywhere: _everywhere(c, councilsManageKey),
          onBack: () => Navigator.of(c).pop(),
          onBell: () => openNotifications(c),
          unread: bellUnread(c),
          initialTab: tab,
          initialSearch: search,
          focusProposalId: focusProposalId,
          pageWrap: communityFrame,
        ),
      ),
    );

Future<void> openManageCouncil(BuildContext ctx, String councilId) => AppShell.push<void>(
  ctx,
  (c) => communityFrame(
    ManageCouncilScreen(
      repository: _community(c),
      councilId: councilId,
      everywhere: _everywhere(c, councilsManageKey),
      onBack: () => Navigator.of(c).pop(),
      onBell: () => openNotifications(c),
      unread: bellUnread(c),
      pageWrap: communityFrame,
    ),
  ),
);

// ---------------------------------------------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------------------------------------------

/// The Events board's pencil; null for everyone who does not run events.
VoidCallback? manageEventsDoor(BuildContext ctx) => _holds(ctx, eventsManageKey) ? () => openManageEvents(ctx) : null;

/// The pencil on one event's sheet; null for everyone who does not run events.
ValueChanged<String>? manageEventDoor(BuildContext ctx) =>
    _holds(ctx, eventsManageKey) ? (id) => openManageEvent(ctx, id) : null;

/// The website's `/admin/community?tab=events` (and `?tab=event-hosts`, on [focusHostApplicationId] when a
/// notification names one company's request).
Future<void> openManageEvents(BuildContext ctx, {String? tab, String? focusHostApplicationId}) => AppShell.push<void>(
  ctx,
  (c) => communityFrame(
    ManageEventsScreen(
      repository: _events(c),
      onBack: () => Navigator.of(c).pop(),
      onBell: () => openNotifications(c),
      unread: bellUnread(c),
      initialTab: tab,
      focusHostApplicationId: focusHostApplicationId,
      pageWrap: communityFrame,
    ),
  ),
);

Future<void> openManageEvent(BuildContext ctx, String eventId) => AppShell.push<void>(
  ctx,
  (c) => communityFrame(
    ManageEventScreen(
      repository: _events(c),
      eventId: eventId,
      onBack: () => Navigator.of(c).pop(),
      onBell: () => openNotifications(c),
      unread: bellUnread(c),
      pageWrap: communityFrame,
    ),
  ),
);

// ---------------------------------------------------------------------------------------------------------------
// The website's console address
// ---------------------------------------------------------------------------------------------------------------

/// The three sections of the website's community console.
enum ManageSection { chapters, councils, events }

const _sectionKeys = {
  ManageSection.chapters: chaptersManageKey,
  ManageSection.councils: councilsManageKey,
  ManageSection.events: eventsManageKey,
};

/// A manage page, and the tab of it to open on (`applications`, `event-hosts`; null for its first).
typedef ConsolePage = ({ManageSection section, String? tab});

/// Which manage page the website's `/admin/community?tab=…` is for [user]: the tab it names when they may manage
/// that section, else the first section they may — the website's own rule. Null for someone who runs none.
ConsolePage? consolePageFor(SessionUser? user, Map<String, String> q) {
  ConsolePage? page(ManageSection section, {String? tab}) =>
      holdsPermission(user, _sectionKeys[section]!) ? (section: section, tab: tab) : null;
  final asked = switch (q['tab']) {
    'chapters' => page(ManageSection.chapters),
    'councils' => page(ManageSection.councils),
    // One tab on the website holds both queues: a proposal is the council staff's, an application the chapter's.
    'applications' =>
      q['proposal'] != null
          ? (page(ManageSection.councils, tab: 'applications') ?? page(ManageSection.chapters, tab: 'applications'))
          : (page(ManageSection.chapters, tab: 'applications') ?? page(ManageSection.councils, tab: 'applications')),
    'events' => page(ManageSection.events),
    'event-hosts' => page(ManageSection.events, tab: 'event-hosts'),
    _ => null,
  };
  return asked ??
      page(ManageSection.chapters) ??
      page(ManageSection.councils) ??
      page(ManageSection.events);
}

/// Opens the website's `/admin/community?tab=…` (a staff notification's page, a link) on the app's own manage
/// page, on the request (`?application=`, `?proposal=`) or the search it names. Null for someone who runs none of
/// the three sections, so the caller says it is a staff page.
Future<void> Function(BuildContext ctx)? communityConsoleRoute(BuildContext ctx, Map<String, String> q) {
  final page = AppConfig.demo ? null : consolePageFor(_user(ctx), q);
  if (page == null) return null;
  // `?search=` fills the list of the section its link named.
  final search = page.tab == null && q['tab'] == page.section.name ? q['search'] : null;
  return switch (page.section) {
    ManageSection.chapters => (c) => openManageChapters(
      c,
      tab: page.tab,
      search: search,
      focusApplicationId: page.tab == null ? null : q['application'],
    ),
    ManageSection.councils => (c) => openManageCouncils(
      c,
      tab: page.tab,
      search: search,
      focusProposalId: page.tab == null ? null : q['proposal'],
    ),
    ManageSection.events => (c) => openManageEvents(
      c,
      tab: page.tab,
      focusHostApplicationId: page.tab == null ? null : q['application'],
    ),
  };
}
