/// What a notification is about, read back from the page it links to.
///
/// The API names each notification's record as a target (`{ kind:
/// 'rfq.supplier', rfqId }`, `notification-targets.ts`) and stores the page
/// `notificationHref` makes of it; the list sends only that page. This turns
/// the page back into the kind and its params, so the app can open the record
/// in its own screen. The kinds are the API's, plus a few pages the app's
/// messages and records link to (`rfq.public`, `product`, `messaging`,
/// `notifications`). A page this does not know is kind `path`: its [href] is
/// still the page to open.
///
/// Some pages stand for more than one kind on the API's side; they are read as
/// the page they are (the opener sees the same page either way):
/// `/mentorship/my?tab=purchases&purchase=X` is `mentorship.mine` (also a
/// buyer's written consultation or resource), `/mentorship/mentor?tab=work&focus=X`
/// is `mentor.desk` (also a sold service, seller side), `/mentorship/groups/X`
/// is `mentorship.groupSession` (also a bought group seat), and
/// `/mentorship/my/sessions/X` is `mentor.purchase` (a bought 1:1).
class NotificationTarget {
  const NotificationTarget(this.kind, {required this.href, this.params = const {}});

  final String kind;

  /// The root-relative page, as the API stored it.
  final String href;

  /// The record's ids and the page's options (`jobId`, `tab`, `replyId`…).
  final Map<String, String> params;

  String? operator [](String key) => params[key];

  /// The record the page shows (the API's `targetRef` id), when it is one record.
  String? get recordId => params[_idParam[kind] ?? ''];

  static const _idParam = {
    NotificationKinds.job: 'jobId',
    NotificationKinds.jobEdit: 'jobId',
    NotificationKinds.adminJobReview: 'jobId',
    NotificationKinds.applicationEmployer: 'applicationId',
    NotificationKinds.applicationCandidate: 'applicationId',
    NotificationKinds.interviewPanel: 'interviewId',
    NotificationKinds.jobAlert: 'searchId',
    NotificationKinds.talentSearch: 'searchId',
    NotificationKinds.companyPage: 'companyId',
    NotificationKinds.adminCompany: 'companyId',
    NotificationKinds.teamInvite: 'token',
    NotificationKinds.adminVerificationSupplier: 'vendorId',
    NotificationKinds.rfqOwner: 'rfqId',
    NotificationKinds.rfqSupplier: 'rfqId',
    NotificationKinds.rfqPublic: 'rfqId',
    NotificationKinds.mentorshipPairing: 'mentorshipId',
    NotificationKinds.mentorshipGroupSession: 'sessionId',
    NotificationKinds.mentorshipProgramme: 'slug',
    NotificationKinds.mentorshipCertificate: 'certificateId',
    NotificationKinds.mentorProfile: 'mentorProfileId',
    NotificationKinds.mentorPurchase: 'purchaseId',
    NotificationKinds.adminMentorshipConcern: 'concernId',
    NotificationKinds.learningAssessment: 'courseCode',
    NotificationKinds.learningCourse: 'code',
    NotificationKinds.learningWorkspace: 'code',
    NotificationKinds.event: 'eventId',
    NotificationKinds.forumThread: 'slug',
    NotificationKinds.blog: 'slug',
    NotificationKinds.member: 'userId',
    NotificationKinds.conversation: 'conversationId',
    NotificationKinds.supportTicket: 'ticketId',
    NotificationKinds.adminSupportTicket: 'ticketId',
    NotificationKinds.product: 'productId',
  };

  @override
  String toString() => 'NotificationTarget($kind, $params)';

