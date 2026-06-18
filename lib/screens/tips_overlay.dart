import 'package:flutter/material.dart';
import '../models/dungeon_card.dart';
import '../models/dungeon_config.dart';
import '../models/tips_piece_info.dart';
import '../services/tips_state_service.dart';
import '../theme/dungeon_theme.dart';

/// Overlay that introduces the special pieces on a puzzle board.
/// Shows one piece at a time with emoji, name, and description.
/// Navigation: PREV / NEXT  +  START GAME on the last page.
/// A close (×) button in the top-right corner lets the player skip at any time.
class TipsOverlay extends StatefulWidget {
  final String dungeonId;
  final int levelIndex;
  final List<DungeonCard> cards;
  final VoidCallback onStartGame;

  const TipsOverlay({
    super.key,
    required this.dungeonId,
    required this.levelIndex,
    required this.cards,
    required this.onStartGame,
  });

  @override
  State<TipsOverlay> createState() => _TipsOverlayState();
}

class _TipsOverlayState extends State<TipsOverlay>
    with SingleTickerProviderStateMixin {
  late List<TipsPieceInfo> _pieces;
  int _currentIndex = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  // Tracks whether the animation controller was actually initialised.
  // It is NOT initialised when _pieces is empty (overlay skips itself).
  bool _controllerInitialised = false;

  // Guards against double-dismiss (e.g. button tap fires while fade is running).
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _pieces = TipsStateService().getUnseenSpecialPieces(
      widget.dungeonId,
      widget.levelIndex,
      widget.cards,
    );

    // If no unseen special pieces, skip immediately.
    // Defer so we never call notifyListeners() during a build pass.
    if (_pieces.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onStartGame();
      });
      return;
    }

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _controllerInitialised = true;
    _fadeController.forward();
  }

  @override
  void dispose() {
    if (_controllerInitialised) _fadeController.dispose();
    super.dispose();
  }

  // ── navigation ──────────────────────────────────────────────────────────────

  void _goNext() {
    if (_dismissing) return;
    if (_currentIndex >= _pieces.length - 1) {
      _dismiss();
      return;
    }
    _fadeController.reverse().then((_) {
      if (!mounted) return;
      setState(() => _currentIndex++);
      _fadeController.forward();
    });
  }

  void _goPrevious() {
    if (_dismissing || _currentIndex <= 0) return;
    _fadeController.reverse().then((_) {
      if (!mounted) return;
      setState(() => _currentIndex--);
      _fadeController.forward();
    });
  }

  // ── dismiss ─────────────────────────────────────────────────────────────────

  /// Mark all pieces as seen and hand control back to the parent.
  /// Does NOT await any animation — the parent (_GameScreenState) removes this
  /// widget from the tree immediately via setState, which is instant.
  Future<void> _dismiss() async {
    if (_dismissing) return;
    _dismissing = true;

    for (final piece in _pieces) {
      await TipsStateService().markAsSeen(
        widget.dungeonId,
        widget.levelIndex,
        piece.emoji,
      );
    }

    if (mounted) widget.onStartGame();
  }

  // ── build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_pieces.isEmpty) return const SizedBox.shrink();

    final piece = _pieces[_currentIndex];
    final isLastPage = _currentIndex == _pieces.length - 1;

    return Padding(
      // Horizontal margin so the card never reaches the screen edge
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Container(
          decoration: BoxDecoration(
            gradient: DungeonTheme.getTheme(DungeonThemeType.stone).bgGradient,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: piece.cardType == CardType.poison
                  ? const Color(0xFF2ECC71).withValues(alpha: 0.5)
                  : const Color(0xFFE1C40F).withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: FadeTransition(
            opacity: _controllerInitialised
                ? _fadeAnim
                : const AlwaysStoppedAnimation(1.0),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── top bar: dots + close button ──────────────────────────
                  Row(
                    children: [
                      // Page indicator dots (centred in remaining space)
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _pieces.length,
                            (i) => Container(
                              width: 8,
                              height: 8,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == _currentIndex
                                    ? const Color(0xFFF1C40F)
                                    : Colors.white30,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Close (×) button — always visible, skips all tips
                      GestureDetector(
                        onTap: _dismiss,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── emoji ─────────────────────────────────────────────────
                  ScaleTransition(
                    scale: _controllerInitialised
                        ? Tween<double>(begin: 0.8, end: 1.0).animate(
                            CurvedAnimation(
                              parent: _fadeController,
                              curve: Curves.elasticOut,
                            ),
                          )
                        : const AlwaysStoppedAnimation(1.0),
                    child: Text(
                      piece.emoji,
                      style: const TextStyle(fontSize: 56),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── name ──────────────────────────────────────────────────
                  Text(
                    piece.displayName.toUpperCase(),
                    style: DungeonTheme.getRuneStyle(
                      16,
                      piece.cardType == CardType.poison
                          ? const Color(0xFF2ECC71)
                          : const Color(0xFFF1C40F),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── description ───────────────────────────────────────────
                  Text(
                    piece.description,
                    textAlign: TextAlign.center,
                    style: DungeonTheme.getBodyStyle(13, Colors.white70),
                  ),
                  const SizedBox(height: 20),

                  // ── navigation row: [PREV]  [NEXT / START GAME]  [spacer] ─
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left slot: PREV — hidden on first page but takes up
                      // the same space so the centre button doesn't shift.
                      SizedBox(
                        width: 72,
                        child: _currentIndex > 0
                            ? TextButton(
                                onPressed: _goPrevious,
                                child: Text(
                                  '← PREV',
                                  style: DungeonTheme.getBodyStyle(
                                    11,
                                    Colors.white54,
                                  ),
                                ),
                              )
                            : null,
                      ),

                      // Centre: primary action
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF1C40F),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: isLastPage ? _dismiss : _goNext,
                        child: Text(
                          isLastPage ? 'START GAME' : 'NEXT',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),

                      // Right slot: mirror of left so centre stays centred
                      const SizedBox(width: 72),
                    ],
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