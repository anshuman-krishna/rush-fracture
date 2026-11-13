extends "res://tests/unit/test_case.gd"

# saving, loading and spending: the profile, the shard shop, run rewards.


func before_each() -> void:
	_wipe()


func after_each() -> void:
	_wipe()


func _wipe() -> void:
	if FileAccess.file_exists(PlayerProfile.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PlayerProfile.save_path))
	if FileAccess.file_exists(GameSettings.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.save_path))


func _finished_run(mode: StringName = RunData.MODE_STANDARD, won: bool = true) -> RunData:
	var data: RunData = RunData.new()
	data.mode = mode
	data.status = RunData.RunStatus.COMPLETED if won else RunData.RunStatus.FAILED
	data.total_enemies_killed = 100
	data.rooms_cleared = 15
	data.bosses_defeated = 3
	data.elites_killed = 4
	data.elapsed_time = 900.0
	data.essence = 55
	data.essence_earned = 300
	return data


func test_fresh_profile_defaults() -> void:
	var p: PlayerProfile = PlayerProfile.load_profile()
	eq(p.fracture_shards, 0, "no shards")
	eq(p.loadout, WeaponDefs.DEFAULT_LOADOUT, "default loadout")
	eq(p.skin, &"default", "default skin")
	check(p.owns_weapon(&"pulse_rifle"), "starter weapons are owned")
	check(not p.owns_weapon(&"ripper"), "paid weapons are not")


func test_save_and_load_roundtrip() -> void:
	var p: PlayerProfile = PlayerProfile.load_profile()
	p.total_kills = 321
	p.best_time = 612.5
	p.fracture_shards = 777
	p.meta_upgrades["damage_boost"] = 4
	p.unlocks["ripper"] = true
	p.unlocks["skin:void"] = true
	p.unlocks["scavenger"] = true
	p.achievements["first_blood"] = true
	p.skin = &"void"
	p.ascension_unlocked = 3
	p.ascension_selected = 2
	p.loadout = [&"ripper", &"pulse_rifle", &"beam_emitter"]
	p.daily_last_played = "2026-11-13"
	p.save()

	var q: PlayerProfile = PlayerProfile.load_profile()
	eq(q.total_kills, 321, "kills")
	near(q.best_time, 612.5, "best time")
	eq(q.fracture_shards, 777, "shards")
	eq(q.get_meta_level("damage_boost"), 4, "meta level")
	check(q.has_unlock("ripper") and q.has_unlock("scavenger"), "unlocks")
	check(q.achievements.has("first_blood"), "achievements")
	eq(q.skin, &"void", "skin")
	eq(q.ascension_unlocked, 3, "ascension unlocked")
	eq(q.ascension_selected, 2, "ascension selected")
	eq(q.loadout, [&"ripper", &"pulse_rifle", &"beam_emitter"] as Array[StringName], "loadout")
	eq(q.daily_last_played, "2026-11-13", "daily key")


func test_load_repairs_a_bad_save() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("stats", "total_kills", "lots")
	cfg.set_value("currency", "fracture_shards", -500)
	cfg.set_value("cosmetics", "skin", "void")
	cfg.set_value("loadout", "weapons", PackedStringArray(["ripper", "nonsense", "pulse_rifle"]))
	cfg.set_value("ascension", "unlocked", 99)
	cfg.set_value("ascension", "selected", 50)
	cfg.set_value("meta", "upgrade_keys", 12)
	cfg.save(PlayerProfile.save_path)

	var p: PlayerProfile = PlayerProfile.load_profile()
	eq(p.total_kills, 0, "a non-number stat falls back")
	eq(p.fracture_shards, 0, "negative currency is clamped")
	eq(p.skin, &"default", "an unowned skin is not equipped")
	eq(p.ascension_unlocked, MetaProgression.MAX_ASCENSION, "ascension is clamped to the maximum")
	eq(p.ascension_selected, MetaProgression.MAX_ASCENSION, "selected tier cannot exceed unlocked")
	eq(p.loadout.size(), WeaponDefs.LOADOUT_SIZE, "loadout is always full")
	check(not p.loadout.has(&"ripper"), "an unowned weapon is removed from the loadout")
	eq(p.meta_upgrades.size(), 0, "a malformed key list is ignored")


