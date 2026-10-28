import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart' show showMessage;
import 'rfq_detail_controller.dart';
import 'rfq_format.dart';
import 'rfq_links.dart';
import 'rfq_models.dart';
import 'rfq_navigation.dart';
import 'rfq_repository.dart';
import 'rfq_scope.dart';
import 'rfq_styles.dart';
import 'widgets/owner_parts.dart';
import 'widgets/requirement_parts.dart';
import 'widgets/rfq_widgets.dart';
import 'widgets/supplier_parts.dart' show RfqSmallButton;
import 'widgets/supplier_picker.dart';

/// The parts of the owner's page, each a pill under the header.
enum OwnerTab {
  responses('Responses'),
  suppliers('Suppliers'),
  messages('Messages'),
  brief('What you posted');

  const OwnerTab(this.label);
  final String label;
}

/// A requirement as its owner runs it: where it stands, the bids (or a staged RFQ's pre-qualification responses),
/// the suppliers invited and the threads with them, and every decision the owner takes: publish, edit, close,
/// cancel, delete a draft, move a staged RFQ on, shortlist, decline, award or select, qualify, invite, message.
///
/// A notification opens it on what it was about: [section] (`prequal`, `invited`) and [focusBidId] (that bid is
/// ringed and brought into view).
class RfqDetailScreen extends StatefulWidget {
  const RfqDetailScreen(
    this.rfqId, {
    super.key,
    this.section,
    this.focusBidId,
    this.repository,
    this.links,
    this.onBack,
    this.onBell,
    this.onOpenConversation,
    this.onOpenSupplier,
    this.onCreateCompany,
  });

  final String rfqId;
  final String? section;
  final String? focusBidId;

  final RfqRepository? repository;
  final RfqLinks? links;
  final VoidCallback? onBack;
  final VoidCallback? onBell;

  /// Opens the app's chat on a thread (the lead's); by default the website's inbox on it.
  final ValueChanged<String>? onOpenConversation;

  /// Opens a supplier's profile (the lead's); by default the website's page.
  final ValueChanged<String>? onOpenSupplier;
  final VoidCallback? onCreateCompany;

  @override
  State<RfqDetailScreen> createState() => _RfqDetailScreenState();
}

