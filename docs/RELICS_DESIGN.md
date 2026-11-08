# Relics

> **Naming note (v0.5.0):** the game was reskinned as "The Unforgotten". Enemy and relic display names changed (for example Brakeman = Bellkeeper, Conductor = Eraser, Gate Warden = Threshold Keeper). IDs, files and rules did not. This document still uses the original names; see [`docs/RESKIN.md`](RESKIN.md) for the full map.

Decisions (from the user): relics are sold by vendors only, one relic per vendor visit; first set was 12 relics, 3 per class plus 3 neutral. This was the first decision; the line now has more vendors and the set has grown, so the current counts are in `docs/GAME_FACTS.md`.

## Model

`RelicData` (Resource, `combat/relic_data.gd`): `id: StringName`, `display_name`, `description`, `character: StringName` (`&""` = neutral, like cards), `kind: RelicData.Kind`, `amount: int`, `price: int`. Data lives in `data/relics/<id>.tres`; `StarterContent` gets `all_relics()` and `relic_pool(character_id)` (class relics for that character plus neutral), mirroring the card equivalents.

`RelicData.Kind` is data-driven like `CardEffect.Kind`: **only append** to the enum.

| Kind | Meaning |
|---|---|
| MAX_HP | On acquire: max HP +amount and current HP +amount |
| FIGHT_START_BLOCK | Gain `amount` Block at the start of turn 1 of each fight |
| TURN_START_BLOCK | Gain `amount` Block at the start of every player turn |
| TURN_START_THORNS | Gain `amount` Thorns at the start of every player turn |
| FIRST_TURN_ENERGY | +`amount` energy on turn 1 of each fight |
| FIRST_PLAY_DRAW | The first card played each turn also draws `amount` |
| PLAYS_BLOCK | Every 3rd card played in a turn (`PLAYS_BLOCK_EVERY := 3`) gains `amount` Block |
| WIN_GOLD | +`amount` gold for each won non-boss fight |
| WIN_HEAL | Heal `amount` after each won fight (boss fight too is irrelevant: the run ends) |
| FIGHT_START_HAUNT | Every enemy starts the fight with `amount` Haunted |
| TURN_START_HEAL_PER_HAUNTED | At the start of every player turn heal `amount` per Haunted living enemy |
| HAUNT_BONUS | Cards that apply Haunt apply `amount` more |
| FIGHT_START_GLIMPSE | Turn 1 of each fight opens a Glimpse `amount` after the opening hand is dealt |
| FIGHT_START_MALICE | Start each fight with Malice +`amount` (lasts the fight) |
| FIGHT_START_WARD | Start each fight with Ward +`amount` (lasts the fight) |
| FIRST_FORGOTTEN_RETURN | The first Forgotten card played each fight returns to hand from the Forgotten pile |
| ANCHOR_END_BLOCK | At end of turn, each Anchor card still in hand gives `amount` Block through the enemy phase |
| FIRST_ATTACK_SHAKEN | The first card with a damage effect each fight applies Shaken `amount` to the enemies it hit |
| FIGHT_START_SCENT | On turn 1 the first living enemy becomes the quarry with `amount` Scent |
| SCENT_HEIR | When the quarry dies, `amount` more Scent passes on than the usual half (never more than it held) |
| QUARRY_KILL_HEAL | Heal `amount` when the quarry dies |

Per-turn grants happen after `start_turn_block()` (which resets Block to Hold and Thorns to 0), so they are not wiped.

## The twelve

| Relic | Class | Kind, amount | Price |
|---|---|---|---|
| Travelling Flask | neutral | MAX_HP 8 | 60 |
| Brass Token Purse | neutral | WIN_GOLD 4 | 50 |
| Ticket Stub Charm | neutral | WIN_HEAL 3 | 70 |
| Regulation Dog Tags | Deserter | FIGHT_START_BLOCK 8 | 55 |
| Barbed Greatcoat | Deserter | TURN_START_THORNS 3 | 65 |
| Field Ration Tin | Deserter | TURN_START_BLOCK 3 | 75 |
| Silk Gloves | Thief | FIRST_PLAY_DRAW 1 | 70 |
| Skeleton Key | Thief | FIRST_TURN_ENERGY 1 | 60 |
| Marked Deck | Thief | PLAYS_BLOCK 4 | 65 |
| Grave Dirt | Medium | FIGHT_START_HAUNT 2 | 60 |
| Planchette | Medium | TURN_START_HEAL_PER_HAUNTED 2 | 70 |
| Bone Rosary | Medium | HAUNT_BONUS 1 | 75 |

Prices and amounts are placeholders for tuning.

### Keyword relics (Phase 5c)

| Relic | Class | Kind, amount | Price |
|---|---|---|---|
| Cracked Lorgnette | Thief | FIGHT_START_GLIMPSE 2 | 60 |
| Hushing Veil | Thief | FIRST_ATTACK_SHAKEN 1 | 65 |
| Mourner's Armband | Deserter | FIGHT_START_WARD 1 | 70 |
| Iron Stakes | Deserter | ANCHOR_END_BLOCK 2 | 60 |
| Pressed Flower | Medium | FIRST_FORGOTTEN_RETURN 1 | 70 |
| Candle Stub | neutral | FIGHT_START_MALICE 1 | 75 |

### Stray relics

| Relic | Class | Kind, amount | Price |
|---|---|---|---|
| Hunter's Whistle | Stray | FIGHT_START_SCENT 2 | 65 |
| Wolf Fang | Stray | SCENT_HEIR 2 | 70 |
| Bloody Muzzle | Stray | QUARRY_KILL_HEAL 3 | 60 |

Pools before the Stray: 5 Thief, 5 Deserter, 4 Medium class relics plus 4 neutral. The new relics use code-drawn badges like the rest.

## Run integration

- `Combat.create(...)` takes an optional trailing `relics: Array[RelicData] = []`; the combat hooks above live in `Combat` so the pure rules stay testable. Passing none behaves exactly as today.
- `RunState.relics: Array[RelicData]`. Acquire effects (MAX_HP) are applied once on purchase; WIN_GOLD and WIN_HEAL are applied in `complete_combat`.
- `Vendor` stocks one relic offer per visit from `relic_pool(character)` minus relics already owned (none if the pool is exhausted), priced by `RelicData.price`. `buy_relic()` follows the card rules: a failed purchase changes nothing; gold never goes negative. RunState wraps it as `vendor_buy_relic()`.
- Save: `RunSave` stores relic ids under `"relics"` (added at save version 2; required since version 3, which migrates older saves, unknown or duplicate ids rejected). The stop-line signature is unchanged. A restored MAX_HP is already in the saved player max HP, so it must not be applied twice.

## UI (second step)

A relic strip (code-drawn icons with tooltip text) on the battle screen and run screens; one relic slot at the vendor. Follows the existing code-drawn art conventions (`docs/CARD_ART_DESIGN.md`).

## Balance

Re-run the sim with bots that buy a relic when affordable (cheapest eligible first). Targets: a relic run should be a few points stronger, not decisive; trim any relic that moves a class by more than about 6 points.
