# Fix: GameHud Streak Info Causing Puzzle Board Resize

**Created:** 2026-06-15T14:30:00Z
**Status:** Draft — awaiting approval
**Files:** `lib/widgets/game_hud.dart`, `lib/screens/game_screen.dart`, `lib/models/game_state.dart`

---

## Problem Analysis

### Root Cause

The `GameHud` widget is used inside a `Column` (in `game_screen.dart`) that contains four children:

1. `GameHud` — **no flex**, takes its natural height
2. `_StreakBrokenOverlay` — conditional (already exists)
3. `_buildCardGrid` — wrapped in `Expanded`
4. `_buildBottomActions` — fixed height

The `GameHud`'s middle section uses an `Expanded` column that stacks:
- Dungeon name (1 line)
- Depth + progress (1 line)
- "DEEPER DESCENT" badge (optional, 1 line)
- **Wrap with modifier + streak badges** (optional, 1+ lines)

When `streakCount > 0`, the streak badge appears. When both a modifier badge AND a streak badge are present, the `Wrap` widget reflows them onto a **second line**. This adds extra vertical height to the HUD.

Since the HUD is **not flexed** (no `Expanded`/`Flexible`), it takes its natural size. The card grid is in `Expanded`, so it gets **whatever space is left**. When the HUD grows taller (extra badge lines), the grid shrinks — cards become smaller, potentially unplayable on narrow screens.

### Evidence

From `game_screen.dart` (lines 180-221):
```dart
SafeArea(
  child: Column(
    children: [
      const SizedBox(height: 12.0),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: GameHud(...),  // <-- NO Expanded — grows naturally
      ),
      // ... streak overlay (conditional) ...
      const SizedBox(height: 12.0),
      Expanded(                         // <-- takes remaining space
        child: _buildCardGrid(...),
      ),
      Padding(...),  // bottom actions
    ],
  ),
),
```

From `game_hud.dart` (lines 119-215):
```dart
// When modifier + streak are both active, Wrap adds a 2nd line:
Wrap(
  alignment: WrapAlignment.center,
  spacing: 6,
  runSpacing: 4,
  children: [
    modifierBadge,   // line 1
    streakBadge,     // line 2 (when both present, wraps!)
  ],
),
```

### Layout Flow

```
Screen height = H
HUD height = H_hud (natural, variable — 2 to 4 lines)
Bottom actions height = H_bottom (fixed ~60px)
SafeArea insets = H_insets (~44px top + ~24px bottom)

Grid available height = H - H_insets - H_hud - H_bottom - 24

When streak appears: H_hud increases by ~30-40px
→ Grid height decreases by ~30-40px
→ Card cells shrink (cellWidth/Height both decrease)
```

---

## Chosen Approach: Animated Streak Counter Overlay on Card Grid

Instead of embedding streak info in the HUD (which causes variable height), show a **brief animated overlay centered on the card grid** every time the streak count changes. This:

1. **Removes the streak badge from the HUD entirely** → HUD stays at fixed height
2. **Makes streak building feel rewarding** — visual feedback on every match
3. **Gives full control over animation** — scale, fade, color, duration
4. **Uses existing infrastructure** — `_StreakBrokenOverlay` and `_StreakMilestoneOverlay` already exist

### What Already Exists

From `game_screen.dart`:

- **`_StreakBrokenOverlay`** (lines 1256-1294): Shows "Streak Broken!" with red text, fades up and out over 1s
- **`_StreakMilestoneOverlay`** (lines 1297-1340+): Shows streak count (3, 6, 9) with golden animation over 800ms

Both are triggered by `gameState.lastTriggeredEffect` being `'streak_broken'` or `'streak_milestone'`. They're already centered on screen.

**Gap:** No overlay fires on *every* streak increment (1, 2, 4, 5, 7, 8, etc.). The streak badge in the HUD is the only persistent indicator.

### Layout Plan

```
SafeArea > Stack (for overlays on top of card grid)
  ├─ Column (main game content)
  │   ├─ GameHud (fixed height — no streak badge)
  │   ├─ Expanded > _buildCardGrid (consistent height)
  │   └─ _buildBottomActions (fixed)
  └─ Stack overlays (positioned over card grid area)
      └─ _StreakCounterOverlay (new) — appears briefly at grid center
          on every streak increment
```

The HUD no longer contains the streak badge. The streak counter overlay is a **transient** widget — it appears when `_streakCount` changes, animates (scale up + fade), then auto-dismisses after ~600ms.

---

## Implementation Plan

### Task 1: Remove Streak Badge from GameHud

**File:** `lib/widgets/game_hud.dart` (lines 164-212)

1. Remove the `if (gameState.streakCount > 0)` block that renders the streak badge inside the Wrap
2. Keep the modifier badge — it's not variable (only changes per level)
3. The Wrap should now only render the modifier badge (if any), staying on one line
4. This makes the HUD height **deterministic** — same height regardless of streak state

**Before:** Wrap contains `[modifierBadge, streakBadge]` → can be 2 lines
**After:** Wrap contains `[modifierBadge]` → always 1 line

### Task 2: Create `_StreakCounterOverlay` Widget

**File:** `lib/screens/game_screen.dart` (append after `_StreakMilestoneOverlay`)

A new `StatefulWidget` that:
- Takes the current streak count as a parameter
- Animates in over 300ms (scale from 0.5→1.0, fade 0→1)
- Shows `🔥 X` (fire emoji + count) in the game's accent color
- Auto-dismisses after 600ms (total ~900ms visible)
- Uses `SingleTickerProviderStateMixin` + `AnimationController`

