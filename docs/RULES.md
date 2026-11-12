# Card and combat rules reference

The rules as the README used to carry them. The full mechanic design and numbers are in `docs/MECHANICS_PLAN.md`; card lists are in [`CARDS.md`](CARDS.md).

## Hand and discard rules

- Turn 1 draws `Combat.HAND_SIZE` (5) cards. During a turn the hand holds at most `Combat.HAND_MAX` (10): every draw (a card's Draw, the first-play relic) stops at the cap and the rest stay in the draw pile (nothing is burned, and the discard pile is only reshuffled when the draw pile runs dry below the cap).
- End Turn opens an end-of-turn discard step (`Phase.DISCARDING`): click cards (or press their number keys, 0 is the tenth) to mark them for discard, then confirm. You may keep at most 5 cards; the confirm button is disabled ("Discard N more") until the hand is down to 5, and you may discard more than required or everything. Unmarked cards stay in your hand through the enemy phase (hand is no longer thrown away automatically). With 5 or fewer cards and nothing marked the button reads "Keep all", so the extra step costs one click (E, E on the keyboard). Back (or Backspace) returns to playing cards with the hand unchanged. An empty hand skips the step.
- The next turn draws back up to 5: `max(0, 5 - cards kept)`. Keeping 5 draws nothing; draws that turn can take the hand up to 10. Discards go to the discard pile; reshuffle rules are unchanged.
- API: `Combat.end_player_turn(discard_indices := [])` is the atomic form (validates, returns false with no change if an index is bad or duplicated or more than 5 cards would stay; with no argument it keeps the hand, valid only for 5 or fewer). `is_valid_discard`, `discard_required` and `can_confirm_discard` support UIs. Bots choose discards with `SimPolicy.discards_for` / `SmartPolicy.discards_for` (keep the 5 best by card score, never discard when 5 or fewer). The numbers `HAND_SIZE` and `HAND_MAX` are the two constants to change.
- Fights are not saved mid-fight (saves are taken at stop boundaries), so the save format is unchanged.

## Card target modes and statuses

A card's `target_mode` (in its `.tres`) is `0` single enemy (default, the selected enemy), `1` all enemies, or `2` self. Block- and draw-only cards should use self so they never need or name a target. An `EXPOSE` effect (`kind = 3`, `amount` = turns) makes the target take 1.5x damage, rounded down, applied before block.

## Card keywords

Cards carry keywords that change how they cycle or what they do (the full rules and numbers are in `docs/MECHANICS_PLAN.md`):

- **Forgotten:** a played Forgotten card goes to the Forgotten pile for the rest of the fight instead of the discard pile, and returns to the deck after the fight.
- **Fading:** if the card is still in hand when the turn ends, it becomes Forgotten.
- **Ready:** the card starts the fight in the opening hand.
- **Anchor:** the card stays in hand and does not count toward the 5 you keep (it still counts toward the hand cap of 10).
- **Dormant:** cannot be played. Enemies shuffle these into your piles (Dread, Murmur).
- **Surge:** spends all remaining energy, and the effect scales with the energy spent. A Surge card can be played at 0 energy (`Combat.can_play` has no energy test for it): its per-energy amounts and hits are then multiplied by 0, so it does nothing (both shipped Surge cards, Cleaned Out and Dig Deep, have only per-energy effects), yet it counts as a play, like any other 0-cost card.
- **Glimpse X:** look at the top X cards of the draw pile and discard any of them.
- **Malice:** a stacking flat bonus to each hit you deal (lasts the fight, or one turn when the card says "this turn").
- **Ward:** a stacking flat bonus to each Block gained from cards (not Hold, Barbs or relic Block).
- **Block-gained trigger (`ON_BLOCK_GAINED`):** fires when the played card's own effects raised your Block (`Combat.play_card` compares Block before and after the card's effects, before any relic or Oath effect of that play). Block from an Oath effect or relic that fires during the same play does not count. Block from a card's discard effects (`discard_effects`, thrown away at end of turn) does not trigger it either: it is not gained by playing a card (owner decision, kept as is).
- **Shaken:** the target deals 25% less damage for N turns.
- **Frayed:** gains 25% less Block for N turns. Only enemies apply it (Threshold Keeper, Memorial Giant).
- **Remembered:** the rest-stop upgrade. At a rest stop choose Remember instead of the heal, then pick one card in your deck that has a Remembered form. It becomes a `+` card (gold title, upgraded text) for the rest of the run; a card can be Remembered once. Cards without a Remembered form cannot be picked. Picking a card first shows a preview, the card as it is now beside the `+` card it becomes, and nothing changes until you press Remember it (Choose another card goes back to the list); an event's Remember works the same way. See `docs/MECHANICS_PLAN.md` for the list.
- **Barbs:** damage dealt back to each enemy that hits you (the old Thorns name; ids and code still say thorns).
- **Omen:** an enemy's shown next action (the old Intent name). The badge above its head shows the exact effect: the amount, hit count for a multi-hit ("6x3"), a signed Malice ("+1") or the card it adds ("Dread"); the tooltip spells it out ("Omen: Shaken 2").

Enemy Omens (phase 5b): The Husher and The Unnamed apply Shaken to you, the Threshold Keeper and Memorial Giant apply Frayed, the Ash Hound and, in its second phase, the Eraser gain Malice, the Eraser has a 3-hit attack (6x3), and the Keepsake Crow (Murmur) and Bellkeeper (Dread) shuffle Dormant cards into your draw pile. Enemies never get temporary stacks.

Hold, Haunt, Expose, Recall (return cards from the Forgotten pile to your hand) and adding a card to a pile are unchanged or described on the cards themselves.


## File and Unseen (added for Chapter 2, `docs/CHAPTER2_PLAN.md`)

- **File N:** sends N cards from your hand to the BOTTOM of your draw pile; the dearest card (highest cost, the leftmost of equals) goes first, and an Anchored card is never filed. An enemy intent with File acts in the enemy phase, so it files the cards you KEPT at the end of your turn; the next turn then draws back up to the hand size, so the filed card is not lost, only a long way from being drawn again. A player card with File does the same to your own hand. Nothing is reshuffled (`CardPiles.file_from_hand`).
- **Unseen:** an enemy marked `unseen` (`EnemyData.unseen`) cannot be targeted while another enemy that is not Unseen is alive. A single-target card aimed at it lands on the first enemy that can be targeted, the default target skips it, and the battle screen will not select it. An all-enemies card still reaches it. When every living enemy is Unseen, or it is the last one, it can be targeted normally. It is shown as a pill with a "?" (`Combat.is_shielded`).

## Scent and the quarry

- Scent marks one quarry among a card's targets. A hit that spends Scent and kills the quarry still counts as the quarry's death: the `QUARRY_KILL_HEAL` relic and the `QUARRY_DIES` Oaths fire, and no Scent is passed on to an heir because it was spent (owner decision; implemented in the combat engine by a teammate in this pass).

## Saving and resuming

- Saves are taken at stop boundaries, not mid-fight. Quitting during a fight and choosing Continue replays the same encounter with the same shuffle. This save-scumming is intentional (owner decision).

## Keyboard play

- The game is meant to be playable with the keyboard alone: number keys play cards, E ends the turn, Backspace goes back. Added in the sixth pass by a teammate: focus returns to the screen after a click, an overlay takes focus when it opens, and L opens the combat log.
- Deliberately not provided (owner decision): reading an enemy's Omen or statuses from the keyboard (they are shown on screen and in tooltips), and a keyword key.
