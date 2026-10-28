import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/util/time_ago.dart';
import '../../widgets/account_kit.dart';
import '../saved_models.dart';

/// The frame every saved item sits in: a white 12 dp card with a hairline
/// border, [lead] (a logo, a photo) at the left, the facts in the middle and
/// the filled bookmark at the right. The bookmark takes the saving off.
class SavedCard extends StatelessWidget {
  const SavedCard({
    super.key,
    required this.item,
    required this.onOpen,
    required this.onUnsave,
    required this.child,
    this.lead,
    this.busy = false,
  });

  final SavedItem item;
  final VoidCallback onOpen;
  final VoidCallback onUnsave;
  final Widget? lead;
  final Widget child;

  /// The API is answering for this card: the bookmark does not take a second tap.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final key = '${item.kind.name}.${item.id}';
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: ValueKey('saved.row.$key'),
          borderRadius: BorderRadius.circular(12),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (lead != null) ...[lead!, const SizedBox(width: 12)],
                Expanded(child: child),
                _BookmarkButton(
                  key: ValueKey('saved.unsave.$key'),
                  label: 'Remove ${item.title} from saved',
                  onPressed: busy ? null : onUnsave,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The filled bookmark: this is saved, tap to un-save. 40 dp to hit.
class _BookmarkButton extends StatelessWidget {
  const _BookmarkButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onPressed,
        radius: 22,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            Symbols.bookmark,
            fill: 1,
            size: 24,
            color: onPressed == null ? AppColors.slate300 : AppColors.primary,
          ),
        ),
      ),
    );
  }
}

/// "Saved 3d ago".
String? savedAgo(SavedItem item, {DateTime? now}) {
  final at = item.savedAt;
  return at == null ? null : 'Saved ${timeAgo(at, now: now)}';
}

/// 2000 paise → "₹20"; 250000 → "₹2,500"; 12345600 → "₹1,23,456", in lakh grouping.
String rupeesFromPaise(int paise) {
  final n = (paise / 100).round();
  final digits = n.toString();
  if (digits.length <= 3) return '₹$digits';
  final head = digits.substring(0, digits.length - 3);
  final grouped = head.replaceAllMapped(RegExp(r'(\d)(?=(\d{2})+$)'), (m) => '${m[1]},');
  return '₹$grouped,${digits.substring(digits.length - 3)}';
}

/// 1204 → "1,204".
String groupedCount(int n) => n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

String _count(int n, String one, [String? many]) => '${groupedCount(n)} ${n == 1 ? one : (many ?? '${one}s')}';

/// A line of small facts separated by dots, or nothing at all when there are none.
class _Facts extends StatelessWidget {
  const _Facts(this.facts, {this.maxLines = 2});

  final List<String> facts;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    if (facts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(facts.join(' · '), style: AccountText.meta, maxLines: maxLines, overflow: TextOverflow.ellipsis),
    );
  }
}

/// "★ 4.8 (12)": a star, the average and how many rated.
class _Rating extends StatelessWidget {
  const _Rating({required this.rating, required this.count});

  final double rating;
  final int count;

