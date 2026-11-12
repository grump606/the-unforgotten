# Chapters: design (Phase B)

**Status: draft, owner decisions applied 2026-11-12. Nothing here is built.** Written 2026-11-12. It answers the Phase B questions in
[`CHAPTERS_PLAN.md`](CHAPTERS_PLAN.md). Items marked **Decision** still need the owner's call; everything else is a recommendation.

**Settled:** 3 chapters; each has a mid-boss and an end boss (`CHAPTERS_PLAN.md`). **Settled (owner, 2026-11-12):** one continuous run;
the deck, relics and gold carry over; HP gets a partial heal at each chapter break.
**Settled (owner, 2026-11-12, later):** the story has a **final boss after Chapter 3's end boss**; "Escaped" is reached after that fight, not after Chapter 3's end boss. The finale's shape (a short set-piece fight or a short map) is open, see `CHAPTER2_PLAN.md`; until it is decided the code treats the last chapter's end boss as the end, as written below.
**Settled (owner, 2026-11-12):** all chapters are the same length (30 rows); the break heal is 0.75 of max HP; the old "Escaped" ending stays until Chapter 2 exists; a chapter's end boss gives a boss relic and gold (no card reward); the mid-boss heal is 0.75.

## What exists today (the facts this design builds on)

- `RouteMap.ACTS = 2`, `ACT_ROWS = 15`, `ROWS = 30`, `DISTRICT_NAMES` (`run/route_map.gd`). `RouteMap.generate(seed, char_id, overrides)`
  builds the whole map; a map is saved as its full dict (`to_dict()`), never re-derived from the seed.
- The map's row layout (story beat rows, forced treasure row, forced rest row, mid-boss, boss) is in `MAP_DESIGN.md`, "Row layout".
- Difficulty: `StarterContent.fight_budget(row)` = `MAP_DIFFICULTY` x lerp(`BUDGET_ACT_START[act]`, `BUDGET_ACT_END[act]`, local), with
  act arrays `[34, 46]` to `[50, 62]`, times `MAP_CLASS_DIFFICULTY` and, for elites, `ELITE_BUDGET_MULTIPLIER`. Packs come from one
  global `Encounters.enemy_pool()`.
- Story: `StoryContent.BEAT_PATHS` has 4 beats in order, with per-character overrides under `data/story/<character>/`.
- Ending: a won final boss sets `run.escaped` and `end_screen.gd` shows "Escaped".
- Saves: map runs write version 5 (`RunSave.MAP_VERSION`); line runs write 4. The game reads 2 to 5.

## The shape

A **chapter** is the existing 30-row map (2 districts, mid-boss, end boss). A run is up to 3 chapters in a row. Between chapters
there is a **chapter break**: a screen, a save, a story beat and a partial heal. Then the next chapter's map is generated and play
continues.

```
Chapter 1 (30 rows) -> BREAK -> Chapter 2 (30 rows) -> BREAK -> Chapter 3 (30 rows) -> ending ("Escaped")
```

Only the last chapter's end boss ends the run with "Escaped". A chapter's end boss otherwise leads to its break.

## Decisions (recommendations)

### 1. Carry-over (settled)

| Carries | Rule |
| --- | --- |
| Deck, relics, gold | Unchanged. |
| Max HP | Unchanged (events and rewards that raised it keep it). |
| HP | Healed by `CHAPTER_BREAK_HEAL_FRACTION` of max HP (0.75, settled; a rest heals 0.5, `MAP_REST_HEAL_FRACTION`), never above max. |
| Run flags (`elite_bonus_gold`, `map_win_heal`, reward-used flags) | Reset, since they belong to a stop. |
| Rest counter | Reset per chapter (`rest_number()` feeds rest wording and heal; check it). |

The chapter's end boss also pays a reward (section 2a).

### 2. Run length (settled)

Every chapter is 30 rows, so a full run is 90 stops, with each break a save point. Still keep the row count per chapter as data
(`rows_per_district`), so a later change is content and not code. A tester should time a Chapter 1 run before Chapter 2 is built.

### 2a. Boss reward (settled, 2026-11-12)

A chapter's **end boss only** pays **a boss relic and gold**, and nothing else (no card reward). The mid-boss keeps its current gold bonus
(`MID_BOSS_GOLD_BONUS`, 15) and gets no relic. Mechanics, modelled on elite spoils (`RunState.take_elite_spoils`, `ELITE_RELIC_FALLBACK_GOLD`):
a relic the character does not own, gold instead when it owns them all, on a spoils screen before the break screen. Relics have no tier
today, so "boss relic" needs one decision when it is built: either a price floor (a higher `TREASURE_MIN_RELIC_PRICE`-style cut-off, simplest) or a
`boss_only` flag on a few new relics. Recommendation: the price floor first, then add boss-only relics with the chapter content. The gold
amount is a constant to tune from the sims (start at 60).

