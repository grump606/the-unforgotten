# Event stops ("?" nodes)

An event is a short story encounter on the route map: a few lines of scene text and two to four buttons that trade HP, gold,
cards and relics. It takes the place of a fight in its row, so it is an optional branch like a rest or a shop. This document is
the spec of how events work and the twelve events as shipped. The map side (layout, weights, measured numbers) is in
`docs/MAP_DESIGN.md`, "Phase 4c".

## The rules the player sees

- Every button prints what it costs and what it gives under its label ("Lose 8 HP. Remember a card."). The line is generated from the
  button's effects, so the printed numbers are always the data's numbers.
- The only randomness is a gamble, and a gamble prints its odds on the button ("40%: Gain a random relic. Otherwise: nothing").
- HP costs never take HP below 1 and never disable a button. A gold payment the player cannot make greys the button, with the reason
  under it ("Needs 70 gold (you have 10)."). A card removal needs a second card in the deck, a Remember needs a card that can be
  Remembered, and a relic button needs a relic left to find; otherwise the button is greyed with the reason.
- Every event has a button that costs nothing (a plain leave, or a free gain), whatever the class, HP and gold. `tests/event_tests.gd`
  checks this at 0 gold and 1 HP for all twelve events and all four classes.
- An event cannot repeat inside a run until all twelve have been shown; then the pool is reshuffled.
- Class variants change flavour text and add bonus buttons; two numbers differ by class (the Thief's odds at the window, the Thief's price
  at the well).

## How it runs

`RouteMap.NodeType.EVENT` (8) plays as `RunState.StopType.EVENT` (5). Both enums are append-only.

The event is not chosen when the node is entered. `RunState.current_event()` rolls it the first time it is asked for, from the run RNG, among
the events not in `events_seen` (all twelve again once every one was seen), and remembers it for the stop. The screen asks when it is shown,
after the arrival save has been written, so a run resumed from that save rolls the same event from the restored RNG. An event that has been
rolled is open: `at_stop_boundary()` is false, `RunSave.save` refuses, and Save & Exit keeps the arrival save (as for an open vendor visit
or chest).

API (all on `RunState`, mirroring the treasure API):

| Call | Does |
| --- | --- |
| `in_event_stop()`, `current_event()` | At an event stop; the rolled `EventData` |
| `event_body()`, `event_choices()` | The scene text and the buttons this character sees |
| `event_choice_state(i)` | `{label, summary, enabled, reason}` for button `i` |
| `resolve_event_choice(i)` | Applies the button; returns an `EventResult` (`ok`, `text`, `followup`) |
| `event_followup()` | The pick still owed: `remove`, `remember`, `pick` or empty |
| `event_remove_card(deck_index)`, `event_remember_card(deck_index)`, `event_pick_card(card)` | Complete a pick |
| `event_pick_choices()`, `event_remember_indices()` | What the pending pick offers |
| `event_resolved()`, `event_outcome()` | Whether a button was pressed, and the text shown after it |
| `finish_event()` | Leaves the stop (needs a choice made and no pick owed) |

Pressing a button applies its effects at once, in order, with the run RNG for every random thing (gambles, random cards and relics, the
three cards of a pick). The picks (remove a card, Remember a card, choose 1 of 3) are queued and made through the calls above, so the
screen can be redrawn at any moment and shows the same place. The outcome text is the choice's own text, the flavour line of a gamble's
result, then one generated line per thing that happened ("You recover 13 HP.").

`events_seen` is saved with a map run (`events_seen`, a list of ids). A v5 save without the key loads with nothing seen; unknown ids are
dropped and repeats merged, so retiring an event never invalidates a save. A line run never carries it.

## Data model

Events are `.tres` resources under `data/events/`, registered in `StarterContent.EVENT_PATHS` and loaded by `StarterContent.all_events()`
(a loader that rejects a missing or wrong-type resource, like cards and relics). All numbers are in the data.

- `EventData` (`combat/event_data.gd`): `id`, `title`, `body`, `class_body` (character id to replacement scene text), `choices`, and `scene`
  (the painted screen shown dimmed behind the card).
- `EventChoice` (`combat/event_choice.gd`): `label`, `outcome`, `only_for` (only this character sees the button), `not_for` (this character
  sees a variant instead), `class_label` and `class_outcome` (character id to replacement text), `win_outcome` and `lose_outcome` (flavour
  added to the outcome after a gamble), `effects`.
