extends "res://tests/unit/test_case.gd"

# the game ships no audio files, so a sound that has no recipe is a sound
# that silently falls back to a blip. these keep the two in step.

const WAVES: PackedStringArray = ["sine", "saw", "square", "tri", "noise"]
const LAYER_KEYS: PackedStringArray = [
	"w", "f", "f2", "d", "v", "a", "p", "t0", "lp", "lp2", "hp", "drive", "vib", "vr", "fm", "fmi",
]


func _scripts(dir: String, into: PackedStringArray) -> void:
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			into.append(dir.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir):
		if sub != "tests" and not sub.begins_with("."):
			_scripts(dir.path_join(sub), into)


## every sound name the game asks for, found by reading the scripts.
func _sounds_in_use() -> Dictionary:
	var files: PackedStringArray = PackedStringArray()
	_scripts("res://scripts", files)
	_scripts("res://systems", files)
	var name_pattern: RegEx = RegEx.create_from_string("&\"([a-z0-9_]+)\"")
	var used: Dictionary = {}
	for path: String in files:
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			if not (line.contains("Game.sfx") or line.contains("fire_sound =")):
				continue
			for found: RegExMatch in name_pattern.search_all(line):
				used[found.get_string(1)] = path
	return used


func test_every_sound_in_use_has_a_recipe() -> void:
	var used: Dictionary = _sounds_in_use()
	check(used.size() > 40, "found the sound calls in the scripts (%d)" % used.size())
	for sound: String in used:
		check(SoundSynth.has_recipe(sound), "'%s' (asked for in %s) has a recipe" % [sound, used[sound]])


func test_every_recipe_is_used() -> void:
	var used: Dictionary = _sounds_in_use()
	for sound: String in SoundSynth.names():
		check(used.has(sound), "recipe '%s' is played somewhere" % sound)


func test_recipes_are_well_formed() -> void:
	for sound: String in SoundSynth.names():
		var layers: Array = SoundSynth.RECIPES[sound]
		check(not layers.is_empty(), "'%s' has at least one layer" % sound)
		var length: float = 0.0
		for layer: Dictionary in layers:
			check(WAVES.has(layer.get("w", "")), "'%s' uses a known waveform" % sound)
			check(layer.has("d") and float(layer.d) > 0.0, "'%s' layers have a duration" % sound)
			check(layer.get("w", "") == "noise" or layer.has("f"), "'%s' pitched layers have a frequency" % sound)
			for key: String in layer:
				check(LAYER_KEYS.has(key), "'%s' has no stray key '%s'" % [sound, key])
			length = maxf(length, float(layer.get("t0", 0.0)) + float(layer.get("d", 0.0)))
		check(length <= 2.5, "'%s' is short enough to be an effect (%.2fs)" % [sound, length])


func test_rendering_is_audible_and_repeatable() -> void:
	for sound: String in ["pulse_fire", "explosion", "ui_select", "boss_warning", "fuse"]:
		var first: AudioStreamWAV = SoundSynth.render(sound)
		var second: AudioStreamWAV = SoundSynth.render(sound)
		check(first.data.size() > 200, "'%s' renders some samples" % sound)
		eq(first.data, second.data, "'%s' renders the same every time" % sound)
		var peak: int = 0
		for i: int in first.data.size() / 2:
			peak = maxi(peak, absi(first.data.decode_s16(i * 2)))
		check(peak > 3000, "'%s' is audible (peak %d)" % [sound, peak])
		check(peak <= 32767 * 0.86, "'%s' leaves headroom (peak %d)" % [sound, peak])
	var unknown: AudioStreamWAV = SoundSynth.render("no_such_sound")
	check(unknown.data.size() > 200, "an unknown name still renders a blip")


func test_music_keys_and_length() -> void:
	for place: StringName in Biome.ACT_ORDER:
		check(MusicSynth.KEYS.has(place), "biome '%s' has a music key" % place)
	check(MusicSynth.KEYS.has(&"menu"), "the menu has a music key")
	eq(MusicSynth.key_for(&"nowhere"), 48, "an unknown place falls back to a default key")
	# the loop has to be a whole number of bars or the layers drift apart
	var beat: float = 60.0 / MusicSynth.BPM
	near(float(MusicSynth.total_samples()) / float(MusicSynth.SAMPLE_RATE),
		beat * MusicSynth.BEATS_PER_BAR * MusicSynth.BARS, "loop length is eight bars", 0.001)
	eq(MusicSynth.CHORDS.size() * 2, MusicSynth.BARS, "two bars per chord fills the loop")
