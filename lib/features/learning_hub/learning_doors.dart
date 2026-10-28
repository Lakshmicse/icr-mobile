import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../learning_assess/assessment_screen.dart';
import '../learning_assess/mock_tests_screen.dart';
import '../learning_exam/certificates_screen.dart';
import '../learning_exam/my_attempts_screen.dart';
import '../learning_study/flash_cards_screen.dart';
import '../learning_study/knowledge_center_screen.dart';
import '../notifications/notification_scope.dart';
import '../shell/app_shell.dart';
import '../shell/icr_bottom_nav.dart';
import '../shell/shell_page.dart';

/// The six doors of the Learning Center, in the order the website's hub
/// (`frontend/src/features/learning/data/hub.ts`) lists them: the order a
/// candidate works in. Check where you stand, rehearse the paper, revise the
/// terms and the numbers, then commit to a programme, ICR's own first.
///
/// [blurb] is the website's sentence cut to one line for a phone tile;
/// [keywords] are what the hub's search matches besides the title and blurb.
enum LearningDoor {
  assessment(
    title: 'Assess Your Knowledge',
    blurb: 'Short quizzes before you certify',
    cta: 'Start Assessment',
    icon: LucideIcons.clipboardCheck,
    image: 'assets/images/demo/learning/hub_assess.jpg',
    keywords: ['assessment', 'quiz', 'quizzes', 'certification', 'level', 'test'],
  ),
  mockTests(
    title: 'Mock Exams',
    blurb: 'Full-length papers by topic',
    cta: 'Take a Mock Exam',
    icon: LucideIcons.timer,
    image: 'assets/images/demo/learning/hub_mock.jpg',
    keywords: ['mock test', 'mock tests', 'exam', 'paper', 'papers', 'practice', 'practise', 'topic', 'competition'],
  ),
  flashCards(
    title: 'Flash Cards',
    blurb: 'Flip through key terms',
    cta: 'Study Flash Cards',
    icon: LucideIcons.layers,
    image: 'assets/images/demo/learning/hub_flash.jpg',
    keywords: ['flash', 'cards', 'flashcards', 'terms', 'revise', 'revision', 'study', 'resources'],
  ),
  knowledgeCenter(
    title: 'Knowledge Center',
    blurb: 'Formulas with worked numbers',
    cta: 'Browse Knowledge Center',
    icon: LucideIcons.sigma,
    image: 'assets/images/demo/learning/hub_knowledge.jpg',
    keywords: ['knowledge', 'formula', 'formulas', 'calculation', 'calculations', 'centre', 'resources'],
  ),
  icrCourses(
    title: 'ICR Courses',
    blurb: "Enrol on ICR's next batch",
    cta: 'Explore Courses',
    icon: LucideIcons.graduationCap,
    image: 'assets/images/demo/learning/hub_icr.jpg',
    keywords: ['icr', 'course', 'courses', 'enrol', 'enroll', 'batch', 'professional', 'development', 'training'],
  ),
  partnerCourses(
    title: 'Partner Courses',
    blurb: 'Institutes and their courses',
    cta: 'Browse Partners',
    icon: LucideIcons.handshake,
    image: 'assets/images/demo/learning/hub_partner.jpg',
    keywords: ['partner', 'partners', 'institute', 'institutes', 'awarding', 'body', 'bodies', 'courses'],
  );

  const LearningDoor({
    required this.title,
    required this.blurb,
    required this.cta,
    required this.icon,
    required this.image,
    required this.keywords,
  });

  final String title;
  final String blurb;
  final String cta;
  final IconData icon;

  /// The website's tile artwork (`frontend/public/images/learning/`), cropped square-cornered.
  final String image;
  final List<String> keywords;

  /// Whether a hub search ([query], lower case) names this door.
  bool matches(String query) {
    if (query.isEmpty) return true;
    return [title, blurb, cta, ...keywords].join(' ').toLowerCase().contains(query);
  }
}

/// How a door's screen is built, given the pushed route's own context and the
/// arrow that leaves it.
typedef LearningPageBuilder = Widget Function(BuildContext context, VoidCallback onBack);

/// The screens the hub and the course grid open for the doors other builders
/// own. Real screens by default; a test passes light stand-ins, because the
/// real ones build an API repository from the tree.
class LearningRoutes {
  const LearningRoutes({
    this.assessment = _assessment,
    this.mockTests = _mockTests,
    this.flashCards = _flashCards,
    this.knowledgeCenter = _knowledgeCenter,
    this.myAttempts = _myAttempts,
    this.certificates = _certificates,
  });

  final LearningPageBuilder assessment;
  final LearningPageBuilder mockTests;
  final LearningPageBuilder flashCards;
  final LearningPageBuilder knowledgeCenter;
  final LearningPageBuilder myAttempts;
  final LearningPageBuilder certificates;

  static Widget _assessment(BuildContext context, VoidCallback onBack) => AssessmentScreen(onBack: onBack);
  static Widget _mockTests(BuildContext context, VoidCallback onBack) => MockTestsScreen(onBack: onBack);
  static Widget _flashCards(BuildContext context, VoidCallback onBack) => FlashCardsScreen(onBack: onBack);
  static Widget _knowledgeCenter(BuildContext context, VoidCallback onBack) => KnowledgeCenterScreen(onBack: onBack);
  static Widget _myAttempts(BuildContext context, VoidCallback onBack) => MyAttemptsScreen(onBack: onBack);
  static Widget _certificates(BuildContext context, VoidCallback onBack) => CertificatesScreen(onBack: onBack);

  /// The builder for the doors whose screens are not the hub's own (ICR Courses
  /// and Partner Courses are, and the hub opens them itself).
  LearningPageBuilder? forDoor(LearningDoor door) => switch (door) {
    LearningDoor.assessment => assessment,
    LearningDoor.mockTests => mockTests,
    LearningDoor.flashCards => flashCards,
    LearningDoor.knowledgeCenter => knowledgeCenter,
    LearningDoor.icrCourses || LearningDoor.partnerCourses => null,
  };
}

/// Pushes a Learning screen over the shell with the Learning tab lit on its
/// bottom bar, as `lib/app_screens.dart` does for Events. A pushed route sits
/// above the tab's providers, so [page] builds what it needs itself; the bell's
/// unread count and the notification router are laid over the route, so its
/// bell opens the app's notifications with the dot that Home shows.
Future<T?> pushLearningPage<T>(BuildContext context, LearningPageBuilder page) {
  final scope = NotificationScope.of(context);
  return AppShell.push<T>(
    context,
    (route) => scope.wrap(ShellPage(tab: AppTab.learning, child: page(route, () => Navigator.of(route).pop()))),
  );
}
