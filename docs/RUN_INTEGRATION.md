# Run-layer integration contract

How a future run layer (map, vendors, rest sites, cutscenes) drives `combat/` without changing it. `tools/run_stub.gd` is a throwaway run layer that exercises exactly this contract.

## Starting a fight

```gdscript
var combat := Combat.new(player, deck, enemy_datas, rng_seed)
combat.combat_ended.connect(on_ended)   # connect BEFORE start()
combat.start()
```

- `player: Combatant` - the caller's persistent instance (see ownership).
- `deck: Array[CardData]` - the full deck for this fight. `CardPiles` copies the array, so later edits to the caller's array do not affect a running fight.
- `enemy_datas: Array[EnemyData]` - 1 to `Combat.MAX_ENEMIES` (3) entries. `StarterContent.varied_encounter(count, rng)` and `early_encounter(count)` build them; the loaders return smaller or empty arrays if a resource fails to load, so check `size()`.
- `rng_seed: int` - seeds shuffling only. Same seed + same deck + same inputs => same fight.

Drive it with `can_play(i)`, `play_card(i, target_index := -1)` and `end_player_turn(discard_indices := [])` while `phase == Combat.Phase.PLAYER_TURN`. `play_card` returns false (changing nothing) for illegal plays. `-1` targets the first living enemy; SELF and ALL_ENEMIES cards ignore the target.

Hand rules: the hand holds at most `HAND_MAX` (10) cards during a turn and you keep at most `HAND_SIZE` (5) at the end of it. `end_player_turn(discard_indices)` discards those hand indices (the rest stay in hand), runs the enemy phase and returns true; it returns false, changing nothing, if an index is out of range or repeated or more than `HAND_SIZE` cards would stay. A caller whose hand never exceeds 5 can call it with no argument. A UI uses the stepwise form instead: `begin_discard()` (phase `DISCARDING`), `toggle_discard(i)`, `confirm_discard()`, `cancel_discard()`. Next turn draws back up to `HAND_SIZE`.

## Ownership

| Caller owns | Combat owns |
|---|---|
| player `Combatant` (HP, max HP, name), carried between fights | `piles`, `energy`, `turn`, `phase` |
| the deck array (add/remove cards between fights) | `enemies` (`EnemyUnit`s built from the `EnemyData`) |
| the seed(s); derive each fight's seed from a run RNG | its internal RNG |

`CardData`, `CardEffect` and `EnemyData` are shared immutable definitions; never mutate them (copy with `duplicate(true)` first, as the loaders do for enemies).

## Outputs

- `combat_ended(victory: bool)` fires exactly once, when the last enemy dies (true) or the player's HP reaches 0 (false). It fires synchronously inside `play_card` or `end_player_turn`.
- After it fires, `combat.phase == Phase.ENDED` and `player.hp` is the HP to carry forward. Nothing is written back for you: the `Combatant` you passed in is already the result.
- `state_changed`, `card_played`, `enemy_acted` are for UIs; a run layer does not need them.

## Reset per fight

- Statuses: `Combat.new` calls `player.clear_statuses()`, so EXPOSED never leaks into the next fight.
- Block: cleared when the fight ends and again at the start of turn 1, so `player.block` is 0 between fights.
- Piles, hand, energy, turn count: new `Combat` => new `CardPiles`; every deck card starts in the draw pile, shuffled.
- Enemy HP, intents, statuses: fresh `EnemyUnit`s per fight.
- NOT reset: `player.hp` and `player.max_hp`.

## A run layer must NOT assume

- That a `Combat` can be restarted or reused: `start()` asserts `NOT_STARTED`. Make a new `Combat` per fight.
- That fights terminate: nothing caps the number of turns (a defensive deck can stall), so the caller needs its own turn cap. A single turn is capped at `Combat.MAX_PLAYS_PER_TURN` (50) plays, after which only ending the turn is possible, so zero-cost draw loops cannot lock a turn.
- That HP is healed for you: call `player.heal(amount)` (clamped to max HP, returns HP restored) for rest sites and vendors.
- That `combat_ended` can be read late: connect before `start()` (it is a signal, there is no `victory` property; afterwards use `player.is_dead()`).
- That `Combat.new` validates the enemy count in release builds: it only asserts. Use `Combat.create(...)`, which returns null (after logging) for fewer than 1 or more than `MAX_ENEMIES` enemies.
- That `Combat.new` leaves `player` untouched: it clears the player's statuses and, while the fight runs, links the player's `changed` signal to its own `state_changed`. The link is removed when the fight ends.

## API gaps

Fixed after the stub exposed them: `Combatant.heal()`, the player signal link now removed when a fight ends, block cleared at fight end, and `Combat.create()` for validated construction (bad enemy count or an already-dead player returns null). A fight you give up on (for example a stall cap) must be released with `combat.abandon()`, which removes the player link without emitting `combat_ended`; otherwise the link stays on the persistent player.

Still open (minor, caller-side workarounds below):

1. No outcome query besides the signal (`combat.victory` or similar). Capture it with a lambda before `start()`, as the stub does, or use `player.is_dead()` afterwards.
2. No turn cap or stall detection in `Combat`; every caller (the stub, `balance_sim.gd`) keeps its own. Proposal if it spreads: an optional `max_turns` that ends the fight as a defeat.

## How the stub demonstrates the seam

`godot --headless --path . -s res://tools/run_stub.gd -- --seed 1 [--character ID]` builds one `Combatant` with the chosen character's max HP (default Deserter, 52) and starting deck, then chains fights with 1, 2 and 3 enemies from `varied_encounter`, using one run RNG for encounters, per-fight combat seeds and rewards. Between fights it heals 8 (clamped) and appends one reward card (a random distinct card type from the starting deck). It stops on a loss or a stall. Per-fight lines show HP in and out, and the next fight's "HP before" equals the previous line's post-rest HP (compare consecutive lines of the output). After `start()` the stub asserts block is 0 and EXPOSED is 0, failing with exit 1 if state leaked. Same seed gives identical output; bad arguments (a non-integer `--seed`, an unknown `--character`) print usage and exit 2.

## Status

`tools/run_stub.gd` was the throwaway stand-in for the run layer; the real one is now `run/run_state.gd` (see `run.gd` for how a screen drives it). The stub still runs and is kept as a minimal example of the public API.

## Stop types

`RunState.StopType`: `COMBAT` (`start_combat()` then `complete_combat(victory)`; a win pays gold and offers a reward, except a boss stop (`Stop.boss`), which fights `StarterContent.boss_encounter()` and pays and offers nothing), `REST` (`rest()`), `STORY` (`current_beat()`, `read_story()`), `VENDOR` (`vendor()` for the stock, `vendor_buy_card/remove_card/buy_heal`, then `leave_vendor()`). Code that walks the line must handle every type: assuming stop 0 is a fight breaks. `run.gd` and `tools/run_sim.gd` are the two reference walkers.

## Save and resume

`run/run_save.gd` (`RunSave`) serialises a run to `user://run_save.json` (`to_dict` / `from_dict`, version field, atomic write). `run.gd` saves at the start of each stop (never mid-fight, mid-reward or mid-vendor-visit; `RunState.at_stop_boundary()` says when) and deletes the save when the run ends. Resuming mid-stop restarts that stop from its beginning with the saved RNG position, so the same encounter, rewards and stock come up. On launch a valid save offers Continue or New Run; a missing save starts a new run silently, and a corrupt, invalid or version-mismatched save starts a new run with a visible message. Every field of a save is validated on load. Map runs (docs/MAP_DESIGN.md, "Phase 3") save in format 5 with their route and position and also when the map is shown; line runs still write format 4.
