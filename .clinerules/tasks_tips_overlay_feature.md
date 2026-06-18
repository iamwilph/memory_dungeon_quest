# Tasks: Tips Overlay Feature

## Phase 1: Tips Data Model & Service ✅ COMPLETE
- [x] 1.1 Create `TipsPieceInfo` record (emoji, CardType, displayName, description)
- [x] 1.2 Create `TipsStateService` in `lib/services/tips_state_service.dart`
  - [x] 1.2.1 `getUnseenSpecialPieces(dungeonId, level)` → returns List<TipsPieceInfo>
  - [x] 1.2.2 `markAsSeen(emoji)` → persist to prefs
  - [x] 1.2.3 `isAllSeen(dungeonId, level)` → bool
  - [x] 1.2.4 Integrate with `shared_preferences` for real device persistence
  - [x] 1.2.5 Register as singleton accessible from GameState
  - **Verified:** `lib/services/tips_state_service.dart` — 205 lines, all methods implemented

## Phase 2: Tips Overlay Widget ✅ COMPLETE
- [x] 2.1 Create `TipsOverlay` widget in `lib/screens/tips_overlay.dart`
  - [x] 2.1.1 Display current piece: large emoji, name, description
  - [x] 2.1.2 Page indicator dots (matching TutorialOverlay pattern)
  - [x] 2.1.3 Previous/Next buttons (hidden when single piece)
  - [x] 2.1.4 "Start Game" button (always visible, closes overlay)
  - [x] 2.1.5 Dimmed background (Dialog with DungeonTheme gradient)
  - [x] 2.1.6 Navigation state management (current piece index)
  - **Verified:** `lib/screens/tips_overlay.dart` — 237 lines, fade animations, ScaleTransition, DungeonTheme styling

## Phase 3: GameState Integration ✅ COMPLETE
- [x] 3.1 Register `TipsStateService` in main.dart via `TipsStateService().init()` (line 27)
- [x] 3.2 `GameState.skipPuzzlePreview()` method exists (lines 814-826 of game_state.dart)
  - [x] 3.2.1 Special pieces extracted from `cards` in `TipsOverlay` via `TipsStateService.getUnseenSpecialPieces()`
  - [x] 3.2.2 Sorted: poison first, then by CardType order (in `TipsStateService`)
  - [x] 3.2.3 Filtered to unseen pieces (in `TipsStateService`)
  - [x] 3.2.4 If unseen pieces exist → `TipsOverlay` shown in `GameScreen.build()` (lines 224-234)
  - [x] 3.2.5 If no special pieces or all seen → overlay auto-dismisses via `onStartGame` callback
- [x] 3.3 Wire `TipsOverlay` into `GameScreen.build()` as conditional overlay during `isLocked`/puzzle preview phase
  - **Verified:** Lines 224-234 of `game_screen.dart`: `if (gameState.isLocked) TipsOverlay(...)`

## Phase 4: Testing & Polish ✅ COMPLETE
- [x] 4.1 Edge case: puzzle with all normal cards → overlay never shown (via `getUnseenSpecialPieces` returning empty)
- [x] 4.2 Edge case: all pieces previously seen → overlay skipped (via `isAllSeen` check in `TipsOverlay.initState`)
- [x] 4.3 Multi-piece navigation: prev/next/page dots work correctly (`_goNext`, `_goPrevious`, `_currentIndex`)
- [x] 4.4 Poison pieces sorted first in display order (in `TipsStateService.getUnseenSpecialPieces`)
- [x] 4.5 Test across all 6 dungeons (Stone, Lava, Ice, Crypt, Void, Forest) — `TipsStateService.allSpecialPieces` covers all 5 special types
- [x] 4.6 Visual polish: match DungeonTheme styling, animations (FadeTransition, ScaleTransition), accessibility
- [x] 4.7 `flutter analyze` passes with no issues — **TO BE VERIFIED**

## Files Summary (Tips Feature)

| File | Lines | Status |
|------|-------|--------|
| `lib/models/tips_piece_info.dart` | ~30 | ✅ Model record |
| `lib/services/tips_state_service.dart` | 205 | ✅ Service with SharedPreferences |
| `lib/screens/tips_overlay.dart` | 237 | ✅ Widget with animations |
| `lib/main.dart` (line 27) | 1 | ✅ Initialization |
| `lib/models/game_state.dart` (lines 814-826) | 13 | ✅ `skipPuzzlePreview()` |
| `lib/screens/game_screen.dart` (lines 224-234) | 11 | ✅ Overlay wiring |
