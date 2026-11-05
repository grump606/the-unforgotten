# Classes build plan

> **Naming note (v0.5.0):** the game was reskinned as "The Unforgotten". Enemy and relic display names changed (for example Brakeman = Bellkeeper, Conductor = Eraser, Gate Warden = Threshold Keeper). IDs, files and rules did not. This document still uses the original names; see [`docs/RESKIN.md`](RESKIN.md) for the full map.

Three playable characters (Deserter, Thief, Medium), each with a class card pool, sharing a neutral pool. Status: Phases 1 (character infrastructure), 2 (character select screen), 3 (Deserter), 4 (Thief), 5 (Medium) and 6 (bots and balance) done; Phase 7 (story) not started. Escape rate over 600 runs and seeds 1 to 3 (re-measured after the bot card-play fixes, see `docs/NEXT_STEPS.md`): greedy Deserter 37.7%, Thief 32.3%, Medium 28.3%; smart 60.8% / 70.8% / 56.9% (the Medium figures include the Bellkeeper Haunt cap, see `docs/LEVELS_DESIGN.md`; before it they were 29.6% and 65.8%). (The Phase 6 figures of 42.7 / 43.9 / 45.2 greedy and about 75 / 62 / 56 smart predate the longer line.) Phase 6 nerfed the Deserter's Hold cards (Hold the Line 5/2, Dig In 2/2, Last Stand 14/10) because HP alone could not fix them without making the Deserter frailer than the Medium.

## Decisions assumed (change any before Phase 1)

