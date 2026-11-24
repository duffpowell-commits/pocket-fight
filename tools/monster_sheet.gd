extends SceneTree
## Renders a contact sheet of monsters to docs/renders/monster_sheet.png so the look can be judged
## from a real engine render. Usage (needs a screen, so xvfb):
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1080x1440 --script tools/monster_sheet.gd
## Optional: -- --out=path.png --seed=7 --say="a fat blue cat" (first tile is that description)

const Monster = preload("res://scripts/monster.gd")
const View = preload("res://scripts/monster_view.gd")


func _initialize() -> void:
	var out := "res://docs/renders/monster_sheet.png"
	var seed_n := 7
	var say := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		if a.begins_with("--seed="):
			seed_n = int(a.trim_prefix("--seed="))
		if a.begins_with("--say="):
			say = a.trim_prefix("--say=")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	var bg := ColorRect.new()
	bg.color = Color("12161f")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(grid)
	var says := say.split("|", false)
	for i in 12:
		var v := View.new()
		v.custom_minimum_size = Vector2(180, 180)
		v.animate = false
		if i < says.size():
			v.design = Monster.from_text(says[i])["design"]
		elif i == says.size():
			v.design = Monster.fresh()
		else:
			v.design = Monster.surprise(rng)
		grid.add_child(v)
		var l := Label.new()
		l.text = says[i] if i < says.size() else "%s: %s %s" % [v.design["name"], v.design["color"], v.design["body"]]
		l.add_theme_font_size_override("font_size", 11)
		l.position = Vector2(6, 2)
		l.size = Vector2(170, 40)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	img.save_png(out)
	print("SHEET SAVED " + out)
	quit()
