/// A stateful fake of what the Offerings panel reads and writes (`/mentor-services/mine`,
/// `/mentor-plans`, `/mentorship/group-sessions`, `/uploads`), in the shapes the real API answers with
/// (each fixture was checked against a live call): a write changes what the next read says, so a
/// test proves the effect, and `api.requests` records what was sent.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/features/mentor_desk/offerings/offerings_files.dart';
import 'package:icr_mobile/features/mentor_desk/offerings/offerings_panel.dart';
import 'package:icr_mobile/features/mentor_desk/offerings/offerings_repository.dart';

import 'mentoring_fakes.dart';

final offeringsNow = DateTime(2026, 10, 26, 10);

Map<String, Object?> serviceJson(
  String id, {
  String type = 'ONE_ON_ONE',
  String title = 'Career clarity call',
  String? blurb = 'A call to map where you are.',
  int price = 0,
  int? compareAt,
  int? duration = 30,
  int? seats,
  String? fileName,
  int? fileSize,
  bool active = true,
  int sales = 0,
  double rating = 0,
  int ratingCount = 0,
  String? coverUrl,
}) => {
  'id': id,
  'mentorProfileId': 'mp-anand',
  'type': type,
  'title': title,
  'blurb': blurb,
  'coverUrl': coverUrl,
  'durationMin': duration,
  'seats': seats,
  'pricePaisa': price,
  'compareAtPaisa': compareAt,
  'currency': 'INR',
  'slaHours': null,
  'fileName': fileName,
  'fileSize': fileSize,
  'active': active,
  'sortOrder': 10,
  'salesCount': sales,
  'rating': rating,
  'ratingCount': ratingCount,
  'isBestSeller': sales >= 5,
  'nextGroupSession': null,
  'createdAt': iso(offeringsNow),
};

Map<String, Object?> planJson(
  String id, {
  String kind = 'RECURRING',
  String title = 'Monthly leadership coaching',
  String? blurb,
  int price = 299900,
  int? compareAt,
  int billing = 1,
  int perMonth = 2,
  int? sessionMin = 45,
  int? access,
  List<String> inclusions = const [],
  List<Map<String, Object?>> modules = const [],
  bool active = true,
  int subscribers = 0,
}) => {
  'id': id,
  'mentorProfileId': 'mp-anand',
  'title': title,
  'blurb': blurb,
  'coverUrl': null,
  'kind': kind,
  'pricePaisa': price,
  'compareAtPaisa': compareAt,
  'currency': 'INR',
  'billingPeriodMonths': billing,
  'sessionsPerMonth': kind == 'CURRICULUM' ? 0 : perMonth,
  'sessionDurationMin': sessionMin,
  'totalSessions': kind == 'CURRICULUM' ? modules.length : null,
  'accessMonths': access,
  'inclusions': inclusions,
  'active': active,
  'sortOrder': 0,
  'subscribersCount': subscribers,
  'perMonthPaisa': price,
  'modules': modules,
};

Map<String, Object?> moduleJson(int position, String title, {String? outline, int? minutes = 60}) => {
  'id': 'mod-$position',
  'position': position,
  'title': title,
  'outline': outline,
  'durationMin': minutes,
};

