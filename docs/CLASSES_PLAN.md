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

**Phase 4a (bot logic for Scent) is built; the balance pass is 4b.** Greedy (`SimPolicy`): Scent cards rank early (before the attacks that use them), spenders rank after the ordinary attacks and wait until the stack is worth spending (2 plus the card's cost) while a card in hand can still add to it, a pure Scent card is skipped at the cap, and every single-target card goes to the enemy holding Scent. Smart (`SmartPolicy`): a Scent effect is worth its points times the other affordable hits this turn plus 80% of a typical fight's later hits, with an ordering bonus when attacks follow and a small preference for the current quarry; a spender that does not kill pays the same value for the stack it uses up, which makes the other attacks go first. Tests: `tests/scent_bot_tests.gd`. Stray escapes of 300, seed 1: greedy 146 (48.7%), smart 140 (46.7%) (before 4a the smart bot escaped 9%). Both bots now play the starting four every run. Left for 4b: the smart bot never takes Worry, Howl, Pounce, Savage or Nose to the Wind (its deck scores are low), Bring Down is almost never played (greedy 0.05 plays per run: a stack of 5 is rare), and no tuning has been done.

**Card updates, step 1 (neutral split) is built.** `CardData.basic` marks Shove and Slip Past: every character still starts with them and the vendor still stocks them (`StarterContent.vendor_pool`), but they are never offered as rewards (`StarterContent.reward_pool`). Eight shared neutral cards join the pool (Steady Hands, Counter Step, Second Look, Downpour, Hold Fast, Pull Together, Lucky Break, Shake Them; all existing effect kinds, no rarity yet) and Sweep now costs 1. Twelve neutral cards can be offered. Run saves accept basic cards (they validate against the vendor pool). Escapes of 300, seed 1, before and after: greedy Deserter 42 -> 49%, Thief 29 -> 41%, Medium 6 -> 21%, Stray 49 -> 56%; smart Deserter 54 -> 63%, Thief 52 -> 48%, Medium 62 -> 66%, Stray 47 -> 59%. The shared cards lift every class, so the balance pass (4b) has to run after the remaining card updates. Next step: wider class pools.

**Card updates, step 3 (Oath triggers and the discard keyword) is built.** Five new `OathTrigger` values, appended after the first four: END_OF_TURN (last thing before the enemies act, so its Block is up for the enemy phase), ON_BLOCK_GAINED (after a card that raised the player's Block), ON_HP_LOST (after a card that cost HP; an Oath's own cost never triggers itself), EACH_PLAY (after every card played, not the Oath's own play) and ON_DISCARD (once for each card thrown away at the end-of-turn discard). `CardData.discard_effects` is a new keyword, "Discarded": effects that fire only when the card is thrown away at the end of the turn (not when played, Forgotten, lost as Fading or kept); self-reach effects land on the player, any other on every living enemy, Scent on the quarry; a Draw at that point joins the hand, so it gives a bigger next hand when five are kept. New cards: Oaths Iron Skin (Deserter, end of turn: Block 4), Bulwark Vow (Deserter, Rare, when you gain Block: 3 to all), Nick and Run (Thief, Rare, each card played: 1 to all), Blood Price (Medium, when a card costs HP: Haunt 3) and Pack Instinct (Stray, first card each turn: Scent 1); Thief discard cards Loose Change, Slipped Pocket and Spare Key. The Stray has one Oath so far (its second, Keep the Trail, needs a rule that Scent survives the quarry). Bots: the smart bot has a firing share for each trigger and prefers throwing away a card with discard effects (deck score counts them at half); greedy also discards such cards first. Card faces show the Discarded keyword and a "When discarded:" line. Vendor value counts discard effects at half. Escapes of 300, seed 1, after step 2 then step 3: greedy Deserter 44 -> 48%, Thief 42 -> 40%, Medium 19 -> 21%, Stray 57 -> 51%; smart Deserter 57 -> 60%, Thief 55 -> 63%, Medium 68 -> 72%, Stray 62 -> 65% (balance is still 4b).

**Card updates, step 2 (rarity) is built.** `CardData.rarity` (Common, Uncommon, Rare; default Common) is set on every card: 36 non-Common (28 Uncommon, 8 Rare), the starting cards and basics all Common. Rewards and vendor stock roll a rarity per slot first, then a card of it (`StarterContent.pick_by_rarity`, odds in `StarterContent.RARITY_WEIGHTS`: Common/Uncommon/Rare 70/27/3 in the first quarter of the stop line, 62/32/6, 52/38/10, 42/42/16 in the last; `RunState.rarity_tier()` picks the row). A rarity missing from the pool is skipped, so offers still fill. Uncommon and Rare cards show a small blue or gold gem at the right end of the name banner. No price change yet. Also fixed while reviewing the card sheet: Oath cards now show their lasting effect on the card face (it was missing; the face only listed the play effects), at a smaller font if needed, and `tools/card_sheet.gd` includes the Stray. Escapes of 300, seed 1, after step 1 then after step 2: greedy Deserter 49 -> 44%, Thief 41 -> 42%, Medium 21 -> 19%, Stray 56 -> 57%; smart Deserter 63 -> 57%, Thief 48 -> 55%, Medium 66 -> 68%, Stray 59 -> 62% (differences are mostly noise at this sample size; balance is 4b).

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

**Card updates, step 4 (wider class pools) is built.** Eight new cards per class, all on existing effect kinds, bring the pools to Deserter 24, Thief 26, Medium 23 and Stray 24. The Deserter gets its first area attacks (Cleave, Earthshaker) and Ward, Malice and Thorns tools (Fortify, Iron Will, Brace for Impact); the Thief gets cheap cyclers, Shaken and Expose tools and a Rare finisher (The Big Score); the Medium gets area Haunt (Whisper Campaign, Mourners), Drain and Dark Pact; the Stray gets more Scent builders and spenders (Lunge, Gnash, Maul, Pack Hunt, Cripple, Wild Hunt). Escapes of 300, seed 1, before and after: greedy Deserter 48 -> 55%, Thief 40 -> 52%, Medium 21 -> 30%, Stray 51 -> 52%; smart Deserter 60 -> 65%, Thief 63 -> 66%, Medium 72 -> 71%, Stray 65 -> 62%. Wider pools lift the greedy bot most, since it has more good cards to find. Next step: the balance pass (4b) over all four classes.

**Stray phase 4b (balance pass) is done.** One baseline after the card updates (greedy 55 / 52 / 30 / 52%, smart 65 / 66 / 71 / 62% for Deserter / Thief / Medium / Stray), one change: the Medium's max HP 60 -> 56, because its starting cards (Lingering Dread, Penance, Confess) carry the smart bot and it was the outlier. After: smart Medium 67%, greedy Medium 26%. The smart bot is the yardstick for a good player (all four classes now sit within 62 to 67%); the greedy bot is a floor, and its gap on the Medium is mostly the bot not using Haunt well. Known leftovers: the smart bot rarely takes the new Medium cards, so they are untested in play.

**Stray relics are built.** Hunter's Whistle (FIGHT_START_SCENT 2), Wolf Fang (SCENT_HEIR 2: more Scent passes on when the quarry dies) and Bloody Muzzle (QUARRY_KILL_HEAL 3), three new relic kinds appended to the enum, with code-drawn glyphs; see `docs/RELICS_DESIGN.md`. The relic-pool test no longer exempts the Stray. Escapes of 300, seed 1: greedy 52 -> 53%, smart 62 -> 64%.

**The Stray's second Oath is built.** Keep the Trail (Uncommon, 1 energy, adds a Dread to the draw pile): when the quarry dies, give the new quarry Scent 2 and draw 1. It uses a new Oath trigger, QUARRY_DIES (appended as 9), which fires after the half-Scent hand-over, only when the dead enemy held Scent and someone is still alive. This replaces the earlier idea of Scent surviving death, which the existing hand-over rule already covers. Escapes of 300, seed 1: greedy 53 -> 50%, smart 64 -> 62% (noise level).

**Remembered upgrades for the Oaths and the Stray are built.** All twelve Oaths and fifteen Stray cards now carry a Remembered block (38 cards in total, up from 11), bringing the Stray and the Oaths in line with the other classes. Cost cuts: Unbroken Vow, Bulwark Vow, Nick and Run and Blood Price (to 0), Bring Down (3 -> 2), Go Feral (2 -> 1). Number bumps elsewhere; Oaths use `RememberedData.oath_effects` where the sworn effect is what improves (Standing Guard Hold 7, Open Grave 6, Iron Skin Block 6, Pack Instinct Scent 2, Keep the Trail Scent 3, Quick Hands Malice +3), and Quiet Debt gains Block 3 on play. The existing remembered-block test checks each is worth more than its base by at most 10 vendor points. Escapes of 300, seed 1: greedy unchanged for Deserter 55%, Thief 52%, Medium 26% (that bot does not Remember), Stray 50 -> 51%; smart Stray 62 -> 71%, so the upgrades matter to a bot that Remembers. The smart Deserter, Thief and Medium were not re-run, and the Stray now sits above the others, so a second balance pass is due.

**Balance pass 4c (after Remembered upgrades).** Smart baseline, 300 runs, seed 1: Deserter 64.7%, Thief 66.7%, Medium 67.0%, Stray 71.0%; so only the Stray moved. One change: Stray max HP 40 -> 37. After: smart Stray 68.3%, greedy Stray 46.3% (was 50.7%). The smart bot now sits at 65 to 68% for all four classes.
