import 'dart:typed_data';

/// A photo or logo: a bundled asset (the demo content) or a URL from the API.
class ChatPicture {
  const ChatPicture.asset(String this.asset) : url = null;
  const ChatPicture.network(String this.url) : asset = null;

  final String? asset;
  final String? url;
}

/// Initials for a name: "Arvind Swamy" is "AS", "Vikasha Aero Tech" is "VT".
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final first = parts.first[0];
  final last = parts.length > 1 ? parts.last[0] : '';
  return '$first$last'.toUpperCase();
}

/// Someone in a conversation (`MessagingPersonDto`).
class ChatPerson {
  const ChatPerson({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.photo,
    this.headline,
    this.online,
  });

  final String id;
  final String firstName;
  final String lastName;
  final ChatPicture? photo;

  /// "Head of Energy & Climate, CBRE": the line the inbox draws under the name, when the source gives one.
  final String? headline;

  /// Presence, as the design draws it (a green dot, a grey one). The API sends none, so a real person is null
  /// and no dot is drawn; the demo content sets it.
  final bool? online;

  String get fullName => '$firstName $lastName'.trim();
  String get initials => initialsOf(fullName);
}

/// A company as a thread names it: the other side of an enquiry, the company a
/// message was sent as.
class ChatCompany {
  const ChatCompany({required this.id, required this.name, this.logo});

  final String id;
  final String name;
  final ChatPicture? logo;
}

/// Why a conversation exists (`ConversationKind`), derived by the API on read.
enum ConversationKind { requirement, bid, enquiry, mentorship, groupSession, consultation, company, direct }

ConversationKind? conversationKindFromApi(String? value) => switch (value) {
  'REQUIREMENT' => ConversationKind.requirement,
  'BID' => ConversationKind.bid,
  'ENQUIRY' => ConversationKind.enquiry,
  'MENTORSHIP' => ConversationKind.mentorship,
  'GROUP_SESSION' => ConversationKind.groupSession,
  'CONSULTATION' => ConversationKind.consultation,
  'COMPANY' => ConversationKind.company,
  'DIRECT' => ConversationKind.direct,
  _ => null,
};

extension ConversationKindWords on ConversationKind {
  /// The badge's word (`support.ConversationKinds`).
  String get label => switch (this) {
    ConversationKind.requirement => 'Requirement',
    ConversationKind.bid => 'Bid',
    ConversationKind.enquiry => 'Enquiry',
    ConversationKind.mentorship => 'Mentorship',
    ConversationKind.groupSession => 'Group session',
    ConversationKind.consultation => 'Consultation',
    ConversationKind.company => 'Company',
    ConversationKind.direct => 'Direct',
  };

  /// About a requirement: the badge names the requirement beside it.
  bool get isRequirement =>
      this == ConversationKind.requirement || this == ConversationKind.bid || this == ConversationKind.enquiry;
}

/// What a company inbox is for (`MessageTopic`).
const messageTopicLabels = {
  'SALES': 'Sales & quotes',
  'PROCUREMENT': 'Requirements & buying',
  'CAREERS': 'Careers',
  'PARTNERSHIP': 'Partnerships',
  'GENERAL': 'General',
};

/// Where a company thread stands in its inbox (`CompanyThreadStatus`).
enum ThreadStatus { open, done, spam }

ThreadStatus? threadStatusFromApi(String? value) => switch (value) {
  'OPEN' => ThreadStatus.open,
  'DONE' => ThreadStatus.done,
  'SPAM' => ThreadStatus.spam,
  _ => null,
};

String threadStatusToApi(ThreadStatus status) => switch (status) {
  ThreadStatus.open => 'OPEN',
  ThreadStatus.done => 'DONE',
  ThreadStatus.spam => 'SPAM',
};

/// A company taking part in a thread as a company (`ConversationPartyDto`).
/// [status] and [assignee] are given only to that company's own people.
class ThreadParty {
  const ThreadParty({
    required this.companyId,
    required this.name,
    required this.topic,
    this.logo,
    this.status,
    this.assignee,
  });

  final String companyId;
  final String name;
  final ChatPicture? logo;
  final String topic;
  final ThreadStatus? status;
  final ChatPerson? assignee;

