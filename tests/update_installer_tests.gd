extends RefCounted
## Tests for UpdateInstaller's state machine. dry_run records the URLs instead of requesting them,
## and the replies are fed in directly, so no network is used and no real installer is run.

const VerifierTests := preload("res://tests/update_verifier_tests.gd")
const TEST_TAG := "v0.3.9"
const RUNNING := "0.3.0"

var _failures := 0
var _dir := "user://update_installer_test_%d" % OS.get_process_id()


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


class Probe extends RefCounted:
	var launched: Array = []
	var quits := 0
	var pid := 4242


func run() -> int:
	var key := Crypto.new().generate_rsa(2048)
	var pem := key.save_to_string(true)
	_test_happy_path(key, pem)
	_test_rejections(key, pem)
	_test_manifest_rejections(key, pem)
	_test_launch_failures(key, pem)
	_test_start_guards(pem)
	_cleanup()
	return _failures


func _installer(pem: String, probe: Probe) -> UpdateInstaller:
	var installer := UpdateInstaller.new()
	installer.dry_run = true
	installer.public_key_pems = [pem] if pem != "" else []
	installer.current_version = RUNNING
	installer.work_dir = _dir
	installer.launch = func(path: String, args: PackedStringArray) -> int:
		probe.launched.append([path, args])
		return probe.pid
	installer.quit_game = func() -> void: probe.quits += 1
	return installer


func _installer_path() -> String:
	return _dir.path_join(UpdateCheck.installer_name(TEST_TAG))


## Writes `content` where the downloader would leave the installer (as the .part file) and returns
## the manifest and signature `key` makes for it as release `manifest_tag`.
func _stage(content: String, key: CryptoKey, manifest_tag := TEST_TAG) -> Dictionary:
	var file := FileAccess.open(_installer_path() + ".part", FileAccess.WRITE)
	file.store_buffer(content.to_utf8_buffer())
	file.close()
	var manifest := VerifierTests.manifest_for(_installer_path() + ".part", manifest_tag)
	return {"manifest": manifest, "sig": VerifierTests.sign_bytes(manifest, key)}


## Feeds the three replies a real download would produce, in order.
func _feed(installer: UpdateInstaller, staged: Dictionary) -> void:
	installer.handle_manifest_signature(HTTPRequest.RESULT_SUCCESS, 200, staged["sig"])
	installer.handle_manifest(HTTPRequest.RESULT_SUCCESS, 200, staged["manifest"])
	installer.handle_installer(HTTPRequest.RESULT_SUCCESS, 200)


