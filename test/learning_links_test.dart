import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/features/feed/feed_models.dart' show FeedPicture;
import 'package:icr_mobile/features/learning/learning_links.dart';
import 'package:icr_mobile/features/learning/opened_learning.dart';
import 'package:icr_mobile/features/learning_assess/api_assess_repository.dart';
import 'package:icr_mobile/features/learning_assess/assess_models.dart';
import 'package:icr_mobile/features/learning_hub/hub_styles.dart';
import 'package:icr_mobile/features/learning_hub/widgets/learn_card.dart';
import 'package:icr_mobile/features/learning_study/study_models.dart';

import 'live/live.dart' show MemoryTokens;

/// The learning cards' share disc and their "Credits" label (owner, 12 Nov 2026: "Credits should be small and the
/// Share option is not working").
void main() {
  const level = AssessPaper(id: 'p1', slug: 'foundation', title: 'Foundation', kind: PaperKind.assessment);
  const set1 = AssessPaper(id: 'p2', slug: 'set-1', title: 'Set 1', kind: PaperKind.mock);
  const programme = PaperGroup(kind: PaperKind.assessment, id: 'c1', key: 'CAPPLAN', title: 'Capital Planning');
  const subject = PaperGroup(kind: PaperKind.mock, id: 't1', key: 'aee-cbcp', title: 'AEE CBCP');
  const deck = StudyTopic(id: 'd1', slug: 'capital-planning', title: 'Capital Planning', kind: StudyKind.qna);

  group('LearningLinks', () {
    test("a programme's and a mock subject's pages, and one level or set, are the assessments repository's own", () {
      final repo = ApiAssessRepository(
        api: ApiClient(tokens: MemoryTokens(), baseUrl: 'http://api.test/api/v1'),
      );
      expect(LearningLinks.group(programme), repo.groupLink(programme));
      expect(LearningLinks.group(subject), repo.groupLink(subject));
      expect(LearningLinks.paper(programme, level), repo.paperLink(programme, level));
      expect(LearningLinks.paper(subject, set1), repo.paperLink(subject, set1));
      expect(LearningLinks.group(programme).path, '/learning/assessment/capplan');
      expect(LearningLinks.paper(subject, set1).path, '/learning/mock-tests/aee-cbcp/set-1');
    });

    test("a deck's page is its shelf on the website; an opened item links to what it holds", () {
      expect(LearningLinks.deck(deck).path, '/learning/resources/capital-planning');
      expect(const OpenedItem(deck: deck, via: OpenedVia.plan).link.path, '/learning/resources/capital-planning');
      expect(
        const OpenedItem(group: subject, paper: set1, via: OpenedVia.credits).link.path,
        '/learning/mock-tests/aee-cbcp/set-1',
      );
      expect(const OpenedItem(group: programme, via: OpenedVia.plan).link.path, '/learning/assessment/capplan');
    });
  });

  group('LearnCard', () {
    final shared = <Map<String, dynamic>>[];
    setUp(() {
      shared.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/share'),
        (call) async {
          shared.add(Map<String, dynamic>.from(call.arguments as Map));
          return null;
        },
      );
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/share'),
        null,
      );
    });

    Future<List<String>> pumpCard(WidgetTester tester, {String? tag, String? badge, bool share = true}) async {
      final opened = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 171,
                child: LearnCard(
                  title: 'AEE CBCP · Set 1',
                  cover: const FeedPicture.asset('assets/images/demo/post_green_tower.jpg'),
                  tag: tag,
                  badge: badge,
                  onTap: () => opened.add('card'),
                  onShare: share
                      ? () => shareLearningLink('AEE CBCP · Set 1', LearningLinks.paper(subject, set1))
                      : null,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return opened;
    }

    testWidgets('"Credits" is a small corner label, not the ICR tab\'s large type', (tester) async {
      await pumpCard(tester, tag: 'Credits');
      final text = tester.widget<Text>(find.text('Credits'));
      expect(text.style, HubText.tag);
      expect(HubText.tag.fontSize, lessThan(HubText.badge.fontSize!));
      expect(tester.getSize(find.text('Credits')).height, lessThan(18));
      expect(tester.takeException(), isNull);
    });

    testWidgets("the share disc opens the phone's share sheet with the name and the page, and does not open the card", (
      tester,
    ) async {
      final opened = await pumpCard(tester, tag: 'Credits');
      await tester.tap(find.byKey(const ValueKey('learn-card-share')));
      await tester.pump();
      expect(shared, hasLength(1));
      expect(shared.single['text'], contains('AEE CBCP · Set 1'));
      expect(shared.single['text'], contains('/learning/mock-tests/aee-cbcp/set-1'));
      expect(opened, isEmpty, reason: 'the disc shares; only the rest of the card opens it');
      expect(tester.getSize(find.byKey(const ValueKey('learn-card-share'))), const Size(36, 36));
    });

    testWidgets('a card with nothing to share draws no disc', (tester) async {
      await pumpCard(tester, share: false);
      expect(find.byKey(const ValueKey('learn-card-share')), findsNothing);
    });
  });
}
