extends "res://tests/test_base.gd"
## Edge cases of UpdateInstaller's state machine that update_installer_tests.gd does not walk: callbacks that
## arrive in the wrong state, out-of-order replies, double installs, a failed rename, cancel followed by a late
## reply, the self-update gate, the worker-thread path, and the UpdateNotice-to-installer hand-off. dry_run
## records URLs instead of sending them and the replies are fed in directly, so no network or real installer runs.

const Support := preload("res://tests/update_support.gd")
const TEST_TAG := "v0.3.9"
const RUNNING := "0.3.0"

var _dir := "user://update_installer_edge_test_%d" % OS.get_process_id()


class Probe extends RefCounted:
	var launched: Array = []
	var quits := 0
	var pid := 4242


func run() -> int:
	_failures = 0
	var key := Crypto.new().generate_rsa(2048)
	var pem := key.save_to_string(true)
	_test_callbacks_in_the_wrong_state(key, pem)
	_test_out_of_order(key, pem)
	_test_double_install(key, pem)
	_test_rename_failure(key, pem)
	_test_cancel_then_late_callback(key, pem)
	_test_self_update_gate()
	_test_worker_path(key, pem)
	_test_notice_hand_off(key, pem)
	_cleanup()
	return _failures


func _installer(pem: String, probe: Probe) -> UpdateInstaller:
	var installer := UpdateInstaller.new()
	installer.dry_run = true
	installer.public_key_pems = [pem]
	installer.current_version = RUNNING
	installer.work_dir = _dir
	installer.launch = func(path: String, args: PackedStringArray) -> int:
		probe.launched.append([path, args])
		return probe.pid
	installer.quit_game = func() -> void: probe.quits += 1
	return installer


func _installer_path() -> String:
	return _dir.path_join(UpdateCheck.installer_name(TEST_TAG))


## Leaves `content` where the downloader would (as the .part file) and returns the signed manifest for it.
func _stage(content: String, key: CryptoKey) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	var file := FileAccess.open(_installer_path() + ".part", FileAccess.WRITE)
	file.store_string(content)
	file.close()
	var manifest := Support.manifest_for(_installer_path() + ".part", TEST_TAG)
	return {"manifest": manifest, "sig": Support.sign_bytes(manifest, key)}


func _feed_signature_and_manifest(installer: UpdateInstaller, staged: Dictionary) -> void:
	installer.handle_manifest_signature(HTTPRequest.RESULT_SUCCESS, 200, staged["sig"])
	installer.handle_manifest(HTTPRequest.RESULT_SUCCESS, 200, staged["manifest"])


func _ready_installer(pem: String, probe: Probe, key: CryptoKey) -> UpdateInstaller:
	var installer := _installer(pem, probe)
	installer.start(TEST_TAG)
	_feed_signature_and_manifest(installer, _stage("good installer", key))
	installer.handle_installer(HTTPRequest.RESULT_SUCCESS, 200)
	return installer


## Runs the installer's frame step until `done` is true (or 10 s pass): the worker thread reports back there.
func _pump(installer: UpdateInstaller, done: Callable) -> bool:
	var started := Time.get_ticks_msec()
	while not done.call():
		if Time.get_ticks_msec() - started > 10000:
			return false
		installer._process(0.0)
		OS.delay_msec(2)
	return true


func _test_callbacks_in_the_wrong_state(key: CryptoKey, pem: String) -> void:
	var good := _stage("late", key)
	# IDLE: nothing was started, so no reply may move anything.
	var installer := _installer(pem, Probe.new())
	installer.handle_manifest_signature(HTTPRequest.RESULT_SUCCESS, 200, good["sig"])
	installer.handle_manifest(HTTPRequest.RESULT_SUCCESS, 200, good["manifest"])
	installer.handle_installer(HTTPRequest.RESULT_SUCCESS, 200)
	_check(installer.state == UpdateInstaller.State.IDLE and installer.requested.is_empty() and installer.error == "", "replies arriving in IDLE change nothing and request nothing")
	installer.free()

	# FAILED: a reply after the failure must not overwrite the reason or request more.
	installer = _installer(pem, Probe.new())
	installer.start(TEST_TAG)
	installer.handle_manifest_signature(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedByteArray())
	var reason := installer.error
	_check(installer.state == UpdateInstaller.State.FAILED and reason != "", "setup: the signature download failed")
	_feed_signature_and_manifest(installer, good)
	installer.handle_installer(HTTPRequest.RESULT_SUCCESS, 200)
	_check(installer.state == UpdateInstaller.State.FAILED and installer.error == reason and installer.requested.size() == 1, "replies arriving after a failure change nothing")
	installer.free()

	# READY: a duplicate installer reply must not re-run the rename/hash or disturb the verified file.
	var probe := Probe.new()
	installer = _ready_installer(pem, probe, key)
	_check(installer.state == UpdateInstaller.State.READY, "setup: ready")
	var before := Support.sha256_hex(_installer_path())
	_stage("a different file", key)
	installer.handle_installer(HTTPRequest.RESULT_SUCCESS, 200)
	installer.handle_manifest(HTTPRequest.RESULT_SUCCESS, 200, good["manifest"])
	installer.handle_manifest_signature(HTTPRequest.RESULT_SUCCESS, 200, good["sig"])
	_check(installer.state == UpdateInstaller.State.READY and Support.sha256_hex(_installer_path()) == before, "replies arriving in READY change nothing and leave the verified file alone")
	_check(not installer.start(TEST_TAG) and installer.state == UpdateInstaller.State.READY, "start() is refused while a verified installer waits")
	installer.free()
	UpdateInstaller.cleanup(_dir)


