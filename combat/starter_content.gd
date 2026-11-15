class_name StarterContent
extends RefCounted
## Placeholder content for the afterlife-escape theme. Card and enemy numbers
## live in .tres resources under res://data/ so they can be tuned in the editor;
## only the starting deck composition is defined here. Numbers are untuned.

const SHOVE_PATH := "res://data/cards/shove.tres"
const SLIP_PAST_PATH := "res://data/cards/slip_past.tres"
const GLIMPSE_EXIT_PATH := "res://data/cards/glimpse_exit.tres"
const WARDEN_PATH := "res://data/enemies/gate_warden.tres"
const LOST_SHADE_PATH := "res://data/enemies/lost_shade.tres"
const HEAVY_BLOW_PATH := "res://data/cards/heavy_blow.tres"
const BRACE_PATH := "res://data/cards/brace.tres"
const STEADY_BREATH_PATH := "res://data/cards/steady_breath.tres"
const SHOULDER_CHARGE_PATH := "res://data/cards/shoulder_charge.tres"
const MARK_THE_WEAK_PATH := "res://data/cards/mark_the_weak.tres"
const SWEEP_PATH := "res://data/cards/sweep.tres"
const CUTTING_WORD_PATH := "res://data/cards/cutting_word.tres"
const SECOND_WIND_PATH := "res://data/cards/second_wind.tres"
const HAMSTRING_PATH := "res://data/cards/hamstring.tres"
const IRON_RESOLVE_PATH := "res://data/cards/iron_resolve.tres"
const FLURRY_PATH := "res://data/cards/flurry.tres"
const GUARDED_STRIKE_PATH := "res://data/cards/guarded_strike.tres"
const HOLD_THE_LINE_PATH := "res://data/cards/hold_the_line.tres"
const BASH_PATH := "res://data/cards/bash.tres"
const DIG_IN_PATH := "res://data/cards/dig_in.tres"
const COLD_STEEL_PATH := "res://data/cards/cold_steel.tres"
const COUNTER_STANCE_PATH := "res://data/cards/counter_stance.tres"
const LAST_STAND_PATH := "res://data/cards/last_stand.tres"
# Phase 4c (Deserter) new cards.
const DIG_DEEP_PATH := "res://data/cards/dig_deep.tres"
const LIFT_PATH := "res://data/cards/lift.tres"
const SLEIGHT_PATH := "res://data/cards/sleight.tres"
const POCKET_WATCH_PATH := "res://data/cards/pocket_watch.tres"
const LAST_POCKET_PATH := "res://data/cards/last_pocket.tres"
const SPREE_PATH := "res://data/cards/spree.tres"
## Phase 4b Thief cards.
const SHARPEN_PATH := "res://data/cards/sharpen.tres"
const QUICK_STUDY_PATH := "res://data/cards/quick_study.tres"
const CLEANED_OUT_PATH := "res://data/cards/cleaned_out.tres"
const CONFESS_PATH := "res://data/cards/confess.tres"
const LINGERING_DREAD_PATH := "res://data/cards/lingering_dread.tres"
const COLD_WHISPER_PATH := "res://data/cards/cold_whisper.tres"
const PENANCE_PATH := "res://data/cards/penance.tres"
const GRAVE_CHILL_PATH := "res://data/cards/grave_chill.tres"
const SPIRIT_TITHE_PATH := "res://data/cards/spirit_tithe.tres"
const SEANCE_PATH := "res://data/cards/seance.tres"
const BLEED_THE_VEIL_PATH := "res://data/cards/bleed_the_veil.tres"
const RECKONING_PATH := "res://data/cards/reckoning.tres"
# Phase 4d: Medium cards that feed on the Forgotten pile.
const REMEMBER_PATH := "res://data/cards/remember.tres"
const CHORUS_OF_THE_LOST_PATH := "res://data/cards/chorus_of_the_lost.tres"
const HOLLOW_BARGAIN_PATH := "res://data/cards/hollow_bargain.tres"
# Phase 6b: Oaths (two per class; the Stray's come with the Stray).
const QUICK_HANDS_PATH := "res://data/cards/quick_hands.tres"
const LIGHT_STEP_PATH := "res://data/cards/light_step.tres"
const UNBROKEN_VOW_PATH := "res://data/cards/unbroken_vow.tres"
const STANDING_GUARD_PATH := "res://data/cards/standing_guard.tres"
const OPEN_GRAVE_PATH := "res://data/cards/open_grave.tres"
const QUIET_DEBT_PATH := "res://data/cards/quiet_debt.tres"
# The Stray (docs/CLASSES_PLAN.md).
const CATCH_THE_SCENT_PATH := "res://data/cards/catch_the_scent.tres"
const SNAP_PATH := "res://data/cards/snap.tres"
const BRISTLE_PATH := "res://data/cards/bristle.tres"
const RUN_DOWN_PATH := "res://data/cards/run_down.tres"
const WORRY_PATH := "res://data/cards/worry.tres"
const CIRCLE_PATH := "res://data/cards/circle.tres"
const NOSE_TO_THE_WIND_PATH := "res://data/cards/nose_to_the_wind.tres"
const OLD_WOUND_PATH := "res://data/cards/old_wound.tres"
const HOWL_PATH := "res://data/cards/howl.tres"
const POUNCE_PATH := "res://data/cards/pounce.tres"
const SAVAGE_PATH := "res://data/cards/savage.tres"
const BRING_DOWN_PATH := "res://data/cards/bring_down.tres"
const HACKLES_PATH := "res://data/cards/hackles.tres"
const TEAR_LOOSE_PATH := "res://data/cards/tear_loose.tres"
const GO_FERAL_PATH := "res://data/cards/go_feral.tres"
# Neutral pool (cards-1): shared cards for rewards and vendors.
const STEADY_HANDS_PATH := "res://data/cards/steady_hands.tres"
const COUNTER_STEP_PATH := "res://data/cards/counter_step.tres"
const SECOND_LOOK_PATH := "res://data/cards/second_look.tres"
const DOWNPOUR_PATH := "res://data/cards/downpour.tres"
const HOLD_FAST_PATH := "res://data/cards/hold_fast.tres"
const PULL_TOGETHER_PATH := "res://data/cards/pull_together.tres"
const LUCKY_BREAK_PATH := "res://data/cards/lucky_break.tres"
const SHAKE_THEM_PATH := "res://data/cards/shake_them.tres"
# Cards step 3: Oaths on the new triggers and the Thief's discard cards.
const IRON_SKIN_PATH := "res://data/cards/iron_skin.tres"
const BULWARK_VOW_PATH := "res://data/cards/bulwark_vow.tres"
const NICK_AND_RUN_PATH := "res://data/cards/nick_and_run.tres"
const BLOOD_PRICE_PATH := "res://data/cards/blood_price.tres"
const PACK_INSTINCT_PATH := "res://data/cards/pack_instinct.tres"
const LOOSE_CHANGE_PATH := "res://data/cards/loose_change.tres"
const SLIPPED_POCKET_PATH := "res://data/cards/slipped_pocket.tres"
const SPARE_KEY_PATH := "res://data/cards/spare_key.tres"
# Cards step 4: wider class pools.
const CLEAVE_PATH := "res://data/cards/cleave.tres"
const CATCH_BREATH_PATH := "res://data/cards/catch_breath.tres"
const TAUNT_PATH := "res://data/cards/taunt.tres"
const BRACE_FOR_IMPACT_PATH := "res://data/cards/brace_for_impact.tres"
const SHIELD_BASH_PATH := "res://data/cards/shield_bash.tres"
const IRON_WILL_PATH := "res://data/cards/iron_will.tres"
const EARTHSHAKER_PATH := "res://data/cards/earthshaker.tres"
const FORTIFY_PATH := "res://data/cards/fortify.tres"
const PICKPOCKET_PATH := "res://data/cards/pickpocket.tres"
const SHIV_FLURRY_PATH := "res://data/cards/shiv_flurry.tres"
const SMOKE_BOMB_PATH := "res://data/cards/smoke_bomb.tres"
const TRIPWIRE_PATH := "res://data/cards/tripwire.tres"
const SECOND_STORY_PATH := "res://data/cards/second_story.tres"
const VANISH_PATH := "res://data/cards/vanish.tres"
const STEADY_AIM_PATH := "res://data/cards/steady_aim.tres"
const THE_BIG_SCORE_PATH := "res://data/cards/the_big_score.tres"
const WHISPER_CAMPAIGN_PATH := "res://data/cards/whisper_campaign.tres"
const HEX_PATH := "res://data/cards/hex.tres"
const DRAIN_PATH := "res://data/cards/drain.tres"
const MOURNERS_PATH := "res://data/cards/mourners.tres"
const DARK_PACT_PATH := "res://data/cards/dark_pact.tres"
const VEIL_WALK_PATH := "res://data/cards/veil_walk.tres"
const WAIL_PATH := "res://data/cards/wail.tres"
const FRIGHTFUL_VISAGE_PATH := "res://data/cards/frightful_visage.tres"
const LUNGE_PATH := "res://data/cards/lunge.tres"
const GNASH_PATH := "res://data/cards/gnash.tres"
const PROWL_PATH := "res://data/cards/prowl.tres"
const MAUL_PATH := "res://data/cards/maul.tres"
const PACK_HUNT_PATH := "res://data/cards/pack_hunt.tres"
const STALK_PATH := "res://data/cards/stalk.tres"
const CRIPPLE_PATH := "res://data/cards/cripple.tres"
const WILD_HUNT_PATH := "res://data/cards/wild_hunt.tres"
const KEEP_THE_TRAIL_PATH := "res://data/cards/keep_the_trail.tres"
const CINDER_HOUND_PATH := "res://data/enemies/cinder_hound.tres"
const MOURNING_CROW_PATH := "res://data/enemies/mourning_crow.tres"
const WISP_PATH := "res://data/enemies/skittering_wisp.tres"
const COLOSSUS_PATH := "res://data/enemies/hollow_colossus.tres"
const WHISPERER_PATH := "res://data/enemies/pale_whisperer.tres"
## The run's boss. Deliberately not in ALL_ENEMY_PATHS: it only appears via boss_encounter().
const CONDUCTOR_PATH := "res://data/enemies/the_conductor.tres"
## The mid-run boss, halfway down the line. Also not in ALL_ENEMY_PATHS: see mid_boss_encounter().
const BRAKEMAN_PATH := "res://data/enemies/the_brakeman.tres"
const EXTENDED_DECK_SIZE := 14
## The bosses, which only appear through boss_encounter() and mid_boss_encounter().
const BOSS_ENEMY_PATHS: Array[String] = [CONDUCTOR_PATH, BRAKEMAN_PATH]
## Chapter 2 (docs/CHAPTER2_PLAN.md): the Registry's enemies, kept apart from Chapter 1's registry above so Chapter 1 never draws them.
## Names are proposals until the owner confirms them. The Misfiled is Unseen; the bosses are the Archivist (mid) and the Registrar (end).
const LEDGER_CLERK_PATH := "res://data/enemies/chapter2/ledger_clerk.tres"
const DROWNED_PORTER_PATH := "res://data/enemies/chapter2/drowned_porter.tres"
const SHELF_WRAITH_PATH := "res://data/enemies/chapter2/shelf_wraith.tres"
const INDEX_MOTH_PATH := "res://data/enemies/chapter2/index_moth.tres"
const MISFILED_PATH := "res://data/enemies/chapter2/the_misfiled.tres"
const PRESSING_HAND_PATH := "res://data/enemies/chapter2/pressing_hand.tres"
const COPYIST_PATH := "res://data/enemies/chapter2/copyist.tres"
const ARCHIVIST_PATH := "res://data/enemies/chapter2/the_archivist.tres"
const REGISTRAR_PATH := "res://data/enemies/chapter2/the_registrar.tres"
const CHAPTER2_ENEMY_PATHS: Array[String] = [LEDGER_CLERK_PATH, DROWNED_PORTER_PATH, SHELF_WRAITH_PATH, INDEX_MOTH_PATH, MISFILED_PATH, PRESSING_HAND_PATH, COPYIST_PATH]
const CHAPTER2_BIG_PATHS: Array[String] = [DROWNED_PORTER_PATH]
const CHAPTER2_SMALL_PATHS: Array[String] = [LEDGER_CLERK_PATH, SHELF_WRAITH_PATH, INDEX_MOTH_PATH, MISFILED_PATH, PRESSING_HAND_PATH, COPYIST_PATH]
## Left out of trios as Chapter 1's Lost Shade is: the sturdy small enemies. None yet; set from the sims.
const CHAPTER2_TRIO_EXCLUDED_PATHS: Array[String] = []
const CHAPTER2_BOSS_PATHS: Array[String] = [ARCHIVIST_PATH, REGISTRAR_PATH]
## Chapter 3's finale boss (docs/CHAPTER3_PLAN.md): a STUB for now. It is not in an encounter pool; only finale_encounter() builds it.
const SCRIVENER_PATH := "res://data/enemies/chapter3/the_scrivener.tres"
const BLOTTER_PATH := "res://data/enemies/chapter3/the_blotter.tres"
const INKWELL_WARDEN_PATH := "res://data/enemies/chapter3/the_warden_of_the_inkwell.tres"
const CHAPTER3_BOSS_PATHS: Array[String] = [BLOTTER_PATH, INKWELL_WARDEN_PATH, SCRIVENER_PATH]
## Chapter 3 (the Scriptorium, docs/CHAPTER3_PLAN.md): seven regular enemies. The Unfinished is Unseen. (The plan's "Blotter" caster is named
## Smudge here so it does not share a name with the mid-boss.)
const INKWELL_IMP_PATH := "res://data/enemies/chapter3/inkwell_imp.tres"
const PEN_KNIGHT_PATH := "res://data/enemies/chapter3/pen_knight.tres"
const SMUDGE_PATH := "res://data/enemies/chapter3/smudge.tres"
const PENWIPER_PATH := "res://data/enemies/chapter3/penwiper.tres"
const SCROLL_MOTHER_PATH := "res://data/enemies/chapter3/scroll_mother.tres"
const UNFINISHED_PATH := "res://data/enemies/chapter3/the_unfinished.tres"
const LEDGER_WOLF_PATH := "res://data/enemies/chapter3/ledger_wolf.tres"
const CHAPTER3_ENEMY_PATHS: Array[String] = [INKWELL_IMP_PATH, PEN_KNIGHT_PATH, SMUDGE_PATH, PENWIPER_PATH, SCROLL_MOTHER_PATH, UNFINISHED_PATH, LEDGER_WOLF_PATH]
const CHAPTER3_BIG_PATHS: Array[String] = [PEN_KNIGHT_PATH]
const CHAPTER3_SMALL_PATHS: Array[String] = [INKWELL_IMP_PATH, SMUDGE_PATH, PENWIPER_PATH, SCROLL_MOTHER_PATH, UNFINISHED_PATH, LEDGER_WOLF_PATH]
const CHAPTER3_TRIO_EXCLUDED_PATHS: Array[String] = []
## Every card, in a fixed order. A card's `character` tag says who may take it (empty = everyone).
const ALL_CARD_PATHS: Array[String] = [
	SHOVE_PATH, SLIP_PAST_PATH, GLIMPSE_EXIT_PATH, BRACE_PATH, FLURRY_PATH, SWEEP_PATH,
	HEAVY_BLOW_PATH, STEADY_BREATH_PATH, SHOULDER_CHARGE_PATH, IRON_RESOLVE_PATH, GUARDED_STRIKE_PATH,
	HOLD_THE_LINE_PATH, BASH_PATH, DIG_IN_PATH, COLD_STEEL_PATH, COUNTER_STANCE_PATH, LAST_STAND_PATH,
	LIFT_PATH, SLEIGHT_PATH, POCKET_WATCH_PATH, LAST_POCKET_PATH, SPREE_PATH,
	CONFESS_PATH, LINGERING_DREAD_PATH, COLD_WHISPER_PATH, PENANCE_PATH, GRAVE_CHILL_PATH,
	SPIRIT_TITHE_PATH, SEANCE_PATH, BLEED_THE_VEIL_PATH, RECKONING_PATH,
	MARK_THE_WEAK_PATH, CUTTING_WORD_PATH, HAMSTRING_PATH, SECOND_WIND_PATH,
	# Phase 4b Thief cards.
	SHARPEN_PATH, QUICK_STUDY_PATH, CLEANED_OUT_PATH,
	# Phase 4c (Deserter).
	DIG_DEEP_PATH,
	# Phase 4d: Medium
	REMEMBER_PATH, CHORUS_OF_THE_LOST_PATH, HOLLOW_BARGAIN_PATH,
	# Phase 6b: Oaths
	QUICK_HANDS_PATH, LIGHT_STEP_PATH, UNBROKEN_VOW_PATH, STANDING_GUARD_PATH, OPEN_GRAVE_PATH, QUIET_DEBT_PATH,
	# Neutral pool
	STEADY_HANDS_PATH, COUNTER_STEP_PATH, SECOND_LOOK_PATH, DOWNPOUR_PATH, HOLD_FAST_PATH, PULL_TOGETHER_PATH, LUCKY_BREAK_PATH, SHAKE_THEM_PATH,
	# Cards step 4
	KEEP_THE_TRAIL_PATH,
	CLEAVE_PATH, CATCH_BREATH_PATH, TAUNT_PATH, BRACE_FOR_IMPACT_PATH, SHIELD_BASH_PATH, IRON_WILL_PATH, EARTHSHAKER_PATH, FORTIFY_PATH, PICKPOCKET_PATH, SHIV_FLURRY_PATH, SMOKE_BOMB_PATH, TRIPWIRE_PATH, SECOND_STORY_PATH, VANISH_PATH, STEADY_AIM_PATH, THE_BIG_SCORE_PATH, WHISPER_CAMPAIGN_PATH, HEX_PATH, DRAIN_PATH, MOURNERS_PATH, DARK_PACT_PATH, VEIL_WALK_PATH, WAIL_PATH, FRIGHTFUL_VISAGE_PATH, LUNGE_PATH, GNASH_PATH, PROWL_PATH, MAUL_PATH, PACK_HUNT_PATH, STALK_PATH, CRIPPLE_PATH, WILD_HUNT_PATH,
	# Cards step 3
	IRON_SKIN_PATH, BULWARK_VOW_PATH, NICK_AND_RUN_PATH, BLOOD_PRICE_PATH, PACK_INSTINCT_PATH, LOOSE_CHANGE_PATH, SLIPPED_POCKET_PATH, SPARE_KEY_PATH,
	# The Stray
	CATCH_THE_SCENT_PATH, SNAP_PATH, BRISTLE_PATH, RUN_DOWN_PATH, WORRY_PATH, CIRCLE_PATH, NOSE_TO_THE_WIND_PATH, OLD_WOUND_PATH, HOWL_PATH, POUNCE_PATH, SAVAGE_PATH, BRING_DOWN_PATH, HACKLES_PATH, TEAR_LOOSE_PATH, GO_FERAL_PATH,
	# Chapter 2 (docs/CHAPTER2_PLAN.md): six cards per class, offered from Chapter 2 on (CardData.from_chapter = 2).
	"res://data/cards/chapter2/wall_of_orders.tres",
	"res://data/cards/chapter2/standing_order.tres",
	"res://data/cards/chapter2/hold_the_archive.tres",
	"res://data/cards/chapter2/brace_and_breathe.tres",
	"res://data/cards/chapter2/siege_stance.tres",
	"res://data/cards/chapter2/veterans_resolve.tres",
	"res://data/cards/chapter2/ledger_slip.tres",
	"res://data/cards/chapter2/cut_and_run.tres",
	"res://data/cards/chapter2/filing_error.tres",
	"res://data/cards/chapter2/back_door.tres",
	"res://data/cards/chapter2/master_key.tres",
	"res://data/cards/chapter2/grand_heist.tres",
	"res://data/cards/chapter2/ink_in_the_margin.tres",
	"res://data/cards/chapter2/dead_weight.tres",
	"res://data/cards/chapter2/reading_aloud.tres",
	"res://data/cards/chapter2/dead_letters.tres",
	"res://data/cards/chapter2/every_name.tres",
	"res://data/cards/chapter2/the_long_wake.tres",
	"res://data/cards/chapter2/nose_through_paper.tres",
	"res://data/cards/chapter2/bared_teeth.tres",
	"res://data/cards/chapter2/bloodhound.tres",
	"res://data/cards/chapter2/savage_shake.tres",
	"res://data/cards/chapter2/pack_leader.tres",
	"res://data/cards/chapter2/final_rush.tres",
	# Chapter 3 (docs/CHAPTER3_PLAN.md): six cards per class, offered from Chapter 3 on (CardData.from_chapter = 3).
	"res://data/cards/chapter3/bulwark_of_ledgers.tres",
	"res://data/cards/chapter3/last_post.tres",
	"res://data/cards/chapter3/unbroken_line.tres",
	"res://data/cards/chapter3/iron_discipline.tres",
	"res://data/cards/chapter3/roll_call.tres",
	"res://data/cards/chapter3/final_dispatch.tres",
	"res://data/cards/chapter3/pocket_the_page.tres",
	"res://data/cards/chapter3/sleight_of_pen.tres",
	"res://data/cards/chapter3/forged_signature.tres",
	"res://data/cards/chapter3/quick_fingers.tres",
	"res://data/cards/chapter3/clean_getaway.tres",
	"res://data/cards/chapter3/the_long_con.tres",
	"res://data/cards/chapter3/whispered_name.tres",
	"res://data/cards/chapter3/paper_ghost.tres",
	"res://data/cards/chapter3/unspoken.tres",
	"res://data/cards/chapter3/struck_from_the_roll.tres",
	"res://data/cards/chapter3/the_dead_remember.tres",
	"res://data/cards/chapter3/final_entry.tres",
	"res://data/cards/chapter3/fresh_trail.tres",
	"res://data/cards/chapter3/quick_snap.tres",
	"res://data/cards/chapter3/ink_stained_snout.tres",
	"res://data/cards/chapter3/run_them_down.tres",
	"res://data/cards/chapter3/howl_in_the_stacks.tres",
	"res://data/cards/chapter3/the_last_scent.tres",
]
## Status cards: Dormant cards that enemies add to the player's piles mid-fight (Dread: Dormant; Murmur:
## Dormant and Fading). An explicit id -> path table, kept OUT of ALL_CARD_PATHS, the reward pools,
## vendors and starting decks; data/status is never scanned.
const STATUS_CARD_PATHS := {
	&"dread": "res://data/status/dread.tres",
	&"murmur": "res://data/status/murmur.tres",
}
## Created cards: playable cards that exist only inside a fight, made by other cards (the Thief's Trinket
## comes from Filch). An explicit id -> path table, kept OUT of ALL_CARD_PATHS, the reward pools, vendors,
## the price table and every starting deck; data/created is never scanned. Add a created card by putting
## its .tres in data/created and listing it here, and nowhere else.
const CREATED_CARD_PATHS := {
	&"trinket": "res://data/created/trinket.tres",
}
## Every relic, in a fixed order. A relic's `character` tag says who may be offered it (empty = everyone).
const RELIC_PATHS: Array[String] = [
	"res://data/relics/travelling_flask.tres", "res://data/relics/brass_token_purse.tres", "res://data/relics/ticket_stub_charm.tres",
	"res://data/relics/regulation_dog_tags.tres", "res://data/relics/barbed_greatcoat.tres", "res://data/relics/field_ration_tin.tres",
	"res://data/relics/silk_gloves.tres", "res://data/relics/skeleton_key.tres", "res://data/relics/marked_deck.tres",
	"res://data/relics/grave_dirt.tres", "res://data/relics/planchette.tres", "res://data/relics/bone_rosary.tres",
	"res://data/relics/cracked_lorgnette.tres", "res://data/relics/hushing_veil.tres", "res://data/relics/mourners_armband.tres",
	"res://data/relics/iron_stakes.tres", "res://data/relics/pressed_flower.tres", "res://data/relics/candle_stub.tres",
	"res://data/relics/hunters_whistle.tres", "res://data/relics/wolf_fang.tres", "res://data/relics/bloody_muzzle.tres",
	# Chapter 2: three neutral relics and one per class (RelicData.from_chapter = 2).
	"res://data/relics/chapter2/brass_reading_lamp.tres",
	"res://data/relics/chapter2/waterproof_satchel.tres",
	"res://data/relics/chapter2/clerks_seal.tres",
	"res://data/relics/chapter2/stamped_orders.tres",
	"res://data/relics/chapter2/forged_pass.tres",
	"res://data/relics/chapter2/tide_mark.tres",
	"res://data/relics/chapter2/dust_of_the_stacks.tres",
	# Chapter 3: three neutral relics and one per class (RelicData.from_chapter = 3).
	"res://data/relics/chapter3/scribes_fee.tres",
	"res://data/relics/chapter3/blotting_paper.tres",
	"res://data/relics/chapter3/margin_pencil.tres",
	"res://data/relics/chapter3/sealed_dispatch.tres",
	"res://data/relics/chapter3/red_pencil.tres",
	"res://data/relics/chapter3/mourning_ink.tres",
	"res://data/relics/chapter3/inked_collar.tres",
]
## Every event of the "?" stops (docs/EVENTS_DESIGN.md), in a fixed order. Add an event by putting its .tres in data/events
## and listing it here (a test fails for a file that is not listed).
const EVENT_PATHS: Array[String] = [
	"res://data/events/rain_barrel.tres", "res://data/events/scraped_plaques.tres", "res://data/events/stopped_kitchen.tres",
	"res://data/events/bell_in_the_well.tres", "res://data/events/unsent_letters.tres", "res://data/events/hound_at_the_fence.tres",
	"res://data/events/window_that_is_lit.tres", "res://data/events/empty_sentry_box.tres", "res://data/events/quiet_choir.tres",
	"res://data/events/name_broker.tres", "res://data/events/cracked_bell.tres", "res://data/events/erasers_chalk.tres",
]
## The events of a chapter other than the first, by chapter number (docs/CHAPTER2_PLAN.md). A chapter without an entry plays
## Chapter 1's events (EVENT_PATHS). Their .tres files live in data/events/chapter<N>/.
const CHAPTER_EVENT_PATHS := {
	2: [
		"res://data/events/chapter2/card_catalogue.tres",
		"res://data/events/chapter2/drowned_lamp.tres",
		"res://data/events/chapter2/the_form.tres",
		"res://data/events/chapter2/clerk_who_trades.tres",
		"res://data/events/chapter2/flooded_aisle.tres",
		"res://data/events/chapter2/misdelivered_letter.tres",
		"res://data/events/chapter2/the_stamp.tres",
		"res://data/events/chapter2/silent_patron.tres",
		"res://data/events/chapter2/overdue_notice.tres",
		"res://data/events/chapter2/back_stacks.tres",
	],
	3: [
		"res://data/events/chapter3/copy_desk.tres",
		"res://data/events/chapter3/blotter_pad.tres",
		"res://data/events/chapter3/self_writing_pen.tres",
		"res://data/events/chapter3/bell_for_silence.tres",
		"res://data/events/chapter3/letter_to_yourself.tres",
		"res://data/events/chapter3/ink_well_deep.tres",
		"res://data/events/chapter3/proofreader.tres",
		"res://data/events/chapter3/lamp_of_the_scriptorium.tres",
		"res://data/events/chapter3/the_index_of_names.tres",
		"res://data/events/chapter3/the_unwritten_page.tres",
	],
}
## Playable characters, in the order a selection screen lists them.
const CHARACTER_PATHS := {
	CharacterIds.DESERTER: "res://data/characters/deserter.tres",
	CharacterIds.THIEF: "res://data/characters/thief.tres",
	CharacterIds.MEDIUM: "res://data/characters/medium.tres",
	CharacterIds.STRAY: "res://data/characters/stray.tres",
}
const DEFAULT_CHARACTER_ID := CharacterIds.DESERTER
## The regular enemy types in a fixed order (the boss is separate, see CONDUCTOR_PATH): warden,
## lost shade, wisp, colossus, whisperer, cinder hound, mourning crow. The colossus is a solo-only
## elite (it was unwinnable next to a second enemy in the balance sim); the
## warden can share a pair; small enemies are what packs are made of.
const ALL_ENEMY_PATHS: Array[String] = [WARDEN_PATH, LOST_SHADE_PATH, WISP_PATH, COLOSSUS_PATH, WHISPERER_PATH, CINDER_HOUND_PATH, MOURNING_CROW_PATH]
const PAIR_BIG_ENEMY_PATHS: Array[String] = [WARDEN_PATH]
const SMALL_ENEMY_PATHS: Array[String] = [LOST_SHADE_PATH, WISP_PATH, WHISPERER_PATH, CINDER_HOUND_PATH, MOURNING_CROW_PATH]
## Trios leave out the Lost Shade (the sturdiest small enemy): three of them out-damaged the
## run mid-line, and the fragile wisps and whisperers keep a three-way fight winnable.
const TRIO_EXCLUDED_PATHS: Array[String] = [LOST_SHADE_PATH]


