/// The COMPANY inbox in Messaging, for the company accounts, against the LOCAL portal API: a company is a party to
/// a thread (not a snapshot of its staff), and who reads which topic is worked out on every request from the
/// member's role. Each test goes through the app's own `ApiMessagingRepository`, as the inbox and conversation
/// screens do, and reads every effect back.
///
/// The thread starters are the Inbox Persona (Anita Rao, `tool/seed/inbox.ts`, a member outside the company) and
/// Bluepeak's seller (the RFQ seed). Threads are one per member, company and topic, so a run reuses them and
/// leaves no new thread behind; every message a test sends is withdrawn at its end (a withdrawn message stays as a
/// blank row, which the inbox seed clears).
///
///     flutter test --no-pub test/live/role_company_inbox_live_test.dart --concurrency=1
@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/messaging/api_messaging_repository.dart';
import 'package:icr_mobile/features/messaging/messaging_models.dart';
import 'package:icr_mobile/features/messaging/messaging_repository.dart';
import 'package:icr_mobile/features/rfq/supplier_controllers.dart';
import 'package:icr_mobile/features/rfq/api_rfq_repository.dart';
import 'package:icr_mobile/features/rfq/rfq_rules.dart' show BidDraft;

import 'live.dart';
import 'role_company_support.dart';

Future<ApiMessagingRepository> _repo(LivePerson who) async => ApiMessagingRepository(api: await liveClient(who));

Future<int?> _refusedWith(Future<Object?> call) async {
  try {
    await call;
    return null;
  } catch (e) {
    return ApiError.from(e).statusCode;
  }
}

/// The company's id, read the way the inbox switcher reads it.
Future<String> _companyId() async {
  final inboxes = await (await _repo(companyAdmin)).inboxes();
  return inboxes.firstWhere((i) => !i.personal).id;
}

Future<List<String>> _ids(ApiMessagingRepository repo, ConversationQuery q) async => [
  for (final c in (await repo.conversations(q)).conversations) c.id,
];

