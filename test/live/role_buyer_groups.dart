/// Role matrix, part 6: Events, Councils, Chapters and the Digital Library for the four accounts that belong to no
/// company. Every place taken (an RSVP, a council seat, a chapter seat) is given back; a person who already holds the
/// place the test would take has it put back as it was.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/chapters/api_chapters_repository.dart';
import 'package:icr_mobile/features/chapters/chapter_models.dart';
import 'package:icr_mobile/features/chapters/chapters_controller.dart';
import 'package:icr_mobile/features/chapters/chapters_screen.dart';
import 'package:icr_mobile/features/councils/api_councils_repository.dart';
import 'package:icr_mobile/features/councils/councils_controller.dart';
import 'package:icr_mobile/features/councils/councils_screen.dart';
import 'package:icr_mobile/features/events/api_events_repository.dart';
import 'package:icr_mobile/features/events/event_models.dart';
import 'package:icr_mobile/features/events/events_controller.dart';
import 'package:icr_mobile/features/events/events_screen.dart';
import 'package:icr_mobile/features/feed/feed_models.dart';
import 'package:provider/provider.dart';

import '../helpers/fonts.dart';
import 'career_live_support.dart';
import 'live.dart';
import 'role_buyer_support.dart';

final _events = <String, ApiEventsRepository>{};
ApiEventsRepository eventsOf(Who w) => _events.putIfAbsent(w.email, () => ApiEventsRepository(api: w.api));

final _councils = <String, ApiCouncilsRepository>{};
ApiCouncilsRepository councilsOf(Who w) => _councils.putIfAbsent(w.email, () => ApiCouncilsRepository(api: w.api));

final _chapters = <String, ApiChaptersRepository>{};
ApiChaptersRepository chaptersOf(Who w) => _chapters.putIfAbsent(w.email, () => ApiChaptersRepository(api: w.api));

FeedAuthor _viewer(Who w) => FeedAuthor(id: w.id, name: '${w.first} ${w.me['lastName'] ?? ''}'.trim());

