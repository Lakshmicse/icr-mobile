import 'contact_models.dart';

/// Where the Contact screen sends its message: the API, or the sample source.
abstract class ContactRepository {
  /// The signed-in member's name, email and phone, to fill the form in. Null
  /// when nobody is signed in (a visitor); throws an `ApiError` when the API
  /// could not be asked, which is not the same thing: the form still works.
  Future<ContactSender?> sender();

  /// Sends the message (`POST /contact`); the API's id for it. Throws an
  /// `ApiError` carrying the API's own sentence when it is refused.
  Future<String> send(ContactMessage message);

  /// The bell's count; 0 for a visitor.
  Future<int> unreadNotifications();
}
