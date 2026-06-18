import 'dungeon_card.dart';

/// Information about a special card piece for the tips overlay.
class TipsPieceInfo {
  final String emoji;
  final CardType cardType;
  final String displayName;
  final String description;

  const TipsPieceInfo({
    required this.emoji,
    required this.cardType,
    required this.displayName,
    required this.description,
  });

  /// Create a [TipsPieceInfo] from a [DungeonCard].
  factory TipsPieceInfo.fromCard(DungeonCard card) {
    return TipsPieceInfo(
      emoji: card.emoji,
      cardType: card.type,
      displayName: _displayNameForType(card.type),
      description: _descriptionForType(card.type),
    );
  }

  static String _displayNameForType(CardType type) {
    switch (type) {
      case CardType.poison:
        return 'Poison';
      case CardType.healing:
        return 'Healing Potion';
      case CardType.treasure:
        return 'Treasure';
      case CardType.scroll:
        return 'Magic Scroll';
      case CardType.gem:
        return 'Gem';
      case CardType.normal:
        return ''; // Should never be shown
    }
  }

  static String _descriptionForType(CardType type) {
    switch (type) {
      case CardType.poison:
        return 'Matching this costs a life, but purifies another poison card from the board.';
      case CardType.healing:
        return 'Matching this restores one life (up to max). Full-health converts to +50 bonus score.';
      case CardType.treasure:
        return 'Matching this grants bonus coins based on your current level.';
      case CardType.scroll:
        return 'Matching this grants a hint charge and auto-reveals a random pair.';
      case CardType.gem:
        return 'Matching this increases your score multiplier and shatters one poison from the board.';
      case CardType.normal:
        return '';
    }
  }
}