  /// Reads a page back into its target. Never throws: anything it cannot read
  /// is kind `path` (or `none` with no page at all).
  static NotificationTarget parse(String? href) {
    if (href == null || href.trim().isEmpty) return const NotificationTarget(NotificationKinds.none, href: '');
    final raw = href.trim();
    Uri uri;
    try {
      uri = Uri.parse(raw);
    } catch (_) {
      return NotificationTarget(NotificationKinds.path, href: raw);
    }
    // A full link to ICR's own site reads as its path.
    final path = uri.path;
    final s = uri.pathSegments.where((p) => p.isNotEmpty).toList();
    final q = uri.queryParameters;
    final fragment = uri.fragment;

    NotificationTarget t(String kind, [Map<String, String?> params = const {}]) => NotificationTarget(
      kind,
      href: raw,
      params: {
        for (final e in params.entries)
          if (e.value != null && e.value!.isNotEmpty) e.key: e.value!,
      },
    );

    bool at(List<String> prefix) {
      if (s.length < prefix.length) return false;
      for (var i = 0; i < prefix.length; i++) {
        if (prefix[i] != '*' && s[i] != prefix[i]) return false;
      }
      return true;
    }

    final n = s.length;
    if (n == 0) return t(NotificationKinds.path, {'path': path});

    switch (s[0]) {
      case 'jobs':
        if (n == 2) return t(NotificationKinds.job, {'jobId': s[1], 'referredBy': q['referredBy']});
      case 'career':
        if (n == 1) return t(NotificationKinds.career);
        if (n == 3 && s[1] == 'applications') {
          return t(NotificationKinds.applicationCandidate, {'applicationId': s[2]});
        }
        if (n == 2 && s[1] == 'alerts') return t(NotificationKinds.jobAlert, {'searchId': q['search']});
        if (n == 2 && s[1] == 'plans') return t(NotificationKinds.membershipPlans, {'audience': 'SEEKER'});
      case 'talent':
        if (n == 1) return t(NotificationKinds.talentSearch, {'searchId': q['savedSearch']});
      case 'manage':
        if (at(['manage', 'jobs', '*', 'edit']) && n == 4) return t(NotificationKinds.jobEdit, {'jobId': s[2]});
        if (at(['manage', 'jobs', '*', 'pipeline']) && n == 4) {
          return t(NotificationKinds.applicationEmployer, {'jobId': s[2], 'applicationId': q['applicant']});
        }
        if (at(['manage', 'interviews']) && n == 3) return t(NotificationKinds.interviewPanel, {'interviewId': s[2]});
        if (at(['manage', 'team']) && n == 2) return t(NotificationKinds.team, {'tab': q['tab']});
        if (at(['manage', 'requirements']) && n == 3) {
          return t(NotificationKinds.rfqOwner, {'rfqId': s[2], 'bidId': q['bid'], 'section': q['section']});
        }
        if (at(['manage', 'bids']) && n == 3) {
          return t(NotificationKinds.rfqSupplier, {'rfqId': s[2], 'section': q['section']});
        }
        if (at(['manage', 'articles']) && n == 2) return t(NotificationKinds.articlesMine, {'articleId': q['edit']});
      case 'invite':
        if (n == 2) return t(NotificationKinds.teamInvite, {'token': s[1]});
      case 'account':
        if (n == 2 && s[1] == 'companies') return t(NotificationKinds.accountCompanies);
      case 'companies':
        if (n == 2) return t(NotificationKinds.companyPage, {'companyId': s[1], 'tab': q['tab']});
      case 'company':
        if (n == 1) return t(NotificationKinds.companyWorkspace, {'tab': q['tab']});
      case 'rfq':
        if (n == 2) return t(NotificationKinds.rfqPublic, {'rfqId': s[1]});
      case 'products':
        if (n == 2) return t(NotificationKinds.product, {'productId': s[1]});
      case 'mentorship':
        if (n == 4 && s[1] == 'my' && s[2] == 'sessions') {
          return t(NotificationKinds.mentorPurchase, {
            'purchaseId': s[3],
            'side': 'buyer',
            'purchaseType': 'ONE_ON_ONE',
          });
        }
        if (n == 3 && s[1] == 'my') {
          return t(NotificationKinds.mentorshipPairing, {
            'mentorshipId': s[2],
            'sessionId': q['session'],
            'taskId': q['task'],
          });
        }
        if (n == 2 && s[1] == 'my') {
          return t(NotificationKinds.mentorshipMine, {
            'tab': q['tab'],
            'purchaseId': q['purchase'],
            'concernId': q['concern'],
          });
        }
        if (n == 3 && s[1] == 'groups') return t(NotificationKinds.mentorshipGroupSession, {'sessionId': s[2]});
        if (n == 3 && s[1] == 'programmes') return t(NotificationKinds.mentorshipProgramme, {'slug': s[2]});
        if (n == 3 && s[1] == 'certificates') {
          return t(NotificationKinds.mentorshipCertificate, {'certificateId': s[2]});
        }
        if (n == 2 && s[1] == 'cpd') return t(NotificationKinds.mentorshipCpd);
        if (n == 3 && s[1] == 'mentors') {
          return t(NotificationKinds.mentorProfile, {'mentorProfileId': s[2], 'section': fragment});
        }
        if (n == 2 && s[1] == 'mentors') return t(NotificationKinds.mentorDirectory);
        if (n == 2 && s[1] == 'become-a-mentor') return t(NotificationKinds.mentorApplication);
        if (n == 2 && s[1] == 'mentor') {
          return t(NotificationKinds.mentorDesk, {'tab': q['tab'], 'lane': q['lane'], 'focusId': q['focus']});
        }
      case 'learning':
        if (n >= 3 && n <= 4 && s[1] == 'assessment') {
          return t(NotificationKinds.learningAssessment, {'courseCode': s[2], 'paperSlug': n == 4 ? s[3] : null});
        }
        if (n == 3 && s[1] == 'professional-development') return t(NotificationKinds.learningCourse, {'code': s[2]});
        if (n == 3 && s[1] == 'courses') return t(NotificationKinds.learningWorkspace, {'code': s[2], 'tab': q['tab']});
        if (n == 2 && s[1] == 'partners') return t(NotificationKinds.learningPartners, {'apply': q['apply']});
      case 'events':
        if (n == 2) return t(NotificationKinds.event, {'eventId': s[1], 'slug': s[1]});
      case 'community':
        if (n == 1) return t(NotificationKinds.forum);
        if (n == 2) {
          final reply = fragment.startsWith('reply-') ? fragment.substring(6) : null;
          return t(NotificationKinds.forumThread, {'slug': s[1], 'replyId': reply});
        }
      case 'blogs':
        if (n == 2) return t(NotificationKinds.blog, {'slug': s[1]});
      case 'members':
        if (n == 2) return t(NotificationKinds.member, {'userId': s[1]});
      case 'documents':
        if (n == 1) return t(NotificationKinds.documents);
      case 'messaging':
        if (n == 1) {
          final c = q['c'];
          if (c == null || c.isEmpty) return t(NotificationKinds.messaging, {'inbox': q['inbox']});
          return t(NotificationKinds.conversation, {'conversationId': c, 'messageId': q['m'], 'inbox': q['inbox']});
        }
      case 'notifications':
        if (n == 1) return t(NotificationKinds.notifications, {'tab': q['tab']});
      case 'profile':
        if (n == 1) return t(NotificationKinds.profile, {'tab': q['tab']});
      case 'support':
        if (n == 1) return t(NotificationKinds.support);
        if (n == 2) return t(NotificationKinds.supportTicket, {'ticketId': s[1]});
      case 'pricing':
        if (n <= 2) return t(NotificationKinds.membershipPlans, {'slug': n == 2 ? s[1] : null});
      case 'membership':
        if (n == 2 && s[1] == 'history') return t(NotificationKinds.membershipHistory, {'audience': q['audience']});
      case 'refer':
        if (n == 1) return t(NotificationKinds.refer);
        if (n == 2 && s[1] == 'credits') return t(NotificationKinds.refer, {'credits': 'true'});
      case 'advertise':
        if (n == 1) return t(NotificationKinds.advertise, {'placementId': q['placement']});
      case 'dashboard':
        if (n == 1) return t(NotificationKinds.dashboard);
      case 'marketing':
        if (n == 1) return t(NotificationKinds.adminMarketing);
      case 'admin':
        if (n == 3 && s[1] == 'jobs' && s[2] == 'review') {
          return t(NotificationKinds.adminJobReview, {'jobId': q['job']});
        }
        if (n == 2 && s[1] == 'verification') {
          if (q['view'] == 'kyc') {
            return t(NotificationKinds.adminVerificationCompany, {'status': q['status'], 'searchKey': q['search']});
          }
          return t(NotificationKinds.adminVerificationSupplier, {'vendorId': q['vendor']});
        }
        if (n == 3 && s[1] == 'companies') return t(NotificationKinds.adminCompany, {'companyId': s[2]});
        if (n == 2 && s[1] == 'mentorship') {
          return t(NotificationKinds.adminMentorshipConcern, {'concernId': q['concern']});
        }
        if (n >= 2 && s[1] == 'learning') {
          return t(NotificationKinds.adminLearning, {
            'section': n >= 3 ? s[2] : null,
            'courseId': q['course'],
            'leadId': q['lead'],
            'assignmentId': q['assignment'],
          });
        }
        if (n == 2 && s[1] == 'forum') {
          return t(NotificationKinds.adminForum, {'tab': q['tab'], 'reportId': q['report'], 'slug': q['slug']});
        }
        if (n == 2 && s[1] == 'blogs') return t(NotificationKinds.adminBlogs, {'articleId': q['review']});
        if (n == 3 && s[1] == 'documents' && s[2] == 'reports') {
          return t(NotificationKinds.adminDocumentReports, {'reportId': q['report']});
        }
        if (n == 3 && s[1] == 'messaging' && s[2] == 'reports') {
          return t(NotificationKinds.adminMessageReports, {'reportId': q['report']});
        }
        if (n == 2 && s[1] == 'support') return t(NotificationKinds.adminSupportTicket, {'ticketId': q['ticket']});
        if (n == 2 && s[1] == 'subscriptions') return t(NotificationKinds.adminSubscriptions);
        if (n == 2 && s[1] == 'contact') return t(NotificationKinds.adminContact, {'messageId': q['message']});
    }
    return t(NotificationKinds.path, {'path': path});
  }
}

