import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Local high score tracking per dungeon-level combination.
class HighScoreService {
  static final HighScoreService _instance = HighScoreService._internal();
  factory HighScoreService() => _instance;
  HighScoreService._internal();

  Map<String, int> _scores = {}; // key: "dungeonId_levelIndex" -> best score
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await _loadScores();
    _initialized = true;
  }

  Future<void> _loadScores() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/high_scores.json');
      if (!file.existsSync()) return;

      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      _scores = {};
      for (final entry in data.entries) {
        final parsed = int.tryParse(entry.value.toString());
        if (parsed != null) {
          _scores[entry.key] = parsed;
        }
      }
    } catch (e) {
      // Corrupted file — reset to defaults
      _scores = {};
    }
  }

  Future<void> _saveScores() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/high_scores.json');

      // Clean up: only keep scores > 0
      final cleanScores = <String, int>{};
      for (final entry in _scores.entries) {
        if (entry.value > 0) cleanScores[entry.key] = entry.value;
      }

      await file.writeAsString(jsonEncode(cleanScores));
    } catch (e) {
      // Silently fail — not critical
    }
  }

  String _keyFor(String dungeonId, int levelIndex) => '${dungeonId}_$levelIndex';

  /// Records a score only if it beats the previous best.
  void recordScore(String dungeonId, int levelIndex, int score) {
    final key = _keyFor(dungeonId, levelIndex);

    // Only record if it's better than previous or first time
    final currentBest = _scores[key] ?? 0;
    if (score > currentBest) {
      _scores[key] = score;
      unawaited(_saveScores());
    }
  }

  /// Returns the best score for a dungeon-level, or null if none recorded.
  int? getBestScore(String dungeonId, int levelIndex) =>
      _scores[_keyFor(dungeonId, levelIndex)];

  /// Returns all recorded scores.
  Map<String, int> getAllScores() => Map.unmodifiable(_scores);

  /// Returns top N scores across all dungeons, sorted by score descending.
  List<MapEntry<String, int>> getTopScores([int limit = 10]) {
    final sorted = _scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).toList();
  }

  /// Resets all high scores.
  void resetAll() {
    _scores.clear();
  }
}