/// Managing Chapters, Councils and Events against the LOCAL portal API, signed in as the seeded Super Admin (the
/// one account that surely holds `chapters:manage`, `councils:manage` and `events:manage`): the app's own
/// repositories, the bodies its forms build, and each effect read back through the API.
///
/// Every write is undone: the chapter, council and event a test makes are unpublished from the start and retired
/// at the end (the API soft-deletes them, so a run leaves three retired rows named "App Live Check …").
///
///     flutter test test/live/community_manage_live_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/auth/session_user.dart';
import 'package:icr_mobile/features/community_manage/community_manage_repository.dart';
import 'package:icr_mobile/features/community_manage/community_manage_rules.dart';
import 'package:icr_mobile/features/events_manage/events_manage_models.dart';
import 'package:icr_mobile/features/events_manage/events_manage_repository.dart';
import 'package:icr_mobile/features/events_manage/events_manage_rules.dart';

import 'live.dart';

const _admin = LivePerson('superadmin@icr.test', 'Test@12345', 'Sana Admin');

String _stamp() => DateTime.now().millisecondsSinceEpoch.toRadixString(36);

void main() {
  late bool up;

  setUpAll(() async => up = await liveApiReachable());

  test('who is told they may manage: the session carries the keys', () async {
    if (!up) return markTestSkipped('the local API is not running');
    final admin = await liveClient(_admin);
    final me = SessionUser.fromJson((await admin.dio.get<Map<String, dynamic>>('/auth/me')).data!);
    expect(me.role, 'SUPER_ADMIN');
    expect(holdsPermissionEverywhere(me, 'chapters:manage'), isTrue);

    final member = await liveClient(pooja);
    final her = SessionUser.fromJson((await member.dio.get<Map<String, dynamic>>('/auth/me')).data!);
    expect(holdsPermission(her, 'events:manage'), isFalse, reason: 'Pooja holds no staff role');
  });

  test('a chapter: listed, made, edited, given an update, and retired', () async {
    if (!up) return markTestSkipped('the local API is not running');
    final repo = ApiCommunityManageRepository(api: await liveClient(_admin));

    final list = await repo.chapters();
    expect(list.rows, isNotEmpty, reason: 'the seeded chapters');
    final first = list.rows.first;
    expect(await repo.mayManageChapter(first.id), isTrue);
    expect((await repo.chapter(first.id))?.name, first.name);
    final content = await repo.content(OrgKind.chapter, first.id);
    expect(content.members.length + content.leads.length, greaterThanOrEqualTo(0));

    // A member with no staff role is told no, not shown an error.
    final asMember = ApiCommunityManageRepository(api: await liveClient(pooja));
    expect(await asMember.mayManageChapter(first.id), isFalse);

    final name = 'App Live Check ${_stamp()}';
    final draft = ChapterDraft(name: name, city: 'Mysuru', region: 'Karnataka', published: false);
    expect(draft.problems(), isEmpty);
    await repo.createChapter(draft.body());
    final made = (await repo.chapters(search: name)).rows.singleWhere((c) => c.name == name);
    addTearDown(() => repo.retire(OrgKind.chapter, made.id).catchError((_) {}));
    expect(made.published, isFalse);
    expect(made.city, 'Mysuru');

    final edit = ChapterDraft.of(made)..description = 'Made by the app\'s live check.';
    await repo.updateChapter(made.id, edit.body(was: made));
    expect((await repo.chapter(made.id))?.description, 'Made by the app\'s live check.');

    await repo.addAnnouncement(OrgKind.chapter, made.id, {'title': 'Hello', 'body': 'First update', 'pinned': false});
    final after = await repo.content(OrgKind.chapter, made.id);
    final update = after.announcements.singleWhere((a) => a.title == 'Hello');
    await repo.removeAnnouncement(OrgKind.chapter, made.id, update.id);
    expect((await repo.content(OrgKind.chapter, made.id)).announcements, isEmpty);

    await repo.retire(OrgKind.chapter, made.id);
    expect((await repo.chapters(search: name)).rows.where((c) => c.id == made.id), isEmpty);
  });

  test('a council: listed, made, edited and retired; the request queues answer', () async {
    if (!up) return markTestSkipped('the local API is not running');
    final repo = ApiCommunityManageRepository(api: await liveClient(_admin));

    final list = await repo.councils();
    expect(list.rows, isNotEmpty, reason: 'the seeded councils');
    expect(await repo.mayManageCouncil(list.rows.first.id), isTrue);
    await repo.content(OrgKind.council, list.rows.first.id);

    final stamp = _stamp();
    final name = 'App Live Check Council $stamp';
    final draft = CouncilDraft(
      name: name,
      slug: 'app-live-check-$stamp',
      focus: 'Live checks',
      segments: ['Testing'],
      published: false,
    );
    expect(draft.problems(), isEmpty);
    await repo.createCouncil(draft.body());
    final made = (await repo.councils(search: name)).rows.singleWhere((c) => c.name == name);
    addTearDown(() => repo.retire(OrgKind.council, made.id).catchError((_) {}));

    final edit = CouncilDraft.of(made)..focus = 'Live checks, edited';
    await repo.updateCouncil(made.id, edit.body(was: made));
    expect((await repo.council(made.id))?.focus, 'Live checks, edited');

    await repo.retire(OrgKind.council, made.id);
    expect((await repo.councils(search: name)).rows.where((c) => c.id == made.id), isEmpty);

    // The two queues of the Applications tab.
    await repo.chapterApplications(status: 'PENDING');
    await repo.councilProposals(status: 'PENDING');
  });

  test('an event: listed, made, edited, a package and a guest added and removed, and deleted', () async {
    if (!up) return markTestSkipped('the local API is not running');
    final repo = ApiEventsManageRepository(api: await liveClient(_admin));

    final list = await repo.events(const EventsQuery());
    expect(list.rows, isNotEmpty, reason: 'the seeded events');
    expect((await repo.event(list.rows.first.id))?.id, list.rows.first.id);
    await repo.chapters();
    await repo.councils();
    await repo.tickets(list.rows.first.id);
    await repo.hostApplications();
    expect(await repo.pendingHostApplications(), greaterThanOrEqualTo(0));

    final title = 'App Live Check ${_stamp()}';
    final draft = EventDraft(published: false)
      ..title = title
      ..startsAt = DateTime.now().add(const Duration(days: 40))
      ..endsAt = DateTime.now().add(const Duration(days: 40, hours: 2))
      ..capacity = '25';
    expect(draft.problems(), isEmpty);
    final id = await repo.createEvent(draft.toJson(create: true));
    expect(id, isNotEmpty);
    addTearDown(() => repo.deleteEvent(id).catchError((_) {}));

    final made = await repo.event(id);
    expect(made?.title, title, reason: 'a hidden event is found through the staff list');
    expect(made?.capacity, 25);

    // Clearing the capacity on an edit: the app sends null, and the API stores it.
    final edit = EventDraft.of(made)..capacity = '';
    await repo.updateEvent(id, edit.toJson(create: false));
    expect((await repo.event(id))?.capacity, isNull);

    final pack = PackageDraft()
      ..name = 'Gold'
      ..price = '5000'
      ..benefits = 'Logo on the stage';
    await repo.createPackage(id, pack.toJson());
    var programme = await repo.programme(id);
    final gold = programme.packages.singleWhere((p) => p.name == 'Gold');
    expect(gold.pricePaisa, 500000);
    await repo.deletePackage(gold.id);

    final invited = await repo.invite(id, emails: [pooja.email]);
    expect(invited.invited, 1);
    programme = await repo.programme(id);
    final guest = programme.invites.singleWhere((i) => i.email == pooja.email);
    await repo.removeInvite(id, guest.userId);
    expect((await repo.programme(id)).invites, isEmpty);

    await repo.deleteEvent(id);
    expect(await repo.event(id), isNull);
  });
}
