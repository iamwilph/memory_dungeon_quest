import 'package:flutter/material.dart';
import '../models/achievement.dart';
import '../models/dungeon_config.dart';
import '../services/achievement_manager.dart';
import '../theme/dungeon_theme.dart';
import '../theme/stone_painter.dart';
import '../widgets/torch_overlay.dart';
import '../widgets/ambient_particles.dart';
import '../shared/widgets/error_boundary.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ach = AchievementManager();

    return ErrorBoundary(
      child: (context) => Scaffold(
        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: DungeonTheme.getTheme(DungeonThemeType.stone).bgGradient,
              ),
            ),
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
                          'ACHIEVEMENTS',
                          style: DungeonTheme.getAchievementsTitleStyle(context, const Color(0xFFF1C40F)),
                        ),
                        SizedBox(width: 80), // Spacer
                      ],
                    ),
                  ),

                  // Achievement Grid
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.4,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: ach.achievements.length,
                        itemBuilder: (context, index) {
                          final achievement = ach.achievements[index];
                          final progress = ach.getProgress(achievement.id);
                          final isUnlocked = ach.isUnlocked(achievement.id);

                          return _AchievementCard(
                            achievement: achievement,
                            progress: progress,
                            isUnlocked: isUnlocked,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
}

// ---------------------------------------------------------------------------
//  Individual Achievement Card
// ---------------------------------------------------------------------------

class _AchievementCard extends StatelessWidget {
  final Achievement achievement;
  final AchievementProgress? progress;
  final bool isUnlocked;

  const _AchievementCard({
    required this.achievement,
    required this.progress,
    required this.isUnlocked,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DungeonTheme.getTheme(DungeonThemeType.stone);

    return Container(
      decoration: BoxDecoration(
        color: isUnlocked
            ? theme.hudBgColor.withValues(alpha: 0.9)
            : const Color(0xFF1A1A1E).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isUnlocked
              ? (achievement.borderColor ?? Colors.amber).withValues(alpha: 0.6)
              : const Color(0xFF424242).withValues(alpha: 0.3),
          width: isUnlocked ? 1.5 : 1.0,
        ),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: (achievement.borderColor ?? Colors.amber).withValues(alpha: 0.15),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CustomPaint(
          painter: StonePainter(
            bgColor: Colors.transparent,
            borderColor: Colors.transparent,
            crackColor: isUnlocked
                ? (achievement.borderColor ?? Colors.amber).withValues(alpha: 0.1)
                : const Color(0xFF424242).withValues(alpha: 0.05),
            drawCracks: true,
            seed: achievement.id.hashCode + 7,
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isUnlocked
                        ? (achievement.borderColor ?? Colors.amber).withValues(alpha: 0.2)
                        : const Color(0xFF2C3E50),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    achievement.icon,
                    size: 22,
                    color: isUnlocked
                        ? (achievement.borderColor ?? Colors.amber)
                        : Colors.white24,
                  ),
                ),

                const SizedBox(height: 6),

                // Name
                Text(
                  isUnlocked ? achievement.name : '???',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DungeonTheme.getBodyStyle(
                    10,
                    isUnlocked ? Colors.white : Colors.white24,
                    weight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 3),

                // Description (shortened)
                Text(
                  achievement.description,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DungeonTheme.getBodyStyle(8, Colors.white54),
                ),

                // Progress bar (if unlocked or has progress)
                if (isUnlocked || (progress != null && progress!.currentCount > 0))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _ProgressBar(progress: progress),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Progress Bar Widget
// ---------------------------------------------------------------------------

class _ProgressBar extends StatelessWidget {
  final AchievementProgress? progress;

  const _ProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    if (progress == null) return const SizedBox.shrink();

    final ratio = progress!.requirement > 0
        ? (progress!.currentCount / progress!.requirement).clamp(0.0, 1.0)
        : 1.0;

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Container(
              height: 4,
              color: const Color(0xFF2C3E50),
              child: FractionallySizedBox(
                widthFactor: ratio,
                child: Container(
                  color: ratio >= 1.0
                      ? Colors.greenAccent
                      : const Color(0xFFF1C40F),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${progress!.currentCount}/${progress!.requirement}',
          style: DungeonTheme.getBodyStyle(7, Colors.white30),
        ),
      ],
    );
  }
}