/// Every kind [NotificationTarget.parse] gives, with the params each carries.
/// The API's kinds come from `backend/src/modules/notifications/notification-targets.ts`.
abstract final class NotificationKinds {
  // Hiring
  /// `/jobs/:jobId` · jobId, referredBy?
  static const job = 'job';

  /// `/manage/jobs/:jobId/edit` · jobId
  static const jobEdit = 'job.edit';

  /// `/manage/jobs/:jobId/pipeline?applicant=` · jobId, applicationId
  static const applicationEmployer = 'application.employer';

  /// `/career/applications/:id` · applicationId
  static const applicationCandidate = 'application.candidate';

  /// `/manage/interviews/:id` · interviewId
  static const interviewPanel = 'interview.panel';

  /// `/career/alerts?search=` · searchId
  static const jobAlert = 'jobAlert';

  /// `/talent?savedSearch=` · searchId
  static const talentSearch = 'talentSearch';

  /// `/career`
  static const career = 'career';

  /// `/admin/jobs/review?job=` · jobId
  static const adminJobReview = 'admin.jobReview';

  // Companies and teams
  /// `/manage/team?tab=` · tab?
  static const team = 'team';

  /// `/invite/:token` · token
  static const teamInvite = 'team.invite';

  /// `/account/companies`
  static const accountCompanies = 'account.companies';

