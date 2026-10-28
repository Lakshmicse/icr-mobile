import '../contact/contact_models.dart' show ContactSender;
import 'volunteer_models.dart';

/// Where the Get Involved screen gets the member's CPD, the form's starting values and the chapters it
/// offers, and where an expression of interest goes: the API, or the sample content.
abstract class VolunteerRepository {
  /// The member's CPD ledger and target; null when nobody is signed in.
  Future<CpdSummary?> cpd();

  /// Who is signed in, to fill the form's name, email and phone; null when nobody is.
  Future<ContactSender?> sender();

  /// Every published chapter, by name, for "Which chapter?".
  Future<List<ChapterChoice>> chapters();

  /// Sends the interest to the ICR team (`POST /contact`, topic `VOLUNTEER`). Throws an `ApiError`
  /// carrying the API's own sentence when it is refused.
  Future<void> apply(VolunteerApplication application);

  Future<int> unreadNotifications();
}
