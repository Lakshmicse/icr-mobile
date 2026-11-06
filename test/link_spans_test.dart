import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/util/link_spans.dart';

void main() {
  test('a typed address becomes a link, its trailing punctuation stays text', () {
    final parts = splitLinks('See https://icr.org.in/community/digital-library-top-stats-d6a080. Thanks');
    expect([for (final p in parts) p.text], [
      'See ',
      'https://icr.org.in/community/digital-library-top-stats-d6a080',
      '.',
      ' Thanks',
    ]);
    expect(parts[1].link.toString(), 'https://icr.org.in/community/digital-library-top-stats-d6a080');
    expect(parts[0].link, isNull);
  });

  test('www. gains https, and text with no address is one plain run', () {
    final parts = splitLinks('(www.example.org/x)');
    expect(parts[1].link.toString(), 'https://www.example.org/x');
    expect([for (final p in parts) p.text], ['(', 'www.example.org/x', ')']);
    expect(splitLinks('no links here'), [(text: 'no links here', link: null)]);
    expect(LinkSpans.hasLink('no links here'), isFalse);
    expect(LinkSpans.hasLink('go to http://a.b'), isTrue);
  });
}