  @override
  Widget build(BuildContext context) {
    // A star rating is out of five, whatever a seeded average says.
    final shown = rating.clamp(0.0, 5.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Symbols.star, fill: 1, size: 14, color: AppColors.amber500),
        const SizedBox(width: 3),
        Text(
          count > 0 ? '${shown.toStringAsFixed(1)} ($count)' : shown.toStringAsFixed(1),
          style: AccountText.meta.copyWith(color: AppColors.slate700, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// --- jobs -------------------------------------------------------------------------------------------------------

class SavedJobCard extends StatelessWidget {
  const SavedJobCard({
    super.key,
    required this.job,
    required this.onOpen,
    required this.onUnsave,
    this.busy = false,
    this.now,
  });

  final SavedJob job;
  final VoidCallback onOpen;
  final VoidCallback onUnsave;
  final bool busy;

  /// For tests: the clock the "Saved … ago" reads.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final closed = job.closed;
    return SavedCard(
      item: job,
      onOpen: onOpen,
      onUnsave: onUnsave,
      busy: busy,
      lead: CompanyLogo(url: job.companyLogo, name: job.companyName, size: 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (closed) ...[
            const AccountChip(label: 'No longer open', color: AppColors.amber50, ink: AppColors.amber800),
            const SizedBox(height: 6),
          ],
          Text(job.title, style: AccountText.itemTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          if (job.jobTitle != null)
            Text(job.companyName, style: AccountText.body, maxLines: 1, overflow: TextOverflow.ellipsis)
          else
            Text(
              'This job has closed. See what else ${job.companyName} is hiring for, or remove it.',
              style: AccountText.meta,
            ),
          if (job.facts.isNotEmpty) _Facts([job.facts], maxLines: 1),
          _Facts([?job.salary, ?savedAgo(job, now: now)]),
        ],
      ),
    );
  }
}

// --- mentors ----------------------------------------------------------------------------------------------------

class SavedMentorCard extends StatelessWidget {
  const SavedMentorCard({
    super.key,
    required this.mentor,
    required this.onOpen,
    required this.onUnsave,
    this.busy = false,
    this.now,
  });

  final SavedMentor mentor;
  final VoidCallback onOpen;
  final VoidCallback onUnsave;
  final bool busy;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final m = mentor;
    final price = m.planFromPaisa == null ? null : 'From ${rupeesFromPaise(m.planFromPaisa!)}/mo';
    return SavedCard(
      item: m,
      onOpen: onOpen,
      onUnsave: onUnsave,
      busy: busy,
      lead: AccountAvatar(url: m.photo, initials: m.initials, size: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(m.name, style: AccountText.itemTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (m.approved) ...[
                const SizedBox(width: 4),
                const Icon(Symbols.verified, fill: 1, size: 15, color: AppColors.primary),
              ],
            ],
          ),
          if (m.roleLine.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(m.roleLine, style: AccountText.body, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 10,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (m.rating > 0) _Rating(rating: m.rating, count: m.ratingCount),
              if (m.topMentor)
                const AccountChip(label: 'Top mentor', color: AppColors.amber50, ink: AppColors.amber800),
              if (m.city != null) Text(m.city!, style: AccountText.meta),
              if (price != null) Text(price, style: AccountText.meta),
            ],
          ),
          if (m.expertise.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final e in m.expertise.take(3))
                  AccountChip(label: e, color: AppColors.chipEmphasis, ink: AppColors.primary),
              ],
            ),
          ],
          _Facts([?savedAgo(m, now: now)]),
        ],
      ),
    );
  }
}

// --- suppliers --------------------------------------------------------------------------------------------------

class SavedSupplierCard extends StatelessWidget {
  const SavedSupplierCard({
    super.key,
    required this.supplier,
    required this.onOpen,
    required this.onUnsave,
    this.busy = false,
    this.now,
  });

  final SavedSupplier supplier;
  final VoidCallback onOpen;
  final VoidCallback onUnsave;
  final bool busy;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final s = supplier;
    return SavedCard(
      item: s,
      onOpen: onOpen,
      onUnsave: onUnsave,
      busy: busy,
      lead: CompanyLogo(url: s.logo, name: s.name, size: 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.name, style: AccountText.itemTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (s.headline != null)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(s.headline!, style: AccountText.body, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (s.level != null)
                AccountChip(
                  label: s.level!,
                  color: AccountChip.blue.$1,
                  ink: AccountChip.blue.$2,
                  icon: Symbols.verified,
                ),
              if (s.premium) const AccountChip(label: 'Premium', color: AppColors.amber50, ink: AppColors.amber800),
              if (s.rating > 0) _Rating(rating: s.rating, count: s.ratingCount),
              if (s.place != null) Text(s.place!, style: AccountText.meta),
            ],
          ),
          _Facts([if (s.gstRegistered) 'GST registered', ?savedAgo(s, now: now)]),
        ],
      ),
    );
  }
}

