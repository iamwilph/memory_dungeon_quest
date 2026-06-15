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
        // ── Top Row ──────────────────────────────────────────────────────────
        // Layout: [FLEE] | [Expanded middle] | [mute] [multiplier]
        // The middle column holds dungeon name, depth, deeper-descent badge,
        // and all optional badges (modifier + streak) in a Wrap so they never
        // overflow regardless of how many are active.
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Left: Flee button (fixed) ─────────────────────────────────
            _FleeButton(context: context, theme: theme),

            // ── Middle: all dungeon info + optional badges ────────────────
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dungeon name
                  Text(
                    gameState.activeDungeon.name.toUpperCase(),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: DungeonTheme.getBodyStyle(
                      16.0,
                      theme.accentColor,
                      weight: FontWeight.bold,
                    ),
                  ),

                  // Depth + progress
                  Text(
                    '${gameState.activeDungeon.depth} • ${gameState.levelProgressString}',
                    textAlign: TextAlign.center,
                    style: DungeonTheme.getRuneStyle(
                      14.0,
                      const Color(0xFFF1C40F),
                    ),
                  ),

                  // "DEEPER DESCENT" badge (only when active)
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

                  // Optional badges: modifier + streak sit in a Wrap so they
                  // reflow to a second line instead of overflowing horizontally.
                  if (gameState.activeModifier != LevelModifier.none ||
                      gameState.streakCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          // Modifier badge
                          if (gameState.activeModifier != LevelModifier.none)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
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
                                    size: 12,
                                    color: Colors.redAccent,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _modifierName(gameState.activeModifier),
                                    style: DungeonTheme.getRuneStyle(
                                      10.0,
                                      Colors.redAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Streak badge
                          if (gameState.streakCount > 0)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: gameState.streakMultiplier > 1.0
                                    ? const Color(0xFFF1C40F)
                                        .withValues(alpha: 0.3)
                                    : Colors.orange.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: gameState.streakMultiplier > 1.0
                                      ? const Color(0xFFF1C40F)
                                      : Colors.orange,
                                  width:
                                      gameState.streakMultiplier >= 2.0 ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    '🔥',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${gameState.streakCount}',
                                    style: DungeonTheme.getRuneStyle(
                                        11.0, Colors.orange),
                                  ),
                                  if (gameState.streakMultiplier > 1.0) ...[
                                    const SizedBox(width: 3),
                                    Text(
                                      '(${gameState.streakMultiplier.toStringAsFixed(1)}x)',
                                      style: DungeonTheme.getRuneStyle(
                                        9.0,
                                        const Color(0xFFF1C40F),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // ── Right: mute + multiplier (fixed) ─────────────────────────
            _MuteButton(context: context, theme: theme),
            const SizedBox(width: 6),
            _MultiplierBadge(gameState: gameState, theme: theme),
          ],
        ),

        const SizedBox(height: 10.0),

        // ── Stats Row: Hearts · Coins · Score ────────────────────────────
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
                  children: [
                    // Always render exactly 5 hearts
                    ...List.generate(5, (index) {
                      final isFull = index < gameState.lives;
                      final isMaxed = gameState.lives >= gameState.maxLives;
                      final isWarning =
                          gameState.lives >= gameState.maxLives - 3 &&
                              gameState.lives < gameState.maxLives;

                      Color heartColor;
                      if (isMaxed) {
                        // Gold glow when fully healed
                        heartColor = const Color(0xFFF1C40F);
                      } else if (isFull) {
                        heartColor = const Color(0xFFE74C3C);
                      } else if (isWarning) {
                        // Dim 5th heart when close to full — "use potions soon"
                        heartColor = Colors.white38;
                      } else {
                        heartColor = isFull
                            ? const Color(0xFFE74C3C)
                            : Colors.white24;
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: Icon(
                          isFull ? Icons.favorite : Icons.favorite_border,
                          color: heartColor,
                          size: 18.0,
                        ),
                      );
                    }),

                    // Overflow text when maxLives > 5
                    if (gameState.maxLives > 5) ...[
                      SizedBox(width: 4),
                      Text(
                        '+${gameState.maxLives - 5}',
                        style: DungeonTheme.getBodyStyle(
                          13.0,
                          (gameState.lives >= gameState.maxLives)
                              ? const Color(0xFFF1C40F) // gold when full
                              : theme.accentColor, // dungeon theme color
                          weight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 6),
                      // Ratio text: current/max
                      Text(
                        '${gameState.lives}/${gameState.maxLives}',
                        style: DungeonTheme.getBodyStyle(
                          11.0,
                          const Color(0xFF8888AA),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10.0),

            // Coins
            Expanded(
              flex: 3,
              child: HudElement(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
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
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                seed: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'SCORE',
                      style:
                          DungeonTheme.getBodyStyle(8.0, theme.primaryColor),
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

// ─────────────────────────────────────────────────────────────────────────────
//  Private sub-widgets  (keep build() methods lean and readable)
// ─────────────────────────────────────────────────────────────────────────────

class _FleeButton extends StatelessWidget {
  final BuildContext context;
  final DungeonThemeData theme;

  const _FleeButton({required this.context, required this.theme});

  @override
  Widget build(BuildContext ctx) {
    return InkWell(
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
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.exit_to_app, size: 12, color: Colors.white70),
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
    );
  }
}

class _MuteButton extends StatelessWidget {
  final BuildContext context;
  final DungeonThemeData theme;

  const _MuteButton({required this.context, required this.theme});

  @override
  Widget build(BuildContext ctx) {
    return InkWell(
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
          color: AudioService().isMuted ? Colors.white24 : Colors.white70,
        ),
      ),
    );
  }
}

class _MultiplierBadge extends StatelessWidget {
  final GameState gameState;
  final DungeonThemeData theme;

  const _MultiplierBadge({required this.gameState, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
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
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.flash_on, size: 12, color: Color(0xFF3498DB)),
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
    );
  }
}