Map<String, Object?> hostedJson(
  String id, {
  String title = 'From site to portfolio: an open clinic',
  String status = 'SCHEDULED',
  DateTime? at,
  int minutes = 60,
  String mode = 'VIDEO',
  int? capacity = 25,
  int taken = 0,
  int waiting = 0,
  int? price,
  String? link = 'https://meet.google.com/icr-demo',
  String? location,
  String? summary = 'An hour on how to frame a portfolio case.',
  List<Map<String, Object?>>? occurrences,
  String? cancelReason,
  List<Map<String, Object?>>? attendees,
}) {
  final start = at ?? offeringsNow.add(const Duration(days: 6));
  return {
    'id': id,
    'title': title,
    'summary': summary,
    'coverUrl': '/uploads/cover.jpg',
    'scheduledAt': iso(start),
    'durationMin': minutes,
    'occurrences':
        occurrences ??
        [
          {
            'id': '$id-occ1',
            'seq': 1,
            'title': null,
            'scheduledAt': iso(start),
            'durationMin': minutes,
            'status': status == 'COMPLETED' ? 'COMPLETED' : (status == 'CANCELLED' ? 'CANCELLED' : 'SCHEDULED'),
            'completedAt': null,
            'cancelledAt': null,
          },
        ],
    'occurrenceCount': occurrences?.length ?? 1,
    'mode': mode,
    'location': location,
    'locationLat': null,
    'locationLng': null,
    'timezone': 'Asia/Kolkata',
    'status': status,
    'capacity': capacity,
    'seatsTaken': taken,
    'seatsLeft': capacity == null ? null : capacity - taken,
    'waitlistCount': waiting,
    'focusAreas': ['Career transitions'],
    'competencies': ['Career transitions'],
    'host': anand,
    'programId': null,
    'programName': null,
    'myStatus': null,
    'pricePaisa': price,
    'serviceId': null,
    'agendaHtml': '<p>Bring a real case.</p><p>We start with scope.</p>',
    'meetingLink': link,
    'cancelReason': cancelReason,
    'completedAt': null,
    'attendees': attendees ?? <Map<String, Object?>>[],
    'rosterScope': 'host',
    'rosterHiddenCount': 0,
    'isHost': true,
    'canRegister': false,
    'seatForSale': false,
    'blockedReason': 'You are hosting this session.',
    'conversationId': null,
  };
}

Map<String, Object?> attendeeJson(
  String id,
  String first,
  String last, {
  String status = 'REGISTERED',
  String? question,
}) => {
  'id': id,
  'user': {'id': 'u-$id', 'firstName': first, 'lastName': last, 'avatarUrl': null, 'companyName': null},
  'status': status,
  'question': question,
  'registeredAt': iso(offeringsNow),
  'minutesCredited': null,
};

class OfferingsWorld {
  OfferingsWorld({
    this.optedIn = true,
    this.accepted = '2026.1',
    this.suspended = false,
    String? blockedReason,
    List<Map<String, Object?>>? services,
    List<Map<String, Object?>>? plans,
    List<Map<String, Object?>>? sessions,
  }) : services =
           services ??
           [
             serviceJson('svc-discovery'),
             serviceJson(
               'svc-strategy',
               title: 'Strategy session',
               price: 149900,
               compareAt: 199900,
               duration: 45,
               sales: 4,
             ),
           ],
       plans = plans ?? [planJson('plan-coaching')],
       sessions = sessions ?? [hostedJson('grp-clinic', taken: 3)],
       _blockedReason = blockedReason;

  bool optedIn;
  String? accepted;
  bool suspended;
  final String? _blockedReason;
  List<Map<String, Object?>> services;
  List<Map<String, Object?>> plans;
  List<Map<String, Object?>> sessions;
  final String current = '2026.1';
  int _n = 0;

  /// The gate state as the API words it (`storefrontState`).
  bool get live => !suspended && optedIn && accepted == current;

  String? get blockedReason {
    if (_blockedReason != null) return _blockedReason;
    if (suspended) return 'Your storefront is suspended. Contact the ICR team.';
    if (!optedIn || accepted != current) return 'Accept the seller terms to open your storefront.';
    return null;
  }

  Map<String, Object?> get storefront => {
    'optedIn': optedIn,
    'termsAcceptedVersion': accepted,
    'termsCurrentVersion': current,
    'suspended': suspended,
    'live': live,
    'blockedReason': live ? null : blockedReason,
    'services': services,
  };

  Map<String, Object?> _row(List<Map<String, Object?>> rows, String id) => rows.firstWhere((r) => r['id'] == id);

