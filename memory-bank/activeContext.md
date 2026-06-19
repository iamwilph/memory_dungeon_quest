# Memory Dungeon - Active Context

## Current Work Focus
Memory bank initialization complete. All 6 core files created:
1. `projectbrief.md` — Project scope, features, success metrics
2. `productContext.md` — Why the game exists, how it works
3. `systemPatterns.md` — Architecture, component relationships, critical paths
4. `techContext.md` — Dependencies, file structure, save formats
5. `activeContext.md` (this file) — Current state and next steps
6. `progress.md` — What's built, what's missing, known issues

## Recent Changes
- Memory bank initialized from codebase exploration
- Git commit hash: `1dcbfa6965c21454d236502144bba649b2168b87`

## Next Steps
- No active development tasks — memory bank is the baseline for future work
- When new tasks are assigned, update this file with current focus

## Active Decisions and Considerations
- GameState (1491 lines) is the single source of truth — consider extracting sub-domains if growing further
- Save format is at version 5 (deeper descent + daily history + muted preference)
- AudioService singleton manages 3 AudioPlayer instances with disk-persisted preferences

## Important Patterns and Preferences
- Card generation: 10-attempt validation ensures every tile has exactly one matching partner
- Modifiers (shadow, timer, swap, sabotage) are dungeon-index and level-specific
- Artifacts use lifetime coins (not per-run coins) for persistence across campaigns
- Daily challenges use deterministic seeding from UTC midnight date
- Deeper Descent (NG+) escalates grids by +1 row/col with 50% coin bonus, 25% score bonus
- Streak multiplier capped at 3.0x (base 1.0, +0.5 every 3 streak, max at 10)

## Learnings and Project Insights
- Shadow modifier hides pairs from the board — Phase Cloak artifact reduces hidden pairs by half
- Sabotage modifier replaces a normal pair with poison doubles (fake pair that costs lives)
- Timer modifier auto-flips cards after 3s (6s with Chronos Hourglass artifact)
- Swap modifier reshuffles active cards every 5 flips
- Poison matching costs a life but purifies another poison card
- Healing potions restore 1 life (up to max) or +50 bonus score if at full health
- Gems increase score multiplier and shatter one poison from board
- Scrolls grant hint charge and auto-reveal a random pair
- Treasure grants bonus coins based on current level