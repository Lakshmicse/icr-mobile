import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/util/links.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/title_bar.dart';
import '../widgets/account_kit.dart';
import 'saved_controller.dart';
import 'saved_models.dart';
import 'saved_repository.dart';
import 'widgets/saved_cards.dart';

/// "Saved Items & Jobs": every bookmark the member has, one chip per kind.
///
/// The website has no single page for this: `/career/saved` lists saved jobs
/// and the other kinds live on their own boards. Here a member sees and
/// manages all five kinds in one place: jobs, mentors, suppliers, councils and
/// forum discussions. Each kind reads, fails and pages on its own.
///
/// Needs an [ApiClient] in `Provider` (as every screen does) unless a
/// [repository] is given. Every `onOpen…` callback takes the app to its own
/// screen for the item; one left out opens the item's page on the website.
class SavedItemsScreen extends StatefulWidget {
  const SavedItemsScreen({
    super.key,
    this.onBack,
    this.onBell,
    this.unread = 0,
    this.initialKind = SavedKind.jobs,
    this.onOpenJob,
    this.onOpenMentor,
    this.onOpenSupplier,
    this.onOpenCouncil,
    this.onOpenThread,
    this.onOpenCompany,
    this.onBrowse,
    this.repository,
    this.opener = openUrl,
  });

  /// The bar's Back. Pops the screen when left out.
  final VoidCallback? onBack;

  /// The bell. The website's notifications when left out.
  final VoidCallback? onBell;
  final int unread;

  /// The chip the screen opens on.
  final SavedKind initialKind;

  /// A job's id.
  final void Function(String id)? onOpenJob;

  /// A mentor profile's id (the id `GET /mentorship/mentors/:id` takes).
  final void Function(String id)? onOpenMentor;

  /// A supplier listing's id (the id `GET /vendors/:id` takes).
  final void Function(String id)? onOpenSupplier;

  /// A council's slug.
  final void Function(String slug)? onOpenCouncil;

  /// A discussion's slug.
  final void Function(String slug)? onOpenThread;

  /// A company's id: where a saved job that has closed takes the member, to the
  /// company's other roles. Its jobs page on the website when left out.
  final void Function(String companyId)? onOpenCompany;

  /// The empty state's button: take the member to where [kind] is browsed.
  /// The kind's board on the website when left out.
  final void Function(SavedKind kind)? onBrowse;

  /// Instead of the API, for tests.
  final SavedRepository? repository;

  final Future<void> Function(BuildContext context, Uri uri) opener;

  @override
  State<SavedItemsScreen> createState() => _SavedItemsScreenState();
}

class _SavedItemsScreenState extends State<SavedItemsScreen> {
  late final SavedController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SavedController(
      widget.repository ?? ApiSavedRepository(api: context.read<ApiClient>()),
      initial: widget.initialKind,
    )..start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _site(String path) => widget.opener(context, AppConfig.sitePage(path));

  void _open(SavedItem item) {
    switch (item) {
      case SavedJob():
        if (item.closed) {
          widget.onOpenCompany != null && item.companyId.isNotEmpty
              ? widget.onOpenCompany!(item.companyId)
              : _site(item.companyId.isEmpty ? '/jobs' : '/companies/${item.companyId}?tab=jobs');
        } else {
          widget.onOpenJob != null ? widget.onOpenJob!(item.id) : _site('/jobs/${item.id}');
        }
      case SavedMentor():
        widget.onOpenMentor != null ? widget.onOpenMentor!(item.id) : _site('/mentorship/mentors/${item.id}');
      case SavedSupplier():
        widget.onOpenSupplier != null
            ? widget.onOpenSupplier!(item.id)
            : _site(item.companyId.isEmpty ? '/vendors/${item.id}' : '/companies/${item.companyId}');
      case SavedCouncil():
        widget.onOpenCouncil != null ? widget.onOpenCouncil!(item.slug) : _site('/councils/${item.slug}');
      case SavedThread():
        widget.onOpenThread != null ? widget.onOpenThread!(item.slug) : _site('/community/${item.slug}');
    }
  }

  void _browse(SavedKind kind) {
    if (widget.onBrowse != null) {
      widget.onBrowse!(kind);
      return;
    }
    _site(switch (kind) {
      SavedKind.jobs => '/jobs',
      SavedKind.mentors => '/mentorship/mentors',
      SavedKind.suppliers => '/vendors',
      SavedKind.councils => '/councils',
      SavedKind.discussions => '/community',
    });
  }

