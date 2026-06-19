# Memory Dungeon - Project Brief

## Core Concept
A Flutter-based memory matching game with dungeon-crawling progression. Players flip cards to find matching pairs in procedurally generated dungeon levels, progressing through 6 themed chambers with increasing difficulty.

## Core Requirements
- **Memory Matching Gameplay**: Flip two cards at a time to find matching pairs before running out of lives
- **Dungeon Progression**: 6 dungeons (Stone → Lava → Ice → Crypt → Void → Forest), each with 20 levels
- **Card Types**: Normal, Poison (costs life), Healing (restores life), Treasure (coins), Scroll (extra hints), Gem (score multiplier)
- **Level Modifiers**: Shadow (hidden cards), Timer (auto-flip), Swap (reshuffle), Sabotage (fake poison pairs)
- **Artifact System**: 10 unlockable passive abilities purchasable with lifetime coins
- **Persistent Progression**: Campaign saves via `shared_preferences`, high scores, achievements
- **Daily Challenges**: Deterministic daily puzzles with seeded random generation
- **New Game+**: "Deeper Descent" mode with escalated grids after clearing all chambers

## Key Goals
- Engaging, progressively challenging memory game
- Rich dungeon-crawling atmosphere with themed visuals
- Meaningful progression systems (artifacts, achievements, high scores)
- Smooth, polished mobile experience with sound and visual feedback