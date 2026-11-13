class_name SoundSynth
extends RefCounted

# renders sound effects from small recipes: a few layered oscillators or
# noise bursts, each with a pitch sweep, an envelope and optional filtering.
# the game ships no audio files; every sound is built from these at startup.
#
# layer keys (all optional except w, f, d):
#   w     waveform: "sine" | "saw" | "square" | "tri" | "noise"
#   f     start frequency in hz (ignored for noise)
#   f2    end frequency (exponential sweep), default f
#   d     duration in seconds
#   v     volume 0..1, default 1
#   a     attack time in seconds, default 0.002
#   p     decay power: envelope is (1 - t/d)^p. higher = snappier. default 2
#   t0    start offset in seconds
#   lp    low-pass cutoff at the start, hz
#   lp2   low-pass cutoff at the end, default lp
#   hp    high-pass cutoff, hz
#   drive distortion amount (tanh), 0 = clean
#   vib   vibrato depth as a fraction of pitch
#   vr    vibrato rate in hz, default 6
#   fm    frequency-modulation ratio (sine only)
#   fmi   frequency-modulation index, default 2

const SAMPLE_RATE: int = 32000

const RECIPES: Dictionary = {
	# --- weapons ----------------------------------------------------------------
	"pulse_fire": [
		{"w": "square", "f": 880.0, "f2": 220.0, "d": 0.09, "v": 0.5, "p": 3.0, "lp": 6000.0, "lp2": 1500.0},
		{"w": "noise", "d": 0.05, "v": 0.5, "p": 4.0, "hp": 1800.0},
		{"w": "sine", "f": 160.0, "f2": 70.0, "d": 0.1, "v": 0.6, "p": 2.0},
	],
	"scatter_fire": [
		{"w": "noise", "d": 0.22, "v": 0.9, "p": 2.5, "lp": 5000.0, "lp2": 600.0},
		{"w": "sine", "f": 140.0, "f2": 40.0, "d": 0.24, "v": 0.9, "p": 2.0},
		{"w": "saw", "f": 300.0, "f2": 90.0, "d": 0.12, "v": 0.35, "p": 3.0, "drive": 3.0},
	],
	"beam_fire": [
		{"w": "saw", "f": 1320.0, "f2": 1280.0, "d": 0.13, "v": 0.3, "p": 1.0, "lp": 4000.0, "vib": 0.02, "vr": 40.0},
		{"w": "sine", "f": 660.0, "d": 0.13, "v": 0.3, "p": 1.0},
	],
	"needle_fire": [
		{"w": "tri", "f": 1900.0, "f2": 1100.0, "d": 0.05, "v": 0.5, "p": 3.0},
		{"w": "noise", "d": 0.03, "v": 0.35, "p": 4.0, "hp": 3500.0},
	],
	"launcher_fire": [
		{"w": "sine", "f": 220.0, "f2": 55.0, "d": 0.3, "v": 1.0, "p": 2.0},
		{"w": "noise", "d": 0.18, "v": 0.6, "p": 3.0, "lp": 1800.0, "lp2": 300.0},
		{"w": "square", "f": 110.0, "f2": 60.0, "d": 0.15, "v": 0.3, "p": 2.0, "lp": 900.0},
	],
	"rail_fire": [
		{"w": "saw", "f": 2600.0, "f2": 120.0, "d": 0.45, "v": 0.7, "p": 2.0, "lp": 9000.0, "lp2": 700.0, "drive": 2.0},
		{"w": "noise", "d": 0.3, "v": 0.7, "p": 3.0, "hp": 900.0},
		{"w": "sine", "f": 90.0, "f2": 35.0, "d": 0.5, "v": 1.0, "p": 1.5},
	],
	"rail_charge": [
		{"w": "sine", "f": 500.0, "f2": 900.0, "d": 0.1, "v": 0.5, "p": 1.0, "a": 0.02, "fm": 2.0, "fmi": 1.5},
	],
	"arc_fire": [
		{"w": "noise", "d": 0.1, "v": 0.6, "p": 1.5, "hp": 2500.0},
		{"w": "square", "f": 95.0, "f2": 140.0, "d": 0.1, "v": 0.4, "p": 1.0, "drive": 4.0, "lp": 3000.0},
	],
	"disc_fire": [
		{"w": "saw", "f": 420.0, "f2": 950.0, "d": 0.2, "v": 0.5, "p": 1.5, "lp": 5000.0, "vib": 0.05, "vr": 30.0},
		{"w": "noise", "d": 0.08, "v": 0.4, "p": 3.0, "hp": 2000.0},
	],
	"disc_hit": [
		{"w": "saw", "f": 1500.0, "f2": 600.0, "d": 0.09, "v": 0.5, "p": 3.0, "drive": 3.0},
		{"w": "noise", "d": 0.06, "v": 0.5, "p": 3.0, "hp": 3000.0},
	],
	"overheat": [
		{"w": "noise", "d": 0.5, "v": 0.6, "p": 1.5, "hp": 2500.0, "a": 0.02},
		{"w": "sine", "f": 700.0, "f2": 180.0, "d": 0.4, "v": 0.4, "p": 2.0},
	],
	"weapon_swap": [
		{"w": "noise", "d": 0.05, "v": 0.4, "p": 3.0, "lp": 3000.0},
		{"w": "square", "f": 300.0, "f2": 520.0, "d": 0.06, "v": 0.3, "p": 2.0, "t0": 0.04, "lp": 2500.0},
	],
	"ricochet": [
		{"w": "sine", "f": 2400.0, "f2": 900.0, "d": 0.14, "v": 0.5, "p": 2.0},
		{"w": "noise", "d": 0.03, "v": 0.3, "p": 4.0, "hp": 4000.0},
	],
	"explosion": [
		{"w": "noise", "d": 0.7, "v": 1.0, "p": 2.0, "lp": 3500.0, "lp2": 200.0},
		{"w": "sine", "f": 110.0, "f2": 28.0, "d": 0.7, "v": 1.0, "p": 1.5},
		{"w": "noise", "d": 0.12, "v": 0.6, "p": 4.0, "hp": 1500.0},
	],
	"explosion_small": [
		{"w": "noise", "d": 0.32, "v": 0.9, "p": 2.5, "lp": 4000.0, "lp2": 350.0},
		{"w": "sine", "f": 150.0, "f2": 45.0, "d": 0.3, "v": 0.8, "p": 2.0},
	],
	# --- movement ---------------------------------------------------------------
	"step": [{"w": "noise", "d": 0.06, "v": 0.5, "p": 3.0, "lp": 900.0}, {"w": "sine", "f": 110.0, "f2": 60.0, "d": 0.06, "v": 0.4, "p": 3.0}],
	"jump": [{"w": "noise", "d": 0.1, "v": 0.4, "p": 2.0, "lp": 1400.0, "lp2": 2600.0}, {"w": "sine", "f": 200.0, "f2": 330.0, "d": 0.1, "v": 0.3, "p": 2.0}],
	"land": [{"w": "noise", "d": 0.11, "v": 0.6, "p": 3.0, "lp": 800.0}, {"w": "sine", "f": 95.0, "f2": 45.0, "d": 0.13, "v": 0.7, "p": 2.0}],
	"slide": [{"w": "noise", "d": 0.4, "v": 0.5, "p": 1.2, "lp": 2400.0, "lp2": 600.0, "hp": 300.0, "a": 0.03}],
	"dash": [{"w": "noise", "d": 0.22, "v": 0.7, "p": 1.5, "lp": 900.0, "lp2": 5000.0, "a": 0.01}, {"w": "sine", "f": 300.0, "f2": 900.0, "d": 0.16, "v": 0.3, "p": 2.0}],
	"thud": [{"w": "sine", "f": 120.0, "f2": 32.0, "d": 0.35, "v": 1.0, "p": 2.0}, {"w": "noise", "d": 0.14, "v": 0.6, "p": 3.0, "lp": 1200.0}],
	"jump_pad": [{"w": "sine", "f": 220.0, "f2": 880.0, "d": 0.3, "v": 0.6, "p": 1.5, "fm": 2.0, "fmi": 1.0}, {"w": "noise", "d": 0.2, "v": 0.3, "p": 2.0, "hp": 2000.0}],
	# --- combat feedback ----------------------------------------------------------
	"enemy_hit": [{"w": "noise", "d": 0.045, "v": 0.6, "p": 3.0, "hp": 1200.0, "lp": 6000.0}, {"w": "square", "f": 520.0, "f2": 260.0, "d": 0.05, "v": 0.35, "p": 3.0, "lp": 3000.0}],
	"enemy_hit_crit": [{"w": "noise", "d": 0.07, "v": 0.7, "p": 3.0, "hp": 1500.0}, {"w": "square", "f": 1100.0, "f2": 500.0, "d": 0.1, "v": 0.5, "p": 2.5, "lp": 5000.0}, {"w": "sine", "f": 1760.0, "d": 0.12, "v": 0.3, "p": 2.0}],
	"enemy_death": [{"w": "noise", "d": 0.28, "v": 0.7, "p": 2.0, "lp": 2500.0, "lp2": 300.0}, {"w": "saw", "f": 300.0, "f2": 55.0, "d": 0.26, "v": 0.6, "p": 2.0, "lp": 1800.0, "drive": 2.0}],
	"enemy_swing": [{"w": "noise", "d": 0.16, "v": 0.6, "p": 1.5, "lp": 700.0, "lp2": 3500.0, "a": 0.02}],
	"enemy_shot": [{"w": "square", "f": 620.0, "f2": 240.0, "d": 0.14, "v": 0.5, "p": 2.5, "lp": 3500.0}, {"w": "noise", "d": 0.05, "v": 0.3, "p": 4.0, "hp": 2500.0}],
	"enemy_dash": [{"w": "noise", "d": 0.3, "v": 0.7, "p": 1.5, "lp": 500.0, "lp2": 4500.0, "a": 0.02}, {"w": "saw", "f": 110.0, "f2": 260.0, "d": 0.28, "v": 0.4, "p": 1.5, "lp": 1500.0}],
	"spit": [{"w": "noise", "d": 0.2, "v": 0.6, "p": 2.0, "lp": 2500.0, "lp2": 500.0}, {"w": "sine", "f": 420.0, "f2": 130.0, "d": 0.2, "v": 0.5, "p": 2.0, "vib": 0.1, "vr": 25.0}],
	"leap": [{"w": "noise", "d": 0.25, "v": 0.5, "p": 1.5, "lp": 600.0, "lp2": 3000.0}, {"w": "sine", "f": 180.0, "f2": 520.0, "d": 0.25, "v": 0.4, "p": 1.5}],
	"fuse": [{"w": "square", "f": 700.0, "f2": 1900.0, "d": 0.55, "v": 0.45, "p": 0.6, "lp": 5000.0, "vib": 0.08, "vr": 18.0, "a": 0.02}],
	"warp": [{"w": "sine", "f": 1400.0, "f2": 180.0, "d": 0.3, "v": 0.5, "p": 1.5, "fm": 1.5, "fmi": 3.0}, {"w": "noise", "d": 0.2, "v": 0.3, "p": 2.0, "hp": 3000.0}],
	"sniper_lock": [{"w": "sine", "f": 1800.0, "d": 0.08, "v": 0.5, "p": 1.0}, {"w": "sine", "f": 2400.0, "d": 0.08, "v": 0.5, "p": 1.0, "t0": 0.1}],
	"sniper_fire": [{"w": "saw", "f": 1800.0, "f2": 200.0, "d": 0.3, "v": 0.7, "p": 2.5, "drive": 3.0, "lp": 7000.0, "lp2": 900.0}, {"w": "noise", "d": 0.2, "v": 0.6, "p": 3.0, "hp": 1200.0}, {"w": "sine", "f": 100.0, "f2": 40.0, "d": 0.3, "v": 0.8, "p": 2.0}],
	"heal_pulse": [{"w": "sine", "f": 520.0, "f2": 780.0, "d": 0.4, "v": 0.5, "p": 1.5, "a": 0.03}, {"w": "sine", "f": 780.0, "f2": 1040.0, "d": 0.4, "v": 0.3, "p": 1.5, "a": 0.03}],
	"shield_block": [{"w": "tri", "f": 900.0, "f2": 700.0, "d": 0.12, "v": 0.6, "p": 2.5}, {"w": "noise", "d": 0.04, "v": 0.5, "p": 4.0, "hp": 3000.0}],
	"shield_break": [{"w": "noise", "d": 0.4, "v": 0.9, "p": 2.0, "hp": 800.0, "lp": 8000.0, "lp2": 1500.0}, {"w": "tri", "f": 1200.0, "f2": 200.0, "d": 0.35, "v": 0.5, "p": 2.0}],
	"spawn": [{"w": "sine", "f": 90.0, "f2": 260.0, "d": 0.4, "v": 0.6, "p": 1.2, "a": 0.05, "vib": 0.06, "vr": 14.0}, {"w": "noise", "d": 0.3, "v": 0.3, "p": 1.5, "lp": 1200.0, "a": 0.05}],
	"heavy_windup": [{"w": "saw", "f": 60.0, "f2": 150.0, "d": 0.7, "v": 0.8, "p": 0.6, "lp": 500.0, "lp2": 2400.0, "a": 0.1, "drive": 2.0}],
	"wave_incoming": [{"w": "saw", "f": 220.0, "f2": 330.0, "d": 0.35, "v": 0.5, "p": 1.0, "lp": 2500.0, "a": 0.03}, {"w": "saw", "f": 330.0, "f2": 440.0, "d": 0.35, "v": 0.4, "p": 1.0, "lp": 2500.0, "t0": 0.18}],
	"player_damage": [{"w": "noise", "d": 0.2, "v": 0.8, "p": 2.5, "lp": 2200.0, "lp2": 400.0}, {"w": "sine", "f": 150.0, "f2": 60.0, "d": 0.22, "v": 0.9, "p": 2.0}, {"w": "square", "f": 320.0, "f2": 120.0, "d": 0.14, "v": 0.3, "p": 2.0, "drive": 3.0, "lp": 2000.0}],
	"pickup": [{"w": "sine", "f": 1100.0, "f2": 1650.0, "d": 0.09, "v": 0.5, "p": 2.0}],
	"heal": [{"w": "sine", "f": 660.0, "d": 0.16, "v": 0.5, "p": 1.5}, {"w": "sine", "f": 990.0, "d": 0.22, "v": 0.5, "p": 1.5, "t0": 0.08}],
	"wall_break": [{"w": "noise", "d": 0.4, "v": 0.9, "p": 2.0, "lp": 3000.0, "lp2": 400.0}, {"w": "tri", "f": 240.0, "f2": 70.0, "d": 0.3, "v": 0.6, "p": 2.0}],
	# --- bosses and events ---------------------------------------------------------
	"boss_slam": [{"w": "sine", "f": 90.0, "f2": 24.0, "d": 0.9, "v": 1.0, "p": 1.5}, {"w": "noise", "d": 0.6, "v": 0.9, "p": 2.0, "lp": 2000.0, "lp2": 150.0}, {"w": "noise", "d": 0.1, "v": 0.6, "p": 4.0, "hp": 1500.0}],
	"boss_shockwave": [{"w": "noise", "d": 0.8, "v": 0.7, "p": 1.2, "lp": 400.0, "lp2": 3500.0, "a": 0.05}, {"w": "saw", "f": 70.0, "f2": 200.0, "d": 0.7, "v": 0.5, "p": 1.2, "lp": 900.0}],
	"boss_phase": [{"w": "saw", "f": 55.0, "f2": 220.0, "d": 1.1, "v": 0.8, "p": 0.8, "lp": 300.0, "lp2": 5000.0, "drive": 3.0, "a": 0.05}, {"w": "noise", "d": 0.9, "v": 0.5, "p": 1.0, "hp": 1000.0, "a": 0.3}],
	"boss_death": [{"w": "saw", "f": 440.0, "f2": 30.0, "d": 1.6, "v": 0.8, "p": 1.0, "lp": 5000.0, "lp2": 200.0, "drive": 2.5}, {"w": "noise", "d": 1.4, "v": 0.7, "p": 1.5, "lp": 3000.0, "lp2": 200.0}, {"w": "sine", "f": 80.0, "f2": 25.0, "d": 1.6, "v": 1.0, "p": 1.2}],
	"boss_warning": [{"w": "saw", "f": 110.0, "d": 0.5, "v": 0.7, "p": 0.8, "lp": 1200.0, "drive": 3.0, "a": 0.03}, {"w": "saw", "f": 104.0, "d": 0.5, "v": 0.7, "p": 0.8, "lp": 1200.0, "drive": 3.0, "t0": 0.55, "a": 0.03}, {"w": "saw", "f": 98.0, "f2": 55.0, "d": 0.9, "v": 0.8, "p": 1.0, "lp": 1500.0, "drive": 3.0, "t0": 1.1, "a": 0.03}],
	"fracture": [{"w": "sine", "f": 220.0, "f2": 1760.0, "d": 0.7, "v": 0.5, "p": 1.0, "fm": 3.5, "fmi": 4.0, "a": 0.05}, {"w": "noise", "d": 0.6, "v": 0.4, "p": 1.2, "hp": 2000.0, "a": 0.2}],
	# --- ui and run events ---------------------------------------------------------
	"ui_hover": [{"w": "sine", "f": 1400.0, "d": 0.03, "v": 0.4, "p": 2.0}],
	"ui_select": [{"w": "sine", "f": 880.0, "d": 0.05, "v": 0.5, "p": 2.0}, {"w": "sine", "f": 1320.0, "d": 0.08, "v": 0.5, "p": 2.0, "t0": 0.04}],
	"ui_deny": [{"w": "square", "f": 180.0, "d": 0.08, "v": 0.5, "p": 1.5, "lp": 1200.0}, {"w": "square", "f": 140.0, "d": 0.12, "v": 0.5, "p": 1.5, "lp": 1200.0, "t0": 0.09}],
	"room_clear": [{"w": "sine", "f": 523.0, "d": 0.16, "v": 0.5, "p": 1.5}, {"w": "sine", "f": 659.0, "d": 0.16, "v": 0.5, "p": 1.5, "t0": 0.1}, {"w": "sine", "f": 784.0, "d": 0.4, "v": 0.5, "p": 1.5, "t0": 0.2}],
	"upgrade_pick": [{"w": "sine", "f": 660.0, "d": 0.12, "v": 0.5, "p": 1.5}, {"w": "sine", "f": 990.0, "d": 0.14, "v": 0.5, "p": 1.5, "t0": 0.07}, {"w": "sine", "f": 1320.0, "d": 0.3, "v": 0.5, "p": 1.5, "t0": 0.14, "fm": 2.0, "fmi": 0.8}],
	"mutation_pick": [{"w": "saw", "f": 220.0, "f2": 110.0, "d": 0.5, "v": 0.6, "p": 1.2, "lp": 2500.0, "lp2": 500.0, "drive": 2.0}, {"w": "sine", "f": 660.0, "f2": 330.0, "d": 0.5, "v": 0.4, "p": 1.5, "fm": 1.5, "fmi": 3.0}],
	"run_start": [{"w": "saw", "f": 110.0, "f2": 440.0, "d": 0.6, "v": 0.6, "p": 0.8, "lp": 400.0, "lp2": 5000.0, "a": 0.05}, {"w": "noise", "d": 0.5, "v": 0.3, "p": 1.0, "hp": 2500.0, "a": 0.3}],
}

