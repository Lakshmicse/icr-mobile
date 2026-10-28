import 'package:flutter/material.dart';

import '../../core/util/links.dart';
import '../learning_exam/open_paper.dart';
import 'assess_models.dart';
import 'assess_repository.dart';
import 'assess_types.dart';
import 'catalogue_screen.dart';

/// Assess Your Knowledge: short topic-based quizzes per certification programme and level, before the real
/// certification. The programmes that have assessment levels as a grid (search, a Free / Paid facet); a card opens
/// the programme's levels (Foundation, Professional, Advanced) with their questions, time, pass mark, the member's
/// best score, whether each is open to them and what opening it takes, the bundle offer, and Start, which hands
/// the paper to the exam (`openPaper`).
///
/// The hub pushes this through its constructor; the screen builds its own controller and repository (a pushed
/// route does not inherit the tab's providers). Tests give their own [opener], [launcher] and [repository].
class AssessmentScreen extends StatelessWidget {
  const AssessmentScreen({
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

  /// The programmes' source; the API (or the sample content) when null.
  final AssessRepository? repository;

  @override
  Widget build(BuildContext context) => CatalogueScreen(
    kind: PaperKind.assessment,
    onBack: onBack,
    opener: opener,
    launcher: launcher,
    payLauncher: payLauncher,
    repository: repository,
  );
}
