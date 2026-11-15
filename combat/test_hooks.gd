class_name TestHooks
extends RefCounted
## The one seam through which tests, the sims and development launches bend the game. Every hook is a static var here,
## off by default, and the game reads it from here (no game class has a public static of its own for this). The shipped
## game never sets one, so with every hook off it plays exactly as written. `reset()` turns them all off again:
## tests/run_tests.gd calls it before each suite (and then sets the one-chapter game the older suites play).

## Chapters.count(): when above 0, a run has this many chapters instead of Chapters.COUNT, and Chapters.open_ended() is
## false (a run then ends as it did). Set by the tests, by tools/run_sim.gd (--chapters) and, in a debug build, by
## THE_UNFORGOTTEN_CHAPTERS (run.gd). Off: 0.
static var chapter_count := 0
## EliteModifiers.for_node() and RouteMap.elite_modifier(): EliteModifiers.FORCE_NONE turns elite modifiers off, an
## EliteModifiers.Kind value makes every elite use it (tools/run_sim.gd --elite-modifier). Off: -1.
static var elite_modifier := -1
## ContentRegistry.events_for(): when non-empty, replaces StarterContent.CHAPTER_EVENT_PATHS (chapter -> Array[String]).
## Off: {}.
static var chapter_event_paths := {}
## Encounters' pack builder: when valid, loads its enemies with this (path -> EnemyData or null) instead of
## ContentRegistry.load_enemy, so a load failure can be provoked. Off: an invalid Callable.
static var budget_enemy_loader := Callable()


## Turns every hook off.
static func reset() -> void:
	chapter_count = 0
	elite_modifier = -1
	chapter_event_paths = {}
	budget_enemy_loader = Callable()
