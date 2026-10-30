import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/core/widgets/detail_sheet.dart';
import 'package:icr_mobile/features/events/demo_events_repository.dart';
import 'package:icr_mobile/features/events/event_detail_controller.dart';
import 'package:icr_mobile/features/events/event_models.dart';
import 'package:icr_mobile/features/events/event_sheet.dart';
import 'package:icr_mobile/features/events/events_controller.dart';
import 'package:icr_mobile/features/events/events_screen.dart';
import 'package:icr_mobile/features/events/widgets/event_card.dart';
import 'package:icr_mobile/features/events/widgets/pills.dart';
import 'package:icr_mobile/features/feed/demo_feed_repository.dart';
import 'package:provider/provider.dart';

import 'helpers/fonts.dart';
import 'helpers/layout_audit.dart';

/// A design's fixed heights were drawn for text under the app's 12 sp floor (27 Oct 2026), so a one-line box
/// 13 to 15 dp tall cut the bottom off its label (a descender in "Hybrid" read "Hvbrid"), and the footer of a
/// half-width card no longer fitted one line. Both the common 390 dp phone and a narrow 360 dp one.
void main() {
  // The demo's events are dated Oct 24, 2026: pin the clock to the week before, or each turns into "Ended" the
  // day that date passes (the goldens do the same).
  final realNow = eventsNow;
  setUpAll(() async {
    eventsNow = () => DateTime(2026, 10, 20, 9);
    await loadAppFonts();
  });
  tearDownAll(() => eventsNow = realNow);

  /// Tall enough to build every row of the board or the sheet, so the whole screen is looked over.
  void sizeView(WidgetTester tester, {required double width, required double height}) {
    tester.view.physicalSize = Size(width * 2, height * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpBoard(WidgetTester tester, {required double width}) async {
    sizeView(tester, width: width, height: 3600);
    final events = EventsController(DemoEventsRepository());
    await tester.runAsync(events.start);
    addTearDown(events.dispose);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: ChangeNotifierProvider.value(
          value: events,
          child: EventsScreen(onBack: () {}, viewer: DemoFeedRepository.me, onAccount: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpSheet(WidgetTester tester, {required double width}) async {
    sizeView(tester, width: width, height: 2000);
    final repo = DemoEventsRepository();
    final controller = EventDetailController(repository: repo, seed: repo.sheetEvent);
    await tester.runAsync(controller.load);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: ChangeNotifierProvider<EventsController>(
          create: (_) => EventsController(repo),
          child: ChangeNotifierProvider.value(
            value: controller,
            child: const Scaffold(
              backgroundColor: Colors.white,
              body: DetailSheetFrame(
                topInset: 0,
                handleTop: 10,
                handleHeight: 24,
                body: EventSheetBody(),
                bottomBar: EventSheetBar(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// What the sweep calls clipped: a label in a box shorter than its own lines.
  List<String> clipped() => layoutProblems().where((p) => p.startsWith('clipped')).toList();

  for (final width in [390.0, 360.0]) {
    group('at ${width.toInt()} dp', () {
      testWidgets('no text on the Events board is cut off by its box', (tester) async {
        await pumpBoard(tester, width: width);
        // The flagship's venue and accreditation line, and the two tiles' titles, are on the board.
        expect(find.text('Mumbai Convention Centre & Hybrid'), findsOneWidget);
        expect(find.text('My Schedule (2)'), findsOneWidget);
        expect(find.text('CPD Earned'), findsOneWidget);
        expect(clipped(), isEmpty);
        expect(tester.takeException(), isNull);
      });

      testWidgets('no text on the event sheet is cut off by its box', (tester) async {
        await pumpSheet(tester, width: width);
        // The sections the sweep found short: About and Overview, the pass pill, the agenda, the status line.
        expect(find.text('About'), findsOneWidget);
        expect(find.text('Active Pass'), findsOneWidget);
        expect(find.text('SUMMIT AGENDA'), findsOneWidget);
        expect(find.text('Your Booking is Active'), findsOneWidget);
        expect(clipped(), isEmpty);
        expect(tester.takeException(), isNull);
      });

      testWidgets('a card\'s button, share and bookmark share one line', (tester) async {
        await pumpBoard(tester, width: width);
        // "Register Free" is the card with all three; the glyphs used to wrap below the button when they no
        // longer fitted beside it.
        final card = find.byWidgetPredicate((w) => w is EventCard && w.event.id == 'ai-in-fm');
        expect(card, findsOneWidget);
        final button = find.descendant(of: card, matching: find.text('Register Free'));
        final glyphs = find.descendant(of: card, matching: find.byType(GlyphButton));
        expect(button, findsOneWidget);
        expect(glyphs, findsNWidgets(2));
        final line = tester.getCenter(button).dy;
        for (final glyph in glyphs.evaluate()) {
          expect(tester.getCenter(find.byWidget(glyph.widget)).dy, closeTo(line, 1));
        }
        // And the whole footer is inside the card, with no word of the button cut off by another glyph.
        final cardBox = tester.getRect(card);
        for (final glyph in glyphs.evaluate()) {
          expect(cardBox.contains(tester.getCenter(find.byWidget(glyph.widget))), isTrue);
        }
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('a count of attendees stays on one line in a pill wide enough for it', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: Center(
            child: AvatarStack(
              avatars: [EventAvatar('MK', AvatarTone.blue), EventAvatar('+1.4k', AvatarTone.count)],
              size: 29.5,
              step: 20,
            ),
          ),
        ),
      ),
    );
    final text = tester.renderObject<RenderParagraph>(find.text('+1.4k'));
    expect(text.size.height, lessThan(20), reason: 'one line, not two');
    expect(layoutProblems().where((p) => p.startsWith('clipped')), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