func test_loadout_slot_swaps() -> void:
	var p: PlayerProfile = PlayerProfile.load_profile()
	p.set_loadout_slot(0, &"beam_emitter")
	eq(p.loadout, [&"beam_emitter", &"scatter_cannon", &"pulse_rifle"] as Array[StringName], "equipping an already-equipped weapon swaps slots")
	p.set_loadout_slot(1, &"ripper")
	eq(p.loadout[1], &"scatter_cannon", "cannot equip a weapon that is not owned")
	p.unlocks["ripper"] = true
	p.set_loadout_slot(1, &"ripper")
	eq(p.loadout[1], &"ripper", "an owned weapon equips")


func test_meta_purchase() -> void:
	var p: PlayerProfile = PlayerProfile.load_profile()
	check(not MetaProgression.can_purchase(p, "damage_boost"), "cannot buy with no shards")
	check(not MetaProgression.purchase(p, "damage_boost"), "purchase fails with no shards")
	var cost: int = MetaProgression.get_upgrade_cost("damage_boost", 0)
	p.fracture_shards = cost
	check(MetaProgression.purchase(p, "damage_boost"), "purchase succeeds with exactly enough")
	eq(p.fracture_shards, 0, "shards are spent")
	eq(p.get_meta_level("damage_boost"), 1, "level went up")
	check(MetaProgression.get_upgrade_cost("damage_boost", 1) > cost, "the next level costs more")
	p.fracture_shards = 9999999
	for i: int in 30:
		MetaProgression.purchase(p, "damage_boost")
	eq(p.get_meta_level("damage_boost"), MetaProgression.get_upgrade_max_level("damage_boost"), "stops at max level")
	eq(MetaProgression.get_upgrade_cost("no_such_upgrade", 0), 999999, "unknown upgrade is unaffordable")
	check(not MetaProgression.purchase(p, "no_such_upgrade"), "unknown upgrade cannot be bought")


func test_meta_bonuses_reach_the_stats() -> void:
	var p: PlayerProfile = PlayerProfile.load_profile()
	p.meta_upgrades = {"damage_boost": 10, "health_boost": 5, "dash_boost": 5, "armor_plating": 8, "weapon_swap_speed": 3}
	var player: Node = (load("res://systems/player/player_controller.gd") as Script).new()
	MetaProgression.apply_to_stats(p, player.stats)
	near(player.stats.value(&"damage"), 1.3, "ten levels of +3% damage")
	near(player.stats.value(&"max_health"), 140.0, "five levels of +8 health")
	near(player.stats.value(&"dash_cooldown"), 0.6 * 0.85, "five levels of -3% dash cooldown")
	near(player.stats.value(&"damage_taken"), 0.84, "eight levels of -2% damage taken")
	near(player.stats.value(&"swap_speed"), 1.75, "weapon swap speed finally does something")
	player.free()


func test_unlock_rules() -> void:
	var p: PlayerProfile = PlayerProfile.load_profile()
	p.fracture_shards = 100000
	check(not MetaProgression.can_unlock(p, "ripper"), "shards alone do not bypass the requirement")
	p.total_kills = 800
	check(MetaProgression.can_unlock(p, "ripper"), "requirement met and affordable")
	check(MetaProgression.purchase_unlock(p, "ripper"), "unlock purchase succeeds")
	check(p.owns_weapon(&"ripper"), "the weapon is now owned")
	check(not MetaProgression.can_unlock(p, "ripper"), "cannot buy the same unlock twice")
	check(not MetaProgression.can_unlock(p, "does_not_exist"), "unknown unlock cannot be bought")
	p.fracture_shards = 0
	check(not MetaProgression.can_unlock(p, "skin:ember"), "cannot unlock with no shards")


func test_unparseable_requirement_fails_closed() -> void:
	var p: PlayerProfile = PlayerProfile.load_profile()
	check(MetaProgression._check_requirement(p, ""), "no requirement is always met")
	check(not MetaProgression._check_requirement(p, "total_kills"), "a truncated requirement is not met")
	check(not MetaProgression._check_requirement(p, "total_kills > 5"), "an unsupported operator is not met")
	check(not MetaProgression._check_requirement(p, "made_up_stat >= 0"), "an unknown field is not met")
	p.total_kills = 10
	check(MetaProgression._check_requirement(p, "total_kills >= 10"), "a valid requirement at the threshold is met")
	check(not MetaProgression._check_requirement(p, "total_kills >= 11"), "one short is not met")


