extends "res://tests/test_base.gd"
## Cross-language signing compatibility: the release signature is made by PowerShell
## (Sign-FileWithPfx in scripts/update_signing.ps1, called from scripts/build_installer.ps1) and verified in
## the game by GDScript (UpdateVerifier). This suite checks a signature the REAL PowerShell signer produced
## against UpdateVerifier, so a .NET/OpenSSL/Godot padding or digest mismatch fails here, not on release day.
##
## How the fixture was made (a throwaway key, never the project's real one; the private key and its .pfx were
## deleted after signing, only the public key and the signature are committed):
##   1. openssl genrsa 3072, a self-signed certificate, and a PKCS#12 bundle (openssl pkcs12 -export, 3DES/SHA1
##      so Windows PowerShell 5.1 can open it) with a throwaway passphrase.
##   2. . scripts\update_signing.ps1; Sign-FileWithPfx -PfxPath <pfx> -Passphrase <pass>
##        -FilePath tests\golden\update_manifest.txt -SigPath tests\golden\update_manifest.txt.sig
##   3. openssl rsa -in <key> -pubout > tests\golden\signing_test_key.pub.txt   (named .txt: *.pem is gitignored)
##   4. openssl dgst -sha256 -verify signing_test_key.pub.txt -signature update_manifest.txt.sig update_manifest.txt
## To regenerate (only if the golden manifest changes), repeat the four steps and commit the two outputs.

const MANIFEST := "res://tests/golden/update_manifest.txt"
const SIGNATURE := "res://tests/golden/update_manifest.txt.sig"
const TEST_KEY := "res://tests/golden/signing_test_key.pub.txt"
## The fixture manifest names this release (see update_manifest_golden_tests.gd).
const TAG := "v1.2.3"


func run() -> int:
	_failures = 0
	var manifest := FileAccess.get_file_as_bytes(MANIFEST)
	var signature := FileAccess.get_file_as_bytes(SIGNATURE)
	var pem := FileAccess.get_file_as_string(TEST_KEY)
	_check(manifest.size() > 0 and signature.size() > 0 and pem != "", "the signing fixture files are present")
	_check(pem.contains("BEGIN PUBLIC KEY") and not pem.contains("PRIVATE"), "the fixture key file is a public key, never a private one")
	_check(signature.size() == 384, "a 3072-bit RSA signature is 384 bytes (got %d)" % signature.size())

	_check(UpdateVerifier.verify_bytes(manifest, signature, [pem]) == "", "the PowerShell signature verifies through UpdateVerifier with the test key")
	_check(UpdateVerifier.verify_manifest(manifest, signature, TAG, "1.0.0", [pem]) == "", "and the signed manifest passes the full release check")
	_check(UpdateVerifier.verify_manifest(manifest, signature, TAG, "1.2.3", [pem]) != "", "a manifest that is not newer than the running game is refused")
	_check(UpdateVerifier.verify_manifest(manifest, signature, "v1.2.4", "1.0.0", [pem]) != "", "a manifest for another tag is refused")

	var changed := manifest.duplicate()
	changed[changed.size() - 2] = changed[changed.size() - 2] ^ 1
	_check(UpdateVerifier.verify_bytes(changed, signature, [pem]) != "", "a one-bit change to the manifest breaks the signature")
	var crlf := FileAccess.get_file_as_string(MANIFEST).replace("\n", "\r\n").to_utf8_buffer()
	_check(UpdateVerifier.verify_bytes(crlf, signature, [pem]) != "", "CRLF line endings would break the signature (the signer and game both use LF)")
	var flipped := signature.duplicate()
	flipped[5] = flipped[5] ^ 1
	_check(UpdateVerifier.verify_bytes(manifest, flipped, [pem]) != "", "a damaged signature is rejected")

	_check(UpdateVerifier.verify_bytes(manifest, signature) != "", "the shipped release keys do NOT trust the throwaway fixture key")
	_check(not UpdateVerifier.PUBLIC_KEY_PEMS.has(pem), "the fixture key is not one of the shipped keys")
	return _failures
