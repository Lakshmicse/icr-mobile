import 'hub_models.dart';
import 'hub_repository.dart';

/// A little sample content for `--dart-define=FEED_SOURCE=demo`: two institutes
/// and a few counts. The design has no Learning hub, so none of it is measured.
class DemoLearningHubRepository implements LearningHubRepository {
  final enquiries = <String>[];

  @override
  Future<List<Institute>> institutes() async => const [
    Institute(
      id: 'demo-vinfraa',
      name: 'Vinfraa Institute',
      slug: 'vinfraa',
      summary: 'Facility management certifications delivered through ICR.',
      logo: FeedPicture.asset('assets/images/demo/learning/badge_partner.png'),
      verified: true,
    ),
    Institute(
      id: 'demo-icr',
      name: 'ICR Institute',
      slug: 'icr-institute',
      summary: "ICR's own institute for professional development and certification.",
      logo: FeedPicture.asset('assets/images/demo/learning/badge_icr.png'),
    ),
  ];

  @override
  Future<MyLearning> myLearning() async => const MyLearning(attempts: 3, certificates: 1);

  @override
  Future<void> enquireInstitute(Institute institute, {required String message}) async {
    enquiries.add('${institute.slug}: $message');
  }
}
