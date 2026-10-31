class_name UpdateInstaller
extends Node
## Downloads a newer release's installer, verifies its signature and hands over to it: the installer
## replaces the game files and relaunches the game. Started only by the player's click (see
## UpdateNotice). Every step is checked and any failure leaves the game running as it was.
##
## Trust chain (docs/UPDATE_CHECK.md): the URLs are built from a validated tag against a fixed host
## (UpdateCheck.installer_url); the download is size-capped; and it is run ONLY if its detached RSA
## signature verifies against the public key built into the game (UpdateVerifier). It is verified
## once on arrival and again right before it is launched.

signal changed

enum State { IDLE, DOWNLOADING, READY, FAILED }

## Arguments for the silent installer. /RELAUNCH=1 makes installer/setup.iss start the game again
## when the files are in place; /SUPPRESSMSGBOXES keeps it from asking anything mid-update.
const INSTALLER_ARGS: PackedStringArray = ["/SILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/RELAUNCH=1"]
const SIGNATURE_TIMEOUT := 20.0
const DOWNLOAD_TIMEOUT := 600.0

var state := State.IDLE
## Why the last attempt failed (when state is FAILED).
var error := ""
## Download progress 0..1 (0 while the size is unknown).
var progress := 0.0
var tag := ""
## The key signatures must verify against; tests substitute a generated one.
var public_key_pem: String = UpdateVerifier.PUBLIC_KEY_PEM
## Where downloads go. user:// is inside the player's own profile.
var work_dir := "user://update"
## Starts a program: (path, args) -> process id, or <= 0 on failure. Tests replace it.
var launch: Callable = func(path: String, args: PackedStringArray) -> int: return OS.create_process(path, args)
## Closes the game once the installer is running. Tests replace it.
var quit_game: Callable = func() -> void: get_tree().quit()

## Tests: record the URL in `requested` instead of sending the request.
var dry_run := false
var requested: Array[String] = []

var _signature := PackedByteArray()
var _installer_path := ""
var _request: HTTPRequest


## Whether in-game install can work at all: a signing key is built in and this is an exported,
## correctly named, writable install. Otherwise the notice keeps its plain Download button.
static func available() -> bool:
	if not UpdateVerifier.is_configured():
		return false
	var dir := OS.get_executable_path().get_base_dir()
	return UpdateCheck.can_self_update(OS.has_feature("editor"), OS.get_executable_path(), _dir_writable(dir))


static func _dir_writable(dir: String) -> bool:
	var probe := dir.path_join(".write_test_%d" % OS.get_process_id())
	var file := FileAccess.open(probe, FileAccess.WRITE)
	if file == null:
		return false
	file.close()
	DirAccess.remove_absolute(probe)
	return true


## Removes leftover downloads from earlier attempts (called at launch). Never fails.
static func cleanup(dir: String = "user://update") -> void:
	var access := DirAccess.open(dir)
	if access == null:
		return
	for file_name in access.get_files():
		access.remove(file_name)


## Begins downloading the release `release_tag`. Returns false (state FAILED, `error` set) when it
## cannot start; true when the signature request is in flight. Ignored while already downloading.
func start(release_tag: String) -> bool:
	if state == State.DOWNLOADING or state == State.READY:
		return false
	tag = release_tag
	if not UpdateCheck.is_valid_tag(tag):
		return _fail("the release version is not valid")
	if not UpdateVerifier.is_configured(public_key_pem):
		return _fail("this version cannot verify updates")
	cleanup(work_dir)
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(work_dir)) != OK:
		return _fail("cannot create the download folder")
	_installer_path = work_dir.path_join(UpdateCheck.installer_name(tag))
	progress = 0.0
	error = ""
	state = State.DOWNLOADING
	if not _begin_request(UpdateCheck.signature_url(tag), "", UpdateCheck.MAX_SIGNATURE_BYTES, SIGNATURE_TIMEOUT, _on_signature_completed):
		return _fail("could not start the download")
	changed.emit()
	return true


## Cancels a download in flight and returns to IDLE.
func cancel() -> void:
	_drop_request()
	if state == State.DOWNLOADING:
		cleanup(work_dir)
		state = State.IDLE
		progress = 0.0
		changed.emit()


## The signature arrived (or failed to): store it and fetch the installer.
func handle_signature(result: int, code: int, body: PackedByteArray) -> void:
	if state != State.DOWNLOADING:
		return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail("the update signature could not be downloaded")
		return
	if body.is_empty() or body.size() > UpdateCheck.MAX_SIGNATURE_BYTES:
		_fail("the update signature is not valid")
		return
	_signature = body
	if not _begin_request(UpdateCheck.installer_url(tag), _installer_path + ".part", UpdateCheck.MAX_INSTALLER_BYTES, DOWNLOAD_TIMEOUT, _on_installer_completed):
		_fail("could not start the download")


## The installer finished downloading to `<path>.part`: move it into place and verify it.
func handle_installer(result: int, code: int) -> void:
	if state != State.DOWNLOADING:
		return
	var part := _installer_path + ".part"
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(part))
		_fail("the update could not be downloaded")
		return
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(part), ProjectSettings.globalize_path(_installer_path)) != OK:
		_fail("the downloaded update could not be saved")
		return
	var why := UpdateVerifier.verify_file(_installer_path, _signature, public_key_pem)
	if why != "":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_installer_path))
		_fail("the download failed verification (%s)" % why)
		return
	progress = 1.0
	state = State.READY
	changed.emit()


## Runs the verified installer and closes the game. Re-verifies first, because the file has sat in
## the player's profile folder since it was checked. Returns false (state FAILED) if anything is off.
func install_and_restart() -> bool:
	if state != State.READY:
		return false
	var why := UpdateVerifier.verify_file(_installer_path, _signature, public_key_pem)
	if why != "":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_installer_path))
		return _fail("the update failed verification (%s)" % why)
	var pid: int = launch.call(ProjectSettings.globalize_path(_installer_path), INSTALLER_ARGS)
	if pid <= 0:
		return _fail("the installer could not be started")
	quit_game.call()
	return true


func _process(_delta: float) -> void:
	if state != State.DOWNLOADING or _request == null:
		return
	var total := _request.get_body_size()
	if total > 0 and _request.download_file != "":
		var now := clampf(float(_request.get_downloaded_bytes()) / float(total), 0.0, 1.0)
		if int(now * 100.0) != int(progress * 100.0):
			progress = now
			changed.emit()


func _begin_request(url: String, file: String, size_limit: int, timeout: float, done: Callable) -> bool:
	_drop_request()
	if dry_run:
		requested.append(url)
		return true
	_request = HTTPRequest.new()
	_request.body_size_limit = size_limit
	_request.timeout = timeout
	if file != "":
		_request.download_file = ProjectSettings.globalize_path(file)
	_request.request_completed.connect(done)
	add_child(_request)
	if _request.request(url, PackedStringArray(["User-Agent: card-battle-prototype"])) != OK:
		_drop_request()
		return false
	return true


func _on_signature_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	handle_signature(result, code, body)


func _on_installer_completed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_drop_request()
	handle_installer(result, code)


func _drop_request() -> void:
	if _request != null:
		_request.queue_free()
		_request = null


func _fail(why: String) -> bool:
	_drop_request()
	state = State.FAILED
	error = why
	changed.emit()
	return false
