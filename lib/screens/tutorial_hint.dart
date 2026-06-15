import 'package:flutter/material.dart';
import '../theme/dungeon_theme.dart';
import '../models/dungeon_config.dart';

/// Interactive tutorial shown on first launch.
/// 3 steps: flip, match, clear.
class TutorialOverlay extends StatefulWidget {
  const TutorialOverlay({super.key});

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  int _step = 0;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnim;

  final List<_TutorialStep> _steps = [
    _TutorialStep(
      icon: Icons.touch_app,
      title: 'TOUCH THE RUNES',
      body:
          'Tap any card to flip it. Find matching pairs of symbols to clear the chamber.',
      highlightCardIndex: 0,
    ),
    _TutorialStep(
      icon: Icons.sync,
      title: 'MATCH PAIRS',
      body:
          'Flip two cards with the same emoji to remove them. Watch out for poison (💀) — it costs a life!',
      highlightCardIndex: 1,
    ),
    _TutorialStep(
      icon: Icons.emoji_events,
      title: 'CLEAR THE CHAMBER',
      body:
          'Match all pairs to complete the level. Earn coins and climb deeper into the dungeon.',
      highlightCardIndex: -1, // No card highlight on step 3
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _scaleAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_step < _steps.length - 1) {
      setState(() => _step++);
    } else {
      // Tutorial complete
      _saveTutorialSeen();
      Navigator.of(context).pop(true);
    }
  }

  // In-memory save — no async gap with context.
  void _saveTutorialSeen() {
    _prefsInstance.setBoolSync('tutorialSeen', true);
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_step];

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            gradient: DungeonTheme.getTheme(DungeonThemeType.forest).bgGradient,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE1C40F).withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Step indicator dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _steps.length,
                    (i) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _step
                            ? const Color(0xFFF1C40F)
                            : Colors.white30,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Icon
                ScaleTransition(
                  scale: _scaleAnim,
                  child: Icon(
                    step.icon,
                    size: 48,
                    color: const Color(0xFFF1C40F),
                  ),
                ),
                const SizedBox(height: 12),

                // Title
                Text(
                  step.title,
                  style: DungeonTheme.getRuneStyle(18, const Color(0xFFF1C40F)),
                ),
                const SizedBox(height: 8),

                // Body
                Text(
                  step.body,
                  textAlign: TextAlign.center,
                  style: DungeonTheme.getBodyStyle(13, Colors.white70),
                ),
                const SizedBox(height: 20),

                // Skip / Next buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        _saveTutorialSeen();
                        Navigator.of(context).pop(true);
                      },
                      child: Text(
                        'SKIP',
                        style: DungeonTheme.getBodyStyle(11, Colors.white54),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF1C40F),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _nextStep,
                      child: Text(
                        _step < _steps.length - 1 ? 'NEXT' : 'BEGIN',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TutorialStep {
  final IconData icon;
  final String title;
  final String body;
  final int highlightCardIndex; // -1 = no highlight
  const _TutorialStep({
    required this.icon,
    required this.title,
    required this.body,
    required this.highlightCardIndex,
  });
}

// ---------------------------------------------------------------------------
//  Lightweight prefs wrapper (works on both IO and Web)
// ---------------------------------------------------------------------------

// In-memory backing for the tutorial flag.
// On real devices this would use shared_preferences.
final _prefsInstance = _InMemoryPrefs();

class _InMemoryPrefs {
  final Map<String, dynamic> _data = {};

  void setBoolSync(String key, bool value) {
    _data[key] = value;
  }

  Future<bool> setBool(String key, bool value) async {
    _data[key] = value;
    return true;
  }

  bool getBool(String key, {bool def = false}) => _data[key] as bool? ?? def;

  Future<void> clear() async {
    _data.clear();
  }
}

/// Check if the tutorial has been shown before.
bool hasTutorialBeenSeen() => _prefsInstance.getBool('tutorialSeen');

/// Show the tutorial if it hasn't been seen yet.
void showTutorialIfNeeded(BuildContext context) {
  return;
  // if (hasTutorialBeenSeen()) return;
  // showDialog(
  //   context: context,
  //   barrierDismissible: false,
  //   builder: (_) => const TutorialOverlay(),
  // );
}