```dart
class _StreakCounterOverlay extends StatefulWidget {
  final int streakCount;
  const _StreakCounterOverlay({required this.streakCount});

  @override
  State<_StreakCounterOverlay> createState() => _StreakCounterOverlayState();
}

class _StreakCounterOverlayState extends State<_StreakCounterOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.4)),
    );
    _controller.forward();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        final gs = Provider.of<GameState>(context, listen: false);
        if (gs.lastTriggeredEffect == 'streak_increment') {
          gs.clearLastEffect();
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnim.value,
            child: Opacity(
              opacity: _fadeAnim.value,
              child: Text(
                '🔥 ${widget.streakCount}',
                style: GoogleFonts.cinzel(
                  fontSize: 24,
                  color: const Color(0xFFF1C40F),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
```

### Task 3: Wire Streak Counter to GameState

**File:** `lib/models/game_state.dart` (around line 885 where streak increments)

When `_streakCount` increments (line 885), set a new effect type:

```dart
_streakCount++;
_streakMultiplier = (1.0 + (min(_streakCount, _maxStreak) ~/ 3) * 0.5)
    .clamp(1.0, 3.0);
_lastTriggeredEffect = 'streak_increment';  // NEW: triggers overlay
```

This is different from `'streak_milestone'` (3, 6, 9) and `'streak_broken'` — it fires on **every** increment, including streak 1.

### Task 4: Display the Overlay in Game Screen

**File:** `lib/screens/game_screen.dart` (in `build()`, inside the Stack)

Add the `_StreakCounterOverlay` to the Stack, positioned over the card grid area:

```dart
// Inside the Stack children (after the main Column):
if (gameState.lastTriggeredEffect == 'streak_increment')
  _StreakCounterOverlay(
    streakCount: gameState.streakCount,
  ),
```

This sits alongside the existing `_StreakBrokenOverlay` and `_StreakMilestoneOverlay` — all three can coexist since they fire on different effect types.

### Task 5: Wire Effect Handler in GameState Listener

**File:** `lib/screens/game_screen.dart` (around lines 109-120, the effect switch)

Add the new case:

```dart
case 'streak_increment':
  // Streak counter overlay is already visible via the Stack condition.
  // No extra visual needed beyond the overlay itself.
  break;
```

### Task 6: Test Scenarios

| Scenario | HUD Height | Grid Impact | Streak Display |
|----------|-----------|-------------|----------------|
| No streak, no modifier | ~80px | Grid gets max space | No overlay |
| Streak 1-2 | ~80px (fixed) | Grid gets max space | Brief 🔥 1 / 🔥 2 overlay |
| Streak 3 (milestone) | ~80px (fixed) | Grid gets max space | Golden milestone overlay (existing) |
| Streak 4-8 | ~80px (fixed) | Grid gets max space | Brief 🔥 X overlay |
| Streak 9 (milestone) | ~80px (fixed) | Grid gets max space | Golden milestone overlay (existing) |
| Streak broken | ~80px (fixed) | Grid gets max space | Red "Streak Broken!" (existing) |
| Deeper Descent + modifier | ~80px (fixed) | Grid gets max space | Unaffected |

---

## Files Changed

| File | Change |
|------|--------|
| `lib/widgets/game_hud.dart` | Remove streak badge from Wrap (lines 164-212); HUD becomes fixed height |
| `lib/screens/game_screen.dart` | Add `_StreakCounterOverlay` widget; add overlay to Stack; add `streak_increment` effect handler |
| `lib/models/game_state.dart` | Set `_lastTriggeredEffect = 'streak_increment'` on streak increment (line ~887) |

---

## Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Overlay spam on fast matches (every 300ms) | Medium | Debounce — only show overlay if streak count actually changed; use 900ms animation so rapid increments don't overlap |
| Overlay blocks card interaction | Low | Use `IgnorePointer` during animation, or place overlay with `pointerInteractable: false` |
| Streak info missing when game is paused/idle | Low | Keep a very small 🔥 dot in the HUD (icon only, no text) — takes ~12px, doesn't affect layout |
| Animation conflicts with milestone/broken overlays | Low | They fire on different effect types (`streak_increment` vs `streak_milestone` vs `streak_broken`); only one can be active at a time |

---

## Design Notes

### Animation Spec

| Property | Value |
|----------|-------|
| Duration | 900ms total |
| Scale curve | `Curves.elasticOut` (pop-in) |
| Fade in | 0–40% of duration (stays visible, fades out 40–100%) |
| Font | `GoogleFonts.cinzel`, 24px, gold (`#F1C40F`) |
| Auto-dismiss | 900ms, calls `gs.clearLastEffect()` |

### Small Streak Dot (Fallback)

If the user wants *any* persistent streak indicator, add a tiny 12px 🔥 icon to the right side of the HUD (inside the stats row, next to score). This is **not text**, just an icon — it takes ~12px width, doesn't affect vertical layout.

```dart
// In the stats Row, after the score column:
if (gameState.streakCount > 0)
  Padding(
    padding: const EdgeInsets.only(left: 6),
    child: const Text('🔥', style: TextStyle(fontSize: 12)),
  ),
```

This is a **horizontal** addition, not vertical — it doesn't affect the grid height.

---

## Decision Log

- **Chosen approach:** Remove streak badge from HUD; show transient animated streak counter overlay on card grid center on every increment
- **Rationale:** Keeps HUD at fixed height (grid never resizes), makes streak building feel rewarding, reuses existing overlay patterns
- **Fallback:** If overlay feels too distracting, keep a tiny 12px 🔥 dot in the HUD (horizontal only, no layout impact)
- **Existing overlays preserved:** `_StreakBrokenOverlay` (red, 1s) and `_StreakMilestoneOverlay` (golden, 800ms) remain unchanged
