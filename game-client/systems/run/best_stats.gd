class_name BestStats
extends RefCounted

# tracks best run stats across sessions. persists to user://best_stats.cfg.

const SAVE_PATH := "user://best_stats.cfg"

var best_kills: int = 0
var best_combo: int = 0
var best_time: float = 0.0
var total_runs: int = 0
var runs_completed: int = 0


static func load_stats() -> BestStats:
	var stats: BestStats = BestStats.new()
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return stats

	stats.best_kills = config.get_value("stats", "best_kills", 0)
	stats.best_combo = config.get_value("stats", "best_combo", 0)
	stats.best_time = config.get_value("stats", "best_time", 0.0)
	stats.total_runs = config.get_value("stats", "total_runs", 0)
	stats.runs_completed = config.get_value("stats", "runs_completed", 0)
	return stats


static func update_from_run(data: RunData, combo_best: int) -> void:
	var stats: BestStats = load_stats()

	stats.total_runs += 1
	if data.status == RunData.RunStatus.COMPLETED:
		stats.runs_completed += 1

	if data.total_enemies_killed > stats.best_kills:
		stats.best_kills = data.total_enemies_killed
	if combo_best > stats.best_combo:
		stats.best_combo = combo_best
	if data.status == RunData.RunStatus.COMPLETED:
		if stats.best_time <= 0 or data.elapsed_time < stats.best_time:
			stats.best_time = data.elapsed_time

	_save(stats)


static func _save(stats: BestStats) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("stats", "best_kills", stats.best_kills)
	config.set_value("stats", "best_combo", stats.best_combo)
	config.set_value("stats", "best_time", stats.best_time)
	config.set_value("stats", "total_runs", stats.total_runs)
	config.set_value("stats", "runs_completed", stats.runs_completed)
	config.save(SAVE_PATH)
