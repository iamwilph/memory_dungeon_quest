import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/dungeon_card.dart';
import '../models/tips_piece_info.dart';

/// Service that tracks which tips pieces have been shown per dungeon+level.
/// Uses [SharedPreferences] for persistence across app launches.
class TipsStateService extends ChangeNotifier {
  static final TipsStateService _instance = TipsStateService._internal();
  factory TipsStateService() => _instance;
  TipsStateService._internal();

  static const String _prefix = 'tips_seen_';

  // All defined special pieces across all dungeons, keyed by emoji.
  // Shared description strings — all poison variants show the same tip, etc.
  static const String _poisonDesc =
      'Matching this costs a life, but purifies another poison card from the board.';
  static const String _healingDesc =
      'Matching this restores one life (up to max). Full-health converts to +50 bonus score.';
  static const String _treasureDesc =
      'Matching this grants bonus coins based on your current level.';
  static const String _scrollDesc =
      'Matching this grants a hint charge and auto-reveals a random pair.';
  static const String _gemDesc =
      'Matching this increases your score multiplier and shatters one poison from the board.';

  /// Every emoji that [DungeonCard.getCardTypeFromEmoji] can classify as
  /// non-normal must have an entry here, or the sort comparator will crash
  /// with a null-check error.
  static const Map<String, TipsPieceInfo> allSpecialPieces = {
    // ── Poison ──────────────────────────────────────────────────────────────
    '🤢': TipsPieceInfo(emoji: '🤢', cardType: CardType.poison, displayName: 'Poison',         description: _poisonDesc),
    '💀': TipsPieceInfo(emoji: '💀', cardType: CardType.poison, displayName: 'Poison Skull',    description: _poisonDesc),
    '☠️': TipsPieceInfo(emoji: '☠️', cardType: CardType.poison, displayName: 'Poison',         description: _poisonDesc),
    '🐍': TipsPieceInfo(emoji: '🐍', cardType: CardType.poison, displayName: 'Viper',           description: _poisonDesc),
    // ── Healing ─────────────────────────────────────────────────────────────
    '💖': TipsPieceInfo(emoji: '💖', cardType: CardType.healing, displayName: 'Healing Potion', description: _healingDesc),
    '🧪': TipsPieceInfo(emoji: '🧪', cardType: CardType.healing, displayName: 'Healing Flask',  description: _healingDesc),
    // ── Treasure ────────────────────────────────────────────────────────────
    '💰': TipsPieceInfo(emoji: '💰', cardType: CardType.treasure, displayName: 'Treasure',      description: _treasureDesc),
    '🪙': TipsPieceInfo(emoji: '🪙', cardType: CardType.treasure, displayName: 'Gold Coin',     description: _treasureDesc),
    '👑': TipsPieceInfo(emoji: '👑', cardType: CardType.treasure, displayName: 'Crown',         description: _treasureDesc),
    // ── Scroll ──────────────────────────────────────────────────────────────
    '📜': TipsPieceInfo(emoji: '📜', cardType: CardType.scroll, displayName: 'Magic Scroll',    description: _scrollDesc),
    '📖': TipsPieceInfo(emoji: '📖', cardType: CardType.scroll, displayName: 'Spell Book',      description: _scrollDesc),
    // ── Gem ─────────────────────────────────────────────────────────────────
    '💎': TipsPieceInfo(emoji: '💎', cardType: CardType.gem, displayName: 'Gem',                description: _gemDesc),
    '🔮': TipsPieceInfo(emoji: '🔮', cardType: CardType.gem, displayName: 'Crystal Orb',        description: _gemDesc),
    '☄️': TipsPieceInfo(emoji: '☄️', cardType: CardType.gem, displayName: 'Comet',             description: _gemDesc),
  };

  // In-memory cache: (dungeonId, level) -> Set<seen emojis>
  final Map<String, Set<String>> _seenCache = {};

  SharedPreferences? _prefs;

  Future<void> init() async {
    if (_prefs != null) return;
    _prefs = await SharedPreferences.getInstance();
  }

