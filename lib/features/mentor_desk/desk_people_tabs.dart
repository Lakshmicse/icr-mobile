import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../mentorship_my/mentoring_format.dart';
import '../mentorship_my/mentoring_links.dart';
import '../mentorship_my/mentoring_models.dart';
import '../mentorship_my/widgets/blocks.dart';
import '../mentorship_my/widgets/kit.dart';
import 'mentor_desk_controller.dart';
import 'mentor_desk_models.dart';

/// The mentor's mentees: live pairings first (each opens the pairing), finished ones after.
class DeskMenteesTab extends StatelessWidget {
  const DeskMenteesTab({super.key, required this.controller, required this.links, required this.onOpenPairing});

  final MentorDeskController controller;
  final MentorshipLinks links;
  final ValueChanged<String> onOpenPairing;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final loading = !c.roster.loaded && c.roster.loading;
    final failed = !c.roster.loaded ? c.roster.error : null;
    final live = c.roster.data ?? const <Pairing>[];
    final liveIds = {for (final p in live) p.id};
    final finished = [
      for (final p in c.mentoring.pairings.data ?? const <Pairing>[])
        if (p.viewerIsMentor && !p.status.live && !liveIds.contains(p.id)) p,
    ];
    final children = <Widget>[
      if (live.isEmpty && finished.isEmpty)
        const EmptyNote(
          icon: LucideIcons.users,
          title: 'No mentees yet',
          body: 'When you accept a request, your mentee appears here, with their sessions, goals and notes.',
        ),
      if (live.isNotEmpty) ...[
        GroupLabel('Mentoring now (${live.length})', top: 0),
        for (final p in live)
          PairingCard(
            key: ValueKey('mentee-${p.id}'),
            pairing: p,
            next: c.mentoring.nextSessionOf(p.id),
            onOpen: () => onOpenPairing(p.id),
            onMessage: () => links.messagePairing(context, c.repository.mentoring, p.id),
          ),
      ],
      if (finished.isNotEmpty) ...[
        GroupLabel('Finished (${finished.length})', top: live.isEmpty ? 0 : 12),
        for (final p in finished)
          PairingCard(key: ValueKey('finished-${p.id}'), pairing: p, onOpen: () => onOpenPairing(p.id)),
      ],
    ];
    return LoadedList(
      loading: loading,
      error: failed,
      errorTitle: "Couldn't load your mentees",
      onRefresh: () => c.refreshTab(DeskTab.mentees),
      children: loading || failed != null ? const [] : children,
    );
  }
}

/// What the mentor earned, read only: ICR pays out, the app never moves money.
class DeskEarningsTab extends StatelessWidget {
  const DeskEarningsTab({super.key, required this.controller});

  final MentorDeskController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final e = c.earnings.data;
    final loading = e == null && c.earnings.loading;
    final failed = e == null ? c.earnings.error : null;
    // What each ledger line was for, read from the sales and terms already loaded.
    final titles = <String, String>{
      for (final r in c.soldAll.data ?? const <SoldRow>[]) r.id: r.purchase.title,
      for (final t in c.terms.data ?? const <PlanTerm>[]) t.id: t.title,
    };
    final names = <String, String>{
      for (final r in c.soldAll.data ?? const <SoldRow>[])
        if (r.purchase.buyer != null) r.id: r.purchase.buyer!.name,
      for (final t in c.terms.data ?? const <PlanTerm>[])
        if (t.counterpart != null) t.id: t.counterpart!.name,
    };
    final children = <Widget>[
      if (e != null) ...[
        StatStrip(tiles: [(inr(e.unsettledPaisa), 'Awaiting payout'), (inr(e.settledPaisa), 'Paid out')]),
        Callout(
          tone: PillTone.grey,
          text:
              'You keep what is left after ICR\'s fee. ICR pays out by bank transfer and records the reference here. '
              'Nothing on this page can be changed from the app.',
        ),
        const SectionTitle(title: 'Earnings'),
        if (e.entries.isEmpty)
          const EmptyNote(
            icon: LucideIcons.wallet,
            compact: true,
            title: 'No earnings yet',
            body: 'Paid sessions, resources, programmes and plans show up here as they are sold.',
          ),
        for (final entry in e.entries)
          MentoringCard(
            key: ValueKey('earning-${entry.id}'),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: entry.settled ? AppColors.emerald50 : AppColors.amber50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    entry.settled ? LucideIcons.circleCheck : LucideIcons.hourglass,
                    size: 18,
                    color: entry.settled ? AppColors.emerald700 : AppColors.amber800,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titles[entry.purchaseId ?? entry.subscriptionId] ??
                            (entry.subscriptionId != null ? 'A plan or programme' : 'A sale'),
                        style: MentoringText.cardTitle,
                      ),
                      Text(
                        [
                          if (names[entry.purchaseId ?? entry.subscriptionId] != null)
                            names[entry.purchaseId ?? entry.subscriptionId]!,
                          dayLabel(entry.createdAt),
                          entry.settled
                              ? 'paid out ${dayLabel(entry.settledAt!)}${entry.settlementRef == null ? '' : ' (${entry.settlementRef})'}'
                              : 'awaiting payout',
                        ].join(' · '),
                        style: MentoringText.meta,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(inr(entry.amountPaisa), style: MentoringText.cardTitle),
              ],
            ),
          ),
      ],
    ];
    return LoadedList(
      loading: loading,
      error: failed,
      errorTitle: "Couldn't load your earnings",
      onRefresh: () => c.refreshTab(DeskTab.earnings),
      children: loading || failed != null ? const [] : children,
    );
  }
}

