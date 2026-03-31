class_name AudioManager
extends Node

# centralized audio playback. uses pooled AudioStreamPlayer nodes
# to avoid allocation during combat. sounds are referenced by name.

const POOL_SIZE := 12

var _pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0
var _sounds: Dictionary = {}
var _enabled: bool = true


func _ready() -> void:
	for i in POOL_SIZE:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_pool.append(player)

	_register_sounds()


func play(sound_name: String, volume_db: float = 0.0, pitch_variance: float = 0.0) -> void:
	if not _enabled:
		return
	var stream: AudioStream = _sounds.get(sound_name)
	if not stream:
		return

	var player: AudioStreamPlayer = _get_next_player()
	player.stream = stream
	player.volume_db = volume_db
	if pitch_variance > 0:
		player.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
	else:
		player.pitch_scale = 1.0
	player.play()


func play_ui(sound_name: String) -> void:
	play(sound_name, -6.0)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled


func _get_next_player() -> AudioStreamPlayer:
	var player: AudioStreamPlayer = _pool[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE
	return player


func _register_sounds() -> void:
	# weapon sounds
	_try_load("pulse_fire", "res://assets/audio/sfx/pulse_fire.wav")
	_try_load("scatter_fire", "res://assets/audio/sfx/scatter_fire.wav")
	_try_load("beam_fire", "res://assets/audio/sfx/beam_fire.wav")

	# combat feedback
	_try_load("enemy_hit", "res://assets/audio/sfx/enemy_hit.wav")
	_try_load("enemy_death", "res://assets/audio/sfx/enemy_death.wav")
	_try_load("player_damage", "res://assets/audio/sfx/player_damage.wav")

	# boss
	_try_load("boss_slam", "res://assets/audio/sfx/boss_slam.wav")
	_try_load("boss_shockwave", "res://assets/audio/sfx/boss_shockwave.wav")
	_try_load("boss_phase", "res://assets/audio/sfx/boss_phase.wav")
	_try_load("boss_death", "res://assets/audio/sfx/boss_death.wav")

	# ui
	_try_load("ui_select", "res://assets/audio/sfx/ui_select.wav")
	_try_load("ui_hover", "res://assets/audio/sfx/ui_hover.wav")
	_try_load("room_clear", "res://assets/audio/sfx/room_clear.wav")
	_try_load("upgrade_pick", "res://assets/audio/sfx/upgrade_pick.wav")

	# run events
	_try_load("run_start", "res://assets/audio/sfx/run_start.wav")
	_try_load("boss_warning", "res://assets/audio/sfx/boss_warning.wav")

	# movement
	_try_load("dash", "res://assets/audio/sfx/dash.wav")

	# generate placeholder tones for missing sounds
	_fill_placeholders()


func _try_load(name: String, path: String) -> void:
	if ResourceLoader.exists(path):
		_sounds[name] = load(path)


func _fill_placeholders() -> void:
	# generate simple procedural tones as placeholders
	var needed: Array = [
		"pulse_fire", "scatter_fire", "beam_fire",
		"enemy_hit", "enemy_death", "player_damage",
		"boss_slam", "boss_shockwave", "boss_phase", "boss_death",
		"ui_select", "ui_hover", "room_clear", "upgrade_pick",
		"run_start", "boss_warning",
		"dash",
	]
	for name in needed:
		if not _sounds.has(name):
			_sounds[name] = _generate_tone(name)


func _generate_tone(sound_name: String) -> AudioStream:
	# procedural placeholder — distinct per sound type
	var sample_rate: int = 22050
	var duration: float = 0.08

	match sound_name:
		"pulse_fire": duration = 0.06
		"scatter_fire": duration = 0.1
		"beam_fire": duration = 0.03
		"enemy_hit": duration = 0.06
		"enemy_death": duration = 0.15
		"player_damage": duration = 0.12
		"boss_slam", "boss_shockwave": duration = 0.2
		"boss_phase", "boss_death": duration = 0.3
		"room_clear", "run_start", "boss_warning": duration = 0.25
		"ui_select", "ui_hover", "upgrade_pick": duration = 0.05
		"dash": duration = 0.08

	var samples: int = int(sample_rate * duration)
	var data: PackedVector2Array = PackedVector2Array()
	data.resize(samples)

	var freq: float = _freq_for_sound(sound_name)
	for i in samples:
		var t: float = float(i) / float(sample_rate)
		var envelope: float = 1.0 - (t / duration)
		# sharper attack for weapons
		if sound_name in ["pulse_fire", "scatter_fire"]:
			envelope *= envelope
		var wave: float = sin(t * freq * TAU) * envelope
		# layered harmonics for richer weapon sounds
		if sound_name == "pulse_fire":
			wave += sin(t * freq * 2.0 * TAU) * envelope * 0.3
		elif sound_name == "scatter_fire":
			wave += randf_range(-0.4, 0.4) * envelope
			wave += sin(t * freq * 0.5 * TAU) * envelope * 0.5
		elif sound_name == "beam_fire":
			wave = sin(t * freq * TAU) * envelope * 0.6
			wave += sin(t * (freq + 50.0) * TAU) * envelope * 0.3
		elif sound_name in ["boss_slam", "enemy_death", "player_damage"]:
			wave += randf_range(-0.3, 0.3) * envelope
		elif sound_name == "boss_warning":
			wave = sin(t * freq * TAU) * envelope
			wave += sin(t * freq * 1.5 * TAU) * envelope * 0.4
		elif sound_name == "room_clear":
			# ascending tone
			var sweep: float = freq + (t / duration) * 200.0
			wave = sin(t * sweep * TAU) * envelope * 0.8
		elif sound_name == "dash":
			# whoosh: noise with descending filter
			wave = randf_range(-0.5, 0.5) * envelope
			wave += sin(t * (freq - t * 1000.0) * TAU) * envelope * 0.3

		wave = clamp(wave, -1.0, 1.0) * 0.4
		data[i] = Vector2(wave, wave)

	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = true

	var byte_data: PackedByteArray = PackedByteArray()
	for sample in data:
		var left: int = int(clamp(sample.x, -1.0, 1.0) * 32767)
		var right: int = int(clamp(sample.y, -1.0, 1.0) * 32767)
		byte_data.append(left & 0xFF)
		byte_data.append((left >> 8) & 0xFF)
		byte_data.append(right & 0xFF)
		byte_data.append((right >> 8) & 0xFF)

	stream.data = byte_data
	return stream


func _freq_for_sound(name: String) -> float:
	match name:
		"pulse_fire": return 880.0
		"scatter_fire": return 440.0
		"beam_fire": return 1200.0
		"enemy_hit": return 660.0
		"enemy_death": return 330.0
		"player_damage": return 220.0
		"boss_slam": return 110.0
		"boss_shockwave": return 165.0
		"boss_phase": return 440.0
		"boss_death": return 220.0
		"ui_select": return 1000.0
		"ui_hover": return 800.0
		"room_clear": return 550.0
		"upgrade_pick": return 700.0
		"run_start": return 330.0
		"boss_warning": return 180.0
		"dash": return 600.0
	return 440.0
