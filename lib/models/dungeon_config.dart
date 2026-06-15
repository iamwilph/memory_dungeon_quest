// Dungeon themes available in the game.
// The enum is updated to include a new `forest` variant.
// Each theme is used to drive UI colours and grid logic.

/// Level modifiers that change how the game is played within a dungeon.
enum LevelModifier { none, shadow, timer, swap, sabotage }

/// Modifier definitions per dungeon index.
const Map<int, List<_LevelModifierEntry>> _dungeonModifiers = {
  0: [ // Stone Chamber (B1) — gentle intro modifiers
    _LevelModifierEntry(8, LevelModifier.shadow),   // Level 8: some cards hidden
    _LevelModifierEntry(14, LevelModifier.swap),     // Level 14: board shuffles
    _LevelModifierEntry(18, LevelModifier.sabotage), // Level 18: fake pair
  ],
  1: [ // Lava Chamber (B2) — pressure modifiers
    _LevelModifierEntry(6, LevelModifier.timer),      // Level 6: cards auto-flip
    _LevelModifierEntry(12, LevelModifier.sabotage),  // Level 12: fake pairs
    _LevelModifierEntry(16, LevelModifier.shadow),     // Level 16: hidden cards
    _LevelModifierEntry(20, LevelModifier.swap),       // Final level: shuffle pressure
  ],
  2: [ // Ice Chamber (B3) — harsh modifiers
    _LevelModifierEntry(5, LevelModifier.timer),      // Early timer exposure
    _LevelModifierEntry(10, LevelModifier.sabotage),  // Mid-game visual trick
    _LevelModifierEntry(15, LevelModifier.shadow),     // Late-level hidden cards
    _LevelModifierEntry(20, LevelModifier.swap),       // Final: shuffle pressure
  ],
  3: [ // Crypt Chamber (B4) — brutal modifiers
    _LevelModifierEntry(5, LevelModifier.sabotage),   // Early deception
    _LevelModifierEntry(10, LevelModifier.swap),      // Mid-game shuffle
    _LevelModifierEntry(15, LevelModifier.timer),     // Late-level pressure
    _LevelModifierEntry(20, LevelModifier.shadow),    // Final: hidden cards
  ],
  4: [ // Void Chamber (B5) — mind-bending modifiers
    _LevelModifierEntry(4, LevelModifier.sabotage),   // Early deception
    _LevelModifierEntry(8, LevelModifier.shadow),     // Hidden cards pressure
    _LevelModifierEntry(12, LevelModifier.timer),     // Mid-game timing test
    _LevelModifierEntry(16, LevelModifier.swap),      // Chaos shuffle
    _LevelModifierEntry(20, LevelModifier.timer),     // Final: relentless pressure
  ],
};

class _LevelModifierEntry {
  final int level;
  final LevelModifier modifier;
  const _LevelModifierEntry(this.level, this.modifier);
}

enum DungeonThemeType { stone, lava, ice, crypt, voidChamber, forest }

/// Configuration for a single dungeon.
///
/// All dungeons share a common level structure – 20 levels – and the
/// following values are calculated based on the current level.
class DungeonConfig {
  final String id;
  final String name;
  final String depth;
  final String description;
  final List<String> emojiSet;
  final DungeonThemeType themeType;
  final int baseRewardCoins;
  final double baseScoreMultiplier;

  const DungeonConfig({
    required this.id,
    required this.name,
    required this.depth,
    required this.description,
    required this.emojiSet,
    required this.themeType,
    required this.baseRewardCoins,
    required this.baseScoreMultiplier,
  });

  // ---------------------------------------------------------------------------
  //  Utility helpers
  // ---------------------------------------------------------------------------

  /// Returns a `{rows, cols}` map for a specific level (1‑20).
  ///
  /// The stone and forest themes use identical grid rules; the other themes
  /// vary slightly for atmosphere.
  Map<String, int> getGridSizeForLevel(int level) {
    level = level.clamp(1, levelsPerDungeon); // Ensure level is within bounds.
    switch (themeType) {
      case DungeonThemeType.stone:
      case DungeonThemeType.forest:
      case DungeonThemeType.lava:
      case DungeonThemeType.ice:
      case DungeonThemeType.crypt:
      case DungeonThemeType.voidChamber:
        if (level <= 5) return {'rows': 4, 'cols': 3};
        if (level <= 10) return {'rows': 5, 'cols': 4};
        if (level <= 15) return {'rows': 6, 'cols': 5};
        return {'rows': 6, 'cols': 6};
    }
  }

