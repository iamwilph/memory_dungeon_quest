import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/game_state.dart';
import '../models/dungeon_config.dart';
import '../theme/dungeon_theme.dart';
import '../widgets/hud_element.dart';
import '../widgets/torch_overlay.dart';
import '../widgets/ambient_particles.dart';
import 'game_screen.dart';
import 'dungeon_selector_screen.dart';
import 'shop_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the base stone theme for the main menu
    final baseTheme = DungeonTheme.getTheme(DungeonThemeType.stone);
    final gameState = Provider.of<GameState>(context);

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: baseTheme.bgGradient,
            ),
          ),

          // Ambient Particles
          const AmbientParticles(),

          // Torchlight ambience and Vignette
          const TorchOverlay(
            child: SizedBox.expand(),
          ),

          // Portal graphics & Title layout
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40.0),
                  
                  // Rotating Runic Portal Ring
                  const RunicPortalWidget(),
                  
                  const SizedBox(height: 30.0),
                  
                  // Game Logo Header
                  Text(
                    'MEMORY',
                    style: DungeonTheme.getRuneStyle(36.0, baseTheme.primaryColor),
                  ),
                  Text(
                    'DUNGEON',
                    style: DungeonTheme.getTitleStyle(context, const Color(0xFFF1C40F)),
                  ),
                  
                  const SizedBox(height: 10.0),
                  
                  Text(
                    '— MEMORY-MATCHING DUNGEON CRAWLER —',
                    style: DungeonTheme.getBodyStyle(12.0, baseTheme.primaryColor.withValues(alpha:0.7)),
                  ),
                  
                  const SizedBox(height: 50.0),
                  
                  // Action Menu
                  MenuButton(
                    text: gameState.isProgressLoaded ? 'DESCEND' : 'READING SEALS',
                    icon: Icons.double_arrow,
                    onPressed: () {
                      if (!gameState.isProgressLoaded) return;
                      gameState.resumeCampaign();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const GameScreen()),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 16.0),
                  
                  MenuButton(
                    text: 'HOW TO PLAY',
                    icon: Icons.menu_book,
                    onPressed: () {
                      _showHowToPlayDialog(context);
                    },
                  ),
                  
                  const SizedBox(height: 16.0),
                  
                  MenuButton(
                    text: 'CHAMBER MAP',
                    icon: Icons.map,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const DungeonSelectorScreen()),
                      );
                    },
                  ),

                  const SizedBox(height: 16.0),
                  
                  MenuButton(
                    text: 'ARTIFACT MARKET',
                    icon: Icons.store,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ShopScreen()),
                      );
                    },
                  ),

                  const SizedBox(height: 16.0),

                  MenuButton(
                    text: 'RESET CAMPAIGN',
                    icon: Icons.refresh,
                    onPressed: () {
                      _showResetConfirmation(context);
                    },
                  ),
                  
                  const SizedBox(height: 40.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Displays instructions carved in a stone modal panel
  void _showHowToPlayDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha:0.8),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: HudElement(
              borderRadius: 16.0,
              padding: const EdgeInsets.all(24.0),
              seed: 5,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      'SCROLL OF RULES',
                      style: DungeonTheme.getTitleStyle(context, const Color(0xFFF1C40F)),
                    ),
                  ),
                  const Divider(color: Colors.white24, height: 24.0),
                  
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildRuleSection(
                            'Goal',
                            'Explore each dungeon grid, match card pairs to reveal item combinations, and survive traps to descend deeper.',
                          ),
                          _buildRuleSection(
                            'Tile Effects & Matches',
                            'Matching specific tile classes triggers powerful dungeon interactions:',
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 12.0, bottom: 12.0),
                            child: Column(
                              children: [
                                _buildItemRow('🧪 Healing Potion', 'Restores 1 life point (Max 5).'),
                                _buildItemRow('🤢 / 💀 Poison Trap', 'Deducts 1 life point. Avoid matching traps!'),
                                _buildItemRow('🪙 Treasure / Gold', 'Awards coins scaled by level multiplier.'),
                                _buildItemRow('📜 Magic Scroll', 'Adds +1 Hint charge (reveals face-down cards).'),
                                _buildItemRow('💎 Mystical Gem', 'Boosts your score multiplier by +0.5x.'),
                                _buildItemRow('🔑 / 🧱 / 🪓 normal', 'Grants basic exploration points.'),
                              ],
                            ),
                          ),
                          _buildRuleSection(
                            'Health & Lives',
                            'You start with 3 lives. If you run out of lives, you perish in the dungeon. Potion matches heal you.',
                          ),
                          _buildRuleSection(
                            'Chamber Hazards (Penalties)',
                            '• Stone Chamber: Safe. Mismatching cards is harmless.\n'
                            '• Lava, Ice, and Crypt Chambers: Severe. Every mismatch costs 1 Life. Train your memory before proceeding!',
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16.0),
                  
                  Center(
                    child: MenuButton(
                      text: 'CLOSE SCROLL',
                      icon: Icons.close,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRuleSection(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.cinzel(
              fontSize: 14.0,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFF1C40F),
            ),
          ),
          const SizedBox(height: 4.0),
          Text(
            body,
            style: GoogleFonts.cinzel(
              fontSize: 11.5,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(String emoji, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              emoji,
              style: GoogleFonts.cinzel(
                fontSize: 12.0,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: Text(
              description,
              style: GoogleFonts.cinzel(
                fontSize: 11.0,
                color: Colors.white60,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmation(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha:0.85),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: HudElement(
            borderRadius: 12.0,
            padding: const EdgeInsets.all(20.0),
            seed: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'RESET PROGRESS?',
                  style: DungeonTheme.getTitleStyle(context, const Color(0xFFE74C3C)),
                ),
                const SizedBox(height: 12.0),
                Text(
                  'This will lock all deeper chambers (Lava, Ice, Crypt) and clear your inventory. Are you sure you wish to return to the entrance?',
                  textAlign: TextAlign.center,
                  style: DungeonTheme.getBodyStyle(12.0, Colors.white70),
                ),
                const SizedBox(height: 24.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'ABANDON',
                        style: DungeonTheme.getBodyStyle(12.0, Colors.white54),
                      ),
                    ),
                    const SizedBox(width: 20.0),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE74C3C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                      ),
                      onPressed: () {
                        Provider.of<GameState>(context, listen: false).resetGame();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF2C3E50),
                            content: Text(
                              'Campaign progress has been erased. The dungeon seals are restored.',
                              style: DungeonTheme.getBodyStyle(12.0, Colors.white),
                            ),
                          ),
                        );
                      },
                      child: Text(
                        'ERASE SEALS',
                        style: DungeonTheme.getBodyStyle(12.0, Colors.white, weight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Renders a rotating runic ring that spins slowly in the background
class RunicPortalWidget extends StatefulWidget {
  const RunicPortalWidget({super.key});

  @override
  State<RunicPortalWidget> createState() => _RunicPortalWidgetState();
}



class _RunicPortalWidgetState extends State<RunicPortalWidget> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotationController.value * 2 * pi,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0x22F1C40F),
                width: 6.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x11F1C40F),
                  blurRadius: 15,
                  spreadRadius: 3,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0x337F8C8D),
                  width: 2.0,
                ),
              ),
              child: Center(
                child: Text(
                  'ᛗ  ᚦ  ᚠ  ᛋ\nᚱ     ᛞ\nᛒ  ᛖ  ᚺ  ᚾ',
                  textAlign: TextAlign.center,
                  style: DungeonTheme.getRuneStyle(12.0, const Color(0x44F1C40F)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Reusable menu buttons with stone styling and interactive scaling/glows
class MenuButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  const MenuButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onPressed,
    this.color,
  });

  @override
  State<MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<MenuButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.color ?? const Color(0xFFF1C40F);
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _isHovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: 250,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: _isHovered ? activeColor.withValues(alpha:0.2) : Colors.black.withValues(alpha:0.3),
                  blurRadius: _isHovered ? 8.0 : 4.0,
                  offset: const Offset(2, 3),
                ),
              ],
            ),
            child: HudElement(
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
              borderRadius: 6.0,
              drawCracks: _isHovered, // Highlight crack lines on hover
              borderWidth: _isHovered ? 2.0 : 1.5,
              seed: widget.text.hashCode,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.icon,
                    size: 16.0,
                    color: _isHovered ? activeColor : Colors.white70,
                  ),
                  const SizedBox(width: 8.0),
                  Flexible(
                    child: Text(
                      widget.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DungeonTheme.getBodyStyle(
                        12.0, 
                        _isHovered ? activeColor : Colors.white,
                        weight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
