# Relics

Decisions (from the user): relics are sold by vendors only, one relic per vendor visit (two vendors on the line, so at most two per run); first set is 12 relics, 3 per class plus 3 neutral.

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
| Silk Gloves | Pickpocket | FIRST_PLAY_DRAW 1 | 70 |
| Skeleton Key | Pickpocket | FIRST_TURN_ENERGY 1 | 60 |
| Marked Deck | Pickpocket | PLAYS_BLOCK 4 | 65 |
| Grave Dirt | Medium | FIGHT_START_HAUNT 2 | 60 |
| Planchette | Medium | TURN_START_HEAL_PER_HAUNTED 2 | 70 |
| Bone Rosary | Medium | HAUNT_BONUS 1 | 75 |

Prices and amounts are placeholders for tuning.

## Run integration

- `Combat.create(...)` takes an optional trailing `relics: Array[RelicData] = []`; the combat hooks above live in `Combat` so the pure rules stay testable. Passing none behaves exactly as today.
- `RunState.relics: Array[RelicData]`. Acquire effects (MAX_HP) are applied once on purchase; WIN_GOLD and WIN_HEAL are applied in `complete_combat`.
- `Vendor` stocks one relic offer per visit from `relic_pool(character)` minus relics already owned (none if the pool is exhausted), priced by `RelicData.price`. `buy_relic()` follows the card rules: a failed purchase changes nothing; gold never goes negative. RunState wraps it as `vendor_buy_relic()`.
- Save: `RunSave` stores relic ids under `"relics"` (added at save version 2; required since version 3, which migrates older saves, unknown or duplicate ids rejected). The stop-line signature is unchanged. A restored MAX_HP is already in the saved player max HP, so it must not be applied twice.

## UI (second step)

A relic strip (code-drawn icons with tooltip text) on the battle screen and run screens; one relic slot at the vendor. Follows the existing code-drawn art conventions (`docs/CARD_ART_DESIGN.md`).

## Balance

Re-run the sim with bots that buy a relic when affordable (cheapest eligible first). Targets: a relic run should be a few points stronger, not decisive; trim any relic that moves a class by more than about 6 points.
