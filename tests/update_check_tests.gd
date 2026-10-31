extends RefCounted
## Tests for the pure update-check logic (run/update_check.gd): version comparison, tag
## validation, reply parsing, the notice text and when the check may run. No network.
## Returns the failure count; the suite in run_tests.gd adds it to its own.

var _failures := 0


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func run() -> int:
	_failures = 0
	_test_is_newer()
	_test_tag_validation()
	_test_parse_version()
	_test_responses()
	_test_notice_text()
	_test_check_enabled()
	_test_fixed_urls()
	_failures += load("res://tests/settings_tests.gd").new().run()
	_test_install_urls()
	_failures += load("res://tests/update_verifier_tests.gd").new().run()
	_failures += load("res://tests/update_installer_tests.gd").new().run()
	return _failures


func _body(text: String) -> PackedByteArray:
	return text.to_utf8_buffer()


func _release(tag: String) -> PackedByteArray:
	return _body(JSON.stringify({"tag_name": tag, "html_url": "https://evil.example/x"}))


func _test_is_newer() -> void:
	_check(UpdateCheck.is_newer("v0.3.1", "0.3.0"), "0.3.1 is newer than 0.3.0")
	_check(not UpdateCheck.is_newer("0.3.0", "0.3.0"), "equal versions are not newer")
	_check(not UpdateCheck.is_newer("0.2.9", "0.3.0"), "an older release is not newer")
	_check(UpdateCheck.is_newer("1.2.10", "1.2.9"), "1.2.10 is newer than 1.2.9 (numeric, not text)")
	_check(not UpdateCheck.is_newer("1.2.9", "1.2.10"), "1.2.9 is not newer than 1.2.10")
	_check(UpdateCheck.is_newer("0.3.1", "0.3"), "0.3.1 is newer than 0.3")
	_check(not UpdateCheck.is_newer("0.3", "0.3.0") and not UpdateCheck.is_newer("0.3.0", "0.3"), "0.3 and 0.3.0 are equal")
	_check(UpdateCheck.is_newer("1", "0.9.9"), "a one-number version compares")
	_check(UpdateCheck.is_newer("V1.0.0.1", "v1.0.0"), "four groups and either v case work")
	_check(UpdateCheck.is_newer("10.0", "9.9.9"), "10 is newer than 9")
	_check(not UpdateCheck.is_newer("latest", "0.3.0"), "an unreadable latest is never newer")
	_check(not UpdateCheck.is_newer("9.9.9", ""), "an unreadable current is never newer")
	_check(not UpdateCheck.is_newer("", ""), "two empty versions are not newer")
	_check(not UpdateCheck.is_newer(null, "0.1"), "null is not newer")
	_check(not UpdateCheck.is_newer(5, "0.1"), "a non-string is not newer")


func _test_tag_validation() -> void:
	for good in ["v0.3.1", "0.3.1", "V1", "1.2", "v10.20.30.40", "9999.9999.9999.9999", "v0"]:
		_check(UpdateCheck.is_valid_tag(good), "'%s' is a valid tag" % good)
	var bad := ["", "v", "latest", "1.2.3-beta", "1.2.3-beta; rm -rf /", "v1.2.3.4.5", "99999", "1.99999", "1..2", ".1", "1.", "v v1", " v1.0", "v1.0 ",
		"v1.0\n", "v1.0\nv2.0", "v\u0661.\u0662", "v1.0\u202e", "\u00e9", "v1,0", "0x10", "1e3", "-1.0", "v1.2.3+build", "https://x.example/v1.0",
		"1".repeat(40), "v1.0.0.0".repeat(5)]
	for tag in bad:
		_check(not UpdateCheck.is_valid_tag(tag), "'%s' is rejected" % tag.c_escape())
	_check(not UpdateCheck.is_valid_tag(null) and not UpdateCheck.is_valid_tag(1.5) and not UpdateCheck.is_valid_tag([]), "non-strings are rejected")


func _test_parse_version() -> void:
	_check(UpdateCheck.parse_version("v1.2.10") == PackedInt32Array([1, 2, 10]), "parse_version reads the numbers")
	_check(UpdateCheck.parse_version("007.01") == PackedInt32Array([7, 1]), "leading zeros are fine")
	_check(UpdateCheck.parse_version("nope").is_empty(), "parse_version of garbage is empty")