  /// `/companies/:id?tab=` · companyId, tab?
  static const companyPage = 'company.page';

  /// `/company?tab=` · tab?
  static const companyWorkspace = 'company.workspace';

  /// `/admin/verification?vendor=` · vendorId?
  static const adminVerificationSupplier = 'admin.verification.supplier';

  /// `/admin/verification?view=kyc&status=&search=` · status, searchKey
  static const adminVerificationCompany = 'admin.verification.company';

  /// `/admin/companies/:id` · companyId
  static const adminCompany = 'admin.company';

  // Requirements, enquiries and bids
  /// `/manage/requirements/:rfqId?bid=&section=` · rfqId, bidId?, section?
  static const rfqOwner = 'rfq.owner';

  /// `/manage/bids/:rfqId?section=` · rfqId, section?
  static const rfqSupplier = 'rfq.supplier';

  /// `/rfq/:rfqId` (a requirement's public posting; records and context strips) · rfqId
  static const rfqPublic = 'rfq.public';

  /// `/products/:id` (records) · productId
  static const product = 'product';

  // Mentorship
  /// `/mentorship/my/:mentorshipId?session=&task=` · mentorshipId, sessionId?, taskId?
  static const mentorshipPairing = 'mentorship.pairing';

  /// `/mentorship/my?tab=&purchase=&concern=` · tab?, purchaseId?, concernId?
  static const mentorshipMine = 'mentorship.mine';

  /// `/mentorship/groups/:id` · sessionId
  static const mentorshipGroupSession = 'mentorship.groupSession';

  /// `/mentorship/programmes/:slug` · slug
  static const mentorshipProgramme = 'mentorship.programme';

  /// `/mentorship/certificates/:id` · certificateId
  static const mentorshipCertificate = 'mentorship.certificate';

  /// `/mentorship/cpd`
  static const mentorshipCpd = 'mentorship.cpd';

  /// `/mentorship/mentors/:id#reviews` · mentorProfileId, section?
  static const mentorProfile = 'mentor.profile';

  /// `/mentorship/mentors`
  static const mentorDirectory = 'mentor.directory';

  /// `/mentorship/become-a-mentor`
  static const mentorApplication = 'mentor.application';

  /// `/mentorship/mentor?tab=&lane=&focus=` · tab?, lane?, focusId?
  static const mentorDesk = 'mentor.desk';

  /// `/mentorship/my/sessions/:purchaseId` (a bought 1:1) · purchaseId, side, purchaseType
  static const mentorPurchase = 'mentor.purchase';

  /// `/admin/mentorship?tab=concerns&concern=` · concernId
  static const adminMentorshipConcern = 'admin.mentorship.concern';

