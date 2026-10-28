import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import '../../core/util/time_ago.dart';
import 'html_view.dart';
import 'site_kit.dart';

/// A blog post as the list and the post page read it (`GET /cms/blogs`, `GET /cms/blogs/:slug`).
class BlogPost {
  const BlogPost({
    required this.slug,
    required this.title,
    required this.excerpt,
    required this.content,
    required this.cover,
    required this.author,
    required this.publishedAt,
  });

  final String slug;
  final String title;
  final String excerpt;

  /// The body: rich text on the post page, empty on the list.
  final String content;
  final String? cover;
  final String author;
  final DateTime? publishedAt;

  factory BlogPost.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>?;
    final name = '${author?['firstName'] ?? ''} ${author?['lastName'] ?? ''}'.trim();
    return BlogPost(
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      excerpt: json['excerpt'] as String? ?? '',
      content: json['content'] as String? ?? '',
      cover: AppConfig.absoluteUrl(json['coverUrl'] as String?),
      author: name.isEmpty ? 'ICR' : name,
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
    );
  }
}

/// Where the blog is read from: the API, or a fake in a test.
abstract class BlogRepository {
  Future<List<BlogPost>> posts({int page = 1});

  Future<BlogPost> post(String slug);
}

class ApiBlogRepository implements BlogRepository {
  ApiBlogRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<BlogPost>> posts({int page = 1}) async {
    try {
      final res = await _api.dio.get<dynamic>('/cms/blogs', queryParameters: {'page': page, 'limit': 20});
      final data = (res.data as Map?)?['data'] as List? ?? const [];
      return [for (final row in data) BlogPost.fromJson((row as Map).cast<String, dynamic>())];
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  @override
  Future<BlogPost> post(String slug) async {
    try {
      final res = await _api.dio.get<dynamic>('/cms/blogs/${Uri.encodeComponent(slug)}');
      return BlogPost.fromJson((res.data as Map).cast<String, dynamic>());
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

BlogRepository _repositoryOf(BuildContext context) => ApiBlogRepository(context.read<ApiClient>());

/// The ICR blog: every published post, newest first (`/blogs`).
class BlogsScreen extends StatefulWidget {
  const BlogsScreen({super.key, this.repository, this.onBack, this.onOpenPost});

  final BlogRepository? repository;
  final VoidCallback? onBack;
  final void Function(BlogPost post)? onOpenPost;

  @override
  State<BlogsScreen> createState() => _BlogsScreenState();
}

class _BlogsScreenState extends State<BlogsScreen> {
  late final BlogRepository _repo = widget.repository ?? _repositoryOf(context);
  late Future<List<BlogPost>> _posts = _repo.posts();

  @override
  Widget build(BuildContext context) {
    return SitePage(
      title: 'Blog',
      onBack: widget.onBack,
      canvas: true,
      child: FutureBuilder<List<BlogPost>>(
        future: _posts,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return SiteError(
              message: snapshot.error is ApiError ? (snapshot.error! as ApiError).message : "Couldn't read the blog.",
              onRetry: () => setState(() {
                _posts = _repo.posts();
              }),
            );
          }
          final posts = snapshot.data;
          if (posts == null) return const SiteLoading();
          if (posts.isEmpty) {
            return Center(child: Text('Nothing has been published yet.', style: SiteText.secondary));
          }
          return ListView.separated(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            itemCount: posts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _PostCard(
              post: posts[i],
              onTap: () =>
                  widget.onOpenPost == null ? openBlogPost(context, posts[i].slug) : widget.onOpenPost!(posts[i]),
            ),
          );
        },
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.onTap});

  final BlogPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('blog:${post.slug}'),
      onTap: onTap,
      child: SiteCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.cover != null)
              Image.network(
                post.cover!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post.title, style: SiteText.subheading),
                  if (post.excerpt.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(post.excerpt, style: SiteText.secondary, maxLines: 3, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    [post.author, if (post.publishedAt != null) timeAgo(post.publishedAt!)].join(' • '),
                    style: SiteText.meta,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A blog post (`/blogs/<slug>`): its cover, title, author and date, and the body drawn by [HtmlView].
class BlogPostScreen extends StatefulWidget {
  const BlogPostScreen({super.key, required this.slug, this.repository, this.onBack});

  final String slug;
  final BlogRepository? repository;
  final VoidCallback? onBack;

  @override
  State<BlogPostScreen> createState() => _BlogPostScreenState();
}

class _BlogPostScreenState extends State<BlogPostScreen> {
  late final BlogRepository _repo = widget.repository ?? _repositoryOf(context);
  late Future<BlogPost> _post = _repo.post(widget.slug);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BlogPost>(
      future: _post,
      builder: (context, snapshot) {
        final post = snapshot.data;
        return SitePage(
          title: post?.title ?? 'Blog',
          onBack: widget.onBack,
          child: snapshot.hasError
              ? SiteError(
                  message: snapshot.error is ApiError
                      ? (snapshot.error! as ApiError).message
                      : "This post couldn't be read.",
                  onRetry: () => setState(() {
                    _post = _repo.post(widget.slug);
                  }),
                )
              : post == null
              ? const SiteLoading()
              : ListView(
                  key: const Key('blog.post'),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    if (post.cover != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Image.network(
                          post.cover!,
                          fit: BoxFit.fitWidth,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    Text(post.title, style: SiteText.title),
                    const SizedBox(height: 6),
                    Text(
                      [post.author, if (post.publishedAt != null) timeAgo(post.publishedAt!)].join(' • '),
                      style: SiteText.meta.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    HtmlView(html: post.content, onLink: (href) => _link(context, href)),
                  ],
                ),
        );
      },
    );
  }

  void _link(BuildContext context, String href) {
    final uri = Uri.tryParse(href);
    if (uri == null) return;
    // A page of the website resolves to the app's own screen; another site goes to the phone.
    openUrl(context, uri.hasScheme ? uri : AppConfig.sitePage(href));
  }
}

Future<void> openBlogs(BuildContext context) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (route) =>
        BlogsScreen(onBack: () => Navigator.of(route).pop(), onOpenPost: (post) => openBlogPost(route, post.slug)),
  ),
);

Future<void> openBlogPost(BuildContext context, String slug) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (route) => BlogPostScreen(slug: slug, onBack: () => Navigator.of(route).pop()),
  ),
);