  Map<String, Reply> routes() {
    final out = <String, Reply>{
      'GET /mentor-services/mine': (_) => storefront,
      'POST /mentor-services/mine/terms': (o) {
        final b = o.data as Map<String, dynamic>;
        if (b['version'] != current) {
          return refuse('That is not the current seller terms version ($current). Reload and read them again.');
        }
        optedIn = true;
        accepted = current;
        return storefront;
      },
      'POST /mentor-services/mine': (o) {
        final b = o.data as Map<String, dynamic>;
        final s = serviceJson(
          'new-${++_n}',
          type: b['type'] as String,
          title: b['title'] as String,
          blurb: b['blurb'] as String?,
          price: b['pricePaisa'] as int,
          compareAt: b['compareAtPaisa'] as int?,
          duration: b['durationMin'] as int?,
          seats: b['seats'] as int?,
          fileName: b['fileName'] as String?,
          fileSize: b['fileSize'] as int?,
          active: b['active'] == true,
          coverUrl: b['coverUrl'] as String?,
        );
        services = [...services, s];
        return s;
      },
      'GET /mentor-plans/mine': (_) => plans,
      'POST /mentor-plans': (o) {
        final b = o.data as Map<String, dynamic>;
        final programme = b['kind'] == 'CURRICULUM';
        final mods = [
          for (final (i, m) in ((b['modules'] as List?) ?? const []).indexed)
            moduleJson(
              i + 1,
              (m as Map)['title'] as String,
              outline: m['outline'] as String?,
              minutes: m['durationMin'] as int?,
            ),
        ];
        final p = planJson(
          'newp-${++_n}',
          kind: b['kind'] as String,
          title: b['title'] as String,
          blurb: b['blurb'] as String?,
          price: b['pricePaisa'] as int,
          compareAt: b['compareAtPaisa'] as int?,
          billing: (programme ? b['accessMonths'] : b['billingPeriodMonths']) as int? ?? 1,
          perMonth: (b['sessionsPerMonth'] as int?) ?? 0,
          sessionMin: b['sessionDurationMin'] as int?,
          access: programme ? b['accessMonths'] as int? : null,
          inclusions: ((b['inclusions'] as List?) ?? const []).cast<String>(),
          modules: mods,
          active: b['active'] == true,
        );
        plans = [...plans, p];
        return p;
      },
      'GET /mentorship/group-sessions': (_) => page(sessions),
      'POST /mentorship/group-sessions': (o) {
        final b = o.data as Map<String, dynamic>;
        final occ = (b['occurrences'] as List).cast<Map<String, dynamic>>();
        final s = hostedJson(
          'newg-${++_n}',
          title: b['title'] as String,
          status: b['publish'] == true ? 'SCHEDULED' : 'DRAFT',
          at: DateTime.parse(occ.first['scheduledAt'] as String),
          minutes: occ.first['durationMin'] as int,
          mode: b['mode'] as String,
          capacity: b['capacity'] as int?,
          price: b['pricePaisa'] as int?,
          link: b['meetingLink'] as String?,
          location: b['location'] as String?,
          summary: b['summary'] as String?,
          occurrences: [
            for (final (i, d) in occ.indexed)
              {
                'id': 'newg-$_n-occ${i + 1}',
                'seq': i + 1,
                'title': d['title'],
                'scheduledAt': d['scheduledAt'],
                'durationMin': d['durationMin'],
                'status': 'SCHEDULED',
                'completedAt': null,
                'cancelledAt': null,
              },
          ],
        );
        sessions = [...sessions, s];
        return s;
      },
    };
    for (final id in ['svc-discovery', 'svc-strategy', 'svc-resource', 'svc-seat', 'svc-query', 'new-1', 'new-2']) {
      out['PATCH /mentor-services/mine/$id'] = (o) {
        final b = o.data as Map<String, dynamic>;
        final row = _row(services, id);
        row
          ..['title'] = b['title']
          ..['blurb'] = b['blurb']
          ..['pricePaisa'] = b['pricePaisa']
          ..['compareAtPaisa'] = b['compareAtPaisa']
          ..['durationMin'] = b['durationMin']
          ..['seats'] = b['seats']
          ..['active'] = b['active'] ?? row['active'];
        if (b.containsKey('coverUrl')) row['coverUrl'] = b['coverUrl'];
        if (b['fileName'] != null) {
          row
            ..['fileName'] = b['fileName']
            ..['fileSize'] = b['fileSize'];
        }
        return row;
      };
      out['DELETE /mentor-services/mine/$id'] = (_) {
        services = services.where((r) => r['id'] != id).toList();
        return {'status': 'retired'};
      };
    }
    for (final id in ['plan-coaching', 'plan-programme', 'newp-1', 'newp-2']) {
      out['PATCH /mentor-plans/$id'] = (o) {
        final b = o.data as Map<String, dynamic>;
        final row = _row(plans, id);
        for (final k in [
          'title',
          'blurb',
          'pricePaisa',
          'compareAtPaisa',
          'active',
          'inclusions',
          'sessionDurationMin',
          'sessionsPerMonth',
        ]) {
          if (b.containsKey(k)) row[k] = b[k];
        }
        if (b['modules'] != null) {
          row['modules'] = [
            for (final (i, m) in (b['modules'] as List).indexed)
              moduleJson(
                i + 1,
                (m as Map)['title'] as String,
                outline: m['outline'] as String?,
                minutes: m['durationMin'] as int?,
              ),
          ];
          row['totalSessions'] = (b['modules'] as List).length;
        }
        if (b['accessMonths'] != null) row['accessMonths'] = b['accessMonths'];
        return row;
      };
      out['DELETE /mentor-plans/$id'] = (_) {
        plans = plans.where((r) => r['id'] != id).toList();
        return {'status': 'retired'};
      };
    }
    for (final id in ['grp-clinic', 'grp-draft', 'grp-paid', 'grp-past', 'newg-1', 'newg-2']) {
      out['GET /mentorship/group-sessions/$id'] = (_) => _row(sessions, id);
      out['PATCH /mentorship/group-sessions/$id'] = (o) {
        final b = o.data as Map<String, dynamic>;
        final row = _row(sessions, id);
        row
          ..['title'] = b['title']
          ..['summary'] = b['summary']
          ..['mode'] = b['mode']
          ..['meetingLink'] = b['meetingLink']
          ..['location'] = b['location']
          ..['capacity'] = b['capacity']
          ..['pricePaisa'] = b['pricePaisa'];
        if (b['publish'] == true) row['status'] = 'SCHEDULED';
        return row;
      };
      out['POST /mentorship/group-sessions/$id/publish'] = (_) => _row(sessions, id)..['status'] = 'SCHEDULED';
      out['POST /mentorship/group-sessions/$id/cancel'] = (o) {
        _row(sessions, id)
          ..['status'] = 'CANCELLED'
          ..['cancelReason'] = (o.data as Map)['reason'];
        return {'status': 'cancelled'};
      };
      out['POST /mentorship/group-sessions/$id/complete'] = (o) {
        _row(sessions, id)['status'] = 'COMPLETED';
        return _row(sessions, id);
      };
    }
    out['POST /uploads'] = (o) => {
      'url': '/uploads/${o.queryParameters['purpose']}-stored.pdf',
      'name': 'probe.pdf',
      'size': 69,
      'mimeType': 'application/pdf',
    };
    return out;
  }

