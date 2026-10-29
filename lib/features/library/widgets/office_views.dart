import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../library_models.dart';
import '../office/office_models.dart';
import '../office/office_reader.dart';
import '../office/zip_reader.dart';
import '../preview_runner.dart';
import 'data_grid.dart';

/// Opens a file found inside a ZIP in the viewer: its name and bytes.
typedef OpenArchiveFile = Future<void> Function(String name, Uint8List bytes);

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _line = Color(0xFFE2E8F0);

/// A centred sentence for a file that cannot be shown. [dark] is for the dark backdrop of a PDF or picture.
class ViewerMessage extends StatelessWidget {
  const ViewerMessage({super.key, required this.icon, required this.text, this.dark = false});

  final IconData icon;
  final String text;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final color = dark ? Colors.white : const Color(0xFF334155);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: color.withValues(alpha: 0.7)),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reads a Word, Excel, PowerPoint or ZIP file in the background and draws what it holds: the text, tables,
/// sheets or slides, or the list of files in an archive. Layout, pictures and formulas are not reproduced.
class OfficeBody extends StatefulWidget {
  const OfficeBody({
    super.key,
    required this.bytes,
    required this.fileName,
    required this.kind,
    required this.runner,
    required this.onOpenFile,
  });

  final Uint8List bytes;
  final String fileName;
  final PreviewKind kind;
  final PreviewRunner runner;
  final OpenArchiveFile onOpenFile;

  @override
  State<OfficeBody> createState() => _OfficeBodyState();
}

class _OfficeBodyState extends State<OfficeBody> {
  late final Future<OfficeOutcome> _outcome = widget.runner<OfficeJob, OfficeOutcome>(
    readOfficeJob,
    OfficeJob(widget.bytes, widget.fileName, widget.kind.name),
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<OfficeOutcome>(
      future: _outcome,
      builder: (context, snap) {
        if (snap.hasError) {
          return const ViewerMessage(icon: LucideIcons.fileX, text: "This file can't be previewed.");
        }
        final out = snap.data;
        if (out == null) return const Center(child: CircularProgressIndicator());
        final problem = out.problem;
        if (problem != null) return ViewerMessage(icon: LucideIcons.fileX, text: problem);
        return switch (out.preview!) {
          WordPreview p => _WordView(p),
          SheetsPreview p => _SheetsView(p),
          SlidesPreview p => _SlidesView(p),
          ArchivePreview p => _ArchiveView(
            preview: p,
            bytes: widget.bytes,
            runner: widget.runner,
            onOpenFile: widget.onOpenFile,
          ),
          TextOfficePreview p => ViewerText(p.text),
        };
      },
    );
  }
}

/// Most lines of a text file shown; a longer file says so at the foot.
const maxTextLines = 20000;

/// Plain text in a monospace face, read-only and not selectable. The lines are grouped in blocks of 40 so a
/// long file is a few hundred widgets rather than twenty thousand, which keeps scrolling and jumping light.
class ViewerText extends StatefulWidget {
  const ViewerText(this.text, {super.key});

  final String text;

  @override
  State<ViewerText> createState() => _ViewerTextState();
}

class _ViewerTextState extends State<ViewerText> {
  static const _perBlock = 40;
  late List<String> _blocks;
  late bool _cut;

  @override
  void initState() {
    super.initState();
    _split();
  }

  @override
  void didUpdateWidget(ViewerText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _split();
  }