  // Learning
  /// `/learning/assessment/:code/:slug?` · courseCode, paperSlug?
  static const learningAssessment = 'learning.assessment';

  /// `/learning/professional-development/:code` · code
  static const learningCourse = 'learning.course';

  /// `/learning/courses/:code?tab=` · code, tab?
  static const learningWorkspace = 'learning.workspace';

  /// `/admin/learning/:section?` · section?, courseId?, leadId?, assignmentId?
  static const adminLearning = 'admin.learning';

  /// `/learning/partners?apply=1` · apply?
  static const learningPartners = 'learning.partners';

  // Events
  /// `/events/:slugOrId` · eventId and slug (the same segment)
  static const event = 'event';

  // Community and content
  /// `/community/:slug#reply-<id>` · slug, replyId?
  static const forumThread = 'forum.thread';

  /// `/community`
  static const forum = 'forum';

  /// `/admin/forum?tab=&report=&slug=` · tab, reportId?, slug?
  static const adminForum = 'admin.forum';

  /// `/blogs/:slug` · slug
  static const blog = 'blog';

  /// `/manage/articles?edit=` · articleId?
  static const articlesMine = 'articles.mine';

  /// `/admin/blogs?review=` · articleId?
  static const adminBlogs = 'admin.blogs';

  /// `/members/:userId` · userId
  static const member = 'member';

  /// `/documents`
  static const documents = 'documents';

  /// `/admin/documents/reports?report=` · reportId?
  static const adminDocumentReports = 'admin.documentReports';

  /// `/messaging?c=&m=&inbox=` · conversationId, messageId?, inbox? (opened in the app by this feature)
  static const conversation = 'conversation';

  /// `/messaging?inbox=` (no thread named) · inbox? (opened in the app by this feature)
  static const messaging = 'messaging';

  /// `/notifications?tab=` · tab? (opened in the app by this feature)
  static const notifications = 'notifications';

  /// `/admin/messaging/reports?report=` · reportId?
  static const adminMessageReports = 'admin.messageReports';

  /// `/profile?tab=credentials` · tab
  static const profile = 'profile';

  // Support
  /// `/support/:ticketId` · ticketId
  static const supportTicket = 'support.ticket';

  /// `/admin/support?ticket=` · ticketId
  static const adminSupportTicket = 'admin.supportTicket';

  /// `/support`
  static const support = 'support';

  // Plans, payments, referrals, placements
  /// `/career/plans` (audience SEEKER) or `/pricing/:slug` · audience? or slug?
  static const membershipPlans = 'membership.plans';

  /// `/membership/history?audience=` · audience?
  static const membershipHistory = 'membership.history';

  /// `/admin/subscriptions`
  static const adminSubscriptions = 'admin.subscriptions';

  /// `/refer` or `/refer/credits` · credits?
  static const refer = 'refer';

  /// `/advertise?placement=` · placementId?
  static const advertise = 'advertise';

  /// `/dashboard`
  static const dashboard = 'dashboard';

  // Staff inboxes
  /// `/marketing`
  static const adminMarketing = 'admin.marketing';

  /// `/admin/contact?message=` · messageId?
  static const adminContact = 'admin.contact';

  /// Any other page (an onboarding step, a row sent before Oct 2026) · path
  static const path = 'path';

  /// A notification with no page.
  static const none = 'none';

  /// Every kind, for a registry that wants to list what it handles.
  static const all = [
    job, jobEdit, applicationEmployer, applicationCandidate, interviewPanel, jobAlert, talentSearch, career, //
    adminJobReview, team, teamInvite, accountCompanies, companyPage, companyWorkspace, adminVerificationSupplier,
    adminVerificationCompany, adminCompany, rfqOwner, rfqSupplier, rfqPublic, product, mentorshipPairing,
    mentorshipMine, mentorshipGroupSession, mentorshipProgramme, mentorshipCertificate, mentorshipCpd, mentorProfile,
    mentorDirectory, mentorApplication, mentorDesk, mentorPurchase, adminMentorshipConcern, learningAssessment,
    learningCourse, learningWorkspace, adminLearning, learningPartners, event, forumThread, forum, adminForum, blog,
    articlesMine, adminBlogs, member, documents, adminDocumentReports, conversation, messaging, notifications,
    adminMessageReports, profile, supportTicket, adminSupportTicket, support, membershipPlans, membershipHistory,
    adminSubscriptions, refer, advertise, dashboard, adminMarketing, adminContact, path, none,
  ];
}
