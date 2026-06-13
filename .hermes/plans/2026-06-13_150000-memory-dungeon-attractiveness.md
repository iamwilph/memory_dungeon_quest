# Memory Dungeon: Gameplay & Attractiveness Expansion Plan

> **For Hermes:** Implement task-by-task. Read `.hermes/memory.md` before starting any phase, append progress entries only (never overwrite).

**Goal:** Transform Memory Dungeon from a solid but silent memory-match app into an immersive, engaging dungeon-crawling experience with sound, streaks, daily challenges, achievements, a campaign map, and polished visuals — while preserving the existing stone-rune aesthetic and Provider state architecture.

**Architecture:** Extend existing `GameState` + Provider pattern. Introduce new models only where needed (`DailyChallenge`, `AchievementManager`). Use existing services for persistence. Keep Material 3 dark theme, Cinzel font, stone-carved UI language intact.

**Tech Stack:** Flutter ^3.10.1, provider ^6.1.5+1, path_provider ^2.1.5

**Existing Dependencies to Add:**
- `audioplayers: ^6.0.0` — Local SFX + ambient audio
- `flip_card: ^0.7.0` — 3D card flip animation (or custom `Transform3D`)

---

## Phase 1: Sound Design 🎵 (Highest Impact, Medium Effort)

Currently the game is completely silent. Sound *is* atmosphere for a dungeon crawler — it transforms blank card-clicking into leaving an ancient tomb.

### Task 1.1: Set up Audio Player Service

**Objective:** Create a reusable audio service that handles SFX playback and ambient loopers.

**Files:**
- **NEW:** `lib/services/audio_service.dart` — Singleton audio manager wrapping `Audioplayers`
- Modify: `pubspec.yaml`

**Steps:**

1. Add dependency to `pubspec.yaml`:
```yaml
dependencies:
  audioplayers: ^6.0.0
  flip_card: ^0.7.0
```

2. Create `lib/services/audio_service.dart`:
```dart
import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  late final AudioPlayer _sfxPlayer;   // Short sounds, overlap-friendly
  late final AudioPlayer _ambientPlayer; // Long looping ambient tracks

  bool _isMuted = false;
  String? _currentAmbientDungeon;

  void init() {
    _sfxPlayer = AudioPlayer(playerId: 'sfx');
    _ambientPlayer = AudioPlayer(playerId: 'ambient');
    // Configure ambient for looping
    _ambientPlayer.setReleaseMode(ReleaseMode.loop);
  }

  Future<void> playSfx(String assetPath) async {
    if (_isMuted) return;
    try {
      await _sfxPlayer.play(AssetSource('audio/$assetPath'));
    } catch (e) {
      // Silently fail if asset missing — don't crash the game
    }
  }

  Future<void> playSfxOnce({required String assetPath, required VoidCallback onComplete}) async {
    if (_isMuted) { onComplete(); return; }
    final player = AudioPlayer(playerId: 'sfx-once');
    await player.play(AssetSource('audio/$assetPath'));
    player.onPlayerComplete.listen((_) {
      onComplete();
      player.dispose();
    });
  }

  Future<void> startAmbient(String dungeonId) async {
    if (_isMuted || _currentAmbientDungeon == dungeonId) return;
    // Stop current ambient first
    await _ambientPlayer.stop();
    try {
      final path = _getAmbientPath(dungeonId);
      if (path != null) {
        await _ambientPlayer.play(AssetSource('audio/$path'));
        _currentAmbientDungeon = dungeonId;
      } else {
        // Fallback: no ambient, just silence or generic stone ambience
        _currentAmbientDungeon = 'generic';
      }
    } catch (e) {
      _currentAmbientDungeon = null;
    }
  }

  Future<void> stopAmbient() async {
    await _ambientPlayer.stop();
    _currentAmbientDungeon = null;
  }

  void setMuted(bool muted) => _isMuted = muted;
  bool get isMuted => _isMuted;

  String? _getAmbientPath(String dungeonId) {
    switch (dungeonId) {
      case 'stone': return 'ambience/stone_drip.mp3';
      case 'lava': return 'ambience/lava_rumble.mp3';
      case 'ice': return 'ambience/ice_crack.mp3';
      case 'crypt': return 'ambience/crypt_wind.mp3';
      case 'voidChamber': return 'ambience/void_hum.mp3';
      case 'forest': return 'ambience/forest_whisper.mp3';
      default: return null;
    }
  }

  void dispose() {
    _sfxPlayer.dispose();
    _ambientPlayer.dispose();
  }
}
```

3. Initialize in `lib/main.dart`:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AudioService().init(); // Add this line
  runApp(ChangeNotifierProvider(...));
}
```

4. Wire up ambient audio in `GameScreen`:
- In `_handleStateEffects` or on level init, call `AudioService().startAmbient(gameState.activeDungeon.id)`
- On screen dispose, call `AudioService().stopAmbient()`
- Add a mute toggle button in the HUD (top-right corner)

### Task 1.2: Create SFX Asset List

**Objective:** Define every sound effect needed and where it plays. Provide placeholder WAV/MP3 files (or instructions for generating them).

**Files:**
- **NEW:** `assets/audio/sfx/flip.wav` — Card flip (short click)
- **NEW:** `assets/audio/sfx/match.wav` — Successful match (pleasant chime)
- **NEW:** `assets/audio/sfx/mismatch.wav` — Mismatch (low thud)
- **NEW:** `assets/audio/sfx/poison.wav` — Poison match (sizzle/hiss)
- **NEW:** `assets/audio/sfx/heal.wav` — Healing potion (warm ascending tone)
- **NEW:** `assets/audio/sfx/gem.wav` — Gem match (crystal bell)
- **NEW:** `assets/audio/sfx/scroll.wav` — Scroll use (paper rustle + magic spark)
- **NEW:** `assets/audio/sfx/treasure.wav` — Treasure match (coin jingle)
- **NEW:** `assets/audio/sfx/shuffle.wav` — Board shuffle (whoosh)
- **NEW:** `assets/audio/sfx/victory.wav` — Level clear fanfare (3 notes ascending)
- **NEW:** `assets/audio/sfx/gameover.wav` — Death sound (descending tones)
- **NEW:** `assets/audio/sfx/whoosh.wav` — UI navigation transitions

**Steps:**

1. Create directory `assets/audio/sfx/` and add all WAV files (short, < 500KB each).
   - For placeholder purposes, generate simple WAVs programmatically or use free SFX from freesound.org
   - Key requirement: flip sound must be VERY short (< 100ms) so rapid plays feel snappy

2. Create ambient audio directory `assets/audio/ambience/`:
   - `stone_drip.mp3` — Water dripping in stone cavern (loop, ~30s)
   - `lava_rumble.mp3` — Distant lava bubbling (loop, ~45s)
   - `ice_crack.mp3` — Ice cracking and wind (loop, ~40s)
   - `crypt_wind.mp3` — Haunting wind through tomb (loop, ~60s)
   - `void_hum.mp3` — Low electronic drone (loop, ~45s)
   - `forest_whisper.mp3` — Rustling leaves, distant bird (loop, ~40s)

3. Wire SFX triggers into `GameState._applyMatchEffects()`:
```dart
void _applyMatchEffects(CardType type) {
  final audio = AudioService();
  switch (type) {
    case CardType.poison:
      audio.playSfx('sfx/poison');
      _lives--;
      // ... rest of logic
    case CardType.healing:
      audio.playSfx('sfx/heal');
      // ... rest of logic
    case CardType.treasure:
      audio.playSfx('sfx/treasure');
      // ... rest of logic
    case CardType.scroll:
      audio.playSfx('sfx/scroll');
      // ... rest of logic
    case CardType.gem:
      audio.playSfx('sfx/gem');
      // ... rest of logic
    case CardType.normal:
      audio.playSfx('sfx/match'); // Normal matches get the pleasant chime too
      _score += 10;
      break;
  }
}
```

4. Wire flip/mismatch SFX into `GameState.flipCard()` and `_checkMatch()`:
```dart
void flipCard(int index) {
  // ... existing logic...
  AudioService().playSfx('sfx/flip');
}

