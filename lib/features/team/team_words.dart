/// The sentences the Team page says, as the website words them (`messages/en/manage.json`: TeamPage, TeamInner,
/// JoinRequests, PendingAdds, EditMemberDialog, RemoveMemberDialog, InviteDialog, AddPersonDialog), and the small
/// formatters they share.
library;

import '../../core/util/time_ago.dart';
import 'team_models.dart';

class TeamWords {
  TeamWords._();

  static const title = 'Team Management';
  static const subtitleHiring = 'Manage your team and access across offices.';
  static const subtitleSupplier = 'Everyone who works on your company account.';
  static const noCompanyLead = 'Team members and invites belong to a company.';
  static const noAccessTitle = 'This Page Is for Your Company’s Team Admins';
  static const noAccessBody = 'Company admins, office admins and supplier accounts run the team.';
  static const couldNotLoad = 'Unable to load the team.';
  static const couldNotLoadTitle = 'Unable to Load the Team';

  static const members = 'Members';
  static const requests = 'Requests';
  static const pending = 'Pending';

  static const addSomeone = 'Add Existing ICR Member';
  static const inviteByEmail = 'Invite Team Member';

  // Members
  static const noMembersTitle = 'No Team Members Yet';
  static const emptyHiring = 'Invite office admins, recruiters and hiring managers.';
  static const emptySupplier = 'Invite colleagues to work on your listing.';
  static const companyWide = 'Company-Wide';
  static const active = 'Active';
  static const deactivated = 'Deactivated';
  static const edit = 'Edit Access';
  static const remove = 'Remove';
  static const allInboxTopics = 'All Topics';
  static const noInboxTopics = 'None';

  // Requests
  static String askedToJoin(int n) => 'Pending Access Requests ($n)';
  static const noRequests = 'No pending requests. Requests to join your company will appear here.';
  static const approve = 'Approve';
  static const decline = 'Decline';
  static const joinAs = 'Assign Role';
  static const office = 'Office';
  static const officeOptional = 'Office (Optional)';
  static const officeHelp =
      'The office they cover. Recruiters, hiring managers and office admins at a company with offices need one.';
  static const noOffice = 'No Office';

  // Pending
  static String waitingToAccept(int n) => 'Waiting to Accept ($n)';
  static String pendingInvites(int n) => 'Pending Invitations ($n)';
  static const nothingPending = 'Nothing is pending. People you add or invite will appear here until they respond.';
  static const cancel = 'Cancel';
  static const revoke = 'Revoke';

  // Edit and remove
  static String editTitle(String name) => 'Edit $name';
  static String removeTitle(String name) => 'Remove $name from the Team?';
  static const removeBody =
      'They will lose access to this company’s work immediately. Their ICR account and their other companies are '
      'not affected.';
  static String declineTitle(String name) => 'Decline $name’s Request?';
  static const declineBody = 'They will be notified that it was declined. They can ask again later.';
  static const role = 'Role';

  // Add Existing ICR Member
  static const searchMembers = 'Search ICR Members by Name';
  static const typeAName = 'Enter a name';
  static const nobodyFound = 'No members found.';
  static const addHelp =
      'They will be notified and will join once they accept from My Companies. To make someone an admin, send an invite '
      'instead.';
  static const askToJoin = 'Ask Them to Join';
  static const asking = 'Asking…';
  static const change = 'Change';

  // Invite Team Member
  static const email = 'Email';
  static const sendInvite = 'Send Invite';
  static const sending = 'Sending…';
  static const checking = 'Checking…';
  static const alreadyOnTeam = 'This person is already on your team.';
  static const onIcr = 'On ICR';
  static const onIcrInvite = 'This email has an ICR account. They will receive an invite to accept.';
  static const notOnIcr = 'Not on ICR yet. They will receive an email to join ICR and your team.';
  static const pendingAdd =
      'You have already added this person and they have not accepted yet. Cancel it in the Pending tab to ask again.';
  static const addsPending = 'They will be asked in the app and will join once they accept from My Companies.';
  static const pendingInvite = 'An invite to this email is already pending. Sending again replaces it.';
  static const adminNeedsInvite = 'Company Admin rights require an invite the person accepts, so this sends an invite.';
  static const joinSupplier = 'They join as a supplier account on your company’s listing.';
  static const joinYourOffice = 'Invitees join your office automatically.';
  static const officeOptionalHelp = 'Optional. The member covers this office and everything inside it.';

  // Learning roles, at a learning-partner company (the website's `LearningRolesField`, `TeamPanel`,
  // `LearningRolesDialog`).
  static const learningRoles = 'Learning Roles';
  static const pickAnyNumber = 'Select any number. Each opens its pages in the Learning console.';
  static const pickALearningRole = 'Select at least one learning role for a member.';
  static const keepOne = 'A member who joined for learning roles keeps at least one.';
  static const memberLearningOnly = 'Member (Learning Roles Only)';

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