  /// The reader answers for this party (the API only tells its own people where it stands).
  bool get mine => status != null;

  ThreadParty copyWith({ThreadStatus? status, ChatPerson? assignee, bool clearAssignee = false}) => ThreadParty(
    companyId: companyId,
    name: name,
    logo: logo,
    topic: topic,
    status: status ?? this.status,
    assignee: clearAssignee ? null : (assignee ?? this.assignee),
  );
}

/// The message a reply quotes: a short excerpt, never the whole body.
class MessageReply {
  const MessageReply({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.excerpt,
    this.attachmentName,
    this.deleted = false,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String excerpt;
  final String? attachmentName;
  final bool deleted;
}

/// One message (`MessageDto`).
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.sender,
    this.senderCompany,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentSize,
    this.attachmentMime,
    this.replyTo,
    this.readAt,
    this.deletedAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final ChatPerson? sender;

  /// Sent as a company (from its inbox): the outsider sees the company first.
  final ChatCompany? senderCompany;
  final String body;
  final String? attachmentUrl;
  final String? attachmentName;
  final int? attachmentSize;
  final String? attachmentMime;
  final MessageReply? replyTo;
  final DateTime? readAt;
  final DateTime? deletedAt;
  final DateTime createdAt;

  bool get deleted => deletedAt != null;
  bool get hasAttachment => !deleted && attachmentUrl != null && attachmentUrl!.isNotEmpty;
  bool get isImage => hasAttachment && (attachmentMime ?? '').startsWith('image/');

  /// The reader's side wrote it: in a company's inbox, anything sent as that
  /// company (a colleague's reply too); read as themselves, what they wrote.
  bool fromMySide(String? meId, String? asCompanyId) =>
      asCompanyId != null ? senderCompany?.id == asCompanyId : senderId == meId;

  ChatMessage asDeleted(DateTime at) => ChatMessage(
    id: id,
    conversationId: conversationId,
    senderId: senderId,
    sender: sender,
    senderCompany: senderCompany,
    body: '',
    createdAt: createdAt,
    replyTo: replyTo,
    readAt: readAt,
    deletedAt: at,
  );

  ChatMessage withReplyDeleted() => ChatMessage(
    id: id,
    conversationId: conversationId,
    senderId: senderId,
    sender: sender,
    senderCompany: senderCompany,
    body: body,
    createdAt: createdAt,
    attachmentUrl: attachmentUrl,
    attachmentName: attachmentName,
    attachmentSize: attachmentSize,
    attachmentMime: attachmentMime,
    replyTo: replyTo == null
        ? null
        : MessageReply(
            id: replyTo!.id,
            senderId: replyTo!.senderId,
            senderName: replyTo!.senderName,
            excerpt: '',
            deleted: true,
          ),
    readAt: readAt,
    deletedAt: deletedAt,
  );
}

/// "Seen", for a thread with two sides: the newest of the reader's messages the other side has read.
class MessageSeen {
  const MessageSeen({required this.messageId, required this.at});

  final String messageId;
  final DateTime at;
}

/// A conversation: a row of the inbox, or the header of an open thread.
class Conversation {
  const Conversation({
    required this.id,
    required this.participants,
    required this.updatedAt,
    this.title,
    this.rfqId,
    this.rfqTitle,
    this.lastMessage,
    this.unread = 0,
    this.starred = false,
    this.pinned = false,
    this.kind,
    this.contextLabel,
    this.counterpartCompany,
    this.parties = const [],
    this.asCompanyId,
    this.verified = false,
  });

  final String id;

  /// Set for rooms and titled threads ("Senior Facilities Manager · Global Infra").
  final String? title;
  final String? rfqId;
  final String? rfqTitle;
  final List<ChatPerson> participants;
  final ChatMessage? lastMessage;
  final int unread;
  final bool starred;
  final bool pinned;
  final ConversationKind? kind;

  /// The requirement's, room's or consultation's title.
  final String? contextLabel;

  /// The company the other side is acting for, when one is known.
  final ChatCompany? counterpartCompany;
  final List<ThreadParty> parties;

  /// The other side is a verified company (the check after the name on the inbox row). The list endpoint does
  /// not say, so a row read from the API is false; the demo content sets it from its context.
  final bool verified;

