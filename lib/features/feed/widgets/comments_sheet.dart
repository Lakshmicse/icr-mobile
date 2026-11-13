import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/util/links.dart';
import '../../forum/mentions/mention_controller.dart';
import '../../forum/mentions/mention_person.dart';
import '../feed_models.dart';
import '../feed_styles.dart';
import 'comment_widgets.dart';
import 'reply_widgets.dart';

/// What the comments sheet reads and does, handed over by the screen that opens it (the Home feed).
class CommentsHost {
  const CommentsHost({
    required this.listenable,
    required this.post,
    required this.loading,
    required this.viewer,
    required this.onLike,
    required this.onSend,
    required this.onMore,
    this.onOpenAuthor,
    this.onOpenMention,
    this.searchPeople,
    this.follows,
    this.now,
  });

  /// Tells the sheet the post changed (a reply arrived, a like landed).
  final Listenable listenable;

  /// The post as it is now; null once it has gone.
  final FeedPost? Function() post;
  final bool Function() loading;
  final FeedAuthor viewer;

  /// Likes or unlikes a comment; a sentence when the forum refuses.
  final Future<String?> Function(FeedReply reply) onLike;

  /// Sends a comment: its words, the comment it answers, the people tagged. A sentence when the forum refuses.
  final Future<String?> Function(String text, String? parentId, List<Mention> mentions) onSend;

  /// A comment's three dots. [sheet] is a context inside the sheet: a menu or a message shown with it lands over
  /// the sheet, not under it.
  final void Function(BuildContext sheet, FeedReply reply) onMore;

  /// A comment's photo or name: opens its author. The sheet closes first, so the profile is not under it.
  final ValueChanged<FeedReply>? onOpenAuthor;

  /// A member tagged in a comment: gets their id. The sheet closes first.
  final ValueChanged<String>? onOpenMention;

  /// Who the "@" in the box may mean; absent, "@" is just a character.
  final MentionSearch? searchPeople;

  /// Whom the reader follows; absent, no comment offers "Follow".
  final FollowBook? follows;

  /// The clock the ages read against (a golden pins it).
  final DateTime? now;
}

/// Opens a post's comments as LinkedIn does: a sheet over the feed with the order at its top, the comments and
/// their answers, and the box to add one pinned at its foot.
Future<void> showCommentsSheet(BuildContext context, {required CommentsHost host}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.94,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        child: CommentsSheet(host: host),
      ),
    ),
  );
}

class CommentsSheet extends StatefulWidget {
  const CommentsSheet({super.key, required this.host});

  final CommentsHost host;

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  late final MentionController _mentions = MentionController(
    search: (q) => widget.host.searchPeople?.call(q) ?? Future.value(const <MentionPerson>[]),
  );
  CommentSort _sort = CommentSort.relevant;
  FeedReply? _replyingTo;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _mentions.attach(_input, _focus);
  }

  @override
  void dispose() {
    _mentions.dispose();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final refusal = await widget.host.onSend(text, _replyingTo?.id, _mentions.mentionsIn(text));
    if (!mounted) return;
    setState(() {
      _sending = false;
      _error = refusal;
      if (refusal == null) {
        _input.clear();
        _mentions.reset();
        _replyingTo = null;
        // A new comment is the newest: show it where it lands.
        _focus.unfocus();
      }
    });
  }

  void _replyTo(FeedReply reply) {
    setState(() => _replyingTo = reply);
    _focus.requestFocus();
  }

  /// Leaves the sheet, then opens what was tapped: a profile pushed under an open sheet would not be seen.
  void _leaveFor(VoidCallback open) {
    Navigator.of(context).maybePop();
    open();
  }

  @override
  Widget build(BuildContext context) {
    final host = widget.host;
    return ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Builder(
          builder: (inner) => ListenableBuilder(
            listenable: Listenable.merge([host.listenable, ?host.follows]),
            builder: (context, _) => _body(inner),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext inner) {
    final host = widget.host;
    final post = host.post();
    final comments = _sort.apply(post?.replies ?? const []);
    final loading = host.loading() && comments.isEmpty;
    final target = _replyingTo;

    final rows = <Widget>[];
    for (final top in comments) {
      final thread = commentRows(top);
      Widget tile(({FeedReply reply, bool nested, String? replyingTo}) row) {
        final reply = row.reply;
        final follows = host.follows;
        return CommentTile(
          key: ValueKey('comment:${reply.id}'),
          reply: reply,
          now: host.now,
          replyingTo: row.replyingTo,
          replyCount: row.nested ? 0 : thread.length - 1,
          onLike: () async {
            final refusal = await host.onLike(reply);
            if (refusal != null && inner.mounted) showMessage(inner, refusal);
          },
          onReply: () => _replyTo(reply),
          onMore: () => host.onMore(inner, reply),
          onFollow: follows != null && follows.offers(reply.author)
              ? () async {
                  final refusal = await follows.followAuthor(reply.author);
                  if (refusal != null && inner.mounted) showMessage(inner, refusal);
                }
              : null,
          onOpenAuthor: host.onOpenAuthor == null ? null : () => _leaveFor(() => host.onOpenAuthor!(reply)),
          onOpenMention: host.onOpenMention == null ? null : (id) => _leaveFor(() => host.onOpenMention!(id)),
        );
      }

      rows.add(tile(thread.first));
      if (thread.length > 1) rows.add(CommentReplies(children: [for (final row in thread.skip(1)) tile(row)]));
    }

    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(color: const Color(0xFF1F1F1F), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(CommentDesign.pad, 6, CommentDesign.pad, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: CommentSortButton(sort: _sort, onChanged: (s) => setState(() => _sort = s)),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))
                : comments.isEmpty
                ? Center(
                    key: const ValueKey('comments-empty'),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.messageSquareText, size: 28, color: HomeLook.soft),
                          const SizedBox(height: 10),
                          Text('No Comments Yet', style: CommentDesign.name),
                          const SizedBox(height: 4),
                          Text('Be the first to comment.', style: CommentDesign.headline),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    key: const ValueKey('comments-list'),
                    padding: const EdgeInsets.fromLTRB(CommentDesign.pad, 0, CommentDesign.pad, 12),
                    children: rows,
                  ),
          ),
          const Divider(height: 1, thickness: 1, color: HomeLook.hairline),
          Padding(
            padding: const EdgeInsets.fromLTRB(CommentDesign.pad, 8, CommentDesign.pad, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (target != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Replying to ${target.author.name}',
                            key: const ValueKey('reply-target'),
                            style: CommentDesign.headline,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkResponse(
                          key: const ValueKey('reply-target-clear'),
                          onTap: () => setState(() => _replyingTo = null),
                          radius: 16,
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(LucideIcons.x, size: 16, color: HomeLook.soft),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 6),
                    child: Text(
                      _error!,
                      key: const ValueKey('reply-error'),
                      style: CommentDesign.headline.copyWith(color: AppColors.error),
                    ),
                  ),
                ReplyBox(
                  look: ReplyLook.home,
                  viewer: host.viewer,
                  controller: _input,
                  focusNode: _focus,
                  sending: _sending,
                  hint: target == null ? 'Add a comment...' : 'Reply to ${target.author.name}...',
                  onSend: _send,
                  newlines: true,
                  mentions: host.searchPeople == null ? null : _mentions,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
