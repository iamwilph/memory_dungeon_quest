# Memory Dungeon - Technical Context

## Technologies Used
- **Flutter** SDK ^3.10.1 (Dart)
- **Provider** ^6.1.5+1 — state management (ChangeNotifierProvider)
- **audioplayers** ^6.7.1 — SFX, ambient, and menu audio
- **flip_card** ^0.7.0 — card flip animations
- **google_fonts** ^8.1.0 — custom typography
- **path_provider** ^2.1.5 — file persistence for saves/audio prefs
- **shared_preferences** ^2.5.5 — not directly used (file-based persistence preferred)
- **url_launcher** ^6.3.2 — terms of use / external links
- **flutter_launcher_icons** ^0.14.4 — build-time icon generation

## Development Setup
- **SDK**: Dart ^3.10.1, Flutter 3.x
- **Platform**: iOS and Android (from android/ and ios/ directories)
- **Linting**: flutter_lints ^6.0.0
- **Asset structure**:
  - `assets/audio/sfx/` — 17 sound effects (flip, match, mismatch, poison, heal, treasure, gem, scroll, victory, gameover, whoosh)
  - `assets/audio/ambience/` — 7 ambient tracks (one per dungeon + generic)
  - `assets/images/logo.png` — app logo

## Technical Constraints
- **No Riverpod** — Uses ChangeNotifier + Provider (per project rules)
- **No codegen** — No `.g.dart` files, no `build_runner`
- **Single ChangeNotifier** — All game state in `GameState` (1491 lines)
- **Platform-specific storage** — `LocalCampaignProgressStoreIO` / `LocalCampaignProgressStoreWeb` for cross-platform file persistence
- **Color API** — Must use `.withValues()` instead of deprecated `withOpacity()` (Flutter 3.22+)
- **Debug mode** — Debug-only UI wrapped in `if (kDebugMode)`

## Key Dependencies
| Package | Purpose |
|---------|---------|
| `audioplayers` | 3 separate AudioPlayer instances (SFX, ambient, menu) |
| `provider` | ChangeNotifierProvider for GameState |
| `path_provider` | App support directory for save files |
| `flip_card` | Card flip animation widget |
| `google_fonts` | Custom fonts for dungeon theming |
| `url_launcher` | Open terms of use URL |

## File Structure (lib/)
```
lib/
  main.dart                    — App entry, initializes services, wraps with Provider
  constants.dart               — Global constants
  models/
    achievement.dart           — Achievement + AchievementProgress models
    campaign_progress.dart     — Save data model (version 5)
    daily_challenge.dart       — Deterministic daily puzzle
    dungeon_card.dart          — Card types + DungeonCard class
    dungeon_config.dart        — 6 dungeons, modifiers, grid logic
    game_state.dart            — Central game logic (1491 lines)
    tips_piece_info.dart       — Tips piece tracking
  screens/
    (11 screens — see systemPatterns.md)
  services/
    achievement_manager.dart   — 14 achievements, file-based persistence
    audio_service.dart         — Singleton, 3 players, volume/mute persistence
    campaign_progress_store.dart — Interface + Memory implementation
    high_score_service.dart    — Platform-specific high scores
    local_campaign_progress_store.dart — Abstract interface
    local_campaign_progress_store_io.dart — File-based (IO)
    local_campaign_progress_store_web.dart — File-based (Web)
    tips_state_service.dart    — Per dungeon+level tip visibility
  theme/
    dungeon_theme.dart         — Per-dungeon color palettes
    stone_painter.dart         — Custom stone texture painter
  widgets/
    ambient_particles.dart     — Background particle effects
    dungeon_card_widget.dart   — Card rendering + flip animation
    game_hud.dart              — Lives, score, coins, level display
    hud_element.dart           — Reusable HUD components
    torch_overlay.dart         — Atmospheric lighting
```

## Save File Formats
- **Campaign Progress**: JSON file with version 5, containing dungeon progress, artifacts, daily history, deeper descent state
- **Audio Preferences**: JSON files (`audio_muted.json`, `audio_volumes.json`) in app support directory
- **Achievements**: JSON file (`achievements.json`) in app documents directory
- **High Scores**: Platform-specific storage (IO vs Web implementations)