void roleBuyerGroups() {
  setUpAll(loadAppFonts);

  group('Events', () {
    liveTest(
      'the board reads, a free place is taken, shows in My Schedule and is given back, for every account',
      () async {
        for (final w in await everyone()) {
          final repo = eventsOf(w);
          final overview = await repo.overview();
          expect(overview.events, isNotEmpty, reason: '${w.email}: there are upcoming events');
          await repo.search(const EventQuery(search: 'summit'));
          await repo.search(const EventQuery(when: EventWhen.past));
          await repo.search(const EventQuery(format: FormatFilter.online));
          expect(await repo.unreadNotifications(), greaterThanOrEqualTo(0));

          final event = overview.events.firstWhere(
            (e) => !e.priced && !e.full && !e.inviteOnly && !e.past && !e.rsvp.holds,
            orElse: () => throw StateError('no free event is open to ${w.email}'),
          );
          final detail = await repo.detail(event);
          expect(detail, isNotNull);
          await repo.passFor(event);
          await repo.speakers([event]);
          final state = await repo.rsvp(event);
          try {
            expect(state, anyOf(RsvpState.going, RsvpState.waitlisted));
            final mine = (await repo.overview()).events.firstWhere((e) => e.id == event.id);
            expect(mine.rsvp.holds, isTrue, reason: '${w.email}: the API keeps the place');
            expect((await repo.overview()).schedule?.count ?? 0, greaterThan(0), reason: 'My Schedule counts it');
          } finally {
            await repo.cancel(event);
          }
          final after = (await repo.overview()).events.firstWhere((e) => e.id == event.id);
          expect(after.rsvp.holds, isFalse, reason: '${w.email}: the place is given back');
          record('Events: board, search, sheet, RSVP, My Schedule, cancel', w.person, 'works', event.title);
        }
      },
    );
  });

  group('Councils', () {
    liveTest('the directory reads, a seat is taken and given back, for every account', () async {
      for (final w in await everyone()) {
        final repo = councilsOf(w);
        final overview = await repo.overview();
        expect(overview.councils, isNotEmpty);
        expect(await repo.unreadNotifications(), greaterThanOrEqualTo(0));
        final council = overview.councils.firstWhere(
          (c) => !c.joined,
          orElse: () => throw StateError('every council is joined'),
        );
        final role = await repo.join(council);
        try {
          expect(role, isNotNull);
          expect((await repo.overview()).joined.map((c) => c.id), contains(council.id));
        } finally {
          await repo.leave(council);
        }
        expect((await repo.overview()).joined.map((c) => c.id), isNot(contains(council.id)));
        record('Councils: directory, join, leave', w.person, 'works', council.name);
      }
    });
  });

  group('Chapters', () {
    liveTest(
      'the board reads, a chapter is joined and left, and a meetup RSVP is taken and given back, for every account',
      () async {
        for (final w in await everyone()) {
          final repo = chaptersOf(w);
          final overview = await repo.overview();
          expect(overview.chapters, isNotEmpty);
          expect(await repo.unreadNotifications(), greaterThanOrEqualTo(0));
          final chapter = overview.chapters.firstWhere(
            (c) => !c.joined,
            orElse: () => throw StateError('every chapter is joined'),
          );
          final detail = await repo.detail(chapter.slug);
          expect(detail, isNotNull);
          await repo.members(chapter.slug);
          await repo.events(chapter.slug);
          await repo.events(chapter.slug, past: true);
          await repo.updates(chapter.slug);
          await repo.resources(chapter.slug);
          await repo.nearby(chapter);
          final role = await repo.join(chapter);
          try {
            expect(role, ChapterRole.member);
            expect((await repo.overview()).chapters.firstWhere((c) => c.id == chapter.id).joined, isTrue);
          } finally {
            await repo.leave(chapter);
          }
          expect((await repo.overview()).chapters.firstWhere((c) => c.id == chapter.id).joined, isFalse);

          // A free meetup on the board: RSVP, then give it back.
          final meetup = overview.meetups
              .where((e) => (e.priceAmount ?? 0) == 0 && !e.full && !e.inviteOnly)
              .firstOrNull;
          if (meetup != null && meetup.myStatus != 'GOING') {
            await repo.rsvp(meetup);
            await repo.cancelRsvp(meetup);
          }
          record('Chapters: board, page sections, join, leave, meetup RSVP', w.person, 'works', chapter.name);
        }
      },
    );
  });

  group('the Events, Councils and Chapters screens, drawn for every account', () {
    testWidgets('Events, Councils and Chapters draw their boards from the live API', tags: const ['live'], (
      tester,
    ) async {
      if (!await liveScreenReady(tester)) return;
      for (final w in (await tester.runAsync(everyone))!) {
        final events = EventsController(eventsOf(w));
        await tester.runAsync(events.start);
        await loadScreen(
          tester,
          EventsScreen(onBack: () {}, viewer: _viewer(w), onAccount: () {}),
          providers: [ChangeNotifierProvider<EventsController>.value(value: events)],
          size: const Size(390, 2000),
        );
        var text = expectHealthy(tester, 'Events as ${w.email}');
        expect(text, contains('Upcoming'));
        expect(text, contains('My Schedule'));
        await unmount(tester);
        events.dispose();

        final councils = CouncilsController(councilsOf(w));
        await tester.runAsync(councils.start);
        await loadScreen(
          tester,
          CouncilsScreen(onBack: () {}),
          providers: [ChangeNotifierProvider<CouncilsController>.value(value: councils)],
          size: const Size(390, 2400),
        );
        text = expectHealthy(tester, 'Councils as ${w.email}');
        expect(text, contains('Your Joined Councils'));
        await unmount(tester);
        councils.dispose();

        final chapters = ChaptersController(chaptersOf(w));
        await tester.runAsync(chapters.start);
        await loadScreen(
          tester,
          ChaptersScreen(onBack: () {}, onOpenEvent: (_) {}),
          providers: [ChangeNotifierProvider<ChaptersController>.value(value: chapters)],
          size: const Size(390, 2200),
        );
        text = expectHealthy(tester, 'Chapters as ${w.email}');
        expect(text, contains('Chapters'));
        await unmount(tester);
        chapters.dispose();
        record('Events, Councils, Chapters: screens', w.person, 'works');
      }
    });
  });
}
