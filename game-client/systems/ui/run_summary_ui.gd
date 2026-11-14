extends UiModal

# the end-of-run screen: outcome, the numbers, the build that got there,
# shards earned and where they came from, anything unlocked, and what to do next.

signal restart_requested
signal menu_requested

var restart_button: Button
var menu_button: Button


func _ready() -> void:
	panel_width = 860.0
	backdrop_alpha = 0.74
	super._ready()
	process_mode = Node.PROCESS_MODE_ALWAYS


## extras: shards_earned, shard_breakdown, achievements, best_combo,
## prev_best_kills, prev_best_combo, damage_dealt, crits, weak_hits,
## mode_name, ascension_unlocked (-1 if none).
func show_summary(data: RunData, extras: Dictionary = {}) -> void:
	_clear_content()
	var won: bool = data.status == RunData.RunStatus.COMPLETED
	var heading: String = "run complete" if won else "you fell"
	if data.is_endless():
		heading = "depth %d" % data.rooms_cleared
	var sub: String = String(extras.get("mode_name", ""))
	if data.ascension > 0:
		sub += "  ·  ascension %d" % data.ascension
	if data.seed_value != 0:
		sub += "  ·  seed %d" % data.seed_value
	_heading(heading, UiKit.GOOD if won else UiKit.DANGER, sub)

	# the four numbers people look for first, large
	var best_combo: int = int(extras.get("best_combo", 0))
	var prev_kills: int = int(extras.get("prev_best_kills", 0))
	var prev_combo: int = int(extras.get("prev_best_combo", 0))
	var big: HBoxContainer = HBoxContainer.new()
	big.alignment = BoxContainer.ALIGNMENT_CENTER
	big.add_theme_constant_override("separation", 54)
	_content.add_child(big)
	_big(big, UiKit.format_time(data.elapsed_time), "time")
	_big(big, "%d" % data.total_enemies_killed, "kills", prev_kills > 0 and data.total_enemies_killed > prev_kills)
	_big(big, "%d" % best_combo, "best combo", prev_combo > 0 and best_combo > prev_combo)
	_big(big, "%d / %d" % [data.rooms_cleared, data.total_rooms()] if not data.is_endless() else "%d" % data.rooms_cleared, "rooms")

	_rule()
	var grid: GridContainer = GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.add_child(grid)
	_stat(grid, "bosses", "%d" % data.bosses_defeated)
	_stat(grid, "elites", "%d" % data.elites_killed)
	_stat(grid, "critical hits", "%d" % int(extras.get("crits", 0)))
	_stat(grid, "damage dealt", "%d" % int(extras.get("damage_dealt", 0)))
	_stat(grid, "damage taken", "%d" % data.damage_taken)
	_stat(grid, "weak-point hits", "%d" % int(extras.get("weak_hits", 0)))

	var strip: BuildStrip = BuildStrip.new()
	strip.set_build(data.chosen_upgrades, data.chosen_mutations)
	if not strip.is_empty():
		_note("what you were by the end", UiKit.TEXT_DIM, 14)
		_content.add_child(strip)
	else:
		strip.free()

	if data.run_tags.size() > 0:
		_note("  ·  ".join(data.run_tags), UiKit.WARN, 15)

	var shards: int = int(extras.get("shards_earned", 0))
	if shards > 0:
		_rule()
		_title("+%d shards" % shards, UiKit.ACCENT, 30)
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


## a large number with a small spaced label under it.
func _big(row: HBoxContainer, value: String, title: String, is_record: bool = false) -> void:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	var v: Label = UiKit.label(value, 46, UiKit.WARN if is_record else UiKit.TEXT)
	v.add_theme_font_override("font", UiKit.font_title())
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(v)
	var t: Label = UiKit.label(title + ("  ·  new best" if is_record else ""), 13, UiKit.WARN if is_record else UiKit.TEXT_DIM)
	t.add_theme_font_override("font", UiKit.font_tag())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)


func _stat(grid: GridContainer, title: String, value: String) -> void:
	var name_label: Label = UiKit.label(title, 15, UiKit.TEXT_DIM)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(name_label)
	var v: Label = UiKit.label(value, 18, UiKit.TEXT, true)
	v.custom_minimum_size = Vector2(90, 0)
	grid.add_child(v)