func _test_responses() -> void:
	_check(UpdateCheck.newer_tag(200, _release("v0.3.1"), "0.3.0") == "v0.3.1", "a newer release is reported")
	_check(UpdateCheck.newer_tag(200, _release("v0.3.0"), "0.3.0") == "", "the same release is ignored")
	_check(UpdateCheck.newer_tag(200, _release("v0.2.0"), "0.3.0") == "", "an older release is ignored")
	_check(UpdateCheck.tag_from_response(200, _release("v0.3.1")) == "v0.3.1", "tag_from_response returns a valid tag")
	for code in [0, 201, 204, 301, 304, 403, 404, 429, 500, 503]:
		_check(UpdateCheck.newer_tag(code, _release("v9.9.9"), "0.3.0") == "", "HTTP %d is ignored" % code)
	_check(UpdateCheck.newer_tag(200, _body(""), "0.3.0") == "", "an empty body is ignored")
	for text in ["not json", "{", "[]", "[\"v9.9.9\"]", "null", "42", "\"v9.9.9\"", "{}", "{\"tag_name\": null}", "{\"tag_name\": 9}", "{\"tag_name\": [\"v9.9.9\"]}",
		"{\"tag_name\": \"latest\"}", "{\"tag_name\": \"9.9.9-rc1\"}", "{\"tag_name\": \"\"}", "{\"tag\": \"v9.9.9\"}", "{\"tag_name\": \"v99999.0\"}", "<html>rate limited</html>"]:
		_check(UpdateCheck.newer_tag(200, _body(text), "0.3.0") == "", "reply '%s' is ignored" % text)
	_check(UpdateCheck.newer_tag(200, PackedByteArray([0xff, 0xfe, 0x00, 0x7b]), "0.3.0") == "", "binary junk is ignored")
	var huge := _body("{\"tag_name\": \"v9.9.9\", \"body\": \"%s\"}" % "x".repeat(UpdateCheck.MAX_BODY_BYTES))
	_check(UpdateCheck.newer_tag(200, huge, "0.3.0") == "", "a reply over the size cap is ignored")
	_check(UpdateCheck.newer_tag(200, _release("v9.9.9"), "garbage") == "", "an unreadable running version never shows a notice")


func _test_notice_text() -> void:
	_check(UpdateCheck.notice_text("v0.3.1", "0.3.0") == "Update available: v0.3.1 (you have 0.3.0)", "notice text from a v tag")
	_check(UpdateCheck.notice_text("0.3.1", "0.3.0") == "Update available: v0.3.1 (you have 0.3.0)", "notice text from a bare tag")
	_check(UpdateCheck.notice_text("V1.0", "v0.9") == "Update available: v1.0 (you have 0.9)", "notice text normalises the v")


func _test_check_enabled() -> void:
	_check(UpdateCheck.check_enabled("windows", ""), "a normal launch checks")
	_check(not UpdateCheck.check_enabled("headless", ""), "headless never checks")
	_check(not UpdateCheck.check_enabled("windows", "1"), "the opt-out variable disables the check")
	_check(not UpdateCheck.check_enabled("windows", "anything"), "any value of the opt-out variable disables it")
	_check(not UpdateCheck.check_enabled("headless", "1"), "headless and opted out is still off")
	_check(UpdateCheck.check_enabled("windows", "", true), "the setting on still checks")
	_check(not UpdateCheck.check_enabled("windows", "", false), "the saved setting off disables the check")
	_check(not UpdateCheck.check_enabled("headless", "", true) and not UpdateCheck.check_enabled("windows", "1", true), "headless and the env var win over an on setting")


func _test_install_urls() -> void:
	var base := "https://github.com/grump606/card-battle-prototype/releases/download/v0.3.5/CardBattlePrototype-Setup-0.3.5.exe"
	_check(UpdateCheck.installer_name("v0.3.5") == "CardBattlePrototype-Setup-0.3.5.exe", "the installer name follows the build script naming")
	_check(UpdateCheck.installer_url("v0.3.5") == base, "the installer URL is the fixed release path")
	_check(UpdateCheck.installer_url("0.3.5") == base and UpdateCheck.installer_url("V0.3.5") == base, "a tag without or with a capital V maps to the same v-tagged path")
	_check(UpdateCheck.signature_url("v0.3.5") == base + ".sig", "the signature sits next to the installer")
	for bad in ["", "latest", "1.2.3-beta", "v1/../../x", "v1.2\nx", "http://evil/x", "v1.2.3.4.5", "../1.0"]:
		_check(UpdateCheck.installer_url(bad) == "" and UpdateCheck.signature_url(bad) == "" and UpdateCheck.installer_name(bad) == "", "an invalid tag never builds a URL: %s" % bad.c_escape())
	_check(UpdateCheck.installer_url("v0.3.5").begins_with(UpdateCheck.DOWNLOAD_BASE), "every download URL starts with the fixed base")
	_check(UpdateCheck.can_self_update(false, "C:/Games/CardBattlePrototype.exe", true), "an exported, correctly named, writable install can update itself")
	_check(not UpdateCheck.can_self_update(true, "C:/Games/CardBattlePrototype.exe", true), "the editor never updates itself")
	_check(not UpdateCheck.can_self_update(false, "C:/Godot/Godot_v4.7.2.exe", true), "another executable name never updates itself")
	_check(not UpdateCheck.can_self_update(false, "C:/Program Files/G/CardBattlePrototype.exe", false), "a folder the player cannot write never updates itself")


func _test_fixed_urls() -> void:
	_check(UpdateCheck.RELEASES_PAGE.begins_with("https://github.com/grump606/card-battle-prototype/"), "the page opened is a fixed github.com repo URL")
	_check(UpdateCheck.LATEST_RELEASE_API.begins_with("https://api.github.com/repos/grump606/card-battle-prototype/"), "the request goes to the fixed api.github.com repo URL")
