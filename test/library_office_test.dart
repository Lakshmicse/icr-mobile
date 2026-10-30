import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/library/csv_rows.dart';
import 'package:icr_mobile/features/library/library_models.dart';
import 'package:icr_mobile/features/library/office/cell_format.dart';
import 'package:icr_mobile/features/library/office/cfb.dart';
import 'package:icr_mobile/features/library/office/office_models.dart';
import 'package:icr_mobile/features/library/office/office_reader.dart';
import 'package:icr_mobile/features/library/office/zip_reader.dart';

import 'helpers/office_fixtures.dart';

/// The library's own sample files (real Word, Excel, PowerPoint and ZIP files; `tool/seed/README.md`).
Uint8List seed(String name) => File('tool/seed/assets/library/$name').readAsBytesSync();

OfficePreview read(Uint8List bytes, String format, [String name = 'file']) {
  final out = readOfficeJob(OfficeJob(bytes, name, format));
  if (out.problem != null) fail('expected a preview, got: ${out.problem}');
  return out.preview!;
}

String problemOf(Uint8List bytes, String format) {
  final out = readOfficeJob(OfficeJob(bytes, 'file', format));
  if (out.problem == null) fail('expected a problem, got ${out.preview.runtimeType}');
  return out.problem!;
}

WordPreview word(Uint8List bytes) => read(bytes, 'word') as WordPreview;
SheetsPreview sheets(Uint8List bytes) => read(bytes, 'sheets') as SheetsPreview;
SlidesPreview slides(Uint8List bytes) => read(bytes, 'slides') as SlidesPreview;

List<WordParagraph> paragraphs(WordPreview p) => p.blocks.whereType<WordParagraph>().toList();

