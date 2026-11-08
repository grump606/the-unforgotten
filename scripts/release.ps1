# One-command release: runs the full check, confirms CI is green on this commit, builds and signs the installer,
# and (with -Publish) creates the GitHub release as a DRAFT that you review and publish on GitHub.
#   powershell -ExecutionPolicy Bypass -File scripts\release.ps1            # check + build + sign only
#   powershell -ExecutionPolicy Bypass -File scripts\release.ps1 -Publish   # ...then ask to create the draft v<version>
#   add -NoDraft to publish immediately instead of leaving a draft
# The signing key's path comes from -KeyPath or $env:UPDATE_SIGNING_KEY (a .pfx or .pem; set it once with
# setx UPDATE_SIGNING_KEY "C:\path\signing-private.pfx"). The passphrase is asked for here, kept only in this
# process's environment for the build, and cleared afterwards. See docs/UPDATE_SIGNING.md.
param(
    [string]$KeyPath = $env:UPDATE_SIGNING_KEY,
    [switch]$Publish,
    [switch]$NoDraft
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

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
$existing = @(gh release list --limit 200 --json tagName --jq '.[].tagName')
if ($LASTEXITCODE -ne 0) { throw 'gh release list failed: run "gh auth status".' }
if ($existing -contains $tag) { throw "Release $tag already exists on GitHub: bump config/version first." }

if (-not $KeyPath -or -not (Test-Path -LiteralPath $KeyPath)) {
    throw 'Signing key not found. Pass -KeyPath or set $env:UPDATE_SIGNING_KEY to the .pfx (or .pem) path.'
}

# Godot: GODOT_EXE / GODOT, the repo-local copy, then common places.
if (-not $env:GODOT_EXE) {
    $candidates = @(
        $env:GODOT,
        (Join-Path $root 'Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'),
        (Join-Path $env:USERPROFILE 'Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'),
        (Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine*" -Filter '*console.exe' -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName)
    )
    $found = $candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
    if (-not $found) { throw 'Godot console exe not found: set $env:GODOT_EXE to it.' }
    $env:GODOT_EXE = $found
}
Write-Host "Releasing $tag with $env:GODOT_EXE"

# Never release a commit that has not passed the full check, both here and on GitHub.
Write-Host 'Running the full check (scripts\check.ps1)...'
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'check.ps1')
if ($LASTEXITCODE -ne 0) { throw 'scripts\check.ps1 failed: fix it before releasing.' }
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

if (-not $Publish) {
    Write-Host "`nBuilt and signed $tag. To publish:"
    Write-Host "  gh release create $tag $($files -join ' ') --title `"$tag`" --generate-notes --draft"
    return
}
$what = if ($NoDraft) { 'PUBLISH' } else { 'create a draft of' }
$answer = Read-Host "$what $tag on GitHub with these $($files.Count) files? (type yes)"
if ($answer -ne 'yes') { Write-Host 'Not published.'; return }
$extra = if ($NoDraft) { @() } else { @('--draft') }
gh release create $tag @files --title $tag --generate-notes @extra
if ($LASTEXITCODE -ne 0) { throw 'gh release create failed' }
if ($NoDraft) { Write-Host "Published $tag" } else { Write-Host "Created the draft ${tag}: review it on GitHub, then click Publish release. Players only see it once it is published." }
