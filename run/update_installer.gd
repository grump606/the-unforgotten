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
## (3) the installer's SHA-256 equals the one in the manifest (UpdateVerifier).
## (3) is checked on arrival and again, on a private copy, right before launch. Signing the name and version, not
## just the bytes, is what stops an older genuinely signed installer being replayed as an update.
##
## Threads: both hashes (and the copy) run on a worker thread in the real game so the UI keeps drawing; tests run
## them inline unless force_worker is set.
##
## States and flags (every way a job ends goes through _abandon, except a normal finish):
##   IDLE         nothing held. start() -> DOWNLOADING.
##   DOWNLOADING  requests in flight, then (threaded) a hash job; _thread is set only during that hash job.
##                _complete_download -> READY (or FAILED); cancel() -> IDLE and removes the files.
##   READY        a verified installer sits in work_dir. install_and_restart() sets _installing while a copy job
##                runs (_thread set, _thread_dir = its run_* folder), then _launch_copy -> _launched (the game quits)
##                or FAILED. cancel() KEEPS the installer (and READY); discard() removes it -> IDLE.
##   FAILED       `error` is set; start() tries again.
## Flags:
##   _job_serial  bumped when a job starts and whenever one is abandoned; a finished job counts only if its serial
##                is still current.
##   _installing  a launch copy is being prepared; a second install_and_restart() is ignored.
##   _launched    the installer process was started; set by _launch_copy, cleared only by start(), so cancel(),
##                discard() and a late click cannot start a second installer.
##   _thread      the current worker (null when none). _retire_worker moves it, with its _thread_dir, to _retired
##                without waiting; _process joins finished ones and removes their run_* folder (_reap_retired).
##   _retired     abandoned workers not yet joined. The node being freed joins them all (the only blocking place).

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
## The two big file jobs (hashing the download, copying and hashing the launch copy) run on a worker thread so
## the UI never stalls on ~120 MB of SHA-256. Off in dry_run (tests stay synchronous) unless force_worker is set.
var use_worker := true
## Tests: run the jobs on the worker thread even in dry_run, to exercise that path.
var force_worker := false

var _manifest_signature := PackedByteArray()
## The SHA-256 (lowercase hex) the signed manifest promises for the installer.
var _expected_sha256 := ""
var _installer_path := ""
var _request: HTTPRequest
var _thread: Thread
## The absolute run_* folder the current job is writing to ("" for a hash job).
var _thread_dir := ""
## Workers whose result was abandoned (cancel, discard, a newer job) but that are still running or not joined yet:
## [{thread, dir}]. _process joins each one once it has finished, so the main thread never waits for a copy.
var _retired: Array = []
## Bumped whenever a job starts or is abandoned (cancel, discard): a finished job only counts if its serial is current.
var _job_serial := 0
## True while the launch copy is being prepared (state stays READY); a second call is ignored.
var _installing := false
## True once the installer was started: the game is about to quit, and a second click must not start another one.
var _launched := false


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
	_launched = false
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


## Cancels work in flight: a download returns to IDLE, and a launch copy being prepared is abandoned (its run_*
## folder is removed once the worker has finished) with the state staying READY. A verified installer the player
## has not discarded is KEPT (only discard() removes it), so "Update & restart" works again afterwards. Never
## waits for the worker (see _retire_worker).
func cancel() -> void:
	_abandon()
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
	if _threaded():
		# Hash on the worker; the state stays DOWNLOADING (at 100%) until it reports back.
		progress = 1.0
		_start_job(_job_serial + 1, _hash_job.bind(_job_serial + 1, ProjectSettings.globalize_path(_installer_path), _expected_sha256))
		return
	_complete_download(UpdateVerifier.verify_file_hash(_installer_path, _expected_sha256))


## The downloaded installer has been hashed: "" means it matches the signed manifest.
func _complete_download(why: String) -> void:
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
	var had_worker := _abandon()
	# Best effort now (a file the worker still has open may survive); the run_* folder of a retired copy is removed
	# for sure when the worker has been joined (_reap_retired).
	if state == State.READY or had_worker:
		cleanup(work_dir)
	if state == State.READY:
		state = State.IDLE
		progress = 0.0
		changed.emit()


## Runs the verified installer and closes the game. The file has sat in the player's profile folder since it
## was checked, so it is copied into a fresh, randomly named folder first and the COPY is hashed and launched:
## nothing that learned the download's name can swap the file between the check and the launch. Returns false
## (state FAILED) if anything is off.
func install_and_restart() -> bool:
	if state != State.READY or _installing or _launched:
		return false
	var launch_dir := work_dir.path_join("run_" + Crypto.new().generate_random_bytes(8).hex_encode())
	var copy_path := launch_dir.path_join(_installer_path.get_file())
	var source_abs := ProjectSettings.globalize_path(_installer_path)
	var dir_abs := ProjectSettings.globalize_path(launch_dir)
	var copy_abs := ProjectSettings.globalize_path(copy_path)
	if _threaded():
		# Returns true = started. A failure arrives later as state FAILED (UpdateNotice listens to `changed`).
		_installing = true
		_start_job(_job_serial + 1, _copy_job.bind(_job_serial + 1, source_abs, dir_abs, copy_abs, _expected_sha256), dir_abs)
		return true
	return _launch_copy(_prepare_copy(source_abs, dir_abs, copy_abs, _expected_sha256), copy_path)


