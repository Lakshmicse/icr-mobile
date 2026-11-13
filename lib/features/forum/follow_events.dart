import 'dart:async';

/// A follow or unfollow made anywhere in the app, told to every list that marks an author as followed, so the feed
/// and a member's profile agree (bug sheet #5, 9 Nov 2026: the feed read "Follow" for someone whose profile read
/// "Following", because each kept its own copy of who the member follows).
typedef FollowChange = ({String memberId, bool follows});

class FollowEvents {
  FollowEvents._();

  static final _changes = StreamController<FollowChange>.broadcast(sync: true);

  static Stream<FollowChange> get stream => _changes.stream;

  static void note(String memberId, {required bool follows}) => _changes.add((memberId: memberId, follows: follows));
}
