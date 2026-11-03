import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import '../learning/learning_controller.dart';
import '../learning/learning_models.dart';
import '../learning/opened_learning.dart';
import '../learning_assess/assess_models.dart';
import '../learning_assess/assess_repository.dart';
import '../learning_study/study_models.dart';
import '../learning_study/study_repository.dart';
import 'hub_models.dart';
import 'hub_repository.dart';
import 'learning_doors.dart';

/// The Learning hub's state: the design's sections — the assessment
/// programmes, the mock exam subjects, the flash-card decks, ICR's and the
/// partners' courses — the institutes, the member's counts, narrowed by the
/// header's search.
///
/// The courses live in a [LearningController] (the one the ICR Courses grid and
/// the course sheet read too), so a place taken in the sheet is in step
/// everywhere. The hub adds the papers ([assess]), the decks ([study]), the
/// institutes, the attempt and certificate counts and the institute enquiry.
/// A hub built without [assess] or [study] (an older test) simply has no such
/// section.
class LearningHubController extends ChangeNotifier {
  LearningHubController({
    required this.repository,
    required this.learning,
    this.assess,
    this.study,
    this.ownsLearning = false,
  }) {
    learning.addListener(_relay);
  }

  final LearningHubRepository repository;
  final LearningController learning;
  final AssessRepository? assess;
  final StudyRepository? study;

  /// The hub made [learning] and disposes it with itself.
  final bool ownsLearning;

  /// How many cards a section holds before "View More".
  static const gridLimit = 6;
  static const courseRailLimit = 9;
  static const instituteRailLimit = 12;

  List<Institute> _institutes = const [];
  bool _institutesLoading = false;
  String? _institutesError;
  List<PaperGroup> _assessments = const [];
  bool _assessLoading = false;
  String? _assessError;
  List<PaperGroup> _mocks = const [];
  bool _mockLoading = false;
  String? _mockError;
  List<StudyTopic> _decks = const [];
  bool _decksLoading = false;
  String? _decksError;
  MyLearning _mine = const MyLearning();
  bool _mineLoading = false;
  MemberAccess? _access;
  String _search = '';
  bool _started = false;
  bool _disposed = false;
  int _generation = 0;

  bool get started => _started;
  String get search => _search;
  bool get narrowed => _search.isNotEmpty;

  bool _hit(String? text) => _search.isEmpty || (text?.toLowerCase().contains(_search) ?? false);

  // --- the papers and the decks ---------------------------------------------

  /// The assessment programmes the search matches, the first few.
  List<PaperGroup> get assessmentsShown => _grid(_assessments);

  /// The mock exam subjects the search matches, the first few.
  List<PaperGroup> get mocksShown => _grid(_mocks);

  List<PaperGroup> _grid(List<PaperGroup> all) => [
    for (final g in all)
      if (_hit(g.title) || _hit(g.summary)) g,
  ].take(gridLimit).toList();

  bool get assessLoading => _assessLoading && _assessments.isEmpty;
  String? get assessError => _assessments.isEmpty ? _assessError : null;
  bool get mockLoading => _mockLoading && _mocks.isEmpty;
  String? get mockError => _mocks.isEmpty ? _mockError : null;

  /// The flash-card decks (never the formula shelves) the search matches.
  List<StudyTopic> get decksShown => [
    for (final d in _decks)
      if (_hit(d.title) || _hit(d.description)) d,
  ];

  bool get decksLoading => _decksLoading && _decks.isEmpty;
  String? get decksError => _decks.isEmpty ? _decksError : null;

  // --- the institutes ------------------------------------------------------

  List<Institute> get institutes => _institutes;
  bool get institutesLoading => _institutesLoading && _institutes.isEmpty;
  String? get institutesError => _institutes.isEmpty ? _institutesError : null;

  /// The institutes the search matches: name or summary.
  List<Institute> get institutesShown {
    if (_search.isEmpty) return _institutes;
    return [
      for (final i in _institutes)
        if (i.name.toLowerCase().contains(_search) || (i.summary?.toLowerCase().contains(_search) ?? false)) i,
    ];
  }

  // --- the courses -----------------------------------------------------------

  bool get coursesLoading => learning.loading && learning.courses.isEmpty;
  String? get coursesError => learning.courses.isEmpty ? learning.error : null;

