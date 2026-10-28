import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/notifications/notification_router.dart';
import 'package:icr_mobile/features/notifications/notification_target.dart';
import 'package:provider/provider.dart';

/// The router every notification, and every ICR link a message carries, goes
/// through: the screens that own a record register an opener for its kind; what
/// no opener takes opens on the website exactly as the API stored it.
void main() {
  late List<String> site;
  late List<String> opened;
  late BuildContext context;

  NotificationRouter router({Map<String, NotificationOpener>? openers}) =>
      NotificationRouter(openers: openers, openSite: (c, path) async => site.add(path));

  NotificationOpener takes(String label, {bool answer = true}) => (c, t) {
    opened.add('$label ${t.kind} ${t.params}');
    return answer;
  };

  Future<void> pumpContext(WidgetTester tester, [NotificationRouter? provided]) async {
    site = [];
    opened = [];
    Widget app = MaterialApp(
      home: Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
    );
    if (provided != null) app = Provider<NotificationRouter>.value(value: provided, child: app);
    await tester.pumpWidget(app);
  }

  testWidgets('a registered opener takes its kind, with the ids the page named, and the website is not asked', (
    tester,
  ) async {
    await pumpContext(tester);
    final r = router(openers: {NotificationKinds.job: takes('jobs')});
    await r.openHref(context, '/jobs/J1?referredBy=U9');
    expect(opened, ['jobs job {jobId: J1, referredBy: U9}']);
    expect(site, isEmpty);
  });

  testWidgets('a kind nobody registered for opens the page on the website, as the API stored it', (tester) async {
    await pumpContext(tester);
    final r = router(openers: {NotificationKinds.job: takes('jobs')});
    await r.openHref(context, '/manage/bids/R1?section=response');
    expect(opened, isEmpty);
    expect(site, ['/manage/bids/R1?section=response']);
  });

  testWidgets('an opener that returns false passes: the website takes it', (tester) async {
    await pumpContext(tester);
    final r = router(openers: {NotificationKinds.event: takes('events', answer: false)});
    await r.openHref(context, '/events/summit-design');
    expect(opened, ['events event {eventId: summit-design, slug: summit-design}']);
    expect(site, ['/events/summit-design']);
  });

  testWidgets('register, registerAll and unregister change who takes a kind, and registeredKinds lists them', (
    tester,
  ) async {
    await pumpContext(tester);
    final r = router();
    expect(r.registeredKinds, isEmpty);
    r.register(NotificationKinds.job, takes('first'));
    r.registerAll({NotificationKinds.event: takes('second'), NotificationKinds.member: takes('third')});
    expect(r.registeredKinds, containsAll([NotificationKinds.job, NotificationKinds.event, NotificationKinds.member]));
    r.register(NotificationKinds.job, takes('replaced'));
    await r.openHref(context, '/jobs/J1');
    expect(opened, ['replaced job {jobId: J1}']);
    r.unregister(NotificationKinds.job);
    await r.openHref(context, '/jobs/J1');
    expect(site, ['/jobs/J1']);
  });

  testWidgets('no page at all opens nothing, anywhere', (tester) async {
    await pumpContext(tester);
    final r = router(openers: {NotificationKinds.job: takes('jobs')});
    await r.open(context, NotificationTarget.parse(null));
    await r.openHref(context, '  ');
    expect(opened, isEmpty);
    expect(site, isEmpty);
  });

  testWidgets('a full link to the ICR site reads as its page', (tester) async {
    await pumpContext(tester);
    final r = router(openers: {NotificationKinds.job: takes('jobs')});
    await r.openHref(context, 'https://icr.org.in/jobs/J9');
    expect(opened, ['jobs job {jobId: J9}']);
  });

  testWidgets('the router the app provided is the one a screen finds; with none, a website-only one', (tester) async {
    final provided = router();
    await pumpContext(tester, provided);
    expect(NotificationRouter.of(context), same(provided));

    await pumpContext(tester);
    final fallback = NotificationRouter.of(context);
    expect(fallback, isNotNull);
    expect(NotificationRouter.of(context), same(fallback), reason: 'one shared fallback');
  });

  test('the kinds the router opens by itself (the app\'s own conversation, inbox and notifications screens)', () {
    expect(NotificationRouter.builtInKinds, {
      NotificationKinds.conversation,
      NotificationKinds.messaging,
      NotificationKinds.notifications,
    });
  });
}
