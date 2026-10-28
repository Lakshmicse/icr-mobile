import 'messaging_format.dart';
import 'messaging_models.dart';

/// What a thread says it is about, under its header, and the openers offered
/// before anyone has written. Pure (no widgets), a port of the website's
/// `chatContext.ts` + `contextLinks.ts`, so the rules can be tested alone.

// --- where each piece of context opens ---------------------------------------

/// A requirement is three pages by who looks: its owner manages it, a supplier
/// works it (their bid sits there), anyone else reads the posting.
String requirementHref(String rfqId, Perspective perspective) => switch (perspective) {
  Perspective.owner => '/manage/requirements/${Uri.encodeComponent(rfqId)}',
  Perspective.supplier => '/manage/bids/${Uri.encodeComponent(rfqId)}',
  Perspective.other => '/rfq/${Uri.encodeComponent(rfqId)}',
};

/// A bid has no page of its own: the supplier's is their bid page, the owner's the requirement's bids.
String bidHref(String rfqId, Perspective perspective) => perspective == Perspective.supplier
    ? '/manage/bids/${Uri.encodeComponent(rfqId)}'
    : '/manage/requirements/${Uri.encodeComponent(rfqId)}';

String mentorshipHref(String id) => '/mentorship/my/${Uri.encodeComponent(id)}';
String groupSessionHref(String id) => '/mentorship/groups/${Uri.encodeComponent(id)}';
String consultationHref({required bool buyer}) =>
    buyer ? '/mentorship/my?tab=purchases' : '/mentorship/mentor?tab=work';
String companyHref(String id) => '/companies/${Uri.encodeComponent(id)}';
String memberHref(String id) => '/members/${Uri.encodeComponent(id)}';

// --- the strip -------------------------------------------------------------------

/// What a small chat window says the conversation is about: the kind and
/// where the reader stands on it ("Enquiry · Chennai · Closes 4 Nov"), then
/// the record's name. [href] is where a tap goes; null when it has no page.
class ContextStripModel {
  const ContextStripModel({required this.title, required this.facts, this.href});

  /// The record's own name (a requirement's title, a session's) or a thread's title.
  final String? title;
  final String? href;

  /// Already worded, in order ("Enquiry", "Chennai", "Closes 4 Nov").
  final List<String> facts;

  /// The strip's two lines: the facts, then the name (the first fact stands in for a missing name).
  ({String? line, String name}) get lines {
    final name = title ?? (facts.isEmpty ? '' : facts.first);
    final rest = title != null ? facts : (facts.isEmpty ? <String>[] : facts.sublist(1));
    return (line: rest.isEmpty ? null : rest.join(' · '), name: name);
  }
}

const _shut = {'CLOSED', 'AWARDED', 'CANCELLED', 'EXPIRED'};

/// The strip under a thread's header. A requirement thread names the requirement
/// and where the reader stands on it (their reply, else its deadline); a
/// mentorship its next session; a room or a consultation itself; any other
/// thread with a title ("Fleet supervisor, Chennai" for a job) that title. A
/// plain conversation between people has none.
ContextStripModel? contextStripModel(ConversationContext? context, String? conversationTitle, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final c = context;
  if (c != null && c.requirement != null && c.kind.isRequirement) {
    final r = c.requirement!;
    final facts = <String>[r.isEnquiry ? 'Enquiry' : 'RFQ'];
    if (r.location != null) facts.add(r.location!);
    final bid = c.bid;
    if (bid != null && bid.awarded) {
      facts.add('Awarded');
    } else if (bid != null) {
      final who = bid.mine ? 'You replied' : 'They replied';
      facts.add(bid.amount != null ? '$who · ${rupees(bid.amount!)}' : who);
    } else if (_shut.contains(r.status)) {
      facts.add('Closed');
    } else if (r.dueDate != null) {
      facts.add(r.dueDate!.isBefore(current) ? 'Closed' : 'Closes ${shortDate(r.dueDate!, now: current)}');
    }
    return ContextStripModel(title: r.title, href: requirementHref(r.id, c.perspective), facts: facts);
  }
  final m = c?.mentorship;
  if (m != null) {
    final facts = <String>['Mentoring'];
    final next = m.nextSessionAt;
    if (next != null && !next.isBefore(current)) {
      facts.add('Next session ${weekdayDate(next)}, ${clockTime(next)}');
    } else if (m.sessionsCount > 0) {
      facts.add(m.sessionsCount == 1 ? '1 session' : '${m.sessionsCount} sessions');
    }
    final topics = m.topics.take(2).join(', ');
    return ContextStripModel(title: topics.isEmpty ? null : topics, href: mentorshipHref(m.id), facts: facts);
  }
  final g = c?.groupSession;
  if (g != null) {
    final facts = <String>['Group session'];
    final next = g.nextAt;
    if (next != null && !next.isBefore(current)) facts.add('Next session ${weekdayDate(next)}, ${clockTime(next)}');
    return ContextStripModel(title: g.title, href: groupSessionHref(g.id), facts: facts);
  }
  final k = c?.consultation;
  if (k != null) {
    final facts = <String>['Consultation'];
    final at = k.scheduledAt;
    if (at != null && !at.isBefore(current)) facts.add('Next session ${weekdayDate(at)}, ${clockTime(at)}');
    return ContextStripModel(
      title: k.title,
      href: consultationHref(buyer: k.buyer),
      facts: facts,
    );
  }
  if (conversationTitle != null && conversationTitle.trim().isNotEmpty) {
    return ContextStripModel(title: conversationTitle, facts: const ['About']);
  }
  return null;
}

