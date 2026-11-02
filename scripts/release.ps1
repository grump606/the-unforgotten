# One-command release: checks the repo, builds and signs the installer, and (with -Publish) creates the GitHub release.
#   powershell -ExecutionPolicy Bypass -File scripts\release.ps1            # build + sign only
#   powershell -ExecutionPolicy Bypass -File scripts\release.ps1 -Publish   # ...then ask to publish v<version>
# The signing key's path comes from -KeyPath or $env:UPDATE_SIGNING_KEY (a .pfx or .pem; set it once with
# setx UPDATE_SIGNING_KEY "C:\path\signing-private.pfx"). The passphrase is asked for here, kept only in this
# process's environment for the build, and cleared afterwards. See docs/UPDATE_SIGNING.md.
param(
    [string]$KeyPath = $env:UPDATE_SIGNING_KEY,
    [switch]$Publish
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

$files = @("build\TheUnforgotten-Setup-$version.exe", "build\TheUnforgotten-Setup-$version.exe.sha256", "build\TheUnforgotten-Setup-$version.exe.sig")
foreach ($f in $files) { if (-not (Test-Path -LiteralPath $f)) { throw "Missing build output: $f" } }

if (-not $Publish) {
    Write-Host "`nBuilt and signed $tag. To publish:"
    Write-Host "  gh release create $tag $($files -join ' ') --title `"$tag`" --generate-notes"
    return
}
$answer = Read-Host "Publish $tag to GitHub with these 3 files? (type yes)"
if ($answer -ne 'yes') { Write-Host 'Not published.'; return }
gh release create $tag @files --title $tag --generate-notes
if ($LASTEXITCODE -ne 0) { throw 'gh release create failed' }
Write-Host "Published $tag"
