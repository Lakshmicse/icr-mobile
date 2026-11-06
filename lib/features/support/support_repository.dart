import 'dart:typed_data';

import 'support_models.dart';

/// Where the support desk reads and writes: the API, or the bundled sample for design review.
abstract class SupportRepository {
  /// `GET /support/tickets`: a page of the member's requests. [status] is `OPEN_ONLY`, `ALL` or one status.
  Future<TicketPage> tickets({String status = 'OPEN_ONLY', String? search, int page = 1, int limit = 20});

  /// `GET /support/tickets/:id`: the request with its thread and history.
  Future<SupportTicket> ticket(String id);

  /// `POST /support/tickets`.
  Future<SupportTicketRaised> raise(RaiseDraft draft);

  /// `POST /support/tickets/:id/messages`. The answer is the ticket without its thread.
  Future<SupportTicket> reply(String id, String body, List<SupportAttachmentDraft> attachments);

  /// `POST /support/tickets/:id/reopen` (a resolved request, within 14 days).
  Future<SupportTicket> reopen(String id);

  /// `POST /support/tickets/:id/rate` (1 to 5, once).
  Future<SupportTicket> rate(String id, int score);

  /// `GET /support/faqs` (public): knowledge-base articles, optionally for one category.
  Future<List<SupportFaq>> faqs({String? category, String? search, int limit = 4});

  /// `POST /support/faqs/:id/view`: counted when an article is opened. Never throws.
  Future<void> markFaqViewed(String id);

  /// `POST /support/faqs/:id/helpful`: counted when an article answered the question. Never throws.
  Future<void> markFaqHelpful(String id);

  /// `GET /subscriptions/account-manager`: null when nobody is named.
  Future<AccountManager?> accountManager();

  /// `POST /uploads?purpose=support`: the file is stored private, readable by its owner and by support staff.
  Future<SupportAttachmentDraft> upload(SupportPickedFile file);

  /// A private upload's bytes, read with the session (the phone's browser has none).
  Future<Uint8List> fileBytes(String url);
}
