/// What the Learning screens draw. The live source fills it from
/// `GET /learning/courses`, `GET /learning/courses/:code`, the member's
/// enrolments and a course's reviews; the demo source holds the Course page
/// design's sample content.
library;

import '../feed/feed_models.dart' show FeedPicture;

export '../feed/feed_models.dart' show FeedPicture;

/// `LearningCourseKind`: a taught course with batches, or a certification
/// programme whose levels are sat as papers.
enum CourseKind {
  development('Professional development'),
  assessment('Certification programmes');

  const CourseKind(this.sectionTitle);

  /// The heading the list groups the kind under.
  final String sectionTitle;

  static CourseKind fromApi(String? v) => v == 'ASSESSMENT' ? assessment : development;
}

/// The two ways a run is delivered, as the design's tab strip offers them.
/// `LearningDeliveryMode` has four values; the retired ONLINE and HYBRID ones
/// fold into these by the only question the tabs ask — do you have to turn up.
enum DeliveryMode {
  inPerson('Face to Face On site Training'),
  virtual('Live Virtual Training');

  const DeliveryMode(this.label);
  final String label;

  static DeliveryMode fromApi(String? v) => v == 'IN_PERSON' || v == 'HYBRID' ? inPerson : virtual;
}

/// How many places a run has left, as the tile's corner words it.
enum RunAvailability {
  open('Open'),
  limited('Limited'),
  full('Full');

  const RunAvailability(this.label);
  final String label;
}

/// What the person is writing to the institute about; each opens the same
/// form with its own title, hint and opening words (`POST …/enquire`).
enum EnquiryKind {
  /// "ask the institute".
  question,

  /// "Suggest A Date & Location".
  dateRequest,

  /// "take this course as in-house": a corporate lead (`kind: CORPORATE`).
  inHouse,
}

/// `LearningEnrollmentStatus`.
enum EnrolmentStatus {
  pending('Place requested'),
  confirmed('Enrolled'),
  waitlisted('On the waitlist'),
  cancelled('Withdrawn'),
  completed('Completed');

  const EnrolmentStatus(this.label);
  final String label;

  static EnrolmentStatus fromApi(String? v) => switch (v) {
    'CONFIRMED' => confirmed,
    'WAITLISTED' => waitlisted,
    'CANCELLED' => cancelled,
    'COMPLETED' => completed,
    _ => pending,
  };

  /// Holds or is waiting for a place.
  bool get active => this != cancelled;
}

/// The awarding body; null on a course means ICR's own credential.
class CourseProvider {
  const CourseProvider({
    required this.id,
    required this.name,
    this.slug,
    this.logo,
    this.website,
    this.verified = false,
  });

  final String id;
  final String name;
  final String? slug;
  final FeedPicture? logo;
  final String? website;
  final bool verified;
}

/// The person a run names for enrolment questions (`LearningBatch.enrolmentSpecialist`).
class CourseContact {
  const CourseContact({required this.name, required this.role, this.photo, this.email, this.whatsapp});

  final String name;

  /// "specialist – program enrollment".
  final String role;
  final FeedPicture? photo;

  /// Only the demo knows these: the API never publishes a trainer's contact.
  final String? email;
  final Uri? whatsapp;
}

/// A scheduled run of a course (`LearningBatch`): what a person enrols on.
class CourseRun {
  const CourseRun({
    required this.id,
    required this.courseId,
    required this.code,
    required this.mode,
    required this.startsAt,
    this.endsAt,
    this.title,
    this.location,
    this.seatsCapacity,
    this.seatsRemaining,
    this.full = false,
    this.waitlistEnabled = true,
    this.priceAmount,
    this.priceCurrency = 'INR',
    this.durationLabel,
    this.schedule,
    this.specialist,
    this.instructor,
    this.confirmed = false,
  });

  final String id;
  final String courseId;
  final String code;
  final DeliveryMode mode;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? title;

  /// "Riyadh, KSA".
  final String? location;
  final int? seatsCapacity;
  final int? seatsRemaining;
  final bool full;
  final bool waitlistEnabled;

