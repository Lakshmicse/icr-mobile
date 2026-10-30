import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:dio/dio.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/auth/token_store.dart';
import 'package:icr_mobile/features/chapters/chapter_models.dart';
import 'package:icr_mobile/features/chapters/chapters_repository.dart';
import 'package:icr_mobile/features/library/demo_library_repository.dart';
import 'package:icr_mobile/features/library/library_device.dart';
import 'package:icr_mobile/features/library/library_models.dart';
import 'package:icr_mobile/features/library/library_repository.dart';
import 'package:icr_mobile/features/library/pdf_engine.dart';
import 'package:icr_mobile/features/library/screen_security.dart';
import 'package:icr_mobile/features/contact/contact_models.dart' show ContactSender;
import 'package:icr_mobile/features/volunteer/demo_volunteer_repository.dart';
import 'package:icr_mobile/features/volunteer/volunteer_models.dart';
import 'package:icr_mobile/features/volunteer/volunteer_repository.dart';

class _Token extends TokenStore {
  @override
  Future<String?> accessToken() async => 'token';
  @override
  Future<String?> refreshToken() async => null;
}

/// What a route answers: a JSON value (200), `(status, body)`, or raw bytes.
typedef Answer = Object Function(RequestOptions options);

/// Answers each `METHOD /path` from a table and records the calls, the queries
/// and the bodies, as the API would for the repositories under test.
class TableApi implements HttpClientAdapter {
  TableApi(this.routes);

  final Map<String, Answer> routes;
  final List<String> calls = [];
  final List<RequestOptions> requests = [];

  static final _json = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method} ${options.path}';
    calls.add(key);
    requests.add(options);
    final handler = routes[key];
    if (handler == null) return ResponseBody.fromString('{"message":"Not found"}', 404, headers: _json);
    final result = handler(options);
    if (result is (int, String)) return ResponseBody.fromString(result.$2, result.$1, headers: _json);
    if (result is List<int>) return ResponseBody.fromBytes(result, 200);
    return ResponseBody.fromString(jsonEncode(result), 200, headers: _json);
  }

  /// The query of the latest call to [key] (`GET /chapters`).
  Map<String, dynamic> queryOf(String key) => requests.lastWhere((r) => '${r.method} ${r.path}' == key).queryParameters;

  RequestOptions lastOf(String key) => requests.lastWhere((r) => '${r.method} ${r.path}' == key);

  int count(String key) => calls.where((c) => c == key).length;

  @override
  void close({bool force = false}) {}

  ApiClient client() {
    final client = ApiClient(tokens: _Token(), baseUrl: 'http://api.test/api/v1');
    client.dio.httpClientAdapter = this;
    return client;
  }
}

/// A recording Chapters source: every call is logged by name, a call can be
/// made to fail with an [ApiError], and a join or leave changes the member's
/// place the way the API's does.
class FakeChapters implements ChaptersRepository {
  FakeChapters({List<ChapterSummary>? chapters, this.unread = 0}) : chapters = chapters ?? sampleChapters();

  List<ChapterSummary> chapters;
  int unread;
  final calls = <String>[];

  /// Method name (or `method:arg`) to what it throws.
  final failures = <String, Object>{};

  /// Calls wait on this when set (to see a loading state).
  Future<void>? gate;

  List<ChapterEvent> meetups = [
    sampleEvent('e1', 'Campus FM at GCC scale', 'bengaluru', DateTime.utc(2026, 11, 1, 5, 30)),
  ];
  List<ChapterEvent> upcoming = [];
  List<ChapterEvent> past = [];
  List<ChapterUpdate> updatesNow = [
    ChapterUpdate(
      id: 'u1',
      title: 'Welcome',
      body: 'Hello chapter',
      pinned: true,
      createdAt: DateTime.utc(2026, 10, 1),
    ),
  ];
  List<ChapterResource> resourcesNow = const [
    ChapterResource(
      id: 'r1',
      title: 'Benchmark 2026',
      kind: 'WHITEPAPER',
      url: 'https://files.test/b.pdf',
      sizeLabel: '2 MB',
    ),
  ];
  List<ChapterPerson> roster = [
    for (var i = 1; i <= 5; i++)
      ChapterPerson(
        id: 'p$i',
        firstName: 'Person',
        lastName: 'Number$i',
        company: i.isEven ? 'Acme' : null,
        role: i == 1 ? ChapterRole.lead : ChapterRole.member,
      ),
  ];
  int pageSize = 2;

