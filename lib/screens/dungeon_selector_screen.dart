import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/game_state.dart';
import '../models/dungeon_config.dart';
import '../theme/dungeon_theme.dart';
import '../theme/stone_painter.dart';
import '../widgets/torch_overlay.dart';
import '../widgets/ambient_particles.dart';
import 'game_screen.dart';

class DungeonSelectorScreen extends StatelessWidget {
  const DungeonSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = DungeonTheme.getTheme(DungeonThemeType.stone);
    final gameState = Provider.of<GameState>(context);

    return Scaffold(
      body: Stack(
        children: [
          // Background Slate
          Container(
            decoration: BoxDecoration(
              gradient: baseTheme.bgGradient,
            ),
          ),

          // Particle System
          const AmbientParticles(),

          // Torch & Vignette overlay
          const TorchOverlay(
            child: SizedBox.expand(),
          ),

          // Selector Content Layout
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20.0),
                
                // Back to main menu runic button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      _buildBackButton(context),
                    ],
                  ),
                ),
                
                const SizedBox(height: 10.0),
                
                Text(
                  'CHAMBER SELECTION',
                  style: DungeonTheme.getTitleStyle(context, const Color(0xFFF1C40F)),
                ),
                
                Text(
                  'DESCEND DEEPER INTO THE ANCIENT LABYRINTH',
                  style: DungeonTheme.getBodyStyle(9.5, baseTheme.primaryColor.withValues(alpha:0.7)),
                ),
                
                const SizedBox(height: 24.0),
                
                // Scrollable list of dungeon levels
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                    itemCount: DungeonConfig.dungeons.length,
                    itemBuilder: (context, index) {
                      final config = DungeonConfig.dungeons[index];
                      // Unlocked if index <= unlocked index
                      final isUnlocked = index <= gameState.unlockedDungeonIndex;
                      
                      return _buildDungeonCard(context, config, isUnlocked, gameState);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pop(context),
      borderRadius: BorderRadius.circular(4.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: const Color(0x3F1A272F),
          borderRadius: BorderRadius.circular(4.0),
          border: Border.all(color: const Color(0xFF5A6B7C), width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_back, size: 14.0, color: Colors.white70),
            const SizedBox(width: 6.0),
            Text(
              'RETURN',
              style: DungeonTheme.getBodyStyle(11.0, Colors.white70, weight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // Card widget representing individual dungeon
  Widget _buildDungeonCard(
    BuildContext context, 
    DungeonConfig config, 
    bool isUnlocked, 
    GameState gameState,
  ) {
    final cardTheme = DungeonTheme.getTheme(config.themeType);

    final dungeonIndex = DungeonConfig.dungeons.indexWhere(
      (d) => d.id == config.id,
    );
    final highestCleared = dungeonIndex == -1
        ? 0
        : gameState.getHighestClearedLevel(dungeonIndex);
    final progressStr = highestCleared >= DungeonConfig.levelsPerDungeon
        ? 'CHAMBER CLEARED'
        : 'NEXT LEVEL ${highestCleared + 1}/${DungeonConfig.levelsPerDungeon}';

    // Grid size subtitle string
    final gridSizeStr = '${config.cols} × ${config.rows} GRID • ${config.totalPairs} PAIRS';
    
    // Border color based on status
    final borderColor = isUnlocked ? cardTheme.hudBorderColor : const Color(0xFF424242);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Stack(
        children: [
          // The base carved stone slab representing the level
          Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha:0.5),
                  offset: const Offset(4, 5),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isUnlocked
                    ? () {
                        // Initialize states and enter crawling grid screen
                        gameState.initDungeonAtNextUnfinishedLevel(config);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const GameScreen()),
                        );
                      }
                    : null,
                splashColor: cardTheme.accentColor.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(8.0),
                child: CustomPaint(
                  painter: StonePainter(
                    bgColor: isUnlocked ? cardTheme.hudBgColor : const Color(0xFF1E1E22),
                    borderColor: borderColor,
                    crackColor: cardTheme.primaryColor.withValues(alpha:isUnlocked ? 0.3 : 0.05),
                    borderRadius: 8.0,
                    borderWidth: 2.0,
                    drawCracks: isUnlocked,
                    seed: config.name.hashCode,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        // Left Column: Visual Icon & Rune
                        _buildDungeonIcon(config, isUnlocked, cardTheme),
                        
                        const SizedBox(width: 20.0),
                        
                        // Right Column: Details & stats
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                  Text(
                                    config.name.toUpperCase(),
                                    style: DungeonTheme.getBodyStyle(
                                      15.0, 
                                      isUnlocked ? cardTheme.accentColor : const Color(0xFF7F7F7F),
                                      weight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    config.depth,
                                    style: DungeonTheme.getRuneStyle(
                                      10.0, 
                                      isUnlocked ? const Color(0xFFF1C40F) : const Color(0xFF7F7F7F),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4.0),
                              Text(
                                isUnlocked ? '$gridSizeStr • $progressStr' : gridSizeStr,
                                style: GoogleFonts.cinzel(
                                  fontSize: 10.0,
                                  fontWeight: FontWeight.w600,
                                  color: isUnlocked ? Colors.white70 : Colors.white24,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const Divider(color: Colors.white12, height: 16.0),
                              Text(
                                config.description,
                                style: GoogleFonts.cinzel(
                                  fontSize: 10.0,
                                  color: isUnlocked ? Colors.white54 : Colors.white30,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 6.0),
                              // Rewards and mismatch indicators
                              if (isUnlocked)
                                Row(
                                  children: [
                                    Icon(Icons.monetization_on, size: 12.0, color: const Color(0xFFF1C40F)),
                                    const SizedBox(width: 3.0),
                                    Text(
                                      'Reward: +${config.baseRewardCoins}c',
                                      style: TextStyle(fontSize: 9.0, color: const Color(0xFFF1C40F), fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 14.0),
                                    Icon(
                                      config.mismatchPenalty ? Icons.report_problem : Icons.shield,
                                      size: 12.0,
                                      color: config.mismatchPenalty ? const Color(0xFFE74C3C) : const Color(0xFF27AE60),
                                    ),
                                    const SizedBox(width: 3.0),
                                    Text(
                                      config.mismatchPenalty ? 'MISMATCH PENALTY (-1 LIFE)' : 'NO MISMATCH PENALTY',
                                      style: TextStyle(
                                        fontSize: 9.0, 
                                        color: config.mismatchPenalty ? const Color(0xFFE74C3C) : const Color(0xFF27AE60),
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Lock overlay for progress tracking
          if (!isUnlocked)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha:0.55),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha:0.85),
                      borderRadius: BorderRadius.circular(4.0),
                      border: Border.all(color: Colors.white10, width: 1.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock, size: 14.0, color: Color(0xFFE74C3C)),
                        const SizedBox(width: 8.0),
                        Text(
                          'SEALED BY RUNE MAGIC',
                          style: DungeonTheme.getBodyStyle(
                            10.0, 
                            const Color(0xFFE74C3C), 
                            weight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Left circular icon showing primary matching tile representation
  Widget _buildDungeonIcon(DungeonConfig config, bool isUnlocked, DungeonThemeData theme) {
    String representEmoji = '🧱'; // Default
    switch (config.themeType) {
      case DungeonThemeType.stone:
        representEmoji = '🔑';
        break;
      case DungeonThemeType.lava:
        representEmoji = '🌋';
        break;
      case DungeonThemeType.ice:
        representEmoji = '❄️';
        break;
      case DungeonThemeType.crypt:
        representEmoji = '⚰️';
        break;
      case DungeonThemeType.voidChamber:
        representEmoji = '🪐';
        break;
      case DungeonThemeType.forest:
        representEmoji = '🌲';
        break;
    }

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isUnlocked ? theme.cardBackBgColor.withValues(alpha:0.4) : const Color(0xFF151515),
        border: Border.all(
          color: isUnlocked ? theme.hudBorderColor : const Color(0xFF424242),
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        isUnlocked ? representEmoji : '?',
        style: const TextStyle(fontSize: 24.0),
      ),
    );
  }
}