void main() {
  group('CSV', () {
    test('reads quoted cells with commas, line breaks and doubled quotes; both line ends; no blank rows', () {
      final csv = parseCsv('a,b,c\r\n1,"x, y","say ""hi"""\n\n"two\nlines",,3\n');
      expect(csv.rows, [
        ['a', 'b', 'c'],
        ['1', 'x, y', 'say "hi"'],
        ['two\nlines', '', '3'],
      ]);
      expect(csv.columns, 3);
      expect(csv.truncated, isFalse);
    });

    test('keeps a last row with no line end, drops a byte-order mark, and says when it stopped early', () {
      expect(parseCsv('﻿name,qty\nbolt,4').rows, [
        ['name', 'qty'],
        ['bolt', '4'],
      ]);
      final long = parseCsv(List.generate(10, (i) => 'r$i,$i').join('\n'), maxRows: 4);
      expect(long.rows, hasLength(4));
      expect(long.truncated, isTrue);
      expect(parseCsv('').rows, isEmpty);
    });

    test('the library’s own sample file', () {
      final csv = parseCsv(String.fromCharCodes(seed('ppm-calendar.csv')));
      expect(csv.rows.first.length, greaterThan(2));
      expect(csv.rows.length, greaterThan(2));
    });
  });

  group('number formats', () {
    test('built-in ids and custom codes pick date, time, percent or plain', () {
      expect(CellFormat.builtIn(14).date, isTrue);
      expect(CellFormat.builtIn(22).time, isTrue);
      expect(CellFormat.builtIn(9).percent, isTrue);
      expect(CellFormat.builtIn(2).date, isFalse);
      expect(CellFormat.fromCode('dd-mmm-yy').date, isTrue);
      expect(CellFormat.fromCode('[\$-409]h:mm AM/PM').time, isTrue);
      expect(CellFormat.fromCode('0.0%').percent, isTrue);
      expect(CellFormat.fromCode('#,##0.00').date, isFalse);
      expect(CellFormat.fromCode('"Rs "0').date, isFalse);
      expect(CellFormat.fromCode('General'), same(CellFormat.general));
    });

    test('serial numbers become days, in either date system, and plain numbers lose binary noise', () {
      const date = CellFormat(date: true);
      expect(date.format(45366), '15 Mar 2024');
      expect(date.format(61), '01 Mar 1900');
      expect(date.format(0, date1904: true), '01 Jan 1904');
      expect(const CellFormat(date: true, time: true).format(45366.75), '15 Mar 2024 18:00');
      expect(const CellFormat(time: true).format(0.5), '12:00');
      expect(const CellFormat(percent: true).format(0.256), '25.6%');
      expect(CellFormat.general.format(0.1 + 0.2), '0.3');
      expect(CellFormat.general.format(42), '42');
      expect(CellFormat.general.format(1234567.891), '1234567.891');
    });
  });

  group('Word (.docx)', () {
    test('the library’s sample documents: title, headings, bullets and a table', () {
      final incident = word(seed('incident-report-template.docx'));
      final ps = paragraphs(incident);
      expect(ps.first.heading, WordParagraph.titleHeading);
      expect(ps.first.text, 'Incident Report Template');
      final h = ps.where((p) => p.heading == 2).map((p) => p.text);
      expect(h, ['What happened', 'Immediate actions', 'Cause and follow-up']);
      expect(ps.where((p) => p.marker == '•'), hasLength(9));
      expect(ps.firstWhere((p) => p.marker != null).text, 'Date, time and exact location');

      final checklist = word(seed('service-contract-review-checklist.docx'));
      final table = checklist.blocks.whereType<WordTable>().single;
      expect(table.rows.first, ['Item', 'Owner', 'Done', 'Date']);
      expect(table.rows, hasLength(4));
    });

    test('numbered lists count, restart a deeper level, and use letters and numerals', () {
      const item =
          '<w:p><w:pPr><w:numPr><w:ilvl w:val="%L"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>%T</w:t></w:r></w:p>';
      String p(int level, String t) => item.replaceFirst('%L', '$level').replaceFirst('%T', t);
      final doc = word(
        buildDocx(
          [p(0, 'one'), p(0, 'two'), p(1, 'two-a'), p(1, 'two-b'), p(0, 'three'), p(1, 'three-a'), p(2, 'x')].join(),
          numbering:
              '<w:abstractNum w:abstractNumId="0">'
              '<w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="decimal"/></w:lvl>'
              '<w:lvl w:ilvl="1"><w:start w:val="1"/><w:numFmt w:val="lowerLetter"/></w:lvl>'
              '<w:lvl w:ilvl="2"><w:start w:val="1"/><w:numFmt w:val="lowerRoman"/></w:lvl>'
              '</w:abstractNum><w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>',
        ),
      );
      expect(paragraphs(doc).map((p) => p.marker), ['1.', '2.', 'a.', 'b.', '3.', 'a.', 'i.']);
      expect(paragraphs(doc).map((p) => p.level), [0, 0, 1, 1, 0, 1, 2]);
    });

    test('headings come from the style name, its outline level or the paragraph itself', () {
      final doc = word(
        buildDocx(
          '<w:p><w:pPr><w:pStyle w:val="H1"/></w:pPr><w:r><w:t>Named</w:t></w:r></w:p>'
          '<w:p><w:pPr><w:pStyle w:val="Odd"/></w:pPr><w:r><w:t>By outline</w:t></w:r></w:p>'
          '<w:p><w:pPr><w:outlineLvl w:val="2"/></w:pPr><w:r><w:t>Direct</w:t></w:r></w:p>'
          '<w:p><w:r><w:t>Body</w:t></w:r></w:p>',
          styles:
              '<w:style w:type="paragraph" w:styleId="H1"><w:name w:val="heading 1"/></w:style>'
              '<w:style w:type="paragraph" w:styleId="Odd"><w:name w:val="Kapitel"/><w:pPr><w:outlineLvl w:val="1"/></w:pPr></w:style>',
        ),
      );
      expect(paragraphs(doc).map((p) => p.heading), [1, 2, 3, 0]);
    });

    test('runs keep bold, italic and underline; links and insertions are read; deletions are not', () {
      final doc = word(
        buildDocx(
          '<w:p>'
          '<w:r><w:rPr><w:b/></w:rPr><w:t>Bold </w:t></w:r>'
          '<w:r><w:rPr><w:i/><w:b w:val="0"/></w:rPr><w:t>italic </w:t></w:r>'
          '<w:hyperlink r:id="rId9"><w:r><w:rPr><w:u w:val="single"/></w:rPr><w:t>link</w:t></w:r></w:hyperlink>'
          '<w:ins w:id="1"><w:r><w:t> added</w:t></w:r></w:ins>'
          '<w:del w:id="2"><w:r><w:delText> removed</w:delText></w:r></w:del>'
          '</w:p>',
        ),
      );
      final p = paragraphs(doc).single;
      expect(p.text, 'Bold italic link added');
      expect(p.runs.map((r) => (r.bold, r.italic, r.underline)).take(3), [
        (true, false, false),
        (false, true, false),
        (false, false, true),
      ]);
    });

    test('a picture shows as [Image], blank lines collapse, content controls and tables are read', () {
      final doc = word(
        buildDocx(
          '<w:p/><w:p/><w:p><w:r><w:t>Before</w:t></w:r></w:p><w:p/><w:p/><w:p/>'
          '<w:p><w:r><w:drawing><a:graphic><a:graphicData><pic:pic><pic:blipFill><a:blip r:embed="rId5"/></pic:blipFill></pic:pic></a:graphicData></a:graphic></w:drawing></w:r></w:p>'
          '<w:sdt><w:sdtContent><w:p><w:r><w:t>In a control</w:t></w:r></w:p></w:sdtContent></w:sdt>'
          '<w:tbl><w:tr><w:tc><w:p><w:r><w:t>A1</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>B1</w:t></w:r></w:p><w:p><w:r><w:t>B1b</w:t></w:r></w:p></w:tc></w:tr></w:tbl>',
        ),
      );
      final texts = doc.blocks.map((b) => b is WordParagraph ? (b.isBlank ? '·' : b.text) : 'table').toList();
      expect(texts, ['Before', '·', '[Image]', 'In a control', 'table']);
      expect(doc.blocks.whereType<WordTable>().single.rows, [
        ['A1', 'B1\nB1b'],
      ]);
    });
  });

  group('Excel (.xlsx)', () {
    test('the library’s sample workbooks', () {
      final lease = sheets(seed('lease-audit-template.xlsx'));
      expect(lease.sheets.single.name, 'Lease audit');
      expect(lease.sheets.single.rows[2], [
        'Clause',
        'Topic',
        'Lease says',
        'Invoice / practice shows',
        'Variance (Rs)',
        'Action',
      ]);
      expect(lease.sheets.single.rows[3].take(2), ['4.2', 'Base rent']);

      final ppm = sheets(seed('ppm-schedule.xlsx')).sheets.single;
      expect(ppm.columns, 15);
      expect(ppm.rows.first.take(4), ['Asset class', 'Task', 'Frequency', 'Jan']);
    });

    test('every kind of cell: shared and inline text, numbers, dates, percentages, booleans, errors, gaps', () {
      final xlsx = buildXlsx(
        {
          'Data':
              '<row r="1"><c r="A1" t="s"><v>0</v></c><c r="C1" t="inlineStr"><is><t>inline</t></is></c></row>'
              '<row r="2"><c r="A2"><v>42</v></c><c r="B2" s="1"><v>45366</v></c><c r="C2" s="2"><v>0.256</v></c></row>'
              '<row r="3"><c r="A3" t="b"><v>1</v></c><c r="B3" t="b"><v>0</v></c><c r="C3" t="e"><v>#DIV/0!</v></c><c r="D3" t="str"><f>A1</f><v>calc</v></c></row>'
              '<row r="5"><c r="B5" s="3"><v>45366.5</v></c></row>',
        },
        shared: ['Hello'],
        styles:
            '<numFmts count="1"><numFmt numFmtId="170" formatCode="dd-mmm-yy hh:mm"/></numFmts>'
            '<cellXfs count="4"><xf numFmtId="0"/><xf numFmtId="14"/><xf numFmtId="9"/><xf numFmtId="170"/></cellXfs>',
      );
      final rows = sheets(xlsx).sheets.single.rows;
      expect(rows[0], ['Hello', '', 'inline']);
      expect(rows[1], ['42', '15 Mar 2024', '25.6%']);
      expect(rows[2], ['TRUE', 'FALSE', '#DIV/0!', 'calc']);
      expect(rows[3], isEmpty, reason: 'a row with nothing in it is kept so row numbers stay true');
      expect(rows[4], ['', '15 Mar 2024 12:00']);
    });

    test('the 1904 date system, several sheets in order, and sheets with nothing in them', () {
      final xlsx = buildXlsx(
        {
          'First': '<row r="1"><c r="A1" s="1"><v>0</v></c></row>',
          'Second': '<row r="1"><c r="A1" t="inlineStr"><is><t>two</t></is></c></row>',
          'Empty': '',
        },
        date1904: true,
        styles: '<cellXfs count="2"><xf numFmtId="0"/><xf numFmtId="14"/></cellXfs>',
      );
      final book = sheets(xlsx);
      expect(book.sheets.map((s) => s.name), ['First', 'Second', 'Empty']);
      expect(book.sheets.first.rows.single, ['01 Jan 1904']);
      expect(book.sheets[1].rows.single, ['two']);
      expect(book.sheets[2].rows, isEmpty);
    });

    test('a very long sheet shows its first rows and says so', () {
      final rows = [for (var r = 1; r <= 2100; r++) '<row r="$r"><c r="A$r"><v>$r</v></c></row>'].join();
      final s = sheets(buildXlsx({'Long': rows})).sheets.single;
      expect(s.rows, hasLength(OfficeLimits.maxRows));
      expect(s.rows.last, ['${OfficeLimits.maxRows}']);
      expect(s.truncated, isTrue);
    });

    test('columns past the limit are cut and flagged', () {
      final cells = [for (var c = 0; c < 60; c++) '<c r="${_col(c)}1"><v>$c</v></c>'].join();
      final s = sheets(buildXlsx({'Wide': '<row r="1">$cells</row>'})).sheets.single;
      expect(s.columns, OfficeLimits.maxColumns);
      expect(s.truncated, isTrue);
    });
  });

  group('PowerPoint (.pptx)', () {
    test('the library’s sample deck: each slide’s lines in order', () {
      final deck = slides(seed('gcc-workplace-briefing.pptx'));
      expect(deck.slides, hasLength(4));
      expect(deck.slides[1].lines.map((l) => l.text), contains('Mid-week peak at 60 to 65% of seats'));
      expect(deck.slides.first.lines.first.text, 'GCC Workplace Leadership: Quarterly Briefing');
    });

    test('titles, bodies with levels, groups and tables are read; footers and slide numbers are not', () {
      const sp =
          '<p:sp><p:nvSpPr><p:cNvPr id="2" name="x"/><p:cNvSpPr/><p:nvPr>%PH</p:nvPr></p:nvSpPr><p:txBody>%P</p:txBody></p:sp>';
      String shape(String ph, String paras) => sp.replaceFirst('%PH', ph).replaceFirst('%P', paras);
      String para(String t, {int level = 0}) => '<a:p><a:pPr lvl="$level"/><a:r><a:t>$t</a:t></a:r></a:p>';
      final deck = slides(
        buildPptx([
          [
            shape('<p:ph type="title"/>', para('Quarterly plan')),
            shape(
              '<p:ph type="body"/>',
              '${para('Top point')}${para('Sub point', level: 1)}<a:p><a:endParaRPr/></a:p>',
            ),
            shape('<p:ph type="ftr"/>', para('Footer text')),
            shape('<p:ph type="sldNum"/>', '<a:p><a:fld><a:t>3</a:t></a:fld></a:p>'),
            '<p:grpSp>${shape('', para('Inside a group'))}</p:grpSp>',
            '<p:graphicFrame><a:graphic><a:graphicData><a:tbl>'
                '<a:tr><a:tc><a:txBody>${para('Region')}</a:txBody></a:tc><a:tc><a:txBody>${para('Target')}</a:txBody></a:tc></a:tr>'
                '</a:tbl></a:graphicData></a:graphic></p:graphicFrame>',
          ].join(),
        ]),
      );
      final s = deck.slides.single;
      expect(s.title, 'Quarterly plan');
      expect(s.lines.map((l) => (l.text, l.level)), [
        ('Top point', 0),
        ('Sub point', 1),
        ('Inside a group', 0),
        ('Region  |  Target', 0),
      ]);
    });
  });

  group('ZIP', () {
    test('lists the files in the library’s sample pack and opens one entry', () {
      final pack = read(seed('contractor-induction-pack.zip'), 'archive') as ArchivePreview;
      expect(
        pack.entries.map((e) => e.name),
        containsAll(['README.txt', 'sign-in-sheet.csv', 'induction-reference.pdf']),
      );
      final readme = pack.entries.firstWhere((e) => e.name == 'README.txt');
      final got = readArchiveEntryJob(ArchiveReadJob(seed('contractor-induction-pack.zip'), readme.index));
      expect(got.problem, isNull);
      expect(String.fromCharCodes(got.bytes!), isNotEmpty);
    });

    test('folders show through their files; Mac metadata is left out; an empty ZIP says so', () {
      final zip = buildZip({
        'docs/handbook/page.txt': 'x',
        '__MACOSX/docs/._page.txt': 'junk',
        'docs/.DS_Store': 'junk',
        'top.csv': 'a,b',
      });
      final pack = read(zip, 'archive') as ArchivePreview;
      expect(pack.entries.map((e) => e.path), ['docs/handbook/page.txt', 'top.csv']);
      expect(pack.entries.first.name, 'page.txt');
      expect(pack.entries.first.folder, 'docs/handbook');
      expect(problemOf(buildZip({}), 'archive'), 'This ZIP file is empty.');
    });

    test('an entry that is not there any more, or is damaged, comes back as a sentence', () {
      final zip = buildZip({'a.txt': 'hello'});
      expect(readArchiveEntryJob(ArchiveReadJob(zip, 7)).problem, "That file isn't in the ZIP any more.");
      expect(readArchiveEntryJob(ArchiveReadJob(Uint8List.fromList([1, 2, 3]), 0)).problem, isNotNull);
    });
  });

  group('compound files', () {
    test('streams of every size come back whole: small ones from the mini stream, large ones from sectors', () {
      final small = Uint8List.fromList(List.generate(300, (i) => i % 251));
      final big = Uint8List.fromList(List.generate(9000, (i) => (i * 7) % 253));
      final cfb = Cfb.parse(
        buildCfb({
          'Small': small,
          'Big': big,
          'Tiny': Uint8List.fromList([1, 2, 3]),
        }),
      );
      expect(cfb.stream('Small'), small);
      expect(cfb.stream('Big'), big);
      expect(cfb.stream('tiny'), [1, 2, 3], reason: 'names match without regard to case');
      expect(cfb.stream('Missing'), isNull);
      expect(cfb.has('Big'), isTrue);
    });

    test('a damaged container is a sentence, not a crash', () {
      final good = buildCfb({'WordDocument': Uint8List(600)});
      expect(() => Cfb.parse(Uint8List.fromList([1, 2, 3])), throwsA(isA<OfficeProblem>()));
      expect(() => Cfb.parse(Uint8List.fromList(good.sublist(0, 200))), throwsA(isA<OfficeProblem>()));
      final loop = Uint8List.fromList(good);
      // Point the first FAT entry at itself so a chain would never end.
      ByteData.sublistView(loop).setUint32(512, 0, Endian.little);
      expect(() => readOfficeJob(OfficeJob(loop, 'x.doc', 'word')), returnsNormally);
    });
  });

  group('Word 97 to 2003 (.doc)', () {
    test('text from 8-bit and UTF-16 pieces, in order, one paragraph per paragraph mark', () {
      final doc = word(
        buildDoc([('Site visit report\rInspected the plant room.\r', false), ('Température élevée — ✓\r', true)]),
      );
      expect(paragraphs(doc).map((p) => p.text), [
        'Site visit report',
        'Inspected the plant room.',
        'Température élevée — ✓',
      ]);
    });

    test('Windows-1252 punctuation is read as itself', () {
      final doc = word(buildDoc([('It\x92s \x93quoted\x94 \x96 \x80100\r', false)]));
      expect(paragraphs(doc).single.text, 'It’s “quoted” – €100');
    });

    test('table cells and rows, field codes left out and their results kept, soft breaks and tabs', () {
      final text =
          'Before\r'
          'Item\x07Owner\x07\x07'
          'Fire\x07Asha\x07\x07'
          'See \x13 HYPERLINK "http://x.test" \x14the guide\x15 now\r'
          'Line one\x0bLine two\tTabbed\r';
      final doc = word(buildDoc([(text, false)]));
      expect(doc.blocks.whereType<WordTable>().single.rows, [
        ['Item', 'Owner'],
        ['Fire', 'Asha'],
      ]);
      final texts = paragraphs(doc).map((p) => p.text).toList();
      expect(texts, ['Before', 'See the guide now', 'Line one\nLine two\tTabbed']);
    });

    test('Word 6 and Word 95 files, which have no piece table', () {
      final doc = word(buildWord6('The quick brown fox\rjumps over the lazy dog\r'));
      expect(paragraphs(doc).map((p) => p.text), ['The quick brown fox', 'jumps over the lazy dog']);
    });

    test('password-protected, empty and ancient files say what they are', () {
      expect(problemOf(buildDoc([('secret\r', false)], encrypted: true), 'word'), contains('password protected'));
      expect(problemOf(buildDoc([('\r\r', false)]), 'word'), contains('no text'));
      // Word 2 for Windows (1991) starts with a different mark.
      final old = Uint8List.fromList(Cfb.parse(buildWord6('x')).stream('WordDocument')!);
      ByteData.sublistView(old).setUint16(0, 0xA59B, Endian.little);
      expect(problemOf(buildCfb({'WordDocument': old}), 'word'), contains('too old'));
    });
  });

  group('Excel 97 to 2003 (.xls)', () {
    final book = {
      'Costs': [
        const XlsCell.text(0, 0, 'Item'),
        const XlsCell.text(0, 1, 'Spreadsheet total'),
        const XlsCell.text(0, 2, 'Привет'),
        const XlsCell.number(1, 0, 12), // an RK integer
        const XlsCell.number(1, 1, 0.256, xf: 1),
        const XlsCell.number(2, 0, 45366, xf: 2),
        const XlsCell.number(2, 1, 45366.5, xf: 3),
        const XlsCell.number(3, 0, 3.5),
        const XlsCell.formulaText(3, 2, 'computed'),
        const XlsCell.text(5, 1, 'Item'),
      ],
      'Notes': [const XlsCell.text(0, 0, 'second sheet')],
    };

    test(
      'text through the shared strings (one split across records, one in UTF-16), numbers, dates, percentages and a formula’s text',
      () {
        final s = sheets(buildXls(book));
        expect(s.sheets.map((x) => x.name), ['Costs', 'Notes']);
        final rows = s.sheets.first.rows;
        expect(rows[0], ['Item', 'Spreadsheet total', 'Привет']);
        expect(rows[1], ['12', '25.6%']);
        expect(rows[2], ['15 Mar 2024', '15 Mar 2024 12:00']);
        expect(rows[3], ['3.5', '', 'computed']);
        expect(rows[4], isEmpty);
        expect(rows[5], ['', 'Item']);
        expect(s.sheets[1].rows.single, ['second sheet']);
      },
    );

    test('the 1904 date system is honoured', () {
      final s = sheets(
        buildXls({
          'D': [const XlsCell.number(0, 0, 0, xf: 2)],
        }, date1904: true),
      );
      expect(s.sheets.single.rows.single, ['01 Jan 1904']);
    });

    test('a password-protected workbook says so', () {
      expect(problemOf(buildXls(book, filepass: true), 'sheets'), contains('password protected'));
    });
  });

  group('PowerPoint 97 to 2003 (.ppt)', () {
    const deck = [
      PptSlide(
        list: [(0, 'Plant review', true), (1, 'First point\rSecond point', false)],
        boxes: ['A free text box', 'First point'],
      ),
      PptSlide(list: [(6, 'Next steps', false)], boxes: ['Owner: Asha']),
    ];

    test('titles and body text from the slide list and the text boxes, each line once, masters left out', () {
      final s = slides(buildPpt(deck));
      expect(s.slides, hasLength(2));
      expect(s.slides[0].title, 'Plant review');
      expect(s.slides[0].lines.map((l) => l.text), ['First point', 'Second point', 'A free text box']);
      expect(s.slides[1].title, 'Next steps');
      expect(s.slides[1].lines.map((l) => l.text), ['Owner: Asha']);
      expect(s.slides.expand((x) => x.lines).map((l) => l.text), isNot(contains('MASTER TEXT')));
    });

    test('a file saved several times shows the current slide, not the old one still in the stream', () {
      final s = slides(buildPpt(deck, staleBefore: true));
      expect(s.slides, hasLength(2));
      expect(s.slides[0].lines.map((l) => l.text), isNot(contains('OLD TEXT FROM AN EARLIER SAVE')));
      expect(s.slides[0].lines.map((l) => l.text), contains('A free text box'));
    });

    test('without an edit history the slides are still found by scanning', () {
      final s = slides(buildPpt(deck, history: false));
      expect(s.slides.map((x) => x.title), ['Plant review', 'Next steps']);
    });

    test('a password-protected deck says so', () {
      expect(problemOf(buildPpt(deck, encrypted: true), 'slides'), contains('password protected'));
    });
  });

  group('read by what is inside, not by name', () {
    test('a Word file filed as a spreadsheet is still read as Word, and the other way round', () {
      expect(read(seed('incident-report-template.docx'), 'sheets'), isA<WordPreview>());
      expect(read(seed('lease-audit-template.xlsx'), 'word'), isA<SheetsPreview>());
      expect(read(seed('gcc-workplace-briefing.pptx'), 'word'), isA<SlidesPreview>());
      expect(read(buildDoc([('Hello\r', false)]), 'sheets'), isA<WordPreview>());
    });

    test('a ZIP that is not an Office package is a list of files whatever it was called', () {
      expect(read(seed('contractor-induction-pack.zip'), 'word'), isA<ArchivePreview>());
    });

    test('text saved under an Office name is shown as text; an HTML export loses its tags', () {
      final text = read(Uint8List.fromList('plain notes\nsecond line'.codeUnits), 'sheets') as TextOfficePreview;
      expect(text.text, 'plain notes\nsecond line');
      final html =
          read(
                Uint8List.fromList(
                  '<html><body><table><tr><td>Name</td><td>Qty</td></tr><tr><td>Bolt</td><td>4</td></tr></table></body></html>'
                      .codeUnits,
                ),
                'sheets',
              )
              as TextOfficePreview;
      expect(html.text, contains('Name\tQty'));
      expect(html.text, isNot(contains('<td>')));
    });

    test('files that are none of those are refused in words', () {
      expect(
        problemOf(Uint8List.fromList(List.generate(500, (i) => i % 256)), 'word'),
        contains('format the app can read'),
      );
      expect(problemOf(Uint8List(0), 'word'), contains('empty'));
      expect(problemOf(Uint8List.fromList('not a zip'.codeUnits), 'archive'), contains('ZIP'));
      expect(problemOf(buildCfb({'Mystery': Uint8List(10)}), 'word'), contains("can't be previewed"));
      expect(
        problemOf(buildCfb({'EncryptedPackage': Uint8List(10), 'EncryptionInfo': Uint8List(10)}), 'word'),
        contains('password protected'),
      );
    });
  });

  group('robustness: damaged files never crash or hang', () {
    final samples = <(String, Uint8List, String)>[
      ('docx', seed('service-contract-review-checklist.docx'), 'word'),
      ('xlsx', seed('ppm-schedule.xlsx'), 'sheets'),
      ('pptx', seed('gcc-workplace-briefing.pptx'), 'slides'),
      ('zip', seed('contractor-induction-pack.zip'), 'archive'),
      ('doc', buildDoc([('Hello\r\x07x\x07\x07', false)]), 'word'),
      (
        'xls',
        buildXls({
          'A': [const XlsCell.text(0, 0, 'Hello world'), const XlsCell.number(1, 0, 7)],
        }),
        'sheets',
      ),
      (
        'ppt',
        buildPpt(const [
          PptSlide(list: [(0, 'T', false)], boxes: ['b']),
        ]),
        'slides',
      ),
    ];

    for (final (name, bytes, format) in samples) {
      test('$name: truncated at many points, and with bytes flipped', () {
        final random = Random(7);
        final started = DateTime.now();
        for (var i = 0; i < 60; i++) {
          final cut = bytes.sublist(0, random.nextInt(bytes.length));
          expect(() => readOfficeJob(OfficeJob(Uint8List.fromList(cut), 'x', format)), returnsNormally);
        }
        for (var i = 0; i < 60; i++) {
          final copy = Uint8List.fromList(bytes);
          for (var k = 0; k < 1 + random.nextInt(12); k++) {
            copy[random.nextInt(copy.length)] = random.nextInt(256);
          }
          final out = readOfficeJob(OfficeJob(copy, 'x', format));
          expect(out.preview != null || out.problem != null, isTrue);
        }
        expect(DateTime.now().difference(started).inSeconds, lessThan(20));
      });
    }
  });

  group('which viewer a file gets', () {
    test('by MIME type first, then by name; SVG and unknown formats have none', () {
      PreviewKind kind(String mime, String name) => previewKindFor(mime, name);
      expect(kind('application/pdf', 'x'), PreviewKind.pdf);
      expect(kind('image/png', 'x'), PreviewKind.image);
      expect(kind('image/svg+xml', 'x.svg'), PreviewKind.none);
      expect(kind('text/plain', 'x'), PreviewKind.text);
      expect(kind('text/csv', 'x'), PreviewKind.table);
      expect(kind('application/msword', 'x'), PreviewKind.word);
      expect(kind('application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'x'), PreviewKind.word);
      expect(kind('application/vnd.ms-excel', 'x'), PreviewKind.sheets);
      expect(kind('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'x'), PreviewKind.sheets);
      expect(kind('application/vnd.ms-powerpoint', 'x'), PreviewKind.slides);
      expect(kind('application/x-zip-compressed', 'x'), PreviewKind.archive);
      expect(kind('application/octet-stream', 'Plan.DOCX'), PreviewKind.word);
      expect(kind('', 'sheet.xls'), PreviewKind.sheets);
      expect(kind('', 'deck.pptx'), PreviewKind.slides);
      expect(kind('', 'pack.zip'), PreviewKind.archive);
      expect(kind('', 'photo.JPG'), PreviewKind.image);
      expect(kind('application/acad', 'plan.dwg'), PreviewKind.none);
      expect(kind('', 'README'), PreviewKind.none);
    });

    test('every format the library accepts for upload has a viewer', () {
      for (final ext in LibraryLimits.extensions) {
        expect(previewKindFor('', 'file.$ext'), isNot(PreviewKind.none), reason: '.$ext');
      }
    });
  });
}

String _col(int i) {
  var n = i + 1;
  var s = '';
  while (n > 0) {
    n -= 1;
    s = String.fromCharCode(65 + n % 26) + s;
    n ~/= 26;
  }
  return s;
}
