class_name TutorialContent
extends RefCounted
## The words and positions of the first-launch tutorial (run/tutorial_overlay.gd draws them). Kept apart from
## the drawing so tests can check every page without building any UI.
##
## Marker positions are in the pixels of art/tutorial/battle_layout.png (1152 x 648, a real battle screenshot).
## If the battle layout changes, retake that picture and move the markers. Tests keep the three in step:
## tests/tutorial_markers_tests.gd (the picture is the base window's size, every marker is inside it and on
## something drawn) and tests/ui_tutorial_layout_test.gd (every marker is on its part of the live layout).
##
## To retake the picture: start a run (or use tools/debug launch) in a real 1152 x 648 window, at a fight with
## three enemies where one is Haunted, the player has some Block and a full hand, and (with a scratch script
## outside the repo that waits a few frames) save `get_tree().root.get_texture().get_image()` with save_png as
## art/tutorial/battle_layout.png. Then move the eight markers of the BATTLE page below onto what they describe.

const BATTLE_IMAGE := "res://art/tutorial/battle_layout.png"
const BATTLE_IMAGE_SIZE := MenuStyle.BASE_SIZE

## Page kinds the overlay knows how to build.
enum Kind { TEXT, BATTLE, CARD, ICONS, KEYWORDS }

## Each page: {title, kind, lead, items}. `items` depends on the kind: strings for TEXT; {at, text} for BATTLE and
## CARD (a numbered marker at `at` and its explanation); {icon, color_kind, name, text} for ICONS.
static func pages() -> Array[Dictionary]:
	return [
		{
			"title": "Welcome",
			"kind": Kind.TEXT,
			"lead": "Someone still remembers you. Cross the city, one stop at a time, and reach the end.",
			"items": [
				"A journey crosses %d rows in %d districts, %s and %s. On the map you choose your road: fights, tougher elite fights, rests, vendors, chests, events marked with a question mark, and short story moments. Beat a chapter's last boss and the journey goes on into the next." % [RouteMap.ROWS, RouteMap.ACTS, RouteMap.DISTRICT_NAMES[0], RouteMap.DISTRICT_NAMES[1]],
				"Win fights to earn gold and add a new card to your deck. Your deck grows as you go. An elite fight is harder and drops a relic.",
				"At a rest you can heal, or Remember a card to make it stronger. Vendors sell cards and relics, and a chest holds one. An event offers a choice, often with a price.",
				"If your HP reaches 0 the journey ends. Beat the final boss to escape.",
				"The next pages show the fight screen, how to read a card and what the icons mean. You can reopen this from the main menu (How to Play).",
			],
		},
		{
			"title": "The fight screen",
			"kind": Kind.BATTLE,
			"lead": "",
			"items": [
				{"at": Vector2(300, 392), "text": "You, with your HP bar. A blue frame and a shield number mean Block, which soaks up damage until your next turn."},
				{"at": Vector2(638, 392), "text": "Enemies, each with an HP bar. Click one to target it (a gold marker appears over it)."},
				{"at": Vector2(766, 163), "text": "Omen: what that enemy will do on its next turn, as an icon and a number."},
				{"at": Vector2(748, 413), "text": "Status pills under the HP bar, such as Haunt 3 here. Hover one for what it does."},
				{"at": Vector2(116, 462), "text": "Energy: what you have left this turn out of what you get each turn. Cards cost energy."},
				{"at": Vector2(154, 574), "text": "Your piles: Draw, Discard, Forgotten and Sworn. Click one, or press " + BattleKeys.pile_keys_text() + ", to look inside."},
				{"at": Vector2(836, 500), "text": "Your hand. Click a card or press its number to play it. Drag a card onto an enemy to aim it."},
				{"at": Vector2(1070, 488), "text": "End Turn (or press " + BattleKeys.end_turn_key_text() + ") passes to the enemies. Log (or press " + BattleKeys.log_key_text() + ") shows what happened."},
			],
		},
		{
			"title": "Reading a card",
			"kind": Kind.CARD,
			"lead": "",
			"items": [
				{"at": Vector2(30, 14), "text": "Cost: the energy you pay to play it."},
				{"at": Vector2(6, 36), "text": "Hotkey: press this number to play the card in a fight."},
				{"at": Vector2(116, 18), "text": "Class emblem. Pale cards marked KEEPSAKE belong to every class."},
				{"at": Vector2(76, 54), "text": "Name. A gem at the right end marks an uncommon (blue) or rare (gold) card."},
				{"at": Vector2(14, 117), "text": "Keywords: special rules such as Forgotten. Hover a card in a fight to read each one."},
				{"at": Vector2(18, 140), "text": "What it does. In a fight a number turns green when your statuses raise it and red when they lower it."},
				{"at": Vector2(122, 178), "text": "Who it hits: ONE ENEMY, ALL ENEMIES or SELF. A red chip means it costs you HP."},
			],
		},
		{
			"title": "Your turn",
			"kind": Kind.TEXT,
			"lead": "",
			"items": [
				"1. You start with your energy and a hand of cards. Check each enemy's Omen to see what is coming.",
				"2. Play cards: click one, or press its number. Cards that hit one enemy need a target: click the enemy first, or drag the card onto it.",
				"3. Hover a card to see it larger. Rest the pointer on it a moment for a note on each of its keywords and effects.",
				"4. When you are done, press End Turn (or %s). You may keep up to %d cards in hand: mark the others to discard, then confirm. With %d or fewer you can just choose Keep all." % [BattleKeys.end_turn_key_text(), Combat.HAND_SIZE, Combat.HAND_SIZE],
				"5. The enemies act as their Omens showed. Your energy refills and you draw back up to %d cards (%d at most)." % [Combat.HAND_SIZE, Combat.HAND_MAX],
				"6. Played cards go to the discard pile, which is reshuffled into the draw pile when that runs out. Press %s to look at the Draw, Discard, Forgotten or Sworn pile. Defeat every enemy to win the fight." % BattleKeys.pile_keys_text(),
			],
		},
		{
			"title": "Icons on the field",
			"kind": Kind.ICONS,
			"lead": "Omen badges above enemies and status pills under the HP bars. Hover any of them in a fight for details.",
			"items": [
				{"icon": &"intent", "color_kind": CardEffect.Kind.DAMAGE, "name": "Attack", "text": "The enemy will hit for this much."},
				{"icon": &"intent", "color_kind": CardEffect.Kind.BLOCK, "name": "Block", "text": "The enemy will guard against damage."},
				{"icon": &"intent", "color_kind": CardEffect.Kind.EXPOSE, "name": "Expose", "text": "The enemy will make you take more damage."},
				{"icon": &"exposed", "color_kind": CardEffect.Kind.EXPOSE, "name": "Exposed", "text": "Takes " + CardGlossary.EXPOSED_X + "x damage for N turns."},
				{"icon": &"haunt", "color_kind": CardEffect.Kind.HAUNT, "name": "Haunt", "text": "Takes N damage at the enemy phase, ignoring Block, then " + CardGlossary.HAUNT_FALLS + "."},
				{"icon": &"shaken", "color_kind": CardEffect.Kind.SHAKEN, "name": "Shaken", "text": "Deals " + CardGlossary.REDUCED_PERCENT + " less damage for N turns."},
				{"icon": &"frayed", "color_kind": CardEffect.Kind.FRAYED, "name": "Frayed", "text": "Gains " + CardGlossary.REDUCED_PERCENT + " less Block for N turns."},
				{"icon": &"malice", "color_kind": CardEffect.Kind.MALICE, "name": "Malice", "text": "A flat bonus to every hit dealt. Red means a penalty."},
				{"icon": &"ward", "color_kind": CardEffect.Kind.WARD, "name": "Ward", "text": "A flat bonus to Block from cards. Red means a penalty."},
				{"icon": &"scent", "color_kind": CardEffect.Kind.SCENT, "name": "Scent", "text": "Your hits on this enemy deal more. Only one enemy at a time."},
				{"icon": &"hold", "color_kind": CardEffect.Kind.HOLD, "name": "Hold", "text": "Keeps some Block into the next turn."},
				{"icon": &"thorns", "color_kind": CardEffect.Kind.THORNS, "name": "Thorns", "text": "Whoever attacks takes this much damage."},
			],
		},
		{
			"title": "Card keywords",
			"kind": Kind.KEYWORDS,
			"lead": "Keywords appear on a card's face. The same explanations show when you hover a card in a fight.",
			"items": [],
		},
	]


static func page_count() -> int:
	return pages().size()


## The keyword explanations for the last page, in the order the cards list them (the glossary is the one source).
static func keyword_rows() -> Array:
	var rows: Array = []
	for term in ["Forgotten", "Fading", "Ready", "Anchor", "Dormant", "Surge", "Oath", "Discarded", "Remembered"]:
		rows.append([term, CardGlossary.KEYWORD_TEXT[term]])
	return rows


## Whether this launch should show the tutorial by itself: only on a real window (not the headless tests,
## sims and CI), only when the player has not seen it, and not under the opt-out used by scripted launches.
static func should_show_on_launch(display_name: String, disable_env_value: String, seen: bool) -> bool:
	return display_name != "headless" and disable_env_value == "" and not seen


const DISABLE_ENV := "THE_UNFORGOTTEN_NO_TUTORIAL"