**Mid-boss heal (settled):** cut from a full heal to 0.75 of max HP (`MAP_MID_BOSS_HEAL_FRACTION`, changed 2026-11-12), the same as the chapter break.
This lowers the bot figures in `docs/SIM.md` a little; re-run the sims before the next release.

### 3. A chapter is data

Add a `ChapterData` resource (one per chapter, under `data/chapters/`), fed to the same `RouteMap` generator:

| Field | Meaning |
| --- | --- |
| `id`, `number`, `title` | "Chapter 1", its name. |
| `district_names` | Two names (replaces the hard-coded `DISTRICT_NAMES`). |
| `rows_per_district` | 15 today. |
| `enemy_pool` | Which enemies packs draw from; elites use the same pool. |
| `mid_boss`, `end_boss` | Enemy ids (today `the_brakeman`, `the_conductor`). |
| `budget_start`, `budget_end` | Per district: replaces `BUDGET_ACT_START/END`. |
| `event_pool` | Events available (some shared across chapters). |
| `story_beats` | The beat indices for the layout's story rows, plus the break beat. |
| `backdrops` | Battle and rest paintings per district. |

`RouteMap.ACTS`, `ACT_ROWS`, `ROWS` and `DISTRICT_NAMES` stop being constants and become reads of the active chapter. The generator
change is the risky part: the constants are used in `route_map.gd`, `starter_content.gd` (`fight_budget`), `debug_launch.gd`,
`tutorial_content.gd`, the bots and tests. Step 1 of the build (below) does this refactor with **no behavior change** and Chapter 1 as the only
chapter, proven by the existing sims and tests producing identical maps for the same seeds.

### 4. Difficulty across chapters

A fresh budget curve per chapter, each starting a little above where the previous chapter's end boss left off. Chapter 1 ends near
budget 62 x 1.9. Starting point for tuning: Chapter 2 starts at about 60 and ends about 80, Chapter 3 starts at about 78 and ends about 98.
These are guesses; set them from the sims (`tools/threat_table.gd`, `tools/run_sim.gd`), and expect the carried deck to be stronger than a
fresh one, so measure with carried decks, not fresh Chapter 2 starts. The pack scale bounds (`PACK_SCALE_MIN/MAX`) cap how far one
enemy set can be pushed, which is why later chapters need their own enemies and not just bigger numbers.

### 5. Saves

- New version 6 (`RunSave.CHAPTER_VERSION`), written only by runs that have a chapter number (all map runs from the release that ships
  chapters). Adds `chapter` (1 to 3) and `chapter_break` (a bool: saved at the break screen).
- A v5 save loads as Chapter 1. The previous release cannot read v6; the existing rule (a newer version is rejected with a clear message)
  covers that.
- The save at a break is made **before** the heal and the next map exist, so quitting on the break screen and resuming shows the break
  again and cannot be abused by re-rolling.
- The next chapter's map seed is derived from the run seed and the chapter number, so it is reproducible and does not depend on how
  much RNG the previous chapter used. The map itself is stored whole once generated, as today.
- Line runs are untouched.

### 6. Chapter break contents

1. The closing story beat of the chapter (per character, 4 characters; see "Writing work").
2. A summary: deck size, relics, bosses beaten, elites fought, gold.
3. The partial heal and its amount, stated on the screen.
4. "Begin Chapter N" (or, until Chapter 2 exists, "To be continued", see "Ending in between").

### 7. The ending in between releases (settled)

The old "Escaped" ending stays as it is until Chapter 2 exists. So nothing player-visible changes for Chapter 1: the Eraser's defeat still
ends the run. The chapter break, its screen and the switch of the ending ship together with the first real Chapter 2 content. Until then
the chapter code is built behind the scenes (steps 1 and 2) and a stub Chapter 2 is reachable only from a debug launch.

### 8. Sims and bots

`tools/run_sim.gd` and both route bots run chapter by chapter: on a chapter break they take the free choice (if any) and continue. The report
gains deaths by chapter, deck size and relic count at each break, and escapes counted only for a finished final chapter. Until Chapter 2
exists a one-chapter run reports "reached the break" as the success state.

### 9. Tutorial and title screen

Say "Chapter 1" only where a player sees it (the map header, the break screen). The tutorial page that describes the route map keeps
"two districts" and adds one sentence: the journey has more than one chapter. Do not promise a count of chapters until two exist.

## Build order

