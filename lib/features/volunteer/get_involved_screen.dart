import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/util/links.dart';
import '../chapters/community_kit.dart';
import 'volunteer_apply_screen.dart';
import 'volunteer_controller.dart';
import 'volunteer_data.dart';
import 'volunteer_models.dart';

/// Opens the application form over the current screen: the volunteer [role] (or none) and chapter to start
/// from, the person's name and email filled in from their account, the chapters to choose from. The
/// result is true when the ICR team has the interest.
Future<bool> openVolunteerForm(
  BuildContext context, {
  required VolunteerController volunteer,
  VolunteerRole? role,
  String? chapterName,
  VoidCallback? onBell,
  Future<void> Function(BuildContext context, Uri uri) opener = openUrl,
}) async {
  final form = VolunteerFormController(
    repository: volunteer.repository,
    roles: volunteer.roles,
    chapters: volunteer.chapters,
    sender: volunteer.sender,
    role: role,
    chapterName: chapterName,
  );
  final sent = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => VolunteerApplyScreen(controller: form, onBell: onBell, opener: opener),
    ),
  );
  final ok = sent == true || form.sent;
  if (ok) volunteer.markSent(role);
  form.dispose();
  return ok;
}

/// Get Involved & Volunteer: ways to give time to ICR, what they ask and what they earn.
///
/// Top to bottom: the headline with "Volunteer with ICR", "Become a mentor" and "Find your chapter"; the
/// member's own CPD (hours, the year, the target, where they came from: what the API holds); the
/// opportunities, searchable, each opening to its responsibilities with Apply; the benefits; and what
/// volunteering earns. Apply opens a form that goes to the ICR team through the contact endpoint.
///
/// Reads a [VolunteerController] from Provider and starts it on first build. Everything that leaves goes
/// through a callback the shell wires: [onBecomeMentor], [onOpenChapters], [onBell].
class GetInvolvedScreen extends StatefulWidget {
  const GetInvolvedScreen({
    super.key,
    required this.onBack,
    this.onBell,
    this.onBecomeMentor,
    this.onOpenChapters,
    this.intent,
    this.opener = openUrl,
  });

  final VoidCallback onBack;

  /// The bell. The website's notifications page when null.
  final VoidCallback? onBell;

  /// "Become a mentor": the mentor application. The button is left out when null.
  final VoidCallback? onBecomeMentor;

  /// "Find your chapter": Regional Chapters. The button is left out when null.
  final VoidCallback? onOpenChapters;

  /// What the visit starts on: a chapter's page asks for a committee seat at that chapter and the
  /// application form opens at once. Nothing else opens it.
  final VolunteerIntent? intent;

  /// Hands a page to the browser. Tests give their own.
  final Future<void> Function(BuildContext context, Uri uri) opener;

  @override
  State<GetInvolvedScreen> createState() => _GetInvolvedScreenState();
}

class _GetInvolvedScreenState extends State<GetInvolvedScreen> {
  final _search = TextEditingController();
  late final VolunteerController _c;

