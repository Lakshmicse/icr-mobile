import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/messaging/messaging_models.dart';
import 'package:icr_mobile/features/notifications/api_notifications_repository.dart';
import 'package:icr_mobile/features/notifications/notification_models.dart';
import 'package:icr_mobile/features/notifications/notification_target.dart';
import 'package:icr_mobile/features/notifications/notifications_controller.dart';
import 'package:icr_mobile/features/notifications/unread_counts.dart';

import 'messaging_fakes.dart';
import 'notifications_fakes.dart';

/// What `GET /notifications` really answers (captured from the local API,
/// 25 Oct 2026: a plain row, a grouped message row, a company's message with
/// its logo, a row about another company).
const _listJson = {
  'data': [
    {
      'id': 'n1',
      'title': 'Sarah Jenkins sent you 3 messages',
      'body': null,
      'type': 'message',
      'link': '/messaging?c=conv-1',
      'company': null,
      'count': 3,
      'readAt': null,
      'createdAt': '2026-10-25T05:38:54.282Z',
      'actor': {
        'id': 'u-sarah',
        'firstName': 'Sarah',
        'lastName': 'Jenkins',
        'avatarUrl': '/uploads/sarah.jpg',
        'headline': 'Director',
      },
      'actorCompany': null,
    },
    {
      'id': 'n2',
      'title': 'Global Infra Solutions sent you a message',
      'body': null,
      'type': 'message',
      'link': '/messaging?c=conv-2',
      'company': null,
      'count': 1,
      'readAt': '2026-10-25T06:00:00.000Z',
      'createdAt': '2026-10-24T20:00:00.000Z',
      'actor': {'id': 'u-priya', 'firstName': 'Priya', 'lastName': 'Sharma', 'avatarUrl': null},
      'actorCompany': {'id': 'co-gi', 'name': 'Global Infra Solutions', 'logoUrl': '/uploads/logo.png'},
    },
    {
      'id': 'n3',
      'title': 'Enrolled with ICR credits',
      'body': 'You enrolled into “Capital Planning” – Advanced with ICR referral credits (5 credits).',
      'type': 'course_purchase_confirmed',
      'link': '/learning/assessment/CP/capital-planning-advanced',
      'company': {'id': 'co-acme', 'name': 'Acme'},
      'count': 1,
      'readAt': null,
      'createdAt': '2026-10-19T13:45:37.264Z',
      'actor': null,
      'actorCompany': null,
    },
  ],
  'meta': {'page': 1, 'limit': 20, 'total': 41, 'totalPages': 3, 'hasNext': true, 'hasPrev': false},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the API mapping (real response shapes)', () {
    test('a page: rows, the company a row names, the grouped count, the page meta', () async {
      final api = TableAdapter({'GET /notifications': (_) => _listJson});
      final repo = ApiNotificationsRepository(api: clientFor(api));
      final page = await repo.list(page: 2, unreadOnly: true);

      expect(api.queryOf('GET /notifications'), {'page': 2, 'limit': 20, 'unread': true});
      expect(page.total, 41);
      expect(page.hasMore, isTrue);
      expect(page.items.map((n) => n.id), ['n1', 'n2', 'n3']);

      final grouped = page.items[0];
      expect(grouped.count, 3);
      expect(grouped.unread, isTrue);
      expect(grouped.actor!.fullName, 'Sarah Jenkins');
      expect(grouped.actor!.photo!.url, 'http://api.test/uploads/sarah.jpg');
      expect(grouped.category.id, 'messages');
      expect(grouped.actorName, 'Sarah Jenkins');

      final fromCompany = page.items[1];
      expect(fromCompany.unread, isFalse);
      expect(fromCompany.actorCompany!.logo!.url, 'http://api.test/uploads/logo.png');
      expect(fromCompany.actorName, 'Global Infra Solutions', reason: 'a company inbox reply names the company');

      final about = page.items[2];
      expect(about.company!.name, 'Acme');
      expect(about.body, startsWith('You enrolled into'));
      expect(about.actor, isNull);
      expect(about.category.id, 'payments', reason: 'course_purchase_confirmed is a locked receipt');
    });

    test('an unread-only request leaves the flag off the first page', () async {
      final api = TableAdapter({
        'GET /notifications': (_) => {
          'data': [],
          'meta': {'total': 0, 'hasNext': false},
        },
      });
      final page = await ApiNotificationsRepository(api: clientFor(api)).list();
      expect(api.queryOf('GET /notifications'), {'page': 1, 'limit': 20});
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test('the unread count, read-all and read-one go to their endpoints', () async {
      final api = TableAdapter({
        'GET /notifications/unread-count': (_) => {'unread': 7},
        'PATCH /notifications/read-all': (_) => {'updated': 7},
        'PATCH /notifications/abc%20d/read': (_) => {'id': 'abc d'},
      });
      final repo = ApiNotificationsRepository(api: clientFor(api));
      expect(await repo.unreadCount(), 7);
      expect(await repo.markAllRead(), 7);
      await repo.markRead('abc d');
      expect(api.calls, [
        'GET /notifications/unread-count',
        'PATCH /notifications/read-all',
        'PATCH /notifications/abc%20d/read',
      ]);
    });

    test('preferences: every category with its locked flag; a save sends one category', () async {
      final api = TableAdapter({
        'GET /notifications/preferences': (_) => [
          {'category': 'messages', 'inApp': true, 'email': false, 'locked': false},
          {'category': 'security', 'inApp': true, 'email': true, 'locked': true},
        ],
        'PUT /notifications/preferences': (_) => [
          {'category': 'messages', 'inApp': false, 'email': false, 'locked': false},
        ],
      });
      final repo = ApiNotificationsRepository(api: clientFor(api));
      final prefs = await repo.preferences();
      expect(prefs.map((p) => p.category.id), ['messages', 'security']);
      expect(prefs[0].email, isFalse);
      expect(prefs[1].locked, isTrue);

      final saved = await repo.savePreference(prefs[0].copyWith(inApp: false));
      expect(api.last('PUT /notifications/preferences').data, {
        'preferences': [
          {'category': 'messages', 'inApp': false, 'email': false},
        ],
      });
      expect(saved.single.inApp, isFalse);
    });

    test('the viewer: who is reading and how many companies they belong to', () async {
      final api = TableAdapter({
        'GET /auth/me': (_) => {'id': 'me', 'companyId': 'co-1', 'role': 'BUYER'},
        'GET /me/companies': (_) => {
          'personalRole': 'BUYER',
          'companies': [
            {'id': 'co-1'},
            {'id': 'co-2'},
          ],
          'requests': [],
        },
      });
      final v = await ApiNotificationsRepository(api: clientFor(api)).viewer();
      expect(v.id, 'me');
      expect(v.activeCompanyId, 'co-1');
      expect(v.companyCount, 2);
    });

    test('a failed companies read is not a failed viewer', () async {
      final api = TableAdapter({
        'GET /auth/me': (_) => {'id': 'me', 'companyId': null},
        'GET /me/companies': (_) => (500, '{"message":"boom"}'),
      });
      final v = await ApiNotificationsRepository(api: clientFor(api)).viewer();
      expect(v.companyCount, 0);
      expect(v.activeCompanyId, isNull);
    });
  });

  group('categories (the website\'s notificationCategoryOf)', () {
    test('a type belongs to the category the preferences list it under', () {
      const table = {
        'message': 'messages',
        'application_stage_changed': 'jobs',
        'interview_scheduled': 'jobs',
        'job_alert_matches': 'jobs',
        'bid_received': 'procurement',
        'rfq_invite': 'procurement',
        'mentorship_session_scheduled': 'mentoring',
        'group_session_reminder': 'mentoring',
        'assignment_graded': 'learning',
        'event_reminder': 'events',
        'forum_reply': 'community',
        'article_approved': 'community',
        'verification_approved': 'verification',
        'cert_granted': 'verification',
        'team_invite': 'team',
        'subscription_expiring': 'membership',
        'referral_reward': 'membership',
        'onboarding_nudge': 'onboarding',
        'info': 'general',
        'something_new': 'general',
        // locked ones win over their prefix
        'subscription_activated': 'payments',
        'invoice_issued': 'payments',
        'course_purchase_confirmed': 'payments',
        'support_reply': 'support',
        'company_suspended': 'security',
        'employer_verification_revoked': 'security',
        'employer_verification_approved': 'verification',
      };
      for (final e in table.entries) {
        expect(notificationCategoryOf(e.key).id, e.value, reason: e.key);
      }
      expect(notificationCategoryOf(null).id, 'general');
      expect(notificationCategoryOf('MESSAGE').id, 'messages', reason: 'case does not matter');
    });

    test('only payments, support and security are locked', () {
      expect(notificationCategories.where((c) => c.locked).map((c) => c.id), ['payments', 'support', 'security']);
      expect(notificationCategories.length, 15);
    });
  });

  group('grouping by when (the reader\'s own midnight)', () {
    final now = DateTime(2026, 10, 25, 15, 30);
    test('today, the six days before, earlier', () {
      expect(bucketOf(DateTime(2026, 10, 25, 0, 0), now), NotificationBucket.today);
      expect(
        bucketOf(DateTime(2026, 10, 24, 23, 59), now),
        NotificationBucket.thisWeek,
        reason: 'yesterday, 1 minute before midnight',
      );
      expect(
        bucketOf(DateTime(2026, 10, 19, 0, 0), now),
        NotificationBucket.thisWeek,
        reason: 'six days back, at midnight',
      );
      expect(bucketOf(DateTime(2026, 10, 18, 23, 59), now), NotificationBucket.earlier);
      expect(bucketOf(DateTime(2026, 1, 3), now), NotificationBucket.earlier);
    });

    test('a rolling 24 hours would put 20 hours ago in Today: the midnight rule does not', () {
      final early = DateTime(2026, 10, 25, 1, 0);
      expect(bucketOf(DateTime(2026, 10, 24, 20, 0), early), NotificationBucket.thisWeek);
    });
  });

  group('every page a notification can name', () {
    // href → kind and the params the screen that opens it needs. The hrefs are
    // what `notificationHref` (backend/.../notification-targets.ts) builds.
    const table = <String, (String, Map<String, String>)>{
      '/jobs/J1': ('job', {'jobId': 'J1'}),
      '/jobs/J1?referredBy=U9': ('job', {'jobId': 'J1', 'referredBy': 'U9'}),
      '/manage/jobs/J1/edit': ('job.edit', {'jobId': 'J1'}),
      '/manage/jobs/J1/pipeline?applicant=A1': ('application.employer', {'jobId': 'J1', 'applicationId': 'A1'}),
      '/career/applications/A1': ('application.candidate', {'applicationId': 'A1'}),
      '/manage/interviews/I1': ('interview.panel', {'interviewId': 'I1'}),
      '/career/alerts?search=S1': ('jobAlert', {'searchId': 'S1'}),
      '/talent?savedSearch=S1': ('talentSearch', {'searchId': 'S1'}),
      '/career': ('career', {}),
      '/admin/jobs/review?job=J1': ('admin.jobReview', {'jobId': 'J1'}),
      '/manage/team?tab=requests': ('team', {'tab': 'requests'}),
      '/invite/TOK': ('team.invite', {'token': 'TOK'}),
      '/account/companies': ('account.companies', {}),
      '/companies/C1?tab=reviews': ('company.page', {'companyId': 'C1', 'tab': 'reviews'}),
      '/company?tab=verification': ('company.workspace', {'tab': 'verification'}),
      '/admin/verification?vendor=V1': ('admin.verification.supplier', {'vendorId': 'V1'}),
      '/admin/verification?view=kyc&status=SUBMITTED&search=AAACZ1234C': (
        'admin.verification.company',
        {'status': 'SUBMITTED', 'searchKey': 'AAACZ1234C'},
      ),
      '/admin/companies/C1': ('admin.company', {'companyId': 'C1'}),
      '/manage/requirements/R1?bid=B1&section=prequal': (
        'rfq.owner',
        {'rfqId': 'R1', 'bidId': 'B1', 'section': 'prequal'},
      ),
      '/manage/bids/R1?section=response': ('rfq.supplier', {'rfqId': 'R1', 'section': 'response'}),
      '/mentorship/my/M1?session=S1&task=T1': (
        'mentorship.pairing',
        {'mentorshipId': 'M1', 'sessionId': 'S1', 'taskId': 'T1'},
      ),
      '/mentorship/my?tab=purchases&purchase=P1': ('mentorship.mine', {'tab': 'purchases', 'purchaseId': 'P1'}),
      '/mentorship/groups/G1': ('mentorship.groupSession', {'sessionId': 'G1'}),
      '/mentorship/programmes/women-in-fm': ('mentorship.programme', {'slug': 'women-in-fm'}),
      '/mentorship/certificates/CE1': ('mentorship.certificate', {'certificateId': 'CE1'}),
      '/mentorship/cpd': ('mentorship.cpd', {}),
      '/mentorship/mentors/MP1#reviews': ('mentor.profile', {'mentorProfileId': 'MP1', 'section': 'reviews'}),
      '/mentorship/mentors': ('mentor.directory', {}),
      '/mentorship/become-a-mentor': ('mentor.application', {}),
      '/mentorship/mentor?tab=work&focus=P1': ('mentor.desk', {'tab': 'work', 'focusId': 'P1'}),
      '/mentorship/my/sessions/P1': ('mentor.purchase', {'purchaseId': 'P1', 'side': 'buyer'}),
      '/admin/mentorship?tab=concerns&concern=CO1': ('admin.mentorship.concern', {'concernId': 'CO1'}),
      '/learning/assessment/CP/capital-planning-advanced': (
        'learning.assessment',
        {'courseCode': 'CP', 'paperSlug': 'capital-planning-advanced'},
      ),
      '/learning/assessment/CP': ('learning.assessment', {'courseCode': 'CP'}),
      '/learning/professional-development/CALS': ('learning.course', {'code': 'CALS'}),
      '/learning/courses/CALS?tab=syllabus': ('learning.workspace', {'code': 'CALS', 'tab': 'syllabus'}),
      '/admin/learning/batches?course=C1': ('admin.learning', {'section': 'batches', 'courseId': 'C1'}),
      '/learning/partners?apply=1': ('learning.partners', {'apply': '1'}),
      '/events/future-of-ai-design': ('event', {'eventId': 'future-of-ai-design'}),
      '/community/thread-slug#reply-R9': ('forum.thread', {'slug': 'thread-slug', 'replyId': 'R9'}),
      '/community/thread-slug': ('forum.thread', {'slug': 'thread-slug'}),
      '/community': ('forum', {}),
      '/admin/forum?tab=reports&report=RP1': ('admin.forum', {'tab': 'reports', 'reportId': 'RP1'}),
      '/blogs/a-post': ('blog', {'slug': 'a-post'}),
      '/manage/articles?edit=AR1': ('articles.mine', {'articleId': 'AR1'}),
      '/admin/blogs?review=AR1': ('admin.blogs', {'articleId': 'AR1'}),
      '/members/U1': ('member', {'userId': 'U1'}),
      '/documents': ('documents', {}),
      '/admin/documents/reports?report=RP1': ('admin.documentReports', {'reportId': 'RP1'}),
      '/messaging?c=CV1&m=MS1&inbox=CO9': (
        'conversation',
        {'conversationId': 'CV1', 'messageId': 'MS1', 'inbox': 'CO9'},
      ),
      '/messaging?inbox=CO9': ('messaging', {'inbox': 'CO9'}),
      '/admin/messaging/reports?report=RP1': ('admin.messageReports', {'reportId': 'RP1'}),
      '/profile?tab=credentials': ('profile', {'tab': 'credentials'}),
      '/support/T1': ('support.ticket', {'ticketId': 'T1'}),
      '/admin/support?ticket=T1': ('admin.supportTicket', {'ticketId': 'T1'}),
      '/support': ('support', {}),
      '/career/plans': ('membership.plans', {'audience': 'SEEKER'}),
      '/pricing/supplier': ('membership.plans', {'slug': 'supplier'}),
      '/membership/history?audience=SEEKER': ('membership.history', {'audience': 'SEEKER'}),
      '/admin/subscriptions': ('admin.subscriptions', {}),
      '/refer': ('refer', {}),
      '/refer/credits': ('refer', {'credits': 'true'}),
      '/advertise?placement=PL1': ('advertise', {'placementId': 'PL1'}),
      '/dashboard': ('dashboard', {}),
      '/marketing': ('admin.marketing', {}),
      '/admin/contact?message=MS1': ('admin.contact', {'messageId': 'MS1'}),
      // Pages the app's records link to, and anything unknown.
      '/rfq/R1': ('rfq.public', {'rfqId': 'R1'}),
      '/products/PR1': ('product', {'productId': 'PR1'}),
      '/notifications?tab=unread': ('notifications', {'tab': 'unread'}),
      '/onboarding/step-3': ('path', {'path': '/onboarding/step-3'}),
    };

    test('each page reads back as its kind with the ids the opener needs', () {
      for (final e in table.entries) {
        final t = NotificationTarget.parse(e.key);
        expect(t.kind, e.value.$1, reason: e.key);
        for (final p in e.value.$2.entries) {
          expect(t[p.key], p.value, reason: '${e.key} → ${p.key}');
        }
        expect(t.href, e.key, reason: 'the page is kept as the API stored it, for the website fallback');
      }
    });

    test('every kind the API can name is produced by some page above', () {
      // `NotificationTarget['kind']` in backend/.../notification-targets.ts.
      const api = [
        'job',
        'job.edit',
        'application.employer',
        'application.candidate',
        'interview.panel',
        'jobAlert',
        'talentSearch',
        'career',
        'admin.jobReview',
        'team',
        'team.invite',
        'account.companies',
        'company.page',
        'company.workspace',
        'admin.verification.supplier',
        'admin.verification.company',
        'admin.company',
        'rfq.owner',
        'rfq.supplier',
        'mentorship.pairing',
        'mentorship.mine',
        'mentorship.groupSession',
        'mentorship.programme',
        'mentorship.certificate',
        'mentorship.cpd',
        'mentor.profile',
        'mentor.directory',
        'mentor.application',
        'mentor.desk',
        'mentor.purchase',
        'admin.mentorship.concern',
        'learning.assessment',
        'learning.course',
        'learning.workspace',
        'admin.learning',
        'learning.partners',
        'event',
        'forum.thread',
        'forum',
        'admin.forum',
        'blog',
        'articles.mine',
        'admin.blogs',
        'member',
        'documents',
        'admin.documentReports',
        'conversation',
        'admin.messageReports',
        'profile',
        'support.ticket',
        'admin.supportTicket',
        'support',
        'membership.plans',
        'membership.history',
        'admin.subscriptions',
        'refer',
        'advertise',
        'dashboard',
        'admin.marketing',
        'admin.contact',
        'path',
      ];
      final produced = {for (final v in table.values) v.$1};
      expect(api.where((k) => !produced.contains(k)), isEmpty);
      expect(NotificationKinds.all.toSet().containsAll(api), isTrue);
    });

    test('no page, a full link, odd input: never throws', () {
      expect(NotificationTarget.parse(null).kind, 'none');
      expect(NotificationTarget.parse('  ').kind, 'none');
      expect(NotificationTarget.parse('https://icr.org.in/jobs/J9').kind, 'job');
      expect(NotificationTarget.parse('/jobs').kind, 'path');
      expect(NotificationTarget.parse('/').kind, 'path');
      expect(NotificationTarget.parse('::not a url::').kind, anyOf('path', 'none'));
    });

    test('recordId is the id the API\'s targetRef names', () {
      expect(NotificationTarget.parse('/manage/bids/R1').recordId, 'R1');
      expect(NotificationTarget.parse('/messaging?c=CV1').recordId, 'CV1');
      expect(NotificationTarget.parse('/dashboard').recordId, isNull);
    });
  });

  group('the notifications controller', () {
    NotificationsController make(FakeNotificationsRepository repo, {List<int>? seen}) =>
        NotificationsController(repo, clock: () => DateTime(2026, 10, 25, 15), onUnreadChanged: seen?.add);

    final items = [
      note('a', title: 'Now', at: DateTime(2026, 10, 25, 14)),
      note('b', title: 'Earlier today', at: DateTime(2026, 10, 25, 2), read: true),
      note('c', title: 'Yesterday', at: DateTime(2026, 10, 24, 12)),
      note('d', title: 'A fortnight ago', at: DateTime(2026, 10, 11, 12), read: true),
    ];

    test('start loads the first page, the count, the viewer; rows fall into their groups', () async {
      final repo = FakeNotificationsRepository(items: items);
      final seen = <int>[];
      final c = make(repo, seen: seen);
      await c.start();
      expect(c.loaded, isTrue);
      expect(c.items.map((n) => n.id), ['a', 'b', 'c', 'd']);
      expect(c.unread, 2);
      expect(seen.last, 2, reason: 'the bell hears the count');
      expect(c.groups.map((g) => '${g.$1.name}:${g.$2.map((n) => n.id).join(',')}'), [
        'today:a,b',
        'thisWeek:c',
        'earlier:d',
      ]);
      c.dispose();
    });

    test('opening a row reads it at once and tells the API; a refusal puts it back', () async {
      final repo = FakeNotificationsRepository(items: items);
      final seen = <int>[];
      final c = make(repo, seen: seen);
      await c.start();

      expect(await c.markRead(c.items[0]), isNull);
      expect(c.items[0].unread, isFalse);
      expect(c.unread, 1);
      expect(repo.calls, contains('markRead a'));

      repo.markReadError = ApiError('Not allowed', statusCode: 403);
      expect(await c.markRead(c.items[2]), 'Not allowed');
      expect(c.items[2].unread, isTrue, reason: 'put back');
      expect(c.unread, 1);
      expect(seen.last, 1);

      expect(await c.markRead(c.items[1]), isNull, reason: 'an already read row asks nothing');
      expect(repo.calls.where((x) => x == 'markRead b'), isEmpty);
      c.dispose();
    });

    test('mark all as read clears the dot; a refusal brings every row back', () async {
      final repo = FakeNotificationsRepository(items: items);
      final c = make(repo);
      await c.start();

      repo.markAllError = ApiError('Try later', statusCode: 500);
      expect(await c.markAllRead(), 'Try later');
      expect(c.unread, 2);
      expect(c.items.where((n) => n.unread), hasLength(2));

      repo.markAllError = null;
      expect(await c.markAllRead(), isNull);
      expect(c.unread, 0);
      expect(c.items.any((n) => n.unread), isFalse);
      expect(await c.markAllRead(), isNull, reason: 'nothing unread: no call');
      expect(repo.calls.where((x) => x == 'markAllRead'), hasLength(2));
      c.dispose();
    });

    test('the Unread tab asks only for unread rows, and reading all empties it', () async {
      final repo = FakeNotificationsRepository(items: items);
      final c = make(repo);
      await c.start();
      await c.setTab(NotificationsTab.unread);
      expect(c.items.map((n) => n.id), ['a', 'c']);
      expect(repo.calls.last, 'list page=1 unread=true');

      await c.markAllRead();
      expect(c.items, isEmpty);
      c.dispose();
    });

    test('pages are appended without repeating a row; a failed page leaves the list alone', () async {
      final many = [
        for (var i = 0; i < 45; i++) note('n$i', at: DateTime(2026, 10, 25, 14).subtract(Duration(minutes: i))),
      ];
      final repo = FakeNotificationsRepository(items: many);
      final c = make(repo);
      await c.start();
      expect(c.items, hasLength(20));
      expect(c.hasMore, isTrue);

      await c.loadMore();
      expect(c.items, hasLength(40));
      await c.loadMore();
      expect(c.items, hasLength(45));
      expect(c.hasMore, isFalse);
      expect(c.items.map((n) => n.id).toSet(), hasLength(45));

      repo.listError = ApiError('down');
      await c.loadMore();
      expect(c.items, hasLength(45));
      c.dispose();
    });

    test('a failed first load says why, and refresh recovers', () async {
      final repo = FakeNotificationsRepository(items: items)..listError = ApiError("Can't reach ICR right now.");
      final c = make(repo);
      await c.start();
      expect(c.loaded, isFalse);
      expect(c.error, "Can't reach ICR right now.");

      repo.listError = null;
      await c.refresh();
      expect(c.error, isNull);
      expect(c.items, hasLength(4));
      c.dispose();
    });

    test('a row about another company needs a switch; the switch is told to the API', () async {
      const mine = ChatCompany(id: 'co-1', name: 'BrightCore');
      const other = ChatCompany(id: 'co-2', name: 'Acme');
      final repo = FakeNotificationsRepository(
        items: [
          note('x', company: other),
          note('y', company: mine),
        ],
      )..viewerAnswer = const NotificationViewer(id: 'me', activeCompanyId: 'co-1', companyCount: 2);
      final c = make(repo);
      await c.start();
      expect(c.needsSwitch(c.items[0]), isTrue);
      expect(c.needsSwitch(c.items[1]), isFalse);
      expect(c.showsCompanyOf(c.items[0]), isTrue, reason: 'someone in two companies sees which one a row is for');

      expect(await c.switchTo(other), isNull);
      expect(repo.calls, contains('switchCompany co-2'));
      expect(c.needsSwitch(c.items[0]), isFalse);

      repo.switchError = ApiError('gone', statusCode: 403);
      expect(await c.switchTo(const ChatCompany(id: 'co-3', name: 'Gone Ltd')), contains('no longer part of Gone Ltd'));
      c.dispose();
    });

    test('someone in one company is not told which company a row is for', () async {
      final repo = FakeNotificationsRepository(
        items: [
          note(
            'x',
            company: const ChatCompany(id: 'co-1', name: 'Acme'),
          ),
        ],
      )..viewerAnswer = const NotificationViewer(id: 'me', activeCompanyId: 'co-1', companyCount: 1);
      final c = make(repo);
      await c.start();
      expect(c.showsCompanyOf(c.items.first), isFalse);
      c.dispose();
    });

    test('preferences: a switch moves at once and saves; a refusal puts it back and says so', () async {
      final repo = FakeNotificationsRepository();
      final c = make(repo);
      await c.loadPreferences();
      final messages = c.preferences!.firstWhere((p) => p.category.id == 'messages');

      expect(await c.setChannel(messages, email: false), isNull);
      expect(c.preferences!.firstWhere((p) => p.category.id == 'messages').email, isFalse);
      expect(repo.calls.last, 'savePreference messages in=true mail=false');

      repo.saveError = ApiError('boom', statusCode: 500);
      final again = c.preferences!.firstWhere((p) => p.category.id == 'messages');
      expect(await c.setChannel(again, inApp: false), 'Your change could not be saved. Try again.');
      expect(c.preferences!.firstWhere((p) => p.category.id == 'messages').inApp, isTrue, reason: 'put back');
      expect(c.saveError, isNotNull);
      c.clearSaveError();
      expect(c.saveError, isNull);

      final locked = c.preferences!.firstWhere((p) => p.category.id == 'security');
      expect(await c.setChannel(locked, email: false), isNull);
      expect(repo.calls.where((x) => x.startsWith('savePreference security')), isEmpty, reason: 'locked: never sent');
      c.dispose();
    });

    test('preferences that cannot load can be retried', () async {
      final repo = FakeNotificationsRepository()..preferencesError = ApiError('x');
      final c = make(repo);
      await c.loadPreferences();
      expect(c.preferences, isNull);
      expect(c.preferencesError, isNotNull);
      repo.preferencesError = null;
      await c.loadPreferences();
      expect(c.preferences, isNotNull);
      expect(c.preferencesError, isNull);
      c.dispose();
    });
  });

  group('the app-wide counts (the bell and the Messages badge)', () {
    test('reads both counts; a failed read keeps the last numbers; screens can set them', () async {
      final source = _CountSource(notifications: 4, messages: 2);
      final counts = UnreadCounts(source, interval: const Duration(hours: 1));
      var heard = 0;
      counts.addListener(() => heard++);

      await counts.refresh();
      expect((counts.notifications, counts.messages, counts.total), (4, 2, 6));
      expect(heard, 1);

      source.failNotifications = true;
      source.messageCount = 9;
      await counts.refresh();
      expect(counts.notifications, 4, reason: 'kept');
      expect(counts.messages, 9);

      counts.setNotifications(0);
      expect(counts.notifications, 0);
      counts.setNotifications(-3);
      expect(counts.notifications, 0, reason: 'never negative');
      counts.dispose();
    });

    test('start reads at once and keeps reading on a timer; stop and dispose end it', () async {
      final source = _CountSource(notifications: 1, messages: 0);
      final counts = UnreadCounts(source, interval: const Duration(milliseconds: 20));
      counts.start();
      await Future<void>.delayed(const Duration(milliseconds: 90));
      expect(source.reads, greaterThan(2));
      expect(counts.running, isTrue);
      counts.stop();
      expect(counts.running, isFalse);
      counts.dispose();
    });
  });
}

class _CountSource implements UnreadSource {
  _CountSource({required int notifications, required int messages})
    : notificationCount = notifications,
      messageCount = messages;

  int notificationCount;
  int messageCount;
  bool failNotifications = false;
  int reads = 0;

  @override
  Future<int> notifications() async {
    reads++;
    if (failNotifications) throw ApiError('down');
    return notificationCount;
  }

  @override
  Future<int> messages() async => messageCount;
}
