// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../models/dungeon_config.dart'; // For DungeonThemeType
import '../theme/dungeon_theme.dart';
import '../widgets/hud_element.dart';
import '../shared/widgets/error_boundary.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = Provider.of<GameState>(context);
    final theme = DungeonTheme.getTheme(DungeonThemeType.stone);

    return ErrorBoundary(
      child: (context) => Scaffold(
        body: Stack(
          children: [
            Container(decoration: BoxDecoration(gradient: theme.bgGradient)),

            // Torchlight & Vignette overlay
            Container(color: Colors.black.withValues(alpha: 0.1)),

            // Main Content
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Header with back button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(
                                  0xFF5A6B7C,
                                ).withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.arrow_back,
                                  size: 14,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'RETURN',
                                  style: DungeonTheme.getBodyStyle(
                                    11,
                                    Colors.white70,
                                    weight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Text(
                          'ARTIFACT MARKET',
                          style: DungeonTheme.getRuneStyle(
                            18.0,
                            const Color(0xFFF1C40F),
                          ),
                        ),
                        SizedBox(width: 60),
                      ],
                    ),

                    const SizedBox(height: 16.0),

                    // Lifetime Coins Display
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.yellow.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFF1C40F).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.stars,
                              size: 20,
                              color: Color(0xFFF1C40F),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${gameState.totalCoins} coins',
                              style: DungeonTheme.getRuneStyle(
                                16.0,
                                const Color(0xFFF1C40F),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16.0),

                    // Artifact Grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.85,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: GameState.artifactsCatalogue.keys.length,
                      itemBuilder: (context, index) {
                        final artifactId = GameState.artifactsCatalogue.keys
                            .toList()[index];
                        final def = GameState.artifactsCatalogue[artifactId]!;
                        final isOwned = gameState.unlockedArtifacts.contains(
                          artifactId,
                        );
                        final price = GameState.artifactPrices[artifactId] ?? 0;
                        final icon = GameState.artifactIcons[artifactId] ?? '📦';

                        return ShopArtifactCard(
                          icon: icon,
                          name: def.displayName,
                          description: def.displayDescription,
                          isOwned: isOwned,
                          price: price,
                          canAfford: gameState.canAffordArtifact(artifactId),
                          onPurchase: () {
                            final success = gameState.tryPurchaseArtifact(
                              artifactId,
                            );
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFF27AE60),
                                  content: Text(
                                    'Acquired "${def.displayName}"!',
                                    style: DungeonTheme.getBodyStyle(
                                      12.0,
                                      Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFFE74C3C),
                                  content: Text(
                                    'Not enough coins or already owned.',
                                    style: DungeonTheme.getBodyStyle(
                                      12.0,
                                      Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 16.0),

                    // Back button at bottom
                    Center(
                      child: MenuButton(
                        text: 'EXIT MARKET',
                        icon: Icons.exit_to_app,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),

                    const SizedBox(height: 16.0),
                  ],
                ),
              ),
            ),

            // Dim overlay for owned items (visual flair)
            if (gameState.unlockedArtifacts.isNotEmpty)
              Container(color: Colors.black.withValues(alpha: 0.05)),
          ],
        ),
      ),
    );
  }
}

/// Shop artifact card component
class ShopArtifactCard extends StatelessWidget {
  final String icon;
  final String name;
  final String description;
  final bool isOwned;
  final int price;
  final bool canAfford;
  final VoidCallback onPurchase;

  const ShopArtifactCard({
    super.key,
    required this.icon,
    required this.name,
    required this.description,
    required this.isOwned,
    required this.price,
    required this.canAfford,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isOwned ? null : onPurchase,
      child: HudElement(
        padding: const EdgeInsets.all(12.0),
        borderRadius: 8.0,
        seed: name.hashCode + (isOwned ? 999 : 0),
        borderWidth: isOwned ? 1.5 : (canAfford ? 2.0 : 1.0),
        borderColor: isOwned
            ? Colors.green.withValues(alpha: 0.5)
            : canAfford
            ? const Color(0xFF3498DB)
            : Colors.white24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon area
            Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOwned
                      ? Colors.green.withValues(alpha: 0.2)
                      : const Color(0xFF3498DB).withValues(alpha: 0.2),
                ),
                child: Center(
                  child: Text(
                    icon,
                    style: const TextStyle(fontSize: 32.0),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),

            const Spacer(),

            // Name
            Text(
              name,
              style: DungeonTheme.getShopTitleStyle(
                context,
                isOwned ? Colors.greenAccent : const Color(0xFFF1C40F),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 4.0),

            // Description
            Text(
              description,
              style: DungeonTheme.getBodyStyle(10.0, Colors.white),
              textAlign: TextAlign.center,
            ),

            const Spacer(),

            // Price / Owned badge
            Center(
              child: isOwned
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'OWNED',
                        style: DungeonTheme.getBodyStyle(
                          10.0,
                          Colors.greenAccent,
                          weight: FontWeight.bold,
                        ),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: canAfford
                            ? const Color(0xFFF1C40F).withValues(alpha: 0.2)
                            : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.stars,
                            size: 12,
                            color: Color(0xFFF1C40F),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$price',
                            style: DungeonTheme.getBodyStyle(
                              10.0,
                              canAfford
                                  ? const Color(0xFFF1C40F)
                                  : Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable menu button with stone styling and interactive scaling/glows
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: _isHovered
                        ? activeColor.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.3),
                    blurRadius: _isHovered ? 8.0 : 4.0,
                    offset: const Offset(2, 3),
                  ),
                ],
              ),
              child: HudElement(
                padding: const EdgeInsets.symmetric(
                  vertical: 10.0,
                  horizontal: 8.0,
                ),
                borderRadius: 6.0,
                drawCracks: _isHovered,
                borderWidth: _isHovered ? 2.0 : 1.5,
                seed: widget.text.hashCode,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.icon,
                      size: 14.0,
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
      ),
    );
  }
}
