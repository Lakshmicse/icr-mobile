/// Saathi, ICR's site assistant, as the app talks to it: the conversation, where the person is, what a reply
/// points to, and the suggestion chips. Mirrors the website's `packages/shared/src/assistant.ts` (`ChatMessage`,
/// `ChatContext`, `QuickAction`, `AssistantSuggestion`, `suggestionsEn`) and `components/assistant/ChatWidget.tsx`.
library;

/// Saathi's name, as the website shows it.
const assistantName = 'Saathi';

/// The website's own words (`common.ChatWidget`), kept byte for byte so both read the same.
abstract final class AssistantCopy {
  static const greeting =
      "Namaste! I'm Saathi 👋 your guide to ICR. Ask me about jobs, suppliers and quotes, mentors, courses, "
      "events or membership, and I'll point you to the right page.";
  static const placeholder = 'Ask about jobs, suppliers, mentors, courses…';
  static const online = 'Online';
  static const troubleResponding = 'I was unable to respond. Try again in a moment.';

  /// The website's line for a 429: asking again straight away would only be refused again.
  static const rateLimited = 'I am receiving many questions right now. Try again in a minute.';
}

enum ChatRole { user, assistant }

/// A page a reply points to, shown as a small button under it.
class QuickAction {
  const QuickAction({required this.label, required this.href});

  factory QuickAction.fromJson(Map<String, dynamic> json) =>
      QuickAction(label: '${json['label'] ?? ''}', href: '${json['href'] ?? ''}');

  final String label;

  /// A root-relative page of the website (`/jobs`, `/mentorship/mentors`).
  final String href;

  @override
  bool operator ==(Object other) => other is QuickAction && other.label == label && other.href == href;

  @override
  int get hashCode => Object.hash(label, href);

  @override
  String toString() => 'QuickAction($label → $href)';
}

/// One turn of the conversation. The buttons on a reply are the screen's: they are never sent back to the API,
/// which reads only role and content.
class AssistantMessage {
  const AssistantMessage(this.role, this.content, {this.actions = const [], this.at});

  const AssistantMessage.user(String content, {DateTime? at}) : this(ChatRole.user, content, at: at);
  const AssistantMessage.assistant(String content, {List<QuickAction> actions = const [], DateTime? at})
    : this(ChatRole.assistant, content, actions: actions, at: at);

  final ChatRole role;
  final String content;
  final List<QuickAction> actions;

  /// When it was said; null for the greeting, which was not.
  final DateTime? at;

  bool get isAssistant => role == ChatRole.assistant;

  AssistantMessage copyWith({String? content, List<QuickAction>? actions}) =>
      AssistantMessage(role, content ?? this.content, actions: actions ?? this.actions, at: at);

  /// What the API reads: role and content only.
  Map<String, String> toJson() => {'role': role.name, 'content': content};
}

/// Where the person is when they ask. Only tailors the wording, the chips and the buttons; no data or permission
/// depends on it, so the API takes it as sent.
class AssistantContext {
  const AssistantContext({this.path, this.signedIn, this.role, this.hasCompany, this.mentor});

  /// The website page that stands for the screen the person is on (`/jobs` for the Jobs tab).
  final String? path;
  final bool? signedIn;
  final String? role;

  /// Whether the member acts for a company; false nudges a person towards the doors a company opens.
  final bool? hasCompany;

  /// Whether the member mentors (a listed mentor, or one with a live mentee): the chips offer their desk. The app's
  /// own, never sent to the API.
  final bool? mentor;

  Map<String, dynamic> toJson() => {
    if (path != null) 'path': path,
    if (signedIn != null) 'signedIn': signedIn,
    if (role != null) 'role': role,
    if (hasCompany != null) 'hasCompany': hasCompany,
  };
}

/// What the reply stream sends: text as it arrives, then the reply's buttons once.
sealed class AssistantEvent {
  const AssistantEvent();
}

class AssistantDelta extends AssistantEvent {
  const AssistantDelta(this.text);

  final String text;
}

class AssistantActions extends AssistantEvent {
  const AssistantActions(this.actions);

  final List<QuickAction> actions;
}

/// A chip above the composer: a page to open ([href]) or a question to ask on the person's behalf ([ask]).
class AssistantSuggestion {
  const AssistantSuggestion.page(this.label, this.href) : ask = null;
  const AssistantSuggestion.ask(this.label, this.ask) : href = null;

  final String label;
  final String? href;
  final String? ask;

  bool get isPage => href != null;
}

/// The website's nine modules, by the page roots that belong to each (`ICR_MODULES` routes and `also` lists).
enum IcrModule {
  mentorship(['/mentorship']),
  jobs(['/jobs', '/companies', '/career']),
  supplierMart(['/vendors', '/products', '/categories', '/rfq']),
  forum(['/community']),
  library(['/documents']),
  learning(['/learning']),
  chaptersCouncils(['/chapters', '/councils']),
  events(['/events']),
  getInvolved(['/get-involved']);

  const IcrModule(this.roots);

  final List<String> roots;

  /// The module a page belongs to (`moduleForPath`): the longest root the path starts with, else null.
  static IcrModule? forPath(String? pathname) {
    if (pathname == null) return null;
    var path = pathname.split('?').first.replaceAll(RegExp(r'/+$'), '');
    if (path.isEmpty) path = '/';
    IcrModule? best;
    var bestLength = 0;
    for (final m in values) {
      for (final root in m.roots) {
        if ((path == root || path.startsWith('$root/')) && root.length > bestLength) {
          best = m;
          bestLength = root.length;
        }
      }
    }
    return best;
  }
}

