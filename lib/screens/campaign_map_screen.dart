import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../models/game_state.dart';
import '../models/dungeon_config.dart';
import '../theme/dungeon_theme.dart';
import '../theme/stone_painter.dart';
import '../widgets/torch_overlay.dart';
import '../widgets/ambient_particles.dart';
import '../constants.dart';
import 'game_screen.dart';
import 'dungeon_selector_screen.dart';
import '../services/high_score_service.dart';
import 'level_select_overlay.dart';

class CampaignMapScreen extends StatelessWidget {
  const CampaignMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = Provider.of<GameState>(context);
    final baseTheme = DungeonTheme.getTheme(DungeonThemeType.stone);

    return Scaffold(
      body: Stack(
        children: [
          Container(decoration: BoxDecoration(gradient: baseTheme.bgGradient)),
          const AmbientParticles(),
          const TorchOverlay(child: SizedBox.expand()),

          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _backButton(context),
                      Text(
                        'CAMPAIGN MAP',
                        style: DungeonTheme.getCampaignTitleStyle(context, const Color(0xFFF1C40F)),
                      ),
                      _listToggle(context),
                    ],
                  ),
                ),

                // Scrollable Vertical Map
                Expanded(
                  child: _CampaignMapContent(gameState: gameState),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _backButton(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pop(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF5A6B7C).withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.arrow_back, size: 14, color: Colors.white70),
            const SizedBox(width: 6),
            Text('RETURN', style: DungeonTheme.getBodyStyle(11, Colors.white70, weight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _listToggle(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DungeonSelectorScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF5A6B7C).withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.list, size: 14, color: Colors.white70),
            const SizedBox(width: 6),
            Text('LIST', style: DungeonTheme.getBodyStyle(11, Colors.white70, weight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Campaign Map Content (vertical scrollable rooms)
// ---------------------------------------------------------------------------

class _CampaignMapContent extends StatelessWidget {
  final GameState gameState;

  const _CampaignMapContent({required this.gameState});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final roomWidth = math.min(constraints.maxWidth - 64, 280.0);

        // Add 1 extra item if Deeper Descent is unlocked
        final extraItems = gameState.deeperDescentUnlocked ? 1 : 0;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          itemCount: DungeonConfig.dungeons.length + extraItems,
          itemBuilder: (context, index) {
            // Deeper Descent room at the end
            if (index >= DungeonConfig.dungeons.length) {
              return Column(
                children: [
                  _RoomConnector(isUnlocked: true),
                  _DeeperDescentRoomCard(
                    gameState: gameState,
                    roomWidth: roomWidth,
                  ),
                ],
              );
            }

            final config = DungeonConfig.dungeons[index];
            final isUnlocked = kIsDebugMode || index <= gameState.unlockedDungeonIndex;

            return Column(
              children: [
                _CampaignRoomCard(
                  config: config,
                  isUnlocked: isUnlocked,
                  gameState: gameState,
                  roomWidth: roomWidth,
                ),
                if (index < DungeonConfig.dungeons.length - 1)
                  _RoomConnector(isUnlocked: isUnlocked),
              ],
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
//  Individual Room Card
// ---------------------------------------------------------------------------

class _CampaignRoomCard extends StatelessWidget {
  final DungeonConfig config;
  final bool isUnlocked;
  final GameState gameState;
  final double roomWidth;

  const _CampaignRoomCard({
    required this.config,
    required this.isUnlocked,
    required this.gameState,
    required this.roomWidth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DungeonTheme.getTheme(config.themeType);
    final dungeonIndex = DungeonConfig.dungeons.indexWhere((d) => d.id == config.id);
    final highestCleared = gameState.getHighestClearedLevel(dungeonIndex);
    final isFullyCleared = highestCleared >= DungeonConfig.levelsPerDungeon;

    // Get best score for the highest cleared level
    final bestScore = isFullyCleared
        ? HighScoreService().getBestScore(config.id, DungeonConfig.levelsPerDungeon - 1)
        : (highestCleared > 0)
            ? HighScoreService().getBestScore(config.id, highestCleared - 1)
            : null;

    return Container(
      width: roomWidth,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isUnlocked
              ? () {
                  if (isFullyCleared) {
                    // Show level-select overlay for fully-cleared chambers
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LevelSelectOverlay(
                          config: config,
                          dungeonIndex: dungeonIndex,
                        ),
                      ),
                    );
                  } else {
                    gameState.initDungeonAtNextUnfinishedLevel(config);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const GameScreen()),
                    );
                  }
                }
              : null,
          borderRadius: BorderRadius.circular(12),
          splashColor: theme.accentColor.withValues(alpha: 0.1),
          child: CustomPaint(
            painter: StonePainter(
              bgColor: isUnlocked ? theme.hudBgColor : const Color(0xFF1E1E22),
              borderColor: isUnlocked ? theme.hudBorderColor : const Color(0xFF424242),
              crackColor: isUnlocked
                  ? theme.primaryColor.withValues(alpha: 0.3)
                  : const Color(0xFF424242).withValues(alpha: 0.1),
              borderRadius: 12,
              borderWidth: isUnlocked ? 2.0 : 1.0,
              drawCracks: true,
              seed: config.name.hashCode + 42,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Room header with icon and name
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isUnlocked
                              ? theme.cardBackBgColor.withValues(alpha: 0.3)
                              : const Color(0xFF151515),
                          border: Border.all(
                            color: isUnlocked ? theme.hudBorderColor : const Color(0xFF424242),
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(isUnlocked ? _getRoomEmoji(config) : '?', style: const TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              config.name.toUpperCase(),
                              style: DungeonTheme.getBodyStyle(14, isUnlocked ? theme.accentColor : Colors.white24, weight: FontWeight.bold),
                            ),
                            Text(
                              '${config.cols}×${config.rows} • ${config.totalPairs} pairs',
                              style: GoogleFonts.cinzel(fontSize: 9, color: isUnlocked ? Colors.white54 : Colors.white24),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Progress dots (level indicators)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(DungeonConfig.levelsPerDungeon, (levelIndex) {
                      final isCleared = levelIndex < highestCleared;
                      final isCurrent = levelIndex == highestCleared && highestCleared < DungeonConfig.levelsPerDungeon;

                      return TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: isCleared || isCurrent ? 1.0 : 0.0),
                        duration: const Duration(milliseconds: 300),
                        builder: (context, val, child) {
                          return Transform.scale(
                            scale: 0.8 + val * 0.2,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isCleared
                                    ? theme.accentColor.withValues(alpha: 0.6)
                                    : isCurrent && isUnlocked
                                        ? theme.primaryColor.withValues(alpha: 0.4)
                                        : const Color(0xFF2C3E50),
                                border: Border.all(
                                  color: isCleared
                                      ? theme.accentColor
                                      : isCurrent && isUnlocked
                                          ? theme.primaryColor
                                          : const Color(0xFF424242),
                                  width: isCurrent && isUnlocked ? 2.0 : 1.0,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  ),

                  const SizedBox(height: 8),

                  // Status text
                  Text(
                    isUnlocked
                        ? (isFullyCleared
                            ? 'CHAMBER CLEARED ✓'
                            : 'Next: Level ${highestCleared + 1}')
                        : 'SEALED BY RUNE MAGIC',
                    style: GoogleFonts.cinzel(
                      fontSize: 9,
                      color: isUnlocked
                          ? (isFullyCleared ? Colors.greenAccent : theme.accentColor)
                          : const Color(0xFFE74C3C),
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  // Best score
                  if (isUnlocked && bestScore != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Best: $bestScore',
                        style: GoogleFonts.cinzel(fontSize: 8, color: Colors.white30),
                      ),
                    ),

                  // Mismatch penalty indicator
                  if (isUnlocked && config.mismatchPenalty)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('⚠️ MISMATCH PENALTY', style: TextStyle(fontSize: 8, color: Color(0xFFE74C3C))),
                    ),

                  // "Select Levels" button for fully-cleared chambers
                  if (isFullyCleared)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: theme.accentColor.withValues(alpha: 0.5),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.swap_horiz, size: 10, color: theme.accentColor),
                            const SizedBox(width: 4),
                            Text(
                              'SELECT LEVELS',
                              style: DungeonTheme.getBodyStyle(
                                9, theme.accentColor, weight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Locked overlay — show a small lock badge aligned to the
                  // right inside the Column (Positioned is only valid in Stack)
                  if (!isUnlocked)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: const Icon(
                          Icons.lock_open,
                          size: 14,
                          color: Color(0xFFE74C3C),
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

  String _getRoomEmoji(DungeonConfig c) {
    switch (c.themeType) {
      case DungeonThemeType.stone: return '🔑';
      case DungeonThemeType.lava: return '🌋';
      case DungeonThemeType.ice: return '❄️';
      case DungeonThemeType.crypt: return '⚰️';
      case DungeonThemeType.voidChamber: return '🪐';
      case DungeonThemeType.forest: return '🌲';
    }
  }
}

// ---------------------------------------------------------------------------
//  Room Connector (corridor between rooms)
// ---------------------------------------------------------------------------

class _RoomConnector extends StatelessWidget {
  final bool isUnlocked;

  const _RoomConnector({required this.isUnlocked});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 24,
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isUnlocked
            ? const Color(0xFFF1C40F).withValues(alpha: 0.2)
            : const Color(0xFF424242).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Deeper Descent Room Card (NG+)
// ---------------------------------------------------------------------------

class _DeeperDescentRoomCard extends StatelessWidget {
  final GameState gameState;
  final double roomWidth;

  const _DeeperDescentRoomCard({
    required this.gameState,
    required this.roomWidth,
  });

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFFE040FB);
    const borderColor = Color(0xFFAA00FF);
    const bgColor = Color(0x9F1A0018);

    return Container(
      width: roomWidth,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            gameState.initDeeperDescent();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const GameScreen()),
            );
          },
          borderRadius: BorderRadius.circular(12),
          splashColor: accentColor.withValues(alpha: 0.15),
          child: CustomPaint(
            painter: StonePainter(
              bgColor: bgColor,
              borderColor: borderColor,
              crackColor: const Color(0xFFE74C3C).withValues(alpha: 0.4),
              borderRadius: 12,
              borderWidth: 2.5,
              drawCracks: true,
              seed: 99999,
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFE74C3C).withValues(alpha: 0.08),
                    const Color(0xFFE040FB).withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [
                                Color(0xFF3A0022),
                                Color(0xFF0A0014),
                              ],
                            ),
                            border: Border.all(
                              color: const Color(0xFFE74C3C),
                              width: 2.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE74C3C).withValues(alpha: 0.4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Text('🔥', style: TextStyle(fontSize: 20)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DEEPER DESCENT',
                                style: DungeonTheme.getBodyStyle(
                                  14, accentColor, weight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'NG+ • ESCALATED GRIDS',
                                style: GoogleFonts.cinzel(
                                  fontSize: 9,
                                  color: const Color(0xFFE74C3C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'All chambers conquered. The dungeon core awakens — '
                      'larger grids, harsher penalties, greater glory.',
                      style: GoogleFonts.cinzel(
                        fontSize: 9,
                        color: Colors.white54,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Descent Level: ${gameState.deeperDescentLevel}',
                          style: GoogleFonts.cinzel(
                            fontSize: 9,
                            color: accentColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE74C3C).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(0xFFE74C3C).withValues(alpha: 0.6),
                            ),
                          ),
                          child: Text(
                            '⚠️ MISMATCH PENALTY',
                            style: GoogleFonts.cinzel(
                              fontSize: 7,
                              color: const Color(0xFFE74C3C),
                              fontWeight: FontWeight.bold,
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
      ),
    );
  }
}