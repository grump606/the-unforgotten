# Chapter 3 and the finale: the plan

**Status: plan, all seven owner decisions answered 2026-11-13 (see the end). Nothing here is built.** Written after v0.10.0 (Chapter 2) shipped. Names, enemies and numbers are still proposals to tune. It follows the shape of [`CHAPTER2_PLAN.md`](CHAPTER2_PLAN.md), which worked, and
reuses everything the chapter machinery already does ([`CHAPTERS_DESIGN.md`](CHAPTERS_DESIGN.md)).

**Settled earlier (owner, 2026-11-10 to 2026-11-12):** 3 chapters of the same shape (2 districts x 15 rows, a mid-boss and an end boss each); deck,
relics, gold and max HP carry over and the break heals 0.75; an end boss pays a boss relic and 60 gold; the story has **a final boss after Chapter 3's
end boss, a single set-piece fight and not a fourth chapter**; each chapter may add new effects; relics carry over and new ones join the pool; each
chapter's survival is about 15% lower than the previous one (relative); art comes last, after a bot confirmation.

## What is already in place for Chapter 3

- `Chapters.chapter(3)` exists as a **stub** (Chapter 1's enemies, bosses and names, on a 84 to 100 budget curve, `Chapters.STUB_CURVES[3]`); `--chapters 3` runs it in the sim.
- Per-chapter plumbing for enemy pools, bosses, events (`CHAPTER_EVENT_PATHS`), story beats (`CHAPTER_BEAT_PATHS`, `BREAK_BEAT_PATHS`), cards and relics
  (`from_chapter`), backdrops (`ChapterData.shared_backdrops`, `mid_boss_backdrop`, `boss_backdrop`, `story_moods`), class budget factors and boss factors.
- The break, the boss reward, saves (format 6 holds the chapter) and the multi-chapter sim report.
- **The open-ended ending**: today the last built chapter's end boss ends the run with "To be continued" (`Chapters.open_ended()`); shipping Chapter 3 means
  `COUNT = 3`, which makes `COUNT == PLANNED` and turns that off.

## What is new in Chapter 3

1. **The story's answer.** Chapter 2 ended on the Last Entry: your name being written in wet ink by a hand that is not finished, and a stair going down.
   Chapter 3 goes down it.
2. **The finale**, a fight that is not a map and not a chapter: the writer itself.
3. **Escaped** returns, after the final boss.
4. **Difficulty:** Chapter 3 survival about 15% below Chapter 2's, then the finale on top.

## Story: the proposal

Chapter 1 was the quiet that forgets, Chapter 2 the Registry that files. **Chapter 3 is the Scriptorium**, where the names are written: a vast, dry, lamplit
room under the Registry, a place of desks, pens and unfinished pages. The hand that has been writing your name is the **Scrivener**; the voice that called
you was its last entry, read aloud by its clerks. The question Chapter 3 answers: *why does it write?* The answer (proposal, to keep or change): the Scrivener
is the first of the forgotten, the only one who could not stop remembering, who has been writing every name down so that no one is ever lost, and
it has learned that a name written down is a name kept, and that a name kept is a name that cannot leave. It is not cruel. It cannot stop. The exit the player
has been following is real, and it is the one thing the Scrivener has never been allowed to write.

The final fight is therefore a **choice made as combat**: the player does not win by being stronger but by being the one name it cannot finish. (How that plays
is the finale design below.)

### The six beats (per character, as in Chapter 2: four map beats and a closing beat, plus the finale's own two)

| # | Where | Title (proposal) | What happens |
| --- | --- | --- | --- |
| 1 | district 1, row 0 | The Dry Stair | The stair ends in dry air. Desks, pens, the sound of writing. The first pages are the names from Chapter 1's book, written out clean. |
| 2 | district 1, row 13 | The Blotter's Alcove | A keeper of the wet ink warns that the one who writes is not unkind, only unable to put the pen down. |
| 3 | district 2, row 3 | The Margin | A quiet scene: the margins of the pages are full of small marks, every one a name someone almost kept. Yours is not among them, because it has been written in full. |
| 4 | district 2, row 13 | The Warden's Door | The Warden of the Inkwell guards the last door, and says what it guards is not a prison. |
| 5 | the break after Chapter 3 | The Foot of the Page | The player reads their own entry to its end and finds the last line blank. |
| 6 | the finale | The Last Name (before) and The Door That Opens (after) | The Scrivener speaks; the fight; and the outcome that replaces "To be continued" with the escape. |

Each class keeps its angle from Chapter 2's writing outline: the Deserter's duty (a roll call that never ends), the Thief's price tags (everything is
listed and nothing is owned), the Medium's dead (they are all here, waiting to be asked to leave) and the Stray's name (the one it was called at the door).
That is 6 beats x 5 versions = **30 texts**, as in Chapter 2.