void _checkMatch() {
  // ... existing logic...
  if (card1.emoji == card2.emoji) {
    audio.playSfx('sfx/match');
  } else {
    audio.playSfx('sfx/mismatch');
  }
}
```

5. Wire victory/gameover SFX into `_completeLevelIfSolved()` and game-over path

### Task 1.3: Add Audio Settings to HUD

**Objective:** Let players toggle mute/unmute from the game screen.

**Files:**
- Modify: `lib/screens/game_screen.dart` — Add mute toggle to HUD

**Steps:**
1. In `_buildHUD`, add a small speaker icon button (top-right corner, near "FLEE" but on the right side)
2. Toggle calls `AudioService().setMuted(!audio.isMuted)`
3. Show muted icon when audio is off
4. Persist mute preference in shared preferences (add `shared_preferences` dependency for this single boolean, or store it alongside campaign progress)

---

## Phase 2: Combo/Streak System 🔥 (High Engagement, Low-Medium Effort)

Consecutive correct matches build a streak multiplier. Gives players a reason to play fast and accurately, not just carefully.

### Task 2.1: Add Streak State to GameState

**Objective:** Track consecutive correct matches, maintain a streak counter and multiplier.

**Files:**
- Modify: `lib/models/game_state.dart`

**Steps:**

1. Add streak fields to `GameState`:
```dart
int _streakCount = 0;       // Current consecutive correct matches
double _streakMultiplier = 1.0; // Score multiplier from streak (capped at 3x)
static const int _maxStreak = 10; // After 10 streaks, multiplier caps
```

2. Reset streak on mismatch in `_checkMatch()`:
```dart
void _checkMatch() {
  // ... existing logic...
  if (card1.emoji != card2.emoji) {
    _streakCount = 0;     // Reset streak!
    _streakMultiplier = 1.0;
    // ... rest of mismatch logic...
  }
}
```

3. Increment streak on match in `_checkMatch()`:
```dart
if (card1.emoji == card2.emoji) {
  _streakCount++;
  // Calculate streak multiplier: every 3 consecutive, +0.5x up to 3x
  _streakMultiplier = (1.0 + (min(_streakCount, _maxStreak) ~/ 3) * 0.5).clamp(1.0, 3.0);
  // ... rest of match logic...
}
```

4. Update score calculation to include streak multiplier in `_checkMatch()`:
```dart
final addedScore = (100 * dungeonMult * _scoreMultiplier * _streakMultiplier).round();
```

5. Apply streak bonus on level clear:
```dart
bool _completeLevelIfSolved() {
  // ... existing logic...
  if (_streakCount >= 5) {
    _coins += _streakCount; // Bonus coins for long streaks at level end
  }
  _streakCount = 0;         // Reset for next level
  _streakMultiplier = 1.0;
  return true;
}
```

### Task 2.2: Display Streak in HUD

**Objective:** Show streak counter prominently in the game screen HUD.

**Files:**
- Modify: `lib/screens/game_screen.dart` — Add streak display to HUD

**Steps:**
1. In the stats row, add a "Streak" element between Score and Hearts (or below Score)
2. Display streak count with a fire icon 🔥: `🔥 3` (meaning 3 consecutive matches)
3. When streak >= 5, display the multiplier: `🔥 7 (1.5x)`
4. When streak reaches 10+, show a glow/flash effect on the streak counter (use existing `_triggerFlash` mechanism)
5. When a mismatch occurs, briefly show "Streak Broken!" text animation (overlay for 1 second then fade)

### Task 2.3: Streak Visual Feedback

**Objective:** Give the streak counter personality — it should feel alive.

**Files:**
- Modify: `lib/screens/game_screen.dart` — Streak widget + effect animations

**Steps:**
1. When streak reaches milestones (3, 6, 9), trigger a golden flash on the HUD
2. The streak icon animates: scale up slightly with each correct match, pulse red when broken
3. Show streak number in a rune-style font (use `DungeonTheme.getRuneStyle`)
4. When streak >= 5 and player matches a gem, show combined bonus (gem multiplier + streak = big score pop)

---

## Phase 3: Achievements & Milestones 🏆 (Fun Bonus, Low Effort)

Completionists love chasing badges. Extends replay time significantly with minimal code.

### Task 3.1: Create Achievement Model and Manager

**Objective:** Define achievement definitions, track progress, persist unlocked state.

**Files:**
- **NEW:** `lib/models/achievement.dart` — Achievement definition model
- **NEW:** `lib/services/achievement_manager.dart` — Tracks and persists achievements

**Steps:**

1. Create `lib/models/achievement.dart`:
```dart
class Achievement {
  final String id;          // e.g. "first_blood", "flawless_run"
  final String name;        // Display name: "First Blood"
  final String description; // Description shown to player
  final IconData icon;      // Achievement icon
  final Color? borderColor; // Color when unlocked (null = locked)
  
  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.borderColor,
  });
}

class AchievementProgress {
  final String achievementId;
  int currentCount;         // Current progress count
  int requirement;          // How many to unlock

  const AchievementProgress({
    required this.achievementId,
    required this.currentCount,
    required this.requirement,
  });

  bool get isUnlocked => currentCount >= requirement;

  AchievementProgress copyWith({int? currentCount, int? requirement}) {
    return AchievementProgress(
      achievementId: achievementId,
      currentCount: currentCount ?? this.currentCount,
      requirement: requirement ?? this.requirement,
    );
  }

  Map<String, Object?> toJson() => {
    'achievementId': achievementId,
    'currentCount': currentCount,
    'requirement': requirement,
  };

  factory AchievementProgress.fromJson(Map<String, dynamic> json) {
    return AchievementProgress(
      achievementId: json['achievementId'] as String,
      currentCount: json['currentCount'] as int? ?? 0,
      requirement: json['requirement'] as int? ?? 1,
    );
  }

  @override
  bool operator ==(Object other) => identical(this, other) ||
    other is AchievementProgress && achievementId == other.achievementId;

  @override
  int get hashCode => achievementId.hashCode;
}
```

2. Create `lib/services/achievement_manager.dart`:
```dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';

class AchievementManager {
  static final AchievementManager _instance = AchievementManager._internal();
  factory AchievementManager() => _instance;
  AchievementManager._internal();

  final List<Achievement> achievements = [
    // First-time milestones
    Achievement(id: 'first_blood', name: 'First Blood', description: 'Clear your first level.', icon: Icons.stars, borderColor: Colors.amber),
    Achievement(id: 'first_dungeon', name: 'Dungeon Delver', description: 'Clear an entire dungeon.', icon: Icons.military_tech, borderColor: Colors.amber),
    Achievement(id: 'all_dungeons', name: 'Dungeon Master', description: 'Clear all 6 dungeons.', icon: Icons.workspace_premium, borderColor: Colors.amber),
    
    // Streak milestones
    Achievement(id: 'streak_5', name: 'On Fire!', description: 'Reach a 5-match streak.', icon: Icons.local_fire_department, borderColor: Colors.orange),
    Achievement(id: 'streak_10', name: 'Unstoppable!', description: 'Reach a 10-match streak.', icon: Icons.speed, borderColor: Colors.red),
    Achievement(id: 'perfect_run', name: 'Flawless Victory!', description: 'Complete a level with zero mismatches.', icon: Icons.emoji_events, borderColor: Colors.purple),
    
    // Play milestones  
    Achievement(id: 'poison_avoided', name: 'Poison Immune', description: 'Complete a level with only poison tiles remaining (unmatched).', icon: Icons.science, borderColor: Colors.green),
    Achievement(id: 'gems_100', name: 'Gem Hoarder', description: 'Match 100 total gem tiles across all runs.', icon: Icons.diamond, borderColor: Colors.blue),
    Achievement(id: 'scrolls_10', name: 'Spell Scholar', description: 'Match 10 total magic scrolls across all runs.', icon: Icons.auto_stories, borderColor: Colors.teal),
    Achievement(id: 'coins_500', name: 'Midas Touch', description: 'Earn 500 lifetime coins.', icon: Icons.monetization_on, borderColor: Colors.yellow),
    Achievement(id: 'score_50k', name: 'High Roller', description: 'Achieve a 50,000 total score across all runs.', icon: Icons.emoji_objects, borderColor: Colors.pink),
    
    // Completionist milestones
    Achievement(id: 'hint_20', name: 'Helpful Hand', description: 'Use 20 hint charges total.', icon: Icons.lightbulb, borderColor: Colors.yellow),
    Achievement(id: 'all_artifacts', name: 'Artificer', description: 'Purchase all artifacts in the shop.', icon: Icons.store, borderColor: Colors.indigo),
    Achievement(id: 'lives_0', name: 'Death Defier', description: 'Clear a level with only 1 life remaining.', icon: Icons.favorite, borderColor: Colors.red),
    Achievement(id: 'lava_veteran', name: 'Lava Walker', description: 'Complete all 20 levels of the Lava Chamber.', icon: Icons.local_fire_department, borderColor: Colors.red),
    Achievement(id: 'crypt_veteran', name: 'Crypt Keeper', description: 'Complete all 20 levels of the Crypt.', icon: Icons.grave, borderColor: Colors.grey),
  ];

