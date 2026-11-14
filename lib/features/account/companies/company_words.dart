/// The sentences "My companies" and "Create a company page" say, as the
/// website words them (`messages/en/account.json`), and the small formatters
/// they share.
library;

import '../../../core/util/time_ago.dart';
import '../account_labels.dart';
import '../account_models.dart';

class CompanyWords {
  CompanyWords._();

  static const listTitle = 'My Companies';
  static const staffNote = 'ICR staff accounts are personal: they do not create or join companies.';
  static const couldNotLoad = 'Unable to load your companies.';
  static const couldNotLoadTitle = 'Unable to Load Your Companies';

  static const emptyTitle = 'You Are Not Part of a Company Yet';
  static const emptyBody =
      'Create a company page to buy, sell or hire on its behalf, or find your company in the directory and '
      'request to join.';

  static const workspaces = 'All Companies';
  static const workspacesLead = 'Switch between companies';
  static const personalAccount = 'Personal Account';
  static const actingAsYourself = 'Acting as yourself';
  static const active = 'Active';

  static const onlyAdmin = 'You are the only admin. Appoint another admin from the team page before leaving.';

  static const awaitingApproval = 'Awaiting Approval';
  static const awaitingExplain = 'The company’s admins review each request. You can withdraw one at any time.';

  static const askToJoinTitle = 'Ask to Join a Company';
  static const askToJoinLead =
      'Find your company on ICR. An admin there decides. Until then nothing changes for you, and they choose '
      'the role you join with.';

  static const invitationsTitle = 'Waiting for You';
  static const invitationsExplain =
      'An admin added you to their team. You join only when you accept, and you can decline.';
  static const accept = 'Accept';
  static const accepting = 'Joining…';
  static const decline = 'Decline';
  static const declining = 'Declining…';
  static const couldNotAccept = 'Unable to accept that invitation.';
  static const couldNotDecline = 'Unable to decline that invitation.';

  /// "Pune, Maharashtra", or null.
  static String? place(String? city, String? state) {
    final parts = [?city, ?state];
    return parts.isEmpty ? null : parts.join(', ');
  }

  /// "Company Admin · Pune, Maharashtra · Facility management services".
  static String facts(MyCompany c) {
    final parts = <String>[
      roleLabel(c.role),
      ?place(c.city, c.state),
      ?(c.industry == null ? null : industryLabel(c.industry)),
    ];
    return parts.join(' · ');
  }

  static String members(int n) => n == 1 ? '1 member' : '$n members';

  static String awaiting(int n) => '$n awaiting approval';

  /// "Requested as Professional · 3d ago".
  static String requested(JoinRequest r, {DateTime? now}) {
    final at = r.requestedAt == null ? null : DateTime.tryParse(r.requestedAt!);
    final role = roleLabel(r.role);
    return at == null ? 'Requested as $role' : 'Requested as $role · ${timeAgo(at, now: now)}';
  }

  /// "Added as Recruiter by Chetan CompanyAdmin · 3d ago", with the office after it when the place is in one.
  static String invited(CompanyInvitation i, {DateTime? now}) {
    final at = i.invitedAt == null ? null : DateTime.tryParse(i.invitedAt!);
    final role = roleLabel(i.role);
    final by = i.invitedBy == null ? '' : ' by ${i.invitedBy}';
    final ago = at == null ? '' : ' · ${timeAgo(at, now: now)}';
    final office = i.branchName == null ? '' : ' · ${i.branchName}';
    return 'Added as $role$by$ago$office';
  }

  static List<String> leavePoints(MyCompany c) => [
    'You lose access to ${c.name}’s team, jobs, requirements and dashboard.',
    'Your ICR account, profile and messages stay yours.',
    'To come back, an admin must invite you again or approve a new request.',
    if (c.active) 'You continue as your next company, or as yourself if you have none.',
  ];
}