## The launch copy was made and hashed (outcome from _prepare_copy): run it, or fail with the reason.
func _launch_copy(outcome: Dictionary, copy_path: String) -> bool:
	_installing = false
	if not outcome["copied"]:
		cleanup(work_dir)
		return _fail("the installer could not be prepared")
	if outcome["why"] != "":
		cleanup(work_dir)
		return _fail("the update failed verification (%s)" % outcome["why"])
	var pid: int = launch.call(ProjectSettings.globalize_path(copy_path), INSTALLER_ARGS)
	if pid <= 0:
		cleanup(work_dir)
		return _fail("the installer could not be started")
	_launched = true
	quit_game.call()
	return true


## Makes the private copy and hashes THE COPY (the exact file that will be launched). Static and free of scene
## state so it can run on a worker thread. Returns {copied: bool, why: String}.
static func _prepare_copy(source_abs: String, launch_dir_abs: String, copy_abs: String, expected_hex: String) -> Dictionary:
	if not FileAccess.file_exists(source_abs) or DirAccess.make_dir_recursive_absolute(launch_dir_abs) != OK or DirAccess.copy_absolute(source_abs, copy_abs) != OK:
		return {"copied": false, "why": ""}
	return {"copied": true, "why": UpdateVerifier.verify_file_hash(copy_abs, expected_hex)}


static func _hash_job(serial: int, path_abs: String, expected_hex: String) -> Dictionary:
	return {"serial": serial, "kind": "hash", "why": UpdateVerifier.verify_file_hash(path_abs, expected_hex)}


static func _copy_job(serial: int, source_abs: String, launch_dir_abs: String, copy_abs: String, expected_hex: String) -> Dictionary:
	var outcome := _prepare_copy(source_abs, launch_dir_abs, copy_abs, expected_hex)
	outcome["serial"] = serial
	outcome["kind"] = "copy"
	outcome["copy_abs"] = copy_abs
	return outcome


func _threaded() -> bool:
	return force_worker or (use_worker and not dry_run)


func _start_job(serial: int, work: Callable, launch_dir_abs := "") -> void:
	_retire_worker()
	_job_serial = serial
	_thread_dir = launch_dir_abs
	_thread = Thread.new()
	_thread.start(work)


## The shared first half of cancel(), discard() and freeing the node: drops the request, invalidates the running job
## (a late result is ignored) and retires its worker without waiting. Leaves `state` and `_launched` alone: once the
## installer has started, nothing may re-arm a second launch. True if a worker was there.
func _abandon() -> bool:
	_drop_request()
	_job_serial += 1
	_installing = false
	return _retire_worker()


## Abandons the current worker WITHOUT waiting for it: callers have already bumped _job_serial, so its result is
## dropped, and the Thread object is kept in _retired until _process sees it finished (a Thread must be joined
## with wait_to_finish() before it is freed, but joining a running copy of ~123 MiB would freeze the UI). The
## worker only does file I/O and hashing, so it needs nothing from the scene. True if a worker was there.
func _retire_worker() -> bool:
	if _thread == null:
		return false
	_retired.append({"thread": _thread, "dir": _thread_dir})
	_thread = null
	_thread_dir = ""
	return true


## Joins the retired workers that have finished and removes the run_* folder each one wrote (so a copy that
## finished after cancel/discard cannot leave a stray installer behind). Never blocks.
func _reap_retired() -> void:
	var hash_reaped := false
	for entry in _retired.duplicate():
		var thread: Thread = entry["thread"]
		if thread.is_alive():
			continue
		thread.wait_to_finish()
		_retired.erase(entry)
		if entry["dir"] != "":
			_remove_folder(entry["dir"])
		else:
			hash_reaped = true
	# A download hash that was abandoned may have kept the file open when cleanup ran: try again when nothing is active.
	if hash_reaped and _thread == null and state != State.DOWNLOADING and state != State.READY:
		cleanup(work_dir)


static func _remove_folder(dir_abs: String) -> void:
	var access := DirAccess.open(dir_abs)
	if access == null:
		return
	for file_name in access.get_files():
		access.remove(file_name)
	DirAccess.remove_absolute(dir_abs)


## True while an abandoned or current worker has not been joined yet (tests wait for it to drop to 0).
func pending_workers() -> int:
	return _retired.size() + (1 if _thread != null else 0)


## Collects the current job if it has finished (or, with `block`, waits for it) and acts on its result, but only
## if no cancel/discard/new job happened since it started.
func _reap(block: bool) -> void:
	if _thread == null:
		return
	if not block and _thread.is_alive():
		return
	var outcome: Variant = _thread.wait_to_finish()
	_thread = null
	_thread_dir = ""
	if not (outcome is Dictionary) or int(outcome["serial"]) != _job_serial:
		return
	if outcome["kind"] == "hash":
		if state == State.DOWNLOADING:
			_complete_download(outcome["why"])
	elif state == State.READY:
		_launch_copy(outcome, outcome["copy_abs"])


## Tests: waits for the running worker and acts on its result exactly as the next frame step would, so a test
## needs no timer or polling (the thread is joined, however slow the machine is). Retired workers are joined too.
func finish_worker() -> void:
	_reap(true)
	for entry in _retired.duplicate():
		(entry["thread"] as Thread).wait_to_finish()
		_retired.erase(entry)
		if entry["dir"] != "":
			_remove_folder(entry["dir"])


## A Thread must be joined before it is freed, so freeing the node (the game closing, or a test) joins every worker
## still around. That is the one place that can wait: nothing is on screen by then, and a worker that was retired
## earlier has normally been reaped by _process already. Also covers a node that was never in the tree.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_abandon()
		for entry in _retired:
			(entry["thread"] as Thread).wait_to_finish()
			if entry["dir"] != "":
				_remove_folder(entry["dir"])
		_retired.clear()


func _process(_delta: float) -> void:
	_reap(false)
	_reap_retired()
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
