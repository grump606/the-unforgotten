# Card mechanics rework: plan

Status: phases 1 to 4 are built; phase 5a (Remembered upgrades), 5b (Omens), 5c (relics) and 5d (bots and balance) are built. Phase 6a (the Oath engine) and 6b (the six Oath cards and their display) are built. Lives on the `thief-rework` branch.

Reference: the Slay the Spire wiki (Mechanics, Keywords, Energy, Intent pages). Those pages are thin and
marked "under construction", and give no numbers for Weak, Vulnerable or Strength. The numbers below are
this game's own choices. The goal is to play in the same family as Slay the Spire without copying it, so
keywords are renamed to fit the setting and a few rules are our own.

## Where the game is today

- 3 energy per turn. Draw pile, hand, discard pile. Hand cap 10.
- The hand refills to 5 each turn. At end of turn the player picks cards to discard, and kept cards count
  toward the 5 (there is no "discard everything" turn).
- Block resets each turn, except Hold, which carries some over. Barbs (today's Thorns) last until the
  next turn.
- Two statuses: Exposed (x1.5, rounded down, counts down by turns) and Haunted (damage at the start of each
  enemy phase, ignores Block and Expose, falls by 1 per phase).
- 14 effect kinds. 35 cards across Deserter, Medium, Thief and neutral. Every played card goes to discard.
- Not present: exhaust, ethereal, innate, retain, unplayable, X-cost, upgrades, multi-hit, Weak, Frail,
  Strength, Dexterity, scry, cards created mid-fight, enemy buffs, status or curse cards.

## Vocabulary

| Function | Our keyword | Rule |
|---|---|---|
| Exhaust | **Forgotten** | The card leaves play for the fight and goes to the Forgotten pile (visible in the fight). Forgotten cards return to the deck after the fight. |
| Ethereal | **Fading** | If it is still in hand when the turn ends, it becomes Forgotten. |
| Innate | **Ready** | Starts the fight in the opening hand, using one of the first draw slots. |
| Retain | **Anchor** | Stays in hand and does not count toward the 5 kept. It still counts toward the hand cap of 10. |
| Unplayable | **Dormant** | Cannot be played. Enemies shuffle these in. |
| X-cost | **Surge** | Spends all remaining energy; the effect scales with what was spent. |
| Weak | **Shaken** | Deals 25% less damage for N turns. |
| Frail | **Frayed** | Gains 25% less Block for N turns. |
| Strength | **Malice** | Stacking flat bonus to each hit dealt. Negative Malice is a debuff. |
| Dexterity | **Ward** | Stacking flat bonus to each Block gained from cards. Negative Ward is a debuff. |
| Scry | **Glimpse X** | Look at the top X cards of the draw pile and discard any of them. |
| Upgrade | **Remembered** | Rest-site action "Remember" brings a card back stronger. |
| Thorns | **Barbs** | Rename only. |
| Intent | **Omen** | Rename only. |
| Unchanged | Expose, Haunt, Hold, Block, Energy | |
| Later | **Oaths** | A card type played once that lasts the fight (the Power equivalent). A to-do after the rest, not part of this rework. |

## Rules (settled)

1. **Damage order, per hit:** base + Malice, then x0.75 if the attacker is Shaken, then x1.5 if the target is
   Exposed, then Block. A hit is never below 0 from negative Malice. One pure function is used by both
   `Combat` and the drag preview, so previews cannot drift from real damage.
2. **Block order:** base + Ward, then x0.75 if Frayed. Ward applies to Block gained from cards only: not to
   Hold, Barbs, or relic Block.
3. **Durations:** Shaken, Frayed and Exposed count down per turn, as Exposed does now. Malice and Ward last
   the whole fight, and some cards grant them for one turn only.
4. **Anchor and the keep-5 rule:** Anchored cards do not count toward the 5 kept, but do count toward the
   hand cap of 10.
5. **Forgotten pile:** visible during the fight. Recalling a card from it costs a card effect, not a free
   action. Cards return to the deck after the fight.

## Where we play differently from Slay the Spire

1. Keep-5 hand: Fading and Anchor make "keep or play" a real decision, since a kept Fading card must be
   played or it is lost.
2. Hold as a central engine for Deserter, not a rare relic effect.
3. The Forgotten pile is a resource: Medium cards gain power from its size, and a few cards recall from it.
4. Play-count chains: cheap cards in sequence are a Thief pillar (the "damage per earlier card this turn"
   effect already exists).
5. HP as a cost, and Haunt that decays by 1 per phase: both already in the game.

## Class identities

- **Thief:** fast and cheap. Zero-cost cards, Glimpse and draw, play-count combos, Shaken and Exposed on
  enemies, Ready and Anchor on key cards.
- **Deserter:** Hold, Barbs, Ward. A patient game, with Forgotten as a one-off cost for big plays.
- **Medium:** Haunt, HP cost, and Forgotten-pile payoffs. Strong cards that cost something.

## Build phases

Each phase is its own PR into `thief-rework`, reviewed and run through `scripts/check.ps1` before merging.

1. **Keywords.** Flags on `CardData` (forgotten, fading, ready, anchor, dormant), the Forgotten pile in
   `CardPiles`, multi-hit (`hits` on damage effects), Surge. `describe()` writes the keyword text.
2. **Damage pipeline and statuses.** The single damage and Block functions; a status table that supports
   both durations (Exposed, Shaken, Frayed) and stacks (Malice, Ward); Shaken, Frayed, Malice, Ward. The
   drag preview moves onto the shared function.
3. **Deck cycling.** Glimpse, add-a-card effects, Dormant cards enemies shuffle in.
4. **Retune the 35 cards** to the keywords, with Thief, Deserter and Medium hooks. Card ids stay the same,
   so saves are unaffected.
5. **Remembered upgrades (5a done).** A run save version bump with migration, the rest-site UI, card art for upgraded
   cards if wanted. Also enemy Omens (intents that apply Shaken or Frayed, gain Malice, hit several times,
   add cards), the Omen display, and the sim/balance tools (`tools/sim_policy.gd`, `smart_policy.gd`).
6. **Later, not now:** Oaths.

## Phase 1 detail

Engine and UI only: no existing card changes, so there is no change to play until phase 4.

**Data model**
- `CardData`: bool fields `forgotten`, `fading`, `ready`, `anchor`, `dormant`, `surge` (defaults leave the
  existing `.tres` files and saves untouched), plus `keyword_lines()` for card text.
- `CardEffect`: `hits: int = 1` (multi-hit) and `per_energy: bool` (Surge multiplies hits on damage, and the
  amount on Block, Draw, Haunt, Expose). A flag, not new kinds.
- `CardPiles`: a `forgotten` pile. A played Forgotten card goes there instead of discard. The deck is never
  modified, so Forgotten cards return next fight with no extra code.

**Rules (`Combat`)**
- Multi-hit: `take_damage` runs per hit. Block absorbs across hits, Expose applies per hit, Barbs trigger per
  hit. Enemy intents get this for free.
- Surge: cost 0, spends all current energy, playable at 0 energy.
- Dormant: `can_play` is false. It takes hand space and is discarded normally.
- Ready: on turn 1, Ready cards move from the draw pile into the opening hand before the normal draw (up to
  the hand cap of 10).
- Anchor: cannot be marked for discard; does not count toward the 5 kept. The turn-start refill draws up to 5
  non-Anchored cards.
- Fading: does not count toward the 5 and cannot be saved by discarding. Fading cards in hand at the end of
  the turn go to the Forgotten pile. Content tests forbid Fading together with Anchor.

**UI:** keyword lines on the card face, "X" in the cost stamp for Surge, muted Dormant, `Draw / Discard /
Forgotten` counts, multi-hit in the drag preview (Block and Expose applied hit by hit), "Deal 3 x2" text.

**Tools:** `Vendor.card_value` multiplies by `hits` and adjusts for keywords. `sim_policy` and `smart_policy`
follow the new discard rules, play Fading cards first, never try Dormant, and score Surge.

**Deferred:** Recall and "damage per Forgotten card" effects (phase 3 and 4). A pile viewer.

**Delivery:** three PRs into `thief-rework`. 1a engine and tests. 1b card UI, previews, pile label (after
1a). 1c vendor, sim, content tests (after 1a, parallel with 1b). A debug-only list of prototype cards (one
per keyword) is added so the keywords can be tried in the game before phase 4.

## Trying the keywords

`data/prototype/` holds one sample card per keyword (Forgotten, Fading, Ready, Anchor, Dormant), a multi-hit
card and a Surge attack and Surge block, all with ids starting `proto_`. They are not in the card registry or
any reward pool. To play a fight with them (two copies of each as the deck):

    godot --path . -- --proto
    godot --path . -- --proto --fight=crow --character=thief

`--proto` alone fights the Colossus; with `--fight=` it uses that enemy. `THE_UNFORGOTTEN_PROTO=1` does the
same from the environment. The list lives in `DebugLaunch.PROTO_CARD_PATHS`. With the status cards added
(a plain Strike and Guard, Shaken and Frayed on a foe, Malice permanent and for one turn, Ward, a Malice
debuff, and a Block card that also Shakens you) the deck was one copy of each, 17 cards. Phase 3b adds seven cycling cards (below), so the deck is 24 cards.

The status prototypes have their own enemy, the Pest (`data/prototype/enemies/proto_pest.tres`, the hound's
figure). It cycles Shaken on you, Frayed on you, Malice for itself, then an attack. It is not in the enemy
registry or any encounter pool; `--fight=` accepts `proto_pest`, `Proto: Pest` or `pest`:

    godot --path . -- --proto --fight=proto_pest
    godot --path . -- --proto --fight=proto_pest --character=thief --hp=30

What to look for: a badge under each fighter for every status (turns for Shaken and Frayed, a signed stack
for Malice and Ward, red when negative), the tooltip on the figure explaining each, the Deal and Block numbers
on the cards in hand turning green or red with your own Malice, Shaken, Ward and Frayed, and the Pest's Omen
number including its own Malice and Shaken.

The cycling prototypes (Glimpse, Recall, adding cards, damage from the Forgotten pile) add: Glimpse 3, Glimpse
2 and Draw, Recall 1 (itself Forgotten, so it can recall itself), Recall 2, Gift (adds a Heavy Blow to your
hand), Dreadful Draw (adds a Dread to your own draw pile, draws 2) and Pile Strike (damage equal to 2x the
Forgotten pile; the Forgotten Strike already in the deck feeds the pile). They fight the Dreadkeeper
(data/prototype/enemies/proto_dreadkeeper.tres, the whisperer's figure, 70 HP): it shuffles a Dread into
your draw pile, puts a Murmur in your hand, then attacks for 6 and for 11, and repeats. It is in no registry
or pool; --fight= accepts proto_dreadkeeper, Proto: Dreadkeeper or dreadkeeper:

    godot --path . -- --proto --fight=proto_dreadkeeper
    godot --path . -- --proto --fight=proto_dreadkeeper --character=medium --hp=30

What to look for: Glimpse and Recall open an overlay over the stage (cards in draw order for Glimpse; tap to
mark for discard, "Keep all" or "Discard N"; Recall needs exactly N picks and shows "Recall 1 of 2"), with
number keys to mark and Enter to confirm, and nothing else playable behind it. Click Draw, Discard or
Forgotten under the energy orb to look at a pile (Draw is sorted, so it shows no order). A floating "+Dread
(draw pile)" appears when something is added, and a line in the Log. Dread and Murmur are grey-green status
cards. Pile Strike's "Deals N" grows as the Forgotten pile does.
## Phase 2 detail

Damage and Block pipeline plus Shaken, Frayed, Malice and Ward. No existing card changes, so no change to
play until phase 4; prototype cards and a prototype enemy let the statuses be tried.

**One pipeline function.** A pure `Combatant.hit_damage(raw, attacker, defender)` does the whole chain: raw
plus the attacker's Malice (floored at 0), then x0.75 if the attacker is Shaken, then x1.5 if the defender
is Exposed. Block comes after. Combat, the drag preview, the intent display and both bot policies all call
it, so previews cannot drift from real damage. `damage_after_status` stays as a thin wrapper for the Expose
step.

**Rounding.** Shaken and Frayed round down but never take a real hit or Block to 0 (a hit of 1 stays 1).
Only negative Malice or negative Ward can reduce a hit or Block to 0.

**Status table.** Each status declares its kind in one place:

| Status | Kind | Behaviour |
|---|---|---|
| Exposed, Shaken, Frayed | duration | counts down per turn |
| Haunted | decaying | falls by 1 each phase (as now) |
| Malice, Ward | stack | signed, lasts the fight, never ticks; removed at 0 |

Statuses are not saved (they are cleared each fight), so there is no save change. Status enum values are
only appended.

**Block.** The Block branch of `Combat._apply` applies Ward, then x0.75 if Frayed, through
`block_from_card(amount)`. Hold, Barbs and relic Block bypass it. Enemy Block intents use the same path, so
an enemy with Ward gets it.

**Barbs** damage stays flat: Malice and Shaken do not affect it (the target's Expose still does).

**New effect kinds** (appended): SHAKEN, FRAYED, MALICE, WARD. Shaken and Frayed behave like Expose: they
land on the card's targets, or on the player for a self-targeted card. For Malice and Ward the sign decides
who receives them: positive buffs the user (an enemy intent buffs the enemy), negative debuffs the target
(an enemy intent debuffs the player). `reach()` reads the sign: positive is SELF, negative is ENEMIES.

**Enemy-applied statuses on the player.** The "pending until after the tick" handling of Expose is
generalised to every duration status, so "Shaken 2" from an enemy lasts the next two player turns.

**Temporary stacks.** Support for "+2 Malice this turn": temporary stacks expire at the start of the owner's
next turn (the same moment Barbs reset).

**Sub-PRs into `thief-rework`:**
- 2a engine: status table, `hit_damage`, `block_from_card`, the four kinds (reach, describe, Vendor value),
  pending-status generalisation, temporary stacks, tests (including the every-kind walk).
- 2b UI (after 2a): status badges and tooltips (duration, or the signed stack) on enemies and the player,
  drag preview and intent damage on the shared function, live numbers on card faces (green when a status
  raises Deal/Block, red when it lowers them), prototype cards for each status and a debug-only prototype
  enemy that applies Shaken and Frayed to the player and gains Malice.
- 2c tools (after 2a, parallel with 2b): sim and smart policies use the pipeline, score the new effects,
  tests for each.

## Phase 3 detail

Deck cycling and the Forgotten-pile effects: Glimpse, adding cards mid-fight, Dormant cards that enemies
shuffle in, Recall. No existing card changes, so no change to play until phase 4; prototype cards and a
prototype enemy let it be tried.

**Choice step.** A new `Combat.Phase.CHOOSING`, like the discard step. Glimpse and Recall queue a choice
that opens after the card's other effects finish. The choice holds a list of cards and how many may be
picked; `Combat.resolve_choice(indices)` finishes it, and the turn cannot end until it is resolved. One
overlay serves both effects.

**New effect kinds** (appended; `CardEffect` gains a `card: CardData` field and a destination pile):
- GLIMPSE `n`: look at the top `n` cards of the draw pile and discard any of them. It looks only at what is
  there and never reshuffles the discard pile.
- ADD_CARD: add `amount` copies of `card` to a chosen pile (hand, draw or discard). If the hand is full the
  card goes to discard. Added to the draw pile, a card is inserted at a random position using the seeded RNG.
  An enemy intent adds the card to the player's piles. Default destination for enemies: the draw pile.
- RECALL `n`: pick `n` cards from the Forgotten pile and return them to the hand (to discard if the hand is
  full). A recalled card is Forgotten again if played.
- DAMAGE_PER_FORGOTTEN `n`: damage equal to `n` times the size of the Forgotten pile.

**Created cards are fight-only.** They vanish after the fight, so the deck and saves are unaffected.

**EffectContext.** `raw_damage(source_block, target_haunt, plays)` is replaced by a small `EffectContext`
object (block, haunt, plays, forgotten) so the Forgotten count has somewhere to go. This touches about six
call sites (preview, bots, Combat).

**Status cards.** Real card resources for what enemies add, kept out of rewards, vendors and starting decks
(a content test enforces it): **Dread** (Dormant: clogs the cycle until discarded) and **Murmur** (Dormant
and Fading: costs one draw slot, then vanishes).

**Pile viewer.** Clicking the pile counters opens the Draw, Discard or Forgotten pile in an overlay. The
draw pile is shown sorted so it does not reveal order.

**Sub-PRs into `thief-rework`:**
- 3a engine: `EffectContext` refactor, the four kinds, the `card` and destination fields, the CHOOSING phase,
  pile helpers, Vendor values, the status cards and their registry exclusion, tests.
- 3b UI (after 3a): the choice overlay, the pile viewer, card text for the new kinds, the DAMAGE_PER_FORGOTTEN
  preview, prototype cards, a prototype enemy that shuffles status cards in.
- 3c tools (after 3a, parallel with 3b): both bots resolve choices (Glimpse discards junk, Recall picks the
  best card), score the new kinds, the run stub resolves choices.

## Phase 4 detail

Retune the existing cards onto the new keywords and statuses, add a few new cards, and give each class its
identity. Numbers stay inside today's ratios (one energy is about 6 damage or 5 Block; Shove 6 for 1, Heavy
Blow 14 for 2, Slip Past 5 for 1). Card ids never change (art and saves key on the id), only effects, keywords
and display names where stated. New cards ship with the generic fallback art until the art pass.

**Retunes**

| Class | Card | Today | Becomes |
|---|---|---|---|
| Neutral | Glimpse the Exit (starter) | 0, Draw 2 | 0, Glimpse 3, Draw 1 |
| Neutral | Flurry | 0, Deal 3 | 0, Deal 2 x2 |
| Thief | Light Fingers | 0, Expose 1 | + Ready |
| Thief | Find the Seam | 1, Expose 2 | 1, Expose 2, Shaken 1 |
| Thief | Filch | 1, Deal 3, Draw 1 | 1, Deal 3, add 1 Trinket to hand |
| Thief | Borrowed Time | 1, +1 energy, Draw 1 | 1, +2 energy, Forgotten |
| Thief | Many Hands | 2, Deal 2 (+2 per card played) | 2, Deal 3 x3 |
| Thief | Cutting Word, Hamstring | | unchanged |
| Deserter | Last Stand | 3, Block 14, Hold 10 | + Anchor |
| Deserter | Heavy Blow | 2, Deal 14 | 2, Deal 20, Forgotten |
| Deserter | Iron Resolve | 2, Block 8 | 2, Block 6, Ward +2 |
| Medium | Seance | 1, lose 3 HP, Draw 3, +1 energy | + Forgotten |
| Medium | Bleed the Veil | 2, lose 6 HP, Haunt 8 all | + Forgotten |

All other cards are unchanged.

**New cards (9 with the created card)**
- Thief: Sharpen (1, Malice +1 for the fight); Quick Study (0, Malice +2 this turn only); Cleaned Out (Surge,
  Deal 3 per energy spent); Trinket (created by Filch: cost 0, Deal 4, Fading; fight-only).
- Deserter: Dig Deep (Surge, Block 5 per energy spent).
- Medium: Remember (1, Recall 1); Chorus of the Lost (1, damage equal to 2x the Forgotten pile); Hollow Bargain
  (0, add a Dread to your own draw pile, Draw 2).
- Fight-only created cards (Trinket) live in `data/created/`, loaded from an explicit list, never in rewards,
  vendors or starting decks, like the status cards.

**Starter decks.** Each class already starts with its own 10-card deck (about 4 class cards and 6 neutral
cards); Phase 4 leaves the three starter decks unchanged. Retuned cards that appear in them (Light Fingers,
Find the Seam, Filch, Last Keepsake for the Thief, and Glimpse the Exit for everyone) change with the retune.

**Content tests (identity checks).** No enemy intent uses a temporary stack; no card targets enemies with a
temporary stack. Each class keeps its signature keywords (Thief: Ready, Shaken, Add card, multi-hit, Malice.
Deserter: Hold, Barbs, Ward, Anchor. Medium: Haunt, HP cost, a Forgotten payoff). Every keyword is used by at
least one shipped card. The golden price table is updated with every change.

**Balance.** A per-class sim baseline is recorded before the changes. After them, the smart bot's escape
rate should stay within about 5 points of the baseline for each class. The bots cannot judge every keyword
yet, so this is a sanity check, not a verdict.

**Sub-PRs into `thief-rework`:**
- 4a groundwork: `data/created/` and its loader, the `starter_deck` helper, per-class sim baselines, the neutral
  retunes, golden table updates.
- 4b Thief, 4c Deserter, 4d Medium (parallel after 4a): the retunes and new cards for that class.
- 4e: identity and keyword-coverage tests, a final balance pass, README card list.

**Balance baseline** (`run_sim.gd --runs 150 --seed S --character C --policy P`, 2026-11-04). Escapes out of
150 (percent in brackets). Before is the original pre-phase-4 tree (commit 0e071ee, seed 7 only), merged
4b-4d is the tree after the class PRs, final 4e is after the balance pass below. Target: smart 40-60%
(60-90 escapes) per class on both seeds; greedy (the dumb robustness bot) at least 12% (18 escapes).

| Class | Policy | Before (seed 7) | Merged 4b-4d, seed 7 | Merged 4b-4d, seed 11 | Final 4e, seed 7 | Final 4e, seed 11 |
|---|---|---|---|---|---|---|
| Thief | smart | 71 (47.3%) | 71 (47.3%) | 91 (60.7%) | 71 (47.3%) | 91 (60.7%) |
| Thief | greedy | 25 (16.7%) | 50 (33.3%) | 62 (41.3%) | 50 (33.3%) | 62 (41.3%) |
| Deserter | smart | 72 (48.0%) | 131 (87.3%) | 134 (89.3%) | 75 (50.0%) | 76 (50.7%) |
| Deserter | greedy | 33 (22.0%) | 103 (68.7%) | 110 (73.3%) | 65 (43.3%) | 62 (41.3%) |
| Medium | smart | 97 (64.7%) | 110 (73.3%) | 107 (71.3%) | 86 (57.3%) | 85 (56.7%) |
| Medium | greedy | 34 (22.7%) | 17 (11.3%) | 21 (14.0%) | 14 (9.3%) | 20 (13.3%) |

Left over after the pass: Thief smart on seed 11 is 91, one escape over the band (the Thief was not changed in
4e: its strength is Last Keepsake, an old card, and the new Thief cards are almost never taken or played by
the smart bot); Medium greedy on seed 7 is 14, below the 18 floor (seed 11 is 20).

**Experiments** (smart escapes, seed 7 / seed 11; each row keeps the earlier kept rows):

| Lever | Value | Class | Seed 7 / seed 11 | Kept |
|---|---|---|---|---|
| (merged tree) | | Deserter | 131 / 134 | |
| Iron Resolve Ward (permanent) | +2 -> +1 | Deserter | 102 / 108 | yes |
| Heavy Blow damage | 20 -> 17 | Deserter | 87 / 97 | |
| Dig Deep Block per energy | 5 -> 4 (on top of 17) | Deserter | 86 / 98 | no, no effect |
| Heavy Blow damage | 20 -> 16 | Deserter | 90 / 91 | yes |
| Last Stand Block | 14 -> 12 | Deserter | 75 / 76 | yes |
| (merged tree) | | Medium | 110 / 107 | |
| Remember cost | 1 -> 2 | Medium | 110 / 107 | no, the smart bot never takes it |
| Bleed the Veil Haunt | 8 -> 6 | Medium | 86 / 85 | yes |
| Seance Draw | 3 -> 2 | Medium | 126 / 123 | no, it made the Medium stronger |
| Bleed the Veil Haunt | 8 -> 7 | Medium | 102 / 103 | no |
| Bleed the Veil Haunt 6, HP cost 5 | | Medium | 90 / 86 | no, at the band edge |
| Bleed the Veil Haunt 6, HP cost 4 | | Medium | 97 / 105 | no |

Medium greedy while tuning (seed 7 / seed 11): Bleed the Veil Haunt 8 gives 17 / 21, Haunt 6 gives 14 / 20,
Haunt 6 with HP cost 5 gives 15 / 25, with HP cost 4 gives 15 / 29. Chorus of the Lost 2x -> 3x changed
nothing (15 / 25), Hollow Bargain Draw 2 -> 3 gave 14 / 28. The greedy bot's Medium run is dominated by the
starter deck and the once-per-fight Bleed the Veil; no number in the lever list lifts seed 7 to 18 without
pushing the smart rate out of band. Remember, Chorus of the Lost and Hollow Bargain never change the smart
result: the smart bot does not take them in rewards.

**Final values of the changed cards** (Phase 4e):

| Card | Merged 4b-4d | Final |
|---|---|---|
| Heavy Blow | 2, Deal 20, Forgotten | 2, Deal 16, Forgotten |
| Iron Resolve | 2, Block 6, Ward +2 (permanent) | 2, Block 6, Ward +1 (permanent) |
| Last Stand | 3, Block 14, Hold 10, Anchor | 3, Block 12, Hold 10, Anchor |
| Bleed the Veil | 2, lose 6 HP, Haunt 8 all, Forgotten | 2, lose 6 HP, Haunt 6 all, Forgotten |

Every other card keeps its Phase 4b-4d numbers (Dig Deep Block 5 per energy, Remember cost 1, Chorus of the
Lost 2x, Hollow Bargain Draw 2, Seance unchanged).

Before 4e, on the Medium smart sim with seed 7 (150 runs): the original Draw 2 on Glimpse the Exit gives 97;
Draw 1 alone gives 89; Glimpse 3 plus Draw 1 gives 75. A player can always decline a Glimpse, so the extra
loss is the smart bot's Glimpse rule (it bins every card scoring below the average card), not the card. The
rule helps decks that cycle (Thief) and hurts decks whose good cards score low in `card_score` (Medium, whose
Haunt and HP-cost cards it undervalues).

**Bot weaknesses worth a later pass:** the smart bot's Glimpse binning (above); neither bot takes or plays
Remember, Chorus of the Lost or Hollow Bargain well (the smart bot never takes them, greedy plays Chorus
about 0.9 times a run), so their numbers are untested by the sim; greedy has no Recall or Forgotten
judgement; the Thief's new cards (Sharpen, Quick Study, Cleaned Out) are almost never taken or played, so
the Thief's escape rate says nothing about them; the Deserter's Dig Deep change from 5 to 4 had no
measurable effect for the same reason.

Relics and enemy content are out of scope here (phase 5).

## Phase 5 detail

Where things stand: a rest stop heals to full and moves on (`RunState.rest()`); saves are version 3 (version 4 after 5a) and store
the deck as a list of card ids; enemies only use Deal, Block and Expose (the Conductor and Brakeman add a
second phase); relic text still says "Thorns" (`barbed_greatcoat.tres`), a missed display rename.

### 5a. Remembered upgrades (engine, save, rest site) - done

- A card gets an optional `remembered` block on `CardData`: a replacement effect list and optionally a cost
  and keyword changes. One file per card, no second id, so rewards, vendor prices and pools stay as they are.
  Cards without a block cannot be remembered.
- A deck entry is a card plus a Remembered flag. In the save it is the id with a `+` suffix (`"sleight+"`).
  Run save VERSION 4; `migrate()` takes version 3 as is (no `+` entries), MIN_VERSION stays 2. A card with a
  `+` but no block is rejected as a bad save.
- Rest stop offers two choices: **Rest** (heal to full, as now) or **Remember** (pick one card in the deck
  that is not yet Remembered and has a block; no heal). One per stop, so it costs the heal. Remembered cards
  show a `+` name, gold title and the changed text.
- Vendor: removing or buying is unchanged; the price table adds a fixed bonus for a Remembered copy.
- Starts with the ten cards worth it most (two per class signature card, plus neutrals), not all 42; the rest
  follow once a playtest says which matter.

**5a status: done.** What shipped:

- `CardData.remembered` is a `RememberedData` block (`combat/remembered_data.gd`): replacement `effects`, an
  optional `cost` (-1 keeps it) and `gain_keywords` / `lose_keywords`. All new fields are appended; no
  CardEffect kind changed.
- **Representation:** `RunState.deck` stays `Array[CardData]`. A Remembered card is a runtime variant built
  once per base card by `CardData.remembered_card()`: same `id`, name plus `+`, the block's effects, cost and
  keywords, flagged `is_remembered` with `base_card` pointing back. Because the id is shared, art, vendor
  prices, reward copy counts and pools work unchanged, and Combat, the pile viewer, card view and the sim
  tools needed no change (they only read `CardData` fields). Rewards and the vendor only ever hand out base
  cards; the variant exists only in the deck. `can_remember()` and `base()` are the helpers.
- **Save:** VERSION 4, MIN_VERSION 2. A Remembered deck entry is `"id+"`; `migrate()` takes v3 as is. A `+` on
  a card with no block, on an unknown card or doubled is rejected.
- **Rest stop:** `RunState.remember(deck_index)` (and `rememberable_indices()`) alongside `rest()`. The rest
  screen has the existing "Follow the voice" button (Rest: heal to full) and a "Remember a card (no heal)"
  button that opens the deck picker (`add_remove_picker`, now with an `only` filter) limited to rememberable
  cards, with Cancel. The Remember button is disabled when nothing can be Remembered.
- **Display:** name with `+`, gold title (bright gold on dark banners, deep gold on the paper banner), text
  from the upgraded effects.
- **Vendor:** unchanged. Removal is by deck position; a Remembered copy is removed like any other. The golden
  price table is unchanged because vendor stock never contains a Remembered card.

Cards with a Remembered form (eleven):

| Class | Card | Today | Remembered |
|---|---|---|---|
| Neutral | Shove | 1, Deal 6 | Deal 8 |
| Neutral | Glimpse the Exit | 0, Glimpse 3, Draw 1 | Glimpse 3, Draw 2 |
| Thief | Light Fingers | 0, Expose 1, Ready | Expose 2 |
| Thief | Find the Seam | 1, Expose 2, Shaken 1 | adds Ready |
| Thief | Many Hands | 2, Deal 3 x3 | Deal 4 x3 |
| Deserter | Heavy Blow | 2, Deal 16, Forgotten | Deal 19 |
| Deserter | Iron Resolve | 2, Block 6, Ward +1 | Block 9, Ward +1 |
| Deserter | Last Stand | 3, Block 12, Hold 10, Anchor | cost 2 |
| Medium | Cold Whisper | 0, Haunt 2 | Haunt 3 |
| Medium | Bleed the Veil | 2, lose 6 HP, Haunt 6 all, Forgotten | Haunt 7 all |
| Medium | Seance | 1, lose 3 HP, Draw 3, +1 energy, Forgotten | lose 2 HP |

Why these: they are the cards each class leans on most (the signature of each, plus the two neutrals that sit
in every starter deck), so the choice at a rest stop is real. Each upgrade is one small step (a few damage,
one more Expose or Haunt, one less cost, Ready for a seam-opener) and never changes what the card is; Bleed
the Veil is held to Haunt 7 because 8 was the number the Medium balance pass already rejected. `tests/
remembered_tests.gd` checks every shipped block (same id, changes something, modest value gain, no Fading with
Anchor, at least two per class and two neutrals). The bots do not take Remember yet (5d).

### 5b. Enemy Omens (done)

- Omen display: the intent badge shows the exact status or stack it will apply, and hit count for multi-hit.
- Use the new engine in enemy intents: Shaken on the player (Pale Whisperer, Lost Shade), Frayed (Gate
  Warden, Hollow Colossus), Malice gain (Cinder Hound, boss phase two), multi-hit (Skittering Wisp already
  hits in a sequence; give the Conductor a real 3-hit), and Dormant Dread or Murmur shuffled into the draw
  pile (Mourning Crow, the Brakeman). Remove the FRAYED allow-list from the identity test.
- Enemies never get temporary stacks (existing rule). Bosses keep their phase structure.
- Built: the badge text is `Fighter.omen_text` (amount, "6x3", "+1", the added card's name); the tooltip line
  reads "Omen:". Changes (a status replaces a Block or Expose turn, damage kept near the old total):
  Husher [Shaken 2, 6, 9]; Unnamed [9, Shaken 1, 11]; Threshold Keeper [10, Frayed 2, 18]; Memorial Giant
  [Frayed 2, 19]; Ash Hound [5, Malice +1, 9]; Keepsake Crow [3, 3, +Murmur, 10]; Bellkeeper phase one
  [Block 14, 13, +Dread, 18]; Eraser [Expose 2, 13, Block 10, 6x3, 13], phase two [13, Malice +1, 13, 16].
  `StarterContent.scaled` now keeps the hit count. Engine needed no change: enemy-source Shaken, Frayed,
  Malice and ADD_CARD already resolved (tests added). Sim, seed 7 (150 runs; before in brackets): smart
  Thief 70 (71), Deserter 77 (75), Medium 94 (86); greedy 58 (50), 68 (65), 15 (14).

### 5c. Relics (done)

- Fix the Barbed Greatcoat text to say Barbs.
- Add six relics that use the keywords: one each for Glimpse, Malice, Ward, Forgotten, Anchor and Shaken.
  Existing relics are not retuned unless the sim shows one dominating.

### 5d. Bot and balance (done)

- Smart bot: Glimpse binning that counts a card's value for the class, a Recall/Forgotten judgement, and
  taking and playing the six cards the sim currently ignores.
- Then re-run the sim and fix the two band misses (Thief smart seed 11, Medium greedy seed 7).

**5d status: done (bots only; no card, enemy or relic numbers changed).**

Bot changes:

- **Glimpse binning (both bots):** Dormant is always binned; a neutral card is binned below the cycle's average
  card score; a class card only below `GLIMPSE_CLASS_SHARE` (0.85) of the average (greedy never bins a class
  card). Binning more is what helps: with class cards never binned (smart, seed 7) Thief fell to 76, Deserter 69,
  Medium 73; at 0.85 they are 82 / 72 / 87.
- **Recall / Forgotten:** greedy plays Recall only if the Forgotten pile holds an attack or defence card. Smart
  prices a Recall from the deck's Forgotten cards (`weights.recall`, floor 5) and Chorus of the Lost from the
  deck's Forgotten count (3 to 5 cards); a Forgotten card that does not kill costs `FORGOTTEN_PLAY_COST` (2) of
  play value, so a 1-damage hit does not burn it (no measurable effect on escapes).
- **Play order:** a Surge goes after every fixed-cost card (smart). Malice before multi-hit already worked.
- **Rest stop (`SimPolicy.rest_stop`, both bots):** Rest below 60% HP, otherwise Remember (smart: the biggest
  `card_score` gain, plus a little for Ready; greedy: the first attack that can be Remembered). `run_sim` uses
  it, and `run_stub` models the same choice with the Remembered variant (same id, `is_remembered`).
- **Rewards:** the skip rule stays at "below the deck average" (0.85 of it, and 0.6, bloated the deck and cost
  15 to 30 escapes). Remember, Chorus and Hollow Bargain now score high enough to be taken sometimes
  (Hollow Bargain in about 20% of smart Medium runs); Remember and Chorus are still rarely taken by smart.
- **Vendor/relics:** both bots already buy the visit's relic when affordable; a test now runs a fight with
  every relic (the six 5c ones included) under both bots.

**Baseline after 5d** (escapes of 150, same command as above; "before" is the 5c tree, the same sims before any
5d change):

| Class | Policy | Before s7 | Before s11 | After s7 | After s11 |
|---|---|---|---|---|---|
| Thief | smart | 65 (43.3%) | 78 (52.0%) | 82 (54.7%) | 85 (56.7%) |
| Thief | greedy | 52 (34.7%) | 54 (36.0%) | 45 (30.0%) | 51 (34.0%) |
| Deserter | smart | 68 (45.3%) | 68 (45.3%) | 72 (48.0%) | 73 (48.7%) |
| Deserter | greedy | 69 (46.0%) | 63 (42.0%) | 71 (47.3%) | 53 (35.3%) |
| Medium | smart | 88 (58.7%) | 81 (54.0%) | 87 (58.0%) | 83 (55.3%) |
| Medium | greedy | 13 (8.7%) | 21 (14.0%) | 10 (6.7%) | 15 (10.0%) |

All six smart results are inside the 60 to 90 band on both seeds, and no card moved the smart bot by 20 or more,
so no card, enemy or relic number was changed. The Remember choice alone moved the Thief smart bot about
+19 (59 -> 78 on seed 7, rest-only versus rest-or-remember), the Medium about -7 to +23 depending on the skip
rule (noise is about 5); the Remembered upgrades are modest per card, the sim gain comes from a whole run of
them. Tried and reverted: Cold Whisper Haunt 2 -> 3 (Remembered 4) lifted Medium greedy only to 16 / 18 and
Medium smart to 112 / 120.

Remaining misses and weaknesses: Medium greedy is below the 18 floor on both seeds (10 / 15; its deck bloats to
about 25 cards and 76% of its boss fights are lost; the same cause as in 4e). Smart still almost never takes
Remember or Chorus of the Lost, and the Thief's Sharpen, Quick Study and Cleaned Out stay below 2% of runs, so
those numbers remain barely tested by the smart sim. Greedy has no Forgotten-cost judgement beyond Recall.

### Order and size

5a first (largest: engine, save migration, UI, tests), then 5b and 5c in parallel (different files), then 5d.
Each is its own PR into `thief-rework`. No version bump or release.

## Phase 6 plan: Oaths (6a and 6b built; 6c not started)

An Oath is a card you play once; it is then Sworn for the rest of the fight and keeps working (the Slay the
Spire Power). Proposed rules, all open to change:

- **Card type:** `CardData.oath: bool`. Playing it moves it to a new Sworn list in `CardPiles` (not discard,
  not Forgotten), shown as a small strip by the player. Sworn cards return to the deck after the fight, like
  the Forgotten pile. Dormant and Fading cards cannot be Oaths.
- **Effects:** an Oath carries `CardEffect`s that fire on a trigger instead of at once. New appended effect
  kinds, reusing the relic hooks already in `combat.gd`: at turn start (gain Block, Malice, Ward, Barbs, draw),
  on the first card played each turn (Shaken, Glimpse), when a card is Forgotten (Block or damage), when
  Anchor cards are kept. Stacks add if sworn twice.
- **Cost:** 1 to 2 energy, with a trade-off in the text (lose HP, add a Dread to the draw pile) so an Oath is
  a commitment, not free value.
- **Cards:** two per class, six in all, one neutral. Thief: *Quick Hands* (first card each turn draws and
  gains Malice 1), *Light Step* (turn start: Glimpse 2). Deserter: *Unbroken Vow* (turn start: Ward +1 up to
  3, adds a Dread now), *Standing Guard* (kept Anchor cards give Block). Medium: *Open Grave* (a Forgotten card
  deals 2 to all enemies, lose 4 HP now), *Quiet Debt* (turn start: Haunt 1 to all, lose 1 HP).
- **As built in 6a (differs from the effects bullet above):** no new effect kinds. `CardData` gains `oath`,
  `oath_trigger` (`TURN_START`, `FIRST_PLAY`, `ON_FORGOTTEN`, `ANCHOR_KEPT`) and `oath_effects`; the card's
  ordinary `effects` still happen when it is played (its cost), and `oath_effects` fire on the trigger. Any
  existing effect kind works as an oath effect: SELF reach lands on the player, anything else on every living
  enemy. `CardPiles.sworn` holds Oaths; a copy sworn twice fires twice. A card played as the first of a turn
  does not trigger its own FIRST_PLAY. Fading cards lost at end of turn each fire ON_FORGOTTEN; each kept
  Anchor card fires ANCHOR_KEPT. An Oath that costs HP at turn start can kill the player (a defeat). A Glimpse
  or Recall fired at end of turn opens at the next turn start. `RememberedData.oath_effects` can replace the
  oath effects on a Remembered Oath. `is_valid_oath()` rejects Dormant, Fading and empty Oaths.
  Tests: `tests/oath_tests.gd`. No card uses it yet, so play is unchanged.
- **As built in 6b:** six Oaths, provisional numbers. Thief: *Quick Hands* (1, adds a Dread to the draw pile;
  first card each turn: Draw 1, Malice +1 this turn), *Light Step* (1, lose 3 HP; turn start: Glimpse 2).
  Deserter: *Unbroken Vow* (2, adds a Dread; turn start: Ward +1), *Standing Guard* (1, lose 3 HP; turn start:
  Hold 4; the Deserter has too few Anchor cards for the planned Anchor trigger). Medium: *Open Grave* (2, lose
  4 HP; a card Forgotten: 2 to all enemies), *Quiet Debt* (1; turn start: Haunt 2 to all, lose 1 HP). The
  Stray's two come with the Stray. Display: a gold double border and an "Oath" keyword line on the card, a
  "Sworn" line in the pile label and a Sworn tab in the pile viewer (a card-list view rather than a separate
  strip by the player). Icons read an Oath's lasting effects. Vendor value counts oath effects three times
  (`OATH_FIRINGS`); the smart bot's deck score counts them `TYPICAL_REMAINING_TURNS + 1` times. None of the
  six has a Remembered upgrade yet. In-fight bot play of Oaths (when to swear one) is 6c.
- **Display and text:** keyword line "Oath: stays for the fight"; the card frame gets a distinct border.
- **Bots:** sim policies value an Oath as its per-turn effect times expected remaining turns.
- **Sub-phases:** 6a engine, piles, save-safe (decks unchanged); 6b the six cards, UI strip and text; 6c bots
  and balance. No version bump.

## Cross-cutting work

- `CardEffect` rule: new kinds are only appended, never reordered (`.tres` files store the integer).
  `tests/mechanics_tests.gd` walks every kind.
- Renames (Thorns to Barbs, Intent to Omen) are display-only: ids and code names stay unless a separate
  pass is approved.
- Tests per phase: rules in `mechanics_tests`, previews in `ui_battle_test`, saves in `run_save_tests`.
- Balance: re-run the sim after phase 4 and again after phase 5.
- Art is deliberately out of scope until mechanics settle.

## Open items

- Exact numbers for the retuned cards (decided in phase 4, with the sim).
- How many cards get each keyword, and which Forgotten-pile payoffs the Medium gets.
- Whether Glimpse needs UI beyond a simple pick-to-discard overlay.
- Oaths (see above).
