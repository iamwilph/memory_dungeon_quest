enum CardType {
  poison,
  healing,
  treasure,
  scroll,
  gem,
  normal,
}

class DungeonCard {
  final int id;
  final String emoji;
  final CardType type;
  bool isFlipped;
  bool isMatched;
  bool isHinted;

  DungeonCard({
    required this.id,
    required this.emoji,
    required this.type,
    this.isFlipped = false,
    this.isMatched = false,
    this.isHinted = false,
  });

  // Determine the card type based on its emoji representation
  static CardType getCardTypeFromEmoji(String emoji) {
    switch (emoji) {
      case '🤢':
      case '💀':
      case '☠️':
      case '🐍':
        return CardType.poison;
      case '🧪':
        return CardType.healing;
      case '🪙':
      case '💰':
      case '👑':
        return CardType.treasure;
      case '📜':
      case '📖':
        return CardType.scroll;
      case '💎':
      case '🔮':
      case '☄️':
        return CardType.gem;
      default:
        return CardType.normal;
    }
  }

  // Copy with helper if needed
  DungeonCard copyWith({
    int? id,
    String? emoji,
    CardType? type,
    bool? isFlipped,
    bool? isMatched,
    bool? isHinted,
  }) {
    return DungeonCard(
      id: id ?? this.id,
      emoji: emoji ?? this.emoji,
      type: type ?? this.type,
      isFlipped: isFlipped ?? this.isFlipped,
      isMatched: isMatched ?? this.isMatched,
      isHinted: isHinted ?? this.isHinted,
    );
  }
}