**Decision (owner): is this the answer you want to give?** It changes the final boss's nature, the finale's mechanics and the ending text, so it comes before everything else.

## Districts and bosses

| | District 1 | District 2 |
| --- | --- | --- |
| Name (proposal) | The Dry Stacks | The Scriptorium |
| Feel | The reading rooms' dry cousin: papers stacked like walls, lamps, no water left. Quiet. | Long rows of copying desks under one great lamp; a ceiling you cannot see; the sound of a thousand pens. |

| Boss | HP (placeholder) | Signature (proposal) | Built from |
| --- | --- | --- | --- |
| the Blotter (mid-boss) | about 180 | Soaks the page: each turn it adds a Blot card to your draw pile and its Block grows by what you spend; phase two (50%): the Blots come in pairs and it hits harder while any are in your hand. | `ADD_CARD`, `BLOCK`, `DAMAGE`, a new effect (see below) |
| the Warden of the Inkwell (end boss) | about 175 | Guards the last door with a count: it files and crosses out your cards on a timer, and phase two stops the timer if you break its Block. | `FILE`, a new effect, `BLOCK`, `DAMAGE` |
| the Scrivener (final boss, the finale) | about 260 across phases | See "The finale" | new effect(s), `FILE`, `MALICE`, `EXPOSE` |

## New effects: proposals (each costs the list of work in `CHAPTER2_PLAN.md`)

