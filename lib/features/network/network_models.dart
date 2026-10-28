/// What the Network screen draws: the website's `/network` (the following
/// feed, who to follow) and the member's following and followers lists, from
/// `GET /members/me/feed`, `/members/me/suggestions`, `/members/me/following`
/// and `/members/:id/followers`.
///
/// ICR has no connection requests: a follow is one-way and needs no accepting,
/// so "your network" is the people you follow, the people who follow you, and
/// the people the API suggests.
library;

import '../chapters/community_kit.dart';

export '../chapters/community_api.dart' show ApiPage;
export '../chapters/community_kit.dart' show FeedPicture;

/// A member as the network lists them.
class NetworkPerson {
  const NetworkPerson({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.photo,
    this.company,
    this.reason,
    this.followers,
    this.since,
  });

  final String id;
  final String firstName;
  final String lastName;
  final FeedPicture? photo;

  /// Where they work, when their profile says.
  final String? company;

  /// Why a suggestion is suggested, in the API's words ("Followed by 2
  /// people you follow", "Works at TechCorp", "Active in the community").
  final String? reason;

  /// Their follower count (suggestions only).
  final int? followers;

  /// When the follow began (the following and followers lists).
  final DateTime? since;

  String get name => '$firstName $lastName'.trim();
  String get initials => initialsOf(firstName, lastName);

  /// This person as a row of the "Following" list, from the moment the member
  /// follows them: the suggestion's reason no longer applies.
  NetworkPerson followedAt(DateTime at) =>
      NetworkPerson(id: id, firstName: firstName, lastName: lastName, photo: photo, company: company, since: at);
}

enum PostKind {
  article('Article'),
  thread('Discussion');

  const PostKind(this.label);
  final String label;
}

/// One thing someone the member follows published.
class NetworkPost {
  const NetworkPost({
    required this.kind,
    required this.id,
    required this.title,
    required this.excerpt,
    required this.link,
    required this.at,
    required this.author,
  });

  final PostKind kind;
  final String id;
  final String title;
  final String excerpt;

  /// The website path it lives at (`/community/<slug>`, `/blogs/<slug>`).
  final String link;
  final DateTime at;
  final NetworkPerson author;

  /// Feed rows are told apart by kind and id (an article and a thread may
  /// share an id).
  String get key => '${kind.name}:$id';
}

/// The four lists, as chips under the header.
enum NetworkTab {
  feed('Feed'),
  suggestions('People to follow'),
  following('Following'),
  followers('Followers');

  const NetworkTab(this.label);
  final String label;
}

/// What a follow or unfollow answers: the counts are the PERSON's (their
/// followers and who they follow), not the signed-in member's, and
/// [viewerFollows] says whether the member now follows them.
class FollowCounts {
  const FollowCounts({required this.followers, required this.following, required this.viewerFollows});

  final int followers;
  final int following;
  final bool viewerFollows;
}
