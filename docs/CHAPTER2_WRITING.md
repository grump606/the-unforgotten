# Chapter 2: the writing outline (events and story beats)

**Status: outlines for the owner's approval. No event or story text is written or built yet.** Written 2026-11-12. This is the writing pass
of `CHAPTER2_PLAN.md` (item 5). Approve, change or strike anything; full text follows only after you do. Voice: Chapter 1's (plain, quiet,
a little sorrowful, no monster words). The Registry setting is in `CHAPTER2_PLAN.md`.

**Correction to the plan's count.** A chapter's map has **four** story rows (`RouteMap.STORY_LOCAL_ROWS`: district 1 rows 0 and 13, district 2
rows 3 and 13), and the first of them *is* the arrival, so Chapter 2 needs **four map beats plus one closing beat for the break = 5 beats**
(not 6), each in 4 class versions (20 texts) and a neutral fallback (5): 25 texts in all.

## Story: the five beats

The spine, in one line each, then how each class meets it. Every beat is a title, about 70 to 110 words and a button line, like Chapter 1's.

| # | Where | Title (proposal) | What happens |
| --- | --- | --- | --- |
| 1 | district 1, row 0 (the arrival) | A Name, Misfiled | The player comes down into the Registry, water to the knee. In a drawer is a card with their name, *not crossed out*: only filed in the wrong place. Someone kept it. |
| 2 | district 1, row 13 (before the Archivist) | The Kind Archivist's Hall | A hall of sealed drawers. The Archivist says everything is safe here, that nobody is lost, only kept. It keeps the names *for someone*. It will not say who. |
| 3 | district 2, row 3 (the quiet scene) | The Reading Room | Dry, lamplit, silent. For once the people look up. One reads aloud from a ledger, in the cadence of the voice that has been calling. |
| 4 | district 2, row 13 (before the Registrar) | The Registrar's Desk | The voice is clear: it is *reading*. The Registrar, a clerk, says it only copies; the one who writes is farther in. |
| 5 | the break, after the Registrar | The Last Entry | The ledger turns to a last page. The player's name is being written, the ink still wet, by a hand that is not finished. The way down opens. (Chapter 3 begins here.) |

