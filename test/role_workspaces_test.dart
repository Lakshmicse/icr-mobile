import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/app_screens.dart';
import 'package:icr_mobile/app_workspaces.dart';
import 'package:icr_mobile/core/auth/session_user.dart';
import 'package:icr_mobile/features/feed/feed_models.dart';
import 'package:icr_mobile/features/workspaces/role_workspaces.dart';
import 'package:icr_mobile/features/workspaces/workspaces.dart';

/// The profile menu's rows (owner's drawer design, 6 Nov 2026: Company, Marketplace, Mentorship, Learning, Jobs), each
/// holding the pages the website's sidebar gives the role (owner, 5 Nov 2026), listing only pages the app shows itself.
void main() {
  SessionUser user(
    String role, {
    String? companyId = 'co1',
    String? mentorStatus,
    List<String> learningRoles = const [],
    bool learningPartner = false,
  }) => SessionUser(
    id: 'u-$role',
    email: '$role@icr.test',
    firstName: 'A',
    lastName: 'B',
    role: role,
    companyId: companyId,
    mentorStatus: mentorStatus,
    learningRoles: learningRoles,
    learningPartner: learningPartner,
  );

  bool everything(String _) => true;
  bool nothing(String _) => false;

  List<String> labels(List<Workspace> w) => [for (final x in w) x.label];
  List<String> pages(List<Workspace> w, String label) => [
    for (final i in w.firstWhere((x) => x.label == label).sections.single.items) i.path,
  ];

  // The owner's table (6 Nov 2026): every user's four rows, Company (the one they run, and My companies for
  // everyone — owner, 7 Nov 2026), then Account.
  // Company second, under Jobs (owner, 12 Nov 2026).
  const design = ['Jobs', 'Company', 'Learning', 'Mentorship', 'Marketplace', 'Account'];

  group('the rows, by role (every page the app could show)', () {
    test("every member gets the table's rows, each opening one set of tabs", () {
      for (final role in ['PROFESSIONAL', 'COMPANY_ADMIN', 'VENDOR', 'BUYER', 'RECRUITER', 'BRANCH_ADMIN']) {
        final w = workspacesFor(user(role), opens: everything);
        expect(labels(w), design, reason: role);
        for (final x in w) {
          expect(x.sections, hasLength(1), reason: '$role › ${x.label} opens straight away');
          expect(x.sections.single.title, x.label);
        }
      }
    });

    test("a user: the table's own pages under Jobs, Learning, Mentorship and Marketplace; Company is My companies", () {
      final w = workspacesFor(user('PROFESSIONAL', companyId: null), opens: everything);
      expect(labels(w), design);
      expect(pages(w, 'Company'), ['/account/companies'], reason: 'My companies sits under Company, not Account');
      // The owner's document "Mobile Profile Screen Text Changes" (12 Nov 2026): no search rows (the tabs are
      // those searches); My Requirements and "Enquiries and RFQ" under Marketplace; Mentor Engagements and
      // Mentoring Sessions under Mentorship.
      expect(pages(w, 'Jobs'), ['/career/applications', '/career/saved']);
      expect(pages(w, 'Learning'), ['/learning?mine=1', '/learning/attempts', '/learning/certificates']);
      expect(pages(w, 'Mentorship'), ['/mentorship/my', '/mentorship/my?tab=calendar']);
      expect(pages(w, 'Marketplace'), ['/manage/requirements', '/rfq']);
      expect(w.firstWhere((x) => x.label == 'Jobs').sections.single.items.map((i) => i.label), [
        'My Applications',
        'My Saved Jobs',
      ]);
      expect(w.firstWhere((x) => x.label == 'Learning').sections.single.items.map((i) => i.label), [
        'My Courses',
        'My Attempts',
        'My Certificates',
      ]);
      expect(w.firstWhere((x) => x.label == 'Mentorship').sections.single.items.map((i) => i.label), [
        'Mentor Engagements',
        'Mentoring Sessions',
      ]);
      expect(w.firstWhere((x) => x.label == 'Marketplace').sections.single.items.map((i) => i.label), [
        'My Requirements',
        'Enquiries and RFQ',
      ]);
      expect(w.firstWhere((x) => x.label == 'Company').sections.single.items.single.label, 'My Companies');
      expect(pages(w, 'Account'), [
        '/membership',
        '/membership/history',
        '/membership/benefits',
        '/refer',
        '/refer/credits',
      ]);
    });

    test('the doors for a member acting as themselves: a company to hire, sell or buy with, and mentoring', () {
      final doors = startDoorsFor(user('PROFESSIONAL', companyId: null));
      expect(doors.map((d) => d.key), ['create-company', 'hire', 'sell', 'source', 'mentor']);
      expect(doors.map((d) => d.path), [
        '/account/companies/new',
        '/account/companies/new?role=COMPANY_ADMIN',
        '/account/companies/new?role=VENDOR',
        '/vendors',
        '/mentorship/become-a-mentor',
      ]);
      // Someone who applied, or mentors, is not pitched mentoring again.
      expect(
        startDoorsFor(user('PROFESSIONAL', companyId: null, mentorStatus: 'PENDING')).map((d) => d.key),
        isNot(contains('mentor')),
      );
      // Acting for a company, the company's workspace is the doors; staff have none.
      expect(startDoorsFor(user('PROFESSIONAL')), isEmpty);
      expect(startDoorsFor(user('SUPER_ADMIN', companyId: null)), isEmpty);
    });

    test("the doors' words are the website's (WelcomeCard intents, nav label, mentorship card)", () {
      final doors = {for (final d in startDoorsFor(user('PROFESSIONAL', companyId: null))) d.key: d};
      expect(doors['hire']!.label, 'Hire Talent');
      expect(doors['hire']!.caption, 'Create your company page, then post a job.');
      expect(doors['sell']!.label, 'Sell to FM Buyers');
      expect(doors['sell']!.caption, 'Create your company page, then list your services.');
      expect(doors['source']!.label, 'Marketplace');
      expect(doors['source']!.caption, 'Search verified suppliers and ask for quotes.');
      expect(doors['mentor']!.label, 'Become a Mentor');
      expect(doors['mentor']!.caption, 'Share your expertise with the next generation.');
    });

    test("who sees the doors is the website's isUndecidedPerson: no staff role, no company in use", () {
      // PLATFORM_ROLES: none of ICR's staff, whichever role and whether or not they hold a company.
      for (final role in ['SUPER_ADMIN', 'LEARNING_ADMIN', 'PARTNER_ADMIN']) {
        expect(startDoorsFor(user(role, companyId: null)), isEmpty, reason: role);
        expect(startDoorsFor(user(role)), isEmpty, reason: '$role with a company');
      }
      // A member acting for a company has its workspace, not the doors, whatever the hat.
      for (final role in [
        'COMPANY_ADMIN',
        'VENDOR',
        'BUYER',
        'RECRUITER',
        'BRANCH_ADMIN',
        'HIRING_MANAGER',
        'PROFESSIONAL',
      ]) {
        expect(startDoorsFor(user(role)), isEmpty, reason: role);
      }
      // Everyone else acting as themselves is offered them (a seller or buyer account with no company yet too).
      for (final role in ['PROFESSIONAL', 'VENDOR', 'BUYER']) {
        expect(startDoorsFor(user(role, companyId: null)).map((d) => d.key), contains('hire'), reason: role);
      }
    });

    test(
      'the mentor door is for a member who may apply (canOfferToMentor): not a mentor, an applicant or a mentor of someone',
      () {
        List<String> keys(SessionUser u) => startDoorsFor(u).map((d) => d.key).toList();
        expect(keys(user('PROFESSIONAL', companyId: null)), contains('mentor'));
        for (final status in ['DRAFT', 'PENDING', 'REJECTED', 'APPROVED', 'PAUSED']) {
          expect(
            keys(user('PROFESSIONAL', companyId: null, mentorStatus: status)),
            isNot(contains('mentor')),
            reason: status,
          );
        }
        const mentorOfSomeone = SessionUser(
          id: 'm',
          email: 'm@icr.test',
          firstName: 'M',
          lastName: 'M',
          role: 'PROFESSIONAL',
          mentorsSomeone: true,
        );
        expect(keys(mentorOfSomeone), isNot(contains('mentor')));
        // The other doors stay.
        expect(keys(mentorOfSomeone), ['create-company', 'hire', 'sell', 'source']);
      },
    );

    test(
      'no door registers anyone for a role only an invite gives (recruiter, hiring manager, office admin, partner admin)',
      () {
        final words = [
          for (final d in startDoorsFor(user('PROFESSIONAL', companyId: null))) ...[d.label, d.caption, d.path],
        ].join(' ').toLowerCase();
        for (final role in [
          'recruiter',
          'hiring manager',
          'office admin',
          'branch',
          'partner admin',
          'learning admin',
        ]) {
          expect(words, isNot(contains(role)), reason: role);
        }
      },
    );

    test('a mentor adds the Mentor Dashboard first under Mentorship', () {
      final w = workspacesFor(user('PROFESSIONAL', companyId: null, mentorStatus: 'APPROVED'), opens: everything);
      expect(pages(w, 'Mentorship'), ['/mentorship/mentor', '/mentorship/my', '/mentorship/my?tab=calendar']);
      expect(w.firstWhere((x) => x.label == 'Mentorship').sections.single.items.first.label, 'Mentor Dashboard');
      final applicant = workspacesFor(
        user('PROFESSIONAL', companyId: null, mentorStatus: 'PENDING'),
        opens: everything,
      );
      expect(pages(applicant, 'Mentorship').last, '/mentorship/become-a-mentor');
    });

    test('a company admin: the Company row (My Companies, Dashboard, team, enquiries, bids), the catalogue under '
        'Marketplace, and hiring under Jobs', () {
      final w = workspacesFor(user('COMPANY_ADMIN'), opens: everything);
      expect(pages(w, 'Company'), [
        '/account/companies',
        '/company',
        '/manage/team',
        '/manage/requirements',
        '/manage/bids',
      ]);
      expect(w.firstWhere((x) => x.label == 'Company').sections.single.items.map((i) => i.label), [
        'My Companies',
        'Dashboard',
        'Manage Team',
        'View Enquiries & RFQs',
        'Bid for Enquiries & RFQs',
      ]);
      expect(pages(w, 'Jobs'), [
        '/manage/jobs',
        '/manage/team',
        '/talent',
        '/manage/projects',
        '/career/applications',
        '/career/saved',
      ]);
      expect(w.firstWhere((x) => x.label == 'Jobs').sections.single.items.map((i) => i.label), [
        'Manage Jobs',
        'Manage Hiring Team',
        'Source Candidates',
        'Projects',
        'My Applications',
        'My Saved Jobs',
      ]);
      expect(pages(w, 'Marketplace'), ['/manage/requirements', '/manage/products', '/manage/services', '/rfq']);
      expect(w.firstWhere((x) => x.label == 'Marketplace').sections.single.items.map((i) => i.label), [
        'My Requirements',
        'My Products',
        'My Services',
        'Enquiries and RFQ',
      ]);
      expect(pages(w, 'Account'), isNot(contains('/account/companies')));
    });

    test('a buyer edits its organisation and views enquiries; it does not sell or hire', () {
      final w = workspacesFor(user('BUYER'), opens: everything);
      expect(pages(w, 'Company'), ['/account/companies', '/company', '/manage/team', '/manage/requirements']);
      expect(pages(w, 'Company'), isNot(contains('/manage/bids')));
      expect(pages(w, 'Jobs'), isNot(contains('/manage/jobs')));
      expect(pages(w, 'Marketplace'), ['/manage/requirements', '/rfq']);
    });

    test('a seller adds services and products and bids; it does not hire', () {
      final w = workspacesFor(user('VENDOR'), opens: everything);
      expect(pages(w, 'Company'), contains('/manage/bids'));
      expect(pages(w, 'Jobs'), isNot(contains('/manage/jobs')));
      // The catalogue moved from Company to Marketplace (the owner's document, 12 Nov 2026).
      expect(pages(w, 'Company'), isNot(contains('/manage/products')));
      expect(pages(w, 'Marketplace'), ['/manage/requirements', '/manage/products', '/manage/services', '/rfq']);
    });

    test('the hiring roles: a recruiter and an office admin hire; a hiring manager has Interviews only', () {
      for (final role in ['RECRUITER', 'BRANCH_ADMIN']) {
        final w = workspacesFor(user(role), opens: everything);
        expect(pages(w, 'Company'), [
          '/account/companies',
          '/company',
          '/manage/team',
          '/manage/locations',
        ], reason: role);
        expect(pages(w, 'Jobs').first, '/manage/jobs', reason: role);
        expect(pages(w, 'Marketplace'), ['/manage/requirements', '/rfq'], reason: role);
      }
      final manager = workspacesFor(user('HIRING_MANAGER'), opens: everything);
      expect(pages(manager, 'Company'), ['/account/companies'], reason: 'runs nothing; My companies only');
      expect(pages(manager, 'Jobs').first, '/manage/interviews');
      expect(pages(manager, 'Jobs'), isNot(contains('/manage/jobs')));
    });

    test('someone acting for a company who may mentor is offered Become a mentor under Mentorship', () {
      // The website's sidebar row (`canOfferToMentor`); a member acting as themselves has the door instead.
      expect(
        pages(workspacesFor(user('RECRUITER'), opens: everything), 'Mentorship').last,
        '/mentorship/become-a-mentor',
      );
      expect(
        pages(workspacesFor(user('COMPANY_ADMIN', mentorStatus: 'PENDING'), opens: everything), 'Mentorship').last,
        '/mentorship/become-a-mentor',
        reason: 'an applicant sees My mentor profile, the same page',
      );
      final w = workspacesFor(user('COMPANY_ADMIN'), opens: everything);
      expect(w.firstWhere((x) => x.label == 'Mentorship').sections.single.items.last.label, 'Become a Mentor');
      expect(
        pages(workspacesFor(user('PROFESSIONAL', companyId: null), opens: everything), 'Mentorship'),
        isNot(contains('/mentorship/become-a-mentor')),
      );
    });

    test("a partner institute's staff get the Learning Partner row", () {
      final w = workspacesFor(user('COMPANY_ADMIN', learningRoles: ['TRAINER']), opens: everything);
      expect(labels(w), ['Jobs', 'Company', 'Learning', 'Mentorship', 'Marketplace', 'Learning Partner', 'Account']);
      expect(pages(w, 'Learning Partner'), [
        '/admin/learning/courses',
        '/manage/team',
        '/admin/learning/batches',
        '/admin/learning/enrolments',
        '/admin/learning/enquiries',
      ]);
      expect(w.firstWhere((x) => x.label == 'Learning Partner').sections.single.items.map((i) => i.label), [
        'Manage Courses',
        'Manage Team',
        'Manage Batches',
        'Enrolment',
        'Enquiries',
      ]);
      // The admin of a company ICR approved as a partner holds no learning role of their own, but runs it.
      final admin = workspacesFor(user('COMPANY_ADMIN', learningPartner: true), opens: everything);
      expect(labels(admin), contains('Learning Partner'));
      expect(
        labels(workspacesFor(user('RECRUITER', learningPartner: true), opens: everything)),
        isNot(contains('Learning Partner')),
        reason: 'only the admin, as the website gives learning roles',
      );
      expect(labels(workspacesFor(user('COMPANY_ADMIN'), opens: everything)), isNot(contains('Learning Partner')));
    });

    test("ICR staff get their consoles and none of the member's rows", () {
      final admin = workspacesFor(user('SUPER_ADMIN', companyId: null), opens: everything);
      expect(labels(admin), ['Company', 'Marketplace', 'Jobs', 'Engage', 'Learn', 'Content', 'Admin']);
      expect(pages(admin, 'Company'), isNot(contains('/account/companies')), reason: 'staff join no company');
      expect(pages(admin, 'Jobs'), isNot(contains('/career')), reason: 'staff are not job seekers');
      expect(labels(workspacesFor(user('LEARNING_ADMIN', companyId: null), opens: everything)), ['Learn']);
      final partner = workspacesFor(user('PARTNER_ADMIN', companyId: null), opens: everything);
      expect(labels(partner), ['Learn']);
      expect(
        pages(partner, 'Learn'),
        containsAll(['/admin/learning/courses', '/admin/learning/batches', '/admin/learning/enrolments']),
      );
      // ICR's own Learning Center keeps its batches and enrolments in the staff console: the app's are the institute's.
      final learning = workspacesFor(user('LEARNING_ADMIN', companyId: null), opens: everything);
      expect(pages(learning, 'Learn'), isNot(contains('/admin/learning/batches')));
      expect(pages(learning, 'Learn'), isNot(contains('/admin/learning/enrolments')));
    });

    test('the Account rows: everything for a member, Settings alone for staff', () {
      final member = accountMenuFor(user('PROFESSIONAL'));
      expect(member.myAccount, same(myAccountSection));
      expect(member.savedItems, isTrue);
      expect(member.referrals, same(referralsSection));
      final staff = accountMenuFor(user('SUPER_ADMIN', companyId: null));
      expect(staff.myAccount, isNull);
      expect(staff.savedItems, isFalse);
      expect(staff.referrals, isNull);
    });
  });

  group('only pages the app shows itself', () {
    test('a page the app has no screen for is left out; a row left empty goes', () {
      expect(labels(workspacesFor(user('COMPANY_ADMIN'), opens: nothing)), isEmpty);
      final w = workspacesFor(user('COMPANY_ADMIN'), opens: (p) => p == '/rfq' || p == '/manage/jobs');
      expect(labels(w), ['Jobs', 'Marketplace']);
      expect(pages(w, 'Marketplace'), ['/rfq']);
      expect(pages(w, 'Jobs'), ['/manage/jobs']);
    });

    test("with the app's real screens: every row the app's own, for every role", () {
      const viewer = FeedAuthor(id: 'u1', name: 'Probe');
      final screens = inAppScreens(viewer: viewer);
      bool opens(String p) => workspaceOpens(p, screens);
      final admin = workspacesFor(user('COMPANY_ADMIN'), opens: opens);
      expect(labels(admin), design);
      expect(
        pages(admin, 'Company'),
        containsAll(['/manage/team', '/manage/requirements', '/manage/bids', '/account/companies', '/company']),
      );
      expect(pages(admin, 'Account'), isNot(contains('/account/companies')));
      expect(
        pages(admin, 'Marketplace'),
        containsAll(['/manage/requirements', '/manage/products', '/manage/services', '/rfq']),
      );
      expect(
        pages(admin, 'Jobs'),
        containsAll(['/manage/jobs', '/talent', '/manage/projects', '/career/applications']),
      );
      // Consoles the app has no screen for are not offered (they would open the website).
      for (final path in ['/crm', '/payments', '/manage/reports', '/admin/users', '/tenders']) {
        expect(opens(path), isFalse, reason: path);
      }
      const roles = [
        'PROFESSIONAL',
        'COMPANY_ADMIN',
        'VENDOR',
        'BUYER',
        'RECRUITER',
        'BRANCH_ADMIN',
        'HIRING_MANAGER',
        'SUPER_ADMIN',
        'LEARNING_ADMIN',
        'PARTNER_ADMIN',
      ];
      for (final role in roles) {
        for (final x in workspacesFor(user(role), opens: opens)) {
          for (final i in x.sections.single.items) {
            expect(opens(i.path), isTrue, reason: '$role › ${x.label} › ${i.label}');
          }
        }
      }
      for (final s in [myAccountSection, referralsSection]) {
        for (final i in s.items) {
          expect(opens(i.path), isTrue, reason: '${s.title} › ${i.label}');
        }
      }
    });
  });

  group("the website's mentor gates", () {
    test('a listed mentor (approved or paused) acts as one; an application in progress is an applicant', () {
      expect(actsAsMentor(user('VENDOR', mentorStatus: 'APPROVED')), isTrue);
      expect(actsAsMentor(user('VENDOR', mentorStatus: 'PAUSED')), isTrue);
      expect(actsAsMentor(user('VENDOR', mentorStatus: 'PENDING')), isFalse);
      for (final s in ['DRAFT', 'PENDING', 'REJECTED']) {
        expect(hasMentorApplication(user('VENDOR', mentorStatus: s)), isTrue, reason: s);
      }
      expect(hasMentorApplication(user('VENDOR', mentorStatus: 'APPROVED')), isFalse);
    });
  });
}
