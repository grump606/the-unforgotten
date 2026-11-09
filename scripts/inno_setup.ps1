# Finds the Inno Setup compiler for scripts/build_installer.ps1. Dot-source it. Kept apart so
# scripts/inno_setup_test.ps1 can test the choice with a fake list of folders.
# installer/setup.iss is written for Inno Setup 6 (CI refuses any other major version too), so only a 6.x install
# is used; a newer major version is reported by name instead of being run against a script it may not understand.

# The compiler exe carries no version resource (0.0.0.0); the uninstaller in the same folder carries the product
# version, with the folder name ("Inno Setup 6") as the fallback.
function Get-InnoFolderVersion([string]$folder) {
    $unins = Join-Path $folder 'unins000.exe'
    $text = if (Test-Path -LiteralPath $unins) { [string](Get-Item -LiteralPath $unins).VersionInfo.ProductVersion } else { '' }
    if ($text -notmatch '^\d+(\.\d+)*') { $text = (Split-Path -Leaf $folder) -replace '[^0-9.]', '' }
    $text = $text.Trim('.')
    if ($text -notmatch '\.') { $text = "$text.0" }  # [version] needs at least major.minor: "6" alone does not parse
    try { return [version]$text } catch { return [version]'0.0' }
}

# Every "Inno Setup*" folder under $roots that holds ISCC.exe, as {Folder, Version}.
function Get-InnoCandidates([string[]]$roots) {
    $found = @()
    foreach ($r in $roots) {
        if (-not $r -or -not (Test-Path -LiteralPath $r)) { continue }
        foreach ($d in Get-ChildItem -LiteralPath $r -Directory -Filter 'Inno Setup*' -ErrorAction SilentlyContinue) {
            if (Test-Path -LiteralPath (Join-Path $d.FullName 'ISCC.exe')) { $found += [pscustomobject]@{ Folder = $d.FullName; Version = (Get-InnoFolderVersion $d.FullName) } }
        }
    }
    return $found
}

# The newest 6.x of the candidates ({Folder, Version}). Throws, naming what was found, when there is none.
function Select-InnoSetup($candidates, [string]$pinned = '') {
    $all = @($candidates)
    if ($all.Count -eq 0) { throw "Inno Setup (ISCC.exe) not found. Install the pinned version: winget install JRSoftware.InnoSetup --version $pinned" }
    $six = @($all | Where-Object { $_.Version.Major -eq 6 } | Sort-Object Version -Descending)
    if ($six.Count -eq 0) {
        $seen = ($all | ForEach-Object { "$($_.Version) ($($_.Folder))" }) -join ', '
        throw "Inno Setup 6 is required (installer/setup.iss is written for it), but only found: $seen. Install the pinned version: winget install JRSoftware.InnoSetup --version $pinned"
    }
    return $six[0]
}