## Rarity odds per run tier; the table lives in RarityPicker.
const RARITY_WEIGHTS: Array[Array] = RarityPicker.RARITY_WEIGHTS


## The neutral 10-card deck (5 Shove, 4 Slip Past, 1 Glimpse the Exit) for standalone battles and tests with
## no character; runs use starter_deck(character_id).
## Card definitions are immutable data, so deck slots of the same card share one instance.
## Returns an empty deck (and logs the cause) if any card resource fails to load.
static func deck() -> Array[CardData]:
	var cards: Array[CardData] = []
	var shove := _load_card(SHOVE_PATH)
	var slip_past := _load_card(SLIP_PAST_PATH)
	var glimpse_exit := _load_card(GLIMPSE_EXIT_PATH)
	if shove == null or slip_past == null or glimpse_exit == null:
		return cards
	for i in 5:
		cards.append(shove)
	for i in 4:
		cards.append(slip_past)
	cards.append(glimpse_exit)
	return cards


## The deck a run of this character starts with: a fresh array of the shared card instances from the
## character's resource (data/characters), which owns the composition.
## An id with no character falls back to deck(), the neutral deck; that is for standalone battles and tests
## that have no character, and runs always pass a real character id.
static func starter_deck(character_id: StringName) -> Array[CardData]:
	if not CHARACTER_PATHS.has(character_id):
		return deck()
	var loaded := character(character_id)
	if loaded == null or loaded.starting_deck.is_empty():
		return deck()
	var cards: Array[CardData] = []
	cards.assign(loaded.starting_deck)
	return cards