  Map<String, AchievementProgress> _progress = {};
  List<Achievement> unlocked = [];

  void init() {
    _loadProgress();
  }

  void increment(String achievementId, [int delta = 1]) {
    _progress.putIfAbsent(achievementId, () => const AchievementProgress(
      achievementId: '',
      currentCount: 0, 
      requirement: 1,
    ));

    final existing = _progress[achievementId]!;
    
    // Set requirement if not set yet using the achievement definition
    final def = achievements.firstWhere(
      (a) => a.id == achievementId, 
      orElse: () => throw Exception('Unknown achievement: $achievementId')
    );

    final newProgress = existing.copyWith(
      currentCount: existing.currentCount + delta,
      requirement: def.id == 'gems_100' ? 100 : 
                  def.id == 'scrolls_10' ? 10 :
                  def.id == 'coins_500' ? 500 :
                  def.id == 'score_50k' ? 50000 :
                  def.id == 'hint_20' ? 20 :
                  existing.requirement,
    );

    _progress[achievementId] = newProgress;
    
    if (newProgress.isUnlocked && !unlocked.contains(achievementId)) {
      unlocked.add(achievementId);
      _saveProgress();
    }
  }

  AchievementProgress? getProgress(String achievementId) => _progress[achievementId];
  
  bool isUnlocked(String achievementId) => unlocked.contains(achievementId);

  Future<void> _loadProgress() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/achievements.json');
    if (!file.existsSync()) return;

    try {
      final content = await file.readAsString();
      final data = jsonDecode(content) as List<dynamic>;
      _progress = {
        for (final entry in data) 
          AchievementProgress.fromJson(entry as Map<String, dynamic>).achievementId: AchievementProgress.fromJson(entry as Map<String, dynamic>)
      };
    } catch (e) {
      // Corrupted file — reset to defaults
      _progress = {};
    }

    unlocked = _progress.values.where((p) => p.isUnlocked).map((p) => p.achievementId).toList();
  }

  Future<void> _saveProgress() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/achievements.json');
    await file.writeAsString(jsonEncode(_progress.values.toList()));
  }

  void reset() {
    _progress.clear();
    unlocked.clear();
    // Clear file
    final dir = await getApplicationDocumentsDirectory();
    File('${dir.path}/achievements.json').deleteSync();
  }
}
```

3. Initialize `AchievementManager` in `main.dart`:
```dart
await AchievementManager().init();
```

### Task 3.2: Integrate Achievements into GameState

**Objective:** Track achievement progress as the player plays.

**Files:**
- Modify: `lib/models/game_state.dart` — Add achievement tracking calls

**Steps:**

1. Import and reference `AchievementManager()`:
```dart
import '../services/achievement_manager.dart';
```

2. In `_completeLevelIfSolved()`:
```dart
bool _completeLevelIfSolved() {
  // ... existing logic...
  
  final ach = AchievementManager();
  ach.increment('first_blood', 1); // Every level clear counts toward first blood
  
  // Check if this was a flawless run (no mismatches during level)
  // We'd need to track mismatch count in GameState — add this:
  if (_mismatchesSinceLevelStart == 0 && _cardsAllMatched) {
    ach.increment('perfect_run', 1);
  }
  
  // Check if player was on low life before level clear (lives <= 1)
  if (_lives == 1) {
    ach.increment('lives_0', 1);
  }

  // Check per-dungeon completion
  if (_currentLevel >= DungeonConfig.levelsPerDungeon) {
    ach.increment('first_dungeon', 1);
    if (_unlockedDungeonIndex >= DungeonConfig.dungeons.length - 1) {
      ach.increment('all_dungeons', 1);
    }
    // Check which dungeon was just completed
    if (_activeDungeon.id == 'lava') ach.increment('lava_veteran', 1);
    if (_activeDungeon.id == 'crypt') ach.increment('crypt_veteran', 1);
  }

  return true;
}
```

3. In `_applyMatchEffects()`:
```dart
void _applyMatchEffects(CardType type) {
  final ach = AchievementManager();
  
  switch (type) {
    case CardType.gem:
      ach.increment('gems_100', 1);
      break;
    case CardType.scroll:
      ach.increment('scrolls_10', 1);
      break;
    // ... other cases...
  }
  
  _score += addedScore;
  ach.increment('score_50k', _score); // Total score check happens here
  
  // Also increment lifetime coins in shop context
  _coins += ...;
  final currentProgress = ach.getProgress('coins_500');
  // Lifetime coins are in GameState._totalCoins — need to call:
  ach.increment('coins_500', _coins); // track run coins too
}
```

4. In `flipCard()` for streak milestones:
```dart
if (_streakCount == 5) ach.increment('streak_5', 1);
if (_streakCount == 10) ach.increment('streak_10', 1);
```

### Task 3.3: Add Achievements UI Screen

**Objective:** Let players view their unlocked achievements, starting from the menu.

**Files:**
- **NEW:** `lib/screens/achievements_screen.dart` — Achievement list screen

**Steps:**
1. Create a screen similar to `shop_screen.dart` — grid of achievement cards
2. Locked achievements show grayed-out icon + "???" name
3. Unlocked achievements glow gold with full details
4. Add button to MenuScreen: "ACHIEVEMENTS" (after "ARTIFACT MARKET", before "RESET CAMPAIGN")
5. Each achievement card shows: icon, name, description, progress bar (e.g., "75/100 gems matched")

---

## Phase 4: Daily Challenge Mode 📅 (Retention Gold, Medium Effort)

One randomly generated dungeon per day. Creates a "come back tomorrow" loop — #1 retention mechanic for puzzle games.

### Task 4.1: Create Daily Challenge Model and Logic

**Objective:** Generate a unique daily dungeon with fixed seed based on date. Track player's daily performance and local high scores.

**Files:**
- **NEW:** `lib/models/daily_challenge.dart` — Daily challenge definition, seed generation, state
- Modify: `lib/models/game_state.dart` — Add daily challenge mode flag and overrides

**Steps:**

1. Create `lib/models/daily_challenge.dart`:
```dart
import 'package:flutter/material.dart';

class DailyChallenge {
  final DateTime date;           // The day this challenge is for (UTC midnight)
  final int seed;               // Fixed random seed derived from date
  final String dungeonId;       // Which dungeon theme to use
  final int baseGridSize;       // Base grid size (pairs) for the day's challenge
  final List<LevelModifier> modifiers; // Modifiers active today
  final bool hasMismatchPenalty; // Override mismatch penalty for the day

  // Pre-computed: this runs only once per date
  static int _seedForDate(DateTime date) {
    // Simple hash: year * 1000 + month * 100 + day
    final hashCode = date.year * 367;
    return ((hashCode + date.month * 31) * 31 + date.day) % 100000;
  }

  static DailyChallenge generateForDate(DateTime date) {
    final seed = _seedForDate(date);
    
    // Pick dungeon based on seed (deterministic)
    final dungeons = ['stone', 'lava', 'ice', 'crypt', 'voidChamber', 'forest'];
    final dungeonId = dungeons[seed % dungeons.length];
    
    // Pick modifier based on seed
    List<LevelModifier> modifiers;
    final modSeed = (seed ~/ dungeons.length) % 256;
    
    // Start from level 1, maybe pick a harder starting level for variety
    final startLevel = ((seed ~/ (dungeons.length * 256)) % 10) + 1; // Levels 1-10
    
    switch (modSeed % 5) {
      case 0: modifiers = [LevelModifier.none]; break;
      case 1: modifiers = [LevelModifier.shadow]; break;
      case 2: modifiers = [LevelModifier.timer]; break;
      case 3: modifiers = [LevelModifier.swap]; break;
      default: modifiers = [LevelModifier.sabotage]; break;
    }

    // Some days get extra punishment (1 in 5 chance)
    if (modSeed % 25 == 0) {
      modifiers.add(LevelModifier.shadow); // Double modifier on brutal days
    }

    return DailyChallenge(
      date: _truncateToMidnight(date),
      seed: seed,
      dungeonId: dungeonId,
      baseGridSize: 6 + (seed % 4), // 6-9 pairs, scales slightly each day
      modifiers: modifiers,
      hasMismatchPenalty: modSeed > 200, // Brutal days have penalties
    );
  }

