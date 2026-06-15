import 'package:flutter/material.dart';

class Achievement {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color? borderColor;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.borderColor,
  });
}

class AchievementProgress {
  final String achievementId;
  final int currentCount;
  final int requirement;

  const AchievementProgress({
    required this.achievementId,
    required this.currentCount,
    required this.requirement,
  });

  bool get isUnlocked => currentCount >= requirement;

  AchievementProgress copyWith({int? currentCount, int? requirement}) {
    return AchievementProgress(
      achievementId: achievementId,
      currentCount: currentCount ?? this.currentCount,
      requirement: requirement ?? this.requirement,
    );
  }

  Map<String, Object?> toJson() => {
        'achievementId': achievementId,
        'currentCount': currentCount,
        'requirement': requirement,
      };

  factory AchievementProgress.fromJson(Map<String, dynamic> json) {
    return AchievementProgress(
      achievementId: json['achievementId'] as String,
      currentCount: json['currentCount'] as int? ?? 0,
      requirement: json['requirement'] as int? ?? 1,
    );
  }

  @override
  bool operator ==(Object other) => identical(this, other) ||
      other is AchievementProgress && achievementId == other.achievementId;

  @override
  int get hashCode => achievementId.hashCode;
}