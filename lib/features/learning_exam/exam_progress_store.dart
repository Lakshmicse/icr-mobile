import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'exam_models.dart';

/// An exam in flight, as it is kept so a sitting survives the app being
/// closed or killed: which paper (with the very questions served, so a
/// randomised paper resumes in the order the candidate saw), when the clock
/// started, where they were, and what they had answered and flagged.
///
/// Local by design: an unsent sitting is not a result.
class ExamSnapshot {
  const ExamSnapshot({
    required this.userId,
    required this.sitting,
    required this.startedAtMs,
    required this.currentIndex,
    required this.answers,
    required this.flagged,
    required this.visited,
  });

  final String userId;
  final PaperSitting sitting;

  /// Epoch ms the clock started; the time left is always derived from it.
  final int startedAtMs;
  final int currentIndex;

  /// Question id to the option indexes picked.
  final Map<String, List<int>> answers;
  final List<String> flagged;
  final List<String> visited;

  DateTime get startedAt => DateTime.fromMillisecondsSinceEpoch(startedAtMs);
  DateTime get deadline => startedAt.add(sitting.paper.duration);

  Map<String, dynamic> toJson() => {
    'v': 1,
    'userId': userId,
    'sitting': sitting.toJson(),
    'startedAt': startedAtMs,
    'current': currentIndex,
    'answers': answers,
    'flagged': flagged,
    'visited': visited,
  };

  /// Null for anything that does not read back as a sitting.
  static ExamSnapshot? tryParse(String raw) {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (j['v'] != 1) return null;
      final sitting = PaperSitting.fromJson(j['sitting'] as Map<String, dynamic>);
      if (sitting.questions.isEmpty) return null;
      return ExamSnapshot(
        userId: j['userId'] as String? ?? '',
        sitting: sitting,
        startedAtMs: (j['startedAt'] as num).toInt(),
        currentIndex: ((j['current'] as num?)?.toInt() ?? 0).clamp(0, sitting.questions.length - 1),
        answers: {
          for (final e in (j['answers'] as Map<String, dynamic>? ?? const {}).entries)
            e.key: [for (final i in e.value as List) (i as num).toInt()],
        },
        flagged: [for (final s in j['flagged'] as List? ?? const []) s.toString()],
        visited: [for (final s in j['visited'] as List? ?? const []) s.toString()],
      );
    } catch (_) {
      return null;
    }
  }
}

/// Keeps an unsent sitting between launches. One per member and paper.
abstract class ExamProgressStore {
  Future<ExamSnapshot?> load(String userId, String slug);

  /// Writes the sitting; a later call replaces it.
  Future<void> save(ExamSnapshot snapshot);

  Future<void> clear(String userId, String slug);
}

/// In memory only: tests, and a fallback when the keystore is unavailable.
class MemoryExamProgressStore implements ExamProgressStore {
  final Map<String, String> _raw = {};
  int writes = 0;

  static String keyOf(String userId, String slug) => 'icr.exam.$userId.$slug';

  @override
  Future<ExamSnapshot?> load(String userId, String slug) async {
    final raw = _raw[keyOf(userId, slug)];
    return raw == null ? null : ExamSnapshot.tryParse(raw);
  }

  @override
  Future<void> save(ExamSnapshot snapshot) async {
    writes++;
    _raw[keyOf(snapshot.userId, snapshot.sitting.paper.slug)] = jsonEncode(snapshot.toJson());
  }

  @override
  Future<void> clear(String userId, String slug) async => _raw.remove(keyOf(userId, slug));
}

/// The platform keystore (as the session's tokens are), with a copy in memory
/// so a failed write or read never loses the sitting for the running app.
class SecureExamProgressStore implements ExamProgressStore {
  SecureExamProgressStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  final MemoryExamProgressStore _memory = MemoryExamProgressStore();

  @override
  Future<ExamSnapshot?> load(String userId, String slug) async {
    final inMemory = await _memory.load(userId, slug);
    if (inMemory != null) return inMemory;
    try {
      final raw = await _storage.read(key: MemoryExamProgressStore.keyOf(userId, slug));
      return raw == null ? null : ExamSnapshot.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(ExamSnapshot snapshot) async {
    await _memory.save(snapshot);
    try {
      await _storage.write(
        key: MemoryExamProgressStore.keyOf(snapshot.userId, snapshot.sitting.paper.slug),
        value: jsonEncode(snapshot.toJson()),
      );
    } catch (_) {
      // The copy in memory still holds the sitting for this run.
    }
  }

  @override
  Future<void> clear(String userId, String slug) async {
    await _memory.clear(userId, slug);
    try {
      await _storage.delete(key: MemoryExamProgressStore.keyOf(userId, slug));
    } catch (_) {}
  }
}
