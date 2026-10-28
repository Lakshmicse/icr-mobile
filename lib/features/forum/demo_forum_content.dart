/// The designs' sample content, shared by the Home feed's demo source and the Forums demo source: the four
/// designed discussions, two more for the Forums tab, and the first discussion's conversation (Arvind Swamy's
/// reply, "VP Sustainability" at Brookfield Properties, with the eight answers the design counts under it).
library;

import '../feed/feed_models.dart';

const _demo = 'assets/images/demo';

class DemoForumContent {
  DemoForumContent({DateTime? now}) : now = now ?? DateTime.now();

  final DateTime now;

  static const me = FeedAuthor(id: 'me', name: 'Rahul Mehta', photo: FeedPicture.asset('$_demo/avatar_me.jpg'));

  static const arvind = FeedAuthor(
    id: 'arvind',
    name: 'Arvind Swamy',
    headline: 'VP Sustainability at Brookfield Properties',
    photo: FeedPicture.asset('$_demo/avatar_arvind.jpg'),
  );
  static const priya = FeedAuthor(id: 'priya', name: 'Priya Nambiar', headline: 'Facilities Lead at Infosys');
  static const sarah = FeedAuthor(
    id: 'sarah',
    name: 'Sarah Jenkins',
    headline: 'Senior Facilities Manager at Google',
    photo: FeedPicture.asset('$_demo/avatar_sarah.jpg'),
  );
  static const david = FeedAuthor(
    id: 'david',
    name: 'David Chen',
    headline: 'Project Director at BuildCo',
    photo: FeedPicture.asset('$_demo/avatar_david.jpg'),
  );
  static const marcus = FeedAuthor(
    id: 'marcus',
    name: 'Marcus Reed',
    headline: 'Lead Architect at DesignCo',
    photo: FeedPicture.asset('$_demo/avatar_marcus.jpg'),
  );
  static const elena = FeedAuthor(
    id: 'elena',
    name: 'Elena Rostova',
    headline: 'Civil & Sustainability Engineer',
    photo: FeedPicture.asset('$_demo/avatar_elena.jpg'),
  );
  static const vikram = FeedAuthor(id: 'vikram', name: 'Vikram Iyer', headline: 'Head of FM at Prestige Group');
  static const rajesh = FeedAuthor(id: 'rajesh', name: 'Rajesh Kumar', headline: 'Procurement Lead · Tata Realty');
  static const fatima = FeedAuthor(id: 'fatima', name: 'Fatima Sheikh', headline: 'ESG and net-zero for buildings');
  static const sanjay = FeedAuthor(id: 'sanjay', name: 'Sanjay Menon', headline: 'Contracts Manager at JLL');
  static const karthik = FeedAuthor(id: 'karthik', name: 'Karthik Subramanian', headline: 'Energy Engineer at CBRE');

  static const spotOn =
      'Spot on Priya. Niagara framework BACnet/IP telemetry cut vendor lock-in completely across our commercial '
      'assets.';

  DateTime _ago(Duration d) => now.subtract(d);

  FeedReply _reply(
    String id,
    FeedAuthor who,
    String body,
    Duration age, {
    int likes = 0,
    String? parentId,
    List<FeedReply> children = const [],
  }) {
    final headline = who.headline;
    final at = headline == null ? -1 : headline.indexOf(RegExp(r'\s(?:at|@|·)\s+'));
    return FeedReply(
      id: id,
      author: who,
      body: body,
      createdAt: _ago(age),
      meta: headline == null
          ? null
          : at < 0
          ? headline
          : headline.substring(at).replaceFirst(RegExp(r'^\s(?:at|@|·)\s+'), ''),
      role: at < 0 ? null : headline!.substring(0, at),
      likes: likes,
      parentId: parentId,
      children: children,
    );
  }