  /// Whether a mismatch penalty applies for a given level.
  bool getMismatchPenaltyForLevel(int level) {
    switch (themeType) {
      case DungeonThemeType.stone:
      case DungeonThemeType.forest:
        return false; // No penalty for these themes.
      case DungeonThemeType.lava:
        return level >= 15; // Starts at level 15.
      case DungeonThemeType.ice:
      case DungeonThemeType.crypt:
      case DungeonThemeType.voidChamber:
        return true; // Always.
    }
  }

  /// Total matching pairs for a level.
  int getTotalPairsForLevel(int level) {
    final grid = getGridSizeForLevel(level);
    return (grid['rows']! * grid['cols']!) ~/ 2;
  }

  /// Scaled monster coin reward for a level.
  int getRewardCoinsForLevel(int level) {
    return baseRewardCoins + level * 2;
  }

  /// Scaled score multiplier for a level.
  double getScoreMultiplierForLevel(int level) {
    return baseScoreMultiplier * (1 + level * 0.05);
  }

  // ---------------------------------------------------------------------------
  //  Convenience getters for use in the UI.
  // ---------------------------------------------------------------------------

  static const int levelsPerDungeon = 20;

  /// Helper that returns the row count for the *final* level (maximum).
  int get rows => getGridSizeForLevel(levelsPerDungeon)['rows']!;

  /// Helper that returns the column count for the *final* level.
  int get cols => getGridSizeForLevel(levelsPerDungeon)['cols']!;

  /// Helper that returns the total pair count for the *final* level.
  int get totalPairs => getTotalPairsForLevel(levelsPerDungeon);

  /// Helper that indicates if the final level of this dungeon applies a penalty.
  bool get mismatchPenalty => getMismatchPenaltyForLevel(levelsPerDungeon);

  // ---------------------------------------------------------------------------
  //  Deeper Descent (New Game+) scaling
  // ---------------------------------------------------------------------------

  /// Deeper Descent grid size: enlarges the standard grid for a given level.
  Map<String, int> getDeepGridSizeForLevel(int level) {
    final base = getGridSizeForLevel(level);
    return {
      'rows': (base['rows']! + 1).clamp(4, 7),
      'cols': (base['cols']! + 1).clamp(3, 6),
    };
  }

  /// Deeper Descent row count for a given level.
  int deeperDescentRows(int level) => getDeepGridSizeForLevel(level)['rows']!;

  /// Deeper Descent column count for a given level.
  int deeperDescentCols(int level) => getDeepGridSizeForLevel(level)['cols']!;

  /// Deeper Descent total pairs for a given level.
  int getDeepTotalPairsForLevel(int level) {
    final grid = getDeepGridSizeForLevel(level);
    final total = grid['rows']! * grid['cols']!;
    // Ensure even tile count — if odd, drop one row to stay even.
    if (total.isOdd) {
      return ((grid['rows']! - 1) * grid['cols']!) ~/ 2;
    }
    return total ~/ 2;
  }

  /// Deeper Descent scaled reward (50% bonus).
  int getDeepRewardCoinsForLevel(int level) {
    return (getRewardCoinsForLevel(level) * 1.5).round();
  }

  /// Deeper Descent scaled score multiplier (25% bonus).
  double getDeepScoreMultiplierForLevel(int level) {
    return getScoreMultiplierForLevel(level) * 1.25;
  }

  /// Returns the active modifier for a given level in this dungeon.
  LevelModifier getModifierForLevel(int level) {
    final idx = DungeonConfig.dungeons.indexWhere((d) => d.id == id);
    if (idx == -1) return LevelModifier.none;

    final entries = _dungeonModifiers[idx] ?? [];
    for (final entry in entries) {
      if (entry.level == level) return entry.modifier;
    }
    return LevelModifier.none;
  }

  // ---------------------------------------------------------------------------
  //  Pre‑defined dungeons.
  // ---------------------------------------------------------------------------

