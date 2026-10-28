/// The tracker's pure parts, ported from the website's
/// `components/career/applications/applicationsModel.ts`: where an application
/// stands in the candidate's words, which tab it sits in, how far it has come,
/// what it waits on, and the figures above the list. No widgets, so tests and
/// both screens read them alike.
library;

import 'career_models.dart';

/// Where an application stands, as the candidate reads it. Not the stage
/// itself: an APPLIED application the recruiter opened reads "Viewed", and a
/// declined offer reads "Offer declined" though the stage stays OFFER.
enum AppStatus {
  applied('Applied'),
  viewed('Viewed'),
  inReview('In review'),
  interviewing('Interviewing'),
  offer('Offer'),
  offerDeclined('Offer declined'),
  hired('Hired'),
  notSelected('Not selected'),
  withdrawn('Withdrawn');

  const AppStatus(this.label);
  final String label;
}

AppStatus statusOf(CareerApplication app) => switch (app.stage) {
  'WITHDRAWN' => AppStatus.withdrawn,
  'REJECTED' => AppStatus.notSelected,
  'HIRED' => AppStatus.hired,
  'OFFER' => app.latestOffer?.status == 'DECLINED' ? AppStatus.offerDeclined : AppStatus.offer,
  'INTERVIEW' => AppStatus.interviewing,
  'SCREENING' => AppStatus.inReview,
  _ => app.viewedAt != null ? AppStatus.viewed : AppStatus.applied,
};

const _archived = {AppStatus.notSelected, AppStatus.withdrawn, AppStatus.offerDeclined};

/// Finished from the candidate's side: it sits under Archived.
bool isArchived(CareerApplication app) => _archived.contains(statusOf(app));

/// Still being decided: neither archived nor hired.
bool _inPlay(AppStatus s) => !_archived.contains(s) && s != AppStatus.hired;

/// The tracker's tabs, in order.
enum ApplicationsTab {
  active('Active'),
  interviews('Interviews'),
  offers('Offers'),
  archived('Archived'),
  all('All');

  const ApplicationsTab(this.label);
  final String label;
}

/// Rounds still to happen, soonest first.
List<CareerInterview> upcomingInterviews(CareerApplication app, DateTime now) =>
    app.interviews.where((iv) => iv.live && !iv.scheduledAt.isBefore(now)).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

bool inTab(CareerApplication app, ApplicationsTab tab, DateTime now) {
  final status = statusOf(app);
  return switch (tab) {
    ApplicationsTab.all => true,
    ApplicationsTab.archived => _archived.contains(status),
    ApplicationsTab.active => _inPlay(status),
    ApplicationsTab.interviews =>
      status == AppStatus.interviewing || (_inPlay(status) && upcomingInterviews(app, now).isNotEmpty),
    ApplicationsTab.offers => status == AppStatus.offer || status == AppStatus.hired,
  };
}

Map<ApplicationsTab, int> tabCounts(List<CareerApplication> apps, DateTime now) => {
  for (final tab in ApplicationsTab.values) tab: apps.where((a) => inTab(a, tab, now)).length,
};

/// With nothing asked for, Active; All when nothing is in play.
ApplicationsTab defaultTab(Map<ApplicationsTab, int> counts) =>
    (counts[ApplicationsTab.active] ?? 0) > 0 ? ApplicationsTab.active : ApplicationsTab.all;

/// Matches the job title, the company or the city, ignoring case.
bool matchesSearch(CareerApplication app, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return [app.jobTitle, app.companyName, app.city].whereType<String>().any((s) => s.toLowerCase().contains(q));
}

/// The newest thing that happened to an application that the candidate can see.
DateTime lastActivityAt(CareerApplication app) {
  final moments = [
    app.createdAt,
    ?app.viewedAt,
    ?app.withdrawnAt,
    ...app.events.map((e) => e.at),
    for (final o in app.offers) ...[?o.sentAt, ?o.respondedAt],
  ];
  return moments.reduce((a, b) => b.isAfter(a) ? b : a);
}

