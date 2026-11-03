class_name UpdateVerifier
extends RefCounted
## Checks a downloaded installer against a signed manifest before the game will run it.
## The release publishes `<installer>.manifest` (name, version, installer SHA-256: UpdateCheck.
## parse_manifest) and `<installer>.manifest.sig`: an RSA PKCS#1 v1.5 signature over the manifest's
## SHA-256 digest, made offline with the maintainer's private key (scripts/build_installer.ps1,
## docs/UPDATE_SIGNING.md). (Builds up to v0.6.1 read a bare-installer `<installer>.sig`; releases from v0.6.5
## no longer publish it.) Only matching PUBLIC keys are embedded
## here, so a tampered or swapped release, or a hijacked GitHub account, cannot produce an update the
## game will install. With no key embedded, verification always fails and in-game install stays off.

## The maintainer's trusted public keys (PEM, RSA-3072, from SigningKeyMaker's signing-public.pem
## certificates). A signature from ANY of them is accepted. Releases are signed with the first (main)
## key; the second is an offline backup, used only if the main key is lost or leaked (docs/UPDATE_SIGNING.md,
## "If the key is lost or exposed"). Installs only trust the keys built into their own version, so a
## key added here protects that version and later ones. scripts/build_installer.ps1 reads this list,
## so it is the single source.
const PUBLIC_KEY_PEMS: Array[String] = [
"""-----BEGIN PUBLIC KEY-----
MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEAlIK0Hy72xKQzljq1CTtR
q6Xx+oRFe9VVUkWuAfnRwXbEnCAAEuQJSi+o8yOTRsa8Zkxf3Z8UfqyDbNDmMCao
wGmTHFCTKQ/yDCAEOGvIO8kxB6dRia7PvkTKCKuQqzqJtTDhdDN50yPAGLMwK5O3
dMoogVVKjqCJusudo8zEzNAQWR8tGC7bUK9kXAPHG2o56kru74q5ll9EOC3Owq6d
syeBk3yW2WcY7teH3Yp27w4g+OI1nCNQvE7XiotdFfRS4Y7likuW2Sc9P0lAQOnK
tb09k7vOh56IYWp9FfBpL8yhkWKLmFOf463h3LCc5S9TRO6/0L8MCM1VPuTvHsQd
5BkHS/FZEV/uleZobrc+NsRtR1g1hKgwYQ9oFA9y13RuVEz28CMa5IRYtQZF+Ofz
GkKw4HuoCZiM764kD6siCSsMJws40chf1OWH5cuWIck6uTCjBN3WIhS8h31y7HZf
00LNFjtsrAh6u46io2hcRC0Nm0Skye7J2RyYmy0SRBzlAgMBAAE=
-----END PUBLIC KEY-----
""",
"""-----BEGIN PUBLIC KEY-----
MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEAvoi13XeFPGgij4Q1bbr1
AJ2EHjuGtXW5nh0LN+QUAglzB4pPaPjdf7NgrVfS/wlgNtft+bNN/14lgZIdZkhC
mFIN57cqiwJKdEZv2/xjkd5SIl5hnXqhZrxlSq+pI82kRYIPlsJBSGuno2clO4oU
+ukqE37tkYCyQ5zlaJ9GBmRdNSnOSNlzk7Yxj3lJBFMVls894SP+0QvArOZktQnC
R8TXZ+bgjFnXCjZDQMDN0AAkhtHUTgtfnv2qGGml6Kg0FWJHX657mbffjxhsZXmx
xuU439NWM9Y1sM4KNjGZCCc5iCy652ChVOuDVSDQoumm5pL/7RB49aQsri0XDHWV
X5y0ayIP/WrA0RrKiq4ntM/eA51RMhdauV4iRJTj74htfa1XYQcnmf9g8zst9gA1
HA53eHOrSte5suCcd1FFDR6cjayx8FIytNsu3/cPOR9wKNym04afTcBGkha2lfau
8Ot4kjEA3easvRLPJigpYnsuD8EQpazlt8blRHZQ5yjJAgMBAAE=
-----END PUBLIC KEY-----
""",
]


## True when at least one non-blank key is present.
static func is_configured(public_key_pems: Array = PUBLIC_KEY_PEMS) -> bool:
	for pem in public_key_pems:
		if String(pem).strip_edges() != "":
			return true
	return false


## "" when signature is a valid signature of data by ANY of public_key_pems; else why not.
## A key that cannot be parsed is skipped (the others still count), so one bad entry cannot
## widen what is trusted.
static func verify_bytes(data: PackedByteArray, signature: PackedByteArray, public_key_pems: Array = PUBLIC_KEY_PEMS) -> String:
	if not is_configured(public_key_pems):
		return "no update signing key is built into this version"
	if signature.is_empty() or signature.size() > UpdateCheck.MAX_SIGNATURE_BYTES:
		return "the signature has an invalid size"
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(data)
	var digest := ctx.finish()
	var readable := 0
	for pem in public_key_pems:
		if String(pem).strip_edges() == "":
			continue
		var key := CryptoKey.new()
		if key.load_from_string(String(pem), true) != OK:
			continue
		readable += 1
		if Crypto.new().verify(HashingContext.HASH_SHA256, digest, signature, key):
			return ""
	if readable == 0:
		return "the built-in update key could not be read"
	return "the signature does not match"

## "" when `manifest` is genuinely signed AND describes exactly this release: the file name for `tag`,
## the same version as `tag`, and a version newer than `current_version`. Checking the signed
## version and name is what stops a validly signed older installer being replayed as an update.
static func verify_manifest(manifest: PackedByteArray, signature: PackedByteArray, tag: String, current_version: String, public_key_pems: Array = PUBLIC_KEY_PEMS) -> String:
	var why := verify_bytes(manifest, signature, public_key_pems)
	if why != "":
		return why
	var fields := UpdateCheck.parse_manifest(manifest)
	if fields.is_empty():
		return "the update manifest is malformed"
	if fields["name"] != UpdateCheck.installer_name(tag):
		return "the manifest is for a different file"
	if UpdateCheck.parse_version(fields["version"]) != UpdateCheck.parse_version(tag):
		return "the manifest is for a different version"
	if not UpdateCheck.is_newer(fields["version"], current_version):
		return "the manifest is not for a newer version"
	return ""


## "" when the file at `path` has SHA-256 `expected_hex` (lowercase); else why not.
static func verify_file_hash(path: String, expected_hex: String) -> String:
	var digest := sha256_file(path)
	if digest.is_empty():
		return "the downloaded file could not be read"
	return "" if digest.hex_encode() == expected_hex else "the download does not match the signed hash"


## SHA-256 of the file at `path`, streamed so a large file is never held whole; empty on any read error.
static func sha256_file(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	while not file.eof_reached():
		var chunk := file.get_buffer(1048576)
		if chunk.size() > 0:
			ctx.update(chunk)
	if file.get_error() != OK and file.get_error() != ERR_FILE_EOF:
		return PackedByteArray()
	return ctx.finish()
