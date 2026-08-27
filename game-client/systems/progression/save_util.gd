class_name SaveUtil
extends RefCounted

# atomic config save. write-then-rename so a crash or power loss mid-write
# can't leave a corrupted save file — the old file is only replaced once
# the new one is fully written to disk.

const SAVE_FORMAT_VERSION: int = 1


static func save_atomic(config: ConfigFile, path: String) -> Error:
	var tmp_path: String = path + ".tmp"
	var err: Error = config.save(tmp_path)
	if err != OK:
		push_error("save write failed")
		return err

	var dir: DirAccess = DirAccess.open(path.get_base_dir())
	if not dir:
		push_error("save dir open failed")
		return ERR_UNAVAILABLE

	var rename_err: Error = dir.rename(tmp_path, path)
	if rename_err != OK:
		push_error("save rename failed")
	return rename_err
