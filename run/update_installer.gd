class_name UpdateInstaller
extends Node
## Downloads a newer release's installer, verifies it against a signed manifest and hands over to it:
## the installer replaces the game files and relaunches the game. Started only by the player's click
## (see UpdateNotice). Every step is checked and any failure leaves the game running as it was.
##
## Trust chain (docs/UPDATE_CHECK.md): the URLs are built from a validated tag against a fixed host
## (UpdateCheck.installer_url); the downloads are size-capped; and the installer is run ONLY if
## (1) the manifest's detached RSA signature verifies against the public key built into the game,
## (2) the manifest names this release's file and version and is newer than the running game, and
## (3) the installer's SHA-256 equals the one in the manifest (UpdateVerifier). (3) is checked on
## arrival and again, on a private copy, right before launch. Signing name and version, not just bytes, is what stops an
## older genuinely signed installer being replayed as an update.

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
## The running game's version; a manifest must be for something newer. Tests set it.
var current_version: String = str(ProjectSettings.get_setting("application/config/version", ""))
## The keys signatures may verify against (any one will do); tests substitute generated ones.
var public_key_pems: Array = UpdateVerifier.PUBLIC_KEY_PEMS
## Where downloads go. user:// is inside the player's own profile.
var work_dir := "user://update"
## Starts a program: (path, args) -> process id, or <= 0 on failure. Tests replace it.
var launch: Callable = func(path: String, args: PackedStringArray) -> int: return OS.create_process(path, args)
## Closes the game once the installer is running. Tests replace it.
var quit_game: Callable = func() -> void: get_tree().quit()

## Tests: record the URL in `requested` instead of sending the request.
var dry_run := false
var requested: Array[String] = []

var _manifest_signature := PackedByteArray()
## The SHA-256 (lowercase hex) the signed manifest promises for the installer.
var _expected_sha256 := ""
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
	# The per-launch copies (see install_and_restart) live in one level of subfolders.
	for dir_name in access.get_directories():
		var sub := DirAccess.open(dir.path_join(dir_name))
		if sub != null:
			for file_name in sub.get_files():
				sub.remove(file_name)
		access.remove(dir_name)


## Begins downloading the release `release_tag`. Returns false (state FAILED, `error` set) when it
## cannot start; true when the first request is in flight. Ignored while already downloading.
func start(release_tag: String) -> bool:
	if state == State.DOWNLOADING or state == State.READY:
		return false
	tag = release_tag
	if not UpdateCheck.is_valid_tag(tag):
		return _fail("the release version is not valid")
	if not UpdateVerifier.is_configured(public_key_pems):
		return _fail("this version cannot verify updates")
	cleanup(work_dir)
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(work_dir)) != OK:
		return _fail("cannot create the download folder")
	_installer_path = work_dir.path_join(UpdateCheck.installer_name(tag))
	progress = 0.0
	error = ""
	state = State.DOWNLOADING
	_expected_sha256 = ""
	if not _begin_request(UpdateCheck.manifest_signature_url(tag), "", UpdateCheck.MAX_SIGNATURE_BYTES, SIGNATURE_TIMEOUT, _on_manifest_signature_completed):
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


## The manifest's signature arrived (or failed to): store it and fetch the manifest.
func handle_manifest_signature(result: int, code: int, body: PackedByteArray) -> void:
	if state != State.DOWNLOADING:
		return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail("the update signature could not be downloaded")
		return
	if body.is_empty() or body.size() > UpdateCheck.MAX_SIGNATURE_BYTES:
		_fail("the update signature is not valid")
		return
	_manifest_signature = body
	if not _begin_request(UpdateCheck.manifest_url(tag), "", UpdateCheck.MAX_MANIFEST_BYTES, SIGNATURE_TIMEOUT, _on_manifest_completed):
		_fail("could not start the download")


## The manifest arrived: it must be signed and describe exactly this release. Only then is the
## installer fetched, and its expected hash is whatever the signed manifest says.
func handle_manifest(result: int, code: int, body: PackedByteArray) -> void:
	if state != State.DOWNLOADING:
		return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail("the update manifest could not be downloaded")
		return
	var why := UpdateVerifier.verify_manifest(body, _manifest_signature, tag, current_version, public_key_pems)
	if why != "":
		_fail("the update failed verification (%s)" % why)
		return
	_expected_sha256 = UpdateCheck.parse_manifest(body)["sha256"]
	if not _begin_request(UpdateCheck.installer_url(tag), _installer_path + ".part", UpdateCheck.MAX_INSTALLER_BYTES, DOWNLOAD_TIMEOUT, _on_installer_completed):
		_fail("could not start the download")


## The installer finished downloading to `<path>.part`: move it into place and check its hash.
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
	var why := UpdateVerifier.verify_file_hash(_installer_path, _expected_sha256)
	if why != "":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_installer_path))
		_fail("the download failed verification (%s)" % why)
		return
	progress = 1.0
	state = State.READY
	changed.emit()


## Removes a downloaded installer that is waiting (READY) or leftovers of a failed attempt, and returns to
## IDLE. The Skip button uses it; cancel() only handles a download in flight.
func discard() -> void:
	_drop_request()
	if state == State.READY:
		cleanup(work_dir)
		state = State.IDLE
		progress = 0.0
		changed.emit()


## Runs the verified installer and closes the game. The file has sat in the player's profile folder since it
## was checked, so it is copied into a fresh, randomly named folder first and the COPY is hashed and launched:
## nothing that learned the download's name can swap the file between the check and the launch. Returns false
## (state FAILED) if anything is off.
func install_and_restart() -> bool:
	if state != State.READY:
		return false
	var launch_dir := work_dir.path_join("run_" + Crypto.new().generate_random_bytes(8).hex_encode())
	var copy_path := launch_dir.path_join(_installer_path.get_file())
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(launch_dir)) != OK \
			or DirAccess.copy_absolute(ProjectSettings.globalize_path(_installer_path), ProjectSettings.globalize_path(copy_path)) != OK:
		cleanup(work_dir)
		return _fail("the installer could not be prepared")
	var why := UpdateVerifier.verify_file_hash(copy_path, _expected_sha256)
	if why != "":
		cleanup(work_dir)
		return _fail("the update failed verification (%s)" % why)
	var pid: int = launch.call(ProjectSettings.globalize_path(copy_path), INSTALLER_ARGS)
	if pid <= 0:
		cleanup(work_dir)
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
	# HTTPRequest follows redirects internally and does not report the final URL, so a redirect to plain http://
	# cannot be refused here. That is safe because nothing downloaded is trusted by its transport: the manifest must
	# carry a valid signature and the installer must match the signed SHA-256. The cap just bounds redirect chains.
	_request.max_redirects = UpdateCheck.MAX_REDIRECTS
	if file != "":
		_request.download_file = ProjectSettings.globalize_path(file)
	_request.request_completed.connect(done)
	add_child(_request)
	if _request.request(url, PackedStringArray(["User-Agent: the-unforgotten"])) != OK:
		_drop_request()
		return false
	return true


func _on_manifest_signature_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	handle_manifest_signature(result, code, body)


func _on_manifest_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	handle_manifest(result, code, body)


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
