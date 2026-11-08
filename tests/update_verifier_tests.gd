extends "res://tests/test_base.gd"
## Tests for UpdateVerifier: a detached RSA signature must match the exact bytes it signs and the
## embedded key, and a signed manifest must describe exactly the release being installed. Keys are
## generated in-process; nothing here touches the network or a real key.

var _dir := "user://update_verifier_test_%d" % OS.get_process_id()


const Support := preload("res://tests/update_support.gd")


func run() -> int:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	var crypto := Crypto.new()
	var key := crypto.generate_rsa(2048)
	var other := crypto.generate_rsa(2048)
	var pem := key.save_to_string(true)
	var other_pem := other.save_to_string(true)
	_test_signatures(key, pem, other_pem)
	_test_file_hash()
	_test_manifest(key, pem, other)
	_test_multiple_keys(key, pem, other, other_pem)
	_test_shipped_key()
	_cleanup()
	return _failures


func _test_signatures(key: CryptoKey, pem: String, other_pem: String) -> void:
	var data := "manifest bytes".to_utf8_buffer()
	var sig := Support.sign_bytes(data, key)
	_check(UpdateVerifier.verify_bytes(data, sig, [pem]) == "", "a correct signature verifies")
	_check(UpdateVerifier.verify_bytes(data, sig, [other_pem]) != "", "a signature from another key is rejected")
	_check(UpdateVerifier.verify_bytes("manifest byteX".to_utf8_buffer(), sig, [pem]) != "", "a one-byte change breaks the signature")
	var flipped := sig.duplicate()
	flipped[10] = flipped[10] ^ 1
	_check(UpdateVerifier.verify_bytes(data, flipped, [pem]) != "", "a damaged signature is rejected")
	_check(UpdateVerifier.verify_bytes(data, PackedByteArray(), [pem]) != "", "an empty signature is rejected")
	var huge := PackedByteArray()
	huge.resize(UpdateCheck.MAX_SIGNATURE_BYTES + 1)
	_check(UpdateVerifier.verify_bytes(data, huge, [pem]) != "", "an oversized signature is rejected")
	_check(UpdateVerifier.verify_bytes(data, sig, [""]) != "" and UpdateVerifier.verify_bytes(data, sig, []) != "", "no embedded key means nothing verifies")
	_check(UpdateVerifier.verify_bytes(data, sig, ["   \n"]) != "", "a blank key counts as no key")
	_check(UpdateVerifier.verify_bytes(data, sig, ["not a key"]) != "", "an unreadable key is rejected")
	_check(not UpdateVerifier.is_configured([]) and not UpdateVerifier.is_configured([" "]) and UpdateVerifier.is_configured([pem]), "is_configured reflects whether a key is present")


func _test_file_hash() -> void:
	var path := _dir.path_join("file.bin")
	_write(path, "installer bytes".to_utf8_buffer())
	var good := Support.sha256_hex(path)
	_check(UpdateVerifier.verify_file_hash(path, good) == "", "a file with the promised hash passes")
	_check(UpdateVerifier.verify_file_hash(path, good.replace(good[0], "g")) != "", "a different hash fails")
	_write(path, "installer byteX".to_utf8_buffer())
	_check(UpdateVerifier.verify_file_hash(path, good) != "", "a one-byte change breaks the hash")
	_check(UpdateVerifier.verify_file_hash(_dir.path_join("missing.bin"), good) != "", "a missing file fails")
	# A file bigger than one read chunk still hashes the same way as the signer saw it.
	var big := PackedByteArray()
	big.resize(3 * 1048576 + 17)
	for i in big.size():
		big[i] = i % 251
	var big_path := _dir.path_join("big.bin")
	_write(big_path, big)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(big)
	_check(UpdateVerifier.verify_file_hash(big_path, ctx.finish().hex_encode()) == "", "a multi-chunk file hashes the same")