func test_shard_calculation() -> void:
	var data: RunData = _finished_run()
	var b: Dictionary = MetaProgression.calculate_shards(data, 12, false)
	eq(b.kills, 100, "one per kill")
	eq(b.rooms, 75, "five per room")
	eq(b.bosses, 60, "twenty per boss")
	eq(b.elites, 12, "three per elite")
	eq(b.completed, 60, "standard completion bonus")
	eq(b.combo_bonus, 10, "combo bonus")
	eq(b.essence, 5, "unspent essence converts ten to one")
	eq(b.total, 322, "sum of the parts")
	check(not b.has("ascension"), "no ascension bonus at tier 0")

	data.ascension = 5
	var hard: Dictionary = MetaProgression.calculate_shards(data, 12, false)
	eq(hard.ascension, 322, "+20% per tier at tier five doubles it")
	eq(hard.total, 644, "ascension total")

	var lost: Dictionary = MetaProgression.calculate_shards(_finished_run(RunData.MODE_STANDARD, false), 0, false)
	check(not lost.has("completed"), "no completion bonus for a failed run")


func test_run_updates_profile_and_ascension() -> void:
	var p: PlayerProfile = PlayerProfile.load_profile()
	p.update_from_run(_finished_run(), 18, false)
	eq(p.total_runs, 1, "run counted")
	eq(p.runs_completed, 1, "completion counted")
	eq(p.total_kills, 100, "kills added")
	eq(p.bosses_defeated, 3, "bosses added")
	eq(p.best_combo, 18, "combo recorded")
	near(p.best_time, 900.0, "best time recorded")
	eq(p.ascension_unlocked, 1, "winning at your highest tier opens the next")

	p.update_from_run(_finished_run(), 5, false)
	eq(p.ascension_unlocked, 1, "winning below your highest tier opens nothing")
	var failed: RunData = _finished_run(RunData.MODE_STANDARD, false)
	failed.ascension = 1
	p.update_from_run(failed, 5, false)
	eq(p.ascension_unlocked, 1, "losing opens nothing")
	eq(p.runs_completed, 2, "a failed run is not a completion")

	var endless: RunData = _finished_run(RunData.MODE_ENDLESS, false)
	endless.rooms_cleared = 23
	p.update_from_run(endless, 0, false)
	eq(p.endless_best_depth, 23, "endless depth recorded")


func test_achievements_grant_once() -> void:
	var p: PlayerProfile = PlayerProfile.load_profile()
	var data: RunData = _finished_run()
	var first: Array[Dictionary] = MetaProgression.check_achievements(p, data, 30, {"bosses_killed": [&"warden", &"titan"], "flawless_boss": true})
	var ids: Array = first.map(func(a: Dictionary) -> String: return a.id)
	check(ids.has("first_blood") and ids.has("gatekeeper") and ids.has("titanfall"), "run and boss achievements earned")
	check(ids.has("untouchable") and ids.has("chain_25"), "flawless and combo achievements earned")
	check(not ids.has("regicide"), "no achievement for a boss that was not killed")
	check(p.fracture_shards > 0, "achievements pay shards")
	var shards: int = p.fracture_shards
	var again: Array[Dictionary] = MetaProgression.check_achievements(p, data, 30, {"bosses_killed": [&"warden", &"titan"], "flawless_boss": true})
	eq(again.size(), 0, "nothing is earned twice")
	eq(p.fracture_shards, shards, "and nothing is paid twice")


func test_settings_roundtrip_and_clamping() -> void:
	var s: GameSettings = GameSettings.load_settings()
	near(s.fov, 90.0, "default fov")
	s.fov = 110.0
	s.screen_shake = 0.25
	s.damage_numbers = false
	s.quality = 1
	s.key_bindings["dash"] = KEY_F
	s.save()
	var t: GameSettings = GameSettings.load_settings()
	near(t.fov, 110.0, "fov saved")
	near(t.screen_shake, 0.25, "shake saved")
	check(not t.damage_numbers, "toggle saved")
	eq(t.quality, 1, "quality saved")
	eq(t.key_bindings.get("dash"), KEY_F, "key binding saved")

	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("display", "fov", 9000.0)
	cfg.set_value("input", "mouse_sensitivity", "fast")
	cfg.set_value("audio", "master_volume", -3.0)
	cfg.save(GameSettings.save_path)
	var bad: GameSettings = GameSettings.load_settings()
	near(bad.fov, 120.0, "fov clamped to its maximum")
	near(bad.mouse_sensitivity, 0.002, "a non-number sensitivity falls back")
	near(bad.master_volume, 0.0, "volume clamped to zero")
