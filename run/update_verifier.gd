class_name UpdateVerifier
extends RefCounted
## Checks a downloaded installer against a detached RSA signature before the game will run it.
## The release publishes `<installer>.sig`: an RSA PKCS#1 v1.5 signature over the installer's
## SHA-256 digest, made offline with the maintainer's private key (scripts/build_installer.ps1,
## docs/UPDATE_SIGNING.md). Only the matching PUBLIC key is embedded here, so a tampered or swapped
## release, or a hijacked GitHub account, cannot produce an update the game will install.
## With no key embedded, verification always fails and in-game install stays off.

## The maintainer's public key (PEM). Empty until docs/UPDATE_SIGNING.md has been followed.
## scripts/build_installer.ps1 reads this constant, so it is the single source.
const PUBLIC_KEY_PEM := """-----BEGIN PUBLIC KEY-----
MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAn1LmsIpyg5XQ6vuVQGu1
4yi3JBSDSfFpu1oyBvTp4xN90Qh0eXQQsDNP/Zgapw4zXuTwyGw5VRz+ph5uQnc4
lFgChAh1TBF7lWn6006FnBvCCe7EDgJR34mlhO3n3LqHE1Tnae5l0IqKHkj+O4Pz
89VpJkCi7x7g6S2bvXeCftAsWzunyJvi8x08edx5cQMyazuc/01Y7Fzhn1UrGPWb
+MEnUC4Xy48pq6nshRC7bDyf55a9c0iCoM/U5OH1V0C+aTnoXUccr7wdeEnf44t0
CrLBNF5qCLD7LtAM4oGlu1um38Bry9zygXt9brIBOl+FRW9bAxrK4i1FXSyApdnI
g1VrTZPg/bVLSitT4At53eA6OuVGuIvFAdJhpYnAGr/4zw7NsebIdQC9EfjzpS3s
Zcc6kVcXfobb4Iitf/oC7TgLDfeDFNCeW7rwF0uHdo7mYsGdBNTh2fK1vCqCbmkN
nmwO9qSQs9x0LnBf9GW4G3719b/FPh+uiWEajdy2stDRVhi6Gal/EbCj8TVcYy49
RJr++E9RU9s8JrbJDpBVpcftJug+0XcB4CMeaKgoEg1vD1eWJskYK5XsXrs9737R
9C1hxbj41MQBQb4CVLsl2ZlgkHAQz3rV4o9+EtsKUuwKUMUNNsonceulHqBlYHDb
vxe8h7jOmyJNmcY1oXoXXJ8CAwEAAQ==
-----END PUBLIC KEY-----
"""


static func is_configured(public_key_pem: String = PUBLIC_KEY_PEM) -> bool:
	return public_key_pem.strip_edges() != ""


## "" when `signature` is a valid signature of the file at `path` by `public_key_pem`'s key; else why not.
static func verify_file(path: String, signature: PackedByteArray, public_key_pem: String = PUBLIC_KEY_PEM) -> String:
	if not is_configured(public_key_pem):
		return "no update signing key is built into this version"
	if signature.is_empty() or signature.size() > UpdateCheck.MAX_SIGNATURE_BYTES:
		return "the signature has an invalid size"
	var key := CryptoKey.new()
	if key.load_from_string(public_key_pem, true) != OK:
		return "the built-in update key could not be read"
	var digest := _sha256_file(path)
	if digest.is_empty():
		return "the downloaded file could not be read"
	var ok := Crypto.new().verify(HashingContext.HASH_SHA256, digest, signature, key)
	return "" if ok else "the signature does not match the download"


## SHA-256 of the file at `path`, streamed so a large file is never held whole; empty on any read error.
static func _sha256_file(path: String) -> PackedByteArray:
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