  Future<T> _call<T>(String name, T Function() body, [String? arg]) async {
    final key = arg == null ? name : '$name:$arg';
    calls.add(key);
    if (gate != null) await gate;
    final failure = failures[key] ?? failures[name];
    if (failure != null) throw failure;
    return body();
  }

  int count(String name) => calls.where((c) => c == name || c.startsWith('$name:')).length;

  @override
  Future<ChaptersOverview> overview() =>
      _call('overview', () => ChaptersOverview(chapters: List.of(chapters), meetups: meetups));

  ChapterSummary _find(String idOrSlug) => chapters.firstWhere(
    (c) => c.slug == idOrSlug || c.id == idOrSlug,
    orElse: () => throw ApiError('Chapter not found', statusCode: 404),
  );

  @override
  Future<ChapterDetail> detail(String idOrSlug) => _call('detail', () {
    final c = _find(idOrSlug);
    return ChapterDetail(
      chapter: c,
      contactEmail: c.slug == 'bengaluru' ? 'blr@icr.test' : null,
      foundedYear: c.slug == 'bengaluru' ? 2014 : null,
      about: const [
        AboutBlock(AboutKind.heading, 'Mission'),
        AboutBlock(AboutKind.paragraph, 'Connect the community.'),
        AboutBlock(AboutKind.bullet, 'Monthly meetups'),
      ],
      stats: ChapterStats(
        memberCount: c.memberCount,
        leadershipCount: 1,
        upcomingEventCount: c.upcomingEventCount,
        pastEventCount: 4,
        memberCompanyCount: 3,
      ),
      sponsors: const [ChapterSponsor(id: 's1', name: 'CBRE', tier: 'Gold', url: 'https://cbre.test')],
      leads: const [
        ChapterPerson(
          id: 'l1',
          firstName: 'Vikram',
          lastName: 'Malhotra',
          title: 'Chapter President',
          company: 'DLF',
          linkedinUrl: 'https://www.linkedin.com/in/vm',
          role: ChapterRole.lead,
        ),
      ],
    );
  }, idOrSlug);

  @override
  Future<ChapterMembersPage> members(
    String slug, {
    int page = 1,
    String? search,
    MemberFilter filter = MemberFilter.all,
  }) => _call('members', () {
    var rows = roster;
    if (filter == MemberFilter.committee) rows = rows.where((p) => p.role == ChapterRole.lead).toList();
    if (filter == MemberFilter.corporate) rows = rows.where((p) => p.company != null).toList();
    final q = (search ?? '').trim().toLowerCase();
    if (q.isNotEmpty) rows = rows.where((p) => p.name.toLowerCase().contains(q)).toList();
    final from = (page - 1) * pageSize;
    final slice = rows.skip(from).take(pageSize).toList();
    return ChapterMembersPage(members: slice, total: rows.length, page: page, hasNext: from + pageSize < rows.length);
  }, '$slug:$page:${filter.name}:${search ?? ''}');

  @override
  Future<List<ChapterEvent>> events(String slug, {bool past = false}) =>
      _call('events', () => past ? this.past : upcoming, '$slug:${past ? 'past' : 'upcoming'}');

  @override
  Future<List<ChapterUpdate>> updates(String slug) => _call('updates', () => updatesNow, slug);

