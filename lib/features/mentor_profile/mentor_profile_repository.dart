import 'mentor_profile_models.dart';

/// Where the Mentor Profile screens get a mentor: the API, or the designs'
/// sample content.
abstract class MentorProfileRepository {
  Future<MentorProfile> profile(String mentorId);

  /// Everything the mentor sells: 1:1 sessions, programmes, ongoing plans,
  /// resources and upcoming group sessions, in that order.
  Future<List<MentorOffering>> offerings(MentorProfile mentor);

  /// Named testimonials first, then anonymous mentee feedback.
  Future<List<MentorReview>> reviews(MentorProfile mentor);

  Future<int> unreadNotifications();

  /// Whether the member has a phone on file; a request shares it with the mentor.
  Future<bool> hasPhone();

  /// The free mentoring request (`POST /mentorship/requests`).
  Future<void> requestMentoring(MentorProfile mentor, {required String message, String? phone});

  /// The thread of a live pairing; its conversation id.
  Future<String?> openConversation(MentorProfile mentor);

  /// Asks for a single 1:1 session; the mentor sets the time. Returns the
  /// purchase id of the request.
  Future<String?> requestSession(
    MentorOffering offering, {
    required String topic,
    required String mode,
    String? preferredTimes,
    String? phone,
  });

  /// Buys or asks for anything else: a resource, a plan, a programme, a seat.
  Future<CheckoutOutcome> buy(MentorProfile mentor, MentorOffering offering, {String? phone});

  Uri link(MentorProfile mentor);
}
