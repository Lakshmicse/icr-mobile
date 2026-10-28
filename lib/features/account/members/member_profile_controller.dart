import 'package:flutter/foundation.dart';

import '../../../core/api/api_error.dart';
import '../account_models.dart';
import '../account_repository.dart';

/// Another member's public page: their profile, their latest discussions, and
/// the two things a visitor does to them, follow and message.
class MemberProfileController extends ChangeNotifier {
  MemberProfileController(this.repository, this.idOrSlug);

  final AccountRepository repository;

  /// The member's id or profile slug (`/members/<slug>`).
  final String idOrSlug;

  MemberProfile? member;
  bool loading = true;

  /// Why the page could not be read, and the status the API gave (404: hidden or gone).
  String? loadError;
  int? loadStatus;

  List<ForumPost> posts = const [];
  bool postsFailed = false;

  /// A follow or unfollow is on its way.
  bool following = false;

  /// A message thread is being opened.
  bool messaging = false;

  /// What the last follow, unfollow or message was refused with.
  String? actionError;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load({bool refresh = false}) async {
    if (!refresh || member == null) {
      loading = true;
      loadError = null;
      loadStatus = null;
      _notify();
    }
    try {
      final m = await repository.member(idOrSlug);
      member = m;
      loadError = null;
      loadStatus = null;
      // The page does not wait for the discussions, and does not fail with them.
      await _loadPosts(m.id);
    } catch (e) {
      final error = ApiError.from(e);
      if (member == null || !refresh) {
        loadError = error.message;
        loadStatus = error.statusCode;
      } else {
        actionError = error.message;
      }
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<void> _loadPosts(String id) async {
    try {
      posts = await repository.memberPosts(id);
      postsFailed = false;
    } catch (_) {
      postsFailed = true;
    }
  }

  void dismissError() {
    if (actionError == null) return;
    actionError = null;
    _notify();
  }

  /// Follows or unfollows. The button changes at once and goes back, with the
  /// API's sentence, when it is refused. Returns whether it worked.
  Future<bool> toggleFollow() async {
    final m = member;
    if (m == null || following || m.isOwner) return false;
    following = true;
    actionError = null;
    final was = m.follow;
    member = m.withFollow(was.copyWith(viewerFollows: !was.viewerFollows, followers: was.followers + (was.viewerFollows ? -1 : 1)));
    _notify();
    try {
      final next = was.viewerFollows ? await repository.unfollow(m.id) : await repository.follow(m.id);
      member = member!.withFollow(next);
      return true;
    } catch (e) {
      member = member!.withFollow(was);
      actionError = ApiError.from(e).message;
      return false;
    } finally {
      following = false;
      _notify();
    }
  }

  /// Opens (or finds) the plain thread with this member; its id, or null with
  /// the sentence in [actionError].
  Future<String?> openConversation() async {
    final m = member;
    if (m == null || messaging || m.isOwner) return null;
    messaging = true;
    actionError = null;
    _notify();
    try {
      return await repository.startConversation(m.id);
    } catch (e) {
      actionError = ApiError.from(e).message;
      return null;
    } finally {
      messaging = false;
      _notify();
    }
  }
}