## Balance-testing deck of EXTENDED_DECK_SIZE (14) cards: 3 Shove, 2 Slip Past,
## 1 Glimpse the Exit, 1 Heavy Blow, 1 Brace, 1 Steady Breath, 1 Shoulder Charge,
## 1 Find the Seam, 1 Sweep, 1 Cutting Word, 1 Borrowed Breath.
## Returns an empty deck (and logs the cause) if any card resource fails to load.
static func extended_deck() -> Array[CardData]:
	var cards: Array[CardData] = []
	var plan: Array = [
		[SHOVE_PATH, 3], [SLIP_PAST_PATH, 2], [GLIMPSE_EXIT_PATH, 1],
		[HEAVY_BLOW_PATH, 1], [BRACE_PATH, 1], [STEADY_BREATH_PATH, 1], [SHOULDER_CHARGE_PATH, 1],
		[MARK_THE_WEAK_PATH, 1], [SWEEP_PATH, 1], [CUTTING_WORD_PATH, 1], [SECOND_WIND_PATH, 1],
	]
	for entry in plan:
		var card := _load_card(entry[0] as String)
		if card == null:
			var empty: Array[CardData] = []
			return empty
		for i in (entry[1] as int):
			cards.append(card)
	return cards


## Every event that loads, in EVENT_PATHS order (cached). Empty (cause logged) if any fails to load.
static func all_events() -> Array[EventData]:
	return ContentRegistry.all_events()


