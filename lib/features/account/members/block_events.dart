import 'dart:async';

/// A block or unblock made anywhere in the app (Nov 2026, App Store guideline 1.2), told to every list that shows
/// members' posts, replies or conversations, so a blocked member's content leaves the screen at once instead of on
/// the next refresh. The API hides it from every later read.
typedef BlockChange = ({String memberId, bool blocked});

class BlockEvents {
  BlockEvents._();

  static final _changes = StreamController<BlockChange>.broadcast(sync: true);

  static Stream<BlockChange> get stream => _changes.stream;

  static void note(String memberId, {required bool blocked}) => _changes.add((memberId: memberId, blocked: blocked));
}
