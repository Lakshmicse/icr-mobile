import 'package:flutter/material.dart';

/// One place a person can go in the app, as the search names it. The catalogue
/// lists what exists; whether the running app can open it is the wiring's call
/// (`lib/app_search.dart` gives each id its opener, and a feature with none is
/// left out of the results).
///
/// Keywords mirror the website's `ASSISTANT_TOPICS`
/// (`packages/shared/src/assistant.ts`): the words a visitor uses for the
/// thing, not only its name.
class AppFeature {
  const AppFeature(
    this.id,
    this.title,
    this.subtitle,
    this.icon,
    this.keywords, {
    this.group,
    this.suggested = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;

  /// Space-separated words and phrases that should find it.
  final String keywords;

  /// The part of the app it belongs to, shown after its subtitle.
  final String? group;

  /// Offered before anything is typed ("Suggested for you").
  final bool suggested;
}

const featureCatalogue = <AppFeature>[
  // The tabs and the spaces on them.
  AppFeature(
    'home',
    'Home',
    'Your feed of discussions and updates',
    Icons.home_outlined,
    'home feed posts timeline updates discussions',
    group: 'Home',
  ),
  AppFeature(
    'jobs',
    'Jobs',
    'Find and apply for roles',
    Icons.work_outline,
    'jobs job openings vacancies careers hiring work apply roles employment',
    group: 'Jobs',
    suggested: true,
  ),
  AppFeature(
    'learning',
    'Learning Centre',
    'Courses, mock exams, flash cards and certificates',
    Icons.school_outlined,
    'learning learn courses course training study cpd certification certified institute',
    group: 'Learning',
  ),
  AppFeature(
    'mentorship',
    'Mentorship',
    'Mentors, programmes and sessions',
    Icons.groups_outlined,
    'mentorship mentors mentor mentoring coach coaching guidance advice',
    group: 'Mentorship',
  ),
  AppFeature(
    'marketplace',
    'Marketplace',
    'Suppliers, products and services',
    Icons.storefront_outlined,
    'marketplace supplier suppliers vendor vendors products services mart buy procure procurement sell',
    group: 'Marketplace',
    suggested: true,
  ),
  AppFeature(
    'forums',
    'Forums',
    'Community discussions and questions',
    Icons.forum_outlined,
    'forum forums community discussions discussion threads questions ask answer topics',
    group: 'Community',
  ),

  // Learning.
  AppFeature(
    'assess',
    'Assess Your Knowledge',
    'Short quizzes before you certify',
    Icons.fact_check_outlined,
    'assess assessment knowledge quiz quizzes test levels check capital planning',
    group: 'Learning',
  ),
  AppFeature(
    'mock',
    'Mock Exams',
    'Full-length papers by topic',
    Icons.timer_outlined,
    'mock exam exams papers practice test timed sit certification prepare',
    group: 'Learning',
    suggested: true,
  ),
  AppFeature(
    'flash',
    'Flash Cards',
    'Flip through key terms',
    Icons.style_outlined,
    'flash cards flashcards decks revise revision memorise terms study',
    group: 'Learning',
  ),
  AppFeature(
    'knowledge',
    'Knowledge Center',
    'Formulas with worked numbers',
    Icons.calculate_outlined,
    'knowledge center centre formulas formula calculators worked examples numbers reference',
    group: 'Learning',
  ),
  AppFeature(
    'attempts',
    'My exam attempts',
    'Papers you have taken and your scores',
    Icons.history_edu_outlined,
    'attempts attempt results result scores score history taken exams my exam',
    group: 'Learning',
  ),
  AppFeature(
    'certificates',
    'Certificates & Badges',
    'What you have earned',
    Icons.workspace_premium_outlined,
    'certificates certificate badges badge earned credentials awards cpd credits',
    group: 'Learning',
  ),

  // Jobs and careers.
  AppFeature(
    'saved_jobs',
    'Saved jobs',
    'Jobs you bookmarked',
    Icons.bookmark_border,
    'saved jobs bookmarked bookmarks shortlist hidden',
    group: 'Jobs',
  ),
  AppFeature(
    'applications',
    'My applications',
    'Where each application stands',
    Icons.assignment_turned_in_outlined,
    'applications application applied status track interview offer my applications',
    group: 'Jobs',
  ),
  AppFeature(
    'job_alerts',
    'Job alerts',
    'Saved searches that tell you about new jobs',
    Icons.notifications_active_outlined,
    'job alerts alert saved search notify new jobs matching',
    group: 'Jobs',
  ),
  AppFeature(
    'interviews',
    'Interviews',
    'Your interview schedule',
    Icons.event_available_outlined,
    'interviews interview schedule slot panel',
    group: 'Jobs',
  ),
  AppFeature(
    'career',
    'Your career',
    'Applications, alerts, interviews and invitations',
    Icons.trending_up,
    'career hub journey progress applications invitations recommendations',
    group: 'Jobs',
  ),
  AppFeature(
    'posted_jobs',
    'Jobs you posted',
    'Post jobs and review applicants',
    Icons.post_add_outlined,
    'post job posted hire hiring recruit recruiter recruitment applicants pipeline ats candidates employer',
    group: 'Jobs',
  ),

  // Mentorship.
  AppFeature(
    'find_mentors',
    'Find mentors',
    'Search mentors by field, company and experience',
    Icons.person_search_outlined,
    'find mentors search mentor expert experts coach advice career guidance book session',
    group: 'Mentorship',
    suggested: true,
  ),
  AppFeature(
    'become_mentor',
    'Become a mentor',
    'Apply to guide others',
    Icons.volunteer_activism_outlined,
    'become mentor apply teach guide volunteer offer sessions paid mentoring join',
    group: 'Mentorship',
  ),
  AppFeature(
    'my_mentoring',
    'My mentoring',
    'Your pairings, sessions, goals and purchases',
    Icons.handshake_outlined,
    'my mentoring pairing pairings sessions goals tasks purchases booked',
    group: 'Mentorship',
  ),
  AppFeature(
    'mentor_desk',
    'Mentor desk',
    'Requests, plans and earnings for mentors',
    Icons.support_agent_outlined,
    'mentor desk requests plans earnings payouts offerings services mentee',
    group: 'Mentorship',
  ),
  AppFeature(
    'programmes',
    'Mentoring programmes',
    'Cohorts you can join',
    Icons.diversity_3_outlined,
    'programme programmes program cohort cohorts structured mentoring apply',
    group: 'Mentorship',
  ),
  AppFeature(
    'group_sessions',
    'Group sessions',
    'Live sessions with mentors',
    Icons.video_camera_front_outlined,
    'group sessions session webinar live room mentoring register seat',
    group: 'Mentorship',
  ),

  // Marketplace.
  AppFeature(
    'post_rfq',
    'Post a requirement',
    'Ask suppliers to quote',
    Icons.note_add_outlined,
    'post requirement rfq enquiry quote quotes tender request proposal buy source',
    group: 'Marketplace',
  ),
  AppFeature(
    'my_rfqs',
    'My requirements',
    'Requirements you posted and the bids on them',
    Icons.request_quote_outlined,
    'my requirements rfqs rfq bids bid quotes received posted enquiries',
    group: 'Marketplace',
  ),
  AppFeature(
    'rfq_alerts',
    'Requirement alerts',
    'Hear about requirements that match you',
    Icons.notifications_none,
    'requirement alerts rfq alerts tender notify matching opportunities supplier',
    group: 'Marketplace',
  ),
  AppFeature(
    'create_company',
    'Create a company',
    'Hire, buy or sell as a company',
    Icons.add_business_outlined,
    'create company page business organisation hire sell supplier start selling register firm',
    group: 'Account',
  ),

  // Community.
  AppFeature(
    'events',
    'Events',
    'Webinars, roundtables and meetups',
    Icons.event_outlined,
    'events event webinars webinar meetups meetup conference roundtable workshop rsvp tickets register',
    group: 'Community',
    suggested: true,
  ),
  AppFeature(
    'councils',
    'Working Councils',
    'Expert councils by theme',
    Icons.account_balance_outlined,
    'councils council working groups committee sustainability esg proptech experts',
    group: 'Community',
  ),
  AppFeature(
    'chapters',
    'Regional Chapters',
    'ICR chapters in your city',
    Icons.public,
    'chapters chapter regional city local bengaluru mumbai delhi meetup',
    group: 'Community',
  ),
  AppFeature(
    'library',
    'Digital Library',
    'Documents shared by members',
    Icons.local_library_outlined,
    'library digital documents document files pdf resources templates download share upload',
    group: 'Community',
  ),
  AppFeature(
    'get_involved',
    'Get Involved & Volunteer',
    'Earn certified CPD credits',
    Icons.favorite_border,
    'get involved volunteer volunteering cpd credits contribute help',
    group: 'Community',
  ),

  // Account.
  AppFeature(
    'profile',
    'My profile',
    'Your résumé, experience and photo',
    Icons.account_circle_outlined,
    'profile my profile resume cv experience education skills photo headline about',
    group: 'Account',
  ),
  AppFeature(
    'settings',
    'Settings & security',
    'Email, mobile number, password and privacy',
    Icons.settings_outlined,
    'settings security password email mobile phone account privacy language delete data sign out',
    group: 'Account',
  ),
  AppFeature(
    'saved',
    'Saved items',
    'Jobs, suppliers and posts you saved',
    Icons.bookmarks_outlined,
    'saved items bookmarks bookmarked saved suppliers saved jobs saved posts',
    group: 'Account',
  ),
  AppFeature(
    'plans',
    'Membership & plans',
    'Compare plans and upgrade',
    Icons.card_membership_outlined,
    'membership plans plan pricing price upgrade subscribe subscription silver gold enterprise premium billing',
    group: 'Account',
    suggested: true,
  ),
  AppFeature(
    'plan_history',
    'Plan history & receipts',
    'Your payments and receipts',
    Icons.receipt_long_outlined,
    'plan history receipts receipt invoices invoice payments billing renew renewal',
    group: 'Account',
  ),
  AppFeature(
    'notifications',
    'Notifications',
    'Everything that happened since you looked',
    Icons.notifications_none,
    'notifications notification bell alerts unread preferences',
    group: 'Account',
  ),
  AppFeature(
    'messages',
    'Messages',
    'Your conversations',
    Icons.chat_bubble_outline,
    'messages message chat inbox conversations conversation dm talk',
    group: 'Account',
  ),
];

/// A feature that matched a query, with how well.
class FeatureMatch {
  const FeatureMatch(this.feature, this.score);

  final AppFeature feature;

  /// 100 is its exact name; below ~30 is a weak guess.
  final int score;

  bool get strong => score >= 70;
}

/// The features [query] is about, best first, keeping only those in
/// [available] (the ones the running app can open; null keeps every one).
///
/// The score favours the name: an exact name (100), a name that starts with the
/// query (85), a name with a word that starts with it (75), then the keywords
/// the same way (60, 50), then any part of the subtitle (25). Every word of a
/// multi-word query has to match somewhere.
List<FeatureMatch> matchFeatures(String query, {Set<String>? available, int limit = 6}) {
  final q = _norm(query);
  if (q.isEmpty) return const [];
  final words = q.split(' ');
  final out = <FeatureMatch>[];
  for (final f in featureCatalogue) {
    if (available != null && !available.contains(f.id)) continue;
    final score = _score(f, q, words);
    if (score > 0) out.add(FeatureMatch(f, score));
  }
  out.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.feature.title.compareTo(b.feature.title);
  });
  return out.length > limit ? out.sublist(0, limit) : out;
}

