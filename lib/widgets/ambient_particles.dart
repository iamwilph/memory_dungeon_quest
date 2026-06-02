import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../models/dungeon_config.dart';
import '../theme/dungeon_theme.dart';

class DungeonParticle {
  double x; // Normalized 0.0 to 1.0
  double y; // Normalized 0.0 to 1.0
  double vx; // Speed x
  double vy; // Speed y
  double size; // Pixel size
  double opacity;
  double life; // 0.0 to 1.0
  double decaySpeed;
  double waveOffset;

  DungeonParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.opacity,
    required this.life,
    required this.decaySpeed,
    required this.waveOffset,
  });
}

class AmbientParticles extends StatefulWidget {
  const AmbientParticles({super.key});

  @override
  State<AmbientParticles> createState() => _AmbientParticlesState();
}

class _AmbientParticlesState extends State<AmbientParticles>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  final List<DungeonParticle> _particles = [];
  final Random _random = Random();
  double _time = 0.0;
  DungeonThemeType? _currentThemeType;

  @override
  void initState() {
    super.initState();
    // Use a Ticker to run logic every frame
    _ticker = createTicker(_updateParticles)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _updateParticles(Duration elapsed) {
    if (!mounted) return;

    // Determine active theme
    final gameState = Provider.of<GameState>(context, listen: false);
    final themeType = gameState.activeDungeon.themeType;

    // Reset particles if the dungeon theme changes
    if (_currentThemeType != themeType) {
      _particles.clear();
      _currentThemeType = themeType;
    }

    final dt = 0.016; // Approx 60 FPS
    _time += dt;

    setState(() {
      // 1. Update and decay existing particles
      for (int i = _particles.length - 1; i >= 0; i--) {
        final p = _particles[i];
        p.life -= p.decaySpeed * dt;

        if (p.life <= 0) {
          _particles.removeAt(i);
          continue;
        }

        // Apply custom movement physics based on theme
        switch (themeType) {
          case DungeonThemeType.stone:
            // Slow drifting dust
            p.x += p.vx * dt;
            p.y += p.vy * dt;
            // Bound wrapping
            if (p.x < 0) p.x = 1.0;
            if (p.x > 1.0) p.x = 0.0;
            if (p.y < 0) p.y = 1.0;
            if (p.y > 1.0) p.y = 0.0;
            break;

          case DungeonThemeType.lava:
            // Rising embers, floating left-to-right via sine wave
            p.y += p.vy * dt;
            p.x += (p.vx + sin(_time * 2 + p.waveOffset) * 0.06) * dt;
            break;

          case DungeonThemeType.ice:
            // Falling snow, swaying left-to-right
            p.y += p.vy * dt;
            p.x += (p.vx + sin(_time * 1.5 + p.waveOffset) * 0.08) * dt;
            break;

          case DungeonThemeType.forest:
            // Natural breezy leaves - similar to stone but slower
            p.x += (p.vx * 0.5) * dt;
            p.y += (p.vy * 0.5) * dt;
            if (p.x < 0) p.x = 1.0;
            if (p.x > 1.0) p.x = 0.0;
            if (p.y < 0) p.y = 1.0;
            if (p.y > 1.0) p.y = 0.0;
            break;

          case DungeonThemeType.crypt:
            // Ghostly fog expansion
            p.x += p.vx * dt;
            p.y += p.vy * dt;
            p.size += 5.0 * dt; // Fog expands
            break;

          case DungeonThemeType.voidChamber:
            // Cosmic drifting stars with gentle orbital sway
            p.x += (p.vx + sin(_time * 0.8 + p.waveOffset) * 0.03) * dt;
            p.y += (p.vy + cos(_time * 0.6 + p.waveOffset) * 0.03) * dt;
            // Twinkling: modulate opacity
            p.opacity =
                (0.3 + 0.7 * ((sin(_time * 3.0 + p.waveOffset) + 1.0) / 2.0))
                    .clamp(0.0, 1.0);
            break;
        }
      }

      // 2. Spawn new particles up to a maximum count
      final maxParticles = themeType == DungeonThemeType.crypt
          ? 12
          : themeType == DungeonThemeType.voidChamber
          ? 40
          : 30;
      if (_particles.length < maxParticles && _random.nextDouble() < 0.15) {
        _spawnParticle(themeType);
      }
    });
  }

  void _spawnParticle(DungeonThemeType themeType) {
    double x = 0.0;
    double y = 0.0;
    double vx = 0.0;
    double vy = 0.0;
    double size = 0.0;
    double opacity = 0.0;
    double decaySpeed = 0.0;

    switch (themeType) {
      case DungeonThemeType.stone:
        x = _random.nextDouble();
        y = _random.nextDouble();
        vx = (_random.nextDouble() * 0.04) - 0.02;
        vy = (_random.nextDouble() * 0.04) - 0.02;
        size = _random.nextDouble() * 3.0 + 1.5;
        opacity = _random.nextDouble() * 0.3 + 0.1;
        decaySpeed = _random.nextDouble() * 0.05 + 0.02; // Long life
        break;

      case DungeonThemeType.lava:
        // Spawn at bottom
        x = _random.nextDouble();
        y = 1.05;
        vx = (_random.nextDouble() * 0.02) - 0.01;
        vy = -(_random.nextDouble() * 0.15 + 0.08); // Rise up
        size = _random.nextDouble() * 4.0 + 2.0;
        opacity = _random.nextDouble() * 0.6 + 0.4;
        decaySpeed = _random.nextDouble() * 0.2 + 0.15;
        break;

      case DungeonThemeType.ice:
        // Spawn at top
        x = _random.nextDouble();
        y = -0.05;
        vx = (_random.nextDouble() * 0.02) - 0.01;
        vy = _random.nextDouble() * 0.12 + 0.06; // Fall down
        size = _random.nextDouble() * 4.0 + 2.0;
        opacity = _random.nextDouble() * 0.7 + 0.3;
        decaySpeed = _random.nextDouble() * 0.18 + 0.12;
        break;

      case DungeonThemeType.crypt:
        // Spawn anywhere (large wisps of purple mist)
        x = _random.nextDouble();
        y = _random.nextDouble();
        vx = (_random.nextDouble() * 0.02) - 0.01;
        vy = (_random.nextDouble() * 0.02) - 0.01;
        size = _random.nextDouble() * 20.0 + 15.0; // Big wisps
        opacity = _random.nextDouble() * 0.08 + 0.02; // Very faint
        decaySpeed = _random.nextDouble() * 0.25 + 0.15;
        break;

      case DungeonThemeType.voidChamber:
        // Cosmic stars: spawn randomly, drift slowly, twinkle
        x = _random.nextDouble();
        y = _random.nextDouble();
        vx = (_random.nextDouble() * 0.015) - 0.0075;
        vy = (_random.nextDouble() * 0.015) - 0.0075;
        size = _random.nextDouble() * 3.5 + 1.0; // Small stars
        opacity = _random.nextDouble() * 0.6 + 0.3;
        decaySpeed = _random.nextDouble() * 0.03 + 0.01; // Very long life
        break;

      case DungeonThemeType.forest:
        // Steam‑like leaves: small and slowly falling
        x = _random.nextDouble();
        y = -0.05;
        vx = (_random.nextDouble() * 0.02) - 0.01;
        vy = _random.nextDouble() * 0.05 + 0.02;
        size = _random.nextDouble() * 2.0 + 1.0;
        opacity = _random.nextDouble() * 0.2 + 0.1;
        decaySpeed = _random.nextDouble() * 0.04 + 0.02;
        break;
    }

    _particles.add(
      DungeonParticle(
        x: x,
        y: y,
        vx: vx,
        vy: vy,
        size: size,
        opacity: opacity,
        life: 1.0,
        decaySpeed: decaySpeed,
        waveOffset: _random.nextDouble() * 2 * pi,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameState = Provider.of<GameState>(context);
    final theme = DungeonTheme.getTheme(gameState.activeDungeon.themeType);

    return CustomPaint(
      size: Size.infinite,
      painter: ParticlePainter(
        particles: _particles,
        particleColor: theme.particleColor,
        themeType: theme.themeType,
      ),
    );
  }
}

class ParticlePainter extends CustomPainter {
  final List<DungeonParticle> particles;
  final Color particleColor;
  final DungeonThemeType themeType;

  ParticlePainter({
    required this.particles,
    required this.particleColor,
    required this.themeType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // Calculate current opacity scaled by remaining life
      final double currentOpacity = (p.opacity * p.life).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = particleColor.withValues(alpha:currentOpacity)
        ..style = PaintingStyle.fill;

      // Map normalized coordinates (0..1) to actual canvas coordinates
      final screenX = p.x * size.width;
      final screenY = p.y * size.height;

      if (themeType == DungeonThemeType.crypt) {
        // Crypt fog gets blurrier and softer
        final blurPaint = Paint()
          ..color = particleColor.withValues(alpha:currentOpacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 0.3)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(Offset(screenX, screenY), p.size, blurPaint);
      } else if (themeType == DungeonThemeType.ice) {
        // Ice particles are sparkling stars or crystals
        final rectPaint = Paint()
          ..color = particleColor.withValues(alpha:currentOpacity)
          ..style = PaintingStyle.fill;

        // Draw diamond-like crystals by rotating or drawing a square
        final path = Path()
          ..moveTo(screenX, screenY - p.size)
          ..lineTo(screenX + p.size * 0.7, screenY)
          ..lineTo(screenX, screenY + p.size)
          ..lineTo(screenX - p.size * 0.7, screenY)
          ..close();
        canvas.drawPath(path, rectPaint);
      } else if (themeType == DungeonThemeType.voidChamber) {
        // Void particles: glowing star points with soft halo
        // Draw a soft halo
        final haloPaint = Paint()
          ..color = particleColor.withValues(alpha:currentOpacity * 0.3)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 1.5)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(screenX, screenY), p.size * 1.2, haloPaint);

        // Draw bright center point
        final corePaint = Paint()
          ..color = Colors.white.withValues(alpha:currentOpacity * 0.8)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(screenX, screenY), p.size * 0.4, corePaint);
      } else {
        // Standard circle for embers and dust
        canvas.drawCircle(Offset(screenX, screenY), p.size, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) => true;
}
