# Card rewards proposal

Status: proposal only, nothing implemented. The owner said rewards "could use work" (`docs/NEXT_STEPS.md` item 2); this doc turns that into options. Anything marked (assumption) is mine, not a stated requirement.

## Current behavior

- A won non-boss fight pays `enemy_count * 8 + 5` gold (`Vendor.gold_for_win`) and rolls a reward in `RunState._roll_rewards` (`run/run_state.gd`). The boss pays nothing and offers nothing.
- The offer is `REWARD_CHOICES = 3` distinct cards: up to `REWARD_CLASS_CHOICES = 2` class cards, then neutrals to fill, then leftover class cards. Cards are shuffled uniformly with the run RNG from `StarterContent.reward_pool(character.id)` (class plus neutral, deduped by id).
- The player takes one card or skips (`resolve_reward(null)`). Skipping gives nothing. The offer is rolled at win time and kept in `_reward_choices`, so seeds are reproducible.
- UI (`run.gd` `_show_reward`): three buttons plus "Skip". No deck view, no card preview beyond name, cost and text.
- Vendor (`run/vendor.gd`): 3 cards drawn from the same pool, priced 10/16/24 by a value formula; remove a card for 15; heal 12 HP for 12. Two vendors per run.
- The bots: greedy never skips; the smart bot skips when the best card scores below the deck average (`tools/smart_policy.gd` `pick_reward`).

## Weaknesses (evidenced from the code)

1. **Small pools, no memory.** Pool sizes are about 17 (Deserter: 11 class + 6 neutral), 15 (Thief) and 15 (Medium) by `.tres` count. Each roll is independent, so the same card can appear in consecutive rewards and in the vendor, and a card already owned is offered as if new. `CLASSES_PLAN.md` line 90 already flagged this risk.
2. **Only four rewards per run.** The default line has four non-boss fights (1, 2, 2, 3 enemies), so a whole run adds at most 4 cards. Each pick matters a lot and a weak offer cannot be recovered from.
3. **No rarity or power curve.** Every card is equally likely at fight 1 and fight 4. Nothing signals a strong card; the vendor's price tiers are the only power signal and rewards ignore them.
4. **One reward type.** The reward is always "add a card". No upgrade, remove, heal, gold or max-HP option, even though removal and heal already exist as vendor services and `Vendor.remove_card` is reusable.
5. **Skip has no value.** Skipping is free but pays nothing, so it is only correct when all three are bad. The smart bot already skips when the best card is below deck average, which suggests offers are often not worth taking.
6. **Gold and reward are disconnected.** Gold is a flat function of enemy count and cannot be spent until a vendor (stop 7 at the earliest). Total gold before the last vendor is about 13+21+21+29 = 84 (computed from the formula), against stock prices of 10 to 24, so gold is generous late and useless early.
7. **Class mix is fixed.** 2 class + 1 neutral regardless of deck state; no way to steer toward a build, and no reroll.
8. **Untested economy.** NEXT_STEPS notes the economy is untested beyond a back-of-envelope check. The sim (`tools/run_sim.gd`) never exercises a skip-for-value choice because none exists.

## Candidate designs

### A. Tuned pick-one (smallest change)
Keep "pick 1 of 3". Add: no duplicates of cards already offered at a previous reward this run, no card already owned twice (assumption: duplicates are unwanted), and a small gold payout for skipping (e.g. 10).
- Pro: tiny change, saves and sim barely move. Fixes weaknesses 1 and 5.
- Con: leaves 2, 3, 4 untouched; still feels like one note.

### B. Rarity tiers plus an upgrade option
Add a `rarity` field to `CardData` (common, uncommon, rare). Offer weights depend on stop depth (rares more likely later). Add a fourth slot to the screen: "Sharpen" (upgrade a deck card: needs upgraded-card data) or "Remove a card" instead of a card.
- Pro: gives progression, a reason to skip, and a power curve. Fixes 3, 4, 5.
- Con: biggest content cost: rarity tagging of about 45 cards and upgraded variants for any upgrade scheme. Needs the bots to value upgrades. Save format changes if upgraded cards are new resources.

