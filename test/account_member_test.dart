import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/account/account_models.dart';
import 'package:icr_mobile/features/account/demo_account_repository.dart';
import 'package:icr_mobile/features/account/members/member_profile_screen.dart';
import 'package:icr_mobile/features/account/widgets/account_kit.dart' show CoverBand;

import 'helpers/account_harness.dart';
import 'helpers/fonts.dart';

/// Another member's public page: what it shows, and what Follow, Message,
/// Mentor profile, the chapters, councils, companies, discussions and links do.
void main() {
  setUpAll(() async {
    await loadAppFonts();
    CoverBand.loadArt = false;
  });

  final now = DateTime.utc(2026, 10, 26);

  /// A mentor with links and a verified credential, who the viewer does not follow yet.
  final mentor = MemberProfile(
    id: 'm-asha',
    firstName: 'Asha',
    lastName: 'Verma',
    profileSlug: 'asha-verma',
    headline: 'Director · Workplace · DLF',
    city: 'Gurugram',
    companyName: 'DLF',
    memberSince: '2026-03-02T00:00:00.000Z',
    about: 'Twenty years in workplace operations.',
    skills: const ['Workplace strategy'],
    languages: const ['English', 'Hindi'],
    yearsExperience: 20,
    experience: const [
      Experience(id: 'e1', title: 'Director', organisation: 'DLF', company: LinkedCompany(id: 'co-dlf', name: 'DLF'), startYear: 2018, isCurrent: true),
    ],
    education: const [Education(id: 'd1', institution: 'IIT Delhi', degree: 'B.Tech')],
    links: const ProfileLinks(linkedin: 'https://linkedin.com/in/asha', website: 'https://asha.example.com'),
    credentials: const [PublicCredential(name: 'Certified Facility Manager', code: 'CFM', issuer: 'IFMA', issuedAt: '2022-05-01T00:00:00.000Z', url: 'https://ifma.example/verify/1', verified: true)],
    reputation: 120,
    threads: 2,
    replies: 9,
    acceptedAnswers: 1,
    chapters: const [MemberGroup(slug: 'delhi', name: 'ICR Delhi Chapter', city: 'Delhi')],
    councils: const [MemberGroup(slug: 'workplace-experience', name: 'Workplace & Employee Experience Council')],
    mentorProfileId: 'mentor-9',
    follow: const FollowState(followers: 41, following: 12, viewerFollows: false),
    signedIn: true,
    readyForNextRole: true,
  );

  DemoAccountRepository repoWith(MemberProfile m, {List<ForumPost>? posts}) {
    final r = DemoAccountRepository();
    r.members = {m.id: m};
    r.posts = {m.id: posts ?? demoPosts};
    return r;
  }

  Future<void> pump(
    WidgetTester tester,
    DemoAccountRepository repo, {
    String userId = 'm-asha',
    void Function(String, MemberProfile)? onMessage,
    List<String>? log,
    List<String>? shared,
    List<Uri>? opened,
    VoidCallback? onEdit,
  }) async {
    usePhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MemberProfileScreen(
          key: ValueKey(userId),
          userId: userId,
          repository: repo,
          now: now,
          onMessage: onMessage,
          onOpenMentor: (id) => log?.add('mentor:$id'),
          onOpenCompany: (id) => log?.add('company:$id'),
          onOpenChapter: (s) => log?.add('chapter:$s'),
          onOpenCouncil: (s) => log?.add('council:$s'),
          onOpenThread: (s) => log?.add('thread:$s'),
          onEditProfile: onEdit,
          share: (text, subject) async => shared?.add('$subject|$text'),
          opener: (context, uri) async => opened?.add(uri),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 250, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  group('what the page shows', () {
    testWidgets('the header: name, headline, place, followers, since when, and the chips', (tester) async {
      await pump(tester, repoWith(mentor));
      expect(find.text('Asha Verma'), findsWidgets);
      expect(find.text('Director · Workplace · DLF'), findsOneWidget);
      expect(find.text('Gurugram · DLF'), findsOneWidget);
      expect(find.text('41 followers · 12 following · Member since Mar 2026'), findsOneWidget);
      expect(find.text('Mentor'), findsOneWidget);
      expect(find.text('Ready for a new role'), findsOneWidget);
      expect(find.text('20 yrs experience'), findsOneWidget);
    });

    testWidgets('each section the member chose to show', (tester) async {
      await pump(tester, repoWith(mentor));
      const detail = {
        'About': 'Twenty years in workplace operations.',
        'Education': 'IIT Delhi',
        'Licenses & certifications': 'Issued May 2022',
      };
      for (final t in ['About', 'Experience', 'Education', 'Licenses & certifications', 'Skills', 'Languages', 'Links', 'Chapters & councils', 'Community activity']) {
        await reveal(tester, find.text(t));
        expect(find.text(t), findsOneWidget);
        if (detail[t] != null) expect(find.text(detail[t]!), findsOneWidget);
      }
    });

    testWidgets('a section with nothing to show is left out', (tester) async {
      final bare = MemberProfile(id: 'm-bare', firstName: 'Bo', lastName: 'Ray', follow: const FollowState(followers: 0, following: 0, viewerFollows: false), signedIn: true);
      await pump(tester, repoWith(bare, posts: const []), userId: 'm-bare');
      expect(find.text('Bo Ray'), findsWidgets);
      for (final t in ['About', 'Experience', 'Education', 'Skills', 'Languages', 'Links', 'Community activity']) {
        expect(find.text(t), findsNothing);
      }
      expect(find.text('0 followers · 0 following'), findsOneWidget);
    });

    testWidgets('the id works as well as the slug', (tester) async {
      await pump(tester, repoWith(mentor), userId: 'asha-verma');
      expect(find.text('Asha Verma'), findsWidgets);
    });

    testWidgets('loading, then a page that is not available says so with Try again', (tester) async {
      final repo = DemoAccountRepository()..gate = Future<void>.delayed(const Duration(milliseconds: 300));
      usePhone(tester);
      await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: MemberProfileScreen(userId: 'nobody', repository: repo)));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('This profile is not available'), findsOneWidget);
      expect(find.text('It may be private, or the member may have left ICR.'), findsOneWidget);
      expect(find.byKey(const Key('account.retry')), findsOneWidget);
    });

    testWidgets('a failure that is not a 404 shows the API sentence', (tester) async {
      final repo = repoWith(mentor)..failures['member'] = ApiError('The server is busy.', statusCode: 503);
      await pump(tester, repo, userId: 'asha-verma');
      expect(find.text('The server is busy.'), findsOneWidget);
      repo.failures.clear();
      await tester.tap(find.byKey(const Key('account.retry')));
      await tester.pumpAndSettle();
      expect(find.text('Director · Workplace · DLF'), findsOneWidget);
    });

    testWidgets('the discussions failing leaves the page whole and says so', (tester) async {
      final repo = repoWith(mentor)..failures['memberPosts'] = ApiError('x', statusCode: 500);
      await pump(tester, repo);
      await reveal(tester, find.text('Community activity'));
      expect(find.text("Couldn't load their discussions."), findsOneWidget);
      expect(find.text('Asha Verma'), findsWidgets);
    });

    testWidgets('pull to refresh reads the page again', (tester) async {
      final repo = repoWith(mentor);
      await pump(tester, repo);
      await tester.fling(find.byType(ListView).first, const Offset(0, 400), 1000);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(repo.count('member'), 2);
    });
  });

  group('Follow and Message', () {
    testWidgets('Follow changes to Following at once, counts one more follower, and Following takes it back', (tester) async {
      final repo = repoWith(mentor);
      await pump(tester, repo);
      await tester.tap(find.byKey(const Key('member.follow')));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('follow:m-asha'));
      expect(find.text('Following'), findsOneWidget);
      expect(find.text('42 followers · 12 following · Member since Mar 2026'), findsOneWidget);

      await tester.tap(find.byKey(const Key('member.follow')));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('unfollow:m-asha'));
      expect(find.text('Follow'), findsOneWidget);
      expect(find.text('41 followers · 12 following · Member since Mar 2026'), findsOneWidget);
    });

    testWidgets('a refused follow goes back with the API sentence', (tester) async {
      final repo = repoWith(mentor)..failures['follow'] = ApiError('You can follow up to 5,000 people.', statusCode: 400);
      await pump(tester, repo);
      await tester.tap(find.byKey(const Key('member.follow')));
      await tester.pumpAndSettle();
      expect(find.text('You can follow up to 5,000 people.'), findsOneWidget);
      expect(find.text('Follow'), findsOneWidget);
      expect(find.text('41 followers · 12 following · Member since Mar 2026'), findsOneWidget);
      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pump();
      expect(find.byKey(const Key('member.error')), findsNothing);
    });

    testWidgets('Message opens (or finds) the thread and hands its id to the app', (tester) async {
      final repo = repoWith(mentor);
      final opened = <String>[];
      await pump(tester, repo, onMessage: (id, m) => opened.add('$id|${m.fullName}'));
      await tester.tap(find.byKey(const Key('member.message')));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('startConversation:m-asha'));
      expect(opened, ['conv-m-asha|Asha Verma']);
    });

    testWidgets('a refused Message shows the API sentence and opens nothing', (tester) async {
      final repo = repoWith(mentor)..failures['startConversation'] = ApiError('This member does not take messages.', statusCode: 403);
      final opened = <String>[];
      await pump(tester, repo, onMessage: (id, m) => opened.add(id));
      await tester.tap(find.byKey(const Key('member.message')));
      await tester.pumpAndSettle();
      expect(find.text('This member does not take messages.'), findsOneWidget);
      expect(opened, isEmpty);
    });

    testWidgets('Mentor profile opens the mentor by id; a member who does not mentor has no such button', (tester) async {
      final log = <String>[];
      await pump(tester, repoWith(mentor), log: log);
      await tester.tap(find.byKey(const Key('member.mentor')));
      await tester.pump();
      expect(log, ['mentor:mentor-9']);

      final plain = MemberProfile(id: 'm-p', firstName: 'Pia', lastName: 'Rao', follow: const FollowState(followers: 1, following: 1, viewerFollows: false), signedIn: true);
      await pump(tester, repoWith(plain), userId: 'm-p');
      expect(find.byKey(const Key('member.mentor')), findsNothing);
    });
  });

  group('the pages it opens', () {
    testWidgets('a role at a company on ICR opens the company; a role with none is not a button', (tester) async {
      final log = <String>[];
      await pump(tester, repoWith(mentor), log: log);
      await reveal(tester, find.byKey(const Key('exp.e1')));
      await tester.tap(find.byKey(const Key('exp.e1')));
      await tester.pump();
      expect(log, ['company:co-dlf']);
    });

    testWidgets('a chapter, a council and a discussion open by their slugs', (tester) async {
      final log = <String>[];
      await pump(tester, repoWith(mentor), log: log);
      await reveal(tester, find.byKey(const Key('chapter.delhi')));
      await tester.tap(find.byKey(const Key('chapter.delhi')));
      await tester.tap(find.byKey(const Key('council.workplace-experience')));
      await reveal(tester, find.byKey(const Key('post.post-1')));
      await tester.tap(find.byKey(const Key('post.post-1')));
      await tester.pump();
      expect(log, ['chapter:delhi', 'council:workplace-experience', 'thread:hybrid-occupancy-sensors']);
      expect(find.text('Which occupancy sensors held up in your hybrid floors?'), findsOneWidget);
      expect(find.textContaining('12 replies'), findsOneWidget);
    });

    testWidgets("the member's own links and credential link go to the phone's browser", (tester) async {
      final opened = <Uri>[];
      await pump(tester, repoWith(mentor), opened: opened);
      await reveal(tester, find.byKey(const Key('link.linkedinUrl')));
      expect(find.text('linkedin.com/in/asha'), findsOneWidget);
      await tester.tap(find.byKey(const Key('link.linkedinUrl')));
      await tester.tap(find.byKey(const Key('link.websiteUrl')));
      await reveal(tester, find.byKey(const Key('cred.0')));
      await tester.tap(find.byKey(const Key('cred.0')));
      await tester.pump();
      expect(opened.map((u) => u.toString()), ['https://linkedin.com/in/asha', 'https://asha.example.com', 'https://ifma.example/verify/1']);
    });

    testWidgets('Share hands the public link to the share sheet', (tester) async {
      final shared = <String>[];
      await pump(tester, repoWith(mentor), shared: shared);
      await tester.tap(find.byKey(const Key('member.share')));
      await tester.pump();
      expect(shared.single, 'Asha Verma on ICR|Asha Verma on ICR\nhttps://icr.org.in/members/asha-verma');
    });
  });

  group('the person\'s own page', () {
    testWidgets('has no Follow or Message, says it is how others see it, and offers Edit profile', (tester) async {
      final own = MemberProfile(
        id: 'me',
        firstName: 'Nikhil',
        lastName: 'Majjagi',
        profileSlug: 'nikhil-majjagi',
        follow: const FollowState(followers: 255, following: 12, viewerFollows: false),
        isOwner: true,
        signedIn: true,
      );
      var edits = 0;
      await pump(tester, repoWith(own), userId: 'me', onEdit: () => edits++);
      expect(find.byKey(const Key('member.follow')), findsNothing);
      expect(find.byKey(const Key('member.message')), findsNothing);
      expect(find.text('This is how other members see your profile.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('member.edit')));
      expect(edits, 1);
    });
  });
}
