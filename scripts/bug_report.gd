extends RefCounted
## REPORT A BUG: a note box, then SEND (opens a prefilled GitHub issue in the browser) or COPY
## (clipboard, to paste in a text). Adds what a tester can't be asked to type: build, device,
## screen, and whatever the current scene returns from `bug_state() -> String` if it has one.
##   BugReport.open(parent_node)

const UI = preload("res://scripts/ui.gd")
const Config = preload("res://scripts/config.gd")


static func report_text(note: String, tree: SceneTree) -> String:
	var scene := tree.current_scene
	var state := ""
	if scene != null and scene.has_method("bug_state"):
		state = str(scene.bug_state())
	var lines := [
		note.strip_edges() if note.strip_edges() != "" else "(no note)",
		"",
		"---",
		"game: %s %s" % [Config.game_title(), Config.version_label()],
		"build: %s" % Config.build_info(),
		"device: %s %s | %s | screen %s" % [OS.get_name(), OS.get_version(), OS.get_model_name(),
			str(DisplayServer.screen_get_size())],
		"scene: %s" % (scene.scene_file_path if scene != null else "?"),
	]
	var tel := tree.root.get_node_or_null("Telemetry")
	if tel != null and tel.crashed_last_run:
		lines.append("crashed last run: yes")
	lines.append("fps: %d" % Engine.get_frames_per_second())
	var st: Node = tree.root.get_node_or_null("Settings")
	if st != null:
		var q = preload("res://scripts/quality.gd")
		lines.append("graphics: %s (test frame %.1f ms)" % [q.NAMES[maxi(int(st.get_value("tier")), 0)], q.last_ms])
	if state != "":
		lines.append("state: " + state)
	return "\n".join(lines)


static func issue_url(text: String) -> String:
	var title := text.split("\n")[0].left(60)
	return "https://github.com/%s/issues/new?labels=bug&title=%s&body=%s" % [
		Config.repo(), ("Bug: " + title).uri_encode(), text.uri_encode()]


static func open(parent: Node) -> VBoxContainer:
	var box := UI.sheet(parent, 480)
	box.add_child(UI.label("REPORT A BUG", 28, UI.ACCENT))
	box.add_child(UI.label("What went wrong? Build and phone details are added for you.", 18, UI.DIM))
	var note := TextEdit.new()
	note.custom_minimum_size = Vector2(0, 200)
	note.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	note.placeholder_text = "I tapped... and then..."
	note.add_theme_font_size_override("font_size", UI.font_size(20))
	box.add_child(note)
	var status := UI.label("", 18, UI.DIM)
	box.add_child(UI.button("SEND (OPENS GITHUB)", func():
		OS.shell_open(issue_url(report_text(note.text, parent.get_tree())))
		UI.close_sheet(box)))
	box.add_child(UI.button("COPY TO TEXT IT", func():
		DisplayServer.clipboard_set(report_text(note.text, parent.get_tree()))
		status.text = "Copied. Paste it in a text.")) 
	box.add_child(status)
	box.add_child(UI.button("CLOSE", func(): UI.close_sheet(box)))
	return box