func _test_out_of_order(key: CryptoKey, pem: String) -> void:
	var staged := _stage("x", key)
	# The manifest before its signature: there is no signature yet, so it cannot verify.
	var installer := _installer(pem, Probe.new())
	installer.start(TEST_TAG)
	installer.handle_manifest(HTTPRequest.RESULT_SUCCESS, 200, staged["manifest"])
	_check(installer.state == UpdateInstaller.State.FAILED and installer.requested.size() == 1, "a manifest that arrives before its signature fails and the installer is never requested")
	installer.free()

	# The installer reply before the manifest: no expected hash is known, and nothing is on disk to rename.
	installer = _installer(pem, Probe.new())
	installer.start(TEST_TAG)
	installer.handle_installer(HTTPRequest.RESULT_SUCCESS, 200)
	_check(installer.state == UpdateInstaller.State.FAILED, "an installer reply before the manifest cannot become READY")
	installer.free()

	# The same, even when a file is sitting at the .part path (a stale download).
	installer = _installer(pem, Probe.new())
	installer.start(TEST_TAG)  # start() cleans the folder, so stage after it
	_stage("stale", key)
	installer.handle_installer(HTTPRequest.RESULT_SUCCESS, 200)
	_check(installer.state == UpdateInstaller.State.FAILED, "a stale file is not accepted without a verified manifest hash")
	installer.free()
	UpdateInstaller.cleanup(_dir)


func _test_double_install(key: CryptoKey, pem: String) -> void:
	var probe := Probe.new()
	var installer := _ready_installer(pem, probe, key)
	_check(installer.install_and_restart() and probe.launched.size() == 1 and probe.quits == 1, "the first install_and_restart launches once")
	_check(not installer.install_and_restart() and probe.launched.size() == 1 and probe.quits == 1, "a second one (a double click before the game quits) does not start another installer")
	installer.free()
	UpdateInstaller.cleanup(_dir)

	# Not READY: nothing runs.
	probe = Probe.new()
	installer = _installer(pem, probe)
	_check(not installer.install_and_restart() and probe.launched.is_empty(), "install_and_restart in IDLE does nothing")
	installer.start(TEST_TAG)
	_check(not installer.install_and_restart() and probe.launched.is_empty(), "install_and_restart while downloading does nothing")
	installer.free()
	UpdateInstaller.cleanup(_dir)


func _test_rename_failure(key: CryptoKey, pem: String) -> void:
	var probe := Probe.new()
	var installer := _installer(pem, probe)
	installer.start(TEST_TAG)
	_feed_signature_and_manifest(installer, _stage("good installer", key))
	# The download's .part vanished (antivirus, disk cleanup): the rename fails.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_installer_path() + ".part"))
	installer.handle_installer(HTTPRequest.RESULT_SUCCESS, 200)
	_check(installer.state == UpdateInstaller.State.FAILED and installer.error.contains("saved"), "a missing .part fails with 'could not be saved' (%s)" % installer.error)
	_check(not FileAccess.file_exists(_installer_path()) and not installer.install_and_restart() and probe.launched.is_empty(), "nothing can be launched after a rename failure")
	installer.free()
	UpdateInstaller.cleanup(_dir)


func _test_cancel_then_late_callback(key: CryptoKey, pem: String) -> void:
	var probe := Probe.new()
	var installer := _installer(pem, probe)
	installer.start(TEST_TAG)
	var staged := _stage("cancelled", key)
	installer.handle_manifest_signature(HTTPRequest.RESULT_SUCCESS, 200, staged["sig"])
	installer.cancel()
	_check(installer.state == UpdateInstaller.State.IDLE, "cancel returns to IDLE")
	installer.handle_manifest(HTTPRequest.RESULT_SUCCESS, 200, staged["manifest"])
	installer.handle_installer(HTTPRequest.RESULT_SUCCESS, 200)
	_check(installer.state == UpdateInstaller.State.IDLE and installer.requested.size() == 2 and not FileAccess.file_exists(_installer_path()), "a reply that arrives after cancel is ignored and requests nothing")
	_check(not installer.install_and_restart() and probe.launched.is_empty(), "and nothing can be installed")
	# A new attempt after the cancel starts clean.
	_check(installer.start(TEST_TAG) and installer.state == UpdateInstaller.State.DOWNLOADING, "a fresh start after a cancel works")
	installer.free()
	UpdateInstaller.cleanup(_dir)