## The events a "?" stop of chapter `chapter` draws from: that chapter's own list when it has one, else Chapter 1's.
static func events_for(chapter: int) -> Array[EventData]:
	return ContentRegistry.events_for(chapter)


## Every event of every chapter (what a save's seen-list and the bounds on max HP are checked against).
static func every_event() -> Array[EventData]:
	return ContentRegistry.every_event()


## A card of the normal pools (not a status or created card) by id, or null when there is none.
static func card_by_id(card_id: StringName) -> CardData:
	for card in all_cards():
		if card.id == card_id:
			return card
	return null


## Returns null (after logging an error) if the resource is missing or not an EventData.
static func _load_event(path: String) -> EventData:
	return ContentRegistry.load_event(path)


static func character_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id in CHARACTER_PATHS:
		ids.append(id)
	return ids


static func warden() -> EnemyData:
	return _load_enemy(WARDEN_PATH)


static func lost_shade() -> EnemyData:
	return _load_enemy(LOST_SHADE_PATH)


## Drops every cached list so the next call rebuilds it from the resources.
static func clear_cache() -> void:
	return ContentRegistry.clear_cache()


## Every card that loads, in ALL_CARD_PATHS order. Empty (cause logged) if any fails to load.
static func all_cards() -> Array[CardData]:
	return ContentRegistry.all_cards()


