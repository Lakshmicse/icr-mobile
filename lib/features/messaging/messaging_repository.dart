import 'dart:typed_data';

import 'messaging_models.dart';

/// The conversation list's filters, as the website's inbox asks for them.
class ConversationQuery {
  const ConversationQuery({
    this.inbox = MessagingInbox.personalId,
    this.filter = InboxFilter.all,
    this.kind,
    this.search = '',
    this.view = CompanyInboxView.open,
    this.topic,
  });

  /// `personal`, or the id of a company inbox the person answers for.
  final String inbox;
  final InboxFilter filter;
  final InboxKind? kind;
  final String search;

  /// A company inbox's own views.
  final CompanyInboxView view;

  /// A company inbox narrowed to one topic.
  final String? topic;

  bool get companyInbox => inbox != MessagingInbox.personalId;

  /// Pinned threads are listed apart (above the rest) on the personal inbox's All tab, with no kind and no search.
  /// Under a kind or a search they stay in the list, so a pinned thread of that kind never disappears.
  bool get excludePinned => !companyInbox && filter == InboxFilter.all && kind == null && search.trim().isEmpty;

  ConversationQuery copyWith({
    String? inbox,
    InboxFilter? filter,
    InboxKind? kind,
    bool clearKind = false,
    String? search,
    CompanyInboxView? view,
    String? topic,
    bool clearTopic = false,
  }) => ConversationQuery(
    inbox: inbox ?? this.inbox,
    filter: filter ?? this.filter,
    kind: clearKind ? null : (kind ?? this.kind),
    search: search ?? this.search,
    view: view ?? this.view,
    topic: clearTopic ? null : (topic ?? this.topic),
  );
}

enum InboxFilter { all, unread, starred }

/// The kinds a list can be narrowed to (`CONVERSATION_KIND_FILTERS`).
enum InboxKind { requirement, mentorship, direct }

extension InboxKindWords on InboxKind {
  String get label => switch (this) {
    InboxKind.requirement => 'Requirements and bids',
    InboxKind.mentorship => 'Mentorship',
    InboxKind.direct => 'Direct',
  };
}

enum CompanyInboxView { open, unread, mine, done, spam }

extension CompanyInboxViewWords on CompanyInboxView {
  String get label => switch (this) {
    CompanyInboxView.open => 'Open',
    CompanyInboxView.unread => 'Unread',
    CompanyInboxView.mine => 'Mine',
    CompanyInboxView.done => 'Done',
    CompanyInboxView.spam => 'Spam',
  };

  String get empty => switch (this) {
    CompanyInboxView.open => 'Nothing waiting in this inbox',
    CompanyInboxView.unread => "You're all caught up",
    CompanyInboxView.mine => 'Nothing assigned to you',
    CompanyInboxView.done => 'Nothing marked done yet',
    CompanyInboxView.spam => 'No spam',
  };
}

/// Where Messages gets its conversations: the API, or the designs' sample
/// content. Every write returns what the API answered, or throws its refusal.
abstract class MessagingRepository {
  /// The signed-in person's id: what tells their messages from the other side's.
  Future<String> viewerId();

  /// The person's own messages, then each company inbox they answer for.
  Future<List<MessagingInbox>> inboxes();

  Future<ConversationPage> conversations(ConversationQuery query, {int page = 1});

  /// The person's pinned threads (at most ten), listed above the rest.
  Future<List<Conversation>> pinned();

  /// Message text across the threads, for two characters or more.
  Future<List<MessageSearchHit>> searchMessages(String q, {String? inbox});

  Future<MessagingUnread> unreadCount();

  /// "Mark all as read": every thread, or one inbox's. Returns how many messages.
  Future<int> markAllRead({String? inbox});

  /// The newest window of a thread; [asCompanyId] reads it from that company's inbox.
  Future<ThreadWindow> thread(String conversationId, {int take = 50, String? asCompanyId});

  /// Older messages than [beforeId], oldest first.
  Future<MessageWindow> older(String conversationId, String beforeId, {int take = 50, String? asCompanyId});

  /// Newer messages than [afterId]: what a poll catches up on.
  Future<MessageWindow> newer(String conversationId, String afterId, {String? asCompanyId});

  /// Why the thread exists; null when the API cannot say.
  Future<ConversationContext?> context(String conversationId, {String? asCompanyId});

  Future<ChatMessage> send(
    String conversationId, {
    required String body,
    String? attachmentUrl,
    String? replyToId,
    String? asCompanyId,
  });

  /// Uploads a file for a message (it is private to the thread once sent).
  Future<UploadedAttachment> upload(PickedAttachment file);

  /// A private attachment's bytes, read with the person's session.
  Future<Uint8List> download(String url);

  /// Reads the other side's messages (and the notifications that announced them).
  Future<void> markRead(String conversationId, {String? asCompanyId});

  /// Withdraws one of the person's own messages. Returns when it was blanked.
  Future<DateTime> deleteMessage(String conversationId, String messageId);

  Future<void> report(String messageId, String reason, {String? note});

  Future<({bool starred, bool pinned})> setPreference(String conversationId, {bool? starred, bool? pinned});

  /// A company sorting the thread in its inbox: done, spam, open, assignee.
  Future<ThreadParty> updateCompanyThread(
    String conversationId, {
    required String companyId,
    ThreadStatus? status,
    String? assigneeId,
    bool unassign = false,
  });

  /// People and suppliers "New message" can reach.
  Future<Recipients> recipients(String search);

  // --- opening a thread (each returns the conversation's id) ---------------

  /// A plain thread with one person, reused when the two already share one.
  Future<String> startWithPerson(String userId, {String? message});

  /// "Send Message" on a supplier listing; its sales inbox answers.
  Future<String> startWithSupplier(String vendorId, {String? rfqId, String? message});

  /// "Message" on a company page, about a topic (`SALES`, `CAREERS`, `PARTNERSHIP`, `GENERAL`).
  Future<String> startWithCompany(String companyId, String topic, {String? message});

  /// "Message" on a job: the API picks the hiring contact.
  Future<String> startWithJobContact(String jobId, {String? message});

  /// A mentor-service purchase's thread: a consultation's own, else the pair's.
  Future<String> openForPurchase(String purchaseId);

  /// A mentoring pairing's thread.
  Future<String> openForMentorship(String mentorshipId);

  /// A group session's room.
  Future<String> openForGroupSession(String sessionId);

  /// A requirement's thread between its buying team and one supplier company.
  Future<String> openForRfq(String rfqId, {String? supplierCompanyId});

  /// An employer's thread with an applicant.
  Future<String> openForApplication(String applicationId);

  // --- shared records ------------------------------------------------------

  /// A shared record, as its page would show it; throws when the reader may not see it.
  Future<RecordFacts> record(RecordRef ref);

  /// Records of one type the share sheet offers for a search.
  Future<List<RecordFacts>> searchRecords(RecordType type, String search);
}
