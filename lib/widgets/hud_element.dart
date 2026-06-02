import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../theme/dungeon_theme.dart';
import '../theme/stone_painter.dart';

class HudElement extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsets padding;
  final bool drawCracks;
  final int seed;
  final double borderRadius;
  final double borderWidth;

  const HudElement({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
    this.drawCracks = true,
    this.seed = 0,
    this.borderRadius = 8.0,
    this.borderWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    final gameState = Provider.of<GameState>(context);
    final theme = DungeonTheme.getTheme(gameState.activeDungeon.themeType);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.4),
            offset: const Offset(3, 4),
            blurRadius: 5,
          ),
        ],
      ),
      child: CustomPaint(
        painter: StonePainter(
          bgColor: theme.hudBgColor,
          borderColor: theme.hudBorderColor,
          crackColor: theme.primaryColor,
          borderWidth: borderWidth,
          borderRadius: borderRadius,
          drawCracks: drawCracks,
          seed: seed,
        ),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
