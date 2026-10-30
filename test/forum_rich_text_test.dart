import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/forum/forum_html.dart';
import 'package:icr_mobile/features/forum/forum_styles.dart';
import 'package:icr_mobile/features/forum/rich_document.dart';
import 'package:icr_mobile/features/forum/widgets/forum_rich_text.dart';
import 'package:icr_mobile/features/forum/rich_text_controller.dart';

/// The composer's rich details: the document and its HTML (what the website's editor writes, and what the app
/// sends), then the field's behaviour as a person types, selects, taps the toolbar and presses Enter or Backspace.
void main() {
  String roundTrip(String html) => RichDoc.fromHtml(html).toHtml();

  group('HTML in and out', () {
    test('what the website writes comes back as it was', () {
      for (final html in [
        '<p>Plain words</p>',
        '<p>Some <strong>bold</strong> and <em>italic</em> words</p>',
        '<p><strong><em>both</em></strong></p>',
        '<h3>A heading</h3><p>Then a paragraph</p>',
        '<ul><li>BMS</li><li>BACnet</li></ul>',
        '<ol><li>First</li><li>Second</li><li>Third</li></ol>',
        '<p>Before</p><ul><li>One</li></ul><p>After</p><ol><li>Two</li></ol>',
        '<p>See <a href="https://icr.org.in/community?a=1&amp;b=2">the page</a>.</p>',
        '<p><a href="mailto:ops@icr.org.in">Mail us</a></p>',
        '<p>1 &lt; 2 &amp; 3 &gt; 2</p>',
      ]) {
        expect(roundTrip(html), html, reason: html);
      }
    });

    test(
      'a list item the editor wraps in a paragraph, a link with its rel and target, and other headings read the same',
      () {
        expect(roundTrip('<ul><li><p>one</p></li><li><p>two</p></li></ul>'), '<ul><li>one</li><li>two</li></ul>');
        expect(
          roundTrip('<p><a target="_blank" rel="noopener noreferrer nofollow" href="https://icr.org.in">ICR</a></p>'),
          '<p><a href="https://icr.org.in">ICR</a></p>',
        );
        expect(roundTrip('<h2>Big</h2><h4>Small</h4>'), '<h3>Big</h3><h3>Small</h3>');
        expect(roundTrip('<h3><strong>Bold heading</strong></h3>'), '<h3>Bold heading</h3>');
      },
    );

    test('a link that is not http, https or mailto is not sent, and its words are kept', () {
      expect(roundTrip('<p><a href="javascript:alert(1)">click</a></p>'), '<p>click</p>');
      expect(roundTrip('<p><a href="data:text/html,x">x</a></p>'), '<p>x</p>');
    });

    test('quotes and code read as paragraphs; a line break starts a new paragraph; empty paragraphs go', () {
      expect(roundTrip('<blockquote>Said</blockquote><pre>code line</pre>'), '<p>Said</p><p>code line</p>');
      expect(roundTrip('<p>one<br>two</p>'), '<p>one</p><p>two</p>');
      expect(roundTrip('<p>a</p><p></p><p>   </p><p>b</p>'), '<p>a</p><p>b</p>');
      expect(htmlHasFormattingEditorLoses('<blockquote>x</blockquote>'), isTrue);
      expect(htmlHasFormattingEditorLoses('<p>Hi <strong>x</strong></p><ul><li>a</li></ul>'), isFalse);
    });

    test('plain words become escaped paragraphs, a line each', () {
      final doc = RichDoc.fromPlain('We run <b>two</b> sites.\n\nOne on BACnet.');
      expect(doc.toHtml(), '<p>We run &lt;b&gt;two&lt;/b&gt; sites.</p><p>One on BACnet.</p>');
      expect(doc.plainText, 'We run <b>two</b> sites.\n\nOne on BACnet.');
      expect(RichDoc.empty.toHtml(), '');
      expect(RichDoc.empty.isBlank, isTrue);
      expect(RichDoc.fromPlain('  \n ').isBlank, isTrue);
    });

    test('the count is the words: no newlines, no list markers', () {
      final doc = RichDoc.fromHtml('<p>abc</p><ul><li>de</li><li>f</li></ul><ol><li>gh</li></ol>');
      expect(doc.text, 'abc\n• de\n• f\n1. gh');
      expect(doc.plainLength, 8);
      expect(doc.plainText, 'abc\nde\nf\ngh');
    });

    test('numbers count on from 1 in each run', () {
      final doc = RichDoc.fromHtml('<ol><li>a</li></ol><p>x</p><ol><li>b</li><li>c</li></ol>');
      expect(doc.text, '1. a\nx\n1. b\n2. c');
    });

    test('a link address: https:// is added, a bad one is refused', () {
      expect(normaliseLink('icr.org.in/events'), 'https://icr.org.in/events');
      expect(normaliseLink(' http://x.org '), 'http://x.org');
      expect(normaliseLink('mailto:a@b.org'), 'mailto:a@b.org');
      expect(normaliseLink('javascript:alert(1)'), isNull, reason: 'it becomes https://javascript:alert(1), no host');
      expect(normaliseLink('two words'), isNull);
      expect(normaliseLink(''), isNull);
    });
  });

  group('what is written is what the discussion page draws', () {
    test('the page reads every block the editor writes', () {
      final c = RichTextController();
      c.load(
        RichDoc.fromHtml(
          '<h3>Plan</h3><p>Use <strong>BACnet</strong> and <em>MQTT</em>, see <a href="https://icr.org.in/x">notes</a></p>'
          '<ul><li>one</li><li>two</li></ul><ol><li>a</li><li>b</li></ol>',
        ),
      );
      final blocks = parseForumHtml(c.doc.toHtml());
      expect(
        [for (final b in blocks) b.kind],
        [
          BlockKind.heading,
          BlockKind.paragraph,
          BlockKind.listItem,
          BlockKind.listItem,
          BlockKind.listItem,
          BlockKind.listItem,
        ],
      );
      final runs = blocks[1].runs;
      expect(runs.firstWhere((r) => r.text == 'BACnet').bold, isTrue);
      expect(runs.firstWhere((r) => r.text == 'MQTT').italic, isTrue);
      expect(runs.firstWhere((r) => r.text == 'notes').href, 'https://icr.org.in/x');
      expect([for (final b in blocks.where((b) => b.kind == BlockKind.listItem)) b.ordinal], [null, null, 1, 2]);
      c.dispose();
    });

    testWidgets('ForumRichText draws it: bold is bold, italic is italic, a link is blue and opens', (tester) async {
      String? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForumRichText(
              html: RichDoc.fromHtml(
                '<p>Use <strong>BACnet</strong> and <em>MQTT</em>, see <a href="https://icr.org.in/x">notes</a></p>'
                '<ul><li>one</li></ul>',
              ).toHtml(),
              style: ForumDesign.body,
              onLink: (href) => opened = href,
            ),
          ),
        ),
      );
      final spans = <TextSpan>[];
      void collect(InlineSpan span) {
        if (span is TextSpan) {
          spans.add(span);
          span.children?.forEach(collect);
        }
      }

      for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
        collect(rich.text);
      }
      TextSpan span(String text) => spans.firstWhere((s) => s.text == text);
      expect(span('BACnet').style!.fontWeight, FontWeight.w700);
      expect(span('MQTT').style!.fontStyle, FontStyle.italic);
      expect(span('notes').style!.decoration, TextDecoration.underline);
      await tester.tapOnText(find.textRange.ofSubstring('notes'));
      expect(opened, 'https://icr.org.in/x');
      expect(find.text('•'), findsOneWidget);
    });
  });

  group('the field', () {
    late RichTextController c;

    setUp(() => c = RichTextController());
    tearDown(() => c.dispose());

    void type(String s) {
      final sel = c.selection.isValid ? c.selection : TextSelection.collapsed(offset: c.text.length);
      final text = c.text.replaceRange(sel.start, sel.end, s);
      c.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: sel.start + s.length),
      );
    }

    void backspace() {
      final at = c.selection.start;
      c.value = TextEditingValue(
        text: c.text.replaceRange(at - 1, at, ''),
        selection: TextSelection.collapsed(offset: at - 1),
      );
    }

    void select(int a, int b) => c.selection = TextSelection(baseOffset: a, extentOffset: b);

    String html() => c.doc.toHtml();

    test('typing is plain; the toolbar before typing marks what comes next, once chosen again it stops', () {
      type('Plain ');
      c.toggleBold();
      expect(c.isBold, isTrue);
      type('bold');
      c.toggleBold();
      expect(c.isBold, isFalse);
      type(' plain');
      expect(html(), '<p>Plain <strong>bold</strong> plain</p>');
    });

    test('typing after a bold word carries on bold; moving the caret away drops the choice', () {
      type('Hello');
      select(0, 5);
      c.toggleBold();
      select(5, 5);
      type(' world');
      expect(html(), '<p><strong>Hello world</strong></p>');
      c.toggleItalic();
      select(0, 0);
      expect(c.isItalic, isFalse, reason: 'a choice belongs to the caret it was made at');
    });

    test('bold and italic on a selection, and off again when all of it has them', () {
      type('one two three');
      select(4, 7);
      c.toggleBold();
      expect(html(), '<p>one <strong>two</strong> three</p>');
      expect(c.isBold, isTrue);
      select(4, 13);
      expect(c.isBold, isFalse, reason: 'not all of it is bold');
      c.toggleBold();
      expect(html(), '<p>one <strong>two three</strong></p>');
      c.toggleBold();
      expect(html(), '<p>one two three</p>');
      select(0, 3);
      c.toggleItalic();
      c.toggleBold();
      expect(html(), '<p><strong><em>one</em></strong> two three</p>');
    });

    test('marks stay on their characters when text goes in before them, and leave with deleted characters', () {
      type('abcdef');
      select(2, 4);
      c.toggleBold();
      select(0, 0);
      type('XY');
      expect(html(), '<p>XYab<strong>cd</strong>ef</p>');
      // Delete the bold pair.
      c.value = const TextEditingValue(text: 'XYabef', selection: TextSelection.collapsed(offset: 4));
      expect(html(), '<p>XYabef</p>');
    });

    test('a keyboard correcting a word keeps the look of the word it replaces', () {
      type('say teh now');
      select(4, 7);
      c.toggleBold();
      c.value = const TextEditingValue(text: 'say the now', selection: TextSelection.collapsed(offset: 7));
      expect(html(), '<p>say <strong>the</strong> now</p>');
    });

    test('a heading is a whole line; the toolbar turns it on and off, and it asks for a paragraph on Enter', () {
      type('Title');
      c.toggleHeading();
      expect(c.isHeading, isTrue);
      expect(html(), '<h3>Title</h3>');
      type('\n');
      type('Body');
      expect(html(), '<h3>Title</h3><p>Body</p>');
      select(0, 0);
      c.toggleHeading();
      expect(html(), '<p>Title</p><p>Body</p>');
    });

    test('a heading chosen on an empty line is for what is typed there', () {
      c.toggleHeading();
      expect(c.isHeading, isTrue);
      type('Section');
      expect(html(), '<h3>Section</h3>');
    });

    test('bullets: the toolbar adds the marker, Enter carries on, Enter on an empty item ends the list', () {
      type('First');
      c.toggleBullets();
      expect(c.text, '• First');
      expect(c.isBulleted, isTrue);
      type('\n');
      expect(c.text, '• First\n• ');
      type('Second');
      type('\n');
      expect(c.text, '• First\n• Second\n• ');
      type('\n');
      expect(c.text, '• First\n• Second\n');
      type('After');
      expect(html(), '<ul><li>First</li><li>Second</li></ul><p>After</p>');
      expect(c.selection, const TextSelection.collapsed(offset: 22));
    });

    test('a keyboard that corrects the word and breaks the line in one update still carries the list on', () {
      c.toggleNumbers();
      type('one');
      expect(c.text, '1. one');
      c.value = const TextEditingValue(text: '1. One\n', selection: TextSelection.collapsed(offset: 7));
      expect(c.text, '1. One\n2. ');
      expect(c.selection, const TextSelection.collapsed(offset: 10));
      type('two');
      expect(html(), '<ol><li>One</li><li>two</li></ol>');
    });

    test('numbers: Enter counts on, a middle item renumbers the rest, the toolbar again takes them off', () {
      type('a');
      c.toggleNumbers();
      type('\n');
      type('b');
      type('\n');
      type('c');
      expect(c.text, '1. a\n2. b\n3. c');
      // Enter at the end of the second item.
      select(9, 9);
      type('\n');
      expect(c.text, '1. a\n2. b\n3. \n4. c');
      type('new');
      expect(c.text, '1. a\n2. b\n3. new\n4. c');
      expect(html(), '<ol><li>a</li><li>b</li><li>new</li><li>c</li></ol>');
      select(0, c.text.length);
      expect(c.isNumbered, isTrue);
      c.toggleNumbers();
      expect(c.text, 'a\nb\nnew\nc');
      expect(html(), '<p>a</p><p>b</p><p>new</p><p>c</p>');
    });

    test('numbers turned on across selected lines count from 1; a bullet list switched to numbers', () {
      type('x\ny\nz');
      select(0, c.text.length);
      c.toggleBullets();
      expect(c.text, '• x\n• y\n• z');
      c.toggleNumbers();
      expect(c.text, '1. x\n2. y\n3. z');
      expect(c.isBulleted, isFalse);
      expect(c.isNumbered, isTrue);
    });

    test('Backspace after a marker takes the whole marker; "- " at the start of a line is a bullet', () {
      type('Item');
      c.toggleBullets();
      select(2, 2);
      backspace();
      expect(c.text, 'Item');
      expect(c.selection, const TextSelection.collapsed(offset: 0));
      c.value = const TextEditingValue(text: 'Item\n-', selection: TextSelection.collapsed(offset: 6));
      type(' ');
      expect(c.text, 'Item\n• ');
      expect(c.selection, const TextSelection.collapsed(offset: 7));
    });

    test('a "1. " typed at the start of a line makes a numbered item', () {
      type('1. ');
      type('first');
      expect(html(), '<ol><li>first</li></ol>');
    });

    test('a link goes on the selected words and comes off; it needs words; it is not carried on by typing', () {
      type('Read the guide now');
      expect(c.canLink, isFalse);
      select(9, 14);
      expect(c.canLink, isTrue);
      c.setLink('https://icr.org.in/guide');
      expect(html(), '<p>Read the <a href="https://icr.org.in/guide">guide</a> now</p>');
      expect(c.currentLink, 'https://icr.org.in/guide');
      select(14, 14);
      type('s');
      expect(html(), '<p>Read the <a href="https://icr.org.in/guide">guide</a>s now</p>');
      // Inside the link, an edit stays in it; the caret on a link can edit or remove it.
      select(11, 11);
      expect(c.canLink, isTrue);
      c.setLink(null);
      expect(html(), '<p>Read the guides now</p>');
    });

    test('pasting several lines keeps each a paragraph; a pasted heading line does not make the rest one', () {
      type('Title');
      c.toggleHeading();
      select(5, 5);
      type('\nsecond line\nthird');
      expect(html(), '<h3>Title</h3><p>second line</p><p>third</p>');
    });

    test('the limit is the words: more is not accepted, and a paste is cut to fit', () {
      final small = RichTextController(maxChars: 10);
      small.value = const TextEditingValue(text: 'abcdef', selection: TextSelection.collapsed(offset: 6));
      small.value = const TextEditingValue(text: 'abcdefghijkl', selection: TextSelection.collapsed(offset: 12));
      expect(small.text, 'abcdefghij');
      expect(small.plainLength, 10);
      small.value = const TextEditingValue(text: 'abcdefghijX', selection: TextSelection.collapsed(offset: 11));
      expect(small.text, 'abcdefghij', reason: 'one more is refused');
      small.dispose();
    });

    test('a loaded document keeps its marks, and edits to it keep them', () {
      c.load(RichDoc.fromHtml('<h3>Plan</h3><p>Use <strong>BACnet</strong></p><ul><li>one</li></ul>'));
      expect(c.text, 'Plan\nUse BACnet\n• one');
      select(0, 0);
      expect(c.isHeading, isTrue);
      select(12, 12);
      expect(c.isBold, isTrue);
      select(c.text.length, c.text.length);
      type('\n');
      type('two');
      expect(html(), '<h3>Plan</h3><p>Use <strong>BACnet</strong></p><ul><li>one</li><li>two</li></ul>');
    });

    test('the text it draws is the text it holds, with the marks as styles', () {
      c.load(RichDoc.fromHtml('<p>a <strong>b</strong> <em>c</em></p><h3>H</h3>'));
      final span = c.buildTextSpan(context: _NoContext(), style: const TextStyle(fontSize: 16), withComposing: false);
      expect(span.toPlainText(), c.text);
      final kids = span.children!.cast<TextSpan>();
      expect(kids.any((s) => s.text == 'b' && s.style!.fontWeight == FontWeight.w700), isTrue);
      expect(kids.any((s) => s.text == 'c' && s.style!.fontStyle == FontStyle.italic), isTrue);
      expect(kids.any((s) => s.text == 'H' && s.style!.fontSize == 18), isTrue);
    });
  });
}

class _NoContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
