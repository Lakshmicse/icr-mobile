import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart' show openUrl;
import '../account/widgets/account_kit.dart';
import '../../core/util/time_ago.dart';
import 'raise_ticket_sheet.dart';
import 'support_controller.dart';
import 'support_models.dart';
import 'support_repository.dart';
import 'support_routes.dart';
import 'support_session.dart';
import 'support_widgets.dart';
import 'support_words.dart';

/// The member's "Help & support" page: the website's `/support`. The common questions, the ICR account manager when
/// one is named, and the member's own requests under Open / Waiting on you / Resolved / All with a search, and a
/// "New request" that opens the form as a sheet and then the new request's thread.
class SupportScreen extends StatefulWidget {
  const SupportScreen({
    super.key,
    this.repository,
    this.onBack,
    this.onRaise,
    this.searchDelay,
    this.pickFiles,
    this.opener,
    this.onOpenContext,
  });

  /// Where the calls go; the API (or the sample in demo mode) when null.
  final SupportRepository? repository;

  /// Back from the title bar; defaults to popping the route.
  final VoidCallback? onBack;

  /// A request was logged from this page (before its thread opens).
  final ValueChanged<SupportTicketRaised>? onRaise;

  /// How long typing settles before the search runs.
  final Duration? searchDelay;

  /// The phone's file chooser for the form's attachments; the system's when null.
  final FilePickFn? pickFiles;

  /// Opens the account manager's `mailto:`; the app's link opener when null.
  final Future<void> Function(BuildContext context, Uri uri)? opener;

