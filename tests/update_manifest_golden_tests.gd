extends "res://tests/test_base.gd"
## The update manifest is written by PowerShell (New-UpdateManifestText in scripts/update_signing.ps1, used
## by scripts/build_installer.ps1) and read and checked by GDScript (UpdateCheck). The two must agree byte for
## byte or every signature fails. tests/golden/update_manifest.txt holds the expected bytes for a fixed input.
## This file checks the GDScript side; scripts/check.ps1 runs scripts/check_manifest_golden.ps1 for the
## PowerShell side against the same file.

const GOLDEN := "res://tests/golden/update_manifest.txt"
const NAME := "TheUnforgotten-Setup-1.2.3.exe"
const VERSION := "1.2.3"
const SHA256 := "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"


func run() -> int:
	_failures = 0
	var golden := FileAccess.get_file_as_bytes(GOLDEN)
	_check(golden.size() > 0, "the golden manifest file is present")
	var made := UpdateCheck.make_manifest(NAME, VERSION, SHA256).to_utf8_buffer()
	_check(made == golden, "make_manifest produces exactly the golden bytes (%d vs %d)" % [made.size(), golden.size()])
	_check(not golden.has(13), "the golden file has no carriage returns")
	_check(golden.size() > 0 and golden[golden.size() - 1] == 10, "the golden file ends with a single line feed")
	_check(golden.size() < 3 or not (golden[0] == 0xEF and golden[1] == 0xBB and golden[2] == 0xBF), "the golden file has no byte order mark")
	var parsed := UpdateCheck.parse_manifest(golden)
	_check(parsed.get("name", "") == NAME and parsed.get("version", "") == VERSION and parsed.get("sha256", "") == SHA256, "the golden bytes parse back to the fixed input")
	return _failures