  /// The party the reader reads this thread as; null when in it as themselves.
  final String? asCompanyId;
  final DateTime updatedAt;

  /// The parties whose inbox the reader answers this thread in.
  List<ThreadParty> get myParties => parties.where((p) => p.mine).toList();

  ThreadParty? get myParty {
    for (final p in parties) {
      if (p.companyId == asCompanyId && p.mine) return p;
    }
    final mine = myParties;
    return mine.isEmpty ? null : mine.first;
  }

  Conversation copyWith({
    int? unread,
    bool? starred,
    bool? pinned,
    ChatMessage? lastMessage,
    List<ThreadParty>? parties,
    ConversationKind? kind,
    ChatCompany? counterpartCompany,
    String? contextLabel,
    DateTime? updatedAt,
    bool? verified,
  }) => Conversation(
    id: id,
    title: title,
    rfqId: rfqId,
    rfqTitle: rfqTitle,
    participants: participants,
    lastMessage: lastMessage ?? this.lastMessage,
    verified: verified ?? this.verified,
    unread: unread ?? this.unread,
    starred: starred ?? this.starred,
    pinned: pinned ?? this.pinned,
    kind: kind ?? this.kind,
    contextLabel: contextLabel ?? this.contextLabel,
    counterpartCompany: counterpartCompany ?? this.counterpartCompany,
    parties: parties ?? this.parties,
    asCompanyId: asCompanyId,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// One page of the conversation list.
class ConversationPage {
  const ConversationPage({required this.conversations, required this.total, required this.hasMore});

  final List<Conversation> conversations;
  final int total;
  final bool hasMore;
}

/// The newest window of a thread, as it opens.
class ThreadWindow {
  const ThreadWindow({required this.conversation, required this.messages, required this.hasMore, this.seen});

  final Conversation conversation;

  /// Oldest first.
  final List<ChatMessage> messages;
  final bool hasMore;
  final MessageSeen? seen;
}

/// Older or newer messages of a thread, oldest first.
class MessageWindow {
  const MessageWindow({required this.messages, required this.hasMore, this.seen});

  final List<ChatMessage> messages;
  final bool hasMore;
  final MessageSeen? seen;
}

/// The person's own messages, or a company inbox they answer for (`MessagingInboxDto`).
class MessagingInbox {
  const MessagingInbox({
    required this.id,
    required this.personal,
    required this.unread,
    this.name,
    this.logo,
    this.topics = const [],
  });

  /// `personal`, or the company's id.
  final String id;
  final bool personal;
  final String? name;
  final ChatPicture? logo;
  final List<String> topics;
  final int unread;

  static const personalId = 'personal';
}

/// Unread messages from the other side: everywhere, and per inbox.
class MessagingUnread {
  const MessagingUnread({required this.count, this.personal = 0, this.companies = const {}});

  final int count;
  final int personal;
  final Map<String, int> companies;
}

/// A message that matched a search, with where it sits.
class MessageSearchHit {
  const MessageSearchHit({
    required this.messageId,
    required this.conversationId,
    required this.participants,
    required this.snippet,
    required this.createdAt,
    this.conversationTitle,
    this.sender,
  });

  final String messageId;
  final String conversationId;
  final String? conversationTitle;
  final List<ChatPerson> participants;
  final ChatPerson? sender;
  final String snippet;
  final DateTime createdAt;
}

/// Someone "New message" can reach.
class RecipientPerson {
  const RecipientPerson({required this.person, this.headline, this.companyName});

  final ChatPerson person;
  final String? headline;
  final String? companyName;
}

/// A supplier listing "New message" can reach; its sales inbox answers.
class RecipientSupplier {
  const RecipientSupplier({required this.vendorId, required this.companyId, required this.name, this.logo, this.city});

  final String vendorId;
  final String companyId;
  final String name;
  final ChatPicture? logo;
  final String? city;
}

class Recipients {
  const Recipients({this.people = const [], this.suppliers = const []});

  final List<RecipientPerson> people;
  final List<RecipientSupplier> suppliers;

  bool get isEmpty => people.isEmpty && suppliers.isEmpty;
}

// --- why the thread exists -------------------------------------------------

/// Where the reader stands on the thread's requirement.
enum Perspective { owner, supplier, other }

/// The company on the other side, as the details show it.
class ContextCompany {
  const ContextCompany({
    required this.id,
    required this.name,
    this.logo,
    this.industry,
    this.city,
    this.verified = false,
    this.sells = false,
    this.role,
  });

  final String id;
  final String name;
  final ChatPicture? logo;
  final String? industry;
  final String? city;
  final bool verified;
  final bool sells;

  /// `BUYER` or `SUPPLIER` on a requirement.
  final String? role;

  ChatCompany get ref => ChatCompany(id: id, name: name, logo: logo);
}

class ContextRequirement {
  const ContextRequirement({
    required this.id,
    required this.title,
    required this.kind,
    required this.status,
    this.budget,
    this.location,
    this.dueDate,
  });

  final String id;
  final String title;

  /// `ENQUIRY` or an RFQ kind.
  final String kind;
  final String status;
  final num? budget;
  final String? location;
  final DateTime? dueDate;

  bool get isEnquiry => kind == 'ENQUIRY';
}

class ContextBid {
  const ContextBid({required this.status, required this.awarded, required this.mine, this.amount});

  final num? amount;
  final String status;
  final bool awarded;
  final bool mine;
}

class ContextMentorship {
  const ContextMentorship({
    required this.id,
    required this.mentee,
    required this.mentorProfileId,
    required this.sessionsCount,
    this.topics = const [],
    this.nextSessionAt,
  });

  final String id;

  /// The reader is the mentee (else the mentor).
  final bool mentee;
  final String mentorProfileId;
  final List<String> topics;
  final int sessionsCount;
  final DateTime? nextSessionAt;
}

class ContextGroupSession {
  const ContextGroupSession({required this.id, required this.title, this.nextAt});

  final String id;
  final String title;
  final DateTime? nextAt;
}

class ContextConsultation {
  const ContextConsultation({
    required this.id,
    required this.title,
    required this.buyer,
    required this.oneOnOne,
    this.scheduledAt,
  });

  final String id;
  final String title;

  /// The reader asked (else answers, as the mentor).
  final bool buyer;

  /// A booked 1:1 sharing the pair's thread (else a written consultation).
  final bool oneOnOne;
  final DateTime? scheduledAt;
}

/// A business event in the thread's timeline: only ever one with a real timestamp.
class ThreadEvent {
  const ThreadEvent({
    required this.id,
    required this.type,
    required this.at,
    this.amount,
    this.mine = false,
    this.label,
  });

  final String id;

  /// BID_SUBMITTED, PURCHASE_ORDER, MENTORSHIP_STARTED, SESSION_HELD,
  /// CONSULTATION_OPENED, CONSULTATION_ANSWERED.
  final String type;
  final DateTime at;
  final num? amount;
  final bool mine;
  final String? label;
}

/// Why the thread exists and what it is about (`GET …/context`).
class ConversationContext {
  const ConversationContext({
    required this.kind,
    this.perspective = Perspective.other,
    this.person,
    this.company,
    this.requirement,
    this.bid,
    this.mentorship,
    this.groupSession,
    this.consultation,
    this.events = const [],
  });

  final ConversationKind kind;
  final Perspective perspective;

  /// The other person in a 1:1; null in a room.
  final ChatPerson? person;
  final ContextCompany? company;
  final ContextRequirement? requirement;
  final ContextBid? bid;
  final ContextMentorship? mentorship;
  final ContextGroupSession? groupSession;
  final ContextConsultation? consultation;
  final List<ThreadEvent> events;
}

// --- shared records and attachments ---------------------------------------

/// The ICR records a message can share as a link (`recordLinks.ts`).
enum RecordType { job, requirement, company, product, mentor, event }

extension RecordTypeWords on RecordType {
  String get label => switch (this) {
    RecordType.job => 'Job',
    RecordType.requirement => 'Requirement',
    RecordType.company => 'Company',
    RecordType.product => 'Product',
    RecordType.mentor => 'Mentor',
    RecordType.event => 'Event',
  };

  String get hint => switch (this) {
    RecordType.job => 'A job posting on ICR',
    RecordType.requirement => 'Your requirements, or one on the open board',
    RecordType.company => 'A company page',
    RecordType.product => 'A product in Supplier Mart',
    RecordType.mentor => "A mentor's profile",
    RecordType.event => 'An upcoming event',
  };

  /// The page a record opens on: `/jobs/<id>`.
  String path(String id) => switch (this) {
    RecordType.job => '/jobs/${Uri.encodeComponent(id)}',
    RecordType.requirement => '/rfq/${Uri.encodeComponent(id)}',
    RecordType.company => '/companies/${Uri.encodeComponent(id)}',
    RecordType.product => '/products/${Uri.encodeComponent(id)}',
    RecordType.mentor => '/mentorship/mentors/${Uri.encodeComponent(id)}',
    RecordType.event => '/events/${Uri.encodeComponent(id)}',
  };

  /// "This job isn't available to you."
  String get unavailable => switch (this) {
    RecordType.job => "This job isn't available to you.",
    RecordType.requirement => "This requirement isn't available to you.",
    RecordType.company => "This company isn't available to you.",
    RecordType.product => "This product isn't available to you.",
    RecordType.mentor => "This mentor's profile isn't available to you.",
    RecordType.event => "This event isn't available to you.",
  };
}

class RecordRef {
  const RecordRef(this.type, this.id);

  final RecordType type;

  /// The id in the page's path; an event's is its slug.
  final String id;

  String get path => type.path(id);

  @override
  bool operator ==(Object other) => other is RecordRef && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);
}

/// What a shared record's card shows, read through the record's own public endpoint.
class RecordFacts {
  const RecordFacts({
    required this.type,
    required this.id,
    required this.title,
    this.owner,
    this.image,
    this.city,
    this.amount,
    this.unit,
    this.date,
    this.years,
    this.kind,
  });

