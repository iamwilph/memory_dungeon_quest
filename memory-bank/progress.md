# Memory Dungeon - Progress

## What Works (Complete)
### Core Gameplay
- Memory matching with 6 dungeon themes (Stone, Lava, Ice, Crypt, Void, Forest)
- 20 levels per dungeon with escalating grid sizes (4×3 → 6×6)
- 1.2s preview → flip-back → unlock game loop
- 5 card types: poison, healing, treasure, scroll, gem, normal
- 4 level modifiers: shadow, timer, swap, sabotage
- Streak/combo system with score multiplier (capped 3.0x)
- Score, coins, lives tracking per level

### Progression Systems
- Campaign mode with dungeon unlocking (Stone → Lava → Ice → Crypt → Void → Forest)
- Daily challenges (deterministic, seeded by date, with unique modifiers)
- Artifact shop (10 unlockable artifacts using lifetime coins)
- Deeper Descent (New Game+) with escalated grids and bonuses
- Campaign save/load (version 5, JSON persistence)
- High score tracking per dungeon-level

### Content
- 6 dungeons with unique emoji sets (8-32 unique emojis each)
- 17 SFX files (flip, match, mismatch, poison, heal, treasure, gem, scroll, victory, gameover, whoosh)
- 7 ambient audio tracks (one per dungeon)
- 14 achievements with file-based persistence
- 5 tips pieces per card type (tutorial overlay)
- Colorblind mode with symbol overlays

### UI/UX
- Menu screen (continue, new game, daily, shop, settings)
- Dungeon selector screen
- Campaign map screen
- Game screen with HUD (lives, score, coins, level progress)
- Shop screen (artifact purchasing)
- Daily challenge screen
- Settings screen (audio controls, accessibility)
- Tips overlay / tutorial hint (first launch)
- Level select overlay
- Achievements screen
- Terms of use screen
- Atmospheric effects: torch overlay, ambient particles, stone painter

### Systems
- AudioService (singleton, 3 players, volume/mute persistence)
- CampaignProgressStore (interface + memory/file implementations)
- HighScoreService (platform-specific)
- AchievementManager (14 achievements, file persistence)
- TipsStateService (per dungeon+level tip visibility)

## What's Left to Build
### Missing Features
- No unit tests (widget_test.dart exists but is default template)
- No integration/e2e tests
- No CI/CD pipeline
- No Android/iOS app store build configuration (icons, splash screens exist but untested)
- No analytics or crash reporting
- No leaderboard system (high scores are local only)
- No multiplayer or sharing features

### Technical Debt
- **GameState (1491 lines)** — monolithic class, should be refactored into sub-domains:
  - Matching logic
  - Scoring system
  - Artifact system
  - Daily challenge logic
  - Deeper descent logic
- **No Riverpod** — project deliberately avoids it, but this limits testability
- **Hardcoded strings** — no localization system (all English)

## Current Status
- **Memory bank initialized** (6/19/2026)
- **Git commit**: `1dcbfa6965c21454d236502144bba649b2168b87`
- All 6 core memory bank files created and validated

## Known Issues
- GameState file is 1491 lines — difficult to navigate and maintain
- Card generation can throw after 10 attempts (rare edge case with certain dungeon/level combos)
- No automatic save on every action (only on level complete/game over — potential data loss)
- AudioService singleton uses factory pattern — not easily mockable for testing
- ~~No error boundaries in screens (exceptions crash the app)~~ → **RESOLVED**: All 9 screens wrapped with `ErrorBoundary` (`lib/shared/widgets/error_boundary.dart`). Exceptions now show a styled error panel with a "Return to Camp" button instead of crashing.
- `kIsDebugMode` constant in `constants.dart` is hardcoded `true` — should use Flutter's `kDebugMode` from `flutter/foundation`

## Evolution of Project Decisions
- Started as a simple memory matching game
- Evolved to include dungeon themes with unique modifiers
- Added daily challenges for replayability
- Added artifact shop for long-term engagement
- Added Deeper Descent (NG+) for completionists
- Added 14 achievements for social/competitive players
- Save format has evolved from v1 to v5 (each version added a new system)