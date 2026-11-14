import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/util/links.dart';
import '../../mentorship_my/mentoring_links.dart';
import '../../mentorship_my/widgets/forms.dart';
import '../../mentorship_my/widgets/kit.dart';
import 'group_form.dart';
import 'mentoring_composer.dart';
import 'offering_rows.dart';
import 'offerings_controller.dart';
import 'offerings_files.dart';
import 'offerings_models.dart';
import 'offerings_repository.dart';
import 'offerings_rules.dart';
import 'ongoing_plan_form.dart';
import 'service_form.dart';
import 'session_sheets.dart';

/// The mentor desk's Offerings tab: the storefront's gates (what must be true
/// before anything sells, as the API reports it), the 1:1 sessions and programmes,
/// resources and ongoing plans a mentor lists, and the group sessions they host.
/// Create, edit, pause and delete each; every form is validated as the API's DTO
/// is, and a refusal shows the API's own sentence and keeps what was typed.
///
/// It draws inside a scrolling tab body (it brings no Scaffold) and owns its
/// loading, error, empty and pull-to-refresh. [onChanged] is called after any
/// write so the desk can read its overview again.
class OfferingsPanel extends StatefulWidget {
  const OfferingsPanel({
    super.key,
    required this.api,
    required this.links,
    this.onChanged,
    this.pickFile = pickOfferingFile,
    this.onOpenSettings,
  });

  final ApiClient api;
  final MentorshipLinks links;
  final VoidCallback? onChanged;

  /// Opens the desk's Settings tab (the composer's "Manage in Settings" and "Change in Settings").
  final VoidCallback? onOpenSettings;

  /// The phone's file chooser; a test stands in for it.
  final OfferingFilePicker pickFile;

  @override
  State<OfferingsPanel> createState() => _OfferingsPanelState();
}

class _OfferingsPanelState extends State<OfferingsPanel> {
  late final OfferingsController _c;

  /// The tab open (owner, 7 Nov 2026: "Show tabs below under offerings: 1:1 mentoring | Group Mentoring |
  /// Resources"): 1:1 sessions, programmes and ongoing plans; the group sessions hosted; the files sold or given.
  int _tab = 0;
  static const _tabs = ['1:1 Mentoring', 'Group Mentoring', 'Resources'];

