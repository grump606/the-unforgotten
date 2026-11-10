# Adding content

Content is data (`.tres` under `data/`) plus explicit, ordered registries in `combat/starter_content.gd`. Order matters: shuffles and encounter draws depend on list order, so seeded sim output changes if a list is reordered or a new entry is inserted in the middle. Append new entries at the end unless you want to change the balance on purpose. `tests/content_tests.gd` scans `data/` and fails when a file is missing from its registry, a registry path does not load, or an enemy has no portrait entry.

## A card
1. Add `data/cards/<name>.tres` (copy a similar one). Set `character` to a class id, or leave it empty for the neutral pool.
2. Add a `<NAME>_PATH` constant and append it to `ALL_CARD_PATHS` in `starter_content.gd`.
3. Optionally add it to a character's `starting_deck`.

Set `effects` from `CardEffect.Kind` (`combat/card_effect.gd`; a card may have several, applied in order) and `target_mode` from `CardData.TargetMode` (single enemy, all enemies, self; block- and draw-only cards should target self). Being in `ALL_CARD_PATHS` is what puts a card in the reward pool and vendor stock (`StarterContent.reward_pool(character_id)`: neutral cards plus that character's own). `extended_deck()` is only the fixed balance-testing deck used by the stand-alone battle scene and the sims; its exact composition and size (`EXTENDED_DECK_SIZE`, 14) are pinned in `tests/content_tests.gd`, so change it only on purpose. A new card also means updating the card-count checks in `tests/content_tests.gd` (for example the `all_cards` size). Open the project once (or run `--import`) so Godot registers the new file.

To let a card be Remembered at a rest stop, give it a `remembered` block (a `RememberedData` sub-resource in the same `.tres`, `combat/remembered_data.gd`): the full replacement `effects` list, an optional `cost` (-1 keeps the card's own) and `gain_keywords` / `lose_keywords`. The upgrade must be a modest improvement that keeps the card's identity. There is no second card id: the game builds the `+` card at run time (`CardData.remembered_card()`), and saves store it as `id+`.

## A relic
1. Add `data/relics/<name>.tres` with a unique `id` (and `character` if class-bound).
2. Append its path to `RELIC_PATHS`. Implement the effect where the hook lives (see `docs/RELICS_DESIGN.md`), and add a badge in the relic art if it needs a new one.

## An event
1. Add `data/events/<id>.tres`: an `EventData` (title, scene text, optional `class_body` per character, the painted `scene` behind it) with two to four `EventChoice` buttons, each with its `effects` (`EventEffect`, `combat/event_effect.gd`). Fields and effect kinds are described in `docs/EVENTS_DESIGN.md`; the cost and reward line under a button is generated from the effects, so write the numbers only in the effects. Give every event a button that costs nothing, and do not use dashes in the text.
2. Append its path to `EVENT_PATHS` in `starter_content.gd` (`tests/event_tests.gd` fails for a file that is not listed). A new effect kind is appended to `EventEffect.Kind`, given a `describe()` line, and applied in `RunState._apply_event_effect`.

## An enemy
1. Add `data/enemies/<name>.tres`.
2. Add a `<NAME>_PATH` constant. Regular enemy: append to `ALL_ENEMY_PATHS`, then put it in `SMALL_ENEMY_PATHS` (joins pairs and trios; also add to `TRIO_EXCLUDED_PATHS` to keep it out of trios), `PAIR_BIG_ENEMY_PATHS` or `SOLO_ONLY_ENEMY_PATHS`. Boss: add to `BOSS_ENEMY_PATHS` and give it its own encounter function.
3. Add its id (the file name, set as `id` in the .tres) to `Fighter.ART_KEYS` (`run/fighter.gd`) with a figure height in `Fighter.HEIGHTS`, and put its painted sprite at `art/layers/<key>/sprite.png` (see `docs/STAGE_DESIGN.md`; without one the stage falls back to the old figure layer, then a ghost). Art is keyed by id, so ids must be unique.
4. Optional: set `max_haunt` in the .tres to cap the Haunt stacks the enemy can carry (default 0 = no cap; Haunt applied past it is lost, whether it comes from a card, the Haunt bonus relic or the fight-start Haunt relic). The cap is enforced in `Combatant.apply_status`, copied from the data by `EnemyUnit`, and kept by `StarterContent.scaled`. The enemy tooltip then shows "Haunt capped at N". Only the Brakeman uses it (9); `tests/content_tests.gd` pins that.

## Boss phases
Any enemy can have a second phase: in its .tres set `phase_two_intents` (a new cycle, enemy intents only: Damage, Block, Expose), `phase_two_hp_percent` (default 50: the switch happens once HP is at or below that share of max) and `phase_two_title` (banner text for the UI). Leave `phase_two_intents` empty for a one-phase enemy. The switch is checked after every card play, after Haunt at the start of the enemy phase and after each enemy acts (so thorns count), happens once, restarts the intent index at the first phase two intent and fires `Combat.enemy_phase_changed(enemy, 2)`; `EnemyUnit.active_intents()` is the current cycle. Both bosses use it (Bellkeeper: no more blocks, heavier hits; Eraser: no more blocks, faster hits). Check winnability for every class (`StarterContent.character_ids()`) after tuning (`tools/balance_sim.gd` and `tools/run_sim.gd`; a boss-only check is easy to write with `StarterContent.boss_encounter()` and `SimPolicy`), and keep `tests/phase_tests.gd` green.

## A character
1. Add `data/characters/<id>.tres` (`id` must equal the file name and registry key) with a starting deck.
2. Add it to `CHARACTER_PATHS` (the order is the select screen order).
3. Add class cards and relics tagged with the id, per-character story beats under `data/story/<id>/`, and a palette in the card and select art.

Then run `powershell -ExecutionPolicy Bypass -File scripts/check.ps1`.
