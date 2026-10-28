/// The sentences "My companies" and "Create a company page" say, as the
/// website words them (`messages/en/account.json`), and the small formatters
/// they share.
library;

import '../../../core/util/time_ago.dart';
import '../account_labels.dart';
import '../account_models.dart';

class CompanyWords {
  CompanyWords._();

  static const listTitle = 'My companies';
  static const listIntro =
      'The companies you belong to on ICR. You work in one at a time, and your role, team and dashboard change with '
      'the company you select.';
  static const staffNote = 'ICR staff accounts are personal: they do not create or join companies.';
  static const couldNotLoad = 'Could not load your companies.';

  static const emptyTitle = 'You are not part of a company yet';
  static const emptyBody =
      'Create a company page to buy, sell or hire on its behalf, or find your organisation in the directory and '
      'request to join.';

  static const workspaces = 'All workspaces';
  static const workspacesLead = 'Switch between the companies you belong to. Your personal account is always available.';
  static const personalAccount = 'Personal account';
  static const actingAsYourself = 'Acting as yourself';
  static const active = 'Active';

  static const onlyAdmin = 'You are the only admin. Appoint another admin from the team page before leaving.';

  static const awaitingApproval = 'Awaiting approval';
  static const awaitingExplain = 'The company’s admins review each request. You can withdraw one at any time.';

  static const askToJoinTitle = 'Ask to join a company';
  static const askToJoinLead =
      'Find your organisation on ICR. An admin there decides; until then nothing changes for you, and they choose '
      'the role you join with.';

  static const principles = <(String, String)>[
    ('One company at a time', 'Switching reloads your dashboard, team, jobs and requirements for that company.'),
    ('Your profile stays yours', 'Your credentials and messages remain with you, whichever company you act for.'),
    ('Every company keeps an admin', 'The last admin appoints a successor from the team page before leaving.'),
  ];

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

  static List<String> leavePoints(MyCompany c) => [
    'You lose access to ${c.name}’s team, jobs, requirements and dashboard.',
    'Your ICR account, profile and messages stay yours.',
    'To come back, an admin must invite you again or approve a new request.',
    if (c.active) 'You carry on as your next company, or as yourself if you have none.',
  ];
}
