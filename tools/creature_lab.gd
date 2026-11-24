extends SceneTree
## EXPLORATION ONLY (Nov 23, 2026): not used by the game. Renders two sheets to
## docs/art/explore-20261123/ so Duff can pick a direction for how monsters look and how
## customising stays cohesive:
##   styles.png  the same animals in four looks (current parts, skeleton + ink, soft clay, pixel)
##   blends.png  six base animals, then mixes of two at 25 / 50 / 75 percent
## Idea under test: an animal is a list of NUMBERS on one skeleton (leg length, snout length,
## tail fluff...), so any two animals can be mixed and every in-between is still one animal.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1080x1440 --script tools/creature_lab.gd

const Monster = preload("res://scripts/monster.gd")
const OldView = preload("res://scripts/monster_view.gd")

const SPECIES := {
	"Fox": {"len": 52, "chest": 25, "hip": 22, "tilt": 0.08, "neck": 14, "head": 21, "snout": 20, "snout_w": 9, "ear": 26, "ear_w": 12, "ear_round": 0.0, "droop": 0.0,
		"leg": 34, "leg_w": 9, "tail": 74, "tail_w": 9, "fluff": 1.0, "curl": 0.5, "eye": 5.0, "horn": 0.0, "wing": 0.0, "spikes": 0.0, "beak": 0.0, "scale": 0.0, "belly": 0.9,
		"col": Color("d9774f"), "acc": Color("f1ece0")},
	"Bear": {"len": 50, "chest": 40, "hip": 38, "tilt": 0.02, "neck": 5, "head": 28, "snout": 11, "snout_w": 15, "ear": 9, "ear_w": 10, "ear_round": 1.0, "droop": 0.0,
		"leg": 28, "leg_w": 18, "tail": 8, "tail_w": 8, "fluff": 0.4, "curl": 0.2, "eye": 4.0, "horn": 0.0, "wing": 0.0, "spikes": 0.0, "beak": 0.0, "scale": 0.0, "belly": 0.5,
		"col": Color("8a5a3c"), "acc": Color("d9b58c")},
	"Drake": {"len": 78, "chest": 24, "hip": 22, "tilt": 0.05, "neck": 26, "head": 18, "snout": 30, "snout_w": 10, "ear": 0, "ear_w": 8, "ear_round": 0.0, "droop": 0.0,
		"leg": 17, "leg_w": 11, "tail": 100, "tail_w": 13, "fluff": 0.0, "curl": 0.15, "eye": 4.5, "horn": 1.0, "wing": 1.0, "spikes": 1.0, "beak": 0.0, "scale": 1.0, "belly": 0.8,
		"col": Color("86b455"), "acc": Color("f0c24a")},
	"Rabbit": {"len": 30, "chest": 23, "hip": 28, "tilt": 0.25, "neck": 4, "head": 20, "snout": 6, "snout_w": 11, "ear": 46, "ear_w": 9, "ear_round": 0.8, "droop": 0.0,
		"leg": 16, "leg_w": 11, "tail": 9, "tail_w": 9, "fluff": 1.0, "curl": 0.2, "eye": 5.5, "horn": 0.0, "wing": 0.0, "spikes": 0.0, "beak": 0.0, "scale": 0.0, "belly": 0.7,
		"col": Color("e9c7b0"), "acc": Color("ffffff")},
	"Cat": {"len": 46, "chest": 22, "hip": 21, "tilt": 0.05, "neck": 8, "head": 21, "snout": 4, "snout_w": 11, "ear": 16, "ear_w": 12, "ear_round": 0.0, "droop": 0.0,
		"leg": 30, "leg_w": 8, "tail": 78, "tail_w": 6, "fluff": 0.1, "curl": 1.0, "eye": 5.5, "horn": 0.0, "wing": 0.0, "spikes": 0.0, "beak": 0.0, "scale": 0.0, "belly": 0.0,
		"col": Color("4a4f5c"), "acc": Color("9aa3b5")},
	"Owl": {"len": 24, "chest": 30, "hip": 27, "tilt": 1.15, "neck": 2, "head": 25, "snout": 9, "snout_w": 7, "ear": 12, "ear_w": 8, "ear_round": 0.0, "droop": 0.0,
		"leg": 13, "leg_w": 5, "tail": 22, "tail_w": 9, "fluff": 0.2, "curl": -0.6, "eye": 7.5, "horn": 0.0, "wing": 0.9, "spikes": 0.0, "beak": 1.0, "scale": 0.0, "belly": 0.9,
		"col": Color("9a6fd0"), "acc": Color("f0c24a")},
}