  final RecordType type;
  final String id;
  final String title;

  /// Whose it is: the company, the mentor's headline.
  final String? owner;
  final ChatPicture? image;
  final String? city;
  final num? amount;
  final String? unit;
  final DateTime? date;
  final int? years;
  final String? kind;

  RecordRef get ref => RecordRef(type, id);
}

/// A file the person chose to send, before it is uploaded.
class PickedAttachment {
  const PickedAttachment({required this.name, required this.bytes, this.mimeType, this.declaredSize});

  final String name;
  final Uint8List bytes;
  final String? mimeType;

  /// The file's size when its bytes were not read (a file over the limit is refused by size alone).
  final int? declaredSize;

  int get size => declaredSize ?? bytes.length;
}

/// A file uploaded for a message (`POST /uploads?purpose=message-attachment`), not yet sent.
class UploadedAttachment {
  const UploadedAttachment({required this.url, required this.name, this.size, this.mimeType});

  final String url;
  final String name;
  final int? size;
  final String? mimeType;

  bool get isImage => (mimeType ?? '').startsWith('image/');
}

/// Why a message is reported (`MessageReportReason`).
const messageReportReasons = {
  'SPAM': 'Spam or unwanted promotion',
  'HARASSMENT': 'Harassment or abuse',
  'FRAUD': 'Fraud, scam or impersonation',
  'INAPPROPRIATE': 'Inappropriate or offensive',
  'OTHER': 'Something else',
};

/// Longest message body the API accepts (`MESSAGE_BODY_MAX`).
const messageBodyMax = 4000;

/// Largest file `POST /uploads` takes.
const attachmentMaxBytes = 10 * 1024 * 1024;

/// What a message attachment may be (`upload-types.ts`: images, PDF, and office files for a message).
const attachmentTypes = {
  'pdf': 'application/pdf',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'webp': 'image/webp',
  'doc': 'application/msword',
  'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'ppt': 'application/vnd.ms-powerpoint',
  'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'csv': 'text/csv',
  'txt': 'text/plain',
  'zip': 'application/zip',
};

/// The type a file is uploaded as, from its name; null when the API would refuse it.
String? attachmentMimeFor(String name, [String? given]) {
  if (given != null && attachmentTypes.containsValue(given)) return given;
  final dot = name.lastIndexOf('.');
  if (dot < 0) return null;
  return attachmentTypes[name.substring(dot + 1).toLowerCase()];
}
