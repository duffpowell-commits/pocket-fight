extends RefCounted
## Texture atlases: many small images in one sheet = fewer draw calls and less memory on phones.
## Make one with tools/pack_atlas.py (a folder of PNGs -> <name>.png + <name>.json), then:
##   icon.texture = Atlas.tex("res://assets/art/ui_icons", "heart")
## The .json maps each image name to [x, y, w, h] in the sheet.

static var _sheets := {}                # path -> {"tex": Texture2D, "rects": Dictionary}
static var _cache := {}                 # "path:name" -> AtlasTexture


static func tex(sheet: String, name: String) -> AtlasTexture:
	var key := sheet + ":" + name
	if _cache.has(key):
		return _cache[key]
	var s := _load(sheet)
	if not s.rects.has(name):
		push_error("atlas %s has no '%s'" % [sheet, name])
		return null
	var r: Array = s.rects[name]
	var a := AtlasTexture.new()
	a.atlas = s.tex
	a.region = Rect2(r[0], r[1], r[2], r[3])
	_cache[key] = a
	return a


static func names(sheet: String) -> Array:
	return (_load(sheet).rects as Dictionary).keys()


static func _load(sheet: String) -> Dictionary:
	if not _sheets.has(sheet):
		var rects = JSON.parse_string(FileAccess.get_file_as_string(sheet + ".json"))
		_sheets[sheet] = {"tex": load(sheet + ".png"), "rects": rects if rects is Dictionary else {}}
	return _sheets[sheet]