static func mix(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	for k in a:
		out[k] = a[k].lerp(b[k], t) if a[k] is Color else lerpf(float(a[k]), float(b[k]), t)
	return out


class Creature extends Control:
	const INK := Color("1b2028")
	var p: Dictionary
	var style := "ink"                 # ink | soft | cel
	var edge := 0.0                    # 0 = cub (cute), 0.5 = rookie, 1 = champion (fierce)
	var disc := true                   # backdrop circle (off when the sprite goes into a 3D world)
	var _q: Array = []

	func _tap(a: Vector2, ra: float, b: Vector2, rb: float, col: Color) -> void:
		_q.append([a, ra, b, rb, col])

	func _tap_pts(a: Vector2, ra: float, b: Vector2, rb: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		var dir := (b - a).normalized() if a.distance_to(b) > 0.01 else Vector2.RIGHT
		var ang := dir.angle()
		for i in 13:
			pts.append(b + Vector2.from_angle(ang - PI * 0.5 + PI * i / 12.0) * rb)
		for i in 13:
			pts.append(a + Vector2.from_angle(ang + PI * 0.5 + PI * i / 12.0) * ra)
		return pts

	func _fill(a: Vector2, ra: float, b: Vector2, rb: float, col: Color) -> void:
		if a.distance_to(b) < 0.5 or absf(ra - rb) >= a.distance_to(b):
			draw_circle(a if ra >= rb else b, maxf(ra, rb), col)
			return
		draw_colored_polygon(_tap_pts(a, ra, b, rb), col)
		draw_circle(a, ra, col)
		draw_circle(b, rb, col)

	func _flush() -> void:
		if style == "ink":
			for s in _q:
				_fill(s[0], s[1] + 3.2, s[2], s[3] + 3.2, INK)
			for s in _q:
				_fill(s[0], s[1], s[2], s[3], s[4])
		elif style == "cel":   # anime cel: ink line, one hard shadow tone on the lower right
			for s in _q:
				_fill(s[0], s[1] + 3.2, s[2], s[3] + 3.2, INK)
			for s in _q:
				_fill(s[0], s[1], s[2], s[3], (s[4] as Color).darkened(0.24).lerp(Color("3a3f7a"), 0.12))
			for s in _q:
				var o := Vector2(-0.1, -0.16)
				_fill(s[0] + o * s[1], s[1] * 0.86, s[2] + o * s[3], s[3] * 0.86, s[4])
		else:   # soft clay: a darker under-layer, the colour shifted up-left, a pale rim light
			for s in _q:
				_fill(s[0], s[1], s[2], s[3], (s[4] as Color).darkened(0.32))
			for s in _q:
				_fill(s[0] + Vector2(-1.5, -2.5), s[1] * 0.9, s[2] + Vector2(-1.5, -2.5), s[3] * 0.9, s[4])
			for s in _q:
				_fill(s[0] + Vector2(-s[1] * 0.3, -s[1] * 0.42), s[1] * 0.3, s[2] + Vector2(-s[3] * 0.3, -s[3] * 0.42), s[3] * 0.3, (s[4] as Color).lightened(0.22))
		_q.clear()

	func _draw() -> void:
		var k := minf(size.x, size.y) / 250.0
		var ground := Vector2(size.x * 0.5, size.y * 0.84)
		if disc:
			draw_set_transform(ground, 0.0, Vector2(k, k))
			draw_circle(Vector2(0, -64), 112.0, Color("223040"))
			draw_set_transform(ground, 0.0, Vector2(k, k * 0.2))
			draw_circle(Vector2(0, 10), 100.0, Color("2c3e52"))
			draw_circle(Vector2(0, 6), float(p["len"]) * 0.5 + 34.0, Color(0, 0, 0, 0.35))
		draw_set_transform(ground, 0.0, Vector2(k, k))
		# Stage: one slider reshapes the same animal from cub to champion.
		p = p.duplicate()
		p["head"] = float(p["head"]) * lerpf(1.22, 0.9, edge)
		p["eye"] = float(p["eye"]) * lerpf(1.35, 0.95, edge)
		p["leg"] = float(p["leg"]) * lerpf(0.7, 1.15, edge)
		p["len"] = float(p["len"]) * lerpf(0.78, 1.12, edge)
		p["snout"] = float(p["snout"]) * lerpf(0.6, 1.15, edge)
		p["neck"] = float(p["neck"]) * lerpf(0.5, 1.3, edge)
		p["horn"] = maxf(float(p["horn"]) * lerpf(0.3, 1.2, edge), edge * 0.9 - 0.45)
		p["spikes"] = maxf(float(p["spikes"]) * lerpf(0.3, 1.2, edge), edge * 0.8 - 0.4)
		p["tail"] = float(p["tail"]) * lerpf(0.7, 1.1, edge)

		var col: Color = p["col"]
		var acc: Color = p["acc"]
		var dark := col.darkened(0.25)
		var tilt: float = p["tilt"]
		var hip := Vector2(-float(p["len"]) * 0.5 * cos(tilt), -(float(p["leg"]) + float(p["hip"]) * 0.75))
		var chest := hip + Vector2(p["len"], 0).rotated(-tilt)
		var cr: float = p["chest"]
		var hr: float = p["hip"]
		var neck_dir := Vector2.from_angle(-lerpf(0.75, 1.35, clampf(tilt, 0.0, 1.0)))
		var head := chest + neck_dir * (float(p["neck"]) + cr * 0.72)
		var hd: float = p["head"]
		var lw: float = p["leg_w"]
		var leg: float = p["leg"]

		# far legs
		for base in [hip + Vector2(9, hr * 0.3), chest + Vector2(9, cr * 0.3)]:
			_tap(base, lw * 0.62, Vector2(base.x + 1, -3), lw * 0.45, dark.darkened(0.25))
		# tail: a tapering chain that can curl and fluff
		var tl: float = p["tail"]
		if tl > 4.0:
			var pos := hip + Vector2(-hr * 0.75, -hr * 0.1)
			var ang := PI + 0.35 + tilt
			var segs := 7
			for i in segs:
				var t0 := float(i) / segs
				var t1 := float(i + 1) / segs
				var r0 := float(p["tail_w"]) * (1.0 - t0 * 0.7) + float(p["fluff"]) * 9.0 * sin(PI * minf(1.0, t0 * 1.15))
				var r1 := float(p["tail_w"]) * (1.0 - t1 * 0.7) + float(p["fluff"]) * 9.0 * sin(PI * minf(1.0, t1 * 1.15))
				ang += float(p["curl"]) * 0.32
				var nxt := pos + Vector2.from_angle(ang) * (tl / segs)
				_tap(pos, r0, nxt, maxf(r1, 2.0), acc if float(p["fluff"]) > 0.6 and i >= segs - 2 else col)
				pos = nxt
		# back spikes
		var sp: float = p["spikes"]
		if sp > 0.15:
			for i in 5:
				var at := hip.lerp(chest, 0.05 + 0.22 * i)
				var up := Vector2(0, -1).rotated(-tilt)
				var r := lerpf(hr, cr, 0.05 + 0.22 * i)
				_tap(at + up * (r - 2.0), 6.0 * sp, at + up * (r + 15.0 * sp), 1.2, acc)
		# wing (behind the body for a folded look)
		var wg: float = p["wing"]
		if wg > 0.15:
			var w0 := chest + Vector2(-cr * 0.3, -cr * 0.5)
			for i in 3:
				var tip := w0 + Vector2(-46 - 10 * i, -40 + 22 * i).rotated(-tilt * 0.5) * wg
				_tap(w0, 8.0 * wg, tip, 3.0, acc.darkened(0.08 * i))
		# body, neck
		_tap(hip, hr, chest, cr, col)
		_tap(chest + neck_dir * cr * 0.3, cr * 0.7, head, hd * 0.8, col)
		# near legs: thigh into shin into paw
		for pair in [[hip + Vector2(-4, hr * 0.35), -5.0, hr], [chest + Vector2(-3, cr * 0.4), 3.0, cr]]:
			var top: Vector2 = pair[0]
			var knee := Vector2(top.x + float(pair[1]), -leg * 0.45)
			var foot := Vector2(top.x, -3)
			_tap(top, lw * 0.85, knee, lw * 0.6, dark)
			_tap(knee, lw * 0.6, foot, lw * 0.5, dark)
			_tap(foot, lw * 0.5, foot + Vector2(lw * 0.6, 0.5), lw * 0.45, dark)
		# champion gear: a shoulder plate in the second colour
		if edge > 0.7:
			var sh := chest + Vector2(-cr * 0.25, -cr * 0.35)
			_tap(sh, cr * 0.5, sh + Vector2(-cr * 0.35, cr * 0.1), cr * 0.34, acc)
		# ears
		var el: float = p["ear"]
		if el > 3.0:
			for off in [-0.5, 0.25]:
				var root := head + Vector2(hd * off, -hd * 0.62)
				var dir := Vector2.from_angle(-PI * 0.5 + off * 0.5 - 0.15 + float(p["droop"]) * 1.6 * signf(off - 0.01))
				_tap(root, float(p["ear_w"]) * 0.55, root + dir * el, float(p["ear_w"]) * lerpf(0.12, 0.5, p["ear_round"]), col if off < 0 else col.lightened(0.08))
		# horns
		var hn: float = p["horn"]
		if hn > 0.15:
			for off in [-0.35, 0.2]:
				var root2 := head + Vector2(hd * off, -hd * 0.7)
				_tap(root2, 4.5 * hn + 1.0, root2 + Vector2(-10, -22) * hn, 1.2, Color("efe6cf"))
		# head + snout (or beak)
		_tap(head, hd, head, hd, col.lightened(0.12))
		var sdir := Vector2.from_angle(0.28)
		var tip2 := head + sdir * (hd * 0.55 + float(p["snout"]))
		if float(p["beak"]) > 0.5:
			_tap(head + sdir * hd * 0.6, float(p["snout_w"]), tip2 + Vector2(2, 3), 1.5, Color("f0c24a"))
		elif float(p["snout"]) > 2.0:
			_tap(head + sdir * hd * 0.35, hd * 0.6, tip2, float(p["snout_w"]) * 0.6, col.lightened(0.12))
		_flush()

		# flank marks grow with the stage
		if edge > 0.3:
			for i in 3:
				var at3 := hip.lerp(chest, 0.2 + 0.25 * i)
				var r3 := lerpf(hr, cr, 0.2 + 0.25 * i)
				var up3 := Vector2(0, -1).rotated(-tilt)
				draw_colored_polygon(PackedVector2Array([at3 + up3 * r3 * 0.88 + Vector2(-5, 0), at3 + up3 * r3 * 0.88 + Vector2(5, 0),
					at3 + up3 * r3 * (0.9 - 0.7 * edge) + Vector2(2, 0)]), dark.darkened(0.2))
		# claws
		if edge > 0.45:
			for fx in [hip.x - 4.0, chest.x - 3.0]:
				for i in 3:
					var c0x: float = float(fx) + lw * 0.2 + i * lw * 0.35
					draw_colored_polygon(PackedVector2Array([Vector2(c0x, -4), Vector2(c0x + lw * 0.3, -4), Vector2(c0x + lw * 0.45, 2.5)]), Color("f4efe2"))
		# belly: one lighter underside from hip to chin, so every mix reads as one animal
		var bl: float = p["belly"]
		if bl > 0.1:
			var bc := col.lerp(acc, 0.75 * bl)
			_fill(hip + Vector2(hr * 0.1, hr * 0.38), hr * 0.5, chest + Vector2(0, cr * 0.4), cr * 0.52, bc)
			if float(p["snout"]) > 8.0 and float(p["beak"]) < 0.5:
				_fill(head + sdir * hd * 0.45 + Vector2(0, hd * 0.22), hd * 0.3, tip2 + Vector2(-2, 2.5), float(p["snout_w"]) * 0.35, bc)
		# scales: a row of darker dots down the flank
		if float(p["scale"]) > 0.5:
			for i in 6:
				var at2 := hip.lerp(chest, 0.1 + 0.16 * i) + Vector2(0, -lerpf(hr, cr, 0.1 + 0.16 * i) * 0.35)
				draw_circle(at2, 3.6, dark)
		# fur: a chest tuft
		if float(p["scale"]) < 0.5 and float(p["beak"]) < 0.5 and cr > 20.0:
			var c0 := chest + Vector2(cr * 0.55, cr * 0.15)
			draw_colored_polygon(PackedVector2Array([c0 + Vector2(-6, -8), c0 + Vector2(7, 2), c0 + Vector2(0, 3), c0 + Vector2(4, 11),
				c0 + Vector2(-4, 8), c0 + Vector2(-9, 12), c0 + Vector2(-10, 0)]), col.lerp(acc, 0.6 * maxf(bl, 0.3)))
		# face
		var er: float = p["eye"]
		var eye := head + Vector2(hd * 0.3, -hd * 0.15)
		if edge < 0.4:      # cub: big round shiny eye
			draw_circle(eye, er + 1.6, INK)
			draw_circle(eye, er, Color.WHITE)
			draw_circle(eye + Vector2(er * 0.15, er * 0.08), er * 0.72, INK)
			draw_circle(eye + Vector2(-er * 0.15, -er * 0.3), er * 0.3, Color.WHITE)
			draw_circle(eye + Vector2(er * 0.35, er * 0.3), er * 0.14, Color.WHITE)
		else:               # sharper: slanted lid, coloured iris, slit pupil
			var slant := (edge - 0.4) * 1.1
			var pts := PackedVector2Array([eye + Vector2(-er * 1.3, -er * (0.2 + slant)), eye + Vector2(er * 1.25, -er * (0.85 - slant * 0.6)),
				eye + Vector2(er * 1.1, er * 0.6), eye + Vector2(-er * 0.9, er * 0.75)])
			var rim := PackedVector2Array()
			for q in pts:
				rim.append(eye + (q - eye) * 1.22)
			draw_colored_polygon(rim, INK)
			draw_colored_polygon(pts, Color.WHITE)
			var iris: Color = acc if acc.get_luminance() < 0.75 else Color("e0a020")
			draw_circle(eye + Vector2(er * 0.15, er * 0.1), er * 0.55, iris)
			draw_line(eye + Vector2(er * 0.15, -er * 0.4), eye + Vector2(er * 0.15, er * 0.6), INK, maxf(1.6, er * 0.3))
			draw_circle(eye + Vector2(-er * 0.2, -er * 0.15), er * 0.18, Color.WHITE)
			draw_line(eye + Vector2(-er * 1.5, -er * (0.35 + slant)), eye + Vector2(er * 1.45, -er * (1.0 - slant * 0.6)), INK, 2.6)
		if float(p["beak"]) < 0.5:
			draw_circle(tip2 + Vector2(-1, -float(p["snout_w"]) * 0.25), 3.2, INK)
			var m0 := head + sdir * hd * 0.5 + Vector2(0, hd * 0.42)
			draw_line(m0, tip2 + Vector2(-3, float(p["snout_w"]) * 0.3), INK, 2.2)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _cell(parent: Control, node: Control, text: String, cell: int) -> void:
	node.custom_minimum_size = Vector2(cell, cell)
	parent.add_child(node)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 11)
	l.position = Vector2(6, 2)
	node.add_child(l)


func _sheet(cols: int, cell: int, build: Callable, out: String, pixel_cols: Array = []) -> void:
	for c in root.get_children():
		c.queue_free()
	await process_frame
	var bg := ColorRect.new()
	bg.color = Color("12161f")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var grid := GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	root.add_child(grid)
	build.call(grid, cell)
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var px := float(img.get_width()) / 540.0
	for c in pixel_cols:          # pixel look: shrink that column 5x and blow it back up, hard edges
		var rect := Rect2i(int(c * cell * px), 0, int(cell * px), img.get_height())
		var part := img.get_region(rect)
		part.resize(rect.size.x / 5, rect.size.y / 5, Image.INTERPOLATE_BILINEAR)
		part.resize(rect.size.x, rect.size.y, Image.INTERPOLATE_NEAREST)
		img.blit_rect(part, Rect2i(Vector2i.ZERO, rect.size), rect.position)
	img.save_png(out)
	print("SAVED " + out)


func _initialize() -> void:
	var dir := "res://docs/art/explore-20261123/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	# Sheet 1: the same four animals in four looks.
	var rows := [["Fox", "orange fox"], ["Drake", "green dragon with spikes"], ["Bear", "fat brown bear"], ["Rabbit", "pink bunny"]]
	await _sheet(4, 135, func(grid: GridContainer, cell: int):
		for r in rows:
			var old := OldView.new()
			old.animate = false
			old.design = Monster.from_text(r[1])["design"]
			_cell(grid, old, "A now: " + r[0], cell)
			for st in [["ink", "B skeleton"], ["soft", "C clay"], ["ink", "D pixel"]]:
				var c := Creature.new()
				c.p = SPECIES[r[0]]
				c.style = st[0]
				_cell(grid, c, st[1], cell), dir + "styles.png", [3])
	# Sheet 2: six bases, then mixes.
	var mixes := [["Fox", "Drake"], ["Bear", "Rabbit"], ["Cat", "Owl"], ["Drake", "Owl"], ["Fox", "Bear"]]
	await _sheet(3, 180, func(grid: GridContainer, cell: int):
		for name in SPECIES:
			var c := Creature.new()
			c.p = SPECIES[name]
			_cell(grid, c, name, cell)
		for m in mixes.slice(0, 2):
			for t in [0.25, 0.5, 0.75]:
				var c2 := Creature.new()
				c2.p = mix(SPECIES[m[0]], SPECIES[m[1]], t)
				_cell(grid, c2, "%s %d%% + %s %d%%" % [m[0], int(100 - t * 100), m[1], int(t * 100)], cell), dir + "blends.png")
	await _sheet(3, 180, func(grid: GridContainer, cell: int):
		for m in mixes.slice(2, 5):
			for t in [0.25, 0.5, 0.75]:
				var c2 := Creature.new()
				c2.p = mix(SPECIES[m[0]], SPECIES[m[1]], t)
				_cell(grid, c2, "%s %d%% + %s %d%%" % [m[0], int(100 - t * 100), m[1], int(t * 100)], cell), dir + "blends2.png")
	# Sheet 3: one animal, three stages (the same numbers pushed from cute to fierce), cel shaded.
	await _sheet(3, 180, func(grid: GridContainer, cell: int):
		for name in ["Fox", "Drake", "Owl"]:
			for st in [[0.0, "cub"], [0.5, "rookie"], [1.0, "champion"]]:
				var c := Creature.new()
				c.p = SPECIES[name]
				c.style = "cel"
				c.edge = st[0]
				_cell(grid, c, "%s: %s" % [name, st[1]], cell)
		for st in [[0.0, "cub"], [0.5, "rookie"], [1.0, "champion"]]:
			var c2 := Creature.new()
			c2.p = mix(SPECIES["Fox"], SPECIES["Drake"], 0.5)
			c2.style = "cel"
			c2.edge = st[0]
			_cell(grid, c2, "Fox+Drake: %s" % st[1], cell), dir + "stages.png")
	await _world(dir + "world.png")
	quit()


## Sheet 4: the HD-2D look. Flat drawn monsters standing in a small lit 3D place, with soft
## focus at the top and bottom of the screen. One real engine render, no pipeline yet.
func _world(out: String) -> void:
	for c in root.get_children():
		c.queue_free()
	await process_frame
	var world := Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("9fd3e6")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b9c8e8")
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = Color("bfe3ee")
	env.fog_density = 0.0035
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_bloom = 0.03
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_color = Color("fff0d0")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	world.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 34.0
	cam.position = Vector3(0, 12.5, 20.0)
	world.add_child(cam)
	cam.look_at(Vector3(0, 0.6, -0.5))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var solid := func(mesh: Mesh, col: Color, pos: Vector3, scl: Vector3 = Vector3.ONE, rough: float = 1.0) -> MeshInstance3D:
		var m := MeshInstance3D.new()
		m.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = col
		mat.roughness = rough
		m.material_override = mat
		m.position = pos
		m.scale = scl
		world.add_child(m)
		return m
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	solid.call(plane, Color("6fb24e"), Vector3.ZERO)
	# lighter and darker grass patches, a dirt path, a pond
	var disc := CylinderMesh.new()
	disc.height = 0.02
	for i in 26:
		var r := rng.randf_range(0.8, 2.6)
		solid.call(disc, Color("7fc257") if i % 2 == 0 else Color("5fa044"), Vector3(rng.randf_range(-11, 11), 0.01 + i * 0.0004, rng.randf_range(-12, 5)), Vector3(r, 1, r * rng.randf_range(0.5, 1.0)))
	for i in 9:
		solid.call(disc, Color("c9a873"), Vector3(-6.0 + i * 1.5, 0.03, 2.2 + sin(i * 0.9) * 0.8), Vector3(1.5, 1, 0.9))
	solid.call(disc, Color("4aa6d8"), Vector3(4.6, 0.04, -3.2), Vector3(3.4, 1, 2.2), 0.1)
	solid.call(disc, Color("8fd0ee"), Vector3(4.3, 0.05, -3.4), Vector3(2.2, 1, 1.2), 0.1)
	# low hills behind
	var ball := SphereMesh.new()
	for i in 7:
		solid.call(ball, Color("5d9c47").lerp(Color("9fd3e6"), 0.25), Vector3(-15 + i * 5, -1.5, -14 - (i % 2) * 3), Vector3(9, 5 + (i % 3), 6))
	# trees: trunk + three stacked cones; rocks; flowers
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	var trunk := CylinderMesh.new()
	for t in [Vector3(-5.2, 0, -4.5), Vector3(-7.4, 0, -1.5), Vector3(-3.0, 0, -7.5), Vector3(7.6, 0, -6.5), Vector3(1.2, 0, -8.5), Vector3(8.6, 0, 0.5), Vector3(-9.0, 0, -8.0), Vector3(5.2, 0, -10.0)]:
		var h := rng.randf_range(0.85, 1.3)
		solid.call(trunk, Color("7a5236"), t + Vector3(0, 0.5 * h, 0), Vector3(0.45, 0.5 * h, 0.45))
		for j in 3:
			solid.call(cone, Color("2f7d4a").lightened(0.07 * j), t + Vector3(0, (1.5 + j * 0.85) * h, 0), Vector3((2.4 - j * 0.6) * h, 0.8 * h, (2.4 - j * 0.6) * h))
	for i in 9:
		var s := rng.randf_range(0.3, 0.9)
		solid.call(ball, Color("8a8f9c"), Vector3(rng.randf_range(-9, 9), s * 0.25, rng.randf_range(-9, 4)), Vector3(s * 1.4, s, s * 1.1))
	for i in 40:
		solid.call(ball, [Color("fff2a8"), Color("f7a8c4"), Color("ffffff")][i % 3], Vector3(rng.randf_range(-9, 9), 0.12, rng.randf_range(-7, 5.5)), Vector3(0.16, 0.16, 0.16))
	# the monsters: each drawn into its own small viewport, then stood up as a flat card
	var cast := [["Fox", 0.5, Vector3(-2.0, 0, 1.6), 2.4, false], ["Drake", 1.0, Vector3(1.9, 0, -0.4), 3.4, true],
		["Owl", 0.0, Vector3(0.2, 0, 3.6), 1.6, false], ["Bear", 0.5, Vector3(-3.6, 0, -2.6), 3.0, false],
		["mix", 0.5, Vector3(3.2, 0, 3.0), 2.4, true]]
	for c in cast:
		var vp := SubViewport.new()
		vp.size = Vector2i(512, 512)
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		var cr := Creature.new()
		cr.p = mix(SPECIES["Fox"], SPECIES["Drake"], 0.5) if c[0] == "mix" else SPECIES[c[0]]
		cr.style = "cel"
		cr.edge = c[1]
		cr.disc = false
		cr.size = Vector2(512, 512)
		vp.add_child(cr)
		var card := Sprite3D.new()
		card.texture = vp.get_texture()
		card.pixel_size = float(c[3]) / 512.0
		card.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		card.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		card.shaded = false
		card.flip_h = c[4]
		card.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		card.position = (c[2] as Vector3) + Vector3(0, float(c[3]) * 0.34, 0)
		world.add_child(card)
		# soft blob shadow on the grass
		var sh := MeshInstance3D.new()
		sh.mesh = disc
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.05, 0.12, 0.08, 0.38)
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sh.material_override = sm
		sh.position = (c[2] as Vector3) + Vector3(0, 0.06, 0)
		sh.scale = Vector3(float(c[3]) * 0.52, 1, float(c[3]) * 0.2)
		world.add_child(sh)
	# tilt-shift: sharp across the middle, soft at the top and bottom, plus a light vignette
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sm2 := ShaderMaterial.new()
	var sh2 := Shader.new()
	sh2.code = """shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
void fragment() {
	float d = smoothstep(0.2, 0.5, abs(SCREEN_UV.y - 0.55));
	vec3 c = textureLod(screen, SCREEN_UV, d * 2.4).rgb;
	vec2 v = SCREEN_UV - vec2(0.5);
	c *= 1.0 - dot(v, v) * 0.45;
	c = mix(c, c * vec3(1.06, 1.0, 0.92), 0.5);
	COLOR = vec4(c, 1.0);
}"""
	sm2.shader = sh2
	rect.material = sm2
	layer.add_child(rect)
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("SAVED " + out)
