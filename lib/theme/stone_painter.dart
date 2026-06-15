import 'package:flutter/material.dart';

class StonePainter extends CustomPainter {
  final Color bgColor;
  final Color borderColor;
  final Color crackColor;
  final double borderWidth;
  final double borderRadius;
  final bool drawCracks;
  final int seed;
  final Color? themeAccent; // Optional theme accent to tint the cracks
  final String? cardBackStyle; // Dungeon theme name for card back rune pattern (e.g., 'stone', 'lava', 'ice')

  StonePainter({
    required this.bgColor,
    required this.borderColor,
    required this.crackColor,
    this.borderWidth = 2.0,
    this.borderRadius = 8.0,
    this.drawCracks = true,
    this.seed = 0,
    this.themeAccent, // optional - tints cracks with dungeon color
    this.cardBackStyle, // optional - card back rune style
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // Use theme accent for cracks if provided
    final effectiveCrackColor = themeAccent ?? crackColor;

    // 1. Draw solid stone background
    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, bgPaint);

    // 2. Draw subtle stone texture noise (noise lines or speckles)
    final texturePaint = Paint()
      ..color = Colors.black.withValues(alpha:0.04)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    // Draw horizontal texture grains
    final grainCount = (size.height / 12).round();
    for (int i = 0; i < grainCount; i++) {
      final y = (i + 1) * 12.0;
      final startX = (i % 2 == 0) ? 5.0 : 15.0;
      final endX = size.width - ((i % 3 == 0) ? 5.0 : 15.0);
      canvas.drawLine(
        Offset(startX, y),
        Offset(endX, y),
        texturePaint,
      );
    }

    // 3. Draw Jagged Cracks if enabled
    if (drawCracks) {
      final crackPaint = Paint()
        ..color = effectiveCrackColor.withValues(alpha:0.4)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final crackHighlightPaint = Paint()
        ..color = Colors.white.withValues(alpha:0.07)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      // Define static jagged cracks based on the seed
      if (seed % 2 == 0) {
        // Crack 1: Top-left branching down
        final path = Path()
          ..moveTo(size.width * 0.15, 0)
          ..lineTo(size.width * 0.20, size.height * 0.18)
          ..lineTo(size.width * 0.12, size.height * 0.32)
          ..lineTo(size.width * 0.25, size.height * 0.45);
        
        canvas.drawPath(path, crackPaint);
        // Offset highlight for 3D depth
        final highlightPath = Path()
          ..moveTo(size.width * 0.15 + 1.0, 1.0)
          ..lineTo(size.width * 0.20 + 1.0, size.height * 0.18 + 1.0)
          ..lineTo(size.width * 0.12 + 1.0, size.height * 0.32 + 1.0)
          ..lineTo(size.width * 0.25 + 1.0, size.height * 0.45 + 1.0);
        canvas.drawPath(highlightPath, crackHighlightPaint);
      }

      if (seed % 3 == 0 || seed == 0) {
        // Crack 2: Bottom-right branching up
        final path = Path()
          ..moveTo(size.width, size.height * 0.8)
          ..lineTo(size.width * 0.82, size.height * 0.72)
          ..lineTo(size.width * 0.88, size.height * 0.58)
          ..lineTo(size.width * 0.75, size.height * 0.40);
        
        canvas.drawPath(path, crackPaint);
        
        final highlightPath = Path()
          ..moveTo(size.width + 1.0, size.height * 0.8 + 1.0)
          ..lineTo(size.width * 0.82 + 1.0, size.height * 0.72 + 1.0)
          ..lineTo(size.width * 0.88 + 1.0, size.height * 0.58 + 1.0)
          ..lineTo(size.width * 0.75 + 1.0, size.height * 0.40 + 1.0);
        canvas.drawPath(highlightPath, crackHighlightPaint);
      }
    }

    // 4. Draw 3D Bevel Highlights and Shadows
    // Lighter highlight on top/left edges
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha:0.12)
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha:0.5)
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke;

    // Draw top-left highlight
    final highlightPath = Path()
      ..moveTo(borderWidth, size.height - borderRadius)
      ..quadraticBezierTo(borderWidth, borderWidth, borderRadius, borderWidth)
      ..lineTo(size.width - borderRadius, borderWidth);
    canvas.drawPath(highlightPath, highlightPaint);

    // Draw bottom-right shadow
    final shadowPath = Path()
      ..moveTo(size.width - borderRadius, size.height - borderWidth)
      ..quadraticBezierTo(size.width - borderWidth, size.height - borderWidth, size.width - borderWidth, size.height - borderRadius)
      ..lineTo(size.width - borderWidth, borderRadius);
    canvas.drawPath(shadowPath, shadowPaint);

    // 5. Draw primary outer border
    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(rrect, borderPaint);

    // 6. Draw card back rune pattern (if cardBackStyle is set)
    if (cardBackStyle != null) {
      _drawCardBackRune(canvas, size, cardBackStyle!);
    }
  }

  /// Draws a dungeon-themed rune in the center of the card back
  void _drawCardBackRune(Canvas canvas, Size size, String style) {
    final center = Offset(size.width / 2, size.height / 2);

    // Subtle circle behind rune
    final circlePaint = Paint()
      ..color = const Color(0xFF1A272F).withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, size.width * 0.2, circlePaint);

    // Rune character based on dungeon style
    String rune;
    switch (style) {
      case 'lava': rune = 'ᛏ'; break; // Teiwaz (Tyr's sword)
      case 'ice': rune = 'ᚠ'; break; // Fehu (frost/wealth)
      case 'crypt': rune = 'ᚦ'; break; // Thurisaz (giant/door)
      case 'voidChamber': rune = 'ᛗ'; break; // Mannaz (humanity void)
      case 'forest': rune = 'ᛚ'; break; // Laguz (flow/nature)
      default: rune = 'ᛊ'; break; // Sowulo (sun/victory) — stone
    }

    final runeStyle = TextStyle(
      fontSize: size.width * 0.12,
      color: const Color(0xFFF1C40F).withValues(alpha: 0.3),
      fontFamily: 'Cinzel',
    );

    final textSpan = TextSpan(text: rune, style: runeStyle);
    final tp = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant StonePainter oldDelegate) {
    return oldDelegate.bgColor != bgColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.crackColor != crackColor ||
        oldDelegate.themeAccent != themeAccent ||
        oldDelegate.cardBackStyle != cardBackStyle ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.drawCracks != drawCracks ||
        oldDelegate.seed != seed;
  }
}
