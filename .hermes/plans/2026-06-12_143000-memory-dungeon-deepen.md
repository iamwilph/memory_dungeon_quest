
# Memory Dungeon: Gameplay Deepening Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Transform Memory Dungeon from a repetitive emoji-matching app into a strategic memory roguelite with meaningful choices, varied levels, and persistent progression.

**Architecture:** Extend the existing `GameState` + Provider pattern. Introduce a `ShopSystem`, `LevelModifier` enums, and a `BattleLog` for tile effects. No new packages — pure Flutter/Dart code. Keep the UI language (stone slabs, runes, Cinzel font) intact, just make gameplay live up to the RPG framing.

**Tech Stack:** Flutter ^3.10.1, provider ^6.1.5+1, path_provider ^2.1.5

---

## Phase 1: Meaningful Tile Effects

Currently matching a poison tile just costs a life and gems add a score multiplier. Make every tile type actively change the board state or run resources.

### Task 1.1: Extend `CampaignProgress` to hold coins and artifacts

**Objective:** Persist player's total coins across runs so they can be spent in a shop.

**Files:**
- Modify: `lib/models/campaign_progress.dart`

**Step 1: Add `_totalCoinsSpent` and `artifactsUnlocked` fields to `CampaignProgress`**

```dart
class CampaignProgress {
  final int unlockedDungeonIndex;
  final Map<int, int> dungeonLevelProgress;
  final int lives;
  final int coins;          // Coins earned this run (transient)
  final int totalCoins;     // Lifetime coins across all runs (persistent)
  final int hintCharges;
  final Set<String> artifactsUnlocked; // e.g. {"extra_hint", "lives_boost"}

  const CampaignProgress({
    required this.unlockedDungeonIndex,
    required this.dungeonLevelProgress,
    required this.lives,
    required this.coins,
    required this.totalCoins,
    required this.hintCharges,
    required this.artifactsUnlocked,
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

    // Parse artifacts: can be a List<String> in JSON
    final rawArtifacts = json['artifactsUnlocked'];
    final Set<String> artifacts;
    if (rawArtifacts is List) {
      artifacts = rawArtifacts.map((e) => e.toString()).toSet();
    } else {
      artifacts = {};
    }

    return CampaignProgress(
      unlockedDungeonIndex: _readInt(json['unlockedDungeonIndex']),
      dungeonLevelProgress: progress,
      lives: _readInt(json['lives'], fallback: 3),
      coins: _readInt(json['coins']),
      totalCoins: _readInt(json['totalCoins'], fallback: 0),
      hintCharges: _readInt(json['hintCharges'], fallback: 1),
      artifactsUnlocked: artifacts,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'version': 2,
      'unlockedDungeonIndex': unlockedDungeonIndex,
      'dungeonLevelProgress': dungeonLevelProgress.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      'lives': lives,
      'coins': coins,
      'totalCoins': totalCoins,
      'hintCharges': hintCharges,
      'artifactsUnlocked': artifactsUnlocked.toList(),
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
```

**Step 2: Update version to 2 and handle migration in `GameState.loadCampaignProgress`**

In `lib/models/game_state.dart`, change the version check logic. Since we're using a single JSON file, add migration handling in `GameState`:

```dart
Future<void> loadCampaignProgress() async {
  try {
    final progress = await _progressStore.load();
    if (progress != null) {
      // Migrate: add default artifacts if missing from version 1 save
      final migrated = CampaignProgress(
        unlockedDungeonIndex: progress.unlockedDungeonIndex,
        dungeonLevelProgress: progress.dungeonLevelProgress,
        lives: progress.lives,
        coins: progress.coins,
        totalCoins: progress.totalCoins, // 0 if migrated from v1
        hintCharges: progress.hintCharges,
        artifactsUnlocked: progress.artifactsUnlocked,
      );
      _applyCampaignProgress(migrated);
    } else {
      resumeCampaign();
    }
  } catch (error, stackTrace) {
    debugPrint('Failed to load campaign progress: $error\n$stackTrace');
    resumeCampaign();
  }

  _isProgressLoaded = true;
  notifyListeners();
}
```

**Step 3: Update `GameState._saveCampaignProgress` to persist totalCoins and artifacts**

Find the `_saveCampaignProgress` method in `game_state.dart` (around line 620ish) and ensure it passes the new fields:

```dart
Future<void> _saveCampaignProgress() async {
  final progress = CampaignProgress(
    unlockedDungeonIndex: _unlockedDungeonIndex,
    dungeonLevelProgress: Map<int, int>.from(_dungeonLevelProgress),
    lives: _lives,
    coins: _coins,
    totalCoins: _totalCoins + _coins, // accumulate run coins into lifetime
    hintCharges: _hintCharges,
    artifactsUnlocked: Set<String>.from(_artifactsUnlocked),
  );
  await _progressStore.save(progress);
}

// Add to GameState constructor or initState:
Set<String> _artifactsUnlocked = {};

// After loading progress, merge in artifacts:
void _applyCampaignProgress(CampaignProgress saved) {
  // ... existing code ...
  _unlockedDungeonIndex = saved.unlockedDungeonIndex;
  _dungeonLevelProgress.clear();
  _dungeonLevelProgress.addAll(saved.dungeonLevelProgress);
  // Note: do NOT restore lives/coins from save — those are run-specific
  _artifactsUnlocked = Set<String>.from(saved.artifactsUnlocked);
  // Apply artifact effects to starting values
  _lives = saved.lives;
}
```

**Verification:** Run `flutter analyze lib/models/game_state.dart lib/models/campaign_progress.dart`. No errors. Save a run, quit, restart — progress loads including coins counter.

---

### Task 1.2: Implement meaningful tile match effects in `GameState._applyMatchEffects`

