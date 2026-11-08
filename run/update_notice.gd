class_name UpdateNotice
extends PanelContainer
## A small bar at the bottom of the run screen: "Update available: v0.3.1 (you have 0.3.0)" with
## Download and Skip buttons. It asks GitHub once per launch (asynchronously, so the game never
## waits). A newer release does not show the bar by itself: it only turns the main menu's Update
## button red, and the bar appears when the player clicks that button (`reveal`). Skip turns update
## checks off (`skipped`; run.gd saves the setting) and the bar goes away. Every failure is silent.
## Rules and validation live in run/update_check.gd; see docs/UPDATE_CHECK.md.

## Something the main menu's Update button shows changed (a newer release is known, or the bar was
## shown or hidden).
signal changed
## The player pressed Skip: the owner should turn update checks off.
signal skipped

## The running game's version; tests set it to try different comparisons.
var current_version: String = str(ProjectSettings.get_setting("application/config/version", ""))
## What Download does with the fixed releases URL; tests replace it so no browser opens.
var open_url: Callable = func(url: String) -> void: OS.shell_open(url)
## The player's saved choice (Settings.update_check_enabled); false means no request is ever made.
var user_enabled := true
## Print why a check ended without a notice (debug only; normal play stays quiet).
var debug := false

var label: Label
var download_button: Button
var skip_button: Button
## The newer release's tag once one is known ("" until then).
var latest_tag := ""
## Downloads, verifies and runs the installer when the player clicks the button (see UpdateInstaller).
var installer := UpdateInstaller.new()
## Whether the button installs in the game (true) or only opens the releases page. False when no
## signing key is built in, in the editor, or when the install folder is not writable; tests set it.
var use_installer := UpdateInstaller.available()

var _request: HTTPRequest
## True once the player has asked to see the update (the red Update button was clicked).
var revealed := false
## False while a screen where the notice does not belong (a run in progress) is showing.
var _allowed := true


func _init() -> void:
	visible = false
	add_child(installer)
	installer.changed.connect(_on_installer_changed)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	label = Label.new()
	label.add_theme_font_size_override("font_size", 14)
	row.add_child(label)
	download_button = Button.new()
	download_button.text = "Download"
	download_button.focus_mode = Control.FOCUS_NONE # the screen's own buttons keep keyboard focus
	download_button.add_theme_font_size_override("font_size", 14)
	download_button.pressed.connect(_on_download)
	row.add_child(download_button)
	skip_button = Button.new()
	skip_button.text = "Skip"
	skip_button.tooltip_text = "Skip this update and turn update checks off"
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.add_theme_font_size_override("font_size", 14)
	skip_button.pressed.connect(_on_skip)
	row.add_child(skip_button)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.03, 0.03, 0.9)
	style.set_border_width_all(1)
	style.border_color = MenuStyle.BRASS
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	add_theme_stylebox_override("panel", style)
	label.add_theme_color_override("font_color", MenuStyle.CREAM)
	# Bottom centre, growing up and out from there.
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_bottom = -5.0


func _ready() -> void:
	UpdateInstaller.cleanup() # leftovers of an earlier update attempt


## Starts the one request, unless this launch is not meant to check (headless, or the opt-out
## variable is set). Returns whether a request is now in flight.
func start() -> bool:
	if _request != null or not UpdateCheck.check_enabled(DisplayServer.get_name(), OS.get_environment(UpdateCheck.DISABLE_ENV), user_enabled):
		return false
	_request = HTTPRequest.new()
	_request.body_size_limit = UpdateCheck.MAX_BODY_BYTES
	_request.timeout = UpdateCheck.TIMEOUT_SECONDS
	# Godot's HTTPRequest follows redirects itself and does not expose where it ended up, so a redirect to plain
	# http:// cannot be refused here. The cap keeps a redirect loop short; the reply is only ever read as a version
	# tag (UpdateCheck validates it) and the installer is trusted only through the signed manifest (UpdateInstaller).
	_request.max_redirects = UpdateCheck.MAX_REDIRECTS
	_request.request_completed.connect(_on_request_completed)
	add_child(_request)
	var headers := PackedStringArray([
		"User-Agent: the-unforgotten/%s" % current_version,
		"Accept: application/vnd.github+json",
	])
	if _request.request(UpdateCheck.LATEST_RELEASE_API, headers) != OK:
		_finish_request("request could not start")
		return false
	return true


## Cancels any request in flight and hides a notice already shown (the player turned the check off).
func stop() -> void:
	installer.cancel()
	_finish_request("stopped")
	latest_tag = ""
	revealed = false
	_refresh()
	changed.emit()


## Shows the bar for a known newer release (the player clicked the red Update button). Does nothing
## while there is no newer release.
func reveal() -> void:
	if latest_tag == "":
		return
	revealed = true
	_refresh()
	changed.emit()


## Whether the screen showing now is one where the notice belongs; it shows only when allowed.
func set_allowed(allowed: bool) -> void:
	_allowed = allowed
	_refresh()


## Takes a reply (the real one from the request, or a fake one from a test). A newer release
## shows the notice; anything else changes nothing.
func handle_response(code: int, body: PackedByteArray) -> void:
	var tag := UpdateCheck.newer_tag(code, body, current_version)
	if tag == "":
		_log("no newer release in the reply (HTTP %d)" % code)
		return
	latest_tag = tag
	label.text = UpdateCheck.notice_text(tag, current_version)
	download_button.text = "Update & restart" if use_installer else "Download"
	_refresh()
	changed.emit() # the menu's Update button turns red


func _refresh() -> void:
	var show_it := latest_tag != "" and _allowed and revealed
	if show_it != visible:
		visible = show_it
		changed.emit()


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS:
		handle_response(code, body)
	else:
		_log("request failed (result %d)" % result)
	_finish_request("done")


func _finish_request(reason: String) -> void:
	if _request != null:
		_request.queue_free()
		_request = null
	_log(reason)


func _on_download() -> void:
	if not use_installer:
		open_url.call(UpdateCheck.RELEASES_PAGE) # the fixed page, never anything from the reply
		return
	match installer.state:
		UpdateInstaller.State.IDLE:
			installer.current_version = current_version
			installer.start(latest_tag)
		UpdateInstaller.State.READY:
			installer.install_and_restart()


## Mirrors the installer onto the bar: progress while downloading, then straight into the install
## when the bar is on a menu screen (a download that finished during a run waits for a click), and a
## plain Download button after a failure.
func _on_installer_changed() -> void:
	match installer.state:
		UpdateInstaller.State.DOWNLOADING:
			label.text = "Downloading v%s... %d%%" % [latest_tag.trim_prefix("v").trim_prefix("V"), int(installer.progress * 100.0)]
			download_button.disabled = true
		UpdateInstaller.State.READY:
			label.text = "Update ready"
			download_button.text = "Restart now"
			download_button.disabled = false
			if _allowed:
				installer.install_and_restart()
		UpdateInstaller.State.FAILED:
			label.text = "Update failed: %s" % installer.error
			use_installer = false # fall back to the releases page
			download_button.text = "Download"
			download_button.disabled = false


func _on_skip() -> void:
	installer.cancel()
	installer.discard() # a verified installer waiting in READY is removed too
	revealed = false
	_refresh()
	skipped.emit()


func _log(message: String) -> void:
	if debug:
		print("update check: ", message)
