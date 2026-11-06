import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../learning/learning_controller.dart';
import '../learning/learning_screen.dart';
import '../learning_study/api_study_repository.dart';
import '../learning_study/deck_study_screen.dart';
import '../learning_study/demo_study_repository.dart';
import '../learning_study/study_models.dart';
import '../learning_study/study_repository.dart';
import '../notifications/notification_scope.dart';
import 'hub_controller.dart';
import 'hub_factory.dart';
import 'learning_doors.dart' show LearningRoutes;

/// The My courses page on its own — the drawer's Learning › My courses (owner, 6 Nov 2026: "My courses means only
/// the courses which are enrolled, not the Learning page"). It is the course grid with its My courses chip on:
/// what the member holds, filed under the website's headings (Mock Exams, Assess Your Knowledge, Flash Cards, then
/// ICR Courses and Partner Courses), with no Catalogue or hub rows around it — the page the hub's "My courses ·
/// View More" opens, reached straight from the menu.
///
/// Built with no [controller], it makes a hub controller from the API, as the hub does, so the shelves read the
/// same assessments, sets and decks as the hub's row.
class MyCoursesScreen extends StatefulWidget {
  const MyCoursesScreen({super.key, required this.onBack, this.controller, this.routes = const LearningRoutes()});

  final VoidCallback onBack;

  /// A hub to share (the tests hand one in); made from the API when null, and disposed with the screen.
  final LearningHubController? controller;
  final LearningRoutes routes;

  @override
  State<MyCoursesScreen> createState() => _MyCoursesScreenState();
}

class _MyCoursesScreenState extends State<MyCoursesScreen> {
  late final LearningHubController _hub;
  late final bool _ownsHub;

  @override
  void initState() {
    super.initState();
    _ownsHub = widget.controller == null;
    _hub = widget.controller ?? createHubController(context);
    _hub.learning
      ..setSearch('')
      ..setMineOnly(true);
  }

  @override
  void dispose() {
    if (_ownsHub) _hub.dispose();
    super.dispose();
  }

  StudyRepository get _study =>
      _hub.study ?? (AppConfig.demo ? DemoStudyRepository() : ApiStudyRepository(api: context.read<ApiClient>()));

  /// A deck on the Flash Cards shelf opens its study screen, as the hub opens it; a deck read takes one of the
  /// plan's places, so the decks are read again after.
  Future<void> _openDeck(StudyTopic deck) async {
    final scope = NotificationScope.of(context);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => scope.wrap(DeckStudyScreen.deck(repository: _study, deck: deck)),
      ),
    );
    if (mounted) _hub.reloadDecks();
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider<LearningController>.value(
    value: _hub.learning,
    child: LearningScreen(onBack: widget.onBack, title: 'My courses', routes: widget.routes, onOpenDeck: _openDeck),
  );
}
