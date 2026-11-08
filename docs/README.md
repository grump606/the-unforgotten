# Documentation index

Status key:

- **Current**: kept up to date; rely on it.
- **Shipped**: describes something that is built and in the game. The design held, but numbers or names inside may have drifted (many still use the pre-v0.5.0 enemy and relic names; the map is in [`RESKIN.md`](RESKIN.md)). Treat the code as the source of truth for details.
- **Historical**: a plan or proposal that has been carried out or overtaken. Read it for the reasoning, not for the current state. Check before relying on this.

Numbers (stops, characters, relics, cards per class) are stated in one place: [`GAME_FACTS.md`](GAME_FACTS.md).

## Start here

| Doc | Status | What it is |
| --- | --- | --- |
| [`../README.md`](../README.md) | Current | Overview, how to run, test, build and release |
| [`GAME_FACTS.md`](GAME_FACTS.md) | Current | The one place for counts and stats |
| [`NEXT_STEPS.md`](NEXT_STEPS.md) | Current | Released vs unreleased work, and what to do next |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Current | Code layout |
| [`RULES.md`](RULES.md) | Current | Hand, discard, target modes, statuses and keywords |
| [`CARDS.md`](CARDS.md) | Current, Stray cards missing | Card list by class |
| [`SIM.md`](SIM.md) | Current usage; results are dated | The simulators and their last results |
| [`../tests/README.md`](../tests/README.md) | Current | How tests are found and written |

## Building, shipping, tooling

| Doc | Status | What it is |
| --- | --- | --- |
| [`CI.md`](CI.md) | Current | The GitHub Actions check, the pinned engine, the import cache |
| [`INSTALLER.md`](INSTALLER.md) | Current | Building and what the Windows installer does |
| [`UPDATE_CHECK.md`](UPDATE_CHECK.md) | Current | How the game finds and installs updates |
| [`UPDATE_SIGNING.md`](UPDATE_SIGNING.md) | Current | The signing key and per-release steps |
| [`MACOS.md`](MACOS.md) | Current | The macOS export (untested on a Mac, not part of releases) |
| [`MACOS_INSTALL.md`](MACOS_INSTALL.md) | Current | Instructions to hand a Mac tester |
| [`REPO_SIZE.md`](REPO_SIZE.md) | Current | What takes space in the repo, and options |
| [`ADDING_CONTENT.md`](ADDING_CONTENT.md) | Current | The tested procedure for new cards, relics, enemies, characters |
| [`PLAYTEST_CHECKLIST.md`](PLAYTEST_CHECKLIST.md) | Check before relying on this | Written for v0.7.3; the build and line have changed since |

## Game design

| Doc | Status | What it is |
| --- | --- | --- |
| [`LEVELS_DESIGN.md`](LEVELS_DESIGN.md) | Shipped | The stop line, two acts, mid-boss, pre-finale rest. Bot figures in it predate the keep-5 hand rule |
| [`MECHANICS_PLAN.md`](MECHANICS_PLAN.md) | Historical | The card-mechanics rework plan (keywords, Remembered, Omens, Oaths); built. Its branch note is stale |
| [`CLASSES_PLAN.md`](CLASSES_PLAN.md) | Historical | The three-class build plan; the Stray came later, so check before relying on this |
| [`RELICS_DESIGN.md`](RELICS_DESIGN.md) | Shipped | Relic design; the relic count it states is stale (see `GAME_FACTS.md`) |
| [`REWARDS_PROPOSAL.md`](REWARDS_PROPOSAL.md) | Historical | Card reward options; designs A and C were built, the rest was not |
| [`RUN_INTEGRATION.md`](RUN_INTEGRATION.md) | Shipped | The contract between a run layer and `combat/` |
| [`RUN_SCREEN_STRUCTURE.md`](RUN_SCREEN_STRUCTURE.md) | Current | How `run.gd` and `run/screens/` divide the work |
| [`RESKIN.md`](RESKIN.md) | Shipped | The v0.5.0 rename map: old ids and names to the in-game ones |

## Presentation and audio

| Doc | Status | What it is |
| --- | --- | --- |
| [`AUDIO.md`](AUDIO.md) | Current | The `AudioManager`, buses, scenes and effects |
| [`STAGE_DESIGN.md`](STAGE_DESIGN.md) | Shipped | The side-view battle stage |
| [`BATTLE_BACKDROP_DESIGN.md`](BATTLE_BACKDROP_DESIGN.md) | Shipped | The code-drawn battle backdrop (theme is the original train line) |
| [`CARD_ART_DESIGN.md`](CARD_ART_DESIGN.md) | Shipped | Card layout and class styling; painted art arrived later, so check before relying on this |
| [`RELIC_ART_DESIGN.md`](RELIC_ART_DESIGN.md) | Shipped | Relic badges |
| [`SCREEN_ART_DESIGN.md`](SCREEN_ART_DESIGN.md) | Shipped | Rest, story and end-card scenes |
| [`PAUSE_SCREEN_DESIGN.md`](PAUSE_SCREEN_DESIGN.md) | Shipped | The pause backdrop (carriage theme from before the reskin) |
| [`VENDOR_ART_DESIGN.md`](VENDOR_ART_DESIGN.md) | Shipped, partly superseded | The vendor scene; the wall and keeper are painted since v0.5.0 |
| [`reference/`](reference/README.md) | Check before relying on this | Generated screen reference sheets (web pages); regenerate when screens change |
