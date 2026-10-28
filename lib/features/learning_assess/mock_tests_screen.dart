import 'package:flutter/material.dart';

import '../../core/util/links.dart';
import '../learning_exam/open_paper.dart';
import 'assess_models.dart';
import 'assess_repository.dart';
import 'assess_types.dart';
import 'catalogue_screen.dart';

/// Mock Exams: full-length competition papers by topic, three sets each. The subjects as a grid (search, a Free /
/// Paid facet, the cover artwork); a card opens the subject's sets, each with its questions, time, pass mark,
/// attempts and the member's best score, whether it is open to them and what opening it takes, and Start, which
/// hands the set to the exam (`openPaper`, a mock).
///
/// The hub pushes this through its constructor; the screen builds its own controller and repository. Tests give
/// their own [opener], [launcher] and [repository].
class MockTestsScreen extends StatelessWidget {
  const MockTestsScreen({
    super.key,
    required this.onBack,
    this.opener = openPaper,
    this.launcher = openUrl,
    this.payLauncher = openExternal,
    this.repository,
  });

  /// The arrow at the top left.
  final VoidCallback onBack;

  /// Opens a paper (its brief, the exam, the result).
  final PaperOpener opener;

  /// Hands a page of the website that the app may draw itself (the plans, the bell) to the app.
  final SiteLauncher launcher;

  /// Hands a payment page to the phone's browser (PayU runs on the website, not in the app).
  final SiteLauncher payLauncher;

  /// The subjects' source; the API (or the sample content) when null.
  final AssessRepository? repository;

  @override
  Widget build(BuildContext context) => CatalogueScreen(
    kind: PaperKind.mock,
    onBack: onBack,
    opener: opener,
    launcher: launcher,
    payLauncher: payLauncher,
    repository: repository,
  );
}
