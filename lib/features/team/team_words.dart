/// The sentences the Team page says, as the website words them (`messages/en/manage.json`: TeamPage, TeamInner,
/// JoinRequests, PendingAdds, EditMemberDialog, RemoveMemberDialog, InviteDialog, AddPersonDialog), and the small
/// formatters they share.
library;

import '../../core/util/time_ago.dart';
import 'team_models.dart';

class TeamWords {
  TeamWords._();

  static const title = 'Team';
  static const subtitleHiring = 'Your hiring team across offices.';
  static const subtitleSupplier = 'Everyone who works on your company account.';
  static const noCompanyLead = 'Team members and invites belong to a company.';
  static const noAccessTitle = 'This page is for your company’s team admins';
  static const noAccessBody = 'Company admins, office admins and supplier accounts run the team.';
  static const couldNotLoad = 'Could not load the team.';

  static const members = 'Members';
  static const requests = 'Requests';
  static const pending = 'Pending';

  static const addSomeone = 'Add someone on ICR';
  static const inviteByEmail = 'Invite by email';

  // Members
  static const noMembersTitle = 'No team members yet';
  static const emptyHiring = 'Invite office admins, recruiters and hiring managers.';
  static const emptySupplier = 'Invite colleagues to work on your listing.';
  static const companyWide = 'Company-wide';
  static const active = 'Active';
  static const deactivated = 'Deactivated';
  static const edit = 'Edit';
  static const remove = 'Remove';
  static const allInboxTopics = 'All topics';
  static const noInboxTopics = 'None';

  // Requests
  static String askedToJoin(int n) => 'Asked to join ($n)';
  static const noRequests = 'Nobody is waiting to join. Requests to join your company show here.';
  static const approve = 'Approve';
  static const decline = 'Decline';
  static const joinAs = 'Join as';
  static const office = 'Office';
  static const officeOptional = 'Office (optional)';
  static const officeHelp =
      'The office they cover. Recruiters, hiring managers and office admins at a company with offices need one.';
  static const noOffice = 'No office';

  // Pending
  static String waitingToAccept(int n) => 'Waiting to accept ($n)';
  static String pendingInvites(int n) => 'Pending invites ($n)';
  static const nothingPending = 'Nothing is waiting. People you add or invite show here until they answer.';
  static const cancel = 'Cancel';
  static const revoke = 'Revoke';

  // Edit and remove
  static String editTitle(String name) => 'Edit $name';
  static String removeTitle(String name) => 'Remove $name from the team?';
  static const removeBody =
      'They lose access to this company’s work at once. Their ICR account, and any other company they belong to, '
      'stay theirs.';
  static String declineTitle(String name) => 'Decline $name’s request?';
  static const declineBody = 'They are told it was declined. They can ask again later.';
  static const role = 'Role';

  // Add someone on ICR
  static const searchMembers = 'Search ICR members by name';
  static const typeAName = 'Type a name';
  static const nobodyFound = 'Nobody found';
  static const addHelp =
      'They are told, and join once they accept from My companies. To make someone an admin, send an invite '
      'instead.';
  static const askToJoin = 'Ask them to join';
  static const asking = 'Asking…';
  static const change = 'Change';

  // Invite by email
  static const email = 'Email';
  static const sendInvite = 'Send invite';
  static const sending = 'Sending…';
  static const checking = 'Checking…';
  static const alreadyOnTeam = 'This person is already on your team.';
  static const onIcr = 'On ICR';
  static const onIcrInvite = 'This address has an ICR account. They will get an invite to accept.';
  static const notOnIcr = 'Not on ICR yet. They will get an email to join ICR and your team.';
  static const pendingAdd =
      'You already added this person. They have not accepted yet; take it back from the Pending tab to ask again.';
  static const addsPending = 'They are asked in-app and join once they accept from My companies.';
  static const pendingInvite = 'An invite to this address is already waiting. Sending again replaces it.';
  static const adminNeedsInvite = 'Company Admin rights need an invite they accept, so this sends an invite.';
  static const joinSupplier = 'They join as a supplier account on your company’s listing.';
  static const joinYourOffice = 'Invitees join your office automatically.';
  static const officeOptionalHelp = 'Optional — the member covers this office and everything inside it';

  // Learning roles, at a learning-partner company (the website's `LearningRolesField`, `TeamPanel`,
  // `LearningRolesDialog`).
  static const learningRoles = 'Learning roles';
  static const pickAnyNumber = 'Tick any number. Each opens its pages in the Learning console.';
  static const pickALearningRole = 'Pick at least one learning role for a member.';
  static const keepOne = 'A member who joined for learning roles keeps at least one.';
  static const memberLearningOnly = 'Member (learning roles only)';

  /// "Added 3d ago · waiting for them to accept", "Added by Asha Rao 3d ago · waiting for them to accept".
  static String added(PendingAdd add, {DateTime? now}) {
    final ago = add.createdAt == null ? '' : ' ${timeAgo(add.createdAt!.toLocal(), now: now)}';
    return add.invitedBy == null
        ? 'Added$ago · waiting for them to accept'
        : 'Added by ${add.invitedBy}$ago · waiting for them to accept';
  }

  /// "Asked 2d ago".
  static String asked(TeamRequest request, {DateTime? now}) =>
      request.createdAt == null ? 'Asked to join' : 'Asked ${timeAgo(request.createdAt!.toLocal(), now: now)}';

  /// "expires 12 Nov 2026".
  static String expires(DateTime at) => 'expires ${day(at)}';

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /// "5 Nov 2026".
  static String day(DateTime at) {
    final local = at.toLocal();
    return '${local.day} ${_months[local.month - 1]} ${local.year}';
  }

  /// The topics a member answers in the company inbox, as one phrase: "All topics", "None", or their names.
  static String inbox(List<String> topics) {
    if (topics.length >= messageTopicCount) return allInboxTopics;
    if (topics.isEmpty) return noInboxTopics;
    return [for (final t in topics) messageTopicLabels[t] ?? t].join(', ');
  }
}