/// The features offered before anything is typed.
List<AppFeature> suggestedFeatures({Set<String>? available}) => [
  for (final f in featureCatalogue)
    if (f.suggested && (available == null || available.contains(f.id))) f,
];

int _score(AppFeature f, String q, List<String> words) {
  final title = _norm(f.title);
  final keywords = _norm(f.keywords).split(' ').toSet();
  final subtitle = _norm(f.subtitle);

  var total = 0;
  for (final w in words) {
    final one = _scoreWord(title, keywords, subtitle, w);
    if (one == 0) return 0;
    total += one;
  }
  var score = (total / words.length).round();
  if (title == q) {
    score = 100;
  } else if (title.startsWith(q)) {
    score = score < 85 ? 85 : score;
  }
  return score;
}

int _scoreWord(String title, Set<String> keywords, String subtitle, String w) {
  if (title == w) return 100;
  final titleWords = title.split(' ');
  if (titleWords.contains(w)) return 90;
  if (title.startsWith(w)) return 85;
  if (titleWords.any((t) => t.startsWith(w))) return 75;
  if (keywords.contains(w)) return 60;
  if (w.length >= 2 && keywords.any((k) => k.startsWith(w))) return 50;
  if (w.length >= 3 && subtitle.contains(w)) return 25;
  return 0;
}

String _norm(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
