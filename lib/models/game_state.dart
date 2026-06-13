import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/campaign_progress_store.dart';
import 'campaign_progress.dart';
import 'dungeon_card.dart';
import 'dungeon_config.dart';

/// Artifact definition: a passive bonus unlocked by the player.
class ArtifactDef {
  final String name;
  final String description;
  const ArtifactDef(this.name, this.description);

  String get displayName => name;
  String get displayDescription => description;
}

class GameState extends ChangeNotifier {
  static const Duration _puzzlePreviewHoldDuration = Duration(
    milliseconds: 1200,
  );
  static const Duration _puzzlePreviewFlipDuration = Duration(
    milliseconds: 400,
  );

  final CampaignProgressStore _progressStore;

  // Game stats
  int _lives = 3;
  int _maxLives = 5;
  int _coins = 0;
  int _score = 0;
  double _scoreMultiplier = 1.0;
  int _hintCharges = 1; // Start with 1 free hint
  int _unlockedDungeonIndex = 0;

  // Level modifier state (Phase 2)
  LevelModifier _activeModifier = LevelModifier.none;
  int _flipCountSinceLastSwap = 0;
  
  // Timer modifier: auto-flips back card after N seconds
  Timer? _timerFlipBack;

  /// Maximum attempts to generate a valid deck before throwing
  static const int maxAttempts = 10;

  // Artifact definitions: artifact ID -> (name, description)
  
  /// Cost in coins to purchase each unlockable artifact.
  static const Map<String, int> artifactPrices = {
    'extra_hint': 50,
    'lives_boost': 150,
    'poison_sight': 75,
  };

  static const Map<String, String> artifactIcons = {
    'extra_hint': '📜',
    'lives_boost': '❤️‍🔥',  
    'poison_sight': '👁️',
  };

  static const Map<String, ArtifactDef> artifactsCatalogue = {
    'extra_hint': ArtifactDef(
      'Extra Hint Scroll',
      'Start every dungeon with +1 hint charge',
    ),
    'lives_boost': ArtifactDef(
      'Rune of Vitality',
      'Start with 4 lives instead of 3; increased max life pool (6)',
    ),
    'poison_sight': ArtifactDef(
      'Poison Sight Rune',
      'Poison cards glow red on the board UI',
    ),
  };

  // Lifetime / shop tracking (persisted across runs)
  int _totalCoins = 0; // Lifetime coins earned across all campaigns
  final Set<String> _artifactsUnlocked = {};

  /// Set of artifact IDs unlocked by the player.
  Set<String> get unlockedArtifacts => _artifactsUnlocked;

  /// Current active level modifier
  LevelModifier get activeModifier => _activeModifier;

  /// Total coins earned across current run
  int get totalCoins => _totalCoins + _coins;

  /// Purchases an artifact if the player has enough coins.
  /// Returns true if purchase was successful, false otherwise.
  bool tryPurchaseArtifact(String artifactId) {
    if (_artifactsUnlocked.contains(artifactId)) return false; // Already owned
    
    final cost = GameState.artifactPrices[artifactId] ?? 0;
    if (_totalCoins < cost) return false; // Not enough coins
    
    _artifactsUnlocked.add(artifactId);
    unawaited(_saveCampaignProgress()); // Persist new artifact
    
    return true;
  }

  /// Returns whether the player can afford a given artifact.
  bool canAffordArtifact(String artifactId) {
    if (_artifactsUnlocked.contains(artifactId)) return false; // Already owned
    final cost = GameState.artifactPrices[artifactId] ?? 0;
    return _totalCoins >= cost;
  }

  // Level tracking
  int _currentLevel = 1;

  // Per-dungeon level progress: maps dungeon index to highest cleared level
  final Map<int, int> _dungeonLevelProgress = {};

  // Active dungeon configurations
  DungeonConfig _activeDungeon = DungeonConfig.dungeons[0];
  List<DungeonCard> _cards = [];
  final List<int> _selectedIndices = [];

