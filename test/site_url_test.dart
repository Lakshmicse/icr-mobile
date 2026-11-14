import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/auth/social_sign_in.dart';
import 'package:icr_mobile/core/config.dart';

/// The owner, 14 Nov 2026: the app's links follow the server it talks to, dev.icr.org.in on a dev build and
/// icr.org.in on a production one, with no second address to keep in step.
void main() {
  group('the website follows the API', () {
    test('a dev build links to dev, a production build to production', () {
      expect(AppConfig.siteFor(site: '', api: 'https://dev.icr.org.in/api/v1'), 'https://dev.icr.org.in');
      expect(AppConfig.siteFor(site: '', api: 'https://icr.org.in/api/v1'), 'https://icr.org.in');
    });

    test('an explicit SITE_URL still wins, without a trailing slash', () {
      expect(
        AppConfig.siteFor(site: 'https://staging.example.org/', api: 'https://dev.icr.org.in/api/v1'),
        'https://staging.example.org',
      );
    });

    test('a local API, or none, keeps production\'s website', () {
      expect(AppConfig.siteFor(site: '', api: 'http://10.0.2.2:3001/api/v1'), AppConfig.productionSite);
      expect(AppConfig.siteFor(site: '', api: ''), AppConfig.productionSite);
    });
  });

  group('social sign-in returns to the app the way the server allows', () {
    test('production uses the website\'s verified return; dev and a local API the app\'s own', () {
      expect(SocialSignIn.flowFor(api: 'https://icr.org.in/api/v1', site: 'https://icr.org.in'), SocialFlow.website);
      expect(
        SocialSignIn.flowFor(api: 'https://dev.icr.org.in/api/v1', site: 'https://dev.icr.org.in'),
        SocialFlow.appRedirect,
      );
      expect(
        SocialSignIn.flowFor(api: 'http://10.0.2.2:3001/api/v1', site: 'https://icr.org.in'),
        SocialFlow.appRedirect,
      );
    });
  });
}
