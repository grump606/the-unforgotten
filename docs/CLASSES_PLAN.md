# Classes build plan

Three playable characters (Deserter, Pickpocket, Medium), each with a class card pool, sharing a neutral pool. Status: Phases 1 (character infrastructure), 2 (character select screen), 3 (Deserter), 4 (Pickpocket), 5 (Medium) and 6 (bots and balance) done; Phase 7 (story) not started. Greedy escape rate over 600 runs and seeds 1 to 3: Deserter 42.7%, Pickpocket 43.9%, Medium 45.2%; smart about 75% / 62% / 56%. Phase 6 nerfed the Deserter's Hold cards (Hold the Line 5/2, Dig In 2/2, Last Stand 14/10) because HP alone could not fix them without making the Deserter frailer than the Medium.

## Decisions assumed (change any before Phase 1)

- Neutral pool: Slip Past, Brace, Shove, Glimpse the Exit, Flurry, Sweep.
- Existing non-neutral cards move into classes: Deserter gets Shoulder Charge, Iron Resolve, Guarded Strike, Heavy Blow, Steady Breath. Pickpocket gets Mark the Weak, Cutting Word, Hamstring, Second Wind. The Medium has no existing cards.
- Starting deck (10 cards): 3 Shove, 2 Slip Past, 1 Glimpse the Exit, plus 4 class cards.
- Starting HP: Deserter 47, Pickpocket 34, Medium 41 (tuned in Phase 6; the Medium's HP-cost cards make it the most HP-sensitive class).
- Counter-Stance keeps its thorns effect (the costliest new mechanic; swap it if it proves awkward).
- Reward offers: about 2 class cards and 1 neutral card per offer of three.
- Cards that cost HP cannot be played if the player would die from the cost.
- Old version-1 saves are rejected with a message rather than migrated (only development saves exist).

## Card lists

Neutral (cost, effect): Slip Past (1, Block 5), Brace (0, Block 2), Shove (1, Damage 6), Glimpse the Exit (0, Draw 2), Flurry (0, Damage 3), Sweep (2, Damage 5 to all).

**Deserter** (starting class cards in bold). New: **Hold the Line** (1, Block 5, Hold 2), **Bash** (1, Damage equal to current Block), Dig In (0, Block 2, Hold 2), Cold Steel (1, Damage 5, or 10 with 10+ Block), Counter-Stance (2, Block 8, thorns 4 this enemy phase), Last Stand (3, Block 14, Hold 10). Existing: **Shoulder Charge**, **Iron Resolve**, Guarded Strike, Heavy Blow, Steady Breath.

**Pickpocket**. New: **Lift** (1, Damage 3, Draw 1), **Sleight** (0, Expose 1), Pocket Watch (1, gain 1 energy, Draw 1), Last Pocket (1, Damage 4 plus 3 per card played earlier this turn), Spree (2, Damage 2 per card played this turn, counting itself). Existing: **Mark the Weak**, Cutting Word, Hamstring, Second Wind.

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
- Characters are built from existing cards only: Deserter and Pickpocket get theirs, the Medium temporarily gets a neutral-only deck.
- Done when: all three characters start a run, rewards and vendor stock show only that class plus neutral, save and resume round-trips the character.

**Phase 2: Character select and new-run flow.** Size: S to M. Edits `run.gd`, `run.tscn`.
- A character screen before a new run (name, HP, one-line pitch, starting deck preview).
- New Run from the pause menu and the end card goes to the select screen.
- Done when: the UI flow test starts a run as each character and the header shows the character.

**Phase 3: Deserter mechanics and cards.** Size: M.
- Hold, `DAMAGE_PER_BLOCK`, `DAMAGE_IF_BLOCK`, thorns; the six new cards; move the existing five.
- UI shows Hold and thorns amounts.
- Done when: unit tests cover each mechanic (Hold carries exactly the right amount, thorns hit each attacker, edge cases such as zero Block).

**Phase 4: Pickpocket mechanics and cards.** Size: S to M.
- `GAIN_ENERGY`, `DAMAGE_PER_PLAY`; five new cards.
- Done when: unit tests cover the energy arithmetic and the per-play scaling (including first card of the turn, and the 50-play cap).

**Phase 5: Medium mechanics and cards.** Size: L.
- Haunt status (including UI), `LOSE_HP` with `hp_cost`, heal per Haunted enemy, damage per Haunt; nine new cards.
- Done when: unit tests cover Haunt decay and ordering against enemy intents, that a Haunt kill removes that enemy's attack, and that HP-cost cards cannot be played to death.

**Phase 6: Sim and balance.** Size: M. Edits `tools/`.
- A `--character` option for `run_sim.gd` and `balance_sim.gd`.
- Teach both policies the new effect kinds.
- Tune each class: greedy bot 40 to 50% escape rate, and the three classes within about 10 points of each other. Smart bot reported for each.

**Phase 7: Story.** Size: M. Edits `data/story/`, `run/story_content.gd`.
- Per-character versions of the boarding, Conductor and Last Light beats (why this passenger is aboard, what the Conductor says to them). `StoryContent.beat(character, index)` with a neutral fallback.
- Done when: every character sees their own beats, and the stop-line signature check still passes.

## Risks

- **Enum order.** Existing `.tres` files store effect kinds as integers. Only append to the enum.
- **Policies mis-valuing cards.** Bots that do not understand Hold, Haunt or Momentum will understate those classes, so the balance numbers would mislead. Phase 6 must verify the bot actually uses the new cards (count plays per card in the sim).
- **Medium scope.** It is the only class with no existing cards and the most new rules. If time runs short, ship Deserter and Pickpocket first; the infrastructure from Phases 1 and 2 supports that.
- **Enemy design.** Haunt and thorns interact with enemy intents (multi-hit enemies punish Block-only play, thorns punish the Whisperer's many small attacks). Review the enemy pool after Phase 5.
- **Reward pool size.** Fewer cards per class means repeats show up sooner. Watch for it while playtesting.

## Testing strategy

- Each mechanic gets unit tests in `tests/run_tests.gd` style with hand-built decks, written before the card data.
- Content tests: every card belongs to exactly one class or neutral, ids are unique, every character's starting deck is 10 cards, every class pool has enough cards for a three-card offer.
- Save tests: character round-trip, version 1 rejection, a deck with cards from another class rejected.
- UI flow test: the select screen, plus one full scripted run per character.
- Sim: `run_sim.gd --character <id>` for both policies, escape rates recorded in the README.
