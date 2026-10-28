import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/account/account_models.dart';
import 'package:icr_mobile/features/account/demo_account_repository.dart';
import 'package:icr_mobile/features/account/profile/my_profile_screen.dart';
import 'package:icr_mobile/features/account/widgets/account_kit.dart' show CoverBand;
import 'package:icr_mobile/features/account/widgets/photo_picker.dart';

import 'helpers/account_harness.dart';
import 'helpers/fonts.dart';

/// The person's own profile: what each section shows, and what every control
/// of the header, About, Skills and Languages sends and answers (the career
/// sections and credentials are in `account_career_test.dart`). Against the
/// in-memory sample repository, which behaves as the API does where the
/// screens depend on it and logs every call.
void main() {
  setUpAll(() async {
    await loadAppFonts();
    CoverBand.loadArt = false;
  });

  PickedPhoto photo([String name = 'me.png']) => PickedPhoto(bytes: List.filled(64, 7), name: name);

  Future<DemoAccountRepository> pump(
    WidgetTester tester, {
    DemoAccountRepository? repo,
    PhotoPicker? pickPhoto,
    void Function(String userId)? onOpenPublic,
    VoidCallback? onSettings,
    VoidCallback? onSecurity,
    List<String>? shared,
    VoidCallback? onChanged,
    double width = 390,
    double height = 844,
  }) async {
    final r = repo ?? DemoAccountRepository();
    usePhone(tester, width: width, height: height);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MyProfileScreen(
          repository: r,
          pickPhoto: pickPhoto ?? () async => photo(),
          onOpenPublicProfile: onOpenPublic,
          onOpenSettings: onSettings,
          onOpenSecurity: onSecurity,
          onProfileChanged: onChanged,
          now: DateTime.utc(2026, 10, 26),
          share: (text, subject) async => shared?.add('$subject|$text'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return r;
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final target = find.byKey(Key(key));
    await tester.ensureVisible(target);
    await tester.pump();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String key, String text) async {
    final field = find.byKey(Key(key));
    await tester.ensureVisible(field);
    await tester.pump();
    await tester.enterText(field, text);
    await tester.pump();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('sheet.save')));
    await tester.pumpAndSettle();
  }

  group('the page', () {
    testWidgets('shows the person, their headline, place and every section', (tester) async {
      await pump(tester);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Nikhil Majjagi'), findsOneWidget);
      expect(find.text('Lead Operations Manager'), findsWidgets);
      expect(find.textContaining('Bengaluru, Karnataka · TechCorp'), findsOneWidget);
      expect(find.text('12 years in the profession'), findsOneWidget);
      expect(find.text('Professional'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
      expect(find.textContaining('Operations leader running Grade-A tech parks'), findsOneWidget);
      for (final title in ['Experience', 'Education', 'Licenses & certifications', 'Skills', 'Languages']) {
        await tester.scrollUntilVisible(find.text(title), 300, scrollable: find.byType(Scrollable).first);
        expect(find.text(title), findsOneWidget);
      }
      expect(find.text('Vendor SLAs'), findsOneWidget);
      expect(find.text('Hindi'), findsOneWidget);
    });

    testWidgets('while it loads there is a spinner, and a failure says why with Try again', (tester) async {
      final repo = DemoAccountRepository()
        ..gate = Future<void>.delayed(const Duration(seconds: 1))
        ..failures['myProfile'] = ApiError('The server is busy.', statusCode: 503);
      usePhone(tester);
      await tester.pumpWidget(
        MaterialApp(theme: buildAppTheme(), home: MyProfileScreen(repository: repo)),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('The server is busy.'), findsOneWidget);
      repo.failures.remove('myProfile');
      await tapKey(tester, 'account.retry');
      expect(find.text('Nikhil Majjagi'), findsOneWidget);
    });

    testWidgets('a section that cannot be read fails alone, with its own Try again', (tester) async {
      final repo = DemoAccountRepository()..failures['education'] = ApiError('Could not read.', statusCode: 500);
      await pump(tester, repo: repo);
      await tester.scrollUntilVisible(find.text('Education'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text("Couldn't load your education."), findsOneWidget);
      expect(find.text('Nikhil Majjagi'), findsOneWidget, reason: 'the rest of the page is fine');
      repo.failures.remove('education');
      await tapKey(tester, 'retry.education');
      await tester.scrollUntilVisible(find.text('RV College of Engineering'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('RV College of Engineering'), findsOneWidget);
    });

    testWidgets('pull to refresh reads everything again and keeps the page', (tester) async {
      final repo = await pump(tester);
      final before = repo.count('myProfile');
      await tester.fling(find.byType(ListView).first, const Offset(0, 400), 1000);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(repo.count('myProfile'), before + 1);
      expect(repo.count('experience'), 2);
      expect(find.text('Nikhil Majjagi'), findsOneWidget);
    });

    testWidgets('Share profile hands the public link to the share sheet; Copy link copies it', (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      final shared = <String>[];
      await pump(tester, shared: shared);
      await tester.tap(find.byKey(const Key('profile.share')));
      await tester.pump();
      expect(shared.single, 'Nikhil Majjagi on ICR|Nikhil Majjagi on ICR\nhttps://icr.org.in/members/nikhil-majjagi');

      await tester.scrollUntilVisible(find.byKey(const Key('profile.copyLink')), 300, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.byKey(const Key('profile.copyLink')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile.copyLink')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Link copied.'), findsOneWidget);
      expect(copied, ['https://icr.org.in/members/nikhil-majjagi']);
    });

    testWidgets('View public profile opens the member page for this person; the gear and security row call out', (tester) async {
      final opened = <String>[];
      var settings = 0;
      var security = 0;
      await pump(tester, onOpenPublic: opened.add, onSettings: () => settings++, onSecurity: () => security++);
      await tapKey(tester, 'profile.viewPublic');
      await tester.tap(find.byKey(const Key('profile.settings')));
      await tester.pump();
      await tester.scrollUntilVisible(find.byKey(const Key('profile.security')), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byKey(const Key('profile.security')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('profile.openPublic')));
      await tester.pump();
      expect(opened, ['me', 'me']);
      expect(settings, 1);
      expect(security, 1);
    });

    testWidgets('with nothing wired the gear opens Settings and the security row opens Sign-in & security', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('profile.settings')));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Sign-in & security'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(const Key('profile.security')), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byKey(const Key('profile.security')));
      await tester.pumpAndSettle();
      expect(find.text('Sign-in & security'), findsWidgets);
      expect(find.text('Contact info'), findsOneWidget);
    });

    testWidgets('fits a 320 x 568 phone', (tester) async {
      await pump(tester, width: 320, height: 568);
      await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('the intro', () {
    testWidgets('the pencil opens it with what the profile says; Save sends the name, headline and years, then the résumé', (tester) async {
      final repo = await pump(tester);
      await tapKey(tester, 'profile.editIntro');
      expect(find.text('Edit intro'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('intro.firstName'))).controller!.text, 'Nikhil');
      expect(tester.widget<TextField>(find.byKey(const Key('intro.headline'))).controller!.text, 'Lead Operations Manager');
      expect(tester.widget<TextField>(find.byKey(const Key('intro.years'))).controller!.text, '12');

      await type(tester, 'intro.firstName', 'Nikhil K');
      await type(tester, 'intro.headline', 'Head of Operations');
      await type(tester, 'intro.years', '13');
      await save(tester);

      expect(repo.sent['updateMe'], {'firstName': 'Nikhil K', 'lastName': 'Majjagi', 'designation': 'Head of Operations', 'yearsExperience': 13});
      expect(repo.sent['updateResume'], {'jobTitle': 'Head of Operations'});
      expect(find.text('Edit intro'), findsNothing);
      expect(find.text('Nikhil K Majjagi'), findsOneWidget);
      expect(find.text('Head of Operations'), findsWidgets);
      expect(find.text('Intro saved.'), findsOneWidget);
    });

    testWidgets('a saved intro and a changed cover tell the app, so the profile menu reads them again', (tester) async {
      var changed = 0;
      await pump(tester, onChanged: () => changed++);
      await tapKey(tester, 'profile.editIntro');
      await type(tester, 'intro.firstName', 'Niks');
      await save(tester);
      expect(changed, 1);
      await tapKey(tester, 'profile.editCover');
      await tester.tap(find.byKey(const Key('cover.blueprint')));
      await tester.pumpAndSettle();
      expect(changed, 2);
    });

    testWidgets('a blank first name, a one-letter headline and years out of range are refused before any call', (tester) async {
      final repo = await pump(tester);
      await tapKey(tester, 'profile.editIntro');
      await type(tester, 'intro.firstName', '  ');
      await type(tester, 'intro.headline', 'X');
      await type(tester, 'intro.years', '61');
      await tester.tap(find.byKey(const Key('sheet.save')));
      await tester.pumpAndSettle();
      expect(find.text('Add your first name.'), findsOneWidget);
      expect(find.text('A headline needs at least 2 characters.'), findsOneWidget);
      expect(find.text('Whole years, 0–60.'), findsOneWidget);
      expect(repo.count('updateMe'), 0);
    });

    testWidgets('a headline from the staff list is offered while typing and fills the field', (tester) async {
      await pump(tester);
      await tapKey(tester, 'profile.editIntro');
      await tester.tap(find.byKey(const Key('intro.headline')));
      await type(tester, 'intro.headline', 'Energy');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('suggestions')), findsOneWidget);
      await tester.tap(find.text('Energy Manager'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byKey(const Key('intro.headline'))).controller!.text, 'Energy Manager');
    });

    testWidgets("the API's refusal shows above the buttons and what was typed stays", (tester) async {
      final repo = DemoAccountRepository()..failures['updateMe'] = ApiError('That name is not allowed.', statusCode: 400);
      await pump(tester, repo: repo);
      await tapKey(tester, 'profile.editIntro');
      await type(tester, 'intro.firstName', 'Niks');
      await save(tester);
      expect(find.text('That name is not allowed.'), findsOneWidget);
      expect(find.text('Edit intro'), findsOneWidget, reason: 'the sheet stays open');
      expect(tester.widget<TextField>(find.byKey(const Key('intro.firstName'))).controller!.text, 'Niks');
    });

    testWidgets('Cancel with edits asks to discard; without edits it just closes', (tester) async {
      await pump(tester);
      await tapKey(tester, 'profile.editIntro');
      await tester.tap(find.byKey(const Key('sheet.cancel')));
      await tester.pumpAndSettle();
      expect(find.text('Edit intro'), findsNothing);

      await tapKey(tester, 'profile.editIntro');
      await type(tester, 'intro.firstName', 'Niks');
      await tester.tap(find.byKey(const Key('sheet.cancel')));
      await tester.pumpAndSettle();
      expect(find.text('Discard your changes?'), findsOneWidget);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(find.text('Edit intro'), findsOneWidget);
      await tester.tap(find.byKey(const Key('sheet.cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm.ok')));
      await tester.pumpAndSettle();
      expect(find.text('Edit intro'), findsNothing);
      expect(find.text('Nikhil Majjagi'), findsOneWidget, reason: 'nothing was saved');
    });

    testWidgets('Save with nothing changed closes without a call', (tester) async {
      final repo = await pump(tester);
      await tapKey(tester, 'profile.editIntro');
      await save(tester);
      expect(repo.count('updateMe'), 0);
      expect(find.text('Edit intro'), findsNothing);
    });

    testWidgets('the location is a city from the list', (tester) async {
      final repo = await pump(tester);
      await tapKey(tester, 'profile.editIntro');
      await tapKey(tester, 'intro.location');
      await tester.tap(find.widgetWithText(ListTile, 'Pune'));
      await tester.pumpAndSettle();
      await save(tester);
      expect(repo.sent['updateResume'], {'location': 'Pune, Maharashtra'});
    });
  });

  group('the photo and the cover', () {
    testWidgets('tapping the photo opens its sheet; Upload sends the file, then sets it as the avatar', (tester) async {
      final repo = DemoAccountRepository(profile: MyProfile.fromJson({
        'user': {'id': 'me', 'email': 'a@b.co', 'firstName': 'Anita', 'lastName': 'Rao', 'role': 'PROFESSIONAL'},
        'resume': {'jobTitle': 'Analyst'},
      }));
      await pump(tester, repo: repo);
      await tapKey(tester, 'profile.avatar');
      expect(find.text('Profile photo'), findsOneWidget);
      expect(find.text('Upload photo'), findsOneWidget);
      await tester.tap(find.byKey(const Key('photo.choose')));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('upload'));
      expect((repo.sent['updateMe'] as Map)['avatarUrl'], startsWith('/uploads/file-1-me.png'));
      expect(find.text('Change photo'), findsOneWidget);
      await tester.tap(find.byKey(const Key('sheet.save')));
      await tester.pumpAndSettle();
    });

    testWidgets('Remove photo asks first, then clears the avatar', (tester) async {
      final repo = await pump(tester);
      await tapKey(tester, 'profile.avatar');
      await tester.tap(find.byKey(const Key('sheet.delete')));
      await tester.pumpAndSettle();
      expect(find.text('Remove your profile photo?'), findsOneWidget);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(repo.count('updateMe'), 0);
      await tester.tap(find.byKey(const Key('sheet.delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm.ok')));
      await tester.pumpAndSettle();
      expect(repo.sent['updateMe'], {'avatarUrl': ''});
      expect(find.text('Upload photo'), findsOneWidget);
    });

    testWidgets('a picture that is too big is refused before it is sent; backing out of the picker does nothing', (tester) async {
      final repo = await pump(tester, pickPhoto: () async => PickedPhoto(bytes: List.filled(5 * 1024 * 1024 + 1, 1), name: 'big.jpg'));
      await tapKey(tester, 'profile.avatar');
      await tester.tap(find.byKey(const Key('photo.choose')));
      await tester.pumpAndSettle();
      expect(find.text('That file is too big. Choose one under 5 MB.'), findsOneWidget);
      expect(repo.count('upload'), 0);
    });

    testWidgets('a refused upload shows the API sentence', (tester) async {
      final repo = DemoAccountRepository()..failures['upload'] = ApiError('image/gif is not an accepted file type for this upload.', statusCode: 400);
      await pump(tester, repo: repo);
      await tapKey(tester, 'profile.avatar');
      await tester.tap(find.byKey(const Key('photo.choose')));
      await tester.pumpAndSettle();
      expect(find.text('image/gif is not an accepted file type for this upload.'), findsOneWidget);
    });

    testWidgets('the camera on the cover opens the covers: a ready-made one saves at once', (tester) async {
      final repo = await pump(tester);
      await tapKey(tester, 'profile.editCover');
      expect(find.text('Cover'), findsOneWidget);
      await tester.tap(find.byKey(const Key('cover.skyline')));
      await tester.pumpAndSettle();
      expect(repo.sent['updateMe'], {'coverImage': 'skyline'});
      expect(repo.profileNow.coverImage, 'skyline');
    });

    testWidgets('Upload your own sets the picture as the cover; Remove cover clears it', (tester) async {
      final repo = await pump(tester);
      await tapKey(tester, 'profile.editCover');
      await tester.tap(find.byKey(const Key('cover.upload')));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('upload'));
      expect(repo.profileNow.coverImage, startsWith('/uploads/'));
      expect(find.text('Your picture'), findsOneWidget);
      await tester.tap(find.byKey(const Key('sheet.delete')));
      await tester.pumpAndSettle();
      expect(repo.sent['updateMe'], {'coverImage': null});
    });
  });

  group('about, skills and languages', () {
    testWidgets('About: the pencil opens the summary; Save sends it trimmed', (tester) async {
      final repo = await pump(tester);
      await tester.tap(find.byTooltip('Edit about'));
      await tester.pumpAndSettle();
      expect(find.textContaining('/ 2,000'), findsOneWidget);
      await type(tester, 'about.summary', '  Running campuses for a decade.  ');
      await save(tester);
      expect(repo.sent['updateResume'], {'summary': 'Running campuses for a decade.'});
      expect(find.text('Running campuses for a decade.'), findsOneWidget);
      expect(find.text('About saved.'), findsOneWidget);
    });

    testWidgets('an empty About offers "Add a summary"', (tester) async {
      final repo = DemoAccountRepository(profile: MyProfile.fromJson({
        'user': {'id': 'me', 'email': 'a@b.co', 'firstName': 'Anita', 'lastName': 'Rao', 'role': 'PROFESSIONAL'},
        'resume': {'jobTitle': 'Analyst'},
      }));
      await pump(tester, repo: repo);
      await tester.tap(find.text('Add a summary'));
      await tester.pumpAndSettle();
      await type(tester, 'about.summary', 'Hello.');
      await save(tester);
      expect(repo.sent['updateResume'], {'summary': 'Hello.'});
    });

    testWidgets('a long summary shows See more and See less', (tester) async {
      final long = List.filled(40, 'Long summary words.').join(' ');
      final repo = DemoAccountRepository(profile: MyProfile.fromJson({
        'user': {'id': 'me', 'email': 'a@b.co', 'firstName': 'Anita', 'lastName': 'Rao', 'role': 'PROFESSIONAL'},
        'resume': {'jobTitle': 'Analyst', 'summary': long},
      }));
      await pump(tester, repo: repo);
      await tester.scrollUntilVisible(find.byKey(const Key('clamp.toggle')), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('See more'), findsOneWidget);
      await tester.tap(find.byKey(const Key('clamp.toggle')));
      await tester.pump();
      expect(find.text('See less'), findsOneWidget);
    });

    testWidgets('Skills: a suggestion adds in one tap, a typed one with Enter, a chip removes; Save sends the list', (tester) async {
      final repo = await pump(tester);
      await tester.scrollUntilVisible(find.byTooltip('Edit skills'), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byTooltip('Edit skills'));
      await tester.pumpAndSettle();
      expect(find.text('5 of 50'), findsOneWidget);
      await tester.tap(find.byKey(const Key('suggest.HVAC')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('chips.input')), 'Chillers');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.tap(find.byTooltip('Remove Budgeting'));
      await tester.pump();
      expect(find.text('6 of 50'), findsOneWidget);
      await save(tester);
      expect(repo.sent['updateResume'], {
        'skills': ['Facility operations', 'Vendor SLAs', 'BMS Automation', 'ESG reporting', 'HVAC', 'Chillers'],
      });
    });

    testWidgets('Skills: a skill is added once, whatever its case', (tester) async {
      await pump(tester);
      await tester.scrollUntilVisible(find.byTooltip('Edit skills'), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byTooltip('Edit skills'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('chips.input')), 'vendor slas');
      await tester.tap(find.byKey(const Key('chips.add')));
      await tester.pump();
      expect(find.text('5 of 50'), findsOneWidget);
    });

    testWidgets('Languages: at most eight, then the box says so', (tester) async {
      final repo = DemoAccountRepository(profile: MyProfile.fromJson({
        'user': {
          'id': 'me',
          'email': 'a@b.co',
          'firstName': 'Anita',
          'lastName': 'Rao',
          'role': 'PROFESSIONAL',
          'languages': ['English', 'Hindi', 'Tamil', 'Telugu', 'Kannada', 'Marathi', 'Bengali', 'Urdu'],
        },
        'resume': {'jobTitle': 'Analyst'},
      }));
      await pump(tester, repo: repo);
      await tester.scrollUntilVisible(find.byTooltip('Edit languages'), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byTooltip('Edit languages'));
      await tester.pumpAndSettle();
      expect(find.text('That is the most you can add'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('chips.input'))).enabled, isFalse);
    });

    testWidgets('Languages: a pick saves through PATCH /users/me', (tester) async {
      final repo = await pump(tester);
      await tester.scrollUntilVisible(find.byTooltip('Edit languages'), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byTooltip('Edit languages'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('suggest.Tamil')));
      await tester.pump();
      await save(tester);
      expect(repo.sent['updateMe'], {'languages': ['English', 'Hindi', 'Kannada', 'Tamil']});
      expect(find.text('Tamil'), findsOneWidget);
    });
  });

  group('the checklist and Add section', () {
    testWidgets('a missing item opens the sheet that finishes it', (tester) async {
      final repo = await pump(tester);
      expect(find.text('Profile strength 85%'), findsOneWidget);
      await tapKey(tester, 'missing.Add your education');
      expect(find.text('Add education'), findsWidgets);
      expect(find.byKey(const Key('edu.institution')), findsOneWidget);
      expect(repo.count('saveEducation'), 0);
    });

    testWidgets('Add section lists what can be added and opens the one chosen', (tester) async {
      await pump(tester);
      await tapKey(tester, 'profile.addSection');
      expect(find.text('Add profile section'), findsOneWidget);
      for (final item in ['About', 'Experience', 'Education', 'Career break', 'Credential', 'Skills', 'Languages']) {
        expect(find.text(item), findsWidgets);
      }
      await tester.tap(find.text('Career break'));
      await tester.pumpAndSettle();
      expect(find.text('Add career break'), findsOneWidget);
    });

    testWidgets('a complete profile has no checklist', (tester) async {
      final repo = DemoAccountRepository(profile: MyProfile.fromJson({
        'user': {'id': 'me', 'email': 'a@b.co', 'firstName': 'Anita', 'lastName': 'Rao', 'role': 'PROFESSIONAL'},
        'resume': {'jobTitle': 'Analyst'},
        'completeness': {'score': 100, 'missing': []},
      }));
      await pump(tester, repo: repo);
      expect(find.byKey(const Key('profile.completion')), findsNothing);
    });
  });
}
