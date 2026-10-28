import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/widgets/title_bar.dart';
import 'package:icr_mobile/features/become_mentor/become_mentor_models.dart';
import 'package:icr_mobile/features/mentorship_my/mentoring_clock.dart';
import 'package:icr_mobile/features/mentorship_my/widgets/kit.dart';

import 'become_mentor_fakes.dart';
import 'helpers/fonts.dart';
import 'mentoring_fakes.dart';

Finder card(String k) => find.byKey(ValueKey('card-$k'));
Finder inCard(String k, String text) => find.descendant(of: card(k), matching: find.text(text));

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await settle(tester);
}

Future<void> tapText(WidgetTester tester, String text, {int index = 0}) async {
  final f = find.text(text).at(index);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await settle(tester);
}

/// Opens a card's sheet from its button.
Future<void> openCard(WidgetTester tester, String key, String button) async {
  final f = inCard(key, button);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await settle(tester);
}

Future<void> enter(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(ValueKey(key)), text);
  await tester.pump();
}

/// Taps the sheet's own button (the last one drawn: the page behind it may carry the same word).
Future<void> tapSheetButton(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).last);
  await settle(tester);
}

Map<String, Object?> credential(String code, String status, {String? name}) => {
  'id': 'cr-$code',
  'code': code,
  'name': name ?? '$code credential',
  'status': status,
};

