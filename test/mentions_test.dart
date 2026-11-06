import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/core/util/links.dart' show SiteRoutes;
import 'package:icr_mobile/features/feed/feed_models.dart';
import 'package:icr_mobile/features/feed/forum_json.dart';
import 'package:icr_mobile/features/forum/forum_html.dart';
import 'package:icr_mobile/features/forum/mentions/mention_controller.dart';
import 'package:icr_mobile/features/forum/mentions/mention_text.dart';
import 'package:icr_mobile/features/forum/mentions/mention_widgets.dart';
import 'package:icr_mobile/features/forum/rich_document.dart';

import 'helpers/fonts.dart';

/// The "@" picker: where the name being typed is, what a pick puts in the words, which picks are still there when
/// the words are sent, the forum's HTML with each as a link to the profile, and the list of people on screen.
void main() {
  setUpAll(loadAppFonts);

  const rahul = Mention(id: 'u-rahul', name: 'Rahul Sharma');
  const priya = Mention(id: 'u-priya', name: 'Priya Nambiar');

  group('finding the name being typed', () {
    MentionQuery? at(String text, [int? caret]) => mentionQueryAt(text, caret ?? text.length);

    test('an "@" and the letters after it, up to the caret', () {
      expect(at('Hi @ra'), const MentionQuery(start: 3, text: 'ra'));
      expect(at('@'), const MentionQuery(start: 0, text: ''));
      expect(at('Hi @'), const MentionQuery(start: 3, text: ''));
      expect(at('(@Ra'), const MentionQuery(start: 1, text: 'Ra'));
      expect(at('Cc\n@priya'), const MentionQuery(start: 3, text: 'priya'));
    });

    test('a second word is allowed ("@ra sh"), a third or a second space in a row is not', () {
      expect(at('@ra sh'), const MentionQuery(start: 0, text: 'ra sh'));
      expect(at('@ra '), const MentionQuery(start: 0, text: 'ra '));
      expect(at('@ra  '), isNull, reason: 'typing a space twice closes it');
      expect(at('@ra  sh'), isNull);
      expect(at('@ra sh kum'), isNull);
    });

    test('the caret decides: moved off the name, the picker is closed', () {
      expect(at('@raj kumar', 3), const MentionQuery(start: 0, text: 'ra'), reason: 'the caret is after "ra"');
      expect(at('@raj and then more words'), isNull);
      expect(at('@raj, thanks'), isNull);
      expect(at('@raj\nnext line'), isNull);
      expect(at('@raj', 0), isNull);
      expect(at('no at here'), isNull);
    });

    test('an address, or an "@" with a space after it, is not a name begun', () {
      expect(at('mail a@b.com'), isNull);
      expect(at('me@ra'), isNull);
      expect(at('call me @ 5pm'), isNull);
      expect(at('@ 5'), isNull);
    });

    test('names with accents, apostrophes and hyphens are names', () {
      expect(at('@Zoë'), const MentionQuery(start: 0, text: 'Zoë'));
      expect(at("@D'Souza"), const MentionQuery(start: 0, text: "D'Souza"));
      expect(at('@Anne-Marie'), const MentionQuery(start: 0, text: 'Anne-Marie'));
    });

    test('a query far longer than any name ends', () {
      expect(at('@${'a' * (mentionQueryMax + 2)}'), isNull);
    });
  });

  group('putting a pick in the words', () {
    test('"@query" is replaced by "@First Last " and the caret goes after it', () {
      const text = 'Thanks @ra';
      final q = mentionQueryAt(text, text.length)!;
      final done = insertMention(text, q, text.length, 'Rahul Sharma');
      expect(done.text, 'Thanks @Rahul Sharma ');
      expect(done.caret, done.text.length);
    });

    test('words after the caret stay, and no second space is added where one follows', () {
      const text = 'Thanks @ra for this';
      final q = mentionQueryAt(text, 10)!;
      final done = insertMention(text, q, 10, 'Rahul Sharma');
      expect(done.text, 'Thanks @Rahul Sharma for this');
      expect(done.caret, 'Thanks @Rahul Sharma'.length);
      final dot = insertMention('Ask @ra.', mentionQueryAt('Ask @ra.', 7)!, 7, 'Rahul Sharma');
      expect(dot.text, 'Ask @Rahul Sharma.');
    });
  });

  group('which picks are still in the words', () {
    test('a pick the text no longer holds is not sent', () {
      expect(mentionsStillIn('Thanks @Rahul Sharma and @Priya Nambiar', [rahul, priya]), [rahul, priya]);
      expect(mentionsStillIn('Thanks Rahul Sharma and @Priya Nambiar', [rahul, priya]), [priya]);
      expect(mentionsStillIn('Thanks @Rahul', [rahul, priya]), isEmpty, reason: 'edited into other words');
    });

    test('the "@" must start a word and the name must end one', () {
      expect(mentionsStillIn('a@Rahul Sharma', [rahul]), isEmpty);
      expect(mentionsStillIn('@Rahul Sharmaji', [rahul]), isEmpty);
      expect(mentionsStillIn('(@Rahul Sharma), hi', [rahul]), [rahul]);
      expect(mentionsStillIn('@Rahul Sharma.', [rahul]), [rahul]);
    });

    test('two different people with the same name are told apart by the order they were picked in', () {
      const first = Mention(id: 'u-1', name: 'Rajesh Sharma');
      const second = Mention(id: 'u-2', name: 'Rajesh Sharma');
      final spans = mentionSpans('@Rajesh Sharma and then @Rajesh Sharma', [first, second]);
      expect([for (final s in spans) s.mention.id], ['u-1', 'u-2']);
      expect(mentionsStillIn('@Rajesh Sharma and then @Rajesh Sharma', [first, second]), [first, second]);
      expect(
        mentionedHtml('@Rajesh Sharma & @Rajesh Sharma', [first, second]),
        '<p><a href="/members/u-1">@Rajesh Sharma</a> &amp; <a href="/members/u-2">@Rajesh Sharma</a></p>',
      );
      expect(mentionsStillIn('@Rajesh Sharma twice @Rajesh Sharma', [first]), [first], reason: 'one person, twice');
    });

    test('a person tagged twice is one mention; a longer name wins over a shorter one it begins', () {
      expect(mentionsStillIn('@Rahul Sharma and again @Rahul Sharma', [rahul]), [rahul]);
      const longer = Mention(id: 'u-rs', name: 'Rahul Sharma Iyer');
      final spans = mentionSpans('@Rahul Sharma Iyer and @Rahul Sharma', [rahul, longer]);
      expect([for (final s in spans) s.mention.id], ['u-rs', 'u-rahul']);
      expect([for (final s in spans) (s.start, s.end)], [(0, 18), (23, 36)]);
    });
  });

  group('the words as the forum\'s HTML', () {
    test('each mention is a link to the member; everything else is escaped as before', () {
      expect(
        mentionedHtml('Thanks @Rahul Sharma, see <b>this</b> & that', [rahul]),
        '<p>Thanks <a href="/members/u-rahul">@Rahul Sharma</a>, see &lt;b&gt;this&lt;/b&gt; &amp; that</p>',
      );
    });

    test('paragraphs and line breaks are kept, a mention in each', () {
      expect(
        mentionedHtml('Hi @Rahul Sharma\nline two\n\n@Priya Nambiar please', [rahul, priya]),
        '<p>Hi <a href="/members/u-rahul">@Rahul Sharma</a><br>line two</p>'
        '<p><a href="/members/u-priya">@Priya Nambiar</a> please</p>',
      );
    });

    test('a mention deleted from the words is not sent', () {
      expect(mentionedHtml('Hi Rahul', [rahul]), '<p>Hi Rahul</p>');
    });

    test('with no mention it is exactly what the app sent before', () {
      for (final text in ['Plain words', 'One\n\nTwo <i>x</i>', '  padded \n']) {
        expect(mentionedHtml(text, const []), ForumJson.textToHtml(text));
        expect(mentionedHtml(text, [rahul]), ForumJson.textToHtml(text), reason: 'not tagged in this text');
      }
    });

    test('a name with markup in it is escaped in the link, and an id cannot break out of it', () {
      const odd = Mention(id: 'u"><b>', name: 'A <b> & C');
      final html = mentionedHtml('Hi @A <b> & C', [odd]);
      expect(html, contains('href="/members/u&quot;&gt;&lt;b&gt;"'));
      expect(html, contains('>@A &lt;b&gt; &amp; C</a>'));
      expect(html, isNot(contains('<b>')));
    });
  });

  group('reading the people a post tags', () {
    test('the anchors of a body, once each, with their names unescaped', () {
      const html =
          '<p>Thanks <a href="/members/u-rahul">@Rahul Sharma</a> and <a href="/members/u-priya">@Priya Nambiar</a>'
          ' and again <a href="/members/u-rahul">@Rahul Sharma</a>, also <a href="https://example.com/x">a site</a>'
          ' and <a href="/members/u-o">@O&#39;Neil &amp; Co</a></p>';
      expect(mentionsInHtml(html), [rahul, priya, const Mention(id: 'u-o', name: "O'Neil & Co")]);
      expect(ForumJson.mentionsIn(html), mentionsInHtml(html));
    });

    test('the anchor as the portal stores it (rel and target added) reads the same, and shows as a link', () {
      const stored =
          '<p>Probe: thanks <a href="/members/u-rahul" rel="noopener noreferrer nofollow" target="_blank">@Rahul Sharma</a>'
          ' &amp; team</p>';
      expect(mentionsInHtml(stored), [rahul]);
      final run = parseForumHtml(stored).single.runs.firstWhere((r) => r.href != null);
      expect(run.href, '/members/u-rahul');
      expect(run.text, '@Rahul Sharma');
      expect(ForumJson.plainText(stored), 'Probe: thanks @Rahul Sharma & team');
    });

    test('no anchors, no mentions', () {
      expect(mentionsInHtml(null), isEmpty);
      expect(mentionsInHtml('<p>Hi</p>'), isEmpty);
      expect(mentionsInHtml('<p><a href="https://icr.org.in/members/u-x">@X</a></p>'), isEmpty);
    });

    test('a reply read from the forum carries them', () {
      final json = const ForumJson(apiBase: 'http://api.test/api/v1', viewerId: 'me');
      final reply = json.reply({
        'id': 'r1',
        'author': {'id': 'u-a', 'firstName': 'A', 'lastName': 'B'},
        'bodyHtml': '<p>Hi <a href="/members/u-rahul">@Rahul Sharma</a></p>',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });
      expect(reply.mentions, [rahul]);
      expect(reply.body, 'Hi @Rahul Sharma');
    });
  });

  group('the composer\'s rich text', () {
    test('a mention still in the details becomes a link to the member; a deleted one is not sent', () {
      final doc = RichDoc.fromPlain('Ping @Rahul Sharma now');
      expect(doc.withMentions([rahul]).toHtml(), '<p>Ping <a href="/members/u-rahul">@Rahul Sharma</a> now</p>');
      expect(RichDoc.fromPlain('Ping Rahul now').withMentions([rahul]).toHtml(), '<p>Ping Rahul now</p>');
      expect(doc.toHtml(), '<p>Ping @Rahul Sharma now</p>', reason: 'the document itself is unchanged');
    });

    test('a post written with a mention keeps it when it is opened to edit and saved again', () {
      const stored = '<p>Ping <a href="/members/u-rahul">@Rahul Sharma</a> now</p>';
      final doc = RichDoc.fromHtml(stored);
      expect(doc.toHtml(), stored);
      expect(parseForumHtml(stored).single.runs.where((r) => r.href != null).single.href, '/members/u-rahul');
    });

    test('only a member link goes without a scheme; any other relative link is still dropped', () {
      expect(parseForumHtml('<p><a href="/community/x">x</a></p>').single.runs.single.href, isNull);
      expect(parseForumHtml('<p><a href="/members/u-1">x</a></p>').single.runs.single.href, '/members/u-1');
      expect(parseForumHtml('<p><a href="//evil.example/members/u-1">x</a></p>').single.runs.single.href, isNull);
    });
  });

  group('the controller behind a field', () {
    final people = [
      for (var i = 0; i < 12; i++)
        MentionPerson(id: 'u$i', firstName: 'Ra$i', lastName: 'Kumar', headline: 'Head of FM $i'),
    ];

    late TextEditingController text;
    late List<String> asked;
    late MentionController c;

    MentionController make({Future<List<MentionPerson>> Function(String q)? search}) {
      asked = [];
      text = TextEditingController();
      addTearDown(text.dispose);
      final controller = MentionController(
        search: (q) {
          asked.add(q);
          return search == null ? Future.value(people) : search(q);
        },
      );
      addTearDown(controller.dispose);
      return controller..attach(text);
    }

    void type(String value, [int? caret]) {
      text.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: caret ?? value.length),
      );
    }

    testWidgets('typing "@" opens it; the search waits out a pause and asks once for the latest letters', (
      tester,
    ) async {
      c = make();
      type('Hi @');
      expect(c.open, isTrue);
      expect(c.loading, isTrue);
      type('Hi @r');
      type('Hi @ra');
      type('Hi @ra s');
      await tester.pump(const Duration(milliseconds: 200));
      expect(asked, isEmpty, reason: 'still inside the pause');
      await tester.pump(const Duration(milliseconds: 100));
      expect(asked, ['ra s']);
      expect(c.loading, isFalse);
      expect(c.results.length, 8, reason: 'at most eight');
      expect(c.resultsFor, 'ra s');
    });

    testWidgets('a slow answer for an earlier query never replaces the later one', (tester) async {
      final first = Completer<List<MentionPerson>>();
      c = make(search: (q) => q == 'ra' ? first.future : Future.value([people[3]]));
      type('@ra');
      await tester.pump(const Duration(milliseconds: 300));
      type('@rav');
      await tester.pump(const Duration(milliseconds: 300));
      expect(c.results, [people[3]]);
      first.complete(people);
      await tester.pump();
      expect(c.results, [people[3]], reason: 'the late answer is ignored');
    });

    testWidgets('a failed search says so and the next letters try again', (tester) async {
      var fail = true;
      c = make(search: (q) async => fail ? throw StateError('offline') : [people[0]]);
      type('@ra');
      await tester.pump(const Duration(milliseconds: 300));
      expect(c.failed, isTrue);
      expect(c.results, isEmpty);
      fail = false;
      type('@rah');
      await tester.pump(const Duration(milliseconds: 300));
      expect(c.failed, isFalse);
      expect(c.results, [people[0]]);
    });

    testWidgets('picking replaces "@query" with "@First Last " and records the person', (tester) async {
      c = make();
      type('Thanks @ra');
      await tester.pump(const Duration(milliseconds: 300));
      c.pick(people[1]);
      expect(text.text, 'Thanks @Ra1 Kumar ');
      expect(text.selection, const TextSelection.collapsed(offset: 18));
      expect(c.open, isFalse, reason: 'the caret is past the name now');
      expect(c.picked, [const Mention(id: 'u1', name: 'Ra1 Kumar')]);
      expect(c.mentionsIn(text.text), [const Mention(id: 'u1', name: 'Ra1 Kumar')]);
      // Deleting the mention from the words un-tags the person.
      type('Thanks ');
      expect(c.mentionsIn(text.text), isEmpty);
    });

    testWidgets('a second space, the caret moving away, or Escape closes it; Escape holds until another "@"', (
      tester,
    ) async {
      c = make();
      type('@ra');
      expect(c.open, isTrue);
      type('@ra  ');
      expect(c.open, isFalse, reason: 'two spaces in a row');
      type('@ra', 3);
      expect(c.open, isTrue);
      type('@ra and then', 12);
      expect(c.open, isFalse, reason: 'the caret is off the name');
      type('@ra', 3);
      c.dismiss();
      expect(c.open, isFalse);
      type('@raj', 4);
      expect(c.open, isFalse, reason: 'dismissed for this "@"');
      type('@raj and @', 10);
      expect(c.open, isTrue, reason: 'a new "@" opens it again');
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('seeding keeps the people already tagged in words being edited; reset forgets everyone', (
      tester,
    ) async {
      c = make();
      c.seed([rahul]);
      expect(c.mentionsIn('Hello @Rahul Sharma'), [rahul]);
      c.reset();
      expect(c.mentionsIn('Hello @Rahul Sharma'), isEmpty);
    });
  });

  group('the list of people', () {
    final people = [
      const MentionPerson(id: 'u-rahul', firstName: 'Rahul', lastName: 'Sharma', headline: 'Head of FM at Prestige'),
      const MentionPerson(id: 'u-priya', firstName: 'Priya', lastName: 'Nambiar'),
    ];

    late TextEditingController text;
    late FocusNode focus;
    late MentionController picker;

    Future<void> pump(WidgetTester tester, {Future<List<MentionPerson>> Function(String q)? search}) async {
      text = TextEditingController();
      focus = FocusNode();
      picker = MentionController(search: search ?? (q) async => people)..attach(text, focus);
      addTearDown(() {
        picker.dispose();
        focus.dispose();
        text.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Column(
              children: [
                MentionSuggestions(controller: picker),
                MentionEscape(
                  controller: picker,
                  child: TextField(key: const ValueKey('field'), controller: text, focusNode: focus),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Future<void> typeIn(WidgetTester tester, String value) async {
      await tester.enterText(find.byKey(const ValueKey('field')), value);
      await tester.pump();
    }

    testWidgets('while a name is typed: a searching row, then each person with photo, name and headline', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byKey(const ValueKey('mention-panel')), findsNothing);
      await typeIn(tester, 'Hi @ra');
      expect(find.byKey(const ValueKey('mention-loading')), findsOneWidget);
      expect(find.text('Searching people…'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('mention-loading')), findsNothing);
      expect(find.byKey(const ValueKey('mention-option:u-rahul')), findsOneWidget);
      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('Head of FM at Prestige'), findsOneWidget);
      expect(find.text('RS'), findsOneWidget, reason: 'the initials stand in for a missing photo');
      expect(find.text('Priya Nambiar'), findsOneWidget);
    });

    testWidgets('tapping a person puts "@First Last " in the field and closes the list', (tester) async {
      await pump(tester);
      await typeIn(tester, 'Hi @ra');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('mention-option:u-rahul')));
      await tester.pump();
      expect(text.text, 'Hi @Rahul Sharma ');
      expect(find.byKey(const ValueKey('mention-panel')), findsNothing);
      expect(picker.mentionsIn(text.text), [const Mention(id: 'u-rahul', name: 'Rahul Sharma')]);
      expect(focus.hasFocus, isTrue, reason: 'the keyboard stays up');
    });

    testWidgets('no match says "No one found"; one letter says what to type', (tester) async {
      await pump(tester, search: (q) async => const []);
      await typeIn(tester, '@zz');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('No one found'), findsOneWidget);
      await typeIn(tester, '@z');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Type a name to tag someone.'), findsOneWidget);
    });

    testWidgets('a failed search says so', (tester) async {
      await pump(tester, search: (q) async => throw StateError('offline'));
      await typeIn(tester, '@zz');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('mention-failed')), findsOneWidget);
    });

    testWidgets('Escape closes the list', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('field')));
      await typeIn(tester, '@ra');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('mention-panel')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byKey(const ValueKey('mention-panel')), findsNothing);
    });

    testWidgets('losing focus hides it, and so does the caret moving off the name', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('field')));
      await typeIn(tester, '@ra');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('mention-panel')), findsOneWidget);
      focus.unfocus();
      await tester.pump();
      expect(find.byKey(const ValueKey('mention-panel')), findsNothing);
    });
  });

  group('a tagged name in a post or a reply', () {
    testWidgets('is blue and tappable, and gives the member\'s id', (tester) async {
      final opened = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: MentionText(
              text: 'Thanks @Rahul Sharma and @Priya Nambiar, all done',
              style: const TextStyle(fontSize: 14),
              mentions: const [
                Mention(id: 'u-rahul', name: 'Rahul Sharma'),
                Mention(id: 'u-priya', name: 'Priya Nambiar'),
              ],
              onOpen: opened.add,
            ),
          ),
        ),
      );
      await tester.tapOnText(find.textRange.ofSubstring('@Priya Nambiar'));
      await tester.tapOnText(find.textRange.ofSubstring('@Rahul Sharma'));
      expect(opened, ['u-priya', 'u-rahul']);
      await tester.tapOnText(find.textRange.ofSubstring('all done'));
      expect(opened.length, 2, reason: 'the rest of the words is not a link');
    });

    testWidgets('a typed web address opens, beside a tagged name, with or without mentions', (tester) async {
      final opened = <String>[];
      final pages = <Uri>[];
      SiteRoutes.resolver = (uri) =>
          (context) async => pages.add(uri);
      addTearDown(() => SiteRoutes.resolver = null);
      const address = 'https://icr.org.in/community/digital-library-top-stats-d6a080';
      Future<void> pump(List<Mention> mentions) => tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: MentionText(
              text: '@Rahul Sharma shared $address, thanks @Priya Nambiar',
              style: const TextStyle(fontSize: 14),
              mentions: mentions,
              onOpen: opened.add,
            ),
          ),
        ),
      );

      await pump(const [Mention(id: 'u-rahul', name: 'Rahul Sharma'), Mention(id: 'u-priya', name: 'Priya Nambiar')]);
      await tester.tapOnText(find.textRange.ofSubstring(address));
      expect(pages.single.toString(), address);
      await tester.tapOnText(find.textRange.ofSubstring('@Priya Nambiar'));
      await tester.tapOnText(find.textRange.ofSubstring('@Rahul Sharma'));
      expect(opened, ['u-priya', 'u-rahul'], reason: 'the names around the address are still tagged');
      expect(pages.length, 1);
      await tester.tapOnText(find.textRange.ofSubstring('thanks'));
      expect(pages.length, 1, reason: 'the words around an address are not a link');

      // Untagged words with an address in them are linked as well; the comma stays text.
      await pump(const []);
      await tester.tapOnText(find.textRange.ofSubstring(address));
      expect(pages.length, 2);
      await tester.tapOnText(find.textRange.ofSubstring('@Priya Nambiar'));
      expect(opened.length, 2, reason: 'no mentions, so no tagged name');

      // Replaced by other words, the old taps are disposed with the widget.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('two namesakes either side of an address are told apart by order', (tester) async {
      final opened = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: MentionText(
              text: '@Raj Kumar then https://example.com/a and @Raj Kumar',
              style: const TextStyle(fontSize: 14),
              mentions: const [
                Mention(id: 'u-raj-1', name: 'Raj Kumar'),
                Mention(id: 'u-raj-2', name: 'Raj Kumar'),
              ],
              onOpen: opened.add,
            ),
          ),
        ),
      );
      final raj = find.textRange.ofSubstring('@Raj Kumar');
      expect(raj, findsNWidgets(2));
      await tester.tapOnText(raj.first);
      await tester.tapOnText(raj.last);
      expect(opened, ['u-raj-1', 'u-raj-2']);
    });

    testWidgets('without an opener, or without mentions, it is plain text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MentionText(
              text: 'Thanks @Rahul Sharma',
              style: TextStyle(fontSize: 14),
              mentions: [Mention(id: 'u-rahul', name: 'Rahul Sharma')],
            ),
          ),
        ),
      );
      expect(find.text('Thanks @Rahul Sharma'), findsOneWidget);
    });
  });
}
