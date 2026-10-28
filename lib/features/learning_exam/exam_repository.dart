import 'exam_models.dart';

/// Thrown when the API refuses to serve a paper: the member has not opened it.
/// Carries what would open it.
class PaperLockedException implements Exception {
  PaperLockedException(this.lock);

  final PaperLock lock;

  @override
  String toString() => lock.message;
}

/// One answer in a submission: the question and the option indexes picked
/// (empty when skipped).
class SubmittedAnswer {
  const SubmittedAnswer(this.questionId, this.selected);

  final String questionId;
  final List<int> selected;

  Map<String, dynamic> toJson() => {'questionId': questionId, 'selected': selected};
}

/// Where the exam flow gets its papers and sends its answers: the API, or a
/// little sample content for the design-review build.
abstract class ExamRepository {
  /// The paper with its questions, ready to sit. Throws [PaperLockedException]
  /// when the member has not opened it.
  Future<PaperSitting> sitting(String slug);

  /// A paper's parameters without its questions (the public list), for the
  /// brief of a paper the member cannot open yet.
  Future<PaperInfo> info(PaperRef ref);

  /// What opening the paper costs this member.
  Future<PaperQuote> quote(String slug);

  /// Spends ICR credits to open the paper for good.
  Future<RedeemResult> redeem(String slug);

  /// Opens the whole course or mock exam the paper sits under with one of the
  /// plan's places ([target] is `COURSE` or `MOCK_EXAM`).
  Future<void> openWithPlan({required String target, required String targetId});

  /// The member's sittings, newest first; of one paper when [paperId] is given.
  Future<List<Attempt>> attempts({String? paperId});

  /// One past sitting with its review.
  Future<AttemptResult> attempt(String id);

  /// Sends the answers; the server scores them. [startedAt] is the sitting's
  /// own start, which also identifies it should the answer never arrive.
  Future<AttemptResult> submit(String slug, {required DateTime startedAt, required List<SubmittedAnswer> answers});

  /// The member's certificates, newest first.
  Future<List<ExamCertificate>> certificates();

  /// Looks a certificate up by its printed number, as anyone may (`GET /learning/certificates/:number`, no
  /// sign-in needed). Null when there is no such certificate.
  Future<ExamCertificate?> verifyCertificate(String certificateId);

  /// The unread count on the bell.
  Future<int> unreadNotifications();

  /// A page of the website.
  Uri sitePage(String path);
}