// --- councils ---------------------------------------------------------------------------------------------------

class SavedCouncilCard extends StatelessWidget {
  const SavedCouncilCard({
    super.key,
    required this.council,
    required this.onOpen,
    required this.onUnsave,
    this.busy = false,
    this.now,
  });

  final SavedCouncil council;
  final VoidCallback onOpen;
  final VoidCallback onUnsave;
  final bool busy;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final c = council;
    return SavedCard(
      item: c,
      onOpen: onOpen,
      onUnsave: onUnsave,
      busy: busy,
      lead: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: AppColors.chipEmphasis, borderRadius: BorderRadius.circular(10)),
        child: const Icon(LucideIcons.landmark, size: 22, color: AppColors.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c.name, style: AccountText.itemTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
          _Facts([
            _count(c.memberCount, 'member'),
            if (c.upcomingEventCount > 0) _count(c.upcomingEventCount, 'upcoming event'),
          ]),
          _Facts([?savedAgo(c, now: now)]),
        ],
      ),
    );
  }
}

// --- discussions ------------------------------------------------------------------------------------------------

class SavedThreadCard extends StatelessWidget {
  const SavedThreadCard({
    super.key,
    required this.thread,
    required this.onOpen,
    required this.onUnsave,
    this.busy = false,
    this.now,
  });

  final SavedThread thread;
  final VoidCallback onOpen;
  final VoidCallback onUnsave;
  final bool busy;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final t = thread;
    final active = t.lastActivityAt ?? t.createdAt;
    return SavedCard(
      item: t,
      onOpen: onOpen,
      onUnsave: onUnsave,
      busy: busy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (t.kindLabel != null || t.topic != null || t.answered) ...[
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                if (t.kindLabel != null)
                  AccountChip(label: t.kindLabel!, color: AppColors.chipEmphasis, ink: AppColors.primary),
                if (t.answered) AccountChip(label: 'Answered', color: AccountChip.green.$1, ink: AccountChip.green.$2),
                if (t.topic != null) AccountChip(label: t.topic!),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Text(t.title, style: AccountText.itemTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (t.excerpt.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(t.excerpt, style: AccountText.body, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              AccountAvatar(url: t.authorPhoto, initials: t.authorInitials, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  [t.authorName, if (active != null) timeAgo(active, now: now)].join(' · '),
                  style: AccountText.meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          _Facts([
            _count(t.replyCount, 'reply', 'replies'),
            if (t.likes > 0) _count(t.likes, 'like'),
            ?savedAgo(t, now: now),
          ]),
        ],
      ),
    );
  }
}

// --- states -----------------------------------------------------------------------------------------------------

/// A kind with nothing saved: a glyph, what it is and where to save one.
class SavedEmpty extends StatelessWidget {
  const SavedEmpty({super.key, required this.kind, required this.onBrowse});

  final SavedKind kind;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 56, 32, 40),
      child: Column(
        children: [
          const Icon(Symbols.bookmark, size: 40, color: AppColors.slate400),
          const SizedBox(height: 12),
          Text(kind.emptyTitle, style: AccountText.cardTitle, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(kind.emptyHint, style: AccountText.body, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          AccountButton(
            key: const ValueKey('saved.browse'),
            label: switch (kind) {
              SavedKind.jobs => 'Browse jobs',
              SavedKind.mentors => 'Find mentors',
              SavedKind.suppliers => 'Open the Marketplace',
              SavedKind.councils => 'See councils',
              SavedKind.discussions => 'Open Forums',
            },
            onPressed: onBrowse,
            outlined: true,
            expand: false,
            height: 40,
          ),
        ],
      ),
    );
  }
}
