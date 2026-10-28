import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/feed/feed_models.dart';
import 'package:icr_mobile/features/feed/widgets/reply_widgets.dart';
import 'package:icr_mobile/features/forum/forum_callbacks.dart';
import 'package:icr_mobile/features/forum/forum_models.dart';
import 'package:icr_mobile/features/forum/thread_controller.dart';
import 'package:icr_mobile/features/forum/thread_screen.dart';
import 'package:provider/provider.dart';

import 'helpers/feed_fixtures.dart';
import 'helpers/fonts.dart';
import 'helpers/forum_fakes.dart';

/// Every control of a discussion's page, pressed on the real screen over the real repository, with only the forum
/// faked (`helpers/forum_fakes.dart`) and the platform channels the screen ends in (the browser, the share sheet,
/// the clipboard) listened to. What the portal does in answer is proved by `test/live/forum_live_test.dart`.

/// A fake that holds back one route until a test lets it go, to see the page while it waits.
class GatedForum extends FakeForum {
  GatedForum(super.routes, this.gated);

  final String gated;
  final gate = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if ('${options.method} ${options.path}' == gated) await gate.future;
    return super.fetch(options, requestStream, cancelFuture);
  }
}

void main() {
  setUpAll(loadAppFonts);

  final launched = <Uri>[];
  final shared = <Map<String, dynamic>>[];
  var copied = '';

  setUp(() {
    launched.clear();
    shared.clear();
    copied = '';
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/url_launcher'), (call) async {
      if (call.method == 'launch') launched.add(Uri.parse((call.arguments as Map)['url'] as String));
      return call.method == 'launch' || call.method == 'canLaunch';
    });
    messenger.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/share'), (call) async {
      shared.add(Map<String, dynamic>.from(call.arguments as Map));
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
  });

  tearDown(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/url_launcher'), null);
    messenger.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/share'), null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
  }

  late ForumWorld world;
  late FakeForum api;
  late ThreadController controller;
  ThreadResult? popped;
  var bells = 0;
  final members = <String>[];
  final tags = <String>[];
  final topics = <String>[];

  Future<void> pumpThread(
    WidgetTester tester, {
    ForumWorld? custom,
    Map<String, Handler> extra = const {},
    FeedPost? preview,
    String? focus,
    FakeForum? fake,
    bool start = true,
    double height = 6000,
    Future<ForumThread?> Function(ForumThread)? onEdit,
  }) async {
    tester.view.physicalSize = Size(780, height);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    world = custom ?? ForumWorld();
    api = fake ?? FakeForum({...world.routes(), ...extra});
    popped = null;
    bells = 0;
    members.clear();
    tags.clear();
    topics.clear();
    controller = ThreadController(
      repository: forumOn(api),
      slug: ForumWorld.slug,
      viewer: reader,
      preview: preview,
      focusReplyId: focus,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const ValueKey('open'),
                onPressed: () async {
                  popped = await Navigator.of(context).push<ThreadResult>(
                    MaterialPageRoute<ThreadResult>(
                      builder: (_) => ChangeNotifierProvider<ThreadController>.value(
                        value: controller,
                        child: ThreadScreen(
                          unread: 2,
                          onEdit: onEdit,
                          callbacks: ForumCallbacks(
                            onBell: () => bells++,
                            onOpenMember: members.add,
                            onOpenTag: tags.add,
                            onOpenTopic: (t) => topics.add(t.slug),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
    if (start) {
      await tester.runAsync(controller.start);
      await settle(tester);
    }
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  Future<void> tapKey(WidgetTester tester, String k) async {
    await tester.ensureVisible(key(k));
    await tester.pumpAndSettle();
    await tester.tap(key(k));
    await settle(tester);
  }

  /// The words typed into the reply box, and the arrow pressed.
  Future<void> write(WidgetTester tester, String text) async {
    await tester.enterText(key('reply-input'), text);
    await tester.pump();
  }

  Future<void> send(WidgetTester tester) async {
    await tester.tap(key('reply-send'));
    await settle(tester);
  }

  Finder snack(String text) => find.descendant(of: find.byType(SnackBar), matching: find.textContaining(text));

  group('reading a discussion', () {
    testWidgets('it draws what the forum holds: filing, title, numbers, author, whole body, tags, reactions', (
      tester,
    ) async {
      await pumpThread(tester);
      expect(find.text('Discussion'), findsOneWidget); // the bar
      expect(find.text('Implementing IoT sensors for HVAC efficiency: Best practices?'), findsOneWidget);
      expect(find.text('ESG & Sustainability'), findsOneWidget);
      expect(find.text('Sustainability'), findsOneWidget);
      expect(find.text('Question'), findsOneWidget);
      expect(find.text('Sarah Jenkins'), findsOneWidget);
      expect(find.text('Senior Facilities Manager at Google'), findsOneWidget);
      expect(find.text('Follow'), findsOneWidget);
      expect(find.textContaining('4,210 views'), findsOneWidget);
      expect(find.textContaining('Still unanswered'), findsOneWidget);
      // The body keeps the website editor's shape: bold, italic, a bulleted list.
      expect(find.textContaining('sensors', findRichText: true), findsWidgets);
      expect(find.text('BMS'), findsOneWidget);
      expect(find.text('BACnet'), findsOneWidget);
      expect(find.text('#HVAC'), findsOneWidget);
      expect(find.text('#PropTech'), findsOneWidget);
      expect(find.text('12 reactions'), findsOneWidget);
      expect(find.text('6 answers'), findsOneWidget);
    });

    testWidgets('the read is counted once, a pull to refresh does not count it again', (tester) async {
      await pumpThread(tester);
      expect(world.viewCalls, 1);
      await tester.runAsync(controller.refresh);
      await settle(tester);
      expect(world.viewCalls, 1);
      expect(api.to('GET', '/forum/threads/slug-q').length, 2);
    });

    testWidgets('the card the list had is drawn while the page is read', (tester) async {
      final gated = GatedForum({...ForumWorld().routes()}, 'GET /forum/threads/slug-q');
      final preview = FeedPost(
        id: ForumWorld.id,
        slug: ForumWorld.slug,
        author: const FeedAuthor(id: 'u-sarah', name: 'Sarah Jenkins', headline: 'Facilities lead'),
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        title: 'A title from the list',
        body: 'The list excerpt.',
        comments: 6,
      );
      await pumpThread(tester, fake: gated, preview: preview, start: false);
      Future<void>? started;
      await tester.runAsync(() async {
        started = controller.start();
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pump();
      expect(find.text('A title from the list'), findsOneWidget);
      expect(find.text('The list excerpt.'), findsOneWidget);
      gated.gate.complete();
      await tester.runAsync(() async {
        await started;
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pumpAndSettle();
      expect(find.text('The list excerpt.'), findsNothing);
      expect(find.text('Implementing IoT sensors for HVAC efficiency: Best practices?'), findsOneWidget);
    });

    testWidgets('a discussion that is not there says so and offers no retry', (tester) async {
      final w = ForumWorld()..refusals['GET /forum/threads/slug-q'] = (404, 'Discussion not found');
      await pumpThread(tester, custom: w);
      expect(find.text("This discussion isn't here"), findsOneWidget);
      expect(key('message-action'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('a failed read says why, and Try again reads it', (tester) async {
      final w = ForumWorld()..refusals['GET /forum/threads/slug-q'] = (500, 'The forum is resting');
      await pumpThread(tester, custom: w);
      expect(find.text("Couldn't load this discussion"), findsOneWidget);
      expect(find.text('The forum is resting'), findsOneWidget);
      w.refusals.clear();
      await tester.tap(key('message-action'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await settle(tester);
      expect(find.text('Implementing IoT sensors for HVAC efficiency: Best practices?'), findsOneWidget);
    });

    testWidgets('a locked discussion says so and the box gives the reason instead of a field', (tester) async {
      await pumpThread(tester, custom: ForumWorld(status: 'LOCKED'));
      expect(find.text('Locked'), findsWidgets);
      expect(find.text('This discussion is locked, so it is not taking new replies.'), findsOneWidget);
      expect(key('reply-input'), findsNothing);
      // Still readable.
      expect(find.text('Spot on Priya.'), findsOneWidget);
    });

    testWidgets('an archived discussion takes no replies either', (tester) async {
      await pumpThread(tester, custom: ForumWorld(status: 'ARCHIVED'));
      expect(find.text('Archived'), findsOneWidget);
      expect(find.text('This discussion has been archived.'), findsWidgets);
      expect(key('reply-input'), findsNothing);
    });

    testWidgets('a moderator may reply to a locked discussion', (tester) async {
      await pumpThread(tester, custom: ForumWorld(status: 'LOCKED', canModerate: true));
      expect(key('reply-input'), findsOneWidget);
    });

    testWidgets('a discussion waiting for review says so to its author, and shows no replies', (tester) async {
      await pumpThread(
        tester,
        custom: ForumWorld(moderation: 'PENDING', canEdit: true, authorId: 'me'),
      );
      expect(find.text('Waiting for review'), findsOneWidget);
      expect(key('replies-heading'), findsNothing);
      expect(api.to('GET', '/forum/threads/slug-q/replies'), isEmpty);
      expect(find.text('This discussion is still awaiting review.'), findsOneWidget);
    });

    testWidgets('a discussion with no replies says to be the first', (tester) async {
      final w = ForumWorld()
        ..page1 = []
        ..replyCount = 0;
      await pumpThread(tester, custom: w);
      expect(find.text('0 answers'), findsOneWidget);
      expect(key('replies-empty'), findsOneWidget);
      expect(find.text('Be the first to share what you know.'), findsOneWidget);
    });

    testWidgets('a file that is not a photo is a tile that opens it; a poll draws its bars without View Discussion', (
      tester,
    ) async {
      final w = ForumWorld(
        withPoll: true,
        attachment: {'uploadId': 'spec.pdf', 'fileName': 'HVAC spec.pdf', 'fileSize': 77000},
      )..myOption = 'o3';
      await pumpThread(tester, custom: w);
      expect(find.text('HVAC spec.pdf · 75 KB'), findsOneWidget);
      await tapKey(tester, 'thread-attachment');
      expect(launched.single.path, '/uploads/spec.pdf');
      expect(find.text('Archibus (Your vote)'), findsOneWidget);
      expect(find.text('View Discussion'), findsNothing);
    });

    testWidgets('a link in the body opens the browser; one that is not http, https or mailto is not a link', (
      tester,
    ) async {
      final w = ForumWorld(
        bodyHtml: '<p>See <a href="https://example.com/spec">the spec</a> and <a href="javascript:x()">this</a>.</p>',
      );
      await pumpThread(tester, custom: w);
      final rich = tester
          .widgetList<RichText>(find.byType(RichText))
          .firstWhere((r) => r.text.toPlainText().startsWith('See the spec'));
      final spans = <TextSpan>[];
      rich.text.visitChildren((span) {
        if (span is TextSpan) spans.add(span);
        return true;
      });
      final link = spans.firstWhere((s) => s.text == 'the spec');
      (link.recognizer! as TapGestureRecognizer).onTap!();
      await settle(tester);
      expect(launched.single.toString(), 'https://example.com/spec');
      expect(spans.firstWhere((s) => s.text == 'this').recognizer, isNull);
    });
  });

  group('the replies', () {
    testWidgets('they hang off one line, an answer stepped in under the reply it answers, with the author\'s role', (
      tester,
    ) async {
      await pumpThread(tester);
      expect(find.text('Spot on Priya.'), findsOneWidget);
      expect(find.text('Thanks Arvind.'), findsOneWidget);
      expect(find.text('Kept the old controllers.'), findsOneWidget);
      expect(find.text('Pilot on one floor first.'), findsOneWidget);
      // Arvind's headline is "General Counsel at Brookfield Properties": the role in the chip, the company under the name.
      expect(find.text('General Counsel'), findsWidgets);
      expect(find.textContaining('Brookfield Properties'), findsWidgets);
      // Depth: the answer sits to the right of the reply it answers.
      final r1 = tester.getTopLeft(find.text('Spot on Priya.')).dx;
      final r2 = tester.getTopLeft(find.text('Thanks Arvind.')).dx;
      final r3 = tester.getTopLeft(find.text('Kept the old controllers.')).dx;
      expect(r2 - r1, closeTo(20, 1));
      expect(r3 - r2, closeTo(20, 1));
      expect(tester.getTopLeft(find.text('Pilot on one floor first.')).dx, closeTo(r1, 1));
    });

    testWidgets('a pending reply of the reader is marked, and the accepted answer is tinted and says so', (
      tester,
    ) async {
      final w = ForumWorld()..acceptedReplyId = 'r4';
      // The forum lists the accepted answer first among its siblings.
      w.page1[1]['accepted'] = true;
      w.page1.insert(0, w.page1.removeAt(1));
      w.page1[2]['moderation'] = 'PENDING';
      await pumpThread(tester, custom: w);
      expect(key('reply-accepted'), findsOneWidget);
      expect(key('reply-pending'), findsOneWidget);
      expect(find.text('Answered'), findsOneWidget);
      // The accepted answer is first.
      expect(
        tester.getTopLeft(find.text('Pilot on one floor first.')).dy <
            tester.getTopLeft(find.text('Spot on Priya.')).dy,
        isTrue,
      );
    });

    testWidgets('"Show more replies" reads the next page and puts each reply under its parent', (tester) async {
      final w = ForumWorld()
        ..replyCount = 8
        ..page2 = [
          // r1's answer on page 2: the forum promotes it to the top of its page.
          replyJson(
            'p2a',
            by: 'Vikram Iyer',
            authorId: 'u-vik',
            headline: null,
            body: 'Late answer under Arvind.',
            age: const Duration(minutes: 2),
          )..['parentId'] = 'r1',
          replyJson(
            'p2b',
            by: 'Karthik S',
            authorId: 'u-kar',
            headline: null,
            body: 'A new root on page two.',
            age: const Duration(minutes: 1),
          ),
        ];
      await pumpThread(tester, custom: w);
      expect(key('replies-more'), findsOneWidget);
      expect(find.text('Late answer under Arvind.'), findsNothing);
      await tapKey(tester, 'replies-more');
      expect(key('replies-more'), findsNothing);
      expect(find.text('Late answer under Arvind.'), findsOneWidget);
      expect(find.text('A new root on page two.'), findsOneWidget);
      expect(controller.totalReplies, 8);
      // The late answer is stepped in under Arvind's reply; the new root is at the top level.
      final root = tester.getTopLeft(find.text('Spot on Priya.')).dx;
      expect(tester.getTopLeft(find.text('Late answer under Arvind.')).dx, closeTo(root + 20, 1));
      expect(tester.getTopLeft(find.text('A new root on page two.')).dx, closeTo(root, 1));
      expect(api.to('GET', '/forum/threads/slug-q/replies').map((o) => o.queryParameters['page']), [1, 2]);
    });

    testWidgets('a page of replies that fails says so, keeps the ones read, and Try again reads it', (tester) async {
      final w = ForumWorld()
        ..replyCount = 7
        ..page2 = [replyJson('p2b', by: 'Karthik S', authorId: 'u-kar', headline: null, body: 'Page two.')];
      var failing = true;
      final base = w.routes();
      await pumpThread(
        tester,
        custom: w,
        extra: {
          ...base,
          'GET /forum/threads/slug-q/replies': (o) {
            if (((o.queryParameters['page'] as int?) ?? 1) == 2 && failing) return (503, '{"message":"Busy"}');
            return base['GET /forum/threads/slug-q/replies']!(o);
          },
        },
      );
      await tapKey(tester, 'replies-more');
      expect(find.text("Couldn't load more. Try again"), findsOneWidget);
      expect(find.text('Spot on Priya.'), findsOneWidget);
      failing = false;
      await tapKey(tester, 'replies-more');
      expect(find.text('Page two.'), findsOneWidget);
    });

    testWidgets('a link to one reply reads pages until it is there and brings it into view', (tester) async {
      final w = ForumWorld()
        ..replyCount = 8
        ..page2 = [
          replyJson('p2b', by: 'Karthik S', authorId: 'u-kar', headline: null, body: 'The one the link named.'),
        ];
      await pumpThread(tester, custom: w, focus: 'p2b', height: 900);
      expect(controller.focusFound, isTrue);
      expect(find.text('The one the link named.'), findsOneWidget);
      // It is on screen (the page is only 450 dp tall), not left far below.
      final y = tester.getTopLeft(find.text('The one the link named.')).dy;
      expect(y, inInclusiveRange(0, 900));
    });
  });

  group('what a reader does to the discussion', () {
    testWidgets("Like reacts at once, again takes it back, and a refusal puts it back with the forum's sentence", (
      tester,
    ) async {
      await pumpThread(tester);
      expect(find.text('12 reactions'), findsOneWidget);
      await tapKey(tester, 'thread-like');
      expect(find.text('13 reactions'), findsOneWidget);
      expect(world.myReaction, 'LIKE');
      expect(api.bodyOf('POST', '/forum/threads/t-q/vote'), {'value': 1, 'reaction': 'LIKE'});
      await tapKey(tester, 'thread-like');
      expect(find.text('12 reactions'), findsOneWidget);
      expect(api.count('DELETE', '/forum/threads/t-q/vote'), 1);
      world.refusals['POST /forum/threads/t-q/vote'] = (400, 'Not today.');
      await tapKey(tester, 'thread-like');
      expect(snack('Not today.'), findsOneWidget);
      expect(find.text('12 reactions'), findsOneWidget);
      expect(controller.post!.myReaction, isNull);
    });

    testWidgets('holding Like offers the five reactions; one is sent, the same one again takes it back', (
      tester,
    ) async {
      await pumpThread(tester);
      await tester.longPress(key('thread-like'));
      await tester.pumpAndSettle();
      for (final kind in ['LIKE', 'CELEBRATE', 'SUPPORT', 'INSIGHTFUL', 'SUSTAINABLE']) {
        expect(key('reaction:$kind'), findsOneWidget);
      }
      await tester.tap(key('reaction:CELEBRATE'));
      await settle(tester);
      expect(api.bodyOf('POST', '/forum/threads/t-q/vote'), {'value': 1, 'reaction': 'CELEBRATE'});
      expect(controller.post!.myReaction, ReactionKind.celebrate);
      expect(find.text('Celebrate'), findsOneWidget);
      await tester.longPress(key('thread-like'));
      await tester.pumpAndSettle();
      await tester.tap(key('reaction:CELEBRATE'));
      await settle(tester);
      expect(controller.post!.myReaction, isNull);
      expect(api.count('DELETE', '/forum/threads/t-q/vote'), 1);
      // Moving to another reaction sends that one.
      await tester.longPress(key('thread-like'));
      await tester.pumpAndSettle();
      await tester.tap(key('reaction:SUPPORT'));
      await settle(tester);
      expect(world.myReaction, 'SUPPORT');
    });

    testWidgets('a member cannot react to their own discussion: the page says so and asks nothing', (tester) async {
      await pumpThread(tester, custom: ForumWorld(authorId: 'me', canEdit: true));
      await tapKey(tester, 'thread-like');
      expect(snack('You cannot vote on your own discussion.'), findsOneWidget);
      expect(api.count('POST', '/forum/threads/t-q/vote'), 0);
      // There is nobody to follow, either.
      expect(key('thread-follow-author'), findsNothing);
    });

    testWidgets("Save keeps the discussion among the reader's saves, again lets it go, a refusal leaves it", (
      tester,
    ) async {
      await pumpThread(tester);
      await tapKey(tester, 'thread-save');
      expect(world.saved, isTrue);
      expect(find.text('Saved'), findsOneWidget);
      await tapKey(tester, 'thread-save');
      expect(world.saved, isFalse);
      expect(find.text('Save'), findsOneWidget);
      world.refusals['POST /forum/threads/t-q/save'] = (500, 'No saves now.');
      await tapKey(tester, 'thread-save');
      expect(snack('No saves now.'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('"Notify me" follows the discussion, again stops, a refusal leaves it', (tester) async {
      await pumpThread(tester);
      expect(find.text('Notify me'), findsOneWidget);
      await tapKey(tester, 'thread-subscribe');
      expect(world.subscribed, isTrue);
      expect(find.text('Notifying'), findsOneWidget);
      await tapKey(tester, 'thread-subscribe');
      expect(world.subscribed, isFalse);
      world.refusals['POST /forum/threads/t-q/subscribe'] = (500, 'Not now.');
      await tapKey(tester, 'thread-subscribe');
      expect(find.text('Notify me'), findsOneWidget);
      expect(snack('Not now.'), findsOneWidget);
    });

    testWidgets('Follow follows the author, again unfollows, a refusal keeps it', (tester) async {
      await pumpThread(tester);
      await tapKey(tester, 'thread-follow-author');
      expect(world.following, {'u-sarah'});
      expect(find.text('Following'), findsOneWidget);
      await tapKey(tester, 'thread-follow-author');
      expect(world.following, isEmpty);
      expect(find.text('Follow'), findsOneWidget);
      world.refusals['POST /members/u-sarah/follow'] = (400, 'You cannot follow that member.');
      await tapKey(tester, 'thread-follow-author');
      expect(snack('You cannot follow that member.'), findsOneWidget);
      expect(find.text('Follow'), findsOneWidget);
    });

    testWidgets('a poll option votes or moves the vote, the bars follow; the same option asks nothing', (tester) async {
      await pumpThread(tester, custom: ForumWorld(withPoll: true, kind: 'DISCUSSION'));
      expect(find.text('Archibus'), findsOneWidget);
      await tapKey(tester, 'poll-option:o2');
      expect(api.bodyOf('POST', '/forum/threads/t-q/poll/vote'), {'optionId': 'o2'});
      expect(find.text('Planon (Your vote)'), findsOneWidget);
      await tapKey(tester, 'poll-option:o3');
      expect(find.text('Archibus (Your vote)'), findsOneWidget);
      expect(find.text('Planon (Your vote)'), findsNothing);
      final calls = api.count('POST', '/forum/threads/t-q/poll/vote');
      await tapKey(tester, 'poll-option:o3');
      expect(api.count('POST', '/forum/threads/t-q/poll/vote'), calls);
    });

    testWidgets('a poll of a locked discussion takes no vote', (tester) async {
      await pumpThread(
        tester,
        custom: ForumWorld(withPoll: true, kind: 'DISCUSSION', status: 'LOCKED'),
      );
      await tapKey(tester, 'poll-option:o2');
      expect(api.count('POST', '/forum/threads/t-q/poll/vote'), 0);
      expect(find.textContaining('Closed'), findsOneWidget);
    });

    testWidgets('a refused poll vote says why and leaves the bars', (tester) async {
      final w = ForumWorld(withPoll: true, kind: 'DISCUSSION')
        ..refusals['POST /forum/threads/t-q/poll/vote'] = (400, 'This discussion is closed, and so is its poll.');
      await pumpThread(tester, custom: w);
      await tapKey(tester, 'poll-option:o2');
      expect(snack('closed, and so is its poll'), findsOneWidget);
      expect(find.text('Planon (Your vote)'), findsNothing);
    });

    testWidgets("Share hands the share sheet the title and the discussion's link; Copy link copies it", (tester) async {
      await pumpThread(tester);
      await tapKey(tester, 'thread-share');
      expect(shared.single['text'], contains('Implementing IoT sensors for HVAC efficiency: Best practices?'));
      expect(shared.single['text'], endsWith('https://icr.org.in/community/slug-q'));
      await tapKey(tester, 'thread-menu');
      await tester.tap(key('menu-copy'));
      await settle(tester);
      expect(copied, 'https://icr.org.in/community/slug-q');
      expect(find.text('Link copied'), findsOneWidget);
    });

    testWidgets("the three dots offer what the reader may do: report someone else's, delete one's own", (tester) async {
      await pumpThread(tester);
      await tapKey(tester, 'thread-menu');
      expect(key('menu-report'), findsOneWidget);
      expect(key('menu-delete'), findsNothing);
      expect(key('menu-edit'), findsNothing);
      expect(key('menu-viewers'), findsOneWidget);
    });

    testWidgets('the three dots on one\'s own discussion offer Delete, not Report', (tester) async {
      await pumpThread(tester, custom: ForumWorld(authorId: 'me', canEdit: true));
      await tapKey(tester, 'thread-menu');
      expect(key('menu-delete'), findsOneWidget);
      expect(key('menu-report'), findsNothing);
      expect(key('menu-edit'), findsNothing); // no editor given
    });

    testWidgets('Edit opens the editor; Delete asks first, then takes the discussion down and leaves', (tester) async {
      ForumThread? offered;
      await pumpThread(
        tester,
        custom: ForumWorld(authorId: 'me', canEdit: true),
        onEdit: (thread) async {
          offered = thread;
          return null;
        },
      );
      await tapKey(tester, 'thread-menu');
      await tester.tap(key('menu-edit'));
      await settle(tester);
      expect(offered?.id, ForumWorld.id);

      await tapKey(tester, 'thread-menu');
      await tester.tap(key('menu-delete'));
      await settle(tester);
      expect(find.text('Delete this discussion?'), findsOneWidget);
      await tester.tap(key('confirm-cancel'));
      await settle(tester);
      expect(api.count('DELETE', '/forum/threads/t-q'), 0);

      await tapKey(tester, 'thread-menu');
      await tester.tap(key('menu-delete'));
      await settle(tester);
      await tester.tap(key('confirm-yes'));
      await settle(tester);
      expect(api.count('DELETE', '/forum/threads/t-q'), 1);
      expect(popped?.deleted, isTrue);
      expect(find.byType(ThreadScreen), findsNothing);
    });

    testWidgets('a refused delete stays on the page and says why', (tester) async {
      final w = ForumWorld(authorId: 'me', canEdit: true)
        ..refusals['DELETE /forum/threads/t-q'] = (403, 'You can only delete your own discussions.');
      await pumpThread(tester, custom: w);
      await tapKey(tester, 'thread-menu');
      await tester.tap(key('menu-delete'));
      await settle(tester);
      await tester.tap(key('confirm-yes'));
      await settle(tester);
      expect(snack('You can only delete your own discussions.'), findsOneWidget);
      expect(find.byType(ThreadScreen), findsOneWidget);
    });

    testWidgets('"N reactions" lists who reacted; the views count lists who read it', (tester) async {
      await pumpThread(tester);
      await tapKey(tester, 'thread-reactions');
      expect(find.text('Reactions'), findsOneWidget);
      expect(find.text('Anita Raghavan'), findsWidgets);
      expect(find.text('Karthik S'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tapKey(tester, 'thread-views');
      expect(find.text('Who viewed'), findsWidgets);
      expect(find.text('Vikram Iyer'), findsOneWidget);
      expect(find.text('4 other members read it with a private profile.'), findsOneWidget);
    });

    testWidgets(
      'a member, the bell, a tag and a topic go where the app wires them; leaving hands the list what was done',
      (tester) async {
        await pumpThread(tester);
        await tester.tap(key('thread-author'));
        await tester.pumpAndSettle();
        expect(members, ['u-sarah']);
        await tester.tap(find.bySemanticsLabel('Notifications, 2 unread').first);
        await tester.pumpAndSettle();
        expect(bells, 1);
        await tapKey(tester, 'thread-like');
        await tapKey(tester, 'thread-tag:#HVAC');
        expect(tags, ['HVAC']);
        expect(popped?.post?.myReaction, ReactionKind.like);
        expect(popped?.deleted, isFalse);
      },
    );

    testWidgets('the category chip opens that topic', (tester) async {
      await pumpThread(tester);
      await tapKey(tester, 'thread-category');
      expect(topics, ['c']);
    });
  });

  group('the replies the reader sends and acts on', () {
    Finder tile(String words) => find.ancestor(of: find.text(words), matching: find.byType(ReplyTile));

    testWidgets('a reply is sent under the discussion as escaped paragraphs, shown, counted, and the box clears', (
      tester,
    ) async {
      await pumpThread(tester);
      await write(tester, 'Hello <b>there</b> & welcome\n\nSecond paragraph');
      await send(tester);
      expect(api.bodyOf('POST', '/forum/threads/t-q/replies'), {
        'bodyHtml': '<p>Hello &lt;b&gt;there&lt;/b&gt; &amp; welcome</p><p>Second paragraph</p>',
      });
      expect(find.text('7 answers'), findsOneWidget);
      expect(tester.widget<TextField>(key('reply-input')).controller!.text, isEmpty);
      expect(controller.post!.comments, 7);
    });

    testWidgets('an empty box sends nothing', (tester) async {
      await pumpThread(tester);
      await write(tester, '   ');
      await send(tester);
      expect(api.count('POST', '/forum/threads/t-q/replies'), 0);
    });

    testWidgets('Reply on a reply addresses that person and sends under that reply, stepped in', (tester) async {
      await pumpThread(tester);
      await tapKey(tester, 'reply-reply:r2');
      expect(find.text('Replying to Priya Nambiar'), findsOneWidget);
      expect(find.text('Reply to Priya Nambiar...'), findsOneWidget);
      await write(tester, 'Glad it helped');
      await send(tester);
      expect(api.bodyOf('POST', '/forum/threads/t-q/replies'), {'bodyHtml': '<p>Glad it helped</p>', 'parentId': 'r2'});
      final r2 = tester.getTopLeft(find.text('Thanks Arvind.')).dx;
      expect(tester.getTopLeft(find.text('Glad it helped')).dx, closeTo(r2 + 20, 1));
      // The target is dropped once sent.
      expect(find.text('Replying to Priya Nambiar'), findsNothing);
    });

    testWidgets('the x drops whom the reply answers', (tester) async {
      await pumpThread(tester);
      await tapKey(tester, 'reply-reply:r2');
      await tester.tap(key('reply-target-clear'));
      await tester.pump();
      expect(find.text('Replying to Priya Nambiar'), findsNothing);
      expect(find.text('Write a reply...'), findsOneWidget);
    });

    testWidgets('a refused reply keeps what was typed and says why above the box', (tester) async {
      final w = ForumWorld()..refusals['POST /forum/threads/t-q/replies'] = (403, 'You may not reply just now.');
      await pumpThread(tester, custom: w);
      await write(tester, 'Please keep me');
      await send(tester);
      expect(key('reply-error'), findsOneWidget);
      expect(find.text('You may not reply just now.'), findsOneWidget);
      expect(tester.widget<TextField>(key('reply-input')).controller!.text, 'Please keep me');
      expect(find.text('7 answers'), findsNothing);
      w.refusals.clear();
      await send(tester);
      expect(find.text('7 answers'), findsOneWidget);
      expect(key('reply-error'), findsNothing);
    });

    testWidgets(
      "Like on a reply likes at once, takes back, and a refusal restores the count; one's own is refused without asking",
      (tester) async {
        await pumpThread(tester);
        await tapKey(tester, 'reply-like:r4');
        expect(api.bodyOf('POST', '/forum/replies/r4/vote'), {'value': 1, 'reaction': 'LIKE'});
        expect(find.descendant(of: tile('Pilot on one floor first.'), matching: find.text('2')), findsOneWidget);
        await tapKey(tester, 'reply-like:r4');
        expect(api.count('DELETE', '/forum/replies/r4/vote'), 1);
        expect(find.descendant(of: tile('Pilot on one floor first.'), matching: find.text('1')), findsOneWidget);
        world.refusals['POST /forum/replies/r4/vote'] = (500, 'Not now.');
        await tapKey(tester, 'reply-like:r4');
        expect(snack('Not now.'), findsOneWidget);
        expect(find.descendant(of: tile('Pilot on one floor first.'), matching: find.text('1')), findsOneWidget);

        await tapKey(tester, 'reply-like:r5');
        expect(snack('You cannot vote on your own reply.'), findsOneWidget);
        expect(api.count('POST', '/forum/replies/r5/vote'), 0);
      },
    );

    testWidgets('the reader can edit their own reply: the words come back to the box, a save changes the tile', (
      tester,
    ) async {
      await pumpThread(tester);
      await tapKey(tester, 'reply-more:r5');
      expect(key('reply-menu-edit'), findsOneWidget);
      await tester.tap(key('reply-menu-edit'));
      await settle(tester);
      expect(find.text('Editing your reply'), findsOneWidget);
      expect(tester.widget<TextField>(key('reply-input')).controller!.text, 'Mine: check the PICS.');
      await write(tester, 'Mine: check the PICS and the BACnet profile.');
      await send(tester);
      expect(api.bodyOf('PATCH', '/forum/replies/r5'), {
        'bodyHtml': '<p>Mine: check the PICS and the BACnet profile.</p>',
      });
      expect(find.text('Mine: check the PICS and the BACnet profile.'), findsOneWidget);
      expect(find.textContaining('(edited)'), findsOneWidget);
      expect(find.text('Editing your reply'), findsNothing);
    });

    testWidgets('saving an edit that changes nothing sends nothing; the x leaves the edit and clears the box', (
      tester,
    ) async {
      await pumpThread(tester);
      await tapKey(tester, 'reply-more:r5');
      await tester.tap(key('reply-menu-edit'));
      await settle(tester);
      await send(tester);
      expect(api.count('PATCH', '/forum/replies/r5'), 0);
      await tapKey(tester, 'reply-more:r5');
      await tester.tap(key('reply-menu-edit'));
      await settle(tester);
      await tester.tap(key('reply-target-clear'));
      await tester.pump();
      expect(tester.widget<TextField>(key('reply-input')).controller!.text, isEmpty);
    });

    testWidgets('the reader can delete their own reply after confirming, and not by accident', (tester) async {
      await pumpThread(tester);
      await tapKey(tester, 'reply-more:r5');
      await tester.tap(key('reply-menu-delete'));
      await settle(tester);
      expect(find.text('Delete your reply?'), findsOneWidget);
      await tester.tap(key('confirm-cancel'));
      await settle(tester);
      expect(api.count('DELETE', '/forum/replies/r5'), 0);
      expect(find.text('Mine: check the PICS.'), findsOneWidget);

      await tapKey(tester, 'reply-more:r5');
      await tester.tap(key('reply-menu-delete'));
      await settle(tester);
      await tester.tap(key('confirm-yes'));
      await settle(tester);
      expect(api.count('DELETE', '/forum/replies/r5'), 1);
      expect(find.text('Mine: check the PICS.'), findsNothing);
      expect(find.text('5 answers'), findsOneWidget);
      expect(controller.post!.comments, 5);
    });

    testWidgets("someone else's reply offers Report and Copy link, never Edit or Delete", (tester) async {
      await pumpThread(tester);
      await tapKey(tester, 'reply-more:r4');
      expect(key('reply-menu-report'), findsOneWidget);
      expect(key('reply-menu-copy'), findsOneWidget);
      expect(key('reply-menu-edit'), findsNothing);
      expect(key('reply-menu-delete'), findsNothing);
      await tester.tap(key('reply-menu-copy'));
      await settle(tester);
      expect(copied, 'https://icr.org.in/community/slug-q#reply-r4');
    });

    testWidgets('the asker accepts an answer: it is marked, tinted, first, and the discussion reads Answered', (
      tester,
    ) async {
      await pumpThread(tester, custom: ForumWorld(authorId: 'me', canEdit: true));
      // Not on one's own reply, on everyone else's.
      expect(key('reply-accept:r5'), findsNothing);
      expect(key('reply-accept:r4'), findsOneWidget);
      await tapKey(tester, 'reply-accept:r4');
      expect(api.count('POST', '/forum/threads/t-q/accept/r4'), 1);
      expect(key('reply-accepted'), findsOneWidget);
      expect(find.text('Answered'), findsOneWidget);
      expect(find.textContaining('Still unanswered'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Pilot on one floor first.')).dy <
            tester.getTopLeft(find.text('Spot on Priya.')).dy,
        isTrue,
      );
      // Moving the answer moves the mark.
      await tapKey(tester, 'reply-accept:r1');
      expect(key('reply-accepted'), findsOneWidget);
      expect(world.acceptedReplyId, 'r1');
    });

    testWidgets("a refused accept puts the answer back with the forum's sentence", (tester) async {
      final w = ForumWorld(authorId: 'me', canEdit: true)
        ..refusals['POST /forum/threads/t-q/accept/r4'] = (403, 'Only the person who asked can mark the answer.');
      await pumpThread(tester, custom: w);
      await tapKey(tester, 'reply-accept:r4');
      expect(snack('Only the person who asked can mark the answer.'), findsOneWidget);
      expect(key('reply-accepted'), findsNothing);
      expect(find.text('Answered'), findsNothing);
    });

    testWidgets('someone who did not ask has no Accept answer', (tester) async {
      await pumpThread(tester, custom: ForumWorld());
      expect(find.text('Accept answer'), findsNothing);
    });

    testWidgets('a discussion that is not a question has no Accept answer, even for its author', (tester) async {
      await pumpThread(
        tester,
        custom: ForumWorld(authorId: 'me', kind: 'DISCUSSION', canEdit: true),
      );
      expect(find.text('Accept answer'), findsNothing);
    });

    testWidgets('Report on a reply sends the reason and the note; a refusal shows in the sheet and keeps the note', (
      tester,
    ) async {
      final w = ForumWorld()..refusals['POST /forum/reports'] = (400, 'You have already reported this.');
      await pumpThread(tester, custom: w);
      await tapKey(tester, 'reply-more:r4');
      await tester.tap(key('reply-menu-report'));
      await settle(tester);
      expect(find.text('Report this reply'), findsOneWidget);
      await tester.tap(key('report-reason:OFF_TOPIC'));
      await tester.pump();
      await tester.enterText(key('report-note'), 'Nothing about HVAC');
      await tester.tap(key('report-send'));
      await settle(tester);
      expect(find.text('You have already reported this.'), findsOneWidget);
      expect(tester.widget<TextField>(key('report-note')).controller!.text, 'Nothing about HVAC');
      expect(find.text('Report this reply'), findsOneWidget);
      w.refusals.clear();
      await tester.tap(key('report-send'));
      await settle(tester);
      expect(api.bodyOf('POST', '/forum/reports'), {
        'replyId': 'r4',
        'reason': 'OFF_TOPIC',
        'note': 'Nothing about HVAC',
      });
      expect(find.text('Report this reply'), findsNothing);
      expect(snack('A moderator will take a look.'), findsOneWidget);
    });

    testWidgets('Report on the discussion names the discussion, with no note when none is typed', (tester) async {
      await pumpThread(tester);
      await tapKey(tester, 'thread-menu');
      await tester.tap(key('menu-report'));
      await settle(tester);
      expect(find.text('Report this discussion'), findsOneWidget);
      await tester.tap(key('report-send'));
      await settle(tester);
      expect(api.bodyOf('POST', '/forum/reports'), {'threadId': 't-q', 'reason': 'SPAM'});
    });

    testWidgets("a reply's photo opens its author", (tester) async {
      await pumpThread(tester);
      final avatar = find
          .descendant(of: tile('Pilot on one floor first.'), matching: find.byType(GestureDetector))
          .first;
      await tester.tap(avatar);
      await tester.pumpAndSettle();
      expect(members, ['u-anita']);
    });

    testWidgets('Back leaves the page and hands back the discussion as it is', (tester) async {
      await pumpThread(tester);
      await tester.tap(find.bySemanticsLabel('Back').first);
      await tester.pumpAndSettle();
      expect(find.byType(ThreadScreen), findsNothing);
      expect(popped?.post?.id, ForumWorld.id);
    });
  });
}
