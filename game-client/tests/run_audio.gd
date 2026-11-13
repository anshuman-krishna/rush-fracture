extends SceneTree

# renders every sound effect and one key of the soundtrack, prints a line of
# measurements for each, and optionally writes them out as wav files to
# listen to.
#
#   godot --headless -s res://tests/run_audio.gd -- --out=<dir> --key=hatchery
#
# exits 1 if anything comes out silent, clipped flat or not a number.

var _failed: int = 0


func _init() -> void:
	var out_dir: String = ""
	var place: StringName = &"hatchery"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--key="):
			place = StringName(arg.trim_prefix("--key="))
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)

	var started: int = Time.get_ticks_msec()
	for sound: String in SoundSynth.names():
		var stream: AudioStreamWAV = SoundSynth.render(sound)
		_report(sound, stream, 0.02, 2.5)
		if out_dir != "":
			stream.save_to_wav(out_dir.path_join("sfx_%s.wav" % sound))
	var effects_msec: int = Time.get_ticks_msec() - started

	started = Time.get_ticks_msec()
	var track: Dictionary = MusicSynth.render(MusicSynth.key_for(place))
	var music_msec: int = Time.get_ticks_msec() - started
	for layer: StringName in track:
		_report("music_%s_%s" % [place, layer], track[layer], 10.0, 20.0)
		if out_dir != "":
			(track[layer] as AudioStreamWAV).save_to_wav(out_dir.path_join("music_%s_%s.wav" % [place, layer]))

	print("[audio] %d effects in %d msec, one music key in %d msec, %d failed" % [
		SoundSynth.names().size(), effects_msec, music_msec, _failed])
	quit(1 if _failed > 0 else 0)


func _report(label: String, stream: AudioStreamWAV, min_len: float, max_len: float) -> void:
	var data: PackedByteArray = stream.data
	var count: int = data.size() / 2
	var peak: float = 0.0
	var sum: float = 0.0
	var first: float = 0.0
	var last: float = 0.0
	var steepest: float = 0.0
	for i: int in count:
		var x: float = float(data.decode_s16(i * 2)) / 32767.0
		peak = maxf(peak, absf(x))
		sum += x * x
		if i == 0:
			first = x
		else:
			steepest = maxf(steepest, absf(x - last))
		last = x
	var rms: float = sqrt(sum / float(maxi(1, count)))
	var seconds: float = float(count) / float(stream.mix_rate)
	var problems: PackedStringArray = PackedStringArray()
	if count == 0 or peak < 0.05:
		problems.append("silent")
	if is_nan(rms) or is_inf(rms):
		problems.append("not a number")
	if peak > 0.999 and rms > 0.6:
		problems.append("clipped")
	if seconds < min_len or seconds > max_len:
		problems.append("length %.2fs outside %.2f..%.2f" % [seconds, min_len, max_len])
	# a loop clicks when the step from its last sample back to its first is
	# bigger than any step the sound makes on its own
	if stream.loop_mode != AudioStreamWAV.LOOP_DISABLED and absf(first - last) > steepest * 1.25 + 0.01:
		problems.append("loop seam jumps %.2f (steepest inside %.2f)" % [absf(first - last), steepest])
	if not problems.is_empty():
		_failed += 1
	print("[audio] %-26s %5.2fs  peak %.2f  rms %.3f  %s" % [label, seconds, peak, rms, ", ".join(problems) if not problems.is_empty() else "ok"])
