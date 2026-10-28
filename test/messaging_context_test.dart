import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/messaging/messaging_context.dart';
import 'package:icr_mobile/features/messaging/messaging_format.dart';
import 'package:icr_mobile/features/messaging/messaging_models.dart';
import 'package:icr_mobile/features/messaging/messaging_repository.dart';
import 'package:icr_mobile/features/notifications/notification_target.dart';

import 'messaging_fakes.dart';

/// The rules behind the screens, with no widgets: how a thread is named, what it
/// says it is about, the openers an empty one offers, the lines a business event
/// draws, shared records, and every stamp. A port of the website's
/// `conversationDisplay`, `chatContext`, `contextLinks`, `recordLinks`.
void main() {
  final now = testNow; // Sunday 25 Oct 2026, 15:00

  group('stamps', () {
    test('the inbox: the time today, Yesterday, a weekday inside six days, then the date', () {
      expect(listTime(DateTime(2026, 10, 25, 9, 5), now: now), '9:05 am');
      expect(listTime(DateTime(2026, 10, 25, 14, 59), now: now), '2:59 pm');
      expect(listTime(DateTime(2026, 10, 25, 0, 30), now: now), '12:30 am');
      expect(listTime(DateTime(2026, 10, 25, 12, 0), now: now), '12:00 pm');
      expect(listTime(DateTime(2026, 10, 24, 23, 0), now: now), 'Yesterday');
      expect(listTime(DateTime(2026, 10, 22, 8, 0), now: now), 'Thu');
      expect(listTime(DateTime(2026, 10, 19, 8, 0), now: now), '19 Oct');
      expect(listTime(DateTime(2025, 12, 3), now: now), '3 Dec 2025');
    });

    test('a thread\'s day separator', () {
      expect(dayLabel(DateTime(2026, 10, 25, 1), now: now), 'Today');
      expect(dayLabel(DateTime(2026, 10, 24, 20), now: now), 'Yesterday');
      expect(dayLabel(DateTime(2026, 10, 23, 13), now: now), 'Fri, 23 Oct');
      expect(dayLabel(DateTime(2025, 3, 3), now: now), 'Mon, 3 Mar 2025');
    });

    test('file sizes and rupees', () {
      expect(fileSize(null), '');
      expect(fileSize(0), '');
      expect(fileSize(900), '900 B');
      expect(fileSize(1300), '1 KB');
      expect(fileSize(84 * 1024), '84 KB');
      expect(fileSize(1572864), '1.5 MB');
      expect(fileSize(25 * 1024 * 1024), '25 MB');
      expect(rupees(18500), '₹18,500');
      expect(rupees(1250000), '₹12,50,000');
      expect(rupees(999), '₹999');
      expect(rupees(100000), '₹1,00,000');
      expect(rupees(-4500), '-₹4,500');
    });
  });

  group('how a conversation is named (conversationDisplay)', () {
    test('a person: their name and photo', () {
      final d = conversationDisplay(participants: const [me, sarah], meId: meId);
      expect((d.name, d.avatar), ('Sarah Jenkins', AvatarKind.person));
    });

    test('a company\'s thread is the company, with the person who writes as the line under it', () {
      final d = conversationDisplay(
        participants: const [me, priya],
        meId: meId,
        kind: ConversationKind.company,
        counterpartCompany: globalInfra,
      );
      expect((d.name, d.avatar, d.secondary), ('Global Infra Solutions', AvatarKind.company, 'Priya Sharma'));
    });

    test('a requirement, a bid and an enquiry are named for the company on the other side', () {
      for (final k in [ConversationKind.requirement, ConversationKind.bid, ConversationKind.enquiry]) {
        final d = conversationDisplay(participants: const [me], meId: meId, kind: k, counterpartCompany: careSupplier);
        expect(d.name, 'Bengaluru Care 101', reason: k.name);
      }
    });

    test('a mentoring or consultation thread is named for the person', () {
      final d = conversationDisplay(participants: const [me, priya], meId: meId, kind: ConversationKind.mentorship);
      expect(d.name, 'Priya Sharma');
    });

    test('a room is named for what it is, and drawn as a group', () {
      final d = conversationDisplay(
        participants: const [me, sarah, david, priya],
        meId: meId,
        kind: ConversationKind.groupSession,
        contextLabel: 'BMS Retrofit Clinic',
      );
      expect((d.name, d.avatar), ('BMS Retrofit Clinic', AvatarKind.group));
      final plain = conversationDisplay(participants: const [me, sarah, david], meId: meId);
      expect(plain.name, 'Sarah Jenkins, David Chen');
      expect(plain.avatar, AvatarKind.group);
    });

    test('a thread with no one else and no company is its title, else "Conversation"', () {
      expect(conversationDisplay(participants: const [me], meId: meId, title: 'Notes to self').name, 'Notes to self');
      expect(conversationDisplay(participants: const [me], meId: meId).name, 'Conversation');
    });

    test('the line beside the kind badge (conversationAbout)', () {
      final d = conversationDisplay(participants: const [me, sarah], meId: meId);
      expect(conversationAbout(convo('a', kind: ConversationKind.requirement, contextLabel: 'Fleet'), d), 'Fleet');
      expect(conversationAbout(convo('a', kind: ConversationKind.consultation, contextLabel: 'Q&A'), d), 'Q&A');
      expect(conversationAbout(convo('a', counterpart: globalInfra), d), 'Global Infra Solutions');
      expect(
        conversationAbout(convo('a', title: 'Senior Facilities Manager · Global Infra'), d),
        'Senior Facilities Manager · Global Infra',
      );
      expect(conversationAbout(convo('a'), d), isNull);
      // Read from a company inbox: the topic it is in (a requirement still names the requirement).
      final inbox = convo(
        'a',
        kind: ConversationKind.company,
        asCompanyId: 'co-acme',
        parties: const [ThreadParty(companyId: 'co-acme', name: 'Acme', topic: 'CAREERS', status: ThreadStatus.open)],
      );
      expect(conversationAbout(inbox, d), 'Careers');
    });
  });

  group('the preview of the last message (messagePreview)', () {
    test('nothing, withdrawn, text, an attachment, records', () {
      expect(messagePreview(null, meId: meId), 'No messages yet');
      expect(messagePreview(msg('1', 'c', sarah, 'x', deleted: true), meId: meId), 'Message deleted');
      expect(messagePreview(msg('1', 'c', sarah, 'Hello\nthere'), meId: meId), 'Hello there');
      expect(messagePreview(msg('1', 'c', sarah, '', attachment: 'Quote.pdf'), meId: meId), 'Quote.pdf');
      expect(messagePreview(msg('1', 'c', sarah, 'https://icr.org.in/jobs/J1'), meId: meId), 'Shared a record');
      expect(
        messagePreview(msg('1', 'c', sarah, 'https://icr.org.in/jobs/J1\nhttps://icr.org.in/events/e1'), meId: meId),
        'Shared 2 records',
      );
    });

    test('your side\'s last word: "You:", and a colleague by first name from a company inbox', () {
      expect(messagePreview(msg('1', 'c', me, 'On my way'), meId: meId), 'You: On my way');
      final colleague = msg('2', 'c', priya, 'Quote sent', company: globalInfra);
      expect(messagePreview(colleague, meId: meId, asCompanyId: 'co-gi'), 'Priya: Quote sent');
      expect(messagePreview(colleague, meId: meId), 'Quote sent', reason: 'to the other side it is simply theirs');
    });
  });

  group('shared records (recordLinks)', () {
    final origins = recordOrigins('https://icr.org.in');

    test('each of the six pages is one record', () {
      const cases = {
        'https://icr.org.in/jobs/J1': RecordRef(RecordType.job, 'J1'),
        'https://icr.org.in/rfq/R9': RecordRef(RecordType.requirement, 'R9'),
        'https://icr.org.in/companies/co-1': RecordRef(RecordType.company, 'co-1'),
        'https://icr.org.in/products/PR1': RecordRef(RecordType.product, 'PR1'),
        'https://icr.org.in/mentorship/mentors/MP1': RecordRef(RecordType.mentor, 'MP1'),
        'https://icr.org.in/events/summit-design': RecordRef(RecordType.event, 'summit-design'),
        'https://www.icr.org.in/jobs/J1/': RecordRef(RecordType.job, 'J1'),
      };
      for (final e in cases.entries) {
        expect(parseRecordLink(e.key, origins), e.value, reason: e.key);
      }
      expect(RecordRef(RecordType.event, 'a b').path, '/events/a%20b');
    });

    test('anything else is not a record: another site, a list page, a query, a fragment, a relative path', () {
      for (final raw in [
        'https://example.com/jobs/J1',
        'https://icr.org.in/jobs',
        'https://icr.org.in/jobs/J1?x=1',
        'https://icr.org.in/jobs/J1#top',
        '/jobs/J1',
        'not a link',
        'https://icr.org.in/jobs/J1/edit',
      ]) {
        expect(parseRecordLink(raw, origins), isNull, reason: raw);
      }
    });

    test(
      'a line that is only a link leaves the text and becomes a card; one in a sentence stays and gets a card too',
      () {
        final r = splitRecordLinks(
          'Look at this\nhttps://icr.org.in/jobs/J1\nand see https://icr.org.in/events/e1, please',
          origins,
        );
        expect(r.text, 'Look at this\nand see https://icr.org.in/events/e1, please');
        expect(r.records, [const RecordRef(RecordType.job, 'J1'), const RecordRef(RecordType.event, 'e1')]);
      },
    );

    test('the same record twice is one card; no records leaves the text whole', () {
      expect(splitRecordLinks('https://icr.org.in/jobs/J1\nhttps://icr.org.in/jobs/J1', origins).records, hasLength(1));
      final plain = splitRecordLinks('Just words.\n\nAnd more.', origins);
      expect(plain.text, 'Just words.\n\nAnd more.');
      expect(plain.records, isEmpty);
    });

    test('links in a text are found for tapping, trailing punctuation excluded by the caller', () {
      expect(linksIn('see https://a.com/x. and http://b.org').map((m) => m.group(0)), [
        'https://a.com/x.',
        'http://b.org',
      ]);
    });
  });

  group('where each piece of context opens', () {
    test('a requirement is three pages by who looks', () {
      expect(requirementHref('R1', Perspective.owner), '/manage/requirements/R1');
      expect(requirementHref('R1', Perspective.supplier), '/manage/bids/R1');
      expect(requirementHref('R1', Perspective.other), '/rfq/R1');
      expect(bidHref('R1', Perspective.supplier), '/manage/bids/R1');
      expect(bidHref('R1', Perspective.owner), '/manage/requirements/R1');
    });

    test('each page is one the notification router knows', () {
      expect(NotificationTarget.parse(requirementHref('R1', Perspective.owner)).kind, NotificationKinds.rfqOwner);
      expect(NotificationTarget.parse(requirementHref('R1', Perspective.supplier)).kind, NotificationKinds.rfqSupplier);
      expect(NotificationTarget.parse(requirementHref('R1', Perspective.other)).kind, NotificationKinds.rfqPublic);
      expect(NotificationTarget.parse(mentorshipHref('M1')).kind, NotificationKinds.mentorshipPairing);
      expect(NotificationTarget.parse(groupSessionHref('G1')).kind, NotificationKinds.mentorshipGroupSession);
      expect(NotificationTarget.parse(companyHref('co-1')).kind, NotificationKinds.companyPage);
      expect(NotificationTarget.parse(memberHref('u1')).kind, NotificationKinds.member);
      expect(NotificationTarget.parse(consultationHref(buyer: true)).kind, NotificationKinds.mentorshipMine);
      expect(NotificationTarget.parse(consultationHref(buyer: false)).kind, NotificationKinds.mentorDesk);
    });
  });

  group('the strip under the header (contextStripModel)', () {
    ConversationContext requirement({
      String perspective = 'OWNER',
      ContextBid? bid,
      String status = 'PUBLISHED',
      DateTime? due,
      String kind = 'ENQUIRY',
    }) => ConversationContext(
      kind: ConversationKind.requirement,
      perspective: perspective == 'OWNER' ? Perspective.owner : Perspective.supplier,
      requirement: ContextRequirement(
        id: 'R1',
        title: 'Annual Housekeeping',
        kind: kind,
        status: status,
        location: 'Mumbai',
        dueDate: due,
      ),
      bid: bid,
    );

    test('a requirement names itself, where the reader stands on it, and opens the page for their side', () {
      final m = contextStripModel(requirement(due: DateTime(2026, 11, 4)), null, now: now)!;
      expect((m.title, m.href), ('Annual Housekeeping', '/manage/requirements/R1'));
      expect(m.facts, ['Enquiry', 'Mumbai', 'Closes 4 Nov']);
      expect(m.lines, (line: 'Enquiry · Mumbai · Closes 4 Nov', name: 'Annual Housekeeping'));

      final supplier = contextStripModel(
        requirement(perspective: 'SUPPLIER', kind: 'RFQ'),
        null,
        now: now,
      )!;
      expect(supplier.href, '/manage/bids/R1');
      expect(supplier.facts.first, 'RFQ');
    });

    test('a reply or a bid replaces the deadline: theirs or yours, the amount, awarded', () {
      expect(
        contextStripModel(
          requirement(bid: const ContextBid(amount: 485000, status: 'PENDING', awarded: false, mine: false)),
          null,
          now: now,
        )!.facts.last,
        'They replied · ₹4,85,000',
      );
      expect(
        contextStripModel(
          requirement(bid: const ContextBid(status: 'PENDING', awarded: false, mine: true)),
          null,
          now: now,
        )!.facts.last,
        'You replied',
      );
      expect(
        contextStripModel(
          requirement(bid: const ContextBid(status: 'AWARDED', awarded: true, mine: true)),
          null,
          now: now,
        )!.facts.last,
        'Awarded',
      );
    });

    test('a shut or past requirement reads Closed', () {
      expect(contextStripModel(requirement(status: 'CLOSED'), null, now: now)!.facts.last, 'Closed');
      expect(contextStripModel(requirement(due: DateTime(2026, 10, 1)), null, now: now)!.facts.last, 'Closed');
    });

    test('a mentorship: its topics, the next session or how many have been held; it opens the pairing', () {
      final next = contextStripModel(
        ConversationContext(
          kind: ConversationKind.mentorship,
          mentorship: ContextMentorship(
            id: 'M1',
            mentee: true,
            mentorProfileId: 'MP',
            sessionsCount: 3,
            topics: const ['IGBC', 'Net-zero', 'Other'],
            nextSessionAt: DateTime(2026, 10, 27, 11),
          ),
        ),
        null,
        now: now,
      )!;
      expect(next.title, 'IGBC, Net-zero');
      expect(next.facts, ['Mentoring', 'Next session Tue, 27 Oct, 11:00 am']);
      expect(next.href, '/mentorship/my/M1');
      final held = contextStripModel(
        const ConversationContext(
          kind: ConversationKind.mentorship,
          mentorship: ContextMentorship(id: 'M1', mentee: false, mentorProfileId: 'MP', sessionsCount: 1),
        ),
        null,
        now: now,
      )!;
      expect(held.facts, ['Mentoring', '1 session']);
    });

    test(
      'a room and a consultation name themselves; a titled direct thread says "About"; a plain one has no strip',
      () {
        final room = contextStripModel(
          ConversationContext(
            kind: ConversationKind.groupSession,
            groupSession: ContextGroupSession(id: 'G1', title: 'BMS Clinic', nextAt: DateTime(2026, 10, 30, 18, 30)),
          ),
          null,
          now: now,
        )!;
        expect((room.title, room.href), ('BMS Clinic', '/mentorship/groups/G1'));
        expect(room.facts, ['Group session', 'Next session Fri, 30 Oct, 6:30 pm']);
        final consult = contextStripModel(
          const ConversationContext(
            kind: ConversationKind.consultation,
            consultation: ContextConsultation(id: 'P1', title: 'CV review', buyer: true, oneOnOne: false),
          ),
          null,
          now: now,
        )!;
        expect(consult.href, '/mentorship/my?tab=purchases');
        final titled = contextStripModel(
          const ConversationContext(kind: ConversationKind.direct),
          'Senior Facilities Manager · Global Infra',
          now: now,
        )!;
        expect(titled.title, 'Senior Facilities Manager · Global Infra');
        expect(titled.facts, ['About']);
        expect(titled.href, isNull);
        expect(contextStripModel(const ConversationContext(kind: ConversationKind.direct), null, now: now), isNull);
        expect(contextStripModel(null, null, now: now), isNull);
      },
    );
  });

  group('the openers an empty thread offers, and its introduction', () {
    test(
      'a supplier asks about the work, the buying team about the offer, a mentee and a mentor about their next session',
      () {
        ConversationContext ctx(Perspective p) => ConversationContext(
          kind: ConversationKind.requirement,
          perspective: p,
          requirement: const ContextRequirement(id: 'R', title: 'T', kind: 'RFQ', status: 'PUBLISHED'),
        );
        expect(starters(ctx(Perspective.supplier)).map((s) => s.key), ['stillOpen', 'siteVisit', 'shareScope']);
        expect(starters(ctx(Perspective.owner)).map((s) => s.key), ['shareQuote', 'whenStart', 'references']);
        expect(starters(ctx(Perspective.other)), isEmpty);
        const mentee = ConversationContext(
          kind: ConversationKind.mentorship,
          mentorship: ContextMentorship(id: 'M', mentee: true, mentorProfileId: 'P', sessionsCount: 0),
        );
        const mentor = ConversationContext(
          kind: ConversationKind.mentorship,
          mentorship: ContextMentorship(id: 'M', mentee: false, mentorProfileId: 'P', sessionsCount: 0),
        );
        expect(starters(mentee).map((s) => s.key), ['menteeNext', 'menteeGoals']);
        expect(starters(mentor).map((s) => s.key), ['mentorNext', 'mentorGoals']);
        expect(starters(const ConversationContext(kind: ConversationKind.direct)), isEmpty);
        expect(starters(null), isEmpty);
      },
    );

    test('the introduction says what the thread is for', () {
      expect(introText(null), 'No messages yet — say hello.');
      expect(
        introText(const ConversationContext(kind: ConversationKind.mentorship)),
        contains('agree how you would like to work together'),
      );
      expect(
        introText(
          ConversationContext(
            kind: ConversationKind.requirement,
            perspective: Perspective.supplier,
            requirement: const ContextRequirement(id: 'R', title: 'T', kind: 'RFQ', status: 'PUBLISHED'),
          ),
        ),
        contains('before you reply'),
      );
    });
  });

  group('business events drawn across the timeline (eventLine)', () {
    final enquiry = ConversationContext(
      kind: ConversationKind.enquiry,
      perspective: Perspective.owner,
      requirement: const ContextRequirement(id: 'R1', title: 'T', kind: 'ENQUIRY', status: 'PUBLISHED'),
    );
    final rfq = ConversationContext(
      kind: ConversationKind.bid,
      perspective: Perspective.supplier,
      requirement: const ContextRequirement(id: 'R1', title: 'T', kind: 'RFQ', status: 'PUBLISHED'),
    );

    test('an enquiry reply and a bid: whose, the amount, and where "View …" goes for the reader', () {
      final reply = eventLine(ThreadEvent(id: '1', type: 'BID_SUBMITTED', at: now, amount: 485000), enquiry);
      expect(
        (reply.title, reply.action, reply.href),
        ('They replied · ₹4,85,000', 'View reply', '/manage/requirements/R1'),
      );
      final mine = eventLine(ThreadEvent(id: '1', type: 'BID_SUBMITTED', at: now, mine: true), rfq);
      expect((mine.title, mine.action, mine.href), ('Your bid submitted', 'View bid', '/manage/bids/R1'));
    });

    test('a purchase order, a mentorship and its sessions, a consultation', () {
      expect(
        eventLine(ThreadEvent(id: '1', type: 'PURCHASE_ORDER', at: now, label: 'PO-17'), rfq).title,
        'Purchase order PO-17 issued',
      );
      const m = ConversationContext(
        kind: ConversationKind.mentorship,
        mentorship: ContextMentorship(id: 'M1', mentee: true, mentorProfileId: 'P', sessionsCount: 1),
      );
      expect(eventLine(ThreadEvent(id: '1', type: 'MENTORSHIP_STARTED', at: now), m).href, '/mentorship/my/M1');
      expect(
        eventLine(ThreadEvent(id: '1', type: 'SESSION_HELD', at: now, label: 'Goal setting'), m).title,
        'Session held: Goal setting',
      );
      const c = ConversationContext(
        kind: ConversationKind.consultation,
        consultation: ContextConsultation(id: 'P1', title: 'CV', buyer: false, oneOnOne: false),
      );
      expect(
        eventLine(ThreadEvent(id: '1', type: 'CONSULTATION_ANSWERED', at: now), c).href,
        '/mentorship/mentor?tab=work',
      );
      expect(eventLine(ThreadEvent(id: '1', type: 'CONSULTATION_OPENED', at: now), c).title, 'Consultation opened');
    });

    test('an unknown event is its label, with no action; a known one with no context has no link', () {
      final unknown = eventLine(
        ThreadEvent(id: '1', type: 'SOMETHING_NEW', at: now, label: 'Something happened'),
        null,
      );
      expect((unknown.title, unknown.action, unknown.href), ('Something happened', null, null));
      expect(eventLine(ThreadEvent(id: '1', type: 'BID_SUBMITTED', at: now), null).href, isNull);
    });
  });

  group('the list\'s filters as the API is asked for them', () {
    test('the excluded-pinned flag follows the website: the person\'s own All tab, no kind, no search', () {
      expect(const ConversationQuery().excludePinned, isTrue);
      expect(const ConversationQuery(filter: InboxFilter.unread).excludePinned, isFalse);
      expect(const ConversationQuery(kind: InboxKind.direct).excludePinned, isFalse);
      expect(const ConversationQuery(search: 'sa').excludePinned, isFalse);
      expect(const ConversationQuery(inbox: 'co-acme').excludePinned, isFalse);
    });
  });
}
