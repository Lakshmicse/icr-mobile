import 'study_models.dart';

/// Where the study screens get their shelves and cards: the API, or a little sample content.
abstract class StudyRepository {
  /// Every published shelf, decks and formula groups together, without their cards. The caller keeps the kind it
  /// wants (`GET /learning/resources`).
  Future<List<StudyTopic>> topics();

  /// One shelf with its cards (`GET /learning/resources/:slug`). A flash-card deck counts against the member's
  /// plan: past its number the API refuses with `403 DECK_LOCKED`, thrown as [DeckLocked] with the API's own
  /// sentence. A formula shelf is never refused.
  Future<StudyTopic> topic(String slug);

  /// What the plan opens of the decks, or null when it cannot be read (the grid then marks nothing).
  Future<DeckPlan?> deckPlan();

  /// The member's starred cards, newest first, each carrying its shelf (`GET /learning/me/resource-stars`). The API
  /// leaves out a card on a deck the plan does not open.
  Future<List<StudyCard>> starredCards();

  /// Stars or unstars a card (`PUT` / `DELETE /learning/me/resource-stars/:cardId`). Starring is held to the same
  /// plan rule as reading, so it can be refused; taking a star back never is.
  Future<void> setStar(String cardId, bool starred);

  Future<int> unreadNotifications();

  /// The plans page the lock notice sends people to, on the website.
  Uri plansLink([String slug = 'professional']);
}