  static const List<DungeonConfig> dungeons = [
    DungeonConfig(
      id: 'stone_chamber',
      name: 'Stone Chamber',
      depth: 'Depth B1',
      description:
          'A dusty stone vault covered in ancient carvings. A safe place to begin your descent.',
      emojiSet: ['🔑', '🧪', '🧿', '🪙', '🧱', '🪓', '🤢', '📜'],
      themeType: DungeonThemeType.stone,
      baseRewardCoins: 15,
      baseScoreMultiplier: 1.0,
    ),
    DungeonConfig(
      id: 'lava_chamber',
      name: 'Lava Chamber',
      depth: 'Depth B2',
      description:
          'A subterranean forge built over rivers of bubbling magma. The heat flickers and traps hurt.',
      emojiSet: [
        '🌋',
        '🔥',
        '🪙',
        '🧪',
        '🐉',
        '⚔️',
        '💀',
        '📜',
        '🪓',
        '🔑',
        '💎',
        '🧱',
      ],
      themeType: DungeonThemeType.lava,
      baseRewardCoins: 35,
      baseScoreMultiplier: 1.5,
    ),
    DungeonConfig(
      id: 'ice_chamber',
      name: 'Ice Chamber',
      depth: 'Depth B3',
      description:
          'A cavern of frozen tears. Chilling frost and crystals, one wrong step freeze-locks your resolve.',
      emojiSet: [
        '❄️',
        '💎',
        '🧊',
        '🪙',
        '🧪',
        '🕸️',
        '🐍',
        '📜',
        '🔑',
        '🧿',
        '🏹',
        '🛡️',
        '🐺',
        '🏔️',
        '🌨️',
        '☄️',
        '🪞',
        '🔮',
      ],
      themeType: DungeonThemeType.ice,
      baseRewardCoins: 60,
      baseScoreMultiplier: 2.2,
    ),
    DungeonConfig(
      id: 'crypt_chamber',
      name: 'Crypt Chamber',
      depth: 'Depth B4',
      description:
          'The final tomb of the rune kings, shrouded in eternal darkness and toxic vapors.',
      emojiSet: [
        '⚰️',
        '🔮',
        '🧿',
        '🪙',
        '🧪',
        '🧵',
        '☠️',
        '📜',
        '🔑',
        '🦇',
        '👻',
        '🕯️',
        '🕷️',
        '🦴',
        '🛡️',
        '⛓️',
        '🗡️',
        '🪦',
        '💎',
        '🎭',
        '🗝️',
        '🩸',
        '🚪',
        '🃏',
      ],
      themeType: DungeonThemeType.crypt,
      baseRewardCoins: 100,
      baseScoreMultiplier: 3.5,
    ),
    DungeonConfig(
      id: 'void_chamber',
      name: 'Void Chamber',
      depth: 'Depth B5',
      description:
          'Beyond the crypt lies the cosmic void — an endless expanse of stars, vortexes, and forgotten gods.',
      emojiSet: [
        '🌌',
        '🌀',
        '🪐',
        '🛸',
        '👾',
        '🚀',
        '🛰️',
        '☄️',
        '🧪',
        '☠️',
        '🪙',
        '📜',
        '💎',
        '🌑',
        '🔭',
        '⭐',
        '🌙',
        '🪬',
        '🧬',
        '🌠',
        '🔮',
        '🃏',
        '🕳️',
        '🧿',
        '🐙',
        '💀',
        '🧱',
        '🔑',
        '🎭',
        '🩸',
        '⚗️',
        '🫧',
      ],
      themeType: DungeonThemeType.voidChamber,
      baseRewardCoins: 150,
      baseScoreMultiplier: 5.0,
    ),
    DungeonConfig(
      id: 'forest_chamber',
      name: 'Whispering Hollow',
      depth: 'Depth B6',
      description:
          'The Verdant Crypt — an ancient buried grove where roots twist through forgotten chambers. A deceptively gentle sanctuary hiding venomous traps and ancient guardians.',
      emojiSet: [
        '🌲',
        '🍄',
        '🍂',
        '🌿',
        '🪵',
        '🌰',
        '🦉',
        '🦊',
        '🐍',
        '🕸️',
        '🕷️',
        '🦇',
        '🐺',
        '🦌',
        '🌾',
        '🌻',
        '🏹',
        '🗡️',
        '💎',
        '🧪',
        '🪙',
        '📜',
        '🔑',
        '🧿',
      ],
      themeType: DungeonThemeType.forest,
      baseRewardCoins: 20,
      baseScoreMultiplier: 1.2,
      // Unique modifier: "poison bloom" — poison tiles appear 2x more than normal pairs
      // This makes the forest feel dangerous despite its welcoming appearance
    ),
  ];
}
