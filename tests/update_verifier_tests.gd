extends RefCounted
## Tests for UpdateVerifier: a detached RSA signature must match the exact bytes of the file and the
## embedded key. Keys are generated in-process; nothing here touches the network or a real key.

var _failures := 0
var _dir := "user://update_verifier_test_%d" % OS.get_process_id()


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func run() -> int:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	var crypto := Crypto.new()
	var key := crypto.generate_rsa(2048)
	var other := crypto.generate_rsa(2048)
	var pem := key.save_to_string(true)
	var other_pem := other.save_to_string(true)
	var path := _dir.path_join("file.bin")
	_write(path, "installer bytes".to_utf8_buffer())
	var sig := sign_file(path, key)

	_check(UpdateVerifier.verify_file(path, sig, pem) == "", "a correct signature verifies")
	_check(UpdateVerifier.verify_file(path, sig, other_pem) != "", "a signature from another key is rejected")
	_write(path, "installer byteX".to_utf8_buffer())
	_check(UpdateVerifier.verify_file(path, sig, pem) != "", "a one-byte change breaks the signature")
	_write(path, "installer bytes".to_utf8_buffer())
	_check(UpdateVerifier.verify_file(path, sig, pem) == "", "restoring the bytes verifies again")

	var flipped := sig.duplicate()
	flipped[10] = flipped[10] ^ 1
	_check(UpdateVerifier.verify_file(path, flipped, pem) != "", "a damaged signature is rejected")
	_check(UpdateVerifier.verify_file(path, PackedByteArray(), pem) != "", "an empty signature is rejected")
	var huge := PackedByteArray()
	huge.resize(UpdateCheck.MAX_SIGNATURE_BYTES + 1)
	_check(UpdateVerifier.verify_file(path, huge, pem) != "", "an oversized signature is rejected")
	_check(UpdateVerifier.verify_file(path, sig, "") != "", "no embedded key means nothing verifies")
	_check(UpdateVerifier.verify_file(path, sig, "   \n") != "", "a blank key counts as no key")
	_check(UpdateVerifier.verify_file(path, sig, "not a key") != "", "an unreadable key is rejected")
	_check(UpdateVerifier.verify_file(_dir.path_join("missing.bin"), sig, pem) != "", "a missing file is rejected")
	_check(not UpdateVerifier.is_configured("") and UpdateVerifier.is_configured(pem), "is_configured reflects whether a key is present")

	# A file bigger than one read chunk still hashes the same way as the signer saw it.
	var big := PackedByteArray()
	big.resize(3 * 1048576 + 17)
	for i in big.size():
		big[i] = i % 251
	var big_path := _dir.path_join("big.bin")
	_write(big_path, big)
	_check(UpdateVerifier.verify_file(big_path, sign_file(big_path, key), pem) == "", "a multi-chunk file verifies")

	# The shipped key must be a readable public-only RSA key, or in-game updates would silently never work.
	var shipped := CryptoKey.new()
	if not UpdateVerifier.is_configured():
		_cleanup()
		return _failures   # unsigned releases: no key embedded, in-game install is off
	_check(shipped.load_from_string(UpdateVerifier.PUBLIC_KEY_PEM, true) == OK, "the embedded key parses as a public key")
	_check(UpdateVerifier.PUBLIC_KEY_PEM.contains("BEGIN PUBLIC KEY") and not UpdateVerifier.PUBLIC_KEY_PEM.contains("PRIVATE"), "the embedded key is a public key block, never a private one")
	_cleanup()
	return _failures


## Signs the SHA-256 of the file at `path` (what scripts/build_installer.ps1 does with openssl).
static func sign_file(path: String, key: CryptoKey) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(file.get_buffer(file.get_length()))
	return Crypto.new().sign(HashingContext.HASH_SHA256, ctx.finish(), key)


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
