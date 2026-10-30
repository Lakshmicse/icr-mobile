import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/app_screens.dart';
import 'package:icr_mobile/features/feed/feed_models.dart';

/// Which pages of the website the app opens itself. A page that resolves here never reaches the web view, so a
/// "Know more" on a cohort card or a "Verify online" lands on the app's own screen.
void main() {
  const viewer = FeedAuthor(id: 'u1', name: 'Bharat Buyer');
  Uri site(String path) => Uri.parse('https://icr.org.in$path');

  group('signed in, the mentoring records the notification router already opens', () {
    for (final path in [
      '/mentorship/programmes/leadership-cohort',
      '/mentorship/groups/g-paid',
      '/mentorship/my/pair-1',
    ]) {
      test(path, () => expect(inAppSiteRoute(site(path), viewer: viewer), isNotNull));
    }

    test('the programme list and the directory still resolve', () {
      expect(inAppSiteRoute(site('/mentorship/programmes'), viewer: viewer), isNotNull);
      expect(inAppSiteRoute(site('/mentorship/mentors/m1'), viewer: viewer), isNotNull);
    });

    test('a page the app has no screen for is left to the web view', () {
      expect(inAppSiteRoute(site('/manage/articles'), viewer: viewer), isNull);
      // The public certificate check: the only link to it is the member's own certificates tab.
      expect(inAppSiteRoute(site('/mentorship/certificates/ICR-MC-2026-AB12'), viewer: viewer), isNull);
    });
  });

  group('signed out, only the legal pages are the app\'s own', () {
    test('Terms of Service and Privacy Policy', () {
      expect(signedOutSiteRoute(site('/terms')), isNotNull);
      expect(signedOutSiteRoute(site('/privacy')), isNotNull);
    });

    test('anything else stays with the phone', () {
      expect(signedOutSiteRoute(site('/jobs')), isNull);
      expect(signedOutSiteRoute(site('/')), isNull);
    });
  });
}
