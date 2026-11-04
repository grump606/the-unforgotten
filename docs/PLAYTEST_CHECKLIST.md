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

## Keeping cards and the end-of-turn discard step (new, branch `hand-keep`)
- [ ] Clarity: after pressing End Turn, is it obvious you are choosing cards to throw away? Is the "DISCARD" stamp, the hint line and the button wording ("Keep all", "Discard N", "Discard N more") clear?
- [ ] The extra click: with 5 or fewer cards the step costs one extra press (E, E). Does it get annoying by the third fight? Should it be skippable (for example when nothing is marked, or auto when the hand is 5 or fewer)?
- [ ] Back (button or Backspace): does it feel safe to press End Turn too early?
- [ ] A 10-card hand (Pickpocket draw cards, Medium Seance): do the overlapping cards stay readable, can you hover and click each one, are the number keys 1-9 and 0 enough?
- [ ] Does keeping cards feel too strong? Watch for decks that hold a perfect hand every turn, and for fights that now end too fast. Likely knobs: `Combat.HAND_SIZE` (keep limit), `Combat.HAND_MAX` (cap). Bot numbers before and after are in the PR and README.
- [ ] Do unplayable-but-valuable cards (expensive attacks, setup) now get used the following turn the way you expect?

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
- [ ] Dragging a card to an enemy: attack and area cards drag, self cards do not, a plain click still plays on the selected enemy. Over each enemy the label and gold HP ghost match what the hit then does (Block, Exposed). A drop plays on that enemy without changing the selected one; releasing elsewhere, Esc or right-click cancels. Does the 8 px start distance feel right on a trackpad or touch screen? Is the label readable over the biggest figures, and over a boss (which has its top bar instead of a per-figure HP bar)?

## Update flow (once)
- [ ] With v0.6.3 installed, launch it: a notice offers v0.6.4.
- [ ] Download, then restart: the installer runs silently and the game relaunches as v0.6.4.
- [ ] A failure shows a clear message and the game keeps running.

## After
Bring me: the class and stop you died at, the three cards or fights that felt worst, and anything you would change. Likely knobs: the Brakeman's `max_haunt` (`data/enemies/the_brakeman.tres`), class HP, `REST_HEAL`, `REWARD_HEAL`, card costs, `Fighter` constants (`HEIGHTS`, `PLAYER_HEIGHT`, `ENEMY_GAP`, `LUNGE_TIME`) and `battle.gd` `ENEMY_STAGGER`.
