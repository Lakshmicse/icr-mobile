import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/feed/repost_quote.dart';

void main() {
  group('RepostQuote', () {
    test('reads the author, title and slug of an instant repost, with no words left over', () {
      final q = RepostQuote.of(
        '↻ Reposted from Sarah Jenkins\n“IoT sensors for HVAC”\nhttps://icr.org.in/community/slug-iot',
      );
      expect(q, isNotNull);
      expect(q!.author, 'Sarah Jenkins');
      expect(q.title, 'IoT sensors for HVAC');
      expect(q.slug, 'slug-iot');
      expect(q.rest, '');
    });

    test('keeps the reposter\'s own words, before or after the quote, and reads paragraph breaks', () {
      final q = RepostQuote.of(
        'Worth a read.\n\n↻ Reposted from Sarah Jenkins\n\n“IoT sensors for HVAC”\n\nhttps://icr.org.in/community/slug-iot\n\nAnd my take.',
      );
      expect(q!.slug, 'slug-iot');
      expect(q.rest, 'Worth a read.\n\nAnd my take.');
    });

    test('a link with a fragment or query still names the discussion', () {
      expect(RepostQuote.of('↻ Reposted from A\n“T”\nhttps://icr.org.in/community/my-post#reply-1')!.slug, 'my-post');
    });

    test('ordinary words are no quote', () {
      expect(RepostQuote.of('Reposted from nobody, really: https://icr.org.in/community/x'), isNull);
      expect(RepostQuote.of(''), isNull);
    });
  });
}