func _overwrite(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func _ready_installer(pem: String, probe: Probe, key: CryptoKey) -> UpdateInstaller:
	var installer := _installer(pem, probe)
	installer.start(TEST_TAG)
	_feed(installer, _stage("good", key))
	return installer


func _test_happy_path(key: CryptoKey, pem: String) -> void:
	var probe := Probe.new()
	var installer := _installer(pem, probe)
	_check(installer.start(TEST_TAG) and installer.state == UpdateInstaller.State.DOWNLOADING, "start begins downloading")
	_check(installer.requested == [UpdateCheck.manifest_signature_url(TEST_TAG)], "the manifest signature is requested first, from the fixed URL")
	var staged := _stage("genuine installer", key)
	installer.handle_manifest_signature(HTTPRequest.RESULT_SUCCESS, 200, staged["sig"])
	_check(installer.requested.size() == 2 and installer.requested[1] == UpdateCheck.manifest_url(TEST_TAG), "then the manifest, from the fixed URL")
	installer.handle_manifest(HTTPRequest.RESULT_SUCCESS, 200, staged["manifest"])
	_check(installer.requested.size() == 3 and installer.requested[2] == UpdateCheck.installer_url(TEST_TAG), "then the installer, from the fixed URL, only after the manifest verified")
	installer.handle_installer(HTTPRequest.RESULT_SUCCESS, 200)
	_check(installer.state == UpdateInstaller.State.READY and installer.progress == 1.0, "a download matching the signed manifest is ready")
	_check(probe.launched.is_empty() and probe.quits == 0, "nothing runs before the player restarts")
	_check(installer.install_and_restart(), "install_and_restart succeeds")
	_check(probe.launched.size() == 1 and (probe.launched[0][0] as String).ends_with("TheUnforgotten-Setup-0.3.9.exe"), "the verified installer is what runs")
	_check(probe.launched[0][1] == UpdateInstaller.INSTALLER_ARGS and "/RELAUNCH=1" in UpdateInstaller.INSTALLER_ARGS and "/SILENT" in UpdateInstaller.INSTALLER_ARGS, "it runs silently and asks to relaunch the game")
	_check(probe.quits == 1, "the game quits once the installer is running")
	var launched_path: String = probe.launched[0][0]
	_check(launched_path.replace("\\", "/").contains("/run_") and not launched_path.replace("\\", "/").begins_with(ProjectSettings.globalize_path(_installer_path()).replace("\\", "/")), "it runs from a private per-launch copy, not the download itself")
	_check(FileAccess.file_exists(launched_path), "the launched copy exists")
	UpdateInstaller.cleanup(_dir)
	_check(not FileAccess.file_exists(launched_path) and DirAccess.get_directories_at(_dir).is_empty(), "cleanup removes the per-launch copies")
	installer.free()

	# Discarding a READY installer (the notice's Skip) removes it from disk.
	probe = Probe.new()
	installer = _ready_installer(pem, probe, key)
	_check(installer.state == UpdateInstaller.State.READY and FileAccess.file_exists(_installer_path()), "setup for discard is ready")
	installer.discard()
	_check(installer.state == UpdateInstaller.State.IDLE and not FileAccess.file_exists(_installer_path()), "discard removes a verified installer")
	installer.free()


func _test_rejections(key: CryptoKey, pem: String) -> void:
	var intruder := Crypto.new().generate_rsa(2048)
	var probe := Probe.new()
	var installer := _installer(pem, probe)
	installer.start(TEST_TAG)
	_feed(installer, _stage("evil", intruder))
	_check(installer.state == UpdateInstaller.State.FAILED and installer.requested.size() == 2, "a manifest signed by another key fails before the installer is requested")
	_check(not installer.install_and_restart() and probe.launched.is_empty() and probe.quits == 0, "a failed download can never be run")
	installer.free()

	probe = Probe.new()
	installer = _installer(pem, probe)
	installer.start(TEST_TAG)
	var staged := _stage("original", key)
	_overwrite(_installer_path() + ".part", "replaced")
	_feed(installer, staged)
	_check(installer.state == UpdateInstaller.State.FAILED and not FileAccess.file_exists(_installer_path()), "a download changed after signing fails and is deleted")
	installer.free()

	probe = Probe.new()
	installer = _ready_installer(pem, probe, key)
	_check(installer.state == UpdateInstaller.State.READY, "setup for the swap test is ready")
	_overwrite(_installer_path(), "malware")
	_check(not installer.install_and_restart() and probe.launched.is_empty() and probe.quits == 0, "a file swapped after verification is caught at launch and not run")
	_check(installer.state == UpdateInstaller.State.FAILED, "the swap leaves the installer failed")
	installer.free()

	for case in [[HTTPRequest.RESULT_CANT_CONNECT, 0, 5], [HTTPRequest.RESULT_SUCCESS, 404, 5], [HTTPRequest.RESULT_SUCCESS, 200, 0], [HTTPRequest.RESULT_SUCCESS, 200, UpdateCheck.MAX_SIGNATURE_BYTES + 1]]:
		installer = _installer(pem, Probe.new())
		installer.start(TEST_TAG)
		var body := PackedByteArray()
		body.resize(case[2])
		installer.handle_manifest_signature(case[0], case[1], body)
		_check(installer.state == UpdateInstaller.State.FAILED and installer.requested.size() == 1, "a bad signature reply stops before anything else is requested: %s" % str(case))
		installer.free()

	installer = _installer(pem, Probe.new())
	installer.start(TEST_TAG)
	staged = _stage("x", key)
	installer.handle_manifest_signature(HTTPRequest.RESULT_SUCCESS, 200, staged["sig"])
	installer.handle_manifest(HTTPRequest.RESULT_SUCCESS, 404, staged["manifest"])
	_check(installer.state == UpdateInstaller.State.FAILED and installer.requested.size() == 2, "an HTTP error on the manifest fails before the installer is requested")
	installer.free()

	installer = _installer(pem, Probe.new())
	installer.start(TEST_TAG)
	staged = _stage("x", key)
	installer.handle_manifest_signature(HTTPRequest.RESULT_SUCCESS, 200, staged["sig"])
	installer.handle_manifest(HTTPRequest.RESULT_SUCCESS, 200, staged["manifest"])
	installer.handle_installer(HTTPRequest.RESULT_SUCCESS, 500)
	_check(installer.state == UpdateInstaller.State.FAILED, "an HTTP error on the installer fails")
	installer.free()


## The point of the signed manifest: a genuinely signed but wrong-release manifest never gets the
## installer downloaded, let alone run.
func _test_manifest_rejections(key: CryptoKey, pem: String) -> void:
	# An older release's own signed manifest and installer, served as if they were TEST_TAG.
	var probe := Probe.new()
	var installer := _installer(pem, probe)
	installer.start(TEST_TAG)
	_feed(installer, _stage("old release", key, "v0.2.0"))
	_check(installer.state == UpdateInstaller.State.FAILED and installer.requested.size() == 2, "an older signed release replayed under a newer tag is refused before download")
	_check(not installer.install_and_restart() and probe.launched.is_empty(), "and can never be run")
	installer.free()

	# A manifest for the right version that the running game already has (or is newer than).
	installer = _installer(pem, Probe.new())
	installer.current_version = "0.3.9"
	installer.start(TEST_TAG)
	_feed(installer, _stage("same version", key))
	_check(installer.state == UpdateInstaller.State.FAILED and installer.requested.size() == 2, "a manifest that is not newer than the running game is refused")
	installer.free()

	# An unreadable manifest, even with a signature over exactly those bytes.
	installer = _installer(pem, Probe.new())
	installer.start(TEST_TAG)
	var junk := "not a manifest\n".to_utf8_buffer()
	installer.handle_manifest_signature(HTTPRequest.RESULT_SUCCESS, 200, VerifierTests.sign_bytes(junk, key))
	installer.handle_manifest(HTTPRequest.RESULT_SUCCESS, 200, junk)
	_check(installer.state == UpdateInstaller.State.FAILED and installer.requested.size() == 2, "a signed but malformed manifest is refused")
	installer.free()

	# The signature only covers what it signed: a swapped manifest body under it fails.
	installer = _installer(pem, Probe.new())
	installer.start(TEST_TAG)
	var staged := _stage("a", key)
	var other := _stage("b", key)
	installer.handle_manifest_signature(HTTPRequest.RESULT_SUCCESS, 200, staged["sig"])
	installer.handle_manifest(HTTPRequest.RESULT_SUCCESS, 200, other["manifest"])
	_check(installer.state == UpdateInstaller.State.FAILED and installer.requested.size() == 2, "a manifest that does not match its signature is refused")
	installer.free()


func _test_launch_failures(key: CryptoKey, pem: String) -> void:
	var probe := Probe.new()
	probe.pid = -1
	var installer := _ready_installer(pem, probe, key)
	_check(not installer.install_and_restart() and probe.quits == 0, "if the installer cannot start, the game keeps running")
	_check(installer.state == UpdateInstaller.State.FAILED and installer.error != "", "and says why")
	installer.free()


func _test_start_guards(pem: String) -> void:
	var installer := _installer(pem, Probe.new())
	_check(not installer.start("latest") and installer.state == UpdateInstaller.State.FAILED, "an invalid tag is refused")
	_check(installer.requested.is_empty(), "an invalid tag requests nothing")
	installer.free()
	installer = _installer("", Probe.new())
	_check(not installer.start(TEST_TAG) and installer.requested.is_empty(), "with no signing key built in, nothing is downloaded")
	installer.free()
	installer = _installer(pem, Probe.new())
	installer.start(TEST_TAG)
	_check(not installer.start("v0.4.0") and installer.requested.size() == 1, "a second start while downloading is ignored")
	installer.cancel()
	_check(installer.state == UpdateInstaller.State.IDLE, "cancel returns to idle")
	installer.free()
	_check(not UpdateInstaller.available(), "headless, editor and unsigned runs never self-update")


func _cleanup() -> void:
	var dir := DirAccess.open(_dir)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_dir))