func _test_self_update_gate() -> void:
	_check(UpdateCheck.can_self_update(false, "C:/Games/The Unforgotten/TheUnforgotten.exe", true), "an exported, correctly named, writable install can update itself")
	_check(UpdateCheck.can_self_update(false, "C:/Games/x/theunforgotten.EXE", true), "the exe name check ignores case")
	_check(not UpdateCheck.can_self_update(true, "C:/Games/x/TheUnforgotten.exe", true), "the editor never updates itself")
	_check(not UpdateCheck.can_self_update(false, "C:/Games/x/TheUnforgotten.exe", false), "a folder the player cannot write to is refused")
	_check(not UpdateCheck.can_self_update(false, "C:/Games/x/Godot_v4.7.2.exe", true), "a renamed or foreign executable is refused")
	_check(not UpdateCheck.can_self_update(false, "", true), "an unknown executable path is refused")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	var abs_dir := ProjectSettings.globalize_path(_dir)
	_check(UpdateInstaller._dir_writable(abs_dir), "a writable folder passes the probe")
	var leftovers := 0
	for file_name in DirAccess.get_files_at(_dir):
		if file_name.begins_with(".write_test_"):
			leftovers += 1
	_check(leftovers == 0, "the write probe cleans up after itself")
	_check(not UpdateInstaller._dir_writable(abs_dir.path_join("no_such_folder_%d" % OS.get_process_id())), "a missing folder fails the probe")
	_check(not UpdateInstaller.available(), "headless runs never self-update")


## The same flow with the file jobs on the worker thread (what the real game does).
func _test_worker_path(key: CryptoKey, pem: String) -> void:
	var probe := Probe.new()
	var installer := _installer(pem, probe)
	installer.force_worker = true
	installer.start(TEST_TAG)
	_feed_signature_and_manifest(installer, _stage("worker installer", key))
	installer.handle_installer(HTTPRequest.RESULT_SUCCESS, 200)
	_check(installer.state == UpdateInstaller.State.DOWNLOADING and installer.progress == 1.0, "the download hash runs in the background: still DOWNLOADING at 100%")
	_check(_pump(installer, func() -> bool: return installer.state != UpdateInstaller.State.DOWNLOADING) and installer.state == UpdateInstaller.State.READY, "the worker reports a matching hash and the state becomes READY")
	_check(installer.install_and_restart() and probe.launched.is_empty(), "install_and_restart starts the copy in the background and launches nothing yet")
	_check(not installer.install_and_restart(), "a second call while the copy is being prepared is ignored")
	_check(_pump(installer, func() -> bool: return probe.quits > 0), "the launch happens once the copy is hashed")
	_check(probe.launched.size() == 1 and probe.quits == 1 and (probe.launched[0][0] as String).replace("\\", "/").contains("/run_"), "the private copy is what runs, exactly once")
	_check(not installer.install_and_restart() and probe.launched.size() == 1, "and a call after the launch does nothing")
	installer.free()
	UpdateInstaller.cleanup(_dir)

	# A download that does not match fails on the worker path too, and the file is removed.
	probe = Probe.new()
	installer = _installer(pem, probe)
	installer.force_worker = true
	installer.start(TEST_TAG)
	var staged := _stage("original", key)
	var file := FileAccess.open(_installer_path() + ".part", FileAccess.WRITE)
	file.store_string("tampered")
	file.close()
	_feed_signature_and_manifest(installer, staged)
	installer.handle_installer(HTTPRequest.RESULT_SUCCESS, 200)
	_check(_pump(installer, func() -> bool: return installer.state != UpdateInstaller.State.DOWNLOADING) and installer.state == UpdateInstaller.State.FAILED and not FileAccess.file_exists(_installer_path()), "a tampered download fails on the worker and is deleted")
	installer.free()
	UpdateInstaller.cleanup(_dir)

	# A file swapped after verification is caught by the hash of the launch copy.
	probe = Probe.new()
	installer = _installer(pem, probe)
	installer.force_worker = true
	installer.start(TEST_TAG)
	_feed_signature_and_manifest(installer, _stage("good installer", key))
	installer.handle_installer(HTTPRequest.RESULT_SUCCESS, 200)
	_pump(installer, func() -> bool: return installer.state != UpdateInstaller.State.DOWNLOADING)
	file = FileAccess.open(_installer_path(), FileAccess.WRITE)
	file.store_string("malware")
	file.close()
	installer.install_and_restart()
	_check(_pump(installer, func() -> bool: return installer.state == UpdateInstaller.State.FAILED) and probe.launched.is_empty() and probe.quits == 0, "a swapped file is caught by the copy's hash on the worker and never launched")
	installer.free()
	UpdateInstaller.cleanup(_dir)

	# Cancel while the download hash is running: the late result is dropped.
	probe = Probe.new()
	installer = _installer(pem, probe)
	installer.force_worker = true
	installer.start(TEST_TAG)
	_feed_signature_and_manifest(installer, _stage("good installer", key))
	installer.handle_installer(HTTPRequest.RESULT_SUCCESS, 200)
	installer.cancel()
	for i in 200:
		installer._process(0.0)
		OS.delay_msec(1)
	_check(installer.state == UpdateInstaller.State.IDLE and probe.launched.is_empty(), "cancel during the background hash: the late result does not revive the download")
	installer.free()
	UpdateInstaller.cleanup(_dir)

	# Discard while the launch copy is being prepared: the late result must not launch anything.
	probe = Probe.new()
	installer = _installer(pem, probe)
	installer.force_worker = true
	installer.start(TEST_TAG)
	_feed_signature_and_manifest(installer, _stage("good installer", key))
	installer.handle_installer(HTTPRequest.RESULT_SUCCESS, 200)
	_pump(installer, func() -> bool: return installer.state != UpdateInstaller.State.DOWNLOADING)
	installer.install_and_restart()
	installer.discard()
	for i in 200:
		installer._process(0.0)
		OS.delay_msec(1)
	_check(installer.state == UpdateInstaller.State.IDLE and probe.launched.is_empty() and probe.quits == 0, "discard during the background copy: nothing is launched")
	installer.free()
	UpdateInstaller.cleanup(_dir)