- Neutral pool: Slip Past, Brace, Shove, Glimpse the Exit, Flurry, Sweep.
- Existing non-neutral cards move into classes: Deserter gets Shoulder Charge, Iron Resolve, Guarded Strike, Heavy Blow, Steady Breath. Thief gets Find the Seam, Cutting Word, Hamstring, Borrowed Breath. The Medium has no existing cards.
- Starting deck (10 cards): 3 Shove, 2 Slip Past, 1 Glimpse the Exit, plus 4 class cards.
- Starting HP: Deserter 47, Thief 34, Medium 41 (tuned in Phase 6; the Medium's HP-cost cards make it the most HP-sensitive class).
- Counter-Stance keeps its thorns effect (the costliest new mechanic; swap it if it proves awkward).
- Reward offers: about 2 class cards and 1 neutral card per offer of three.
- Cards that cost HP cannot be played if the player would die from the cost.
- Old version-1 saves are rejected with a message rather than migrated (only development saves exist).

## Card lists

Neutral (cost, effect): Slip Past (1, Block 5), Brace (0, Block 2), Shove (1, Damage 6), Glimpse the Exit (0, Draw 2), Flurry (0, Damage 3), Sweep (2, Damage 5 to all).

**Deserter** (starting class cards in bold). New: **Hold the Line** (1, Block 5, Hold 2), **Bash** (1, Damage equal to current Block), Dig In (0, Block 2, Hold 2), Cold Steel (1, Damage 5, or 10 with 10+ Block), Counter-Stance (2, Block 8, thorns 4 this enemy phase), Last Stand (3, Block 14, Hold 10). Existing: **Shoulder Charge**, **Iron Resolve**, Guarded Strike, Heavy Blow, Steady Breath.

**Thief**. New: **Filch** (1, Damage 3, Draw 1), **Light Fingers** (0, Expose 1), Borrowed Time (1, gain 1 energy, Draw 1), Last Keepsake (1, Damage 4 plus 3 per card played earlier this turn), Many Hands (2, Damage 2 per card played this turn, counting itself). Existing: **Find the Seam**, Cutting Word, Hamstring, Borrowed Breath.

**Medium**. All new: **Confess** (1, lose 4 HP, Damage 12), **Lingering Dread** (1, Haunt 4), **Penance** (1, lose 2 HP, Block 8), **Cold Whisper** (0, Haunt 2), Grave Chill (2, Damage 6, Haunt 3), Spirit Tithe (1, heal 3 per Haunted enemy), Seance (1, lose 3 HP, Draw 3, gain 1 energy), Bleed the Veil (2, lose 6 HP, Haunt 8 to all), Reckoning (2, Damage equal to double the target's Haunt).

## Mechanics: what each needs in the code

Today `CardEffect.Kind` is `DAMAGE, BLOCK, DRAW, EXPOSE`, block clears at the start of each player turn (`Combat._begin_player_turn`), statuses are turn counters ticked by `tick_statuses`, and `Combat.plays_this_turn` already exists. New kinds are appended to the enum, never inserted, so the integer values stored in existing `.tres` files stay valid. `CardEffect` gains an optional `bonus` field for effects that scale.

| Mechanic | Where | Notes |
|---|---|---|
| Hold X | `Combatant.hold`; kept amount re-applied in `_begin_player_turn` after `clear_block` | Carry the lesser of the hold total and the Block left after the enemy phase. |
| Damage = current Block (`DAMAGE_PER_BLOCK`) | `Combat._apply` | Reads player Block at resolution. |
| Conditional damage (`DAMAGE_IF_BLOCK`) | `Combat._apply` | `amount`, `bonus`, threshold. Covers Cold Steel. |
| Thorns | `Combatant.thorns`, applied in `_apply` when an enemy damages the player | Cleared at the start of the player turn. |
| Gain energy (`GAIN_ENERGY`) | `Combat._apply` | Energy may exceed the per-turn amount within the turn. |
| Damage per card played (`DAMAGE_PER_PLAY`) | `Combat._apply` | Amount plus bonus times cards played earlier this turn. |
| Haunt | New `Combatant.Status.HAUNTED`; damage at the start of the enemy phase, before intents | Damage equals current stacks, then `tick_statuses` drops it by 1. Reuses the existing counter. |
| Lose HP (`LOSE_HP`) and `CardData.hp_cost` | `Combat._apply`, `can_play` | Ignores Block. `can_play` rejects a card whose HP cost would kill the player. |
| Heal per Haunted enemy, damage per Haunt | `Combat._apply` | Uses `Combatant.heal`, which already exists. |

Every new kind needs `describe()` text, UI text, and handling in `tools/sim_policy.gd` and `tools/smart_policy.gd`, whose heuristics only understand damage and block today.

## Phases

Every phase ends with `scripts/check.ps1` passing and a commit. Combat mechanics (Phases 3 to 5) all edit `combat/combat.gd` and `combat/card_effect.gd`, so they run one after another, not in parallel. Pure content (cards, story text, tests for data) can use parallel agents with separate file scopes.

**Phase 1: Character infrastructure (no new mechanics).** Size: M.
- `CardData.character: StringName` (empty means neutral).
- New `Character` resource: id, display name, max HP, starting deck as card ids, story set.
- `StarterContent.character(id)`, `reward_pool(character)` (class plus neutral), a class-weighted reward draw.
- `RunState.new(seed, character_id)` with a default so existing tests keep working; `Vendor` takes the class pool.
- `RunSave` version 2 stored `character`; version 1 is rejected with a message (the current version is 3, and version 2 saves are migrated on load).
- Characters are built from existing cards only: Deserter and Thief get theirs, the Medium temporarily gets a neutral-only deck.
- Done when: all three characters start a run, rewards and vendor stock show only that class plus neutral, save and resume round-trips the character.

**Phase 2: Character select and new-run flow.** Size: S to M. Edits `run.gd`, `run.tscn`.
- A character screen before a new run (name, HP, one-line pitch, starting deck preview).
- New Run from the pause menu and the end card goes to the select screen.
- Done when: the UI flow test starts a run as each character and the header shows the character.

**Phase 3: Deserter mechanics and cards.** Size: M.
- Hold, `DAMAGE_PER_BLOCK`, `DAMAGE_IF_BLOCK`, thorns; the six new cards; move the existing five.
- UI shows Hold and thorns amounts.
- Done when: unit tests cover each mechanic (Hold carries exactly the right amount, thorns hit each attacker, edge cases such as zero Block).

**Phase 4: Thief mechanics and cards.** Size: S to M.
- `GAIN_ENERGY`, `DAMAGE_PER_PLAY`; five new cards.
- Done when: unit tests cover the energy arithmetic and the per-play scaling (including first card of the turn, and the 50-play cap).

**Phase 5: Medium mechanics and cards.** Size: L.
- Haunt status (including UI), `LOSE_HP` with `hp_cost`, heal per Haunted enemy, damage per Haunt; nine new cards.
- Done when: unit tests cover Haunt decay and ordering against enemy intents, that a Haunt kill removes that enemy's attack, and that HP-cost cards cannot be played to death.

**Phase 6: Sim and balance.** Size: M. Edits `tools/`.
- A `--character` option for `run_sim.gd` and `balance_sim.gd` (done).
- Teach both policies the new effect kinds.
- (Rules note: since the `hand-keep` change the hand is no longer discarded each turn; see README, "Hand and discard rules". Bot escape numbers in these older docs predate it.)
- Tune each class: greedy bot 40 to 50% escape rate, and the three classes within about 10 points of each other. Smart bot reported for each.

**Phase 7: Story.** Size: M. Edits `data/story/`, `run/story_content.gd`.
- Per-character versions of the boarding, Conductor and Last Light beats (why this passenger is aboard, what the Conductor says to them). `StoryContent.beat(character, index)` with a neutral fallback.
- Done when: every character sees their own beats, and the stop-line signature check still passes.

## Risks

- **Enum order.** Existing `.tres` files store effect kinds as integers. Only append to the enum.
- **Policies mis-valuing cards.** Bots that do not understand Hold, Haunt or Momentum will understate those classes, so the balance numbers would mislead. Phase 6 must verify the bot actually uses the new cards (count plays per card in the sim).
- **Medium scope.** It is the only class with no existing cards and the most new rules. If time runs short, ship Deserter and Thief first; the infrastructure from Phases 1 and 2 supports that.
- **Enemy design.** Haunt and thorns interact with enemy intents (multi-hit enemies punish Block-only play, thorns punish the Whisperer's many small attacks). Review the enemy pool after Phase 5.
- **Reward pool size.** Fewer cards per class means repeats show up sooner. Watch for it while playtesting.

## Testing strategy

- Each mechanic gets unit tests in `tests/run_tests.gd` style with hand-built decks, written before the card data.
- Content tests: every card belongs to exactly one class or neutral, ids are unique, every character's starting deck is 10 cards, every class pool has enough cards for a three-card offer.
- Save tests: character round-trip, version 1 rejection, a deck with cards from another class rejected.
- UI flow test: the select screen, plus one full scripted run per character.
- Sim: `run_sim.gd --character <id>` for both policies, escape rates recorded in the README.

## Fourth class proposal: the Stray (design settled, not started)

Numbers and names are still open to tuning. Nothing here is built. Decided: half of the Scent moves on when the quarry dies, Scent is capped at 8, and the class has a second pillar, a Malice engine.

**Pitch.** The Eraser strips names, but an animal never had one to lose. The Stray is a memorial hound that
tracks by scent: it picks one quarry and does not let go.

**Identity.** The Thief is fast, the Deserter patient, the Medium costly. The Stray *hunts one target*: it
commits to a single enemy and pays off the longer it stays on it. Its resource is Scent, which no other class
uses. It has two pillars. **Scent** is the focus: build it on one enemy, then spend it. **Malice** is the
snowball: feral cards add permanent Malice, so every hit grows over the fight. Multi-hit cards feed both, since
Malice and Scent each add to every hit. It leans on systems already built (Malice, multi-hit, Shaken, Fading,
Ready) so the engine cost is small.

### The mechanic: Scent

- **Scent** is a stack status on an enemy. It lasts the fight and never ticks down.
- **One quarry.** Only one enemy can hold Scent at a time. Applying Scent to a different enemy moves the whole
  stack there. This is the commitment: switching targets costs you the build-up.
- **Cap.** Scent stops at 8. Applying more than that is wasted.
- **Passive bonus.** Every hit the player's cards deal to the quarry gets +1 per Scent. It is added with
  Malice, before Shaken and Expose, so multi-hit cards gain the bonus on every hit. Enemy attacks, Barbs and
  Haunt are not affected.
- **Spending.** "Run Down" style cards deal extra damage per Scent and then remove all of it. Spending is the
  payoff and resets the build-up, so the decision is when to stop building.
- **Quarry dies.** Half of its Scent, rounded down, moves to a random living enemy (chosen with the seeded
  fight RNG). With no living enemy left the fight is over anyway. Losing the target still costs you, but a
  fight with several enemies does not reset the class every kill.
- **Not Haunt, not Expose.** Haunt decays and ignores Block; Expose is a flat x1.5 for a few turns. Scent
  grows, targets one enemy, and rewards many small hits as well as one big one.

### Character

- Id `stray`, display name The Stray. Starting HP 40 (to tune; between the Thief and Deserter).
- Starting deck (10): 3 Shove, 2 Slip Past, 1 Glimpse the Exit, plus 4 class cards (in bold below).
- Reward and vendor pools follow the existing rule: the class pool plus the neutral pool.

### Cards (provisional, 15)

| Card | Cost | Effect |
|---|---|---|
| **Catch the Scent** | 0 | Scent 2 |
| **Snap** | 1 | Damage 4, 2 hits |
| **Bristle** | 1 | Block 5, Malice 1 until next turn |
| **Run Down** | 1 | Damage 4 plus 3 per Scent, spend all Scent |
| Worry | 1 | Damage 3, Scent 1, Shaken 1 |
| Circle | 1 | Block 6, Scent 1 |
| Nose to the Wind | 0 | Glimpse 2, Scent 1. Ready |
| Old Wound | 1 | Scent 2, Expose 2 |
| Howl | 1 | Shaken 1 to all enemies, Scent 2 |
| Pounce | 2 | Damage 5, 2 hits. Fading |
| Savage | 2 | Damage 4, 3 hits |
| Bring Down | 3 | Damage 6 plus 5 per Scent, spend all Scent. Forgotten |
| Hackles | 1 | Malice 1, Draw 1 |
| Tear Loose | 1 | Damage 3, 2 hits, Malice 1 |
| Go Feral | 2 | Malice 2. Forgotten |

The last three are the Malice engine: Hackles is the cheap setup, Tear Loose grows as it hits, Go Feral is the
big permanent buff (Forgotten, so it is a one-shot for the fight). There is deliberately no Forgotten-pile
recall; that is the Medium's identity.

### What it needs in the code

| Change | Where | Notes |
|---|---|---|
| `Status.SCENT` (stack kind) | `Combatant`, status table | Appended to the status enum. Not saved. |
| One-quarry rule | `Combat._apply`, SCENT branch | Clears Scent from any other enemy, then adds. |
| Scent bonus per hit | `Combatant.hit_damage` | Applies only when the attacker is the player and the defender holds Scent. Previews, intent display and both bot policies already call this function. |
| `CardEffect.Kind.SCENT` | `card_effect.gd`, appended | Apply Scent. `reach()` is ENEMIES (single target). |
| `CardEffect.Kind.DAMAGE_PER_SCENT` | appended | `amount` plus `bonus` per Scent, then clears it. Uses `hits` where the card has them. |
| Text and UI | `describe()`, status badge | Scent badge and tooltip on the enemy; live numbers on card faces like the other statuses. |
| Character data | `StarterContent`, `Character` resource, `run_save.gd` | The save check that rejects another class's cards must know the Stray. |
| Bots | `tools/sim_policy.gd`, `smart_policy.gd` | Focus fire on the quarry, build Scent before a spender, and do not spread targets. |

New effect kinds and statuses are only appended, never reordered. `tests/mechanics_tests.gd` walks every kind.

### Interaction with the rest of the rework

- **Oaths (phase 6):** the Stray gets two, to be designed once Scent is settled. First ideas: *Keep the Trail*
  (Scent is not lost when the quarry dies) and *Pack Instinct* (the first card each turn adds Scent 1).
  Oath triggers should include Scent applied and Scent spent so these are possible.
- **Remembered upgrades:** the usual rule (a stronger version of each card) with no class-specific work.
- **Omens and enemies:** an enemy that changes target or clears statuses would punish or counter Scent. Review
  the enemy pool once the cards exist; no enemy change is planned up front.
- **Relics:** at least one class relic that touches Scent (for example, a first Scent each fight is doubled).

### Phases

Each phase ends with `scripts/check.ps1` passing and a commit, as before.

**Status:** phase 1 (infrastructure) is built: `data/characters/stray.tres` (40 HP, neutral-only starting deck of 5 Shove, 4 Slip Past, 1 Glimpse the Exit), the `stray` entry in `StarterContent.CHARACTER_PATHS`, placeholder palette and colours for the card frame, battle stage and backdrop. The select screen shows four panels (the Stray has no painted or code-drawn figure yet). Tests exempt the Stray from the class-card, class-relic and distinct-rewards checks until phases 2 to 4 and its relics land.

**Phase 2 (Scent engine) is built.** `Status.SCENT` (a stack, capped at `Combatant.SCENT_CAP` = 8), the per-hit bonus in `Combatant.hit_damage` (added with Malice, before Shaken and Expose, so every hit of a multi-hit card gets it), `CardEffect.Kind.SCENT` and `DAMAGE_PER_SCENT` (appended; `amount` plus `bonus` per Scent, then the Scent is spent after every hit of the effect), `EffectContext.scent`, the one-quarry rule (`Combat._give_scent`: a new holder takes the old stack too), a card that targets several enemies marks the current quarry if it is among them else the first living one, and half of a dead quarry's Scent (rounded down) passes to a random living enemy using the fight's seeded RNG (`Combat._pass_on_scent`, run from `_check_phases`). Enemy intents cannot apply Scent. Oath effects can (one quarry). No card uses it yet. Card faces have a placeholder Scent glyph; the status badge on the enemy, the card-face live numbers and the bots are phases 3 and 4. Tests: `tests/scent_tests.gd`.

**Phase 3 (cards and UI) is built.** The fifteen cards of the table above are in `data/cards` (all tagged `stray`, provisional numbers) and in the reward pool; the starting deck is 3 Shove, 2 Slip Past, 1 Glimpse the Exit, Catch the Scent, Snap, Bristle and Run Down. An enemy holding Scent shows a Scent badge (stack size) and a tooltip; the drag preview already counts Scent because it goes through `Combatant.hit_damage`. Card faces show no per-target number for Scent (Scent belongs to the target, like Expose, so it stays in the preview line). The class has no relics and no Remembered upgrades yet, so the relic-pool test still exempts it. The bots only score the new kinds in a basic way (deck scoring, damage lists); in-fight play of Scent is phase 4. First sims (100 runs, seed 1, before phase 4): greedy 43%, smart 9%.

1. **Infrastructure.** The `stray` character with a neutral-only starting deck, so the select screen, saves and
   rewards work before any new mechanic. Small.
2. **Scent engine.** Status, one-quarry rule, hit bonus, the two effect kinds, unit tests (move on retarget,
   bonus on every hit of a multi-hit, spend clears, quarry death, preview matches real damage).
3. **Cards and UI.** The twelve cards, Scent badge, card-face live numbers, content tests.
4. **Bots and balance.** Teach both policies Scent, check the bot actually plays the cards (count plays per
   card), tune to the same targets as the other classes (greedy within about 10 points of the rest).
5. **Story.** The Stray's per-character boarding and boss beats (`StoryContent.beat`).

Sequence relative to Oaths: design the Stray first, then build mechanics phase 6a (Oath engine) with any shared
hooks the Stray needs, then phases 2 to 4 above, then the Oaths for all four classes in 6b and 6c.

### Risks

- **Single-target tunnel vision.** Fights with several weak enemies may feel bad if the quarry rule fights the
  player. The half-transfer rule on death and the Howl card are the mitigation; check in the sim.
- **Multi-hit plus per-hit bonus** can scale fast. Savage with 8 Scent and 3 Malice is 3 hits of 15. The
  Scent cap bounds one factor; if the sim shows runaway damage, lower the cap or trim Malice from Tear Loose.
- **Overlap with Exposed.** Old Wound stacks both. If the combination is too strong, drop Expose from it.
- **Bots mis-valuing setup cards.** Zero-damage turns look wasteful to a greedy policy, which would understate
  the class. This is the same risk as the Medium's Haunt and needs the same play-count check.

### Art dependencies (not decided here)

Art is out of scope until the mechanics settle. When it is time, the class will need: a left-facing player
sprite, a class battle backdrop, card art for the class pool, a Scent status icon, and character-select art.
Style decisions go in a separate art doc.

### Open questions

- Final name and starting HP (40 is a guess; tune in the sim).
- The two Oaths (first ideas above) once the Oath cards are designed in 6b.
- Whether the Malice engine and Scent together are too strong; the sim decides.
