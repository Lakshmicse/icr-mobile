import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/directory/companies_directory_screen.dart';
import 'package:icr_mobile/features/membership/plan_benefits_screen.dart';
import 'package:icr_mobile/features/site/reviews_screen.dart';

/// The four pages of a member's workspaces the app now draws itself instead of handing to the website (owner, 4 Nov
/// 2026): the companies directory, what the plans include, credits and redemptions, and reviews.
void main() {
  group('the companies directory', () {
    test("an enum reads as words, its initialisms kept", () {
      expect(enumWords('FM_SERVICES'), 'FM services');
      expect(enumWords('CORPORATE_OCCUPIER'), 'Corporate occupier');
      expect(enumWords('HVAC'), 'HVAC');
    });

    test('a row says the industry and the place', () {
      final c = DirectoryCompany.fromJson({
        'id': 'c1',
        'name': 'Northwind Facilities',
        'industry': 'FM_SERVICES',
        'city': 'Pune',
        'country': 'India',
        'openJobs': 3,
        'verificationStatus': 'VERIFIED',
      });
      expect(c.line, 'FM services · Pune, India');
      expect(c.openJobs, 3);
      expect(c.verified, isTrue);
      expect(DirectoryCompany.fromJson({'id': 'c2', 'name': 'Bare'}).line, '');
    });
  });

  group('what my plans include', () {
    test('a benefit says which plan gives it, in the website\'s words', () {
      PlanBenefit? b(Map<String, dynamic> source, {String kind = 'LIMIT', bool shown = true}) => PlanBenefit.fromJson({
        'label': 'Job applications',
        'text': 'Unlimited job applications',
        'kind': kind,
        'area': 'JOBS',
        'shown': shown,
        'source': source,
      });
      expect(b({'type': 'PLAN', 'planName': 'Pro', 'via': 'PERSONAL'})!.from, 'From your Pro plan');
      expect(b({'type': 'PLAN', 'planName': 'Gold', 'via': 'COMPANY'})!.from, "From your company's Gold plan");
      expect(b({'type': 'FREE_PLAN', 'planName': 'Free'})!.from, 'From the free plan (Free)');
      expect(b({'type': 'GRANT'})!.from, 'Extra from ICR');
      expect(b({'type': 'PLAN', 'planName': 'Pro'})!.line, 'Unlimited job applications');
      expect(
        b({'type': 'PLAN', 'planName': 'Pro'}, kind: 'FLAG')!.line,
        'Job applications',
        reason: 'a flag reads as its label',
      );
      expect(b({'type': 'PLAN'}, shown: false), isNull, reason: 'what the website hides stays hidden');
    });
  });

  test('a review keeps its stars, subject, comment and tone', () {
    final r = PlatformReview.fromJson({
      'id': 'r1',
      'score': 4,
      'targetType': 'vendor',
      'comment': 'Quick to respond.',
      'sentiment': 'POSITIVE',
      'createdAt': '2026-11-04T10:00:00Z',
    });
    expect(r.score, 4);
    expect(r.targetType, 'vendor');
    expect(r.sentiment, 'POSITIVE');
    expect(r.at, isNotNull);
  });
}
