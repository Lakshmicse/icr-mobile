import '../../core/config.dart';
import '../events/event_format.dart';
import '../events/events_repository.dart';
import '../events/event_models.dart';
import '../feed/feed_models.dart';
import '../feed/feed_repository.dart';
import '../jobs/job_models.dart';
import '../jobs/jobs_repository.dart';
import '../learning/learning_models.dart';
import '../learning/learning_repository.dart';
import '../library/library_models.dart';
import '../library/library_repository.dart';
import '../marketplace/marketplace_filters.dart';
import '../marketplace/marketplace_repository.dart';
import '../mentorship/mentorship_models.dart';
import '../mentorship/mentorship_repository.dart';
import '../messaging/messaging_repository.dart';
import 'search_models.dart';

/// The sources the global search reads, built on the repositories the screens
/// already use: each one asks the endpoint its own screen asks and reads the
/// answer with that screen's parser. There is no search endpoint in the API, so
/// this is the whole of "search everything": one request per source, in
/// parallel, each failing alone.
///
/// A source takes the repository, never the API client, so the demo's sample
/// repositories (or a fake in a test) stand in for the real ones.
List<SearchSource> repositorySources({
  required MessagingRepository messaging,
  required JobsRepository jobs,
  required MentorshipRepository mentorship,
  required LearningRepository learning,
  required MarketplaceRepository marketplace,
  required EventsRepository events,
  required FeedRepository feed,
  required LibraryRepository library,
}) => [
  PeopleSource(messaging),
  JobsSource(jobs),
  MentorsSource(mentorship),
  CoursesSource(learning),
  SuppliersSource(marketplace),
  EventsSource(events),
  DiscussionsSource(feed),
  DocumentsSource(library),
];

String? _url(String? path) => AppConfig.absoluteUrl(path);

String? _text(String? s) {
  final t = s?.trim();
  return t == null || t.isEmpty ? null : t;
}

