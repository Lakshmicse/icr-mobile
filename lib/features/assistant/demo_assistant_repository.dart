import 'assistant_models.dart';
import 'assistant_repository.dart';

/// Saathi's sample answers, for design review and tests: a few of the catalogue's replies, streamed a word at a
/// time as the API's do. It keeps what it was asked.
class DemoAssistantRepository implements AssistantRepository {
  DemoAssistantRepository({this.delay = const Duration(milliseconds: 18)});

  /// The pause between words; zero in a test.
  final Duration delay;

  /// Every question asked, in order, with the context it came with.
  final asked = <({String text, AssistantContext context})>[];

  static final _greeting = RegExp(
    r'^(hi+|hello|hey|hiya|namaste|namaskar|good (morning|afternoon|evening)|greetings)\b[\s!.,]*(saathi|there|icr)?[\s!.,]*$',
    caseSensitive: false,
  );
  static final _thanks = RegExp(r'^(ok(ay)?[\s,]*)?(thanks|thank you|thankyou|thx|ty|great|cool|perfect|got it)\b', caseSensitive: false);

  @override
  Stream<AssistantEvent> ask(List<AssistantMessage> history, AssistantContext context) async* {
    final text = history.lastWhere((m) => m.role == ChatRole.user, orElse: () => const AssistantMessage.user('')).content;
    asked.add((text: text, context: context));
    final (reply, actions) = _answer(text.trim(), context);
    for (final word in reply.split(' ')) {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      yield AssistantDelta(word == reply.split(' ').last ? word : '$word ');
    }
    if (actions.isNotEmpty) yield AssistantActions(actions);
  }

  (String, List<QuickAction>) _answer(String text, AssistantContext context) {
    final lower = text.toLowerCase();
    if (_greeting.hasMatch(text)) {
      return (
        "Hello! I'm Saathi, your guide to ICR. Ask me about jobs, suppliers and quotes, mentors, courses, events or "
            "membership, and I'll point you to the right page.",
        const [QuickAction(label: 'Browse jobs', href: '/jobs'), QuickAction(label: 'Find a mentor', href: '/mentorship/mentors')],
      );
    }
    if (_thanks.hasMatch(text)) return ("You're welcome! Anything else I can help you find?", const []);
    if (lower.contains('mentor')) {
      return (
        'Find Mentors lists every approved ICR mentor with their expertise, languages and availability. Open a profile '
            'and send a mentoring request, or book one of their sessions.',
        const [
          QuickAction(label: 'Find a mentor', href: '/mentorship/mentors'),
          QuickAction(label: 'Group sessions', href: '/mentorship/groups'),
        ],
      );
    }
    if (lower.contains('post a job') || lower.contains('hire')) {
      return (
        'Jobs are posted for a company: from your company\'s Hire workspace, choose Post a job, fill in the title, '
            'description and skills, and publish. Applicants land in your pipeline.',
        const [QuickAction(label: 'Post a job', href: '/manage/jobs/new'), QuickAction(label: 'Job Portal plans', href: '/pricing/corporate')],
      );
    }
    if (lower.contains('job')) {
      return (
        'The Jobs board lists facility-management roles across India. Filter by city, function and experience, save '
            'the ones you like, and apply with your ICR résumé.',
        const [QuickAction(label: 'Browse jobs', href: '/jobs'), QuickAction(label: 'Job alerts', href: '/career/alerts')],
      );
    }
    if (lower.contains('supplier') || lower.contains('quote') || lower.contains('requirement') || lower.contains('sell')) {
      return (
        'Supplier Mart is where buyers find verified suppliers. Post a requirement to receive quotes, or list your '
            'business to be found and bid on requirements.',
        const [QuickAction(label: 'Post a requirement', href: '/rfq/new'), QuickAction(label: 'Supplier Mart', href: '/vendors')],
      );
    }
    if (lower.contains('course') || lower.contains('learn') || lower.contains('certif')) {
      return (
        'The Learning Center has certification courses, assessment levels, mock exams and flash cards. Many open '
            'with your membership; the rest can be bought one at a time.',
        const [QuickAction(label: 'Learning Center', href: '/learning'), QuickAction(label: 'Flash cards', href: '/learning/flash-cards')],
      );
    }
    if (lower.contains('what can i do')) {
      return (
        'On ICR you can find a job or hire, buy from or sell to verified suppliers, find a mentor or mentor others, '
            'learn and get certified, join discussions, chapters and councils, and attend events.',
        const [QuickAction(label: 'Jobs', href: '/jobs'), QuickAction(label: 'Supplier Mart', href: '/vendors'), QuickAction(label: 'Mentorship', href: '/mentorship')],
      );
    }
    return (
      "I'm not sure I've understood that one. I can help you find your way around ICR: Mentorship, Jobs, Supplier "
          'Mart, Discussion Forum, Digital Library, Learning, Chapters & Councils, Events, Get Involved, membership '
          'plans and your company account. Try asking something like "How do I post a job?" or "Where can I find a '
          'mentor?" For anything about your account, the support team can help.',
      const [QuickAction(label: 'Browse jobs', href: '/jobs'), QuickAction(label: 'Support', href: '/support')],
    );
  }
}
