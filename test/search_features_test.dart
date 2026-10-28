import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/search/feature_catalogue.dart';

List<String> ids(String q, {Set<String>? available}) =>
    matchFeatures(q, available: available).map((m) => m.feature.id).toList();

void main() {
  group('the feature catalogue', () {
    test('every entry has a unique id, a title, a subtitle and keywords', () {
      final seen = <String>{};
      for (final f in featureCatalogue) {
        expect(seen.add(f.id), isTrue, reason: 'duplicate id ${f.id}');
        expect(f.title.trim(), isNotEmpty);
        expect(f.subtitle.trim(), isNotEmpty);
        expect(f.keywords.trim(), isNotEmpty);
      }
    });

    test('names the places a person goes in the app', () {
      final all = featureCatalogue.map((f) => f.id).toSet();
      expect(
        all,
        containsAll([
          'jobs', 'learning', 'mentorship', 'marketplace', 'forums', 'find_mentors', 'mock', 'flash', 'events',
          'councils', 'chapters', 'library', 'plans', 'settings', 'messages', 'notifications', 'profile',
          'applications',
        ]),
      );
    });
  });

  group('matching a query', () {
    test('an empty query matches nothing', () {
      expect(ids(''), isEmpty);
      expect(ids('   '), isEmpty);
    });

    test('a feature named exactly comes first, at 100', () {
      final m = matchFeatures('jobs');
      expect(m.first.feature.id, 'jobs');
      expect(m.first.score, 100);
      expect(m.first.strong, isTrue);
    });

    test('a word of the name is a strong match: "plans" finds Membership & plans before anything else', () {
      expect(ids('plans').first, 'plans');
      expect(ids('mentor'), containsAll(['find_mentors', 'become_mentor', 'mentorship']));
    });

    test('a prefix finds it from the first letters', () {
      expect(ids('mock'), contains('mock'));
      expect(ids('cert'), contains('certificates'));
      expect(ids('j').first, isIn(['jobs', 'job_alerts', 'saved_jobs', 'posted_jobs']));
    });

    test('the words people use, not the name: synonyms reach the same place', () {
      expect(ids('vacancies').first, 'jobs');
      expect(ids('cv'), contains('profile'));
      expect(ids('invoice'), contains('plan_history'));
      expect(ids('webinar'), contains('events'));
      expect(ids('volunteer'), contains('get_involved'));
      expect(ids('rfq'), containsAll(['post_rfq', 'my_rfqs']));
      expect(ids('password'), contains('settings'));
    });

    test('every word of a longer query has to match', () {
      expect(ids('post requirement').first, 'post_rfq');
      expect(ids('saved jobs').first, 'saved_jobs');
      expect(ids('exam attempts').first, 'attempts');
      expect(ids('jobs zzzqq'), isEmpty);
    });

    test('case, punctuation and spacing do not matter', () {
      expect(ids('  MENTOR   desk! ').first, 'mentor_desk');
      expect(ids('Flash-Cards').first, 'flash');
    });

    test('a name beats a keyword: "mentor" lists the pages named for it before the ones that only mention it', () {
      final m = matchFeatures('mentor', limit: 20);
      final named = m.where((x) => x.feature.title.toLowerCase().contains('mentor')).map((x) => x.score).toList();
      final mentioned = m.where((x) => !x.feature.title.toLowerCase().contains('mentor')).map((x) => x.score).toList();
      expect(named, isNotEmpty);
      expect(mentioned, isNotEmpty, reason: 'pages that only carry the word as a keyword (Mentoring programmes, Group sessions...)');
      expect(named.reduce((a, b) => a < b ? a : b), greaterThan(mentioned.reduce((a, b) => a > b ? a : b)));
    });

    test('a singular finds the plural: "event" is Events', () {
      expect(ids('event').first, 'events');
    });

    test('nothing matches nonsense', () {
      expect(ids('xqzjv'), isEmpty);
    });

    test('limit caps the list', () {
      expect(matchFeatures('a', limit: 3).length, lessThanOrEqualTo(3));
    });
  });

  group('what the running app can open', () {
    test('a feature outside the available set is never offered', () {
      expect(ids('jobs', available: {'jobs'}), ['jobs']);
      expect(ids('jobs', available: {'learning'}), isEmpty);
      expect(ids('mentor', available: {'find_mentors'}), ['find_mentors']);
    });

    test('suggestions are the flagged few, and respect availability', () {
      final all = suggestedFeatures();
      expect(all.length, inInclusiveRange(4, 8));
      expect(all.every((f) => f.suggested), isTrue);
      expect(suggestedFeatures(available: {'jobs'}).map((f) => f.id), ['jobs']);
    });
  });
}