- `EventEffect` (`combat/event_effect.gd`): `kind`, `amount`, and for the card and relic kinds `card_id`, `rarity` (-1 any), `pool`
  (neutral, class, any), `count`, `has_effect` (a card must have this `CardEffect.Kind`), and for a gamble the nested `win` and `lose` lists.

Effect kinds (append-only, saved as numbers):

| Kind | Means |
| --- | --- |
| HEAL_PERCENT, HEAL_FLAT | Heal a percent of max HP or a flat amount, never past max HP |
| LOSE_HP, LOSE_HP_PERCENT | Lose HP, never below 1 |
| GOLD | Gain gold, or pay it when negative (a payment must be affordable; inside a gamble gold stops at 0) |
| MAX_HP | Change max HP; HP follows a rise and is capped by a fall |
| ADD_CARD | Add a named card of the normal pools |
| ADD_RANDOM_CARD | Add random cards by pool, rarity and an optional effect kind |
| PICK_CARD | Choose 1 of `count` cards of the character's own, of a rarity (follow-up) |
| REMOVE_CARD | The player picks a card to remove (follow-up) |
| REMEMBER_CARD | The player picks a card to Remember (follow-up) |
| GAIN_RELIC | A random relic not owned, from the pool |
| ADD_CURSE | Put Dread or Murmur in the persistent deck |
| GAMBLE | `amount` percent chance of the `win` effects, else the `lose` effects |
| REMOVE_RANDOM_CARD | Remove random cards (never the last card, and never one that a pending removal needs) |

A relic from an event follows the shop's rules: a MAX_HP relic raises max HP and HP once. The neutral pool falls back to any unowned
relic of the character when every neutral relic is owned (there are only four neutral relics), and when nothing at all is left a won relic
gamble pays `RunState.EVENT_RELIC_FALLBACK_GOLD` (40) instead and a plain relic button is greyed ("There is nothing left to find.").

## Curses: Dread and Murmur in the deck

Dread and Murmur are Dormant status cards (`data/status`) that enemies shuffle into a fight. An event can put them into the persistent
deck (ADD_CURSE). What was checked and changed for that:

- **Saves.** The deck check in `RunSave` only knew the character's card pool, so a deck holding a status card was rejected as "a card that no
  longer exists". Status cards are now accepted in a deck (kept apart from the pool table the offered list is checked against); a
  Remembered mark on one is refused. Map saves (v5) and line saves (v4) both round-trip a deck with curses.
- **Combat.** `Combat` takes the deck as is: nothing strips or duplicates a status card, it is shuffled in like any card, Dormant keeps it
  unplayable, a Dread can be discarded, and a Murmur left in hand is Forgotten at the end of the turn (as when an enemy adds one). The
  deck itself is never changed by a fight, so the curses come back every fight.
- **Views.** The card view already has a status look (a sickly grey-green card with an inkblot). The pickers (event removal, vendor removal,
  reward removal, Remember) list the whole deck, curses included.
- **Removal.** The vendor removes a curse like any card (flat price), the reward screen's free Remove and an event's removal can too, and
  both bots pick a curse first when they remove.
- **Bots.** The scoring already gives a Dormant card the lowest score, so the smart bot sees a curse as the weakest card.

## The screen