  /// Paise; null falls back to the course's price.
  final int? priceAmount;
  final String priceCurrency;
  final String? durationLabel;
  final String? schedule;
  final CourseContact? specialist;
  final String? instructor;

  /// The run is confirmed to go ahead (the design's green CONFIRMED). Only
  /// the demo knows this; the API has no such fact about a run.
  final bool confirmed;

  RunAvailability get availability {
    if (full) return RunAvailability.full;
    final remaining = seatsRemaining;
    final capacity = seatsCapacity;
    if (remaining != null && capacity != null && capacity > 0 && remaining <= (capacity * 0.2).ceil()) {
      return RunAvailability.limited;
    }
    return RunAvailability.open;
  }
}

/// A unit of the syllabus (`LearningCourseModule`); its topics are the lessons.
class CourseModule {
  const CourseModule({required this.id, required this.title, this.summary, this.lessons = const []});

  final String id;
  final String title;
  final String? summary;
  final List<String> lessons;
}

/// What a past learner said (`LearningCourseReview`, published only).
class CourseReview {
  const CourseReview({required this.id, required this.body, required this.author, this.role, this.photo, this.rating});

  final String id;
  final String body;
  final String author;

  /// Their job title when they wrote it.
  final String? role;
  final FeedPicture? photo;
  final int? rating;
}

/// The member's own place on a course (`GET /learning/me/enrollments`).
class MyEnrolment {
  const MyEnrolment({
    required this.id,
    required this.courseId,
    this.runId,
    required this.status,
    this.startsAt,
    this.endsAt,
    this.location,
  });

  final String id;
  final String courseId;
  final String? runId;
  final EnrolmentStatus status;

  /// The run's dates and place, as `GET /learning/me/enrollments` carries them.
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? location;
}

/// A page of a course's published reviews and how many exist in all.
class CourseReviews {
  const CourseReviews({this.items = const [], this.total = 0});

  final List<CourseReview> items;
  final int total;
}

class Course {
  const Course({
    required this.id,
    required this.code,
    required this.title,
    this.slug,
    this.summary,
    this.description,
    this.kind = CourseKind.development,
    this.level,
    this.provider,
    this.cover,
    this.badge,
    this.priceAmount,
    this.priceCurrency = 'INR',
    this.durationLabel,
    this.deliveryMode,
    this.language,
    this.cpdCredits = 0,
    this.certificateEnabled = false,
    this.enrollmentOpen = true,
    this.batchStartsAt,
    this.full = false,
    this.waitlistEnabled = true,
    this.brochureUrl,
    this.runs = const [],
    this.modules = const [],
    this.outcomes = const [],
    this.prerequisites = const [],
    this.audience = const [],
    this.aboutCertificate,
    this.certificateBadges = const [],
    this.contact,
    this.enrolment,
    this.detailLoaded = false,
  });

  final String id;

  /// "CALS": also the public route param.
  final String code;
  final String title;
  final String? slug;

  /// The one line under the title.
  final String? summary;

  /// The overview; the summary stands in when a course has none.
  final String? description;
  final CourseKind kind;

  /// "Leadership", "Advanced"…
  final String? level;
  final CourseProvider? provider;
  final FeedPicture? cover;

  /// The pill on the cover ("PREMIUM CERTIFICATION", "LEADERSHIP COURSE"),
  /// drawn by the app from the course (`coverBadge`).
  final String? badge;

  /// Paise; null or 0 means free.
  final int? priceAmount;
  final String priceCurrency;

  /// "4 days · 32 hours".
  final String? durationLabel;

  /// The course's own words ("Virtual live training"), for a course with no runs.
  final String? deliveryMode;
  final String? language;
  final int cpdCredits;

  /// The course issues a certificate on completion (`certificateEnabled`).
  final bool certificateEnabled;
  final bool enrollmentOpen;

  /// The single cohort's date, for a course that schedules no runs.
  final DateTime? batchStartsAt;
  final bool full;
  final bool waitlistEnabled;
  final String? brochureUrl;

