/// What the Learning hub draws beyond the courses themselves: the partner
/// institutes (`GET /learning/providers`) and the member's own counts.
library;

import '../learning/learning_format.dart';
import '../learning/learning_models.dart';

export '../learning/learning_models.dart' show FeedPicture;

/// A partner awarding body or training institute (`LearningProvider`), as the
/// directory lists it: ICR has taken it on, whether or not it has published a
/// course yet.
class Institute {
  const Institute({
    required this.id,
    required this.name,
    this.slug,
    this.summary,
    this.logo,
    this.website,
    this.verified = false,
    this.courseCount = 0,
  });

  final String id;
  final String name;

  /// The public route param, and what `POST /learning/providers/:slug/enquire` takes.
  final String? slug;
  final String? summary;
  final FeedPicture? logo;
  final String? website;

  /// ICR has verified the institute.
  final bool verified;

  /// Published courses and programmes it awards here.
  final int courseCount;

  /// "AB" for "Aldersgate Brooks": drawn on the plate of an institute with no logo.
  String get initials => courseInitials(name);

  /// An institute can be written to only when it has a public slug.
  bool get canEnquire => slug != null && slug!.isNotEmpty;

  /// "3 courses", "1 course", "No courses published yet".
  String get courseCountLabel => switch (courseCount) {
    0 => 'No courses published yet',
    1 => '1 course',
    _ => '$courseCount courses',
  };
}

/// The member's own places in the Learning Center. A count is null when the
/// API would not give it (a failed read): the strip then shows a dash rather
/// than a zero it does not know.
class MyLearning {
  const MyLearning({this.attempts, this.certificates});

  /// Sittings of assessments and mock exams (`GET /learning/me/attempts`).
  final int? attempts;

  /// Certificates earned (`GET /learning/me/certificates`).
  final int? certificates;
}
