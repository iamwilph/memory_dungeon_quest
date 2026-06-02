import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/campaign_progress_store.dart';
import 'campaign_progress.dart';
import 'dungeon_card.dart';
import 'dungeon_config.dart';

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
  final int _maxLives = 5;
  int _coins = 0;
  int _score = 0;
  double _scoreMultiplier = 1.0;
  int _hintCharges = 1; // Start with 1 free hint
  int _unlockedDungeonIndex = 0;

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
    _activeDungeon = config;
    _currentLevel = startLevel.clamp(1, DungeonConfig.levelsPerDungeon).toInt();
    _selectedIndices.clear();
    _isLocked = false;
    _isGameOver = false;
    _isLevelCleared = false;
    _isPreviewingPuzzle = false;
    _lastTriggeredEffect = null;

    if (resetStats) {
      _lives = 3;
      _coins = 0;
      _score = 0;
      _scoreMultiplier = 1.0;
      _hintCharges = 1;
    } else {
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

    final totalPairs = totalTiles ~/ 2;
    const int maxAttempts = 10;
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
    _selectedIndices.add(index);
    _lastTriggeredEffect = 'flip';

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

    _isLevelCleared = true;
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

  bool _isPuzzleSolved() {
    final unmatchedCards = _cards.where((card) => !card.isMatched).toList();
    if (unmatchedCards.isEmpty) return true;

    return unmatchedCards.every((card) => card.type == CardType.poison);
  }

  // Applies side effects based on matched tile types
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
        if (_lives < _maxLives) {
          _lives++;
        }
        _lastTriggeredEffect = 'heal';
        break;
      case CardType.treasure:
        final dungeonMult = _activeDungeon.getScoreMultiplierForLevel(
          _currentLevel,
        );
        final gainedCoins = (_activeDungeon.baseRewardCoins * dungeonMult)
            .round();
        _coins += gainedCoins;
        _lastTriggeredEffect = 'treasure';
        break;
      case CardType.scroll:
        _hintCharges++;
        _lastTriggeredEffect = 'scroll';
        break;
      case CardType.gem:
        _scoreMultiplier += 0.5;
        _lastTriggeredEffect = 'gem';
        break;
      case CardType.normal:
        _lastTriggeredEffect = 'normal';
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
    );
  }

  void _applyCampaignProgress(CampaignProgress progress) {
    _dungeonLevelProgress
      ..clear()
      ..addAll(_sanitizeLevelProgress(progress.dungeonLevelProgress));

    _unlockedDungeonIndex = progress.unlockedDungeonIndex
        .clamp(
          _derivedUnlockedDungeonIndex(),
          DungeonConfig.dungeons.length - 1,
        )
        .toInt();
    _lives = progress.lives.clamp(1, _maxLives).toInt();
    _coins = max(0, progress.coins);
    _score = max(0, progress.score);
    _hintCharges = max(0, progress.hintCharges);

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

  @override
  void dispose() {
    _previewSessionId++;
    _cancelPuzzlePreviewTimers();
    super.dispose();
  }
}