  /// Taught courses first, then certification programmes, those the search
  /// matches (title, summary, code, awarding body).
  List<Course> get matchingCourses {
    bool matches(Course c) =>
        _search.isEmpty ||
        c.title.toLowerCase().contains(_search) ||
        (c.summary?.toLowerCase().contains(_search) ?? false) ||
        (c.provider?.name.toLowerCase().contains(_search) ?? false) ||
        c.code.toLowerCase().contains(_search);
    return [
      for (final kind in CourseKind.values)
        for (final c in learning.courses)
          if (c.kind == kind && matches(c)) c,
    ];
  }

  /// The ICR Courses rail: the first few matches.
  List<Course> get courseRail => matchingCourses.take(courseRailLimit).toList();

  /// "ICR Certifications": the taught courses ICR itself runs, the first few — the website's dashboard rail, which
  /// reads only `kind=DEVELOPMENT` (`useDevelopmentCourses`). The certification programmes are ICR's too but sit
  /// behind Assess Your Knowledge; listing them here filled the row with Capital Planning, Colloboration… where
  /// production's website shows one card, Facility Management Professional (owner's report, 3 Nov 2026).
  List<Course> get icrCourses =>
      matchingCourses.where((c) => c.kind == CourseKind.development && isIcr(c)).take(gridLimit).toList();

  /// "Partner Courses": the institutes' courses, the first few.
  List<Course> get partnerCourses => matchingCourses.where((c) => !isIcr(c)).take(gridLimit).toList();

  /// ICR's own course: one with no awarding body, as the website's "ICR certified programs" lists them
  /// (`!course.provider`). An institute's course is a partner's even when the institute is ICR's own — the
  /// website files it under the institute, and production has one ICR-certified programme where this grid once
  /// showed the institute's whole catalogue (owner's report, 2 Nov 2026).
  static bool isIcr(Course c) => c.provider == null;

  // --- "My courses" -----------------------------------------------------------------

  /// The hub's My courses row (owner, 3 Nov 2026): everything the member holds, in the order the My courses page
  /// shelves it (the website's): the mock exams, then the Assess Your Knowledge programmes and levels, then the
  /// flash-card decks they opened (a plan place, ICR credits or a purchase), then the courses they hold a place on —
  /// ICR's, then the institutes', running places before finished ones. What the search matches; empty when the
  /// member holds nothing, and the row is then left out.
  List<MyLearningEntry> get myLearning {
    final opened = openedLearning(access: _access, courses: _assessments, mocks: _mocks, decks: _decks);
    final places = [...learning.mine]
      ..sort(
        (a, b) =>
            (a.enrolment?.status == EnrolmentStatus.completed ? 1 : 0) -
            (b.enrolment?.status == EnrolmentStatus.completed ? 1 : 0),
      );
    return [
      for (final kind in const [OpenedKind.mock, OpenedKind.course, OpenedKind.deck])
        for (final item in opened)
          if (item.kind == kind && _hit(item.title)) MyLearningEntry.opened(item),
      for (final own in const [true, false])
        for (final course in places)
          if (isIcr(course) == own && _hit(course.title)) MyLearningEntry.course(course),
    ];
  }

  // --- the doors and "My learning" ---------------------------------------------

  List<LearningDoor> get doors => [
    for (final d in LearningDoor.values)
      if (d.matches(_search)) d,
  ];

  /// Places the member holds on courses; null until the catalogue has loaded.
  int? get coursesHeld => !learning.started || learning.loading || learning.error != null ? null : learning.mine.length;
  int? get attempts => _mine.attempts;
  int? get certificates => _mine.certificates;

  /// The counts are still being read.
  bool get mineLoading => _mineLoading;
  bool get coursesHeldLoading => learning.loading;

  /// The bell's dot, read with the catalogue.
  int get unread => learning.unread;

  /// Nothing on the page matches the search.
  bool get nothingMatches =>
      narrowed &&
      assessmentsShown.isEmpty &&
      mocksShown.isEmpty &&
      decksShown.isEmpty &&
      // What the ICR Certifications row shows, not every course: a search that finds only a certification
      // programme (Assess Your Knowledge's) would otherwise leave a page with no section and no notice.
      icrCourses.isEmpty &&
      institutesShown.isEmpty &&
      myLearning.isEmpty &&
      !assessLoading &&
      !mockLoading &&
      !decksLoading &&
      !coursesLoading &&
      !institutesLoading;

  // --- actions ----------------------------------------------------------------

