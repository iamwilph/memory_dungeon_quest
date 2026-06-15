import 'package:flutter/material.dart';
import 'package:memory_dungeon/models/dungeon_config.dart';
import 'package:memory_dungeon/models/game_state.dart';
import 'package:memory_dungeon/services/audio_service.dart';
import 'package:memory_dungeon/theme/dungeon_theme.dart';
import 'package:memory_dungeon/widgets/hud_element.dart';

class GameHud extends StatelessWidget {
  final BuildContext context;
  final GameState gameState;
  final DungeonThemeData theme;

  // Modifier badge display helpers
  IconData _modifierIcon(LevelModifier mod) {
    switch (mod) {
      case LevelModifier.shadow:
        return Icons.visibility_off;
      case LevelModifier.timer:
        return Icons.timelapse;
      case LevelModifier.swap:
        return Icons.shuffle;
      case LevelModifier.sabotage:
        return Icons.warning_amber_rounded;
      case LevelModifier.none:
        break;
    }
    return Icons.error_outline;
  }

  String _modifierName(LevelModifier mod) {
    switch (mod) {
      case LevelModifier.shadow:
        return 'SHADOW';
      case LevelModifier.timer:
        return 'TIMELIMIT';
      case LevelModifier.swap:
        return 'SWAP';
      case LevelModifier.sabotage:
        return 'SABOTAGE';
      case LevelModifier.none:
        break;
    }
    return '';
  }

  const GameHud({
    super.key,
    required this.context,
    required this.gameState,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top Row: Chamber name, Depth and Escape Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: theme.hudBorderColor.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.exit_to_app,
                      size: 12,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'FLEE',
                      style: DungeonTheme.getBodyStyle(
                        12.0,
                        Colors.white70,
                        weight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Column(
              children: [
                Text(
                  gameState.activeDungeon.name.toUpperCase(),
                  style: DungeonTheme.getBodyStyle(
                    16.0,
                    theme.accentColor,
                    weight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${gameState.activeDungeon.depth} • ${gameState.levelProgressString}',
                  textAlign: TextAlign.center,
                  style: DungeonTheme.getRuneStyle(
                    14.0,
                    const Color(0xFFF1C40F),
                  ),
                ),
                if (gameState.isDeeperDescent)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE74C3C).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFFE040FB).withValues(alpha: 0.6),
                      ),
                    ),
                    child: Text(
                      '🔥 DEEPER DESCENT',
                      style: DungeonTheme.getRuneStyle(
                        9.0,
                        const Color(0xFFE040FB),
                      ),
                    ),
                  ),
              ],
            ),

            // Active Modifier Badge (below dungeon name)
            if (gameState.activeModifier != LevelModifier.none)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _modifierIcon(gameState.activeModifier),
                        size: 14,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _modifierName(gameState.activeModifier),
                        style: DungeonTheme.getRuneStyle(
                          12.0,
                          Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Streak display (below modifier badge, only when active)
            if (gameState.streakCount > 0)
              Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: gameState.streakMultiplier > 1.0
                        ? const Color(0xFFF1C40F).withValues(alpha: 0.3)
                        : Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: gameState.streakMultiplier > 1.0
                          ? const Color(0xFFF1C40F)
                          : Colors.orange,
                      width: gameState.streakMultiplier >= 2.0 ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 2),
                      Text(
                        '${gameState.streakCount}',
                        style: DungeonTheme.getRuneStyle(12.0, Colors.orange),
                      ),
                      if (gameState.streakMultiplier > 1.0) ...[
                        const SizedBox(width: 3),
                        Text(
                          '(${gameState.streakMultiplier.toStringAsFixed(1)}x)',
                          style: DungeonTheme.getRuneStyle(
                            10.0,
                            const Color(0xFFF1C40F),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            // Mute toggle button (top-right corner)
            InkWell(
              onTap: () {
                final audio = AudioService();
                audio.setMuted(!audio.isMuted);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      audio.isMuted ? 'Audio muted' : 'Audio unmuted',
                    ),
                    duration: const Duration(seconds: 1),
                    backgroundColor: Colors.black.withValues(alpha: 0.6),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: theme.hudBorderColor.withValues(alpha: 0.5),
                  ),
                ),
                child: Icon(
                  AudioService().isMuted ? Icons.volume_off : Icons.volume_up,
                  size: 14,
                  color: AudioService().isMuted
                      ? Colors.white24
                      : Colors.white70,
                ),
              ),
            ),

            // Multiplier Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: gameState.scoreMultiplier > 1.0
                      ? const Color(0xFF3498DB)
                      : theme.hudBorderColor.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.flash_on,
                    size: 12,
                    color: Color(0xFF3498DB),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${gameState.scoreMultiplier.toStringAsFixed(1)}x',
                    style: DungeonTheme.getBodyStyle(
                      12.0,
                      gameState.scoreMultiplier > 1.0
                          ? const Color(0xFF3498DB)
                          : Colors.white70,
                      weight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10.0),

        // Stats Row: Hearts, Coins, Score
        Row(
          children: [
            // Hearts / Lives
            Expanded(
              flex: 4,
              child: HudElement(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 10,
                ),
                seed: 1,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(gameState.maxLives, (index) {
                    final isFull = index < gameState.lives;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: Icon(
                        isFull ? Icons.favorite : Icons.favorite_border,
                        color: isFull
                            ? const Color(0xFFE74C3C)
                            : Colors.white24,
                        size: 18.0,
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(width: 10.0),

            // Coins
            Expanded(
              flex: 3,
              child: HudElement(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                seed: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🪙 ', style: TextStyle(fontSize: 14.0)),
                    const SizedBox(width: 4.0),
                    Text(
                      '${gameState.coins}',
                      style: DungeonTheme.getBodyStyle(
                        12.0,
                        const Color(0xFFF1C40F),
                        weight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10.0),

            // Score
            Expanded(
              flex: 3,
              child: HudElement(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                seed: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'SCORE',
                      style: DungeonTheme.getBodyStyle(8.0, theme.primaryColor),
                    ),
                    Text(
                      '${gameState.score}',
                      style: DungeonTheme.getBodyStyle(
                        11.0,
                        Colors.white,
                        weight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
