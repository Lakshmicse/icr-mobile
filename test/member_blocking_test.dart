// Blocking a member (App Store guideline 1.2, Nov 2026): from a profile, the Settings list, and the feed dropping a
// blocked member's posts and replies at once. The thread page's Block items are tested in forum_thread_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/account/account_models.dart';
import 'package:icr_mobile/features/account/demo_account_repository.dart';
import 'package:icr_mobile/features/account/members/block_events.dart';
import 'package:icr_mobile/features/account/members/member_profile_screen.dart';
import 'package:icr_mobile/features/account/settings/blocked_members_screen.dart';
import 'package:icr_mobile/features/feed/demo_feed_repository.dart';
import 'package:icr_mobile/features/feed/feed_controller.dart';
import 'package:icr_mobile/features/feed/feed_models.dart';

import 'helpers/account_harness.dart';
import 'helpers/fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  final asha = MemberProfile(
    id: 'm-asha',
    firstName: 'Asha',
    lastName: 'Rao',
    headline: 'Head of Workplace',
    signedIn: true,
  );

  DemoAccountRepository repoWith(MemberProfile m) => DemoAccountRepository()
    ..members = {m.id: m}
    ..posts = {m.id: const []};

  Future<void> pumpProfile(WidgetTester tester, DemoAccountRepository repo) async {
    usePhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MemberProfileScreen(userId: 'm-asha', repository: repo),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('a member profile', () {
    testWidgets('More → Block asks first, blocks, and leaves only Unblock (no Follow, no Message)', (tester) async {
      final repo = repoWith(asha);
      await pumpProfile(tester, repo);
      expect(find.byKey(const Key('member.follow')), findsOneWidget);
      await tester.tap(find.byKey(const Key('member.more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('member.block')));
      await tester.pumpAndSettle();
      expect(find.text('Block Asha Rao?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirm-yes')));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('block:m-asha'));
      expect(find.text('Blocked by you'), findsOneWidget);
      expect(find.byKey(const Key('member.unblock')), findsOneWidget);
      expect(find.byKey(const Key('member.follow')), findsNothing);
      expect(find.byKey(const Key('member.message')), findsNothing);
    });

    testWidgets('a profile read as blocked offers Unblock, and Unblock brings Follow and Message back', (tester) async {
      final repo = repoWith(asha.withBlocked(true));
      await pumpProfile(tester, repo);
      await tester.tap(find.byKey(const Key('member.unblock')));
      await tester.pumpAndSettle();
      expect(find.text('Unblock Asha Rao?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirm-yes')));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('unblock:m-asha'));
      expect(find.byKey(const Key('member.follow')), findsOneWidget);
      expect(find.byKey(const Key('member.message')), findsOneWidget);
    });

    testWidgets('one\'s own profile has no Block', (tester) async {
      final repo = repoWith(
        MemberProfile(id: 'm-asha', firstName: 'Asha', lastName: 'Rao', signedIn: true, isOwner: true),
      );
      await pumpProfile(tester, repo);
      expect(find.byKey(const Key('member.more')), findsNothing);
    });
  });

  group('Settings → Blocked Members', () {
    testWidgets('lists the members blocked, and Unblock takes one off the list', (tester) async {
      final repo = repoWith(asha)..blockedIds.add('m-asha');
      usePhone(tester);
      await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: BlockedMembersScreen(repository: repo)));
      await tester.pumpAndSettle();
      expect(find.text('Asha Rao'), findsOneWidget);
      await tester.tap(find.byKey(const Key('blocked.unblock.m-asha')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-yes')));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('unblock:m-asha'));
      expect(find.byKey(const Key('blocked.none')), findsOneWidget);
    });

    testWidgets('with nobody blocked it says so', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(
        MaterialApp(theme: buildAppTheme(), home: BlockedMembersScreen(repository: DemoAccountRepository())),
      );
      await tester.pumpAndSettle();
      expect(find.text("You haven't blocked anyone."), findsOneWidget);
    });
  });

  group('the feed', () {
    FeedAuthor who(String id) => FeedAuthor(id: id, name: id);
    FeedReply reply(String id, String by, {List<FeedReply> children = const []}) =>
        FeedReply(id: id, author: who(by), body: id, createdAt: DateTime(2026), children: children);

    test('drops a blocked member\'s replies and moves the answers under them up a level', () {
      final tree = [
        reply('a', 'x', children: [reply('a1', 'y')]),
        reply('b', 'y'),
      ];
      final left = withoutAuthor(tree, 'x');
      expect(left.map((r) => r.id), ['a1', 'b']);
    });

    test('takes a blocked member\'s posts off the Home feed as soon as the block is made', () async {
      final feed = FeedController(DemoFeedRepository());
      await feed.refresh();
      expect(feed.posts, isNotEmpty);
      final author = feed.posts.first.author.id;
      BlockEvents.note(author, blocked: true);
      expect(feed.posts.where((p) => p.author.id == author), isEmpty);
      feed.dispose();
    });
  });
}