`run/screens/event_screen.gd` (`EventScreen`) over `run/event_scene.gd` (`EventScene`: the event's painted screen, dimmed and cooled). The
header names the stop "A Place Along the Way". A card holds the title, the scene text and one block per button (the button, then the cost
line in teal, with the reason in amber when it is greyed). After a button: the outcome text and "Continue". A pick uses the existing
pickers: `add_remove_picker` for removal and Remember (without Cancel, because the price is already paid) and a row of card views for
"choose 1 of 3". The card scrolls if the window is too small for it.

## The twelve events

Numbers are the shipped data. "%HP" is a percent of max HP. "Class" lists the class-only differences.

| Id | Title | Buttons (cost and reward) | Class |
| --- | --- | --- | --- |
| rain_barrel | The Rain Barrel | Drink: heal 25%HP. Reach: gain 20 gold, lose 3 HP. Walk on | Stray laps the water |
| scraped_plaques | The Scraped Plaques | Finish the scraping: remove a card, lose 6 HP. Pry the plaque: gain 40 gold, a Murmur. Leave | Medium: the half-line is a whispered name; Thief: "Work the plaque loose" |
| stopped_kitchen | The Stopped Kitchen | Eat: pay 20 gold, heal 40%HP. Wash the dishes: heal 15%HP, gain 2 max HP. Take the kettle: gain 30 gold, lose 5 HP. Leave | Deserter eats at a mess table |
| bell_in_the_well | The Bell in the Well | Drop in a coin: pay 30 gold, 40% a relic. Ring it: 50% gain 45 gold, else lose 10 HP. Leave | Thief pays 25; Medium scene line |
| unsent_letters | The Unsent Letters | Read one aloud: lose 8 HP, Remember a card. Carry them: gain 15 gold, heal 5%HP. Leave | Medium: Answer the writers (lose 4 HP, Remember, a Murmur) |
| hound_at_the_fence | The Hound at the Fence | Share your food: lose 6 HP, gain 4 max HP. Cut the wire: lose 4 HP, choose 1 of 3 uncommon class cards. Leave | Stray: Press your nose to its nose (gain 6 max HP) |
| window_that_is_lit | The Window That Is Lit | Pick the latch: 60% a neutral relic, else lose 12 HP and 15 gold. Watch the window: heal 10%HP. Walk on | Thief picks at 80% |
| empty_sentry_box | The Empty Sentry Box | Stand the watch: lose 10 HP, choose 1 of 3 uncommon class cards. Take the coat: a random neutral Block card, gain 10 gold. Sleep: heal 15%HP | Deserter: Report in (lose 5 HP, Remember) |
| quiet_choir | The Quiet Choir | Take the front place: a Dread, choose 1 of 3 rare class cards. Stand at the back: heal 20%HP. Leave | Medium is made room for |
| name_broker | The Name Broker | Buy a keepsake: pay 70 gold, a neutral relic. Sell a name: gain 45 gold, lose 4 max HP. Walk away | none |
| cracked_bell | The Cracked Bell | Strike it hard: lose 14 HP, a neutral relic. Strike it softly: lose 5 HP, gain 25 gold. Leave | Deserter and Medium scene lines |
| erasers_chalk | The Eraser's Chalk | Cross out one of your own: remove a card, 30% a second random card goes too. Take the chalk: a neutral relic, lose 4 max HP, a Dread. Smudge the slate | Stray: no second removal; the Stray reads its own scene |

Changes from the approved draft:

- The Name Broker pays 45 gold for 4 max HP (the draft's 60 was trimmed, designer decision 6).
- Button labels carry no numbers (the draft's "Drop in 30 gold and ask" is "Drop in a coin and ask"), so the printed line is the only place a
  number lives and a data edit cannot leave a stale label.
- The neutral relic pool has only four relics, so a neutral-relic effect falls back to any unowned relic of the character instead of
  becoming a dead button (see above).
- Interpretations of the draft: the Deserter's mess-table line is added to the end of the Eat outcome; "the Medium sees the half-line as a
  name" is the outcome of Finish the scraping; the Stray's nose button is a fourth button beside Share your food (it is strictly better, as
  drafted; the draft's "replaces the first button's HP cost" is read as flavour); the Deserter's "stand the watch" line is the outcome of
  that button; the Thief's two number changes are separate buttons with `only_for` (and `not_for` on the base one) rather than a number
  table.

## Tuning and adding an event

Tuning is a data edit: change an amount in the `.tres` and the printed line follows. The event frequency is a map setting
(`RouteMap.CONFIG["type_weights"]["event"]`, docs/MAP_DESIGN.md). To add an event see "An event" in `docs/ADDING_CONTENT.md`; a new
effect kind is appended to `EventEffect.Kind`, given a line in `describe()` and applied in `RunState._apply_event_effect`.

## Bots and debug

`SimPolicy.event_stop` (greedy: the first enabled button that costs no HP, gold, max HP or curse and is no gamble, else a plain leave)
and `SmartPolicy.event_stop` (scores each button: healing is worth more when HP is under 60%, relics and card picks when healthy, a gold
payment is never made under 60 gold, a gamble that can cost HP is not taken while hurt) settle an event through the public API and make
every pick it owes (`SimPolicy.finish_event_picks`: removal takes a curse first). `SmartPolicy.choose_route` mildly prefers an event while
HP is at least 70%. `tools/run_sim.gd --map` plays them and reports the events played.

`--screen=event` opens a random event of a throwaway map run, `--screen=event:<id>` a chosen one (an id, or its number: `event:e04`);
`--gold`, `--hp` and `--character` apply, and the environment variable `THE_UNFORGOTTEN_SCREEN` takes the same values. Nothing is saved.
`tools/event_sheet.gd` takes the screenshots.