Each step is its own PR with the full check (`scripts/check.ps1`) green. Steps 1 to 3 and 5 change nothing a player sees; the release
that changes the ending is step 6, when Chapter 2 has real content.

1. **Chapter as data, no behavior change. Done 2026-11-12.** Because every chapter has the same 2 x 15-row shape, the geometry (`ACTS`, `ACT_ROWS`, `ROWS`) stays in `RouteMap`; a chapter supplies names, budget curves and bosses (`run/chapter_data.gd`, `run/chapters.gd`, `tests/chapters_tests.gd`). `RouteMap.DISTRICT_NAMES` and `StarterContent.BUDGET_ACT_*` now alias Chapter 1's values and `fight_budget(row, chapter = 1)` reads the chapter; every map and budget is identical. `ChapterData` for Chapter 1; `RouteMap` and `fight_budget` read it; identical maps for the same
   seeds (test against stored golden maps); sims unchanged.
2. **Run state and saves. Done 2026-11-12** (`RunState.chapter`, `chapter_break`, `enter_chapter_break()`, `start_next_chapter()`, `CHAPTER_BREAK_HEAL_FRACTION` 0.75, `RunSave.CHAPTER_VERSION` 6; the deck, gold and relic bounds of a save scale with the rows played over all chapters; a break save must sit on the end boss; `tests/chapter_run_tests.gd`). `Chapters.count_override` lets tests and the later debug stub reach a second chapter. `RunState.chapter`, `chapter_break`, `start_next_chapter()`; save version 6 (only for a run that has reached a
   chapter feature; until then a Chapter 1 run keeps writing v5 so the previous release can read it); v5 loads as Chapter 1; save tests.
3. **Boss reward and break screen. Done 2026-11-12** (`RunState.END_BOSS_GOLD` 60, `BOSS_MIN_RELIC_PRICE` 70, `END_BOSS_FALLBACK_GOLD` 100, `take_boss_spoils()`; `run/screens/chapter_break_screen.gd`; the reward screen's spoils panel is shared with elites; the header names the chapter once more than one exists; `tests/chapter_run_tests.gd`, `tests/ui_chapter_break_test.gd`). Reached only when `Chapters.count() > 1`: a development build with `THE_UNFORGOTTEN_CHAPTERS=2` plays a second chapter (the same content as the first). The break's closing line is one neutral sentence (`ChapterBreakScreen.CLOSING_LINE`) until each character has its own beat. The price floor is 70 because the dearest relic costs 75 (the treasure floor is 65). Original text: (spoils, summary, 0.75 heal, closing beat), reached only when the run has a next chapter. A stub
   Chapter 2 (Chapter 1's enemies, harder budget) behind a debug launch exercises the path.
4. **Sims and bots** run multi-chapter. **Done 2026-11-12:** `tools/run_sim.gd --map --chapters N` (1 to 3; rows count over all chapters; the report adds "Deaths by chapter" and "Runs that reached the break after"; works with `--jobs`). **First finding:** with Chapter 1's content and budget repeated, a run that survives Chapter 1 almost never dies later (200 runs per class, both bots, `--chapters 3`: 0 to 2% of runs die in each of chapters 2 and 3, against 26 to 46% in Chapter 1). So a carried deck outgrows Chapter 1 difficulty completely, and the Chapter 2 and 3 budget curves (section 4) must start clearly above the end of Chapter 1; tune them with this report. Original text:, with per-chapter reports.
5. **Chapter 2 content** (Phase C): districts, enemies, bosses, events, beats, art.
6. **Switch the ending and release.** Chapter 1's end boss leads to the break; "Escaped" moves to the last chapter. Release note needed.

## Writing work

Per chapter break: 1 closing beat per character (4 characters), plus the opening of the next chapter. Chapters 2 and 3 each add 4 map beats
per character. That is the largest writing cost of the whole plan and should be scheduled with the Chapter 2 story arc, not left to the end.

## Risks

- **The constants refactor (step 1)** touches the generator, difficulty, bots, tests and debug launch at once. Keep it behavior-neutral and prove it.
- **90-stop runs** may be too long; the data fields above keep that adjustable.
- **Carried decks make difficulty hard to tune by feel.** Tune from carried-deck sims only.
- **Save compatibility:** v6 cannot be read by older releases. Players who downgrade lose the save; this matches earlier format bumps.
- **Installer size:** see `CHAPTERS_PLAN.md`, Phase C (about 15 to 25 MB per chapter).

## Open decisions for the owner

None open. Settled 2026-11-12: the boss relic uses a price floor (a `BOSS_MIN_RELIC_PRICE` constant, built in step 3) and the end-boss gold is 60.