class _RfqDetailScreenState extends State<RfqDetailScreen> {
  late final RfqHooks _hooks;
  late final RfqDetailController _c;
  late OwnerTab _tab;
  final _bidKeys = <String, GlobalKey>{};
  final _prequalKey = GlobalKey(debugLabel: 'prequal');
  final _messaging = <String>{};
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _hooks = RfqHooks(
      repository: widget.repository ?? rfqRepositoryOf(context),
      links: widget.links ?? const SystemRfqLinks(),
      onOpenConversation: widget.onOpenConversation,
      onOpenSupplier: widget.onOpenSupplier,
      onCreateCompany: widget.onCreateCompany,
    );
    _tab = widget.section == 'invited' ? OwnerTab.suppliers : OwnerTab.responses;
    _c = RfqDetailController(repository: _hooks.repository, rfqId: widget.rfqId)..addListener(_focusWhenLoaded);
    _c.start();
  }

  @override
  void dispose() {
    _c.removeListener(_focusWhenLoaded);
    _c.dispose();
    super.dispose();
  }

  GlobalKey _keyOfBid(String id) => _bidKeys.putIfAbsent(id, () => GlobalKey(debugLabel: 'bid-$id'));

  /// Brings the bid or the section a notification named into view, once, when the page has loaded.
  void _focusWhenLoaded() {
    if (_focused || _c.rfq == null || _c.loading) return;
    final target = widget.focusBidId != null && _c.bids.any((b) => b.id == widget.focusBidId)
        ? _keyOfBid(widget.focusBidId!)
        : (widget.section == 'prequal' ? _prequalKey : null);
    _focused = true;
    if (target == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = target.currentContext;
      if (ctx != null && mounted) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250), alignment: 0.05);
    });
  }

  Future<void> _say(Future<String?> action) async {
    final message = await action;
    if (message != null && mounted) showMessage(context, message);
  }

  String _nameOf(String key) => _hooks.repository.categoryName(key) ?? prettyKey(key);

  // ---- The requirement ---------------------------------------------------------------------------------

  Future<void> _edit() async {
    final saved = await pushComposer(context, _hooks, editId: widget.rfqId);
    if (saved != null && mounted) await _c.refresh();
  }

  Future<void> _similar() async {
    final posted = await pushComposer(context, _hooks, copyFromId: widget.rfqId);
    if (posted != null && mounted) showMessage(context, 'Your new requirement is in My RFQ\'s.');
  }

  Future<void> _close() async {
    final enquiry = _c.rfq?.isEnquiry ?? false;
    final ok = await confirmMove(
      context,
      title: enquiry ? 'Close this enquiry?' : 'Close this requirement?',
      body: 'Suppliers can no longer reply. The responses you have stay here.',
      confirm: 'Close it',
    );
    if (ok) await _say(_c.act(RfqAction.close));
  }

  Future<void> _cancel() async {
    final ok = await confirmMove(
      context,
      title: 'Cancel this requirement?',
      body: 'It is taken off the board and suppliers can no longer reply. This can’t be undone.',
      confirm: 'Cancel requirement',
      destructive: true,
    );
    if (ok) await _say(_c.act(RfqAction.cancel));
  }

  Future<void> _delete() async {
    final ok = await confirmMove(
      context,
      title: 'Delete this draft?',
      body: 'Only your team has seen it. It is deleted for good.',
      confirm: 'Delete draft',
      destructive: true,
    );
    if (!ok) return;
    final message = await _c.deleteDraft();
    if (!mounted) return;
    if (message != null) {
      showMessage(context, message);
    } else {
      Navigator.of(context).pop();
    }
  }

  // ---- Bids -----------------------------------------------------------------------------------------------

  Future<void> _award(Bid bid) async {
    final enquiry = _c.rfq?.isEnquiry ?? false;
    final name = bid.supplier.name;
    final ok = await confirmMove(
      context,
      title: enquiry ? 'Select $name?' : 'Award to $name?',
      body: enquiry
          ? 'This closes the enquiry with $name as your chosen supplier and tells the others. Take it forward in messages. This can’t be undone.'
          : 'This awards the requirement to $name, generates a purchase order, and declines all other bids. This can’t be undone.',
      confirm: enquiry ? 'Confirm selection' : 'Confirm award',
    );
    if (!ok || !mounted) return;
    final result = await _c.award(bid);
    if (mounted && result.message.isNotEmpty) showMessage(context, result.message);
  }

  Future<void> _messageSupplier({String? conversationId, String? companyId, required String key}) async {
    if (_messaging.contains(key)) return;
    setState(() => _messaging.add(key));
    final result = await _c.conversationWith(conversationId: conversationId, supplierCompanyId: companyId);
    if (!mounted) return;
    setState(() => _messaging.remove(key));
    final id = result.id;
    if (id == null) {
      showMessage(context, result.error ?? "Couldn't open the conversation.");
      return;
    }
    await _hooks.openConversation(context, id);
    if (mounted) await _c.refresh();
  }

  Future<void> _openFile(RfqFile f, {required bool private}) async {
    if (!private) {
      final url = AppConfig.absoluteUrl(f.url);
      if (url == null) return;
      await _hooks.links.openUri(context, Uri.parse(url));
      return;
    }
    try {
      final path = await _hooks.repository.saveFile(f);
      final taken = await _hooks.links.shareFile(path, f.name ?? f.title);
      if (!taken && mounted) showMessage(context, 'Nothing on this phone could open ${f.name ?? f.title}.');
    } catch (e) {
      if (mounted) showMessage(context, "Couldn't fetch ${f.name ?? f.title}. Try again.");
    }
  }

  Future<void> _sort() async {
    final picked = await pickOne<BidSort>(
      context,
      title: 'Sort bids by',
      options: BidSort.values,
      labelOf: (s) => s.label,
      selected: _c.sort,
    );
    if (picked?.value != null) _c.setSort(picked!.value!);
  }

  Future<void> _compare() {
    final live = _c.sortedBids.where((b) => b.status != BidStatus.rejected).toList();
    return showCompareSheet(
      context,
      bids: live,
      enquiry: _c.rfq?.isEnquiry ?? false,
      onOpenBid: (b) {
        setState(() => _tab = OwnerTab.responses);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = _keyOfBid(b.id).currentContext;
          if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250), alignment: 0.05);
        });
      },
    );
  }

  // ---- Suppliers ------------------------------------------------------------------------------------------

  Future<void> _invite() {
    final already = {for (final i in _c.invites) i.supplier.vendorId};
    return showSupplierPicker(
      context,
      title: 'Invite companies',
      confirmLabel: 'Invite',
      search: _c.findSuppliers,
      suggested: _c.suggested,
      excluded: already,
      onConfirm: (chosen) async {
        final error = await _c.invite([for (final s in chosen) s.vendorId]);
        if (error == null && mounted) showMessage(context, 'Invitations sent.');
        return error;
      },
    );
  }

  // ---- The page ---------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) => RfqScaffold(
        title: 'Requirement',
        onBack: widget.onBack ?? () => Navigator.maybePop(context),
        unread: _c.unread,
        onBell: widget.onBell ?? () => pushAlerts(context, _hooks),
        body: _body(),
      ),
    );
  }

  Widget _body() {
    final rfq = _c.rfq;
    if (_c.loading && rfq == null) return const RfqSpinner();
    if (rfq == null) {
      return RfqNotice(
        icon: LucideIcons.cloudOff,
        title: "Couldn't load this requirement",
        body: _c.error,
        action: 'Try again',
        onAction: _c.refresh,
      );
    }
    final now = RfqClock.now();
    final enquiry = rfq.isEnquiry;
    final owner = _c.notOwner == null;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _c.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          RequirementHeader(rfq: rfq, nameOf: _nameOf, now: now),
          if (owner) ...[
            _manage(rfq),
            if (rfq.staged)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: TenderStageCard(
                  rfq: rfq,
                  busy: _c.acting,
                  onAdvance: rfq.stage?.next == null ? null : () => _say(_c.advanceStage()),
                ),
              ),
            const SizedBox(height: 14),
            _tabs(rfq),
            const SizedBox(height: 4),
            ..._tabBody(rfq, enquiry: enquiry, now: now),
          ] else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: RfqBanner(_c.notOwner!, tone: Tone.amber, icon: LucideIcons.lock),
            ),
            ..._briefSection(rfq, owner: false),
          ],
        ],
      ),
    );
  }

  // ---- Manage -------------------------------------------------------------------------------------------------

  Widget _manage(Requirement rfq) {
    final enquiry = rfq.isEnquiry;
    final help = rfq.expiredEnquiry
        ? 'This enquiry closed on its reply-by date, so suppliers can no longer reply. You can still select one of the replies.'
        : switch (rfq.status) {
            RfqStatus.draft => 'Only your team can see it. Publish it to reach suppliers.',
            RfqStatus.published => 'Live: suppliers can find it and reply.',
            RfqStatus.awarded => 'Awarded. Close it once the work is under way.',
            RfqStatus.closed => 'Closed: suppliers can no longer reply.',
            RfqStatus.cancelled => 'Cancelled: it is no longer listed.',
          };
    final busy = _c.acting;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: RfqCard(
        key: const ValueKey('manage-card'),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Manage this ${enquiry ? 'enquiry' : 'requirement'}', style: RfqText.section.copyWith(fontSize: 14)),
            const SizedBox(height: 4),
            Text(help, key: const ValueKey('manage-help'), style: RfqText.small),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (rfq.status == RfqStatus.draft)
                  RfqSmallButton(
                    key: const ValueKey('act-publish'),
                    label: 'Publish',
                    icon: LucideIcons.send,
                    filled: true,
                    onTap: busy ? null : () => _say(_c.act(RfqAction.publish)),
                  ),
                if (rfq.status == RfqStatus.draft || rfq.status == RfqStatus.published)
                  RfqSmallButton(
                    key: const ValueKey('act-edit'),
                    label: 'Edit',
                    icon: LucideIcons.pencil,
                    onTap: busy ? null : _edit,
                  ),
                if (rfq.status == RfqStatus.published || rfq.status == RfqStatus.awarded)
                  RfqSmallButton(
                    key: const ValueKey('act-close'),
                    label: 'Close',
                    icon: LucideIcons.lock,
                    onTap: busy ? null : _close,
                  ),
                RfqSmallButton(
                  key: const ValueKey('act-similar'),
                  label: 'Post a similar one',
                  icon: LucideIcons.copy,
                  onTap: busy ? null : _similar,
                ),
                if (rfq.status == RfqStatus.draft || rfq.status == RfqStatus.published)
                  RfqSmallButton(
                    key: const ValueKey('act-cancel'),
                    label: 'Cancel',
                    icon: LucideIcons.ban,
                    danger: true,
                    onTap: busy ? null : _cancel,
                  ),
                if (rfq.status == RfqStatus.draft)
                  RfqSmallButton(
                    key: const ValueKey('act-delete'),
                    label: 'Delete draft',
                    icon: LucideIcons.trash2,
                    danger: true,
                    onTap: busy ? null : _delete,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---- Tabs ---------------------------------------------------------------------------------------------------

  List<OwnerTab> _tabsFor(Requirement rfq) => [
    OwnerTab.responses,
    if (!rfq.staged) OwnerTab.suppliers,
    OwnerTab.messages,
    OwnerTab.brief,
  ];

  Widget _tabs(Requirement rfq) {
    final tabs = _tabsFor(rfq);
    final enquiry = rfq.isEnquiry;
    if (!tabs.contains(_tab)) _tab = tabs.first;
    return PillTabs<OwnerTab>(
      values: tabs,
      selected: _tab,
      labelOf: (t) => switch (t) {
        OwnerTab.responses => rfq.staged ? 'Responses' : (enquiry ? 'Replies' : 'Bids'),
        _ => t.label,
      },
      countOf: (t) => switch (t) {
        OwnerTab.responses => rfq.staged ? _c.responses.length + _c.bids.length : _c.bids.length,
        OwnerTab.suppliers => _c.invites.length,
        OwnerTab.messages => _c.threads.length,
        OwnerTab.brief => null,
      },
      onSelect: (t) => setState(() => _tab = t),
    );
  }

  List<Widget> _tabBody(Requirement rfq, {required bool enquiry, required DateTime now}) => switch (_tab) {
    OwnerTab.responses => _responses(rfq, enquiry: enquiry, now: now),
    OwnerTab.suppliers => _suppliers(rfq),
    OwnerTab.messages => _messages(rfq, now: now),
    OwnerTab.brief => _briefSection(rfq, owner: true),
  };

  // ---- Responses -------------------------------------------------------------------------------------------------

  List<Widget> _responses(Requirement rfq, {required bool enquiry, required DateTime now}) {
    final out = <Widget>[];
    final showBids = !rfq.staged || _c.quotesOpen || rfq.status == RfqStatus.awarded || _c.bids.isNotEmpty;
    if (showBids) out.addAll(_bids(rfq, enquiry: enquiry, now: now));
    if (rfq.staged) out.addAll(_prequal(rfq, now: now));
    return out;
  }

  List<Widget> _bids(Requirement rfq, {required bool enquiry, required DateTime now}) {
    final bids = _c.sortedBids;
    final live = bids.where((b) => b.status != BidStatus.rejected).toList();
    final priced = [for (final b in live) if (b.amount != null) b.amount!];
    final best = priced.length > 1 ? priced.reduce((a, b) => a < b ? a : b) : null;
    final topRating = live.length > 1 ? live.map((b) => b.supplier.rating).fold<double>(0, (a, b) => a > b ? a : b) : null;
    return [
      RfqSectionTitle(
        enquiry ? 'Replies (${bids.length})' : 'Bids (${bids.length})',
        trailing: bids.length > 1
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (live.length > 1)
                    TextButton.icon(
                      key: const ValueKey('compare'),
                      onPressed: _compare,
                      icon: const Icon(LucideIcons.columns3, size: 15),
                      label: Text('Compare', style: RfqText.link),
                    ),
                  TextButton.icon(
                    key: const ValueKey('bids-sort'),
                    onPressed: _sort,
                    icon: const Icon(LucideIcons.arrowDownUp, size: 14),
                    label: Text(_c.sort.label, style: RfqText.link),
                  ),
                ],
              )
            : null,
      ),
      if (bids.isEmpty)
        RfqNotice(
          icon: LucideIcons.inbox,
          title: enquiry ? 'No replies yet' : 'No bids yet',
          body: enquiry ? 'Suppliers who reply to your enquiry appear here.' : 'Companies will appear here as they bid.',
        )
      else
        for (final b in bids)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: KeyedSubtree(
              key: _keyOfBid(b.id),
              child: BidResponseCard(
                key: ValueKey('bid-card-${b.id}'),
                bid: b,
                enquiry: enquiry,
                canAct: _c.canAward,
                best: best != null && b.amount == best && b.status != BidStatus.rejected,
                topRated: topRating != null && topRating > 0 && b.supplier.rating == topRating && b.status != BidStatus.rejected,
                focused: b.id == widget.focusBidId,
                busy: _c.isBusy(b.id),
                messaging: _messaging.contains('bid-${b.id}'),
                now: now,
                onMessage: () => _messageSupplier(conversationId: b.conversationId, companyId: b.supplier.companyId, key: 'bid-${b.id}'),
                onShortlist: () => _say(_c.triage(b, BidStatus.shortlisted)),
                onRestore: () => _say(_c.triage(b, BidStatus.pending)),
                onDecline: () => _say(_c.triage(b, BidStatus.rejected)),
                onAward: () => _award(b),
                onOpenFile: (f) => _openFile(f, private: true),
                onOpenSupplier: () => _hooks.openSupplier(context, b.supplier.vendorId),
              ),
            ),
          ),
    ];
  }

  List<Widget> _prequal(Requirement rfq, {required DateTime now}) {
    final responses = _c.responses;
    return [
      KeyedSubtree(key: _prequalKey, child: RfqSectionTitle('Pre-qualification responses (${responses.length})')),
      if (responses.isEmpty)
        const RfqNotice(
          icon: LucideIcons.clipboardCheck,
          title: 'No responses yet',
          body: 'Suppliers who submit a pre-qualification response will appear here.',
        )
      else
        for (final r in responses)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: PreQualCard(
              response: r,
              busy: _c.isBusy(r.supplier.vendorId),
              canAct: rfq.live,
              canShortlist: rfq.stage == RfqStage.shortlisting,
              messaging: _messaging.contains('pq-${r.supplier.vendorId}'),
              now: now,
              onMessage: () => _messageSupplier(companyId: r.supplier.companyId, key: 'pq-${r.supplier.vendorId}'),
              onQualify: () => _say(_c.screen(r, PreQualStatus.qualified)),
              onReject: () => _say(_c.screen(r, PreQualStatus.rejected)),
              onShortlist: () => _say(_c.shortlist(r)),
            ),
          ),
    ];
  }

  // ---- Suppliers and messages ------------------------------------------------------------------------------------

  List<Widget> _suppliers(Requirement rfq) {
    final canInvite = rfq.status == RfqStatus.draft || rfq.status == RfqStatus.published;
    return [
      RfqSectionTitle('Invited companies (${_c.invites.length})'),
      if (_c.invites.isEmpty)
        const RfqNotice(
          icon: LucideIcons.userPlus,
          title: 'No one invited yet',
          body: 'Matched suppliers are alerted when it goes live. Invite more by name below.',
        )
      else
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              for (final i in _c.invites)
                InvitedRow(
                  invite: i,
                  messaging: _messaging.contains('inv-${i.supplier.vendorId}'),
                  onMessage: () => _messageSupplier(companyId: i.supplier.companyId, key: 'inv-${i.supplier.vendorId}'),
                ),
            ],
          ),
        ),
      if (canInvite)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('invite-open'),
              onPressed: _invite,
              icon: const Icon(LucideIcons.userPlus, size: 16),
              label: const Text('Invite companies'),
            ),
          ),
        ),
    ];
  }

  List<Widget> _messages(Requirement rfq, {required DateTime now}) {
    final threads = _c.threads;
    return [
      RfqSectionTitle(threads.isEmpty ? 'Supplier messages' : 'Supplier messages (${threads.length})'),
      if (threads.isEmpty)
        const RfqNotice(
          icon: LucideIcons.messageSquare,
          title: 'No messages yet',
          body: 'Suppliers who message you about this requirement appear here.',
        )
      else
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              for (final t in threads)
                ThreadRow(
                  thread: t,
                  now: now,
                  onOpen: () async {
                    await _hooks.openConversation(context, t.conversationId);
                    if (mounted) await _c.refresh();
                  },
                ),
            ],
          ),
        ),
    ];
  }

  List<Widget> _briefSection(Requirement rfq, {required bool owner}) => [
    if (owner) RfqSectionTitle('What you posted'),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: RequirementBrief(
        rfq: rfq,
        nameOf: _nameOf,
        showContact: owner,
        onOpenFile: (f) => _openFile(f, private: false),
      ),
    ),
  ];
}
