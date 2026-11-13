class_name MusicSynth
extends RefCounted

# generates the soundtrack: one eight-bar loop per key, rendered as three
# layers that play in sync so the mix can follow the action.
#
#   pad    slow chords. always on: the room's mood
#   drive  bass, kick, snare and hats. fades in when a fight starts
#   lead   a sixteenth-note arpeggio. added for bosses
#
# the progression is i - VI - III - VII in a minor key, two bars per chord.

const SAMPLE_RATE: int = 22050
const BPM: float = 124.0
const BARS: int = 8
const BEATS_PER_BAR: int = 4

# chord tones as semitone offsets from the key's root
const CHORDS: Array = [[0, 3, 7], [-4, 0, 3], [3, 7, 10], [-2, 2, 5]]
const ARP_PATTERN: Array[int] = [0, 1, 2, 1, 0, 2, 1, 2]

## midi note of the root for each place the music plays
const KEYS: Dictionary = {
	&"menu": 45,
	&"hatchery": 50,
	&"marrow": 53,
	&"fracture": 48,
}


static func key_for(place: StringName) -> int:
	return KEYS.get(place, 48)


static func _hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


static func total_samples() -> int:
	var beat: float = 60.0 / BPM
	return int(beat * BEATS_PER_BAR * BARS * SAMPLE_RATE)


## renders all three layers for a key. slow (a few seconds); call off the main thread.
static func render(root_midi: int) -> Dictionary:
	return {
		&"pad": SoundSynth.to_stream(_pad(root_midi), SAMPLE_RATE, true, true),
		&"drive": SoundSynth.to_stream(_drive(root_midi), SAMPLE_RATE, true, true),
		&"lead": SoundSynth.to_stream(_lead(root_midi), SAMPLE_RATE, true, true),
	}


static func _pad(root: int) -> PackedFloat32Array:
	var n: int = total_samples()
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(n)
	var chord_len: int = n / CHORDS.size()
	var fade: int = int(0.55 * SAMPLE_RATE)
	var inv: float = 1.0 / float(SAMPLE_RATE)

	for c: int in CHORDS.size():
		var tones: Array = CHORDS[c]
		# each tone is two slightly detuned triangles: a soft, wide chord
		var incs: PackedFloat32Array = PackedFloat32Array()
		for tone: int in tones:
			var f: float = _hz(float(root + tone))
			incs.append(f * 0.997 * inv)
			incs.append(f * 1.004 * inv)
		incs.append(_hz(float(root + tones[0] - 12)) * inv)
		var phases: PackedFloat32Array = PackedFloat32Array()
		phases.resize(incs.size())
		var lp: float = 0.0
		# the chord rings a little past its slot so neighbours overlap
		var start: int = c * chord_len
		for i: int in chord_len + fade:
			var env: float = 1.0
			if i < fade:
				env = float(i) / float(fade)
			elif i > chord_len:
				env = 1.0 - float(i - chord_len) / float(fade)
			var x: float = 0.0
			for k: int in incs.size():
				phases[k] += incs[k]
				var frac: float = phases[k] - floorf(phases[k])
				x += 4.0 * absf(frac - 0.5) - 1.0
			# slow swell on top of the chord
			var swell: float = 0.75 + 0.25 * sin(TAU * float(i) / float(chord_len))
			lp += 0.09 * (x - lp)
			buf[(start + i) % n] += lp * env * swell * 0.14
	return buf


static func _drive(root: int) -> PackedFloat32Array:
	var n: int = total_samples()
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(n)
	var beat: float = 60.0 / BPM
	var beat_samples: float = beat * SAMPLE_RATE
	var total_beats: int = BARS * BEATS_PER_BAR
	var inv: float = 1.0 / float(SAMPLE_RATE)
	var noise: int = 9001

	for b: int in total_beats:
		var chord: Array = CHORDS[(b / (BEATS_PER_BAR * 2)) % CHORDS.size()]
		var beat_start: int = int(float(b) * beat_samples)

		# kick on every beat
		var kick_len: int = int(0.2 * SAMPLE_RATE)
		var phase: float = 0.0
		for i: int in kick_len:
			var u: float = float(i) / float(kick_len)
			phase += lerpf(150.0, 42.0, minf(1.0, u * 3.0)) * inv
			buf[(beat_start + i) % n] += sin(TAU * phase) * pow(1.0 - u, 2.0) * 0.9

		# snare on beats two and four
		if b % 2 == 1:
			var snare_len: int = int(0.14 * SAMPLE_RATE)
			var prev: float = 0.0
			for i: int in snare_len:
				var u2: float = float(i) / float(snare_len)
				noise = (noise * 1103515245 + 12345) & 0x7fffffff
				var w: float = float(noise) / 1073741824.0 - 1.0
				var hp: float = w - prev
				prev = w
				buf[(beat_start + i) % n] += (hp * 0.35 + sin(TAU * 190.0 * float(i) * inv) * 0.25) * pow(1.0 - u2, 2.5)

		# eighth notes: bass on both, a hat on the off one
		for e: int in 2:
			var at: int = beat_start + int(float(e) * beat_samples * 0.5)
			var bass_f: float = _hz(float(root + chord[0] - 24 + (12 if e == 1 and b % 4 == 3 else 0)))
			var bass_len: int = int(0.2 * SAMPLE_RATE)
			var bp: float = 0.0
			var blp: float = 0.0
			for i: int in bass_len:
				var u3: float = float(i) / float(bass_len)
				bp += bass_f * inv
				var frac: float = bp - floorf(bp)
				var saw: float = 2.0 * frac - 1.0
				blp += lerpf(0.35, 0.06, u3) * (saw - blp)
				buf[(at + i) % n] += blp * pow(1.0 - u3, 1.2) * 0.55
			if e == 1:
				var hat_len: int = int(0.035 * SAMPLE_RATE)
				var hprev: float = 0.0
				for i: int in hat_len:
					noise = (noise * 1103515245 + 12345) & 0x7fffffff
					var w2: float = float(noise) / 1073741824.0 - 1.0
					var h: float = w2 - hprev
					hprev = w2
					buf[(at + i) % n] += h * (1.0 - float(i) / float(hat_len)) * 0.16
	return buf


static func _lead(root: int) -> PackedFloat32Array:
	var n: int = total_samples()
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(n)
	var beat_samples: float = 60.0 / BPM * SAMPLE_RATE
	var step_samples: float = beat_samples * 0.25
	var steps: int = BARS * BEATS_PER_BAR * 4
	var inv: float = 1.0 / float(SAMPLE_RATE)
	var note_len: int = int(0.16 * SAMPLE_RATE)

	for s: int in steps:
		var chord: Array = CHORDS[(s / (BEATS_PER_BAR * 2 * 4)) % CHORDS.size()]
		var tone: int = chord[ARP_PATTERN[s % ARP_PATTERN.size()]]
		# lift every other bar an octave so the line climbs and falls
		var octave: int = 12 if (s / 16) % 2 == 0 else 24
		var f: float = _hz(float(root + tone + octave))
		var at: int = int(float(s) * step_samples)
		var phase: float = 0.0
		var lp: float = 0.0
		for i: int in note_len:
			var u: float = float(i) / float(note_len)
			phase += f * inv
			var frac: float = phase - floorf(phase)
			var sq: float = 1.0 if frac < 0.35 else -1.0
			lp += 0.3 * (sq - lp)
			buf[(at + i) % n] += lp * pow(1.0 - u, 1.8) * 0.3
	return buf
