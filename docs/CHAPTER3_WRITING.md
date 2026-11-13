# Chapter 3: the writing outline (events and story beats)

**Status: the 35 story texts are written (2026-11-13, on the owner's "continue with your recommendations"; the outline was not individually reviewed, so expect edits).** They are in `data/story/chapter3/` (neutral) and `data/story/<class>/`, registered in `StoryContent.CHAPTER_BEAT_PATHS`, `BREAK_BEAT_PATHS` and `FINALE_BEAT_PATHS`; the finale's "before" text shows on the break screen above the "Face the Scrivener" button and "after" on the escape end card; `tests/chapter3_story_tests.gd` checks shape. The events below are still a proposal. Not yet run through `writegood`.
only after you do. Voice: Chapter 1's (plain, quiet, a little sorrowful, no monster words). Setting and spine: `CHAPTER3_PLAN.md` (the Scriptorium; the
Scrivener is the first of the forgotten who cannot stop remembering; the escape is the one name it cannot finish).

## Story: the beats

Four map beats (district 1 rows 0 and 13, district 2 rows 3 and 13), the closing beat at the break, and the finale's two texts (before and after the
fight). That is 7 texts x 5 versions (four classes and a neutral fallback) = **35 texts**, about 70 to 110 words each (the finale's two a little longer).

| # | Where | Title (proposal) | What happens |
| --- | --- | --- | --- |
| 1 | district 1, row 0 | The Dry Stair | The stair ends in dry air. Desks, pens, the sound of writing. The first pages are the names from Chapter 1's book, written out clean. |
| 2 | district 1, row 13 (before the Blotter) | The Blotter's Alcove | A keeper of the wet ink warns that whoever writes is not unkind, only unable to put the pen down. |
| 3 | district 2, row 3 (the quiet scene) | The Margin | The margins are full of small marks, each a name someone almost kept. Yours is not among them, because it has been written in full. |
| 4 | district 2, row 13 (before the Warden) | The Warden's Door | The Warden of the Inkwell guards the last door and says what it guards is not a prison. |
| 5 | the break after the Warden | The Foot of the Page | The player reads their own entry to its end and finds the last line blank. |
| 6a | the finale, before | The Last Name | The Scrivener speaks: it has remembered everyone, and cannot remember how to stop. It asks to be told one name it cannot finish. |
| 6b | the finale, after (the escape) | The Door That Opens | The pen falls. The last line is filled in, by the player, in their own hand. Someone speaks your name; this time you answer. |

### How each class meets them

| Class | Angle | Beat 1 | Beat 3 (the Margin) | Finale (the name it cannot finish) |
| --- | --- | --- | --- | --- |
| Deserter | duty; a roll call that never ends | the names are in roll-call order, one gap at the end | a tick beside every name but theirs | their own rank and number, said aloud for the first time since |
| Thief | price tags; everything listed, nothing owned | each name has a value pencilled beside it | the marks are tallies of what each person owned | the one thing they never priced: their name |
| Medium | the dead are all here, waiting to be asked to leave | the pages are warm and the writing is a murmur | the marks are the dead, trying to speak through the paper | the dead's own name for the Scrivener, which it has never been told |
| Stray | the name it was called at the door | the pages smell of ink and of home | a small mark that smells like a hand it knew | the name it was called in from the cold with |
| Neutral | a plain second-person version | as the table above | as the table above | a name the player chooses by not choosing |

## Events: ten

Rules from `EVENTS_DESIGN.md` hold: every event has a free button; each button prints its numbers; gambles print their odds; HP costs never go below 1; a relic
button pays 40 gold when no relic is left. Numbers are first guesses at Chapter 2's scale. **Existing effect kinds only.** Class twists use `only_for` and `not_for`.

| # | Id | Title | Scene | Buttons (cost, then reward) | Class twist |
| --- | --- | --- | --- | --- | --- |
| 1 | `copy_desk` | The Copy Desk | A desk with a half-copied page of your own deck. | **Finish the copy:** pay 30 gold, add a copy of a card in your deck. **Strike a line:** remove a card, lose 5 HP. **Leave it.** | Thief copies it free |
| 2 | `blotter_pad` | The Blotter Pad | A pad that has soaked up every name written on it. | **Press your hand to it:** lose 8 HP, choose 1 of 3 uncommon class cards. **Read the mirror-writing:** gain 35 gold, a Murmur. **Turn it over.** | Medium reads it without the Murmur |
| 3 | `self_writing_pen` | The Pen That Writes Itself | A pen moving over a page, in your hand's own slant. | **Let it finish the line:** 50% a neutral relic, else lose 9 HP. **Take the pen:** gain 2 max HP, a Dread. **Set it down.** | Deserter's pen writes a service record (no Dread) |
| 4 | `bell_for_silence` | The Bell for Silence | A brass bell, a card: *Ring for quiet.* | **Ring it:** heal 14% HP. **Ring it twice:** heal 22% HP, lose 8 HP. **Leave it.** | Stray rings it by nosing the cord (the second ring is free) |
| 5 | `letter_to_yourself` | A Letter to Yourself | Your name, your hand, a date that has not happened. | **Open it:** Remember a card. **Answer it:** pay 25 gold, gain 3 max HP. **Seal it back.** | Medium hears the letter read in someone else's voice (gain 15 gold too) |
| 6 | `ink_well_deep` | The Deep Inkwell | A well of ink, a ladder, a glint at the bottom. | **Climb down:** lose 10 HP, a neutral relic. **Dip a card:** Remember a card, lose 4 HP. **Look and go.** | Stray follows the glint by smell (no HP cost to climb) |
| 7 | `proofreader` | The Proofreader | A reader with a red pencil, marking errors in strangers. | **Be corrected:** remove a card, pay 40 gold. **Correct them:** gain 45 gold, lose 6 HP. **Walk on.** | Thief hands over the pencil first (the removal is free) |
| 8 | `lamp_of_the_scriptorium` | The Great Lamp's Spill | A pool of lamplight on a floor otherwise dark. | **Stand in it:** heal 10% HP. **Gather it:** 50% gain 60 gold, else lose 8 HP. **Step around.** | Deserter stands watch in it (heal 14%) |
| 9 | `the_index_of_names` | The Index of Names | A cabinet index; one card is yours, the rest are blank. | **Take your card:** gain 2 max HP, lose 6 HP. **Add a name:** pay 20 gold, choose 1 of 3 rare class cards. **Close the drawer.** | Medium finds a card in the dead's hand |
| 10 | `the_unwritten_page` | The Unwritten Page | One blank page in a bound book, kept apart. | **Write on it:** choose a card to transform into a random one. **Tear it out:** gain 40 gold, a Dread. **Leave it blank.** | Stray leaves a pawprint (gain a free card of the class's uncommons instead) |

(If "transform a card" or "add a copy" has no matching event effect, the button is rebuilt from the existing kinds; I will check against `event_effect.gd` before writing.)

Why these ten: the Scriptorium's theme is **what you let be written about you**. Four ask what you will give up (the Copy Desk, the Proofreader, the Index, the Letter), two are rests
with a catch (the Bell, the Lamp), and the rest are gambles or curses, so the mix matches Chapters 1 and 2. At least two carry a Dread or Murmur as a real cost.

## What I need from you

1. **The beats:** keep the spine and titles, or change any? The finale's two texts matter most.
2. **The class angles** for the finale (the "name it cannot finish").
3. **The ten events:** strike, swap or reword any.
4. **Length:** about 70 to 110 words per beat; say if you want more.

When you approve, I write the 35 texts and the 10 events, run them through the `writegood` skill, register them, and run the sims and tests.
