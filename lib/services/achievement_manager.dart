import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/achievement.dart';

class AchievementManager {
  static final AchievementManager _instance = AchievementManager._internal();
  factory AchievementManager() => _instance;
  AchievementManager._internal();

  // Define all achievements
  final List<Achievement> achievements = [
    // First-time milestones
    Achievement(
      id: 'first_blood',
      name: 'First Blood',
      description: 'Clear your first level.',
      icon: Icons.stars,
      borderColor: Colors.amber,
    ),
    Achievement(
      id: 'first_dungeon',
      name: 'Dungeon Delver',
      description: 'Clear an entire dungeon.',
      icon: Icons.military_tech,
      borderColor: Colors.amber,
    ),
    Achievement(
      id: 'all_dungeons',
      name: 'Dungeon Master',
      description: 'Clear all 6 dungeons.',
      icon: Icons.workspace_premium,
      borderColor: Colors.amber,
    ),

    // Streak milestones
    Achievement(
      id: 'streak_5',
      name: 'On Fire!',
      description: 'Reach a 5-match streak.',
      icon: Icons.local_fire_department,
      borderColor: Colors.orange,
    ),
    Achievement(
      id: 'streak_10',
      name: 'Unstoppable!',
      description: 'Reach a 10-match streak.',
      icon: Icons.speed,
      borderColor: Colors.red,
    ),
    Achievement(
      id: 'perfect_run',
      name: 'Flawless Victory!',
      description: 'Complete a level with zero mismatches.',
      icon: Icons.emoji_events,
      borderColor: Colors.purple,
    ),

    // Play milestones
    Achievement(
      id: 'gems_100',
      name: 'Gem Hoarder',
      description: 'Match 100 total gem tiles across all runs.',
      icon: Icons.diamond,
      borderColor: Colors.blue,
    ),
    Achievement(
      id: 'scrolls_10',
      name: 'Spell Scholar',
      description: 'Match 10 total magic scrolls across all runs.',
      icon: Icons.auto_stories,
      borderColor: Colors.teal,
    ),
    Achievement(
      id: 'coins_500',
      name: 'Midas Touch',
      description: 'Earn 500 lifetime coins.',
      icon: Icons.monetization_on,
      borderColor: Colors.yellow,
    ),
    Achievement(
      id: 'score_50k',
      name: 'High Roller',
      description: 'Achieve a 50,000 total score across all runs.',
      icon: Icons.emoji_objects,
      borderColor: Colors.pink,
    ),

    // Completionist milestones
    Achievement(
      id: 'hint_20',
      name: 'Helpful Hand',
      description: 'Use 20 hint charges total.',
      icon: Icons.lightbulb,
      borderColor: Colors.yellow,
    ),
    Achievement(
      id: 'lives_0',
      name: 'Death Defier',
      description: 'Clear a level with only 1 life remaining.',
      icon: Icons.favorite,
      borderColor: Colors.red,
    ),
    Achievement(
      id: 'lava_veteran',
      name: 'Lava Walker',
      description: 'Complete all 20 levels of the Lava Chamber.',
      icon: Icons.local_fire_department,
      borderColor: Colors.red,
    ),
    Achievement(
      id: 'crypt_veteran',
      name: 'Crypt Keeper',
      description: 'Complete all 20 levels of the Crypt.',
      icon: Icons.cabin,
      borderColor: Colors.grey,
    ),
  ];

  Map<String, AchievementProgress> _progress = {};
  List<String> unlocked = [];
  // Track notifications already shown to avoid spam
  final Set<String> _notifiedAchievements = {};

  void init() {
    _loadProgress();
  }

  void increment(String achievementId, [int delta = 1]) {
    final existing = _progress[achievementId];

    // Find the achievement definition
    final def = achievements.firstWhere(
      (a) => a.id == achievementId,
      orElse: () => throw Exception('Unknown achievement: $achievementId'),
    );

    final int requirement;
    switch (def.id) {
      case 'gems_100':
        requirement = 100;
        break;
      case 'scrolls_10':
        requirement = 10;
        break;
      case 'coins_500':
        requirement = 500;
        break;
      case 'score_50k':
        requirement = 50000;
        break;
      case 'hint_20':
        requirement = 20;
        break;
      default:
        requirement = 1;
    }

    final int currentCount = (existing?.currentCount ?? 0) + delta;

    _progress[achievementId] = AchievementProgress(
      achievementId: achievementId,
      currentCount: currentCount,
      requirement: requirement,
    );

    // Check if just unlocked
    final wasUnlocked = existing?.isUnlocked ?? false;
    final isNowUnlocked = currentCount >= requirement;

    if (isNowUnlocked && !unlocked.contains(achievementId)) {
      unlocked.add(achievementId);
      // NOTE: Do NOT add to _notifiedAchievements here — let claimNewlyUnlocked
      // handle UI notification so the game screen can show the toast.
      _saveProgress();
    } else if (isNowUnlocked && wasUnlocked) {
      // Already unlocked before, but progress may have updated
      _saveProgress();
    }
  }

  AchievementProgress? getProgress(String achievementId) =>
      _progress[achievementId];

  bool isUnlocked(String achievementId) => unlocked.contains(achievementId);

  List<Achievement> getUnlockedAchievements() {
    return achievements
        .where((a) => unlocked.contains(a.id))
        .toList();
  }

  int get totalUnlocked => unlocked.length;
  int get totalCount => achievements.length;

  Future<void> _loadProgress() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/achievements.json');
      if (!file.existsSync()) return;

      final content = await file.readAsString();
      final data = jsonDecode(content) as List<dynamic>;

      _progress = {};
      for (final entry in data) {
        final progress = AchievementProgress.fromJson(
          Map<String, dynamic>.from(entry as Map),
        );
        _progress[progress.achievementId] = progress;
        if (progress.isUnlocked) {
          unlocked.add(progress.achievementId);
          _notifiedAchievements.add(progress.achievementId);
        }
      }
    } catch (e) {
      // Corrupted file — reset to defaults
      _progress = {};
      unlocked = [];
    }
  }

  Future<void> _saveProgress() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/achievements.json');
      await file.writeAsString(
        jsonEncode(_progress.values.toList()),
        flush: true,
      );
    } catch (e) {
      // Silently fail — progress will be recovered on next load
    }
  }

  void resetAll() async {
    _progress.clear();
    unlocked.clear();
    _notifiedAchievements.clear();
    try {
      final dir = await getApplicationDocumentsDirectory();
      File('${dir.path}/achievements.json').deleteSync();
    } catch (e) {
      // Ignore
    }
  }

  void clearNotifications() {
    _notifiedAchievements.clear();
  }

  Map<String, dynamic> toJson() {
    return {
      'progress': _progress.values.map((p) => p.toJson()).toList(),
      'unlocked': unlocked,
    };
  }

  /// Returns any achievements that were just unlocked since the last call.
  /// Call this periodically (e.g., after level complete) to show toast notifications.
  /// Clears the internal list after returning.
  List<Achievement> claimNewlyUnlocked() {
    final newlyUnlocked = unlocked.where((id) => !_notifiedAchievements.contains(id)).toList();
    for (final id in newlyUnlocked) {
      _notifiedAchievements.add(id);
    }
    return achievements.where((a) => newlyUnlocked.contains(a.id)).toList();
  }

  /// Reset notifications (e.g., when switching screens)
  void resetNotifications() {
    _notifiedAchievements.clear();
  }
}