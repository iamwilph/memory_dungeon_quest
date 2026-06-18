# Tasks: Tips Overlay Feature

## Phase 1: Tips Data Model & Service [Not Started]
- [ ] 1.1 Create `TipsPieceInfo` record (emoji, CardType, displayName, description)
- [ ] 1.2 Create `TipsStateService` in `lib/services/tips_state_service.dart`
  - [ ] 1.2.1 `getUnseenSpecialPieces(dungeonId, level)` → returns List<TipsPieceInfo>
  - [ ] 1.2.2 `markAsSeen(emoji)` → persist to prefs
  - [ ] 1.2.3 `isAllSeen(dungeonId, level)` → bool
  - [ ] 1.2.4 Integrate with existing `_InMemoryPrefs` (swap to `shared_preferences` for real device)
  - [ ] 1.2.5 Register as singleton accessible from GameState

## Phase 2: Tips Overlay Widget [Not Started]
- [ ] 2.1 Create `TipsOverlay` widget in `lib/screens/tips_overlay.dart`
  - [ ] 2.1.1 Display current piece: large emoji, name, description
  - [ ] 2.1.2 Page indicator dots (matching TutorialOverlay pattern)
  - [ ] 2.1.3 Previous/Next buttons (hidden when single piece)
  - [ ] 2.1.4 "Start Game" button (always visible, closes overlay)
  - [ ] 2.1.5 Dimmed background (barrierDismissible: false, DungeonTheme gradient)
  - [ ] 2.1.6 Navigation state management (current piece index)

## Phase 3: GameState Integration [Not Started]
- [ ] 3.1 Register `TipsStateService` as a provider (ChangeNotifierProvider or singleton)
- [ ] 3.2 Modify `GameState.initDungeon()` to check for special pieces after `_generateCards()`
  - [ ] 3.2.1 Extract special pieces (CardType != normal) from `_cards`
  - [ ] 3.2.2 Sort: poison first, then others by CardType order
  - [ ] 3.2.3 Filter to unseen pieces via `TipsStateService`
  - [ ] 3.2.4 If unseen pieces exist → show `TipsOverlay` before `_startPuzzlePreview()`
  - [ ] 3.2.5 If no special pieces or all seen → skip overlay, proceed normally
- [ ] 3.3 Wire `TipsOverlay` into `GameScreen.build()` as a conditional overlay in the Stack

## Phase 4: Testing & Polish [Not Started]
- [ ] 4.1 Edge case: puzzle with all normal cards → overlay never shown
- [ ] 4.2 Edge case: all pieces previously seen → overlay skipped
- [ ] 4.3 Multi-piece navigation: prev/next/page dots work correctly
- [ ] 4.4 Poison pieces sorted first in display order
- [ ] 4.5 Test across all 6 dungeons (Stone, Lava, Ice, Crypt, Void, Forest)
- [ ] 4.6 Visual polish: match DungeonTheme styling, animations, accessibility
