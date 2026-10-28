import 'package:dio/dio.dart' show Options;

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/config.dart';
import 'mentor_profile_format.dart';
import 'mentor_profile_models.dart';
import 'mentor_profile_repository.dart';

/// The Mentor Profile screens from the API: the public profile
/// (`GET /mentorship/mentors/:id`), the storefront
/// (`GET /mentor-services/mentors/:id`), the plans
/// (`GET /mentor-plans/by-mentor/:id`), the mentor's upcoming group sessions,
/// and the reviews behind the rating.
class ApiMentorProfileRepository implements MentorProfileRepository {
  ApiMentorProfileRepository({required this.api});

  final ApiClient api;

  @override
  Future<MentorProfile> profile(String mentorId) async => _profile(await _get('/mentorship/mentors/$mentorId'));

  @override
  Future<List<MentorOffering>> offerings(MentorProfile mentor) async {
    final results = await Future.wait([
      _quiet(() => _get('/mentor-services/mentors/${mentor.id}')),
      _quiet(() => api.dio.get<dynamic>('/mentor-plans/by-mentor/${mentor.id}').then((r) => r.data)),
      _quiet(() => _get('/mentorship/group-sessions', {'hostId': mentor.userId, 'limit': 6, 'page': 1})),
      // The viewer's own plan requests, so a programme asked for stays "Requested" after a reload.
      _quiet(() => api.dio.get<dynamic>('/mentor-plans/subscriptions/mine').then((r) => r.data)),
    ]);
    final storefront = results[0] as Map<String, dynamic>? ?? const {};
    final services = storefront['live'] == true
        ? (storefront['services'] as List? ?? const []).cast<Map<String, dynamic>>()
        : const <Map<String, dynamic>>[];
    final plans = (results[1] as List? ?? const []).cast<Map<String, dynamic>>();
    final groups = ((results[2] as Map<String, dynamic>?)?['data'] as List? ?? const []).cast<Map<String, dynamic>>();
    final waiting = {
      for (final sub in (results[3] as List? ?? const []).whereType<Map<String, dynamic>>())
        if (sub['status'] == 'PENDING_MENTOR' || sub['status'] == 'PENDING_PAYMENT') sub['planId'] as String: sub['id'],
    };

    final singles = <MentorOffering>[];
    final resources = <MentorOffering>[];
    final queries = <MentorOffering>[];
    for (final s in services) {
      final offering = _service(s, mentor);
      if (offering == null) continue;
      switch (offering.kind) {
        case OfferingKind.oneOnOne:
          singles.add(offering);
        case OfferingKind.resource:
          resources.add(offering);
        case OfferingKind.query:
          queries.add(offering);
        default:
          break;
      }
    }
    final programs = [
      for (final p in plans.where((p) => p['kind'] == 'CURRICULUM'))
        _plan(p, mentor, waitingId: waiting[p['id']] as String?),
    ];
    final recurring = [for (final p in plans.where((p) => p['kind'] != 'CURRICULUM')) _plan(p, mentor)];
    final now = DateTime.now();
    final sessions = [
      for (final g in groups)
        if (g['status'] == 'SCHEDULED' && (_date(g['scheduledAt'])?.isAfter(now) ?? false)) _group(g),
    ];
    // A programme is the 1:1 mentoring on offer; a single session follows it, as the design lists them.
    return [...programs, ...singles, ...recurring, ...resources, ...queries, ...sessions];
  }

