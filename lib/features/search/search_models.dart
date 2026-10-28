import 'package:flutter/material.dart';

/// What a search hit is. Each kind is one source the global search asks and one
/// chip on the results page.
enum SearchKind {
  feature('In the app', 'In the app', Icons.apps_rounded),
  person('People', 'Person', Icons.person_outline),
  job('Jobs', 'Job', Icons.work_outline),
  mentor('Mentors', 'Mentor', Icons.school_outlined),
  course('Courses', 'Course', Icons.menu_book_outlined),
  supplier('Companies & suppliers', 'Supplier', Icons.storefront_outlined),
  event('Events', 'Event', Icons.event_outlined),
  discussion('Discussions', 'Discussion', Icons.forum_outlined),
  document('Documents', 'Document', Icons.description_outlined);

  const SearchKind(this.plural, this.singular, this.icon);

  /// The chip and the group heading.
  final String plural;

  /// The small label at the end of a row.
  final String singular;
  final IconData icon;

  /// "See all people", and for the app's own places "More in the app".
  String get seeAll => this == feature ? 'More in the app' : 'See all ${plural.toLowerCase()}';

  /// The chip row's order, after "All".
  static const chips = [person, job, course, mentor, supplier, event, discussion, document, feature];
}

/// One thing a search found, in the words a row shows. [payload] is whatever
/// the opener needs to open it (the job, the course, the post as the list read
/// it), so a tap does not read the record again before showing it.
class SearchHit {
  const SearchHit({
    required this.kind,
    required this.id,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.imageAsset,
    this.slug,
    this.verified = false,
    this.icon,
    this.payload,
  });

  final SearchKind kind;

  /// The record's id; for [SearchKind.feature], the catalogue entry's id.
  final String id;
  final String? slug;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? imageAsset;
  final bool verified;

  /// A glyph for a hit with no picture (a feature, a discussion, a document).
  final IconData? icon;
  final Object? payload;

  String get key => '${kind.name}:$id';
}

/// How far one source has got for the query on screen.
enum GroupStatus { idle, loading, done, failed }

/// The hits of one source for the current query, and where it is.
class SearchGroup {
  const SearchGroup(
    this.kind, {
    this.status = GroupStatus.idle,
    this.hits = const [],
    this.hasMore = false,
    this.page = 0,
    this.query = '',
    this.loadingMore = false,
  });

  final SearchKind kind;
  final GroupStatus status;
  final List<SearchHit> hits;
  final bool hasMore;

  /// The last page read (1-based); 0 before the first.
  final int page;

  /// The query these hits answer.
  final String query;
  final bool loadingMore;

  bool get isEmpty => hits.isEmpty;

  SearchGroup copyWith({
    GroupStatus? status,
    List<SearchHit>? hits,
    bool? hasMore,
    int? page,
    String? query,
    bool? loadingMore,
  }) => SearchGroup(
    kind,
    status: status ?? this.status,
    hits: hits ?? this.hits,
    hasMore: hasMore ?? this.hasMore,
    page: page ?? this.page,
    query: query ?? this.query,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// A page of one source's hits.
class SourcePage {
  const SourcePage(this.hits, {this.hasMore = false});

  final List<SearchHit> hits;
  final bool hasMore;
}

/// One place the search looks. [search] answers a query from page 1; a source
/// that has more than a page ([pages]) answers `page: 2` and on.
abstract class SearchSource {
  SearchKind get kind;

  /// Whether `search(page: 2)` reads more.
  bool get pages => false;

  Future<SourcePage> search(String query, {int page = 1});
}