  void _split() {
    final all = widget.text.split(RegExp(r'\r\n|\r|\n'));
    _cut = all.length > maxTextLines;
    final lines = _cut ? all.sublist(0, maxTextLines) : all;
    if (lines.every((l) => l.trim().isEmpty)) {
      _blocks = const [];
      return;
    }
    _blocks = [
      for (var i = 0; i < lines.length; i += _perBlock)
        lines.sublist(i, i + _perBlock > lines.length ? lines.length : i + _perBlock).join('\n'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_blocks.isEmpty) {
      return const ViewerMessage(icon: LucideIcons.fileText, text: 'This file is empty.');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _blocks.length + (_cut ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _blocks.length) {
          return const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('The rest of this file is not shown.', style: TextStyle(fontSize: 12, color: _muted)),
          );
        }
        return Text(
          _blocks[i],
          style: const TextStyle(fontSize: 13, height: 1.45, color: _ink, fontFamily: 'monospace'),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Word
// ---------------------------------------------------------------------------

class _WordView extends StatelessWidget {
  const _WordView(this.preview);

  final WordPreview preview;

  @override
  Widget build(BuildContext context) {
    final blocks = preview.blocks;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
      itemCount: blocks.length + (preview.truncated ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == blocks.length) {
          return const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('The rest of this document is not shown.', style: TextStyle(fontSize: 12, color: _muted)),
          );
        }
        return switch (blocks[i]) {
          WordParagraph p => _paragraph(p),
          WordTable t => _WordTable(t),
        };
      },
    );
  }

  static TextStyle _style(int heading) {
    const base = TextStyle(fontSize: 14.5, height: 1.5, color: _ink);
    return switch (heading) {
      WordParagraph.titleHeading => base.copyWith(fontSize: 24, fontWeight: FontWeight.w700, height: 1.25),
      WordParagraph.subtitleHeading => base.copyWith(fontSize: 17, fontWeight: FontWeight.w500, color: _muted),
      1 => base.copyWith(fontSize: 21, fontWeight: FontWeight.w700, height: 1.3),
      2 => base.copyWith(fontSize: 18.5, fontWeight: FontWeight.w700, height: 1.3),
      3 => base.copyWith(fontSize: 16.5, fontWeight: FontWeight.w700, height: 1.35),
      > 3 && < 7 => base.copyWith(fontSize: 15.5, fontWeight: FontWeight.w700),
      _ => base,
    };
  }

  static Widget _paragraph(WordParagraph p) {
    if (p.isBlank && p.marker == null) return const SizedBox(height: 10);
    final style = _style(p.heading);
    final text = Text.rich(
      TextSpan(
        children: [
          for (final r in p.runs)
            TextSpan(
              text: r.text,
              style: TextStyle(
                fontWeight: r.bold ? FontWeight.w700 : null,
                fontStyle: r.italic ? FontStyle.italic : null,
                decoration: r.underline ? TextDecoration.underline : null,
                color: r.muted ? _muted : null,
              ),
            ),
        ],
      ),
      style: style,
    );
    final padded = Padding(
      padding: EdgeInsets.only(top: p.heading > 0 ? 14 : 0, bottom: 6),
      child: p.marker == null
          ? text
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 20.0 + p.level * 18),
                SizedBox(width: 24, child: Text(p.marker!, style: style)),
                Expanded(child: text),
              ],
            ),
    );
    return padded;
  }
}

class _WordTable extends StatelessWidget {
  const _WordTable(this.table);

  final WordTable table;

  @override
  Widget build(BuildContext context) {
    final columns = table.rows.fold<int>(0, (m, r) => math.max(m, r.length));
    if (columns == 0) return const SizedBox.shrink();
    final wide = columns > 4;
    final grid = Table(
      border: TableBorder.all(color: _line),
      defaultColumnWidth: wide ? const FixedColumnWidth(140) : const FlexColumnWidth(),
      children: [
        for (final row in table.rows)
          TableRow(
            children: [
              for (var c = 0; c < columns; c++)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    c < row.length ? row[c] : '',
                    style: const TextStyle(fontSize: 13, height: 1.35, color: _ink),
                  ),
                ),
            ],
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: wide ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: grid) : grid,
    );
  }
}

// ---------------------------------------------------------------------------
// Excel
// ---------------------------------------------------------------------------

class _SheetsView extends StatefulWidget {
  const _SheetsView(this.preview);

  final SheetsPreview preview;

  @override
  State<_SheetsView> createState() => _SheetsViewState();
}

