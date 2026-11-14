import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/util/time_ago.dart';
import '../../core/widgets/title_bar.dart';

/// A rating left on ICR (`GET /reviews`): its stars, what it was about, the comment and the tone read from it.
class PlatformReview {
  const PlatformReview({required this.id, required this.score, this.targetType, this.comment, this.sentiment, this.at});

  final String id;
  final int score;
  final String? targetType;
  final String? comment;
  final String? sentiment;
  final DateTime? at;

  factory PlatformReview.fromJson(Map<String, dynamic> j) => PlatformReview(
    id: j['id'] as String,
    score: (j['score'] as num?)?.round() ?? 0,
    targetType: j['targetType'] as String?,
    comment: j['comment'] as String?,
    sentiment: j['sentiment'] as String?,
    at: DateTime.tryParse('${j['createdAt']}'),
  );
}

/// "Reviews" (the website's `/reviews`, Engage's Reputation): ratings and feedback across the platform, newest first,
/// more as the list scrolls.
class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key, this.onBack, this.onBell, this.unread = 0});

  final VoidCallback? onBack;
  final VoidCallback? onBell;
  final int unread;

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  static const _pageSize = 12;
  final _items = <PlatformReview>[];
  final _scroll = ScrollController();
  int _page = 0;
  bool _loading = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 300) unawaited(_more());
    });
    unawaited(_more());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _more() async {
    if (_loading || _done) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await context.read<ApiClient>().dio.get<Map<String, dynamic>>(
        '/reviews',
        queryParameters: {'page': _page + 1, 'limit': _pageSize},
      );
      if (!mounted) return;
      final data = (res.data?['data'] as List? ?? const []).cast<Map<String, dynamic>>();
      final meta = (res.data?['meta'] as Map?)?.cast<String, dynamic>() ?? const {};
      setState(() {
        _items.addAll(data.map(PlatformReview.fromJson));
        _page += 1;
        _done = meta['hasNext'] != true;
      });
    } on DioException catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TitleBar(title: 'Reviews', onBack: widget.onBack, unread: widget.unread, onBell: widget.onBell ?? () {}),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_items.isEmpty && _loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty && _error != null) {
      return Center(
        child: TextButton(onPressed: _more, child: Text('$_error Try Again')),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_border, size: 40, color: AppColors.icon),
              const SizedBox(height: 8),
              Text('No Reviews Yet', style: AppText.plexSans(16, FontWeight.w600, AppColors.onSurface)),
              const SizedBox(height: 4),
              Text(
                'Reviews will appear here once submitted.',
                textAlign: TextAlign.center,
                style: AppText.plexSans(13, FontWeight.w400, AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      controller: _scroll,
      itemCount: _items.length + (_done ? 0 : 1),
      separatorBuilder: (_, _) => const Divider(height: 1, thickness: 1, color: AppColors.outlineVariant),
      itemBuilder: (context, i) {
        if (i == _items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final r = _items[i];
        final about = r.targetType == null || r.targetType!.isEmpty
            ? null
            : '${r.targetType![0].toUpperCase()}${r.targetType!.substring(1)}';
        return Padding(
          key: ValueKey('review-${r.id}'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (var s = 1; s <= 5; s++)
                    Icon(s <= r.score ? Icons.star : Icons.star_border, size: 18, color: const Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [?about, if (r.at != null) timeAgo(r.at!)].join(' · '),
                      style: AppText.plexSans(12, FontWeight.w400, AppColors.onSurfaceVariant),
                    ),
                  ),
                  if (r.sentiment != null) _Tone(sentiment: r.sentiment!),
                ],
              ),
              if (r.comment != null && r.comment!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(r.comment!, style: AppText.plexSans(14, FontWeight.w400, AppColors.onSurface)),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The tone read from a review: green, amber or red, in the website's words.
class _Tone extends StatelessWidget {
  const _Tone({required this.sentiment});

  final String sentiment;

  @override
  Widget build(BuildContext context) {
    final (word, colour) = switch (sentiment) {
      'POSITIVE' => ('positive', AppColors.tertiary),
      'NEGATIVE' => ('negative', AppColors.error),
      _ => ('neutral', const Color(0xFFB45309)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: colour.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(word, style: AppText.plexSans(12, FontWeight.w500, colour)),
    );
  }
}
