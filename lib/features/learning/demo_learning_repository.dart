import '../../core/config.dart';
import 'learning_format.dart';
import 'learning_models.dart';
import 'learning_repository.dart';

/// The Course page design's sample content, bundled for design review.
class DemoLearningRepository implements LearningRepository {
  DemoLearningRepository();

  MyEnrolment? _enrolment;

  /// The design's thumbnail without its baked-in "PREMIUM CERTIFICATION" label
  /// (the app draws its own pill, as it does over a live cover).
  static const _cover = FeedPicture.asset('assets/images/demo/learning/course_cover_clean.png');

  /// The design's enrolment specialist. The design names no WhatsApp number,
  /// so the button opens WhatsApp with no recipient.
  static final _specialist = CourseContact(
    name: 'Bushra A.',
    role: 'specialist – program enrollment',
    photo: const FeedPicture.asset('assets/images/demo/learning/specialist.png'),
    email: 'contact@icrvinfraa.com',
    whatsapp: Uri.parse('https://wa.me/'),
  );

  static CourseRun _run(
    int n,
    String location,
    DateTime start,
    DateTime end, {
    int? remaining,
    bool confirmed = false,
    DeliveryMode mode = DeliveryMode.inPerson,
  }) => CourseRun(
    id: 'demo-run-$n',
    courseId: 'demo-cals',
    code: 'CALS-2024$n',
    mode: mode,
    startsAt: start,
    endsAt: end,
    location: location,
    seatsCapacity: 20,
    seatsRemaining: remaining,
    durationLabel: '5 days',
    specialist: _specialist,
    confirmed: confirmed,
  );

  /// The one course the design draws.
  Course get course => Course(
    id: 'demo-cals',
    code: 'CALS',
    slug: 'certificate-in-advanced-leadership-skills',
    title: 'Certificate in Advanced Leadership Skills',
    summary:
        'Future-ready Insights, Models and Practices to elevate your strategic decision-making and drive '
        'organizational transformation.',
    // The four lines the design shows, then the continuation "show more" reveals.
    description:
        'Leadership is not something people are just born with; leadership can be learnt. All around the world '
        'businesses are realizing the power of great leadership. They realize the value it brings to the business '
        'and to individuals and they are recognizing the significant costs of poor leadership too!\n\n'
        'This certificate programme gives senior managers the frameworks and the personal insight to lead through '
        'disruption, delivered face to face over five days by ICR Institute.',
    kind: CourseKind.development,
    level: 'Leadership',
    cover: _cover,
    certificateEnabled: true,
    badge: coverBadge('LEADERSHIP', CourseKind.development, certificateEnabled: true),
    durationLabel: '5 days · 35 hours',
    // The design's brochure button is live; a demo link keeps it so.
    brochureUrl: 'https://icr.org.in/learning/professional-development/CALS',
    runs: [
      _run(1, 'Riyadh, KSA', DateTime(2024, 8, 23), DateTime(2024, 8, 27), remaining: 12, confirmed: true),
      _run(2, 'London, UK', DateTime(2024, 9, 14), DateTime(2024, 9, 18), remaining: 16),
      _run(3, 'Dubai, UAE', DateTime(2024, 10, 5), DateTime(2024, 10, 9), remaining: 3),
    ],
    modules: const [
      CourseModule(
        id: 'm1',
        title: 'Leadership Intelligence',
        lessons: [
          'Leadership in a Disruptive World',
          'The Evolution of Leadership Paradigms',
          'Assessing Personal Leadership Competencies',
        ],
      ),
      CourseModule(id: 'm2', title: 'Personal Mastery'),
    ],
    outcomes: const [
      'Self-evaluate your personal leadership style and effectiveness, be able to identify your priorities for '
          'people management and leadership development.',
      'Design and implement high-performance team strategies by understanding team dynamics including '
          'teamworking, conflict resolution and collaboration.',
      'Diagnose organizational culture to identify strengths, weaknesses and required change to drive successful '
          'transformation.',
    ],
    audience: const [
      'Executive Management',
      'Senior Project Directors',
      'Facility & Asset Leaders',
      'VP Operations',
      'High-Potential Talent',
    ],
    aboutCertificate:
        'This exclusive bundled offering includes face-to-face onsite training delivered and awarded by ICR '
        'Institute, together with online self-paced content from premium academic partners. Upon successful '
        'completion, participants receive dual certification recognizing their achievement.',
    certificateBadges: const [
      FeedPicture.asset('assets/images/demo/learning/badge_icr.png'),
      FeedPicture.asset('assets/images/demo/learning/badge_partner.png'),
    ],
    contact: _specialist,
    enrolment: _enrolment,
    detailLoaded: true,
  );

  @override
  Future<List<Course>> courses() async => [course];

  @override
  Future<Course> detail(Course course) async => this.course;

  @override
  Future<List<MyEnrolment>> myEnrolments() async => [?_enrolment];

  @override
  Future<CourseReviews> reviews(Course course) async => const CourseReviews(
    total: 1,
    items: [
      CourseReview(
        id: 'demo-review',
        body:
            '"The staffs are very professional and helpful since we started corresponding before eventually coming '
            'to Dubai to do the course. Am going back very confident, well fulfilled and my knowledge in facility '
            'management has been enlightening. Thank you!"',
        author: 'Charles Selasie Tuffour',
        role: 'Facilities Manager',
      ),
    ],
  );

  @override
  Future<MyEnrolment> enrol(Course course, {CourseRun? run}) async => _enrolment = MyEnrolment(
    id: 'demo-enrolment',
    courseId: course.id,
    runId: run?.id,
    status: EnrolmentStatus.confirmed,
    startsAt: run?.startsAt,
    endsAt: run?.endsAt,
    location: run?.location,
  );

  @override
  Future<void> enquire(
    Course course, {
    required String message,
    EnquiryKind kind = EnquiryKind.question,
    String? company,
    int? headcount,
  }) async {}

  @override
  Future<int> unreadNotifications() async => 1;

  @override
  Uri link(Course course) => AppConfig.sitePage('/learning/professional-development');

  @override
  Uri checkoutLink(Course course, CourseRun? run) => link(course);
}