class _SheetsViewState extends State<_SheetsView> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final sheets = widget.preview.sheets;
    final sheet = sheets[_selected.clamp(0, sheets.length - 1)];
    return Column(
      children: [
        if (sheets.length > 1)
          SizedBox(
            height: 50,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: sheets.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ChoiceChip(
                label: Text(sheets[i].name),
                selected: i == _selected,
                onSelected: (_) => setState(() => _selected = i),
              ),
            ),
          ),
        Expanded(
          child: sheet.rows.isEmpty
              ? const ViewerMessage(icon: LucideIcons.table, text: 'This sheet is empty.')
              : DataGrid(key: ValueKey('sheet-$_selected'), rows: sheet.rows),
        ),
        if (sheet.truncated)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Only the first part of this sheet is shown.', style: TextStyle(fontSize: 12, color: _muted)),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// PowerPoint
// ---------------------------------------------------------------------------

class _SlidesView extends StatelessWidget {
  const _SlidesView(this.preview);

  final SlidesPreview preview;

  @override
  Widget build(BuildContext context) {
    final slides = preview.slides;
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: slides.length,
      itemBuilder: (_, i) => _SlideCard(slides[i], total: slides.length),
    );
  }
}

class _SlideCard extends StatelessWidget {
  const _SlideCard(this.slide, {required this.total});

  final SlideData slide;
  final int total;

  @override
  Widget build(BuildContext context) {
    final empty = slide.title.isEmpty && slide.lines.isEmpty;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Slide ${slide.number} of $total', style: const TextStyle(fontSize: 11, color: _muted)),
          const SizedBox(height: 8),
          if (slide.title.isNotEmpty)
            Text(
              slide.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.3, color: _ink),
            ),
          if (slide.title.isNotEmpty && slide.lines.isNotEmpty) const SizedBox(height: 10),
          for (final line in slide.lines)
            Padding(
              padding: EdgeInsets.only(left: line.level * 16.0, bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Text('•', style: TextStyle(fontSize: 14, height: 1.45, color: _muted)),
                  ),
                  Expanded(
                    child: Text(line.text, style: const TextStyle(fontSize: 14, height: 1.45, color: _ink)),
                  ),
                ],
              ),
            ),
          if (empty)
            const Text(
              'No text on this slide. Pictures and shapes are not previewed.',
              style: TextStyle(fontSize: 13, color: _muted),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ZIP
// ---------------------------------------------------------------------------

class _ArchiveView extends StatefulWidget {
  const _ArchiveView({required this.preview, required this.bytes, required this.runner, required this.onOpenFile});

  final ArchivePreview preview;
  final Uint8List bytes;
  final PreviewRunner runner;
  final OpenArchiveFile onOpenFile;

  @override
  State<_ArchiveView> createState() => _ArchiveViewState();
}

class _ArchiveViewState extends State<_ArchiveView> {
  int? _busy;

  Future<void> _open(ArchiveEntryInfo entry) async {
    if (_busy != null) return;
    if (previewKindFor('', entry.name) == PreviewKind.none) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text("${entry.name} can't be previewed in the app.")));
      return;
    }
    setState(() => _busy = entry.index);
    try {
      final out = await widget.runner<ArchiveReadJob, EntryOutcome>(
        readArchiveEntryJob,
        ArchiveReadJob(widget.bytes, entry.index),
      );
      if (!mounted) return;
      final bytes = out.bytes;
      if (bytes == null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(out.problem ?? "That file can't be opened.")));
        return;
      }
      await widget.onOpenFile(entry.name, bytes);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.preview.entries;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length + (widget.preview.truncated ? 1 : 0),
      separatorBuilder: (_, _) => const Divider(height: 1, color: _line),
      itemBuilder: (_, i) {
        if (i == entries.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Only the first files in this ZIP are listed.', style: TextStyle(fontSize: 12, color: _muted)),
          );
        }
        final e = entries[i];
        final previewable = previewKindFor('', e.name) != PreviewKind.none;
        return ListTile(
          leading: Icon(
            LibraryFileType.classify('', e.name).icon,
            color: previewable ? const Color(0xFF32629E) : const Color(0xFF94A3B8),
          ),
          title: Text(
            e.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: _ink),
          ),
          subtitle: Text(
            [if (e.folder.isNotEmpty) e.folder, _size(e.size)].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
          trailing: _busy == e.index
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(
                  previewable ? LucideIcons.eye : LucideIcons.eyeOff,
                  size: 18,
                  color: previewable ? const Color(0xFF32629E) : const Color(0xFF94A3B8),
                ),
          onTap: () => _open(e),
        );
      },
    );
  }

  static String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(bytes < 10 * 1024 ? 1 : 0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