  Future<void> _unsave(SavedItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    final removal = await _controller.unsave(item);
    if (removal == null || !mounted) return;
    messenger.hideCurrentSnackBar();
    if (!removal.ok) {
      messenger.showSnackBar(SnackBar(content: Text(removal.error!)));
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text('Removed “${item.title}” from saved', maxLines: 2, overflow: TextOverflow.ellipsis),
        action: SnackBarAction(label: 'Undo', onPressed: () => _undo(removal)),
      ),
    );
  }

  Future<void> _undo(SavedRemoval removal) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = await _controller.restore(removal.item, removal.index);
    if (message != null && mounted) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _refresh(SavedKind kind) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = await _controller.refresh(kind);
    if (message != null && mounted) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.white),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TitleBar(
                  title: 'Saved items',
                  onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
                  unread: widget.unread,
                  onBell: widget.onBell ?? () => _site('/notifications'),
                ),
                if (!_controller.nothingAvailable) _Chips(controller: _controller),
                Expanded(child: _body()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_controller.nothingAvailable) {
      return const _Centered(
        title: 'Saving is not available here',
        message: 'This account cannot bookmark jobs, mentors, suppliers, councils or discussions.',
      );
    }
    final kind = _controller.selected;
    final s = _controller.section(kind);
    return RefreshIndicator(
      key: ValueKey('saved.refresh.${kind.name}'),
      color: AppColors.primary,
      onRefresh: () => _refresh(kind),
      child: ListView(
        key: ValueKey('saved.list.${kind.name}'),
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: _rows(kind, s),
      ),
    );
  }

  List<Widget> _rows(SavedKind kind, SavedSection s) {
    switch (s.status) {
      case SavedStatus.loading:
        return const [SizedBox(height: 320, child: AccountLoading())];
      case SavedStatus.failed:
        return [
          SizedBox(
            height: 360,
            child: AccountError(
              title: 'Could not load saved ${kind.label.toLowerCase()}',
              message: s.error ?? 'Something went wrong.',
              onRetry: () => _controller.load(kind),
            ),
          ),
        ];
      case SavedStatus.unavailable:
        return const [];
      case SavedStatus.loaded:
        if (s.isEmpty) return [SavedEmpty(kind: kind, onBrowse: () => _browse(kind))];
        return [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Text(_heading(kind, s.total), key: ValueKey('saved.count.${kind.name}'), style: AccountText.meta),
          ),
          for (final item in s.items) _card(item),
          if (s.hasNext) _more(kind, s),
        ];
    }
  }

  String _heading(SavedKind kind, int total) => switch (kind) {
    SavedKind.jobs => total == 1 ? '1 saved job' : '$total saved jobs',
    SavedKind.mentors => total == 1 ? '1 saved mentor' : '$total saved mentors',
    SavedKind.suppliers => total == 1 ? '1 saved supplier' : '$total saved suppliers',
    SavedKind.councils => total == 1 ? '1 saved council' : '$total saved councils',
    SavedKind.discussions => total == 1 ? '1 saved discussion' : '$total saved discussions',
  };

  Widget _card(SavedItem item) {
    void open() => _open(item);
    void unsave() => _unsave(item);
    final busy = _controller.isBusy(item);
    return switch (item) {
      SavedJob() => SavedJobCard(
        key: ValueKey('saved.card.job.${item.id}'),
        job: item,
        onOpen: open,
        onUnsave: unsave,
        busy: busy,
      ),
      SavedMentor() => SavedMentorCard(
        key: ValueKey('saved.card.mentor.${item.id}'),
        mentor: item,
        onOpen: open,
        onUnsave: unsave,
        busy: busy,
      ),
      SavedSupplier() => SavedSupplierCard(
        key: ValueKey('saved.card.supplier.${item.id}'),
        supplier: item,
        onOpen: open,
        onUnsave: unsave,
        busy: busy,
      ),
      SavedCouncil() => SavedCouncilCard(
        key: ValueKey('saved.card.council.${item.id}'),
        council: item,
        onOpen: open,
        onUnsave: unsave,
        busy: busy,
      ),
      SavedThread() => SavedThreadCard(
        key: ValueKey('saved.card.thread.${item.id}'),
        thread: item,
        onOpen: open,
        onUnsave: unsave,
        busy: busy,
      ),
    };
  }

  Widget _more(SavedKind kind, SavedSection s) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
    child: Column(
      children: [
        if (s.moreError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              s.moreError!,
              key: const ValueKey('saved.moreError'),
              style: AccountText.error,
              textAlign: TextAlign.center,
            ),
          ),
        Center(
          child: AccountButton(
            key: const ValueKey('saved.more'),
            label: s.moreError != null ? 'Try again' : 'Show more',
            outlined: true,
            expand: false,
            height: 40,
            busy: s.loadingMore,
            onPressed: () => _controller.loadMore(kind),
          ),
        ),
      ],
    ),
  );
}

/// The row of kinds: a chip each with the member's count, the one on filled.
/// It scrolls sideways on a narrow phone and brings the chip that is on into view.
class _Chips extends StatefulWidget {
  const _Chips({required this.controller});

  final SavedController controller;

  @override
  State<_Chips> createState() => _ChipsState();
}

class _ChipsState extends State<_Chips> {
  final _keys = {for (final k in SavedKind.values) k: GlobalKey()};
  SavedKind? _shown;

  void _reveal(SavedKind kind) {
    if (_shown == kind) return;
    _shown = kind;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _keys[kind]?.currentContext;
      if (!mounted || context == null) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    _reveal(controller.selected);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: SizedBox(
        height: 34,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              for (final kind in controller.kinds) ...[
                if (kind != controller.kinds.first) const SizedBox(width: 8),
                _chip(controller, kind),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(SavedController controller, SavedKind kind) {
    final s = controller.section(kind);
    final selected = controller.selected == kind;
    return KeyedSubtree(
      key: _keys[kind],
      child: IcrChip(
        key: ValueKey('saved.tab.${kind.name}'),
        label: s.status == SavedStatus.loaded ? '${kind.label} (${s.total})' : kind.label,
        tone: selected ? ChipTone.primary : ChipTone.outlined,
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        textStyle: AccountText.chip.copyWith(
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : AppColors.slate700,
        ),
        onTap: () => controller.select(kind),
      ),
    );
  }
}

/// A title and a sentence in the middle of the page.
class _Centered extends StatelessWidget {
  const _Centered({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: AccountText.cardTitle, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(message, style: AccountText.body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