  @override
  void initState() {
    super.initState();
    _c = OfferingsController(OfferingsRepository(api: widget.api), onChanged: widget.onChanged)..start();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _c.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _gatesBlock(context),
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: SegmentTabs(
                  key: const ValueKey('offerings-tabs'),
                  labels: _tabs,
                  selected: _tab,
                  onSelect: (i) => setState(() => _tab = i),
                ),
              ),
              ...switch (_tab) {
                0 => [..._oneToOneSections(context), ..._plansSections(context)],
                1 => _sessionsSection(context),
                _ => _resourceSections(context),
              },
            ],
          ),
        );
      },
    );
  }

  // --- gates -----------------------------------------------------------------------------

  Widget _gatesBlock(BuildContext context) {
    final l = _c.storefront;
    if (!l.loaded && l.loading) return const _Loading();
    if (!l.loaded && l.error != null) {
      return _SectionError(title: 'Unable to Load Your Storefront', error: l.error!, onRetry: l.load);
    }
    final g = _c.gates;
    if (g == null) return const SizedBox.shrink();
    // A live desk shows no storefront card (owner, 7 Nov 2026: "Store front has to be completely removed here");
    // while something still stops the mentor selling, the card says what, with the seller terms to accept.
    if (g.live) return const SizedBox.shrink();
    return GatesCard(
      gates: g,
      listings: _c.listingsUsed,
      onAccept: () => _acceptTerms(context),
      onReadTerms: () => widget.links.openSite(context, '/terms'),
    );
  }

  Future<void> _acceptTerms(BuildContext context) async {
    final g = _c.gates!;
    var read = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, setState) => AlertDialog(
          title: Text('Seller Terms ${g.termsCurrentVersion}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ICR collects payment and settles your earnings monthly by bank transfer. A platform fee is taken on each sale. '
                'The Earnings tab shows the figures. If a paid session is cancelled, the member is refunded. '
                'The mentor code of conduct applies to paid work in the same way as to free mentoring.',
                style: MentoringText.body,
              ),
              const SizedBox(height: 8),
              InkWell(
                key: const ValueKey('read-terms'),
                onTap: () => widget.links.openSite(context, '/terms'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text('Read the Full Terms', style: MentoringText.buttonQuiet),
                ),
              ),
              CheckboxListTile(
                key: const ValueKey('terms-read'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: read,
                onChanged: (v) => setState(() => read = v == true),
                title: Text('I have read and accept the seller terms', style: MentoringText.bodyStrong),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Not Now')),
            TextButton(
              onPressed: read ? () => Navigator.pop(dialog, true) : null,
              child: const Text('Accept and Open'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final refusal = await _c.acceptTerms();
    if (context.mounted) showMessage(context, refusal ?? 'Your storefront is open.');
  }

  // --- services ----------------------------------------------------------------------------

  /// The 1:1 mentoring tab's first half: sessions and programmes (the ongoing plans follow).
  List<Widget> _oneToOneSections(BuildContext context) {
    final l = _c.storefront;
    if (!l.loaded) return const [];
    final live = _c.gates?.live ?? false;
    return [
      _SectionHead(
        top: 8,
        title: '1:1 Mentoring',
        count: _c.singles.length + _c.programmes.length,
        description: 'Single sessions and programmes, one mentee at a time.',
        action: 'Add 1:1 Mentoring',
        actionKey: 'add-mentoring',
        onAction: () => _addMentoring(context),
      ),
      if (_c.singles.isEmpty && _c.programmes.isEmpty)
        _Hint(
          live
              ? 'No 1:1 mentoring offerings yet. Offer a single session or a programme of up to 24 sessions.'
              : 'Available once your storefront is live.',
        ),
      for (final s in _c.singles) _serviceRow(context, s),
      for (final p in _c.programmes) _planRow(context, p),
    ];
  }

  /// The Resources tab: the files sold or given away, and any older listings.
  List<Widget> _resourceSections(BuildContext context) {
    final l = _c.storefront;
    if (!l.loaded) return const [];
    final older = [..._c.legacySeats, ..._c.retired.where((r) => r.kind != ServiceKind.groupSeat)];
    return [
      _SectionHead(
        top: 8,
        title: 'Resources',
        count: _c.resources.length,
        description: 'Guides and templates mentees download after paying.',
        action: 'Add Resource',
        actionKey: 'add-resource',
        onAction: () => _addService(context, ServiceKind.resource),
      ),
      if (_c.resources.isEmpty) const _Hint('No resources yet. Add a downloadable guide or template, delivered on payment.'),
      for (final s in _c.resources) _serviceRow(context, s),
      if (older.isNotEmpty) ...[
        const SectionTitle(title: 'Older Listings'),
        const _Hint(
          'Seats are now sold from the group session itself. These older listings can be edited, paused or deleted.',
        ),
        for (final s in older) _serviceRow(context, s),
      ],
    ];
  }

  Widget _serviceRow(BuildContext context, OfferedService s) => ServiceRow(
    service: s,
    onEdit: () => _editService(context, s),
    onToggle: () async {
      final resuming = !s.active;
      final refusal = await _c.setServiceActive(s, resuming);
      if (!context.mounted) return;
      // The API will not publish a resource without its file in the same call: choose it again in the form.
      if (resuming && s.kind == ServiceKind.resource && refusal == fileNeededMessage) {
        showMessage(context, refusal!);
        await _editService(context, s, activate: true);
        return;
      }
      showMessage(context, refusal ?? (resuming ? 'Live on your storefront.' : 'Paused. Members no longer see it.'));
    },
    onDelete: () => _confirmDelete(context, s.title, () => _c.deleteService(s)),
  );

  Future<void> _addService(BuildContext context, ServiceKind kind) async {
    if (!_openOrSay(context)) return;
    final saved = await showFormSheet(
      context,
      (_) => ServiceForm(controller: _c, pickFile: widget.pickFile, kind: kind),
    );
    if (saved && context.mounted) showMessage(context, 'Added.');
  }

  /// "Add 1:1 Mentoring": one session or a programme, decided by the count (the website's `MentoringComposer`).
  Future<void> _addMentoring(BuildContext context) async {
    if (!_openOrSay(context)) return;
    final saved = await openMentoringComposer(
      context,
      controller: _c,
      pickFile: widget.pickFile,
      onOpenSettings: widget.onOpenSettings,
    );
    if (saved && context.mounted) showMessage(context, 'Added.');
  }

  Future<void> _editService(BuildContext context, OfferedService s, {bool activate = false}) async {
    if (s.kind == ServiceKind.oneOnOne) {
      final saved = await openMentoringComposer(
        context,
        controller: _c,
        pickFile: widget.pickFile,
        service: s,
        onOpenSettings: widget.onOpenSettings,
      );
      if (saved && context.mounted) showMessage(context, 'Saved.');
      return;
    }
    final saved = await showFormSheet(
      context,
      (_) => ServiceForm(controller: _c, pickFile: widget.pickFile, existing: s, activate: activate),
    );
    if (saved && context.mounted) showMessage(context, 'Saved.');
  }

  /// A service or plan cannot be listed while the storefront is closed: say why, in the API's words, without a request.
  bool _openOrSay(BuildContext context) {
    final g = _c.gates;
    if (g == null || g.live) return true;
    showMessage(context, g.blockedReason ?? 'Your storefront is not open.');
    return false;
  }

  // --- plans ---------------------------------------------------------------------------------

  List<Widget> _plansSections(BuildContext context) {
    final l = _c.plans;
    if (!l.loaded && l.loading) return const [_Loading()];
    if (!l.loaded && l.error != null) {
      return [_SectionError(title: 'Unable to Load Your Plans', error: l.error!, onRetry: l.load)];
    }
    return [
      _SectionHead(
        title: 'Ongoing Plans',
        count: _c.ongoing.length,
        description: 'A set number of sessions a month for a term, booked as needed.',
        action: 'Create a Plan',
        actionKey: 'add-plan',
        onAction: () => _addPlan(context),
      ),
      if (_c.ongoing.isEmpty)
        const _Hint(
          'No Ongoing Plans Yet',
          body: 'For example, offer 2 sessions a month for 3 months. Plans do not count toward your listing limit.',
        ),
      for (final p in _c.ongoing) _planRow(context, p),
    ];
  }

  Widget _planRow(BuildContext context, OfferedPlan p) => PlanRow(
    plan: p,
    onEdit: () => _editPlan(context, p),
    onToggle: () async {
      final refusal = await _c.setPlanActive(p, !p.active);
      if (context.mounted) {
        showMessage(context, refusal ?? (p.active ? 'Paused. Members no longer see it.' : 'Live on your storefront.'));
      }
    },
    onDelete: () => _confirmDelete(context, p.title, () => _c.deletePlan(p)),
  );

  /// "Create a Plan": an ongoing plan (the website's `PlanFormDialog`).
  Future<void> _addPlan(BuildContext context) async {
    if (!_openOrSay(context)) return;
    final saved = await openOngoingPlanForm(context, controller: _c, pickFile: widget.pickFile);
    if (saved && context.mounted) showMessage(context, 'Added.');
  }

  /// A programme is 1:1 mentoring of several sessions, edited in the composer; an ongoing plan in its own form.
  Future<void> _editPlan(BuildContext context, OfferedPlan p) async {
    final Future<bool> opened;
    if (p.programme) {
      opened = openMentoringComposer(
        context,
        controller: _c,
        pickFile: widget.pickFile,
        plan: p,
        onOpenSettings: widget.onOpenSettings,
      );
    } else {
      opened = openOngoingPlanForm(context, controller: _c, pickFile: widget.pickFile, existing: p);
    }
    if (await opened && context.mounted) showMessage(context, 'Saved.');
  }

  // --- group sessions --------------------------------------------------------------------------

  List<Widget> _sessionsSection(BuildContext context) {
    final l = _c.sessions;
    final rows = l.data ?? const <HostedSession>[];
    return [
      _SectionHead(
        top: 8,
        title: 'Group Sessions',
        count: rows.length,
        description: 'Clinics and multi-day series you host for several mentees at once.',
        action: 'Host a Group Session',
        actionKey: 'add-group',
        onAction: () async {
          final saved = await openGroupComposer(context, controller: _c, pickFile: widget.pickFile);
          if (saved && context.mounted) showMessage(context, 'Saved.');
        },
      ),
      if (!l.loaded && l.loading) const _Loading(),
      if (!l.loaded && l.error != null)
        _SectionError(title: 'Unable to Load Your Group Sessions', error: l.error!, onRetry: l.load),
      if (l.loaded && rows.isEmpty)
        const _Hint('No group sessions yet. Host a single clinic or a multi-day series, free or paid.'),
      for (final s in rows)
        SessionRow(
          session: s,
          onOpen: () => showSessionSheet(context, _c, s),
          onPublish: () async {
            final refusal = await _c.publishSession(s);
            if (context.mounted) showMessage(context, refusal ?? 'Published. Members can register.');
          },
        ),
    ];
  }

  Future<void> _confirmDelete(BuildContext context, String title, Future<String?> Function() delete) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Delete "$title"?'),
        content: const Text('It is removed from your storefront. Members who already bought it keep their purchase.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Keep It')),
          TextButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final refusal = await delete();
    if (context.mounted) showMessage(context, refusal ?? 'Deleted.');
  }
}

/// What must be true before anything sells, as the API reports it: the lines,
/// its own sentence for what is missing, and (only when the seller terms are the
/// one thing missing) the button that accepts them.
class GatesCard extends StatelessWidget {
  const GatesCard({
    super.key,
    required this.gates,
    required this.listings,
    required this.onAccept,
    required this.onReadTerms,
  });

  final StorefrontGates gates;
  final int listings;
  final VoidCallback onAccept;
  final VoidCallback onReadTerms;

  @override
  Widget build(BuildContext context) {
    final g = gates;
    // No "Storefront" card, checklist or listing count (owner, 9 Nov 2026: "Store front has to be completely
    // removed"): only the API's sentence for what still stops the mentor selling, and the terms to accept.
    if (g.live || (g.blockedReason == null && !g.termsAreTheBlocker)) return const SizedBox.shrink();
    return Padding(
      key: const ValueKey('gates'),
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (g.blockedReason != null)
            Callout(key: const ValueKey('gate-reason'), tone: PillTone.amber, text: g.blockedReason!),
          if (g.termsAreTheBlocker)
            ActionWrap(
              children: [
                SolidButton(
                  key: const ValueKey('accept-terms'),
                  label: 'Accept Seller Terms (${g.termsCurrentVersion})',
                  icon: LucideIcons.fileCheck,
                  onPressed: onAccept,
                ),
                QuietButton(label: 'Read the Terms', onPressed: onReadTerms),
              ],
            ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 36),
    child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))),
  );
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.title, required this.error, required this.onRetry});

  final String title;
  final String error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => EmptyNote(
    icon: LucideIcons.cloudOff,
    compact: true,
    title: title,
    body: error,
    action: 'Try Again',
    onAction: onRetry,
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text, {this.body});

  /// The sentence, or the heading when there is a [body] under it.
  final String text;
  final String? body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: body == null
        ? Text(text, style: MentoringText.body)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: MentoringText.bodyStrong),
              const SizedBox(height: 2),
              Text(body!, style: MentoringText.body),
            ],
          ),
  );
}

/// A section of the tab, as the website's offerings workspace draws it: the title with how many it holds, the line
/// that says what it is, and its add button.
class _SectionHead extends StatelessWidget {
  const _SectionHead({
    required this.title,
    required this.count,
    required this.description,
    required this.action,
    required this.actionKey,
    required this.onAction,
    this.top = 18,
  });

  final String title;
  final int count;
  final String description;
  final String action;
  final String actionKey;
  final VoidCallback onAction;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(child: Text(title, style: MentoringText.section)),
              const SizedBox(width: 8),
              Container(
                key: ValueKey('$actionKey-count'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(999)),
                child: Text('$count', style: MentoringText.bodyStrong),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(description, style: MentoringText.body),
          ActionWrap(
            top: 8,
            children: [
              QuietButton(key: ValueKey(actionKey), label: action, icon: LucideIcons.plus, onPressed: onAction),
            ],
          ),
        ],
      ),
    );
  }
}
