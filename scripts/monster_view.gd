extends Control
## Draws one monster design (scripts/monster.gd) with code: no sprite sheets, so every part
## combination works the moment it is added, and real art can replace a part later without
## touching the creator. The monster stands on the bottom-centre of this control, facing right
## (or left with `flip`).
##
##   view.design = Monster.clean(...)   set or replace the design (redraws)
##   view.act("hop")                    one-shot animation: hop, Splash, Climb, attack, hurt, guard, faint
##
## How the outline works: shapes are queued, then _flush() draws every queued shape slightly
## bigger in ink, then every shape in its colour. Shapes in one flush share one outline, so a
## body, its legs and its head read as a single silhouette.

const Monster = preload("res://scripts/monster.gd")
const INK := Color("1b2028")
const OUT := 3.5                      # outline thickness in monster units

var design: Dictionary = Monster.fresh():
	set(v):
		design = Monster.clean(v)
		queue_redraw()
var flip := false
var stage := true                     # soft spotlight disc behind the monster
var fit := 1.0                        # extra zoom, 1.0 = fills about 60% of the control's height
var animate := true                   # false = frozen idle pose (tests, low graphics)

var t := 0.0
var act_name := ""
var act_t := 0.0
var act_len := 0.0
var _q: Array = []
const ACTS := {"hop": 0.45, "Splash": 0.7, "Climb": 0.7, "attack": 0.4, "hurt": 0.4, "guard": 0.5, "faint": 0.8}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func act(action: String) -> void:
	if not ACTS.has(action):
		return
	act_name = action
	act_t = 0.0
	act_len = ACTS[action]
	queue_redraw()


func acting() -> bool:
	return act_name != ""


func _process(dt: float) -> void:
	if not animate:
		return
	t += dt
	if act_name != "":
		act_t += dt
		if act_t >= act_len and act_name != "faint":
			act_name = ""
	queue_redraw()


# ---------------------------------------------------------------- queue + outline

func _ell(c: Vector2, rx: float, ry: float, col: Color, rot: float = 0.0) -> void:
	_q.append(["e", c, Vector2(rx, ry), rot, col])


func _cap(a: Vector2, b: Vector2, w: float, col: Color) -> void:
	_q.append(["c", a, b, w, col])


func _poly(pts: PackedVector2Array, col: Color) -> void:
	_q.append(["p", pts, col])