  /// A request's context link (`/mentorship/my/<id>`), handed on to each thread this page opens.
  final void Function(String href)? onOpenContext;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  late final SupportRepository _repository;
  late final SupportController _controller;
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? supportRepositoryOf(context);
    _controller = SupportController(repository: _repository)..start();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _search.dispose();
    super.dispose();
  }

  void _typed(String value) {
    _debounce?.cancel();
    _debounce = Timer(widget.searchDelay ?? const Duration(milliseconds: 350), () => _controller.setSearch(value));
    setState(() {});
  }

  Future<void> _raise() async {
    final raised = await showRaiseTicketSheet(context, repository: _repository, pickFiles: widget.pickFiles);
    if (raised == null || !mounted) return;
    widget.onRaise?.call(raised);
    // The website opens the new request's thread.
    await openSupportTicket(
      context,
      raised.id,
      repository: _repository,
      pickFiles: widget.pickFiles,
      onOpenContext: widget.onOpenContext,
    );
    if (mounted) unawaited(_controller.load(refresh: true));
  }

  Future<void> _open(SupportTicket ticket) async {
    await openSupportTicket(
      context,
      ticket.id,
      repository: _repository,
      pickFiles: widget.pickFiles,
      onOpenContext: widget.onOpenContext,
    );
    // It may have moved on (a reply, a reopen, a rating).
    if (mounted) unawaited(_controller.load(refresh: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceContainer,
      appBar: AccountBar(title: SupportWords.listTitle, onBack: widget.onBack),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final c = _controller;
          return RefreshIndicator(
            onRefresh: c.refresh,
            child: ListView(
              key: const Key('support.list'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 12, bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(SupportWords.listLead, style: AccountText.body),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: AccountButton(
                    key: const Key('support.new'),
                    label: SupportWords.newRequest,
                    icon: Symbols.add,
                    onPressed: _raise,
                  ),
                ),
                if (c.manager != null) _ManagerCard(manager: c.manager!, opener: widget.opener),
                if (c.faqs.isNotEmpty) _Faqs(controller: c),
                _Filters(controller: c, search: _search, onTyped: _typed),
                ..._requests(c),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _requests(SupportController c) {
    if (c.loading && c.tickets.isEmpty) {
      return const [Padding(padding: EdgeInsets.only(top: 24), child: AccountLoading())];
    }
    if (c.error != null && c.tickets.isEmpty) {
      return [
        SizedBox(
          height: 260,
          child: AccountError(message: c.error!, onRetry: c.load, title: SupportWords.couldNotLoad),
        ),
      ];
    }
    if (c.tickets.isEmpty) {
      final searching = c.search.isNotEmpty;
      return [
        Container(
          key: const Key('support.empty'),
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: AppColors.slate100, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Symbols.support_agent, size: 26, color: AppColors.slate500),
              ),
              const SizedBox(height: 12),
              Text(
                searching ? SupportWords.nothingMatches : SupportWords.nothingOpen,
                style: AccountText.cardTitle,
                textAlign: TextAlign.center,
              ),
              if (!searching) ...[
                const SizedBox(height: 6),
                Text(SupportWords.nothingOpenLead, style: AccountText.body, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                AccountButton(
                  key: const Key('support.empty.new'),
                  label: SupportWords.newRequest,
                  icon: Symbols.add,
                  expand: false,
                  onPressed: _raise,
                ),
              ],
            ],
          ),
        ),
      ];
    }
    return [
      if (c.error != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(c.error!, key: const Key('support.error'), style: AccountText.error),
        ),
      Container(
        key: const Key('support.tickets'),
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, t) in c.tickets.indexed) _TicketRow(ticket: t, first: i == 0, onTap: () => _open(t)),
              if (c.hasNext)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Center(
                    child: c.loadingMore
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : TextButton(
                            key: const Key('support.more'),
                            onPressed: c.loadMore,
                            child: const Text('Load more'),
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ];
  }
}

/// Open / Waiting on you / Resolved / All, and the search over them.
class _Filters extends StatelessWidget {
  const _Filters({required this.controller, required this.search, required this.onTyped});

  final SupportController controller;
  final TextEditingController search;
  final ValueChanged<String> onTyped;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: SupportFilter.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final f = SupportFilter.values[i];
                final on = f == controller.filter;
                return Semantics(
                  button: true,
                  selected: on,
                  child: Material(
                    color: on ? AppColors.primary : Colors.white,
                    shape: const StadiumBorder(),
                    child: InkWell(
                      key: Key('support.filter.${f.name}'),
                      customBorder: const StadiumBorder(),
                      onTap: () => controller.setFilter(f),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Center(
                          widthFactor: 1,
                          child: Text(
                            f.label,
                            style: AccountText.chip.copyWith(
                              color: on ? Colors.white : AppColors.slate700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: TextField(
              key: const Key('support.search'),
              controller: search,
              onChanged: onTyped,
              textInputAction: TextInputAction.search,
              style: AccountText.input,
              decoration: InputDecoration(
                hintText: SupportWords.searchMine,
                hintStyle: AccountText.hint,
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.slate400),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One request: its subject, "ICR-12 · Category · About", the status, the replies and when it last moved.
class _TicketRow extends StatelessWidget {
  const _TicketRow({required this.ticket, required this.first, required this.onTap});

  final SupportTicket ticket;
  final bool first;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = ticket;
    final meta = [
      SupportWords.reference(t.reference),
      SupportWords.category(t.category),
      if (t.contextLabel != null) t.contextLabel!,
    ].join(' · ');
    final n = t.messageCount;
    final replies = '$n ${n == 1 ? 'reply' : 'replies'}';
    final when = t.lastActivityAt == null ? '' : ' · ${timeAgo(t.lastActivityAt!.toLocal())}';
    return Container(
      decoration: BoxDecoration(
        border: Border(top: first ? BorderSide.none : const BorderSide(color: AppColors.slate200)),
      ),
      child: InkWell(
        key: Key('support.ticket.${t.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.subject, maxLines: 2, overflow: TextOverflow.ellipsis, style: AccountText.itemTitle),
                    const SizedBox(height: 2),
                    Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: AccountText.meta),
                    const SizedBox(height: 2),
                    Text('$replies$when', style: AccountText.meta),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SupportStatusChip(status: t.status),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Common questions": the answers people can read now, before the request they would wait on.
class _Faqs extends StatelessWidget {
  const _Faqs({required this.controller});

  final SupportController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('support.faqs'),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text(SupportWords.commonQuestions, style: AccountText.cardTitle),
            ),
            for (final (i, f) in controller.faqs.indexed)
              SupportFaqTile(
                faq: f,
                first: i == 0,
                helpful: controller.helpful.contains(f.id),
                onOpened: () => controller.viewed(f),
                onHelpful: () => controller.markHelpful(f),
              ),
          ],
        ),
      ),
    );
  }
}

/// The ICR person looking after the member, when ICR has named one.
class _ManagerCard extends StatelessWidget {
  const _ManagerCard({required this.manager, required this.opener});

  final AccountManager manager;
  final Future<void> Function(BuildContext context, Uri uri)? opener;

  @override
  Widget build(BuildContext context) {
    final m = manager;
    final line = [m.email, ?m.phone].where((s) => s.isNotEmpty).join(' · ');
    return AccountCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        key: const Key('support.manager'),
        children: [
          AccountAvatar(url: m.avatarUrl, initials: m.initials, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(SupportWords.yourManager, style: AccountText.meta.copyWith(fontWeight: FontWeight.w600)),
                Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AccountText.itemTitle),
                if (line.isNotEmpty) Text(line, maxLines: 1, overflow: TextOverflow.ellipsis, style: AccountText.meta),
                if (m.note != null)
                  Text(m.note!, maxLines: 2, overflow: TextOverflow.ellipsis, style: AccountText.meta),
              ],
            ),
          ),
          if (m.email.isNotEmpty) ...[
            const SizedBox(width: 8),
            AccountButton(
              key: const Key('support.manager.email'),
              label: 'Email',
              expand: false,
              height: 36,
              onPressed: () => (opener ?? ((c, uri) => openUrl(c, uri)))(context, Uri(scheme: 'mailto', path: m.email)),
            ),
          ],
        ],
      ),
    );
  }
}
