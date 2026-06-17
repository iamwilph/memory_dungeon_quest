import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../models/dungeon_config.dart';
import '../theme/dungeon_theme.dart';
import '../theme/stone_painter.dart';
import '../widgets/torch_overlay.dart';
import '../widgets/ambient_particles.dart';
import '../services/high_score_service.dart';
import 'game_screen.dart';

/// Level-select overlay: shown when a fully-cleared chamber is tapped on the
/// campaign map. Lets the player pick any level 1–20 within that chamber.
class LevelSelectOverlay extends StatelessWidget {
  final DungeonConfig config;
  final int dungeonIndex;

  const LevelSelectOverlay({
    super.key,
    required this.config,
    required this.dungeonIndex,
  });

  @override
  Widget build(BuildContext context) {
    final gameState = Provider.of<GameState>(context);
    final theme = DungeonTheme.getTheme(config.themeType);
    final highestCleared = gameState.getHighestClearedLevel(dungeonIndex);

    return Dialog(
      backgroundColor: Colors.transparent,
      // Ensure the dialog respects screen edges with explicit horizontal margins
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
        child: Material(
          color: Colors.transparent,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background
              Container(
                decoration: BoxDecoration(
                  gradient: theme.bgGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: const AmbientParticles(),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: const TorchOverlay(child: SizedBox.expand()),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  // Fill the constrained box height so Expanded works correctly
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Title row — back arrow pinned left, title truly centred
                    SizedBox(
                      width: double.infinity,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            config.name.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: DungeonTheme.getCampaignTitleStyle(
                              context,
                              theme.accentColor,
                            ),
                          ),
                          Positioned(
                            left: 0,
                            child: InkWell(
                              onTap: () => Navigator.pop(context),
                              borderRadius: BorderRadius.circular(20),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.arrow_back,
                                  size: 16,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Subtitle
                    Text(
                      'SELECT YOUR DESCENT',
                      style: GoogleFonts.cinzel(
                        fontSize: 10,
                        color: Colors.white54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Grid takes all remaining vertical space and scrolls if needed
                    Expanded(
                      child: GridView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: DungeonConfig.levelsPerDungeon,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1.1,
                        ),
                        itemBuilder: (context, index) {
                          final level = index + 1;
                          final isCleared = level <= highestCleared;
                          final isCurrent = level == highestCleared + 1;
                          final modifier = config.getModifierForLevel(level);
                          final bestScore = HighScoreService().getBestScore(
                            config.id,
                            level - 1,
                          );

                          return _LevelButton(
                            level: level,
                            isCleared: isCleared,
                            isCurrent: isCurrent,
                            modifier: modifier,
                            bestScore: bestScore,
                            theme: theme,
                            buttonWidth: 0,
                            dungeonId: config.id,
                            onTap: () {
                              gameState.initDungeon(
                                config,
                                startLevel: level,
                              );
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const GameScreen(),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Hint text
                    Text(
                      'Complete all 20 levels to unlock the next chamber.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cinzel(
                        fontSize: 8,
                        color: Colors.white54,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Individual Level Button
// ---------------------------------------------------------------------------

class _LevelButton extends StatelessWidget {
  final int level;
  final bool isCleared;
  final bool isCurrent;
  final LevelModifier modifier;
  final int? bestScore;
  final DungeonThemeData theme;
  final double buttonWidth;
  final String dungeonId;
  final VoidCallback onTap;

  const _LevelButton({
    required this.level,
    required this.isCleared,
    required this.isCurrent,
    required this.modifier,
    required this.bestScore,
    required this.theme,
    required this.buttonWidth,
    required this.dungeonId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final modifierLabel = _modifierLabel(modifier);

    return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isCleared ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          splashColor: theme.accentColor.withValues(alpha: 0.15),
          child: CustomPaint(
            painter: StonePainter(
              bgColor: isCleared
                  ? theme.hudBgColor
                  : const Color(0xFF1A1A1E),
              borderColor: isCleared
                  ? (isCurrent ? theme.accentColor : theme.hudBorderColor)
                  : const Color(0xFF3A3A3E),
              crackColor: isCleared
                  ? theme.primaryColor.withValues(alpha: 0.2)
                  : const Color(0xFF3A3A3E).withValues(alpha: 0.1),
              borderRadius: 8,
              borderWidth: isCleared ? 1.5 : 1.0,
              drawCracks: isCleared,
              seed: level * 7 + theme.themeType.index,
            ),
            child: Container(
              decoration: isCurrent
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: theme.accentColor.withValues(alpha: 0.2),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    )
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Level number
                    Text(
                      'LVL $level',
                      style: DungeonTheme.getBodyStyle(
                        9,
                        isCleared ? Colors.white : Colors.white30,
                        weight: FontWeight.bold,
                      ),
                    ),

                    // Grid size
                    Text(
                      configForLevel(level),
                      style: GoogleFonts.cinzel(
                        fontSize: 7,
                        color: isCleared ? Colors.white70 : Colors.white24,
                      ),
                    ),

                    // Modifier badge (if any)
                    if (modifier != LevelModifier.none && isCleared)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE74C3C).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: const Color(0xFFE74C3C).withValues(alpha: 0.5),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            modifierLabel,
                            style: GoogleFonts.cinzel(
                              fontSize: 6,
                              color: const Color(0xFFE74C3C),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                    // Best score (if exists)
                    if (bestScore != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          '$bestScore',
                          style: GoogleFonts.cinzel(
                            fontSize: 6,
                            color: theme.accentColor.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ),
      ),
    );
  }

  String _modifierLabel(LevelModifier mod) {
    switch (mod) {
      case LevelModifier.shadow: return 'SHADOW';
      case LevelModifier.timer: return 'TIMER';
      case LevelModifier.swap: return 'SWAP';
      case LevelModifier.sabotage: return 'FAKE';
      case LevelModifier.none: return '';
    }
  }

  String configForLevel(int level) {
    final grid = DungeonConfig.dungeons.firstWhere(
      (d) => d.id == dungeonId,
    ).getGridSizeForLevel(level);
    return '${grid['rows']}×${grid['cols']}';
  }
}