  @override
  Future<List<ChapterResource>> resources(String slug) => _call('resources', () => resourcesNow, slug);

  @override
  Future<List<ChapterSummary>> nearby(ChapterSummary chapter) => _call(
    'nearby',
    () => chapters.where((c) => c.country == chapter.country && c.id != chapter.id).take(4).toList(),
    chapter.slug,
  );

  @override
  Future<ChapterRole> join(ChapterSummary chapter) => _call('join', () {
    chapters = [
      for (final c in chapters)
        c.id == chapter.id ? c.copyWith(role: ChapterRole.member, memberCount: c.memberCount + 1) : c,
    ];
    return ChapterRole.member;
  }, chapter.id);

  @override
  Future<void> leave(ChapterSummary chapter) => _call('leave', () {
    chapters = [
      for (final c in chapters) c.id == chapter.id ? c.copyWith(clearRole: true, memberCount: c.memberCount - 1) : c,
    ];
  }, chapter.id);

  /// The RSVP the API would keep for [id]: what the next read of the events carries.
  void _setStatus(String id, String? status) {
    ChapterEvent change(ChapterEvent e) => e.id == id ? e.withStatus(status, moveCount: true) : e;
    upcoming = [for (final e in upcoming) change(e)];
    meetups = [for (final e in meetups) change(e)];
  }

  @override
  Future<String> rsvp(ChapterEvent event) => _call('rsvp', () {
    final status = event.full ? 'WAITLISTED' : 'GOING';
    _setStatus(event.id, status);
    return status;
  }, event.id);

  @override
  Future<void> cancelRsvp(ChapterEvent event) => _call('cancel', () => _setStatus(event.id, null), event.id);

  @override
  Future<int> unreadNotifications() => _call('unread', () => unread);

  @override
  Uri link(ChapterSummary chapter) => Uri.parse('https://icr.test/chapters/${chapter.slug}');
}

ChapterEvent sampleEvent(
  String id,
  String title,
  String chapterSlug,
  DateTime at, {
  String? status,
  int capacity = 60,
  int going = 42,
  int? price,
  bool inviteOnly = false,
}) => ChapterEvent(
  id: id,
  slug: '$id-slug',
  title: title,
  kind: 'CHAPTER_MEET',
  location: 'Koramangala, Bengaluru',
  startsAt: at,
  endsAt: at.add(const Duration(hours: 3)),
  capacity: capacity,
  attendeeCount: going,
  priceAmount: price,
  inviteOnly: inviteOnly,
  chapterSlug: chapterSlug,
  chapterName: 'ICR ${chapterSlug[0].toUpperCase()}${chapterSlug.substring(1)} Chapter',
  myStatus: status,
);

ChapterSummary sampleChapter(
  String slug, {
  String? name,
  String city = 'Bengaluru',
  String country = 'India',
  String? region = 'Karnataka',
  int members = 9,
  int events = 0,
  ChapterRole? role,
  DateTime? created,
  DateTime? next,
  String? description,
}) => ChapterSummary(
  id: 'id-$slug',
  name: name ?? 'ICR ${slug[0].toUpperCase()}${slug.substring(1)} Chapter',
  slug: slug,
  city: city,
  country: country,
  region: region,
  description: description ?? 'The $city community.',
  createdAt: created ?? DateTime.utc(2024, 2, 1),
  memberCount: members,
  upcomingEventCount: events,
  role: role,
  nextEventAt: next,
);

/// The clock the board and page tests run on: Pune is ten days old on it, Bengaluru 2024.
final testNow = DateTime.utc(2026, 10, 26, 9);

