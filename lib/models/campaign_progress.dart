import 'dungeon_config.dart';
import 'daily_challenge.dart';

class CampaignProgress {
  final int unlockedDungeonIndex;
  final Map<int, int> dungeonLevelProgress;
  final int lives;
  final int coins;
  final int score;
  final int hintCharges;

  // Shop / artifact fields (persisted across runs)
  final int totalCoins;       // Lifetime coins earned across all runs (v2+)
  final Set<String> artifactsUnlocked; // e.g. {'extra_hint', 'lives_boost'}
  final List<DailyChallengeProgress> dailyChallengeHistory; // (v3+)
  final bool deeperDescentUnlocked; // (v4+)
  final int deeperDescentLevel;     // (v4+) current NG+ level (0 = not started)

  const CampaignProgress({
    required this.unlockedDungeonIndex,
    required this.dungeonLevelProgress,
    required this.lives,
    required this.coins,
    required this.score,
    required this.hintCharges,
    required this.totalCoins,
    required this.artifactsUnlocked,
    this.dailyChallengeHistory = const [],
    this.deeperDescentUnlocked = false,
    this.deeperDescentLevel = 0,
  });

  factory CampaignProgress.fromJson(Map<String, Object?> json) {
    final rawProgress = json['dungeonLevelProgress'];
    final progress = <int, int>{};

    if (rawProgress is Map) {
      for (final entry in rawProgress.entries) {
        final dungeonIndex = int.tryParse(entry.key.toString());
        final level = entry.value;
        if (dungeonIndex != null && level is num) {
          progress[dungeonIndex] = level.toInt();
        }
      }
    }

    // Parse artifacts: can be a List<String> in JSON (v2+)
    final rawArtifacts = json['artifactsUnlocked'];
    Set<String> artifacts;
    if (rawArtifacts is List) {
      artifacts = rawArtifacts.map((e) => e.toString()).toSet();
    } else {
      artifacts = {}; // v1 migration: no artifacts
    }

    final rawDailyHistory = json['dailyChallengeHistory'];
    final List<DailyChallengeProgress> dailyHistory;
    if (rawDailyHistory is List) {
      dailyHistory = rawDailyHistory
          .map((e) => DailyChallengeProgress.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } else {
      dailyHistory = [];
    }

    return CampaignProgress(
      unlockedDungeonIndex: _readInt(json['unlockedDungeonIndex']),
      dungeonLevelProgress: progress,
      lives: _readInt(json['lives'], fallback: 3),
      coins: _readInt(json['coins']),
      score: _readInt(json['score']),
      hintCharges: _readInt(json['hintCharges'], fallback: 1),
      totalCoins: _readInt(json['totalCoins'], fallback: 0), // v1 -> 0
      artifactsUnlocked: artifacts,
      dailyChallengeHistory: dailyHistory,
      deeperDescentUnlocked: json['deeperDescentUnlocked'] == true,
      deeperDescentLevel: _readInt(json['deeperDescentLevel'], fallback: 0),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'version': 4,
      'unlockedDungeonIndex': unlockedDungeonIndex,
      'dungeonLevelProgress': dungeonLevelProgress.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      'lives': lives,
      'coins': coins,
      'score': score,
      'hintCharges': hintCharges,
      'totalCoins': totalCoins,
      'artifactsUnlocked': artifactsUnlocked.toList(),
      'dailyChallengeHistory': dailyChallengeHistory.map((d) => d.toJson()).toList(),
      'deeperDescentUnlocked': deeperDescentUnlocked,
      'deeperDescentLevel': deeperDescentLevel,
    };
  }

  static int _readInt(Object? value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static int nextUnfinishedDungeonIndex(Map<int, int> progress) {
    for (var i = 0; i < DungeonConfig.dungeons.length; i++) {
      if ((progress[i] ?? 0) < DungeonConfig.levelsPerDungeon) {
        return i;
      }
    }
    return DungeonConfig.dungeons.length - 1;
  }

  static int nextUnfinishedLevelForDungeon(
    Map<int, int> progress,
    int dungeonIndex,
  ) {
    final clearedLevel = progress[dungeonIndex] ?? 0;
    if (clearedLevel >= DungeonConfig.levelsPerDungeon) {
      return DungeonConfig.levelsPerDungeon;
    }
    return clearedLevel + 1;
  }
}