func _ell_pts(c: Vector2, r: Vector2, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 28:
		pts.append(c + (Vector2(cos(TAU * i / 28.0) * r.x, sin(TAU * i / 28.0) * r.y)).rotated(rot))
	return pts


func _flush() -> void:
	for s in _q:
		match s[0]:
			"e":
				draw_colored_polygon(_ell_pts(s[1], s[2] + Vector2(OUT, OUT), s[3]), INK)
			"c":
				draw_line(s[1], s[2], INK, s[3] + OUT * 2.0)
				draw_circle(s[1], s[3] * 0.5 + OUT, INK)
				draw_circle(s[2], s[3] * 0.5 + OUT, INK)
			"p":
				var pts: PackedVector2Array = s[1]      # edge by edge with round corners: no miter spikes
				for i in pts.size():
					draw_line(pts[i], pts[(i + 1) % pts.size()], INK, OUT * 2.0)
					draw_circle(pts[i], OUT, INK)
	for s in _q:
		match s[0]:
			"e":
				draw_colored_polygon(_ell_pts(s[1], s[2], s[3]), s[4])
			"c":
				draw_line(s[1], s[2], s[4], s[3])
				draw_circle(s[1], s[3] * 0.5, s[4])
				draw_circle(s[2], s[3] * 0.5, s[4])
			"p":
				draw_colored_polygon(s[1], s[2])
	_q.clear()


# ---------------------------------------------------------------- the monster

func _draw() -> void:
	var d := design
	var main: Color = Monster.COLORS[d["color"]]
	var acc: Color = Monster.COLORS[d["accent"]]
	var dark := main.darkened(0.28)
	var lite := main.lightened(0.22)
	var ground := Vector2(size.x * 0.5, size.y * 0.86)
	var base := minf(size.x, size.y) / 250.0 * fit
	var k := base * lerpf(0.72, 1.18, d["size"])

	if stage:
		draw_set_transform(ground, 0.0, Vector2(base, base))
		draw_circle(Vector2(0, -70), 118.0, Color("223040"))
		draw_colored_polygon(_ell_pts(Vector2(0, 4), Vector2(104, 20), 0.0), Color("2c3e52"))

	# --- proportions
	var dims: Array = {"Round": [46.0, 42.0, 18.0, 26.0, Vector2(30, -16)],
		"Leggy": [38.0, 31.0, 36.0, 24.0, Vector2(28, -20)],
		"Bean": [31.0, 46.0, 16.0, 27.0, Vector2(8, -50)],
		"Slink": [60.0, 24.0, 13.0, 23.0, Vector2(54, -12)]}[d["body"]]
	var rx: float = dims[0] * lerpf(0.78, 1.26, d["chub"])
	var ry: float = dims[1] * lerpf(0.9, 1.12, d["chub"])
	var leg: float = dims[2] * lerpf(0.25, 1.75, d["legs"])
	var hr: float = dims[3] * lerpf(0.74, 1.32, d["head"])
	var head_off: Vector2 = dims[4] * Vector2(lerpf(0.9, 1.15, d["chub"]), 1.0)

	# --- animation
	var speed: float = {"Bold": 3.4, "Shy": 2.2, "Goofy": 5.0, "Grumpy": 2.6}[d["mood"]]
	var breathe := sin(t * speed) if animate else 0.0
	var off := Vector2.ZERO          # whole-monster offset
	var squash := 1.0 + breathe * 0.025
	var tilt := 0.0                  # head tilt
	var tail_swing := sin(t * speed * 0.8) * 0.25 if animate else 0.0
	var u := clampf(act_t / act_len, 0.0, 1.0) if act_name != "" else 0.0
	var arc := sin(u * PI)
	var flash := false
	match act_name:
		"hop":
			off.y = -26.0 * arc
			squash = 1.0 + 0.12 * sin(u * TAU)
		"Splash":
			if d["tail"] == "None":      # belly-flop
				off.y = -30.0 * arc if u < 0.6 else 0.0
				squash = 1.0 - (0.22 * sin((u - 0.6) / 0.4 * PI) if u >= 0.6 else 0.0)
			else:                        # tail slap
				tail_swing = -1.1 * arc
		"Climb":
			off.y = -58.0 * arc
			off.x = 10.0 * arc
		"attack":
			off.x = 34.0 * arc
			tilt = 0.25 * arc
		"hurt":
			off.x = -10.0 * arc + sin(u * 40.0) * 3.0
			flash = int(u * 10.0) % 2 == 0
		"guard":
			squash = 1.0 - 0.1 * arc
			tilt = -0.2 * arc
		"faint":
			tilt = 0.9 * u
			squash = 1.0 - 0.25 * u
	if d["mood"] == "Goofy" and act_name == "":
		tilt = sin(t * 2.3) * 0.12
	if d["mood"] == "Shy" and act_name == "":
		tilt = -0.08
	if flash:
		main = main.lerp(Color.WHITE, 0.6)
		lite = Color.WHITE

	draw_set_transform(ground + off * k, 0.0, Vector2(-k if flip else k, k))
	# shadow (stays on the ground when the monster leaves it)
	var lift := clampf(1.0 + off.y / 80.0, 0.4, 1.0)
	draw_set_transform(ground + Vector2(off.x * k, 0), 0.0, Vector2(-k if flip else k, k))
	draw_colored_polygon(_ell_pts(Vector2(4, 2), Vector2((rx + 14) * lift, 9 * lift), 0.0), Color(0, 0, 0, 0.35))
	draw_set_transform(ground + off * k, 0.0, Vector2(-k if flip else k, k))

	ry *= squash
	rx *= 2.0 - squash
	var bc := Vector2(0, -(leg + ry * 0.82))            # body centre
	var hc := bc + head_off * Vector2(1, squash)         # head centre

	# --- behind the body: far legs, tail, back spikes
	var hip := rx * 0.5
	var foot_y := 0.0
	var leg_w := clampf(rx * 0.3, 10.0, 18.0)
	if d["legs"] > 0.02:
		_cap(Vector2(-hip + 9, bc.y + ry * 0.5), Vector2(-hip + 9, foot_y - 2), leg_w, dark.darkened(0.2))
		_cap(Vector2(hip + 9, bc.y + ry * 0.5), Vector2(hip + 9, foot_y - 2), leg_w, dark.darkened(0.2))
	var tail_root := bc + Vector2(-rx * 0.82, ry * 0.1)
	match d["tail"]:
		"Paddle":
			var tip := tail_root + Vector2(-40, -6).rotated(-tail_swing)
			_cap(tail_root, tip, 13, main)
			_ell(tip + Vector2(-10, 0).rotated(-tail_swing), 19, 13, dark, -tail_swing)
		"Whip":
			var p1 := tail_root + Vector2(-26, -8).rotated(-tail_swing)
			var p2 := p1 + Vector2(-20, -18).rotated(-tail_swing * 1.6)
			var p3 := p2 + Vector2(-6, -22).rotated(-tail_swing * 2.2)
			_cap(tail_root, p1, 9, main)
			_cap(p1, p2, 8, main)
			_cap(p2, p3, 7, main)
		"Puff":
			var tip2 := tail_root + Vector2(-18, -12).rotated(-tail_swing)
			_cap(tail_root, tip2, 9, main)
			_ell(tip2 + Vector2(-8, -6), 17, 17, acc)
		"Club":
			var tip3 := tail_root + Vector2(-36, -14).rotated(-tail_swing)
			_cap(tail_root, tip3, 11, main)
			for i in 5:
				var a := PI * 0.5 + TAU * i / 5.0
				_poly(PackedVector2Array([tip3 + Vector2.from_angle(a - 0.4) * 12.0,
					tip3 + Vector2.from_angle(a) * 25.0, tip3 + Vector2.from_angle(a + 0.4) * 12.0]), acc)
			_ell(tip3, 14, 14, dark)
	if d["back"] == "Spikes":
		for i in 4:
			var a2 := -PI * 0.5 - 0.95 + 0.48 * i
			var on := bc + Vector2(cos(a2) * rx, sin(a2) * ry) * 0.92
			var out := Vector2(cos(a2) * rx, sin(a2) * ry).normalized()
			var side := out.orthogonal() * 9.0
			_poly(PackedVector2Array([on - side, on + out * 22.0, on + side]), acc)
	# --- body + near legs
	_ell(bc, rx, ry, main)
	if d["legs"] > 0.02:
		_cap(Vector2(-hip, bc.y + ry * 0.55), Vector2(-hip, foot_y), leg_w, dark)
		_cap(Vector2(hip, bc.y + ry * 0.55), Vector2(hip, foot_y), leg_w, dark)
		_ell(Vector2(-hip + 4, foot_y), leg_w * 0.75, 6, dark)
		_ell(Vector2(hip + 4, foot_y), leg_w * 0.75, 6, dark)
	# --- behind the head: ears, mane
	var e1 := hc + Vector2(-hr * 0.55, -hr * 0.62).rotated(tilt)
	var e2 := hc + Vector2(hr * 0.35, -hr * 0.78).rotated(tilt)
	if d["top"] == "Horns":              # horns take the crown; ears move down to the sides
		e1 += Vector2(-hr * 0.3, hr * 0.38).rotated(tilt)
		e2 += Vector2(hr * 0.42, hr * 0.5).rotated(tilt)
	var crown1 := hc + Vector2(-hr * 0.43, -hr * 0.52).rotated(tilt)
	var crown2 := hc + Vector2(hr * 0.25, -hr * 0.66).rotated(tilt)
	match d["ears"]:
		"Pointy":
			for e in [e1, e2]:
				_poly(PackedVector2Array([e + Vector2(-hr * 0.34, hr * 0.3), e + Vector2(-hr * 0.1, -hr * 0.72).rotated(tilt),
					e + Vector2(hr * 0.34, hr * 0.3)]), main)
		"Round":
			_ell(e1 + Vector2(-2, -2), hr * 0.38, hr * 0.38, main)
			_ell(e2 + Vector2(2, -2), hr * 0.38, hr * 0.38, main)
		"Floppy":
			var flop := 0.5 + breathe * 0.05
			_ell(e1 + Vector2(-hr * 0.28, hr * 0.5), hr * 0.26, hr * 0.62, dark, flop)
			_ell(e2 + Vector2(hr * 0.5, hr * 0.62), hr * 0.24, hr * 0.58, dark, -flop * 0.6)
		"Long":
			_ell(e1 + Vector2(-hr * 0.1, -hr * 0.55), hr * 0.22, hr * 0.8, main, -0.25 + tilt)
			_ell(e2 + Vector2(hr * 0.05, -hr * 0.55), hr * 0.22, hr * 0.8, main, 0.12 + tilt)
		"Fins":
			_poly(PackedVector2Array([hc + Vector2(-hr * 0.75, -hr * 0.3), hc + Vector2(-hr * 0.55, -hr * 1.5),
				hc + Vector2(hr * 0.35, -hr * 0.8)]), acc)
	if d["top"] == "Horns":
		for e in [crown1, crown2]:
			_poly(PackedVector2Array([e + Vector2(-hr * 0.2, hr * 0.25), e + Vector2(-hr * 0.42, -hr * 0.45),
				e + Vector2(-hr * 0.12, -hr * 0.82), e + Vector2(hr * 0.2, hr * 0.25)]), Color("efe6cf"))
	if d["top"] == "Mane":
		for i in 6:
			var a3 := -PI * 0.5 - 1.5 + 0.42 * i
			_ell(hc + Vector2(cos(a3), sin(a3)) * hr * 0.98, hr * 0.3, hr * 0.3, acc)
	if d["top"] == "Antenna":
		for sx in [-0.35, 0.3]:
			var root := hc + Vector2(hr * sx, -hr * 0.8)
			var tipa: Vector2 = root + Vector2(hr * (sx + 0.15) * 0.9, -hr * 0.85).rotated(tilt + breathe * 0.06)
			_cap(root, tipa, 3.0, dark)
			_ell(tipa, 6.5, 6.5, acc)
	# --- head
	_ell(hc, hr, hr * 0.94, lite, tilt)
	# the snout shares the head's outline; a beak replaces it
	var snout: String = d["snout"] if d["mouth"] != "Beak" else "Flat"
	var nose := Vector2.ZERO
	match snout:
		"Snout":
			_ell(hc + Vector2(hr * 0.74, hr * 0.3).rotated(tilt), hr * 0.5, hr * 0.33, lite, tilt + 0.08)
			nose = hc + Vector2(hr * 1.16, hr * 0.17).rotated(tilt)
		"Muzzle":
			_ell(hc + Vector2(hr * 0.52, hr * 0.4).rotated(tilt), hr * 0.46, hr * 0.37, lite.lightened(0.25), tilt)
			nose = hc + Vector2(hr * 0.74, hr * 0.2).rotated(tilt)
		"Long":
			_ell(hc + Vector2(hr * 0.98, hr * 0.26).rotated(tilt), hr * 0.82, hr * 0.31, lite, tilt + 0.05)
			nose = hc + Vector2(hr * 1.62, hr * 0.12).rotated(tilt)
	if d["mouth"] == "Beak":
		var bk := hc + Vector2(hr * 0.78, hr * 0.2).rotated(tilt)
		_poly(PackedVector2Array([bk + Vector2(-hr * 0.2, -hr * 0.3), bk + Vector2(hr * 0.62, hr * 0.02),
			bk + Vector2(-hr * 0.2, hr * 0.3)]), Color("f0c24a"))
	_flush()

	# --- on top of the body: belly, marks (kept inside the body so nothing needs clipping)
	match d["marks"]:
		"Belly":
			draw_colored_polygon(_ell_pts(bc + Vector2(rx * 0.12, ry * 0.3), Vector2(rx * 0.62, ry * 0.58), 0.0), acc.lerp(lite, 0.35))
		"Spots":
			for p in [Vector2(-0.5, -0.25), Vector2(-0.15, -0.55), Vector2(-0.6, 0.3), Vector2(-0.05, 0.1), Vector2(-0.3, 0.55)]:
				draw_circle(bc + p * Vector2(rx, ry), rx * (0.13 if p.y < 0.2 else 0.1), acc)
		"Stripes":
			for i in 4:
				var x := -rx * 0.72 + rx * 0.34 * i
				var top := -ry * sqrt(maxf(0.0, 1.0 - pow(x / rx, 2.0)))
				draw_line(bc + Vector2(x, top + 3.0), bc + Vector2(x + 5.0, top * 0.25), acc, 7.0)
				draw_circle(bc + Vector2(x + 5.0, top * 0.25), 3.5, acc)
		"Mask":
			draw_colored_polygon(_ell_pts(hc + Vector2(hr * 0.3, -hr * 0.12).rotated(tilt), Vector2(hr * 0.66, hr * 0.36), tilt), acc)
	# near legs again over a belly patch
	# --- wings sit on the body with their own outline
	if d["back"] == "Wings":
		var w0 := bc + Vector2(-rx * 0.1, -ry * 0.55)
		var flap := -0.3 + breathe * 0.12 - (0.9 * arc if act_name in ["hop", "Climb"] else 0.0)
		var wing := PackedVector2Array()
		for p in [Vector2(0, 0), Vector2(-14, -34), Vector2(-46, -44), Vector2(-40, -24), Vector2(-52, -16),
				Vector2(-38, -4), Vector2(-44, 8), Vector2(-14, 12)]:
			wing.append(w0 + (p * Vector2(1.0, 1.0)).rotated(flap))
		_poly(wing, acc)
		_flush()

	# --- face
	var blink := animate and act_name == "" and fmod(t + float(d["name"].length()) * 0.37, 3.4) < 0.13
	var eye_c := hc + Vector2(hr * 0.3, -hr * 0.12).rotated(tilt)
	var gap := hr * 0.36
	var eyes: Array = [[eye_c + Vector2(-gap, 0).rotated(tilt), 1.0], [eye_c + Vector2(gap, 0).rotated(tilt), 0.86]]
	var er := hr * 0.27
	if d["eyes"] == "Cyclops":
		eyes = [[eye_c, 1.55]]
	var pup := INK if d["marks"] != "Mask" or d["accent"] != "Coal" else Color("0c0f14")
	for e in eyes:
		var c: Vector2 = e[0]
		var r: float = er * e[1]
		if act_name == "faint":
			draw_line(c - Vector2(r, r) * 0.7, c + Vector2(r, r) * 0.7, INK, 3.0)
			draw_line(c + Vector2(-r, r) * 0.7, c + Vector2(r, -r) * 0.7, INK, 3.0)
			continue
		if blink or act_name == "hurt":
			draw_line(c - Vector2(r, 0), c + Vector2(r, 0), INK, 3.0)
			continue
		match d["eyes"]:
			"Dot":
				draw_circle(c, r * 0.5, pup)
				draw_circle(c + Vector2(-r * 0.15, -r * 0.18), r * 0.14, Color.WHITE)
			_:
				draw_circle(c, r + 1.5, INK)
				draw_circle(c, r, Color.WHITE)
				draw_circle(c + Vector2(r * 0.22, r * 0.05), r * 0.56, pup)
				draw_circle(c + Vector2(r * 0.02, -r * 0.22), r * 0.2, Color.WHITE)
				if d["eyes"] == "Sleepy":
					draw_colored_polygon(PackedVector2Array([c + Vector2(-r - 2, -r - 2), c + Vector2(r + 2, -r - 2),
						c + Vector2(r + 2, -r * 0.05), c + Vector2(-r - 2, -r * 0.05)]), lite.darkened(0.12))
					draw_line(c + Vector2(-r - 2, -r * 0.05), c + Vector2(r + 2, -r * 0.05), INK, 2.5)
				if d["eyes"] == "Fierce" or d["mood"] == "Grumpy":
					var inner := 1.0 if c.x < eye_c.x else -1.0
					if eyes.size() == 1:
						inner = 0.0
					draw_line(c + Vector2(-r * 1.15, -r * (1.0 + 0.45 * inner)), c + Vector2(r * 1.15, -r * (1.0 - 0.45 * inner)), INK, 4.0)
	# mouth
	var mc := hc + Vector2(hr * 0.42, hr * 0.46).rotated(tilt)
	var mw := hr * 0.3
	match snout:
		"Snout":
			mc = hc + Vector2(hr * 0.84, hr * 0.44).rotated(tilt)
			mw = hr * 0.24
		"Muzzle":
			mc = hc + Vector2(hr * 0.56, hr * 0.56).rotated(tilt)
			mw = hr * 0.24
		"Long":
			mc = hc + Vector2(hr * 1.22, hr * 0.4).rotated(tilt)
			mw = hr * 0.26
	if snout != "Flat":
		draw_circle(nose, hr * (0.07 if snout == "Long" else 0.12), INK)
	match d["mouth"]:
		"Smile", "Tongue", "Fangs":
			var open: bool = act_name in ["attack", "hop", "Splash", "Climb"] or d["mood"] == "Goofy"
			if d["mood"] == "Grumpy" and d["mouth"] != "Tongue":
				draw_arc(mc + Vector2(0, mw * 0.7), mw, PI * 1.2, PI * 1.8, 10, INK, 3.0)
			elif open:
				draw_colored_polygon(_ell_pts(mc, Vector2(mw, mw * 0.62), tilt), Color("5a2330"))
				draw_polyline(_closed(_ell_pts(mc, Vector2(mw, mw * 0.62), tilt)), INK, 2.5)
			else:
				draw_arc(mc + Vector2(0, -mw * 0.5), mw, PI * 0.18, PI * 0.82, 10, INK, 3.0)
			if d["mouth"] == "Fangs":
				for fx in [-0.55, 0.45]:
					var f0 := mc + Vector2(mw * fx, mw * 0.08)
					draw_colored_polygon(PackedVector2Array([f0 + Vector2(-3.5, -2), f0 + Vector2(3.5, -2), f0 + Vector2(0, 9)]), Color.WHITE)
					draw_polyline(PackedVector2Array([f0 + Vector2(-3.5, -2), f0 + Vector2(0, 9), f0 + Vector2(3.5, -2)]), INK, 1.5)
			if d["mouth"] == "Tongue":
				draw_colored_polygon(_ell_pts(mc + Vector2(mw * 0.15, mw * 0.55), Vector2(mw * 0.42, mw * 0.6), 0.2), Color("ef7d94"))
				draw_polyline(_closed(_ell_pts(mc + Vector2(mw * 0.15, mw * 0.55), Vector2(mw * 0.42, mw * 0.6), 0.2)), INK, 1.5)
	# cheek blush for the shy ones
	if d["mood"] == "Shy":
		draw_circle(hc + Vector2(hr * 0.05, hr * 0.32).rotated(tilt), hr * 0.14, Color(0.95, 0.45, 0.5, 0.5))

	# --- move effects
	if act_name == "Splash" and u > 0.45:
		var at := Vector2(-rx - 44, 0) if d["tail"] != "None" else Vector2(0, 0)
		var grow := (u - 0.45) / 0.55
		draw_set_transform(ground + Vector2(off.x * k, 0), 0.0, Vector2(-k if flip else k, k))
		draw_arc(at, 16.0 + 40.0 * grow, PI, TAU, 24, Color(0.62, 0.89, 0.93, 1.0 - grow), 4.0)
		for i in 5:
			var dir := Vector2.from_angle(-PI * 0.5 + (i - 2) * 0.38)
			draw_circle(at + dir * (20.0 + 50.0 * grow) + Vector2(0, 30.0 * grow * grow), 4.0 * (1.0 - grow) + 1.0, Color(0.62, 0.89, 0.93, 1.0 - grow))
	if act_name == "guard":
		draw_arc(bc + Vector2(rx * 0.4, 0), rx + hr + 6.0, -PI * 0.45, PI * 0.45, 20, Color(1, 1, 1, 0.7 * arc), 5.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var c := pts.duplicate()
	c.append(pts[0])
	return c