  @override
  Future<List<MentorReview>> reviews(MentorProfile mentor) async {
    final results = await Future.wait([
      _quiet(() => api.dio.get<dynamic>('/mentorship/testimonials').then((r) => r.data)),
      _quiet(() => api.dio.get<dynamic>('/mentorship/mentors/${mentor.id}/feedback').then((r) => r.data)),
    ]);
    final testimonials = (results[0] as List? ?? const []).cast<Map<String, dynamic>>();
    final feedback = (results[1] as List? ?? const []).cast<Map<String, dynamic>>();
    return [
      for (final t in testimonials.where((t) => t['mentorProfileId'] == mentor.id))
        MentorReview(
          id: 't-${t['id']}',
          name: t['authorName'] as String? ?? 'A mentee',
          subline: t['authorTitle'] as String? ?? 'Mentee',
          photo: _picture(t['avatarUrl'] as String?),
          // A curated testimonial has no rating of its own: it reads with the
          // mentor's (5.0 → five stars). A date shows once the API sends one.
          rating: mentor.ratingCount > 0 ? mentor.rating.round().clamp(1, 5) : null,
          quote: t['quote'] as String? ?? '',
          createdAt: _date(t['createdAt']),
        ),
      for (final f in feedback.where((f) => (f['comment'] as String?)?.trim().isNotEmpty ?? false))
        MentorReview(
          id: 'f-${f['id']}',
          name: 'A mentee',
          subline: 'Mentee',
          rating: (f['rating'] as num?)?.toInt(),
          quote: f['comment'] as String,
          createdAt: _date(f['createdAt']),
        ),
    ];
  }

