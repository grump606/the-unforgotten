# Tests

Run everything with `scripts/check.ps1` (import, unit tests, smoke load, every UI test; see the
README). Run only the unit tests with
`godot --headless --path . -s res://tests/run_tests.gd` and expect `FAILURES: 0`.

## Adding a test: no registration needed

| You add | It is picked up by | Notes |
| --- | --- | --- |
| `tests/<topic>_tests.gd` with a `run() -> int` method | `tests/run_tests.gd` (discovery, name order) | returns its failure count; one process runs all of them |
| `tests/ui_<topic>_test.gd` extending `SceneTree` | `scripts/check.ps1` (glob, name order) | one Godot process per file; call `quit(1)` on failure |
| a new standalone step (own flags, such as the audio driver) | a named `Invoke-Step` in `check.ps1` | also list the file in `STANDALONE_STEPS` in `tests/test_wiring_tests.gd` |

`tests/test_wiring_tests.gd` fails if a file in `tests/` looks like a test (`*_test.gd`, `*_tests.gd`,
a `run()` method, or `extends SceneTree`) but is not wired one of those ways, so a test cannot be
added and silently never run. Support files that are not tests (helpers, this README) are fine.
`run_tests.gd` prints one `TEST FILE: <name>` line per discovered file, so a log shows exactly what
ran. A suite that another suite already runs must not also be discovered: do not chain suites, give
each its own file.

## Writing a unit-test file

```gdscript
extends "res://tests/test_base.gd"
## What this file covers, in a line or two.


func run() -> int:
	_failures = 0
	_check(1 + 1 == 2, "arithmetic works")
	return _failures
```

`test_base.gd` provides `_check(condition, label)` (counts the failure and prints
`FAIL: <label> [<file>]`) and the `_failures` counter. It is a path-based base, not a global class,
so it needs no import step. Every suite uses it (the old per-file copies of `_check` were removed). `_checks` counts the checks that ran, and
`run_tests.gd` prints `CHECKS: <n>` at the end, so a suite that silently stops checking shows up as a smaller total. `MIN_CHECKS` in `run_tests.gd` (the only place the number is written) is the floor: a run with fewer checks fails. Raise it to a little under the new total whenever you add tests; never lower it to get a run through. Waiting in tests: use frames or signals (`await process_frame`, a polling helper with a generous cap, or `UpdateInstaller.finish_worker()` for its worker thread), not fixed timers.

## Content totals and balance pins

Suites compare totals with the registries (`StarterContent.ALL_CARD_PATHS`, `RELIC_PATHS`, `ALL_ENEMY_PATHS`,
`character_ids()`), so adding a card or relic touches no test. The intentional numbers (112 cards, 21 relics,
starting HP, deck sizes, class card counts) live in `tests/pinned_balance_tests.gd`; update them there and in
`docs/GAME_FACTS.md` when content changes on purpose. Card-text pins such as `describe() == "Deal 16"` in the
per-class card suites are balance pins too and change only when a card is rebalanced.

## Signing fixture

`tests/golden/` holds `update_manifest.txt`, its signature `update_manifest.txt.sig` and `signing_test_key.pub.txt`,
made with a throwaway key through the real PowerShell signer. How is in the header of
`tests/signing_compat_tests.gd`. Never commit a private key; only the public key and signature belong here.
`tests/update_support.gd` has the shared signing helpers for the update tests.

## Scratch files

Tests that write to `user://` must use names ending in the process id
(`user://thing_%d.json` with `OS.get_process_id()`), never the real `settings.json` or
`run_save.json`, and must remove the file and its `.tmp`/`.bak` companions on every path out:
`TestBase.remove_scratch(path)` does that. A saving object (such as the audio manager) may write
once more when it is freed, so flush it before the cleanup. As a backstop, `run_tests.gd` sweeps
`user://` at startup and deletes scratch files and folders older than a day that match the
`<name>_<pid>` pattern; it never matches `settings.json` or `run_save.json`.

## Layout of the larger suites

Big topics are split by concern into several files named after the topic (for example
`run_state_*_tests.gd`, `smart_policy_*_tests.gd`, `ui_battle_*_test.gd`). Helpers shared by the parts of a split suite live in a `*_support.gd` file (for example
`smart_policy_support.gd`, `ui_battle_support.gd`); the wiring guard skips those, and the parts
inherit from them with `extends "res://tests/<name>_support.gd"`.
