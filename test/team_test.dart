import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/team/api_team_repository.dart';
import 'package:icr_mobile/features/team/demo_team_repository.dart';
import 'package:icr_mobile/features/team/team_models.dart';
import 'package:icr_mobile/features/team/team_screen.dart';

import 'helpers/account_harness.dart';
import 'helpers/fonts.dart';

/// The Team page (the website's `/manage/team`): Members, Requests and Pending with their counts, approving or
/// declining a request, taking an add or an invite back, editing and removing a member, adding someone on ICR and
/// inviting by email, with what each role may do.
void main() {
  setUpAll(loadAppFonts);

  const adminUser = 'u-asha';

  late AccountHarness h;
  late DemoTeamRepository repo;

  /// Pumps the screen as [role] at a company (or none), over the sample team unless [repository] is given.
  Future<void> pump(
    WidgetTester tester, {
    String role = 'COMPANY_ADMIN',
    String? companyId = 'co-1',
    String userId = adminUser,
    DemoTeamRepository? repository,
    TeamTab tab = TeamTab.members,
    VoidCallback? onCreateCompany,
    void Function(String)? onOpenMember,
    bool learningPartner = false,
    String? inviteLearningRole,
  }) async {
    repo = repository ?? DemoTeamRepository();
    h = AccountHarness();
    await h.signIn(tester, userJson(id: userId, role: role, companyId: companyId, learningPartner: learningPartner));
    usePhone(tester);
    await tester.pumpWidget(
      h.app(
        TeamScreen(
          repository: repo,
          initialTab: tab,
          searchDelay: Duration.zero,
          onCreateCompany: onCreateCompany,
          onOpenMember: onOpenMember,
          inviteLearningRole: inviteLearningRole,
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

  Future<void> tapKey(WidgetTester tester, String key) async {
    final target = find.byKey(Key(key));
    await reveal(tester, target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> tapTab(WidgetTester tester, TeamTab tab) async {
    await tester.tap(find.byKey(Key('team.tab.${tab.name}')));
    await tester.pumpAndSettle();
  }

  /// Opens a form's select field (its inner tap target, not the widget's middle) and picks a row of the list.
  Future<void> pickFrom(WidgetTester tester, String fieldKey, String label) async {
    final field = find.descendant(of: find.byKey(Key(fieldKey)), matching: find.byType(InkWell));
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(ListTile), matching: find.text(label)));
    await tester.pumpAndSettle();
  }

  bool saveEnabled(WidgetTester tester) {
    final button = find.descendant(of: find.byKey(const Key('sheet.save')), matching: find.byType(FilledButton));
    return tester.widget<FilledButton>(button).onPressed != null;
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('sheet.save')));
    await tester.pumpAndSettle();
  }

  group('the page', () {
    testWidgets('three tabs with their counts, the team on Members: role, office, status and inbox on each row', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Team Management'), findsOneWidget);
      expect(find.text('Manage your team and access across offices.'), findsOneWidget);
      expect(find.text('Members 6'), findsOneWidget);
      expect(find.text('Requests 1'), findsOneWidget);
      expect(find.text('Pending 2'), findsOneWidget, reason: 'one add from ICR and one email invite');
      expect(find.text('Asha Rao'), findsOneWidget);
      expect(find.text('asha@techcorp.example'), findsOneWidget);
      expect(find.text('Company Admin'), findsOneWidget);
      expect(find.text('Inbox Permissions: All Topics'), findsOneWidget);
      expect(find.byKey(const Key('team.member.inbox.u-hema')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('team.member.inbox.u-hema'))).data, 'Inbox Permissions: None');
      expect(tester.widget<Text>(find.byKey(const Key('team.member.inbox.u-bina'))).data, 'Inbox Permissions: Careers');
      await reveal(tester, find.byKey(const Key('team.member.u-dev')));
      expect(
        find.descendant(of: find.byKey(const Key('team.member.u-dev')), matching: find.text('Deactivated')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(const Key('team.member.u-asha')), matching: find.text('Company-Wide')),
        findsOneWidget,
        reason: 'no office reads Company-wide',
      );
    });

    testWidgets('a supplier account sees its own subtitle', (tester) async {
      await pump(tester, role: 'VENDOR', userId: 'u-vivek');
      expect(find.text('Everyone who works on your company account.'), findsOneWidget);
    });

    testWidgets('?tab=requests opens on Requests, ?tab=pending on Pending', (tester) async {
      expect(teamTabOf('requests'), TeamTab.requests);
      expect(teamTabOf('pending'), TeamTab.pending);
      expect(teamTabOf('members'), TeamTab.members);
      expect(teamTabOf(null), TeamTab.members);
      expect(teamTabOf('anything'), TeamTab.members);
      await pump(tester, tab: TeamTab.requests);
      expect(find.byKey(const Key('team.requests')), findsOneWidget);
      expect(find.text('Pending Access Requests (1)'), findsOneWidget);
      expect(find.text('Pooja Pillai'), findsOneWidget);
      expect(find.text('“I run facilities at your Pune site.”'), findsOneWidget);
      expect(find.byKey(const Key('team.members')), findsNothing);
    });

    testWidgets('a member row opens their profile when the caller gives a way', (tester) async {
      final opened = <String>[];
      await pump(tester, onOpenMember: opened.add);
      await tester.tap(find.byKey(const Key('team.member.open.u-bina')));
      await tester.pumpAndSettle();
      expect(opened, ['u-bina']);
    });

    testWidgets('a team that has nobody says what to do; an empty Requests and Pending say so', (tester) async {
      await pump(
        tester,
        repository: DemoTeamRepository(members: const [], requests: const [], adds: const [], invites: const []),
      );
      expect(find.text('No Team Members Yet'), findsOneWidget);
      expect(find.text('Invite office admins, recruiters and hiring managers.'), findsOneWidget);
      await tapTab(tester, TeamTab.requests);
      expect(find.byKey(const Key('team.requests.empty')), findsOneWidget);
      await tapTab(tester, TeamTab.pending);
      expect(find.byKey(const Key('team.pending.empty')), findsOneWidget);
    });

    testWidgets('a failed read says why with Try again; a pull reads every list again', (tester) async {
      final failing = DemoTeamRepository()..failures['members'] = ApiError('The server is busy.', statusCode: 503);
      await pump(tester, repository: failing);
      expect(find.text('The server is busy.'), findsOneWidget);
      failing.failures.clear();
      await tester.tap(find.byKey(const Key('account.retry')));
      await tester.pumpAndSettle();
      expect(find.text('Asha Rao'), findsOneWidget);
      final before = failing.count('members');
      await tester.fling(find.byKey(const Key('team.list')), const Offset(0, 400), 1000);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(failing.count('members'), before + 1);
      expect(failing.count('requests'), greaterThan(1));
    });

    testWidgets('someone acting for no company is told the team belongs to one, and offered a company to create', (
      tester,
    ) async {
      var created = 0;
      await pump(tester, companyId: null, onCreateCompany: () => created++);
      expect(find.byKey(const Key('team.noCompany')), findsOneWidget);
      expect(find.text('Team members and invites belong to a company.'), findsOneWidget);
      expect(repo.calls, isEmpty, reason: 'nothing is asked of the API without a company');
      await tester.tap(find.byKey(const Key('team.createCompany')));
      expect(created, 1);
    });

    testWidgets('a role that does not run a team gets a calm note, never a 403', (tester) async {
      await pump(tester, role: 'RECRUITER', userId: 'u-rahul');
      expect(find.byKey(const Key('team.noAccess')), findsOneWidget);
      expect(find.text('This Page Is for Your Company’s Team Admins'), findsOneWidget);
      expect(repo.calls, isEmpty);
      expect(find.byKey(const Key('team.add')), findsNothing);
    });
  });

  group('requests', () {
    testWidgets('Approve names the role and office, sends them, and the person moves to Members', (tester) async {
      await pump(tester, tab: TeamTab.requests);
      await tapKey(tester, 'team.approve.u-pooja');
      expect(find.text('Approve Pooja Pillai'), findsOneWidget);
      expect(find.text('Professional'), findsWidgets, reason: 'the role they asked for is where it starts');
      await pickFrom(tester, 'approve.role', 'Recruiter');
      await pickFrom(tester, 'approve.office', 'Head Office');
      await save(tester);
      expect(repo.sent['approve'], {'userId': 'u-pooja', 'role': 'RECRUITER', 'branchId': 'b-hq'});
      expect(find.text('Requests 0'), findsOneWidget);
      expect(find.text('Members 7'), findsOneWidget);
      expect(find.text('Pooja Pillai joined the team.'), findsOneWidget);
    });

    testWidgets('an approval with no office change sends no office; the first role is the one asked for', (
      tester,
    ) async {
      await pump(tester, tab: TeamTab.requests);
      await tapKey(tester, 'team.approve.u-pooja');
      await save(tester);
      expect(repo.sent['approve'], {'userId': 'u-pooja', 'role': 'PROFESSIONAL', 'branchId': null});
    });

    testWidgets('a refusal (a full team) is shown in the sheet, which keeps the role chosen', (tester) async {
      final r = DemoTeamRepository()
        ..failures['approve'] = ApiError(
          'Your plan includes 5 team members, counting pending invites.',
          statusCode: 403,
        );
      await pump(tester, repository: r, tab: TeamTab.requests);
      await tapKey(tester, 'team.approve.u-pooja');
      await pickFrom(tester, 'approve.role', 'Hiring Manager');
      await save(tester);
      expect(find.text('Your plan includes 5 team members, counting pending invites.'), findsOneWidget);
      expect(find.byKey(const Key('sheet.error')), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const Key('approve.role')), matching: find.text('Hiring Manager')),
        findsOneWidget,
      );
      r.failures.clear();
      await save(tester);
      expect(r.sent['approve'], containsPair('role', 'HIRING_MANAGER'));
      expect(find.byKey(const Key('approve.role')), findsNothing, reason: 'the sheet closed');
    });

    testWidgets('Decline asks first; backing out sends nothing, confirming declines', (tester) async {
      await pump(tester, tab: TeamTab.requests);
      await tapKey(tester, 'team.decline.u-pooja');
      expect(find.text('Decline Pooja Pillai’s Request?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.count('decline'), 0);
      expect(find.byKey(const Key('team.request.u-pooja')), findsOneWidget);
      await tapKey(tester, 'team.decline.u-pooja');
      await tester.tap(find.byKey(const Key('confirm.ok')));
      await tester.pumpAndSettle();
      expect(repo.count('decline'), 1);
      expect(find.text('Requests 0'), findsOneWidget);
      expect(find.byKey(const Key('team.requests.empty')), findsOneWidget);
    });
  });

  group('pending', () {
    testWidgets('an add from ICR shows who added them and when; Cancel takes it back and frees the seat', (
      tester,
    ) async {
      await pump(tester, tab: TeamTab.pending);
      expect(find.text('Waiting to Accept (1)'), findsOneWidget);
      expect(find.text('Added by Asha Rao 3d ago · waiting for them to accept'), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const Key('team.add.u-kiran')), matching: find.text('Recruiter')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(const Key('team.add.u-kiran')), matching: find.text('Head Office')),
        findsOneWidget,
      );
      await tapKey(tester, 'team.cancelAdd.u-kiran');
      expect(repo.count('cancelAdd'), 1);
      expect(find.text('Waiting to Accept (1)'), findsNothing);
      expect(find.text('Pending 1'), findsOneWidget);
    });

    testWidgets('an open email invite shows its address, role, office and expiry; Revoke ends it', (tester) async {
      await pump(tester, tab: TeamTab.pending);
      expect(find.text('Pending Invitations (1)'), findsOneWidget);
      expect(find.text('hr@partner.example'), findsOneWidget);
      expect(find.textContaining('expires '), findsOneWidget);
      await tapKey(tester, 'team.revoke.inv-1');
      expect(repo.count('revokeInvite'), 1);
      expect(find.text('hr@partner.example'), findsNothing);
      expect(find.text('Pending 1'), findsOneWidget);
    });

    testWidgets('a refused take-back is shown above the lists and the row stays', (tester) async {
      final r = DemoTeamRepository()..failures['cancelAdd'] = ApiError('Could not take that back.', statusCode: 400);
      await pump(tester, repository: r, tab: TeamTab.pending);
      await tapKey(tester, 'team.cancelAdd.u-kiran');
      expect(find.text('Could not take that back.'), findsOneWidget);
      expect(find.byKey(const Key('team.add.u-kiran')), findsOneWidget);
      await tester.tap(find.byKey(const Key('team.error.close')));
      await tester.pumpAndSettle();
      expect(find.text('Could not take that back.'), findsNothing);
    });
  });

  group('members', () {
    testWidgets('Edit sends only what changed: the role alone, the office alone, a cleared office as null', (
      tester,
    ) async {
      await pump(tester);
      await tapKey(tester, 'team.edit.u-rahul');
      expect(find.text('Edit Rahul Menon'), findsOneWidget);
      expect(saveEnabled(tester), isFalse, reason: 'nothing changed yet');
      await pickFrom(tester, 'edit.role', 'Hiring Manager');
      expect(saveEnabled(tester), isTrue);
      await save(tester);
      expect(repo.sent['updateMember'], {'id': 'u-rahul', 'role': 'HIRING_MANAGER'});

      await tapKey(tester, 'team.edit.u-rahul');
      await pickFrom(tester, 'edit.office', 'Pune Campus');
      await save(tester);
      expect(repo.sent['updateMember'], {'id': 'u-rahul', 'branchId': 'b-pune'});

      await tapKey(tester, 'team.edit.u-rahul');
      await pickFrom(tester, 'edit.office', 'Company-Wide');
      await save(tester);
      final sent = repo.sent['updateMember']! as Map;
      expect(sent.containsKey('branchId'), isTrue);
      expect(sent['branchId'], isNull);
      expect(sent.containsKey('role'), isFalse);
    });

    testWidgets('the role list never offers Company Admin, but keeps the member\'s own role', (tester) async {
      await pump(tester);
      await tapKey(tester, 'team.edit.u-rahul');
      await tester.tap(find.descendant(of: find.byKey(const Key('edit.role')), matching: find.byType(InkWell)));
      await tester.pumpAndSettle();
      final labels = [for (final t in tester.widgetList<ListTile>(find.byType(ListTile))) (t.title! as Text).data];
      expect(labels, ['Office Admin', 'Recruiter', 'Hiring Manager', 'Seller', 'Buyer']);
    });

    testWidgets('a refusal (an office a role needs) is shown in the sheet and what was chosen stays', (tester) async {
      final r = DemoTeamRepository()
        ..failures['updateMember'] = ApiError('Recruiter accounts need an office. Choose one for this member.');
      await pump(tester, repository: r);
      await tapKey(tester, 'team.edit.u-rahul');
      await pickFrom(tester, 'edit.office', 'Company-Wide');
      await save(tester);
      expect(find.text('Recruiter accounts need an office. Choose one for this member.'), findsOneWidget);
      expect(find.byKey(const Key('edit.role')), findsOneWidget, reason: 'the sheet stays open');
      expect(saveEnabled(tester), isTrue);
    });

    testWidgets('Remove asks first; backing out removes nothing, confirming ends their place', (tester) async {
      await pump(tester);
      await tapKey(tester, 'team.remove.u-rahul');
      expect(find.text('Remove Rahul Menon from the Team?'), findsOneWidget);
      expect(find.textContaining('Their ICR account and their other companies are not affected.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.count('removeMember'), 0);
      await tapKey(tester, 'team.remove.u-rahul');
      await tester.tap(find.byKey(const Key('confirm.ok')));
      await tester.pumpAndSettle();
      expect(repo.count('removeMember'), 1);
      // The rows' "Inbox Permissions" lines run to two lines on a phone, so the tabs are scrolled back into view.
      await tester.scrollUntilVisible(
        find.byKey(const Key('team.tab.members')),
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Members 5'), findsOneWidget);
      expect(find.byKey(const Key('team.member.u-rahul')), findsNothing);
    });

    testWidgets('a company admin edits and removes colleagues, but not themselves, a deactivated account or staff', (
      tester,
    ) async {
      await pump(tester);
      for (final id in ['u-bina', 'u-rahul', 'u-vivek', 'u-hema']) {
        expect(find.byKey(Key('team.edit.$id')), findsOneWidget, reason: 'Edit on $id');
        expect(find.byKey(Key('team.remove.$id')), findsOneWidget, reason: 'Remove on $id');
      }
      expect(find.byKey(const Key('team.edit.u-asha')), findsNothing, reason: 'not on themselves');
      expect(find.byKey(const Key('team.remove.u-asha')), findsNothing);
      await reveal(tester, find.byKey(const Key('team.member.u-dev')));
      expect(find.byKey(const Key('team.edit.u-dev')), findsNothing, reason: 'deactivated');
      expect(find.byKey(const Key('team.remove.u-dev')), findsNothing);
    });

    testWidgets('a fellow Company Admin can be removed but not re-roled here', (tester) async {
      final r = DemoTeamRepository(
        members: const [
          TeamMember(id: 'u-asha', email: 'a@x.example', firstName: 'Asha', lastName: 'Rao', role: 'COMPANY_ADMIN'),
          TeamMember(id: 'u-other', email: 'o@x.example', firstName: 'Omar', lastName: 'Khan', role: 'COMPANY_ADMIN'),
          TeamMember(id: 'u-staff', email: 's@x.example', firstName: 'Sana', lastName: 'Admin', role: 'SUPER_ADMIN'),
        ],
      );
      await pump(tester, repository: r);
      expect(find.byKey(const Key('team.edit.u-other')), findsNothing);
      expect(find.byKey(const Key('team.remove.u-other')), findsOneWidget);
      expect(find.byKey(const Key('team.remove.u-staff')), findsNothing, reason: 'ICR staff are not removed here');
    });

    testWidgets('an office admin sees the team, the requests and the pending lists, but edits and removes nobody', (
      tester,
    ) async {
      await pump(tester, role: 'BRANCH_ADMIN', userId: 'u-bina');
      expect(find.text('Members 6'), findsOneWidget);
      for (final id in ['u-asha', 'u-rahul', 'u-vivek', 'u-hema']) {
        expect(find.byKey(Key('team.edit.$id')), findsNothing);
        expect(find.byKey(Key('team.remove.$id')), findsNothing);
      }
      await tapTab(tester, TeamTab.requests);
      expect(find.byKey(const Key('team.approve.u-pooja')), findsOneWidget);
      await tapTab(tester, TeamTab.pending);
      expect(find.byKey(const Key('team.cancelAdd.u-kiran')), findsOneWidget);
      expect(find.byKey(const Key('team.revoke.inv-1')), findsOneWidget);
    });

    testWidgets(
      'a supplier account manages only supplier accounts: no Edit, Remove on sellers, Cancel on seller adds',
      (tester) async {
        final r = DemoTeamRepository(
          adds: [
            PendingAdd(
              id: 'add-1',
              userId: 'u-k',
              firstName: 'Kiran',
              lastName: 'Bose',
              role: 'RECRUITER',
              createdAt: DateTime.now(),
            ),
            PendingAdd(
              id: 'add-2',
              userId: 'u-s',
              firstName: 'Sunil',
              lastName: 'Das',
              role: 'VENDOR',
              createdAt: DateTime.now(),
            ),
          ],
          invites: const [
            TeamInvite(id: 'inv-h', email: 'h@x.example', role: 'RECRUITER'),
            TeamInvite(id: 'inv-v', email: 'v@x.example', role: 'VENDOR'),
          ],
        );
        await pump(tester, role: 'VENDOR', userId: 'u-vivek', repository: r);
        expect(find.text('Members 6'), findsOneWidget, reason: 'the whole team counts towards its seats');
        for (final id in ['u-asha', 'u-bina', 'u-rahul', 'u-hema']) {
          expect(find.byKey(Key('team.remove.$id')), findsNothing, reason: 'not a supplier account: $id');
        }
        expect(find.byKey(const Key('team.edit.u-vivek')), findsNothing);
        await tapTab(tester, TeamTab.pending);
        expect(find.byKey(const Key('team.cancelAdd.u-k')), findsNothing);
        expect(find.byKey(const Key('team.cancelAdd.u-s')), findsOneWidget);
        expect(find.byKey(const Key('team.revoke.inv-h')), findsNothing);
        expect(find.byKey(const Key('team.revoke.inv-v')), findsOneWidget);
      },
    );
  });

  group('add someone on ICR', () {
    testWidgets('type a name, pick the person, name their role and office, ask: the add is pending', (tester) async {
      await pump(tester);
      await tapKey(tester, 'team.add');
      expect(find.text('Add Existing ICR Member'), findsWidgets);
      expect(saveEnabled(tester), isFalse, reason: 'nobody picked yet');
      await tester.enterText(find.byKey(const Key('add.search')), 'M');
      await tester.pumpAndSettle();
      expect(repo.count('findPeople'), 0, reason: 'it searches from two letters');
      await tester.enterText(find.byKey(const Key('add.search')), 'Mee');
      await tester.pumpAndSettle();
      expect(repo.count('findPeople'), 1);
      expect(find.byKey(const Key('add.hit.u-meera')), findsOneWidget);
      await tester.tap(find.byKey(const Key('add.hit.u-meera')));
      await tester.pumpAndSettle();
      expect(find.text('Meera Joshi'), findsOneWidget);
      expect(find.textContaining('To make someone an admin, send an invite instead.'), findsOneWidget);
      await pickFrom(tester, 'add.role', 'Buyer');
      await pickFrom(tester, 'add.office', 'Head Office');
      expect(saveEnabled(tester), isTrue);
      await save(tester);
      expect(repo.sent['addMember'], {'userId': 'u-meera', 'role': 'BUYER', 'branchId': 'b-hq'});
      expect(find.text('Pending 3'), findsOneWidget);
      expect(find.text('Meera Joshi'), findsOneWidget, reason: 'the page moved to Pending, where the add waits');
    });

    testWidgets('the role list leaves out Company Admin and Member; nobody found says so', (tester) async {
      await pump(tester);
      await tapKey(tester, 'team.add');
      await tester.enterText(find.byKey(const Key('add.search')), 'Zzz');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('add.none')), findsOneWidget);
      expect(find.text('No members found.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('add.search')), 'Meera');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add.hit.u-meera')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byKey(const Key('add.role')), matching: find.byType(InkWell)));
      await tester.pumpAndSettle();
      final labels = [for (final t in tester.widgetList<ListTile>(find.byType(ListTile))) (t.title! as Text).data];
      expect(labels, ['Office Admin', 'Recruiter', 'Hiring Manager', 'Seller', 'Buyer']);
    });

    testWidgets('a refusal (a full team) stays in the sheet, with the person and role still chosen', (tester) async {
      final r = DemoTeamRepository()
        ..failures['addMember'] = ApiError('Your plan includes 5 team members, counting pending invites.');
      await pump(tester, repository: r);
      await tapKey(tester, 'team.add');
      await tester.enterText(find.byKey(const Key('add.search')), 'Meera');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add.hit.u-meera')));
      await tester.pumpAndSettle();
      await pickFrom(tester, 'add.role', 'Buyer');
      await save(tester);
      expect(find.text('Your plan includes 5 team members, counting pending invites.'), findsOneWidget);
      expect(find.text('Meera Joshi'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('add.role')), matching: find.text('Buyer')), findsOneWidget);
      expect(saveEnabled(tester), isTrue);
    });

    testWidgets('an office admin may add only recruiters and hiring managers, with no office to pick', (tester) async {
      await pump(tester, role: 'BRANCH_ADMIN', userId: 'u-bina');
      await tapKey(tester, 'team.add');
      await tester.enterText(find.byKey(const Key('add.search')), 'Meera');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add.hit.u-meera')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('add.office')), findsNothing);
      await tester.tap(find.descendant(of: find.byKey(const Key('add.role')), matching: find.byType(InkWell)));
      await tester.pumpAndSettle();
      final labels = [for (final t in tester.widgetList<ListTile>(find.byType(ListTile))) (t.title! as Text).data];
      expect(labels, ['Recruiter', 'Hiring Manager']);
    });
  });

  group('invite by email', () {
    Future<void> openInvite(WidgetTester tester) async {
      await tapKey(tester, 'team.invite');
      expect(find.text('Invite a Team Member'), findsOneWidget);
      expect(saveEnabled(tester), isFalse, reason: 'no address yet');
    }

    testWidgets('an address not on ICR is sent an email invite with the role and office', (tester) async {
      await pump(tester);
      await openInvite(tester);
      await tester.enterText(find.byKey(const Key('invite.email')), 'new.hire@example.com');
      await tester.pumpAndSettle();
      expect(repo.count('lookup'), 1);
      expect(find.byKey(const Key('invite.notOnIcr')), findsOneWidget);
      expect(find.text('Not on ICR yet. They will receive an email to join ICR and your team.'), findsOneWidget);
      await pickFrom(tester, 'invite.role', 'Hiring Manager');
      await pickFrom(tester, 'invite.office', 'Head Office');
      await save(tester);
      expect(repo.sent['invite'], {'email': 'new.hire@example.com', 'role': 'HIRING_MANAGER', 'branchId': 'b-hq'});
      expect(find.text('Pending 3'), findsOneWidget);
      expect(find.text('new.hire@example.com'), findsOneWidget);
    });

    testWidgets('the role starts on Recruiter and offers the invitable roles, Company Admin among them', (
      tester,
    ) async {
      await pump(tester);
      await openInvite(tester);
      expect(
        find.descendant(of: find.byKey(const Key('invite.role')), matching: find.text('Recruiter')),
        findsOneWidget,
      );
      await tester.tap(find.descendant(of: find.byKey(const Key('invite.role')), matching: find.byType(InkWell)));
      await tester.pumpAndSettle();
      final labels = [for (final t in tester.widgetList<ListTile>(find.byType(ListTile))) (t.title! as Text).data];
      expect(labels, ['Company Admin', 'Office Admin', 'Recruiter', 'Hiring Manager', 'Seller', 'Buyer']);
    });

    testWidgets('someone on ICR with a public profile is asked in the app instead, and the button says so', (
      tester,
    ) async {
      await pump(tester);
      repo.lookups['meera@example.com'] = const TeamLookup(
        onIcr: true,
        person: TeamPerson(id: 'u-meera', firstName: 'Meera', lastName: 'Joshi', headline: 'Facilities manager'),
      );
      await openInvite(tester);
      await tester.enterText(find.byKey(const Key('invite.email')), 'Meera@Example.com');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('invite.person')), findsOneWidget);
      expect(find.text('Meera Joshi'), findsOneWidget);
      expect(find.text('On ICR'), findsOneWidget);
      expect(find.byKey(const Key('invite.addsPending')), findsOneWidget);
      expect(find.text('Ask Them to Join'), findsOneWidget);
      await pickFrom(tester, 'invite.role', 'Buyer');
      await save(tester);
      expect(repo.sent['addMember'], {'userId': 'u-meera', 'role': 'BUYER', 'branchId': null});
      expect(repo.count('invite'), 0, reason: 'no email goes to someone who is asked in the app');
      expect(repo.lookups.containsKey('meera@example.com'), isTrue);
    });

    testWidgets('as Company Admin even someone on ICR is sent an invite they accept, and the form says why', (
      tester,
    ) async {
      await pump(tester);
      repo.lookups['meera@example.com'] = const TeamLookup(
        onIcr: true,
        person: TeamPerson(id: 'u-meera', firstName: 'Meera', lastName: 'Joshi'),
      );
      await openInvite(tester);
      await tester.enterText(find.byKey(const Key('invite.email')), 'meera@example.com');
      await tester.pumpAndSettle();
      await pickFrom(tester, 'invite.role', 'Company Admin');
      expect(find.byKey(const Key('invite.adminNeedsInvite')), findsOneWidget);
      expect(find.text('Send Invite'), findsOneWidget);
      await save(tester);
      expect(repo.sent['invite'], containsPair('role', 'COMPANY_ADMIN'));
      expect(repo.count('addMember'), 0);
    });

    testWidgets('an address already on the team says so and cannot be sent; an add already waiting warns', (
      tester,
    ) async {
      await pump(tester);
      repo.lookups['asha@techcorp.example'] = const TeamLookup(onIcr: true, alreadyMember: true);
      repo.lookups['kiran@example.com'] = const TeamLookup(
        onIcr: true,
        person: TeamPerson(id: 'u-kiran', firstName: 'Kiran', lastName: 'Bose'),
        pendingAdd: true,
        pendingInvite: true,
      );
      await openInvite(tester);
      await tester.enterText(find.byKey(const Key('invite.email')), 'asha@techcorp.example');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('invite.alreadyMember')), findsOneWidget);
      expect(find.text('This person is already on your team.'), findsOneWidget);
      expect(saveEnabled(tester), isFalse);
      await tester.enterText(find.byKey(const Key('invite.email')), 'kiran@example.com');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('invite.alreadyAdded')), findsOneWidget);
      expect(find.byKey(const Key('invite.pendingInvite')), findsOneWidget);
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('a refusal stays in the sheet with the address typed', (tester) async {
      final r = DemoTeamRepository()
        ..failures['invite'] = ApiError('Your plan includes 5 team members, counting pending invites.');
      await pump(tester, repository: r);
      await openInvite(tester);
      await tester.enterText(find.byKey(const Key('invite.email')), 'new.hire@example.com');
      await tester.pumpAndSettle();
      await save(tester);
      expect(find.text('Your plan includes 5 team members, counting pending invites.'), findsOneWidget);
      expect(find.text('new.hire@example.com'), findsOneWidget, reason: 'the address stays as typed');
      expect(saveEnabled(tester), isTrue);
      r.failures.clear();
      await save(tester);
      expect(r.sent['invite'], containsPair('email', 'new.hire@example.com'));
    });

    testWidgets(
      'an office admin is not asked to lookup or pick an office; a supplier is told they join as a supplier',
      (tester) async {
        await pump(tester, role: 'BRANCH_ADMIN', userId: 'u-bina');
        await openInvite(tester);
        await tester.enterText(find.byKey(const Key('invite.email')), 'new.hire@example.com');
        await tester.pumpAndSettle();
        expect(repo.count('lookup'), 0, reason: 'only a company admin may ask whether an address is on ICR');
        expect(find.byKey(const Key('invite.office')), findsNothing);
        expect(find.text('Invitees join your office automatically.'), findsOneWidget);
        await save(tester);
        expect(repo.sent['invite'], {'email': 'new.hire@example.com', 'role': 'RECRUITER', 'branchId': null});
      },
    );

    testWidgets('a supplier account invites supplier accounts only', (tester) async {
      await pump(tester, role: 'VENDOR', userId: 'u-vivek');
      await openInvite(tester);
      expect(find.text('They join as a supplier account on your company’s listing.'), findsOneWidget);
      expect(find.byKey(const Key('invite.role')), findsNothing);
      expect(find.byKey(const Key('invite.office')), findsNothing);
      await tester.enterText(find.byKey(const Key('invite.email')), 'seller@example.com');
      await tester.pumpAndSettle();
      await save(tester);
      expect(repo.sent['invite'], {'email': 'seller@example.com', 'role': 'VENDOR', 'branchId': null});
    });
  });

  group('the API repository', () {
    test('reads the lists from the paths the website reads and sends the bodies the API takes', () async {
      final member = {
        'id': 'u-1',
        'email': 'rahul@x.example',
        'firstName': 'Rahul',
        'lastName': 'Recruiter',
        'isActive': true,
        'role': 'RECRUITER',
        'learningRoles': ['TRAINER'],
        'handlesTopics': ['CAREERS'],
        'branchId': 'b1',
        'branch': {'name': 'Head Office', 'city': 'Bengaluru'},
      };
      final api = AccountHarness(
        routes: {
          'GET /team/members': (_) => [member],
          'GET /team/requests': (_) => [
            {
              'id': 'r1',
              'role': 'PROFESSIONAL',
              'note': 'Hello',
              'createdAt': '2026-11-05T09:55:12.244Z',
              'user': {'id': 'u-2', 'firstName': 'Pooja', 'lastName': 'P', 'avatarUrl': '/uploads/a.jpg'},
            },
          ],
          'GET /team/invitations': (_) => [
            {
              'id': 'm1',
              'role': 'RECRUITER',
              'branchId': null,
              'branch': null,
              'learningRoles': [],
              'createdAt': '2026-11-02T09:00:00.000Z',
              'invitedBy': {'id': 'u-0', 'firstName': 'Asha', 'lastName': 'Rao'},
              'user': {'id': 'u-3', 'firstName': 'Kiran', 'lastName': 'B', 'avatarUrl': null},
            },
          ],
          'GET /team/invites': (_) => [
            {
              'id': 'i1',
              'email': 'hr@x.example',
              'role': 'HIRING_MANAGER',
              'learningRoles': [],
              'branch': {'name': 'Head Office'},
              'expiresAt': '2026-11-12T00:00:00.000Z',
            },
          ],
          'GET /branches': (_) => [
            {'id': 'b2', 'name': 'Tower A', 'parentId': 'b1', 'status': 'ACTIVE', 'deletedAt': null},
            {'id': 'b1', 'name': 'Head Office', 'parentId': null, 'status': 'ACTIVE', 'deletedAt': null},
            {'id': 'b3', 'name': 'Old Office', 'parentId': null, 'status': 'INACTIVE', 'deletedAt': null},
          ],
          'POST /team/requests/u-2/approve': (_) => {'success': true},
          'POST /team/requests/u-2/decline': (_) => {'success': true},
          'DELETE /team/invitations/u-3': (_) => {'success': true},
          'DELETE /team/invites/i1': (_) => {'success': true},
          'PATCH /team/members/u-1': (_) => member,
          'DELETE /team/members/u-1': (_) => {'success': true},
          'GET /team/people': (_) => [
            {'id': 'u-4', 'firstName': 'Meera', 'lastName': 'Joshi', 'avatarUrl': null},
          ],
          'POST /team/members': (_) => {'success': true, 'status': 'INVITED'},
          'GET /team/lookup': (_) => {
            'onIcr': true,
            'person': {'id': 'u-4', 'firstName': 'Meera', 'lastName': 'Joshi', 'avatarUrl': null, 'headline': 'FM'},
            'alreadyMember': false,
            'pendingInvite': false,
            'pendingAdd': false,
          },
          'POST /team/invites': (_) => {'id': 'i2'},
        },
      );
      final repo = ApiTeamRepository(api: api.client);

      final members = await repo.members();
      expect(members.single.name, 'Rahul Recruiter');
      expect(members.single.branchName, 'Head Office');
      expect(members.single.learningRoles, ['TRAINER']);
      expect((await repo.requests()).single.note, 'Hello');
      final add = (await repo.pendingAdds()).single;
      expect(add.invitedBy, 'Asha Rao');
      expect(add.branchName, isNull);
      expect((await repo.invites()).single.branchName, 'Head Office');

      final offices = await repo.offices('co-1');
      expect(api.api.last('GET /branches').query, {'companyId': 'co-1'});
      expect(
        [for (final o in offices) '${o.depth}:${o.name}'],
        ['0:Head Office', '1:Tower A'],
        reason: 'parents before their children; a retired office is left out',
      );

      await repo.approve('u-2', role: 'RECRUITER', branchId: 'b1');
      expect(api.api.last('POST /team/requests/u-2/approve').json, {'role': 'RECRUITER', 'branchId': 'b1'});
      await repo.approve('u-2', role: 'RECRUITER');
      expect(api.api.last('POST /team/requests/u-2/approve').json, {'role': 'RECRUITER'});
      await repo.decline('u-2');
      await repo.cancelAdd('u-3');
      await repo.revokeInvite('i1');
      await repo.updateMember('u-1', {'branchId': null});
      expect(api.api.last('PATCH /team/members/u-1').json, {'branchId': null});
      await repo.removeMember('u-1');
      expect(api.api.count('DELETE /team/members/u-1'), 1);

      expect((await repo.findPeople(' Meer ')).single.name, 'Meera Joshi');
      expect(api.api.last('GET /team/people').query, {'search': 'Meer'});
      await repo.addMember(userId: 'u-4', role: 'BUYER');
      expect(api.api.last('POST /team/members').json, {'userId': 'u-4', 'role': 'BUYER'});
      final lookup = await repo.lookup('Meera@Example.com');
      expect(api.api.last('GET /team/lookup').query, {'email': 'meera@example.com'});
      expect(lookup.person?.headline, 'FM');
      await repo.invite(email: ' new@x.example ', role: 'RECRUITER', branchId: 'b1');
      expect(api.api.last('POST /team/invites').json, {
        'email': 'new@x.example',
        'role': 'RECRUITER',
        'branchId': 'b1',
      });
    });

    test('a refusal comes out as the API\'s own sentence', () async {
      final api = AccountHarness(
        routes: {
          'POST /team/invites': (_) =>
              ApiReply.refusal(403, 'Your plan includes 5 team members, counting pending invites. Gold includes more.'),
        },
      );
      await expectLater(
        ApiTeamRepository(api: api.client).invite(email: 'a@b.example', role: 'RECRUITER'),
        throwsA(isA<ApiError>().having((e) => e.message, 'message', contains('Your plan includes 5 team members'))),
      );
    });
  });

  group('learning roles, at a learning-partner company (the website\'s TeamPanel, 6 Nov 2026)', () {
    const memberLabel = 'Member (Learning Roles Only)';

    Future<void> openInvite(WidgetTester tester) async {
      await tapKey(tester, 'team.invite');
      expect(find.text('Invite a Team Member'), findsOneWidget);
    }

    /// Picks a row that may sit below the picker sheet's fold (Member is the seventh role).
    Future<void> pickRole(WidgetTester tester, String fieldKey, String label) async {
      final field = find.descendant(of: find.byKey(Key(fieldKey)), matching: find.byType(InkWell));
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      await tester.tap(field);
      await tester.pumpAndSettle();
      final row = find.descendant(of: find.byType(ListTile), matching: find.text(label));
      await tester.scrollUntilVisible(row, 80, scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
    }

    testWidgets('the admin invites a Member with learning roles; a Member needs at least one and no office', (
      tester,
    ) async {
      await pump(tester, learningPartner: true);
      await openInvite(tester);
      await tester.enterText(find.byKey(const Key('invite.email')), 'trainer@example.com');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('invite.learningRoles')), findsOneWidget);
      expect(find.text('Learning Roles'), findsOneWidget);
      expect(find.text('Select any number. Each opens its pages in the Learning console.'), findsOneWidget);
      await pickRole(tester, 'invite.role', memberLabel);
      expect(find.byKey(const Key('invite.office')), findsNothing, reason: 'a Member has no office');
      expect(find.text('Select at least one learning role for a member.'), findsOneWidget);
      expect(saveEnabled(tester), isFalse);
      await tapKey(tester, 'learning.TRAINER');
      expect(find.text('Select at least one learning role for a member.'), findsNothing);
      expect(saveEnabled(tester), isTrue);
      await save(tester);
      expect(repo.sent['invite'], {
        'email': 'trainer@example.com',
        'role': 'PROFESSIONAL',
        'branchId': null,
        'learningRoles': ['TRAINER'],
      });
      expect(find.text('Trainer'), findsWidgets, reason: 'the pending invite shows the learning role');
    });

    testWidgets('learning roles ride along with any role, and go with an add from ICR too', (tester) async {
      await pump(tester, learningPartner: true);
      await openInvite(tester);
      await tester.enterText(find.byKey(const Key('invite.email')), 'new.hire@example.com');
      await tester.pumpAndSettle();
      await pickFrom(tester, 'invite.role', 'Recruiter');
      await tapKey(tester, 'learning.COURSE_ADMIN');
      await tapKey(tester, 'learning.FINANCE');
      await save(tester);
      expect(repo.sent['invite'], {
        'email': 'new.hire@example.com',
        'role': 'RECRUITER',
        'branchId': null,
        'learningRoles': ['COURSE_ADMIN', 'FINANCE'],
      });

      await tapKey(tester, 'team.add');
      await tester.enterText(find.byKey(const Key('add.search')), 'Meera');
      await tester.pumpAndSettle();
      await tapKey(tester, 'add.hit.u-meera');
      expect(find.byKey(const Key('add.learningRoles')), findsOneWidget);
      await pickFrom(tester, 'add.role', 'Professional');
      expect(saveEnabled(tester), isFalse, reason: 'a Member needs a learning role');
      await tapKey(tester, 'learning.BATCH_ADMIN');
      await save(tester);
      expect(repo.sent['addMember'], {
        'userId': 'u-meera',
        'role': 'PROFESSIONAL',
        'branchId': null,
        'learningRoles': ['BATCH_ADMIN'],
      });
    });

    testWidgets('"Add a trainer" opens the invite form on Member with Trainer ticked', (tester) async {
      await pump(tester, learningPartner: true, inviteLearningRole: 'TRAINER');
      expect(find.text('Invite a Team Member'), findsOneWidget);
      expect(find.text(memberLabel), findsOneWidget);
      final trainer = find.descendant(of: find.byKey(const Key('learning.TRAINER')), matching: find.byType(Checkbox));
      expect(tester.widget<Checkbox>(trainer).value, isTrue);
      expect(find.byKey(const Key('invite.office')), findsNothing);
      await tester.enterText(find.byKey(const Key('invite.email')), 'trainer@example.com');
      await tester.pumpAndSettle();
      await save(tester);
      expect(repo.sent['invite'], {
        'email': 'trainer@example.com',
        'role': 'PROFESSIONAL',
        'branchId': null,
        'learningRoles': ['TRAINER'],
      });
    });

    testWidgets('a company that is not a partner offers neither Member nor learning roles', (tester) async {
      await pump(tester);
      await openInvite(tester);
      expect(find.byKey(const Key('invite.learningRoles')), findsNothing);
      await tester.tap(find.descendant(of: find.byKey(const Key('invite.role')), matching: find.byType(InkWell)));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(ListTile), matching: find.text(memberLabel)), findsNothing);
    });

    testWidgets('Edit sets a member\'s learning roles, and a Member keeps at least one', (tester) async {
      final r = DemoTeamRepository(
        members: const [
          TeamMember(id: 'u-asha', email: 'a@x.example', firstName: 'Asha', lastName: 'Rao', role: 'COMPANY_ADMIN'),
          TeamMember(id: 'u-rahul', email: 'r@x.example', firstName: 'Rahul', lastName: 'Menon', role: 'RECRUITER'),
          TeamMember(
            id: 'u-tara',
            email: 't@x.example',
            firstName: 'Tara',
            lastName: 'Iyer',
            role: 'PROFESSIONAL',
            learningRoles: ['TRAINER'],
          ),
        ],
      );
      await pump(tester, learningPartner: true, repository: r);
      await tapKey(tester, 'team.edit.u-rahul');
      expect(find.byKey(const Key('edit.learningRoles')), findsOneWidget);
      await tapKey(tester, 'learning.TRAINER');
      await save(tester);
      expect(r.sent['updateMember'], {
        'id': 'u-rahul',
        'learningRoles': ['TRAINER'],
      });

      await tapKey(tester, 'team.edit.u-tara');
      await tapKey(tester, 'learning.TRAINER');
      expect(find.text('A member who joined for learning roles keeps at least one.'), findsOneWidget);
      expect(saveEnabled(tester), isFalse);
      await tapKey(tester, 'learning.ENROLMENT_ADMIN');
      expect(saveEnabled(tester), isTrue);
      await save(tester);
      expect(r.sent['updateMember'], {
        'id': 'u-tara',
        'learningRoles': ['ENROLMENT_ADMIN'],
      });
    });
  });
}