/// Five chapters in three countries: the member leads Bengaluru and belongs to Pune.
List<ChapterSummary> sampleChapters() => [
  sampleChapter('bengaluru', members: 128, events: 2, role: ChapterRole.lead, next: DateTime.utc(2026, 11, 1, 5, 30)),
  sampleChapter('mumbai', city: 'Mumbai', region: 'Maharashtra', members: 96, events: 2),
  sampleChapter(
    'pune',
    city: 'Pune',
    region: 'Maharashtra',
    members: 2,
    role: ChapterRole.member,
    created: testNow.subtract(const Duration(days: 10)),
  ),
  sampleChapter('singapore', city: 'Singapore', country: 'Singapore', region: null, members: 2),
  sampleChapter('new-york', city: 'New York', country: 'USA', region: 'NY', members: 9),
];

// ---------------------------------------------------------------------------
// The Digital Library
// ---------------------------------------------------------------------------

/// The Library source for widget and controller tests: the sample documents (`DemoLibraryRepository`, the
/// member owns d3, d5 and d9), every call logged by name, any call made to fail with an [ApiError], and a
/// gate to see a loading state.
class FakeLibrary implements LibraryRepository {
  FakeLibrary({
    DemoLibraryRepository? inner,
    this.unread = 0,
    LibraryViewer? viewer = const LibraryViewer(id: DemoLibraryRepository.meId),
  }) : inner = inner ?? DemoLibraryRepository(),
       viewerValue = viewer;

  final DemoLibraryRepository inner;
  int unread;
  final calls = <String>[];

  /// The signed-in person `viewer()` answers (null for signed out); the demo member by default.
  LibraryViewer? viewerValue;

  /// Method name (or `method:arg`) to what it throws.
  final failures = <String, Object>{};

  /// Calls wait on this when set (to see a loading state).
  Future<void>? gate;

  Future<T> _call<T>(String name, Future<T> Function() body, [String? arg]) async {
    final key = arg == null ? name : '$name:$arg';
    calls.add(key);
    if (gate != null) await gate;
    final failure = failures[key] ?? failures[name];
    if (failure != null) throw failure;
    return body();
  }

  int count(String name) => calls.where((c) => c == name || c.startsWith('$name:')).length;

  @override
  Future<LibraryPage> documents(LibraryQuery q) => _call('documents', () => inner.documents(q), '${q.page}');

  @override
  Future<List<String>> categories() => _call('categories', inner.categories);

  @override
  Future<List<FileTypeFacet>> fileTypes() => _call('fileTypes', inner.fileTypes);

  @override
  Future<int> myUploadCount() => _call('myUploadCount', inner.myUploadCount);

  @override
  Future<LibraryDocument> document(String id) => _call('document', () => inner.document(id), id);

  @override
  Future<List<TaxonomyNode>> taxonomy() => _call('taxonomy', inner.taxonomy);

  @override
  Future<LibraryViewer?> viewer() => _call('viewer', () async => viewerValue);

  @override
  Future<DocumentBytes> previewFile(LibraryDocument document, LibraryFile file) =>
      _call('preview', () => inner.previewFile(document, file), file.id);

  @override
  Future<int> recordView(String id) => _call('view', () => inner.recordView(id), id);

  @override
  Future<StoredFile> upload(PickedFile file, {void Function(double)? onProgress}) =>
      _call('upload', () => inner.upload(file, onProgress: onProgress), file.name);

  @override
  Future<LibraryDocument> create(DocumentDraft draft, List<StoredFile> files) =>
      _call('create', () => inner.create(draft, files), draft.title);

  @override
  Future<LibraryDocument> addFiles(String id, List<StoredFile> files) =>
      _call('addFiles', () => inner.addFiles(id, files), id);

  @override
  Future<void> removeFile(String documentId, String fileId) =>
      _call('removeFile', () => inner.removeFile(documentId, fileId), fileId);

  @override
  Future<void> delete(String id) => _call('delete', () => inner.delete(id), id);

  @override
  Future<void> report(String id, DocumentReportReason reason, {String? note}) =>
      _call('report', () => inner.report(id, reason, note: note), '$id:${reason.api}');

  @override
  Future<int> unreadNotifications() => _call('unread', () async => unread);