### C. Choice of reward kind (middle)
Each reward screen offers pick-1-of-3 cards plus fixed non-card alternatives drawn from existing systems: remove a card (free, once per run or per N fights), heal part of the missing HP, or take bonus gold. No rarity and no upgrades. Pool memory as in A.
- Pro: reuses `Vendor.remove_card` and `Combatant.heal`; makes skip meaningful; no new card content. Fixes 1, 4, 5, partly 6.
- Con: removal and heal could make the vendors redundant, and it shifts the balance everyone tuned (escape rates 40 to 50% greedy) upward; needs retuning.

## Recommendation: A then C, defer B

Do A first as a safe fix, then C behind constants so balance can be tuned in the sim. B is the right long-term direction but needs a content pass (rarity per card, upgrades) that should wait until playtesting says the card pool, not the reward flow, is the problem (assumption: playtest, NEXT_STEPS item 1, comes first).

## Implementation outline (A + C)

Files touched:
- `run/run_state.gd`: track `_offered_ids` (cards shown this run); `_roll_rewards` excludes them and anything the deck already holds twice; new `REWARD_ALT_*` constants; `resolve_reward` gains alternatives (e.g. `resolve_reward_alt(kind)`), skip pays `SKIP_GOLD`. Persist the new fields.
- `run/run_save.gd`: serialize `_offered_ids` with a version bump or a safe default for old saves.
- `run.gd`: `_show_reward` adds the alternative buttons and shows the gold for skip; remove picks reuse the existing remove list UI.
- `run/vendor.gd`: only if the remove logic is factored out so it can be shared.
- `tools/smart_policy.gd`, `tools/run_sim.gd`: teach the bots the new choices (greedy keeps taking a card); add a `--card-stats`-style print of skip and alt usage.
- Tests: `tests/run_state_*_tests.gd` (no repeats across rewards with a seed, skip pays gold, alt applies and advances, rejected when not pending), `tests/run_save_tests.gd` (round-trip of new fields, old save loads), `tests/ui_flow_test.gd` (reward screen buttons).

Test strategy: run `scripts/check.ps1`, then compare escape rates before and after for all three characters (`--runs 600 --seed 1 --policy smart`) against the figures in NEXT_STEPS (greedy 40 to 50%; smart about 75/62/56). Accept only if the shift is deliberate; retune gold constants if not.

## Open questions for the owner

1. Is the goal more choice, more power growth, or fewer dead offers? That decides A vs B vs C.
2. Should duplicates of a card ever be offered or owned (stacking copies may be a feature for some classes)?
3. Should skipping pay gold, and how much, or should it stay free?
4. Are free removal or healing at reward screens acceptable, given the vendor sells both?
5. Is rarity or upgrade content wanted at all, and is the card count (about 45) going to grow?
6. Do you want rerolls or a "choose class or neutral" toggle?
7. Should the boss pay anything (currently nothing, by design: no later stop to spend it)?
8. Should elites or a branching map (listed as bigger ideas) drive better rewards later, and should this design leave room for them?

## Decisions (recorded from the owner's go-ahead on the recommended answers)

1. Goal: fewer dead offers. Do design A first, then C; defer B.
2. Duplicates: never re-offer a card already offered earlier this run, and never offer one the deck holds twice. The copy cap is a constant.
3. Skipping pays gold: `SKIP_GOLD = 10`.
4. Free remove or heal at rewards (design C): at most once per run each, after A ships; retune against the sim.
5. No rarity or upgrades for now.
6. No rerolls and no class/neutral toggle.
7. The boss keeps paying nothing.
8. Keep the reward roll a function of pool and context so elites can reuse it later; build nothing for them now.

Status: designs A and C implemented.
