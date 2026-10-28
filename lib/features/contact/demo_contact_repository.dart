import 'contact_models.dart';
import 'contact_repository.dart';

/// The sample source: Bharat Buyer is signed in and every message is taken.
class DemoContactRepository implements ContactRepository {
  final sent = <ContactMessage>[];

  @override
  Future<ContactSender?> sender() async =>
      const ContactSender(name: 'Bharat Buyer', email: 'buyer@icr.dev', phone: '+919879879898');

  @override
  Future<String> send(ContactMessage message) async {
    sent.add(message);
    return 'demo-${sent.length}';
  }

  @override
  Future<int> unreadNotifications() async => 3;
}