  // Control flags
  bool _isLocked = false;
  bool _isGameOver = false;
  bool _isLevelCleared = false;
  bool _isProgressLoaded = false;
  bool _isPreviewingPuzzle = false;
  int _previewSessionId = 0;
  Timer? _previewHoldTimer;
  Timer? _previewUnlockTimer;

  // Feedback strings for UI animations
  String? _lastTriggeredEffect;

  // Getters
  int get lives => _lives;
  int get maxLives => _maxLives;
  int get coins => _coins;
  int get score => _score;
  double get scoreMultiplier => _scoreMultiplier;
  int get hintCharges => _hintCharges;
  int get unlockedDungeonIndex => _unlockedDungeonIndex;
  DungeonConfig get activeDungeon => _activeDungeon;
  List<DungeonCard> get cards => _cards;
  List<int> get selectedIndices => _selectedIndices;
  bool get isLocked => _isLocked;
  // Clean up modifier timers when level ends or game over
  void _disposeModifierTimers() {
    _timerFlipBack?.cancel();
    _timerFlipBack = null;
  }

  /// Flushes all active game state (called on level clear or game over).
  void _flushGame() {
    _disposeModifierTimers();
    _selectedIndices.clear();
  }

  bool get isGameOver => _isGameOver;
  bool get isLevelCleared => _isLevelCleared;
  bool get isProgressLoaded => _isProgressLoaded;
  bool get isPreviewingPuzzle => _isPreviewingPuzzle;
  String? get lastTriggeredEffect => _lastTriggeredEffect;
  int get currentLevel => _currentLevel;
  Map<int, int> get dungeonLevelProgress => _dungeonLevelProgress;

  // Dynamic grid getters for active dungeon + level
  int get activeRows =>
      _activeDungeon.getGridSizeForLevel(_currentLevel)['rows']!;
  int get activeCols =>
      _activeDungeon.getGridSizeForLevel(_currentLevel)['cols']!;
  int get activeTotalPairs =>
      _activeDungeon.getTotalPairsForLevel(_currentLevel);
  bool get activeMismatchPenalty =>
      _activeDungeon.getMismatchPenaltyForLevel(_currentLevel);

  /// Whether current level is the last in this chamber
  bool get isLastLevelInChamber =>
      _currentLevel >= DungeonConfig.levelsPerDungeon;

  /// Progress string for HUD, e.g. "Level 5/20"
  String get levelProgressString =>
      'Level $_currentLevel/${DungeonConfig.levelsPerDungeon}';

  /// Get highest cleared level for a dungeon index (0 if none)
  int getHighestClearedLevel(int dungeonIndex) {
    return _dungeonLevelProgress[dungeonIndex] ?? 0;
  }

  // Constructor
  GameState({CampaignProgressStore? progressStore})
    : _progressStore = progressStore ?? MemoryCampaignProgressStore() {
    initDungeon(_activeDungeon);
  }

