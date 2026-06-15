import 'dungeon_config.dart';

/// Represents a unique daily dungeon challenge with deterministic seed.
class DailyChallenge {
  final DateTime date;           // Truncated to UTC midnight
  final int seed;               // Deterministic seed from date
  final String dungeonId;       // Which dungeon theme to use
  final int baseGridSize;       // Base grid pairs for the challenge
  final List<LevelModifier> modifiers; // Active modifiers today
  final bool hasMismatchPenalty; // Override mismatch penalty

  const DailyChallenge({
    required this.date,
    required this.seed,
    required this.dungeonId,
    required this.baseGridSize,
    required this.modifiers,
    required this.hasMismatchPenalty,
  });

  /// Simple hash: deterministic from date, reproducible across platforms.
  static int _seedForDate(DateTime date) {
    final hashCode = date.year * 367;
    return ((hashCode + date.month * 31) * 31 + date.day) % 100000;
  }

  /// Generates a daily challenge for a given date.
  static DailyChallenge generateForDate(DateTime date) {
    final seed = _seedForDate(date);

    final dungeonIds = <String>[
      'stone', 'lava', 'ice', 'crypt', 'voidChamber', 'forest',
    ];
    final dungeonId = dungeonIds[seed % dungeonIds.length];

    final modSeed = (seed ~/ dungeonIds.length) % 256;

    // Pick modifier
    List<LevelModifier> modifiers;
    switch (modSeed % 5) {
      case 0:
        modifiers = [LevelModifier.none];
        break;
      case 1:
        modifiers = [LevelModifier.shadow];
        break;
      case 2:
        modifiers = [LevelModifier.timer];
        break;
      case 3:
        modifiers = [LevelModifier.swap];
        break;
      default:
        modifiers = [LevelModifier.sabotage];
    }

    // 1-in-5 chance of brutal double modifier
    if (modSeed % 25 == 0) {
      // Avoid stacking shadow on shadow
      if (modifiers.first != LevelModifier.shadow) {
        modifiers.add(LevelModifier.shadow);
      }
    }

    return DailyChallenge(
      date: truncateToMidnight(date),
      seed: seed,
      dungeonId: dungeonId,
      baseGridSize: 6 + (seed % 4), // 6–9 pairs
      modifiers: modifiers,
      hasMismatchPenalty: modSeed > 200,
    );
  }

  static DateTime truncateToMidnight(DateTime dt) =>
      DateTime.utc(dt.year, dt.month, dt.day);

  /// Returns today's challenge.
  static DailyChallenge getToday() => generateForDate(DateTime.now());

  /// Human-readable dungeon name.
  String get dungeonName {
    switch (dungeonId) {
      case 'stone':
        return 'Stone Chamber';
      case 'lava':
        return 'Lava Chamber';
      case 'ice':
        return 'Ice Tomb';
      case 'crypt':
        return 'Crypt';
      case 'voidChamber':
        return 'Void Chamber';
      case 'forest':
        return 'Whispering Hollow';
      default:
        return 'Unknown Chamber';
    }
  }

  /// Human-readable modifier badge text.
  String get modifierText {
    final names = modifiers.map((m) => m.name).toList();
    return names.join(' + ');
  }

  /// Emoji for the dungeon.
  String get dungeonEmoji {
    switch (dungeonId) {
      case 'stone':
        return '🔑';
      case 'lava':
        return '🌋';
      case 'ice':
        return '❄️';
      case 'crypt':
        return '⚰️';
      case 'voidChamber':
        return '🪐';
      case 'forest':
        return '🌲';
      default:
        return '❓';
    }
  }
}

/// Persisted result of a daily challenge attempt.
class DailyChallengeProgress {
  final String date;              // "YYYY-MM-DD"
  final int score;                // 0 = not attempted
  final bool isCompleted;         // Cleared?
  final int livesRemaining;       // Lives left when cleared (or 0)

  const DailyChallengeProgress({
    required this.date,
    required this.score,
    required this.isCompleted,
    required this.livesRemaining,
  });

  DailyChallengeProgress copyWith({
    int? score,
    bool? isCompleted,
    int? livesRemaining,
  }) {
    return DailyChallengeProgress(
      date: date,
      score: score ?? this.score,
      isCompleted: isCompleted ?? this.isCompleted,
      livesRemaining: livesRemaining ?? this.livesRemaining,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'score': score,
        'isCompleted': isCompleted,
        'livesRemaining': livesRemaining,
      };

  factory DailyChallengeProgress.fromJson(Map<String, dynamic> json) {
    return DailyChallengeProgress(
      date: json['date'] as String,
      score: json['score'] as int? ?? 0,
      isCompleted: json['isCompleted'] as bool? ?? false,
      livesRemaining: json['livesRemaining'] as int? ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyChallengeProgress && date == other.date;

  @override
  int get hashCode => date.hashCode;
}