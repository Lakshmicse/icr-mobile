import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:icr_mobile/features/projects/project_models.dart';
import 'package:icr_mobile/features/projects/project_screen.dart';
import 'package:icr_mobile/features/projects/projects_repository.dart';
import 'package:icr_mobile/features/projects/projects_screen.dart';

import 'helpers/fonts.dart';

/// The company's sourcing projects (the website's `/manage/projects` and `/manage/projects/[id]`), drawn by the app
/// since 12 Nov 2026: the list with its search and switches, a project created through the sheet with the website's
/// fields, the project's page with its roster by stage and the people its criteria match, archive, edit and delete.
void main() {
  setUpAll(loadAppFonts);

  const admin = ProjectsViewer(id: 'u-asha', role: 'COMPANY_ADMIN', companyId: 'co-1');

  late DemoProjectsRepository repo;

  Future<void> pump(
    WidgetTester tester, {
    DemoProjectsRepository? repository,
    ProjectsViewer viewer = admin,
    ValueChanged<String>? onOpenJob,
    VoidCallback? onCreateCompany,
  }) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repo = repository ?? DemoProjectsRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: ProjectsScreen(
          onBack: () {},
          repository: repo,
          viewer: viewer,
          onOpenJob: onOpenJob,
          onCreateCompany: onCreateCompany,
          searchDelay: Duration.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openProject(WidgetTester tester, String id) async {
    await tester.tap(find.byKey(ValueKey('projects.row.$id')));
    await tester.pumpAndSettle();
  }

  /// Opens a form's select field (its inner tap target) and picks a row of the list.
  Future<void> pickFrom(WidgetTester tester, String fieldKey, String label) async {
    final field = find.descendant(of: find.byKey(Key(fieldKey)), matching: find.byType(InkWell));
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(ListTile), matching: find.text(label)));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String key, String text) async {
    final field = find.byKey(Key(key));
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, text);
    await tester.pumpAndSettle();
  }

  bool saveEnabled(WidgetTester tester) {
    final button = find.descendant(of: find.byKey(const Key('sheet.save')), matching: find.byType(FilledButton));
    return tester.widget<FilledButton>(button).onPressed != null;
  }

  group('the list', () {
    testWidgets('reads in the owner’s words: heading, description, CTA, search, filters', (tester) async {
      await pump(tester);
      expect(find.text('Talent Sourcing Projects'), findsOneWidget, reason: 'the heading, in the title bar');
      expect(find.text('Projects'), findsNothing);
      expect(
        find.text(
          'Build and manage talent pools beyond individual job openings. Identify, engage and shortlist candidates '
          'for current and future hiring needs.',
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(const Key('projects.new')), matching: find.text('Create Project')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(const Key('projects.new')), matching: find.byIcon(Icons.add_rounded)),
        findsOneWidget,
        reason: 'the “+” of “+ Create Project”',
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('projects.search'))).decoration!.hintText,
        'Search projects by name or role…',
      );
      expect(
        find.descendant(of: find.byKey(const Key('projects.filter.mine')), matching: find.text('My Projects')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(const Key('projects.filter.archived')), matching: find.text('Show Archived')),
        findsOneWidget,
      );
      for (final old in ['Sourcing projects', 'New project', 'Only mine', 'Show archived']) {
        expect(find.text(old), findsNothing, reason: old);
      }
    });

    testWidgets('the full heading fits the title bar of a 360 dp phone', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      repo = DemoProjectsRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ProjectsScreen(onBack: () {}, repository: repo, viewer: admin, searchDelay: Duration.zero),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'no overflow anywhere on the page');
      final heading = tester.getRect(find.text('Talent Sourcing Projects'));
      final bell = tester.getRect(find.byIcon(LucideIcons.bell));
      expect(heading.right, lessThan(bell.left), reason: 'the heading ends before the bell');
    });

    testWidgets("lists the live projects as the website's cards: name, Private, what it sources for, the counts", (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Regional FM Managers — West'), findsOneWidget);
      expect(find.text('Sourcing for Senior Facility Manager'), findsOneWidget);
      expect(find.text('5 candidates'), findsOneWidget);
      expect(find.text('Sourced 2'), findsOneWidget);
      expect(find.text('Contacted 1'), findsOneWidget);
      expect(find.text('Shortlisted 1'), findsOneWidget);
      expect(find.text('Workplace tech leads'), findsOneWidget);
      expect(find.text('Private'), findsOneWidget);
      expect(find.text('0 candidates'), findsOneWidget);
      expect(
        find.text('Housekeeping supervisors 2025'),
        findsNothing,
        reason: 'archived projects are hidden by default',
      );
      expect(find.byType(Card), findsNothing, reason: 'rows the whole width, hairlines between');
    });

    testWidgets('Show Archived brings the archived project in, dimmed and marked; My Projects keeps the viewer’s', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('projects.filter.archived')));
      await tester.pumpAndSettle();
      expect(find.text('Housekeeping supervisors 2025'), findsOneWidget);
      expect(find.text('Archived'), findsOneWidget);
      final row = tester.widget<Opacity>(
        find.descendant(of: find.byKey(const ValueKey('projects.row.proj-3')), matching: find.byType(Opacity)),
      );
      expect(row.opacity, 0.65);

      await tester.tap(find.byKey(const Key('projects.filter.mine')));
      await tester.pumpAndSettle();
      expect(find.text('Housekeeping supervisors 2025'), findsNothing, reason: 'Hema’s project is not mine');
      expect(find.text('Regional FM Managers — West'), findsOneWidget);
    });

    testWidgets('the search narrows the list by name; nothing matching says so', (tester) async {
      await pump(tester);
      await tester.enterText(find.byKey(const Key('projects.search')), 'tech');
      await tester.pumpAndSettle();
      expect(find.text('Workplace tech leads'), findsOneWidget);
      expect(find.text('Regional FM Managers — West'), findsNothing);

      await tester.enterText(find.byKey(const Key('projects.search')), 'zzz');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('projects.empty')), findsOneWidget);
      expect(find.text('No Matching Projects'), findsOneWidget);
    });

    testWidgets('no projects yet is the owner’s empty state, whose Create Your First Project opens the sheet', (
      tester,
    ) async {
      await pump(tester, repository: DemoProjectsRepository(rows: []));
      expect(find.text('No Sourcing Projects Yet'), findsOneWidget);
      expect(
        find.text(
          'Create your first project to build a talent pool and shortlist candidates for upcoming or recurring '
          'hiring needs.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('projects.empty.create')));
      await tester.pumpAndSettle();
      expect(find.text('New Sourcing Project'), findsOneWidget);
      await type(tester, 'project.name', 'First bench');
      await tester.tap(find.byKey(const Key('sheet.save')));
      await tester.pumpAndSettle();
      expect(repo.sent.single['op'], 'create');
      expect(find.text('First bench'), findsOneWidget);
      expect(find.byKey(const Key('projects.empty')), findsNothing);
    });

    testWidgets('a search that finds nothing is not the first-project state', (tester) async {
      await pump(tester);
      await tester.enterText(find.byKey(const Key('projects.search')), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No Sourcing Projects Yet'), findsNothing);
      expect(find.byKey(const Key('projects.empty.create')), findsNothing);
      expect(find.text('Try another name or clear the filters.'), findsOneWidget);
    });

    testWidgets('a list that cannot be read says so and can be tried again', (tester) async {
      await pump(tester, repository: DemoProjectsRepository(failList: true));
      expect(find.byKey(const Key('projects.error')), findsOneWidget);
      expect(find.text('Unable to load projects.'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets('someone acting for no company is told projects belong to one, and offered a company to create', (
      tester,
    ) async {
      var created = false;
      await pump(
        tester,
        viewer: const ProjectsViewer(id: 'u1', role: 'PROFESSIONAL'),
        onCreateCompany: () => created = true,
      );
      expect(find.byKey(const Key('projects.noCompany')), findsOneWidget);
      expect(find.text('Talent sourcing projects belong to a company.'), findsOneWidget);
      expect(find.byKey(const Key('projects.new')), findsNothing);
      await tester.tap(find.byKey(const Key('projects.createCompany')));
      expect(created, isTrue);
    });

    testWidgets('a role outside the hiring team gets a calm note, never a 403', (tester) async {
      await pump(
        tester,
        viewer: const ProjectsViewer(id: 'u1', role: 'VENDOR', companyId: 'co-1'),
      );
      expect(find.byKey(const Key('projects.noAccess')), findsOneWidget);
      expect(find.text('This Page Is for Your Company’s Hiring Team'), findsOneWidget);
    });

    testWidgets('ICR staff reach the list with no company of their own', (tester) async {
      await pump(
        tester,
        viewer: const ProjectsViewer(id: 'staff', role: 'SUPER_ADMIN'),
      );
      expect(find.text('Regional FM Managers — West'), findsOneWidget);
    });
  });

  group('New project', () {
    testWidgets("the sheet asks the website's fields and sends them as the website does", (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('projects.new')));
      await tester.pumpAndSettle();
      expect(find.text('New Sourcing Project'), findsOneWidget);
      expect(find.text('Not Linked to a Job'), findsOneWidget, reason: 'no job until one is picked');
      expect(saveEnabled(tester), isFalse, reason: 'Create waits for a name');

      await type(tester, 'project.name', '  Lease admins — North ');
      expect(saveEnabled(tester), isTrue);
      await type(tester, 'project.description', 'A bench for the Delhi leases.');
      await pickFrom(tester, 'project.visibility', 'Private (Only Me)');
      await pickFrom(tester, 'project.job', 'Workplace Experience Lead');
      await type(tester, 'project.titles', 'Lease Administrator, Transactions Manager');
      await type(tester, 'project.skills', 'Lease admin, , Negotiation');
      await type(tester, 'project.locations', 'Delhi, Gurugram');
      await type(tester, 'project.minYears', '4');

      await tester.tap(find.byKey(const Key('sheet.save')));
      await tester.pumpAndSettle();

      expect(repo.sent, [
        {
          'op': 'create',
          'body': {
            'name': 'Lease admins — North',
            'description': 'A bench for the Delhi leases.',
            'visibility': 'PRIVATE',
            'jobId': 'job-2',
            'titles': ['Lease Administrator', 'Transactions Manager'],
            'skills': ['Lease admin', 'Negotiation'],
            'locations': ['Delhi', 'Gurugram'],
            'minYears': 4,
          },
        },
      ]);
      expect(find.text('Project created.'), findsOneWidget);
      expect(find.text('Lease admins — North'), findsOneWidget, reason: 'the new project heads the list');
      expect(find.text('Sourcing for Workplace Experience Lead'), findsOneWidget);
    });

    testWidgets('blank optional fields are left out of what is sent', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('projects.new')));
      await tester.pumpAndSettle();
      await type(tester, 'project.name', 'Just a name');
      await tester.tap(find.byKey(const Key('sheet.save')));
      await tester.pumpAndSettle();
      expect(repo.sent.single['body'], {
        'name': 'Just a name',
        'visibility': 'TEAM',
        'titles': <String>[],
        'skills': <String>[],
        'locations': <String>[],
      });
    });

    testWidgets('a refusal is shown in the sheet, which keeps what was typed', (tester) async {
      await pump(tester, repository: DemoProjectsRepository(failWrites: 'Your plan includes 3 projects.'));
      await tester.tap(find.byKey(const Key('projects.new')));
      await tester.pumpAndSettle();
      await type(tester, 'project.name', 'A fourth');
      await tester.tap(find.byKey(const Key('sheet.save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sheet.error')), findsOneWidget);
      expect(find.text('Your plan includes 3 projects.'), findsOneWidget);
      expect(find.text('A fourth'), findsOneWidget);
    });
  });

  group('the project page', () {
    testWidgets("shows the website's heading, chips and the roster by stage", (tester) async {
      await pump(tester);
      await openProject(tester, 'proj-1');
      expect(find.byKey(const Key('project.title')), findsOneWidget);
      expect(
        find.text('A bench of facility managers for the Mumbai and Pune portfolios before the Q1 openings.'),
        findsOneWidget,
        reason: 'the description is the subtitle',
      );
      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Team (Anyone with Recruiter Access)'), findsOneWidget);
      expect(find.byKey(const Key('project.job.chip')), findsOneWidget);
      for (final chip in [
        'Title: Facility Manager',
        'Skill: Lease admin',
        'Location: Pune',
        '5+ yrs',
        'Senior',
        'On-Site',
      ]) {
        expect(find.text(chip), findsOneWidget, reason: chip);
      }
      expect(find.text('Pipeline (5)'), findsOneWidget);
      expect(find.text('Find Candidates'), findsOneWidget);

      // The board's stages, each with its count, then Archived under them.
      for (final stage in ['SOURCED', 'CONTACTED', 'REPLIED', 'SHORTLISTED', 'ARCHIVED']) {
        expect(find.byKey(Key('project.stage.$stage')), findsOneWidget, reason: stage);
      }
      expect(find.text('No candidates in this stage yet.'), findsOneWidget, reason: 'Replied is empty');
      expect(find.text('Ravi Kumar'), findsOneWidget);
      expect(find.text('Prestige Estates · Pune · 7 yrs · 30d notice'), findsOneWidget);
      expect(find.text('Ran the Hinjewadi campus; strong on vendor SLAs.'), findsOneWidget);
      expect(find.text('Ex-landlord side'), findsOneWidget, reason: 'the company’s tag');
      expect(find.text('JLL · Mumbai · 5 yrs · Immediate'), findsOneWidget);
      expect(find.text('Applied to Senior Facility Manager · screening'), findsOneWidget);
      expect(find.text('Sanjay Patil'), findsOneWidget, reason: 'the archived candidate is listed under Archived');
    });

    testWidgets('a project without a description or job reads "Sourcing project"; one with a job names it', (
      tester,
    ) async {
      await pump(tester);
      await openProject(tester, 'proj-2');
      expect(find.text('Sourcing project'), findsOneWidget);
      expect(find.text('Private (Only Me)'), findsOneWidget);
      expect(find.byKey(const Key('project.roster.empty')), findsOneWidget);
      expect(find.text('No Candidates Yet'), findsOneWidget);
    });

    testWidgets('the job chip and a candidate’s "Applied to" open the job when the app can', (tester) async {
      final opened = <String>[];
      await pump(tester, onOpenJob: opened.add);
      await openProject(tester, 'proj-1');
      await tester.tap(find.byKey(const Key('project.job.chip')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('project.candidate.applied.u-meera')));
      await tester.pumpAndSettle();
      expect(opened, ['job-1', 'job-1']);
    });

    testWidgets('the arrow moves a candidate to the next stage; the menu moves them anywhere or removes them', (
      tester,
    ) async {
      await pump(tester);
      await openProject(tester, 'proj-1');

      await tester.tap(find.byKey(const ValueKey('project.candidate.next.u-ravi')));
      await tester.pumpAndSettle();
      expect(repo.sent.last, {
        'op': 'moveCandidate',
        'projectId': 'proj-1',
        'candidateId': 'u-ravi',
        'stage': 'CONTACTED',
      });

      await tester.tap(find.byKey(const ValueKey('project.candidate.menu.u-arjun')));
      await tester.pumpAndSettle();
      expect(find.text('Move to Contacted'), findsNothing, reason: 'the stage they are in is not offered');
      await tester.tap(find.byKey(const ValueKey('project.candidate.move.u-arjun.SHORTLISTED')));
      await tester.pumpAndSettle();
      expect(repo.sent.last, {
        'op': 'moveCandidate',
        'projectId': 'proj-1',
        'candidateId': 'u-arjun',
        'stage': 'SHORTLISTED',
      });

      await tester.tap(find.byKey(const ValueKey('project.candidate.menu.u-divya')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('project.candidate.remove.u-divya')));
      await tester.pumpAndSettle();
      expect(repo.sent.last, {'op': 'removeCandidate', 'projectId': 'proj-1', 'candidateId': 'u-divya'});
      expect(find.text('Divya Menon'), findsNothing);
      expect(find.text('Removed Divya Menon from the project.'), findsOneWidget);
      expect(find.text('Pipeline (4)'), findsOneWidget, reason: 'the count follows');
    });

    testWidgets('Find candidates lists the matches with the website’s note; Save adds one and takes them off', (
      tester,
    ) async {
      await pump(tester);
      await openProject(tester, 'proj-1');
      await tester.tap(find.byKey(const Key('project.tab.find')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          "Candidates matching this project's criteria, excluding anyone already saved. These are rule-based "
          'filters, not an AI ranking.',
        ),
        findsOneWidget,
      );
      expect(find.text('Kavya Reddy'), findsOneWidget);
      expect(find.text('Facility Manager · Embassy Services · Pune'), findsOneWidget);
      expect(find.text('Nikhil Joshi'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('project.match.save.u-kavya')));
      await tester.pumpAndSettle();
      expect(repo.sent.last, {'op': 'addCandidate', 'projectId': 'proj-1', 'candidateId': 'u-kavya'});
      expect(find.text('Kavya Reddy'), findsNothing, reason: 'saved people leave the matches');
      expect(find.text('Saved Kavya Reddy to the project.'), findsOneWidget);
      expect(find.text('Pipeline (6)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('project.tab.pipeline')));
      await tester.pumpAndSettle();
      expect(find.text('Kavya Reddy'), findsOneWidget, reason: 'now in Sourced');
    });

    testWidgets('a refused save is shown above the matches, as the website’s warning', (tester) async {
      await pump(
        tester,
        repository: DemoProjectsRepository(failWrites: 'Your plan includes 5 candidates saved to projects.'),
      );
      await openProject(tester, 'proj-1');
      await tester.tap(find.byKey(const Key('project.tab.find')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('project.match.save.u-kavya')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('project.saveError')), findsOneWidget);
      expect(find.text('Your plan includes 5 candidates saved to projects.'), findsOneWidget);
      expect(find.text('Kavya Reddy'), findsOneWidget, reason: 'still offered');
    });

    testWidgets('no matches says how to loosen the criteria', (tester) async {
      await pump(tester);
      await openProject(tester, 'proj-2');
      await tester.tap(find.byKey(const Key('project.tab.find')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('project.matches.empty')), findsOneWidget);
      expect(find.text("Broaden the project's criteria or add candidates from talent search."), findsOneWidget);
    });

    testWidgets('Archive sends the website’s patch and the button turns to Un-archive; the list drops the row', (
      tester,
    ) async {
      await pump(tester);
      await openProject(tester, 'proj-2');
      await tester.tap(find.byKey(const Key('project.archive')));
      await tester.pumpAndSettle();
      expect(repo.sent.last, {
        'op': 'update',
        'id': 'proj-2',
        'body': {'archived': true},
      });
      expect(find.text('Unarchive'), findsOneWidget);
      expect(find.text('Project archived.'), findsOneWidget);

      await tester.tap(find.byIcon(Symbols.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Workplace tech leads'), findsNothing, reason: 'archived, and Show archived is off');
    });

    testWidgets('Edit opens the form over the project and sends only what changed', (tester) async {
      await pump(tester);
      await openProject(tester, 'proj-1');
      await tester.tap(find.byKey(const Key('project.menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('project.menu.edit')));
      await tester.pumpAndSettle();
      expect(find.text('Edit Project'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byKey(const Key('project.titles'))).controller!.text,
        'Facility Manager, Transactions',
        reason: 'the lists come back comma separated',
      );
      expect(saveEnabled(tester), isFalse, reason: 'nothing changed yet');

      await type(tester, 'project.name', 'Regional FM Managers — West & South');
      await type(tester, 'project.locations', 'Mumbai, Pune, Bengaluru');
      await type(tester, 'project.minYears', '');
      await pickFrom(tester, 'project.job', 'Not Linked to a Job');
      await tester.tap(find.byKey(const Key('sheet.save')));
      await tester.pumpAndSettle();

      expect(repo.sent.last, {
        'op': 'update',
        'id': 'proj-1',
        'body': {
          'name': 'Regional FM Managers — West & South',
          'jobId': null,
          'locations': ['Mumbai', 'Pune', 'Bengaluru'],
          'minYears': null,
        },
      });
      expect(find.text('Project saved.'), findsOneWidget);
      expect(find.text('Regional FM Managers — West & South'), findsOneWidget);
      expect(find.text('Location: Bengaluru'), findsOneWidget);
      expect(find.byKey(const Key('project.job.chip')), findsNothing);
      expect(find.text('Pipeline (5)'), findsOneWidget, reason: 'the counts the page read are kept');
    });

    testWidgets('Delete asks first; backing out sends nothing, confirming deletes and returns to the list', (
      tester,
    ) async {
      await pump(tester);
      await openProject(tester, 'proj-2');
      await tester.tap(find.byKey(const Key('project.menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('project.menu.delete')));
      await tester.pumpAndSettle();
      expect(find.text('Delete Workplace tech leads?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.sent, isEmpty);
      expect(find.byKey(const Key('project.title')), findsOneWidget);

      await tester.tap(find.byKey(const Key('project.menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('project.menu.delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm.ok')));
      await tester.pumpAndSettle();
      expect(repo.sent, [
        {'op': 'delete', 'id': 'proj-2'},
      ]);
      expect(find.text('Talent Sourcing Projects'), findsOneWidget, reason: 'back on the list');
      expect(find.text('Workplace tech leads'), findsNothing);
      expect(find.text('Regional FM Managers — West'), findsOneWidget);
    });

    testWidgets('a page that cannot be read says so and can be tried again', (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ProjectScreen(projectId: 'missing', repository: DemoProjectsRepository(), onBack: () {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('project.error')), findsOneWidget);
      expect(find.text('Project not found.'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });
  });

  group('the model', () {
    test('reads the API’s project with its counts, criteria and subtitle', () {
      final p = Project.fromJson({
        'id': 'p1',
        'name': 'West bench',
        'description': null,
        'visibility': 'TEAM',
        'jobId': 'j1',
        'job': {'id': 'j1', 'title': 'Senior FM'},
        'titles': ['Facility Manager'],
        'skills': ['FM'],
        'locations': ['Pune'],
        'seniority': 'SENIOR',
        'workMode': null,
        'minYears': 5,
        'stageCounts': {'SOURCED': 2, 'ARCHIVED': 1},
        'candidateCount': 3,
        'archivedAt': null,
        'createdBy': {'firstName': 'Asha', 'lastName': 'Rao'},
        'createdAt': '2026-11-01T10:00:00.000Z',
        'updatedAt': '2026-11-10T10:00:00.000Z',
      });
      expect(p.subtitle, 'Sourcing for Senior FM');
      expect(p.criteria, ['Title: Facility Manager', 'Skill: FM', 'Location: Pune', '5+ yrs', 'Senior']);
      expect(p.stageCounts, {'SOURCED': 2, 'ARCHIVED': 1});
      expect(p.candidateCount, 3);
      expect(p.createdByName, 'Asha Rao');
      expect(p.archived, isFalse);
    });

    test('a draft sends only what differs from the project, clearing with null', () {
      const p = Project(
        id: 'p1',
        name: 'West bench',
        description: 'Old words',
        visibility: 'TEAM',
        jobId: 'j1',
        jobTitle: 'Senior FM',
        titles: ['Facility Manager'],
        minYears: 5,
      );
      const same = ProjectDraft(
        name: 'West bench ',
        description: ' Old words',
        visibility: 'TEAM',
        jobId: 'j1',
        titles: ['Facility Manager'],
        minYears: 5,
      );
      expect(same.changesFrom(p), isEmpty);
      const changed = ProjectDraft(
        name: 'West bench',
        description: '',
        visibility: 'PRIVATE',
        titles: ['Facility Manager'],
      );
      expect(changed.changesFrom(p), {'description': null, 'visibility': 'PRIVATE', 'jobId': null, 'minYears': null});
    });

    test('the candidate’s meta line and "Applied to" chip read as the website’s', () {
      final c = ProjectCandidate.fromJson({
        'id': 'r1',
        'projectId': 'p1',
        'candidateId': 'u1',
        'firstName': 'Meera',
        'lastName': 'Shah',
        'stage': 'SOURCED',
        'currentCompany': 'JLL',
        'currentLocation': 'Mumbai',
        'experienceYears': 5,
        'noticePeriodDays': 0,
        'applicationId': 'a1',
        'applicationStage': 'INTERVIEW',
        'applicationJobId': 'j1',
        'applicationJobTitle': 'Senior FM',
      });
      expect(c.meta, 'JLL · Mumbai · 5 yrs · Immediate');
      expect(c.appliedChip, 'Applied to Senior FM · interview');
      expect(nextSourcingStage('SOURCED'), 'CONTACTED');
      expect(nextSourcingStage('SHORTLISTED'), isNull);
      expect(nextSourcingStage('ARCHIVED'), isNull);
    });
  });
}