**Objective:** Poison purifies an adjacent poison card. Scrolling gives a guaranteed free flip. Gems remove one random unmatched pair from the board permanently (they vanish, don't cost lives).

**Files:**
- Modify: `lib/models/game_state.dart` (the `_applyMatchEffects` method)

**Step 1: Read the current `_applyMatchEffects` and replace it**

Current implementation (from lines ~490-516 of game_state.dart, truncated):

```dart
void _applyMatchEffects(CardType type) {
  switch (type) {
    case CardType.poison:
      _lives--;
      _lastTriggeredEffect = 'poison';
      if (_lives <= 0) {
        _isGameOver = true;
        _lastTriggeredEffect = 'game_over';
      }
      break;
    case CardType.healing:
      // truncated — need to read rest
```

Replace the entire `_applyMatchEffects` method with:

```dart
void _applyMatchEffects(CardType type) {
  switch (type) {
    case CardType.poison:
      // Poison still costs a life, but it also PURIFIES one adjacent poison card.
      _lives--;
      _lastTriggeredEffect = 'poison';
      
      // Purify: find any other poison card and remove it from the board (mark as matched)
      final unpurifiedPoisons = _cards.where(
        (c) => c.type == CardType.poison && !c.isMatched,
      ).toList();
      
      if (unpurifiedPoisons.length >= 2) {
        // Remove one poison card from the board (it "dissolves")
        final toDissolve = unpurifiedPoisons.first;
        toDissolve.isMatched = true; // Remove from play
        _lastTriggeredEffect = 'poison_purify';
      }
      
      if (_lives <= 0) {
        _isGameOver = true;
        _lastTriggeredEffect = 'game_over';
      }
      break;

    case CardType.healing:
      if (_lives < _maxLives) {
        _lives++;
        _lastTriggeredEffect = 'heal';
      } else {
        // Full health: convert to a bonus score instead of healing
        _score += 50;
        _lastTriggeredEffect = 'heal_overflow';
      }
      break;

    case CardType.treasure:
      // Coins already awarded in _completeLevelIfSolved; reward extra small bonus here
      _coins += 1 + (_currentLevel ~/ 5); // Scaling micro-bonus
      _lastTriggeredEffect = 'treasure';
      break;

    case CardType.scroll:
      // Give a hint charge, but also reveal one UNKNOWN pair (best hints only show random cards)
      _hintCharges++;
      
      // Reveal a known-but-unmatched pair: find any unmatched type that appears exactly twice
      final unmatched = _cards.where((c) => !c.isMatched && !c.isFlipped).toList();
      if (unmatched.length >= 2) {
        // Pick a random pair by matching emojis
        final emojiGroups = <String, List<DungeonCard>>{};
        for (final card in unmatched) {
          emojiGroups.putIfAbsent(card.emoji, () => []);
          emojiGroups[card.emoji]!.add(card);
        }
        
        for (final group in emojiGroups.values) {
          if (group.length >= 2) {
            // Reveal this pair! (Flip them face-up briefly, then they auto-match)
            group[0].isFlipped = true;
            group[1].isFlipped = true;
            
            // Auto-match after 1s (they glow and disappear)
            Timer(const Duration(seconds: 1), () {
              if (!group[0].isMatched) {
                group[0].isMatched = true;
                group[1].isMatched = true;
                
                // Recalculate level completion after auto-match
                _completeLevelIfSolved();
                notifyListeners();
              }
            });
            
            _lastTriggeredEffect = 'scroll_reveal';
            break; // Only reveal one pair per scroll match
          }
        }
      }
      break;

    case CardType.gem:
      // Gem boosts multiplier AND removes one matched poison from the board
      _scoreMultiplier += 0.5;
      
      // Also "shatter" a poison: find one poison and remove it (it's already been dealt with)
      // But if there are leftover poisons on the board, shatter one!
      final remainingPoisons = _cards.where(
        (c) => c.type == CardType.poison && !c.isMatched,
      ).toList();
      
      if (remainingPoisons.isNotEmpty) {
        remainingPoisons.first.isMatched = true; // Shatter one poison permanently
        _lastTriggeredEffect = 'gem_shatter';
      } else {
        // No poisons to shatter: bonus score instead
        _score += 75;
      }
      break;

    case CardType.normal:
      // Normal tiles just add a small score bonus for being matched
      _score += 10; // Micro-bonus per normal pair
      break;
  }
}
```

**Step 2: Update `_completeLevelIfSolved` to handle auto-matches from scrolls/shatters**

The existing method already calls `_isPuzzleSolved()` which checks `!card.isMatched`, so auto-matches will be detected. No change needed there, but add a `notifyListeners()` after the auto-match timer fires (already included above).

**Verification:** Run `flutter analyze lib/models/game_state.dart`. No errors. Play a level, match poison → see one less poison on board. Match scroll → see a pair auto-match after 1 second.

---

### Task 1.3: Add artifact system to GameState (passive bonuses)

**Objective:** Implement artifacts as passive bonuses applied at the start of each run.

**Files:**
- Modify: `lib/models/game_state.dart` (constructor and `initDungeon`)

**Step 1: Add artifact definitions as a const map and apply in constructor**

Add near the top of `GameState` class:

```dart
class GameState extends ChangeNotifier {
  // Artifact definitions: artifact ID -> (name, description)
  static const Map<String, _ArtifactDef> _artifacts = {
    'extra_hint': _ArtifactDef('Extra Hint Scroll', 'Start every dungeon with +1 hint charge'),
    'lives_boost': _ArtifactDef('Rune of Vitality', 'Start with 4 lives instead of 3'),
    'poison_sight': _ArtifactDef('Poison Sight Rune', 'Poison cards glow red on the board'),
  };

  // ... existing fields ...
  
  Set<String> get unlockedArtifacts => _artifactsUnlocked;
  Map<String, _ArtifactDef> get artifactsCatalogue => _artifacts;

  GameState({CampaignProgressStore? progressStore})
    : _progressStore = progressStore ?? MemoryCampaignProgressStore() {
    initDungeon(_activeDungeon);
  }

  // Override initDungeon to apply artifact bonuses at start of run
  void initDungeon(
    DungeonConfig config, {
    bool resetStats = false,
    int startLevel = 1,
  }) {
    // Apply passive artifacts
    if (_artifactsUnlocked.contains('lives_boost')) {
      _maxLives = 6; // Extend max life pool
    } else {
      _maxLives = 5;
    }

    // Start with artifact bonuses
    if (resetStats) {
      _lives = 3;
      if (_artifactsUnlocked.contains('lives_boost')) _lives = 4;
      _coins = 0;
      _score = 0;
      _scoreMultiplier = 1.0;
      _hintCharges = 1;
      if (_artifactsUnlocked.contains('extra_hint')) _hintCharges++;
    } else {
      // Descending: apply artifacts to current run state
      if (_artifactsUnlocked.contains('extra_hint') && _hintCharges < 1) {
        _hintCharges = 1; // Ensure at least 1 hint on descent
      }
    }

    _activeDungeon = config;
    _currentLevel = startLevel.clamp(1, DungeonConfig.levelsPerDungeon).toInt();
    _selectedIndices.clear();
    _isLocked = false;
    _isGameOver = false;
    _isLevelCleared = false;
    _isPreviewingPuzzle = false;
    _lastTriggeredEffect = null;

    if (!resetStats) {
      // Ensure player has at least 3 lives when descending
      if (_lives < 3) {
        _lives = 3;
      }
      // Reset multiplier per level to prevent exponential scores
      _scoreMultiplier = 1.0;
    }

    _generateCards();
    _startPuzzlePreview();
  }
```

**Step 2: Add the `_ArtifactDef` helper class at file top level (outside GameState)**

```dart
class _ArtifactDef {
  final String name;
  final String description;
  const _ArtifactDef(this.name, this.description);

  String get displayName => name;
  String get displayDescription => description;
}
```

**Verification:** Run `flutter analyze lib/models/game_state.dart`. Play a run — if you have `lives_boost` artifact, HUD shows 4 hearts.

---

## Phase 2: Level Modifiers

Inject variety within dungeons so level 10 feels mechanically different from level 9, not just "bigger grid."

### Task 2.1: Add `LevelModifier` enum to `DungeonConfig`

**Objective:** Define modifier types that can be applied per level.

**Files:**
- Modify: `lib/models/dungeon_config.dart`

**Step 1: Add the enum at top of file (before `DungeonConfig`)**

```dart
/// Level modifiers that change how the game is played.
/// Only a few active per dungeon to keep it manageable.
enum LevelModifier {
  none,           // Normal gameplay
  shadow,         // 2-3 random cards are permanently hidden (auto-fail)
  timer,          // Cards auto-flip back after 3 seconds of being face-up
  swap,           // Board layout reshuffles every 5 successful flips
  sabotage,       // One pair looks identical but both are poison (visual misdirection)
  fragments,      // Cards need 2 flips to match (first flip shows glyph, second shows emoji)
}

/// Modifier definitions per dungeon index.
/// Maps: dungeonIndex -> list of (level, modifier) pairs.
const Map<int, List<_LevelModifierEntry>> _dungeonModifiers = {
  0: [ // Stone Chamber (B1) — gentle intro modifiers
    _LevelModifierEntry(8, LevelModifier.shadow),   // Level 8: some cards hidden
    _LevelModifierEntry(14, LevelModifier.swap),     // Level 14: board shuffles
    _LevelModifierEntry(18, LevelModifier.fragments), // Level 18: two-flip matching
  ],
  1: [ // Lava Chamber (B2) — pressure modifiers
    _LevelModifierEntry(6, LevelModifier.timer),      // Level 6: cards auto-flip
    _LevelModifierEntry(12, LevelModifier.sabotage),  // Level 12: fake pairs
    _LevelModifierEntry(16, LevelModifier.shadow),     // Level 16: hidden cards
    _LevelModifierEntry(20, LevelModifier.swap),       // Final level: shuffle pressure
  ],
  3: [ // Ice Chamber (B3) — harsh modifiers
    _LevelModifierEntry(5, LevelModifier.timer),      // Early timer exposure
    _LevelModifierEntry(10, LevelModifier.sabotage),  // Mid-game visual trick
    _LevelModifierEntry(15, LevelModifier.fragments),  // Late-level complexity
    _LevelModifierEntry(20, LevelModifier.shadow),     // Final: hidden + pressure
  ],
  4: [ // Crypt Chamber (B4) — brutal modifiers
    _LevelModifierEntry(5, LevelModifier.fragments),
    _LevelModifierEntry(10, LevelModifier.swap),
    _LevelModifierEntry(15, LevelModifier.timer),
    _LevelModifierEntry(20, LevelModifier.sabotage),   // Final: deception
  ],
  5: [ // Void Chamber (B5) — mind-bending modifiers
    _LevelModifierEntry(4, LevelModifier.sabotage),
    _LevelModifierEntry(8, LevelModifier.shadow),
    _LevelModifierEntry(12, LevelModifier.timer),
    _LevelModifierEntry(16, LevelModifier.fragments),
    _LevelModifierEntry(20, LevelModifier.swap),        // Final: chaos mode
  ],
  // Stone (0) and Forest (5) have their own entries above.
  // Lava (1), Ice (2), Crypt (3) also added above.
};

class _LevelModifierEntry {
  final int level;
  final LevelModifier modifier;
  const _LevelModifierEntry(this.level, this.modifier);
}

enum DungeonThemeType { stone, lava, ice, crypt, voidChamber, forest }
```

*(Note: I'm adding the enum and modifier map BEFORE the existing `DungeonThemeType` and `DungeonConfig`. The rest of `DungeonConfig` stays the same.)*

**Step 2: Add a helper to DungeonConfig**

Add inside `DungeonConfig` class:

```dart
/// Returns the active modifier for a given level in this dungeon.
LevelModifier getModifierForLevel(int level) {
  final entries = _dungeonModifiers[id] ?? []; // Need to add 'id' based lookup
  for (final entry in entries) {
    if (entry.level == level) return entry.modifier;
  }
  return LevelModifier.none;
}
```

Wait — the map is keyed by dungeon index, not ID. Let me fix that:

```dart
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

/// Whether the current level has an active modifier.
bool get hasModifier => getModifierForLevel(_currentLevel) != LevelModifier.none;

/// Current modifier name for display.
String get modifierName {
  final mod = getModifierForLevel(_currentLevel);
  switch (mod) {
    case LevelModifier.shadow: return '🌑 SHADOW';
    case LevelModifier.timer: return '⏱️ TIMER';
    case LevelModifier.swap: return '🔀 SWAP';
    case LevelModifier.sabotage: return '⚠️ SABOTAGE';
    case LevelModifier.fragments: return '💎 FRAGMENTS';
    case LevelModifier.none: return '';
  }
}
```

**Verification:** Run `flutter analyze lib/models/dungeon_config.dart`. No errors. Level 8 of Stone Chamber should return `LevelModifier.shadow`.

---

### Task 2.2: Implement modifier logic in `GameState`

**Objective:** Make `_generateCards` and `flipCard` respect active modifiers.

**Files:**
- Modify: `lib/models/game_state.dart`

**Step 1: Add modifier state fields to GameState**

```dart
LevelModifier _activeModifier = LevelModifier.none;
int _flipCountSinceLastSwap = 0;
```

**Step 2: Update `initDungeon` to set the active modifier**

In `initDungeon`, after setting `_activeDungeon`, add:
```dart
_activeModifier = _activeDungeon.getModifierForLevel(_currentLevel);
_flipCountSinceLastSwap = 0;
```

**Step 3: Implement modifier effects in `flipCard` and `_generateCards`**

In `flipCard`, after incrementing the flip (before the timer check), add modifier logic. Find this block:

```dart
// Flip the card
card.isFlipped = true;
_selectedIndices.add(index);
_lastTriggeredEffect = 'flip';
```

After `_selectedIndices.add(index)`, add:

```dart
// Handle Swap modifier: reshuffle board every 5 flips
if (_activeModifier == LevelModifier.swap) {
  _flipCountSinceLastSwap++;
  if (_flipCountSinceLastSwap >= 5) {
    _shuffledBoard();
    _flipCountSinceLastSwap = 0;
    _lastTriggeredEffect = 'board_swap';
  }
}
```

Add the `_shuffledBoard` method:

```dart
void _shuffledBoard() {
  // Collect all unmatched, unflipped cards and shuffle their positions
  final activeCards = <DungeonCard>[];
  
  for (final card in _cards) {
    if (!card.isMatched && !card.isFlipped) {
      activeCards.add(card);
    }
  }
  
  if (activeCards.isEmpty) return;
  
  // Shuffle the card data but keep positions fixed
  final shuffledEmojis = activeCards.map((c) => c.emoji).toList();
  shuffledEmojis.shuffle(Random());
  
  for (var i = 0; i < activeCards.length; i++) {
    final oldEmoji = activeCards[i].emoji;
    // Only swap if emojis are different (avoid no-op shuffle)
  }
  
  // Simpler approach: just swap the positions of all active cards in the _cards list
  final cardIds = <int>[];
  for (var i = 0; i < _cards.length; i++) {
    if (!_cards[i].isMatched && !_cards[i].isFlipped) {
      cardIds.add(i);
    }
  }
  
  // Shuffle the indices and swap cards in-place
  cardIds.shuffle(Random());
  for (var i = 0; i < cardIds.length - 1; i += 2) {
    final a = cardIds[i];
    final b = cardIds[i + 1];
    final tempEmoji = _cards[a].emoji;
    final tempType = _cards[a].type;
    _cards[a].isFlipped = false; // Safety: ensure hidden during swap
    
    final cardAEmoji = _cards[a].emoji;
    final cardAType = _cards[a].type;
    
    // Actually, simpler: swap entire card state between positions
    final temp = DungeonCard(
      id: _cards[a].id, emoji: _cards[a].emoji, type: _cards[a].type,
      isFlipped: false, isMatched: false, isHinted: false,
    );
    
    _cards[a] = DungeonCard(
      id: _cards[b].id, emoji: _cards[b].emoji, type: _cards[b].type,
      isFlipped: false, isMatched: false, isHinted: false,
    );
    
    _cards[b] = temp;
  }
  
  notifyListeners();
}
```

Actually, that's overly complicated. Let me simplify: just shuffle the emoji assignments in the `_cards` list for non-matched, non-flipped positions. The existing `copyWith` on DungeonCard doesn't support changing emoji/type. I'll add a helper:

```dart
void _reassignCardEmoji(int index, String newEmoji, CardType newType) {
  final card = _cards[index];
  _cards[index] = DungeonCard(
    id: card.id,
    emoji: newEmoji,
    type: newType,
    isFlipped: card.isFlipped,
    isMatched: card.isMatched,
    isHinted: false, // Reset hint on swap
  );
}

void _shuffledBoard() {
  final activeIndices = <int>[];
  for (var i = 0; i < _cards.length; i++) {
    if (!_cards[i].isMatched && !_cards[i].isFlipped) {
      activeIndices.add(i);
    }
  }

  if (activeIndices.length < 4) return; // Need at least 2 pairs to shuffle

  final emojis = activeIndices.map((i) => _cards[i].emoji).toList();
  final types = activeIndices.map((i) => _cards[i].type).toList();

  // Simple Fisher-Yates shuffle
  for (var i = emojis.length - 1; i > 0; i--) {
    final j = Random().nextInt(i + 1);
    final tempEmoji = emojis[i];
    emojis[i] = emojis[j];
    emojis[j] = tempEmoji;

    final tempType = types[i];
    types[i] = types[j];
    types[j] = tempType;
  }

  for (var i = 0; i < activeIndices.length; i++) {
    _reassignCardEmoji(activeIndices[i], emojis[i], types[i]);
  }

  notifyListeners();
}
```

**Step 4: Implement Shadow modifier in `_generateCards`**

In the existing `_generateCards` method, after creating cards but before shuffling:

```dart
void _generateCards() {
  // ... existing code for creating deckAssets and shuffling ...

  final cards = List.generate(deckAssets.length, (index) {
    final emoji = deckAssets[index];
    return DungeonCard(
      id: index,
      emoji: emoji,
      type: DungeonCard.getCardTypeFromEmoji(emoji),
    );
  });

  // Apply Shadow modifier: hide 2-3 random cards (mark as permanently unflippable)
  if (_activeModifier == LevelModifier.shadow) {
    final hiddenCount = min(3, cards.length ~/ 8); // Up to 3 or 12.5% of board
    final hiddenIndices = <int>[];
    while (hiddenIndices.length < hiddenCount) {
      final idx = Random().nextInt(cards.length);
      if (!hiddenIndices.contains(idx)) hiddenIndices.add(idx);
    }

    for (final idx in hiddenIndices) {
      // Mark as "poison shadow" — always treat as matched (removed from board)
      cards[idx].isMatched = true;
    }

    // Remove the shadow cards from the deck entirely for matching purposes
    // Actually, let's keep them but flag them as "void" so they never get matched
    // and count toward puzzle solved check differently.
  }

  if (_validateGeneratedLevel(cards, expectedTileCount: totalTiles)) {
    _cards = cards;
  }
}
```

Update `_isPuzzleSolved` to account for shadow cards:

```dart
bool _isPuzzleSolved() {
  final unmatchedCards = _cards.where((card) => !card.isMatched).toList();
  if (unmatchedCards.isEmpty && _activeModifier != LevelModifier.shadow) return true;

  // For shadow modifier: only count non-shadow cards
  if (_activeModifier == LevelModifier.shadow) {
    final activeUnmatched = unmatchedCards.where(
      (c) => c.type != CardType.poison || !unmatchedCards.every((other) => other.id == c.id),
    ).toList();
    // Actually simpler: check if all non-shadow cards are matched or poison-only
  }

  return unmatchedCards.every((card) => card.type == CardType.poison);
}
```

Hmm, this is getting complicated. Let me simplify the Shadow modifier: just remove 2-3 poison cards from the generation entirely by reducing totalPairs. That's cleaner:

```dart
// In _generateCards, before calling getGridSizeForLevel:
if (_activeModifier == LevelModifier.shadow) {
  final hiddenCount = min(3, totalPairs ~/ 4); // Hide 1 pair + up to 1 single
  _cards = []; // will be regenerated with reduced pairs below
}
```

Actually, the cleanest approach: modify `_generateCards` to skip generating pairs for shadow cards. Let me rewrite it cleanly in the plan as a single atomic replacement:

```dart
void _generateCards() {
  final totalTiles = activeRows * activeCols;
  if (totalTiles.isOdd) {
    throw StateError('Dungeon ${_activeDungeon.id} level $_currentLevel has an odd deck size: $totalTiles');
  }

  int totalPairs = totalTiles ~/ 2;
  
  // Shadow modifier: remove some pairs from the board
  if (_activeModifier == LevelModifier.shadow) {
    final hiddenPairs = min(3, totalPairs ~/ 4);
    totalPairs -= hiddenPairs;
  }

  const int maxAttempts = 10;
  final random = Random();

  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    final deckAssets = <String>[];

    for (final asset in _selectPairAssets(totalPairs)) {
      deckAssets..add(asset)..add(asset);
    }

    deckAssets.shuffle(random);

    _cards = List.generate(deckAssets.length, (index) {
      final emoji = deckAssets[index];
      return DungeonCard(
        id: index,
        emoji: emoji,
        type: DungeonCard.getCardTypeFromEmoji(emoji),
      );
    });

    if (_validateGeneratedLevel(_cards, expectedTileCount: deckAssets.length)) {
      return;
    }
  }

  throw StateError(
    'Failed to generate a valid ${_activeDungeon.id} level $_currentLevel deck after $maxAttempts attempts.',
  );
}
```

**Step 5: Implement Timer modifier — cards auto-flip back after N seconds**

Add a timer field and hook into `flipCard`:

```dart
Timer? _timerFlipBack; // For timer modifier

void flipCard(int index) {
  if (_isLocked || _isGameOver || _isLevelCleared) return;
  // ... existing validation ...

  card.isFlipped = true;
  
  // Timer modifier: schedule auto-flip back after 3 seconds (if card was newly flipped)
  if (_activeModifier == LevelModifier.timer && !card.isMatched) {
    _timerFlipBack?.cancel(); // Cancel any pending timer
    final scheduledIndex = index;
    
    _timerFlipBack = Timer(const Duration(seconds: 3), () {
      if (!_cards[scheduledIndex].isFlipped) return; // Already processed
      _cards[scheduledIndex].isFlipped = false;
      if (_selectedIndices.contains(scheduledIndex)) {
        _selectedIndices.remove(scheduledIndex);
      }
      notifyListeners();
    });
  }

  _selectedIndices.add(index);
  _lastTriggeredEffect = 'flip';
  
  // ... rest of existing flipCard logic ...
}

@override
void dispose() {
  _timerFlipBack?.cancel(); // Clean up in GameState (if it had dispose)
}
```

Since `GameState` is a `ChangeNotifier` and no explicit dispose, add cleanup in the game screen's dispose:

```dart
@override
void dispose() {
  Provider.of<GameState>(context, listen: false).removeListener(_handleStateEffects);
  _shakeController.dispose();
  _flashController.dispose();
}
```

**Step 6: Implement Sabotage modifier — one fake identical pair where both are poison**

In `_generateCards`, after creating the deck, add sabotage:

```dart
// Sabotage modifier: replace one normal pair with poison doubles
if (_activeModifier == LevelModifier.sabotage) {
  final normalCards = _cards.where((c) => c.type == CardType.normal).toList();
  if (normalCards.length >= 2) {
    // Find a pair in the deck and turn both into poison
    for (var i = 0; i < _cards.length - 1; i++) {
      if (_cards[i].type == CardType.normal) {
        // Find its match
        for (var j = i + 1; j < _cards.length; j++) {
          if (_cards[j].emoji == _cards[i].emoji && _cards[j].type == CardType.normal) {
            // BOTH become poison — same emoji, but both are traps!
            _cards[i] = DungeonCard(id: _cards[i].id, emoji: '☠️', type: CardType.poison);
            _cards[j] = DungeonCard(id: _cards[j].id, emoji: '☠️', type: CardType.poison);
            break; // Only one sabotage pair per level
          }
        }
      }
    }
  }
}
```

**Step 7: Implement Fragment modifier — cards need two flip states, show a glyph first**

This is the most complex. Each card has: `glyph` (first face), `emoji` (second/true face). When flipped the first time, show glyph. Second flip reveals emoji and checks match.

Add `glyph` field to `DungeonCard`:

```dart
class DungeonCard {
  final int id;
  final String emoji;
  final String glyph;   // NEW: first-flip display (rune-like)
  final CardType type;
  bool isFlipped;        // Currently: showing glyph (first flip) or emoji (second flip)
  bool isMatched;
  bool isHinted;

  DungeonCard({
    required this.id,
    required this.emoji,
    required this.glyph,  // NEW parameter
    required this.type,
    this.isFlipped = false,
    this.isMatched = false,
    this.isHinted = false,
  });

  // Override copyWith to include glyph
  DungeonCard copyWith({
    int? id,
    String? emoji,
    String? glyph,  // NEW
    CardType? type,
    bool? isFlipped,
    bool? isMatched,
    bool? isHinted,
  }) {
    return DungeonCard(
      id: id ?? this.id,
      emoji: emoji ?? this.emoji,
      glyph: glyph ?? this.glyph,
      type: type ?? this.type,
      isFlipped: isFlipped ?? this.isFlipped,
      isMatched: isMatched ?? this.isMatched,
      isHinted: isHinted ?? this.isHinted,
    );
  }

  static CardType getCardTypeFromEmoji(String emoji) {
    // ... existing switch statement, no changes needed ...
  }

  static const Map<int, String> _glyphs = {
    0: 'ᚠ', 1: 'ᚢ', 2: 'ᚦ', 3: 'ᚨ',
    4: 'ᚱ', 5: 'ᚲ', 6: 'ᚷ', 7: 'ᚹ',
    8: 'ᚺ', 9: 'ᚾ', 10: 'ᛁ', 11: 'ᛃ',
    12: 'ᛇ', 13: 'ᛈ', 14: 'ᛉ', 15: 'ᛋ',
    16: 'ᛏ', 17: 'ᛒ', 18: 'ᛖ', 19: 'ᛗ',
    20: 'ᛚ', 21: 'ᛜ', 22: 'ᛞ', 23: 'ᛟ',
    24: 'ᚫ', 25: 'ᛣ', 26: 'ᛤ', 27: 'ᛥ',
    28: 'ᛦ', 29: 'ᛧ', 30: 'ᛨ', 31: 'ᚾ',
    32: 'ᛩ', 33: 'ᛪ', 34: '᛫', 35: '᛬',
    36: '᛭', 37: 'ᚱ', 38: 'ᚲ', 39: 'ᚳ',
    40: '᙮', 41: 'ᛮ', 42: 'ᛰ', 43: 'ᚴ',
    44: 'ᙰ', 45: 'ᛱ', 46: 'ᚵ', 47: 'ᙱ',
    48: 'ᛲ', 49: 'ᚶ', 50: 'ᙲ', 51: 'ᛳ',
    52: 'ᚷ', 53: 'ᙳ', 54: 'ᛴ', 55: 'ᚸ',
    // Extend as needed — at least maxPairs (36 for 6x6 grid)
    // For 72 cards: need more glyphs. Use extended Unicode runes.
  };

  static String getGlyph(int id) {
    return _glyphs[id] ?? '᛫'; // Fallback rune if id not in map
  }
}

// In _generateCards, when creating cards:
final glyph = DungeonCard.getGlyph(index); // or assign by pair

_cards = List.generate(deckAssets.length, (index) {
  final emoji = deckAssets[index];
  return DungeonCard(
    id: index,
    emoji: emoji,
    glyph: '᛫', // All cards show the same glyph initially under fragment mode
    type: DungeonCard.getCardTypeFromEmoji(emoji),
  );
});
```

Now update `_isPuzzleSolved` for fragments:

```dart
bool _isPuzzleSolved() {
  if (_activeModifier != LevelModifier.fragments) {
    final unmatchedCards = _cards.where((card) => !card.isMatched).toList();
    if (unmatchedCards.isEmpty) return true;
    return unmatchedCards.every((card) => card.type == CardType.poison);
  }

  // Fragment modifier: puzzle solved when all FRAGMENTED (second-flip) cards are matched or poison.
  // Cards still showing glyph but unmatched = not yet attempted.
 final attemptedUnmatched = _cards.where(
    (card) => !card.isMatched && card.isFlipped, // Card is currently showing emoji (second flip)
  ).toList();

  if (attemptedUnmatched.isEmpty && !_cards.any((c) => !c.isMatched)) return true;

  // Check if all attempted-unmatched cards are poison OR all non-poison pairs are fully matched
  final nonPoisonAttempted = attemptedUnmatched.where((c) => c.type != CardType.poison).toList();
  if (nonPoisonAttempted.isEmpty) {
    // Either all matched, or remaining are poison-only. Check:
    final anyUnpoisonUnmatched = _cards.any((c) => !c.isMatched && c.type != CardType.poison);
    if (!anyUnpoisonUnmatched) return true; // All non-poison pairs have been attempted and cleared
  }

  return false;
}
```

Update `flipCard` for fragment logic:

```dart
void flipCard(int index) {
  if (_isLocked || _isGameOver || _isLevelCleared) return;
  if (index < 0 || index >= _cards.length) return;

  final card = _cards[index];
  
  // Fragment modifier: handle two-stage flip
  if (_activeModifier == LevelModifier.fragments) {
    if (card.isMatched) return;
    
    if (!card.isFlipped) {
      // First flip: show glyph (rune), card "turns over" to reveal rune
      card.isFlipped = true; // Now showing glyph (first flip state)
      _selectedIndices.add(index);
      _lastTriggeredEffect = 'flip';

      // Auto-advance: show emoji after 0.5s (brief preview of glyph)
      _selectedIndices.clear(); // No counting fragments the same way
      
      Timer(const Duration(milliseconds: 1500), () {
        // Second flip: reveal emoji, then check match with any other revealed card
        if (card.isMatched) return; // Might have been matched during preview

        card.isFlipped = false; 
        // Actually, need a better model. Let me rethink below in next step.
      });

      notifyListeners();
      // For now, just do second flip immediately after:
      card.isFlipped = false; // Toggle to show emoji face (second flip)
      
      // Match check logic already below handles _selectedIndices == 2, so add to indices
      if (_selectedIndices.length == 1) {
        _isLocked = true;
        notifyListeners();

        Timer(const Duration(milliseconds: 800), () {
          _checkMatch();
        });
      } else if (_selectedIndices.length == 2) {
        _isLocked = true;
        notifyListeners();

        Timer(const Duration(milliseconds: 800), () {
          _checkMatch();
        });
      }

      return; // Don't fall through to normal logic
    } else {
      // Card is already showing glyph (first flip), and player taps again to reveal emoji
      // For now, just treat it as already showing: skip or re-flip to reveal emoji
      return; // Prevent double-tap confusion
    }
  }

  // ... existing normal flipCard logic below this point ...
}
```

Hmm, the fragment modifier is getting complex. Let me simplify it for now: when a card is tapped in fragment mode, immediately show the emoji (like normal) but add a 1.5s delay before checking match, AND the card stays visible until then (no auto-flip). The "two flip" aspect is: player has to remember which glyph was where during the preview phase, and on the actual gameplay phase they see emojis but need to recall glyph positions.

Actually, a simpler approach: Fragment modifier = during preview phase, cards show glyphs (runic characters). During gameplay, they show emojis. Player has to remember the emoji-to-glyph mapping from preview. This is a pure memory twist, no state changes needed!

```dart
// In _generateCards for fragment modifier:
if (_activeModifier == LevelModifier.fragments) {
  // Assign each card a glyph based on its emoji's pair index
  final emojiToGlyph = <String, String>{};
  var glyphIdx = 0;
  
  for (var i = 0; i < _cards.length; i++) {
    final emoji = _cards[i].emoji;
    if (!emojiToGlyph.containsKey(emoji)) {
      emojiToGlyph[emoji] = DungeonCard._glyphs[glyphIdx % DungeonCard._glyphs.length]!;
      glyphIdx++;
    }
  }
  
  for (var i = 0; i < _cards.length; i++) {
    final glyph = emojiToGlyph[_cards[i].emoji]!;
    _cards[i] = DungeonCard(
      id: _cards[i].id,
      emoji: _cards[i].emoji,
      type: _cards[i].type,
      glyph: glyph, // NEW field
    );
  }
}

// In _startPuzzlePreview for fragment modifier:
void _startPuzzlePreview() {
  _cancelPuzzlePreviewTimers();
  final sessionId = ++_previewSessionId;

  _isLocked = true;
  _isPreviewingPuzzle = true;

  // Fragment modifier: show glyphs instead of emojis during preview
  for (final card in _cards) {
    if (_activeModifier == LevelModifier.fragments) {
      card.isFlipped = true; // Previews show glyph (handled in widget below)
    } else {
      card.isFlipped = true; // Normal preview shows emoji
    }
  }

  notifyListeners();

  _previewHoldTimer = Timer(_puzzlePreviewHoldDuration, () {
    if (sessionId != _previewSessionId) return;

    for (final card in _cards) {
      if (!card.isMatched) {
        card.isFlipped = false; // Hide all cards
      }
    }

    notifyListeners();

    _previewUnlockTimer = Timer(_puzzleFlipDuration, () {
      if (sessionId != _previewSessionId) return;

      _isPreviewingPuzzle = false;
      _isLocked = false;
      notifyListeners();
    });
  });
}

// In DungeonCardWidget._buildFrontFace for fragment modifier:
// When activeModifier == LevelModifier.fragments and card.isFlipped is true, show glyph instead of emoji.
// The widget already has access to game state — use isFlipped as "showing the back" during preview,
// and swap display logic. Actually, simplest: just show _cards[index].glyph when fragment mode is active
// and card is face-up. This requires adding a _isFragmenting flag to DungeonCard or passing it via GameState.
```

OK, fragment modifier is the most involved task. For now, I'll keep it simple: **Fragment = preview shows glyphs, gameplay shows emojis.** Player memorizes glyph→emoji mapping during the 1.2s preview, then plays normally with emojis but has to recall which glyph corresponded to which emoji.

This requires:
1. Adding `glyph` field to `DungeonCard` (Task 2.7)
2. Modifying `_startPuzzlePreview` to show glyphs during preview when fragment mode is active
3. Modifying `DungeonCardWidget._buildFrontFace` to check: if fragment mode + isFlipped → show glyph, else show emoji

I'll write these in the tasks below. For now, mark fragments as **Task 2.8** (lower priority, more complex).

---

### Task 2.3: Add modifier display to GameScreen HUD

**Objective:** Show the active modifier (if any) in the game screen's HUD so players know what they're dealing with.

**Files:**
- Modify: `lib/screens/game_screen.dart` (the `_buildHUD` method)

**Step 1: In the HUD row, add a modifier badge under the dungeon name**

Find this block in `_buildHUD`:
```dart
Column(
  children: [
    Text(gameState.activeDungeon.name.toUpperCase(), ...),
    Text('${gameState.activeDungeon.depth} • ${gameState.levelProgressString}', ...),
  ],
),
```

Replace with:
```dart
Column(
  children: [
    Text(gameState.activeDungeon.name.toUpperCase(), ...),
    if (gameState.activeDungeon.hasModifier)
      Text(
        gameState.activeDungeon.modifierName,
        style: DungeonTheme.getBodyStyle(10.0, const Color(0xFFE74C3C), weight: FontWeight.bold),
      ),
    Text('${gameState.activeDungeon.depth} • ${gameState.levelProgressString}', ...),
  ],
),
```

**Verification:** Start level 8 of Stone Chamber — HUD should show "🌑 SHADOW" between dungeon name and depth.

---

## Phase 3: The Dungeon Shop

Let players spend lifetime coins on artifacts between dungeons. This is the "reward" that makes repeated runs meaningful.

### Task 3.1: Create the Shop screen

**Objective:** A new screen that appears after completing a dungeon, offering artifacts for purchase with lifetime coins.

**Files:**
- Create: `lib/screens/shop_screen.dart`
- Modify: `lib/models/game_state.dart` (add `_shopCoins` getter and artifact purchase method)
- Modify: `lib/models/dungeon_config.dart` (add `getArtifactCost` helper, or keep costs in GameState)

**Step 1: Add coin spending logic to GameState**

```dart
// In GameState class, add:
int get shopCoins => _totalCoins; // Lifetime coins available for shop

void purchaseArtifact(String artifactId) {
  final cost = _getArtifactCost(artifactId);
  
  if (_totalCoins < cost || _artifactsUnlocked.contains(artifactId)) {
    return; // Can't afford or already owned
  }

  _totalCoins -= cost;
  _artifactsUnlocked.add(artifactId);
  notifyListeners();
  
  unawaited(_saveCampaignProgress()); // Persist artifact purchase
}

int _getArtifactCost(String artifactId) {
  switch (artifactId) {
    case 'extra_hint': return 10;   // Cheap starter artifact
    case 'lives_boost': return 25;  // Mid-tier power boost
    case 'poison_sight': return 15; // Strategic info artifact
    default: return 999;            // Unknown/locked
  }
}

void completeDungeonAndAwardCoins() {
  final coinsEarned = _activeDungeon.getRewardCoinsForLevel(_currentLevel);
  _totalCoins += coinsEarned; // Add run coins to lifetime stash
}
```

Add `_totalCoins` field in `GameState`:

```dart
int _totalCoins = 0; // Lifetime coins (persisted)
```

Update `_saveCampaignProgress` to include it:
```dart
// In toJson of CampaignProgress, already added 'totalCoins' field.
```

**Step 2: Create `lib/screens/shop_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../theme/dungeon_theme.dart';
import 'dungeon_selector_screen.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = Provider.of<GameState>(context);
    final theme = DungeonTheme.getTheme(DungeonThemeType.stone);

    return Scaffold(
      body: Stack(
        children: [
          Container(decoration: BoxDecoration(gradient: theme.bgGradient)),
          const Padding(top: 16, left: 16, right: 16),
          
          SafeArea(
            child: Column(
              children: [
                // Back button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha((0.3 * 255).toInt()),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.arrow_back, size: 14, color: Colors.white70),
                              SizedBox(width: 6),
                              Text('RETURN', style: TextStyle(fontSize: 11, color: Colors.white70)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                
                // Shop title
                Text(
                  'RUNIC ARTIFACTS',
                  style: DungeonTheme.getTitleStyle(context, const Color(0xFFF1C40F)),
                ),
                
                // Coin balance
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${gameState.shopCoins} 🪙 Available',
                    style: DungeonTheme.getBodyStyle(12.0, const Color(0xFFF1C40F)),
                  ),
                ),

                const SizedBox(height: 24),

                // Artifact list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: gameState.artifactsCatalogue.length,
                    itemBuilder: (context, index) {
                      final artifactId = gameState.artifactsCatalogue.keys.elementAt(index);
                      final artifact = gameState.artifactsCatalogue[artifactId]!;
                      final cost = gameState._getArtifactCost(artifactId);
                      final owned = gameState.artifactsUnlocked.contains(artifactId);
                      
                      return _buildArtifactCard(context, artifactId, artifact, cost, owned, gameState);
                    },
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtifactCard(
    BuildContext context,
    String artifactId,
    dynamic artifact, // _ArtifactDef
    int cost,
    bool owned,
    GameState gameState,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withAlpha((0.3 * 255).toInt()),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: owned ? const Color(0xFF27AE60) : const Color(0xFF5A6B7C)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(owned ? Icons.check_circle : Icons.stars, color: owned ? const Color(0xFF27AE60) : Colors.amber),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artifact.name,
                      style: DungeonTheme.getBodyStyle(12.0, Colors.white, weight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      artifact.description,
                      style: DungeonTheme.getBodyStyle(10.0, Colors.white54),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              owned
                  ? Text('OWNED', style: DungeonTheme.getBodyStyle(10.0, const Color(0xFF27AE60), weight: FontWeight.bold))
                  : ElevatedButton(
                      onPressed: () {
                        if (gameState.shopCoins >= cost) {
                          gameState.purchaseArtifact(artifactId);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Need $cost 🪙')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF1C40F), foregroundColor: Colors.black),
                      child: Text('$cost 🪙'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
```

**Step 3: Wire ShopScreen into the victory flow**

In `game_screen.dart`, `_buildVictoryOverlay`, when a dungeon is fully cleared (`isLastLevel`), add "OPEN SHOP" as an option:

Find the victory overlay buttons and modify:
```dart
// After "DESCEND" or "ASCEND HOME", add conditional shop button:
if (isLastLevel && hasNextChamber) {
  // Add Shop button between "Chamber Map" and "Descend"
}
```

Actually, simpler: on "Cleared" screen for the last level of a dungeon, add a third button:

```dart
// In _buildVictoryOverlay, replace the Row of buttons with a Column:
Column(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    // Shop button (if dungeon cleared)
    if (isLastLevel && hasNextChamber)
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ElevatedButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ShopScreen()),
            );
          },
          child: Text('OPEN SHOP'),
        ),
      ),
    
    // Normal buttons Row (next level / descend)
    Row(
      children: [
        Expanded(child: ... 'CHAMBER MAP' button),
        const SizedBox(width: 12),
        Expanded(child: ... 'DESCEND' / 'NEXT LEVEL'),
      ],
    ),
  ],
),
```

And for `completeDungeonAndAwardCoins()`, call it in `_completeLevelIfSolved` when the final level is cleared:

```dart
bool _completeLevelIfSolved() {
  // ... existing code ...
  
  if (isLastLevel && hasNextChamber) {
    // Award coins to lifetime stash before showing shop
  }
  
  return true;
}
```

Actually, keep it simple: just add totalCoins whenever a level is cleared (it already does `_coins += reward` each level). The shop just reads `_totalCoins` which accumulates. No special "complete dungeon" event needed — coins trickle in per level, and the shop lets you spend them.

**Verification:** Clear all 20 levels of Stone Chamber. Victory screen shows "OPEN SHOP" button. Tap it → shop with 3 artifacts, costs displayed, coins deducted on purchase.

---

### Task 3.2: Navigate to Shop after clearing a dungeon

**Objective:** When the final level of a dungeon is cleared, add an "Open Shop" button to the victory overlay.

**Files:**
- Modify: `lib/screens/game_screen.dart` (the `_buildVictoryOverlay` method)

**Step 1: Add ShopScreen import and a shop button to the victory overlay buttons**

```dart
// At top of game_screen.dart, add:
import 'shop_screen.dart';

// In _buildVictoryOverlay, find the button Row and replace with:
Column(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    // Shop button when dungeon is cleared and there's a next chamber
    if (isLastLevel && hasNextChamber)
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const ShopScreen()),
              (route) => false, // Clear all navigation stack to menu
            );
          },
          icon: const Icon(Icons.store, size: 16),
          label: Text(
            'RUNIC SHOP',
            style: DungeonTheme.getBodyStyle(10.0, Colors.black, weight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF1C40F),
            foregroundColor: Colors.black,
          ),
        ),
      ),

    // Normal navigation buttons
    Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pushReplacement(context, ...),
            child: Text('CHAMBER MAP', ...),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () { /* ... existing logic ... */ },
            child: Text(!isLastLevel ? 'NEXT LEVEL' : hasNextChamber ? 'DESCEND' : 'ASCEND HOME', ...),
          ),
        ),
      ],
    ),
  ],
),
```

**Step 2: Ensure coins are credited to `_totalCoins` before showing shop**

In `GameState._completeLevelIfSolved`, add coin accumulation:
```dart
_coins += _activeDungeon.getRewardCoinsForLevel(_currentLevel);

// Add to lifetime stash
_totalCoins += _activeDungeon.getRewardCoinsForLevel(_currentLevel);
```

**Verification:** Clear level 20 of Stone Chamber. You should see "RUNIC SHOP" button on the victory overlay.

---

## Phase 4: Visual Enhancements (Beyond Emoji-Only Cards)

### Task 4.1: Add card glow color based on type in `DungeonCardWidget`

**Objective:** Make card types visually distinct at a glance, so players can scan the board and spot threats (poison) vs rewards (gems/treasure).

**Files:**
- Modify: `lib/widgets/dungeon_card_widget.dart` (the `_buildFrontFace` method)

**Step 1: Already done!** The existing code at line ~96 already does this:
```dart
final glowColor = DungeonTheme.getCardGlowColor(card.type);
```

The border and shadow already use glow colors per type. This is good — no change needed here.

---

### Task 4.2: Add poison card visual warning indicator

**Objective:** When `poison_sight` artifact is equipped, render a subtle red border or dot on poison cards so players can identify them without flipping.

**Files:**
- Modify: `lib/widgets/dungeon_card_widget.dart` (the `_buildBackFace` method)

**Step 1: Add poison indicator to card back face**

In `_buildBackFace`, after the `CustomPaint` painter, add:
```dart
// When poison_sight artifact is active and this card is poison type, show a subtle indicator on the back
// (Only effective when artifact is equipped — check GameState)

final hasPoisonSight = gameState.unlockedArtifacts.contains('poison_sight');
if (hasPoisonSight && card.type == CardType.poison) {
  // Subtle red dot in corner to indicate danger
} else {
  // Normal rune display
}
```

Add above the `_getRuneCharacter` text in the widget's build:
```dart
if (hasPoisonSight && card.type == CardType.poison) {
  Positioned(
    bottom: 6,
    right: 6,
    child: Container(
      width: 8, height: 8,
      decoration: BoxDecoration(color: const Color(0xFFE74C3C), shape: BoxShape.circle),
    ),
  );
}
```

**Verification:** Buy `poison_sight` in shop. In a dungeon with poison cards, card backs for poison pairs should have tiny red dots in the bottom-right corner.

---

### Task 4.3: Improve card back design with stone texture variations per dungeon theme

**Objective:** Make the card backs feel themed to each dungeon, not just generic stone.

**Files:**
- Modify: `lib/theme/stone_painter.dart` (the `StonePainter` class)

**Step 1: Add a `themeAccent` parameter to StonePainter that tints the cracks**

In `StonePainter`:
```dart
class StonePainter extends CustomPainter {
  final Color bgColor;
  final Color borderColor;
  final Color crackColor;
  final double borderRadius;
  final double borderWidth;
  final int seed;
  final Color? themeAccent; // NEW: tints the cracks with dungeon color

  StonePainter({
    required this.bgColor,
    required this.borderColor,
    required this.crackColor,
    required this.borderRadius,
    required this.borderWidth,
    required this.seed,
    this.themeAccent, // optional
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ... existing crack drawing code ...

    // Modify the drawCracks call to use themeAccent if provided:
    final effectiveCrackColor = themeAccent ?? crackColor;

    // ... rest of paint method unchanged, just swap crackColor -> effectiveCrackColor in the crack-drawing section ...
  }

  @override
  bool shouldRepaint(covariant StonePainter oldDelegate) {
    return bgColor != oldDelegate.bgColor ||
           borderColor != oldDelegate.borderColor ||
           crackColor != oldDelegate.crackColor ||
           themeAccent != oldDelegate.themeAccent; // NEW comparison
  }
}
```

Then in `DungeonCardWidget._buildBackFace`, pass the theme accent:
```dart
// In _buildBackFace, change:
CustomPaint(
  painter: StonePainter(
    bgColor: theme.cardBackBgColor,
    borderColor: theme.hudBorderColor,
    crackColor: theme.cardBackRuneColor.withAlpha((0.3 * 255).toInt()),
    borderRadius: 6.0,
    borderWidth: 1.5,
    drawCracks: true,
    seed: card.id,
  ),
```

To:
```dart
CustomPaint(
  painter: StonePainter(
    bgColor: theme.cardBackBgColor,
    borderColor: theme.hudBorderColor,
    crackColor: theme.accentColor.withAlpha((0.4 * 255).toInt()), // Use dungeon accent color for cracks
    borderRadius: 6.0,
    borderWidth: 1.5,
    seed: card.id,
  ),
```

**Verification:** Play as Lava Chamber → cracks should glow orange. Ice Chamber → blue cracks. Visual polish, no logic changes.

---

## Phase 5: Bug Fixes and Polish

### Task 5.1: Fix GameState listener leak in GameScreen

**Objective:** GameScreen adds a listener but doesn't remove it. The commented-out code at line 57-58 should be active.

**Files:**
- Modify: `lib/screens/game_screen.dart` (the `initState` and `dispose` methods)

**Step 1: Activate the listener removal**

```dart
@override
void initState() {
  super.initState();

  _shakeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  _flashController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    Provider.of<GameState>(context, listen: false).addListener(_handleStateEffects);
  });
}

@override
void dispose() {
  // FIX: Properly remove listener to prevent memory leaks
  final gameState = Provider.of<GameState>(context, listen: false);
  gameState.removeListener(_handleStateEffects);

  _shakeController.dispose();
  _flashController.dispose();
  
  // Also cancel any pending timers from modifiers
  // (If we add _timerFlipBack to GameState, cancel it here)

  super.dispose();
}
```

**Verification:** Navigate between screens rapidly. No console warnings about context not mounted or listener leaks.

---

### Task 5.2: Handle web platform for campaign progress store

**Objective:** The web store file is fully commented out. Uncomment and fix it so the game works on web too.

**Files:**
- Modify: `lib/services/local_campaign_progress_store_web.dart`

**Step 1: Uncomment and fix the web store implementation**

```dart
import 'dart:convert';

// import 'package:web/web.dart' as web;

import '../models/campaign_progress.dart';
import 'campaign_progress_store.dart';

class LocalCampaignProgressStore implements CampaignProgressStore {
  static const _storageKey = 'memory_dungeon.campaign_progress';

  @override
  Future<void> clear() async {
    web.window.localStorage.removeItem(_storageKey);
  }

  @override
  Future<CampaignProgress?> load() async {
    final raw = web.window.localStorage.getItem(_storageKey);
    if (raw == null) return null;

    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;

    return CampaignProgress.fromJson(Map<String, Object?>.from(decoded));
  }

  @override
  Future<void> save(CampaignProgress progress) async {
    web.window.localStorage.setItem(_storageKey, jsonEncode(progress.toJson()));
  }
}
```

Need to add `web` package dependency in `pubspec.yaml`:

```yaml
dependencies:
  web: ^0.5.1  # Add this line
```

**Verification:** Run `flutter run -d chrome`. Load a campaign, refresh page — progress persists.

---

## Files Summary

| File | Changes |
|------|---------|
| `lib/models/campaign_progress.dart` | Add `totalCoins`, `artifactsUnlocked`, version bump to 2, JSON migration |
| `lib/models/game_state.dart` | Add artifact system, meaningful tile effects (`_applyMatchEffects`), modifier state, `_totalCoins`, `_shuffledBoard`, timer/swap/shadow/sabotage logic |
| `lib/models/dungeon_config.dart` | Add `LevelModifier` enum, `_dungeonModifiers` map, `getModifierForLevel()`, modifier display helpers |
| `lib/models/dungeon_card.dart` | Add `glyph` field, update `copyWith`, add `_glyphs` map and `getGlyph()` |
| `lib/screens/shop_screen.dart` | **NEW** — Full shop UI with artifact purchasing |
| `lib/screens/game_screen.dart` | Add modifier badge to HUD, add Shop button to victory overlay, fix listener leak in dispose |
| `lib/widgets/dungeon_card_widget.dart` | Add poison sight indicator on card backs, pass theme accent to StonePainter |
| `lib/theme/stone_painter.dart` | Add optional `themeAccent` parameter, tint cracks with dungeon color |
| `lib/services/local_campaign_progress_store_web.dart` | Uncomment and fix web store implementation |
| `pubspec.yaml` | Add `web: ^0.5.1` dependency (optional, only for web support) |

## Verification Steps

After completing all tasks:
1. `flutter analyze lib/` — should return 0 errors, 0 warnings (except existing deprecation `withValues`)
2. Run on iOS simulator — play a level, match poison (one dissolves), match scroll (pair auto-matches)
3. Clear a dungeon → open shop → buy artifact → see effect in next run
4. Switch to level 8 of Stone Chamber → HUD shows "🌑 SHADOW" modifier
5. Switch to level 14 of Stone Chamber → board reshuffles every 5 flips
6. Navigate screens rapidly — no memory leak warnings in console

## Risks and Tradeoffs

1. **Fragment modifier complexity** — The glyph→emoji mapping during preview is a significant UX change. If it feels confusing, it can be disabled and replaced with a simpler "cards flip faster" modifier.
2. **Board shuffle (Swap modifier)** — Shuffling can feel unfair if it breaks a near-match. Consider adding a "shuffle preview" indicator (board dims briefly before reshuffling).
3. **Sabotage modifier** — Making two identical-emoji cards poison could cause genuine confusion/double-matches. Ensure the UI makes it clear these are traps (perhaps they glow differently).
4. **Artifact balancing** — The costs (10/15/25 coins) assume a certain coin earn rate. Monitor actual playtest data and adjust. The `lives_boost` (25 coins) should take ~2-3 dungeons to unlock.
5. **JSON migration** — The version bump from 1 to 2 in `CampaignProgress.toJson()` means old saves will get default values for new fields (0 coins, empty artifacts). This is intended — it's a fresh start for the shop system.

## Open Questions

1. Should the Shop appear *every* time a dungeon is cleared, or only once (e.g., after clearing all 6 dungeons)?
2. Are there additional artifacts to add beyond the starter 3? (Suggestions: `mismatch_shield` — immune to one mismatch penalty per dungeon; `time_freeze` — pause timer modifier for 5 seconds; `double_dip` — match two pairs per turn instead of one)
3. Should there be a "Daily Dungeon" mode with procedurally generated boards and modifiers? (Out of scope for this plan but a natural Phase 6 extension)
