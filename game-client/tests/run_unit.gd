extends SceneTree

# runs every tests/unit/test_*.gd file.
#
#   godot --headless --path game-client -s res://tests/run_unit.gd [-- --only=name]
#
# exits 0 when every check passes, 1 otherwise.

const UNIT_DIR: String = "res://tests/unit"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var only: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.substr(7)

	# saves must never touch a real profile
	PlayerProfile.save_path = "user://unit_test_profile.cfg"
	GameSettings.save_path = "user://unit_test_settings.cfg"

	var files: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(UNIT_DIR)
	if dir:
		for f: String in dir.get_files():
			if f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd":
				if only.is_empty() or f.contains(only):
					files.append(f)
	files.sort()

	var total_tests: int = 0
	var total_checks: int = 0
	var failed: int = 0
	for file: String in files:
		var script: Script = load("%s/%s" % [UNIT_DIR, file]) as Script
		if not script:
			print("[unit] FAIL %s: could not load" % file)
			failed += 1
			continue
		var names: PackedStringArray = PackedStringArray()
		for m: Dictionary in script.get_script_method_list():
			if String(m.name).begins_with("test_"):
				names.append(m.name)
		names.sort()
		for method: String in names:
			var case: RefCounted = script.new()
			case.before_each()
			case.call(method)
			case.after_each()
			total_tests += 1
			total_checks += case.checks
			if case.failures.is_empty():
				continue
			failed += 1
			print("[unit] FAIL %s :: %s" % [file, method])
			for msg: String in case.failures:
				print("[unit]      %s" % msg)

	for path: String in [PlayerProfile.save_path, GameSettings.save_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	print("[unit] %d files, %d tests, %d checks, %d failed" % [files.size(), total_tests, total_checks, failed])
	print("[unit] %s" % ("PASS" if failed == 0 and total_tests > 0 else "FAIL"))
	quit(0 if failed == 0 and total_tests > 0 else 1)