  @override
  Future<int> unreadNotifications() async {
    final res = await _get('/notifications/unread-count');
    return (res['unread'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<bool> hasPhone() async {
    final me = await _get('/auth/me');
    final user = (me['user'] as Map<String, dynamic>?) ?? me;
    final phone = user['phone'] as String?;
    return phone != null && phone.trim().isNotEmpty;
  }

  @override
  Future<void> requestMentoring(MentorProfile mentor, {required String message, String? phone}) async {
    await _send('POST', '/mentorship/requests', {
      'mentorProfileId': mentor.id,
      'message': message.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
    });
  }

  @override
  Future<String?> openConversation(MentorProfile mentor) async {
    final id = mentor.viewer?.mentorshipId;
    if (id == null) return null;
    final res = await _send('POST', '/mentorship/$id/conversation');
    return (res as Map<String, dynamic>?)?['conversationId'] as String?;
  }

  @override
  Future<String?> requestSession(
    MentorOffering offering, {
    required String topic,
    required String mode,
    String? preferredTimes,
    String? phone,
  }) async {
    final res = await _send('POST', '/mentor-services/${offering.id}/request', {
      'topic': topic.trim(),
      'mode': mode,
      if (preferredTimes != null && preferredTimes.trim().isNotEmpty) 'preferredTimes': preferredTimes.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
    });
    return (res as Map<String, dynamic>?)?['id'] as String?;
  }

  @override
  Future<CheckoutOutcome> buy(MentorProfile mentor, MentorOffering offering, {String? phone}) async {
    final phoneBody = {if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim()};
    switch (offering.kind) {
      case OfferingKind.resource:
        if (!offering.free) {
          // Paid checkout (PayU) runs on the website; `?book=` opens this
          // service's checkout there.
          return CheckoutOutcome(
            CheckoutState.website,
            sitePath: '/mentorship/mentors/${mentor.id}?book=${offering.id}',
          );
        }
        await _send('POST', '/mentor-services/${offering.id}/checkout', const {});
        return const CheckoutOutcome(
          CheckoutState.completed,
          message: 'Added to your purchases. Download it from Purchases on the website.',
        );
      case OfferingKind.plan:
        if (!offering.free) {
          return CheckoutOutcome(CheckoutState.website, sitePath: '/mentorship/mentors/${mentor.id}');
        }
        final res = await _send('POST', '/mentor-plans/${offering.id}/subscribe', phoneBody) as Map<String, dynamic>?;
        final mentorshipId = res?['mentorshipId'] as String?;
        return CheckoutOutcome(
          CheckoutState.completed,
          message: 'You are on ${offering.title}. Schedule your first session on the website.',
          sitePath: mentorshipId == null ? '/mentorship/my' : '/mentorship/my/$mentorshipId',
        );
      case OfferingKind.program:
        await _send('POST', '/mentor-plans/${offering.id}/request', phoneBody);
        return CheckoutOutcome(
          CheckoutState.requested,
          message: 'Request sent. Once ${mentor.firstName} accepts, you pay on the website.',
          sitePath: '/mentorship/my?tab=purchases',
        );
      case OfferingKind.groupSession:
        return CheckoutOutcome(CheckoutState.website, sitePath: '/mentorship/groups/${offering.groupSessionId}');
      case OfferingKind.oneOnOne:
      case OfferingKind.query:
        throw StateError('A session is asked for with requestSession.');
    }
  }

  @override
  Uri link(MentorProfile mentor) => AppConfig.sitePage('/mentorship/mentors/${mentor.id}');

  // --- mapping -------------------------------------------------------------

  MentorProfile _profile(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? const {};
    final career = (json['career'] as Map<String, dynamic>?)?['currentRole'] as Map<String, dynamic>?;
    final viewerJson = json['viewer'] as Map<String, dynamic>?;
    final openSlots = (json['openSlots'] as num?)?.toInt() ?? 0;
    final modes = _strings(json['preferredModes']).map(_modeLabel).whereType<String>().toList();
    return MentorProfile(
      id: json['id'] as String,
      userId: user['id'] as String? ?? '',
      firstName: user['firstName'] as String? ?? '',
      lastName: user['lastName'] as String? ?? '',
      roleTitle: career?['title'] as String?,
      roleOrganisation: career?['organisation'] as String?,
      headline: json['headline'] as String?,
      bioHtml: json['bioHtml'] as String?,
      photo: _picture(user['avatarUrl'] as String?),
      cover: _cover(json['coverImage'] as String?),
      verified: json['status'] == 'APPROVED',
      yearsExperience: (json['yearsExperience'] as num?)?.toInt(),
      city: json['city'] as String?,
      modes: modes,
      modeKeys: _strings(json['preferredModes']),
      languages: _strings(json['languages']),
      competencies: _strings(json['competencies']),
      topics: _strings(json['topics']),
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
      stats: MentorStats(
        sessions: sessionsLabel((json['sessionsCompleted'] as num?)?.toInt() ?? 0),
        sessionsBadge: json['isTopMentor'] == true ? 'Top Mentor' : null,
        mentees: '${(json['menteesHelped'] as num?)?.toInt() ?? 0}',
        menteesNote: openSlots > 0 ? '$openSlots slot${openSlots == 1 ? '' : 's'} open' : 'At capacity',
      ),
      experience: [for (final r in (json['experience'] as List? ?? const []).cast<Map<String, dynamic>>()) _role(r)],
      education: [
        for (final e in (json['education'] as List? ?? const []).cast<Map<String, dynamic>>())
          MentorEducation(
            institution: e['institution'] as String? ?? '',
            degree: e['degree'] as String?,
            field: e['fieldOfStudy'] as String?,
            startYear: (e['startYear'] as num?)?.toInt(),
            endYear: (e['endYear'] as num?)?.toInt(),
          ),
      ],
      availability: [
        for (final b in (json['availabilityBlocks'] as List? ?? const []).cast<Map<String, dynamic>>())
          AvailabilityBlock(
            weekday: (b['weekday'] as num).toInt(),
            startMin: (b['startMin'] as num).toInt(),
            endMin: (b['endMin'] as num).toInt(),
          ),
      ],
      timezone: json['timezone'] as String? ?? 'Asia/Kolkata',
      viewer: viewerJson == null
          ? null
          : MentorViewer(
              isOwner: viewerJson['isOwner'] == true,
              canRequest: viewerJson['canRequest'] == true,
              blockedReason: viewerJson['blockedReason'] as String?,
              blocker: AskBlocker.fromApi(viewerJson['blocker'] as String?),
              mentorshipId: viewerJson['mentorshipId'] as String?,
              pendingRequestId: viewerJson['pendingRequestId'] as String?,
            ),
      openSlots: openSlots,
      capacity: (json['capacity'] as num?)?.toInt() ?? 0,
      yearsLabel: switch ((json['yearsExperience'] as num?)?.toInt()) {
        null || 0 => null,
        final n => n == 1 ? '1 Year Experience' : '$n+ Years Experience',
      },
    );
  }

  MentorRole _role(Map<String, dynamic> r) => MentorRole(
    title: r['title'] as String? ?? '',
    organisation: r['organisation'] as String? ?? '',
    organisationLinked: r['company'] is Map,
    startYear: (r['startYear'] as num?)?.toInt() ?? 0,
    startMonth: (r['startMonth'] as num?)?.toInt(),
    endYear: (r['endYear'] as num?)?.toInt(),
    endMonth: (r['endMonth'] as num?)?.toInt(),
    isCurrent: r['isCurrent'] == true,
    place: r['city'] as String?,
    description: r['description'] as String?,
  );

  /// A service row as the Offerings tab draws it; null for the kinds a buyer
  /// never sees here (a group seat is sold from the session's own page).
  MentorOffering? _service(Map<String, dynamic> s, MentorProfile mentor) {
    final type = s['type'] as String?;
    final price = (s['pricePaisa'] as num?)?.toInt() ?? 0;
    final duration = (s['durationMin'] as num?)?.toInt();
    final best = s['isBestSeller'] == true;
    final open = s['myOpenRequest'] as Map<String, dynamic>?;
    final base = (
      id: s['id'] as String,
      title: s['title'] as String? ?? '',
      blurb: s['blurb'] as String?,
      compareAt: (s['compareAtPaisa'] as num?)?.toInt(),
      rating: (s['rating'] as num?)?.toDouble() ?? 0,
      ratingCount: (s['ratingCount'] as num?)?.toInt() ?? 0,
      sales: (s['salesCount'] as num?)?.toInt() ?? 0,
      cover: _picture(s['coverUrl'] as String?),
      fileName: s['fileName'] as String?,
      openId: open?['purchaseId'] as String?,
      bookingAt: _date(s['myUpcomingBookingAt']),
    );
    final modeWord = mentor.modes.contains('Video') ? 'Video' : (mentor.modes.firstOrNull ?? 'Call');
    switch (type) {
      case 'ONE_ON_ONE':
        return MentorOffering(
          id: base.id,
          kind: OfferingKind.oneOnOne,
          title: base.title,
          blurb: base.blurb,
          pricePaisa: price,
          compareAtPaisa: base.compareAt,
          durationMin: duration,
          tags: [
            if (best) const OfferingTag('BEST SELLER'),
            // Beside the BEST SELLER pill the length stands alone, as the design draws it.
            OfferingTag(
              duration == null
                  ? '1:1 $modeWord'
                  : best
                  ? '$duration Min'
                  : '$duration Min • 1:1 $modeWord',
            ),
          ],
          ctaLabel: 'Book Now',
          isBestSeller: best,
          rating: base.rating,
          ratingCount: base.ratingCount,
          salesCount: base.sales,
          cover: base.cover,
          myOpenRequestId: base.openId,
          myUpcomingBookingAt: base.bookingAt,
          kicker: price == 0 ? 'FREE SESSION' : '1:1 SESSION',
          facts: [
            OfferingFact(glyph: OfferingGlyph.person, label: '1:1 $modeWord call'),
            if (duration != null) OfferingFact(glyph: OfferingGlyph.clock, label: '$duration Minutes'),
            OfferingFact(glyph: OfferingGlyph.calendar, label: slotDaysLabel(mentor.availability) ?? 'Any day'),
          ],
          details: [
            const OfferingDetail(
              glyph: OfferingGlyph.sessions,
              title: '1 Session',
              body: 'One live call; the mentor sets the time after accepting.',
            ),
            if (duration != null)
              OfferingDetail(
                glyph: OfferingGlyph.clock,
                title: '$duration Minutes',
                body: 'A focused one-to-one discussion.',
              ),
            OfferingDetail(
              glyph: OfferingGlyph.person,
              title: mentor.modes.isEmpty ? 'Any mode' : mentor.modes.join(' / '),
              body: 'How you meet, in the mentor\'s own hours.',
            ),
            const OfferingDetail(
              glyph: OfferingGlyph.chat,
              title: 'Private thread',
              body: 'Message the mentor around the session.',
            ),
          ],
        );
      case 'RESOURCE':
        final ext = base.fileName?.contains('.') ?? false ? base.fileName!.split('.').last.toUpperCase() : null;
        final kind = resourceTag(base.fileName);
        return MentorOffering(
          id: base.id,
          kind: OfferingKind.resource,
          title: base.title,
          blurb: base.blurb,
          pricePaisa: price,
          compareAtPaisa: base.compareAt,
          tags: [
            if (best) const OfferingTag('BEST SELLER'),
            OfferingTag(kind.label),
            if (kind.generic) const OfferingTag('Instant Download', green: true),
          ],
          ctaLabel: price == 0 ? 'Get Guide' : 'Purchase Guide',
          isBestSeller: best,
          rating: base.rating,
          ratingCount: base.ratingCount,
          salesCount: base.sales,
          cover: base.cover,
          fileName: base.fileName,
          kicker: 'RESOURCE',
          facts: [
            const OfferingFact(glyph: OfferingGlyph.download, label: 'Instant download'),
            if (base.fileName != null) OfferingFact(glyph: OfferingGlyph.list, label: base.fileName!),
          ],
          details: [
            const OfferingDetail(
              glyph: OfferingGlyph.download,
              title: 'Instant download',
              body: 'Yours as soon as the purchase clears.',
            ),
            OfferingDetail(
              glyph: OfferingGlyph.list,
              title: ext == null || ext.length > 5 ? 'One file' : '$ext file',
              body: base.fileName ?? 'Kept under Purchases on the website.',
            ),
          ],
        );
      case 'QUERY':
        final sla = (s['slaHours'] as num?)?.toInt() ?? 72;
        return MentorOffering(
          id: base.id,
          kind: OfferingKind.query,
          title: base.title,
          blurb: base.blurb,
          pricePaisa: price,
          compareAtPaisa: base.compareAt,
          tags: [OfferingTag('Async Query • ${sla}h TAT')],
          ctaLabel: 'Ask Query',
          rating: base.rating,
          ratingCount: base.ratingCount,
          salesCount: base.sales,
          cover: base.cover,
          slaHours: sla,
          myOpenRequestId: base.openId,
          kicker: 'WRITTEN CONSULTATION',
          facts: [
            const OfferingFact(glyph: OfferingGlyph.chat, label: 'Written answer'),
            OfferingFact(glyph: OfferingGlyph.clock, label: 'Within $sla hours'),
          ],
          details: [
            OfferingDetail(
              glyph: OfferingGlyph.clock,
              title: '$sla-hour answer',
              body: 'The mentor replies in a private thread.',
            ),
          ],
        );
      default:
        return null;
    }
  }

  MentorOffering _plan(Map<String, dynamic> p, MentorProfile mentor, {String? waitingId}) {
    final curriculum = p['kind'] == 'CURRICULUM';
    final price = (p['pricePaisa'] as num?)?.toInt() ?? 0;
    final modules = (p['modules'] as List? ?? const []).cast<Map<String, dynamic>>();
    final total = (p['totalSessions'] as num?)?.toInt() ?? modules.length;
    final perMonth = (p['sessionsPerMonth'] as num?)?.toInt() ?? 0;
    final duration = (p['sessionDurationMin'] as num?)?.toInt();
    final months = (p['billingPeriodMonths'] as num?)?.toInt() ?? 1;
    final access = (p['accessMonths'] as num?)?.toInt() ?? months;
    final title = p['title'] as String? ?? '';
    final subscribers = (p['subscribersCount'] as num?)?.toInt() ?? 0;
    final best = subscribers >= bestSellerMinSales;
    final slots = mentor.openSlots;
    final modeWord = mentor.modes.contains('Video') ? 'Video' : (mentor.modes.firstOrNull ?? 'Live');
    final slotDays = slotDaysLabel(mentor.availability);
    return MentorOffering(
      id: p['id'] as String,
      kind: curriculum ? OfferingKind.program : OfferingKind.plan,
      title: title,
      blurb: p['blurb'] as String?,
      pricePaisa: price,
      compareAtPaisa: (p['compareAtPaisa'] as num?)?.toInt(),
      durationMin: duration,
      tags: curriculum
          ? [
              if (best) const OfferingTag('BEST SELLER'),
              OfferingTag(duration == null ? '$total Session${total == 1 ? '' : 's'}' : '$duration Min'),
            ]
          : [
              OfferingTag('$perMonth Session${perMonth == 1 ? '' : 's'} / mo'),
              if (duration != null) OfferingTag('$duration Min'),
            ],
      ctaLabel: curriculum ? 'Book Now' : 'Subscribe',
      isBestSeller: best,
      // A plan has no ratings of its own; its photo carries the mentor's.
      rating: mentor.rating,
      ratingCount: mentor.ratingCount,
      salesCount: subscribers,
      cover: _picture(p['coverUrl'] as String?),
      myOpenRequestId: waitingId,
      sessionsPerMonth: perMonth,
      sessionDurationMin: duration,
      billingPeriodMonths: months,
      perMonthPaisa: (p['perMonthPaisa'] as num?)?.toInt() ?? (price / months).round(),
      inclusions: _strings(p['inclusions']),
      accessMonths: access,
      totalSessions: total,
      kicker: curriculum ? '1:1 MENTORING' : 'ONGOING PLAN',
      facts: curriculum
          ? [
              OfferingFact(glyph: OfferingGlyph.person, label: '1:1 $modeWord call'),
              if (duration != null) OfferingFact(glyph: OfferingGlyph.clock, label: '$duration Minutes'),
              OfferingFact(glyph: OfferingGlyph.calendar, label: slotDays ?? 'Within $access months'),
            ]
          : [
              OfferingFact(glyph: OfferingGlyph.sessions, label: '$perMonth / month'),
              if (duration != null) OfferingFact(glyph: OfferingGlyph.clock, label: '$duration Minutes'),
              OfferingFact(glyph: OfferingGlyph.calendar, label: '$months-month term'),
            ],
      details: curriculum
          ? [
              OfferingDetail(glyph: OfferingGlyph.sessions, title: '$total Sessions', body: 'Worked through in order.'),
              if (duration != null)
                OfferingDetail(
                  glyph: OfferingGlyph.clock,
                  title: '$duration Minutes / session',
                  body: 'Each step is one live call.',
                ),
              OfferingDetail(
                glyph: OfferingGlyph.list,
                title: 'Within $access month${access == 1 ? '' : 's'}',
                body: 'The window to finish the syllabus in.',
              ),
              const OfferingDetail(
                glyph: OfferingGlyph.chat,
                title: 'Private thread',
                body: 'Message the mentor between sessions.',
              ),
            ]
          : [
              OfferingDetail(
                glyph: OfferingGlyph.sessions,
                title: '$perMonth Session${perMonth == 1 ? '' : 's'} / Month',
                body: 'Booked as you go, session by session.',
              ),
              if (duration != null)
                OfferingDetail(
                  glyph: OfferingGlyph.clock,
                  title: '$duration Minutes / session',
                  body: 'Each one a live 1:1 call.',
                ),
              OfferingDetail(
                glyph: OfferingGlyph.calendar,
                title: '$months-month term',
                body: 'Paid per term; it never renews on its own.',
              ),
              const OfferingDetail(
                glyph: OfferingGlyph.chat,
                title: 'Private thread',
                body: 'Message the mentor between sessions.',
              ),
            ],
      // One block per term: the syllabus, in the mentor's order. The API has no
      // weekly curriculum, so the design's "Month 1 / Week 1…" becomes the
      // programme's own sessions under its term.
      roadmap: curriculum && modules.isNotEmpty
          ? [
              RoadmapTerm(
                label: termLabel(access),
                modules: [
                  RoadmapModule(
                    title: '$total-session syllabus',
                    badge: monthsSpan(access),
                    steps: [for (final (i, m) in modules.indexed) stepLabel(i, '${m['title']}')],
                  ),
                ],
              ),
            ]
          : const [],
      previewLabel: curriculum && modules.isNotEmpty ? 'Inspect $total-session syllabus preview' : null,
      planKicker: curriculum ? '1:1 MENTORING' : 'ONGOING PLAN',
      seatsNote: slots > 0 && slots <= 3 ? 'Only $slots slot${slots == 1 ? '' : 's'} left' : null,
      applyLabel: 'Apply for ${applyName(title)}',
      familyKey: curriculum ? title.trim().toLowerCase() : null,
      termMonths: curriculum ? access : null,
    );
  }

  MentorOffering _group(Map<String, dynamic> g) {
    final at = _date(g['scheduledAt']);
    final seatsLeft = (g['seatsLeft'] as num?)?.toInt();
    final duration = (g['durationMin'] as num?)?.toInt();
    final price = (g['pricePaisa'] as num?)?.toInt() ?? 0;
    return MentorOffering(
      id: 'group-${g['id']}',
      kind: OfferingKind.groupSession,
      title: g['title'] as String? ?? '',
      blurb: g['summary'] as String?,
      pricePaisa: price,
      durationMin: duration,
      tags: [
        const OfferingTag('Group Session'),
        if (at != null) OfferingTag(sessionDateLabel(at)),
        if (seatsLeft != null) OfferingTag('$seatsLeft seat${seatsLeft == 1 ? '' : 's'} left', green: seatsLeft > 0),
      ],
      ctaLabel: 'Reserve Seat',
      cover: _picture(g['coverUrl'] as String?),
      nextSessionAt: at,
      seatsLeft: seatsLeft,
      groupSessionId: g['id'] as String,
      kicker: 'GROUP SESSION',
      facts: [
        const OfferingFact(glyph: OfferingGlyph.group, label: 'Group'),
        if (duration != null) OfferingFact(glyph: OfferingGlyph.clock, label: '$duration Minutes'),
        if (at != null) OfferingFact(glyph: OfferingGlyph.calendar, label: sessionDateLabel(at)),
      ],
      details: [
        if (at != null)
          OfferingDetail(glyph: OfferingGlyph.calendar, title: sessionDateLabel(at), body: 'The next occurrence.'),
        if (seatsLeft != null)
          OfferingDetail(
            glyph: OfferingGlyph.group,
            title: '$seatsLeft seat${seatsLeft == 1 ? '' : 's'} left',
            body: 'Reserved from the session\'s own page.',
          ),
      ],
    );
  }

  static String? _modeLabel(String mode) => switch (mode) {
    'VIDEO' => 'Video',
    'PHONE' => 'Phone',
    'IN_PERSON' => 'In person',
    'CHAT' => 'Chat',
    _ => null,
  };

  static DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

  static List<String> _strings(Object? v) => (v as List? ?? const []).map((e) => e.toString()).toList();

  FeedPicture? _picture(String? path) {
    final url = AppConfig.absoluteUrl(path, apiBase: api.dio.options.baseUrl);
    return url == null ? null : FeedPicture.network(url);
  }

  /// `User.coverImage` is a preset key or an upload path; only a path is a picture.
  FeedPicture? _cover(String? value) {
    if (value == null || value.isEmpty) return null;
    if (!value.startsWith('/') && !value.startsWith('http')) return null;
    return _picture(value);
  }

  // --- transport -------------------------------------------------------------

  Future<T?> _quiet<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _get(String path, [Map<String, dynamic>? query]) async {
    try {
      final res = await api.dio.get<Map<String, dynamic>>(path, queryParameters: query);
      return res.data ?? const {};
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<dynamic> _send(String method, String path, [Map<String, dynamic>? body]) async {
    try {
      final res = await api.dio.request<dynamic>(
        path,
        data: body,
        options: Options(method: method),
      );
      return res.data;
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}
