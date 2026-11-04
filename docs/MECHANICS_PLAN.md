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
