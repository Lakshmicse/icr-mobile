import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_colors.dart';
import 'package:icr_mobile/features/learning_exam/exam_widgets.dart' show ExamCard;
import 'package:icr_mobile/features/mentorship_my/widgets/kit.dart';

/// The owner's rule, restated 5 Nov 2026: no borders on content. A card is a row set off by a 1 px hairline or a
/// tinted block, never an outlined box. These pin the shared pieces the mentoring and exam screens are built from.
void main() {
  /// Every border a widget under [of] draws: a decoration's, or a Material shape's. A [Divider] is the hairline
  /// itself (it draws as a one-sided border), so it is left out.
  List<BorderSide> sidesUnder(WidgetTester tester, Finder of) {
    final sides = <BorderSide>[];
    final rules = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.descendant(of: of, matching: find.byType(Divider)),
            matching: find.byType(DecoratedBox),
          ),
        )
        .toSet();
    for (final box in tester.widgetList<DecoratedBox>(find.descendant(of: of, matching: find.byType(DecoratedBox)))) {
      if (rules.contains(box)) continue;
      final d = box.decoration;
      if (d is BoxDecoration && d.border is Border) {
        final b = d.border! as Border;
        sides.addAll([b.top, b.right, b.bottom, b.left].where((s) => s.style != BorderStyle.none && s.width > 0));
      }
    }
    for (final m in tester.widgetList<Material>(find.descendant(of: of, matching: find.byType(Material)))) {
      final shape = m.shape;
      if (shape is OutlinedBorder && shape.side.style != BorderStyle.none && shape.side.width > 0) {
        sides.add(shape.side);
      }
    }
    return sides;
  }

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));

  testWidgets('a mentoring card is a row closed by one hairline, with no outline', (tester) async {
    await pump(tester, const MentoringCard(child: Text('Session with Anand')));
    expect(find.text('Session with Anand'), findsOneWidget);
    expect(sidesUnder(tester, find.byType(MentoringCard)), isEmpty);
    final rule = tester.widget<Divider>(
      find.descendant(of: find.byType(MentoringCard), matching: find.byType(Divider)),
    );
    expect(rule.height, 1);
    expect(rule.thickness, 1);
    // It sits on the page's own margin: the card's text is not indented by a box.
    expect(tester.getTopLeft(find.text('Session with Anand')).dx, 0);
  });

  testWidgets('a card that asks for attention is a pale amber block, not an amber outline', (tester) async {
    await pump(tester, const MentoringCard(tint: AppColors.amber50, child: Text('Overdue')));
    expect(sidesUnder(tester, find.byType(MentoringCard)), isEmpty);
    final tinted = tester.widgetList<Material>(
      find.descendant(of: find.byType(MentoringCard), matching: find.byType(Material)),
    );
    expect(tinted.any((m) => m.color == AppColors.amber50), isTrue);
    expect(
      find.descendant(of: find.byType(MentoringCard), matching: find.byType(Divider)),
      findsNothing,
      reason: 'a tinted block is set off by its tint, not a hairline',
    );
  });

  testWidgets('a stat tile is plain figures: no outline and no fill (owner, 6 Nov 2026)', (tester) async {
    await pump(
      tester,
      const Row(
        children: [StatTile(value: '3', label: 'Active')],
      ),
    );
    expect(sidesUnder(tester, find.byType(StatTile)), isEmpty);
    final boxes = tester.widgetList<Container>(
      find.descendant(of: find.byType(StatTile), matching: find.byType(Container)),
    );
    expect(boxes.where((b) => b.decoration != null || b.color != null), isEmpty, reason: 'no fill behind a figure');
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
  });

  testWidgets('an exam card and a result tile are tinted with no outline', (tester) async {
    await pump(tester, const ExamCard(child: Text('Verification')));
    expect(sidesUnder(tester, find.byType(ExamCard)), isEmpty);
    final card = tester.widget<Material>(
      find.descendant(of: find.byType(ExamCard), matching: find.byType(Material)).first,
    );
    expect(card.color, AppColors.surfaceContainer);
  });
}
