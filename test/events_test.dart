import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/events/demo_events_repository.dart';
import 'package:icr_mobile/features/events/event_detail_controller.dart';
import 'package:icr_mobile/features/events/event_format.dart';
import 'package:icr_mobile/features/events/event_models.dart';
import 'package:icr_mobile/features/events/events_controller.dart';
import 'package:icr_mobile/features/events/events_repository.dart';

import 'helpers/events_fixtures.dart';

const _webinar = {
  'id': 'e1',
  'title': 'Future of AI in Facility Management',
  'slug': 'future-of-ai',
  'kind': 'WEBINAR',
  'description': '<p>How AI changes FM.</p><p>Bring questions.</p>',
  'location': 'Online',
  'coverUrl': '/uploads/ai.jpg',
  'capacity': 25,
  'priceAmount': null,
  'priceCurrency': 'INR',
  'startsAt': '2099-10-24T10:30:00.000Z',
  'endsAt': '2099-10-24T12:00:00.000Z',
  'attendeeCount': 18,
  'chapter': {'id': 'c1', 'name': 'PropTech India Chapter', 'slug': 'proptech-india'},
  'council': null,
  'inviteOnly': false,
  'callForSpeakersUntil': null,
};

const _conference = {
  'id': 'e2',
  'title': 'Global CRE PropTech Summit 2026',
  'slug': 'global-summit',
  'kind': 'CONFERENCE',
  'location': 'Mumbai Convention Centre & Hybrid',
  'capacity': null,
  'priceAmount': 1500000,
  'priceCurrency': 'INR',
  'startsAt': '2099-11-12T03:30:00.000Z',
  'endsAt': '2099-11-14T11:30:00.000Z',
  'attendeeCount': 1420,
  'chapter': null,
  'council': null,
  'inviteOnly': false,
};

const _roundtable = {
  'id': 'e3',
  'title': 'Sustainable GCC Campus & Net-Zero Operations',
  'slug': 'gcc-net-zero',
  'kind': 'ROUNDTABLE',
  'location': 'Bengaluru',
  'capacity': 25,
  'startsAt': '2099-11-25T09:00:00.000Z',
  'attendeeCount': 7,
  'inviteOnly': true,
};

Map<String, Object Function(RequestOptions)> _board({List<Map<String, Object?>>? rsvps}) => {
  'GET /events': (_) => {
    'data': [_webinar, _conference, _roundtable],
    'meta': {'total': 3, 'hasNext': false},
  },
  'GET /events/rsvps/mine': (_) =>
      rsvps ??
      [
        {
          'eventId': 'e1',
          'status': 'GOING',
          'createdAt': '2099-01-01T00:00:00.000Z',
          'event': {
            'id': 'e1',
            'title': 'Future of AI in Facility Management',
            'slug': 'future-of-ai',
            'startsAt': '2099-10-24T10:30:00.000Z',
            'kind': 'WEBINAR',
          },
        },
      ],
  'GET /mentorship/cpd/target': (_) => {
    'year': 2026,
    'targetHours': 15,
    'achievedHours': 8.5,
    'progress': 0.57,
    'isDefault': false,
  },
  'GET /notifications/unread-count': (_) => {'unread': 3},
};