  @override
  Uri link() => Uri.parse('https://icr.test/documents');
}

/// The phone, for the Library screens: the files the picker "chooses" come from [picks] (one batch per
/// tap), and each page opened is recorded. It has no way to take a document out of the app: the library is
/// view-only, so `LibraryDevice` offers none.
class FakeLibraryDevice extends LibraryDevice {
  FakeLibraryDevice();

  /// Batches the picker hands over, in order; an empty list when it runs out (the person chose nothing).
  final picks = <List<PickedFile>>[];
  final opened = <Uri>[];
  int pickerOpened = 0;

  @override
  Future<List<PickedFile>> pickFiles() async {
    pickerOpened++;
    return picks.isEmpty ? const [] : picks.removeAt(0);
  }

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}

/// A 1 x 1 PNG: what the fake PDF engine "draws" for every page.
final fakePagePng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// The phone's PDF renderer, for the viewer's tests: [pages] A4-shaped pages, every request recorded, and
/// [failure] to make `open` refuse in the reader's words.
class FakePdfEngine implements PdfEngine {
  FakePdfEngine({this.pages = 3, this.failure});

  final int pages;
  final PdfProblem? failure;
  final opened = <Uint8List>[];
  final rendered = <(int page, int width)>[];
  int closed = 0;

  @override
  Future<PdfDocumentHandle> open(Uint8List bytes) async {
    opened.add(bytes);
    if (failure != null) throw failure!;
    return _FakePdf(this);
  }
}

class _FakePdf extends PdfDocumentHandle {
  _FakePdf(this._engine);

  final FakePdfEngine _engine;

  @override
  List<Size> get pageSizes => List.filled(_engine.pages, const Size(595, 842));

  @override
  Future<Uint8List> render(int index, int widthPx) async {
    _engine.rendered.add((index, widthPx));
    return fakePagePng;
  }

  @override
  Future<void> close() async => _engine.closed++;
}

/// The window's screenshot protection, for tests: every request the Library made, in order.
class FakeScreenSecurity implements ScreenSecurityPlatform {
  final requests = <bool>[];

  @override
  Future<void> setSecure(bool on) async => requests.add(on);
}

/// A file the picker hands over: [size] bytes of zeros.
PickedFile pickedFile(String name, {int size = 1024}) => PickedFile(name: name, bytes: Uint8List(size));

// ---------------------------------------------------------------------------
// Get Involved & Volunteer
// ---------------------------------------------------------------------------

/// The Get Involved source for tests: the sample content (`DemoVolunteerRepository`), every call logged by
/// name, any call made to fail with an [ApiError], and what was sent kept in [sent].
class FakeVolunteer implements VolunteerRepository {
  FakeVolunteer({DemoVolunteerRepository? inner, this.unread = 0}) : inner = inner ?? DemoVolunteerRepository();

  final DemoVolunteerRepository inner;
  int unread;
  final calls = <String>[];
  final failures = <String, Object>{};

  /// What `cpd()` answers; null reads as signed out. The sample ledger by default.
  bool signedOut = false;

  Future<T> _call<T>(String name, Future<T> Function() body) async {
    calls.add(name);
    final failure = failures[name];
    if (failure != null) throw failure;
    return body();
  }

  List<VolunteerApplication> get sent => inner.sent;

  int count(String name) => calls.where((c) => c == name).length;

  @override
  Future<CpdSummary?> cpd() => _call('cpd', () async => signedOut ? null : inner.cpd());

  @override
  Future<ContactSender?> sender() => _call('sender', () async => signedOut ? null : inner.sender());

  @override
  Future<List<ChapterChoice>> chapters() => _call('chapters', inner.chapters);

  @override
  Future<void> apply(VolunteerApplication application) => _call('apply', () => inner.apply(application));

  @override
  Future<int> unreadNotifications() => _call('unread', () async => unread);
}