enum ApplicationsSort {
  recent('Recent activity'),
  applied('Date applied'),
  match('Best match');

  const ApplicationsSort(this.label);
  final String label;
}

List<CareerApplication> sortApps(List<CareerApplication> apps, ApplicationsSort sort) {
  int byApplied(CareerApplication a, CareerApplication b) => b.createdAt.compareTo(a.createdAt);
  final rows = [...apps];
  switch (sort) {
    case ApplicationsSort.applied:
      rows.sort(byApplied);
    case ApplicationsSort.match:
      rows.sort((a, b) {
        final m = (b.matchScore ?? -1).compareTo(a.matchScore ?? -1);
        return m != 0 ? m : byApplied(a, b);
      });
    case ApplicationsSort.recent:
      rows.sort((a, b) {
        final m = lastActivityAt(b).compareTo(lastActivityAt(a));
        return m != 0 ? m : byApplied(a, b);
      });
  }
  return rows;
}

// --- Progress ----------------------------------------------------------------

enum ProgressState { done, current, todo, locked }

class ProgressStep {
  const ProgressStep(this.label, this.state, [this.at]);

  final String label;
  final ProgressState state;

  /// When the application reached it, where the candidate may know.
  final DateTime? at;
}

DateTime? _reachedAt(CareerApplication app, String stage, [String? alsoType]) {
  for (final e in app.events) {
    if (e.toStage == stage || (alsoType != null && e.type == alsoType)) return e.at;
  }
  return null;
}

/// The five steps an application moves through, while in play or hired; null
/// once it is archived (the row says how it ended instead). Without the plan
/// that shows viewed receipts, "Viewed" is locked while the stage is APPLIED.
List<ProgressStep>? progressOf(CareerApplication app) {
  if (isArchived(app)) return null;
  final hired = app.stage == 'HIRED';
  final offer = app.latestOffer;
  final current = hired || app.stage == 'OFFER'
      ? 4
      : app.stage == 'INTERVIEW'
      ? 3
      : app.stage == 'SCREENING'
      ? 2
      : app.viewedAt != null
      ? 1
      : 0;
  final dates = <DateTime?>[
    app.createdAt,
    app.viewedAt,
    _reachedAt(app, 'SCREENING'),
    _reachedAt(app, 'INTERVIEW', 'INTERVIEW_SCHEDULED'),
    hired
        ? (_reachedAt(app, 'HIRED') ?? offer?.respondedAt)
        : (offer?.sentAt ?? _reachedAt(app, 'OFFER', 'OFFER_SENT')),
  ];
  const labels = ['Applied', 'Viewed', 'In review', 'Interview', 'Offer'];
  final lockedViewed = app.visibilityLocked && current == 0;
  return [
    for (var i = 0; i < labels.length; i++)
      () {
        final state = i == 1 && lockedViewed
            ? ProgressState.locked
            : hired || i < current
            ? ProgressState.done
            : i == current
            ? ProgressState.current
            : ProgressState.todo;
        final label = hired && i == 4 ? 'Hired' : labels[i];
        return ProgressStep(
          label,
          state,
          state == ProgressState.done || state == ProgressState.current ? dates[i] : null,
        );
      }(),
  ];
}

// --- What it waits on --------------------------------------------------------

sealed class NextStep {
  const NextStep();
}

class OfferStep extends NextStep {
  const OfferStep(this.offer);
  final CareerOffer offer;
}

class InterviewStep extends NextStep {
  const InterviewStep(this.interview);
  final CareerInterview interview;
}

class HiredStep extends NextStep {
  const HiredStep(this.offer);
  final CareerOffer? offer;
}

class ClosedStep extends NextStep {
  const ClosedStep();
}

