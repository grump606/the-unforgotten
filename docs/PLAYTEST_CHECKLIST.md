# Playtest checklist (v0.6.4)

The numbers are tuned against bots, not people. Play with a pen: note what felt off, not why. Tune afterwards with the sims (`README.md`, "Balance simulation").

## Before you start
- [ ] Install v0.6.3 first, then check the in-game update (see "Update flow") before playing on v0.6.4.
- [ ] Play each class at least once to the end or to a loss: Deserter, Pickpocket, Medium. Note the class, the stop you died at, and what killed you.

## Per class (rate each 1 to 5: boring / fair / too hard / too easy)
- [ ] **Deserter** (skill-sensitive): is Hold readable and worth it? Do you feel weak early, strong late, or just fine?
- [ ] **Pickpocket** (burst): do the per-play cards (Spree, Last Pocket, Pocket Watch) feel good? Is anything pointless?
- [ ] **Medium** (Haunt, HP costs): is Haunt satisfying or confusing? Do the HP-cost cards (Confess, Penance, Seance) feel risky or free? Is it too easy in ordinary fights?
- [ ] Cards that felt weak or that you never played. The bots' verdict: Spree, Reckoning and Spirit Tithe are probably weak.

## The Brakeman (stop 9, mid-boss) and the Conductor (last)
- [ ] Medium vs the Brakeman: Haunt is capped at 9 (the tooltip says "Haunt capped at 9"). Is the fight now a real fight, or is it a wall? Target: you lose it sometimes, not mostly.
- [ ] Deserter and Pickpocket vs the Brakeman: its Expose attack. Fair, or a spike you cannot play around?
- [ ] The Conductor: is it the hardest fight? Does the Pickpocket still breeze through it?

## Pacing and economy
- [ ] 21 stops: where do you get bored, and where do you feel pressure?
- [ ] Rests (heal 36), vendor prices, relics (3 per run at most), card rewards, free Remove and Heal: any choice that was obviously right every time?
- [ ] Relic badges and tooltips (never yet seen in a real run): readable?

## Stage and presentation
- [ ] Sprite sizes and facing, attack lunges, hit reactions, enemy stagger timing.
- [ ] Intent and HP readouts, the log toggle, the damage preview on cards.
- [ ] Backdrops in motion (battle, rest, vendor), the main menu and character select, the pause menu (centred in a normal launch).
- [ ] Anything that stutters or drops frames (note the screen and the GPU).

## Update flow (once)
- [ ] With v0.6.3 installed, launch it: a notice offers v0.6.4.
- [ ] Download, then restart: the installer runs silently and the game relaunches as v0.6.4.
- [ ] A failure shows a clear message and the game keeps running.

## After
Bring me: the class and stop you died at, the three cards or fights that felt worst, and anything you would change. Likely knobs: the Brakeman's `max_haunt` (`data/enemies/the_brakeman.tres`), class HP, `REST_HEAL`, `REWARD_HEAL`, card costs, `Fighter` constants (`HEIGHTS`, `PLAYER_HEIGHT`, `ENEMY_GAP`, `LUNGE_TIME`) and `battle.gd` `ENEMY_STAGGER`.