/// One line: a title that wraps in the post's card has a line break in it.
String _flat(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

String? _join(Iterable<String?> parts, [String sep = ' · ']) {
  final kept = [for (final p in parts) if (_text(p) != null) p!.trim()];
  return kept.isEmpty ? null : kept.join(sep);
}

/// "Head of X at Company", unless the headline already names the company
/// ("Product Manager @ Amazon"), which mentors' headlines usually do.
String? _headlineAt(String? headline, String? company) {
  final h = _text(headline);
  final c = _text(company);
  if (h == null || c == null) return h ?? c;
  return h.toLowerCase().contains(c.toLowerCase()) ? h : '$h at $c';
}

/// Members, by name (`GET /messaging/recipients?search=`): the people "New
/// message" can reach, which is every active member with a public profile.
class PeopleSource extends SearchSource {
  PeopleSource(this._repo);

  final MessagingRepository _repo;

  @override
  SearchKind get kind => SearchKind.person;

  @override
  Future<SourcePage> search(String query, {int page = 1}) async {
    final found = await _repo.recipients(query);
    return SourcePage([
      for (final r in found.people)
        SearchHit(
          kind: SearchKind.person,
          id: r.person.id,
          title: '${r.person.firstName} ${r.person.lastName}'.trim(),
          subtitle: _join([r.headline, r.companyName], ' at '),
          imageUrl: _url(r.person.photo?.url),
          imageAsset: r.person.photo?.asset,
        ),
    ]);
  }
}

/// Jobs on the board (`GET /jobs?search=`), not only the Easy Apply ones the
/// board opens on.
class JobsSource extends SearchSource {
  JobsSource(this._repo);

  final JobsRepository _repo;

  @override
  SearchKind get kind => SearchKind.job;

  @override
  bool get pages => true;

  @override
  Future<SourcePage> search(String query, {int page = 1}) async {
    final found = await _repo.search(JobFilters(search: query, easyApply: false), page: page);
    return SourcePage([
      for (final j in found.jobs)
        SearchHit(
          kind: SearchKind.job,
          id: j.id,
          title: j.title,
          subtitle: _join([j.company.name, j.city]),
          imageUrl: _url(j.company.logo?.url),
          imageAsset: j.company.logo?.asset,
          verified: j.company.verified,
          payload: j,
        ),
    ], hasMore: found.hasMore);
  }
}

/// Mentors (`GET /mentorship/mentors?search=`): names, headlines and expertise.
class MentorsSource extends SearchSource {
  MentorsSource(this._repo);

  final MentorshipRepository _repo;

  @override
  SearchKind get kind => SearchKind.mentor;

  @override
  bool get pages => true;

  @override
  Future<SourcePage> search(String query, {int page = 1}) async {
    final found = await _repo.search(MentorFilters(search: query), page: page);
    return SourcePage([
      for (final m in found.mentors)
        SearchHit(
          kind: SearchKind.mentor,
          id: m.id,
          title: m.name,
          subtitle: _headlineAt(m.headline ?? m.role, m.companyName),
          imageUrl: _url(m.avatar?.url),
          imageAsset: m.avatar?.asset,
          verified: m.approved,
        ),
    ], hasMore: found.hasMore);
  }
}

/// ICR's and its partners' courses. The courses endpoint has no search term (it
/// returns the whole published catalogue, which the Learning Centre also reads
/// whole), so the catalogue is read once and kept for a minute, and matched
/// here on its title, code, summary and provider.
class CoursesSource extends SearchSource {
  CoursesSource(this._repo, {DateTime Function()? clock, this.keepFor = const Duration(minutes: 1)})
    : _clock = clock ?? DateTime.now;

  final LearningRepository _repo;
  final DateTime Function() _clock;
  final Duration keepFor;

  Future<List<Course>>? _catalogue;
  DateTime? _readAt;

  @override
  SearchKind get kind => SearchKind.course;

  Future<List<Course>> _courses() {
    final at = _readAt;
    if (_catalogue != null && at != null && _clock().difference(at) < keepFor) return _catalogue!;
    _readAt = _clock();
    final read = _repo.courses();
    // A failed read must not be remembered.
    _catalogue = read..catchError((Object _) {
      _catalogue = null;
      return <Course>[];
    });
    return read;
  }

  @override
  Future<SourcePage> search(String query, {int page = 1}) async {
    final words = _words(query);
    final scored = <(Course, int)>[];
    for (final c in await _courses()) {
      final score = _score(c, words);
      if (score > 0) scored.add((c, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return SourcePage([
      for (final (c, _) in scored.take(12))
        SearchHit(
          kind: SearchKind.course,
          id: c.id,
          slug: c.slug ?? c.code,
          title: c.title,
          subtitle: _join([c.provider?.name ?? 'ICR', c.durationLabel ?? c.deliveryMode]),
          imageUrl: _url(c.cover?.url),
          imageAsset: c.cover?.asset,
          payload: c,
        ),
    ]);
  }

  static List<String> _words(String q) =>
      q.toLowerCase().split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty).toList();

  /// Every word has to appear; a title hit counts most.
  static int _score(Course c, List<String> words) {
    final title = c.title.toLowerCase();
    final code = c.code.toLowerCase();
    final rest = '${c.summary ?? ''} ${c.provider?.name ?? ''} ${c.level ?? ''}'.toLowerCase();
    var total = 0;
    for (final w in words) {
      if (title.contains(w) || code == w) {
        total += title.startsWith(w) ? 5 : 3;
      } else if (code.contains(w)) {
        total += 2;
      } else if (rest.contains(w)) {
        total += 1;
      } else {
        return 0;
      }
    }
    return total;
  }
}

/// Supplier listings (`GET /vendors?search=`), at every trust level: a search is
/// not the Marketplace's "verified first" browse.
class SuppliersSource extends SearchSource {
  SuppliersSource(this._repo);

  final MarketplaceRepository _repo;

  @override
  SearchKind get kind => SearchKind.supplier;

  @override
  bool get pages => true;

  @override
  Future<SourcePage> search(String query, {int page = 1}) async {
    final found = await _repo.suppliers(MarketplaceFilters(search: query, minLevel: null), page: page);
    return SourcePage([
      for (final s in found.suppliers)
        SearchHit(
          kind: SearchKind.supplier,
          id: s.id,
          title: s.name,
          subtitle: _join([s.headline, s.city]),
          imageUrl: _url(s.logoUrl),
          verified: s.level.isVerified,
          payload: s,
        ),
    ], hasMore: found.hasMore);
  }
}

/// Upcoming events (`GET /events?search=`).
class EventsSource extends SearchSource {
  EventsSource(this._repo);

  final EventsRepository _repo;

  @override
  SearchKind get kind => SearchKind.event;

  @override
  Future<SourcePage> search(String query, {int page = 1}) async {
    final found = await _repo.search(EventQuery(search: query));
    return SourcePage([
      for (final e in found.take(12))
        SearchHit(
          kind: SearchKind.event,
          id: e.id,
          slug: e.slug ?? e.id,
          title: e.title,
          subtitle: _join([e.kind.label, shortDay(e.startsAt), e.city ?? e.location]),
          imageUrl: _url(e.cover?.url),
          imageAsset: e.cover?.asset,
        ),
    ]);
  }
}

/// Forum discussions (`GET /forum/threads?search=`).
class DiscussionsSource extends SearchSource {
  DiscussionsSource(this._repo);

  final FeedRepository _repo;

  @override
  SearchKind get kind => SearchKind.discussion;

  @override
  bool get pages => true;

  @override
  Future<SourcePage> search(String query, {int page = 1}) async {
    final found = await _repo.load(FeedFilter.all, page: page, search: query);
    return SourcePage([
      for (final p in found.posts)
        SearchHit(
          kind: SearchKind.discussion,
          id: p.id,
          slug: p.slug,
          title: p.title.trim().isEmpty ? _snippet(p.body) : _flat(p.title),
          subtitle: _join([p.author.name, '${p.comments} ${p.comments == 1 ? 'comment' : 'comments'}']),
          imageUrl: _url(p.author.photo?.url),
          imageAsset: p.author.photo?.asset,
          payload: p,
        ),
    ], hasMore: found.hasMore);
  }

  static String _snippet(String body) {
    final flat = _flat(body);
    return flat.length <= 90 ? flat : '${flat.substring(0, 90)}…';
  }
}

/// Documents in the Digital Library (`GET /documents?search=`).
class DocumentsSource extends SearchSource {
  DocumentsSource(this._repo);

  final LibraryRepository _repo;

  @override
  SearchKind get kind => SearchKind.document;

  @override
  bool get pages => true;

  @override
  Future<SourcePage> search(String query, {int page = 1}) async {
    final found = await _repo.documents(LibraryQuery(search: query, page: page, limit: 12));
    return SourcePage([
      for (final d in found.documents)
        SearchHit(
          kind: SearchKind.document,
          id: d.id,
          title: d.title,
          subtitle: _join([d.category, d.uploader?.name]),
          payload: d,
        ),
    ], hasMore: found.hasNext);
  }
}
