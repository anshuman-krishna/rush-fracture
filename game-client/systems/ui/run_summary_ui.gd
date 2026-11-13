extends UiModal

# the end-of-run screen: outcome, the numbers, shards earned and where they
# came from, anything unlocked, and what to do next.

signal restart_requested
signal menu_requested

var restart_button: Button
var menu_button: Button


func _ready() -> void:
	panel_width = 720.0
	backdrop_alpha = 0.72
	super._ready()
	process_mode = Node.PROCESS_MODE_ALWAYS


## extras: shards_earned, shard_breakdown, achievements, best_combo,
## prev_best_kills, prev_best_combo, damage_dealt, crits, weak_hits,
## mode_name, ascension_unlocked (-1 if none).
func show_summary(data: RunData, extras: Dictionary = {}) -> void:
	_clear_content()
	var won: bool = data.status == RunData.RunStatus.COMPLETED
	var heading: String = "run complete" if won else "run failed"
	if data.is_endless():
		heading = "depth %d" % data.rooms_cleared
	_title(heading, UiKit.GOOD if won else UiKit.DANGER, 38)
	var sub: String = String(extras.get("mode_name", ""))
	if data.ascension > 0:
		sub += "  ·  ascension %d" % data.ascension
	if data.seed_value != 0:
		sub += "  ·  seed %d" % data.seed_value
	_note(sub)

	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.add_child(grid)

	var best_combo: int = int(extras.get("best_combo", 0))
	_stat(grid, "rooms", "%d / %d" % [data.rooms_cleared, data.total_rooms()] if not data.is_endless() else "%d" % data.rooms_cleared)
	_stat(grid, "time", UiKit.format_time(data.elapsed_time))
	_stat(grid, "kills", "%d" % data.total_enemies_killed, data.total_enemies_killed > int(extras.get("prev_best_kills", 0)) and int(extras.get("prev_best_kills", 0)) > 0)
	_stat(grid, "best combo", "%d" % best_combo, best_combo > int(extras.get("prev_best_combo", 0)) and int(extras.get("prev_best_combo", 0)) > 0)
	_stat(grid, "bosses", "%d" % data.bosses_defeated)
	_stat(grid, "elites", "%d" % data.elites_killed)
	_stat(grid, "damage dealt", "%d" % int(extras.get("damage_dealt", 0)))
	_stat(grid, "damage taken", "%d" % data.damage_taken)
	_stat(grid, "upgrades", "%d" % data.chosen_upgrades.size())
	_stat(grid, "mutations", "%d" % data.chosen_mutations.size())
	_stat(grid, "critical hits", "%d" % int(extras.get("crits", 0)))
	_stat(grid, "weak-point hits", "%d" % int(extras.get("weak_hits", 0)))

	if data.run_tags.size() > 0:
		_note(" · ".join(data.run_tags), UiKit.WARN, 15)

	var shards: int = int(extras.get("shards_earned", 0))
	if shards > 0:
		_content.add_child(HSeparator.new())
		_title("+%d shards" % shards, UiKit.ACCENT, 26)
		var parts: PackedStringArray = PackedStringArray()
		var breakdown: Dictionary = extras.get("shard_breakdown", {})
		for key: String in ["kills", "rooms", "bosses", "elites", "completed", "combo_bonus", "essence", "ascension", "pvp_win"]:
			if int(breakdown.get(key, 0)) > 0:
				parts.append("%s %d" % [key.replace("_", " "), breakdown[key]])
		if not parts.is_empty():
			_note("  ·  ".join(parts), UiKit.TEXT_DIM, 14)

	for a: Dictionary in extras.get("achievements", []):
		_note("achievement: %s (+%d shards)" % [a.get("name", ""), int(a.get("reward", 0))], UiKit.WARN, 17)
	if int(extras.get("ascension_unlocked", -1)) > 0:
		_note("ascension %d unlocked" % int(extras.ascension_unlocked), Color(1.0, 0.4, 0.9), 18)

	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	_content.add_child(row)
	restart_button = UiKit.button("run it back", 19, Vector2(220, 50))
	restart_button.pressed.connect(func() -> void:
		hide_panel()
		restart_requested.emit())
	row.add_child(restart_button)
	menu_button = UiKit.button("main menu", 19, Vector2(220, 50))
	menu_button.pressed.connect(func() -> void:
		hide_panel()
		menu_requested.emit())
	row.add_child(menu_button)

	_open()
	restart_button.grab_focus.call_deferred()


func _stat(grid: GridContainer, title: String, value: String, is_record: bool = false) -> void:
	var name_label: Label = UiKit.label(title, 15, UiKit.TEXT_DIM)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(name_label)
	var text: String = value + ("  new best" if is_record else "")
	grid.add_child(UiKit.label(text, 19, UiKit.WARN if is_record else UiKit.TEXT, true))
