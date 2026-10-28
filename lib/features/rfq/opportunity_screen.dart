import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart' show showMessage;
import '../../core/widgets/buttons.dart';
import 'rfq_format.dart';
import 'rfq_links.dart';
import 'rfq_models.dart';
import 'rfq_navigation.dart';
import 'rfq_repository.dart';
import 'rfq_rules.dart';
import 'rfq_scope.dart';
import 'rfq_styles.dart';
import 'rfq_uploads.dart';
import 'supplier_controllers.dart';
import 'widgets/owner_parts.dart' show TenderStageCard;
import 'widgets/requirement_parts.dart';
import 'widgets/response_parts.dart';
import 'widgets/rfq_widgets.dart';
import 'widgets/supplier_parts.dart' show SupplierGateView;

/// A requirement as a supplier reads it: who is buying, how well it fits, the brief, and the one card that says
/// what they can do now (reply or quote, answer pre-qualification, wait, read back what they sent, change or
/// withdraw it where the API allows, decline an invitation). Each state is the one the API would enforce: no form
/// is offered that it would refuse, and what it refuses anyway (a used-up plan, an unverified listing) is shown in
/// its own words with the form kept as typed.
class OpportunityScreen extends StatefulWidget {
  const OpportunityScreen(
    this.rfqId, {
    super.key,
    this.section,
    this.repository,
    this.links,
    this.onBack,
    this.onBell,
    this.onOpenConversation,
    this.onOpenSupplier,
    this.onSeePlans,
  });

  final String rfqId;

  /// `response` lands on the reply form ("Detailed quotes are open" opens it there).
  final String? section;

  final RfqRepository? repository;
  final RfqLinks? links;
  final VoidCallback? onBack;
  final VoidCallback? onBell;

  /// Opens the app's chat on a thread (the lead's); by default the website's inbox on it.
  final ValueChanged<String>? onOpenConversation;
  final ValueChanged<String>? onOpenSupplier;

  /// Opens the supplier plans (the lead's): offered with a plan refusal. By default the website's pricing page.
  final VoidCallback? onSeePlans;

  @override
  State<OpportunityScreen> createState() => _OpportunityScreenState();
}

