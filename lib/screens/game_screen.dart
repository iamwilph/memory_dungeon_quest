// ignore_for_file: deprecated_member_use

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:memory_dungeon/widgets/game_hud.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/game_state.dart';
import '../models/dungeon_config.dart';
import 'tips_overlay.dart';
import '../theme/dungeon_theme.dart';
import '../widgets/hud_element.dart';
import '../widgets/torch_overlay.dart';
import '../widgets/ambient_particles.dart';
import '../widgets/dungeon_card_widget.dart';
import '../services/audio_service.dart';
import '../services/achievement_manager.dart';
import '../widgets/ad_banner.dart';
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

  // Tracks whether the TipsOverlay should be rendered.  Decoupled from
  // gameState.isLocked so that the overlay can complete its own fade-out
  // animation before skipPuzzlePreview() mutates the game state.
  bool _showTipsOverlay = false;

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

    // Start ambient audio for current dungeon
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gameState = Provider.of<GameState>(context, listen: false);
      AudioService().startAmbient(gameState.activeDungeon.id);

      // Add listener to process visual triggers from GameState
      gameState.addListener(_handleStateEffects);

      // Seed the tips-overlay flag: show it when the puzzle preview starts
      // and tips are pending. isAwaitingTipsOverlay is only true during the
      // tips phase — not during hint reveals or match-check locks.
      gameState.addListener(_handlePreviewState);
      if (gameState.isAwaitingTipsOverlay) {
        setState(() => _showTipsOverlay = true);
      }
    });
  }

  @override
  void dispose() {
    try {
      final gameState = Provider.of<GameState>(context, listen: false);
      gameState.removeListener(_handleStateEffects);
      gameState.removeListener(_handlePreviewState);
    } catch (e) {
      debugPrint(e.toString());
    }
    AudioService().stopAmbient();
    _shakeController.dispose();
    _flashController.dispose();
    super.dispose();
  }

  /// Called by the GameState listener. Shows the TipsOverlay only when
  /// GameState is specifically awaiting tips (preview start), not for
  /// every isLocked state (hint reveals, match checks, etc.).
  void _handlePreviewState() {
    if (!mounted) return;
    final gameState = Provider.of<GameState>(context, listen: false);
    if (gameState.isAwaitingTipsOverlay && !_showTipsOverlay) {
      setState(() => _showTipsOverlay = true);
    }
  }

  /// Called by TipsOverlay after its own dismiss animation finishes.
  /// Hides the overlay first, then tells GameState to end the preview —
  /// this order prevents GameState from rebuilding the tree (and therefore
  /// removing the overlay widget) while its fade-out is still running.
  void _onTipsOverlayDone() {
    if (!mounted) return;
    setState(() => _showTipsOverlay = false);
    final gameState = Provider.of<GameState>(context, listen: false);
    gameState.skipPuzzlePreview();
  }

  // React to game engine events with high-fidelity visual feedback
  void _handleStateEffects() {
    if (!mounted) return;

    final gameState = Provider.of<GameState>(context, listen: false);
    final effect = gameState.lastTriggeredEffect;

    if (effect == null) return;

    // Effects that have dedicated overlay widgets self-dismiss via clearLastEffect()
    // in their own timers: streak_increment, streak_milestone, streak_broken.
    // All other effects are fire-and-forget (flash/haptic only) — clear them here.
    bool selfDismissed = false;

    switch (effect) {
      case 'poison':
        _triggerShake();
        _triggerFlash(const Color(0x7F2ECC71)); // Toxic green flash
        HapticFeedback.mediumImpact();
        selfDismissed = true; // GameHud listener handles clearLastEffect after HUD animation
        break;
      case 'mismatch_penalty':
        _triggerShake();
        _triggerFlash(const Color(0x7FE74C3C)); // Damage red flash
        HapticFeedback.mediumImpact();
        selfDismissed = true; // GameHud listener handles clearLastEffect after HUD animation
        break;
      case 'heal':
        _triggerFlash(const Color(0x60E74C3C)); // Warm heart heal flash
        selfDismissed = true; // GameHud listener handles clearLastEffect after HUD animation
        break;
      case 'treasure':
        _triggerFlash(const Color(0x60F1C40F)); // Golden hoard flash
        selfDismissed = true; // GameHud listener handles clearLastEffect after HUD animation
        break;
      case 'gem':
        _triggerFlash(const Color(0x603498DB)); // Crystal multiplier flash
        selfDismissed = true; // GameHud listener handles clearLastEffect after HUD animation
        break;
      case 'gem_shatter':
        _triggerFlash(const Color(0x603498DB)); // Crystal shatter flash
        selfDismissed = true; // GameHud listener handles clearLastEffect after HUD animation
        break;
      case 'scroll':
        _triggerFlash(const Color(0x60E67E22)); // Spell scroll flash
        break;
      case 'victory':
        _triggerFlash(const Color(0x6027AE60)); // Victory green flash
        break;
      case 'streak_milestone':
        // Golden flash — overlay widget (_StreakCounterOverlay) self-dismisses
        _triggerFlash(const Color(0x80F1C40F));
        HapticFeedback.lightImpact();
        selfDismissed = true; // overlay timer calls clearLastEffect()
        break;
      case 'streak_broken':
        // Subtle red flash — overlay widget (_StreakBrokenOverlay) self-dismisses
        _triggerFlash(const Color(0x40E74C3C));
        selfDismissed = true; // overlay timer calls clearLastEffect()
        break;
      case 'streak_increment':
        // Orange flash — overlay widget (_StreakCounterOverlay) self-dismisses
        _triggerFlash(const Color(0x40E67E22));
        selfDismissed = true; // overlay timer calls clearLastEffect()
        break;
      default:
        break;
    }

    // Clear fire-and-forget effects immediately; overlay-backed effects clear themselves.
    if (!selfDismissed) {
      gameState.clearLastEffect();
    }
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
      body: Column(
        children: [
          Expanded(
            child: Stack(
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
                    // child: _buildHUD(context, gameState, theme),
                    child: GameHud(
                      context: context,
                      theme: theme,
                    ),
                  ),

                  // Streak / effect text overlay (appears briefly)
                  if (gameState.streakCount > 0 &&
                      gameState.lastTriggeredEffect == 'streak_broken')
                    const _StreakBrokenOverlay(),

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

          // 5b. Deeper Descent crimson overlay tint (always visible in NG+)
          if (gameState.isDeeperDescent)
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Colors.transparent, theme.deeperDescentOverlay],
                    radius: 1.2,
                  ),
                ),
              ),
            ),

          // 5c. Tips Overlay — floats above the entire game scene during the
          //     puzzle preview phase.  Positioned here (above flash/vignette
          //     layers, below game-over) so it is always visible and always
          //     the topmost interactive surface when active.
          //
          //     _showTipsOverlay is managed independently of gameState.isLocked
          //     so the overlay can complete its own fade-out animation before
          //     skipPuzzlePreview() mutates the game tree.
          if (_showTipsOverlay) ...[
            // ModalBarrier covers the whole screen, blocking all game touches,
            // but does NOT absorb touches on widgets above it in the Stack
            // (the TipsOverlay card below this entry).
            const ModalBarrier(dismissible: false, color: Color(0x8C000000)),
            // Centred card panel — sits above the ModalBarrier and is fully interactive
            Center(
              child: TipsOverlay(
                dungeonId: gameState.activeDungeon.id,
                levelIndex: gameState.currentLevel - 1,
                cards: gameState.cards,
                onStartGame: _onTipsOverlayDone,
              ),
            ),
          ],

          // 6. Game Over Overlay Dialog Panel
          if (gameState.isGameOver)
            _buildGameOverOverlay(context, gameState, theme),

          // 7. Dungeon Stage Victory/Clear Overlay Dialog Panel
          if (gameState.isLevelCleared)
            _buildVictoryOverlay(context, gameState, theme),

          // 8. Achievement toast overlay (shown briefly after victory)
          if (gameState.isLevelCleared) const _AchievementToastOverlay(),

          // 9. Streak counter overlay (brief animated popup on every streak build)
          // NOTE: lastTriggeredEffect is 'streak_milestone' on hits of 3/6/9,
          // overwriting 'streak_increment' in game_state.dart — so we match both.
          if (gameState.lastTriggeredEffect == 'streak_increment' ||
              gameState.lastTriggeredEffect == 'streak_milestone')
            _StreakCounterOverlay(
              streakCount: gameState.streakCount,
            ),
              ],
            ),
          ),
          const AdBanner(),
        ],
      ),
    );
  }

  // Modifier badge display helpers
  // IconData _modifierIcon(LevelModifier mod) {
  //   switch (mod) {
  //     case LevelModifier.shadow:
  //       return Icons.visibility_off;
  //     case LevelModifier.timer:
  //       return Icons.timelapse;
  //     case LevelModifier.swap:
  //       return Icons.shuffle;
  //     case LevelModifier.sabotage:
  //       return Icons.warning_amber_rounded;
  //     case LevelModifier.none:
  //       break;
  //   }
  //   return Icons.error_outline;
  // }

  // String _modifierName(LevelModifier mod) {
  //   switch (mod) {
  //     case LevelModifier.shadow:
  //       return 'SHADOW';
  //     case LevelModifier.timer:
  //       return 'TIMELIMIT';
  //     case LevelModifier.swap:
  //       return 'SWAP';
  //     case LevelModifier.sabotage:
  //       return 'SABOTAGE';
  //     case LevelModifier.none:
  //       break;
  //   }
  //   return '';
  // }

  // Carved HUD Layout
  // Widget _buildHUD(
  //   BuildContext context,
  //   GameState gameState,
  //   DungeonThemeData theme,
  // ) {
  //   return Column(
  //     children: [
  //       // Top Row: Chamber name, Depth and Escape Button
  //       Row(
  //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //         children: [
  //           InkWell(
  //             onTap: () => Navigator.pop(context),
  //             borderRadius: BorderRadius.circular(4),
  //             child: Container(
  //               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  //               decoration: BoxDecoration(
  //                 color: Colors.black.withValues(alpha: 0.3),
  //                 borderRadius: BorderRadius.circular(4),
  //                 border: Border.all(
  //                   color: theme.hudBorderColor.withValues(alpha: 0.5),
  //                   width: 1,
  //                 ),
  //               ),
  //               child: Row(
  //                 children: [
  //                   const Icon(
  //                     Icons.exit_to_app,
  //                     size: 12,
  //                     color: Colors.white70,
  //                   ),
  //                   const SizedBox(width: 4),
  //                   Text(
  //                     'FLEE',
  //                     style: DungeonTheme.getBodyStyle(
  //                       12.0,
  //                       Colors.white70,
  //                       weight: FontWeight.bold,
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ),
  //           Column(
  //             children: [
  //               Text(
  //                 gameState.activeDungeon.name.toUpperCase(),
  //                 style: DungeonTheme.getBodyStyle(
  //                   16.0,
  //                   theme.accentColor,
  //                   weight: FontWeight.bold,
  //                 ),
  //               ),
  //               Text(
  //                 '${gameState.activeDungeon.depth} • ${gameState.levelProgressString}',
  //                 textAlign: TextAlign.center,
  //                 style: DungeonTheme.getRuneStyle(
  //                   14.0,
  //                   const Color(0xFFF1C40F),
  //                 ),
  //               ),
  //               if (gameState.isDeeperDescent)
  //                 Container(
  //                   margin: const EdgeInsets.only(top: 2),
  //                   padding: const EdgeInsets.symmetric(
  //                     horizontal: 6,
  //                     vertical: 1,
  //                   ),
  //                   decoration: BoxDecoration(
  //                     color: const Color(0xFFE74C3C).withValues(alpha: 0.25),
  //                     borderRadius: BorderRadius.circular(4),
  //                     border: Border.all(
  //                       color: const Color(0xFFE040FB).withValues(alpha: 0.6),
  //                     ),
  //                   ),
  //                   child: Text(
  //                     '🔥 DEEPER DESCENT',
  //                     style: DungeonTheme.getRuneStyle(
  //                       9.0,
  //                       const Color(0xFFE040FB),
  //                     ),
  //                   ),
  //                 ),
  //             ],
  //           ),

  //           // Active Modifier Badge (below dungeon name)
  //           if (gameState.activeModifier != LevelModifier.none)
  //             Center(
  //               child: Container(
  //                 padding: const EdgeInsets.symmetric(
  //                   horizontal: 10,
  //                   vertical: 4,
  //                 ),
  //                 decoration: BoxDecoration(
  //                   color: Colors.red.withValues(alpha: 0.3),
  //                   borderRadius: BorderRadius.circular(8),
  //                   border: Border.all(
  //                     color: Colors.red.withValues(alpha: 0.6),
  //                   ),
  //                 ),
  //                 child: Row(
  //                   mainAxisSize: MainAxisSize.min,
  //                   children: [
  //                     Icon(
  //                       _modifierIcon(gameState.activeModifier),
  //                       size: 14,
  //                       color: Colors.redAccent,
  //                     ),
  //                     const SizedBox(width: 4),
  //                     Text(
  //                       _modifierName(gameState.activeModifier),
  //                       style: DungeonTheme.getRuneStyle(
  //                         12.0,
  //                         Colors.redAccent,
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //             ),

  //           // Streak display (below modifier badge, only when active)
  //           if (gameState.streakCount > 0)
  //             Center(
  //               child: AnimatedContainer(
  //                 duration: const Duration(milliseconds: 200),
  //                 curve: Curves.easeOut,
  //                 padding: const EdgeInsets.symmetric(
  //                   horizontal: 8,
  //                   vertical: 2,
  //                 ),
  //                 decoration: BoxDecoration(
  //                   color: gameState.streakMultiplier > 1.0
  //                       ? const Color(0xFFF1C40F).withValues(alpha: 0.3)
  //                       : Colors.orange.withValues(alpha: 0.2),
  //                   borderRadius: BorderRadius.circular(6),
  //                   border: Border.all(
  //                     color: gameState.streakMultiplier > 1.0
  //                         ? const Color(0xFFF1C40F)
  //                         : Colors.orange,
  //                     width: gameState.streakMultiplier >= 2.0 ? 1.5 : 1.0,
  //                   ),
  //                 ),
  //                 child: Row(
  //                   mainAxisSize: MainAxisSize.min,
  //                   children: [
  //                     const Text('🔥', style: TextStyle(fontSize: 12)),
  //                     const SizedBox(width: 2),
  //                     Text(
  //                       '${gameState.streakCount}',
  //                       style: DungeonTheme.getRuneStyle(12.0, Colors.orange),
  //                     ),
  //                     if (gameState.streakMultiplier > 1.0) ...[
  //                       const SizedBox(width: 3),
  //                       Text(
  //                         '(${gameState.streakMultiplier.toStringAsFixed(1)}x)',
  //                         style: DungeonTheme.getRuneStyle(
  //                           10.0,
  //                           const Color(0xFFF1C40F),
  //                         ),
  //                       ),
  //                     ],
  //                   ],
  //                 ),
  //               ),
  //             ),

  //           // Mute toggle button (top-right corner)
  //           InkWell(
  //             onTap: () {
  //               final audio = AudioService();
  //               audio.setMuted(!audio.isMuted);
  //               ScaffoldMessenger.of(context).showSnackBar(
  //                 SnackBar(
  //                   content: Text(
  //                     audio.isMuted ? 'Audio muted' : 'Audio unmuted',
  //                   ),
  //                   duration: const Duration(seconds: 1),
  //                   backgroundColor: Colors.black.withValues(alpha: 0.6),
  //                 ),
  //               );
  //             },
  //             borderRadius: BorderRadius.circular(4),
  //             child: Container(
  //               padding: const EdgeInsets.all(6),
  //               decoration: BoxDecoration(
  //                 color: Colors.black.withValues(alpha: 0.3),
  //                 borderRadius: BorderRadius.circular(4),
  //                 border: Border.all(
  //                   color: theme.hudBorderColor.withValues(alpha: 0.5),
  //                 ),
  //               ),
  //               child: Icon(
  //                 AudioService().isMuted ? Icons.volume_off : Icons.volume_up,
  //                 size: 14,
  //                 color: AudioService().isMuted
  //                     ? Colors.white24
  //                     : Colors.white70,
  //               ),
  //             ),
  //           ),

  //           // Multiplier Badge
  //           Container(
  //             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  //             decoration: BoxDecoration(
  //               color: Colors.black.withValues(alpha: 0.3),
  //               borderRadius: BorderRadius.circular(4),
  //               border: Border.all(
  //                 color: gameState.scoreMultiplier > 1.0
  //                     ? const Color(0xFF3498DB)
  //                     : theme.hudBorderColor.withValues(alpha: 0.5),
  //                 width: 1,
  //               ),
  //             ),
  //             child: Row(
  //               children: [
  //                 const Icon(
  //                   Icons.flash_on,
  //                   size: 12,
  //                   color: Color(0xFF3498DB),
  //                 ),
  //                 const SizedBox(width: 2),
  //                 Text(
  //                   '${gameState.scoreMultiplier.toStringAsFixed(1)}x',
  //                   style: DungeonTheme.getBodyStyle(
  //                     12.0,
  //                     gameState.scoreMultiplier > 1.0
  //                         ? const Color(0xFF3498DB)
  //                         : Colors.white70,
  //                     weight: FontWeight.bold,
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ],
  //       ),
  //       const SizedBox(height: 10.0),

  //       // Stats Row: Hearts, Coins, Score
  //       Row(
  //         children: [
  //           // Hearts / Lives
  //           Expanded(
  //             flex: 4,
  //             child: HudElement(
  //               padding: const EdgeInsets.symmetric(
  //                 vertical: 8,
  //                 horizontal: 10,
  //               ),
  //               seed: 1,
  //               child: Row(
  //                 mainAxisAlignment: MainAxisAlignment.center,
  //                 children: List.generate(gameState.maxLives, (index) {
  //                   final isFull = index < gameState.lives;
  //                   return Padding(
  //                     padding: const EdgeInsets.symmetric(horizontal: 2.0),
  //                     child: Icon(
  //                       isFull ? Icons.favorite : Icons.favorite_border,
  //                       color: isFull
  //                           ? const Color(0xFFE74C3C)
  //                           : Colors.white24,
  //                       size: 18.0,
  //                     ),
  //                   );
  //                 }),
  //               ),
  //             ),
  //           ),
  //           const SizedBox(width: 10.0),

  //           // Coins
  //           Expanded(
  //             flex: 3,
  //             child: HudElement(
  //               padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
  //               seed: 2,
  //               child: Row(
  //                 mainAxisAlignment: MainAxisAlignment.center,
  //                 children: [
  //                   const Text('🪙 ', style: TextStyle(fontSize: 14.0)),
  //                   const SizedBox(width: 4.0),
  //                   Text(
  //                     '${gameState.coins}',
  //                     style: DungeonTheme.getBodyStyle(
  //                       12.0,
  //                       const Color(0xFFF1C40F),
  //                       weight: FontWeight.bold,
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ),
  //           const SizedBox(width: 10.0),

  //           // Score
  //           Expanded(
  //             flex: 3,
  //             child: HudElement(
  //               padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
  //               seed: 3,
  //               child: Column(
  //                 mainAxisAlignment: MainAxisAlignment.center,
  //                 children: [
  //                   Text(
  //                     'SCORE',
  //                     style: DungeonTheme.getBodyStyle(8.0, theme.primaryColor),
  //                   ),
  //                   Text(
  //                     '${gameState.score}',
  //                     style: DungeonTheme.getBodyStyle(
  //                       11.0,
  //                       Colors.white,
  //                       weight: FontWeight.bold,
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ),
  //         ],
  //       ),
  //     ],
  //   );
  // }

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

  // Returns death reason text based on the last triggered effect
  String _getDeathReason(String? effect) {
    switch (effect) {
      case 'poison':
        return 'Poison seeped into your veins… The chamber consumes another soul.';
      case 'mismatch_penalty':
        return 'A wrong turn in the dark. The walls close in.';
      case 'game_over':
        return 'The ancient traps proved too much. Rest now, adventurer.';
      case 'heal':
      case 'treasure':
      case 'gem':
      case 'scroll':
      case 'victory':
      case 'streak_milestone':
      case 'streak_broken':
      case 'flip':
      case 'board_swap':
      case 'hint_activate':
      case 'scroll_reveal':
      case 'poison_purify':
      case 'heal_overflow':
      case 'gem_shatter':
      case 'mismatch':
      case null:
        break;
    }
    return 'The dungeon claimed you.';
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

                  // Death reason text
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      _getDeathReason(gameState.lastTriggeredEffect),
                      textAlign: TextAlign.center,
                      style: DungeonTheme.getBodyStyle(
                        11.5,
                        const Color(0xFFE74C3C).withValues(alpha: 0.85),
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 16.0),

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
                  // Daily mode: one shot only — no retry allowed
                  if (gameState.isDailyMode)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'THE VAULT SEALS UNTIL TOMORROW.',
                        textAlign: TextAlign.center,
                        style: DungeonTheme.getBodyStyle(
                          10.0,
                          const Color(0xFFE74C3C).withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
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
                      // No RETRY button in daily mode
                      if (!gameState.isDailyMode) ...[
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
                    gameState.isDailyMode
                        ? 'VAULT PLUNDERED'
                        : isLastLevel
                            ? 'CHAMBER CLEARED'
                            : 'LEVEL COMPLETE',
                    style: DungeonTheme.getTitleStyle(
                      context,
                      const Color(0xFF27AE60),
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    gameState.isDailyMode
                        ? 'THE DAILY VAULT HAS BEEN CONQUERED'
                        : isLastLevel
                            ? 'THE SEALS OPEN TO THE DEEPS'
                            : 'LEVEL $completedLevel OF \${DungeonConfig.levelsPerDungeon} COMPLETE',
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
                  // Daily mode: one board, one shot — no next level, no retry
                  if (gameState.isDailyMode) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'RETURN TOMORROW FOR THE NEXT TRIAL.',
                        textAlign: TextAlign.center,
                        style: DungeonTheme.getBodyStyle(
                          10.0,
                          const Color(0xFF27AE60).withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
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
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MenuScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'RETURN TO CAMP',
                          style: DungeonTheme.getBodyStyle(
                            11.0,
                            Colors.white,
                            weight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ] else
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
                              textAlign: TextAlign.center,
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
                                gameState.initDungeon(nextDungeon);
                              } else {
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

// ─── Achievement Toast Overlay ────────────────────────────

class _AchievementToastOverlay extends StatefulWidget {
  const _AchievementToastOverlay();

  @override
  State<_AchievementToastOverlay> createState() =>
      _AchievementToastOverlayState();
}

class _AchievementToastOverlayState extends State<_AchievementToastOverlay>
    with SingleTickerProviderStateMixin {
  bool _hasShown = false;

  void _showToasts() async {
    if (_hasShown) return;
    _hasShown = true;

    // Wait for victory overlay to render, then show achievement toasts
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final newlyUnlocked = AchievementManager().claimNewlyUnlocked();
    for (final achievement in newlyUnlocked) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(achievement.icon, color: achievement.borderColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ACHIEVEMENT UNLOCKED',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      achievement.name,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFF1C40F),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      achievement.description,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.black.withValues(alpha: 0.85),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: achievement.borderColor ?? Colors.white24,
              width: 1,
            ),
          ),
          margin: const EdgeInsets.only(bottom: 80, left: 12, right: 12),
        ),
      );
      // Brief pause between toasts
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showToasts());
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

// ─── Streak Broken Overlay ────────────────────────────────

class _StreakBrokenOverlay extends StatefulWidget {
  const _StreakBrokenOverlay();

  @override
  State<_StreakBrokenOverlay> createState() => _StreakBrokenOverlayState();
}

class _StreakBrokenOverlayState extends State<_StreakBrokenOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    // Auto-dismiss after 1 second
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        final gs = Provider.of<GameState>(context, listen: false);
        if (gs.lastTriggeredEffect == 'streak_broken') {
          gs.clearLastEffect();
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final value = _controller.value; // 0 → 1
          return Transform.translate(
            offset: Offset(0, -value * 20),
            child: Text(
              'Streak Broken!',
              style: GoogleFonts.cinzel(
                fontSize: 16,
                color: Colors.redAccent.withValues(alpha: (1.0 - value) * 0.8),
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Streak Milestone Overlay ─────────────────────────────

class _StreakMilestoneOverlay extends StatefulWidget {
  final int streakCount;
  const _StreakMilestoneOverlay({required this.streakCount});

  @override
  State<_StreakMilestoneOverlay> createState() =>
      _StreakMilestoneOverlayState();
}

class _StreakMilestoneOverlayState extends State<_StreakMilestoneOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        final gs = Provider.of<GameState>(context, listen: false);
        if (gs.lastTriggeredEffect == 'streak_milestone') {
          gs.clearLastEffect();
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final value = _controller.value; // 0 → 1
          return Transform.scale(
            scale: 1.0 + (1.0 - value) * 0.3,
            child: Text(
              '🔥 Streak Milestone!',
              style: GoogleFonts.cinzel(
                fontSize: 18,
                color: const Color(
                  0xFFF1C40F,
                ).withValues(alpha: (1.0 - value) * 0.9),
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Streak Counter Overlay (transient, every streak build) ──────────────

class _StreakCounterOverlay extends StatefulWidget {
  final int streakCount;
  const _StreakCounterOverlay({required this.streakCount});

  @override
  State<_StreakCounterOverlay> createState() => _StreakCounterOverlayState();
}

class _StreakCounterOverlayState extends State<_StreakCounterOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4),
      ),
    );
    _controller.forward();

    // Auto-dismiss after animation completes
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        final gs = Provider.of<GameState>(context, listen: false);
        if (gs.lastTriggeredEffect == 'streak_increment' ||
            gs.lastTriggeredEffect == 'streak_milestone') {
          gs.clearLastEffect();
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnim.value,
            child: Opacity(
              opacity: _fadeAnim.value,
              child: Text(
                '🔥 ${widget.streakCount}',
                style: GoogleFonts.cinzel(
                  fontSize: 24,
                  color: const Color(0xFFF1C40F),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}