## UpdateNotice drives an UpdateInstaller: a verified download installs by itself on a menu screen, waits when a
## run is under way, and a failure falls back to the plain Download button. (ui_update_notice_test.gd covers the
## synchronous flow in a real scene; this adds the worker path and the failure text.)
func _test_notice_hand_off(key: CryptoKey, pem: String) -> void:
	var probe := Probe.new()
	var notice := UpdateNotice.new()
	notice.current_version = RUNNING
	notice.use_installer = true
	notice.installer.dry_run = true
	notice.installer.force_worker = true
	notice.installer.public_key_pems = [pem]
	notice.installer.work_dir = _dir
	notice.installer.launch = func(path: String, args: PackedStringArray) -> int:
		probe.launched.append([path, args])
		return probe.pid
	notice.installer.quit_game = func() -> void: probe.quits += 1
	notice.handle_response(200, JSON.stringify({"tag_name": TEST_TAG}).to_utf8_buffer())
	notice.download_button.pressed.emit()
	var installer := notice.installer
	_check(installer.state == UpdateInstaller.State.DOWNLOADING and notice.download_button.disabled, "the click starts the download")
	_feed_signature_and_manifest(installer, _stage("notice installer", key))
	installer.handle_installer(HTTPRequest.RESULT_SUCCESS, 200)
	_check(_pump(installer, func() -> bool: return probe.quits > 0), "READY on a menu screen installs by itself (the notice calls install_and_restart on the worker path)")
	_check(probe.launched.size() == 1 and installer.state == UpdateInstaller.State.READY, "exactly one installer was started")

	# During a run the bar waits for a click.
	probe.launched.clear()
	probe.quits = 0
	installer.discard()
	notice.set_allowed(false)
	notice.download_button.disabled = false
	notice.download_button.pressed.emit()
	_feed_signature_and_manifest(installer, _stage("notice installer", key))
	installer.handle_installer(HTTPRequest.RESULT_SUCCESS, 200)
	_pump(installer, func() -> bool: return installer.state == UpdateInstaller.State.READY)
	_check(installer.state == UpdateInstaller.State.READY and probe.launched.is_empty() and notice.download_button.text == "Restart now", "during a run a verified download waits for Restart now")
	notice.set_allowed(true)
	notice.download_button.pressed.emit()
	_check(_pump(installer, func() -> bool: return probe.quits > 0) and probe.launched.size() == 1, "Restart now installs")

	# A bad download shows why and falls back to the plain button.
	installer.discard()
	notice.use_installer = true
	notice.download_button.pressed.emit()
	installer.handle_manifest_signature(HTTPRequest.RESULT_SUCCESS, 500, PackedByteArray())
	_check(notice.label.text.begins_with("Update failed") and notice.download_button.text == "Download" and not notice.use_installer, "a failed update shows why and falls back to Download")
	notice.free()
	UpdateInstaller.cleanup(_dir)


func _cleanup() -> void:
	UpdateInstaller.cleanup(_dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_dir))
