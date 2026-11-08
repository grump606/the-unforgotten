extends RefCounted
## Shared helpers for the update tests (update_verifier_tests.gd, update_installer_tests.gd,
## update_installer_edge_tests.gd, ui_update_notice_test.gd): sign bytes with a generated key and build the
## manifest a release would publish. Not a test suite; test_wiring_tests.gd skips *_support.gd files.


## Signs the SHA-256 of `data` (what scripts/build_installer.ps1 does to the manifest with openssl).
static func sign_bytes(data: PackedByteArray, key: CryptoKey) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(data)
	return Crypto.new().sign(HashingContext.HASH_SHA256, ctx.finish(), key)


## Lowercase hex SHA-256 of the file at `path`.
static func sha256_hex(path: String) -> String:
	return UpdateVerifier.sha256_file(path).hex_encode()


## The signed manifest bytes for the file at `path` as release `tag` would publish them.
static func manifest_for(path: String, tag: String) -> PackedByteArray:
	return UpdateCheck.make_manifest(UpdateCheck.installer_name(tag), tag.trim_prefix("v"), sha256_hex(path)).to_utf8_buffer()
