# Update signing (one-time setup and every release)

The game installs updates itself (see `docs/UPDATE_CHECK.md`), but only an installer that carries a
valid signature from **your** private key. The game contains just the public key, so nobody who
gains access to the GitHub repo or a release can make players install something else. This is a
separate mechanism from Windows code signing (Authenticode), which this project does not use.

Until a public key is built in, the game does **not** install updates itself: the notice keeps its
plain Download button.

> **Status (v0.5.0): signing is switched off.** `PUBLIC_KEY_PEM` in `run/update_verifier.gd` is empty, so releases carry no `.sig`, the build script writes none, and the in-game updater only offers the download page. To turn it back on, create a key below and put its public half back in that constant. Older installs (v0.4.0 and earlier) still hold the old public key and will not auto-install an unsigned release.

## One-time setup

The easy way: open a normal **Windows PowerShell window** (Start menu, not an editor or assistant
prompt) and run

```powershell
powershell -ExecutionPolicy Bypass -File D:\Projects\card-battle-prototype\scripts\make_signing_key.ps1
```

It creates the pair in `%TEMP%\signing`, tests that a signature made with the private key verifies
with the public one, and prints a random passphrase once for you to save (add `-Prompt` to type your
own instead). Then continue at step 3 below.

To do it by hand instead, run these in PowerShell or Git Bash (OpenSSL ships with Git for Windows in
`C:\Program Files\Git\usr\bin`), in a temporary folder, not in the repo.

```powershell
mkdir $env:TEMP\signing; cd $env:TEMP\signing
$openssl = "C:\Program Files\Git\usr\bin\openssl.exe"

# The passphrase is passed through an environment variable of this window only: the OpenSSL that
# ships with Git often cannot read its own hidden prompt from PowerShell.
$s = Read-Host "Choose a passphrase" -AsSecureString
$env:KEYPASS = [System.Net.NetworkCredential]::new('', $s).Password

# 1. Create a passphrase-protected 4096-bit RSA key.
& $openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -aes-256-cbc -pass env:KEYPASS -out update_signing_private.pem

# 2. Derive the public key.
& $openssl pkey -in update_signing_private.pem -passin env:KEYPASS -pubout -out update_signing_public.pem

Remove-Item Env:KEYPASS
```

(In Git Bash the plain commands work and prompt for the passphrase: drop the `-pass`/`-passin` options.)

3. **Store the private key in your password manager**: attach `update_signing_private.pem` to a
   secure note and keep the passphrase in the same entry (or a separate one). Make a second copy of
   the encrypted file somewhere offline, such as a USB stick in a drawer. Then delete the
   `update_signing_private.pem` file from the temporary folder. **Never commit it, and never paste it
   into a chat or issue.**
4. The public key is not secret. Put it in `run/update_verifier.gd` as the value of
   `PUBLIC_KEY_PEM` (the whole `-----BEGIN PUBLIC KEY-----` ... `-----END PUBLIC KEY-----` block, as a
   `"""` multi-line string), commit it and release a version that contains it. Installs older than
   that version have no key, so they update once by the normal download; after that updates are
   in-game.

## Every release

1. Take `update_signing_private.pem` out of the password manager into a temporary folder.
2. In PowerShell:

```powershell
$env:UPDATE_SIGNING_KEY = 'C:\path\to\update_signing_private.pem'
$s = Read-Host "Key passphrase" -AsSecureString
$env:UPDATE_SIGNING_PASS = [System.Net.NetworkCredential]::new('', $s).Password
powershell -File scripts\build_installer.ps1
```

   If `UPDATE_SIGNING_PASS` is not set, OpenSSL asks for the passphrase itself, which works in Git Bash
   but not in every PowerShell host.

   The script exports the game, builds the installer, writes `.sha256`, signs the installer's
   SHA-256 into `.sig`, and checks the signature against the public key in `run/update_verifier.gd`
   before finishing. It refuses to start if a public key is built in but `UPDATE_SIGNING_KEY` is
   missing.
3. Delete the temporary private key file and clear the variables (`Remove-Item Env:UPDATE_SIGNING_KEY, Env:UPDATE_SIGNING_PASS`).
4. Publish all three files in the release (the `.sig` is what the game downloads):

```powershell
gh release create v<version> build\CardBattlePrototype-Setup-<version>.exe build\CardBattlePrototype-Setup-<version>.exe.sha256 build\CardBattlePrototype-Setup-<version>.exe.sig
```

A release without the `.sig` is simply not installable in-game: the update fails with a message and
the bar falls back to the Download button.

## If the key is lost or exposed

- **Lost** (no copy left): installed games cannot verify anything signed by a new key. Generate a new
  key, embed its public half, release it, and tell players to reinstall once by hand from the
  releases page.
- **Exposed**: treat it the same way. Anyone holding the key and the passphrase can sign an update
  that every install will accept, so rotate immediately and reinstall by hand.
