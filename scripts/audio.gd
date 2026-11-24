extends Node
## Autoload "Audio". Audio.sfx("good") plays assets/audio/good.wav on the SFX bus;
## Audio.music("music_loop") loops a track on the Music bus. Volumes live in Settings.
## Buses are in default_bus_layout.tres (web ignores buses added at runtime: add new ones there).
## Audio standard (GROK_STANDARDS.md #6):
##   Audio.music_layers("music_loop", "music_combat")  # two synced loops of the same length
##   Audio.set_intensity(1.0)                          # crossfades to the combat layer (0 = explore)
##   Audio.duck()                                      # music dips under an important sound
##   Audio.step(surface)                               # footsteps per surface (Character3D calls it)

const DIR := "res://assets/audio/"
const VOICES := 8
const DUCK_DB := -10.0
const FADE := 1.5                      # seconds for a full explore <-> combat crossfade

var played: Array[String] = []         # last sounds played (tests and bug reports read this)
var intensity := 0.0                   # where the music is now (0 explore .. 1 combat)
var target_intensity := 0.0
var duck_db := 0.0                     # current duck offset on the music
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _combat: AudioStreamPlayer
var _cache := {}
var _duck_hold := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_combat = AudioStreamPlayer.new()
	_combat.bus = "Music"
	_combat.volume_db = -80.0
	add_child(_combat)


func _stream(name: String) -> AudioStream:
	if not _cache.has(name):
		var path := DIR + name + ".wav"
		_cache[name] = load(path) if ResourceLoader.exists(path) else null
	return _cache[name]


func sfx(name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var s := _stream(name)
	if s == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = s
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()
	played.append(name)
	if played.size() > 32:
		played.pop_front()
	if name == "hit_heavy" or name == "gameover":
		duck()


## Footstep for a surface ("stone", "wood", "grass", "water"...); falls back to stone.
func step(surface: String) -> void:
	var n := "step_" + surface
	sfx(n if _stream(n) != null else "step_stone", randf_range(0.9, 1.1), -6.0)


func music(name: String) -> void:
	var s := _stream(name)
	if s == null or (_music.stream == s and _music.playing):
		return
	# Looping is set in the track's .import (edit/loop_mode=2) or an .ogg's loop flag.
	_music.stream = s
	_music.play()
	_combat.stop()


## Explore + combat layers of the same length, started together so they stay in sync.
func music_layers(explore: String, combat: String) -> void:
	var a := _stream(explore)
	var b := _stream(combat)
	if a == null or b == null:
		return
	if _music.stream == a and _combat.stream == b and _music.playing:
		return
	_music.stream = a
	_combat.stream = b
	_music.play()
	_combat.play()


func set_intensity(x: float) -> void:
	target_intensity = clampf(x, 0.0, 1.0)


## Dip the music for an important sound (a heavy hit, a line of dialogue, a stinger).
func duck(hold: float = 0.4) -> void:
	_duck_hold = maxf(_duck_hold, hold)


func stop_music() -> void:
	_music.stop()
	_combat.stop()


func _process(dt: float) -> void:
	intensity = move_toward(intensity, target_intensity, dt / FADE)
	if _duck_hold > 0.0:
		_duck_hold -= dt
		duck_db = move_toward(duck_db, DUCK_DB, dt * 80.0)
	else:
		duck_db = move_toward(duck_db, 0.0, dt * 15.0)
	var layered := _combat.playing
	_music.volume_db = linear_to_db(maxf(1.0 - intensity * 0.8, 0.001) if layered else 1.0) + duck_db
	_combat.volume_db = (linear_to_db(maxf(intensity, 0.001)) + duck_db) if layered else -80.0