static func has_recipe(sound: String) -> bool:
	return RECIPES.has(sound)


static func names() -> Array:
	return RECIPES.keys()


## renders a named sound, or a short generic blip for a name with no recipe.
static func render(sound: String) -> AudioStreamWAV:
	var layers: Array = RECIPES.get(sound, [{"w": "sine", "f": 600.0, "f2": 400.0, "d": 0.08, "v": 0.4}])
	return render_layers(layers)


static func render_layers(layers: Array) -> AudioStreamWAV:
	var length: float = 0.0
	for layer: Dictionary in layers:
		length = maxf(length, float(layer.get("t0", 0.0)) + float(layer.get("d", 0.1)))
	var total: int = int(length * SAMPLE_RATE) + 64
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(total)
	for layer: Dictionary in layers:
		_add_layer(buf, layer)
	# every effect leaves here at the same peak, so how loud it plays is
	# decided in one place: the volume the caller asks for
	return to_stream(buf, SAMPLE_RATE, false, true)


## packs a float buffer into a 16-bit mono stream, normalised to a safe peak.
## with level_out the result is scaled up as well as down, so every buffer
## ends at the same peak whatever went into it.
static func to_stream(buf: PackedFloat32Array, rate: int, loop: bool = false, level_out: bool = false) -> AudioStreamWAV:
	var peak: float = 0.0001
	for x: float in buf:
		peak = maxf(peak, absf(x))
	var gain: float = 0.85 / peak if peak > 0.85 or level_out else 1.0
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i: int in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i] * gain, -1.0, 1.0) * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = buf.size()
	return stream