  // Detail.
  final List<CourseRun> runs;
  final List<CourseModule> modules;
  final List<String> outcomes;
  final List<String> prerequisites;
  final List<String> audience;

  /// The paragraph under "About the Certificate". The live source words it
  /// from the awarding body; the demo carries the design's.
  final String? aboutCertificate;

  /// The marks shown above that paragraph: the awarding body's logo, or the
  /// design's two badges.
  final List<FeedPicture> certificateBadges;

  /// The enrolment specialist of the first run, for a course whose runs name one.
  final CourseContact? contact;
  final MyEnrolment? enrolment;

  /// Whether the detail fields were fetched (a list row has only the summary).
  final bool detailLoaded;

  bool get free => (priceAmount ?? 0) <= 0;

  /// Whether a place on [run] (or the course itself) costs money.
  bool isPaid(CourseRun? run) => (run?.priceAmount ?? priceAmount ?? 0) > 0;

  int? priceFor(CourseRun? run) => run?.priceAmount ?? priceAmount;

  /// The runs under one tab.
  List<CourseRun> runsIn(DeliveryMode mode) => runs.where((r) => r.mode == mode).toList();

  /// The modes with a run, in the strip's order.
  List<DeliveryMode> get scheduledModes => DeliveryMode.values.where((m) => runs.any((r) => r.mode == m)).toList();

  bool get enrolled => enrolment != null && enrolment!.status.active;

  /// Nothing to join: enrolment closed, or no run and no cohort date.
  bool get closed => !enrollmentOpen || (runs.isEmpty && batchStartsAt == null);

  Course copyWith({MyEnrolment? enrolment, bool clearEnrolment = false, Course? detail, FeedPicture? cover}) => Course(
    id: id,
    code: code,
    title: detail?.title ?? title,
    slug: detail?.slug ?? slug,
    summary: detail?.summary ?? summary,
    description: detail?.description ?? description,
    kind: detail?.kind ?? kind,
    level: detail?.level ?? level,
    provider: detail?.provider ?? provider,
    cover: cover ?? detail?.cover ?? this.cover,
    badge: detail?.badge ?? badge,
    priceAmount: detail?.priceAmount ?? priceAmount,
    priceCurrency: detail?.priceCurrency ?? priceCurrency,
    durationLabel: detail?.durationLabel ?? durationLabel,
    deliveryMode: detail?.deliveryMode ?? deliveryMode,
    language: detail?.language ?? language,
    cpdCredits: detail?.cpdCredits ?? cpdCredits,
    certificateEnabled: detail?.certificateEnabled ?? certificateEnabled,
    enrollmentOpen: detail?.enrollmentOpen ?? enrollmentOpen,
    batchStartsAt: detail?.batchStartsAt ?? batchStartsAt,
    full: detail?.full ?? full,
    waitlistEnabled: detail?.waitlistEnabled ?? waitlistEnabled,
    brochureUrl: detail?.brochureUrl ?? brochureUrl,
    runs: detail?.runs ?? runs,
    modules: detail?.modules ?? modules,
    outcomes: detail?.outcomes ?? outcomes,
    prerequisites: detail?.prerequisites ?? prerequisites,
    audience: detail?.audience ?? audience,
    aboutCertificate: detail?.aboutCertificate ?? aboutCertificate,
    certificateBadges: detail?.certificateBadges ?? certificateBadges,
    contact: detail?.contact ?? contact,
    enrolment: clearEnrolment ? null : enrolment ?? detail?.enrolment ?? this.enrolment,
    detailLoaded: detail?.detailLoaded ?? detailLoaded,
  );
}

/// A titled run of courses on the Learning tab.
class CourseSection {
  const CourseSection({required this.kind, required this.courses, this.heading});

  final CourseKind kind;
  final List<Course> courses;

  /// Replaces the kind's heading (the "My courses" list groups both kinds).
  final String? heading;

  String get title => heading ?? kind.sectionTitle;
}