  @override
  void initState() {
    super.initState();
    _c = context.read<VolunteerController>();
    if (!_c.started) _c.start();
    final intent = widget.intent;
    if (intent != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openIntent(intent));
    }
  }

  /// The form opens once the screen knows who the member is (their name and email) and the chapters.
  Future<void> _openIntent(VolunteerIntent intent) async {
    if (!mounted) return;
    await _c.start();
    if (!mounted) return;
    await _apply(role: _c.roleByKey(intent.roleKey), chapterName: intent.chapterName);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _bell() {
    final go = widget.onBell;
    if (go != null) return go();
    widget.opener(context, AppConfig.sitePage('/notifications'));
  }

  Future<void> _apply({VolunteerRole? role, String? chapterName}) async {
    final sent = await openVolunteerForm(
      context,
      volunteer: _c,
      role: role,
      chapterName: chapterName,
      onBell: widget.onBell,
      opener: widget.opener,
    );
    if (sent && mounted) showMessage(context, 'Your interest is with the ICR team.');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<VolunteerController>();
    return CommunityPage(
      title: 'Get Involved',
      onBack: widget.onBack,
      onBell: _bell,
      unread: c.unread,
      onRefresh: c.refresh,
      children: _body(c),
    );
  }

  List<Widget> _body(VolunteerController c) {
    final roles = c.visibleRoles;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GET INVOLVED & VOLUNTEER', style: CommunityText.kicker),
            const SizedBox(height: 6),
            Text(
              'Volunteer, lead, shape the profession',
              style: AppText.workSans(20, FontWeight.w700, AppColors.slate900, lineHeight: 26),
            ),
            const SizedBox(height: 8),
            Text(
              'ICR offers members meaningful opportunities to give back: lead a chapter, mentor, speak, review '
              'standards and more. Volunteering earns certified CPD credits.',
              style: CommunityText.body,
            ),
            const SizedBox(height: 14),
            CommunityButton(
              label: 'Volunteer with ICR',
              icon: LucideIcons.handHeart,
              expand: true,
              height: 40,
              onPressed: () => _apply(),
            ),
            if (widget.onBecomeMentor != null || widget.onOpenChapters != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (widget.onBecomeMentor != null)
                    Expanded(
                      child: CommunityButton(
                        label: 'Become a mentor',
                        outlined: true,
                        expand: true,
                        height: 38,
                        onPressed: widget.onBecomeMentor,
                      ),
                    ),
                  if (widget.onBecomeMentor != null && widget.onOpenChapters != null) const SizedBox(width: 8),
                  if (widget.onOpenChapters != null)
                    Expanded(
                      child: CommunityButton(
                        label: 'Find your chapter',
                        outlined: true,
                        expand: true,
                        height: 38,
                        onPressed: widget.onOpenChapters,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 18),
      const Divider(height: 1, thickness: 1, color: CommunityColors.tileRule),
      const SizedBox(height: 14),
      CommunitySectionHeading(
        title: 'Your CPD',
        dot: AppColors.success,
        caption: c.cpd == null ? null : (c.cpd!.year == null ? null : '${c.cpd!.year}'),
      ),
      const SizedBox(height: 8),
      _CpdCard(controller: c),
      const SizedBox(height: 16),
      const Divider(height: 1, thickness: 1, color: CommunityColors.tileRule),
      const SizedBox(height: 14),
      CommunitySectionHeading(title: 'Volunteer Opportunities', pill: '${c.roles.length}'),
      const SizedBox(height: 4),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text('Ways to give back, from a few hours a month to a cohort or an event.', style: CommunityText.small),
      ),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: CommunitySearchField(
          controller: _search,
          hint: 'Search roles, for example mentor or ESG…',
          onChanged: c.setSearch,
        ),
      ),
      const SizedBox(height: 12),
      if (roles.isEmpty)
        CommunityNotice(
          icon: LucideIcons.searchX,
          title: 'No role matches',
          body: 'Try another word, or tell the team what you have in mind.',
          action: 'Volunteer with ICR',
          onAction: () => _apply(),
          secondary: 'Clear search',
          onSecondary: () {
            _search.clear();
            c.setSearch('');
          },
          padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
        )
      else
        for (final r in roles)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: _RoleCard(
              role: r,
              open: c.isOpen(r),
              sent: c.isSent(r),
              onToggle: () => c.toggle(r),
              onApply: () => _apply(role: r),
            ),
          ),
      const SizedBox(height: 8),
      const Divider(height: 1, thickness: 1, color: CommunityColors.tileRule),
      const SizedBox(height: 14),
      const CommunitySectionHeading(title: 'Volunteer Benefits'),
      const SizedBox(height: 4),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'Volunteering with ICR is a two-way exchange: you shape the profession and it shapes you.',
          style: CommunityText.small,
        ),
      ),
      const SizedBox(height: 10),
      for (final b in volunteerBenefits)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: CommunityCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(volunteerIcon(b.icon), size: 18, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.title, style: CommunityText.personName),
                      const SizedBox(height: 2),
                      Text(b.description, style: CommunityText.body),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: CommunityButton(label: 'Raise your hand', expand: true, height: 40, onPressed: () => _apply()),
      ),
      const SizedBox(height: 18),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: CommunityCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Volunteering earns CPD credits', style: CommunityText.cardTitle),
              const SizedBox(height: 4),
              Text(
                'Committee work, mentoring, speaking and standards work count towards your certification.',
                style: CommunityText.body,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final (name, credits) in volunteerCreditCopy)
                    CommunityPill(
                      label: '$name: $credits',
                      fill: Colors.white,
                      border: CommunityColors.border,
                      style: CommunityText.sectionPill,
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 28),
    ];
  }
}

/// The member's CPD as the API gives it: hours, this year, the target and how far along it is, where
/// the hours came from and the latest entries; or why there is none (signed out, a failed read).
class _CpdCard extends StatelessWidget {
  const _CpdCard({required this.controller});