  /// Returns the special pieces present on this board, sorted with
  /// poison first, then by CardType. Only includes pieces not yet seen
  /// for this (dungeonId, level).
  List<TipsPieceInfo> getUnseenSpecialPieces(
    String dungeonId,
    int levelIndex,
    List<DungeonCard> cards,
  ) {
    final seen = _getSeenSet(dungeonId, levelIndex);

    // Collect unique special piece emojis from the board.
    final uniqueSpecial = <String>{};
    for (final card in cards) {
      if (card.type != CardType.normal) {
        uniqueSpecial.add(card.emoji);
      }
    }

    // Filter to unseen pieces.
    final unseen = uniqueSpecial
        .where((emoji) => !seen.contains(emoji))
        .toList();

    // Sort: poison first, then by CardType order.
    final order = [
      CardType.poison,
      CardType.healing,
      CardType.treasure,
      CardType.scroll,
      CardType.gem,
    ];

    unseen.sort((a, b) {
      final typeA = allSpecialPieces[a]?.cardType;
      final typeB = allSpecialPieces[b]?.cardType;
      final idxA = typeA != null ? order.indexOf(typeA) : order.length;
      final idxB = typeB != null ? order.indexOf(typeB) : order.length;
      return idxA.compareTo(idxB);
    });

    return unseen
        .where((emoji) => allSpecialPieces[emoji] != null)
        .map((emoji) => allSpecialPieces[emoji]!)
        .toList();
  }

  /// Whether all special pieces for this dungeon+level have been seen.
  bool isAllSeen(String dungeonId, int levelIndex, List<DungeonCard> cards) {
    final seen = _getSeenSet(dungeonId, levelIndex);
    final uniqueSpecial = <String>{};
    for (final card in cards) {
      if (card.type != CardType.normal) {
        uniqueSpecial.add(card.emoji);
      }
    }
    return uniqueSpecial.isEmpty || uniqueSpecial.every(seen.contains);
  }

  /// Marks a piece emoji as seen for this dungeon+level.
  Future<void> markAsSeen(String dungeonId, int levelIndex, String emoji) async {
    final key = _cacheKey(dungeonId, levelIndex);
    _seenCache.putIfAbsent(key, () => {}).add(emoji);
    await _persistSeen(dungeonId, levelIndex, emoji);
    notifyListeners();
  }

  /// Returns true if the given piece has been seen for this dungeon+level.
  bool isPieceSeen(String dungeonId, int levelIndex, String emoji) {
    final seen = _getSeenSet(dungeonId, levelIndex);
    return seen.contains(emoji);
  }

  // ------------------------------------------------------------------
  //  Internal helpers
  // ------------------------------------------------------------------

  String _cacheKey(String dungeonId, int levelIndex) =>
      '$dungeonId/L$levelIndex';

  Set<String> _getSeenSet(String dungeonId, int levelIndex) {
    final key = _cacheKey(dungeonId, levelIndex);
    if (!_seenCache.containsKey(key)) {
      _loadSeenSetIntoCache(dungeonId, levelIndex);
    }
    return _seenCache[key] ?? {};
  }

  void _loadSeenSetIntoCache(String dungeonId, int levelIndex) {
    final key = _cacheKey(dungeonId, levelIndex);
    if (_prefs == null) {
      _seenCache[key] = {};
      return;
    }
    final raw = _prefs?.getString('$_prefix$key');
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _seenCache[key] = list.cast<String>().toSet();
      } catch (_) {
        _seenCache[key] = {};
      }
    } else {
      _seenCache[key] = {};
    }
  }

  Future<void> _persistSeen(String dungeonId, int levelIndex, String emoji) async {
    final key = _cacheKey(dungeonId, levelIndex);
    if (_prefs == null) return;

    final raw = _prefs!.getString('$_prefix$key');
    Set<String> set;
    if (raw != null && raw.isNotEmpty) {
      try {
        set = (jsonDecode(raw) as List<dynamic>).cast<String>().toSet();
      } catch (_) {
        set = {};
      }
    } else {
      set = {};
    }
    set.add(emoji);
    await _prefs!.setString('$_prefix$key', jsonEncode(set.toList()));
  }

  /// Resets all tips data (e.g. for campaign reset).
  Future<void> reset() async {
    if (_prefs == null) return;
    final keys = _prefs!.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in keys) {
      await _prefs!.remove(k);
    }
    _seenCache.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _prefs = null;
    super.dispose();
  }
}