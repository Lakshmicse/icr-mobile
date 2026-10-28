@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/site/advertise_screen.dart';
import 'package:icr_mobile/features/site/blog_screens.dart';
import 'package:icr_mobile/features/site/partner_apply_screen.dart';
import 'package:icr_mobile/features/site/refer_screen.dart';

import 'live.dart';

/// The website's small pages, read from the local API as the app draws them: every parser on what the API really
/// answers. Reads only (nothing is sent, no application is filed).
///
/// Run: `flutter test test/live/site_pages_live_test.dart --concurrency=1`
void main() {
  liveTest('the blog: the list reads and a post comes back with its body and author', () async {
    final repo = ApiBlogRepository(await liveClient());
    final posts = await repo.posts();
    expect(posts, isNotEmpty, reason: 'the seed publishes "Welcome to ICR"');
    for (final p in posts) {
      expect(p.slug, isNotEmpty);
      expect(p.title, isNotEmpty);
      expect(p.author, isNotEmpty);
    }
    final post = await repo.post(posts.first.slug);
    expect(post.title, posts.first.title);
    expect(post.content, isNotEmpty);
  });

  liveTest('the invitations: code, link, the programme\'s words and the counts read', () async {
    final mine = await ApiReferralsRepository(await liveClient()).mine();
    expect(mine.code, isNotEmpty);
    expect(mine.link, contains(mine.code.substring(0, 4)));
    expect(mine.shareText, isNotEmpty);
    expect(mine.invited, greaterThanOrEqualTo(0));
    expect(mine.verified, lessThanOrEqualTo(mine.invited));
  });

  liveTest('advertise: both placements are described, a quote is optional, and the placements list reads', () async {
    final data = await ApiAdvertiseRepository(await liveClient()).read();
    expect(data.offers.map((o) => o.sku), ['DIRECTORY', 'HERO']);
    for (final o in data.offers) {
      expect(o.title, isNotEmpty);
      expect(o.body, isNotEmpty);
      // A member with nothing to promote has no quote; one with a listing has a price per month.
      if (o.monthlyPaisa != null) expect(o.monthlyPaisa, greaterThan(0));
    }
    expect(data.mine, isA<List<MyPlacement>>());
  });

  liveTest('become a partner: the companies the member administers read (none for a buyer without one)', () async {
    final companies = await ApiPartnerApplyRepository(await liveClient()).companies();
    expect(companies, isA<List<PartnerCompany>>());
    for (final c in companies) {
      expect(c.id, isNotEmpty);
      expect(c.name, isNotEmpty);
    }
  });
}
