// ignore_for_file: deprecated_member_use

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/game_state.dart';
import '../models/dungeon_config.dart';
import '../theme/dungeon_theme.dart';
import '../widgets/hud_element.dart';
import '../widgets/torch_overlay.dart';
import '../widgets/ambient_particles.dart';
import '../widgets/dungeon_card_widget.dart';
import 'menu_screen.dart';
import 'dungeon_selector_screen.dart';
import 'shop_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late AnimationController _shakeController;
  late AnimationController _flashController;
  Color _flashColor = Colors.transparent;

  @override
  void initState() {
    super.initState();

    // 1. Controller for screen shaking (damage/poison)
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // 2. Controller for screen-matching color flashes
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    // Add listener to process visual triggers from GameState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GameState>(
        context,
        listen: false,
      ).addListener(_handleStateEffects);
    });
  }

  @override
  void dispose() {
    // FIX: Properly remove listener to prevent memory leaks
    // final gameState = Provider.of<GameState>(context, listen: false);
    // gameState.removeListener(_handleStateEffects);
    // _shakeController.dispose();
    // _flashController.dispose();
    super.dispose();
  }

  // React to game engine events with high-fidelity visual feedback
  void _handleStateEffects() {
    if (!mounted) return;

    final gameState = Provider.of<GameState>(context, listen: false);
    final effect = gameState.lastTriggeredEffect;

    if (effect == null) return;

    switch (effect) {
      case 'poison':
        _triggerShake();
        _triggerFlash(const Color(0x7F2ECC71)); // Toxic green flash
        break;
      case 'mismatch_penalty':
        _triggerShake();
        _triggerFlash(const Color(0x7FE74C3C)); // Damage red flash
        break;
      case 'heal':
        _triggerFlash(const Color(0x60E74C3C)); // Warm heart heal flash
        break;
      case 'treasure':
        _triggerFlash(const Color(0x60F1C40F)); // Golden hoard flash
        break;
      case 'gem':
        _triggerFlash(const Color(0x603498DB)); // Crystal multiplier flash
        break;
      case 'scroll':
        _triggerFlash(const Color(0x60E67E22)); // Spell scroll flash
        break;
      default:
        break;
    }

    // Acknowledge event
    gameState.clearLastEffect();
  }

  void _triggerShake() {
    _shakeController.forward(from: 0.0);
  }

  void _triggerFlash(Color color) {
    setState(() {
      _flashColor = color;
    });
    // Fade in and out
    _flashController.forward(from: 0.0).then((_) {
      _flashController.reverse();
    });
  }

  // Returns offset translation for the screen shake shake animation
  Offset _getShakeOffset(double progress) {
    if (progress == 0.0 || progress == 1.0) return Offset.zero;

    // Jagged translation values
    final shakeSpeed = 50.0;
    final displacement = 10.0 * (1.0 - progress); // Decay displacement
    final dx = sin(progress * shakeSpeed) * displacement;
    final dy = cos(progress * shakeSpeed * 1.2) * displacement;

    return Offset(dx, dy);
  }

  @override
  Widget build(BuildContext context) {
    final gameState = Provider.of<GameState>(context);
    final currentDungeon = gameState.activeDungeon;
    final theme = DungeonTheme.getTheme(currentDungeon.themeType);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Ambient Background Layer
          Container(decoration: BoxDecoration(gradient: theme.bgGradient)),

          // 2. Active Ambient Particle Emitting Layer
          const AmbientParticles(),

          // 3. Flickering Torch & Screen Vignette Overlay
          const TorchOverlay(child: SizedBox.expand()),

          // 4. Primary Crawling Scene (with potential Screen Shake transformation)
          AnimatedBuilder(
            animation: _shakeController,
            builder: (context, child) {
              return Transform.translate(
                offset: _getShakeOffset(_shakeController.value),
                child: child,
              );
            },
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 12.0),

                  // Top carved HUD elements
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildHUD(context, gameState, theme),
                  ),

                  const SizedBox(height: 12.0),

                  // Interactive Grid of Memory Cards
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildCardGrid(context, gameState, currentDungeon),
                    ),
                  ),

                  // Bottom Action Rune Banner
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    child: _buildBottomActions(context, gameState, theme),
                  ),
                ],
              ),
            ),
          ),

          // 5. Screen Flash Color Layer
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _flashController,
              builder: (context, child) {
                // Animate opacity using a curved progress
                final opacity = _flashController.value;
                return Container(
                  color: _flashColor.withValues(
                    alpha: _flashColor.opacity * opacity,
                  ),
                );
              },
            ),
          ),

          // 6. Game Over Overlay Dialog Panel
          if (gameState.isGameOver)
            _buildGameOverOverlay(context, gameState, theme),

          // 7. Dungeon Stage Victory/Clear Overlay Dialog Panel
          if (gameState.isLevelCleared)
            _buildVictoryOverlay(context, gameState, theme),
        ],
      ),
    );
  }

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