// --- openers for an empty thread ---------------------------------------------------

/// A chip an empty thread offers; tapping it puts [text] in the composer.
class Starter {
  const Starter(this.key, this.text);

  final String key;
  final String text;
}

const _starterText = {
  'stillOpen': 'Is this still open for quotes?',
  'siteVisit': 'Can we visit the site first?',
  'shareScope': 'Could you share the scope or BOQ?',
  'shareQuote': 'Could you share your quote?',
  'whenStart': 'When could you start?',
  'references': 'Could you share references from similar work?',
  'menteeNext': 'When are you free for our next session?',
  'menteeGoals': 'Could we go over my goals?',
  'mentorNext': 'When suits you for our next session?',
  'mentorGoals': 'How are your goals going?',
};

/// Openers by who the reader is in the thread: a supplier asks about the
/// work, the buyer about the supplier's offer, a mentee and a mentor about
/// their next session. Anything else starts with a plain hello (no chips).
List<Starter> starters(ConversationContext? context) {
  final c = context;
  if (c == null) return const [];
  List<Starter> pick(List<String> keys) => [for (final k in keys) Starter(k, _starterText[k]!)];
  if (c.kind.isRequirement && c.requirement != null) {
    return switch (c.perspective) {
      Perspective.supplier => pick(['stillOpen', 'siteVisit', 'shareScope']),
      Perspective.owner => pick(['shareQuote', 'whenStart', 'references']),
      Perspective.other => const [],
    };
  }
  if (c.kind == ConversationKind.mentorship && c.mentorship != null) {
    return c.mentorship!.mentee ? pick(['menteeNext', 'menteeGoals']) : pick(['mentorNext', 'mentorGoals']);
  }
  return const [];
}

/// The sentence that introduces an empty thread.
String introText(ConversationContext? context) {
  final c = context;
  if (c != null && c.kind.isRequirement && c.requirement != null) {
    if (c.perspective == Perspective.supplier) {
      return 'Ask about the scope, a site visit or the timeline before you reply. Their buying team sees your messages.';
    }
    if (c.perspective == Perspective.owner) {
      return 'Ask about their quote, their timeline or similar work they have done.';
    }
  }
  if (c?.kind == ConversationKind.mentorship) return 'Say hello and agree how you would like to work together.';
  return 'No messages yet — say hello.';
}

// --- business events inside the thread -------------------------------------------

/// A business event drawn as a line across the timeline: how it reads, and
/// the record it opens (null for none).
({String title, String? action, String? href}) eventLine(ThreadEvent e, ConversationContext? context) {
  final enquiry = context?.requirement?.isEnquiry ?? false;
  final rfqId = context?.requirement?.id;
  final perspective = context?.perspective ?? Perspective.other;
  switch (e.type) {
    case 'BID_SUBMITTED':
      final title = enquiry
          ? (e.mine ? 'You replied' : 'They replied')
          : (e.mine ? 'Your bid submitted' : 'Bid submitted');
      return (
        title: e.amount != null ? '$title · ${rupees(e.amount!)}' : title,
        action: rfqId == null ? null : (enquiry ? 'View reply' : 'View bid'),
        href: rfqId == null ? null : bidHref(rfqId, perspective),
      );
    case 'PURCHASE_ORDER':
      return (
        title: 'Purchase order ${e.label ?? ''} issued'.replaceAll('  ', ' '),
        action: rfqId == null ? null : 'View bid',
        href: rfqId == null ? null : bidHref(rfqId, perspective),
      );
    case 'MENTORSHIP_STARTED':
      final m = context?.mentorship;
      return (
        title: 'Mentorship started',
        action: m == null ? null : 'Open mentorship',
        href: m == null ? null : mentorshipHref(m.id),
      );
    case 'SESSION_HELD':
      final m = context?.mentorship;
      return (
        title: e.label != null ? 'Session held: ${e.label}' : 'Session held',
        action: m == null ? null : 'Open mentorship',
        href: m == null ? null : mentorshipHref(m.id),
      );
    case 'CONSULTATION_OPENED':
    case 'CONSULTATION_ANSWERED':
      final k = context?.consultation;
      return (
        title: e.type == 'CONSULTATION_OPENED' ? 'Consultation opened' : 'Consultation answered',
        action: k == null ? null : 'Open consultation',
        href: k == null ? null : consultationHref(buyer: k.buyer),
      );
  }
  return (title: e.label ?? 'Update', action: null, href: null);
}
