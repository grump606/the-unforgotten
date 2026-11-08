# Verifies a published (or draft) release the way a player's game would, from what GitHub actually serves:
# downloads the four assets, recomputes the installer's SHA-256, checks the .sha256 file and the signed manifest
# against it, checks the manifest's exact bytes, and verifies the .manifest.sig against the public keys built into
# run/update_verifier.gd with OpenSSL (the same check build_installer.ps1 does). Prints PASS or FAIL per check and
# exits 1 if anything failed. It signs nothing and needs no key.
#
#   powershell -ExecutionPolicy Bypass -File scripts\verify_release.ps1                 # the version in project.godot
#   powershell -ExecutionPolicy Bypass -File scripts\verify_release.ps1 -Version 0.8.3  # a specific version
#   ...verify_release.ps1 -Version 0.8.3 -Draft    # a draft: run this BEFORE clicking Publish release (needs gh auth)
#   ...verify_release.ps1 -LocalDir build          # check files already on disk (no download): used by tests and by hand
# -PublicKeyPath overrides the embedded keys with one PEM file (only for testing against a fixture key).
# See docs/UPDATE_SIGNING.md.
param(
    [string]$Version,
    [switch]$Draft,
    [string]$LocalDir,
    [string]$PublicKeyPath,
    [string]$Repo = 'grump606/the-unforgotten'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'update_signing.ps1')

if (-not $Version) {
    $Version = (Select-String -Path (Join-Path $root 'project.godot') -Pattern '^config/version="([^"]+)"').Matches.Groups[1].Value
    if (-not $Version) { throw 'config/version not found in project.godot' }
}
$Version = $Version.TrimStart('v')
$tag = "v$Version"
$name = "TheUnforgotten-Setup-$Version.exe"
$assets = @($name, "$name.sha256", "$name.manifest", "$name.manifest.sig")

$script:failed = 0
function Report([bool]$ok, [string]$what, [string]$detail = '') {
    $line = if ($ok) { "PASS  $what" } else { "FAIL  $what" }
    if ($detail) { $line += " ($detail)" }
    Write-Host $line
    if (-not $ok) { $script:failed++ }
}

# Where the files come from.
$cleanup = $null
if ($LocalDir) {
    $dir = (Resolve-Path -LiteralPath $LocalDir).ProviderPath
} else {
    $dir = Join-Path ([IO.Path]::GetTempPath()) "verify_release_${PID}"
    New-Item -ItemType Directory -Force $dir | Out-Null
    $cleanup = $dir
    Write-Host "Downloading $tag$(if ($Draft) { ' (draft)' }) from $Repo ..."
    # gh finds a published release by tag. A draft has no tag yet, so it is looked up in the release list and its
    # assets are fetched through the API by id.
    $fetched = $false
    if (-not $Draft) {
        $patterns = @()
        foreach ($a in $assets) { $patterns += '--pattern'; $patterns += $a }
        gh release download $tag --repo $Repo --dir $dir --clobber @patterns
        $fetched = ($LASTEXITCODE -eq 0)
    }
    if (-not $fetched) {
        $json = gh api "repos/$Repo/releases?per_page=100" --paginate
        if ($LASTEXITCODE -ne 0) { throw 'gh api failed: run "gh auth status".' }
        $release = @($json | ConvertFrom-Json) | ForEach-Object { $_ } | Where-Object { $_.tag_name -eq $tag } | Select-Object -First 1
        if (-not $release) { throw "No release with the tag $tag found on $Repo (draft or published)." }
        Write-Host "Release $tag found (draft: $($release.draft))."
        foreach ($a in $assets) {
            $asset = @($release.assets) | Where-Object { $_.name -eq $a } | Select-Object -First 1
            if (-not $asset) { continue }
            # curl.exe (in Windows 10+) keeps the bytes intact; PowerShell 5.1's `>` would re-encode a binary as text.
            $token = (gh auth token).Trim()
            curl.exe --silent --show-error --fail --location -H "Authorization: Bearer $token" -H 'Accept: application/octet-stream' -o (Join-Path $dir $a) "https://api.github.com/repos/$Repo/releases/assets/$($asset.id)"
            if ($LASTEXITCODE -ne 0) { throw "Could not download $a" }
        }
    }
}