// Carved HUD Layout
  Widget _buildHUD(
    BuildContext context,
    GameState gameState,
    DungeonThemeData theme,
  ) {
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
              ],
            ),
        
        // Active Modifier Badge (below dungeon name)
        if (gameState.activeModifier != LevelModifier.none)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_modifierIcon(gameState.activeModifier), size: 14, color: Colors.redAccent),
                  const SizedBox(width: 4),
                  Text(
                    _modifierName(gameState.activeModifier),
                    style: DungeonTheme.getRuneStyle(12.0, Colors.redAccent),
                  ),
                ],
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

  // Generates card grid with calculated responsive aspect ratio
  Widget _buildCardGrid(
    BuildContext context,
    GameState gameState,
    DungeonConfig config,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;

        // Total columns and rows
        final cols = gameState.activeCols;
        final rows = gameState.activeRows;

        // Total available width/height minus padding and inter-item gaps
        final totalSpacingWidth = (cols - 1) * spacing;
        final totalSpacingHeight = (rows - 1) * spacing;

        // Calculate card height/width bounds
        final cellWidth = (constraints.maxWidth - totalSpacingWidth) / cols;
        final cellHeight = (constraints.maxHeight - totalSpacingHeight) / rows;

        // Aspect ratio for cards: width / height
        final aspectRatio = cellWidth / cellHeight;

        return Center(
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                childAspectRatio: aspectRatio,
              ),
              itemCount: gameState.cards.length,
              itemBuilder: (context, index) {
                final card = gameState.cards[index];
                return DungeonCardWidget(
                  card: card,
                  onTap: () => gameState.flipCard(index),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // Bottom action bar containing hint triggers
  Widget _buildBottomActions(
    BuildContext context,
    GameState gameState,
    DungeonThemeData theme,
  ) {
    final hasHints = gameState.hintCharges > 0;
    final hintColor = hasHints ? const Color(0xFFE67E22) : Colors.white24;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: hasHints && !gameState.isLocked
              ? () => gameState.triggerHint()
              : null,
          child: Container(
            width: 260,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: hasHints
                      ? const Color(0x3FE67E22)
                      : Colors.transparent,
                  blurRadius: 8,
                ),
              ],
            ),
            child: HudElement(
              borderRadius: 6.0,
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 8.0,
              ),
              drawCracks: hasHints,
              seed: 9,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_stories, size: 16.0, color: hintColor),
                  const SizedBox(width: 8.0),
                  Flexible(
                    child: Text(
                      'READ SCROLL OF HINTS (${gameState.hintCharges})',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DungeonTheme.getBodyStyle(
                        14,
                        hasHints ? Colors.white : Colors.white30,
                        weight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Game Over stone panel modal
  Widget _buildGameOverOverlay(
    BuildContext context,
    GameState gameState,
    DungeonThemeData theme,
  ) {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: HudElement(
              borderRadius: 16.0,
              padding: const EdgeInsets.all(32.0),
              seed: 666,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'YOU PERISHED',
                    style: DungeonTheme.getTitleStyle(
                      context,
                      const Color(0xFFE74C3C),
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    'THE LABYRINTH RECLAIMS YOUR SOUL',
                    textAlign: TextAlign.center,
                    style: DungeonTheme.getBodyStyle(10.0, theme.primaryColor),
                  ),
                  const Divider(color: Colors.white12, height: 32.0),

                  // Run Stats
                  _buildStatRow(
                    'CHAMBER',
                    gameState.activeDungeon.name.toUpperCase(),
                  ),
                  _buildStatRow('DEPTH', gameState.activeDungeon.depth),
                  _buildStatRow('GOLD RECOVERED', '${gameState.coins} 🪙'),
                  _buildStatRow('SCORE RECORDED', '${gameState.score}'),

                  const SizedBox(height: 32.0),

                  // Restart options
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF5A6B7C)),
                            padding: const EdgeInsets.symmetric(vertical: 14.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const MenuScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'CAMP',
                            style: DungeonTheme.getBodyStyle(
                              11.0,
                              Colors.white,
                              weight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE74C3C),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                          ),
                          onPressed: () {
                            // Retry current dungeon, resets run stats
                            gameState.initDungeon(
                              gameState.activeDungeon,
                              resetStats: true,
                              startLevel: gameState.currentLevel,
                            );
                          },
                          child: Text(
                            'RETRY',
                            style: DungeonTheme.getBodyStyle(
                              11.0,
                              Colors.white,
                              weight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Victory stone panel modal
  Widget _buildVictoryOverlay(
    BuildContext context,
    GameState gameState,
    DungeonThemeData theme,
  ) {
    final isLastLevel = gameState.isLastLevelInChamber;

    // Check if there is a next chamber
    final dungeons = DungeonConfig.dungeons;
    final currentIdx = dungeons.indexWhere(
      (d) => d.id == gameState.activeDungeon.id,
    );
    final hasNextChamber = currentIdx != -1 && currentIdx < dungeons.length - 1;
    final nextDungeon = hasNextChamber ? dungeons[currentIdx + 1] : null;

    final completedLevel = gameState.currentLevel;
    final earnedCoins = gameState.activeDungeon.getRewardCoinsForLevel(
      completedLevel,
    );

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: HudElement(
              borderRadius: 16.0,
              padding: const EdgeInsets.all(32.0),
              seed: 777,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isLastLevel ? 'CHAMBER CLEARED' : 'LEVEL COMPLETE',
                    style: DungeonTheme.getTitleStyle(
                      context,
                      const Color(0xFF27AE60),
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    isLastLevel
                        ? 'THE SEALS OPEN TO THE DEEPS'
                        : 'LEVEL $completedLevel OF ${DungeonConfig.levelsPerDungeon} COMPLETE',
                    textAlign: TextAlign.center,
                    style: DungeonTheme.getBodyStyle(10.0, theme.primaryColor),
                  ),
                  const Divider(color: Colors.white12, height: 32.0),

                  // Stage summary stats
                  _buildStatRow(
                    'CHAMBER',
                    gameState.activeDungeon.name.toUpperCase(),
                  ),
                  _buildStatRow(
                    'LEVEL',
                    '$completedLevel / ${DungeonConfig.levelsPerDungeon}',
                  ),
                  _buildStatRow('COMPLETION REWARD', '+$earnedCoins Coins 🪙'),
                  _buildStatRow('TOTAL COINS', '${gameState.coins} 🪙'),
                  _buildStatRow('CURRENT SCORE', '${gameState.score}'),

                  const SizedBox(height: 32.0),

                  // Navigation options
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF5A6B7C)),
                            padding: const EdgeInsets.symmetric(vertical: 14.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const DungeonSelectorScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'CHAMBER MAP',
                            style: DungeonTheme.getBodyStyle(
                              10.0,
                              Colors.white,
                              weight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      
                      // Shop Button (Phase 3)
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF1C40F),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ShopScreen(),
                              ),
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.store, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                'SHOP',
                                style: DungeonTheme.getBodyStyle(
                                  10.0,
                                  Colors.black,
                                  weight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF27AE60),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                          ),
                          onPressed: () {
                            if (!isLastLevel) {
                              gameState.advanceToNextLevel();
                            } else if (hasNextChamber && nextDungeon != null) {
                              // Descend to next dungeon carrying over lives and coins
                              gameState.initDungeon(nextDungeon);
                            } else {
                              // Beat the game! Return to selector
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const DungeonSelectorScreen(),
                                ),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFF27AE60),
                                  content: Text(
                                    'Congratulations! You have conquered the deepest tombs of the Crypt Chamber!',
                                    style: DungeonTheme.getBodyStyle(
                                      12.0,
                                      Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            }
                          },
                          child: Text(
                            !isLastLevel
                                ? 'NEXT LEVEL'
                                : hasNextChamber
                                ? 'DESCEND'
                                : 'ASCEND HOME',
                            style: DungeonTheme.getBodyStyle(
                              10.0,
                              Colors.white,
                              weight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.cinzel(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: Colors.white54,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.cinzel(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
