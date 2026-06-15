import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/game_state.dart';
import '../models/daily_challenge.dart';
import '../models/dungeon_config.dart';
import '../theme/dungeon_theme.dart';
import '../widgets/hud_element.dart';
import '../widgets/torch_overlay.dart';
import '../widgets/ambient_particles.dart';
import 'game_screen.dart';

class DailyChallengeScreen extends StatelessWidget {
  const DailyChallengeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = Provider.of<GameState>(context);
    final todayChallenge = DailyChallenge.getToday();
    
    // Find previous attempts for today
    final todayStr = DailyChallenge.truncateToMidnight(DateTime.now()).toString();
    final todayProgressList = gameState.dailyChallengeHistory.where((h) => h.date == todayStr).toList();
    final DailyChallengeProgress? previousProgress = todayProgressList.isNotEmpty ? todayProgressList.first : null;

    final dungeonTheme = DungeonTheme.getTheme(
      DungeonConfig.dungeons.firstWhere(
        (d) => d.id.startsWith(todayChallenge.dungeonId),
        orElse: () => DungeonConfig.dungeons[0],
      ).themeType,
    );

    final String dayStr = _ordinal(DateTime.now().day);
    final String monthStr = _monthName(DateTime.now().month);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Ambient Background Layer
          Container(
            decoration: BoxDecoration(
              gradient: dungeonTheme.bgGradient,
            ),
          ),

          // 2. Active Particle Layer
          const AmbientParticles(),

          // 3. Flickering Torch Overlay
          const TorchOverlay(
            child: SizedBox.expand(),
          ),

          // 4. Main Panel
          SafeArea(
            child: Column(
              children: [
                // Header row
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _backButton(context),
                      Text(
                        'DAILY TRIAL',
                        style: DungeonTheme.getTitleStyle(context, const Color(0xFFF1C40F)),
                      ),
                      const SizedBox(width: 80), // Spacer
                    ],
                  ),
                ),

                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Date Banner
                            Text(
                              'THE $dayStr OF $monthStr'.toUpperCase(),
                              style: DungeonTheme.getRuneStyle(16.0, dungeonTheme.primaryColor),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12.0),

                            // Main Trial Card
                            HudElement(
                              borderRadius: 16.0,
                              padding: const EdgeInsets.all(24.0),
                              seed: todayChallenge.seed,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Dungeon icon circle
                                  Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: dungeonTheme.cardBackBgColor.withValues(alpha: 0.25),
                                      border: Border.all(
                                        color: dungeonTheme.hudBorderColor,
                                        width: 2.0,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: dungeonTheme.accentColor.withValues(alpha: 0.2),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      todayChallenge.dungeonEmoji,
                                      style: const TextStyle(fontSize: 34.0),
                                    ),
                                  ),
                                  const SizedBox(height: 16.0),

                                  // Chamber Name
                                  Text(
                                    todayChallenge.dungeonName.toUpperCase(),
                                    style: DungeonTheme.getGothicStyle(24.0, dungeonTheme.accentColor, weight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 4.0),
                                  
                                  Text(
                                    'DETERMINISTIC SEED: #${todayChallenge.seed}',
                                    style: DungeonTheme.getBodyStyle(9.0, Colors.white38),
                                    textAlign: TextAlign.center,
                                  ),

                                  const Divider(color: Colors.white12, height: 24.0),

                                  // Core Trial Properties
                                  _propertyRow('GRID SIZE', '${todayChallenge.baseGridSize} PAIRS'),
                                  _propertyRow(
                                    'MODIFIER',
                                    todayChallenge.modifierText.toUpperCase(),
                                    valueColor: todayChallenge.modifiers.first == LevelModifier.none ? Colors.white70 : const Color(0xFFE74C3C),
                                  ),
                                  _propertyRow(
                                    'MISMATCH HAZARD',
                                    todayChallenge.hasMismatchPenalty ? 'CRITICAL (LIVES DEDUCTED)' : 'SAFE (NO DAMAGE)',
                                    valueColor: todayChallenge.hasMismatchPenalty ? const Color(0xFFE74C3C) : const Color(0xFF27AE60),
                                  ),

                                  const Divider(color: Colors.white12, height: 24.0),

                                  // Status section (if already played)
                                  if (previousProgress != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                      decoration: BoxDecoration(
                                        color: previousProgress.isCompleted
                                            ? const Color(0x1F27AE60)
                                            : const Color(0x1FE74C3C),
                                        borderRadius: BorderRadius.circular(8.0),
                                        border: Border.all(
                                          color: previousProgress.isCompleted
                                              ? const Color(0xFF27AE60).withValues(alpha: 0.4)
                                              : const Color(0xFFE74C3C).withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                previousProgress.isCompleted ? Icons.check_circle : Icons.cancel,
                                                color: previousProgress.isCompleted ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
                                                size: 16.0,
                                              ),
                                              const SizedBox(width: 6.0),
                                              Text(
                                                previousProgress.isCompleted ? 'CHALLENGE CLEARED' : 'DUNGEON PERISHED',
                                                style: DungeonTheme.getBodyStyle(
                                                  11.0,
                                                  previousProgress.isCompleted ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
                                                  weight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6.0),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                            children: [
                                              Text(
                                                'SCORE: ${previousProgress.score}',
                                                style: DungeonTheme.getRuneStyle(11.0, Colors.white70),
                                              ),
                                              Text(
                                                'HEARTS LEFT: ${previousProgress.livesRemaining}',
                                                style: DungeonTheme.getBodyStyle(10.0, Colors.white60),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20.0),
                                  ] else ...[
                                    Text(
                                      'A unique tomb generated once per day. Survive to earn +10 bonus coins!',
                                      textAlign: TextAlign.center,
                                      style: DungeonTheme.getBodyStyle(10.5, Colors.white60),
                                    ),
                                    const SizedBox(height: 20.0),
                                  ],

                                  // Descend Button
                                  _actionButton(context, gameState, previousProgress != null),
                                ],
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

  Widget _propertyRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.cinzel(
              fontSize: 10.0,
              color: Colors.white38,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.cinzel(
                fontSize: 11.0,
                color: valueColor ?? Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(BuildContext context, GameState gameState, bool hasPlayed) {
    final text = hasPlayed ? 'RETRY RUN' : 'DESCEND INTO TRIAL';
    final activeColor = hasPlayed ? Colors.orange : const Color(0xFFF1C40F);
    final icon = hasPlayed ? Icons.refresh : Icons.double_arrow;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          // Initialize daily run
          gameState.initDailyLevel(1);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const GameScreen()),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: activeColor.withValues(alpha: 0.2),
                blurRadius: 8.0,
                offset: const Offset(2, 3),
              ),
            ],
          ),
          child: HudElement(
            padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
            borderRadius: 6.0,
            drawCracks: true,
            borderWidth: 2.0,
            seed: 42,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16.0,
                  color: Colors.black,
                ),
                const SizedBox(width: 8.0),
                Text(
                  text,
                  style: DungeonTheme.getBodyStyle(
                    11.5,
                    Colors.black,
                    weight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Formatting helpers
  static String _ordinal(int number) {
    if (number >= 11 && number <= 13) {
      return '${number}TH';
    }
    switch (number % 10) {
      case 1:
        return '${number}ST';
      case 2:
        return '${number}ND';
      case 3:
        return '${number}RD';
      default:
        return '${number}TH';
    }
  }

  static String _monthName(int month) {
    const names = [
      'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
      'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'
    ];
    if (month >= 1 && month <= 12) {
      return names[month - 1];
    }
    return '';
  }
}
