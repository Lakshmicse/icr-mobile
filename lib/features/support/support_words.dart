/// The words the website's support desk says, copied from `@icr/shared` (`SupportTicketStatus`,
/// `SUPPORT_TICKET_STATUS_LABELS`, `SUPPORT_TICKET_CATEGORY_LABELS` and `_HINTS`, `SUPPORT_TICKET_EVENT_LABELS`,
/// `MAX_SUPPORT_ATTACHMENTS`) and from `messages/en/support.json` and `common.json` (`RaiseTicketDialog`,
/// `AttachmentPicker`).
library;

class SupportWords {
  SupportWords._();

  // --- The list (`support.MyTicketsList`) ---------------------------------------------------------------------

  static const listTitle = 'Help & Support';
  static const listLead = 'Raise a request, follow it, and reply to the ICR team in one place.';
  static const commonQuestions = 'Common Questions';
  static const helpAnswered = 'This Was Helpful';
  static const helpThanks = 'Thank you';
  static const newRequest = 'New Request';
  static const searchMine = 'Search my requests';
  static const nothingOpen = 'No Open Requests';
  static const nothingOpenLead = 'When something is not working, raise a request here and follow its progress.';
  static const nothingMatches = 'No Matching Requests';
  static const couldNotLoad = 'Unable to load your requests.';
  static const couldNotLoadTitle = 'Unable to Load Your Requests';
  static const yourManager = 'Your ICR Account Manager';

  // --- A request (`support.TicketThread`, `support.TicketRoute`) ------------------------------------------------

  static const couldNotOpen =
      'Unable to open this request. It may have been removed, or it belongs to another account.';
  static const history = 'History';
  static const addAReply = 'Add a Reply';
  static const replyHint = 'Anything else that would help us';
  static const sendReply = 'Send Reply';
  static const sending = 'Sending…';
  static const replyNotSent = 'Your reply was not sent.';
  static const reopen = 'Reopen This Request';
  static const reopening = 'Reopening…';
  static const couldNotReopen = 'Unable to reopen this request.';
  static const didWeGetThisRight = 'Rate Our Support';
  static const submitRating = 'Submit Rating';
  static const youRatedThis = 'You rated this';
  static const couldNotRate = 'Your rating was not sent.';
  static const closedNote = 'This request is closed. If the issue returns, raise a new request.';
  static const waitingOnYou = 'We need more information from you to continue. Reply below.';

  static String aimToReply(int hours) =>
      'We aim to reply within $hours hours. You will receive a notification and an email when we reply.';

  /// "ICR-12 · Billing & payments · raised 3d ago".
  static String raisedLine(String reference, String category, String ago) => '$reference · $category · raised $ago';

  static const couldNotOpenFile = 'Unable to open this file. Try again.';
  static const fileNotShown = "This file's type can't be shown in the app.";

  // --- Raising one (`common.RaiseTicketDialog`, `common.AttachmentPicker`) ------------------------------------

  static const raiseTitle = 'Get Help from ICR';
  static const whatIsThisAbout = 'Select a Topic';
  static const about = 'About';
  static const beforeYouWrite = 'Common Questions on This Topic';
  static const subject = 'Subject';
  static const subjectHint = 'Summarise the problem in one line';
  static const whatHappened = 'What happened?';
  static const whatHappenedHint = 'What you did, what you expected, and what happened instead.';
  static const sendRequest = 'Send Request';
  static const couldNotLog = 'Unable to submit your request.';
  static const attachAFile = 'Attach a File';
  static const uploading = 'Uploading…';

  static String screenshotsHelp(int max) => 'Screenshots help. Up to $max files, 10 MB each.';

  static String couldNotUpload(String name) => '$name could not be uploaded. PDFs and images up to 10 MB.';

  // --- Codes ----------------------------------------------------------------------------------------------------

  /// `SUPPORT_TICKET_STATUS_LABELS`, as the member reads them.
  static const statusLabels = {
    'NEW': 'New',
    'OPEN': 'In Progress',
    'AWAITING_USER': 'Waiting on You',
    'RESOLVED': 'Resolved',
    'CLOSED': 'Closed',
  };

  static String status(String key) => statusLabels[key] ?? key;

  /// `SUPPORT_TICKET_EVENT_LABELS`.
  static const eventLabels = {
    'RAISED': 'Raised',
    'ASSIGNED': 'Assigned',
    'UNASSIGNED': 'Unassigned',
    'STATUS_CHANGED': 'Status changed',
    'PRIORITY_CHANGED': 'Priority changed',
    'CATEGORY_CHANGED': 'Category changed',
    'FIRST_RESPONSE': 'First reply sent',
    'REOPENED': 'Reopened',
    'RATED': 'Rated by the requester',
    'SLA_BREACHED': 'Response target missed',
  };

  static String event(String key) => eventLabels[key] ?? key;

  /// `SupportTicketCategory`: its key, `SUPPORT_TICKET_CATEGORY_LABELS` and `SUPPORT_TICKET_CATEGORY_HINTS`.
  static const categories = <(String, String, String)>[
    (
      'ACCOUNT_ACCESS',
      'Account & Sign-In',
      'Cannot sign in, lost access to an email or phone, a team invite that will not open.',
    ),
    (
      'BILLING_PAYMENTS',
      'Billing & Payments',
      'A payment that failed or charged twice, a refund, an invoice, a membership you did not expect.',
    ),
    (
      'VERIFICATION',
      'Verification',
      'Your company or supplier verification is stuck, or you were asked for documents you cannot supply.',
    ),
    (
      'JOBS_HIRING',
      'Jobs & Hiring',
      'A posting that will not publish, a rejected job, an applicant or interview problem.',
    ),
    (
      'MENTORSHIP',
      'Mentorship',
      'Bookings, sessions, plans or CPD. For conduct or safety, use "Report a concern" on the pairing instead.',
    ),
    (
      'MARKETPLACE_RFQ',
      'Marketplace & Requirements',
      'Your listing, your bids, or a requirement that is not reaching the right suppliers.',
    ),
    ('LEARNING', 'Learning Center', 'Course access, batches, assessments or certificates.'),
    (
      'COMMUNITY',
      'Community & Discussions',
      'The forum, chapters, councils or events. To report a specific post, use Report on the post.',
    ),
    ('BUG', 'Something Is Broken', 'Something does not work correctly. Describe what you did and what happened.'),
    ('FEATURE_REQUEST', 'Feature Request', 'A feature you would like ICR to add.'),
    ('OTHER', 'Something Else', 'Describe it in your own words.'),
  ];

  static String category(String key) {
    for (final (k, label, _) in categories) {
      if (k == key) return label;
    }
    return key;
  }

  static String categoryHint(String key) {
    for (final (k, _, hint) in categories) {
      if (k == key) return hint;
    }
    return '';
  }

  /// "ICR-12": the number as people say it out loud.
  static String reference(int n) => 'ICR-$n';

  /// `MAX_SUPPORT_ATTACHMENTS`.
  static const maxAttachments = 5;

  /// What a file may weigh (the API's upload limit).
  static const maxFileBytes = 10 * 1024 * 1024;

  /// The types the desk takes (the website's picker: PDF, PNG, JPEG, WEBP).
  static const fileExtensions = ['pdf', 'png', 'jpg', 'jpeg', 'webp'];

  /// Open tickets one requester may hold (`MAX_OPEN_SUPPORT_TICKETS_PER_USER`): the API says it in its own words.
  static const maxOpen = 10;
}
