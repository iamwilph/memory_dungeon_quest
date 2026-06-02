import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/dungeon_config.dart';
import '../models/dungeon_card.dart';

class DungeonThemeData {
  final DungeonThemeType themeType;
  final Gradient bgGradient;
  final Color primaryColor;
  final Color accentColor;
  final Color torchColor;
  final Color particleColor;
  final Color hudBgColor;
  final Color hudBorderColor;
  final Color cardBackBgColor;
  final Color cardBackRuneColor;

  const DungeonThemeData({
    required this.themeType,
    required this.bgGradient,
    required this.primaryColor,
    required this.accentColor,
    required this.torchColor,
    required this.particleColor,
    required this.hudBgColor,
    required this.hudBorderColor,
    required this.cardBackBgColor,
    required this.cardBackRuneColor,
  });
}

class DungeonTheme {
  // Glow colors for card borders
  static Color getCardGlowColor(CardType type) {
    switch (type) {
      case CardType.poison:
        return const Color(0xFF2ECC71); // Toxic Green
      case CardType.healing:
        return const Color(0xFFE74C3C); // Ruby Red
      case CardType.treasure:
        return const Color(0xFFF1C40F); // Radiant Gold
      case CardType.scroll:
        return const Color(0xFFE67E22); // Ancient Parchment Orange
      case CardType.gem:
        return const Color(0xFF3498DB); // Sapphire Cyan
      case CardType.normal:
        return const Color(0xFF95A5A6); // Silver Slate
    }
  }

  // Get specific theme config based on DungeonThemeType
  static DungeonThemeData getTheme(DungeonThemeType type) {
    switch (type) {
      case DungeonThemeType.stone:
        return const DungeonThemeData(
          themeType: DungeonThemeType.stone,
          bgGradient: LinearGradient(
            colors: [Color(0xFF2C3E50), Color(0xFF0F141A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          primaryColor: Color(0xFF7F8C8D),
          accentColor: Color(0xFF27AE60), // Moss Green
          torchColor: Color(0xFFE67E22),  // Warm Amber
          particleColor: Color(0x3F95A5A6),
          hudBgColor: Color(0x9F1E272C),
          hudBorderColor: Color(0xFF5A6B7C),
          cardBackBgColor: Color(0xFF34495E),
          cardBackRuneColor: Color(0xFF7F8C8D),
        );
      case DungeonThemeType.lava:
        return const DungeonThemeData(
          themeType: DungeonThemeType.lava,
          bgGradient: LinearGradient(
            colors: [Color(0xFF2C0F0F), Color(0xFF0F0303)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          primaryColor: Color(0xFFE74C3C),
          accentColor: Color(0xFFD35400), // Volcanic Orange
          torchColor: Color(0xFFE25822),  // Flame Red/Orange
          particleColor: Color(0x5FEE5A24),
          hudBgColor: Color(0x9F2E0F0F),
          hudBorderColor: Color(0xFFC0392B),
          cardBackBgColor: Color(0xFF3E1717),
          cardBackRuneColor: Color(0xFFD35400),
        );
      case DungeonThemeType.ice:
        return const DungeonThemeData(
          themeType: DungeonThemeType.ice,
          bgGradient: LinearGradient(
            colors: [Color(0xFF1B4F72), Color(0xFF030D16)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          primaryColor: Color(0xFF3498DB),
          accentColor: Color(0xFF00D2D3), // Glacial Turquoise
          torchColor: Color(0xFF00E5FF),  // Cyan Ice
          particleColor: Color(0x7FCEF6FF),
          hudBgColor: Color(0x9F0F2A3F),
          hudBorderColor: Color(0xFF2980B9),
          cardBackBgColor: Color(0xFF1C3A52),
          cardBackRuneColor: Color(0xFF00D2D3),
        );
      case DungeonThemeType.crypt:
        return const DungeonThemeData(
          themeType: DungeonThemeType.crypt,
          bgGradient: LinearGradient(
            colors: [Color(0xFF1E0B36), Color(0xFF07020F)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          primaryColor: Color(0xFF9B59B6),
          accentColor: Color(0xFF8E44AD), // Dark Magic Violet
          torchColor: Color(0xFF9B59B6),  // Ghastly Purple Flame
          particleColor: Color(0x4FBB86FC),
          hudBgColor: Color(0x9F180A28),
          hudBorderColor: Color(0xFF5E35B1),
          cardBackBgColor: Color(0xFF281145),
          cardBackRuneColor: Color(0xFFBB86FC),
        );
      case DungeonThemeType.forest:
        return const DungeonThemeData(
          themeType: DungeonThemeType.forest,
          bgGradient: LinearGradient(
            colors: [Color(0xFF0A4E23), Color(0xFF03120E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          primaryColor: Color(0xFF1B5E20), // Deep forest green
          accentColor: Color(0xFF66BB6A), // Light emerald
          torchColor: Color(0xFF388E3C), // Dark green torch
          particleColor: Color(0x4FE7F5CB),
          hudBgColor: Color(0x9F192A1E),
          hudBorderColor: Color(0xFF388E3C),
          cardBackBgColor: Color(0xFF2E7D32),
          cardBackRuneColor: Color(0xFF1B5E20),
        );
      case DungeonThemeType.voidChamber:
        return const DungeonThemeData(
          themeType: DungeonThemeType.voidChamber,
          bgGradient: LinearGradient(
            colors: [Color(0xFF0A0014), Color(0xFF020008)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          primaryColor: Color(0xFFE040FB), // Neon Magenta
          accentColor: Color(0xFFD500F9),  // Electric Violet
          torchColor: Color(0xFF7C4DFF),   // Deep Indigo Glow
          particleColor: Color(0x5FE040FB),
          hudBgColor: Color(0x9F0A0018),
          hudBorderColor: Color(0xFFAA00FF),
          cardBackBgColor: Color(0xFF1A0033),
          cardBackRuneColor: Color(0xFFE040FB),
        );
    }
  }

  // Runic & medieval typographic helpers
  static TextStyle getTitleStyle(BuildContext context, Color color) {
    return GoogleFonts.cinzel(
      textStyle: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: color,
        letterSpacing: 2.0,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha:0.8),
            offset: const Offset(2, 2),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }

  static TextStyle getRuneStyle(double size, Color color) {
    return GoogleFonts.uncialAntiqua(
      textStyle: TextStyle(
        fontSize: size,
        color: color,
        shadows: [
          Shadow(
            color: color.withValues(alpha:0.5),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }

  static TextStyle getGothicStyle(double size, Color color, {FontWeight weight = FontWeight.normal}) {
    return GoogleFonts.grenzeGotisch(
      textStyle: TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: 1.2,
      ),
    );
  }

  static TextStyle getBodyStyle(double size, Color color, {FontWeight weight = FontWeight.normal}) {
    return GoogleFonts.cinzel(
      textStyle: TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: 1.0,
      ),
    );
  }
}
