# One-command release: runs the full check, confirms CI is green on this commit, builds and signs the installer,
# and (with -Publish) creates the GitHub release as a DRAFT that you review and publish on GitHub.
#   powershell -ExecutionPolicy Bypass -File scripts\release.ps1            # check + build + sign only
#   powershell -ExecutionPolicy Bypass -File scripts\release.ps1 -Publish   # ...then ask to create the draft v<version>
#   add -NoDraft to publish immediately instead of leaving a draft
#   add -ReplaceDraft to delete a half-created draft of the same tag left by an earlier failed upload (asks first)
# The release is pinned to the commit that was built and checked (gh release create --target <sha>). After a draft is
# created, run scripts\verify_release.ps1 -Draft before clicking Publish; after -NoDraft it runs by itself.
# The signing key's path comes from -KeyPath or $env:UPDATE_SIGNING_KEY (a .pfx or .pem; set it once with
# setx UPDATE_SIGNING_KEY "<real path to your key file>", then open a new window). The passphrase is asked for here, kept only in this
# process's environment for the build, and cleared afterwards. See docs/UPDATE_SIGNING.md.
param(
    [string]$KeyPath = $env:UPDATE_SIGNING_KEY,
    [switch]$Publish,
    [switch]$NoDraft,
    [switch]$ReplaceDraft
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
. (Join-Path $PSScriptRoot 'engine_version.ps1')
. (Join-Path $PSScriptRoot 'check_floor_record.ps1')

# Release from a clean, up-to-date main so the tag matches what was built.
$branch = (git branch --show-current).Trim()
if ($branch -ne 'main') { throw "Release from main (currently on '$branch')." }
if (git status --porcelain) { throw 'Working tree is not clean: commit or stash first.' }
git fetch --quiet origin
if ((git rev-parse HEAD) -ne (git rev-parse origin/main)) { throw 'Local main differs from origin/main: pull (or push) first.' }

$version = (Select-String -Path 'project.godot' -Pattern '^config/version="([^"]+)"').Matches.Groups[1].Value
if (-not $version) { throw 'config/version not found in project.godot' }
$presets = Get-Content -Raw -LiteralPath 'export_presets.cfg'
$expected = "$version.0"
foreach ($key in 'application/file_version', 'application/product_version') {
    $m = [regex]::Match($presets, '(?m)^' + [regex]::Escape($key) + '="([^"]*)"')
    if (-not $m.Success) { throw "$key not found in export_presets.cfg" }
    if ($m.Groups[1].Value -ne $expected) {
        throw "Version mismatch: project.godot has config/version=`"$version`" but export_presets.cfg has $key=`"$($m.Groups[1].Value)`" (expected `"$expected`"). Update export_presets.cfg to match."
    }
}
foreach ($key in 'application/short_version', 'application/version') {
    $m = [regex]::Match($presets, '(?m)^' + [regex]::Escape($key) + '="([^"]*)"')
    if (-not $m.Success) { throw "$key (the macOS preset) not found in export_presets.cfg" }
    if ($m.Groups[1].Value -ne $version) {
        throw "Version mismatch: project.godot has config/version=`"$version`" but the macOS preset has $key=`"$($m.Groups[1].Value)`". Update export_presets.cfg to match."
    }
}
$tag = "v$version"
if (git tag --list $tag) { throw "Tag $tag already exists: bump config/version first." }
$listJson = gh release list --limit 200 --json tagName,isDraft
if ($LASTEXITCODE -ne 0) { throw 'gh release list failed: run "gh auth status".' }
$sameTag = @($listJson | ConvertFrom-Json) | ForEach-Object { $_ } | Where-Object { $_.tagName -eq $tag }
$staleDraft = $false
if ($sameTag) {
    if (-not $sameTag.isDraft) { throw "Release $tag is already published on GitHub: bump config/version first." }
    # A draft left by an earlier run whose upload failed halfway (see docs/UPDATE_SIGNING.md, "If a release fails").
    if (-not $ReplaceDraft) { throw "A draft release $tag already exists (probably from a failed upload). Look at it on GitHub, then rerun with -ReplaceDraft to delete it and create a fresh one, or delete it by hand." }
    $staleDraft = $true
}
if (git ls-remote --tags origin "refs/tags/$tag") { throw "The tag $tag already exists on origin: bump config/version first, or delete the stray tag." }

if (-not $KeyPath -or -not (Test-Path -LiteralPath $KeyPath)) {
    $tried = if ($KeyPath) { "'$KeyPath'" } else { '(nothing: $env:UPDATE_SIGNING_KEY is empty)' }
    throw "Signing key not found at $tried. Pass -KeyPath with the real path to the .pfx (or .pem), or fix `$env:UPDATE_SIGNING_KEY (after setx, open a new window)."
}

# Godot: GODOT_EXE / GODOT, the repo-local copy, then common places.
if (-not $env:GODOT_EXE) {
    $candidates = @(
        $env:GODOT,
        (Join-Path $root (Join-Path $GodotFolder $GodotConsole)),
        (Join-Path $env:USERPROFILE (Join-Path 'Downloads' (Join-Path $GodotFolder $GodotConsole))),
        (Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine*" -Filter '*console.exe' -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName)
    )
    $found = $candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
    if (-not $found) { throw 'Godot console exe not found: set $env:GODOT_EXE to it.' }
    $env:GODOT_EXE = $found
}
Write-Host "Releasing $tag with $env:GODOT_EXE"

# Never release a commit that has not passed the full check, both here and on GitHub.
Write-Host 'Running the full check (scripts\check.ps1)...'
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'check.ps1') | Tee-Object -Variable checkOutput
if ($LASTEXITCODE -ne 0) { throw 'scripts\check.ps1 failed: fix it before releasing.' }
# The record behind the check floor must not lag the suite by more than 5% (else the floor protects nothing).
$liveChecks = Get-LiveCheckTotal @($checkOutput | ForEach-Object { "$_" })
$recordedChecks = Get-CheckRecord (Join-Path $root 'tests\golden\min_checks.txt') 'TOTAL_CHECKS'
$recordState = Get-CheckRecordStatus $recordedChecks $liveChecks
if ($recordState -eq 'missing') { throw "Could not read the check totals (live $liveChecks, TOTAL_CHECKS $recordedChecks in tests/golden/min_checks.txt)." }
if ($recordState -eq 'stale') { throw "tests/golden/min_checks.txt records TOTAL_CHECKS=$recordedChecks but the suite ran $liveChecks checks (more than 5% above the record): set TOTAL_CHECKS to $liveChecks, commit and merge, then release." }
$sha = (git rev-parse HEAD).Trim()
$runsJson = gh run list --commit $sha --json status,conclusion,name --limit 20
if ($LASTEXITCODE -ne 0) { throw 'gh run list failed: run "gh auth status".' }
$runs = @($runsJson | ConvertFrom-Json)
if ($runs.Count -eq 0) { throw "No GitHub Actions run found for ${sha}: wait for CI to start on this commit." }
$notGreen = @($runs | Where-Object { $_.status -ne 'completed' -or $_.conclusion -ne 'success' })
if ($notGreen.Count -gt 0) {
    throw "CI is not green on ${sha}: $(($notGreen | ForEach-Object { '{0} ({1}/{2})' -f $_.name, $_.status, $_.conclusion }) -join ', '). Wait for it, or fix it."
}
Write-Host "CI is green on $sha."

$secure = Read-Host 'Signing key passphrase' -AsSecureString
$env:UPDATE_SIGNING_KEY = $KeyPath
$env:UPDATE_SIGNING_PASS = [System.Net.NetworkCredential]::new('', $secure).Password
try {
    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'build_installer.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'build_installer.ps1 failed' }
} finally {
    Remove-Item Env:UPDATE_SIGNING_PASS -ErrorAction SilentlyContinue
    if (-not $PSBoundParameters.ContainsKey('KeyPath') -and -not [Environment]::GetEnvironmentVariable('UPDATE_SIGNING_KEY', 'User')) {
        Remove-Item Env:UPDATE_SIGNING_KEY -ErrorAction SilentlyContinue
    }
}

$files = @("build\TheUnforgotten-Setup-$version.exe", "build\TheUnforgotten-Setup-$version.exe.sha256", "build\TheUnforgotten-Setup-$version.exe.manifest", "build\TheUnforgotten-Setup-$version.exe.manifest.sig")
foreach ($f in $files) { if (-not (Test-Path -LiteralPath $f)) { throw "Missing build output: $f" } }

$installerBytes = (Get-Item -LiteralPath $files[0]).Length
$newCapMatch = Select-String -Path 'run/update_check.gd' -Pattern '^const MAX_INSTALLER_BYTES := (\d+) \* 1024 \* 1024'
$newCapMiB = [int64]$newCapMatch.Matches.Groups[1].Value
$installerMiB = [math]::Round($installerBytes / 1MB, 1)
Write-Host "Installer is $installerMiB MiB: margin $([math]::Round($newCapMiB - $installerMiB, 1)) MiB to the in-game download cap of $newCapMiB MiB."
Write-Host "Installer size: $installerBytes bytes. Put this number in tests/golden/latest_installer_size.txt in the next commit (a test keeps the in-game download cap at least 1.5x of it)."

if (-not $Publish) {
    Write-Host "`nBuilt and signed $tag. To publish:"
    Write-Host "  gh release create $tag $($files -join ' ') --title `"$tag`" --generate-notes --draft"
    return
}
$what = if ($NoDraft) { 'PUBLISH' } else { 'create a draft of' }
$answer = Read-Host "$what $tag on GitHub with these $($files.Count) files? (type yes)"
if ($answer -ne 'yes') { Write-Host 'Not published.'; return }
if ($staleDraft) {
    $answer = Read-Host "Delete the existing DRAFT $tag (and its uploaded files) first? (type yes)"
    if ($answer -ne 'yes') { Write-Host 'Draft kept, nothing published.'; return }
    gh release delete $tag --yes
    if ($LASTEXITCODE -ne 0) { throw "gh release delete $tag failed" }
}
# Build the extra flags with += : a one-item array returned from an `if` expression is unrolled into a plain
# string, and splatting a string passes its characters one by one ("- - d r a f t").
$extra = @()
if (-not $NoDraft) { $extra += '--draft' }
# --target pins the tag to the commit that was checked and built, not whatever the default branch is by the time
# the release is published.
gh release create $tag @files --title $tag --generate-notes --target $sha @extra
if ($LASTEXITCODE -ne 0) { throw "gh release create failed. If it left a half-created draft, rerun with -ReplaceDraft (docs/UPDATE_SIGNING.md)." }
if ($NoDraft) {
    Write-Host "Published $tag; verifying what GitHub serves..."
    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'verify_release.ps1') -Version $version
    if ($LASTEXITCODE -ne 0) { throw "verify_release.ps1 FAILED for the published ${tag}: take the release down (gh release edit $tag --draft) and investigate." }
} else {
    Write-Host "Created the draft ${tag}: run   powershell -ExecutionPolicy Bypass -File scripts\verify_release.ps1 -Version $version -Draft   then review it on GitHub and click Publish release. Players only see it once it is published."
}