try {
    # 1. All four files are there and not empty.
    foreach ($a in $assets) {
        $p = Join-Path $dir $a
        Report ((Test-Path -LiteralPath $p) -and (Get-Item -LiteralPath $p).Length -gt 0) "asset present: $a"
    }
    if ($script:failed -gt 0) {
        Write-Host "VERIFY FAILED: assets are missing for $tag, so nothing more can be checked."
        exit 1
    }
    $setup = Join-Path $dir $name
    $sumFile = "$setup.sha256"
    $manifestFile = "$setup.manifest"
    $sigFile = "$setup.manifest.sig"

    # 2. The installer's real SHA-256 against the .sha256 file and against the manifest.
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $setup).Hash.ToLowerInvariant()
    $sumText = (Get-Content -Raw -LiteralPath $sumFile).Trim()
    $sumParts = $sumText -split '\s+'
    Report ($sumParts[0] -eq $actual -and $sumParts.Count -ge 2 -and $sumParts[-1] -eq $name) "installer SHA-256 equals the .sha256 file" $actual
    $manifestBytes = [System.IO.File]::ReadAllBytes($manifestFile)
    $manifestText = (New-Object System.Text.UTF8Encoding($false)).GetString($manifestBytes)
    $fields = @{}
    foreach ($line in ($manifestText -split "`n")) {
        if ($line -match '^(name|version|sha256)=(.*)$') { $fields[$Matches[1]] = $Matches[2] }
    }
    Report ($fields['sha256'] -eq $actual) 'installer SHA-256 equals the signed manifest' $fields['sha256']

    # 3. The manifest names this release and is byte-for-byte what the signer writes (LF, no BOM, trailing LF).
    Report ($fields['name'] -eq $name -and $fields['version'] -eq $Version) "manifest names $name and version $Version"
    $expected = (New-Object System.Text.UTF8Encoding($false)).GetBytes((New-UpdateManifestText -Name $name -Version $Version -Sha256 $actual))
    $same = $expected.Length -eq $manifestBytes.Length
    if ($same) { for ($i = 0; $i -lt $expected.Length; $i++) { if ($expected[$i] -ne $manifestBytes[$i]) { $same = $false; break } } }
    Report $same 'manifest bytes are exactly the canonical text (LF, no BOM)'

    # 4. The signature verifies against a key the game trusts.
    $openssl = Get-OpenSslPath
    if (-not $openssl) { throw 'openssl not found (it ships with Git for Windows: Program Files\Git\usr\bin).' }
    $pems = if ($PublicKeyPath) { @((Get-Content -Raw -LiteralPath $PublicKeyPath).Trim() -replace "`r", '') } else { @(Get-EmbeddedPublicKeyPems) }
    if ($pems.Count -eq 0) { throw 'No public keys found to verify against.' }
    $matched = Find-MatchingPublicKey -OpenSsl $openssl -PublicPems $pems -FilePath $manifestFile -SigPath $sigFile
    $source = if ($PublicKeyPath) { "key file $PublicKeyPath" } else { "embedded key #$($matched + 1) of $($pems.Count) in run/update_verifier.gd" }
    Report ($matched -ge 0) 'manifest signature verifies' $(if ($matched -ge 0) { $source } else { "none of the $($pems.Count) trusted keys matches" })
} finally {
    if ($cleanup) { Remove-Item -Recurse -Force -LiteralPath $cleanup -ErrorAction SilentlyContinue }
}

if ($script:failed -gt 0) {
    Write-Host "VERIFY FAILED: $($script:failed) check(s) failed for $tag."
    exit 1
}
Write-Host "VERIFY PASSED: $tag"
exit 0