  static DateTime _truncateToMidnight(DateTime dt) => 
    DateTime.utc(dt.year, dt.month, dt.day);

  static DailyChallenge getToday() => generateForDate(DateTime.now());
}

class DailyChallengeProgress {
  final String date;              // Date string "YYYY-MM-DD"
  int score;                      // Score achieved (0 = not attempted)
  bool isCompleted;               // Was the level cleared?
  int livesRemaining;             // Lives left when cleared (or 0)

  const DailyChallengeProgress({
    required this.date,
    required this.score,
    required this.isCompleted,
    required this.livesRemaining,
  });

  DailyChallengeProgress copyWith({int? score, bool? isCompleted, int? livesRemaining}) {
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
  bool operator ==(Object other) => identical(this, other) ||
    other is DailyChallengeProgress && date == other.date;

  @override
  int get hashCode => date.hashCode;
}
```

2. Add daily challenge state to `GameState`:
```dart
// In GameState class:
DailyChallenge? _dailyChallenge;
bool _isDailyMode = false;

void initDailyChallenge() {
  final today = DailyChallenge.getToday();
  _dailyChallenge = today;
  _isDailyMode = true;
  
  // Initialize dungeon with daily parameters
  // Use the same initDungeon logic but override grid size, modifiers, etc.
}

DailyChallenge? get dailyChallenge => _dailyChallenge;
bool get isDailyMode => _isDailyMode;

// Override level configuration when in daily mode
int get _dailyGridSize => _dailyChallenge?.baseGridSize ?? activeCols * activeRows;

// When starting a daily level, pass the seed to grid generation
void initDailyLevel(int levelIndex) {
  _isDailyMode = true;
  _dailyChallenge = DailyChallenge.getToday();
  
  // Use the seed for reproducible grid generation
  _seededRandom = Random(_dailyChallenge!.seed + levelIndex);
  
  // Apply the day's modifiers instead of normal dungeon modifiers
  _activeModifier = _dailyChallenge!.modifiers.first;
  
  // Apply mismatch penalty override
  _mismatchPenaltyOverride = _dailyChallenge!.hasMismatchPenalty;
  
  initDungeonByIndex(0); // Always stone dungeon base, but override parameters
}

// Helper for seeded random (deterministic boards)
Random? _seededRandom;

int? getSeededInt({required int min, required int max}) {
  if (_seededRandom != null) {
    return _seededRandom!.nextInt(max - min + 1) + min;
  }
  return Random().nextInt(max - min + 1) + min;
}

// In grid generation, use seeded random when in daily mode:
void _generateCards() {
  final random = _seededRandom ?? Random();
  // ... rest of generation uses 'random' instead of global Random()
}
```

### Task 4.2: Add Daily Challenge Entry Point to Menu

**Objective:** Let players access the daily challenge from the main menu. Show the current day's challenge preview (dungeon theme, modifiers) without revealing the board.

**Files:**
- Modify: `lib/screens/menu_screen.dart` — Add "DAILY CHALLENGE" button
- Modify: `lib/screens/dungeon_selector_screen.dart` — Add daily challenge card

**Steps:**
1. In `MenuScreen`, add a "DAILY CHALLENGE" button between "ARTIFACT MARKET" and "RESET CAMPAIGN":
```dart
MenuButton(
  text: 'DAILY CHALLENGE',
  icon: Icons.calendar_today,
  onPressed: () {
    // Navigate to daily challenge preview/entry screen
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DailyChallengeScreen()),
    );
  },
),
```

2. Create `lib/screens/daily_challenge_screen.dart` — Shows today's challenge details:
   - Date displayed as "Day of the [Month]" in rune text (e.g., "ᗪᗩᎴ 13 ᛟᚠ ᛃᚢᚾᛖ")
   - Today's dungeon theme icon and name (e.g., "⚰️ Crypt Chamber")
   - Today's modifier(s) badge (e.g., "🌑 Shadow + Timer")
   - Mismatch penalty indicator
   - Grid size hint (e.g., "7 pairs")
   - Button: "DESCEND" — enters daily mode
   - If already played today, show previous score and a "RETRY" button

3. Wire the "DESCEND" button to call `GameState.initDailyLevel(1)` and navigate to GameScreen

4. Save daily challenge progress after each attempt (win or lose) in `campaign_progress.dart`

### Task 4.3: Daily Challenge Progress Persistence

**Objective:** Persist daily challenge attempts and results so players can come back and continue their streak.

**Files:**
- Modify: `lib/models/campaign_progress.dart` — Add daily challenge history

**Steps:**
1. Add `dailyChallengeHistory` field (List<DailyChallengeProgress>) to CampaignProgress
2. Update JSON serialization:
```dart
Map<String, Object?> toJson() {
  return {
    // ... existing fields...
    'dailyChallengeHistory': dailyChallengeHistory.map((d) => d.toJson()).toList(),
  };
}

factory CampaignProgress.fromJson(Map<String, Object?> json) {
  // ... existing parsing...
  
  final rawDailyHistory = json['dailyChallengeHistory'];
  final List<DailyChallengeProgress> history;
  if (rawDailyHistory is List) {
    history = rawDailyHistory
        .map((e) => DailyChallengeProgress.fromJson(e as Map<String, dynamic>))
        .toList();
  } else {
    history = [];
  }

  return CampaignProgress(
    // ... existing fields...
    dailyChallengeHistory: history,
  );
}
```

3. In `_completeLevelIfSolved()`, when in daily mode:
```dart
if (_isDailyMode) {
  // Save daily challenge result
  final today = DailyChallenge.getToday();
  final yesterdayProgress = getDailyHistoryForDate(today.date);
  
  _dailyChallengeHistory.add(DailyChallengeProgress(
    date: today.date.toString(),
    score: _score,
    isCompleted: true,
    livesRemaining: _lives,
  ).copyWith(
    // Update if already exists
    score: yesterdayProgress?.score ?? _score,
  ));

  // Award bonus coins if completed (small daily challenge bonus)
  _coins += 10; // Daily completion bonus
}
```

---

## Phase 5: Campaign Map (Vertical Dungeon View) 🗺️ (Theme Immersion, Medium Effort)

Replace the scrollable list of dungeons with an actual vertical dungeon map — rooms connected by corridors. Makes it feel like a real dungeon crawl, not a menu.

### Task 5.1: Create Campaign Map Screen with Room Rendering

**Objective:** Build a vertical, scrollable map showing dungeon rooms as connected chambers. Each room shows progress dots (level cleared = filled).

**Files:**
- **NEW:** `lib/screens/campaign_map_screen.dart` — Full campaign map rendering
- Modify: `lib/widgets/hud_element.dart` (optional) — Add corridor/room connector drawing capability

**Steps:**

1. Create `lib/screens/campaign_map_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../models/dungeon_config.dart';
import '../theme/dungeon_theme.dart';

class CampaignMapScreen extends StatelessWidget {
  const CampaignMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = Provider.of<GameState>(context);
    
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(decoration: BoxDecoration(gradient: DungeonTheme.getTheme(DungeonThemeType.stone).bgGradient)),
          const AmbientParticles(),
          const TorchOverlay(child: SizedBox.expand()),