/// The one thing a row calls out: an offer to answer, the next round, the
/// hire, or a job that stopped taking applications while this one was early on.
NextStep? nextStepOf(CareerApplication app, DateTime now) {
  final status = statusOf(app);
  if (_archived.contains(status)) return null;
  final offer = app.latestOffer;
  if (offer?.status == 'SENT') return OfferStep(offer!);
  if (status == AppStatus.hired) return HiredStep(offer?.status == 'ACCEPTED' ? offer : null);
  final interviews = upcomingInterviews(app, now);
  if (interviews.isNotEmpty) return InterviewStep(interviews.first);
  if ((app.stage == 'APPLIED' || app.stage == 'SCREENING') &&
      (app.jobStatus == 'CLOSED' || app.jobStatus == 'PAUSED')) {
    return const ClosedStep();
  }
  return null;
}

/// When an archived application ended, where the candidate may know.
DateTime? endedAt(CareerApplication app) => switch (statusOf(app)) {
  AppStatus.withdrawn => app.withdrawnAt ?? _reachedAt(app, 'WITHDRAWN'),
  AppStatus.offerDeclined => app.latestOffer?.respondedAt,
  AppStatus.notSelected => _reachedAt(app, 'REJECTED', 'AUTO_ARCHIVED'),
  _ => null,
};

bool canWithdraw(CareerApplication app) => app.stage != 'WITHDRAWN' && app.stage != 'HIRED' && app.stage != 'REJECTED';

// --- Up next and the summary -------------------------------------------------

/// An interview coming up, or an offer waiting on a reply.
class UpNextItem {
  const UpNextItem.interview(this.app, CareerInterview this.interview) : offer = null;
  const UpNextItem.offer(this.app, CareerOffer this.offer) : interview = null;

  final CareerApplication app;
  final CareerInterview? interview;
  final CareerOffer? offer;
}

/// Rounds coming up (soonest first), then offers waiting on a reply (soonest deadline first).
List<UpNextItem> upNext(List<CareerApplication> apps, DateTime now, {int max = 3}) {
  final interviews = [
    for (final app in apps.where((a) => _inPlay(statusOf(a))))
      for (final iv in upcomingInterviews(app, now)) UpNextItem.interview(app, iv),
  ]..sort((a, b) => a.interview!.scheduledAt.compareTo(b.interview!.scheduledAt));
  final far = DateTime(9999);
  final offers = [
    for (final app in apps)
      if (app.latestOffer?.status == 'SENT') UpNextItem.offer(app, app.latestOffer!),
  ]..sort((a, b) => (a.offer!.expiresAt ?? far).compareTo(b.offer!.expiresAt ?? far));
  return [...interviews, ...offers].take(max).toList();
}

class ApplicationsSummary {
  const ApplicationsSummary({
    required this.active,
    required this.sentThisWeek,
    required this.viewed,
    required this.interviews,
    required this.offers,
    required this.awaitingReply,
    this.nextInterviewAt,
  });

  final int active;
  final int sentThisWeek;

  /// Null when the plan hides viewed receipts.
  final int? viewed;
  final int interviews;
  final DateTime? nextInterviewAt;
  final int offers;
  final int awaitingReply;
}

ApplicationsSummary summaryOf(List<CareerApplication> apps, DateTime now) {
  final counts = tabCounts(apps, now);
  final viewable = apps.where((a) => a.stage != 'WITHDRAWN');
  final locked = apps.any((a) => a.visibilityLocked);
  final next = [for (final a in apps.where((a) => _inPlay(statusOf(a)))) ...upcomingInterviews(a, now)]
    ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  return ApplicationsSummary(
    active: counts[ApplicationsTab.active]!,
    sentThisWeek: apps.where((a) => now.difference(a.createdAt) < const Duration(days: 7)).length,
    viewed: locked ? null : viewable.where((a) => a.viewedAt != null).length,
    interviews: counts[ApplicationsTab.interviews]!,
    nextInterviewAt: next.isEmpty ? null : next.first.scheduledAt,
    offers: counts[ApplicationsTab.offers]!,
    awaitingReply: apps.where((a) => a.latestOffer?.status == 'SENT').length,
  );
}

/// Whole calendar days from [now] to [at]: 0 today, negative once past.
int daysUntil(DateTime at, DateTime now) {
  final a = DateTime(at.year, at.month, at.day);
  final b = DateTime(now.year, now.month, now.day);
  return (a.difference(b).inHours / 24).round();
}