  Future<void> loadCampaignProgress() async {
    try {
      final progress = await _progressStore.load();
      if (progress != null) {
        _applyCampaignProgress(progress);
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

  // Initialize a dungeon, optionally at a specific level
  void initDungeon(
    DungeonConfig config, {
    bool resetStats = false,
    int startLevel = 1,
  }) {
    // Apply passive artifacts: max life pool
    if (_artifactsUnlocked.contains('lives_boost')) {
      _maxLives = 6;
    } else {
      _maxLives = 5;
    }

    // Apply passive artifacts: starting stats at run start
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
    
    // Set active modifier for this level
    _activeModifier = config.getModifierForLevel(_currentLevel);
    _flipCountSinceLastSwap = 0;
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

  void resumeCampaign() {
    final dungeonIndex = CampaignProgress.nextUnfinishedDungeonIndex(
      _dungeonLevelProgress,
    ).clamp(0, _unlockedDungeonIndex).toInt();
    final startLevel = CampaignProgress.nextUnfinishedLevelForDungeon(
      _dungeonLevelProgress,
      dungeonIndex,
    );

    initDungeon(DungeonConfig.dungeons[dungeonIndex], startLevel: startLevel);
  }

  void initDungeonAtNextUnfinishedLevel(DungeonConfig config) {
    final dungeonIndex = DungeonConfig.dungeons.indexWhere(
      (d) => d.id == config.id,
    );
    final startLevel = dungeonIndex == -1
        ? 1
        : CampaignProgress.nextUnfinishedLevelForDungeon(
            _dungeonLevelProgress,
            dungeonIndex,
          );

    initDungeon(config, startLevel: startLevel);
  }

  /// Advance to next level within the same dungeon
  void advanceToNextLevel() {
    _disposeModifierTimers();
    if (_currentLevel >= DungeonConfig.levelsPerDungeon) return;

    _currentLevel++;
    _selectedIndices.clear();
    _isLocked = false;
    _isGameOver = false;
    _isLevelCleared = false;
    _isPreviewingPuzzle = false;
    _lastTriggeredEffect = null;
    _scoreMultiplier = 1.0;

    _generateCards();
    _startPuzzlePreview();
  }

  // Restart the whole game from dungeon 1
  void resetGame() {
    _disposeModifierTimers();
    _unlockedDungeonIndex = 0;
    _dungeonLevelProgress.clear();
    initDungeon(DungeonConfig.dungeons[0], resetStats: true);
    unawaited(_clearCampaignProgress());
  }

  // Generate cards for the active dungeon grid at the current level
  void _generateCards() {
    final totalTiles = activeRows * activeCols;
    if (totalTiles.isOdd) {
      throw StateError(
        'Dungeon ${_activeDungeon.id} level $_currentLevel has an odd deck size: $totalTiles',
      );
    }

    final totalPairsRaw = totalTiles ~/ 2;
    
    // Shadow modifier: hide some pairs from the board (they never appear)
    int totalPairs = totalPairsRaw;
    if (_activeModifier == LevelModifier.shadow) {
      final hiddenPairs = (totalPairsRaw ~/ 4).clamp(1, 3);
      totalPairs -= hiddenPairs;
    }
    final random = Random();

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final deckAssets = <String>[];

      for (final asset in _selectPairAssets(totalPairs)) {
        deckAssets
          ..add(asset)
          ..add(asset);
      }

      deckAssets.shuffle(random);

      final cards = List.generate(deckAssets.length, (index) {
        final emoji = deckAssets[index];
        return DungeonCard(
          id: index,
          emoji: emoji,
          type: DungeonCard.getCardTypeFromEmoji(emoji),
        );
      });

      // Sabotage modifier: replace one normal pair with poison doubles (fake pair)
      if (_activeModifier == LevelModifier.sabotage) {
        final normalCards = cards.where((c) => c.type == CardType.normal).toList();
        if (normalCards.length >= 2) {
          // Find a matching pair and turn both into poison
          for (var i = 0; i < cards.length - 1; i++) {
            if (cards[i].emoji == cards[i + 1].emoji && 
                cards[i].type != CardType.poison) {
              // Found a normal pair - sabotage it!
              cards[i] = DungeonCard(
                id: cards[i].id,
                emoji: '🤢', // poison emoji
                type: CardType.poison,
              );
              cards[i + 1] = DungeonCard(
                id: cards[i + 1].id,
                emoji: '🤢', // poison emoji  
                type: CardType.poison,
              );
              break;
            }
          }
        }
      }

      if (_validateGeneratedLevel(cards, expectedTileCount: totalTiles)) {
        _cards = cards;
        return;
      }
    }

    throw StateError(
      'Failed to generate a valid ${_activeDungeon.id} level $_currentLevel deck after $maxAttempts attempts.',
    );
  }

  List<String> _selectPairAssets(int totalPairs) {
    final assets = <String>[];
    final seen = <String>{};

    for (final emoji in [..._activeDungeon.emojiSet, ..._fallbackPairAssets]) {
      if (seen.add(emoji)) {
        assets.add(emoji);
      }

      if (assets.length == totalPairs) {
        return assets;
      }
    }

    throw StateError(
      'Not enough unique assets to create $totalPairs exact pairs for ${_activeDungeon.id}.',
    );
  }

  static const List<String> _fallbackPairAssets = [
    '🗝️',
    '🛡️',
    '⚔️',
    '🏹',
    '🕯️',
    '🦴',
    '⚰️',
    '🕸️',
    '🕷️',
    '🦇',
    '👻',
    '🧊',
    '❄️',
    '🌨️',
    '🏔️',
    '🪞',
    '🌌',
    '🌀',
    '🪐',
    '🛸',
    '👾',
    '🚀',
    '🛰️',
    '🌑',
    '🔭',
    '⭐',
    '🌙',
    '🌠',
    '🧬',
    '🕳️',
    '🌲',
    '🍄',
    '🍃',
    '🌿',
    '🪵',
    '🌰',
  ];

  /// Validates that every generated tile has exactly one matching partner.
  bool _validateGeneratedLevel(
    List<DungeonCard> cards, {
    required int expectedTileCount,
  }) {
    if (expectedTileCount.isOdd || cards.length != expectedTileCount) {
      return false;
    }

    final counts = <String, int>{};
    for (final card in cards) {
      counts[card.emoji] = (counts[card.emoji] ?? 0) + 1;
    }

    return counts.length == expectedTileCount ~/ 2 &&
        counts.values.every((count) => count == 2);
  }

  @visibleForTesting
  bool hasValidGeneratedLevel() {
    return _validateGeneratedLevel(
      _cards,
      expectedTileCount: activeRows * activeCols,
    );
  }

  void _startPuzzlePreview() {
    _cancelPuzzlePreviewTimers();
    final sessionId = ++_previewSessionId;

    _isLocked = true;
    _isPreviewingPuzzle = true;
    for (final card in _cards) {
      card.isFlipped = true;
      card.isHinted = false;
    }
    notifyListeners();

    _previewHoldTimer = Timer(_puzzlePreviewHoldDuration, () {
      if (sessionId != _previewSessionId) return;

      for (final card in _cards) {
        if (!card.isMatched) {
          card.isFlipped = false;
        }
      }
      notifyListeners();

      _previewUnlockTimer = Timer(_puzzlePreviewFlipDuration, () {
        if (sessionId != _previewSessionId) return;

        _isPreviewingPuzzle = false;
        _isLocked = false;
        notifyListeners();
      });
    });
  }

  void _cancelPuzzlePreviewTimers() {
    _previewHoldTimer?.cancel();
    _previewUnlockTimer?.cancel();
    _previewHoldTimer = null;
    _previewUnlockTimer = null;
  }

  // Flip a card
  void flipCard(int index) {
    if (_isLocked || _isGameOver || _isLevelCleared) return;
    if (index < 0 || index >= _cards.length) return;

    final card = _cards[index];
    if (card.isFlipped || card.isMatched) return;

    // Flip the card
    card.isFlipped = true;
    
    // Timer modifier: schedule auto-flip back after 3 seconds (if card was newly flipped)
    if (_activeModifier == LevelModifier.timer && !card.isMatched) {
      _timerFlipBack?.cancel(); // Cancel any pending timer
      final scheduledIndex = index;
      
      _timerFlipBack = Timer(const Duration(seconds: 3), () {
        if (scheduledIndex >= _cards.length || scheduledIndex < 0) return;
        
        final targetCard = _cards[scheduledIndex];
        if (!targetCard.isFlipped) return; // Already processed
        
        targetCard.isFlipped = false;
        if (_selectedIndices.contains(scheduledIndex)) {
          _selectedIndices.remove(scheduledIndex);
        }
        notifyListeners();
      });
    }

    _selectedIndices.add(index);
    _lastTriggeredEffect = 'flip';
    
    // Swap modifier: track flip count for board shuffle
    if (_activeModifier == LevelModifier.swap && !_isGameOver && !_isLevelCleared) {
      _flipCountSinceLastSwap++;
    }

    // Swap modifier: reshuffle board every 5 flips
    if (_activeModifier == LevelModifier.swap && _flipCountSinceLastSwap >= 5) {
      _shuffledBoard();
      _flipCountSinceLastSwap = 0;
      _lastTriggeredEffect = 'board_swap';
    }

    if (_completeLevelIfSolved()) {
      _selectedIndices.clear();
      _isLocked = false;
      notifyListeners();
      return;
    }

    notifyListeners();

    // If 2 cards are flipped, check for match
    if (_selectedIndices.length == 2) {
      _isLocked = true;
      notifyListeners();

      Timer(const Duration(milliseconds: 800), () {
        _checkMatch();
      });
    }
  }

  // Swap modifier: reshuffle active (unmatched, unflipped) cards in place
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

    // Fisher-Yates shuffle
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
      _cards[activeIndices[i]] = DungeonCard(
        id: _cards[activeIndices[i]].id,
        emoji: emojis[i],
        type: types[i],
        isFlipped: false, // Reset flip state during shuffle
        isMatched: false,
        isHinted: _cards[activeIndices[i]].isHinted,
      );
    }

    notifyListeners();
  }

  // Match checking logic
  void _checkMatch() {
    if (_selectedIndices.length != 2) return;

    final firstIndex = _selectedIndices[0];
    final secondIndex = _selectedIndices[1];
    final card1 = _cards[firstIndex];
    final card2 = _cards[secondIndex];

    if (card1.emoji == card2.emoji) {
      // It's a MATCH!
      card1.isMatched = true;
      card2.isMatched = true;

      // Trigger effects based on item card type
      _applyMatchEffects(card1.type);

      // Calculate score: base score of 100 * dungeon multiplier * current multiplier
      final dungeonMult = _activeDungeon.getScoreMultiplierForLevel(
        _currentLevel,
      );
      final addedScore = (100 * dungeonMult * _scoreMultiplier).round();
      _score += addedScore;

      _completeLevelIfSolved();
    } else {
      // MISMATCH!
      card1.isFlipped = false;
      card2.isFlipped = false;

      // Optional mismatch penalty: lose a life if configured for the dungeon+level
      if (activeMismatchPenalty) {
        _lives--;
        _lastTriggeredEffect = 'mismatch_penalty';

        if (_lives <= 0) {
          _isGameOver = true;
          _flushGame();
          _lastTriggeredEffect = 'game_over';
        }
      } else {
        _lastTriggeredEffect = 'mismatch';
      }

      _completeLevelIfSolved();
    }

    _selectedIndices.clear();
    _isLocked = false;
    notifyListeners();
  }

  bool _completeLevelIfSolved() {
    if (_isLevelCleared || _isGameOver || !_isPuzzleSolved()) return false;

    _flushGame();
    _lastTriggeredEffect = 'victory';

    final currentDungeonIdx = DungeonConfig.dungeons.indexWhere(
      (d) => d.id == _activeDungeon.id,
    );
    if (currentDungeonIdx != -1) {
      final prev = _dungeonLevelProgress[currentDungeonIdx] ?? 0;
      if (_currentLevel > prev) {
        _dungeonLevelProgress[currentDungeonIdx] = _currentLevel;
      }

      if (_currentLevel >= DungeonConfig.levelsPerDungeon) {
        if (currentDungeonIdx == _unlockedDungeonIndex &&
            _unlockedDungeonIndex < DungeonConfig.dungeons.length - 1) {
          _unlockedDungeonIndex++;
        }
      }
    }

    _coins += _activeDungeon.getRewardCoinsForLevel(_currentLevel);
    unawaited(_saveCampaignProgress());
    return true;
  }

  @override
  void dispose() {
    _disposeModifierTimers();
    super.dispose();
  }

  bool _isPuzzleSolved() {
    final unmatchedCards = _cards.where((card) => !card.isMatched).toList();
    if (unmatchedCards.isEmpty) return true;

    return unmatchedCards.every((card) => card.type == CardType.poison);
  }

  // Applies side effects based on matched tile types
  void _applyMatchEffects(CardType type) {
    switch (type) {
      case CardType.poison:
        // Poison costs a life, but PURIFIES one adjacent poison card from the board.
        _lives--;
        _lastTriggeredEffect = 'poison';

        final unpurifiedPoisons =
            _cards.where((c) => c.type == CardType.poison && !c.isMatched).toList();

        if (unpurifiedPoisons.length >= 2) {
          // Dissolve one poison card from the board (it's been neutralized)
          final toDissolve = unpurifiedPoisons.first;
          toDissolve.isMatched = true;
          _lastTriggeredEffect = 'poison_purify';
        }

        if (_lives <= 0) {
          _isGameOver = true;
          _flushGame();
          _lastTriggeredEffect = 'game_over';
        }
        break;

      case CardType.healing:
        if (_lives < _maxLives) {
          _lives++;
          _lastTriggeredEffect = 'heal';
        } else {
          // Full health: convert to bonus score instead of healing
          _score += 50;
          _lastTriggeredEffect = 'heal_overflow';
        }
        break;

      case CardType.treasure:
        // Coins already awarded in _completeLevelIfSolved; reward a small scaling bonus here
        _coins += 1 + (_currentLevel ~/ 5); // Scaling micro-bonus per dungeon depth
        _lastTriggeredEffect = 'treasure';
        break;

      case CardType.scroll:
        _hintCharges++;

        // Reveal a known-but-unmatched pair and auto-match it after 1 second.
        final unmatched = _cards.where((c) => !c.isMatched && !c.isFlipped).toList();
        if (unmatched.length >= 2) {
          final emojiGroups = <String, List<DungeonCard>>{};
          for (final card in unmatched) {
            emojiGroups.putIfAbsent(card.emoji, () => []);
            emojiGroups[card.emoji]!.add(card);
          }

          for (final group in emojiGroups.values) {
            if (group.length >= 2) {
              // Flip the pair face-up so the player sees what it was.
              group[0].isFlipped = true;
              group[1].isFlipped = true;

              Timer(const Duration(seconds: 1), () {
                if (!group[0].isMatched) {
                  group[0].isMatched = true;
                  group[1].isMatched = true;

                  _completeLevelIfSolved();
                  notifyListeners();
                }
              });

              _lastTriggeredEffect = 'scroll_reveal';
              break; // Only auto-match one pair per scroll
            }
          }
        }
        break;

      case CardType.gem:
        _scoreMultiplier += 0.5;

        // Shatter one remaining poison from the board (it's permanently removed).
        final remainingPoisons =
            _cards.where((c) => c.type == CardType.poison && !c.isMatched).toList();

        if (remainingPoisons.isNotEmpty) {
          remainingPoisons.first.isMatched = true; // Shatter one poison permanently
          _lastTriggeredEffect = 'gem_shatter';
        } else {
          // No poisons to shatter: bonus score instead.
          _score += 75;
        }
        break;

      case CardType.normal:
        // Normal tiles just add a small score bonus for being matched.
        _score += 10;
        break;
    }
  }

  // Trigger hint: temporarily reveal 3 random face-down tiles for 2 seconds
  void triggerHint() {
    if (_hintCharges <= 0 || _isLocked || _isGameOver || _isLevelCleared) {
      return;
    }

    // Deduct charge
    _hintCharges--;
    _isLocked = true;
    _lastTriggeredEffect = 'hint_activate';
    notifyListeners();

    // Find unmatched, face-down cards
    final faceDownIndices = <int>[];
    for (int i = 0; i < _cards.length; i++) {
      if (!_cards[i].isMatched && !_cards[i].isFlipped) {
        faceDownIndices.add(i);
      }
    }

    if (faceDownIndices.isEmpty) {
      _isLocked = false;
      notifyListeners();
      return;
    }

    // Select up to 3 random cards to reveal
    final random = Random();
    final cardsToReveal = <int>[];
    final count = min(3, faceDownIndices.length);

    // Shuffle the available indices to grab random unique ones
    faceDownIndices.shuffle(random);
    for (int i = 0; i < count; i++) {
      cardsToReveal.add(faceDownIndices[i]);
    }

    // Flip and mark them as hinted
    for (final index in cardsToReveal) {
      _cards[index].isFlipped = true;
      _cards[index].isHinted = true;
    }
    notifyListeners();

    // After 2.0 seconds, flip them back
    Timer(const Duration(milliseconds: 2000), () {
      for (final index in cardsToReveal) {
        if (!_cards[index].isMatched) {
          _cards[index].isFlipped = false;
        }
        _cards[index].isHinted = false;
      }
      _isLocked = false;
      _lastTriggeredEffect = null;
      notifyListeners();
    });
  }

  // Helper to clear effect string after UI reacts to it
  void clearLastEffect() {
    _lastTriggeredEffect = null;
  }

  CampaignProgress _snapshotCampaignProgress() {
    return CampaignProgress(
      unlockedDungeonIndex: _unlockedDungeonIndex,
      dungeonLevelProgress: Map<int, int>.from(_dungeonLevelProgress),
      lives: _lives,
      coins: _coins,
      score: _score,
      hintCharges: _hintCharges,
      totalCoins: _totalCoins + _coins, // accumulate run coins into lifetime
      artifactsUnlocked: Set<String>.from(_artifactsUnlocked),
    );
  }

  void _applyCampaignProgress(CampaignProgress saved) {
    // Restore persistent progression (dungeons unlocked, levels cleared)
    _dungeonLevelProgress
      ..clear()
      ..addAll(_sanitizeLevelProgress(saved.dungeonLevelProgress));

    _unlockedDungeonIndex = saved.unlockedDungeonIndex
        .clamp(
          _derivedUnlockedDungeonIndex(),
          DungeonConfig.dungeons.length - 1,
        )
        .toInt();

    // Lifetime / shop fields: persist across runs
    _totalCoins = max(0, saved.totalCoins);

    // NOTE: lives and coins are run-specific — they get reset on initDungeon()
    // so we do NOT restore them from the save file.  Only restore hintCharges
    // (it is a per-run consumable that *can* carry over from the last interrupted save).
    _hintCharges = max(0, saved.hintCharges);

    // Merge artifacts unlocked previously
    _artifactsUnlocked.addAll(saved.artifactsUnlocked);

    // Start the player at their last active dungeon/level
    resumeCampaign();
  }

  Map<int, int> _sanitizeLevelProgress(Map<int, int> progress) {
    final sanitized = <int, int>{};
    for (final entry in progress.entries) {
      if (entry.key < 0 || entry.key >= DungeonConfig.dungeons.length) {
        continue;
      }
      sanitized[entry.key] = entry.value
          .clamp(0, DungeonConfig.levelsPerDungeon)
          .toInt();
    }
    return sanitized;
  }

  int _derivedUnlockedDungeonIndex() {
    var unlockedIndex = 0;
    for (var i = 0; i < DungeonConfig.dungeons.length - 1; i++) {
      if ((_dungeonLevelProgress[i] ?? 0) >= DungeonConfig.levelsPerDungeon) {
        unlockedIndex = i + 1;
      } else {
        break;
      }
    }
    return unlockedIndex;
  }

  Future<void> _saveCampaignProgress() async {
    try {
      await _progressStore.save(_snapshotCampaignProgress());
    } catch (error, stackTrace) {
      debugPrint('Failed to save campaign progress: $error\n$stackTrace');
    }
  }

  Future<void> _clearCampaignProgress() async {
    try {
      await _progressStore.clear();
    } catch (error, stackTrace) {
      debugPrint('Failed to clear campaign progress: $error\n$stackTrace');
    }
  }

}