**Plants for the final boss** (settled: a final boss after Chapter 3's end boss): whoever *writes* is still writing, and the voice that has been
calling is that hand's last entry (beats 4 and 5). The Registrar is a clerk of the writer and never the writer.

### How each class meets the beats

| Class | Their angle (a few words, the rest is the writing) | Beat 1 card | Beat 3 reader says |
| --- | --- | --- | --- |
| Deserter | duty, the signal in the dark, a leaving they regret | a service record: "absent", never "deserted" | the names in the order of a roll call |
| Thief | keys, doors, things that were never theirs to keep | a key tag: "returned", filed under strangers | a list of what was taken, in the voice of the voice |
| Medium | the dead speak first; this time someone is speaking *to* them | the card is warm and the handwriting is a voice | the dead's own words, read back to them |
| Stray | scent, loyalty, a name known by smell more than sound | a collar tag, smelled before it is read | a name said the way they were once called home |

## Events: ten

Rules from `EVENTS_DESIGN.md` hold: every event has a free button (a plain leave or a free gain); each button prints its numbers;
gambles print their odds; HP costs never go below 1; a relic button pays 40 gold when no relic is left. Numbers below are first
guesses in the style and scale of Chapter 1's twelve (heals about a third lower than the first draft, because map fights heal you).
`only_for` and `class_*` are the existing per-class hooks. All ten use **existing effect kinds only**.

| # | Id | Title | Scene (one line) | Buttons (cost, then reward) | Class twist |
| --- | --- | --- | --- | --- | --- |
| 1 | `card_catalogue` | The Card Catalogue | A cabinet of drawers, one open, water to the brass handles. | **Pull the open drawer:** lose 6 HP, choose 1 of 3 uncommon class cards. **Flip through quickly:** a random neutral card. **Close it.** | Medium finds a card in their own hand; Thief picks the lock first (no HP cost) |
| 2 | `drowned_lamp` | The Drowned Reading Lamp | A lamp still lit under a foot of water. | **Sit and read by it:** heal 12% HP. **Lift it out:** 50% a neutral relic, else lose 8 HP. **Leave it burning.** | Stray drinks and finds the water clean |
| 3 | `the_form` | The Form | A form on a desk: *Name: ____*. A dry pen. | **Write your name:** pay 20 gold, gain 2 max HP. **Write another:** gain 50 gold, a Dread. **Leave it blank:** heal 4% HP. | Deserter writes the unit number; Thief has the wrong name ready (the Dread is free) |
| 4 | `clerk_who_trades` | The Clerk Who Trades | A clerk behind a grille, ledger open, who will take anything *filed*. | **Surrender a card:** remove a card, gain 25 gold. **Buy a file:** pay 60 gold, choose 1 of 3 rare class cards. **Decline.** | Thief haggles (the file costs 50) |
| 5 | `flooded_aisle` | The Flooded Aisle | A long aisle, shelves to the ceiling, the water chest-deep. | **Wade through:** lose 6 HP, gain 40 gold. **Carry the books up:** lose 3 HP, Remember a card. **Wait for it to fall:** heal 8% HP. | Stray swims it (no HP cost on Wade) |
| 6 | `misdelivered_letter` | The Misdelivered Letter | A letter with your name on it, stamped *Return to sender*. | **Open it:** 50% a neutral relic, else a Murmur. **Return it:** gain 20 gold. **Burn it.** (nothing) | Medium hears who wrote it; the Murmur is theirs |
| 7 | `the_stamp` | The Stamp | A rubber stamp on a pad, *APPROVED* in red. | **Stamp yourself:** lose 8 HP, gain 4 max HP. **Stamp a card:** Remember a card, lose 5 HP. **Put it down.** | Deserter's stamp reads *DISCHARGED* (no HP cost on the first button) |
| 8 | `silent_patron` | The Silent Patron | A reader at a desk, upright, very still, a ledger under one hand. | **Sit beside them:** heal 10% HP. **Ask what they are reading:** lose 7 HP, choose 1 of 3 uncommon class cards. **Let them read.** | Medium is read *to* (heal 14%) |
| 9 | `overdue_notice` | The Overdue Notice | A notice nailed to a shelf, your name, a fine. | **Pay the fine:** pay 45 gold, remove a card. **Argue it:** 45% gain 60 gold, else lose 10 HP. **Walk away.** | Thief is the one who nailed it up (free removal, no fine) |
| 10 | `back_stacks` | The Back Stacks | A door marked STAFF, ajar, a draught of dry air behind it. | **Force it:** lose 12 HP, a neutral relic. **Look through the gap:** gain 30 gold, lose 4 HP. **Close it.** | Stray catches a scent that opens it (no HP cost on Force) |

Why these ten: a spread of costs (HP, gold, max HP, a curse), rewards (a card, a pick of three, a relic, a Remember, a removal, gold, healing), and risk
(three gambles or curses) so no one event is the obvious best, matching Chapter 1's mix. Two events (the Form, the Overdue Notice) ask *what you
will give up*, which is the chapter's theme; two (the Lamp, the Patron) are rests with a catch.

**Open design question:** the neutral relic pool is small (four), so Chapter 2's new relics should include **neutral ones** or several of these buttons will
pay the 40-gold fallback early. This is a request for the relic design pass (milestone 6), not a change to the events.

## What I need from you

1. **The five beats:** keep the spine and the five titles, or change any? (The break beat, "The Last Entry", is the one that matters most for Chapter 3.)
2. **The class angles:** right voices for the four classes?
3. **The ten events:** strike, swap or reword any; flag any you dislike. I would keep at least one event with a Dread or Murmur as a real cost.
4. **Length:** beats at about 70 to 110 words each (Chapter 1's are about that); say if you want them longer.

When you approve, I write all 25 beat texts and the 10 events (with class variants), run them through the `writegood` skill, add them to the
Chapter 2 lists (`CHAPTER_BEAT_PATHS`, `CHAPTER_EVENT_PATHS`), and the sims and tests confirm nothing broke.
