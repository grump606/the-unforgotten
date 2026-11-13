class_name ChapterBreakScreen
extends RunScreen
## Between chapters (docs/CHAPTERS_DESIGN.md, section 6): a run summary, the heal the next chapter starts with and a
## button to begin it. The save is made before this screen opens, so quitting here resumes here.

## One neutral closing line until each character has its own (writing work, docs/CHAPTERS_DESIGN.md).
const CLOSING_LINE := "The way opens behind you, and further on a voice still calls."


func show() -> void:
	add_backdrop(EndScene.new())
	var box := panel("End of Chapter %d" % run.chapter, true)
	style_banner(box.get_child(0) as Label)
	# The chapter's closing beat when it has one (per class), else the neutral line.
	var beat := StoryContent.break_beat(run.chapter, run.character.id if run.character != null else &"")
	var line := make_label(("%s

%s" % [beat.title, beat.text]) if beat != null else CLOSING_LINE)
	line.name = "ClosingBeat"
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(480, 0)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(line)
	var heal := mini(run.player.max_hp - run.player.hp, roundi(run.player.max_hp * RunState.CHAPTER_BREAK_HEAL_FRACTION))
	var finale := run.can_start_finale()
	var summary := make_label("HP %d/%d  ·  Gold %d\nDeck: %d cards  ·  Keepsakes: %d\nThe %s begins with +%d HP." % [
		run.player.hp, run.player.max_hp, run.gold, run.deck.size(), run.relics.size(), "finale" if finale else "next chapter", heal,
	])
	summary.name = "BreakSummary"
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(summary)
	var begin := add_button(box, Chapters.chapter(run.chapter).finale_button if finale else "Begin Chapter %d" % (run.chapter + 1), _begin)
	begin.name = "BeginChapterButton"
	style_service(begin)


func _begin() -> void:
	sfx(&"confirm")
	if not run.start_finale():
		run.start_next_chapter()
	refresh.call()