void main() {
  group('who has which inbox', () {
    companyTest(
      'each account\'s switcher: its own messages, and the company\'s with the topics its role answers',
      () async {
        const all = ['SALES', 'PROCUREMENT', 'CAREERS', 'PARTNERSHIP', 'GENERAL'];
        final expected = <LivePerson, List<String>?>{
          companyAdmin: all,
          founder: all,
          marketBuyer: all,
          branchAdmin: ['CAREERS'],
          recruiter: ['CAREERS'],
          marketNoPhone: ['PROCUREMENT'],
          hiringManager: null, // an interview panelist answers for no inbox: the switcher does not appear
        };
        for (final entry in expected.entries) {
          final inboxes = await (await _repo(entry.key)).inboxes();
          expect(inboxes.first.personal, isTrue, reason: entry.key.label);
          final companyInboxes = inboxes.where((i) => !i.personal).toList();
          if (entry.value == null) {
            expect(companyInboxes, isEmpty, reason: entry.key.label);
          } else {
            expect(companyInboxes, hasLength(1), reason: entry.key.label);
            expect(companyInboxes.single.topics, unorderedEquals(entry.value!), reason: entry.key.label);
            expect(companyInboxes.single.name, isNotEmpty, reason: entry.key.label);
          }
        }
      },
    );
  });

  group('writing to a company, and answering as it', () {
    companyTest(
      'a member writes to the company on two topics: each member of the team reads only the topics their role takes',
      () async {
        final company = await _companyId();
        final anita = await _repo(outsider);
        final careers = await anita.startWithCompany(
          company,
          'CAREERS',
          message: 'Role test: is the Pune post still open?',
        );
        final sales = await anita.startWithCompany(
          company,
          'SALES',
          message: 'Role test: can you quote for a site visit?',
        );
        expect(careers, isNot(sales), reason: 'one thread per member, company and topic');
        expect(await anita.startWithCompany(company, 'CAREERS'), careers, reason: 'the same thread again');
        addTearDown(() async {
          for (final conv in [careers, sales]) {
            final mine = await anita.thread(conv);
            for (final m in mine.messages.where((m) => m.body.startsWith('Role test') && !m.deleted)) {
              try {
                await anita.deleteMessage(conv, m.id);
              } catch (_) {}
            }
          }
        });

        final q = ConversationQuery(inbox: company);
        // The admins take every topic.
        for (final who in [companyAdmin, founder]) {
          final repo = await _repo(who);
          final ids = await _ids(repo, q);
          expect(ids, containsAll([careers, sales]), reason: who.label);
          final byTopic = await repo.conversations(q.copyWith(topic: 'SALES'));
          expect(byTopic.conversations.every((c) => c.myParty?.topic == 'SALES'), isTrue, reason: who.label);
          expect(byTopic.conversations.map((c) => c.id), contains(sales));
          expect(byTopic.conversations.map((c) => c.id), isNot(contains(careers)));
        }
        // The office admin and the recruiter take careers, and are never shown sales.
        for (final who in [branchAdmin, recruiter]) {
          final repo = await _repo(who);
          final ids = await _ids(repo, q);
          expect(ids, contains(careers), reason: who.label);
          expect(ids, isNot(contains(sales)), reason: '${who.label}: sales is not their topic');
          expect(await _refusedWith(repo.thread(sales, asCompanyId: company)), isIn([403, 404]), reason: who.label);
          final window = await repo.thread(careers, asCompanyId: company);
          expect(window.conversation.asCompanyId, company, reason: who.label);
          expect(window.messages.any((m) => m.body.startsWith('Role test')), isTrue, reason: who.label);
        }
        // The hiring manager has no company inbox at all; nor does the buyer take careers or sales.
        final hm = await _repo(hiringManager);
        expect(await _ids(hm, q).then((v) => v, onError: (_) => <String>[]), isNot(contains(careers)));
        for (final conv in [careers, sales]) {
          expect(
            await _refusedWith(hm.thread(conv, asCompanyId: company)),
            isIn([403, 404]),
            reason: 'hiring manager $conv',
          );
        }
        final buyer = await _repo(marketNoPhone);
        expect(await _refusedWith(buyer.thread(careers, asCompanyId: company)), isIn([403, 404]));
        // The member sees both in their own inbox.
        final theirs = await _ids(anita, const ConversationQuery());
        expect(theirs, containsAll([careers, sales]));
      },
    );

    companyTest(
      'the recruiter answers as the company; the member sees the company, the colleague sees a reply to take',
      () async {
        final company = await _companyId();
        final anita = await _repo(outsider);
        final thread = await anita.startWithCompany(company, 'CAREERS', message: 'Role test: when can I interview?');
        final asked = (await anita.thread(
          thread,
        )).messages.lastWhere((m) => m.body == 'Role test: when can I interview?');
        final rc = await _repo(recruiter);
        final ba = await _repo(branchAdmin);
        final ca = await _repo(companyAdmin);
        final ids = <String>[asked.id];
        addTearDown(() async {
          try {
            await anita.deleteMessage(thread, asked.id);
          } catch (_) {}
          try {
            await rc.deleteMessage(thread, ids.last);
          } catch (_) {}
        });

        // Unread for the company until someone opens it; the member's message is the other side's.
        expect((await ca.unreadCount()).companies[company], greaterThan(0));
        await rc.markRead(thread, asCompanyId: company);

        final reply = await rc.send(
          thread,
          body: 'Role test: Friday at 11, the recruiter will call.',
          asCompanyId: company,
        );
        ids.add(reply.id);
        expect(reply.senderCompany?.id, company, reason: 'sent as the company');
        // The member reads it from the company; the colleagues read it as the company's own words.
        final seen = (await anita.thread(thread)).messages.firstWhere((m) => m.id == reply.id);
        expect(seen.senderCompany?.id, company);
        expect(seen.body, contains('Friday at 11'));
        for (final repo in [ba, ca]) {
          final w = await repo.thread(thread, asCompanyId: company);
          expect(w.messages.map((m) => m.id), contains(reply.id));
        }
        // The company\'s list names the last word and whose it is.
        final row = (await ca.conversations(
          ConversationQuery(inbox: company),
        )).conversations.firstWhere((c) => c.id == thread);
        expect(row.myParty!.topic, 'CAREERS');
        expect(row.asCompanyId, company);

        // Sorting the thread is the team\'s: assign to me, done, spam, back to open; each is kept and put back.
        final me = await ca.viewerId();
        addTearDown(() async {
          await ca.updateCompanyThread(thread, companyId: company, status: ThreadStatus.open);
          await ca.updateCompanyThread(thread, companyId: company, unassign: true);
        });
        final assigned = await ca.updateCompanyThread(thread, companyId: company, assigneeId: me);
        expect(assigned.assignee!.id, me);
        final mineView = ConversationQuery(inbox: company, view: CompanyInboxView.mine);
        expect(await _ids(ca, mineView), contains(thread));
        expect(await _ids(rc, mineView), isNot(contains(thread)), reason: 'it is the admin\'s, not the recruiter\'s');
        final done = await ba.updateCompanyThread(thread, companyId: company, status: ThreadStatus.done);
        expect(done.status, ThreadStatus.done, reason: 'the office admin sorts careers too');
        expect(await _ids(ca, ConversationQuery(inbox: company, view: CompanyInboxView.done)), contains(thread));
        expect(await _ids(ca, ConversationQuery(inbox: company)), isNot(contains(thread)));
        await ba.updateCompanyThread(thread, companyId: company, status: ThreadStatus.open);
        expect(await _ids(ca, ConversationQuery(inbox: company)), contains(thread));
        // The hiring manager cannot sort a company\'s thread, and the member cannot write as the company.
        expect(
          await _refusedWith(
            (await _repo(hiringManager)).updateCompanyThread(thread, companyId: company, status: ThreadStatus.spam),
          ),
          isIn([403, 404]),
        );
        expect(
          await _refusedWith(anita.send(thread, body: 'Role test: as the company?', asCompanyId: company)),
          isIn([403, 404]),
        );
      },
    );

    companyTest(
      'a bidder\'s message about a requirement is the buying team\'s: procurement reads it, careers and the panel do not',
      () async {
        final company = await _companyId();
        final posted = await postRequirement(companyAdmin);
        final blue = OpportunityController(
          repository: ApiRfqRepository(api: await liveClient(bluepeak)),
          rfqId: posted.id,
        );
        await blue.start();
        expect(await blue.placeBid(BidDraft()..message = 'Role test: we can start next week.'), isNull);
        final thread = (await blue.messageBuyer()).id!;
        final blueRepo = await _repo(bluepeak);
        final said = await blueRepo.send(thread, body: 'Role test: shall we visit the site on Monday?');
        addTearDown(() async {
          try {
            await blueRepo.deleteMessage(thread, said.id);
          } catch (_) {}
        });

        final q = ConversationQuery(inbox: company);
        // Both admins take procurement.
        for (final who in [companyAdmin, founder]) {
          final repo = await _repo(who);
          final ids = await _ids(repo, q);
          expect(ids, contains(thread), reason: who.label);
          final row = (await repo.conversations(q)).conversations.firstWhere((c) => c.id == thread);
          expect(row.myParty!.topic, 'PROCUREMENT', reason: who.label);
          expect(row.kind, anyOf(ConversationKind.requirement, ConversationKind.enquiry), reason: who.label);
          final ctx = await repo.context(thread, asCompanyId: company);
          expect(ctx!.perspective, Perspective.owner, reason: who.label);
        }
        // Not careers, not the panel.
        for (final who in [branchAdmin, recruiter]) {
          expect(await _ids(await _repo(who), q), isNot(contains(thread)), reason: who.label);
        }
        expect(await _refusedWith((await _repo(hiringManager)).thread(thread, asCompanyId: company)), isIn([403, 404]));
        // The buyer person (a different company\'s BUYER) cannot read this one\'s either.
        expect(await _refusedWith((await _repo(marketNoPhone)).thread(thread, asCompanyId: company)), isIn([403, 404]));

        // The buying team answers as the company, and the supplier reads it from the buyer company.
        final reply = await (await _repo(
          companyAdmin,
        )).send(thread, body: 'Role test: Monday works.', asCompanyId: company);
        addTearDown(() async {
          try {
            await (await _repo(companyAdmin)).deleteMessage(thread, reply.id);
          } catch (_) {}
        });
        final back = (await blueRepo.thread(thread)).messages.firstWhere((m) => m.id == reply.id);
        expect(back.senderCompany?.id, company);
      },
    );

    companyTest(
      'a BUYER takes procurement: he reads the requirement threads of his company, and writes as it',
      () async {
        final posted = await postRequirement(marketBuyer, expectCompany: 'Meridian Corporate Estates');
        final blue = OpportunityController(
          repository: ApiRfqRepository(api: await liveClient(bluepeak)),
          rfqId: posted.id,
        );
        await blue.start();
        expect(await blue.placeBid(BidDraft()..message = 'Role test: a bid for Meridian.'), isNull);
        final thread = (await blue.messageBuyer()).id!;
        final blueRepo = await _repo(bluepeak);
        final said = await blueRepo.send(thread, body: 'Role test: can we meet this week?');
        addTearDown(() async {
          try {
            await blueRepo.deleteMessage(thread, said.id);
          } catch (_) {}
        });
        final nikhil = await _repo(marketNoPhone);
        final inbox = (await nikhil.inboxes()).firstWhere((i) => !i.personal);
        expect(inbox.topics, ['PROCUREMENT']);
        final q = ConversationQuery(inbox: inbox.id);
        expect(await _ids(nikhil, q), contains(thread));
        expect(await _ids(await _repo(marketBuyer), q), contains(thread));
        final row = (await nikhil.conversations(q)).conversations.firstWhere((c) => c.id == thread);
        expect(row.myParty!.topic, 'PROCUREMENT');
        final reply = await nikhil.send(thread, body: 'Role test: Thursday, 3 pm.', asCompanyId: inbox.id);
        addTearDown(() async {
          try {
            await nikhil.deleteMessage(thread, reply.id);
          } catch (_) {}
        });
        expect(reply.senderCompany?.id, inbox.id);
        // The switcher offers him one topic chip, so a topic he does not take is never asked for.
        expect(inbox.topics, hasLength(1));
      },
    );
  });
}
