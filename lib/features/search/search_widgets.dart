import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'search_models.dart';
import 'search_styles.dart';

/// The picture at the start of a row: a person's photo as a circle, a company's
/// or a course's as a rounded square, and for what has none (a feature, a
/// document, a discussion) its glyph on a tint.
class HitImage extends StatelessWidget {
  const HitImage(this.hit, {super.key, this.size = SearchLook.avatar});

  final SearchHit hit;
  final double size;

  bool get _round => switch (hit.kind) {
    SearchKind.person || SearchKind.mentor || SearchKind.discussion || SearchKind.feature => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    final radius = _round ? BorderRadius.circular(size / 2) : BorderRadius.circular(4);
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(width: size, height: size, child: _content()),
    );
  }

  Widget _content() {
    final url = hit.imageUrl;
    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 120),
        placeholder: (_, _) => _fallback(),
        errorWidget: (_, _, _) => _fallback(),
      );
    }
    final asset = hit.imageAsset;
    if (asset != null) {
      return Image.asset(asset, fit: BoxFit.cover, errorBuilder: (_, _, _) => _fallback());
    }
    return _fallback();
  }

  /// Initials for people and companies, the glyph for the rest.
  Widget _fallback() {
    final glyph = hit.icon ?? hit.kind.icon;
    final initials = switch (hit.kind) {
      SearchKind.person || SearchKind.mentor || SearchKind.supplier || SearchKind.job => _initials(hit.title),
      _ => null,
    };
    return ColoredBox(
      color: SearchLook.tint,
      child: Center(
        child: initials != null && initials.isNotEmpty
            ? Text(initials, style: searchText(size * 0.34, FontWeight.w600, SearchLook.blue))
            : Icon(glyph, size: size * 0.5, color: SearchLook.blue),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return '$first$last'.toUpperCase();
  }
}

/// One hit: picture, name, one line of context, and what kind of thing it is.
class HitRow extends StatelessWidget {
  const HitRow({super.key, required this.hit, required this.onTap, this.showKind = true});

  final SearchHit hit;
  final VoidCallback onTap;

  /// The kind label at the end of the row ("Person", "Job"); off on a chip
  /// that already says it.
  final bool showKind;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SearchLook.pad, vertical: 8),
          child: Row(
            children: [
              HitImage(hit),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(hit.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: SearchStyles.title),
                        ),
                        if (hit.verified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, size: 14, color: SearchLook.blue),
                        ],
                      ],
                    ),
                    if (hit.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(hit.subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: SearchStyles.sub),
                    ],
                  ],
                ),
              ),
              // A feature's group heading already says "In the app".
              if (showKind && hit.kind != SearchKind.feature) ...[
                const SizedBox(width: 8),
                Text(hit.kind.singular, style: SearchStyles.kind),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "People", "Jobs"... over a group of hits on the All chip.
class GroupHeader extends StatelessWidget {
  const GroupHeader(this.kind, {super.key});

  final SearchKind kind;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(SearchLook.pad, 16, SearchLook.pad, 4),
    child: Semantics(header: true, child: Text(kind.plural, style: SearchStyles.heading)),
  );
}

/// The blue "See all people" under a group that has more.
class SeeAllRow extends StatelessWidget {
  const SeeAllRow({super.key, required this.kind, required this.onTap});

  final SearchKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 44),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: SearchLook.pad),
      child: Text(kind.seeAll, style: SearchStyles.link),
    ),
  );
}

/// A thin rule between groups.
class GroupRule extends StatelessWidget {
  const GroupRule({super.key});

  @override
  Widget build(BuildContext context) => const Divider(height: 1, thickness: 1, color: SearchLook.hairline);
}

/// A chip of the row under the field: filled when it is the one chosen.
class KindChip extends StatelessWidget {
  const KindChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 32,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? SearchLook.blue : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? SearchLook.blue : SearchLook.chipBorder),
        ),
        child: Text(label, style: selected ? SearchStyles.chipOn : SearchStyles.chip),
      ),
    ),
  );
}

/// Grey bars where a group's rows will be, before anything has come back.
class SkeletonRows extends StatelessWidget {
  const SkeletonRows({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: const Color(0xFFEAE8E4), borderRadius: BorderRadius.circular(3)),
    );
    return Column(
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SearchLook.pad, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: SearchLook.avatar,
                  height: SearchLook.avatar,
                  decoration: const BoxDecoration(color: Color(0xFFEAE8E4), shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [bar(150 + (i % 2) * 40, 12), const SizedBox(height: 8), bar(220, 10)],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A feature's row: the glyph on a tint, its name, and where it lives.
SearchHit featureHit(String id, String title, String subtitle, IconData icon, {String? group}) => SearchHit(
  kind: SearchKind.feature,
  id: id,
  title: title,
  subtitle: group == null ? subtitle : '$subtitle · $group',
  icon: icon,
);
