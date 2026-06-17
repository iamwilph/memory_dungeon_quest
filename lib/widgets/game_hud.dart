import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:memory_dungeon/models/dungeon_config.dart';
import 'package:memory_dungeon/models/game_state.dart';
import 'package:memory_dungeon/services/audio_service.dart';
import 'package:memory_dungeon/theme/dungeon_theme.dart';
import 'package:memory_dungeon/widgets/hud_element.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  GameHud — now StatefulWidget so it can self-animate on effect events
// ─────────────────────────────────────────────────────────────────────────────

class GameHud extends StatefulWidget {
  final BuildContext context;
  final DungeonThemeData theme;

  const GameHud({
    super.key,
    required this.context,
    required this.theme,
  });

  @override
  State<GameHud> createState() => _GameHudState();
}

class _GameHudState extends State<GameHud> with TickerProviderStateMixin {
  // ── Animation controllers ─────────────────────────────────────────────────

  // Hearts: pulse UP (heal) — scale + green glow
  late final AnimationController _heartsGainCtrl;
  late final Animation<double> _heartsGainScale;

  // Hearts: shake + red flash (lose life)
  late final AnimationController _heartsLoseCtrl;
  late final Animation<double> _heartsLoseShake;
  late final Animation<double> _heartsLoseFlash;

  // Coins: bounce + golden shimmer (treasure / gold earned)
  late final AnimationController _coinsCtrl;
  late final Animation<double> _coinsScale;
  late final Animation<double> _coinsBounce;

  // Multiplier badge: electric pulse (gem)
  late final AnimationController _multCtrl;
  late final Animation<double> _multScale;
  late final Animation<double> _multGlow;

  // ── Score bump (every match) ──────────────────────────────────────────────
  late final AnimationController _scoreCtrl;
  late final Animation<double> _scoreScale;
  late final Animation<Color?> _scoreColor;

  // Floating "+N" label per panel
  String? _coinsDelta;    // e.g. "+3"
  bool _showCoinsDelta = false;
  String? _heartsDelta;   // "+1" or "-1"
  bool _showHeartsDelta = false;
  bool _heartsGainMode = true; // true = gain (green), false = lose (red)

  late GameState _gameState;

