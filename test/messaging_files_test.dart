import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/widgets/chips.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/messaging/attachment_picker.dart';
import 'package:icr_mobile/features/messaging/conversation_screen.dart';
import 'package:icr_mobile/features/messaging/messaging_launcher.dart';
import 'package:icr_mobile/features/messaging/messaging_models.dart';
import 'package:icr_mobile/features/messaging/widgets/message_bubble.dart';
import 'package:icr_mobile/features/notifications/notification_router.dart';
import 'package:provider/provider.dart';

import 'helpers/fonts.dart';
import 'messaging_fakes.dart';

/// The paperclip (a photo or a file: refused by size and kind, uploaded, held
/// in the box, sent, opened by the other side), shared ICR records (a card read
/// through the record's own endpoint, "Share an ICR record", a link in a
/// sentence) and the phone's own picker. What the API does with each call:
/// `test/live/messaging_live_test.dart`.
void main() {
  setUpAll(loadAppFonts);

  /// A 1x1 transparent PNG.
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  );

  late FakeMessagingRepository repo;
  late List<String> routed;
  late List<({String name, int bytes})> opened;

  PickedAttachment file(String name, {int bytes = 2048, int? declared, Uint8List? data}) => PickedAttachment(
    name: name,
    bytes: data ?? Uint8List(bytes),
    mimeType: attachmentMimeFor(name),
    declaredSize: declared,
  );

  FakeMessagingRepository seeded({List<ChatMessage>? thread}) => FakeMessagingRepository(
    rows: [convo('sarah')],
    threads: {
      'sarah': thread ?? [msg('s1', 'sarah', sarah, 'Hello', ago: 60, read: true)],
    },
    contexts: {'sarah': const ConversationContext(kind: ConversationKind.direct, person: sarah)},
  );

  Future<void> pump(
    WidgetTester tester, {
    FakeMessagingRepository? repository,
    AttachmentPicker? picker,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repo = repository ?? seeded();
    routed = [];
    opened = [];
    await tester.pumpWidget(
      Provider<NotificationRouter>.value(
        value: NotificationRouter(
          openSite: (context, path) async => routed.add('site $path'),
          openers: {
            for (final k in const ['job', 'company.page', 'rfq.public', 'event', 'mentor.profile', 'product'])
              k: (context, t) {
                routed.add('${t.kind} ${t.params}');
                return true;
              },
          },
        ),
        child: MaterialApp(
          theme: buildAppTheme(),
          home: ConversationScreen(
            conversationId: 'sarah',
            repository: repo,
            pickAttachment: picker,
            poll: false,
            clock: () => testNow,
            openAttachment: (context, message, bytes) async =>
                opened.add((name: message.attachmentName ?? '', bytes: bytes.length)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder text(String t) => find.text(t, findRichText: true);
  Finder composer() => find.byKey(const ValueKey('composer'));
  Finder attach() => find.byKey(const ValueKey('attach'));

  group('the paperclip', () {
    testWidgets('is not drawn when the app has no picker', (tester) async {
      final saved = MessagingLauncher.attachmentPicker;
      MessagingLauncher.attachmentPicker = null;
      addTearDown(() => MessagingLauncher.attachmentPicker = saved);
      await pump(tester);
      expect(attach(), findsNothing);
    });

    testWidgets('the phone\'s own picker is the default (the app has file_picker)', (tester) async {
      expect(MessagingLauncher.attachmentPicker, isNotNull);
      await pump(tester);
      expect(attach(), findsOneWidget);
    });

    testWidgets('a picked file is uploaded, held in the box with its name and size, and sent with the message', (
      tester,
    ) async {
      await pump(tester, picker: (context) async => file('Site checklist.pdf', bytes: 84 * 1024));
      await tester.tap(attach());
      await tester.pumpAndSettle();
      expect(repo.uploads.single.name, 'Site checklist.pdf');
      expect(repo.calls.any((c) => c.startsWith('upload Site checklist.pdf')), isTrue);
      final bar = find.byKey(const ValueKey('attachment-bar'));
      expect(bar, findsOneWidget);
      expect(find.descendant(of: bar, matching: find.text('Site checklist.pdf')), findsOneWidget);
      expect(find.descendant(of: bar, matching: find.text('84 KB')), findsOneWidget);

      await tester.enterText(composer(), 'Here it is');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pumpAndSettle();
      final sent = repo.sent.single;
      expect(sent.body, 'Here it is');
      expect(sent.attachmentUrl, startsWith('/uploads/up-'));
      expect(find.byKey(const ValueKey('attachment-bar')), findsNothing, reason: 'the bar goes with the send');
      expect(find.text('Site checklist.pdf'), findsOneWidget, reason: 'now on the message, as a file row');
    });

    testWidgets('a file alone is a message (no words needed)', (tester) async {
      await pump(tester, picker: (context) async => file('Quote.pdf'));
      await tester.tap(attach());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pumpAndSettle();
      expect(repo.sent.single.body, '');
      expect(repo.sent.single.attachmentUrl, isNotNull);
    });

    testWidgets('a file over 10 MB is refused by size before anything is uploaded', (tester) async {
      await pump(tester, picker: (context) async => file('Huge.pdf', bytes: 0, declared: 11 * 1024 * 1024));
      await tester.tap(attach());
      await tester.pumpAndSettle();
      expect(find.text('That file is over 10 MB.'), findsOneWidget);
      expect(repo.uploads, isEmpty);
      expect(find.byKey(const ValueKey('attachment-bar')), findsNothing);
    });

    testWidgets('a kind the API would refuse is refused first, with the kinds that are allowed', (tester) async {
      await pump(tester, picker: (context) async => file('setup.exe'));
      await tester.tap(attach());
      await tester.pumpAndSettle();
      expect(find.text("That kind of file can't be sent. Send a photo, a PDF or an Office document."), findsOneWidget);
      expect(repo.uploads, isEmpty);
    });

    testWidgets('an upload the API refuses says why and leaves the box as it was', (tester) async {
      final repository = seeded()..errors['upload'] = ApiError('Files of this type are not allowed.', statusCode: 400);
      await pump(tester, repository: repository, picker: (context) async => file('Quote.pdf'));
      await tester.tap(attach());
      await tester.pumpAndSettle();
      expect(find.text("The file couldn't be uploaded. Files of this type are not allowed."), findsOneWidget);
      expect(find.byKey(const ValueKey('attachment-bar')), findsNothing);
    });

    testWidgets('no connection: the plain offline sentence, not a code', (tester) async {
      final repository = seeded()
        ..errors['upload'] = ApiError("Can't reach ICR right now. Check your connection and try again.");
      await pump(tester, repository: repository, picker: (context) async => file('Quote.pdf'));
      await tester.tap(attach());
      await tester.pumpAndSettle();
      expect(find.text("Can't reach ICR right now. Check your connection and try again."), findsOneWidget);
    });

    testWidgets('while it uploads the box says so, and Send and the paperclip wait', (tester) async {
      final repository = seeded();
      final gate = Completer<void>();
      repository.holds['upload'] = gate;
      await pump(tester, repository: repository, picker: (context) async => file('Quote.pdf'));
      await tester.tap(attach());
      await tester.pump();
      expect(find.text('Uploading Quote.pdf…'), findsOneWidget);
      expect(tester.widget<IconButton>(attach()).onPressed, isNull);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Uploading Quote.pdf…'), findsNothing);
      expect(find.byKey(const ValueKey('attachment-bar')), findsOneWidget);
    });

    testWidgets('removing the file from the box sends nothing of it', (tester) async {
      await pump(tester, picker: (context) async => file('Quote.pdf'));
      await tester.tap(attach());
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: find.byKey(const ValueKey('attachment-bar')), matching: find.byTooltip('Remove')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('attachment-bar')), findsNothing);
      await tester.enterText(composer(), 'Never mind the file');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pumpAndSettle();
      expect(repo.sent.single.attachmentUrl, isNull);
    });

    testWidgets('choosing nothing changes nothing', (tester) async {
      await pump(tester, picker: (context) async => null);
      await tester.tap(attach());
      await tester.pumpAndSettle();
      expect(repo.uploads, isEmpty);
      expect(find.byKey(const ValueKey('attachment-bar')), findsNothing);
    });

    testWidgets('a refused send with a file puts the file back in the box on Discard', (tester) async {
      final repository = seeded()..errors['send'] = ApiError('Nope', statusCode: 400);
      await pump(tester, repository: repository, picker: (context) async => file('Quote.pdf'));
      await tester.tap(attach());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('attachment-bar')), findsNothing);
      expect(find.byKey(const ValueKey('pending-discard')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pending-discard')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('attachment-bar')), findsOneWidget);
    });
  });

  group('a file in the thread', () {
    testWidgets('shows as a row with its name and size; a tap reads it with the person\'s session and hands it over', (
      tester,
    ) async {
      final thread = [
        msg(
          'f1',
          'sarah',
          sarah,
          '',
          ago: 30,
          attachment: 'Site feasibility checklist.pdf',
          attachmentMime: 'application/pdf',
          attachmentSize: 1300,
        ),
      ];
      await pump(tester, repository: seeded(thread: thread));
      expect(find.text('Site feasibility checklist.pdf'), findsOneWidget);
      expect(find.text('1 KB'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('attachment-f1')));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('download /uploads/Site feasibility checklist.pdf'));
      expect(opened.single, (name: 'Site feasibility checklist.pdf', bytes: 3));
    });

    testWidgets('a file that cannot be read says so, with the API\'s reason', (tester) async {
      final thread = [
        msg(
          'f1',
          'sarah',
          sarah,
          '',
          ago: 30,
          attachment: 'Quote.pdf',
          attachmentMime: 'application/pdf',
          attachmentSize: 5000,
        ),
      ];
      final repository = seeded(thread: thread)
        ..errors['download'] = ApiError('The file is no longer available.', statusCode: 404);
      await pump(tester, repository: repository);
      await tester.tap(find.byKey(const ValueKey('attachment-f1')));
      await tester.pumpAndSettle();
      expect(find.text("The file couldn't be opened. The file is no longer available."), findsOneWidget);
      expect(opened, isEmpty);
    });

    testWidgets('a photo is drawn from its private bytes, and a tap opens it', (tester) async {
      final thread = [
        msg(
          'p1',
          'sarah',
          sarah,
          '',
          ago: 30,
          attachment: 'Plant room.png',
          attachmentMime: 'image/png',
          attachmentSize: 90000,
        ),
      ];
      final repository = seeded(thread: thread)..downloadAnswer = Uint8List.fromList(png);
      await pump(tester, repository: repository);
      // The picture decodes off the test clock.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(repository.calls.where((c) => c.startsWith('download')), hasLength(1));
      await tester.tap(find.byKey(const ValueKey('attachment-p1')));
      await tester.pumpAndSettle();
      expect(opened.single.name, 'Plant room.png');
    });

    testWidgets('a withdrawn message keeps no file', (tester) async {
      final thread = [msg('f1', 'sarah', sarah, '', ago: 30, attachment: 'Quote.pdf', deleted: true)];
      await pump(tester, repository: seeded(thread: thread));
      expect(find.text('Quote.pdf'), findsNothing);
      expect(find.text('This message was deleted'), findsOneWidget);
    });
  });

  group('the phone\'s picker', () {
    testWidgets('asks Photo or File, and gives the source the person chose to the picker', (tester) async {
      final asked = <AttachmentSource>[];
      AttachmentPicking.picker = (source) async {
        asked.add(source);
        return DeviceFile(name: 'IMG_1.jpg', length: 4, read: () async => Uint8List.fromList([1, 2, 3, 4]));
      };
      addTearDown(() => AttachmentPicking.picker = pickFromDevice);
      PickedAttachment? result;
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      unawaited(pickDeviceAttachment(context).then((v) => result = v));
      await tester.pumpAndSettle();
      expect(find.text('Photo'), findsOneWidget);
      expect(find.text('File'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('attach-photo')));
      await tester.pumpAndSettle();
      expect(asked, [AttachmentSource.photo]);
      expect(result!.name, 'IMG_1.jpg');
      expect(result!.mimeType, 'image/jpeg');
      expect(result!.bytes, [1, 2, 3, 4]);

      result = null;
      unawaited(pickDeviceAttachment(context).then((v) => result = v));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('attach-file')));
      await tester.pumpAndSettle();
      expect(asked.last, AttachmentSource.file);
    });

    testWidgets('dismissing the sheet, or choosing nothing, gives nothing', (tester) async {
      AttachmentPicking.picker = (source) async => null;
      addTearDown(() => AttachmentPicking.picker = pickFromDevice);
      PickedAttachment? result = file('x.pdf');
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      unawaited(pickDeviceAttachment(context).then((v) => result = v));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(result, isNull);

      result = file('x.pdf');
      unawaited(pickDeviceAttachment(context).then((v) => result = v));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('attach-file')));
      await tester.pumpAndSettle();
      expect(result, isNull, reason: 'the picker returned nothing');
    });

    test('a file over the limit is never read into memory; its size alone is carried', () async {
      var reads = 0;
      final big = await readAttachment(
        DeviceFile(
          name: 'Huge.pdf',
          length: 12 * 1024 * 1024,
          read: () async {
            reads++;
            return Uint8List(1);
          },
        ),
      );
      expect(reads, 0);
      expect(big!.size, 12 * 1024 * 1024);
      expect(big.bytes, isEmpty);
      final small = await readAttachment(DeviceFile(name: 'a.docx', read: () async => Uint8List.fromList([9, 9])));
      expect(small!.size, 2);
      expect(small.mimeType, 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
      expect(await readAttachment(null), isNull);
    });

    test('what a message may carry', () {
      expect(attachmentMimeFor('x.PDF'), 'application/pdf');
      expect(attachmentMimeFor('photo.JPG'), 'image/jpeg');
      expect(attachmentMimeFor('notes.txt'), 'text/plain');
      expect(attachmentMimeFor('setup.exe'), isNull);
      expect(attachmentMimeFor('noextension'), isNull);
      expect(
        attachmentMimeFor('x.bin', 'image/png'),
        'image/png',
        reason: 'a type the API knows, as the picker gave it',
      );
    });
  });

  group('shared records (a card, read through the record\'s own page)', () {
    final job = RecordFacts(
      type: RecordType.job,
      id: 'J1',
      title: 'Senior Facilities Manager for STP Plant',
      owner: 'CBRE South Asia',
      city: 'Mumbai',
    );

    FakeMessagingRepository withLink(String body) =>
        seeded(thread: [msg('r1', 'sarah', sarah, body, ago: 30)])
          ..recordAnswers[const RecordRef(RecordType.job, 'J1')] = job;

    testWidgets('a line that is only a link becomes a card: kind, title, owner and place; the link itself is gone', (
      tester,
    ) async {
      await pump(tester, repository: withLink('Look at this role\nhttps://icr.org.in/jobs/J1'));
      expect(find.text('JOB'), findsOneWidget);
      expect(find.text('Senior Facilities Manager for STP Plant'), findsOneWidget);
      expect(find.text('CBRE South Asia · Mumbai'), findsOneWidget);
      expect(text('Look at this role'), findsOneWidget);
      expect(find.textContaining('https://icr.org.in/jobs/J1'), findsNothing);
      expect(repo.calls, contains('record job/J1'));
    });

    testWidgets('a link inside a sentence stays a link and gets its card too', (tester) async {
      await pump(tester, repository: withLink('Have a look at https://icr.org.in/jobs/J1, it suits you.'));
      expect(find.text('Senior Facilities Manager for STP Plant'), findsOneWidget);
      expect(find.textContaining('https://icr.org.in/jobs/J1'), findsOneWidget);
    });

    testWidgets('a tap on the card opens the record in the app (the router), and on the link too', (tester) async {
      await pump(tester, repository: withLink('Have a look at https://icr.org.in/jobs/J1, it suits you.'));
      await tester.tap(find.byKey(const ValueKey('record-job-J1')));
      await tester.pumpAndSettle();
      expect(routed, ['job {jobId: J1}']);
      routed.clear();
      // The link in the sentence is tappable too.
      final rich = tester.widget<RichText>(
        find.descendant(of: find.byType(LinkedText), matching: find.byType(RichText)).first,
      );
      TapGestureRecognizer? tap;
      rich.text.visitChildren((span) {
        if (span is TextSpan && span.recognizer is TapGestureRecognizer) tap = span.recognizer as TapGestureRecognizer;
        return true;
      });
      tap!.onTap!();
      await tester.pumpAndSettle();
      expect(routed, ['job {jobId: J1}']);
    });

    testWidgets('a company, a requirement and an event open on their own pages', (tester) async {
      final r =
          seeded(
              thread: [
                msg(
                  'r1',
                  'sarah',
                  sarah,
                  'https://icr.org.in/companies/co-1\nhttps://icr.org.in/rfq/R9\nhttps://icr.org.in/events/summit-design',
                  ago: 30,
                ),
              ],
            )
            ..recordAnswers[const RecordRef(RecordType.company, 'co-1')] = const RecordFacts(
              type: RecordType.company,
              id: 'co-1',
              title: 'Global Infra Solutions',
              owner: 'Commercial real estate',
              city: 'Bengaluru',
            )
            ..recordAnswers[const RecordRef(RecordType.requirement, 'R9')] = RecordFacts(
              type: RecordType.requirement,
              id: 'R9',
              title: 'Annual Housekeeping',
              amount: 1250000,
              date: DateTime(2026, 11, 9),
            )
            ..recordAnswers[const RecordRef(RecordType.event, 'summit-design')] = RecordFacts(
              type: RecordType.event,
              id: 'summit-design',
              title: 'Smart Buildings Summit',
              owner: 'ICR Vinfraa Chapter',
              date: DateTime(2026, 11, 2),
            );
      await pump(tester, repository: r, size: const Size(390, 1200));
      expect(find.text('₹12,50,000 · 9 Nov'), findsOneWidget);
      expect(find.text('ICR Vinfraa Chapter · 2 Nov'), findsOneWidget);
      for (final key in ['record-company-co-1', 'record-requirement-R9', 'record-event-summit-design']) {
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
      }
      expect(routed, [
        'company.page {companyId: co-1}',
        'rfq.public {rfqId: R9}',
        'event {eventId: summit-design, slug: summit-design}',
      ]);
    });

    testWidgets('a record the reader may not see says so, and never leaks its title', (tester) async {
      final r = seeded(thread: [msg('r1', 'sarah', sarah, 'https://icr.org.in/jobs/SECRET', ago: 30)]);
      await pump(tester, repository: r);
      expect(find.text("This job isn't available to you."), findsOneWidget);
    });

    testWidgets('no connection: "Couldn\'t load this job."', (tester) async {
      final r = seeded(thread: [msg('r1', 'sarah', sarah, 'https://icr.org.in/jobs/J1', ago: 30)])
        ..errors['record'] = ApiError("Can't reach ICR right now.");
      await pump(tester, repository: r);
      expect(find.text("Couldn't load this job."), findsOneWidget);
    });

    testWidgets('while it loads the card shows its kind and a progress line', (tester) async {
      final r = withLink('https://icr.org.in/jobs/J1');
      final gate = Completer<void>();
      r.holds['record'] = gate;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ConversationScreen(conversationId: 'sarah', repository: r, poll: false, clock: () => testNow),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('a link to another site is just a link: no card, no record read', (tester) async {
      await pump(
        tester,
        repository: seeded(thread: [msg('r1', 'sarah', sarah, 'See https://example.com/jobs/J1', ago: 30)]),
      );
      expect(repo.calls.where((c) => c.startsWith('record')), isEmpty);
      expect(find.text('JOB'), findsNothing);
    });
  });

  group('"Share an ICR record" (the link beside the paperclip)', () {
    FakeMessagingRepository sharing() => seeded()
      ..searchRecordsAnswers[RecordType.job] = [
        const RecordFacts(
          type: RecordType.job,
          id: 'J1',
          title: 'Senior Facilities Manager',
          owner: 'CBRE South Asia',
          city: 'Mumbai',
        ),
        const RecordFacts(type: RecordType.job, id: 'J2', title: 'Energy Lead', owner: 'Global Infra'),
      ]
      ..searchRecordsAnswers[RecordType.company] = [
        const RecordFacts(
          type: RecordType.company,
          id: 'co-1',
          title: 'Global Infra Solutions',
          owner: 'Real estate',
          city: 'Bengaluru',
        ),
      ]
      ..searchRecordsAnswers[RecordType.event] = [
        const RecordFacts(type: RecordType.event, id: 'summit-design', title: 'Smart Buildings Summit'),
      ];

    Future<void> openPicker(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('share-record')));
      await tester.pumpAndSettle();
    }

    /// The kinds run sideways and build as they scroll in: at the app's text sizes the last ones are past the edge.
    Future<void> scrollToKind(WidgetTester tester, RecordType t) async {
      // The chip row is the scrollable around the kind chips that are built (always some of them).
      final row = find.ancestor(of: find.byType(IcrChip), matching: find.byType(Scrollable)).first;
      await tester.scrollUntilVisible(find.byKey(ValueKey('picker-${t.name}')), 80, scrollable: row);
      await tester.pumpAndSettle();
    }

    testWidgets('opens on Jobs, lists what the API gives, and the six kinds are one tap away', (tester) async {
      await pump(tester, repository: sharing());
      await openPicker(tester);
      expect(find.text('Share an ICR record'), findsOneWidget);
      expect(repo.calls, contains('searchRecords job ""'));
      expect(find.text('Senior Facilities Manager'), findsOneWidget);
      expect(find.text('CBRE South Asia · Mumbai'), findsOneWidget);
      for (final t in RecordType.values) {
        await scrollToKind(tester, t);
        expect(find.byKey(ValueKey('picker-${t.name}')), findsOneWidget);
      }
    });

    testWidgets('choosing a row puts the record\'s link in the box on its own line; sending carries it', (
      tester,
    ) async {
      await pump(tester, repository: sharing());
      await tester.enterText(composer(), 'Take a look');
      await openPicker(tester);
      await tester.tap(find.byKey(const ValueKey('picker-row-J1')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(composer()).controller!.text, 'Take a look\nhttps://icr.org.in/jobs/J1');
      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pumpAndSettle();
      expect(repo.sent.single.body, 'Take a look\nhttps://icr.org.in/jobs/J1');
    });

    testWidgets('an empty box takes just the link', (tester) async {
      await pump(tester, repository: sharing());
      await openPicker(tester);
      await tester.tap(find.byKey(const ValueKey('picker-row-J2')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(composer()).controller!.text, 'https://icr.org.in/jobs/J2');
    });

    testWidgets('another kind searches that kind; an event is linked by its slug', (tester) async {
      await pump(tester, repository: sharing());
      await openPicker(tester);
      await tester.tap(find.byKey(const ValueKey('picker-company')));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('searchRecords company ""'));
      expect(find.text('Global Infra Solutions'), findsOneWidget);
      await scrollToKind(tester, RecordType.event);
      await tester.tap(find.byKey(const ValueKey('picker-event')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('picker-row-summit-design')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(composer()).controller!.text, 'https://icr.org.in/events/summit-design');
    });

    testWidgets('typing searches a moment after the person pauses', (tester) async {
      await pump(tester, repository: sharing());
      await openPicker(tester);
      await tester.enterText(find.byKey(const ValueKey('picker-search')), 'energy');
      await tester.pump(const Duration(milliseconds: 200));
      expect(repo.calls.where((c) => c.contains('"energy"')), isEmpty);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('searchRecords job "energy"'));
    });

    testWidgets('nothing found, and a failure with Retry', (tester) async {
      final r = sharing()..searchRecordsAnswers[RecordType.product] = const [];
      await pump(tester, repository: r);
      await openPicker(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('picker-product')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('picker-product')));
      await tester.pumpAndSettle();
      expect(find.text('Nothing found'), findsOneWidget);

      r.errors['searchRecords'] = ApiError('The server is busy.', statusCode: 503);
      r.searchRecordsAnswers[RecordType.mentor] = const [
        RecordFacts(type: RecordType.mentor, id: 'MP1', title: 'Rajesh Sharma', owner: 'VP Facility Ops', years: 14),
      ];
      await tester.ensureVisible(find.byKey(const ValueKey('picker-mentor')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('picker-mentor')));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't load these."), findsOneWidget);
      expect(find.text('The server is busy.'), findsOneWidget);
      r.errors.remove('searchRecords');
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Rajesh Sharma'), findsOneWidget);
      expect(find.text('VP Facility Ops · 14 yrs experience'), findsOneWidget);
    });

    testWidgets('closing the sheet without choosing leaves the box alone', (tester) async {
      await pump(tester, repository: sharing());
      await tester.enterText(composer(), 'draft');
      await openPicker(tester);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(composer()).controller!.text, 'draft');
    });
  });
}