static func _add_layer(buf: PackedFloat32Array, layer: Dictionary) -> void:
	var wave: String = layer.get("w", "sine")
	var dur: float = maxf(0.005, layer.get("d", 0.1))
	var n: int = int(dur * SAMPLE_RATE)
	var start: int = int(float(layer.get("t0", 0.0)) * SAMPLE_RATE)
	var vol: float = layer.get("v", 1.0)
	var attack: float = maxf(0.0005, layer.get("a", 0.002))
	var power: float = layer.get("p", 2.0)
	var f: float = maxf(1.0, layer.get("f", 440.0))
	var f2: float = maxf(1.0, layer.get("f2", f))
	var sweep: float = pow(f2 / f, 1.0 / float(n))
	var lp: float = layer.get("lp", 0.0)
	var lp2: float = layer.get("lp2", lp)
	var hp: float = layer.get("hp", 0.0)
	var drive: float = layer.get("drive", 0.0)
	var vib: float = layer.get("vib", 0.0)
	var vib_rate: float = layer.get("vr", 6.0)
	var fm: float = layer.get("fm", 0.0)
	var fmi: float = layer.get("fmi", 2.0)

	var phase: float = 0.0
	var freq: float = f
	var lp_y: float = 0.0
	var lp_coef: float = 1.0
	var hp_y: float = 0.0
	var hp_prev: float = 0.0
	var hp_alpha: float = 1.0 / (1.0 + TAU * hp / float(SAMPLE_RATE)) if hp > 0.0 else 0.0
	var inv_rate: float = 1.0 / float(SAMPLE_RATE)
	var limit: int = mini(n, buf.size() - start)
	# each layer carries its own noise state: the same recipe always renders
	# the same samples, and layers on different threads never share it
	var noise: int = (22222 + start * 31 + n * 7) & 0x7fffffff

	for i: int in limit:
		var t: float = float(i) * inv_rate
		var u: float = float(i) / float(n)
		var x: float = 0.0
		if wave == "noise":
			noise = (noise * 1103515245 + 12345) & 0x7fffffff
			x = float(noise) / 1073741824.0 - 1.0
		else:
			var inst: float = freq
			if vib > 0.0:
				inst *= 1.0 + vib * sin(TAU * vib_rate * t)
			phase += inst * inv_rate
			var frac: float = phase - floorf(phase)
			match wave:
				"saw":
					x = 2.0 * frac - 1.0
				"square":
					x = 1.0 if frac < 0.5 else -1.0
				"tri":
					x = 4.0 * absf(frac - 0.5) - 1.0
				_:
					x = sin(TAU * phase + (fmi * sin(TAU * phase * fm) if fm > 0.0 else 0.0))
			freq *= sweep

		var env: float = minf(1.0, t / attack) * pow(1.0 - u, power)
		x *= env
		if lp > 0.0:
			if i % 32 == 0:
				var cutoff: float = lerpf(lp, lp2, u)
				lp_coef = 1.0 - exp(-TAU * cutoff * inv_rate)
			lp_y += lp_coef * (x - lp_y)
			x = lp_y
		if hp > 0.0:
			hp_y = hp_alpha * (hp_y + x - hp_prev)
			hp_prev = x
			x = hp_y
		if drive > 0.0:
			x = tanh(x * (1.0 + drive))
		buf[start + i] += x * vol
