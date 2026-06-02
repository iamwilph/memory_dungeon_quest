import 'dungeon_config.dart';

class CampaignProgress {
  final int unlockedDungeonIndex;
  final Map<int, int> dungeonLevelProgress;
  final int lives;
  final int coins;
  final int score;
  final int hintCharges;

  const CampaignProgress({
    required this.unlockedDungeonIndex,
    required this.dungeonLevelProgress,
    required this.lives,
    required this.coins,
    required this.score,
    required this.hintCharges,
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

    return CampaignProgress(
      unlockedDungeonIndex: _readInt(json['unlockedDungeonIndex']),
      dungeonLevelProgress: progress,
      lives: _readInt(json['lives'], fallback: 3),
      coins: _readInt(json['coins']),
      score: _readInt(json['score']),
      hintCharges: _readInt(json['hintCharges'], fallback: 1),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'version': 1,
      'unlockedDungeonIndex': unlockedDungeonIndex,
      'dungeonLevelProgress': dungeonLevelProgress.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      'lives': lives,
      'coins': coins,
      'score': score,
      'hintCharges': hintCharges,
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
