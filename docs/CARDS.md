# Card list

Card text as shown in game, by class. Cost in brackets; keywords after a dash. New or retuned in the card mechanics rework (phase 4) are marked. The keyword rules are in the README's "Card keywords" section and `docs/MECHANICS_PLAN.md`. Counts (how many cards per class, how many relics) live in [`GAME_FACTS.md`](GAME_FACTS.md).

**Not listed yet: the Stray.** This list was last written before the fourth class existed. The Stray's cards are the `data/cards/*.tres` files tagged `character = &"stray"`; their in-game text is the source of truth.

**Neutral:** Shove (1, Deal 6), Slip Past (1, Block 5), Glimpse the Exit (0, Glimpse 3, Draw 1; retuned), Brace (0, Block 2), Flurry (0, Deal 2 x2; retuned), Sweep (2, Deal 5).

**Deserter:** Heavy Blow (2, Deal 16 - Forgotten; retuned), Steady Breath (1, Draw 1, Block 3), Shoulder Charge (2, Deal 7, Block 6), Iron Resolve (2, Block 6, Ward +1; retuned), Guarded Strike (1, Deal 4, Block 2), Hold the Line (1, Block 5, Hold 2), Bash (1, Deal damage equal to your Block), Dig In (0, Block 2, Hold 2), Cold Steel (1, Deal 5, or 10 with 10+ Block), Counter-Stance (2, Block 8, Thorns 4, the Barbs mechanic), Last Stand (3, Block 12, Hold 10 - Anchor; retuned), Dig Deep (0, Block 5 per energy spent - Surge; new).

**Thief:** Filch (1, Deal 3, add a Trinket to your hand; retuned), Light Fingers (0, Expose 1 - Ready; retuned), Borrowed Time (1, Gain 2 energy - Forgotten; retuned), Last Keepsake (1, Deal 4, +3 for each card played earlier this turn), Many Hands (2, Deal 3 x3; retuned), Find the Seam (1, Expose 2, Shaken 1; retuned), Cutting Word (1, Deal 3, Expose 1), Hamstring (2, Deal 8, Expose 1), Borrowed Breath (0, Block 2, Draw 1), Sharpen (1, Malice +1; new), Quick Study (0, Malice +2 this turn; new), Cleaned Out (0, Deal 3 x energy spent - Surge; new). Trinket (0, Deal 4 - Fading) exists only inside a fight, made by Filch.

**Medium:** Confess (1, lose 4 HP, Deal 12), Lingering Dread (1, Haunt 4), Cold Whisper (0, Haunt 2), Penance (1, lose 2 HP, Block 8), Grave Chill (2, Deal 6, Haunt 3), Spirit Tithe (1, heal 4 per Haunted enemy; retuned), Seance (1, lose 3 HP, Draw 3, Gain 1 energy - Forgotten; retuned), Bleed the Veil (2, lose 6 HP, Haunt 6 to all enemies - Forgotten; retuned), Reckoning (2, Deal 3x the target's Haunt; retuned), Remember (1, Recall 1; new), Chorus of the Lost (1, Deal 2x the Forgotten pile; new), Hollow Bargain (0, add a Dread to your draw pile, Draw 2; new).

**Remembered forms** (the `+` card, from the rest stop's Remember choice): Shove+ (Deal 8), Glimpse the Exit+ (Glimpse 3, Draw 2), Light Fingers+ (Expose 2), Find the Seam+ (adds Ready), Many Hands+ (Deal 4 x3), Heavy Blow+ (Deal 19), Iron Resolve+ (Block 9, Ward +1), Last Stand+ (cost 2), Cold Whisper+ (Haunt 3), Bleed the Veil+ (Haunt 7 to all), Seance+ (lose 2 HP).

**Status cards** (added by enemies, never in rewards): Dread (Dormant), Murmur (Dormant, Fading).

Balance numbers for the retuned cards and the sim results behind them are in `docs/MECHANICS_PLAN.md` (Balance baseline).