class _OpportunityScreenState extends State<OpportunityScreen> {
  late final RfqHooks _hooks;
  late final OpportunityController _c;
  late AttachmentUploader _uploader;
  final _responseKey = GlobalKey(debugLabel: 'response');
  bool _editing = false;
  bool _justSent = false;
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    _hooks = RfqHooks(
      repository: widget.repository ?? rfqRepositoryOf(context),
      links: widget.links ?? const SystemRfqLinks(),
      onOpenConversation: widget.onOpenConversation,
      onOpenSupplier: widget.onOpenSupplier,
      onSeePlans: widget.onSeePlans,
    );
    _uploader = AttachmentUploader(repository: _hooks.repository, purpose: 'bid-attachment');
    _c = OpportunityController(repository: _hooks.repository, rfqId: widget.rfqId)..addListener(_landOnResponse);
    _c.start();
  }

  @override
  void dispose() {
    _c.removeListener(_landOnResponse);
    _c.dispose();
    _uploader.dispose();
    super.dispose();
  }

  void _landOnResponse() {
    if (_scrolled || _c.rfq == null || _c.loading) return;
    _scrolled = true;
    if (widget.section != 'response') return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToResponse());
  }

  void _scrollToResponse() {
    final ctx = _responseKey.currentContext;
    if (ctx != null && mounted) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250), alignment: 0.02);
    }
  }

  String _nameOf(String key) => _hooks.repository.categoryName(key) ?? prettyKey(key);

  VoidCallback get _seePlans => _hooks.onSeePlans ?? () => _hooks.openSite(context, '/pricing/supplier');

  // ---- Actions ---------------------------------------------------------------------------------------------

  Future<void> _pickFiles() async {
    final files = await _hooks.links.pickFiles();
    if (files.isNotEmpty) await _uploader.add(files);
  }

  Future<String?> _send(BidDraft draft) async {
    final error = await _c.placeBid(draft);
    if (error == null && mounted) {
      setState(() => _justSent = true);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToResponse());
    }
    return error;
  }

  Future<String?> _saveChanges(BidDraft draft) async {
    final error = await _c.updateBid(draft);
    if (error == null && mounted) {
      setState(() {
        _editing = false;
        _justSent = false;
      });
      showMessage(context, 'Your bid was updated.');
    }
    return error;
  }

  void _startEditing() {
    final bid = _c.myBid;
    if (bid == null) return;
    _uploader.dispose();
    _uploader = AttachmentUploader(repository: _hooks.repository, purpose: 'bid-attachment', initial: bid.files);
    setState(() => _editing = true);
  }

  Future<void> _withdraw() async {
    final enquiry = _c.rfq?.isEnquiry ?? false;
    final ok = await confirmMove(
      context,
      title: enquiry ? 'Withdraw your reply?' : 'Withdraw your quote?',
      body:
          'The buyer will no longer see it, and you can send a new one while the requirement is open.${enquiry ? '' : ' A withdrawn quote does not give back a bid you used this month.'}',
      confirm: 'Withdraw',
      keep: 'Keep it',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final error = await _c.withdrawBid();
    if (!mounted) return;
    if (error != null) {
      showMessage(context, error);
    } else {
      _uploader.dispose();
      _uploader = AttachmentUploader(repository: _hooks.repository, purpose: 'bid-attachment');
      setState(() {
        _editing = false;
        _justSent = false;
      });
      showMessage(context, 'Your bid was withdrawn.');
    }
  }

  Future<void> _decline() async {
    final ok = await confirmMove(
      context,
      title: 'Decline this invitation?',
      body: 'The buyer is told you will not respond.',
      confirm: 'Decline',
      keep: 'Keep it',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final error = await _c.decline();
    if (error != null && mounted) showMessage(context, error);
  }

  Future<String?> _message() async {
    final result = await _c.messageBuyer();
    final id = result.id;
    if (id == null) return result.error ?? "Couldn't open the conversation.";
    if (!mounted) return null;
    await _hooks.openConversation(context, id);
    return null;
  }

  Future<void> _openFile(RfqFile f, {required bool private}) async {
    if (!private) {
      final url = AppConfig.absoluteUrl(f.url);
      if (url != null) await _hooks.links.openUri(context, Uri.parse(url));
      return;
    }
    try {
      final path = await _hooks.repository.saveFile(f);
      final taken = await _hooks.links.shareFile(path, f.name ?? f.title);
      if (!taken && mounted) showMessage(context, 'Nothing on this phone could open ${f.name ?? f.title}.');
    } catch (_) {
      if (mounted) showMessage(context, "Couldn't fetch ${f.name ?? f.title}. Try again.");
    }
  }

  Future<String?> _pickEmployees(String current) async {
    final picked = await pickOne<String>(
      context,
      title: 'Employees',
      options: companySizes,
      labelOf: sizeLabel,
      selected: current.isEmpty ? null : current,
      clearLabel: 'Leave blank',
    );
    return picked == null ? null : (picked.value ?? '');
  }

  Future<void> _startSelling() async {
    final message = await _c.startSellingAndReload();
    if (message != null && mounted) showMessage(context, message);
  }

  // ---- The page --------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) => RfqScaffold(
        title: 'Requirement',
        onBack: widget.onBack ?? () => Navigator.maybePop(context),
        unread: _c.unread,
        onBell: widget.onBell ?? () => pushAlerts(context, _hooks),
        bottomBar: _bar(),
        body: _body(),
      ),
    );
  }

  Widget? _bar() {
    final r = _c.rfq;
    if (r == null || _editing) return null;
    final label = switch (_c.state) {
      ResponseState.form => r.isEnquiry ? 'Reply now' : 'Quote now',
      ResponseState.preQual => 'Respond to the criteria',
      ResponseState.sent => 'View your ${r.isEnquiry ? 'reply' : 'quote'}',
      _ => null,
    };
    if (label == null) return null;
    return BottomActionBar(
      children: [
        Expanded(
          child: PrimaryButton(key: const ValueKey('respond-now'), label: label, onPressed: _scrollToResponse),
        ),
      ],
    );
  }

  Widget _body() {
    final rfq = _c.rfq;
    if (_c.loading && rfq == null) return const RfqSpinner();
    if (rfq == null) {
      return switch (_c.errorStatus) {
        403 => RfqNotice(
          icon: LucideIcons.clock,
          title: 'Not open to your plan yet',
          body: _c.error,
          action: 'See plans',
          onAction: _seePlans,
          secondary: 'Back',
          onSecondary: () => Navigator.maybePop(context),
        ),
        404 => RfqNotice(
          icon: LucideIcons.searchX,
          title: 'This requirement is not available',
          body: 'It may be a draft, a private requirement, or one that no longer exists.',
          action: 'Back',
          onAction: () => Navigator.maybePop(context),
        ),
        _ => RfqNotice(
          icon: LucideIcons.cloudOff,
          title: "Couldn't load this requirement",
          body: _c.error,
          action: 'Try again',
          onAction: _c.refresh,
        ),
      };
    }
    final ctx = _c.context;
    final enquiry = rfq.isEnquiry;
    final state = _c.state;
    final now = RfqClock.now();
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _c.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          if (ctx?.buyer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: BuyerLine(buyer: ctx!.buyer!, size: 40),
            ),
          RequirementHeader(rfq: rfq, nameOf: _nameOf, now: now, showStatus: !rfq.live),
          if (state == ResponseState.own)
            OwnRequirementNotice(onOpenOwner: () => pushRfqDetail(context, _hooks, rfq.id))
          else ...[
            if (rfq.staged)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: TenderStageCard(rfq: rfq, busy: false, owner: false),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: KeyedSubtree(
                key: _responseKey,
                child: _response(rfq, enquiry: enquiry),
              ),
            ),
            if (ctx?.matchScore != null && state != ResponseState.notSupplier)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: MatchCard(score: ctx!.matchScore!, matched: ctx.matched, reasons: ctx.reasons),
              ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: Text('The requirement', style: RfqText.section),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: RequirementBrief(rfq: rfq, nameOf: _nameOf, onOpenFile: (f) => _openFile(f, private: false)),
          ),
          if (state != ResponseState.own &&
              state != ResponseState.notSupplier &&
              (rfq.live || _c.myBid != null || _c.invitedOnly))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ContactBuyerCard(
                contact: _c.contact,
                onMessage: _message,
                onReveal: _c.revealContact,
                onSeePlans: _seePlans,
              ),
            ),
        ],
      ),
    );
  }

  Widget _response(Requirement rfq, {required bool enquiry}) {
    final formTitle = enquiry ? 'Reply to this enquiry' : 'Submit your quote';
    final formCaption = enquiry
        ? 'Tell the buyer how you would handle it. A price is optional.'
        : 'Your price for the work as described, with anything that supports it.';
    switch (_c.state) {
      case ResponseState.own:
        return const SizedBox.shrink();
      case ResponseState.notSupplier:
        return const ResponseCard(
          title: 'Responses come from suppliers',
          icon: LucideIcons.store,
          child: ResponseNote(
            'Your account is not a supplier\'s, so it cannot reply here. A company that sells on ICR has supplier accounts; ask your company admin to add you as one.',
          ),
        );
      case ResponseState.sent:
        final bid = _c.myBid!;
        if (_editing) {
          return ResponseCard(
            title: enquiry ? 'Change your reply' : 'Change your quote',
            caption: 'The buyer sees the new version.',
            child: ReplyForm(
              key: const ValueKey('reply-form-edit'),
              enquiry: enquiry,
              editing: true,
              initial: BidDraft.from(bid),
              uploader: _uploader,
              onSend: _saveChanges,
              onPick: _pickFiles,
              onCancel: () => setState(() => _editing = false),
              onSeePlans: _seePlans,
            ),
          );
        }
        return ResponseCard(
          title: enquiry ? 'Your reply' : 'Your quote',
          child: MyReplySummary(
            bid: bid,
            enquiry: enquiry,
            justSent: _justSent,
            busy: _c.sending,
            onOpenFile: (f) => _openFile(f, private: true),
            onEdit: _c.canChangeBid ? _startEditing : null,
            onWithdraw: _c.canChangeBid ? _withdraw : null,
            changesNeedBuyer: _c.bidChangesNeedBuyer,
            onSeeBids: () => pushMyBids(context, _hooks),
          ),
        );
      case ResponseState.closed:
        return const ResponseCard(
          title: 'This requirement is closed',
          icon: LucideIcons.lock,
          child: ResponseNote('Bidding is no longer open for this requirement.'),
        );
      case ResponseState.declined:
        return const ResponseCard(
          title: 'Invitation declined',
          icon: LucideIcons.ban,
          child: ResponseNote('You\'ve declined this quote request. The buyer has been notified.'),
        );
      case ResponseState.noListing:
        final startsVerified = _c.access?.listingStartsVerified ?? false;
        return ResponseCard(
          title: formTitle,
          child: SupplierGateView(
            gate: SupplierGate.noListing,
            what: enquiry ? 'reply to requirements' : 'bid on requirements',
            onStartSelling: _startSelling,
            note: startsVerified
                ? 'Buyers see quotes from a company\'s supplier listing. Your company is already verified, so once you start selling you can quote right away.'
                : null,
          ),
        );
      case ResponseState.preQual:
        return ResponseCard(
          title: 'Submit pre-qualification response',
          icon: LucideIcons.clipboardCheck,
          caption: 'The buyer screens suppliers against the criteria before asking for detailed quotes.',
          child: PreQualForm(
            key: const ValueKey('prequal-form'),
            blocker: _c.access != null && !_c.access!.verified ? _c.blocker : null,
            onPickEmployees: _pickEmployees,
            onSend: _c.submitPreQual,
          ),
        );
      case ResponseState.screening:
        return const ResponseCard(
          title: 'Under evaluation',
          icon: LucideIcons.hourglass,
          child: ResponseNote(
            'The buyer is screening pre-qualification responses. If you\'re shortlisted, you\'ll be able to submit a detailed quote here.',
          ),
        );
      case ResponseState.evaluation:
        return const ResponseCard(
          title: 'Quotes under evaluation',
          icon: LucideIcons.hourglass,
          child: ResponseNote('Detailed quotes are closed and being evaluated by the buyer.'),
        );
      case ResponseState.form:
        return ResponseCard(
          title: formTitle,
          caption: formCaption,
          child: ReplyForm(
            key: const ValueKey('reply-form'),
            enquiry: enquiry,
            uploader: _uploader,
            allowance: _c.allowance,
            blocker: _c.blocker,
            invited: _c.invitedOnly,
            stageNote: rfq.staged && rfq.stage == RfqStage.quotation
                ? 'You\'ve been shortlisted: submit your detailed quote below.'
                : null,
            onDecline: _c.invitedOnly ? _decline : null,
            onSend: _send,
            onPick: _pickFiles,
            onSeePlans: _seePlans,
          ),
        );
    }
  }
}