  /// Sarah's conversation: Arvind's reply first (three likes), its branch (his own first answer, as the design
  /// draws it, then eight more, the newest Priya Nambiar's), then three more threads.
  List<FeedReply> get sarahReplies => [
    _reply(
      'r1',
      arvind,
      spotOn,
      const Duration(minutes: 42),
      likes: 3,
      children: [
        // The design draws Arvind's answer to himself as the branch's first tile, word for word.
        _reply('r2', arvind, spotOn, const Duration(minutes: 42), likes: 3, parentId: 'r1'),
        _reply(
          'r3',
          priya,
          'Thanks Arvind. Did you keep the legacy controllers or replace them?',
          const Duration(minutes: 33),
          likes: 1,
          parentId: 'r1',
          children: [
            _reply(
              'r4',
              arvind,
              'Kept them. Niagara supervises the old controllers and maps their points over BACnet/IP, so nothing had '
                  'to be ripped out.',
              const Duration(minutes: 29),
              likes: 2,
              parentId: 'r3',
            ),
          ],
        ),
        _reply(
          'r5',
          vikram,
          'Same approach on our retrofit. Point mapping took longer than the sensors did.',
          const Duration(minutes: 26),
          parentId: 'r1',
        ),
        _reply(
          'r6',
          rajesh,
          'Ask each vendor for their BACnet PICS before you shortlist. It saves a lot of arguing later.',
          const Duration(minutes: 22),
          likes: 4,
          parentId: 'r1',
        ),
        _reply(
          'r7',
          fatima,
          'And budget for sensor re-baselining. We recalibrated twice in the first year.',
          const Duration(minutes: 18),
          parentId: 'r1',
        ),
        _reply(
          'r8',
          sanjay,
          'Put data ownership in the contract, not just the integration scope.',
          const Duration(minutes: 13),
          parentId: 'r1',
        ),
        _reply(
          'r9',
          karthik,
          'Phase it: one AHU zone first, prove the savings, then roll out.',
          const Duration(minutes: 9),
          parentId: 'r1',
        ),
        _reply(
          'r10',
          priya,
          'Great tips everyone. The PICS point is going straight into our RFP.',
          const Duration(minutes: 6),
          parentId: 'r1',
        ),
      ],
    ),
    _reply(
      'f1',
      elena,
      'We went with wireless LoRaWAN sensors on the return air path. No cabling into a 15-year-old ceiling void, and '
          'the payback was under two years.',
      const Duration(minutes: 110),
      likes: 2,
    ),
    _reply(
      'f2',
      vikram,
      'Check whether your BMS exposes BACnet/IP or only MS/TP. That decides whether you need a gateway or can '
          'integrate directly.',
      const Duration(minutes: 96),
      likes: 1,
    ),
    _reply(
      'f3',
      karthik,
      "Don't skip the commissioning data. Without a clean baseline you can't prove the peak-load saving afterwards.",
      const Duration(minutes: 80),
    ),
  ];