void main() {
  setUpAll(loadAppFonts);
  setUp(() => mentoringNow = () => DateTime(2026, 10, 26, 10));
  tearDown(() => mentoringNow = DateTime.now);

  group('a member with no mentor profile yet', () {
    testWidgets('sees where to start: the draft banner, three steps, and every line still needed', (tester) async {
      final (api, _) = await pumpBecomeMentor(tester, MentorWorld());
      expect(find.text('Become a mentor'), findsOneWidget);
      expect(find.byKey(const ValueKey('banner-DRAFT')), findsOneWidget);
      expect(find.textContaining('Draft — not yet visible'), findsOneWidget);
      expect(find.text('Not started'), findsOneWidget);
      expect(find.text('0 of 3 steps done'), findsOneWidget);
      for (final line in [
        'Add your current role.',
        'Add your years in the profession.',
        'Add at least one language you mentor in.',
        'Add at least one role to your career history.',
        'Tell mentees how you mentor — at least 100 characters.',
        'Add at least one area of expertise — it is how mentees find you.',
        'Choose who you want to mentor.',
      ]) {
        expect(find.text(line), findsOneWidget, reason: line);
      }
      expect(
        find.text('Add a profile photo — it is the first thing a mentee sees.'),
        findsNothing,
        reason: 'there is a photo',
      );
      expect(find.text('Still missing from your card'), findsNothing);
      expect(find.text('Still needed to submit'), findsOneWidget);
      expect(find.text('Finish the items above to submit.'), findsOneWidget);
      expect(tester.widget<SolidButton>(find.byKey(const ValueKey('submit'))).onPressed, isNull);
      // Nothing is read that needs a profile.
      expect(api.count('GET /mentorship/mentors/me/documents'), 0);
      expect(find.byKey(const ValueKey('card-documents')), findsNothing);
      expect(find.byKey(const ValueKey('card-listing')), findsNothing);
    });

    testWidgets('a missing photo is the first thing needed', (tester) async {
      await pumpBecomeMentor(tester, MentorWorld(avatar: null));
      expect(find.text('Add a profile photo — it is the first thing a mentee sees.'), findsOneWidget);
      expect(find.byKey(const ValueKey('photo-line')), findsOneWidget);
      expect(
        find.text('No photo yet. It is the first thing a mentee sees, and it is needed to submit.'),
        findsOneWidget,
      );
    });

    testWidgets('a line of the checklist opens the sheet that fixes it', (tester) async {
      await pumpBecomeMentor(tester, MentorWorld());
      await tapText(tester, 'Tell mentees how you mentor — at least 100 characters.');
      expect(find.byKey(const ValueKey('bio-text')), findsOneWidget);
      await tester.tapAt(const Offset(20, 20));
      await settle(tester);
      await tapText(tester, 'Add your current role.');
      expect(find.byKey(const ValueKey('intro-role')), findsOneWidget);
      await tester.tapAt(const Offset(20, 20));
      await settle(tester);
      await tapText(tester, 'Choose who you want to mentor.');
      expect(find.byKey(const ValueKey('audience-EARLY_CAREER')), findsOneWidget);
    });

    testWidgets('a load that fails says why, and Try again asks again', (tester) async {
      final w = MentorWorld();
      var fail = true;
      final (api, _) = await pumpBecomeMentor(
        tester,
        w,
        extra: {'GET /mentorship/mentors/me': (_) => fail ? refuse('The mentoring service is down.', status: 500) : ''},
      );
      expect(find.text("Couldn't load your mentor profile"), findsOneWidget);
      expect(find.text('The mentoring service is down.'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.text('Become a mentor'), findsOneWidget);
      expect(api.count('GET /mentorship/mentors/me'), 2);
    });

    testWidgets('the bell opens the notifications', (tester) async {
      final (_, rec) = await pumpBecomeMentor(tester, MentorWorld());
      await tester.tap(find.byType(BellButton));
      await tester.pump();
      expect(rec.opened, ['bell']);
    });

    testWidgets('pulling down reads it all again', (tester) async {
      final (api, _) = await pumpBecomeMentor(tester, MentorWorld(), height: 1800);
      await tester.fling(find.byType(ListView).first, const Offset(0, 500), 1000);
      await settle(tester);
      expect(api.count('GET /mentorship/mentors/me'), 2);
      expect(api.count('GET /mentorship/mentors/me/readiness'), 2);
      expect(api.count('GET /users/me/profile'), 2);
    });
  });

  group('How you mentor', () {
    testWidgets('the first save creates the draft, as paragraphs stored as HTML', (tester) async {
      final (api, _) = await pumpBecomeMentor(tester, MentorWorld());
      await openCard(tester, 'bio', 'Add');
      expect(find.text('0 of the 100 characters needed to submit. Blank lines start a new paragraph.'), findsOneWidget);
      await enter(tester, 'bio-text', 'Hello\n\nWorld');
      expect(
        find.text('11 of the 100 characters needed to submit. Blank lines start a new paragraph.'),
        findsOneWidget,
      );
      await tapSheetButton(tester, 'Save');
      expect(api.bodyOf('PUT /mentorship/mentors/me'), {'bioHtml': '<p>Hello</p><p>World</p>'});
      expect(find.text('Saved.'), findsOneWidget);
      expect(find.text('My mentor profile'), findsOneWidget, reason: 'there is a profile now');
      expect(find.text('Hello\n\nWorld'), findsOneWidget);
      expect(find.byKey(const ValueKey('card-documents')), findsOneWidget, reason: 'a profile can hold documents');
    });

    testWidgets('a hundred characters turns the counter into the paragraph hint, and the need disappears', (
      tester,
    ) async {
      await pumpBecomeMentor(tester, MentorWorld());
      await openCard(tester, 'bio', 'Add');
      await enter(tester, 'bio-text', 'a' * 100);
      expect(find.text('Blank lines start a new paragraph.'), findsOneWidget);
    });

    testWidgets('emptying it sends null, and a draft may be saved at any length under the limit', (tester) async {
      final w = MentorWorld(withProfile: true)..profile!['bioHtml'] = '<p>Short.</p>';
      final (api, _) = await pumpBecomeMentor(tester, w);
      await openCard(tester, 'bio', 'Edit');
      expect(find.text('Short.'), findsWidgets);
      await enter(tester, 'bio-text', '');
      await tapSheetButton(tester, 'Save');
      expect(api.bodyOf('PUT /mentorship/mentors/me'), {'bioHtml': null});
    });

    testWidgets('over 20,000 characters is refused here, as the API refuses it, and nothing is sent', (tester) async {
      final (api, _) = await pumpBecomeMentor(tester, MentorWorld());
      await openCard(tester, 'bio', 'Add');
      await enter(tester, 'bio-text', 'a' * 20001);
      await tapSheetButton(tester, 'Save');
      expect(find.text('“How you mentor” is too long — keep it under 20,000 characters.'), findsOneWidget);
      expect(api.count('PUT /mentorship/mentors/me'), 0);
    });

    testWidgets('a refusal stays in the sheet, with what was typed', (tester) async {
      final w = MentorWorld()..refusals['PUT me'] = refuse('We could not save your profile. Try again.');
      final (api, _) = await pumpBecomeMentor(tester, w);
      await openCard(tester, 'bio', 'Add');
      await enter(tester, 'bio-text', 'My own words');
      await tapSheetButton(tester, 'Save');
      expect(find.text('We could not save your profile. Try again.'), findsOneWidget);
      expect(find.text('My own words'), findsOneWidget);
      await tapSheetButton(tester, 'Save');
      expect(api.count('PUT /mentorship/mentors/me'), 2);
      expect(find.text('Saved.'), findsOneWidget);
    });
  });

  group('Expertise', () {
    testWidgets('areas are searched and chosen from the 24 domains, topics are typed', (tester) async {
      final (api, _) = await pumpBecomeMentor(tester, MentorWorld());
      await openCard(tester, 'expertise', 'Add');
      expect(find.text('0 chosen, up to 12.'), findsOneWidget);
      await enter(tester, 'option-search', 'facil');
      expect(find.byKey(const ValueKey('option-Facility Management')), findsOneWidget);
      expect(find.byKey(const ValueKey('option-Vendor Management')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('option-Facility Management')));
      await tester.pump();
      expect(find.text('1 chosen, up to 12.'), findsOneWidget);
      await enter(tester, 'topic-text', 'Managing your first team');
      await tester.tap(find.text('Add').last);
      await tester.pump();
      expect(find.byKey(const ValueKey('chip-Managing your first team')), findsOneWidget);
      await enter(tester, 'topic-text', 'managing YOUR first team');
      await tester.tap(find.text('Add').last);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('chip-managing YOUR first team')),
        findsNothing,
        reason: 'a duplicate is ignored',
      );
      await tapSheetButton(tester, 'Save');
      expect(api.bodyOf('PUT /mentorship/mentors/me'), {
        'competencies': ['Facility Management'],
        'topics': ['Managing your first team'],
      });
      expect(find.text('Facility Management'), findsOneWidget);
      expect(find.text('Managing your first team'), findsOneWidget);
    });

    testWidgets('no more than twelve areas can be chosen', (tester) async {
      await pumpBecomeMentor(tester, MentorWorld());
      await openCard(tester, 'expertise', 'Add');
      for (final d in competencyDomains.take(12)) {
        final f = find.byKey(ValueKey('option-$d'));
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pump();
      }
      expect(find.text('12 of 12 chosen: the most you can pick.'), findsOneWidget);
      final thirteenth = find.byKey(ValueKey('option-${competencyDomains[12]}'));
      await tester.ensureVisible(thirteenth);
      await tester.tap(thirteenth, warnIfMissed: false);
      await tester.pump();
      expect(find.text('12 of 12 chosen: the most you can pick.'), findsOneWidget);
    });

    testWidgets('a topic can be taken away again, and at most twelve are held', (tester) async {
      final w = MentorWorld(withProfile: true)..profile!['topics'] = [for (var i = 0; i < 12; i++) 'Topic $i'];
      final (api, _) = await pumpBecomeMentor(tester, w);
      await openCard(tester, 'expertise', 'Edit');
      expect(find.text('That is the most you can add (12)'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Remove Topic 3'));
      await tester.tap(find.byTooltip('Remove Topic 3'));
      await tester.pump();
      await tapSheetButton(tester, 'Save');
      final topics = (api.bodyOf('PUT /mentorship/mentors/me') as Map)['topics'] as List;
      expect(topics, hasLength(11));
      expect(topics, isNot(contains('Topic 3')));
    });
  });

  group('Who you mentor', () {
    testWidgets('audiences are kept in the enum\'s order, and roles are picked from ICR\'s titles or typed', (
      tester,
    ) async {
      final (api, _) = await pumpBecomeMentor(tester, MentorWorld());
      await openCard(tester, 'audience', 'Choose');
      await tester.tap(find.byKey(const ValueKey('audience-PEOPLE_LEADER')));
      await tester.tap(find.byKey(const ValueKey('audience-EARLY_CAREER')));
      await tester.pump();
      await enter(tester, 'role-text', 'facil');
      expect(find.byKey(const ValueKey('suggest-Facility Manager')), findsOneWidget);
      expect(find.byKey(const ValueKey('suggest-Facilities Head')), findsOneWidget);
      expect(find.byKey(const ValueKey('suggest-Energy Manager')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('suggest-Facility Manager')));
      await tester.pump();
      await enter(tester, 'role-text', 'Portfolio Lead');
      await tester.tap(find.text('Add').last);
      await tester.pump();
      await tapSheetButton(tester, 'Save');
      expect(api.bodyOf('PUT /mentorship/mentors/me'), {
        'targetAudiences': ['EARLY_CAREER', 'PEOPLE_LEADER'],
        'targetRoles': ['Facility Manager', 'Portfolio Lead'],
      });
      expect(find.text('Early career'), findsOneWidget);
      expect(find.text('People leader'), findsOneWidget);
      expect(find.text('Portfolio Lead'), findsOneWidget);
    });

    testWidgets('ticking a box off removes it, and eight roles are the most', (tester) async {
      final w = MentorWorld(withProfile: true)
        ..profile!['targetAudiences'] = ['EARLY_CAREER', 'RETURNER']
        ..profile!['targetRoles'] = [for (var i = 0; i < 8; i++) 'Role $i'];
      final (api, _) = await pumpBecomeMentor(tester, w);
      await openCard(tester, 'audience', 'Edit');
      expect(find.text('That is the most you can add (8)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('audience-EARLY_CAREER')));
      await tester.pump();
      await tapSheetButton(tester, 'Save');
      expect((api.bodyOf('PUT /mentorship/mentors/me') as Map)['targetAudiences'], ['RETURNER']);
    });
  });

  group('Availability', () {
    testWidgets('capacity, how you meet, how often and when you are free are saved as the API takes them', (
      tester,
    ) async {
      final (api, _) = await pumpBecomeMentor(tester, MentorWorld(withProfile: true));
      expect(find.byKey(const ValueKey('capacity-line')), findsOneWidget);
      await openCard(tester, 'availability', 'Edit');
      expect(find.text('Mentees at a time: 2'), findsOneWidget);
      await tester.drag(find.byKey(const ValueKey('capacity-slider')), const Offset(150, 0));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('mode-PHONE')));
      await tester.tap(find.byKey(const ValueKey('cadence-WEEKLY')));
      await enter(tester, 'availability-note', 'Weekday evenings after 7pm IST');
      await tapSheetButton(tester, 'Save');
      final body = api.bodyOf('PUT /mentorship/mentors/me') as Map;
      expect(body['capacity'], greaterThan(2));
      expect(body['capacity'], lessThanOrEqualTo(10));
      expect(body['preferredModes'], ['VIDEO', 'PHONE']);
      expect(body['cadence'], 'WEEKLY');
      expect(body['availabilityNote'], 'Weekday evenings after 7pm IST');
      expect(find.text('Video call · Phone'), findsOneWidget);
      expect(find.text('Weekly'), findsOneWidget);
    });

    testWidgets('a cadence is cleared by tapping it again, and an emptied note is sent as null', (tester) async {
      final w = MentorWorld(withProfile: true)
        ..profile!['cadence'] = 'MONTHLY'
        ..profile!['availabilityNote'] = 'Saturdays';
      final (api, _) = await pumpBecomeMentor(tester, w);
      await openCard(tester, 'availability', 'Edit');
      await tester.tap(find.byKey(const ValueKey('cadence-MONTHLY')));
      await tester.pump();
      await enter(tester, 'availability-note', '   ');
      await tapSheetButton(tester, 'Save');
      final body = api.bodyOf('PUT /mentorship/mentors/me') as Map;
      expect(body['cadence'], isNull);
      expect(body.containsKey('cadence'), isTrue, reason: 'null is sent so the API clears it');
      expect(body['availabilityNote'], isNull);
    });

    testWidgets('a note over 280 characters is refused with the API\'s words, and nothing is sent', (tester) async {
      final (api, _) = await pumpBecomeMentor(tester, MentorWorld(withProfile: true));
      await openCard(tester, 'availability', 'Edit');
      await enter(tester, 'availability-note', 'a' * 281);
      expect(find.text('281 / 280'), findsOneWidget);
      await tapSheetButton(tester, 'Save');
      expect(find.text('Keep “When you\'re free” to 280 characters.'), findsOneWidget);
      expect(api.count('PUT /mentorship/mentors/me'), 0);
    });
  });

  group('Weekly hours', () {
    testWidgets('they cannot be set before there is a profile: they belong to it', (tester) async {
      await pumpBecomeMentor(tester, MentorWorld());
      expect(find.text('Save any section above first: your hours belong to your mentor profile.'), findsOneWidget);
      expect(inCard('hours', 'Set hours'), findsNothing, reason: 'there is no button to press yet');
    });

    testWidgets('a window is added to a day, saved as minutes after midnight, and listed Monday first', (tester) async {
      final (api, _) = await pumpBecomeMentor(tester, MentorWorld(withProfile: true));
      expect(
        find.text('No weekly hours set: a mentee asks you for a time instead of picking a free one.'),
        findsOneWidget,
      );
      await openCard(tester, 'hours', 'Set hours');
      await tapKey(tester, 'add-window-2');
      await tapKey(tester, 'add-window-0');
      expect(find.text('2 of 21 windows'), findsOneWidget);
      await tapSheetButton(tester, 'Save hours');
      expect(api.bodyOf('PUT /mentorship/mentors/me/availability'), {
        'blocks': [
          {'weekday': 2, 'startMin': 1080, 'endMin': 1170},
          {'weekday': 0, 'startMin': 1080, 'endMin': 1170},
        ],
      });
      expect(find.text('Hours saved.'), findsOneWidget);
      final lines = [for (final t in tester.widgetList<Text>(find.byType(Text))) t.data ?? ''];
      final tuesday = lines.indexWhere((l) => l.startsWith('Tuesday'));
      final sunday = lines.indexWhere((l) => l.startsWith('Sunday'));
      expect(tuesday, greaterThan(-1));
      expect(sunday, greaterThan(tuesday), reason: 'the week reads Monday to Sunday');
      expect(find.text('Tuesday  6:00 PM – 7:30 PM'), findsOneWidget);
    });

    testWidgets('two windows on a day must not overlap, and a window must end after it starts', (tester) async {
      final w = MentorWorld(withProfile: true)
        ..profile!['availabilityBlocks'] = [
          {'weekday': 2, 'startMin': 1080, 'endMin': 1230},
        ];
      final (api, _) = await pumpBecomeMentor(tester, w);
      expect(find.text('Tuesday  6:00 PM – 8:30 PM'), findsOneWidget);
      await openCard(tester, 'hours', 'Edit hours');
      await tapKey(tester, 'add-window-2');
      await tester.tap(find.byKey(const ValueKey('start-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('8:00 PM').last);
      await tester.pumpAndSettle();
      await tapSheetButton(tester, 'Save hours');
      expect(find.text('Windows on the same day must not overlap.'), findsOneWidget);
      expect(api.count('PUT /mentorship/mentors/me/availability'), 0);

      await tester.tap(find.byKey(const ValueKey('end-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5:00 PM').last);
      await tester.pumpAndSettle();
      await tapSheetButton(tester, 'Save hours');
      expect(find.text('Each window must end after it starts.'), findsOneWidget);
      expect(api.count('PUT /mentorship/mentors/me/availability'), 0);
    });

    testWidgets(
      'a window can be removed, all of them can (the API clears the hours), and the API\'s refusal stays in the sheet',
      (tester) async {
        final w = MentorWorld(withProfile: true)
          ..profile!['availabilityBlocks'] = [
            {'weekday': 1, 'startMin': 600, 'endMin': 720},
          ]
          ..refusals['hours'] = refuse('Create a mentor profile first.', status: 404);
        final (api, _) = await pumpBecomeMentor(tester, w);
        await openCard(tester, 'hours', 'Edit hours');
        await tapKey(tester, 'remove-window-0');
        expect(find.text('0 of 21 windows'), findsOneWidget);
        await tapSheetButton(tester, 'Save hours');
        expect(find.text('Create a mentor profile first.'), findsOneWidget);
        await tapSheetButton(tester, 'Save hours');
        expect(api.bodyOf('PUT /mentorship/mentors/me/availability'), {'blocks': <Object?>[]});
      },
    );
  });

  group('Certifications', () {
    MentorWorld withCredentials() => MentorWorld(withProfile: true)
      ..credentials = [
        credential('CFMP', 'VERIFIED', name: 'Certified Facility Management Professional'),
        credential('CCREA', 'SELF_DECLARED'),
        credential('OLD', 'REJECTED'),
        {'id': 'cr-x', 'code': null, 'name': 'A credential with no short code', 'status': 'VERIFIED'},
      ];

    testWidgets(
      'are picked from what the member holds, never typed; a rejected or code-less credential is not offered',
      (tester) async {
        final (api, rec) = await pumpBecomeMentor(tester, withCredentials());
        expect(
          find.text('Optional. Show the certifications you hold — mentees working toward the same one look for them.'),
          findsOneWidget,
        );
        await openCard(tester, 'certifications', 'Choose');
        expect(find.byKey(const ValueKey('cert-CFMP')), findsOneWidget);
        expect(find.text('CFMP · verified'), findsOneWidget);
        expect(find.byKey(const ValueKey('cert-CCREA')), findsOneWidget);
        expect(find.byKey(const ValueKey('cert-OLD')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('cert-CFMP')));
        await tester.pump();
        await tapSheetButton(tester, 'Save');
        expect(api.bodyOf('PUT /mentorship/mentors/me'), {
          'certifications': ['CFMP'],
        });
        expect(find.text('CFMP'), findsOneWidget);
        expect(rec.sites, isEmpty);
      },
    );

    testWidgets('Manage my credentials opens the profile\'s credentials page on the website', (tester) async {
      final (_, rec) = await pumpBecomeMentor(tester, withCredentials());
      await openCard(tester, 'certifications', 'Choose');
      await tester.tap(find.text('Manage my credentials'));
      await tester.pump();
      expect(rec.sites, ['/profile?tab=credentials&code=1']);
    });

    testWidgets('a code the member no longer holds stays visible, blocks the save, and is removed first', (
      tester,
    ) async {
      final w = withCredentials()..profile!['certifications'] = ['CFMP', 'GONE'];
      final (api, _) = await pumpBecomeMentor(tester, w);
      expect(
        find.text('Remove GONE from your certifications — no longer on your profile.'),
        findsOneWidget,
        reason: 'the checklist names it',
      );
      expect(find.textContaining('GONE is no longer on your profile — remove it before you submit.'), findsOneWidget);
      await openCard(tester, 'certifications', 'Edit');
      expect(find.byKey(const ValueKey('stale-GONE')), findsOneWidget);
      await tapSheetButton(tester, 'Save');
      expect(find.text('GONE is no longer on your profile — remove it to save.'), findsWidgets);
      expect(api.count('PUT /mentorship/mentors/me'), 0);
      await tester.tap(find.byTooltip('Remove GONE'));
      await tester.pump();
      await tapSheetButton(tester, 'Save');
      expect(api.bodyOf('PUT /mentorship/mentors/me'), {
        'certifications': ['CFMP'],
      });
    });
  });

  group('Role and experience', () {
    testWidgets('are the person\'s own, written to PATCH /users/me, and read back', (tester) async {
      final (api, _) = await pumpBecomeMentor(tester, MentorWorld());
      expect(find.text('Not added yet — needed to submit.'), findsNWidgets(2));
      await openCard(tester, 'intro', 'Add');
      await enter(tester, 'intro-role', 'facil');
      expect(find.byKey(const ValueKey('role-suggest-Facility Manager')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('role-suggest-Facility Manager')));
      await tester.pump();
      await enter(tester, 'intro-years', '12');
      await tapSheetButton(tester, 'Save');
      expect(api.bodyOf('PATCH /users/me'), {'designation': 'Facility Manager', 'yearsExperience': 12});
      expect(find.text('Facility Manager'), findsOneWidget);
      expect(find.text('12 years'), findsOneWidget);
      expect(find.text('Add your current role.'), findsNothing, reason: 'the need is gone');
      expect(find.text('Add your years in the profession.'), findsNothing);
    });

    testWidgets('are checked as the API checks them: two characters at least, whole years 0 to 60', (tester) async {
      final (api, _) = await pumpBecomeMentor(tester, MentorWorld());
      await openCard(tester, 'intro', 'Add');
      await enter(tester, 'intro-role', 'A');
      await tapSheetButton(tester, 'Save');
      expect(find.text('A headline needs at least 2 characters.'), findsOneWidget);
      await enter(tester, 'intro-role', 'Head of Facilities');
      await enter(tester, 'intro-years', '61');
      await tapSheetButton(tester, 'Save');
      expect(find.text('Whole years, 0–60.'), findsNWidgets(2), reason: 'the hint under the field, and the problem');
      await enter(tester, 'intro-years', '1.5');
      await tapSheetButton(tester, 'Save');
      expect(find.text('Whole years, 0–60.'), findsNWidgets(2));
      expect(api.count('PATCH /users/me'), 0);
    });

    testWidgets('a blank role and blank years clear them', (tester) async {
      final (api, _) = await pumpBecomeMentor(tester, MentorWorld(designation: 'Head of Facilities', years: 9));
      await openCard(tester, 'intro', 'Edit');
      await enter(tester, 'intro-role', '');
      await enter(tester, 'intro-years', '');
      await tapSheetButton(tester, 'Save');
      expect(api.bodyOf('PATCH /users/me'), {'designation': '', 'yearsExperience': null});
      expect(find.text('Add your current role.'), findsOneWidget);
    });

    testWidgets('a refusal from the API stays in the sheet', (tester) async {
      final w = MentorWorld()..refusals['PATCH me'] = refuse('That role cannot be saved right now.');
      final (api, _) = await pumpBecomeMentor(tester, w);
      await openCard(tester, 'intro', 'Add');
      await enter(tester, 'intro-role', 'Head of Facilities');
      await tapSheetButton(tester, 'Save');
      expect(find.text('That role cannot be saved right now.'), findsOneWidget);
      expect(find.text('Head of Facilities'), findsOneWidget);
      await tapSheetButton(tester, 'Save');
      expect(api.count('PATCH /users/me'), 2);
    });
  });

  group('Languages', () {
    testWidgets('are picked from the usual ones or typed, and saved as a list', (tester) async {
      final (api, _) = await pumpBecomeMentor(tester, MentorWorld());
      await openCard(tester, 'languages', 'Add');
      await tester.tap(find.byKey(const ValueKey('suggest-Hindi')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('suggest-English')));
      await tester.pump();
      await enter(tester, 'language-text', 'Tulu');
      await tester.tap(find.text('Add').last);
      await tester.pump();
      await enter(tester, 'language-text', 'hindi');
      await tester.tap(find.text('Add').last);
      await tester.pump();
      await tapSheetButton(tester, 'Save');
      expect(api.bodyOf('PATCH /users/me'), {
        'languages': ['Hindi', 'English', 'Tulu'],
      });
      expect(find.text('Tulu'), findsOneWidget);
      expect(find.text('Add at least one language you mentor in.'), findsNothing);
    });

    testWidgets('no more than eight, and one can be taken away', (tester) async {
      final w = MentorWorld(
        languages: ['English', 'Hindi', 'Tamil', 'Telugu', 'Kannada', 'Marathi', 'Bengali', 'Odia'],
      );
      final (api, _) = await pumpBecomeMentor(tester, w);
      await openCard(tester, 'languages', 'Edit');
      expect(find.text('That is the most you can add (8)'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove Odia'));
      await tester.pump();
      await tapSheetButton(tester, 'Save');
      expect((api.bodyOf('PATCH /users/me') as Map)['languages'], hasLength(7));
    });
  });

  group('Career history', () {
    Future<void> fillRole(
      WidgetTester tester, {
      String title = 'Facility Manager',
      String org = 'Prestige Group',
      String year = '2019',
    }) async {
      await enter(tester, 'xp-title', title);
      await enter(tester, 'xp-org', org);
      await enter(tester, 'xp-start-year', year);
    }

    testWidgets('a role is added, and the whole list is saved as the API wants it', (tester) async {
      final (api, _) = await pumpBecomeMentor(tester, MentorWorld());
      expect(find.text('Add at least one role to your career history to submit.'), findsOneWidget);
      await openCard(tester, 'experience', 'Add a role');
      await fillRole(tester);
      await enter(tester, 'xp-city', 'Bengaluru');
      await tester.tap(find.byKey(const ValueKey('xp-start-month')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apr').last);
      await tester.pumpAndSettle();
      await tapSheetButton(tester, 'Save role');
      expect(api.bodyOf('PUT /profile/experience'), {
        'rows': [
          {
            'title': 'Facility Manager',
            'organisation': 'Prestige Group',
            'city': 'Bengaluru',
            'industryKeys': <Object?>[],
            'startYear': 2019,
            'startMonth': 4,
            'isCurrent': true,
          },
        ],
      });
      expect(find.text('Role added.'), findsOneWidget);
      expect(find.text('Facility Manager'), findsOneWidget);
      expect(find.text('Prestige Group · Apr 2019 - Present'), findsOneWidget);
      expect(find.text('Add at least one role to your career history.'), findsNothing);
    });

    testWidgets('every rule shows its sentence under the form, and nothing is sent', (tester) async {
      final (api, _) = await pumpBecomeMentor(tester, MentorWorld());
      await openCard(tester, 'experience', 'Add a role');
      await tapSheetButton(tester, 'Save role');
      expect(find.text('Add your role.'), findsWidgets);
      expect(find.text('Add the organisation.'), findsWidgets);
      expect(find.text('Add the year you started.'), findsWidgets);
      await fillRole(tester, year: '2027');
      await tester.pump();
      expect(find.text('The start date can’t be in the future.'), findsOneWidget);
      await fillRole(tester, title: 'F', org: 'P');
      await tester.pump();
      expect(find.text('A role needs at least 2 characters.'), findsOneWidget);
      expect(find.text('An organisation needs at least 2 characters.'), findsOneWidget);
      await fillRole(tester);
      await tester.tap(find.byKey(const ValueKey('xp-current')));
      await tester.pump();
      expect(find.text('Add when this role ended, or tick “I work here now”.'), findsOneWidget);
      await enter(tester, 'xp-end-year', '2017');
      await tester.pump();
      expect(find.text('The end date is before the start date.'), findsOneWidget);
      await enter(tester, 'xp-end-year', '2027');
      await tester.pump();
      expect(
        find.text('The end date can’t be in the future. If you still work here, tick “I work here now”.'),
        findsOneWidget,
      );
      await tapSheetButton(tester, 'Save role');
      expect(api.count('PUT /profile/experience'), 0);
    });

    testWidgets('a role that ended is saved with its end, and a role can be edited without losing what it carried', (
      tester,
    ) async {
      final w = MentorWorld(
        experience: [
          {
            'id': 'xp-0',
            'title': 'Head of Facilities',
            'organisation': 'Prestige Group',
            'company': {'id': 'co-1', 'name': 'Prestige Group'},
            'employmentType': 'FULL_TIME',
            'city': 'Bengaluru',
            'industryKeys': ['real-estate'],
            'startYear': 2019,
            'startMonth': 4,
            'endYear': null,
            'endMonth': null,
            'isCurrent': true,
            'description': null,
            'sortOrder': 0,
          },
          {
            'id': 'xp-1',
            'title': 'Site Engineer',
            'organisation': 'ACME',
            'company': null,
            'employmentType': null,
            'city': null,
            'industryKeys': <String>[],
            'startYear': 2012,
            'startMonth': null,
            'endYear': 2018,
            'endMonth': 12,
            'isCurrent': false,
            'description': 'Built things.',
            'sortOrder': 1,
          },
        ],
      );
      final (api, _) = await pumpBecomeMentor(tester, w);
      expect(find.text('ACME · 2012 - Dec 2018'), findsOneWidget);
      await tapKey(tester, 'role-0');
      expect(find.text('Edit this role'), findsOneWidget);
      await enter(tester, 'xp-title', 'Head of Facilities Strategy');
      await tapSheetButton(tester, 'Save role');
      final rows = (api.bodyOf('PUT /profile/experience') as Map)['rows'] as List;
      expect(rows, hasLength(2));
      expect(rows[0]['title'], 'Head of Facilities Strategy');
      expect(
        rows[0]['companyId'],
        'co-1',
        reason: 'the linked company page stays linked while the organisation is unchanged',
      );
      expect(rows[0]['employmentType'], 'FULL_TIME');
      expect(rows[0]['industryKeys'], ['real-estate']);
      expect(rows[1]['endYear'], 2018);
      expect(rows[1]['endMonth'], 12);
      expect(rows[1]['description'], 'Built things.');
    });

    testWidgets('changing the organisation unlinks the company page, and a role can be removed', (tester) async {
      final w = MentorWorld(
        experience: [
          {
            'id': 'xp-0',
            'title': 'Head of Facilities',
            'organisation': 'Prestige Group',
            'company': {'id': 'co-1'},
            'industryKeys': <String>[],
            'startYear': 2019,
            'isCurrent': true,
            'sortOrder': 0,
          },
        ],
      );
      final (api, _) = await pumpBecomeMentor(tester, w);
      await tapKey(tester, 'role-0');
      await enter(tester, 'xp-org', 'Brigade Group');
      await tapSheetButton(tester, 'Save role');
      expect(((api.bodyOf('PUT /profile/experience') as Map)['rows'] as List).first.containsKey('companyId'), isFalse);
      await tapKey(tester, 'role-0');
      await tapSheetButton(tester, 'Remove this role');
      expect(api.bodyOf('PUT /profile/experience'), {'rows': <Object?>[]});
      expect(find.text('Add at least one role to your career history to submit.'), findsOneWidget);
    });

    testWidgets('a refusal stays in the sheet with what was typed', (tester) async {
      final w = MentorWorld()
        ..refusals['PUT experience'] = refuse('title must be longer than or equal to 2 characters');
      final (api, _) = await pumpBecomeMentor(tester, w);
      await openCard(tester, 'experience', 'Add a role');
      await fillRole(tester);
      await tapSheetButton(tester, 'Save role');
      expect(find.text('title must be longer than or equal to 2 characters'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('xp-title'))).controller!.text, 'Facility Manager');
      await tapSheetButton(tester, 'Save role');
      expect(api.count('PUT /profile/experience'), 2);
    });
  });

  group('The photo', () {
    final small = PickedFile(bytes: [1, 2, 3], name: 'me.jpg');

    testWidgets('a chosen photo is uploaded and saved as the member\'s photo', (tester) async {
      var picked = 0;
      final (api, _) = await pumpBecomeMentor(
        tester,
        MentorWorld(avatar: null),
        pickPhoto: () async {
          picked++;
          return small;
        },
      );
      await openCard(tester, 'photo', 'Add');
      await tapSheetButton(tester, 'Choose a photo');
      expect(picked, 1);
      expect(api.queryOf('POST /uploads'), {'purpose': 'avatar'});
      expect(api.bodyOf('PATCH /users/me'), {'avatarUrl': '/uploads/abc123.pdf'});
      expect(find.text('Photo saved.'), findsOneWidget);
      expect(find.text('Mentees see this first.'), findsOneWidget);
      expect(find.text('Add a profile photo — it is the first thing a mentee sees.'), findsNothing);
    });

    testWidgets('backing out of the picker sends nothing', (tester) async {
      final (api, _) = await pumpBecomeMentor(tester, MentorWorld(avatar: null), pickPhoto: () async => null);
      await openCard(tester, 'photo', 'Add');
      await tapSheetButton(tester, 'Choose a photo');
      expect(api.count('POST /uploads'), 0);
      expect(api.count('PATCH /users/me'), 0);
    });

    testWidgets('a photo over 5 MB is refused before it is sent', (tester) async {
      final big = PickedFile(bytes: List.filled(5 * 1024 * 1024 + 1, 0), name: 'big.jpg');
      final (api, _) = await pumpBecomeMentor(tester, MentorWorld(avatar: null), pickPhoto: () async => big);
      await openCard(tester, 'photo', 'Add');
      await tapSheetButton(tester, 'Choose a photo');
      expect(find.text('That file is too big. Choose one under 5 MB.'), findsOneWidget);
      expect(api.count('POST /uploads'), 0);
    });

    testWidgets('a photo can be changed and removed (an empty address clears it)', (tester) async {
      final (api, _) = await pumpBecomeMentor(tester, MentorWorld(), pickPhoto: () async => small);
      await openCard(tester, 'photo', 'Change');
      expect(find.text('Change photo'), findsOneWidget);
      await tester.tap(find.text('Remove photo'));
      await settle(tester);
      expect(api.bodyOf('PATCH /users/me'), {'avatarUrl': ''});
      expect(find.text('Add a profile photo — it is the first thing a mentee sees.'), findsOneWidget);
    });

    testWidgets('an upload the API refuses says why', (tester) async {
      final (_, _) = await pumpBecomeMentor(
        tester,
        MentorWorld(avatar: null),
        pickPhoto: () async => small,
        extra: {'POST /uploads': (_) => refuse('image/gif is not an accepted file type for this upload.')},
      );
      await openCard(tester, 'photo', 'Add');
      await tapSheetButton(tester, 'Choose a photo');
      expect(find.text('image/gif is not an accepted file type for this upload.'), findsOneWidget);
    });
  });

  group('The code of conduct', () {
    testWidgets('ticking the box agrees to the current version, creating the draft first when there is none', (
      tester,
    ) async {
      final (api, _) = await pumpBecomeMentor(tester, MentorWorld());
      expect(find.text('I have read and agree to the ICR Mentor Code of Conduct (version 2026.1).'), findsOneWidget);
      expect(find.text('Tick this to send your profile for review.'), findsOneWidget);
      await tapKey(tester, 'conduct-check');
      expect(api.bodyOf('POST /mentorship/mentors/me/code-of-conduct'), {'version': '2026.1'});
      final calls = api.calls;
      expect(
        calls.indexOf('PUT /mentorship/mentors/me'),
        lessThan(calls.indexOf('POST /mentorship/mentors/me/code-of-conduct')),
      );
      expect(find.text('Agreed. Thank you.'), findsOneWidget);
      expect(find.text('Accepted — 2026.1'), findsOneWidget);
      expect(
        tester.widget<CheckboxListTile>(find.byKey(const ValueKey('conduct-check'))).onChanged,
        isNull,
        reason: 'it is agreed once',
      );
      expect(find.text('My mentor profile'), findsOneWidget);
    });

    testWidgets('the whole code can be read, and "I agree" records the same agreement', (tester) async {
      final (api, _) = await pumpBecomeMentor(tester, MentorWorld(withProfile: true));
      await tapKey(tester, 'read-conduct');
      expect(find.text('Mentor code of conduct — version 2026.1'), findsOneWidget);
      expect(find.text('1. I am volunteering'), findsOneWidget);
      expect(find.text('3. I will keep it confidential'), findsOneWidget);
      await tapSheetButton(tester, 'I agree');
      expect(api.count('POST /mentorship/mentors/me/code-of-conduct'), 1);
      expect(find.text('Agreed. Thank you.'), findsOneWidget);
      await tapKey(tester, 'read-conduct');
      expect(find.text('You have agreed to this version.'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('a version that is no longer current is refused, in the API\'s words', (tester) async {
      final w = MentorWorld(withProfile: true)
        ..refusals['conduct'] = refuse('That is not the current code of conduct (2026.2). Reload and read it again.');
      await pumpBecomeMentor(tester, w);
      await tapKey(tester, 'conduct-check');
      expect(find.text('That is not the current code of conduct (2026.2). Reload and read it again.'), findsOneWidget);
      expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('conduct-check'))).value, isFalse);
    });

    testWidgets('the checkbox waits until the code has loaded', (tester) async {
      await pumpBecomeMentor(
        tester,
        MentorWorld(withProfile: true),
        extra: {'GET /mentorship/code-of-conduct': (_) => refuse('Unavailable.', status: 503)},
      );
      expect(find.text('I have read and agree to the ICR Mentor Code of Conduct.'), findsOneWidget);
      expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('conduct-check'))).onChanged, isNull);
      await tapKey(tester, 'read-conduct');
      expect(find.text('Unavailable.'), findsOneWidget);
    });
  });

  group('Submitting', () {
    testWidgets('a complete application is held back only by the agreement, then goes to review', (tester) async {
      final (api, _) = await pumpBecomeMentor(tester, completeWorld());
      expect(find.text('Still needed to submit'), findsNothing);
      expect(
        find.text('1 of 3 steps done'),
        findsOneWidget,
        reason: 'the profile is done; the agreement and the review are not',
      );
      expect(find.text('Agree to the code of conduct to submit.'), findsOneWidget);
      expect(tester.widget<SolidButton>(find.byKey(const ValueKey('submit'))).onPressed, isNull);
      await tapKey(tester, 'conduct-check');
      expect(find.text('2 of 3 steps done'), findsOneWidget);
      expect(tester.widget<SolidButton>(find.byKey(const ValueKey('submit'))).onPressed, isNotNull);
      await tapKey(tester, 'submit');
      expect(api.count('POST /mentorship/mentors/me/submit'), 1);
      expect(
        find.text('Sent to the ICR review team — we will let you know when your profile is live.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('banner-PENDING')), findsOneWidget);
      expect(find.textContaining('A member of the ICR team is reading your profile.'), findsOneWidget);
      expect(find.byKey(const ValueKey('submit')), findsNothing, reason: 'it is with the review team');
      expect(find.text('Awaiting review'), findsOneWidget);
      expect(find.text('ICR review — in progress'), findsOneWidget);
    });

    testWidgets('the API\'s refusal at submit is shown as it words it, and the application stays a draft', (
      tester,
    ) async {
      final w = completeWorld()
        ..refusals['submit'] = refuse('Add your current role. Say a little more about how you mentor.');
      final (api, _) = await pumpBecomeMentor(tester, w);
      await tapKey(tester, 'conduct-check');
      await tapKey(tester, 'submit');
      expect(find.text('Add your current role. Say a little more about how you mentor.'), findsOneWidget);
      expect(find.byKey(const ValueKey('banner-DRAFT')), findsOneWidget);
      expect(tester.widget<SolidButton>(find.byKey(const ValueKey('submit'))).onPressed, isNotNull);
      await tapKey(tester, 'submit');
      expect(api.count('POST /mentorship/mentors/me/submit'), 2);
    });

    testWidgets('saving what the checklist names makes the line go away and the application ready', (tester) async {
      final w = completeWorld()
        ..conductAccepted = true
        ..conductVersion = '2026.1'
        ..profile!['targetAudiences'] = <String>[];
      await pumpBecomeMentor(tester, w);
      expect(find.text('Choose who you want to mentor.'), findsOneWidget);
      expect(tester.widget<SolidButton>(find.byKey(const ValueKey('submit'))).onPressed, isNull);
      await tapText(tester, 'Choose who you want to mentor.');
      await tester.tap(find.byKey(const ValueKey('audience-WORKING_PROFESSIONAL')));
      await tester.pump();
      await tapSheetButton(tester, 'Save');
      expect(find.text('Choose who you want to mentor.'), findsNothing);
      expect(tester.widget<SolidButton>(find.byKey(const ValueKey('submit'))).onPressed, isNotNull);
    });
  });

  group('Where the application stands', () {
    testWidgets('not approved: the reviewer\'s note verbatim, and the way to resubmit', (tester) async {
      final w = completeWorld(status: 'REJECTED')
        ..conductAccepted = true
        ..conductVersion = '2026.1'
        ..profile!['reviewNote'] = 'Please add a recent photo and say more about the sectors you know best.';
      await pumpBecomeMentor(tester, w);
      expect(find.byKey(const ValueKey('banner-REJECTED')), findsOneWidget);
      expect(
        find.textContaining('Please add a recent photo and say more about the sectors you know best.'),
        findsOneWidget,
      );
      expect(find.text('Not approved'), findsWidgets);
      expect(find.text('Resubmit for review'), findsOneWidget);
    });

    testWidgets('not approved with no note says changes were asked for', (tester) async {
      await pumpBecomeMentor(tester, completeWorld(status: 'REJECTED'));
      expect(find.textContaining('The review team asked for changes.'), findsOneWidget);
    });

    testWidgets('listed: no submit, the way to the public profile, and the steps are done', (tester) async {
      final w = completeWorld(status: 'APPROVED')
        ..conductAccepted = true
        ..conductVersion = '2026.1';
      final (_, rec) = await pumpBecomeMentor(tester, w);
      expect(find.byKey(const ValueKey('banner-APPROVED')), findsOneWidget);
      expect(find.textContaining('Members can find you in the directory.'), findsOneWidget);
      expect(find.text('3 of 3 steps done'), findsOneWidget);
      expect(find.text('Listed in the directory'), findsOneWidget);
      expect(find.byKey(const ValueKey('submit')), findsNothing);
      await tapText(tester, 'View public profile');
      expect(rec.opened, ['mentor:mp-kiran']);
    });

    testWidgets('paused by ICR: hidden from the directory, mentorships unaffected', (tester) async {
      final w = completeWorld(status: 'PAUSED')
        ..conductAccepted = true
        ..conductVersion = '2026.1';
      await pumpBecomeMentor(tester, w);
      expect(find.byKey(const ValueKey('banner-PAUSED')), findsOneWidget);
      expect(
        find.textContaining('Your profile is hidden from the directory and is not taking new requests.'),
        findsOneWidget,
      );
      expect(find.text('View public profile'), findsNothing, reason: 'it is not on the directory');
    });

    testWidgets('a listing due for renewal says when it runs out', (tester) async {
      final w = completeWorld(status: 'APPROVED')
        ..conductAccepted = true
        ..conductVersion = '2026.1'
        ..renewalDue = true;
      await pumpBecomeMentor(tester, w);
      expect(find.byKey(const ValueKey('renewal')), findsOneWidget);
      expect(find.textContaining('Your listing is due for renewal.'), findsOneWidget);
      expect(find.textContaining('It expires on 10 Nov.'), findsOneWidget);
    });
  });

  group('Mentor training', () {
    List<Map<String, Object?>> courses() => [
      {
        'courseId': 'c1',
        'code': 'MT-101',
        'title': 'Mentoring basics',
        'slug': 'mentoring-basics',
        'durationLabel': '2 hours',
        'status': 'NOT_ENROLLED',
        'completed': false,
      },
      {
        'courseId': 'c2',
        'code': 'MT-102',
        'title': 'Boundaries and escalation',
        'slug': 'boundaries',
        'durationLabel': null,
        'status': 'CONFIRMED',
        'completed': false,
      },
      {
        'courseId': 'c3',
        'code': 'MT-103',
        'title': 'Giving feedback',
        'slug': 'feedback',
        'durationLabel': null,
        'status': 'COMPLETED',
        'completed': true,
      },
    ];

    testWidgets(
      'what is required, how far along, and a step in the application (the card is hidden when none is required)',
      (tester) async {
        await pumpBecomeMentor(tester, completeWorld()..requiredCourses = courses());
        expect(find.byKey(const ValueKey('card-training')), findsOneWidget);
        expect(find.text('1 of 3 complete'), findsOneWidget);
        expect(find.text('2 hours · Not started'), findsOneWidget);
        expect(find.text('Enrolment confirmed'), findsOneWidget);
        expect(find.text('Complete'), findsOneWidget);
        expect(find.text('Mentor training'), findsWidgets);
        expect(find.text('Finish mentor training (1 of 3 modules).'), findsOneWidget);
        expect(find.text('Enrol'), findsOneWidget);
        expect(find.text('Open'), findsOneWidget);
        expect(find.text('1 of 4 steps done'), findsOneWidget);
      },
    );

    testWidgets(
      'a module opens in the learning centre (a website handoff), and the checklist line goes to the first unfinished one',
      (tester) async {
        final (_, rec) = await pumpBecomeMentor(tester, completeWorld()..requiredCourses = courses());
        await tapText(tester, 'Open');
        expect(rec.sites, ['/learning/professional-development/MT-102']);
        await tapText(tester, 'Enrol');
        expect(rec.sites.last, '/learning/professional-development/MT-101');
        await tapText(tester, 'Finish mentor training (1 of 3 modules).');
        expect(rec.sites.last, '/learning/professional-development/MT-101');
      },
    );

    testWidgets('unfinished training blocks the submit even with the agreement', (tester) async {
      await pumpBecomeMentor(tester, completeWorld()..requiredCourses = courses());
      await tapKey(tester, 'conduct-check');
      expect(tester.widget<SolidButton>(find.byKey(const ValueKey('submit'))).onPressed, isNull);
      expect(find.text('Finish the items above to submit.'), findsOneWidget);
    });

    testWidgets('finished training lets it through', (tester) async {
      final done = [
        for (final c in courses()) {...c, 'completed': true, 'status': 'COMPLETED'},
      ];
      await pumpBecomeMentor(tester, completeWorld()..requiredCourses = done);
      expect(find.text('3 of 3 complete'), findsOneWidget);
      expect(find.text('Enrol'), findsNothing);
      await tapKey(tester, 'conduct-check');
      expect(tester.widget<SolidButton>(find.byKey(const ValueKey('submit'))).onPressed, isNotNull);
    });
  });

  group('Supporting documents', () {
    final pdf = PickedFile(bytes: [37, 80, 68], name: 'cfmp.pdf');
    Map<String, Object?> doc(String id, String status, {String? note, String? label}) => {
      'id': id,
      'kind': 'CERTIFICATION',
      'label': label ?? 'CFMP certificate',
      'fileUrl': '/uploads/$id.pdf',
      'fileName': '$id.pdf',
      'fileSize': 2048,
      'status': status,
      'reviewNote': note,
      'reviewedAt': null,
      'createdAt': '2026-10-20T00:00:00.000Z',
    };

    testWidgets('a file is uploaded as private screening evidence and attached', (tester) async {
      final (api, _) = await pumpBecomeMentor(tester, MentorWorld(withProfile: true), pickDocument: () async => pdf);
      expect(find.text('Nothing attached yet.'), findsOneWidget);
      await openCard(tester, 'documents', 'Add');
      await tapSheetButton(tester, 'Attach');
      expect(find.text('Choose the file to attach.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('kind-EMPLOYMENT_PROOF')));
      await enter(tester, 'doc-label', 'Letter from Prestige');
      await tester.tap(find.byKey(const ValueKey('doc-choose')));
      await tester.pump();
      expect(find.text('cfmp.pdf · 1 KB'), findsOneWidget);
      await tapSheetButton(tester, 'Attach');
      expect(api.queryOf('POST /uploads'), {'purpose': 'mentor-screening'});
      expect(api.bodyOf('POST /mentorship/mentors/me/documents'), {
        'kind': 'EMPLOYMENT_PROOF',
        'fileUrl': '/uploads/abc123.pdf',
        'label': 'Letter from Prestige',
        'fileName': 'upload.pdf',
        'fileSize': 3,
      });
      expect(find.text('Letter from Prestige'), findsOneWidget);
      expect(find.text('Awaiting review'), findsWidgets);
    });

    testWidgets('a file over 10 MB is refused before it is sent', (tester) async {
      final big = PickedFile(bytes: List.filled(10 * 1024 * 1024 + 1, 0), name: 'scan.pdf');
      final (api, _) = await pumpBecomeMentor(tester, MentorWorld(withProfile: true), pickDocument: () async => big);
      await openCard(tester, 'documents', 'Add');
      await tester.tap(find.byKey(const ValueKey('doc-choose')));
      await tester.pump();
      expect(find.text('That file is too big. Choose one under 10 MB.'), findsOneWidget);
      await tapSheetButton(tester, 'Attach');
      expect(api.count('POST /uploads'), 0);
    });

    testWidgets('only a document nobody has reviewed can be taken back; a rejected one carries the reviewer\'s note', (
      tester,
    ) async {
      final w = MentorWorld(withProfile: true)
        ..documents = [
          doc('doc-1', 'PENDING'),
          doc('doc-2', 'REJECTED', note: 'The scan is cut off.', label: 'Reference letter'),
          doc('doc-3', 'VERIFIED', label: 'Employment proof'),
        ];
      final (api, _) = await pumpBecomeMentor(tester, w);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Not accepted'), findsOneWidget);
      expect(find.text('The scan is cut off.'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget, reason: 'only the pending one');
      await tapText(tester, 'Remove');
      expect(api.count('DELETE /mentorship/mentors/me/documents/doc-1'), 1);
      expect(find.text('Removed.'), findsOneWidget);
      expect(find.text('CFMP certificate'), findsNothing);
    });

    testWidgets('twelve documents are the most: Add goes away', (tester) async {
      final w = MentorWorld(withProfile: true)
        ..documents = [for (var i = 0; i < 12; i++) doc('d$i', 'PENDING', label: 'Doc $i')];
      await pumpBecomeMentor(tester, w);
      expect(inCard('documents', 'Add'), findsNothing);
      expect(find.text('Doc 11'), findsOneWidget);
    });

    testWidgets('a refusal from the API stays in the sheet', (tester) async {
      final (api, _) = await pumpBecomeMentor(
        tester,
        MentorWorld(withProfile: true),
        pickDocument: () async => pdf,
        extra: {
          'POST /mentorship/mentors/me/documents': (_) =>
              refuse('That is 12 documents — remove one before adding another.'),
        },
      );
      await openCard(tester, 'documents', 'Add');
      await tester.tap(find.byKey(const ValueKey('doc-choose')));
      await tester.pump();
      await tapSheetButton(tester, 'Attach');
      expect(find.text('That is 12 documents — remove one before adding another.'), findsOneWidget);
      expect(find.text('cfmp.pdf · 1 KB'), findsOneWidget, reason: 'the chosen file stays');
      expect(api.count('POST /uploads'), 1);
    });
  });

  group('Your listing', () {
    testWidgets('"Accepting new requests" is switched on its own', (tester) async {
      final (api, _) = await pumpBecomeMentor(tester, completeWorld());
      expect(find.text('Mentees can find you and ask.'), findsOneWidget);
      await tapKey(tester, 'visibility');
      expect(api.bodyOf('PATCH /mentorship/mentors/me/visibility'), {'discoverable': false});
      expect(find.text('Hidden: you are not taking new requests.'), findsOneWidget);
      expect(find.text('Your profile is hidden. Existing mentorships are unaffected.'), findsOneWidget);
      await tapKey(tester, 'visibility');
      expect(api.bodyOf('PATCH /mentorship/mentors/me/visibility'), {'discoverable': true});
      expect(find.text('You are taking new requests.'), findsOneWidget);
    });

    testWidgets('withdrawing asks first, then the profile is gone and the page starts again', (tester) async {
      final (api, _) = await pumpBecomeMentor(tester, completeWorld());
      await tapText(tester, 'Withdraw my profile');
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Keep it')));
      await tester.pumpAndSettle();
      expect(api.count('DELETE /mentorship/mentors/me'), 0);
      await tapText(tester, 'Withdraw my profile');
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Withdraw')));
      await settle(tester);
      expect(api.count('DELETE /mentorship/mentors/me'), 1);
      expect(find.text('Withdrawn. You can start again any time.'), findsOneWidget);
      expect(find.text('Become a mentor'), findsOneWidget);
      expect(find.byKey(const ValueKey('card-listing')), findsNothing);
      expect(find.text('Not started'), findsOneWidget);
    });

    testWidgets('mentorships under way stop a withdrawal, in the API\'s words, and the profile stays', (tester) async {
      final w = completeWorld()
        ..withdrawRefusal =
            'You have 2 mentorships under way. Complete them before withdrawing your profile — or pause it instead to stop new requests.';
      await pumpBecomeMentor(tester, w);
      await tapText(tester, 'Withdraw my profile');
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Withdraw')));
      await settle(tester);
      expect(find.textContaining('You have 2 mentorships under way.'), findsOneWidget);
      expect(find.text('My mentor profile'), findsOneWidget);
    });
  });
}