/// Reviews the mentor received, read only: anonymous ratings from mentees, and reviews of what they sell.
class DeskReviewsTab extends StatelessWidget {
  const DeskReviewsTab({super.key, required this.controller});

  final MentorDeskController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final loading =
        (!c.feedback.loaded && c.feedback.loading) || (!c.serviceReviews.loaded && c.serviceReviews.loading);
    final failed = !c.feedback.loaded && !c.serviceReviews.loaded ? (c.feedback.error ?? c.serviceReviews.error) : null;
    final profile = c.profile;
    final fb = c.feedback.data ?? const <MenteeFeedback>[];
    final sr = c.serviceReviews.data ?? const <ServiceReviewRow>[];
    final children = <Widget>[
      StatStrip(
        tiles: [
          (profile == null || profile.ratingCount == 0 ? '-' : profile.rating.toStringAsFixed(1), 'Rating'),
          ('${profile?.ratingCount ?? 0}', 'Reviews'),
          ('${profile?.menteesHelped ?? 0}', 'Mentees helped'),
        ],
      ),
      const GroupLabel('From your mentees', top: 0),
      if (fb.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'No mentee has rated a mentorship with you yet. Ratings are anonymous.',
            style: MentoringText.body,
          ),
        ),
      for (final f in fb)
        MentoringCard(
          key: ValueKey('fb-${f.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Stars(f.rating),
                  const Spacer(),
                  Text(dayLabel(f.createdAt), style: MentoringText.meta),
                ],
              ),
              if (f.comment != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(f.comment!, style: MentoringText.quote),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('A mentee', style: MentoringText.meta),
              ),
            ],
          ),
        ),
      const GroupLabel('On what you sell', top: 12),
      if (sr.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text('No reviews of your sessions or resources yet.', style: MentoringText.body),
        ),
      for (final r in sr)
        MentoringCard(
          key: ValueKey('sr-${r.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Stars(r.rating),
                  const Spacer(),
                  Text(dayLabel(r.createdAt), style: MentoringText.meta),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(r.serviceTitle, style: MentoringText.cardTitle),
              ),
              if (r.comment != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(r.comment!, style: MentoringText.quote),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(r.authorName ?? 'A buyer', style: MentoringText.meta),
              ),
            ],
          ),
        ),
    ];
    return LoadedList(
      loading: loading,
      error: failed,
      errorTitle: "Couldn't load your reviews",
      onRefresh: () => c.refreshTab(DeskTab.reviews),
      children: loading || failed != null ? const [] : children,
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars(this.rating);

  final int rating;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 1; i <= 5; i++)
        Icon(
          i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 18,
          color: i <= rating ? MentoringColors.star : AppColors.outline,
        ),
    ],
  );
}
