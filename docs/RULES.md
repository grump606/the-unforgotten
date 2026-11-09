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
- **Surge:** spends all remaining energy, and the effect scales with the energy spent. A Surge card can be played at 0 energy; it then does nothing and counts as a play, like any other 0-cost card.
- **Glimpse X:** look at the top X cards of the draw pile and discard any of them.
- **Malice:** a stacking flat bonus to each hit you deal (lasts the fight, or one turn when the card says "this turn").
- **Ward:** a stacking flat bonus to each Block gained from cards (not Hold, Barbs or relic Block).
- **Block-gained trigger (`ON_BLOCK_GAINED`):** counts only Block gained by the played card's own effects, not Block from an Oath effect or relic that fires during the same play.
- **Shaken:** the target deals 25% less damage for N turns.
- **Frayed:** gains 25% less Block for N turns. Only enemies apply it (Threshold Keeper, Memorial Giant).
- **Remembered:** the rest-stop upgrade. At a rest stop choose Remember instead of the heal, then pick one card in your deck that has a Remembered form. It becomes a `+` card (gold title, upgraded text) for the rest of the run; a card can be Remembered once. Cards without a Remembered form cannot be picked. See `docs/MECHANICS_PLAN.md` for the list.
- **Barbs:** damage dealt back to each enemy that hits you (the old Thorns name; ids and code still say thorns).
- **Omen:** an enemy's shown next action (the old Intent name). The badge above its head shows the exact effect: the amount, hit count for a multi-hit ("6x3"), a signed Malice ("+1") or the card it adds ("Dread"); the tooltip spells it out ("Omen: Shaken 2").

Enemy Omens (phase 5b): The Husher and The Unnamed apply Shaken to you, the Threshold Keeper and Memorial Giant apply Frayed, the Ash Hound and, in its second phase, the Eraser gain Malice, the Eraser has a 3-hit attack (6x3), and the Keepsake Crow (Murmur) and Bellkeeper (Dread) shuffle Dormant cards into your draw pile. Enemies never get temporary stacks.

Hold, Haunt, Expose, Recall (return cards from the Forgotten pile to your hand) and adding a card to a pile are unchanged or described on the cards themselves.

