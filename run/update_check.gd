class_name UpdateCheck
extends RefCounted
## The pure logic of the in-game update check (see docs/UPDATE_CHECK.md): which launches check at
## all, what the GitHub reply may contain, how versions compare and what the notice says. No
## network and no nodes here; run/update_notice.gd does the request and feeds the reply to this.
## Everything that comes from the reply is untrusted and validated before use.

## The only request the game makes, and the only page it will ever open. Both are fixed here and
## never built from the reply.
const LATEST_RELEASE_API := "https://api.github.com/repos/grump606/card-battle-prototype/releases/latest"
const RELEASES_PAGE := "https://github.com/grump606/card-battle-prototype/releases/latest"
## A reply larger than this is ignored (HTTPRequest.body_size_limit is set to it too).
const MAX_BODY_BYTES := 65536
const TIMEOUT_SECONDS := 5.0
## Set to any value to turn the check off.
const DISABLE_ENV := "CARD_BATTLE_NO_UPDATE_CHECK"
## 1 to 4 dotted groups of at most 4 ASCII digits, with an optional leading v. `\z`, not `$`, so a
## trailing newline is not accepted; [0-9], not `\d`, so other scripts' digits are not either.
const TAG_PATTERN := "^[vV]?[0-9]{1,4}(\\.[0-9]{1,4}){0,3}\\z"

static var _tag_regex: RegEx


## Whether this launch should ask GitHub: not in a headless run (tests, CI, the sims), not when
## the opt-out variable is set to anything, and not when the player turned it off in the main
## menu (Settings.update_check_enabled). The arguments are passed in so tests can vary them.
static func check_enabled(display_name: String, disable_env_value: String, setting_enabled := true) -> bool:
	return display_name != "headless" and disable_env_value == "" and setting_enabled


## True when `tag` is a plain version ("v0.3.1", "0.4", "V2"), and nothing else.
static func is_valid_tag(tag: Variant) -> bool:
	if not tag is String or (tag as String).length() > 24:
		return false
	if _tag_regex == null:
		_tag_regex = RegEx.create_from_string(TAG_PATTERN)
	return _tag_regex.search(tag) != null


## The numbers of a valid tag ("v1.2.10" is [1, 2, 10]); empty for anything else.
static func parse_version(tag: Variant) -> PackedInt32Array:
	var parts := PackedInt32Array()
	if not is_valid_tag(tag):
		return parts
	for piece in (tag as String).trim_prefix("v").trim_prefix("V").split("."):
		parts.append(int(piece))
	return parts


## True when `latest` is a strictly higher version than `current`. Dotted numeric comparison with
## missing groups counted as 0 (1.2.10 > 1.2.9, 0.3.1 > 0.3, 0.3.0 == 0.3). If either side is not
## a valid version the answer is false: nothing unreadable ever produces a notice.
static func is_newer(latest: Variant, current: Variant) -> bool:
	var a := parse_version(latest)
	var b := parse_version(current)
	if a.is_empty() or b.is_empty():
		return false
	for i in maxi(a.size(), b.size()):
		var left := a[i] if i < a.size() else 0
		var right := b[i] if i < b.size() else 0
		if left != right:
			return left > right
	return false


## The release tag in a GitHub "latest release" reply, or "" if the reply is not a clean 200 with
## a JSON object holding a valid "tag_name".
static func tag_from_response(code: int, body: PackedByteArray) -> String:
	if code != 200 or body.is_empty() or body.size() > MAX_BODY_BYTES:
		return ""
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK or not json.data is Dictionary:
		return ""
	var tag: Variant = (json.data as Dictionary).get("tag_name")
	return tag if is_valid_tag(tag) else ""


## The newer release's tag when the reply announces one, else "".
static func newer_tag(code: int, body: PackedByteArray, current: String) -> String:
	var tag := tag_from_response(code, body)
	return tag if tag != "" and is_newer(tag, current) else ""


## "Update available: v0.3.1 (you have 0.3.0)". The tag must already be valid.
static func notice_text(tag: String, current: String) -> String:
	return "Update available: v%s (you have %s)" % [tag.trim_prefix("v").trim_prefix("V"), current.trim_prefix("v").trim_prefix("V")]


## --- In-game install (see docs/UPDATE_CHECK.md, "Updating in the game") ---
## Where a release's files live. The host and path are fixed here; only a tag that already passed
## is_valid_tag is ever spliced in, so nothing from the reply can choose where the game downloads from.
const DOWNLOAD_BASE := "https://github.com/grump606/card-battle-prototype/releases/download/"
## The installer is ~30 MB; anything past this is refused while downloading.
const MAX_INSTALLER_BYTES := 150 * 1024 * 1024
## An RSA-4096 signature is 512 bytes.
const MAX_SIGNATURE_BYTES := 1024
## The exported game's file name; self-update only runs from a build with exactly this name.
const GAME_EXE_NAME := "CardBattlePrototype.exe"


## "CardBattlePrototype-Setup-0.3.5.exe" for tag "v0.3.5" ("" for an invalid tag).
static func installer_name(tag: String) -> String:
	if not is_valid_tag(tag):
		return ""
	return "CardBattlePrototype-Setup-%s.exe" % tag.trim_prefix("v").trim_prefix("V")


## The installer's download URL for `tag`, or "" for an invalid tag.
static func installer_url(tag: String) -> String:
	var file := installer_name(tag)
	return "" if file == "" else "%s%s/%s" % [DOWNLOAD_BASE, _canonical_tag(tag), file]


## The detached signature's URL (the installer's URL plus ".sig"), or "" for an invalid tag.
static func signature_url(tag: String) -> String:
	var url := installer_url(tag)
	return "" if url == "" else url + ".sig"


## Release tags are published as "v<version>"; a reply tag without the v still maps to that path.
static func _canonical_tag(tag: String) -> String:
	return "v" + tag.trim_prefix("v").trim_prefix("V")


## Whether this process may replace itself: an exported build (never the editor, whose executable
## is Godot itself) running under the expected name. `can_write_dir` is whether the install folder
## accepts new files, since an all-users install needs rights the silent installer would not ask for.
static func can_self_update(is_editor: bool, exe_path: String, can_write_dir: bool) -> bool:
	return not is_editor and can_write_dir and exe_path.get_file().to_lower() == GAME_EXE_NAME.to_lower()
