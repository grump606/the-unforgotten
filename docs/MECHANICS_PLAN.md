# Card mechanics rework: plan

Status: planning only. Nothing here is implemented. Lives on the `thief-rework` branch.

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
5. **Remembered upgrades.** A run save version bump with migration, the rest-site UI, card art for upgraded
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

**Starter decks.** Each class starts with its own signature card instead of one shared deck: 5 Shove, 3 Slip
Past, 1 Glimpse the Exit and 1 signature (Thief: Light Fingers; Deserter: Dig In; Medium: Cold Whisper).
Still 10 cards.

**Content tests (identity checks).** No enemy intent uses a temporary stack; no card targets enemies with a
temporary stack. Each class keeps its signature keywords (Thief: Ready, Shaken, Add card, multi-hit, Malice.
Deserter: Hold, Barbs, Ward, Anchor. Medium: Haunt, HP cost, a Forgotten payoff). Every keyword is used by at
least one shipped card. The golden price table is updated with every change.

**Balance.** A per-class sim baseline is recorded before the changes. After them, the smart bot's escape
rate should stay within about 5 points of the baseline for each class. The bots cannot judge every keyword
yet, so this is a sanity check, not a verdict.

**Sub-PRs into `thief-rework`:**
- 4a groundwork: `data/created/` and its loader, per-class starter decks, per-class sim baselines, the neutral
  retunes, golden table updates.
- 4b Thief, 4c Deserter, 4d Medium (parallel after 4a): the retunes and new cards for that class.
- 4e: identity and keyword-coverage tests, a final balance pass, README card list.

**Balance baseline** (`run_sim.gd --runs 150 --seed 7 --character C --policy P`, 2026-11-04). Before is
commit 0e071ee (the old starter decks: each class held its own mix of class cards); after is Phase 4a (the
new starter decks and the two neutral retunes). Escapes out of 150:

| Class | Policy | Before | After |
|---|---|---|---|
| Thief | greedy | 25 (16.7%) | 11 (7.3%) |
| Thief | smart | 71 (47.3%) | 54 (36.0%) |
| Deserter | greedy | 33 (22.0%) | 70 (46.7%) |
| Deserter | smart | 72 (48.0%) | 109 (72.7%) |
| Medium | greedy | 34 (22.7%) | 48 (32.0%) |
| Medium | smart | 97 (64.7%) | 73 (48.7%) |

The 4a moves are well past 5 points, and nearly all of it is the starter deck: the old decks held four
class cards (Thief: Mark the Weak, Lift, Sleight, Last Pocket; Deserter: Shoulder Charge, Iron Resolve,
Hold the Line, Bash; Medium: Confess, Lingering Dread, Penance, Cold Whisper) and the new ones hold one,
swapping the rest for Shove and Slip Past. The Deserter's old starting cards were weaker in the bots' hands
than plain Shove and Slip Past plus Dig In; the Thief and Medium lose cards their bots used well. The
Glimpse the Exit and Flurry retunes are small next to that. Not attributed card by card; the 4b-4d class
retunes and the 4e balance pass move these again, so the targets are the 4e numbers, not these.

Relics and enemy content are out of scope here (phase 5).

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
