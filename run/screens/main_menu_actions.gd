class_name MainMenuActions
extends RefCounted
## What the main menu can do, handed over by the run layer so MainMenuScreen.show takes one argument instead of a
## long parameter list. Leave a callable invalid to hide its button (only the update toggle and How to Play are
## optional).

## Already bound to the saved run by the caller; only called when a save exists.
var on_continue := Callable()
var on_new_run := Callable()
var on_exit := Callable()
## Called on each press of the small Update button and returns the new setting; invalid hides the button.
var on_toggle_updates := Callable()
var on_how_to_play := Callable()
## The update setting the Update button starts with (the notice owns it while it exists).
var update_check_on := true
## The update notice, so the button can turn red when a newer version is known and reveal the bar.
var update_notice: UpdateNotice = null
