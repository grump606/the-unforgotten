# Chapters: the plan after Chapter 1

**Status: plan, nothing here is built except the Chapter 1 facts.** Written 2026-11-10 after v0.9.1. Open decisions are marked
**Decision** and are the owner's call; the rest is a recommendation.

**Settled (owner, 2026-11-10):** the game is **3 chapters**. Chapter 1 is what exists; **2 more chapters** follow, and each chapter has its own mid-boss and end boss. So the finished game has 6 bosses (3 mid-bosses, 3 end bosses). Chapter 1's two bosses are the Bellkeeper (mid) and the Eraser (end).

## What Chapter 1 is

The run that exists today is **Chapter 1**. It is two districts, each ending in a boss (the first is the chapter's mid-boss, the second its end boss):

| District (code: act) | Boss | Rows |
| --- | --- | --- |
| The Quiet Streets (act 1) | the Bellkeeper (`brakeman` enemy) | 0 to 14 |
| The Dead Country (act 2) | the Eraser (`conductor` enemy) | 15 to 29 |

So a Chapter 1 run is 30 rows and 2 bosses (`docs/GAME_FACTS.md`, "Map size"). The code and most docs still say "act" for a district and have no
word for the chapter; that is fine until a second chapter exists. Player-facing text should say "district", and, once chapters are visible
to players, "Chapter 1".

## Goals

1. Make Chapter 1 a finished, shippable chapter, so the next ones are additions and never a rescue.
2. Decide how chapters connect before building any chapter 2 content.
3. Keep the 300 MiB in-game download cap in mind: every chapter adds enemy, boss and event art.

## Phase A: finish Chapter 1 (before any new chapter)

1. **Playtest the map** (`docs/PLAYTEST_CHECKLIST.md`): choices, rest and shop pacing, elites, events. Retune from that (`REWARD_HEAL`, node weights, `ELITE_BUDGET_MULTIPLIER`; try 1.25 if it is too easy).
2. **The end of Chapter 1.** Today the Eraser's defeat shows the escape painting, "Someone speaks your name. This time, you answer." and "Outcome: Escaped" (`run/screens/end_screen.gd`, `run/end_scene.gd`): that is a final ending, and with 3 chapters it belongs at the end of Chapter 3. Chapter 1 needs: a closing story beat that answers its question and opens the next one; an "End of Chapter 1" screen with a run summary (deck, relics, bosses beaten, elites fought); and a save at the break. Until Chapter 2 exists, the break screen has a "To be continued" state, so the next release must not claim an escape. The "Escaped" outcome, the escape painting and the line above move to the end of Chapter 3. **Decision:** whether the 0.9.x releases keep the old ending until Chapter 2 is ready (cheap, but it says "escaped") or switch now to the chapter-break screen (honest, and testers see the real structure).
3. **Elite modifiers or an elite roster** (`docs/MAP_DESIGN.md`, "Elite modifier ideas (not built)"). **Decision:** build one, or leave elites as scaled packs.
4. **Stray gap** (greedy 76.7% against smart 56.7% as the Stray before elites): find out whether it is a bot weakness or a design problem.
5. **Remaining polish:** card and relic wording ("keepsake", "Heal 3" against "Heal 3 HP", the generic reward line), figure portraits, rest paintings (`docs/NEXT_STEPS.md`, "To do").

## Phase B: the chapter structure (design first, then code)

Today `RouteMap.ACTS` is 2 and `RunState` builds one map. A chapter layer would sit above it. Questions to settle in a design doc (`docs/CHAPTERS_DESIGN.md`, to be written) before code:

- **What carries over?** Recommendation: the deck, relics and gold carry over; HP is restored in part (a rest-sized heal, not a full one), so the chapter break is a breath and not a reset. **Decision.**
- **One run or separate runs?** Recommendation: one run through all 3 chapters, with each break as a save point. **Decision.**
- **Run length.** One chapter is 30 rows, so 3 chapters is 90 stops in one run. Check how long a Chapter 1 run takes with testers before committing; if it is long, either shorten later chapters (for example 2 districts of 10 to 12 rows) or lean on the save points. **Decision.**
- **The class and the story.** The 4 characters play through all 3 chapters; each needs its own beats at the chapter breaks (as they have story beats now), which is writing work for 4 characters times 2 more chapters.
- **How is a chapter built?** Recommendation: a chapter is a data set (district names, enemy pool, boss pair, events, story beats, art) given to the same `RouteMap` generator, so a new chapter is content, not a new engine.
- **Difficulty across chapters.** Recommendation: a fresh budget curve per chapter that starts near the end of the last one (`fight_budget` and `MAP_DIFFICULTY`), checked with the sims and not by feel.
- **Saves.** A chapter number and its carried state need a save format bump (map runs write version 5 now; `docs/MAP_DESIGN.md` has the format notes) and old saves must still load as Chapter 1.
- **Sims and bots.** `tools/run_sim.gd` and the route bots need to run a multi-chapter run and report deaths by chapter.
- **Tutorial and title screen.** Say "Chapter 1" where it helps and no further.

## Phase C: Chapters 2 and 3 content (only after A and B; build Chapter 2 fully, then Chapter 3)

Per chapter, the minimum is: 2 districts with names and paintings, a mid-boss and an end boss, about 7 new regular enemies (or a re-skinned set with new moves), 8 to 12 events, a story arc of 4 beats, and new cards and relics to keep the decks growing.
**Decision:** how much of the deck and relic pool is new per chapter. Recommendation: about a quarter new cards per class and 6 to 8 new relics.

Art cost drives the installer size: a chapter of enemies plus their elite auras is roughly 15 to 25 MB, so two more chapters add about 30 to 50 MB on top of about 123 MiB today. The 150 MiB guard for old clients was removed on 2026-11-10, so this fits under the 300 MiB in-game cap with room to spare (players on v0.8.2 or earlier must download a larger installer by hand). Check `scripts/build_installer.ps1`'s 2/3-of-cap warning at every chapter, and raise `MAX_INSTALLER_BYTES` one release before it is needed (`docs/UPDATE_CHECK.md`, "Installer size cap").

## Also on the list (not chapter work)

- Authenticode signing before any public launch (on hold, `docs/NEXT_STEPS.md`, decision 1).
- Economy and relic price playtesting; the keep-5 hand rule review.

## Order

A.1 and A.2 first (playtest, the ending); A.3 to A.5 in parallel as they come up; then the Phase B design doc; then B code; then C. Cut a release after each phase that changes what players see.