  Future<void> start() async {
    _started = true;
    // Not notifying yet: this runs from initState, before the first build listens.
    await Future.wait([
      if (!learning.started) learning.start(),
      _loadInstitutes(notify: false),
      _loadMine(),
      _loadAssess(notify: false),
      _loadMocks(notify: false),
      _loadDecks(notify: false),
      _loadAccess(),
    ]);
  }

  /// Pull to refresh: everything again.
  Future<void> refresh() => Future.wait([
    learning.refresh(),
    _loadInstitutes(),
    _loadMine(notify: true),
    _loadAssess(),
    _loadMocks(),
    _loadDecks(),
    _loadAccess(),
  ]);

  Future<void> reloadInstitutes() => _loadInstitutes();
  Future<void> reloadAssess() => _loadAssess();
  Future<void> reloadMocks() => _loadMocks();
  Future<void> reloadDecks() => _loadDecks();

  /// What the member has opened, read again (after a page where they may have opened a level, a set or a course).
  Future<void> reloadAccess() => _loadAccess();

  void setSearch(String query) {
    final next = query.trim().toLowerCase();
    if (next == _search) return;
    _search = next;
    notifyListeners();
  }

  void clearSearch() => setSearch('');

  /// Writes to an institute as the member; a sentence when the API refuses.
  Future<String?> enquireInstitute(Institute institute, String message) async {
    try {
      await repository.enquireInstitute(institute, message: message);
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }

  Future<void> _loadInstitutes({bool notify = true}) async {
    final generation = ++_generation;
    _institutesLoading = true;
    _institutesError = null;
    if (notify) _notify();
    try {
      final rows = await repository.institutes();
      if (generation != _generation) return;
      _institutes = rows;
    } catch (e) {
      if (generation != _generation) return;
      _institutesError = ApiError.from(e).message;
    } finally {
      if (generation == _generation) {
        _institutesLoading = false;
        _notify();
      }
    }
  }

  Future<void> _loadAssess({bool notify = true}) async {
    final source = assess;
    if (source == null) return;
    _assessLoading = true;
    _assessError = null;
    if (notify) _notify();
    try {
      _assessments = await source.groups(PaperKind.assessment);
    } catch (e) {
      _assessError = ApiError.from(e).message;
    } finally {
      _assessLoading = false;
      _notify();
    }
  }

  Future<void> _loadMocks({bool notify = true}) async {
    final source = assess;
    if (source == null) return;
    _mockLoading = true;
    _mockError = null;
    if (notify) _notify();
    try {
      _mocks = await source.groups(PaperKind.mock);
    } catch (e) {
      _mockError = ApiError.from(e).message;
    } finally {
      _mockLoading = false;
      _notify();
    }
  }

  Future<void> _loadDecks({bool notify = true}) async {
    final source = study;
    if (source == null) return;
    _decksLoading = true;
    _decksError = null;
    if (notify) _notify();
    try {
      final topics = await source.topics();
      _decks = [
        for (final t in topics)
          if (t.isDeck) t,
      ];
    } catch (e) {
      _decksError = ApiError.from(e).message;
    } finally {
      _decksLoading = false;
      _notify();
    }
  }

  Future<void> _loadMine({bool notify = false}) async {
    _mineLoading = true;
    if (notify) _notify();
    try {
      _mine = await repository.myLearning();
    } catch (_) {
      _mine = const MyLearning();
    } finally {
      _mineLoading = false;
      _notify();
    }
  }

  /// The member's places and unlocks, for the My courses row. An aside: a failed read keeps what was known, and the
  /// courses they hold a place on still show.
  Future<void> _loadAccess() async {
    final source = assess;
    if (source == null) return;
    try {
      _access = (await source.member(PaperKind.assessment)).access;
    } catch (_) {
      return;
    }
    _notify();
  }

  void _relay() => _notify();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    learning.removeListener(_relay);
    if (ownsLearning) learning.dispose();
    super.dispose();
  }
}

/// One card of the hub's My courses row: an exam, programme, level, set or deck the member opened, or a course they
/// hold a place on.
class MyLearningEntry {
  const MyLearningEntry.opened(OpenedItem this.opened) : course = null;
  const MyLearningEntry.course(Course this.course) : opened = null;

  final OpenedItem? opened;
  final Course? course;

  String get key => opened?.key ?? 'course:${course!.id}';
  String get title => opened?.title ?? course!.title;
}
