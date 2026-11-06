import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/util/links.dart';
import '../../core/widgets/chips.dart';
import '../chapters/community_kit.dart';
import 'document_screen.dart';
import 'library_controller.dart';
import 'library_device.dart';
import 'library_format.dart';
import 'library_handoffs.dart';
import 'library_models.dart';
import 'upload_document_screen.dart';
import 'widgets/document_card.dart';

/// The Digital Library: every document members shared, searchable and filterable, with a page for each
/// and a form to share your own. A document is previewed in the app, and each file can be downloaded and shared.
///
/// Top to bottom: the search box with the Upload button beside it, as the website's toolbar has them (the
/// sliders glyph opens Sort and "Only my uploads"; the list opens newest first), four tiles (Documents,
/// Categories, Formats, Your uploads), "Browse by kind" quick searches, the category chips, the format chips,
/// the result count with Clear filters, and a row per document (24 a page, "Show more documents"). Reads a
/// [LibraryController] from Provider and starts it on first build. Everything that leaves goes through
/// [LibraryHandoffs].
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.onBack,
    this.onBell,
    this.onOpenMember,
    this.onOpenPlans,
    this.device,
    this.share = shareLibraryLink,
    this.searchDelay = const Duration(milliseconds: 300),
  });

  /// The arrow at the top left.
  final VoidCallback onBack;

  /// The bell. The website's notifications page when null.
  final VoidCallback? onBell;

  /// Whoever shared a document: their profile, by user id. Not tappable without it.
  final ValueChanged<String>? onOpenMember;

  /// "See plans" on the card that says a plan does not open a document; no button without it.
  final VoidCallback? onOpenPlans;

  /// Choosing files, handing a download to the phone, opening a page. Tests give their own.
  final LibraryDevice? device;

  /// Opens the phone's share sheet. Tests give their own.
  final ShareLibraryLink share;

  /// How long the search box waits after the last key before it asks the API.
  final Duration searchDelay;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _search = TextEditingController();

  /// The list's heading, which the figures above scroll to.
  final _listKey = GlobalKey();
  Timer? _debounce;
  late final LibraryController _lc;
  String _seenQuery = '';

  LibraryHandoffs get _handoffs => LibraryHandoffs(
    onBell: widget.onBell,
    onOpenMember: widget.onOpenMember,
    onOpenPlans: widget.onOpenPlans,
    device: widget.device ?? const SystemLibraryDevice(),
    share: widget.share,
  );

  @override
  void initState() {
    super.initState();
    final c = _lc = context.read<LibraryController>();
    c.addListener(_onController);
    if (!c.started) c.start();
  }

  @override
  void dispose() {
    _lc.removeListener(_onController);
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _bell() {
    final go = widget.onBell;
    if (go != null) return go();
    _handoffs.device.openPage(context, AppConfig.sitePage('/notifications'));
  }

  void _typed(String text) {
    _debounce?.cancel();
    final c = context.read<LibraryController>();
    // Cleared at once; typing waits for a pause so a query runs per pause, not per key.
    if (text.trim().isEmpty) return c.setSearch('');
    _debounce = Timer(widget.searchDelay, () => c.setSearch(text));
  }

  /// A kind chip or Clear filters change the search from outside the box: the box follows. Only a change
  /// of the controller's search moves it, so a key typed while an answer is in flight is never overwritten.
  void _onController() {
    final s = _lc.query.search;
    if (s == _seenQuery) return;
    _seenQuery = s;
    if (_search.text.trim() != s) {
      _search.value = TextEditingValue(
        text: s,
        selection: TextSelection.collapsed(offset: s.length),
      );
    }
  }

  void _open(LibraryController c, LibraryDocument d) {
    openDocumentPage(
      context,
      repository: c.repository,
      documentId: d.id,
      initial: d,
      handoffs: _handoffs,
      onChanged: c.documentChanged,
      onRemoved: c.documentRemoved,
    );
  }

  Future<void> _upload(LibraryController c) async {
    final doc = await Navigator.of(context).push<LibraryDocument>(
      MaterialPageRoute(
        builder: (_) =>
            UploadDocumentScreen(repository: c.repository, handoffs: _handoffs, usedCategories: c.categories),
      ),
    );
    if (doc == null || !mounted) return;
    showMessage(context, '“${doc.title}” is in the library.');
    await c.documentAdded();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LibraryController>();
    return CommunityPage(
      title: 'Digital Library',
      onBack: widget.onBack,
      onBell: _bell,
      unread: c.unread,
      onRefresh: c.refresh,
      children: _body(c),
    );
  }

  /// The search box and Upload, first under the title bar where the website's toolbar has them: a search
  /// must never sit below the tiles and chips, and must stay when a read fails so it can be tried again.
  Widget _searchRow(LibraryController c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: CommunitySearchField(
              controller: _search,
              hint: 'Search documents',
              onChanged: _typed,
              onFilters: () => _filters(c),
              filtersLabel: 'Sort and filter documents',
              filtersActive: c.query.mine || c.query.sort != LibraryQuery.defaultSort,
            ),
          ),
          const SizedBox(width: 8),
          CommunityButton(
            key: const ValueKey('library-upload'),
            label: 'Upload',
            icon: LucideIcons.upload,
            height: CommunitySearchField.height,
            onPressed: () => _upload(c),
          ),
        ],
      ),
    );
  }

  List<Widget> _body(LibraryController c) {
    if (c.documents.isEmpty && c.error != null && !c.loading) {
      return [
        const SizedBox(height: 10),
        _searchRow(c),
        CommunityNotice(
          icon: LucideIcons.cloudOff,
          title: "Couldn't load the library",
          body: c.error!,
          action: 'Try again',
          onAction: c.refresh,
        ),
      ];
    }
    final q = c.query;
    final mineIds = c.viewer?.id;
    return [
      const SizedBox(height: 10),
      _searchRow(c),
      const SizedBox(height: 12),
      CommunityStatGrid(
        tiles: [
          // Every figure opens what it counts (owner, 4 Nov 2026), and the page then shows the list.
          CommunityStatTile(
            key: const ValueKey('stat-documents'),
            label: 'Documents',
            value: c.libraryTotal == null ? '–' : groupThousands(c.libraryTotal!),
            onTap: () {
              _search.clear();
              c.clearFilters();
              _showList();
            },
          ),
          CommunityStatTile(
            key: const ValueKey('stat-categories'),
            label: 'Categories',
            value: groupThousands(c.categories.length),
            onTap: c.categories.isEmpty ? null : () => _pickCategory(c),
          ),
          CommunityStatTile(
            key: const ValueKey('stat-formats'),
            label: 'Formats',
            value: groupThousands(c.fileTypes.length),
            onTap: c.fileTypes.isEmpty ? null : () => _pickFormat(c),
          ),
          CommunityStatTile(
            key: const ValueKey('stat-mine'),
            label: 'Your uploads',
            value: groupThousands(c.myUploads),
            blue: true,
            onTap: () {
              c.setMine(!q.mine);
              _showList();
            },
          ),
        ],
      ),
      const SizedBox(height: 8),
      const Divider(height: 1, thickness: 1, color: CommunityColors.tileRule),
      const SizedBox(height: 12),
      const CommunitySectionHeading(title: 'Browse by kind', caption: 'Quick searches'),
      const SizedBox(height: 8),
      ChipRow(
        height: 31,
        gap: 6,
        padding: 16,
        children: [
          for (final k in libraryKinds)
            IcrChip(
              label: k.label,
              icon: k.icon,
              iconSize: 13,
              tone: c.activeKind == k ? ChipTone.primary : ChipTone.outlined,
              height: 31,
              textStyle: CommunityText.chip,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              onTap: () => c.toggleKind(k),
            ),
        ],
      ),
      const SizedBox(height: 14),
      ChipRow(
        height: 31,
        gap: 6,
        padding: 16,
        children: [
          IcrChip(
            label: 'All Categories (${c.categories.length})',
            tone: q.category == null ? ChipTone.primary : ChipTone.outlined,
            height: 31,
            textStyle: CommunityText.chip,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            onTap: () => c.setCategory(null),
          ),
          for (final cat in c.categories)
            IcrChip(
              label: cat,
              tone: q.category == cat ? ChipTone.primary : ChipTone.outlined,
              height: 31,
              textStyle: CommunityText.chip,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              onTap: () => c.setCategory(q.category == cat ? null : cat),
            ),
        ],
      ),
      const SizedBox(height: 6),
      ChipRow(
        height: 31,
        gap: 6,
        padding: 16,
        children: [
          IcrChip(
            label: 'All formats',
            tone: q.fileType == null ? ChipTone.primary : ChipTone.outlined,
            height: 31,
            textStyle: CommunityText.chip,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            onTap: () => c.setFileType(null),
          ),
          for (final f in c.fileTypes)
            IcrChip(
              label: '${f.label} (${f.count})',
              tone: q.fileType == f.type ? ChipTone.primary : ChipTone.outlined,
              height: 31,
              textStyle: CommunityText.chip,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              onTap: () => c.setFileType(q.fileType == f.type ? null : f.type),
            ),
        ],
      ),
      const SizedBox(height: 12),
      CommunitySectionHeading(
        key: _listKey,
        title: q.mine ? 'Your uploads' : 'Documents',
        pill: c.loading && c.documents.isEmpty ? null : documentsLabel(c.total),
      ),
      if (q.filtered)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _search.clear();
                c.clearFilters();
              },
              child: Text('Clear filters', style: CommunityText.sectionLink),
            ),
          ),
        ),
      const SizedBox(height: 8),
      if (c.loading && c.documents.isEmpty)
        const CommunityLoading(height: 220)
      else if (c.documents.isEmpty)
        CommunityNotice(
          icon: LucideIcons.fileSearch,
          title: q.filtered ? 'No documents match' : 'The library is empty',
          body: q.mine
              ? "You haven't shared a document yet. Share a checklist, a template or a case study."
              : (q.filtered ? 'Try another word, or clear a filter.' : 'Be the first to share one.'),
          action: q.filtered ? 'Clear filters' : 'Upload the first document',
          onAction: q.filtered
              ? () {
                  _search.clear();
                  c.clearFilters();
                }
              : () => _upload(c),
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
        )
      else ...[
        for (final (i, d) in c.documents.indexed) ...[
          // No outline round a document: a hairline between one and the next.
          if (i > 0) const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: CommunityColors.tileRule),
          DocumentCard(document: d, mine: mineIds != null && d.uploaderId == mineIds, onOpen: () => _open(c, d)),
        ],
        const SizedBox(height: 10),
        if (c.moreError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(c.moreError!, style: CommunityText.fieldError),
          ),
        if (c.hasNext)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: CommunityButton(
              label: 'Show more documents',
              outlined: true,
              expand: true,
              height: 38,
              busy: c.loadingMore,
              onPressed: c.loadMore,
            ),
          ),
      ],
      const SizedBox(height: 28),
    ];
  }

  /// Brings the list's heading to the top once a figure above has changed what it holds.
  void _showList() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final at = _listKey.currentContext;
      if (at == null || !at.mounted) return;
      Scrollable.ensureVisible(at, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  /// "Categories": every category the library holds, to narrow the list to one.
  Future<void> _pickCategory(LibraryController c) async {
    await showCommunitySheet<void>(
      context,
      title: 'Categories',
      body: (sheet, _) => CommunityChoiceWrap<String?>(
        title: 'Show documents in',
        options: [null, ...c.categories],
        selected: c.query.category,
        label: (cat) => cat ?? 'All categories (${c.categories.length})',
        onSelected: (cat) {
          c.setCategory(cat);
          Navigator.pop(sheet);
          _showList();
        },
      ),
    );
  }

  /// "Formats": every file type in the library with how many documents have it.
  Future<void> _pickFormat(LibraryController c) async {
    await showCommunitySheet<void>(
      context,
      title: 'Formats',
      body: (sheet, _) => CommunityChoiceWrap<LibraryFileType?>(
        title: 'Show documents in',
        options: [null, for (final f in c.fileTypes) f.type],
        selected: c.query.fileType,
        label: (type) {
          if (type == null) return 'All formats';
          final f = c.fileTypes.firstWhere((f) => f.type == type);
          return '${f.label} (${f.count})';
        },
        onSelected: (type) {
          c.setFileType(type);
          Navigator.pop(sheet);
          _showList();
        },
      ),
    );
  }

  Future<void> _filters(LibraryController c) async {
    await showCommunitySheet<void>(
      context,
      title: 'Sort and filter',
      body: (sheet, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommunityChoiceWrap<LibrarySort>(
            title: 'Sort by',
            options: LibrarySort.values,
            selected: c.query.sort,
            label: (s) => s.label,
            onSelected: (s) => setState(() => c.setSort(s)),
          ),
          const SizedBox(height: 16),
          CommunityChoiceWrap<bool>(
            title: 'Show',
            options: const [false, true],
            selected: c.query.mine,
            label: (m) => m ? 'Only my uploads' : 'Everyone’s documents',
            onSelected: (m) => setState(() => c.setMine(m)),
          ),
        ],
      ),
      footer: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: CommunityButton(
                label: 'Reset',
                outlined: true,
                height: 38,
                expand: true,
                onPressed: () {
                  c.setSort(LibraryQuery.defaultSort);
                  c.setMine(false);
                  Navigator.pop(sheet);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CommunityButton(
                label: 'Show documents',
                height: 38,
                expand: true,
                onPressed: () => Navigator.pop(sheet),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
