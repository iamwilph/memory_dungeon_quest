# Memory Dungeon - System Patterns

## Architecture Overview
Memory Dungeon is a single-feature Flutter app (no feature splitting) using `ChangeNotifier` for state management. All game logic, screens, models, and services live in `lib/` with subdirectories.

## Key Technical Decisions

### State Management
- **ChangeNotifier** (`GameState`) is the central state object, managing all game logic
- **Provider** wraps `GameState` at the app root via `ChangeNotifierProvider`
- Services (AudioService, HighScoreService, etc.) use singleton pattern via factory constructors
- No Riverpod, no codegen — simple and focused for this project scope

### Data Persistence
- **CampaignProgress** serialized to JSON, stored via `CampaignProgressStore` interface
- `LocalCampaignProgressStoreIO` / `LocalCampaignProgressStoreWeb` implement platform-specific file persistence via `path_provider`
- `MemoryCampaignProgressStore` for in-memory testing (default)
- Audio preferences (mute + volume) persisted as JSON files in app support directory
- High scores stored separately via `HighScoreService` (platform-specific implementations)

### Card Generation Pattern
1. Calculate grid size from dungeon config + level
2. Select pair assets from dungeon's emoji set + fallback pool
3. Shuffle deck, generate `DungeonCard` objects
4. Apply modifiers (shadow hides pairs, sabotage replaces with poison doubles)
5. Validate every tile has exactly one matching partner (up to 10 attempts)

### Game Flow
```
Menu → Dungeon Selector → Game Screen (with HUD) → Level Complete → Next Level
  → (or) Game Over → Return to Menu
  → (or) Daily Challenge (deterministic, seeded)
  → (or) Campaign Map (progress overview)
  → (or) Shop (unlock artifacts with lifetime coins)
```

## Component Relationships

### Models
- `DungeonConfig` — 6 predefined dungeons with modifiers, grid sizes, scoring
- `DungeonCard` — individual card with type (poison, healing, treasure, scroll, gem, normal)
- `GameState` — central game logic (1491 lines), handles matching, scoring, artifacts, daily, deeper descent
- `CampaignProgress` — save data model (version 5), including artifacts, daily history, deeper descent state
- `DailyChallenge` — deterministic daily puzzle with seed
- `CampaignProgress` helpers for finding next unfinished dungeon/level

### Services
- `AudioService` — singleton with 3 players (SFX, ambient, menu), volume/mute persistence
- `CampaignProgressStore` — interface; `MemoryCampaignProgressStore` (default), `LocalCampaignProgressStoreIO`, `LocalCampaignProgressStoreWeb`
- `HighScoreService` — platform-specific high score storage
- `AchievementManager` — tracks achievement progress
- `TipsStateService` — tracks which tips pieces have been seen per dungeon+level

### Screens
- `MenuScreen` — main hub (continue, new game, daily, shop, settings)
- `DungeonSelectorScreen` — choose dungeon/level
- `CampaignMapScreen` — visual progress overview
- `GameScreen` — active gameplay with `DungeonCardWidget`, `GameHud`
- `ShopScreen` — unlock artifacts
- `DailyChallengeScreen` — daily puzzle
- `SettingsScreen` — audio controls, accessibility
- `TipsOverlay` / `TutorialHint` — onboarding
- `LevelSelectOverlay` — level picker within dungeon
- `AchievementsScreen` — achievement tracking
- `TermsOfUseScreen` — legal

### Theme
- `DungeonTheme` — per-dungeon color palettes
- `StonePainter` — custom painter for stone texture background

### Widgets
- `DungeonCardWidget` — renders individual cards with flip animations
- `GameHud` — displays lives, score, coins, level progress
- `TorchOverlay` — atmospheric lighting effect
- `AmbientParticles` — particle effects background
- `HudElement` — reusable HUD components

## Critical Implementation Paths
1. **Card matching**: `GameState.flipCard()` → `_checkMatch()` → `_applyMatchEffects()` → `_completeLevelIfSolved()`
2. **Persistence**: `GameState._saveCampaignProgress()` → `CampaignProgressStore.save()` → JSON file
3. **Daily Challenge**: `DailyChallenge.getToday()` (seeded by date) → `GameState.initDailyLevel()`
4. **Artifact system**: `GameState.tryPurchaseArtifact()` → deducts lifetime coins, persists to save
5. **Deeper Descent**: Unlocked when all 6 dungeons cleared → `initDeeperDescent()` with escalated grids (rows+1, cols+1)