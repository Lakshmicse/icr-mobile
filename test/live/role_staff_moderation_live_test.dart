/// What STAFF can do to other members' content, and what the app shows of it, against the LOCAL portal API.
///
/// The portal gives moderators the forum (`forum:moderate`: edit, delete, accept an answer on anyone's
/// discussion through the ordinary member endpoints, plus the `/forum/admin/*` console: pin, lock, hide,
/// approve, resolve reports) and gives a SUPER_ADMIN the library's report queue and the right to change any
/// document. The app carries the first half (the member endpoints answer `canEdit` / `canModerate` for a
/// moderator, and the screens follow them) and none of the console.
///
/// Every test works on rows it creates (a discussion by Pooja Professional, a reply by Bharat Buyer, a document
/// by Pooja) and removes them; a report is closed as APPROVED ("the content stands"), which leaves nothing open.
///
///     flutter test --no-pub --timeout=120s test/live/role_staff_moderation_live_test.dart --concurrency=1
@Tags(['live'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart' show DioException;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/feed/feed_models.dart';
import 'package:icr_mobile/features/forum/api_forum_repository.dart';
import 'package:icr_mobile/features/forum/forum_models.dart';
import 'package:icr_mobile/features/forum/reply_tree.dart';
import 'package:icr_mobile/features/forum/thread_controller.dart';
import 'package:icr_mobile/features/forum/thread_screen.dart';
import 'package:icr_mobile/features/library/api_library_repository.dart';
import 'package:icr_mobile/features/library/document_controller.dart';
import 'package:icr_mobile/features/library/document_screen.dart';
import 'package:icr_mobile/features/library/library_models.dart';
import 'package:icr_mobile/features/library/upload_controller.dart';
import 'package:icr_mobile/features/notifications/api_notifications_repository.dart';
import 'package:icr_mobile/features/notifications/notification_router.dart';
import 'package:icr_mobile/features/notifications/notification_target.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../helpers/fonts.dart';

import 'live.dart';
import 'role_staff_support.dart';

/// One person's signed-in client, forum and id.
class _Person {
  _Person(this.who);

  final LivePerson who;
  late final ApiClient api;
  late final String id;
  late final ApiForumRepository forum;
  var _ready = false;

  Future<_Person> open() async {
    if (_ready) return this;
    api = await clientFor(who);
    id = await idOf(api);
    forum = ApiForumRepository(api: api, viewerId: id);
    _ready = true;
    return this;
  }

  FeedAuthor get asViewer => FeedAuthor(id: id, name: who.label);
}

final _pooja = _Person(pooja);
final _bharat = _Person(bharat);
final _admin = _Person(superAdmin);
final _content = _Person(contentAdmin);
final _support = _Person(supportAgent);

/// A question by Pooja, deleted by [remove].
class _Sandbox {
  _Sandbox(this.thread);

  final ForumThread thread;

  String get id => thread.id;
  String get slug => thread.slug;

  static Future<_Sandbox> create({String? title, ThreadKind kind = ThreadKind.question}) async {
    final p = await _pooja.open();
    final tech = (await p.forum.taxonomy()).firstWhere((n) => n.key == 'TECHNOLOGY_INNOVATION');
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final thread = await p.forum.create(
      ForumDraft(
        categoryKey: tech.key,
        title: title ?? 'A staff sandbox for the app ($stamp)',
        body: 'A discussion the staff live tests made. It is deleted when the test ends.',
        kind: kind,
        tags: const ['app-live-test'],
      ),
    );
    return _Sandbox(thread);
  }

  Future<void> remove() async {
    try {
      await (await _pooja.open()).forum.deleteThread(id);
    } on Object {
      // Already gone.
    }
  }
}

/// The API's answer to [call] as a status and a sentence, or null when it went through.
Future<({int? status, String message})?> refusal(Future<dynamic> Function() call) async {
  try {
    await call();
    return null;
  } on DioException catch (e) {
    final error = ApiError.from(e);
    return (status: error.statusCode, message: error.message);
  } on ApiError catch (e) {
    return (status: e.statusCode, message: e.message);
  }
}

/// A one-line text file Pooja shares, through the app's own upload form.
Future<LibraryDocument> _share() async {
  final p = await _pooja.open();
  final repo = ApiLibraryRepository(api: p.api);
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final form = UploadController(repository: repo, usedCategories: await repo.categories());
  form.pick([
    PickedFile(
      name: 'Staff test $stamp.txt',
      bytes: Uint8List.fromList(utf8.encode('A document the staff live tests made. It is deleted when the test ends.')),
      mimeType: 'text/plain',
    ),
  ]);
  form
    ..setDescription('Live test document: please ignore.')
    ..setCategory((await repo.categories()).first);
  final doc = await form.submit();
  expect(doc, isNotNull, reason: form.error);
  return doc!;
}

Future<void> _remove(LibraryDocument doc) async {
  try {
    await ApiLibraryRepository(api: (await _pooja.open()).api).delete(doc.id);
  } on Object {
    // Already gone.
  }
}

void main() {
  setUpAll(StaffRoles.ensure);
  tearDownAll(StaffRoles.restore);

  group('the forum: a moderator works on other members\' discussions through the app\'s own controllers', () {
    liveTest(
      'a SUPER_ADMIN may edit, answer, accept and remove what others wrote; the page says so (canEdit, canModerate, canAccept)',
      () async {
        final admin = await _admin.open();
        final bharatP = await _bharat.open();
        final box = await _Sandbox.create();
        try {
          final reply = await bharatP.forum.reply(box.id, 'Bharat writes an answer for the moderator to handle.');

          final c = ThreadController(repository: admin.forum, slug: box.slug, viewer: admin.asViewer);
          await c.start();
          addTearDown(c.dispose);
          expect(c.isOwn, isFalse, reason: 'Pooja wrote it');
          expect(c.thread!.canEdit, isTrue, reason: 'a moderator may edit anyone\'s discussion');
          expect(c.thread!.canModerate, isTrue);
          expect(c.canAccept, isTrue, reason: 'on a question a moderator may mark the answer');
          expect(c.takesReplies, isTrue);
          final seen = findReply(c.replies, reply.id)!;
          expect(seen.canEdit, isTrue, reason: 'and anyone\'s reply');
          expect(seen.accepted, isFalse);

          // Accept Bharat's answer to Pooja's question.
          expect(await c.accept(seen), isNull);
          expect(findReply(c.replies, reply.id)!.accepted, isTrue);
          expect((await admin.forum.thread(box.slug)).acceptedReplyId, reply.id, reason: 'the forum kept it');

          // Edit another member's reply, then the discussion itself.
          expect(await c.editReply(findReply(c.replies, reply.id)!, 'Edited by a moderator for clarity.'), isNull);
          final back = await bharatP.forum.replies(box.slug);
          expect(findReply(back.replies, reply.id)!.body, contains('Edited by a moderator'));
          final edited = await admin.forum.update(
            box.id,
            const ForumDraft(categoryKey: null, title: 'Edited by a moderator: a staff sandbox'),
          );
          expect(edited.card.title, 'Edited by a moderator: a staff sandbox');
          expect(edited.card.author.id, (await _pooja.open()).id, reason: 'the author is still Pooja');

          // Delete another member's reply; its place in the thread goes with it, and the accepted mark.
          expect(await c.deleteReply(findReply(c.replies, reply.id)!), isNull);
          final after = await bharatP.forum.replies(box.slug);
          expect(findReply(after.replies, reply.id), isNull);
          expect((await bharatP.forum.thread(box.slug)).acceptedReplyId, isNull);

          // Delete the discussion from the moderator's page.
          expect(await c.deleteThread(), isNull);
          await expectLater(
            bharatP.forum.thread(box.slug),
            throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 404)),
          );
        } finally {
          await box.remove();
        }
      },
    );

    liveTest(
      'pin, lock and hide are the console\'s: the app\'s reads follow them (pinned first, locked closes the reply box for members only, hidden is gone)',
      () async {
        final admin = await _admin.open();
        final bharatP = await _bharat.open();
        final box = await _Sandbox.create();
        try {
          Future<void> moderate(Map<String, Object?> body) =>
              admin.api.dio.patch<dynamic>('/forum/admin/threads/${box.id}', data: body);

          // Pinned: the board leads with the pinned discussions (the Home design's four are pinned too), ours among them.
          await moderate({'pinned': true});
          final board = await bharatP.forum.threads(const ForumQuery());
          final lead = board.posts.takeWhile((p) => p.pinned).map((p) => p.id);
          expect(lead, contains(box.id), reason: 'a pinned discussion is in the pinned run at the top');
          await moderate({'pinned': false});
          final unpinned = await bharatP.forum.threads(const ForumQuery());
          expect(unpinned.posts.takeWhile((p) => p.pinned).map((p) => p.id), isNot(contains(box.id)));

          // Locked: a member's page closes the reply box in the forum's words; a moderator's stays open.
          await moderate({'status': 'LOCKED'});
          final member = ThreadController(repository: bharatP.forum, slug: box.slug, viewer: bharatP.asViewer);
          final mod = ThreadController(repository: admin.forum, slug: box.slug, viewer: admin.asViewer);
          addTearDown(member.dispose);
          addTearDown(mod.dispose);
          await member.start();
          await mod.start();
          expect(member.takesReplies, isFalse);
          expect(member.lockedReason, 'This discussion is locked, so it is not taking new replies.');
          expect(await member.sendReply('Can I still answer?'), isNotNull, reason: 'the forum refuses a member');
          expect(mod.takesReplies, isTrue);
          expect(mod.lockedReason, isNull);
          expect(await mod.sendReply('A moderator may still answer a locked discussion.'), isNull);
          await moderate({'status': 'OPEN'});

          // Hidden (rejected): gone from the board and from the page for everyone but the console.
          await moderate({'moderation': 'REJECTED', 'reason': 'A staff test hides it.'});
          await expectLater(
            bharatP.forum.thread(box.slug),
            throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 404)),
          );
          final ids = (await bharatP.forum.threads(const ForumQuery())).posts.map((p) => p.id);
          expect(ids, isNot(contains(box.id)));
        } finally {
          await box.remove();
        }
      },
    );

    liveTest('a report reaches the moderators\' queue and their bell; the app opens neither in the app', () async {
      final admin = await _admin.open();
      final bharatP = await _bharat.open();
      final box = await _Sandbox.create();
      final marker = 'staff-test-${DateTime.now().millisecondsSinceEpoch}';
      String? reportId;
      try {
        await bharatP.forum.report(threadId: box.id, reason: ReportReason.spam, note: marker);

        // The console's queue (the website's /admin/forum) holds it, with the excerpt a moderator reads.
        final queue = (await admin.api.dio.get<Map<String, dynamic>>(
          '/forum/admin/reports',
          queryParameters: {'limit': 100},
        )).data!;
        final row = (queue['data'] as List).cast<Map<String, dynamic>>().firstWhere(
          (r) => r['note'] == marker,
          orElse: () => <String, dynamic>{},
        );
        expect(row, isNotEmpty, reason: 'the report is in the moderators\' queue');
        reportId = row['id'] as String;
        expect(row['reason'], 'SPAM');
        expect((row['target'] as Map)['kind'], 'THREAD');
        expect((row['target'] as Map)['threadSlug'], box.slug);

        // The bell: a notification for the moderator, and the app reads where it points.
        final notifications = ApiNotificationsRepository(api: admin.api);
        final page = await notifications.list(unreadOnly: true);
        final bell = page.items.firstWhere(
          (n) => (n.link ?? '').contains('/admin/forum') && (n.link ?? '').contains(reportId!),
          orElse: () => throw StateError('no bell for the report in ${page.items.map((n) => n.link)}'),
        );
        final target = NotificationTarget.parse(bell.link);
        expect(target.kind, NotificationKinds.adminForum);
        expect(target['reportId'], reportId);
        // The app has no opener for it, so it goes to the website's console: that is the handoff.
        final opened = <String>[];
        final router = NotificationRouter(openSite: (context, path) async => opened.add(path));
        expect(router.registeredKinds, isNot(contains(NotificationKinds.adminForum)));
        await openWithoutScreen(router, target, opened);
        expect(opened, [bell.link]);
      } finally {
        if (reportId != null) {
          await admin.api.dio.patch<dynamic>(
            '/forum/admin/reports/$reportId',
            data: {'status': 'APPROVED', 'resolutionNote': 'A staff test closes it: the content stands.'},
          );
        }
        await box.remove();
      }
    });

    liveTest(
      'the other two staff accounts hold no forum:moderate: no moderator\'s rights on a page, the console answers 403',
      () async {
        final bharatP = await _bharat.open();
        final box = await _Sandbox.create();
        try {
          final reply = await bharatP.forum.reply(box.id, 'An answer nobody but its author may touch.');
          for (final who in [_content, _support]) {
            final p = await who.open();
            expect((await p.forum.access()).canModerate, isFalse, reason: who.who.label);
            final c = ThreadController(repository: p.forum, slug: box.slug, viewer: p.asViewer);
            await c.start();
            addTearDown(c.dispose);
            expect(c.canModerate, isFalse);
            expect(c.thread!.canEdit, isFalse);
            expect(c.canAccept, isFalse);
            expect(findReply(c.replies, reply.id)!.canEdit, isFalse);

            // Ordinary member endpoints refuse an edit, a delete and an accept in the forum's words.
            expect(await c.editReply(findReply(c.replies, reply.id)!, 'Sneaking in an edit.'), isNotNull);
            expect(await c.deleteReply(findReply(c.replies, reply.id)!), isNotNull);
            expect(await c.deleteThread(), isNotNull);

            // The console is closed by permission, not hidden by role.
            for (final call in <Future<dynamic> Function()>[
              () => p.api.dio.get<dynamic>('/forum/admin/reports'),
              () => p.api.dio.get<dynamic>('/forum/admin/queue'),
              () => p.api.dio.patch<dynamic>('/forum/admin/threads/${box.id}', data: {'pinned': true}),
            ]) {
              final r = await refusal(call);
              expect(r?.status, 403, reason: '${who.who.label} is not a moderator');
              expect(r?.message, 'Insufficient permissions');
            }
          }
          // They can still report, like any member.
          final p = await _support.open();
          await p.forum.report(threadId: box.id, reason: ReportReason.offTopic, note: 'staff-test');
          final admin = await _admin.open();
          final queue = (await admin.api.dio.get<Map<String, dynamic>>(
            '/forum/admin/reports',
            queryParameters: {'limit': 100},
          )).data!;
          for (final r in (queue['data'] as List).cast<Map<String, dynamic>>().where(
            (r) => r['note'] == 'staff-test',
          )) {
            await admin.api.dio.patch<dynamic>('/forum/admin/reports/${r['id']}', data: {'status': 'APPROVED'});
          }
        } finally {
          await box.remove();
        }
      },
    );
  });

  group('the discussion page draws the moderator tools only for a moderator', () {
    setUpAll(loadAppFonts);

    for (final entry in {superAdmin: true, contentAdmin: false, supportAgent: false}.entries) {
      testWidgets(
        '${entry.key.label}: ${entry.value ? "Accept answer, Edit and Delete on another member's discussion" : 'only Copy link, Who viewed and Report'}',
        tags: const ['live'],
        timeout: const Timeout(Duration(minutes: 3)),
        (tester) async {
          if (!await liveScreenReady(tester)) return;
          final box = (await tester.runAsync(_Sandbox.create))!;
          try {
            final bharatP = (await tester.runAsync(_bharat.open))!;
            final reply = (await tester.runAsync(
              () => bharatP.forum.reply(box.id, 'An answer on a page a moderator is reading.'),
            ))!;
            final who = (await tester.runAsync(() => _Person(entry.key).open()))!;
            await pumpAs(
              tester,
              entry.key,
              (context) => ChangeNotifierProvider<ThreadController>(
                create: (_) => ThreadController(repository: who.forum, slug: box.slug, viewer: who.asViewer)..start(),
                child: ThreadScreen(onEdit: (thread) async => null),
              ),
            );
            await settle(tester);
            expect(thrown(tester), isNull);
            expectNoRawErrors(tester, 'the discussion');
            expect(find.textContaining('An answer on a page a moderator is reading.'), findsWidgets);
            expect(
              find.byKey(ValueKey('reply-accept:${reply.id}')),
              entry.value ? findsOneWidget : findsNothing,
              reason: 'only the asker or a moderator marks the answer',
            );

            await tester.tap(find.byIcon(LucideIcons.ellipsisVertical).first);
            await tester.pump(const Duration(milliseconds: 400));
            expect(find.byKey(const ValueKey('menu-copy')), findsOneWidget);
            expect(find.byKey(const ValueKey('menu-report')), findsOneWidget, reason: 'it is not their own');
            expect(find.byKey(const ValueKey('menu-edit')), entry.value ? findsOneWidget : findsNothing);
            expect(find.byKey(const ValueKey('menu-delete')), entry.value ? findsOneWidget : findsNothing);
            await finishLive(tester);
          } finally {
            await tester.runAsync(box.remove);
          }
        },
      );
    }
  });

  group('the library: a SUPER_ADMIN changes any document, the other two staff only their own', () {
    liveTest(
      'the document page lets a SUPER_ADMIN delete what Pooja shared; the others are refused in the words the API gives',
      () async {
        final doc = await _share();
        try {
          for (final who in [_content, _support]) {
            final p = await who.open();
            final repo = ApiLibraryRepository(api: p.api);
            final page = DocumentController(repository: repo, documentId: doc.id, initial: doc);
            await page.start();
            addTearDown(page.dispose);
            expect(page.viewer!.isAdmin, isFalse, reason: who.who.label);
            expect(page.mayChange, isFalse);
            expect(page.isMine, isFalse);
            final r = await refusal(() => repo.delete(doc.id));
            expect(r?.status, 403);
            expect(r?.message, 'You can only change a document you uploaded.');
          }
          // A member can report it; the queue is for a SUPER_ADMIN alone.
          final admin = await _admin.open();
          final repo = ApiLibraryRepository(api: admin.api);
          final page = DocumentController(repository: repo, documentId: doc.id, initial: doc);
          await page.start();
          addTearDown(page.dispose);
          expect(page.viewer!.isAdmin, isTrue);
          expect(page.mayChange, isTrue);
          expect(page.isMine, isFalse);
          expect(await page.delete(), isNull);
          await expectLater(repo.document(doc.id), throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 404)));
        } finally {
          await _remove(doc);
        }
      },
    );

    liveTest('a report is in the SUPER_ADMIN queue and nobody else queue; the app has no queue', () async {
      final doc = await _share();
      final marker = 'staff-test-${DateTime.now().millisecondsSinceEpoch}';
      String? reportId;
      final admin = await _admin.open();
      try {
        final b = await _bharat.open();
        final page = DocumentController(
          repository: ApiLibraryRepository(api: b.api),
          documentId: doc.id,
          initial: doc,
        );
        await page.start();
        addTearDown(page.dispose);
        expect(await page.report(DocumentReportReason.spam, note: marker), isNull);

        final queue = (await admin.api.dio.get<Map<String, dynamic>>(
          '/documents/admin/reports',
          queryParameters: {'status': 'PENDING', 'limit': 100},
        )).data!;
        final row = (queue['data'] as List).cast<Map<String, dynamic>>().firstWhere(
          (r) => r['note'] == marker,
          orElse: () => <String, dynamic>{},
        );
        expect(row, isNotEmpty);
        reportId = row['id'] as String;

        for (final who in [_content, _support, _bharat]) {
          final p = await who.open();
          final r = await refusal(() => p.api.dio.get<dynamic>('/documents/admin/reports'));
          expect(r?.status, 403, reason: who.who.label);
          expect(r?.message, 'Insufficient role permissions');
        }
      } finally {
        if (reportId != null) {
          await admin.api.dio.patch<dynamic>('/documents/admin/reports/$reportId', data: {'status': 'APPROVED'});
        }
        await _remove(doc);
      }
    });
  });

  group('the consoles: which staff account may open which, and what the app does with a staff bell', () {
    /// (website console, the list endpoint behind it, the permission it asks, or null for "a SUPER_ADMIN only").
    /// The app has none of these screens.
    const consoles = <(String, String, String?)>[
      ('Forum moderation  /admin/forum', '/forum/admin/reports', 'forum:moderate'),
      ('Support desk  /admin/support', '/support/admin/queue', 'support:read'),
      ('Contact inbox  /admin/contact', '/contact', 'contact:read'),
      ('Blogs  /admin/blogs', '/cms/blogs/admin', 'blogs:manage'),
      ('Mentor applications  /admin/mentorship', '/mentorship/admin/queue', 'mentorship:review'),
      ('Library reports  /admin/documents/reports', '/documents/admin/reports', null),
      ('Verification  /admin/verification', '/verification/queue', null),
      ('Users  /admin/users', '/users', null),
      ('Subscriptions  /admin/subscriptions', '/admin/subscriptions', 'subscriptions:read'),
      ('Roles  /admin/roles', '/access/roles', 'roles:manage'),
      ('Translations  /admin/translations', '/i18n/translations/stats', 'translations:manage'),
      ('Onboarding  /admin/onboarding', '/admin/onboarding/funnel', 'onboarding:read'),
      ('Homepage  /admin/homepage', '/homepage/admin/testimonials', 'homepage:manage'),
    ];

    liveTest('each console opens for the account that holds its permission and answers 403 to the others', () async {
      final people = [_admin, _content, _support];
      final held = <String, Set<String>>{};
      for (final person in people) {
        await person.open();
        final me = (await person.api.dio.get<Map<String, dynamic>>('/auth/me')).data!;
        held[person.who.email] = {for (final k in (me['permissions'] as List? ?? const [])) '$k'};
      }
      final rows = <String>[
        for (final person in people.skip(1)) '${person.who.email} holds: ${held[person.who.email]!.toList()}',
        if (StaffRoles.catalogueMissing)
          'NOTE: this database has no permission catalogue (db:seed:access never ran), so the two custom-role '
              'accounts are plain members here',
      ];
      for (final (name, path, key) in consoles) {
        final cells = <String>[];
        for (final person in people) {
          final r = await refusal(() => person.api.dio.get<dynamic>(path, queryParameters: {'limit': 1}));
          final open = r == null || (r.status != 401 && r.status != 403);
          final allowed = person == _admin || (key != null && held[person.who.email]!.contains(key));
          cells.add('${person.who.email.split('@').first}=${open ? 'open' : '403'}');
          expect(open, allowed, reason: '$name for ${person.who.email}: ${r?.status} ${r?.message}');
        }
        rows.add('$name  ->  ${cells.join('  ')}');
      }
      // ignore: avoid_print
      print(rows.join('\n'));
    });

    liveTest('a SUPER_ADMIN bell is full of console links; the app reads each and hands it to the website', () async {
      final admin = await _admin.open();
      final repo = ApiNotificationsRepository(api: admin.api);
      final page = await repo.list();
      expect(page.items, isNotEmpty);
      final kinds = <String, int>{};
      final handedOver = <String>[];
      final router = NotificationRouter(openSite: (context, path) async => handedOver.add(path));
      for (final n in page.items) {
        final target = NotificationTarget.parse(n.link);
        kinds[target.kind] = (kinds[target.kind] ?? 0) + 1;
        if (target.kind.startsWith('admin.') || target.kind == NotificationKinds.adminMarketing) {
          // A console link: no screen of the app takes it, so it opens the website's page. It never throws.
          await openWithoutScreen(router, target, handedOver);
        }
      }
      final consoleLinks = kinds.entries.where((e) => e.key.startsWith('admin.')).fold<int>(0, (n, e) => n + e.value);
      expect(consoleLinks, greaterThan(0), reason: 'a SUPER_ADMIN is told about reviews and reports');
      expect(handedOver, hasLength(consoleLinks));
      expect(handedOver.every((href) => href.startsWith('/admin/')), isTrue);
      // ignore: avoid_print
      print('bell kinds: $kinds');
    });
  });

  group('the document page draws Delete and Add files for a SUPER_ADMIN on any document', () {
    setUpAll(loadAppFonts);

    for (final entry in {superAdmin: true, contentAdmin: false}.entries) {
      testWidgets(
        '${entry.key.label}: ${entry.value ? 'Add files and Delete' : 'only Share and Report'}',
        tags: const ['live'],
        timeout: const Timeout(Duration(minutes: 3)),
        (tester) async {
          if (!await liveScreenReady(tester)) return;
          final doc = (await tester.runAsync(_share))!;
          try {
            final api = (await tester.runAsync(() => clientFor(entry.key)))!;
            await pumpAs(
              tester,
              entry.key,
              (context) => documentPage(
                repository: ApiLibraryRepository(api: api),
                documentId: doc.id,
                initial: doc,
                onBack: () {},
              ),
            );
            await settle(tester);
            expect(thrown(tester), isNull);
            expectNoRawErrors(tester, 'the document page');
            expect(find.textContaining('Staff test'), findsWidgets);
            expect(find.text('Report'), findsOneWidget, reason: 'it is not their own');
            expect(find.text('Delete'), entry.value ? findsOneWidget : findsNothing);
            expect(find.text('Add files'), entry.value ? findsOneWidget : findsNothing);
            await finishLive(tester);
          } finally {
            await tester.runAsync(() => _remove(doc));
          }
        },
      );
    }
  });
}

/// Runs the router's open on a target without a screen: the website opener ignores the context.
Future<void> openWithoutScreen(NotificationRouter router, NotificationTarget target, List<String> opened) async {
  await router.open(_NoContext.instance, target);
}

class _NoContext extends Fake implements BuildContext {
  static final instance = _NoContext();
}
