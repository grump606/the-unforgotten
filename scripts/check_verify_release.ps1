# Tests scripts/verify_release.ps1 offline with the committed signing fixture (tests/golden): a throwaway key
# signed tests/golden/update_manifest.txt (see tests/signing_compat_tests.gd). The fixture installer is the three
# bytes "abc", whose SHA-256 is the one in the golden manifest. A good set must pass; damaging any one file must fail.
# Run alone: powershell -ExecutionPolicy Bypass -File scripts\check_verify_release.ps1   (exit 0 = all as expected)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$golden = Join-Path $root 'tests\golden'
$verify = Join-Path $PSScriptRoot 'verify_release.ps1'
$name = 'TheUnforgotten-Setup-1.2.3.exe'
$hash = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
$lf = New-Object System.Text.UTF8Encoding($false)
$problems = 0

function New-Fixture {
    $dir = Join-Path ([IO.Path]::GetTempPath()) "verify_fixture_${PID}_$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    New-Item -ItemType Directory -Force $dir | Out-Null
    [System.IO.File]::WriteAllBytes((Join-Path $dir $name), $lf.GetBytes('abc'))
    [System.IO.File]::WriteAllText((Join-Path $dir "$name.sha256"), "$hash  $name`n", $lf)
    Copy-Item (Join-Path $golden 'update_manifest.txt') (Join-Path $dir "$name.manifest")
    Copy-Item (Join-Path $golden 'update_manifest.txt.sig') (Join-Path $dir "$name.manifest.sig")
    return $dir
}

function Invoke-Verify([string]$dir, [string]$pub = (Join-Path $golden 'signing_test_key.pub.txt')) {
    $out = powershell -NoProfile -ExecutionPolicy Bypass -File $verify -Version 1.2.3 -LocalDir $dir -PublicKeyPath $pub
    return @{ Code = $LASTEXITCODE; Out = ($out -join "`n") }
}

function Expect([bool]$condition, [string]$what) {
    if ($condition) { Write-Host "ok   $what" } else { Write-Host "FAIL $what"; $script:problems++ }
}

$dir = New-Fixture
try {
    $r = Invoke-Verify $dir
    Expect ($r.Code -eq 0 -and $r.Out -match 'VERIFY PASSED') 'a good release passes'
    Expect (([regex]::Matches($r.Out, '(?m)^PASS ')).Count -ge 8) 'and prints a PASS line per check'

    # Wrong key: the signature must not verify against the shipped keys (the fixture key is not one of them).
    $r = powershell -NoProfile -ExecutionPolicy Bypass -File $verify -Version 1.2.3 -LocalDir $dir
    Expect ($LASTEXITCODE -eq 1 -and ($r -join "`n") -match 'FAIL\s+manifest signature verifies') 'the shipped keys do not accept the fixture signature'
} finally { Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }

$damage = @{
    'a changed installer'         = { param($d) [System.IO.File]::WriteAllBytes((Join-Path $d $name), $lf.GetBytes('abd')) }
    'a wrong .sha256 file'        = { param($d) [System.IO.File]::WriteAllText((Join-Path $d "$name.sha256"), ('0' * 64) + "  $name`n", $lf) }
    'a changed manifest'          = { param($d) [System.IO.File]::WriteAllText((Join-Path $d "$name.manifest"), (([System.IO.File]::ReadAllText((Join-Path $d "$name.manifest"))).Replace('1.2.3', '1.2.4')), $lf) }
    'a manifest with CRLF endings' = { param($d) [System.IO.File]::WriteAllText((Join-Path $d "$name.manifest"), (([System.IO.File]::ReadAllText((Join-Path $d "$name.manifest"))).Replace("`n", "`r`n")), $lf) }
    'a damaged signature'         = { param($d) $p = Join-Path $d "$name.manifest.sig"; $b = [System.IO.File]::ReadAllBytes($p); $b[7] = $b[7] -bxor 1; [System.IO.File]::WriteAllBytes($p, $b) }
    'a missing signature'         = { param($d) Remove-Item (Join-Path $d "$name.manifest.sig") }
    'an empty manifest'           = { param($d) [System.IO.File]::WriteAllBytes((Join-Path $d "$name.manifest"), [byte[]]@()) }
}
foreach ($case in $damage.GetEnumerator()) {
    $dir = New-Fixture
    try {
        & $case.Value $dir
        $r = Invoke-Verify $dir
        Expect ($r.Code -ne 0 -and $r.Out -notmatch 'VERIFY PASSED') "$($case.Key) fails"
    } finally { Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
}

if ($problems -gt 0) { Write-Host "verify_release self-test: $problems problem(s)"; exit 1 }
Write-Host 'verify_release self-test OK'
exit 0
