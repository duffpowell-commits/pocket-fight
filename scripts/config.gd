extends RefCounted
## Build facts, read from files CI writes into the export (never edit them by hand):
##   res://build_code.txt  counting build number (GitHub run number), e.g. 42
##   res://build.txt       "<sha> <date> #<run>", shown in bug reports
##   res://repo.txt        "owner/name" of the GitHub repo this build came from
## In the editor none of these exist: build 0, repo unknown, updater off.

const FALLBACK_REPO := "duffpowell-commits/godot-game-starter"


static func _read(path: String) -> String:
	if FileAccess.file_exists(path):
		return FileAccess.get_file_as_string(path).strip_edges()
	return ""


static func build_code() -> int:
	return _read("res://build_code.txt").to_int()


static func build_info() -> String:
	var b := _read("res://build.txt")
	return b if b != "" else "editor build"


static func repo() -> String:
	var r := _read("res://repo.txt")
	return r if r != "" else FALLBACK_REPO


## The APK in the dev release is named after the repo: <name>.apk
static func apk_name() -> String:
	return repo().get_file() + ".apk"


static func release_url() -> String:
	return "https://github.com/%s/releases/download/dev/" % repo()


static func game_title() -> String:
	return str(ProjectSettings.get_setting("application/config/name", "Game"))


## "v0.1.42" in a CI build, "dev" in the editor. Shown on the title screen.
static func version_label() -> String:
	var c := build_code()
	return "v0.1.%d" % c if c > 0 else "dev"


## Dev-only tools (debug menu): debug exports (the dev APK) and the editor. Never a release export.
static func dev_build() -> bool:
	return OS.is_debug_build()