func _test_manifest(key: CryptoKey, pem: String, other: CryptoKey) -> void:
	var tag := "v0.4.0"
	var current := "0.3.0"
	var name := UpdateCheck.installer_name(tag)
	var sha := "ab".repeat(32)
	var manifest := UpdateCheck.make_manifest(name, "0.4.0", sha).to_utf8_buffer()
	var sig := Support.sign_bytes(manifest, key)
	_check(UpdateVerifier.verify_manifest(manifest, sig, tag, current, [pem]) == "", "a signed manifest for this release verifies")
	_check(UpdateCheck.parse_manifest(manifest) == {"name": name, "version": "0.4.0", "sha256": sha}, "the manifest parses back to its fields")
	_check(UpdateVerifier.verify_manifest(manifest, Support.sign_bytes(manifest, other), tag, current, [pem]) != "", "a manifest signed by another key is rejected")
	_check(UpdateVerifier.verify_manifest(manifest, sig, tag, current, []) != "", "no embedded key rejects every manifest")

	# Replay: a genuinely signed OLD release must not pass as the new one.
	var old_manifest := UpdateCheck.make_manifest(UpdateCheck.installer_name("v0.2.0"), "0.2.0", sha).to_utf8_buffer()
	var old_sig := Support.sign_bytes(old_manifest, key)
	_check(UpdateVerifier.verify_manifest(old_manifest, old_sig, "v0.2.0", current, [pem]) != "", "an older signed release is not newer than the running game")
	_check(UpdateVerifier.verify_manifest(old_manifest, old_sig, tag, current, [pem]) != "", "an old signed manifest replayed under a newer tag is rejected")
	var renamed := UpdateCheck.make_manifest(UpdateCheck.installer_name("v0.4.0"), "0.2.0", sha).to_utf8_buffer()
	_check(UpdateVerifier.verify_manifest(renamed, Support.sign_bytes(renamed, key), tag, current, [pem]) != "", "a signed manifest whose version differs from the tag is rejected")
	var wrong_file := UpdateCheck.make_manifest("Other-Setup-0.4.0.exe", "0.4.0", sha).to_utf8_buffer()
	_check(UpdateVerifier.verify_manifest(wrong_file, Support.sign_bytes(wrong_file, key), tag, current, [pem]) != "", "a signed manifest for a different file name is rejected")
	_check(UpdateVerifier.verify_manifest(manifest, sig, tag, "0.4.0", [pem]) != "", "the same version is not an update")
	_check(UpdateVerifier.verify_manifest(manifest, sig, tag, "", [pem]) != "", "an unknown running version never updates")

	# Format: anything but the exact four lines is malformed, even when signed.
	for bad in [
		"",
		"the-unforgotten-update 2\nname=%s\nversion=0.4.0\nsha256=%s\n" % [name, sha],
		"the-unforgotten-update 1\nname=%s\nversion=0.4.0\nsha256=%s" % [name, sha],
		"the-unforgotten-update 1\r\nname=%s\r\nversion=0.4.0\r\nsha256=%s\r\n" % [name, sha],
		"the-unforgotten-update 1\nname=%s\nversion=v0.4.0\nsha256=%s\n" % [name, sha],
		"the-unforgotten-update 1\nname=%s\nversion=0.4.0\nsha256=%s\n" % [name, sha.to_upper()],
		"the-unforgotten-update 1\nname=%s\nversion=0.4.0\nsha256=%s\n" % [name, "ab".repeat(31)],
		"the-unforgotten-update 1\nname=%s\nversion=0.4.0\nsha256=%s\nextra=1\n" % [name, sha],
		"the-unforgotten-update 1\nversion=0.4.0\nname=%s\nsha256=%s\n" % [name, sha],
	]:
		var bytes: PackedByteArray = bad.to_utf8_buffer()
		_check(UpdateCheck.parse_manifest(bytes).is_empty(), "a malformed manifest does not parse: %s" % bad.c_escape())
		_check(UpdateVerifier.verify_manifest(bytes, Support.sign_bytes(bytes, key), tag, current, [pem]) != "", "a signed but malformed manifest is rejected: %s" % bad.c_escape())
	var oversized := PackedByteArray()
	oversized.resize(UpdateCheck.MAX_MANIFEST_BYTES + 1)
	_check(UpdateCheck.parse_manifest(oversized).is_empty(), "an oversized manifest does not parse")


## Main + backup: a signature from either trusted key is accepted, a stranger's is not, and a key that
## cannot be read neither widens nor breaks the rest of the list.
func _test_multiple_keys(key: CryptoKey, pem: String, other: CryptoKey, other_pem: String) -> void:
	var stranger := Crypto.new().generate_rsa(2048)
	var data := "manifest bytes".to_utf8_buffer()
	var both := [pem, other_pem]
	_check(UpdateVerifier.verify_bytes(data, Support.sign_bytes(data, key), both) == "", "the first trusted key's signature verifies")
	_check(UpdateVerifier.verify_bytes(data, Support.sign_bytes(data, other), both) == "", "the backup key's signature verifies")
	_check(UpdateVerifier.verify_bytes(data, Support.sign_bytes(data, stranger), both) != "", "a signature from neither trusted key is rejected")
	_check(UpdateVerifier.verify_bytes(data, Support.sign_bytes(data, other), [pem]) != "", "a key that is not in the list is not trusted")
	_check(UpdateVerifier.verify_bytes(data, Support.sign_bytes(data, other), ["not a key", other_pem]) == "", "an unreadable entry is skipped, the rest still count")
	_check(UpdateVerifier.verify_bytes(data, Support.sign_bytes(data, stranger), ["not a key", pem]) != "", "an unreadable entry never makes anything verify")
	_check(UpdateVerifier.verify_bytes(data, Support.sign_bytes(data, key), ["not a key"]) != "", "a list of only unreadable keys trusts nothing")
	var manifest := UpdateCheck.make_manifest(UpdateCheck.installer_name("v0.4.0"), "0.4.0", "ab".repeat(32)).to_utf8_buffer()
	_check(UpdateVerifier.verify_manifest(manifest, Support.sign_bytes(manifest, other), "v0.4.0", "0.3.0", both) == "", "a manifest signed by the backup key installs")
	_check(UpdateVerifier.verify_manifest(manifest, Support.sign_bytes(manifest, stranger), "v0.4.0", "0.3.0", both) != "", "a manifest signed by a stranger does not")


func _test_shipped_key() -> void:
	# Every shipped key must be a readable public-only RSA key, or in-game updates would silently never work
	# (or, for the backup, silently not be there when it is needed).
	if not UpdateVerifier.is_configured():
		return   # unsigned releases: no key embedded, in-game install is off
	_check(UpdateVerifier.PUBLIC_KEY_PEMS.size() >= 2, "a main key and an offline backup key are built in")
	var seen := {}
	for pem in UpdateVerifier.PUBLIC_KEY_PEMS:
		var shipped := CryptoKey.new()
		_check(shipped.load_from_string(pem, true) == OK, "each embedded key parses as a public key")
		_check(pem.contains("BEGIN PUBLIC KEY") and not pem.contains("PRIVATE"), "each embedded key is a public key block, never a private one")
		_check(not seen.has(pem.strip_edges()), "the embedded keys are all different")
		seen[pem.strip_edges()] = true


func _write(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func _cleanup() -> void:
	var dir := DirAccess.open(_dir)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_dir))