  final VolunteerController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final cpd = c.cpd;
    if (cpd == null) {
      if (c.cpdLoading || !c.started) return const CommunityLoading(height: 90);
      if (c.cpdError != null) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(LucideIcons.circleAlert, size: 16, color: AppColors.error),
              const SizedBox(width: 8),
              Expanded(child: Text(c.cpdError!, style: CommunityText.fieldError)),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: c.refresh,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('Try again', style: CommunityText.link),
                ),
              ),
            ],
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text('Sign in to see the CPD hours you have earned.', style: CommunityText.small),
      );
    }
    final target = cpd.targetHours;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CommunityStatGrid(
          tiles: [
            CommunityStatTile(label: 'Hours earned', value: CpdSummary.hoursLabel(cpd.totalHours)),
            CommunityStatTile(
              label: cpd.year == null ? 'This year' : 'In ${cpd.year}',
              value: CpdSummary.hoursLabel(cpd.hoursThisYear),
              blue: true,
              note: target == null ? null : 'of ${CpdSummary.hoursLabel(target)}',
            ),
          ],
        ),
        if (cpd.progress != null) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: cpd.progress!.clamp(0, 1).toDouble(),
                    minHeight: 5,
                    color: AppColors.success,
                    backgroundColor: CommunityColors.greyPill,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  cpd.targetIsDefault
                      ? '${(cpd.progress! * 100).round()}% of the suggested ${CpdSummary.hoursLabel(target!)} hours'
                      : '${(cpd.progress! * 100).round()}% of your ${CpdSummary.hoursLabel(target!)}-hour target',
                  style: CommunityText.meta,
                ),
              ],
            ),
          ),
        ],
        if (cpd.bySource.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in cpd.bySource)
                  CommunityPill(
                    label: '${CpdSummary.sourceLabel(s.source)} ${CpdSummary.hoursLabel(s.hours)} h',
                    fill: CommunityColors.greyPill,
                    style: CommunityText.sectionPill,
                    height: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
              ],
            ),
          ),
        ],
        if (cpd.recent.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final e in cpd.recent.take(3))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      '+${CpdSummary.hoursLabel(e.hours)} h',
                      style: CommunityText.metaGreen.copyWith(fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e.description ?? CpdSummary.sourceLabel(e.source),
                      style: CommunityText.personLine,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (e.awardedAt != null) Text(monthDay(e.awardedAt!), style: CommunityText.meta),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// A volunteer role: its glyph, title and description, "Responsibilities" that open, the time asked, and
/// Apply (or "Interest sent" once it was, with Apply again).
class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.open,
    required this.sent,
    required this.onToggle,
    required this.onApply,
  });

  final VolunteerRole role;
  final bool open;
  final bool sent;
  final VoidCallback onToggle;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final r = role;
    return CommunityCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: CommunityColors.blue50, borderRadius: BorderRadius.circular(9)),
                child: Icon(volunteerIcon(r.icon), size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(r.title, style: CommunityText.cardTitle.copyWith(fontSize: 14, height: 1.3)),
                ),
              ),
              if (sent)
                CommunityPill(
                  label: 'INTEREST SENT',
                  icon: LucideIcons.check,
                  fill: CommunityColors.green50,
                  style: CommunityText.pill.copyWith(color: CommunityColors.green700),
                  height: 18,
                  border: CommunityColors.green200,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(r.description, style: CommunityText.body),
          const SizedBox(height: 8),
          Semantics(
            button: true,
            expanded: open,
            label: 'Responsibilities of ${r.title}',
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: CommunityColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('Responsibilities', style: CommunityText.metaStrong)),
                        Icon(
                          open ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                          size: 16,
                          color: AppColors.slate400,
                        ),
                      ],
                    ),
                    if (open) ...[
                      const SizedBox(height: 6),
                      for (final item in r.responsibilities)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 6, right: 8, left: 2),
                                child: Container(
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                ),
                              ),
                              Expanded(child: Text(item, style: CommunityText.body)),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(LucideIcons.clock, size: 13, color: AppColors.slate400),
              const SizedBox(width: 5),
              Expanded(child: Text(r.commitment, style: CommunityText.personLine)),
            ],
          ),
          const SizedBox(height: 10),
          CommunityButton(
            label: sent ? 'Apply again' : 'Apply',
            outlined: sent,
            expand: true,
            height: 36,
            onPressed: onApply,
          ),
        ],
      ),
    );
  }
}
