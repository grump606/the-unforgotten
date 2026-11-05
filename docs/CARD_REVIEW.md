# Card review against Slay the Spire

A comparison of our 63 cards (2026-11-05) with the Slay the Spire card list, to find design gaps before the
Stray's bots and balance phase. Slay the Spire is the reference the mechanics rework aims to sit near without
copying (see `docs/MECHANICS_PLAN.md`). Nothing here is decided: it is a list of findings and proposals.

## Sources and how far to trust them

- Slay the Spire wiki: the Cards page (intro text), the Cards_List page (all 367 cards, read in partial windows),
  and the Defect and Watcher pages.
- **Energy costs are not in the fetched text** (the wiki shows them as icons), so no cost comparison uses wiki data.
- Ironclad and Silent lines come from a model-written summary of the page, not verbatim text, so single lines
  could be wrong. Watcher is missing about 11 Uncommon cards and all Rare cards.
- Colorless, Curse and Status effect text was not retrieved. Statements about the Colorless pool below come from
  general knowledge of the game, not from the fetched data.
- Our side comes from `StarterContent.all_cards()`: 63 cards (6 neutral, 14 Deserter, 14 Thief, 15 Medium,
  15 Stray) with 6 Oaths among them.

## Where we already match

| Ours | Slay the Spire |
|---|---|
| Forgotten, Fading, Anchor, Ready, Surge | Exhaust, Ethereal, Retain, Innate, X-cost |
| Expose, Shaken, Frayed | Vulnerable, Weak, Frail |
| Malice, Ward | Strength, Dexterity |
| Glimpse | Scry |
| Hold | a lighter Barricade / Blur |
| Oaths | Powers (only 6, with 4 triggers) |

Class parallels:

- **Deserter** (Ironclad Block): Bash is Body Slam, Counter-Stance is Flame Barrier, Heavy Blow is Bludgeon,
  Last Stand is Impervious, Dig Deep is Whirlwind, Guarded Strike is Iron Wave.
- **Thief** (Silent): Many Hands and Last Keepsake are Riddle with Holes and Finisher, Filch's Trinket is a Shiv,
  Glimpse and draw are Acrobatics and Prepared, Find the Seam is Neutralize.
- **Medium**: Haunt is Poison (Reckoning is close to Catalyst), Bleed the Veil is Crippling Cloud, Seance is
  Offering, Confess and Penance are Hemokinesis and Bloodletting, the Forgotten pile is the Exhaust pile
  (Chorus of the Lost is a Fiend Fire).
- **Stray**: Scent is Watcher's Mark crossed with Defect's Lock-On (Run Down and Bring Down echo Pressure Points),
  the Malice cards echo Flex, Inflame and Demon Form, Snap, Pounce and Savage echo Twin Strike, Pummel and
  Sword Boomerang, Howl echoes Intimidate.

## Gaps

1. **Pool size and rarity.** About 15 cards per class against about 70, and no Common / Uncommon / Rare tiers
   (Slay the Spire's rare chance also rises as commons roll). `docs/REWARDS_PROPOSAL.md` already proposes rarity.
2. **Attacks on all enemies.** Only the neutral Sweep deals damage to everyone (Howl only Shakens and marks).
   Slay the Spire has Cleave, Thunderclap, Whirlwind, Immolate and more; our fights include trios.
3. **Powers and triggers.** About one card in five is a Power there, and they define archetypes. Our Oaths fire
   on four triggers (turn start, first card each turn, a card Forgotten, an Anchor card kept). Theirs also fire on
   gaining Block (Juggernaut), losing HP (Rupture), every card played (After Image, A Thousand Cuts), end of
   turn (Metallicize, Combust), drawing and Scrying (Nirvana).
4. **Discard payoffs.** Silent's core is cards that trigger when discarded (Reflex, Tactician, Sneaky Strike).
   Our end-of-turn discard step is a natural place for "Discarded:" effects, and we have none.
5. **Cards that change as you play them.** Rampage, Claw, Glass Knife, Genetic Algorithm. We have none.
6. **Attack and Skill payoffs.** Clash, Finisher, Flechettes count card types. We could derive Attack (has a
   damage effect) and Skill without adding a card field.
7. **Deserter specifics.** No all-enemies attack, no Strength-style payoff, no Entrench ("double your Block").
8. **Status cards.** They have Wound, Dazed, Burn, Slimed, Void and payoffs for drawing them (Evolve, Fire
   Breathing). We have Dread and Murmur and almost no payoff for either.

## The neutral pool

Slay the Spire keeps two shared groups apart:

- **Basics** (Strike, Defend): starting cards only, never offered as rewards.
- **Colorless** (about 35 cards, Uncommon and Rare): a separate pool from shops, events and Prismatic Shard,
  generally stronger than class filler.

Ours is one pool of six cards that does both jobs, and one of three reward offers is a neutral card.

| Ours | Slay the Spire | Comparison |
|---|---|---|
| Shove (6 for 1) | Strike (6 for 1) | Matches. |
| Slip Past (5 Block for 1) | Defend (5 Block for 1) | Matches. |
| Sweep (5 to all for 2) | Cleave (8 to all for 1) | Clearly weaker. |
| Glimpse the Exit (Glimpse 3, draw 1, free) | Third Eye, Cut Through Fate | Fine. |
| Flurry (2 x2, free, repeatable) | Shiv (4, free, Exhaust) | Stronger: it does not exhaust. |
| Brace (2 Block, free) | none | Very small. |

Problems:

- Our tests require that a character can be offered every card it starts with, so Shove and Slip Past (the
  Strike and Defend equivalents) can appear as rewards, which is close to a wasted pick.
- With six neutral cards, the one neutral slot in every offer repeats quickly.

## Proposals (none started)

1. **Split the neutral cards.** Keep Shove and Slip Past as starting and vendor cards, out of reward offers. Add
   a small Colorless-style pool of about 8 to 12 shared cards for rewards and the vendor, with rarity: a real
   all-enemies attack, a cheap draw, a Block-and-attack card, a utility card. Fix Sweep (5 for 2 is well below
   Cleave).
2. **Add rarity** (Common, Uncommon, Rare) to `CardData`, with offer weights by stop depth, and widen each class
   pool toward 25 to 30 cards over time.
3. **More Oath triggers:** gaining Block, losing HP, each card played, end of turn, a card discarded. Each is a
   hook in `combat.gd` like the four that exist, so the cost is small.
4. **A "Discarded:" card keyword** that fires when a card is thrown away at end of turn, as the Thief's identity
   and a payoff for the keep-5 hand.
5. **Class gaps to fill first:** Deserter all-enemies attack and a Strength-style payoff (Malice already
   exists), Thief discard cards, a payoff for Dread and Murmur for the Medium.
6. **Attack / Skill counting** payoffs derived from effects, if wanted.

## Not covered

Cost-by-cost balance (no wiki cost data), the Colorless, Curse and Status lists, Watcher Rare cards, and
whether any of our enemies need matching changes.
