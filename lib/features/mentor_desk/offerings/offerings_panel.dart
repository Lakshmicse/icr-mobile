import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/util/links.dart';
import '../../mentorship_my/mentoring_links.dart';
import '../../mentorship_my/widgets/forms.dart';
import '../../mentorship_my/widgets/kit.dart';
import 'group_form.dart';
import 'offering_rows.dart';
import 'offerings_controller.dart';
import 'offerings_files.dart';
import 'offerings_models.dart';
import 'offerings_repository.dart';
import 'offerings_rules.dart';
import 'plan_form.dart';
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
  });

  final ApiClient api;
  final MentorshipLinks links;
  final VoidCallback? onChanged;

  /// The phone's file chooser; a test stands in for it.
  final OfferingFilePicker pickFile;

  @override
  State<OfferingsPanel> createState() => _OfferingsPanelState();
}

class _OfferingsPanelState extends State<OfferingsPanel> {
  late final OfferingsController _c;

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
              ..._storefrontSections(context),
              ..._plansSections(context),
              ..._sessionsSection(context),
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
      return _SectionError(title: "Couldn't load your storefront", error: l.error!, onRetry: l.load);
    }
    final g = _c.gates;
    if (g == null) return const SizedBox.shrink();
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
          title: Text('Seller terms ${g.termsCurrentVersion}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ICR collects payment and settles your earnings monthly by bank transfer. A platform fee is taken on each sale; '
                'the Earnings tab shows the figures. If a paid session is cancelled, the member is refunded. '
                'The mentor code of conduct applies to paid work in the same way as to free mentoring.',
                style: MentoringText.body,
              ),
              const SizedBox(height: 8),
              InkWell(
                key: const ValueKey('read-terms'),
                onTap: () => widget.links.openSite(context, '/terms'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text('Read the full terms', style: MentoringText.buttonQuiet),
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
            TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Not now')),
            TextButton(
              onPressed: read ? () => Navigator.pop(dialog, true) : null,
              child: const Text('Accept and open'),
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

  List<Widget> _storefrontSections(BuildContext context) {
    final l = _c.storefront;
    if (!l.loaded) return const [];
    final live = _c.gates?.live ?? false;
    final older = [..._c.legacySeats, ..._c.retired.where((r) => r.kind != ServiceKind.groupSeat)];
    return [
      const SectionTitle(title: '1:1 mentoring', top: 18),
      ActionWrap(
        top: 0,
        children: [
          QuietButton(
            key: const ValueKey('add-session'),
            label: 'Add a 1:1 session',
            icon: LucideIcons.plus,
            onPressed: () => _addService(context, ServiceKind.oneOnOne),
          ),
          QuietButton(
            key: const ValueKey('add-programme'),
            label: 'Add a programme',
            icon: LucideIcons.plus,
            onPressed: () => _addPlan(context, programme: true),
          ),
        ],
      ),
      const SizedBox(height: 10),
      if (_c.singles.isEmpty && _c.programmes.isEmpty)
        _Hint(
          live
              ? 'Nothing listed yet. A session is booked in one go; a programme is a fixed run of sessions.'
              : 'Open your storefront to list 1:1 mentoring.',
        ),
      for (final s in _c.singles) _serviceRow(context, s),
      for (final p in _c.programmes) _planRow(context, p),
      const SectionTitle(title: 'Resources'),
      ActionWrap(
        top: 0,
        children: [
          QuietButton(
            key: const ValueKey('add-resource'),
            label: 'Add a resource',
            icon: LucideIcons.plus,
            onPressed: () => _addService(context, ServiceKind.resource),
          ),
        ],
      ),
      const SizedBox(height: 10),
      if (_c.resources.isEmpty) const _Hint('No resources. A guide or a template, paid or free as a lead magnet.'),
      for (final s in _c.resources) _serviceRow(context, s),
      if (older.isNotEmpty) ...[
        const SectionTitle(title: 'Older listings'),
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

  Future<void> _editService(BuildContext context, OfferedService s, {bool activate = false}) async {
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
      return [_SectionError(title: "Couldn't load your plans", error: l.error!, onRetry: l.load)];
    }
    return [
      const SectionTitle(title: 'Ongoing plans'),
      ActionWrap(
        top: 0,
        children: [
          QuietButton(
            key: const ValueKey('add-plan'),
            label: 'Add an ongoing plan',
            icon: LucideIcons.plus,
            onPressed: () => _addPlan(context, programme: false),
          ),
        ],
      ),
      const SizedBox(height: 10),
      if (_c.ongoing.isEmpty) const _Hint('No ongoing plans. A prepaid term with sessions every month.'),
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

  Future<void> _addPlan(BuildContext context, {required bool programme}) async {
    if (!_openOrSay(context)) return;
    final saved = await showFormSheet(
      context,
      (_) => PlanForm(controller: _c, pickFile: widget.pickFile, programme: programme),
    );
    if (saved && context.mounted) showMessage(context, 'Added.');
  }

  Future<void> _editPlan(BuildContext context, OfferedPlan p) async {
    final saved = await showFormSheet(context, (_) => PlanForm(controller: _c, pickFile: widget.pickFile, existing: p));
    if (saved && context.mounted) showMessage(context, 'Saved.');
  }

  // --- group sessions --------------------------------------------------------------------------

  List<Widget> _sessionsSection(BuildContext context) {
    final l = _c.sessions;
    final rows = l.data ?? const <HostedSession>[];
    return [
      const SectionTitle(title: 'Group sessions'),
      ActionWrap(
        top: 0,
        children: [
          QuietButton(
            key: const ValueKey('add-group'),
            label: 'Host a group session',
            icon: LucideIcons.plus,
            onPressed: () async {
              final saved = await showFormSheet(context, (_) => GroupSessionForm(controller: _c));
              if (saved && context.mounted) showMessage(context, 'Saved.');
            },
          ),
        ],
      ),
      const SizedBox(height: 10),
      if (!l.loaded && l.loading) const _Loading(),
      if (!l.loaded && l.error != null)
        _SectionError(title: "Couldn't load your group sessions", error: l.error!, onRetry: l.load),
      if (l.loaded && rows.isEmpty)
        const _Hint('No group sessions yet. A clinic is an hour with a room of members; free ones keep a waitlist.'),
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
        content: const Text('It comes off your storefront. Members who already bought it keep what they bought.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Keep it')),
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
    return MentoringCard(
      key: const ValueKey('gates'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Storefront', style: MentoringText.cardTitle)),
              StatusPill(g.live ? 'Live' : 'Not open', tone: g.live ? PillTone.mint : PillTone.amber),
            ],
          ),
          const SizedBox(height: 8),
          _line('Not suspended', !g.suspended),
          _line('Paid selling switched on', g.optedIn),
          _line(
            g.termsCurrentVersion.isEmpty ? 'Seller terms accepted' : 'Seller terms ${g.termsCurrentVersion} accepted',
            g.termsCurrent,
          ),
          if (!g.live && g.blockedReason != null)
            Callout(key: const ValueKey('gate-reason'), tone: PillTone.amber, text: g.blockedReason!),
          if (g.termsAreTheBlocker)
            ActionWrap(
              children: [
                SolidButton(
                  key: const ValueKey('accept-terms'),
                  label: 'Accept seller terms (${g.termsCurrentVersion})',
                  icon: LucideIcons.fileCheck,
                  onPressed: onAccept,
                ),
                QuietButton(label: 'Read the terms', onPressed: onReadTerms),
              ],
            ),
          MetaLine(icon: LucideIcons.layers, text: '$listings of $maxServices service listings used'),
        ],
      ),
    );
  }

  Widget _line(String text, bool ok) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Icon(
          ok ? LucideIcons.circleCheck : LucideIcons.circle,
          size: 16,
          color: ok ? MentoringColors.green : AppColors.outline,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: ok ? MentoringText.bodyStrong : MentoringText.body)),
      ],
    ),
  );
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
    action: 'Try again',
    onAction: onRetry,
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: MentoringText.body),
  );
}