          // Map Content
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _backButton(context),
                      Text(
                        'CAMPAIGN MAP',
                        style: DungeonTheme.getTitleStyle(context, const Color(0xFFF1C40F)),
                      ),
                      SizedBox(width: 60), // Spacer for alignment
                    ],
                  ),
                ),

                // Scrollable Vertical Map
                Expanded(
                  child: _CampaignMapContent(gameState: gameState),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _backButton(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pop(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF5A6B7C).withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.arrow_back, size: 14, color: Colors.white70),
            const SizedBox(width: 6),
            Text('RETURN', style: DungeonTheme.getBodyStyle(11, Colors.white70, weight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _CampaignMapContent extends StatelessWidget {
  final GameState gameState;

  const _CampaignMapContent({required this.gameState});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final roomWidth = min(constraints.maxWidth - 64, 280.0);
        final roomHeight = 170.0; // Fixed height for each room card
        
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          itemCount: DungeonConfig.dungeons.length,
          itemBuilder: (context, index) {
            final config = DungeonConfig.dungeons[index];
            final isUnlocked = index <= gameState.unlockedDungeonIndex;
            
            return Column(
              children: [
                // Room Card (chamber)
                _CampaignRoomCard(
                  config: config,
                  isUnlocked: isUnlocked,
                  gameState: gameState,
                  roomWidth: roomWidth,
                ),
                
                // Connector to next room (if not last)
                if (index < DungeonConfig.dungeons.length - 1)
                  _RoomConnector(
                    isUnlocked: isUnlocked, // Next room's connector lit if current unlocked
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CampaignRoomCard extends StatelessWidget {
  final DungeonConfig config;
  final bool isUnlocked;
  final GameState gameState;
  final double roomWidth;

  const _CampaignRoomCard({
    required this.config,
    required this.isUnlocked,
    required this.gameState,
    required this.roomWidth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DungeonTheme.getTheme(config.themeType);
    final dungeonIndex = DungeonConfig.dungeons.indexWhere((d) => d.id == config.id);
    final highestCleared = gameState.getHighestClearedLevel(dungeonIndex);

    return Container(
      width: roomWidth,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isUnlocked
              ? () {
                  gameState.initDungeonAtNextUnfinishedLevel(config);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const GameScreen()),
                  );
                }
              : null,
          borderRadius: BorderRadius.circular(12),
          splashColor: theme.accentColor.withValues(alpha: 0.1),
          child: CustomPaint(
            painter: StonePainter(
              bgColor: isUnlocked ? theme.hudBgColor : const Color(0xFF1E1E22),
              borderColor: isUnlocked ? theme.hudBorderColor : const Color(0xFF424242),
              crackColor: isUnlocked ? theme.primaryColor.withValues(alpha: 0.3) : const Color(0xFF424242).withValues(alpha: 0.1),
              borderRadius: 12,
              borderWidth: isUnlocked ? 2.0 : 1.0,
              drawCracks: true,
              seed: config.name.hashCode + 42, // Same cracks for same room every time
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Room header with icon and name
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isUnlocked ? theme.cardBackBgColor.withValues(alpha: 0.3) : const Color(0xFF151515),
                          border: Border.all(color: isUnlocked ? theme.hudBorderColor : const Color(0xFF424242), width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: Text(isUnlocked ? _getRoomEmoji(config) : '?', style: const TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(config.name.toUpperCase(), style: DungeonTheme.getBodyStyle(14, isUnlocked ? theme.accentColor : Colors.white24, weight: FontWeight.bold)),
                            Text('${config.cols}×${config.rows} • ${config.totalPairs} pairs', style: GoogleFonts.cinzel(fontSize: 9, color: isUnlocked ? Colors.white54 : Colors.white24)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Progress dots (level indicators)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(DungeonConfig.levelsPerDungeon, (levelIndex) {
                      final isCleared = levelIndex < highestCleared;
                      final isCurrent = levelIndex == gameState.getHighestClearedLevel(dungeonIndex);

                      return Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCleared 
                              ? theme.accentColor.withValues(alpha: 0.6)
                              : isCurrent && isUnlocked
                                  ? theme.primaryColor.withValues(alpha: 0.4) // Current level — pulsing
                                  : const Color(0xFF2C3E50), // Not yet reached
                          border: Border.all(
                            color: isCleared 
                                ? theme.accentColor 
                                : const Color(0xFF424242),
                            width: isCurrent && isUnlocked ? 2.0 : 1.0,
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 8),

                  // Status text
                  Text(
                    isUnlocked 
                        ? (highestCleared >= DungeonConfig.levelsPerDungeon ? 'CHAMBER CLEARED ✓' : 'Next: Level ${highestCleared + 1}')
                        : isLockedByPreviousDungeonText(gameState, dungeonIndex),
                    style: GoogleFonts.cinzel(
                      fontSize: 9, 
                      color: isUnlocked ? (highestCleared >= DungeonConfig.levelsPerDungeon ? Colors.greenAccent : theme.accentColor) : const Color(0xFFE74C3C),
                      weight: FontWeight.w600,
                    ),
                  ),

                  // Mismatch penalty indicator (if active)
                  if (isUnlocked && config.mismatchPenalty)
                    const SizedBox(height: 4),
                  if (isUnlocked && config.mismatchPenalty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('⚠️ MISMATCH PENALTY', style: TextStyle(fontSize: 8, color: const Color(0xFFE74C3C))),
                    ),

                  // Locked overlay
                  if (!isUnlocked)
                    Positioned(
                      right: 8, top: 8,
                      child: Icon(Icons.lock_open, size: 14, color: const Color(0xFFE74C3C)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  String _getRoomEmoji(DungeonConfig c) {
    switch (c.themeType) {
      case DungeonThemeType.stone: return '🔑';
      case DungeonThemeType.lava: return '🌋';
      case DungeonThemeType.ice: return '❄️';
      case DungeonThemeType.crypt: return '⚰️';
      case DungeonThemeType.voidChamber: return '🪐';
      case DungeonThemeType.forest: return '🌲';
    }
  }

  String isLockedByPreviousDungeonText(GameState gs, int dungeonIndex) {
    if (dungeonIndex == 0) return 'Entrance'; // Stone is always first
    final prevCleared = gs.getHighestClearedLevel(dungeonIndex - 1) >= DungeonConfig.levelsPerDungeon;
    return prevCleared ? 'Unsealing...' : 'Sealed by Rune Magic';
  }
}

class _RoomConnector extends StatelessWidget {
  final bool isUnlocked;

  const _RoomConnector({required this.isUnlocked});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3, // Corridor width
      height: 24,
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isUnlocked 
            ? const Color(0xF1C40F).withValues(alpha: 0.2) 
            : const Color(0xFF424242).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
```

### Task 5.2: Wire Campaign Map into Menu

**Objective:** Replace the "Chamber Map" button in menu with a link to the new campaign map screen.

**Steps:**
1. In `lib/screens/menu_screen.dart`, change the "CHAMBER MAP" button to use the new screen:
```dart
MenuButton(
  text: 'CAMPAIGN MAP', // Updated from "CHAMBER MAP"
  icon: Icons.map,
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CampaignMapScreen()),
    );
  },
),
```

2. Keep the old `dungeon_selector_screen.dart` in place — it can be accessed via a small "LIST" button on the campaign map screen, or just leave it and remove it from the menu.

---

## Phase 6: Card Visual Polish ✨ (High Attractiveness, Low Effort)

### Task 6.1: Dungeon-Themed Card Backs

**Objective:** Each dungeon has its own card back design — stone runes for Stone, flames for Lava, frost patterns for Ice.

**Files:**
- Modify: `lib/widgets/dungeon_card_widget.dart` — Card back rendering

**Steps:**
1. Add card back painting to `StonePainter`:
```dart
class StonePainter extends CustomPainter {
  // ... existing fields...
  final String? cardBackStyle; // 'stone', 'lava', 'ice', etc.

  @override
  void paint(Canvas canvas, Size size) {
    // ... existing border/grain/crack painting...

    // Draw card back pattern if specified
    if (cardBackStyle != null) {
      _drawCardBack(canvas, size, cardBackStyle!);
    }
  }

  void _drawCardBack(Canvas canvas, Size size, String style) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Draw subtle rune pattern in center of card back
    final paint = Paint()
      ..color = const Color(0xFF1A272F).withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    // Circle behind rune
    canvas.drawCircle(center, size.width * 0.2, paint);

    // Rune text
    final runeStyle = TextStyle(
      fontSize: size.width * 0.12,
      color: const Color(0xF1C40F).withValues(alpha: 0.3),
      fontFamily: 'Cinzel', // Use the same rune font
    );

    String rune;
    switch (style) {
      case 'lava': rune = 'ᛏ'; break; // Teiwaz (Tyr's sword)
      case 'ice': rune = 'ᚠ'; break; // Fehu (frost/wealth)
      case 'crypt': rune = 'ᚦ'; break; // Thurisaz (giant/door)
      case 'voidChamber': rune = 'ᛗ'; break; // Mannaz (humanity void)
      case 'forest': rune = 'ᛚ'; break; // Laguz (flow/nature)
      default: rune = 'ᛊ'; break; // Sowilo (sun/victory)
    }

    final textSpan = TextSpan(text: rune, style: runeStyle);
    final tp = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }
}
```

2. Pass dungeon theme to card widget in `GameScreen._buildCardGrid()`:
```dart
child: DungeonCardWidget(
  card: _cards[index],
  onTap: () => gameState.flipCard(index),
  isLocked: _isLocked,
  themeAccent: currentDungeon.themeType.name, // Pass dungeon style name
),
```

3. In `dungeon_card_widget.dart`, use the themeAccent to determine card back style:
```dart
// In build method, when rendering card back:
CustomPaint(
  painter: StonePainter(
    // ... existing args...
    cardBackStyle: themeAccent, // NEW
  ),
)
```

### Task 6.2: Match/Mismatch Visual Feedback Enhancement

**Objective:** Make matched cards shatter with a brief particle burst instead of just fading. Mismatched cards shake and flash red briefly.

**Files:**
- Modify: `lib/widgets/dungeon_card_widget.dart` — Add shatter/shake animations

**Steps:**
1. For matched cards: add a brief scale-up + fade-out animation (200ms):
```dart
// In DungeonCardWidget, when isMatched transitions to true:
AnimatedContainer(
  duration: const Duration(milliseconds: 200),
  curve: Curves.easeOut,
  child: AnimatedOpacity(
    opacity: isMatched ? 0.3 : 1.0,
    duration: const Duration(milliseconds: 200),
    child: Transform.scale(
      scale: isMatched ? 1.1 : 1.0, // Slight pop before dissolving
      child: CardContent(card: card),
    ),
  ),
)
```

2. For mismatched cards: trigger a brief shake (reuse existing `_shakeController` from GameScreen):
```dart
// The game screen already has shake/flash. We need to pass effect info down:
// In flipCard(), if mismatch, the game screen's _handleStateEffects already triggers shake+flash
// For match: trigger a green flash
```

3. The existing `_handleStateEffects()` already routes to shake on mismatch and color flash on matches — this is mostly wired up. Just ensure the animations look good (adjust durations if needed).

### Task 6.3: Upgrade to 3D Card Flip Animation

**Objective:** Replace the basic flip with a proper 3D card flip using the `flip_card` package (or custom `Transform3D`).

**Files:**
- Modify: `lib/widgets/dungeon_card_widget.dart` — Swap to 3D flip

**Steps:**
1. Use `flip_card` package:
```dart
import 'package:flip_card/flip_card.dart';

class DungeonCardWidget extends StatefulWidget {
  // ... existing fields...
  
  @override
  State<DungeonCardWidget> createState() => _DungeonCardWidgetState();
}

class _DungeonCardWidgetState extends State<DungeonCardWidget> with SingleTickerProviderStateMixin {
  late AnimationController _flipController;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    // Watch for flip state changes
    if (widget.card.isFlipped) {
      _flipController.forward();
    }
  }

  @override
  void didUpdateWidget(DungeonCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.card.isFlipped != oldWidget.card.isFlipped) {
      if (widget.card.isFlipped) {
        _flipController.forward(); // Flip to front
      } else {
        _flipController.reverse(); // Flip back
      }
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!widget.card.isFlipped) {
          widget.onTap();
        }
      },
      child: FlipCard(
        controller: _flipController,
        front: CardFace(card: widget.card, isFront: true),
        back: const CardBack(themeAccent: 'stone'), // or pass from parent
      ),
    );
  }
}
```

2. If `flip_card` package introduces issues (some versions have bugs with state sync), fall back to a custom `Transform3D`:
```dart
AnimatedBuilder(
  animation: _flipAnimation, // Tween from 0 to pi/2 or pi
  builder: (context, child) {
    return Transform(
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001) // Perspective
        ..rotateY(_flipAnimation.value),
      alignment: Alignment.center,
      child: _frontOrBackChild, // Switch based on animation progress
    );
  },
)
```

---

## Phase 7: New Game+ (Deeper Descent) 🕳️ (Endgame Content, Medium-Heavy Effort)

After clearing all 6 dungeons, enable a harder remixed mode with expanded grids and more poison tiles.

### Task 7.1: Add New Game+ State to GameState

**Objective:** Track whether the player has unlocked "Deeper Descent" mode, track their NG+ level.

**Files:**
- Modify: `lib/models/game_state.dart` — Add NG+ tracking fields
- Modify: `lib/models/campaign_progress.dart` — Persist NG+ state

**Steps:**
1. Add fields to `GameState`:
```dart
// New Game+ state (Deeper Descent)
bool _deeperDescentUnlocked = false; // Cleared all 6 dungeons
int _deeperDescentLevel = 0;         // How far into NG+ they are
static const int deeperDescentModifierCount = 3; // Min 3 modifiers stack on NG+ levels
```

2. Detect completion of all dungeons and unlock deeper descent:
```dart
bool _completeLevelIfSolved() {
  // ... existing logic...

  if (_currentLevel >= DungeonConfig.levelsPerDungeon) {
    // Check if ALL dungeons are completed
    bool allDungeonsCompleted = true;
    for (var i = 0; i < DungeonConfig.dungeons.length - 1; i++) {
      if ((_dungeonLevelProgress[i] ?? 0) < DungeonConfig.levelsPerDungeon) {
        allDungeonsCompleted = false;
        break;
      }
    }

    if (allDungeonsCompleted && !_deeperDescentUnlocked) {
      _deeperDescentUnlocked = true;
      _lastTriggeredEffect = 'deeper_descent_unlocked';
    }

    // If already unlocked, track NG+ level (highest across all dungeons)
    if (_deeperDescentUnlocked) {
      final maxLevel = _dungeonLevelProgress.values.reduce(max);
      if (maxLevel > _deeperDescentLevel) {
        _deeperDescentLevel = maxLevel;
      }
    }
  }

  return true;
}
```

3. In `DungeonConfig`, add NG+ grid scaling:
```dart
class DungeonConfig {
  // ... existing fields...

  /// Returns the grid size for "Deeper Descent" NG+ mode
  int get deeperDescentRows => _rows + (_unlockedDungeonIndex * 2); // Each cleared dungeon adds height
  int get deeperDescentCols => _cols + (_unlockedDungeonIndex * 2);
  
  /// Returns the number of poison tiles for NG+ mode (30% more than base)
  int get deeperDescentPoisonCount => (basePoisonMultiplier * 1.3).round();
}
```

4. Add NG+ mode to `GameState`:
```dart
void enterDeeperDescent() {
  if (!_deeperDescentUnlocked) return;
  
  // Use the same dungeon init but override grid size + poison density
  _isDeeperDescent = true;
  
  // Override modifier count for earlier, harder levels
  _activeModifier = LevelModifier.shadow; // Always start with shadow in NG+
  
  initDungeonByIndex(_unlockedDungeonIndex);
}

bool get isDeeperDescent => _isDeeperDescent;

// Override grid size calculation when in deeper descent
int get activeCols => _isDeeperDescent ? DungeonConfig.dungeons[_unlockedDungeonIndex].deeperDescentCols : _activeCols;
int get activeRows => _isDeeperDescent ? DungeonConfig.dungeons[_unlockedDungeonIndex].deeperDescentRows : _activeRows;
```

5. Wire into CampaignMapScreen: After the last dungeon room, add a "DEEPER DESCENT" room if unlocked.

### Task 7.2: Deeper Descent Visual Distinction

**Objective:** Make NG+ mode feel different — add a dark vignette, pulsing aura on cards, and red rune accents.

**Files:**
- Modify: `lib/theme/dungeon_theme.dart` — Add NG+ theme overlay data

**Steps:**
1. Add `deeperDescentOverlay` field to DungeonThemeData:
```dart
class DungeonThemeData {
  // ... existing fields...
  final Color? deeperDescentOverlay; // Dark red overlay color for NG+

  factory DungeonThemeData({
    required this.name,
    required this.primaryColor,
    required this.accentColor,
    required this.bgGradient,
    required this.hudBgColor,
    required this.hudBorderColor,
    required this.cardBackBgColor,
    required this.deeperDescentOverlay, // NEW
  }) { ... }
}
```

2. In each dungeon theme's factory, add a deeper descent overlay:
```dart
DungeonThemeData(
  // ... existing...
  deeperDescentOverlay: primaryColor.withValues(alpha: 0.15), // Subtle tint of the dungeon color
);

// Special: voidChamber gets a distinct dark overlay since it's already dark
```

3. In `GameScreen.build()`, apply the deeper descent overlay:
```dart
if (gameState.isDeeperDescent) {
  // Wrap the main content with a subtle dark overlay + pulsing aura
  Container(
    color: theme.deeperDescentOverlay,
    child: AnimatedBuilder(
      animation: _pulseController, // New controller for pulse effect
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: theme.accentColor.withValues(alpha: _pulseController.value * 0.3),
                blurRadius: 20,
                spreadRadius: _pulseController.value * 5,
              ),
            ],
          ),
          child: child,
        );
      },
    ),
  )
}
```

---

## Phase 8: Quality-of-Life & Polish 🛠️ (Player Comfort)

### Task 8.1: Pause / Resume Screen

**Objective:** Allow players to pause mid-level, especially important on timer/difficult levels.

**Files:**
- Modify: `lib/screens/game_screen.dart` — Add pause functionality and screen

**Steps:**
1. Add `_isPaused` state to `GameState`:
```dart
bool _isPaused = false;

void togglePause() {
  if (_isGameOver || _isLevelCleared) return;
  _isPaused = !_isPaused;
  if (_isPaused) {
    // Cancel all active timers (timer modifier, scroll auto-match, hint reveal)
    _timerFlipBack?.cancel();
    _previewHoldTimer?.cancel();
    _previewUnlockTimer?.cancel();
  } else {
    // Restore timer modifier if it was active
    // (This is tricky — we'd need to track remaining time on each level)
  }
}

bool get isPaused => _isPaused; // Expose to UI
```

2. Add pause button to GameScreen HUD:
```dart
InkWell(
  onTap: () {
    // Show pause overlay dialog
    showDialog(context: context, barrierDismissible: false, builder: ...);
  },
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(children: [Icon(Icons.pause, size: 12), Text('PAUSE', style: ...)]),
  ),
)
```

3. Build pause overlay with Resume and Flee buttons, similar to the existing game over dialog style.

### Task 8.2: Victory Stats Breakdown Screen

**Objective:** After every level clear, show a detailed stats breakdown screen.

**Files:**
- Modify: `lib/screens/game_screen.dart` — Replace current victory overlay with stats screen

**Steps:**
1. Add `_victoryStats` to GameState:
```dart
// Track for stats screen
int _mismatchesThisLevel = 0;
int _poisonsMatchedThisLevel = 0;
int _healsReceivedThisLevel = 0;
int _gemsMatchedThisLevel = 0;
int _scrollsMatchedThisLevel = 0;
int _treasuresMatchedThisLevel = 0;

// Increment in _applyMatchEffects():
void _applyMatchEffects(CardType type) {
  switch (type) {
    case CardType.poison: _poisonsMatchedThisLevel++; break;
    case CardType.healing: _healsReceivedThisLevel++; break;
    case CardType.gem: _gemsMatchedThisLevel++; break;
    case CardType.scroll: _scrollsMatchedThisLevel++; break;
    case CardType.treasure: _treasuresMatchedThisLevel++; break;
  }
}

// Reset at level start:
void initDungeonAtNextUnfinishedLevel(DungeonConfig config) {
  // Reset counters...
  _mismatchesThisLevel = 0;
  _poisonsMatchedThisLevel = 0;
  // ... etc
}

// Expose stats as a map for the UI:
Map<String, dynamic> get victoryStats => {
  'score': _score,
  'coinsEarned': _activeDungeon.getRewardCoinsForLevel(_currentLevel),
  'streakPeak': _streakCount, // Or track peak during level separately
  'mismatches': _mismatchesThisLevel,
  'poisonsMatched': _poisonsMatchedThisLevel,
  'healsReceived': _healsReceivedThisLevel,
  'gemsMatched': _gemsMatchedThisLevel,
  'scrollsMatched': _scrollsMatchedThisLevel,
  'treasuresMatched': _treasuresMatchedThisLevel,
};
```

2. Replace `_buildVictoryOverlay()` with a richer stats panel:
```dart
Widget _buildVictoryOverlay(BuildContext context, GameState gs, DungeonThemeData theme) {
  final stats = gs.victoryStats;

  return Dialog(
    backgroundColor: Colors.transparent,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: HudElement(
        padding: const EdgeInsets.all(24),
        borderRadius: 16,
        seed: 99,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('CHAMBER CLEARED', style: DungeonTheme.getTitleStyle(context, Colors.amber)),
            const Divider(color: Colors.white24),

            // Big stats section
            Text(stats['score'].toString(), style: DungeonTheme.getRuneStyle(28, Colors.white)),
            Text('SCORE', style: DungeonTheme.getBodyStyle(10, theme.primaryColor)),

            const SizedBox(height: 16),

            // Mini stat cards
            _buildStatCard('Coins', '+${stats['coinsEarned']}', Colors.yellow),
            _buildStatCard('Mismatches', stats['mismatches'].toString(), const Color(0xFFE74C3C)),
            _buildStatCard('Poisons', stats['poisonsMatched'].toString(), const Color(0xFF2ECC71)),
            _buildStatCard('Gems', stats['gemsMatched'].toString(), const Color(0xFF3498DB)),

            const SizedBox(height: 16),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text('CONTINUE')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF1C40F), foregroundColor: Colors.black),
                  onPressed: () { /* Go to dungeon selector */ },
                  child: Text('NEXT LEVEL'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildStatCard(String label, String value, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
    child: Text('$value $label', style: DungeonTheme.getBodyStyle(10, color)),
  );
}
```

### Task 8.3: Local High Scores (Per Dungeon-Level)

**Objective:** Track best scores per dungeon-level combination, stored locally.

**Files:**
- **NEW:** `lib/services/high_score_service.dart` — Local high score tracking

**Steps:**
1. Create `lib/services/high_score_service.dart`:
```dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class HighScoreService {
  static final HighScoreService _instance = HighScoreService._internal();
  factory HighScoreService() => _instance;
  HighScoreService._internal();

  Map<String, int> _scores = {}; // key: "dungeonId_levelIndex" -> best score

  void init() => _loadScores();

  Future<void> _loadScores() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/high_scores.json');
    if (!file.existsSync()) return;

    try {
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      _scores = {for (final entry in data.entries) 
        entry.key: int.tryParse(entry.value.toString()) ?? 0
      };
    } catch (e) {
      _scores = {};
    }
  }

  Future<void> _saveScores() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/high_scores.json');

    // Clean up: only keep scores for completed levels
    final cleanScores = <String, int>{};
    for (final entry in _scores.entries) {
      if (entry.value > 0) cleanScores[entry.key] = entry.value;
    }

    await file.writeAsString(jsonEncode(cleanScores));
  }

  String _keyFor(String dungeonId, int levelIndex) => '$dungeonId_$levelIndex';

  void recordScore(String dungeonId, int levelIndex, int score) {
    final key = _keyFor(dungeonId, levelIndex);
    
    // Only record if it's better than previous or first time
    final currentBest = _scores[key] ?? 0;
    if (score > currentBest) {
      _scores[key] = score;
      _saveScores();
    }
  }

  int? getBestScore(String dungeonId, int levelIndex) => _scores[_keyFor(dungeonId, levelIndex)];

  // Get top scores across all dungeons (for leaderboard screen)
  List<MapEntry<String, int>> getTopScores([int limit = 10]) {
    final sorted = _scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).toList();
  }

  void resetAll() {
    _scores.clear();
  }
}
```

2. Integrate into `_completeLevelIfSolved()`:
```dart
bool _completeLevelIfSolved() {
  // ... existing logic...

  HighScoreService().recordScore(_activeDungeon.id, _currentLevel - 1, _score);
  
  return true;
}
```

3. Display best score in Campaign Map cards and Dungeon Selector:
```dart
// In _CampaignRoomCard (Phase 5):
final bestScore = HighScoreService().getBestScore(config.id, highestCleared);
if (bestScore != null) {
  Text('Best: $bestScore', style: GoogleFonts.cinzel(fontSize: 8, color: Colors.white30)),
}
```

### Task 8.4: Accessibility Improvements (Color-Blind Mode, Haptics)

**Objective:** Make the game playable for color-blind users and provide tactile feedback on mismatch.

**Files:**
- Modify: `lib/models/game_state.dart` — Add color-blind mode state
- Modify: `pubspec.yaml` — Add vibration package (optional, only for mobile)

**Steps:**
1. Add color-blind mode toggle to GameState:
```dart
bool _colorBlindMode = false;

void setColorBlind(bool enabled) {
  _colorBlindMode = enabled;
  // Save preference to shared prefs or campaign progress
}

bool get isColorBlindMode => _colorBlindMode;
```

2. In card rendering (`dungeon_card_widget.dart`), when color-blind mode is on:
   - Poison tiles get a distinct "✕" overlay (not just red tint)
   - Healing tiles get a "+" overlay
   - Treasure tiles get a "$" overlay
   - Gem tiles get a "★" overlay

3. Add haptic feedback on mismatch in `GameScreen._checkMatch()`:
```dart
// In flipCard or _handleStateEffects:
if (effect == 'mismatch_penalty') {
  await HapticFeedback.mediumImpact(); // Requires: import 'package:flutter/services.dart';
}
```

---

## Phase 9: Additional Polish & Refinement 🧹 (Optional, Low Priority)

### Task 9.1: Forest Chamber Theme Refinement

**Objective:** The Forest Chamber currently feels like a re-skin of Stone Chamber. Give it unique personality — different grid rules, new modifier flavors, unique emoji pool with more forest-appropriate items.

**Files:**
- Modify: `lib/models/dungeon_config.dart` — Give Forest Chamber unique identity

**Steps:**
1. Change Forest's description to be more dungeon-appropriate (e.g., "The Verdant Crypt — an ancient buried grove, where roots twist through forgotten chambers")
2. Give Forest a unique grid rule: larger grids but fewer modifiers (a welcoming "oasis" between Crypt and Void)
3. Consider replacing Forest with a more fitting name like "Sunken Library" or "Whispering Hollow" if the forest theme doesn't fit the dungeon aesthetic

### Task 9.2: Game Over Screen Enhancement

**Objective:** Make game-over more dramatic — show the reason you fell (lives drained, last mismatch was a poison, etc.)

**Files:**
- Modify: `lib/screens/game_screen.dart` — Enhance `_buildGameOverOverlay()`

**Steps:**
1. Add "reason" display:
```dart
Text(
  'The dungeon claimed you.',
  style: DungeonTheme.getTitleStyle(context, const Color(0xFFE74C3C)),
),
Text(
  switch (_lastTriggeredEffect) {
    'poison' => 'Poison seeped into your veins... The chamber consumes another soul.',
    'mismatch_penalty' => 'A wrong turn in the dark. The walls close in.',
    _ => 'The ancient traps proved too much. Rest now, adventurer.',
  },
  style: DungeonTheme.getBodyStyle(12, Colors.white70),
)
```

### Task 9.3: Tutorial / Hint System for First-Time Players

**Objective:** New players should understand the game within 30 seconds, not by reading a wall of text.

**Files:**
- **NEW:** `lib/screens/tutorial_hint.dart` — Lightweight tutorial overlay system

**Steps:**
1. On first-ever launch (track via a `hasPlayedBefore` boolean in shared prefs), show a brief 3-step interactive tutorial:
   - Step 1: "Tap a card to flip it" (highlight first card with pulsing outline)
   - Step 2: "Find matching pairs! Match the same symbols" (show a demo pair)
   - Step 3: "Match all pairs to clear the chamber" (show completed board)

2. Each step auto-advances after 3 seconds if player doesn't interact, or advances early on first match

3. After tutorial completes, store `hasPlayedBefore = true` and never show again (unless "How to Play" dialog is opened)

---

## Files Summary

| File | Changes |
|------|---------|
| `pubspec.yaml` | Add `audioplayers: ^6.0.0`, `flip_card: ^0.7.0` |
| **NEW** `lib/services/audio_service.dart` | Audio SFX + ambient management |
| **NEW** `lib/models/achievement.dart` | Achievement definition model |
| **NEW** `lib/services/achievement_manager.dart` | Track & persist achievement progress |
| **NEW** `lib/models/daily_challenge.dart` | Daily challenge generation, seed logic, progress tracking |
| **NEW** `lib/screens/achievements_screen.dart` | Achievement grid UI |
| **NEW** `lib/screens/campaign_map_screen.dart` | Vertical dungeon map view (rooms + connectors) |
| **NEW** `lib/screens/daily_challenge_screen.dart` | Daily challenge preview/entry screen |
| **NEW** `lib/services/high_score_service.dart` | Local high score tracking per dungeon-level |
| **NEW** `lib/screens/tutorial_hint.dart` | First-time interactive tutorial |
| Modify: `lib/main.dart` | Initialize AudioService, AchievementManager, HighScoreService |
| Modify: `lib/models/game_state.dart` | Add streak fields, daily mode override, NG+ state, pause, color-blind toggle, victory stats tracking |
| Modify: `lib/models/dungeon_config.dart` | Add deeper descent grid scaling, Forest Chamber refinement |
| Modify: `lib/models/campaign_progress.dart` | Add dailyChallengeHistory, deeperDescent fields, version bump to 3 |
| Modify: `lib/screens/game_screen.dart` | Add streak HUD, pause button, enhanced victory overlay, game-over enhancement, daily mode init |
| Modify: `lib/screens/menu_screen.dart` | Add Daily Challenge button, replace "Chamber Map" with Campaign Map, add Achievements button |
| Modify: `lib/widgets/dungeon_card_widget.dart` | Add dungeon-themed card backs, 3D flip animation, color-blind overlays, shatter/mismatch FX |
| Modify: `lib/theme/dungeon_theme.dart` | Add deeperDescentOverlay field to DungeonThemeData |
| `assets/audio/sfx/` | Add 12 SFX WAV files (flip, match, mismatch, poison, heal, gem, scroll, treasure, shuffle, victory, gameover, whoosh) |
| `assets/audio/ambience/` | Add 6 ambient MP3 files (stone_drip, lava_rumble, ice_crack, crypt_wind, void_hum, forest_whisper) |

---

## Verification Steps

After implementing all phases:

1. **Sound:** Play a level — should hear flip SFX, match chime, ambient dungeon audio. Mute toggle in HUD should silence everything.

2. **Streak:** Match 3+ cards consecutively — HUD should show streak fire icon with growing multiplier. Mismatch should reset streak with brief "Broken!" text.

3. **Achievements:** Clear a level — check notification toast for "First Blood". Check Achievements screen to see it unlocked.

4. **Daily Challenge:** Enter daily challenge — should show today's dungeon/modifier preview, generate reproducible board. After playing, save result to history.

5. **Campaign Map:** Open map — should see 6 rooms connected by corridors, progress dots per room. Clicking unlocked room enters that dungeon.

6. **Card Polish:** Cards should flip in 3D, have dungeon-themed card backs with rune symbols. Matched cards shatter briefly before fading.

7. **NG+**: After clearing all 6 dungeons, campaign map should show a "Deeper Descent" option with expanded grids and dark overlay.

8. **Stats Screen:** After clearing a level, should see detailed breakdown (score, coins, mismatches, item counts).

9. **High Scores:** Clear a level twice — second better score should persist and show on campaign map card.

10. **Color-Blind Mode:** Toggle from settings — poison tiles should show "✕" overlay, healing "+", etc.

---

## Risks and Tradeoffs

1. **Asset management** — Sound files add to app size. Keep SFX under 500KB each, ambience under 2MB each. Compress MP3s to ~128kbps.

2. **Daily challenge determinism** — The seed-based generation must produce exactly the same board for players on the same day. Any randomness outside the seeded Random will break reproducibility.

3. **Streak complexity** — Adding streaks changes score calculation entirely. If a previous plan had score formulas, ensure this is factored in (not stacked on top of existing modifiers).

4. **Achievement spam** — Too many achievement notifications will annoy players. Show only on significant milestones (first-time unlocks), not every increment. Consider a "Achievement Unlocked!" toast that auto-dismisses after 2 seconds.

5. **Campaign map vs list** — Some players may prefer the old scrollable list format (faster navigation). Consider keeping both accessible via a toggle on the map screen.

6. **NG+ grid sizes** — Adding rows/columns per cleared dungeon can make late-game boards very large (8x10+). Ensure the card grid scales properly and doesn't become unusable on smaller screens.

7. **3D flip performance** — FlipCard package can cause jank on lower-end devices. Test on an actual device (not just simulator). If performance is poor, fall back to 2D flip.

---

## Open Questions

1. **Daily challenge rewards** — Should completing daily challenges award special cosmetics or shop discounts, or just a score bonus?

2. **Achievement notifications** — Should they be toast popups (quick) or a dedicated notification center in the menu?

3. **Color-blind mode persistence** — Should it be a separate setting (in shared prefs) or bundled with campaign progress?

4. **Tutorial skip option** — Should returning players see a "Skip Tutorial" button in "How to Play", or should it be auto-skipped via the `hasPlayedBefore` flag?

5. **Forest Chamber identity** — Does it need a complete re-theme, or is the emoji pool + grid difference enough for a unique feel?

6. **Should there be co-op/local two-player?** — Out of scope for this plan but would be a fun future addition (alternating turns on the same board).
