# Tips Overlay Feature

## Goal
Create a tips overlay that appears at the start of each puzzle to introduce only the special pieces included in that puzzle, excluding those with `CardType.normal`. The overlay prioritizes showing `CardType.poison` first when multiple special pieces exist, and allows navigation through them using next and previous buttons. The overlay must not repeat pieces that have already been shown in previous puzzles, storing that data locally. It must appear before gameplay begins, dim the background, display each piece's image and emoji, and include a "Start" button to continue once viewed.

## Architecture Analysis

### Current State
- **CardType enum** (`lib/models/dungeon_card.dart`): `poison`, `healing`, `treasure`, `scroll`, `gem`, `normal`
- **Puzzle Preview** (`GameState._startPuzzlePreview()`): Shows all cards face-up for 1.2s, then flips them back. This is a generic preview, not per-piece.
- **Card Generation** (`GameState._generateCards()`): Creates pairs from dungeon emoji sets, filtered to `totalPairs`.
- **Tutorial** (`lib/screens/tutorial_hint.dart`): 3-step onboarding tutorial shown once on first launch. Uses in-memory prefs.
- **Persistence** (`CampaignProgress` v5): JSON-based save/restore for campaign state. Does NOT track per-piece seen state.
- **UI Pattern**: Overlays are Dialog-based (TutorialOverlay, _buildGameOverOverlay, _buildVictoryOverlay), using `DungeonTheme` for styling.

### Design Decisions
1. **TipsOverlayWidget** — New Flutter widget in `lib/screens/tips_overlay.dart`
   - Appears as a Dialog (matching TutorialOverlay pattern)
   - Shows one special piece at a time with:
     - Large emoji display
     - Piece name (from CardType enum)
     - Brief description of what the piece does
   - Navigation: Previous / Next buttons (when multiple pieces)
   - "Start Game" button (always visible, enables gameplay after viewing)
   - Dimmed background overlay (barrierDismissible: false)
   - Skips entirely if no special pieces exist in the puzzle (all normal)

2. **TipsStateService** — New service in `lib/services/tips_state_service.dart`
   - Tracks which (dungeonId, level, pieceEmoji) combos have been shown
   - Uses `shared_preferences` (same as tutorial system pattern)
   - Key format: `tips_seen_{dungeonId}_L{level}_{emoji}`
   - Methods: `isPieceSeen()`, `markPieceSeen()`, `getUnseenSpecialPieces()`

3. **Integration with GameState**
   - After `_generateCards()` and before `_startPuzzlePreview()`, check for special pieces
   - If special pieces exist and not all have been seen, show TipsOverlay
   - After tips dismissed, proceed with normal puzzle preview

## Implementation Phases

### Phase 1: Tips Data Model & Service
- Create `TipsPieceInfo` record: (emoji, CardType, displayName, description)
- Create `TipsStateService` with SharedPreferences integration
- Methods: `getUnseenSpecialPieces(dungeonId, level)`, `markAsSeen(emoji)`, `isAllSeen(dungeonId, level)`

### Phase 2: Tips Overlay Widget
- Create `TipsOverlay` widget in `lib/screens/tips_overlay.dart`
- Display: emoji, name, description per piece
- Navigation: Previous/Next buttons, page indicator dots
- "Start Game" button (always present, closes overlay)
- Dimmed background with DungeonTheme styling
- Handle edge case: single piece (no nav, just Start)

### Phase 3: GameState Integration
- Modify `_startPuzzlePreview()` to check for special pieces first
- If special pieces exist and unseen → show TipsOverlay before preview
- Wire up TipsStateService into GameState via Provider
- Ensure tips overlay appears before puzzle preview timing

### Phase 4: Testing & Polish
- Verify no special pieces → skip overlay entirely
- Verify all pieces previously seen → skip overlay
- Verify multi-piece navigation works (prev/next/start)
- Verify poison pieces appear first
- Test across all 6 dungeons with varying piece compositions
