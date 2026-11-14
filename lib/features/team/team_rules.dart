/// Who may do what on the Team page, as the website's `TeamPanel` and the API's `TeamController` decide it. Pure, so
/// the screen, the sheets and the tests read one set of rules.
library;

import '../../core/auth/session_user.dart';
import 'team_models.dart';

/// The signed-in person as the Team page needs them: who they are, the role they hold at the company they act for
/// (the role rides in the token), and that company.
class TeamViewer {
  const TeamViewer({required this.id, required this.role, this.companyId, this.learningPartner = false});

  factory TeamViewer.of(SessionUser user) =>
      TeamViewer(id: user.id, role: user.role, companyId: user.companyId, learningPartner: user.learningPartner);

  final String id;
  final String role;
  final String? companyId;

  /// The company is a learning partner ICR approved (`UserDto.learningPartner`).
  final bool learningPartner;

  /// Learning roles (Course Admin, Trainer…) are a company admin's to give, at a learning-partner company — the
  /// website's `TeamPanel` (`learningPartner && role === COMPANY_ADMIN`) and the API's `learningRolesFor`.
  bool get givesLearningRoles => learningPartner && role == 'COMPANY_ADMIN';

  /// The learning roles, in the website's order (`LearningStaffRole`).
  static const learningStaffRoles = ['COURSE_ADMIN', 'BATCH_ADMIN', 'ENROLMENT_ADMIN', 'TRAINER', 'FINANCE'];

  /// A plain member (PROFESSIONAL) joins only to teach or run enrolments, so needs at least one learning role —
  /// the API's `grantableMainRole`.
  static bool memberNeedsLearningRole(String role, List<String> learningRoles) =>
      role == 'PROFESSIONAL' && learningRoles.isEmpty;

  /// The roles that run a company's team (`TEAM_MANAGER_ROLES`); everyone else is told the page is not theirs.
  static const managerRoles = {'COMPANY_ADMIN', 'BRANCH_ADMIN', 'VENDOR', 'SUPER_ADMIN'};

  bool get reachesPage => managerRoles.contains(role);

  /// The team belongs to a company; with none, nothing on it can be read.
  bool get hasCompany => companyId != null && companyId!.isNotEmpty;

  /// A supplier account: its team is its supplier accounts, one role, no offices.
  bool get isSupplier => role == 'VENDOR';

  bool get isBranchAdmin => role == 'BRANCH_ADMIN';

  /// Edit and remove members: company admins and suppliers (the API refuses everyone else).
  bool get canManage => role == 'COMPANY_ADMIN' || role == 'SUPER_ADMIN' || isSupplier;

  /// Only a company admin may ask whether an address is on ICR while inviting.
  bool get canLookup => role == 'COMPANY_ADMIN' || role == 'SUPER_ADMIN';

  /// Everyone on the company counts towards its seats, so a supplier sees the whole team but manages only supplier
  /// accounts; the API refuses the rest.
  bool manages(String memberRole) => !isSupplier || memberRole == 'VENDOR';

  /// The role choices of "Invite by email". At a learning-partner company the admin may also invite a Member —
  /// someone who joins only for learning roles (the website's `memberLearningOnly`).
  List<String> get inviteRoles => isSupplier
      ? const ['VENDOR']
      : isBranchAdmin
      ? const ['RECRUITER', 'HIRING_MANAGER']
      : [
          'COMPANY_ADMIN',
          'BRANCH_ADMIN',
          'RECRUITER',
          'HIRING_MANAGER',
          'VENDOR',
          'BUYER',
          if (givesLearningRoles) 'PROFESSIONAL',
        ];

  /// The role choices of "Add Existing ICR Member": never Company Admin (that needs an invite they accept); Member only
  /// where learning roles can be given with it (the API refuses a Member without one).
  List<String> get addRoles => isSupplier
      ? const ['VENDOR']
      : isBranchAdmin
      ? const ['RECRUITER', 'HIRING_MANAGER']
      : ['BRANCH_ADMIN', 'RECRUITER', 'HIRING_MANAGER', 'VENDOR', 'BUYER', if (givesLearningRoles) 'PROFESSIONAL'];

  /// The role the first screen of either form starts on.
  String get defaultRole => isSupplier ? 'VENDOR' : 'RECRUITER';

  /// The roles an admin may name when approving a request.
  static const approveRoles = ['BRANCH_ADMIN', 'RECRUITER', 'HIRING_MANAGER', 'PROFESSIONAL', 'VENDOR'];

  /// The roles a member can be changed to; their own stays pickable whatever it is. Never Company Admin.
  List<String> editRoles(String memberRole) {
    final base = isBranchAdmin
        ? const ['RECRUITER', 'HIRING_MANAGER']
        : ['BRANCH_ADMIN', 'RECRUITER', 'HIRING_MANAGER', 'VENDOR', 'BUYER', if (givesLearningRoles) 'PROFESSIONAL'];
    return base.contains(memberRole) ? base : [memberRole, ...base];
  }

  /// Whether a member's row offers Edit and Remove: an active colleague who is not the viewer or ICR staff, and one
  /// the viewer manages.
  bool actsOn(TeamMember m) => canManage && m.isActive && m.id != id && m.role != 'SUPER_ADMIN' && manages(m.role);

  /// Role and office can be changed here; a fellow Company Admin's cannot, and a supplier's team has one role.
  bool canEdit(TeamMember m) => actsOn(m) && !isSupplier && m.role != 'COMPANY_ADMIN';

  /// The office a role can be given: not by an office admin (they invite into their own), and not on a supplier
  /// account.
  bool picksOffice(String role) => !isBranchAdmin && !isSupplier && role != 'VENDOR' && role != 'PROFESSIONAL';
}

/// The Team page's tabs.
enum TeamTab { members, requests, pending }

/// The tab the website's `?tab=` names: `requests` and `pending` open there, anything else on Members.
TeamTab teamTabOf(String? tab) => switch (tab) {
  'requests' => TeamTab.requests,
  'pending' => TeamTab.pending,
  _ => TeamTab.members,
};