## The distinct cards a character can be offered as rewards: every neutral card plus the cards tagged for
## `character_id`, except the basic cards (Shove, Slip Past), which they start with and can buy but are never
## offered. Empty (cause logged) if any card fails to load.
static func reward_pool(character_id: StringName, chapter: int = ContentRegistry.ALL_CHAPTERS) -> Array[CardData]:
	return ContentRegistry.reward_pool(character_id, chapter)


## The cards a vendor may stock for `character_id`: the reward pool plus the basic cards.
static func vendor_pool(character_id: StringName, chapter: int = ContentRegistry.ALL_CHAPTERS) -> Array[CardData]:
	return ContentRegistry.vendor_pool(character_id, chapter)


## Every relic that loads, in RELIC_PATHS order. Empty (cause logged) if any fails to load.
static func all_relics() -> Array[RelicData]:
	return ContentRegistry.all_relics()


## The relics a vendor may offer `character_id`: every neutral relic plus the ones tagged for them.
static func relic_pool(character_id: StringName, chapter: int = ContentRegistry.ALL_CHAPTERS) -> Array[RelicData]:
	return ContentRegistry.relic_pool(character_id, chapter)


## The character with this id, or null (cause logged) for an unknown id or a resource that fails to load.
static func character(character_id: StringName) -> Character:
	return ContentRegistry.character(character_id)