void main() {
  group('formatting', () {
    test('every clock is the Indian one', () {
      final at = DateTime.utc(2099, 10, 24, 10, 30);
      expect(clock(at), '4:00 PM');
      expect(clock(at, minutes: false), '4 PM');
      expect(monthTag(at), 'OCT');
      expect(ist(DateTime.utc(2099, 12, 31, 20)).year, 2100);
      expect(nextWhen(at), 'Oct 24, 4 PM');
    });

    test('a date line reads as the design writes it', () {
      final repo = DemoEventsRepository();
      expect(dateLineFor(DemoEventsRepository.ai), 'Oct 24, 2026 • 4:00 PM IST • 90 mins');
      expect(dateLineFor(DemoEventsRepository.summit), 'Nov 12-14, 2026 • 9:00 AM IST');
      expect(dateLineFor(DemoEventsRepository.gcc), 'Nov 25, 2026 • 2:30 PM • Bengaluru');
      expect(dateLineFor(DemoEventsRepository.bms), 'Dec 04, 2026 • 10:00 AM • Bangalore HQ');
      expect(timeRange(repo.sheetEvent), '10:00 AM – 4:30 PM IST');
      expect(durationLabel(DemoEventsRepository.ai), '90 mins');
      expect(durationLabel(DemoEventsRepository.bms), '6 hrs');
    });

    test('the format is read from the kind and the venue, as the website does', () {
      EventSummary at(String? venue, EventKind kind) =>
          EventSummary(id: 'x', title: 't', kind: kind, startsAt: DateTime.utc(2099), location: venue);
      expect(formatOf(at('Mumbai Convention Centre & Hybrid', EventKind.conference)), EventFormat.hybrid);
      expect(formatOf(at(null, EventKind.webinar)), EventFormat.online);
      expect(formatOf(at('Zoom', EventKind.workshop)), EventFormat.online);
      expect(formatOf(at('Pune', EventKind.workshop)), EventFormat.inPerson);
    });

    test('pills and footers come from what the API knows', () {
      EventSummary row(Map<String, dynamic> json) => EventSummary(
        id: json['id'] as String,
        title: json['title'] as String,
        kind: EventKind.fromApi(json['kind'] as String?),
        startsAt: DateTime.parse(json['startsAt'] as String),
        location: json['location'] as String?,
        inviteOnly: json['inviteOnly'] == true,
        pricePaisa: (json['priceAmount'] as num?)?.toInt() ?? 0,
        capacity: (json['capacity'] as num?)?.toInt(),
        going: (json['attendeeCount'] as num?)?.toInt() ?? 0,
      );
      final webinar = row(_webinar);
      expect(tagsFor(webinar).map((t) => t.label), ['WEBINAR', 'LIVE VIRTUAL']);
      expect(footerFor(webinar).action, 'Register Free');
      final conference = row(_conference);
      expect(tagsFor(conference).map((t) => t.label), ['CONFERENCE', 'HYBRID']);
      expect(footerFor(conference).action, 'Get Tickets');
      expect(footerFor(conference).note, '₹15,000 per pass');
      final roundtable = row(_roundtable);
      expect(tagsFor(roundtable).map((t) => t.label), ['ROUNDTABLE', 'INVITE ONLY']);
      expect(footerFor(roundtable).note, '18 / 25 Seats Left');
      expect(lineFor(roundtable)!.$1, 'By invitation only');
      expect(footerFor(webinar.copyWith(rsvp: RsvpState.going)).note, 'Registered');
    });

    test('a description becomes paragraphs', () {
      expect(paragraphs('<p>One &amp; two.</p><p>Three.</p>'), ['One & two.', 'Three.']);
      expect(paragraphs(null), isEmpty);
    });

    test('a bold-led list in a description becomes highlight cards, any other list stays text', () {
      final text = describe(
        '<p>Intro &amp; more.</p><ul><li><strong>Smart IoT &amp; FM</strong>: Deploying twins.</li>'
        '<li><b>ESG</b> – Benchmarks.</li><li><strong>Only a title</strong></li></ul>',
      );
      expect(text.paragraphs, ['Intro & more.']);
      expect(text.highlights.map((h) => (h.title, h.body)), [
        ('Smart IoT & FM', 'Deploying twins.'),
        ('ESG', 'Benchmarks.'),
        ('Only a title', ''),
      ]);

      final plain = describe('<p>Intro.</p><ul><li>One</li><li>Two</li></ul>');
      expect(plain.paragraphs, ['Intro.', 'One', 'Two']);
      expect(plain.highlights, isEmpty);

      final mixed = describe('<ul><li><strong>Titled</strong>: yes</li><li>Not titled</li></ul>');
      expect(mixed.highlights, isEmpty, reason: 'a list is cards only when every item has a title');
      expect(mixed.paragraphs, ['Titled: yes', 'Not titled']);
      expect(describe(null).paragraphs, isEmpty);
    });

    test('money and counts', () {
      expect(priceLabel(150000), '₹1,500');
      expect(priceLabel(150050), '₹1,500.50');
      expect(groupThousands(1420), '1,420');
      expect(hoursLabel(8.5), '8.5');
      expect(hoursLabel(15), '15');
      expect(cpdLabel(4.5), '4.5 CPD Credits');
      expect(initialsOf('Alex Rivers'), 'AR');
      expect(compactCount(639), '639');
      expect(compactCount(1000), '1k');
      expect(compactCount(1420), '1.4k');
      expect(compactCount(9999), '10k');
      expect(compactCount(12000), '12k');
    });

    test('the spotlight\'s kicker is short and true, its price slot says what the seat costs', () {
      EventSummary at(String? venue, {EventKind kind = EventKind.conference, int price = 0, bool invite = false}) =>
          EventSummary(
            id: 'x',
            title: 't',
            kind: kind,
            startsAt: DateTime.utc(2099),
            location: venue,
            pricePaisa: price,
            inviteOnly: invite,
          );
      expect(kickerFor(at('Mumbai Convention Centre & Hybrid')), 'CONFERENCE • HYBRID');
      expect(kickerFor(at('Pune')), 'CONFERENCE • IN PERSON');
      expect(kickerFor(at(null, kind: EventKind.webinar)), 'WEBINAR • LIVE VIRTUAL');
      expect(kickerFor(DemoEventsRepository.spotlight), 'FLAGSHIP GLOBAL GATHERING', reason: 'the demo keeps its own');
      expect(priceNote(at('Pune')), 'Free for members');
      expect(priceNote(at('Pune', price: 1500000)), '₹15,000 per pass');
      expect(priceNote(at('Pune', invite: true)), 'Invite only');
    });

    test('a card\'s second line: the speaker first, then who it is for, then where, then who hosts it', () {
      EventSummary at({String? speaker, bool invite = false, String? venue, String? host}) => EventSummary(
        id: 'x',
        title: 't',
        kind: EventKind.roundtable,
        startsAt: DateTime.utc(2099),
        location: venue,
        host: host,
        inviteOnly: invite,
        speakerLine: speaker,
      );
      expect(lineFor(at(speaker: 'Dr. Iyer, VP', invite: true, venue: 'Pune'))!, ('Dr. Iyer, VP', LineIcon.speaker));
      expect(lineFor(at(invite: true, venue: 'Pune'))!, ('By invitation only', LineIcon.lock));
      expect(lineFor(at(venue: ' Pune '))!, ('Pune', LineIcon.venue));
      expect(lineFor(at(host: 'ICR Pune Chapter'))!, ('Hosted by ICR Pune Chapter', LineIcon.speaker));
      expect(lineFor(at()), isNull);
      expect(
        speakerCardLine(const EventTalk(title: 't', speaker: 'Rajesh Sharma', bio: ' VP, Infosys ')),
        'Rajesh Sharma, VP, Infosys',
      );
      expect(speakerCardLine(const EventTalk(title: 't', speaker: 'Rajesh Sharma')), 'Rajesh Sharma');
    });
  });

  group('tracks and who is going', () {
    test('a track is the council\'s name without its tail', () {
      expect(trackLabelOf('Smart Buildings, BMS & PropTech Council'), 'Smart Buildings');
      expect(trackLabelOf('Sustainability, ESG & Net-Zero Council'), 'Sustainability');
      expect(trackLabelOf('Data Centre & Digital Infrastructure Council'), 'Data Centre');
      expect(trackLabelOf('CXO Workplace Strategy & FM Leadership'), 'CXO Workplace Strategy');
      expect(trackLabelOf('Banking, Financial Services & Insurance (BFSI) Council'), 'BFSI');
      expect(trackLabelOf('Corporate & Commercial Real Estate Council'), 'Corporate & Commercial Real Estate');
      expect(trackLabelOf('Procurement & Supply Chain Council'), 'Procurement & Supply Chain');
      expect(trackLabelOf('Facility Management Leadership Council'), 'Facility Management Leadership');
      expect(trackLabelOf('  '), isNull);
      expect(trackLabelOf(null), isNull);
    });

    test('a track wears the glyph of what it talks about', () {
      TrackIcon icon(String label) => trackIconFor(label);
      expect(icon('Sustainability'), TrackIcon.sustainability);
      expect(icon('Smart Buildings'), TrackIcon.tech);
      expect(icon('Data Centre'), TrackIcon.datacentre);
      expect(icon('Legal'), TrackIcon.legal);
      expect(icon('BFSI'), TrackIcon.finance);
      expect(icon('Construction'), TrackIcon.construction);
      expect(icon('Procurement & Supply Chain'), TrackIcon.procurement);
      expect(icon('CXO Workplace Strategy'), TrackIcon.leadership);
      expect(icon('Facility Management Leadership'), TrackIcon.leadership);
      expect(icon('Corporate & Commercial Real Estate'), TrackIcon.offices);
    });

    test('the attendee circles are the host\'s initials, or ICR\'s', () {
      final vinfraa = hostAvatars('ICR Vinfraa & PropTech India Chapter');
      expect(vinfraa.map((a) => a.initials), ['I', 'V', 'P']);
      expect(vinfraa.map((a) => a.tone), [AvatarTone.blue, AvatarTone.mint, AvatarTone.lavender]);
      expect(hostAvatars(null).map((a) => a.initials), ['I', 'C', 'R']);
      expect(hostAvatars('Mumbai').map((a) => a.initials), ['M']);
      expect(hostAvatars('the Council of Elders').map((a) => a.initials), ['C', 'E']);
      final sheet = hostAvatars('A B C', tones: const [AvatarTone.blue, AvatarTone.green, AvatarTone.slate]);
      expect(sheet.map((a) => a.tone), [AvatarTone.blue, AvatarTone.green, AvatarTone.slate]);
    });
  });

  group('the programme', () {
    // 10:00 AM IST is 04:30 UTC.
    DateTime atIst(int h, [int m = 0]) =>
        DateTime.utc(2026, 10, 24, h, m).subtract(const Duration(hours: 5, minutes: 30));
    EventSummary event({DateTime? end, DateTime? start}) =>
        EventSummary(id: 'x', title: 't', kind: EventKind.conference, startsAt: start ?? atIst(10), endsAt: end);

    String span((DateTime, DateTime) s) => '${clock(s.$1)} – ${clock(s.$2)}';

    test('talks are tagged by their own words', () {
      expect(talkTag('The Autonomous Facility', 'Keynote on the architecture').tag, 'KEYNOTE');
      expect(talkTag('Retrofitting Towers', 'Panel on retrofits'), (tag: 'PANEL', green: true, panel: true));
      expect(talkTag('A chat', 'A fireside with the CFO').tag, 'FIRESIDE');
      expect(talkTag('Sensors', 'A hands-on lab').tag, 'WORKSHOP');
      expect(talkTag('Future of AI', 'Where AI pays for itself').tag, 'TALK');
    });

    test('slots run from the start, 75 minutes with 15 between: the design\'s 10:00–11:15 and 11:30–12:45', () {
      final slots = talkSlots(event(end: atIst(16, 30)), 2);
      expect(slots.map(span), ['10:00 AM – 11:15 AM', '11:30 AM – 12:45 PM']);
      expect(talkSlots(event(end: atIst(16, 30)), 0), isEmpty);
    });

    test('a lone talk fills a short event, takes 75 minutes of a long one', () {
      expect(talkSlots(event(end: atIst(11, 30)), 1).map(span), ['10:00 AM – 11:30 AM']);
      expect(talkSlots(event(end: atIst(16, 30)), 1).map(span), ['10:00 AM – 11:15 AM']);
    });

    test('slots are squeezed to fit a short window, never below 15 minutes', () {
      // Three talks in three hours: 50 minutes each with 15 between, the last ending as the event does.
      final three = talkSlots(event(end: atIst(13)), 3);
      expect(three.map(span), ['10:00 AM – 10:50 AM', '11:05 AM – 11:55 AM', '12:10 PM – 1:00 PM']);
      final many = talkSlots(event(end: atIst(13)), 8);
      expect(many.first.$2.difference(many.first.$1).inMinutes, 15);
    });

    test('an event with no end is given exactly what its talks need; a long one is read on its first day', () {
      expect(talkSlots(event(), 2).map(span), ['10:00 AM – 11:15 AM', '11:30 AM – 12:45 PM']);
      final threeDays = event(start: atIst(9), end: atIst(9).add(const Duration(days: 3)));
      expect(talkSlots(threeDays, 3).map(span), ['9:00 AM – 10:15 AM', '10:30 AM – 11:45 AM', '12:00 PM – 1:15 PM']);
    });

    test('a session carries its slot, tag and speaker; a panel adds its panelists', () {
      final sessions = sessionsFor(event(end: atIst(16, 30)), const [
        EventTalk(
          title: 'The Autonomous Facility',
          abstract: 'Keynote on sensing.',
          speaker: 'Rajesh Sharma',
          bio: 'VP Global Real Estate, Infosys',
        ),
        EventTalk(title: 'Retrofitting', abstract: 'Panel on retrofits.', speaker: 'Priya Nambiar', bio: 'IGBC AP'),
        EventTalk(title: 'Unnamed', speaker: '', bio: 'Guest of honour'),
        EventTalk(title: 'Nobody'),
      ]);
      expect(sessions.map((s) => s.tag), ['KEYNOTE', 'PANEL', 'TALK', 'TALK']);
      expect(sessions[0].time, '10:00 AM – 11:15 AM');
      expect(sessions[0].speaker, 'Rajesh Sharma (VP Global Real Estate, Infosys)');
      expect(sessions[1].speaker, 'Priya Nambiar (IGBC AP) & Panelists');
      expect(sessions[1].panel, isTrue);
      expect(sessions[1].tagGreen, isTrue);
      expect(sessions[2].speaker, 'Guest of honour');
      expect(sessions[3].speaker, 'Speaker to be announced');
    });
  });

  group('the member\'s pass and calendar', () {
    test('the pass reference is the event\'s code', () {
      expect(eventCode('design-ev-fbis'), 'FBIS');
      expect(eventCode('cmvkdmjct001emyzoeo0d1'), 'O0D1');
      expect(passReference('design-ev-fbis'), 'ICR-EVT-FBIS');
      expect(passReference('ab'), 'ICR-EVT-AB');
    });

    test('"Add to calendar" opens Google Calendar with the event filled in', () {
      final event = EventSummary(
        id: 'fbis',
        title: 'Future of Business & Innovation Summit 2024',
        kind: EventKind.conference,
        startsAt: DateTime.utc(2026, 10, 24, 4, 30),
        endsAt: DateTime.utc(2026, 10, 24, 11),
        location: 'Grand Auditorium, Hall 3 • Mumbai Convention Centre',
      );
      final uri = googleCalendarUri(event, Uri.parse('https://icr.org.in/events/fbis'));
      expect(uri.host, 'calendar.google.com');
      expect(uri.path, '/calendar/render');
      expect(uri.queryParameters['action'], 'TEMPLATE');
      expect(uri.queryParameters['text'], 'Future of Business & Innovation Summit 2024');
      expect(uri.queryParameters['dates'], '20261024T043000Z/20261024T110000Z');
      expect(uri.queryParameters['location'], 'Grand Auditorium, Hall 3 • Mumbai Convention Centre');
      expect(uri.queryParameters['details'], contains('https://icr.org.in/events/fbis'));

      final open = googleCalendarUri(
        EventSummary(id: 'x', title: 'No end', kind: EventKind.webinar, startsAt: DateTime.utc(2026, 1, 2, 3, 4, 5)),
        Uri.parse('https://icr.org.in/events/x'),
      );
      expect(open.queryParameters['dates'], '20260102T030405Z/20260102T040405Z', reason: 'calendars assume an hour');
      expect(open.queryParameters.containsKey('location'), isFalse);
    });
  });

  group('the API source', () {
    test('maps the board, the member\'s places and their CPD year', () async {
      final api = FakeApi(_board());
      final overview = await repoOn(api).overview();

      expect(overview.events.length, 2, reason: 'the flagship has its own card and is not repeated in the agenda');
      final ai = overview.events.first;
      expect(ai.title, 'Future of AI in Facility Management');
      expect(ai.kind, EventKind.webinar);
      expect(ai.cover?.url, 'http://api.test/uploads/ai.jpg');
      expect(ai.host, 'PropTech India Chapter');
      expect(ai.going, 18);
      expect(ai.capacity, 25);
      expect(ai.seatsLeft, 7);
      expect(ai.cpdHours, 1.5);
      expect(ai.rsvp, RsvpState.going);
      expect(ai.priced, isFalse);

      final summit = overview.spotlight!;
      expect(summit.pricePaisa, 1500000);
      expect(summit.cpdHours, 56.0, reason: 'the ledger credits the whole span, start to end, as markAttendance does');
    });

    test('the spotlight is the best attended, the schedule the places held, the CPD year the target route', () async {
      final overview = await repoOn(FakeApi(_board())).overview();
      expect(overview.spotlight!.id, 'e2');
      expect(overview.events.map((e) => e.id), ['e1', 'e3']);
      expect(overview.schedule!.count, 1);
      expect(overview.schedule!.next!.id, 'e1');
      expect(overview.cpd!.earned, 8.5);
      expect(overview.cpd!.target, 15);
      expect(overview.cpd!.remaining, 6.5);
      expect(
        overview.readyCount,
        1,
        reason: 'the invite-only roundtable is not open to register, the flagship is apart',
      );
      expect(overview.upcomingCount, 0, reason: 'all three are decades away');
    });

    test('with fewer than two councils the category tiles are the event kinds, most events first', () async {
      final overview = await repoOn(FakeApi(_board())).overview();
      expect(overview.tracks.every((t) => t.kind != null && t.council == null), isTrue);
      expect(overview.tracks.firstWhere((t) => t.kind == EventKind.webinar).count, 1);
      expect(overview.tracks.firstWhere((t) => t.kind == EventKind.conference).count, 0);
      expect(overview.tracks.firstWhere((t) => t.kind == EventKind.chapterMeet).count, 0);
      expect(
        overview.tracks.map((t) => t.count),
        [...overview.tracks.map((t) => t.count)]..sort((a, b) => b.compareTo(a)),
      );
    });

    test('with two or more councils the tiles are their industry tracks, counted over the agenda', () async {
      final world = EventsWorld();
      final overview = await repoOn(FakeApi(world.routes())).overview();
      expect(overview.spotlight!.id, 'flag');
      expect(overview.events.map((e) => e.id), ['ai', 'esg', 'zoom', 'bms', 'summit', 'gcc', 'far']);
      expect(overview.tracks.map((t) => (t.label, t.count)), [
        ('Smart Buildings', 2),
        ('Sustainability', 2),
        ('CXO Workplace Strategy', 1),
      ]);
      expect(overview.tracks.every((t) => t.council != null && t.kind == null && t.filters), isTrue);
      expect(overview.tracks.first.icon, TrackIcon.tech);
      expect(overview.tracks[1].icon, TrackIcon.sustainability);
      expect(overview.tracks.last.icon, TrackIcon.leadership);
      expect(overview.upcomingCount, 6, reason: 'the chapter meeting is 90 days away');
      expect(overview.readyCount, 6, reason: 'the invite-only roundtable is not open to register');
    });

    test('a search and a kind go to the API as query parameters', () async {
      final api = FakeApi(_board());
      final repo = repoOn(api);
      await repo.search(const EventQuery(search: 'AI', kind: EventKind.webinar));
      final i = api.calls.indexOf('GET /events');
      expect(api.queries[i]['search'], 'AI');
      expect(api.queries[i]['kind'], 'WEBINAR');
      expect(api.queries[i]['when'], 'upcoming');
      await repo.search(const EventQuery(when: EventWhen.past));
      expect(api.queries.last['when'], 'past');
    });

    test('the format filter keeps online events, or in-person ones', () async {
      final repo = repoOn(FakeApi(EventsWorld().routes()));
      final online = await repo.search(const EventQuery(format: FormatFilter.online));
      expect(online.every((e) => formatOf(e) != EventFormat.inPerson), isTrue);
      expect(online.map((e) => e.id), containsAll(['ai', 'esg', 'zoom']));
      expect(online.map((e) => e.id), isNot(contains('bms')));
      final inPerson = await repo.search(const EventQuery(format: FormatFilter.inPerson));
      expect(inPerson.every((e) => formatOf(e) != EventFormat.online), isTrue);
      expect(inPerson.map((e) => e.id), containsAll(['bms', 'summit', 'gcc']));
    });

    test('an event\'s sheet reads the programme and names the member and their company', () async {
      final api = FakeApi({
        ..._board(),
        'GET /events/future-of-ai': (_) => _webinar,
        'GET /events/e1/programme': (_) => {
          'eventId': 'e1',
          'speakers': [
            {
              'id': 'p1',
              'title': 'The Autonomous Facility',
              'abstract': 'Keynote on sensing.',
              'bio': 'VP Global Real Estate, Infosys',
              'speaker': {'id': 'u1', 'firstName': 'Rajesh', 'lastName': 'Sharma'},
            },
          ],
          'mine': {'invited': false},
        },
        'GET /auth/me': (_) => {'firstName': 'Alex', 'lastName': 'Rivers', 'companyId': 'co1'},
        'GET /companies/co1': (_) => {'id': 'co1', 'name': 'TechCorp'},
      });
      final repo = repoOn(api);
      final overview = await repo.overview();
      final detail = await repo.detail(overview.events.first);

      expect(detail.event.description, contains('Bring questions'));
      expect(detail.organiser, 'PropTech India Chapter');
      expect(detail.sessions.single.title, 'The Autonomous Facility');
      expect(detail.sessions.single.speaker, 'Rajesh Sharma (VP Global Real Estate, Infosys)');
      expect(detail.sessions.single.time, '4:00 PM – 5:30 PM', reason: 'a lone talk fills the 90-minute webinar');
      expect(detail.sessions.single.tag, 'KEYNOTE');
      expect(detail.agendaNote, 'Indicative times • Oct 24');
      expect(detail.pass!.holder, 'Alex Rivers (TechCorp)');
      expect(detail.pass!.reference, 'ICR-EVT-E1', reason: 'the pass carries the event\'s code');
      expect(detail.event.speakerLine, 'Rajesh Sharma, VP Global Real Estate, Infosys');
      expect(detail.attendeeNote, '25 seats in total');
    });

    test('a waitlisted place has a pass card but no pass to show', () async {
      final world = EventsWorld()..places['ai'] = 'WAITLISTED';
      final repo = repoOn(FakeApi(world.routes()));
      final overview = await repo.overview();
      final detail = await repo.detail(overview.events.firstWhere((e) => e.id == 'ai'));
      expect(detail.event.rsvp, RsvpState.waitlisted);
      expect(detail.pass, isNotNull);
      expect(detail.pass!.reference, isNull);
    });

    test('an event the member has no place at has no pass; a description\'s list becomes the highlights', () async {
      final world = EventsWorld();
      world.byId('esg')['description'] = '<p>About it.</p><ul><li><strong>Scope 3</strong>: Supplier data.</li></ul>';
      final repo = repoOn(FakeApi(world.routes()));
      final overview = await repo.overview();
      final detail = await repo.detail(overview.events.firstWhere((e) => e.id == 'esg'));
      expect(detail.pass, isNull);
      expect(describe(detail.event.description).highlights.single.title, 'Scope 3');
      expect(detail.sessions.map((s) => s.tag), ['KEYNOTE', 'PANEL']);
      // A 90-minute event with two talks: 35 minutes each, 15 between.
      final start = DateTime.parse(world.byId('esg')['startsAt'] as String);
      String at(int minutes) => clock(start.add(Duration(minutes: minutes)));
      expect(detail.sessions.map((s) => s.time), ['${clock(start)} – ${at(35)}', '${at(50)} – ${at(85)}']);
    });

    test('a priced event says whether its tickets are sold online', () async {
      final repo = repoOn(FakeApi(EventsWorld().routes()));
      final overview = await repo.overview();
      expect((await repo.detail(overview.events.firstWhere((e) => e.id == 'summit'))).sellsTickets, isTrue);
      expect((await repo.detail(overview.events.firstWhere((e) => e.id == 'esg'))).sellsTickets, isFalse);
    });

    test(
      'speakers are read from the first twelve programmes, once each, and events without talks are left out',
      () async {
        final events = [for (var i = 0; i < 15; i++) eventRow('x$i', 'Event $i', at: Duration(days: 2 + i))];
        final world = EventsWorld(events: events)
          ..places.clear()
          ..talks.clear();
        world.talks['x1'] = [
          {
            'id': 't',
            'title': 'Opening',
            'abstract': 'Words.',
            'bio': 'Chair',
            'speaker': {'firstName': 'Asha', 'lastName': 'Rao'},
          },
        ];
        final api = FakeApi(world.routes());
        final repo = repoOn(api);
        final overview = await repo.overview();
        final found = await repo.speakers(overview.events);
        expect(found, {'x1': 'Asha Rao, Chair'});
        expect(api.calls.where((c) => c.endsWith('/programme')).length, 12);
      },
    );

    test('registering and cancelling call the RSVP routes', () async {
      final api = FakeApi({
        ..._board(rsvps: []),
        'POST /events/e1/rsvp': (_) => {'status': 'WAITLISTED'},
        'DELETE /events/e1/rsvp': (_) => {'status': 'CANCELLED'},
      });
      final repo = repoOn(api);
      final event = (await repo.overview()).events.first;
      expect(event.rsvp, RsvpState.none);
      expect(await repo.rsvp(event), RsvpState.waitlisted);
      await repo.cancel(event);
      expect(api.calls, containsAllInOrder(['POST /events/e1/rsvp', 'DELETE /events/e1/rsvp']));
    });

    test(
      'the schedule follows the places the repository knows: taking one adds it, giving it back takes it out',
      () async {
        final world = EventsWorld();
        final repo = repoOn(FakeApi(world.routes()));
        final overview = await repo.overview();
        final known = [...overview.events, overview.spotlight!];
        expect(overview.schedule!.count, 1);
        expect(overview.schedule!.next!.id, 'ai');

        final bms = known.firstWhere((e) => e.id == 'bms');
        await repo.rsvp(bms);
        expect(repo.schedule(known)!.count, 2);
        expect(repo.schedule(known)!.next!.id, 'ai', reason: 'the soonest place still ahead');
        await repo.cancel(known.firstWhere((e) => e.id == 'ai'));
        expect(repo.schedule(known)!.count, 1);
        expect(repo.schedule(known)!.next!.id, 'bms');
        await repo.cancel(bms);
        expect(repo.schedule(known), isNull);
      },
    );

    test('the unread count is the notification bell\'s', () async {
      expect(await repoOn(FakeApi(_board())).unreadNotifications(), 3);
    });

    test('a refusal reaches the caller in the API\'s own words', () async {
      final world = EventsWorld()..refuseRsvp = 'This event is invite-only.';
      final repo = repoOn(FakeApi(world.routes()));
      final overview = await repo.overview();
      await expectLater(
        repo.rsvp(overview.events.firstWhere((e) => e.id == 'bms')),
        throwsA(isA<ApiError>().having((e) => e.message, 'message', 'This event is invite-only.')),
      );
    });
  });

  group('the controller', () {
    test('the chips follow the board, and a chip narrows the agenda to one kind', () async {
      final events = EventsController(DemoEventsRepository());
      await events.start();
      expect(events.chips.map((c) => c.label), [
        'All Events',
        'Upcoming (24)',
        'Conferences',
        'Webinars',
        'Roundtables',
        'Workshops',
      ]);
      expect(events.agenda.length, 7);
      events.chips[2].select();
      expect(events.agenda.map((e) => e.kind).toSet(), {EventKind.conference});
      expect(events.agenda.length, 2);
      events.chips.first.select();
      expect(events.agenda.length, 7);
    });

    test('the flagship has its own card and is not repeated in the agenda, but is still found', () async {
      final events = EventsController(repoOn(FakeApi(EventsWorld().routes())));
      await events.start();
      await events.speakersSettled;
      expect(events.spotlight!.id, 'flag');
      expect(events.agenda.map((e) => e.id), isNot(contains('flag')));
      expect(events.find('flag'), isNotNull);
      expect(events.chips.map((c) => c.label), [
        'All Events',
        'Upcoming (6)',
        'Conferences',
        'Webinars',
        'Roundtables',
        'Workshops',
        'Chapter meetups',
      ]);
      events.chips.firstWhere((c) => c.label == 'Conferences').select();
      expect(events.agenda.map((e) => e.id), ['summit'], reason: 'the flagship is a conference and shows above');
      events.dispose();
    });

    test('"Upcoming" shows the next 30 days, and a kind chip then replaces it', () async {
      final events = EventsController(repoOn(FakeApi(EventsWorld().routes())));
      await events.start();
      events.chips[1].select();
      expect(events.chips[1].selected, isTrue);
      expect(events.agenda.map((e) => e.id), ['ai', 'esg', 'zoom', 'bms', 'summit', 'gcc']);
      events.chips.firstWhere((c) => c.label == 'Webinars').select();
      expect(events.chips[1].selected, isFalse);
      expect(events.agenda.map((e) => e.id), ['ai', 'esg']);
      events.chips.first.select();
      expect(events.agenda.length, 7);
      events.dispose();
    });

    test('a category tile narrows the agenda to its track, a second tap lifts it, "Clear" resets everything', () async {
      final events = EventsController(repoOn(FakeApi(EventsWorld().routes())));
      await events.start();
      final smart = events.tracks.first;
      expect(smart.label, 'Smart Buildings');

      events.selectTrack(smart);
      expect(events.track!.label, 'Smart Buildings');
      expect(events.agenda.map((e) => e.id), ['bms', 'far']);
      expect(events.agenda.length, smart.count);
      expect(events.agendaTitle, 'Smart Buildings Events');
      expect(events.filtered, isTrue);
      expect(events.chips.first.selected, isFalse, reason: '"All Events" is not what the agenda shows now');

      // A kind chip works inside the track.
      events.chips.firstWhere((c) => c.label == 'Workshops').select();
      expect(events.agenda.map((e) => e.id), ['bms']);

      events.selectTrack(smart);
      expect(events.track, isNull);
      expect(events.agenda.map((e) => e.id), ['zoom', 'bms']);

      events.selectTrack(events.tracks.last);
      await events.clearAll();
      expect(events.filtered, isFalse);
      expect(events.agenda.length, 7);
      expect(events.agendaTitle, 'Upcoming Agenda');
      expect(events.chips.first.selected, isTrue);
      events.dispose();
    });

    test('the demo\'s categories have nothing to match, so a tap changes nothing', () async {
      final events = EventsController(DemoEventsRepository());
      await events.start();
      events.selectTrack(events.tracks.first);
      expect(events.track, isNull);
      expect(events.agenda.length, 7);
    });

    test('a kind tile (no councils among the events) acts as its chip', () async {
      final events = EventsController(repoOn(FakeApi(_board())));
      await events.start();
      final tile = events.tracks.firstWhere((t) => t.kind == EventKind.roundtable);
      events.selectTrack(tile);
      expect(events.query.kind, EventKind.roundtable);
      expect(events.agenda.map((e) => e.id), ['e3']);
      events.dispose();
    });

    test('a search narrows the board to one list, and a track narrows the results', () async {
      final events = EventsController(DemoEventsRepository());
      await events.start();
      await events.setSearch('masterclass');
      expect(events.narrowed, isTrue);
      expect(events.agendaTitle, 'Events matching "masterclass"');
      expect(events.agenda.single.title, contains('Masterclass'));
      await events.setSearch('');
      expect(events.narrowed, isFalse);

      final live = EventsController(repoOn(FakeApi(EventsWorld().routes())));
      await live.start();
      await live.setSearch('summit');
      expect(live.agenda.map((e) => e.id), ['flag', 'summit', 'far']);
      live.selectTrack(live.tracks.firstWhere((t) => t.label == 'Smart Buildings'));
      expect(live.agenda.map((e) => e.id), ['far']);
      await live.clearAll();
      expect(live.narrowed, isFalse);
      expect(live.track, isNull);
      live.dispose();
    });

    test('the filter sheet\'s window and format narrow the board; clearing the filters keeps the words', () async {
      final events = EventsController(repoOn(FakeApi(EventsWorld().routes())));
      await events.start();
      await events.setQuery(const EventQuery(when: EventWhen.past));
      expect(events.agendaTitle, 'Past Events');
      expect(events.agenda.map((e) => e.id), ['old']);
      await events.setQuery(const EventQuery(search: 'ESG', format: FormatFilter.online));
      expect(events.agenda.map((e) => e.id), ['esg']);
      await events.clearFilters();
      expect(events.query.search, 'ESG');
      expect(events.query.format, FormatFilter.any);
      await events.clearAll();
      expect(events.query.search, '');
      events.dispose();
    });

    test('a card\'s second line is the first speaker once the programmes are read, and they are read once', () async {
      final api = FakeApi(EventsWorld().routes());
      final events = EventsController(repoOn(api));
      await events.start();
      await events.speakersSettled;
      expect(events.find('ai')!.speakerLine, 'Dr. Radhika Iyer, VP Sustainable PropTech');
      expect(events.find('esg')!.speakerLine, 'Vikram Malhotra, Director ESG', reason: 'the first of its talks');
      expect(events.find('bms')!.speakerLine, isNull);
      final asked = api.calls.where((c) => c.endsWith('/programme')).length;
      expect(asked, 7, reason: 'one programme for each card of the agenda');

      await events.refresh();
      await events.speakersSettled;
      expect(api.calls.where((c) => c.endsWith('/programme')).length, asked, reason: 'a refresh does not ask again');
      expect(events.find('ai')!.speakerLine, isNotNull);
      events.dispose();
    });

    test('registering shows the place at once and takes it back when the API refuses', () async {
      final repo = _Refusing(DemoEventsRepository());
      final events = EventsController(repo);
      await events.start();
      final event = events.agenda.first;
      expect(event.rsvp, RsvpState.none);
      final before = event.going;

      final message = await events.register(event);
      expect(message, 'The API said no.');
      expect(events.find(event.id)!.rsvp, RsvpState.none);
      expect(events.find(event.id)!.going, before);
    });

    test('registering with the demo source holds the place and counts it', () async {
      final events = EventsController(DemoEventsRepository());
      await events.start();
      final event = events.agenda.first;
      expect(await events.register(event), isNull);
      expect(events.find(event.id)!.rsvp, RsvpState.going);
      expect(events.find(event.id)!.going, event.going + 1);
      expect(await events.cancel(events.find(event.id)!), isNull);
      expect(events.find(event.id)!.rsvp, RsvpState.cancelled);
      expect(events.find(event.id)!.going, event.going);
    });

    test('a place taken or given back moves "My Schedule" at once', () async {
      final events = EventsController(repoOn(FakeApi(EventsWorld().routes())));
      await events.start();
      expect(events.schedule!.count, 1);
      expect(await events.register(events.find('bms')!), isNull);
      expect(events.schedule!.count, 2);
      expect(await events.cancel(events.find('ai')!), isNull);
      expect(events.schedule!.count, 1);
      expect(events.schedule!.next!.id, 'bms');
      expect(await events.cancel(events.find('bms')!), isNull);
      expect(events.schedule, isNull);
      events.dispose();
    });

    test('a full event gives a waitlist place: the card says so and the seat count is left alone', () async {
      final world = EventsWorld()..waitlisted.add('gcc');
      final events = EventsController(repoOn(FakeApi(world.routes())));
      await events.start();
      final gcc = events.find('gcc')!;
      expect(await events.register(gcc), isNull);
      expect(events.find('gcc')!.rsvp, RsvpState.waitlisted);
      expect(events.find('gcc')!.going, gcc.going);
      expect(events.schedule!.count, 2, reason: 'a waitlist place is on the schedule');
      events.dispose();
    });

    test('a priced seat is refused as a free place, with the API\'s reason, and the card goes back', () async {
      final world = EventsWorld()..refuseRsvp = 'This event is ticketed. Buy a ticket to take your place.';
      final events = EventsController(repoOn(FakeApi(world.routes())));
      await events.start();
      final summit = events.find('summit')!;
      final message = await events.register(summit);
      expect(message, 'This event is ticketed. Buy a ticket to take your place.');
      expect(events.find('summit')!.rsvp, RsvpState.none);
      expect(events.find('summit')!.going, summit.going);
      expect(events.schedule!.count, 1);
      events.dispose();
    });

    test('a paid seat refuses to cancel and the place is put back', () async {
      final api = FakeApi({
        ..._board(),
        'DELETE /events/e1/rsvp': (_) => (
          403,
          '{"statusCode":403,"message":"Your ticket is paid for. To cancel it, contact ICR support, who will arrange any refund."}',
        ),
      });
      final events = EventsController(repoOn(api));
      await events.start();
      final event = events.find('e1')!;
      expect(event.rsvp, RsvpState.going);
      final message = await events.cancel(event);
      expect(message, startsWith('Your ticket is paid for'));
      expect(events.find('e1')!.rsvp, RsvpState.going);
      expect(events.find('e1')!.going, 18);
      expect(events.unread, 3);
    });

    test('a bookmark is kept on the device and never fails', () async {
      final events = EventsController(DemoEventsRepository());
      await events.start();
      final event = events.agenda.first;
      events.toggleSave(event);
      expect(events.find(event.id)!.saved, isTrue);
      events.toggleSave(events.find(event.id)!);
      expect(events.find(event.id)!.saved, isFalse);
    });

    test('a bookmark survives a refresh', () async {
      final events = EventsController(repoOn(FakeApi(EventsWorld().routes())));
      await events.start();
      events.toggleSave(events.find('bms')!);
      await events.refresh();
      expect(events.find('bms')!.saved, isTrue);
      events.dispose();
    });

    test('a board that cannot load says why and recovers on a refresh', () async {
      final world = EventsWorld();
      final routes = world.routes();
      var down = true;
      final handler = routes['GET /events']!;
      routes['GET /events'] = (o) => down ? (503, '{"message":"The API is down."}') : handler(o);
      final events = EventsController(repoOn(FakeApi(routes)));
      await events.start();
      expect(events.overview, isNull);
      expect(events.error, 'The API is down.');
      down = false;
      await events.refresh();
      expect(events.error, isNull);
      expect(events.overview, isNotNull);
      events.dispose();
    });
  });

  group('the sheet\'s controller', () {
    test('loads the sheet, registers and cancels, and tells the board', () async {
      final repo = DemoEventsRepository();
      final seen = <EventSummary>[];
      final controller = EventDetailController(repository: repo, seed: repo.sheetEvent, onChanged: seen.add);
      await controller.load();
      expect(controller.detail.pass!.reference, 'ICR-EVT-8849');
      expect(controller.detail.sessions.length, 2);
      expect(controller.event.rsvp, RsvpState.going);

      expect(await controller.cancel(), isNull);
      expect(controller.event.rsvp, RsvpState.cancelled);
      expect(controller.detail.pass, isNull);
      expect(controller.event.going, 641);
      expect(await controller.register(), isNull);
      expect(controller.event.rsvp, RsvpState.going);
      expect(seen.length, greaterThanOrEqualTo(2));
    });

    test('a refused cancel restores the pass and the count', () async {
      final repo = _Refusing(DemoEventsRepository());
      final controller = EventDetailController(repository: repo, seed: repo.inner.sheetEvent);
      await controller.load();
      final message = await controller.cancel();
      expect(message, 'The API said no.');
      expect(controller.event.rsvp, RsvpState.going);
      expect(controller.event.going, 642);
      expect(controller.detail.pass, isNotNull);
    });

    test('a refused registration restores the card, and the sheet\'s bookmark is kept', () async {
      final world = EventsWorld()..refuseRsvp = 'This event is invite-only.';
      final repo = repoOn(FakeApi(world.routes()));
      final seen = <EventSummary>[];
      final overview = await repo.overview();
      final controller = EventDetailController(
        repository: repo,
        seed: overview.events.firstWhere((e) => e.id == 'bms'),
        onChanged: seen.add,
      );
      await controller.load();
      controller.toggleSave();
      expect(controller.event.saved, isTrue);
      expect(seen.last.saved, isTrue);

      final going = controller.event.going;
      expect(await controller.register(), 'This event is invite-only.');
      expect(controller.event.rsvp.holds, isFalse);
      expect(controller.event.going, going);
      expect(controller.event.saved, isTrue);
    });
  });

  group('the demo source', () {
    test('reproduces the designs\' sample content', () async {
      final overview = await DemoEventsRepository().overview();
      expect(overview.events.map((e) => e.title), [
        'Future of AI in Facility Management',
        'Global CRE PropTech Summit 2026',
        'Sustainable GCC Campus & Net-Zero Operations',
        'Smart BMS & Predictive Maintenance Masterclass',
        'Future of AI in Facility Management',
        'Global CRE PropTech Summit 2026',
        'Sustainable GCC Campus & Net-Zero Operations',
      ]);
      expect(overview.spotlight!.title, 'Global CRE PropTech Summit 2026');
      expect(overview.spotlight!.going, 1420);
      expect(overview.upcomingCount, 24);
      expect(overview.schedule!.count, 2);
      expect(overview.cpd!.earned, 8.5);
      expect(overview.cpd!.target, 15);
      expect(overview.tracks.length, 6);
      expect(overview.readyCount, 4);
    });
  });
}

/// The demo source, except that taking and giving back a place fail.
class _Refusing implements EventsRepository {
  _Refusing(this.inner);

  final DemoEventsRepository inner;

  @override
  Future<RsvpState> rsvp(EventSummary event) async => throw ApiError('The API said no.');
  @override
  Future<void> cancel(EventSummary event) async => throw ApiError('The API said no.');

  @override
  Future<EventsOverview> overview() => inner.overview();
  @override
  Future<List<EventSummary>> search(EventQuery query) => inner.search(query);
  @override
  Future<EventDetail> detail(EventSummary event) => inner.detail(event);
  @override
  Future<EventPass?> passFor(EventSummary event) => inner.passFor(event);
  @override
  Future<Map<String, String>> speakers(List<EventSummary> events) => inner.speakers(events);
  @override
  MySchedule? schedule(List<EventSummary> known) => inner.schedule(known);
  @override
  Future<int> unreadNotifications() => inner.unreadNotifications();
  @override
  Uri link(EventSummary event) => inner.link(event);
}