const _askWhatIcrDoes = AssistantSuggestion.ask('What can I do on ICR?', 'What can I do on ICR?');

/// The doors a company opens, for a member acting as themselves (the website's `UNDECIDED_MEMBER_SUGGESTIONS`).
const _undecidedMember = [
  AssistantSuggestion.ask('Start Selling', 'How do I list my business?'),
  AssistantSuggestion.ask('Hire for a Team', 'How do I post a job?'),
  AssistantSuggestion.ask('Find a Mentor', 'How do I find a mentor?'),
  AssistantSuggestion.ask('Post a Requirement', 'How do I post a requirement?'),
];

/// Each module's own chips (the website's `MODULE_SUGGESTIONS`).
const _moduleSuggestions = <IcrModule, List<AssistantSuggestion>>{
  IcrModule.supplierMart: [
    AssistantSuggestion.page('Request a Quote', '/rfq/new'),
    AssistantSuggestion.ask('Sell on ICR', 'How do I list my business on Supplier Mart?'),
    AssistantSuggestion.ask('Supplier Verification', 'How does supplier verification work?'),
    AssistantSuggestion.page('Marketplace Plans', '/pricing/supplier'),
  ],
  IcrModule.jobs: [
    AssistantSuggestion.page('Browse Jobs', '/jobs'),
    AssistantSuggestion.page('Job Alerts', '/career/alerts'),
    AssistantSuggestion.ask('Post a Job', 'How do I post a job?'),
  ],
  IcrModule.mentorship: [
    AssistantSuggestion.page('Find a Mentor', '/mentorship/mentors'),
    AssistantSuggestion.page('Group Sessions', '/mentorship/groups'),
    AssistantSuggestion.ask('Become a Mentor', 'How do I become a mentor?'),
  ],
  IcrModule.learning: [
    AssistantSuggestion.ask('What can I learn?', 'What courses and certifications are there?'),
    AssistantSuggestion.page('Flash Cards', '/learning/flash-cards'),
    AssistantSuggestion.page('Verify a Certificate', '/learning/verify'),
  ],
  IcrModule.forum: [
    AssistantSuggestion.page('Start a Discussion', '/community/new'),
    AssistantSuggestion.ask('Write an Article', 'How do I write an article?'),
  ],
  IcrModule.library: [
    AssistantSuggestion.page('Resources', '/resources'),
    AssistantSuggestion.ask("What's in the library?", 'What is in the Digital Library?'),
  ],
  IcrModule.chaptersCouncils: [
    AssistantSuggestion.page('Chapters', '/chapters'),
    AssistantSuggestion.page('Councils', '/councils'),
    AssistantSuggestion.ask('Join a Chapter', 'How do I join a chapter?'),
  ],
  IcrModule.events: [
    AssistantSuggestion.page('Browse Events', '/events'),
    AssistantSuggestion.ask('Tickets and RSVPs', 'How do event tickets work?'),
  ],
  IcrModule.getInvolved: [
    AssistantSuggestion.ask('Become a Mentor', 'How do I become a mentor?'),
    AssistantSuggestion.ask('Ways to Contribute', 'How can I volunteer or contribute?'),
  ],
};

/// Three to six chips for where the person is (the website's `suggestionsEn`): the module's own on a module page,
/// otherwise a general set that differs for a signed-in member — their role's own doors first (owner, 6 Nov 2026:
/// a mentor's desk and offerings, a company's hiring, selling and buying) — and again for one with no company.
List<AssistantSuggestion> suggestionsFor(AssistantContext ctx) {
  final module = IcrModule.forPath(ctx.path);
  if (module != null) return _moduleSuggestions[module]!;
  if (ctx.signedIn == true && ctx.hasCompany == false) {
    return [
      if (ctx.mentor == true) const AssistantSuggestion.page('Mentor Dashboard', '/mentorship/mentor'),
      ..._undecidedMember,
    ];
  }
  if (ctx.signedIn == true) {
    final role = ctx.role;
    final forCompany = ctx.hasCompany == true;
    final hires = forCompany && const ['COMPANY_ADMIN', 'RECRUITER', 'BRANCH_ADMIN'].contains(role);
    final sells = forCompany && const ['COMPANY_ADMIN', 'VENDOR'].contains(role);
    final buys = forCompany && const ['COMPANY_ADMIN', 'VENDOR', 'BUYER'].contains(role);
    final chips = <AssistantSuggestion>[
      _askWhatIcrDoes,
      if (ctx.mentor == true) ...const [
        AssistantSuggestion.page('Mentor Dashboard', '/mentorship/mentor'),
        AssistantSuggestion.page('My Offerings', '/mentorship/mentor?tab=services'),
      ] else
        const AssistantSuggestion.ask('Find a Mentor', 'How do I find a mentor?'),
      if (hires) const AssistantSuggestion.page('Post a Job', '/manage/jobs'),
      if (sells) const AssistantSuggestion.page('Enquiries & RFQs', '/manage/bids'),
      if (buys) const AssistantSuggestion.page('Post a Requirement', '/rfq/new'),
    ];
    // At least four chips with Get help: a member whose role brings nothing gets their Dashboard.
    if (chips.length < 3) chips.add(const AssistantSuggestion.page('Dashboard', '/dashboard'));
    chips.add(const AssistantSuggestion.page('Get Help', '/support'));
    return chips;
  }
  return const [
    _askWhatIcrDoes,
    AssistantSuggestion.ask('Find a Job', 'How do I find a job?'),
    AssistantSuggestion.page('Request a Quote', '/rfq/new'),
    AssistantSuggestion.page('Join Free', '/register'),
  ];
}