  /// The four designed discussions, as the Home design draws them.
  List<FeedPost> get designed => [
    FeedPost(
      id: 'iot-hvac',
      slug: 'implementing-iot-sensors-for-hvac-efficiency',
      author: sarah,
      createdAt: _ago(const Duration(hours: 2)),
      topic: 'Sustainability',
      topicTone: TopicTone.green,
      // The design breaks this title after "HVAC".
      title: 'Implementing IoT sensors for HVAC\nefficiency: Best practices?',
      body:
          'We are currently looking to retrofit a 15- year-old commercial building with modern IoT sensors '
          'to better manage our HVAC load during peak hours. Has anyone successfully implemented a system that '
          'integrates smoothly with legacy BMS? Looking for recommendations on vendors that balance cost with '
          'reliability.',
      tags: const ['#HVAC', '#PropTech', '#SmartBMS'],
      reactions: 184,
      reactionKinds: const [ReactionKind.like, ReactionKind.insightful, ReactionKind.celebrate],
      comments: 52,
      shares: 14,
      showFollow: true,
      replyTo: 'Priya Nambiar',
      repliesLoaded: true,
      replies: sarahReplies.take(1).toList(),
      kind: ThreadKind.question,
      pinned: true,
    ),
    FeedPost(
      id: 'ai-feasibility',
      slug: 'the-impact-of-ai-on-preliminary-site-feasibility-analysis',
      author: david,
      createdAt: _ago(const Duration(hours: 5)),
      topic: 'Real Estate Tech',
      topicTone: TopicTone.blue,
      title: 'The impact of AI on preliminary site feasibility analysis',
      body:
          "I've been experimenting with several new AI tools aimed at automating preliminary site feasibility "
          "studies. While the speed is impressive, I'm finding the data heavily relies on outdated municipal "
          'records in certain regions.',
      images: const [FeedPicture.asset('$_demo/post_control_room.jpg')],
      imageCaption: 'BIM Feasibility Lab',
      reactions: 184,
      reactionKinds: const [ReactionKind.like, ReactionKind.insightful, ReactionKind.celebrate],
      comments: 52,
      shares: 14,
      showFollow: true,
      replyTo: 'David Chen',
      pinned: true,
    ),
    FeedPost(
      id: 'fm-software-poll',
      slug: 'what-is-your-primary-fm-software-in-2026',
      author: marcus,
      createdAt: _ago(const Duration(hours: 10)),
      topic: 'Poll',
      topicTone: TopicTone.blue,
      title: 'What is your primary FM Software in 2026?',
      body: 'Select the ecosystem your team relies on for facility workflows.',
      poll: const FeedPoll(
        id: 'poll',
        totalVotes: 842,
        myOptionId: 'archibus',
        timeLeft: '2 days left',
        options: [
          FeedPollOption(id: 'tririga', label: 'IBM TRIRIGA', votes: 236),
          FeedPollOption(id: 'planon', label: 'Planon', votes: 118),
          FeedPollOption(id: 'archibus', label: 'Archibus', votes: 387),
          FeedPollOption(id: 'other', label: 'Other / Custom In-House', votes: 101),
        ],
      ),
      comments: 31,
      replyTo: 'Marcus Reed',
      pinned: true,
    ),
    FeedPost(
      id: 'site-audit',
      slug: 'site-audit-implementing-sustainable-net-zero-solutions',
      author: elena,
      createdAt: _ago(const Duration(hours: 8)),
      topic: 'Site Audit',
      topicTone: TopicTone.green,
      title: 'Site Audit: Implementing Sustainable Net-Zero Solutions',
      body:
          "Just wrapped up an incredible site visit. It's fascinating to see how the integration of smart "
          'climate control systems and renewable energy sources can transform an existing structure into a '
          'beacon of sustainability.',
      images: const [
        FeedPicture.asset('$_demo/post_green_tower.jpg'),
        FeedPicture.asset('$_demo/post_rooftop_hvac.jpg'),
      ],
      morePhotos: 3,
      reactions: 184,
      reactionKinds: const [ReactionKind.like, ReactionKind.insightful, ReactionKind.celebrate],
      comments: 52,
      shares: 14,
      replyTo: 'Elena Rostova',
      pinned: true,
    ),
  ];

  /// Two more for the Forums tab: a member's question with no answer yet, and the reader's own discussion.
  List<FeedPost> get more => [
    FeedPost(
      id: 'amc-escalation',
      slug: 'what-does-a-fair-amc-escalation-clause-look-like',
      author: rajesh,
      createdAt: _ago(const Duration(days: 1, hours: 3)),
      topic: 'Procurement & Supply Chain',
      topicTone: TopicTone.blue,
      title: 'What does a fair AMC escalation clause look like across multiple cities?',
      body:
          'Our AMCs run on city-by-city contracts and the escalation terms are all over the place. Is there a '
          'sensible way to standardise a clause without losing the local wage differences?',
      tags: const ['#AMC', '#Contracts'],
      kind: ThreadKind.question,
      views: 410,
      showFollow: true,
    ),
    FeedPost(
      id: 'bms-partner',
      slug: 'shortlisting-a-bms-retrofit-partner-for-a-12-site-campus-portfolio',
      author: me,
      createdAt: _ago(const Duration(days: 3)),
      topic: 'Technology',
      topicTone: TopicTone.blue,
      title: 'Shortlisting a BMS retrofit partner for a 12-site campus portfolio',
      body:
          'We are about to retrofit the BMS across twelve campuses, most of them on different legacy controllers. '
          'Before we go to RFP I would like to hear how others scored integrators.',
      tags: const ['#BMS', '#Retrofit'],
      kind: ThreadKind.question,
      reactions: 13,
      reactionKinds: const [ReactionKind.like, ReactionKind.insightful],
      comments: 3,
      views: 640,
      saved: true,
    ),
  ];
}
