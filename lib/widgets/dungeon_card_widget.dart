import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/dungeon_card.dart';
import '../models/game_state.dart';
import '../theme/dungeon_theme.dart';
import '../theme/stone_painter.dart';

class DungeonCardWidget extends StatelessWidget {
  final DungeonCard card;
  final VoidCallback onTap;

  const DungeonCardWidget({
    super.key,
    required this.card,
    required this.onTap,
  });

  // Returns a stable runic character based on card ID
  String _getRuneCharacter(int id) {
    const runes = ['ᚠ', 'ᚢ', 'ᚦ', 'ᚨ', 'ᚱ', 'ᚲ', 'ᚷ', 'ᚹ', 'ᚺ', 'ᚾ', 'ᛁ', 'ᛃ', 'ᛇ', 'ᛈ', 'ᛉ', 'ᛋ', 'ᛏ', 'ᛒ', 'ᛖ', 'ᛗ', 'ᛚ', 'ᛜ', 'ᛞ', 'ᛟ'];
    return runes[id % runes.length];
  }

  @override
  Widget build(BuildContext context) {
    final gameState = Provider.of<GameState>(context);
    final theme = DungeonTheme.getTheme(gameState.activeDungeon.themeType);

    // Animate between flipped (1.0) and unflipped (0.0) states
    final isFlipped = card.isFlipped || card.isMatched;

    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: isFlipped ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        builder: (context, val, child) {
          final isFront = val >= 0.5;
          final angle = val * pi;

          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.003) // Perspective
              ..rotateY(angle),
            alignment: Alignment.center,
            child: isFront
                ? Transform(
                    transform: Matrix4.identity()..rotateY(pi), // Flip front card face back
                    alignment: Alignment.center,
                    child: _buildFrontFace(context, theme),
                  )
                : _buildBackFace(context, theme, gameState),
          );
        },
      ),
    );
  }

  // Renders the rough chiseled stone block card back
  Widget _buildBackFace(BuildContext context, DungeonThemeData theme, GameState gameState) {
    // Check for poison_sight artifact
    final hasPoisonSight = gameState.unlockedArtifacts.contains('poison_sight');
    final showPoisonWarning = hasPoisonSight && card.type == CardType.poison;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.5),
            offset: const Offset(2, 3),
            blurRadius: 4,
          ),
        ],
      ),
      child: Stack(
        children: [
          CustomPaint(
            painter: StonePainter(
              bgColor: theme.cardBackBgColor,
              borderColor: theme.hudBorderColor,
              crackColor: hasPoisonSight
                  ? (card.type == CardType.poison
                      ? const Color(0xFFE74C3C) // Red tint for poison cards
                      : theme.accentColor)
                  : theme.accentColor, // Use dungeon accent color for cracks
              borderRadius: 6.0,
              borderWidth: showPoisonWarning ? 2.0 : 1.5,
              drawCracks: true,
              seed: card.id,
              themeAccent: hasPoisonSight && card.type == CardType.poison ? null : theme.accentColor,
            ),
            child: Center(
              child: Text(
                _getRuneCharacter(card.id),
                style: DungeonTheme.getRuneStyle(22.0, theme.cardBackRuneColor.withValues(alpha:0.55)),
              ),
            ),
          ),
          // Poison warning indicator (red dot in bottom-right corner)
          if (showPoisonWarning)
            Positioned(
              bottom: 6,
              right: 6,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFFE74C3C),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Renders the polished dark obsidian card front
  Widget _buildFrontFace(BuildContext context, DungeonThemeData theme) {
    final glowColor = DungeonTheme.getCardGlowColor(card.type);
    
    // Pulse animation overlay if card is highlighted/hinted
    final isHinted = card.isHinted;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF15151D),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(
          color: isHinted ? const Color(0xFF00FFFF) : glowColor.withValues(alpha:0.85),
          width: isHinted ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isHinted
                ? const Color(0xFF00FFFF).withValues(alpha:0.6)
                : glowColor.withValues(alpha:0.35),
            blurRadius: isHinted ? 8.0 : 4.0,
            spreadRadius: isHinted ? 1.0 : 0.0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha:0.7),
            offset: const Offset(1, 2),
            blurRadius: 3,
          ),
        ],
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.75,
          colors: [
            const Color(0xFF22222E),
            const Color(0xFF0D0D14),
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The emoji icon in the center
          Center(
            child: Text(
              card.emoji,
              style: const TextStyle(fontSize: 32.0),
            ),
          ),
          // Subtle success indicator if card is matched
          if (card.isMatched)
            Positioned(
              top: 3,
              right: 3,
              child: Icon(
                Icons.check_circle_outline,
                size: 14.0,
                color: Colors.white.withValues(alpha:0.35),
              ),
            ),
          // Special border indicator based on item types (glowing corners/dots)
          if (card.type != CardType.normal && !card.isMatched)
            Positioned(
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
                decoration: BoxDecoration(
                  color: glowColor.withValues(alpha:0.15),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: glowColor.withValues(alpha:0.3), width: 0.5),
                ),
                child: Text(
                  card.type.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 8.0,
                    fontWeight: FontWeight.bold,
                    color: glowColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