## A status card by id (`dread` or `murmur`), or null (cause logged) for an unknown id or a bad resource.
static func status_card(id: StringName) -> CardData:
	return ContentRegistry.status_card(id)


## A created card by id, or null (cause logged) for an unknown id or a bad resource.
static func created_card(id: StringName) -> CardData:
	return ContentRegistry.created_card(id)


static func _load_card(path: String) -> CardData:
	return ContentRegistry.load_card(path)


## Enemies are deep-copied so each encounter slot owns its data, as before.
## Returns null (after logging an error) if the resource is missing or not an EnemyData.
static func _load_enemy(path: String) -> EnemyData:
	return ContentRegistry.load_enemy(path)


## Every enemy, regular and boss, by EnemyData id (debug launch and tools; encounters use the path lists).
static func enemy_ids() -> Array[StringName]:
	return ContentRegistry.enemy_ids()


## A fresh copy of the enemy with this id (regular or boss), or null if there is none.
static func enemy_by_id(enemy_id: StringName) -> EnemyData:
	return ContentRegistry.enemy_by_id(enemy_id)


## The weights for `tier` (clamped to the table).
static func rarity_weights(tier: int) -> Array[int]:
	return RarityPicker.rarity_weights(tier)


## Picks up to `count` distinct cards from `pool`, one at a time: roll a rarity from `weights` (only among the
## rarities that still have a card), then a random card of that rarity. Uses `rng`, so a seed repeats the picks.
## The pool is not changed. Fewer than `count` come back only when the pool is smaller.
static func pick_by_rarity(pool: Array[CardData], count: int, weights: Array[int], rng: RandomNumberGenerator) -> Array[CardData]:
	return RarityPicker.pick_by_rarity(pool, count, weights, rng)
