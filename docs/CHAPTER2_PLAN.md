# Chapter 2: the plan

**Status: plan, owner decisions applied 2026-11-12. Nothing here is built.** Written after the chapter machinery (steps 1 to 4 of
[`CHAPTERS_DESIGN.md`](CHAPTERS_DESIGN.md)) was committed. Items marked **Decision** are still open; names, enemies and numbers
are proposals meant to be replaced by better ones. Chapter 3 is out of scope here, but every choice below should leave it room.

**Settled by the owner (2026-11-12):**
1. The story leads to **a final boss after Chapter 3's end boss**; the arc below is written for that (so Chapter 3's end boss is not the last fight, and "Escaped" belongs after the final boss).
2. **Each chapter may add new effect kinds** and keep using the existing ones: no full new rule set per chapter, but new mechanics are allowed.
3. **Elite modifiers are in** (Chapter 2 introduces them).
4. **Relics carry over:** any relic from Chapter 1's pool the character does not own yet stays available, and Chapter 2 adds new ones to the same pool (no gating, no removal).
5. **Difficulty target:** each chapter's survival rate is about **15% lower than the previous chapter's** (relative; see "Difficulty").
6. **Order:** build everything that is not art, **bot-test it to confirm it works**, and only then commission the Chapter 2 artwork.
7. **The finale is a single set-piece fight, not a fourth chapter** (after Chapter 3's break: one boss with its own phase two, no map, a save point before it, then "Escaped").
8. **The 15% is relative** (70% becomes about 60%, then about 51%).
9. **Elite modifiers also come to Chapter 1** (in the same release that adds them).
10. **First new effects: File and Unseen** (my recommendation, accepted); more only when a boss or enemy cannot be said without one.
11. **Names:** the owner will confirm or change the proposals in "Names" below.

**Settled elsewhere:** 3 chapters of the same shape (2 districts x 15 rows, a mid-boss and an end boss each); deck, relics, gold and max
HP carry over; the break heals 0.75; an end boss pays a boss relic and 60 gold; the old "Escaped" ending stays until Chapter 2 ships
(`CHAPTERS_DESIGN.md`).

## What the chapter has to do

1. **Answer Chapter 1's question and ask a bigger one.** Chapter 1 ends with the Eraser, a figure carrying a book with every name but the
   player's crossed out, and the breathing door. The player has been following a voice that calls their name.
2. **Feel new, not harder.** The sim finding in `CHAPTERS_DESIGN.md` (step 4) says Chapter 1's content is trivial for a run that survived
   it. Chapter 2 needs its own enemies, its own bosses and a curve that starts above where Chapter 1 ends, and its own look.
3. **Reward the carried deck.** The player arrives with 15 to 25 cards and a few relics. New cards and relics should give that deck new
   directions, not just bigger numbers.
4. **Cost little to build wrong.** Every piece should be playable with placeholder art, so the tuning can start before the painting does.

## Story: the proposal

Chapter 1 is *the quiet*: a memorial city where the dead are kept calm by forgetting their names (the Bellkeeper rings it, the Eraser
crosses names out). The player is someone who remembers.

**Chapter 2: the register.** Beating the Eraser does not open the door; it drops the book. The names are not gone, they are *filed*:
beneath the city is the **Registry**, where everything the quiet took is kept, sorted and sealed. The voice is in there, and it is
calling from a page. The player must go through the Registry to find the page. The chapter's question: *who wrote the names down, and
why does the voice sound like it is reading them?*

**Chapter 3 and the finale (for room only):** Chapter 3's end boss is not the last fight. Chapter 2 plants the answer that makes a final boss
necessary: whoever wrote the names down is still writing, and the voice is that hand's *last entry*. Chapter 3 reaches the place where
the writing happens and beats its warden (the chapter's end boss); the **final boss** is the writer itself, met after Chapter 3's break.
"Escaped" lives after the final boss. So the Registrar (Chapter 2's end boss) must be a *clerk of* the writer, never the writer, and
its last line must point past itself. The finale is one set-piece fight (settled, see above).

### The four beats (per character; today's chapter has four)

| Beat | Where | Job |
| --- | --- | --- |
| Opening, after the break | map start | Arrive in the Registry; the player's name is on a card in a drawer, not crossed out, only *misfiled*. |
| 1 (district 1, early) | row 0 | Meet the first of the clerks; first hint the names are being kept for someone. |
| 2 (district 1, late) | row 13 | The Archivist's hall (the mid-boss). A name the player knows, belonging to a character's own past. |
| 3 (district 2, early) | row 3 | A quiet scene, as Chapter 1's garden: a reading room where people look up, for once. |
| 4 (district 2, late) | row 13 | The way to the end boss; the voice is clearer and it is *reading*. |
| Break | after the end boss | Closing beat that opens Chapter 3 and names the writer without showing it (see "Writing"). |

Each of the 4 classes has its own version of every beat (the Deserter, Thief, Medium and Stray already do for Chapter 1: see
`data/story/<class>/`). That is 6 beats x 4 classes = 24 short texts, plus the neutral fallback for each (6).

**Decision (owner): is this arc the one you want?** The rest of the document depends on the setting ("the Registry"); a different setting
changes names and art, not structure.

## Districts

| | District 1 | District 2 |
| --- | --- | --- |
| Name (proposal) | The Flooded Stacks | The Reading Rooms |
| Feel | Shelving drowned to the waist; the quiet city's rain has seeped down here. Cold, echoing, lamplit. | Dry, high, silent; clerks at desks that nobody has used. Warmer light, much more watched. |
| Mid-boss / end boss | the Archivist | the Registrar |
| Battle backdrop | a new one per district (2) | |
| Rest painting | a new one per district (2) | |
| Map backdrop and node art | reuse Chapter 1's map frame with a new colour tint | |

**Decision:** keep two districts of 15 rows exactly (this is settled), or vary the row layout (forced treasure and rest rows) per
chapter. Recommendation: same layout, so the generator and its 138,000 checks stay as they are.

## Bosses

Both reuse the two-phase machinery of the Eraser and Bellkeeper (`phase_two_intents`, `phase_two_hp_percent`, `phase_two_title`) so no
new engine feature is needed. Each should have **one signature rule** that tests a build, not just HP.

| Boss | HP | Signature (proposal) | Built from |
| --- | --- | --- | --- |
| the Archivist (mid) | about 120 | Files a card of yours away: `ADD_CARD` of a "Filed" status card into your draw pile each turn; a hand of Filed cards is dead weight. Phase two (50%): files three at once. | `ADD_CARD`, `LOSE_HP`, `DAMAGE` |
| the Registrar (end) | about 130 | Reads the player's name aloud: stacks `MALICE` on itself every turn it is not damaged; phase two strips Block and counts down to a large hit that must be answered by a kill, a break (Expose) or enough Block. | `MALICE`, `EXPOSE`, `DAMAGE`, `BLOCK` |

Chapter 1's bosses are 96 HP; Chapter 2 bosses are larger because the carried deck is larger. **The HP numbers are placeholders**; set
them from the sims (`--chapters 2`, below).

**New mechanics are allowed** (owner, 2026-11-12). The bosses above can be built from existing kinds, but one new effect per chapter is welcome
where an existing kind cannot say what the enemy does. Every new `CardEffect.Kind` costs the same list of work, so budget for it:
the enum entry (append-only), the `Combat` rule, the threat model (`THREAT_STATUS_POINTS` in `combat/starter_content.gd`, or the pack builder
will undervalue the enemy), the tooltip and glossary text (`combat/card_glossary.gd`), `docs/RULES.md`, a test, and both bot policies
(`tools/sim_policy.gd`, `tools/smart_policy.gd`) so sims do not mis-play it. Proposed first new effects, to be confirmed one at a time: **File**
(move a card from your hand to the bottom of your draw pile, an enemy intent) and **Unseen** (an enemy that cannot be targeted until the
last other enemy dies).

## Regular enemies: seven new ones

Chapter 1's roster is seven regulars (Ash Hound, Threshold Keeper, Memorial Giant, The Unnamed, Keepsake Crow, The Husher, Stray
Recollection). Chapter 2 gets **seven new ones**, so the two chapters share no enemy: this is the "new, not harder" part.

| # | Enemy (proposal) | Role | Rough shape |
| --- | --- | --- | --- |
| 1 | Ledger Clerk | small, common | alternates a small hit and `ADD_CARD` of a junk card into your discard |
| 2 | Water-Warden | tank | high HP, gains `BLOCK`, one heavy swing every third turn |
| 3 | Stack Wraith | glass hitter | low HP, multi-hit damage (`hits`) |
| 4 | Index Moth | support | `WARD` on allies, applies `FRAYED` |
| 5 | The Misfiled | oddball | changes its pattern when it is the last enemy standing |
| 6 | Pressing Hand | pair-breaker | `EXPOSE` on you, hits harder on an Exposed player |
| 7 | Quiet Scribe | caster | `SHAKEN` and `LOSE_HP`, slow but unavoidable damage |

Each enemy needs: data (`data/enemies/*.tres`), an intent list, a threat value the budget builder can read (automatic from intents,
`StarterContent.enemy_threat`), a figure painting and an idle animation, and a name that fits the Registry. Balance is by the budget
builder, so an enemy's exact numbers matter less than its **role** and its **threat spread**: a pool of 7 should offer a mix of
low-threat 1-enemy and high-threat 3-enemy packs (check with `tools/threat_table.gd`).

**Elites** use the same pool and the same flame-aura treatment, as in Chapter 1. **Elite modifiers are in** (owner, 2026-11-12). Start from the proposals in `docs/MAP_DESIGN.md`, "Elite modifier ideas (not built)", and give
each elite visit one modifier from a short list, shown on the map tooltip, in the battle log and on the spoils screen like the relic drop is. The
modifier is an addition to the budget scaling, so the first sim pass should hold the elite budget at 1.2 and measure what each modifier does to
elite lethality before any budget is changed. Modifiers belong to the engine, not to the chapter, so Chapter 1's elites may get them
too, and Chapter 1's elites get them in the same release (owner, 2026-11-12), one modifier at a time as each is tested.

## Events: eight to twelve new

Chapter 1 has 12 events. Chapter 2 gets **10 new events** with the Registry theme (a card catalogue you may add to, a drowned
reading lamp, a form that asks your name, a clerk who trades). They live in the chapter's own pool; the rules in
[`EVENTS_DESIGN.md`](EVENTS_DESIGN.md) (every event has a free button, each button prints its numbers, gambles print their odds)
apply unchanged. Class variants only where the story wants them.

## Cards and relics

- **Cards:** about a quarter new per class, so **6 new cards per class** (24 total). They should *reward the carried deck's
  commitments*: payoffs for a deck of 25 cards (draw, discard and Forget synergies, Scent and Haunt scaling), not new starters. Each
  class pool is 23 to 26 today; the check requires at least 22.
- **Relics:** **7 new relics** (21 today), priced 70 to 95 so the boss-relic floor (`BOSS_MIN_RELIC_PRICE`, 70) can pick them, which is
  how a chapter-end relic stays special. **They join the same pool** (owner, 2026-11-12): a relic the character did not find in Chapter 1 stays
  available in Chapter 2, and the new ones are available from Chapter 2's first shop, chest or elite. The rolls already skip owned relics, so
  this needs only the pool and the tags below, no new rule.
- **Which cards and relics Chapter 2's rewards offer:** all of them (old and new). The pool grows; Chapter 1's balance is untouched by
  the new cards and relics because they are only offered from Chapter 2 on (a "from chapter" tag, see "Plumbing").

## Difficulty

**The target (owner, 2026-11-12):** each chapter's survival rate is about **15% lower than the previous chapter's**. Read as a relative
figure: if 70% of runs survive Chapter 1, about 60% of the runs that reach Chapter 2 should survive it (70 x 0.85), and about 51% of those
should survive Chapter 3. (If a 15-point drop was meant, say so: 70% would become 55%, which is steeper, and the budgets below would
drop in step.) The numbers are measured per class and per bot, from the Chapter 1 baseline in `docs/SIM.md` (greedy 55 to 72%, smart 54 to
62% across the classes with the map), so each class has its own target. The "survival rate of a chapter" is the share of runs that
**reach its break** among those that **started it**, which is what "Runs that reached the break after" prints.

The Chapter 1 curve runs 34 to 62 (x1.9 difficulty and a per-class factor), and a carried deck is far stronger than that by its end
(the step 4 finding: 0 to 2% of survivors die in chapters 2 and 3 with Chapter 1's budget). Start Chapter 2 around **75** and end around
**105** (district 1 at 75 to 90, district 2 at 90 to 105, before the class factor), then move the numbers until the sim lands on the target.

**How we tune it:**
1. Build the plumbing, the enemies and the bosses with placeholder art.
2. `tools/run_sim.gd --map --chapters 2 --policy greedy|smart --character all --jobs N --runs 200` after each change; read "Deaths by
   chapter" and "Runs that reached the break after". Use 200 runs or more per class: the Wilson interval at 200 runs is about 7 points wide.
3. Move `budget_start` and `budget_end` for the chapter, then the boss HP, then the elite modifiers, in that order, one at a time.
4. Check each class; the Stray is the weakest bot class in Chapter 1 and the Thief lost ground with the keep-5 rule (`docs/NEXT_STEPS.md`).
5. Re-check the bosses' HP at the end of the tuning, not the start: a boss that dies in four turns is a sim finding, not a feel.

The bots do not play around relics, elites or new effects the way a person does, so the sims set the shape and **playtesting** sets the final
numbers.

## Plumbing the code needs (before content)

These are the engine changes the chapter machinery does not yet do. None changes what a Chapter 1 player sees.

1. **A per-chapter enemy pool.** `Encounters.enemy_pool()` returns every enemy in `ALL_ENEMY_PATHS`. Add `ChapterData.enemy_paths` and have
   `budget_encounter` and `varied_encounter` draw from the chapter's pool. Chapter 1's pool must be exactly today's 7 so its maps and fights
   are unchanged (golden test).
2. **Bosses by chapter.** `StarterContent.boss_encounter()` and `mid_boss_encounter()` ignore `ChapterData.mid_boss`/`end_boss`. Read them.
   `Fighter`'s art key table (`run/fighter.gd`), `BattleBackdrop` and the boss intro name the Chapter 1 bosses by id; they need the new ones.
3. **Budget by chapter.** `RunState.start_combat` calls `budget_encounter(stop.enemy_count, _rng, stop.row, ...)`; pass the chapter so
   `fight_budget(row, chapter)` is used (the argument exists already, unused).
4. **Events by chapter.** `StarterContent.all_events()` is global and "seen" tracking assumes 12; add a chapter pool and let `events_seen`
   keep working across chapters (save validation already drops unknown ids).
5. **Story by chapter.** `StoryContent.BEAT_PATHS` has 4 entries and `RouteMap.STORY_LOCAL_ROWS` indexes into them; a chapter needs its own
   list and the route generator must ask the chapter. A story node already stores its `beat_index`; saves keep it as-is.
6. **Cards and relics by chapter.** `ContentRegistry` pools need a "from chapter" tag on new cards/relics, honoured by rewards, the vendor and
   treasure/elite/boss rolls. Old saves hold cards and relics by id, so nothing in a save changes.
7. **Backdrops, rest paintings and districts** by chapter (`DISTRICT_NAMES`, `RouteMap` backdrop tables, `BattleBackdrop`).
8. **Counts that tests pin** (9 enemies, 21 relics, 112 cards, 12 events) become per-chapter counts in `tests/pinned_balance_tests.gd` and
   `docs/GAME_FACTS.md`.
9. **`Chapters.COUNT` and the save bound.** Raise it to 2 only in the release that ships Chapter 2 (step 6 of the design doc); until then
   a development build sets it with `THE_UNFORGOTTEN_CHAPTERS=2` and everything must work behind that switch.

Everything on this list is testable with the existing tools (golden maps, the sims, the pinned counts), and each item is its own PR.

## Art and size

| Piece | Count | Notes |
| --- | --- | --- |
| Regular enemy figures | 7 | 960 x 320 `figure.png`, plus idle layers; the elite aura is generic |
| Boss figures | 2 | larger, with a phase-two look |
| Battle backdrops | 2 | one per district |
| Rest paintings | 2 | one per district |
| Story / event scenes | 6 | one per beat; events reuse a shared set |
| Map frame and node icons | tint of Chapter 1's | little new art |
| Card art | 24 | at the existing resolution (`art/CARD_ART_DESIGN.md`) |
| Relic icons | 7 | existing style (`art/RELIC_ART_DESIGN.md`) |

That is roughly the 15 to 25 MB `CHAPTERS_PLAN.md` estimated, on top of about 123 MiB. Placeholder art (an existing enemy tinted, a gradient
backdrop, a text card) lets every other piece be built and tuned first; painting is the last milestone and does not block sims. Check
`scripts/build_installer.ps1`'s 2/3-of-cap warning when the art lands.

## Writing

| Item | Count |
| --- | --- |
| Story beats | 6 (opening, 4 map beats, break) x 4 classes + 6 neutral = 30 |
| Events | 10 (about 3 lines of text and 2 to 4 buttons each) |
| Enemy and boss names and intent text | 9 |
| Card and relic names and descriptions | 31 |
| Tutorial line | 1 sentence ("more than one chapter") |

The closing beat of Chapter 2 ("the break") must **ask Chapter 3's question**; draft it with the Chapter 3 outline so the chapters join.
Run the new text through the `writegood` skill the way the existing story text was written.

## Order of work

**Art comes last** (owner, 2026-11-12): everything that is not art is built, bot-tested and confirmed working first, with placeholder art, and
the Chapter 2 artwork is commissioned only after that pass. Each item is its own PR with `scripts/check.ps1` green and the sims re-run
when numbers change.

**Gate 1: Chapter 2 plays, in the sim.**
1. **Plumbing 1 to 3** (pool, bosses, budget by chapter) with a **stub Chapter 2** (placeholder enemies cloned from Chapter 1 with new names,
   its own curve), behind `THE_UNFORGOTTEN_CHAPTERS=2`. Done when a two-chapter sim runs and the Chapter 1 golden maps and tests are unchanged.
2. **The seven enemies and two bosses as data**, including their new effects, placeholder art, bots that handle the new effects. Tune the
   curve and the boss HP against the target above.
3. **Elite modifiers** (engine first, then the shortlist), measured in the sim.

**Gate 2: Chapter 2 is complete without art.**
4. **Plumbing 4 to 7** (events, story, cards and relics, backdrops by chapter).
5. **Events (10)** and **story beats (30)**, in one writing pass.
6. **Cards (24) and relics (7)**, then re-run the sims for every class and both bots; the survival target must hold for the Stray and the Thief too.
7. **The bot confirmation:** a full `--chapters 2` sim (200 runs per class, both policies, with `--jobs`), the existing tests and the check
   all green, and the numbers written into `docs/SIM.md`. This is the gate: nothing is painted before it passes.

**Then the artwork.**
8. **Art**, enemies and bosses first (the most visible), then backdrops and rest paintings, then card and relic art.
9. **Tune with testers** (`docs/PLAYTEST_CHECKLIST.md`, with a Chapter 2 section), then step 6 of `CHAPTERS_DESIGN.md`: switch the ending, set
   `Chapters.COUNT = 2`, release.

## Names (proposed: confirm or change)

Chapter 1's names are plain and a little sorrowful (Ash Hound, Threshold Keeper, The Unnamed, the Bellkeeper, the Eraser). These follow the
same voice: an office or object, never a monster word. Ids are the snake_case file names (`data/enemies/<id>.tres`).

| Thing | Proposed name | Id | Note |
| --- | --- | --- | --- |
| Chapter | Chapter 2: The Registry | `chapter_2` | the player-facing title, also shown at the break |
| District 1 | The Flooded Stacks | - | `DISTRICT_NAMES` |
| District 2 | The Reading Rooms | - | |
| Mid-boss | the Archivist | `the_archivist` | files cards away (File) |
| End boss | the Registrar | `the_registrar` | reads your name aloud; a clerk of the writer |
| Chapter 3 end boss | the Warden of the Inkwell | `the_inkwell_warden` | placeholder, for room only |
| Final boss | the Scrivener | `the_scrivener` | the writer; the finale |
| Enemy 1 | Ledger Clerk | `ledger_clerk` | small, adds junk to your discard |
| Enemy 2 | Drowned Porter | `drowned_porter` | tank, Block, one heavy swing |
| Enemy 3 | Shelf Wraith | `shelf_wraith` | multi-hit glass hitter |
| Enemy 4 | Index Moth | `index_moth` | support, Ward and Frayed |
| Enemy 5 | The Misfiled | `the_misfiled` | changes pattern when alone; the Unseen enemy |
| Enemy 6 | Pressing Hand | `pressing_hand` | Expose, hits an Exposed player harder |
| Enemy 7 | Copyist | `copyist` | Shaken and HP loss, slow and unavoidable |
| New effect | File | `Kind.FILE` | an intent: send a card from your hand to the bottom of your draw pile |
| New effect | Unseen | `Kind.UNSEEN` | an enemy cannot be targeted while another enemy lives |
| Elite modifier | Plated | - | starts with Block (MAP_DESIGN idea 1) |
| Elite modifier | Enraged | - | second intent cycle at half HP (idea 2) |
| Elite modifier | Marked | - | the player starts the fight Exposed or Shaken (idea 4) |

Idea 3 of `MAP_DESIGN.md` (a named elite roster) is a separate system and is not part of this list. Events, cards and relics are named
when they are written (milestone 5 and 6 of "Order of work"), not here.

## Decisions for the owner

Answered 2026-11-12: the story, new effects, elite modifiers (Chapter 1 included), carried-over relics, the relative 15% target, the finale
as one set-piece fight, the first new effects (File, Unseen) and art last. Still open:

1. **Names:** the table above. Reply with changes; nothing is built under a name until it is confirmed (a rename after the files exist
   means renaming data files, ids in saves and art keys).
2. **The finale's details** (not urgent, before Chapter 3): where the save point sits, whether the player gets one last shop or rest before it, and
   whether the final boss has more than two phases.