  FakeApi api({Map<String, Reply> extra = const {}}) => FakeApi({...routes(), ...extra});
}

/// A file the "phone" hands the panel.
PickedUpload pdfFile({String name = 'guide.pdf', int bytes = 69}) =>
    PickedUpload(bytes: Uint8List.fromList(List.filled(bytes, 37)), name: name, mimeType: mimeOfName(name));

Future<(FakeApi, LinkRecorder)> pumpOfferings(
  WidgetTester tester,
  OfferingsWorld world, {
  Map<String, Reply> extra = const {},
  OfferingFilePicker? pickFile,
  double height = 16000,
  List<String>? changes,
}) async {
  phone(tester, height: height);
  final api = world.api(extra: extra);
  final rec = LinkRecorder();
  await pumpApp(
    tester,
    Scaffold(
      body: OfferingsPanel(
        api: api.client(),
        links: rec.links,
        pickFile: pickFile ?? ({required bool imageOnly}) async => pdfFile(name: imageOnly ? 'cover.png' : 'guide.pdf'),
        onChanged: () => changes?.add('changed'),
      ),
    ),
  );
  return (api, rec);
}

/// A client built over [api] for a repository-level test.
ApiClient clientOf(FakeApi api) => api.client();

// --- helpers for the panel's widget tests -----------------------------------------

Finder inRow(String key, String text) => find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(text));

Finder inDialog(String text) => find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

Future<void> tapText(WidgetTester tester, String text, {int index = 0}) async {
  final f = find.text(text).at(index);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await settle(tester);
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await settle(tester);
}

Future<void> tapIn(WidgetTester tester, String key, String text) async {
  final f = inRow(key, text);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await settle(tester);
}

Future<void> typeKey(WidgetTester tester, String key, String text) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.enterText(f, text);
  await tester.pump();
}

/// Taps a form's submit button (the label also appears in the form's title or the list behind it).
Future<void> submit(WidgetTester tester, String label) async {
  final f = find.text(label).last;
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await settle(tester);
}
