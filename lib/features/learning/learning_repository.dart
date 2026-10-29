import 'learning_models.dart';

/// Where the Learning screens get their courses: the API, or the design's
/// sample content.
abstract class LearningRepository {
  /// Every published course, as the list shows them.
  Future<List<Course>> courses();

  /// The course in full: runs, syllabus, outcomes, audience, contact.
  Future<Course> detail(Course course);

  /// The member's own places, so rows and the sheet can say "Enrolled".
  Future<List<MyEnrolment>> myEnrolments();

  /// The course's published reviews, newest first, and how many exist.
  Future<CourseReviews> reviews(Course course);

  /// Takes a free place (or a waitlist place) on [run], or on the course
  /// itself when it schedules no runs. A paid place is bought on the website.
  Future<MyEnrolment> enrol(Course course, {CourseRun? run});

  /// Takes back the member's place or request on [course] (`DELETE /learning/courses/:id/enroll`). The API
  /// refuses a place that is paid for, with a sentence that sends the member to ICR, who arrange the refund.
  Future<void> withdraw(Course course);

  /// Writes to the institute that awards the course. [message] is the whole
  /// text; an in-house request is a corporate lead, which also carries the
  /// [company] and how many people to train ([headcount]).
  Future<void> enquire(
    Course course, {
    required String message,
    EnquiryKind kind = EnquiryKind.question,
    String? company,
    int? headcount,
  });

  Future<int> unreadNotifications();

  /// The course's page on the website.
  Uri link(Course course);

  /// The website's enrolment panel, where a paid place is bought.
  Uri checkoutLink(Course course, CourseRun? run);
}
