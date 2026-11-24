extends Label
## Teach by doing (first-60-seconds standard): one short prompt, at most 4 words, shown until the
## player does the thing, then gone for good (saved in user://coach.cfg). No text walls.
##   Coach.teach(ui_parent, "move", "DRAG TO MOVE", func(): return hero.speed() > 1.0)

const PATH := "user://coach.cfg"
const MAX_WORDS := 4

var id := ""
var done_when: Callable
var learned := false


static func seen(hint_id: String) -> bool:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	return cfg.get_value("seen", hint_id, false)


static func forget_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


static func teach(parent: Node, hint_id: String, text: String, check: Callable) -> Label:
	assert(text.split(" ", false).size() <= MAX_WORDS, "coach hints are 4 words max")
	if seen(hint_id):
		return null
	var c := new()
	c.id = hint_id
	c.text = text
	c.done_when = check
	c.name = "Coach_" + hint_id
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.anchor_right = 1.0
	c.anchor_top = 0.42
	c.anchor_bottom = 0.42
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_theme_font_size_override("font_size", 34)
	c.add_theme_color_override("font_color", Color("e8a33d"))
	c.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	c.add_theme_constant_override("outline_size", 10)
	parent.add_child(c)
	return c


func _process(_dt: float) -> void:
	modulate.a = 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.006)
	if not learned and done_when.is_valid() and done_when.call():
		learned = true
		var cfg := ConfigFile.new()
		cfg.load(PATH)
		cfg.set_value("seen", id, true)
		cfg.save(PATH)
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.3)
		tw.tween_callback(queue_free)