  @override
  void initState() {
    super.initState();
    // Fetch once — GameHud owns its own listener, independent of parent rebuilds
    _gameState = Provider.of<GameState>(widget.context, listen: false);

    // ── Hearts gain (heal) ────────────────────────────────────────────────
    _heartsGainCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _heartsGainScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.28), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.28, end: 0.94), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.94, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _heartsGainCtrl, curve: Curves.easeOut));

    // ── Hearts lose (poison / mismatch) ───────────────────────────────────
    _heartsLoseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    // Horizontal shake — mapped to translateX via builder
    _heartsLoseShake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _heartsLoseCtrl, curve: Curves.linear));
    // Red overlay opacity
    _heartsLoseFlash = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.55), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.55, end: 0.0), weight: 80),
    ]).animate(CurvedAnimation(parent: _heartsLoseCtrl, curve: Curves.easeOut));

    // ── Coins (treasure) ──────────────────────────────────────────────────
    _coinsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _coinsScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.90), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.90, end: 1.08), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _coinsCtrl, curve: Curves.easeInOut));
    // Vertical bounce offset (coin emoji "jumps")
    _coinsBounce = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 2.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 2.0, end: -4.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -4.0, end: 0.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _coinsCtrl, curve: Curves.easeOut));

    // ── Multiplier (gem) ──────────────────────────────────────────────────
    _multCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _multScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 0.88), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.12), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _multCtrl, curve: Curves.elasticOut));
    _multGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _multCtrl, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)),
    );

    // ── Score bump ────────────────────────────────────────────────────────
    _scoreCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scoreScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.95), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _scoreCtrl, curve: Curves.easeOut));
    _scoreColor = ColorTween(
      begin: Colors.white,
      end: const Color(0xFFF1C40F),
    ).animate(CurvedAnimation(
      parent: _scoreCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    ));

    _gameState.addListener(_onEffect);
  }

  @override
  void dispose() {
    _gameState.removeListener(_onEffect);
    _heartsGainCtrl.dispose();
    _heartsLoseCtrl.dispose();
    _coinsCtrl.dispose();
    _multCtrl.dispose();
    _scoreCtrl.dispose();
    super.dispose();
  }

  // ── Effect handler ────────────────────────────────────────────────────────

  void _onEffect() {
    if (!mounted) return;
    final effect = _gameState.lastTriggeredEffect;

    switch (effect) {
      // ── Life gained ──────────────────────────────────────────────────────
      case 'heal':
        HapticFeedback.lightImpact();
        setState(() {
          _heartsGainMode = true;
          _heartsDelta = '+1';
          _showHeartsDelta = true;
        });
        _heartsGainCtrl.forward(from: 0.0);
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            setState(() => _showHeartsDelta = false);
            _gameState.clearLastEffect();
          }
        });

      // ── Life lost ────────────────────────────────────────────────────────
      case 'poison':
      case 'mismatch_penalty':
        HapticFeedback.heavyImpact();
        setState(() {
          _heartsGainMode = false;
          _heartsDelta = '-1';
          _showHeartsDelta = true;
        });
        _heartsLoseCtrl.forward(from: 0.0);
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) {
            setState(() => _showHeartsDelta = false);
            _gameState.clearLastEffect();
          }
        });

      // ── Coins / gold earned ───────────────────────────────────────────────
      case 'treasure':
        HapticFeedback.selectionClick();
        final earned = 1 + (_gameState.currentLevel ~/ 5);
        setState(() {
          _coinsDelta = '+$earned';
          _showCoinsDelta = true;
        });
        _coinsCtrl.forward(from: 0.0);
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            setState(() => _showCoinsDelta = false);
            _gameState.clearLastEffect();
          }
        });

      // ── Multiplier up (gem) ───────────────────────────────────────────────
      case 'gem':
      case 'gem_shatter':
        HapticFeedback.lightImpact();
        _multCtrl.forward(from: 0.0);
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) _gameState.clearLastEffect();
        });
    }

    // Bump score panel on every effect that changes the score
    if (effect == 'streak_increment' ||
        effect == 'streak_milestone' ||
        effect == 'heal_overflow' ||
        effect == 'mismatch_penalty') {
      _scoreCtrl.forward(from: 0.0);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final gameState = _gameState;
    final theme = widget.theme;

    return Column(
      children: [
        // ── Top Row ─────────────────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _FleeButton(context: widget.context, theme: theme),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    gameState.activeDungeon.name.toUpperCase(),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: DungeonTheme.getBodyStyle(
                      16.0, theme.accentColor, weight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${gameState.activeDungeon.depth} • ${gameState.levelProgressString}',
                    textAlign: TextAlign.center,
                    style: DungeonTheme.getRuneStyle(14.0, const Color(0xFFF1C40F)),
                  ),
                  if (gameState.isDeeperDescent)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE74C3C).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFFE040FB).withValues(alpha: 0.6),
                        ),
                      ),
                      child: Text(
                        '🔥 DEEPER DESCENT',
                        style: DungeonTheme.getRuneStyle(9.0, const Color(0xFFE040FB)),
                      ),
                    ),
                  if (gameState.activeModifier != LevelModifier.none)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_modifierIcon(gameState.activeModifier),
                                size: 12, color: Colors.redAccent),
                            const SizedBox(width: 4),
                            Text(_modifierName(gameState.activeModifier),
                                style: DungeonTheme.getRuneStyle(10.0, Colors.redAccent)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _MuteButton(context: widget.context, theme: theme),
            const SizedBox(width: 6),
            // ── Animated multiplier badge ──────────────────────────────────
            AnimatedBuilder(
              animation: _multCtrl,
              builder: (_, _) {
                final glowStrength = _multGlow.value * 12.0;
                return Transform.scale(
                  scale: _multScale.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: gameState.scoreMultiplier > 1.0
                            ? const Color(0xFF3498DB)
                            : theme.hudBorderColor.withValues(alpha: 0.5),
                        width: 1,
                      ),
                      boxShadow: _multCtrl.isAnimating
                          ? [
                              BoxShadow(
                                color: const Color(0xFF3498DB).withValues(alpha: _multGlow.value * 0.8),
                                blurRadius: glowStrength,
                                spreadRadius: glowStrength * 0.4,
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.flash_on, size: 12, color: Color(0xFF3498DB)),
                        const SizedBox(width: 2),
                        Text(
                          '${gameState.scoreMultiplier.toStringAsFixed(1)}x',
                          style: DungeonTheme.getBodyStyle(
                            12.0,
                            gameState.scoreMultiplier > 1.0
                                ? const Color(0xFF3498DB)
                                : Colors.white70,
                            weight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),

        const SizedBox(height: 10.0),

        // ── Stats Row ────────────────────────────────────────────────────────
        Row(
          children: [
            // ── Hearts panel — intrinsic width so it hugs content, no gap ─
            IntrinsicWidth(
              child: AnimatedBuilder(
                animation: Listenable.merge([_heartsGainCtrl, _heartsLoseCtrl]),
                builder: (_, child) {
                  final isGain = _heartsGainMode;
                  final shakeOffset = _heartsLoseCtrl.isAnimating ? _heartsLoseShake.value : 0.0;
                  final flashOpacity = _heartsLoseCtrl.isAnimating ? _heartsLoseFlash.value : 0.0;
                  final gainScale = _heartsGainCtrl.isAnimating ? _heartsGainScale.value : 1.0;

                  return Transform.translate(
                    offset: Offset(shakeOffset, 0),
                    child: Transform.scale(
                      scale: gainScale,
                      child: Stack(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: HudElement(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                            seed: 1,
                            child: Stack(
                              children: [
                                // Heart icons — adaptive to prevent overflow
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ...List.generate(
                                      gameState.maxLives > 5 ? 5 : gameState.maxLives,
                                      (index) {
                                        final isFull = index < gameState.lives;
                                        final isMaxed = gameState.lives >= gameState.maxLives;
                                        final isWarning = gameState.lives == 1 || gameState.lives == 2;
                                        final iconSize = gameState.maxLives > 5 ? 14.0 : 18.0;
                                        final hPad = gameState.maxLives > 5 ? 1.5 : 2.0;
                                        Color heartColor;
                                        if (isMaxed) {
                                          heartColor = const Color(0xFFF1C40F);
                                        } else if (isFull) {
                                          heartColor = _heartsGainCtrl.isAnimating
                                              ? Color.lerp(
                                                  const Color(0xFFE74C3C),
                                                  const Color(0xFF2ECC71),
                                                  (_heartsGainScale.value - 1.0).clamp(0.0, 1.0),
                                                )!
                                              : const Color(0xFFE74C3C);
                                        } else if (isWarning) {
                                          heartColor = Colors.white38;
                                        } else {
                                          heartColor = Colors.white24;
                                        }
                                        return Padding(
                                          padding: EdgeInsets.symmetric(horizontal: hPad),
                                          child: Icon(
                                            isFull ? Icons.favorite : Icons.favorite_border,
                                            color: heartColor,
                                            size: iconSize,
                                          ),
                                        );
                                      },
                                    ),
                                    if (gameState.maxLives > 5) ...[
                                      const SizedBox(width: 4),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${gameState.lives}/${gameState.maxLives}',
                                            style: DungeonTheme.getBodyStyle(
                                              11.0,
                                              gameState.lives >= gameState.maxLives
                                                  ? const Color(0xFFF1C40F)
                                                  : Colors.white70,
                                              weight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            'HP',
                                            style: DungeonTheme.getBodyStyle(
                                              8.0,
                                              const Color(0xFF8888AA),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),

                                // Floating delta label ("+1" / "-1")
                                if (_showHeartsDelta)
                                  Positioned.fill(
                                    child: _FloatingDeltaLabel(
                                      text: _heartsDelta ?? '',
                                      color: isGain
                                          ? const Color(0xFF2ECC71)
                                          : const Color(0xFFE74C3C),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          ),

                          // Red damage flash overlay
                          if (flashOpacity > 0)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE74C3C).withValues(alpha: flashOpacity),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(width: 10.0),

            // ── Coins panel ───────────────────────────────────────────────
            Expanded(
              flex: 3,
              child: AnimatedBuilder(
                animation: _coinsCtrl,
                builder: (_, _) {
                  return Transform.scale(
                    scale: _coinsScale.value,
                    child: HudElement(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      seed: 2,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Coin emoji bounces vertically
                              Transform.translate(
                                offset: Offset(0, _coinsBounce.value),
                                child: Text(
                                  '🪙 ',
                                  style: TextStyle(
                                    fontSize: _coinsCtrl.isAnimating ? 16.0 : 14.0,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4.0),
                              Text(
                                '${gameState.coins}',
                                style: DungeonTheme.getBodyStyle(
                                  12.0,
                                  _coinsCtrl.isAnimating
                                      ? Color.lerp(
                                          const Color(0xFFF1C40F),
                                          Colors.white,
                                          (_coinsScale.value - 1.0).clamp(0.0, 1.0),
                                        )!
                                      : const Color(0xFFF1C40F),
                                  weight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          // Floating "+N" delta
                          if (_showCoinsDelta)
                            Positioned.fill(
                              child: _FloatingDeltaLabel(
                                text: _coinsDelta ?? '',
                                color: const Color(0xFFF1C40F),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(width: 10.0),

            // ── Score panel — bumps on every match ────────────────────────
            Expanded(
              flex: 3,
              child: AnimatedBuilder(
                animation: _scoreCtrl,
                builder: (_, _) => Transform.scale(
                  scale: _scoreScale.value,
                  child: HudElement(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    seed: 3,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('SCORE', style: DungeonTheme.getBodyStyle(8.0, theme.primaryColor)),
                        Text(
                          '${gameState.score}',
                          style: DungeonTheme.getBodyStyle(
                            11.0,
                            _scoreColor.value ?? Colors.white,
                            weight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Modifier helpers (moved from old StatelessWidget) ─────────────────────

  IconData _modifierIcon(LevelModifier mod) {
    switch (mod) {
      case LevelModifier.shadow:   return Icons.visibility_off;
      case LevelModifier.timer:    return Icons.timelapse;
      case LevelModifier.swap:     return Icons.shuffle;
      case LevelModifier.sabotage: return Icons.warning_amber_rounded;
      case LevelModifier.none:     break;
    }
    return Icons.error_outline;
  }

  String _modifierName(LevelModifier mod) {
    switch (mod) {
      case LevelModifier.shadow:   return 'SHADOW';
      case LevelModifier.timer:    return 'TIMELIMIT';
      case LevelModifier.swap:     return 'SWAP';
      case LevelModifier.sabotage: return 'SABOTAGE';
      case LevelModifier.none:     break;
    }
    return '';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _FloatingDeltaLabel — the animated "+1" / "-1" / "+3" that floats up and
//  fades out over the HUD panel that changed.
// ─────────────────────────────────────────────────────────────────────────────

class _FloatingDeltaLabel extends StatefulWidget {
  final String text;
  final Color color;

  const _FloatingDeltaLabel({required this.text, required this.color});

  @override
  State<_FloatingDeltaLabel> createState() => _FloatingDeltaLabelState();
}

class _FloatingDeltaLabelState extends State<_FloatingDeltaLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<double> _offsetY;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _offsetY = Tween<double>(begin: 0.0, end: -22.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Transform.translate(
        offset: Offset(0, _offsetY.value),
        child: Opacity(
          opacity: _opacity.value,
          child: Center(
            child: Text(
              widget.text,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: widget.color,
                shadows: [
                  Shadow(
                    color: widget.color.withValues(alpha: 0.8),
                    blurRadius: 8,
                  ),
                  const Shadow(color: Colors.black, blurRadius: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Private sub-widgets (unchanged from original)
// ─────────────────────────────────────────────────────────────────────────────

class _FleeButton extends StatelessWidget {
  final BuildContext context;
  final DungeonThemeData theme;

  const _FleeButton({required this.context, required this.theme});

  @override
  Widget build(BuildContext ctx) {
    return InkWell(
      onTap: () => Navigator.pop(context),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: theme.hudBorderColor.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.exit_to_app, size: 12, color: Colors.white70),
            const SizedBox(width: 4),
            Text(
              'FLEE',
              style: DungeonTheme.getBodyStyle(12.0, Colors.white70, weight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _MuteButton extends StatelessWidget {
  final BuildContext context;
  final DungeonThemeData theme;

  const _MuteButton({required this.context, required this.theme});

  @override
  Widget build(BuildContext ctx) {
    final audio = AudioService();
    return ValueListenableBuilder<bool>(
      valueListenable: audio.mutedValue,
      builder: (context, isMuted, _) {
            return InkWell(
              onTap: () {
                final wasMuted = isMuted;
                audio.setMuted(!isMuted);
                // When un-muting, resume dungeon ambient that was paused
                if (wasMuted && !audio.isMuted) {
                  audio.resumeAmbientIfUnmuted();
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isMuted ? 'Audio unmuted' : 'Audio muted'),
                    duration: const Duration(seconds: 1),
                    backgroundColor: Colors.black.withValues(alpha: 0.6),
                  ),
                );
              },
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: theme.hudBorderColor.withValues(alpha: 0.5)),
            ),
            child: Icon(
              isMuted ? Icons.volume_off : Icons.volume_up,
              size: 14,
              color: isMuted ? Colors.white24 : Colors.white70,
            ),
          ),
        );
      },
    );
  }
}