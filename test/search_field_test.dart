import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/core/widgets/search_field.dart';

import 'helpers/fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('typed text sits in the middle of the box, as the hint does', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: IcrSearchField(controller: controller, height: 40, onSubmitted: (_) {}),
            ),
          ),
        ),
      ),
    );
    final box = tester.getRect(find.byType(IcrSearchField));
    final hint = tester.getRect(find.text('Search jobs, courses, partners...'));
    expect((hint.center.dy - box.center.dy).abs(), lessThan(1.5));

    controller.text = 'Srikanth';
    await tester.pump();
    final typed = tester.getRect(find.byType(EditableText));
    expect(find.text('Srikanth'), findsOneWidget);
    // The clear button is on show, and the text has not moved up to make room for it.
    expect((typed.center.dy - box.center.dy).abs(), lessThan(1.5));
  });
}
