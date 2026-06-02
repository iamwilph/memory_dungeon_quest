import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../models/dungeon_config.dart';
import '../theme/dungeon_theme.dart';

class TorchOverlay extends StatefulWidget {
  final Widget? child;

  const TorchOverlay({super.key, this.child});

  @override
  State<TorchOverlay> createState() => _TorchOverlayState();
}

class _TorchOverlayState extends State<TorchOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;


  @override
  void initState() {
    super.initState();
    // A medium-duration looping animation for the torch flicker
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = Provider.of<GameState>(context);
    final theme = DungeonTheme.getTheme(gameState.activeDungeon.themeType);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Calculate dynamic flicker offset and radius
        final flickerVal = _controller.value;
        
        // Minor high-frequency noise using sinusoids for realistic flame jumpiness
        final timeSeed = DateTime.now().millisecondsSinceEpoch / 150.0;
        final microFlicker = sin(timeSeed) * 0.015 + cos(timeSeed * 0.7) * 0.008;

        final radius = 0.85 + (microFlicker) + (flickerVal * 0.05);
        final opacity = 0.22 + (microFlicker * 0.5) + (flickerVal * 0.04);
        
        // Torch position is centered horizontally but slightly high, like a wall torch
        final Alignment torchCenter = Alignment(
          0.0 + sin(timeSeed * 0.5) * 0.02, 
          -0.5 + cos(timeSeed * 0.4) * 0.02
        );

        // Adjust dark vignette intensity depending on depth
        double edgeDarkness = 0.85;
        if (theme.themeType == DungeonThemeType.crypt) {
          edgeDarkness = 0.95; // Deep crypts are darker
        } else if (theme.themeType == DungeonThemeType.stone) {
          edgeDarkness = 0.75; // Stone chambers are slightly brighter
        } else if (theme.themeType == DungeonThemeType.voidChamber) {
          edgeDarkness = 0.92; // Void is very dark at edges with neon center glow
        }

        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: torchCenter,
              radius: radius,
              colors: [
                theme.torchColor.withValues(alpha:opacity),
                theme.torchColor.withValues(alpha:opacity * 0.4),
                Colors.black.withValues(alpha:edgeDarkness * 0.5),
                Colors.black.withValues(alpha:edgeDarkness),
              ],
              stops: const [0.0, 0.35, 0.7, 1.0],
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}