1. **Cross Out** (a card effect and an intent): sends the dearest card in your hand to the **Forgotten pile** for the fight (Chapter 2's File sends it to the bottom of the draw
   pile; Cross Out takes it out of play, which the Medium's Forgotten engine can turn to advantage and the Deserter cannot). **Recommend building it.**
2. **Blot**: a Dormant status card (like Dread and Murmur, `data/status/`) that costs HP if it is still in your hand at the end of your turn. This needs a small new
   rule (a Dormant card with an end-of-turn cost) and a tooltip line. **Optional**; the same pressure can be made from Dread with no engine change.
3. **Unwritten** (an enemy trait, like Unseen): an enemy that does not take damage until a condition is met (for example until its Block is gone). **Maybe**, for the Warden.

**Decision:** which of these, if any. Recommendation: Cross Out only, and use Blot as a data-only status card made from the Dormant keyword.

## The finale: the Scrivener

A single set-piece fight after Chapter 3's break. Everything is existing machinery except the **flow**:

- **Flow.** Chapter 3's end boss pays its relic and gold, the break shows the closing beat and heals 0.75 (as before), and then the player's button reads **"Face the Scrivener"**.
  A save is made at the break, before the fight, so quitting here resumes here. The fight is a normal combat stop (a `RunState` stop with `finale = true`, no map, no
  reward screen). Winning it ends the run as an **escape**; losing it ends the run as a defeat, as any fight does.
- **The fight.** Three phases, switching at 66% and 33% of its HP (the engine has two-phase enemies today; a third phase needs a small extension of `EnemyData`, or the Scrivener is
  three linked enemies that appear in turn, which needs none). Each phase retells one chapter: phase one it **forgets** (Cross Out, Chapter 1's quiet), phase two it **files**
  (File and Dread, Chapter 2's Registry), phase three it **writes** (it names a card of yours each turn and that card is played against you; the only counter is to break its Block).
  It cannot be out-damaged cheaply: its HP is the largest and it heals a little each turn it is not damaged, so the player has to keep up pressure.
- **Difficulty.** Not budgeted; a fixed fight with a per-class factor (`boss_class_factor`) like the other bosses. Target: the finale's loss rate for those who reach it is **15% of
  them** (the other bosses lose 0.5 to 5%): a real final exam, not a coin flip. Tuned in the sim over 400 runs per class and bot, like the Registrar.
- **One last rest or shop?** **Decision (open):** none (the break is the rest), or a single rest between the break and the fight. Recommendation: none; the break heals 0.75 already.

## Regular enemies: seven new ones (names proposed, as for Chapter 2)

| # | Enemy | Role | Rough shape |
| --- | --- | --- | --- |
| 1 | Inkwell Imp | small | a hit, then Blot (a Dread) into your draw pile |
| 2 | Pen Knight | big tank | high HP, Block, a heavy thrust every fourth turn |
| 3 | Blotter | caster | Shaken and Frayed, slow, unavoidable |
| 4 | Penwiper | glass hitter | multi-hit damage |
| 5 | Scroll Mother | support | Ward on the others, a heal; the first enemy that **heals allies** (existing `HEAL`? to be checked) |
| 6 | The Unfinished | oddball | Unseen, and **Cross Out** (the first enemy to use it) |
| 7 | Ledger Wolf | pair-breaker | `EXPOSE` on you, hits an Exposed player harder |

Elites use the same pool and the existing modifiers (Plated, Enraged, Marked); **Decision:** a fourth modifier for Chapter 3, or none (recommendation: none, the three are enough).

## Events, cards and relics

- **Events:** 10 new, in the Scriptorium's voice (a copy desk, a blotter, a pen that writes by itself, a bell for silence, a letter to yourself); same rules as Chapter 2's ten (a free
  button, prices printed, class twists). Outline first, text after approval, as for Chapter 2.
- **Cards:** 6 new per class (24), payoffs for a deck that has carried two chapters. **Relics:** 7 new (three neutral, one per class), priced 80 to 100; the boss-relic floor (`BOSS_MIN_RELIC_PRICE`
  70) already picks them.
- **Tags:** `from_chapter = 3`; nothing from Chapters 1 or 2 is removed.

## Difficulty and the targets

- Chapter 3 survival of Chapter 2's survivors about **15% below Chapter 2's**, per class (mean of the greedy and smart bots), then the finale's 15% loss rate on top.
  First guess for the curve: 84 to 100 as the stub has it; tune it as for Chapter 2 with the per-class factors.
- Re-check Chapter 2's numbers with Chapter 3's cards in the pool: Chapter 3 cards are `from_chapter = 3`, so they do not change Chapter 2, but the carried decks
  that reach Chapter 3 will be stronger than the bots' Chapter 2 decks. The sim already measures that with `--chapters 3`.
- The bot confirmation (Gate 2) is again the gate before any art: 400 runs per class and bot with `--chapters 3`, the full finale included.

## Plumbing the code needs (before content)

1. **The finale stop.** A `RunState` state after Chapter 3's break: `start_finale()`, the combat built from `ChapterData` (`finale_boss_path`), no map, no reward, `escaped = true` on a win.
   `RunSave` needs the state (format 6 gains `finale: bool`, or a chapter number of 4). The break screen's button reads "Face the Scrivener" in that case.
2. **A three-phase enemy** (or three linked enemies). `EnemyData` has `phase_two_*`; add `phase_three_*` or compose the Scrivener of three enemies that replace each other.
3. **`Chapters.COUNT = 3`**, which turns `open_ended()` off, and `PLANNED` stays 3.
4. **The end screen** after the finale: "Escaped", the escape painting and the line "Someone speaks your name. This time, you answer." come back, with the Chapter 3 closing beats before them.
5. **Sims and bots**: a run now ends in a fight, so `run_sim` must play the finale (it is a combat stop) and report its loss rate separately.
6. **Backdrops and the debug launch** for Chapter 3's bosses and the finale.

## Art and size

| Piece | Count | Notes |
| --- | --- | --- |
| Regular enemy sprites and elite auras | 7 + 7 | the Chapter 2 recipe |
| Boss sprites | 2, plus the Scrivener in three looks (or three sprites) | the finale needs the most art of any fight |
| Battle backdrops | 6 (four regular, mid-boss, boss) + 1 for the finale | |
| Story paintings | 4 + 2 for the finale | |
| Card art | 24 | |

Chapter 2 added about 42 MB of PNG and the installer is 158 MiB. Chapter 3 would add about 45 MB, so roughly **175 to 185 MiB**: above the 2/3-of-cap warning (200 MiB is 2/3 of 300),
close to it. `MAX_INSTALLER_BYTES` (the in-game cap, 300 MiB) must be raised **one release before it is needed**, and `docs/UPDATE_CHECK.md` ("Installer size cap") says how. Consider
shrinking the backdrops (lossy export, 1280x720) before Chapter 3's art.

## Order of work

Each item is its own PR with `scripts/check.ps1` green and the sims re-run when numbers change; art comes last.

**Gate 1: Chapter 3 plays in the sim, with a stub finale.**
1. The finale stop and the three-phase enemy, behind `THE_UNFORGOTTEN_CHAPTERS=3`, with a stub Scrivener (a re-skinned Registrar). Chapter 1 and 2 behaviour unchanged.
2. The new effect(s), the seven enemies, the three bosses as data; tune the curve and the finale against the targets.

**Gate 2: Chapter 3 is complete without art.**
3. Events (10) and story beats (30), written after the outline is approved.
4. Cards (24) and relics (7), then re-run the sims for every class and both bots.
5. **The bot confirmation** (`--chapters 3`, 400 runs per class and bot), written into `docs/SIM.md`.

**Then art and the release.**
6. Art (the Chapter 2 recipe in `art/PROMPTS.md`), then a playtest, then `Chapters.COUNT = 3`, the version bump and `scripts/release.ps1` (raise the installer cap one release earlier).

## Decisions for the owner

**All answered 2026-11-13:**

1. **The story's answer:** the Scrivener is the first of the forgotten, who could not stop remembering and writes every name so that no one is lost; a kept name cannot leave; the escape is the one name it cannot finish.
2. **Names:** the proposals stand (the Scriptorium, the Dry Stacks, the Blotter, the Warden of the Inkwell, the Scrivener, the seven enemies).
3. **New effects:** **Cross Out only.** Blot is made from a Dormant status card with no new rule; no Unwritten trait.
4. **The finale's shape:** **extend `EnemyData`** with phase-three fields (the Scrivener is one enemy with three phases at 66% and 33% HP). Target loss rate **about 15%** of those who reach it.
5. **Before the finale:** **nothing**; the break (heal 0.75, a save) is the rest.
6. **A fourth elite modifier:** **no**.
7. **The installer cap:** **raise `MAX_INSTALLER_BYTES` in the next patch release** (v0.10.x), one release before Chapter 3 needs it (`docs/UPDATE_CHECK.md`, "Installer size cap"). Done 2026-11-13 on `main` (300 to 400 MiB, for v0.10.1). Note: Chapter 3's installer (about 175 to 185 MiB) is under the old 300 MiB cap too, so v0.10.0 players could take it in-game either way; the raise is headroom for later.

Next: the v0.10.x patch that raises the cap (and fixes anything the Chapter 2 playtest finds), then Gate 1 of "Order of work".
