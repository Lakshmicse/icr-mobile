import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/mentorship/mentorship_models.dart';
import 'package:icr_mobile/features/mentorship/widgets/mentor_card.dart';

import 'helpers/fonts.dart';

/// A mentor's card messages them from its Message button and opens their profile anywhere else (owner, 12 Nov
/// 2026: "connect to message them and click on the other space it will goes to profile").
void main() {
  setUpAll(loadAppFonts);

  const rajesh = Mentor(
    id: 'mp1',
    userId: 'u-rajesh',
    name: 'Rajesh Menon',
    headline: 'Head of Facilities',
    expertise: ['HVAC', 'Vendor management'],
  );
  const noAccount = Mentor(id: 'mp2', name: 'Asha Rao', headline: 'Workplace lead');
  const me = Mentor(id: 'mp3', userId: 'u-me', name: 'Pooja Professional', headline: 'Facility manager');

  Future<({List<String> opened, List<String> messaged})> pumpRow(
    WidgetTester tester,
    Mentor left,
    Mentor? right,
  ) async {
    tester.view.physicalSize = const Size(780, 900);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final opened = <String>[];
    final messaged = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.topCenter,
              child: MentorRow(
                left: left,
                right: right,
                onOpen: (m) => opened.add(m.id),
                onMessage: (m) => messaged.add(m.userId!),
                viewerId: 'u-me',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return (opened: opened, messaged: messaged);
  }

  testWidgets('Message opens a conversation with the mentor; the rest of the card opens the profile', (tester) async {
    final log = await pumpRow(tester, rajesh, null);
    final button = find.byKey(const ValueKey('mentor-card-message'));
    expect(button, findsOneWidget);
    expect(find.text('Message'), findsOneWidget);

    await tester.tap(button);
    await tester.pump();
    expect(log.messaged, ['u-rajesh']);
    expect(log.opened, isEmpty, reason: 'the button messages; it does not open the profile');

    await tester.tap(find.text('Rajesh Menon'));
    await tester.pump();
    expect(log.opened, ['mp1']);
    expect(log.messaged, ['u-rajesh']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no button for a mentor with no account to reach, nor on the viewer\'s own card', (tester) async {
    await pumpRow(tester, noAccount, me);
    expect(find.byKey(const ValueKey('mentor-card-message')), findsNothing);
  });

  testWidgets('both cards of a row keep their buttons at the foot, level, whatever their text', (tester) async {
    const long = Mentor(
      id: 'mp4',
      userId: 'u-long',
      name: 'Venkatesh Subramanian',
      headline: 'Director of Integrated Facility Management, Asia Pacific region',
      expertise: ['Integrated FM', 'Energy', 'Procurement'],
    );
    await pumpRow(tester, rajesh, long);
    final buttons = find.byKey(const ValueKey('mentor-card-message'));
    expect(buttons, findsNWidgets(2));
    expect(tester.getRect(buttons.at(0)).bottom, tester.getRect(buttons.at(1)).bottom);
    expect(tester.takeException(), isNull);
  });
}
