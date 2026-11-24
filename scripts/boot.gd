extends Control
## Boot: a short splash, then the intro (first launch only) or the title.

const Quality = preload("res://scripts/quality.gd")


func _ready() -> void:
	if int(get_node("/root/Settings").get_value("tier")) < 0:
		await Quality.pick(self)               # first launch: time the GPU, pick LOW / MEDIUM / HIGH
	else:
		Quality.restore(get_tree())
	if not $StudioSplash.finished:
		await $StudioSplash.dismissed
	var seen: bool = get_node("/root/Settings").get_value("intro_seen")
	get_node("/root/Loader").go("res://scenes/title.tscn" if seen else "res://scenes/intro.tscn")
