extends "res://tests/unit/test_case.gd"

# catalogue integrity: every upgrade, mutation, weapon, enemy, boss and
# unlock that the game offers must be backed by something real. the project
# once shipped upgrades and shop items that did nothing at all; these tests
# fail the moment a catalogue entry points at an effect that does not exist.

const PLAYER_SCRIPT: String = "res://systems/player/player_controller.gd"


func _player_stats() -> StatBlock:
	var player: Node = (load(PLAYER_SCRIPT) as Script).new()
	var stats: StatBlock = player.stats
	player.free()
	return stats


func _source(path: String) -> String:
	var script: Script = load(path) as Script
	return script.source_code if script else ""


func test_upgrade_ids_are_unique_and_complete() -> void:
	var seen: Dictionary = {}
	for u: Dictionary in UpgradeDefinitions.CATALOG:
		var id: StringName = u.get("id", &"")
		check(id != &"", "upgrade has an id")
		check(not seen.has(id), "upgrade id '%s' is unique" % id)
		seen[id] = true
		check(String(u.get("name", "")).length() > 0, "%s has a name" % id)
		check(String(u.get("description", "")).length() > 0, "%s has a description" % id)
		check(UpgradeDefinitions.RARITY_WEIGHT.has(u.get("rarity", &"")), "%s has a known rarity" % id)
		check(UpgradeDefinitions.max_stacks(u) >= 1, "%s can be taken at least once" % id)
		var does_something: bool = not (u.get("mods", []) as Array).is_empty() or u.has("special") or u.has("flag")
		check(does_something, "%s has at least one effect" % id)
	check(seen.size() >= 100, "catalogue has the expected breadth (%d)" % seen.size())


func test_upgrade_mods_target_real_stats() -> void:
	var stats: StatBlock = _player_stats()
	for u: Dictionary in UpgradeDefinitions.CATALOG:
		for mod: Array in u.get("mods", []):
			eq(mod.size(), 3, "%s mod has three parts" % u.id)
			check(stats.has(mod[0]), "%s modifies '%s', which the player has" % [u.id, mod[0]])
			check(mod[1] == "mul" or mod[1] == "add", "%s mod mode is mul or add" % u.id)


func test_upgrade_specials_are_handled() -> void:
	var manager_src: String = _source("res://systems/upgrades/upgrade_manager.gd")
	check(manager_src.length() > 0, "upgrade manager source is readable")
	for u: Dictionary in UpgradeDefinitions.CATALOG:
		var special: StringName = u.get("special", &"")
		if special == &"":
			continue
		check(manager_src.contains("&\"%s\"" % special), "special '%s' (%s) is handled by the upgrade manager" % [special, u.id])


func test_upgrade_flags_are_read_by_their_weapon() -> void:
	for u: Dictionary in UpgradeDefinitions.CATALOG:
		var flag: Array = u.get("flag", [])
		if flag.is_empty():
			continue
		eq(flag.size(), 3, "%s flag has three parts" % u.id)
		var weapon_id: StringName = flag[0]
		check(WeaponDefs.exists(weapon_id), "%s targets a real weapon (%s)" % [u.id, weapon_id])
		eq(u.get("weapon", &""), weapon_id, "%s is only offered with its weapon equipped" % u.id)
		if WeaponDefs.exists(weapon_id):
			var src: String = _source(WeaponDefs.CATALOG[weapon_id].script)
			check(src.contains("&\"%s\"" % flag[1]), "weapon %s reads the flag '%s' set by %s" % [weapon_id, flag[1], u.id])


func test_upgrade_application_changes_the_stat() -> void:
	var player: Node = (load(PLAYER_SCRIPT) as Script).new()
	var manager: UpgradeManager = UpgradeManager.new()
	manager.bind(player, null)
	for u: Dictionary in UpgradeDefinitions.CATALOG:
		if (u.get("mods", []) as Array).is_empty() or u.has("flag"):
			continue
		var before: Dictionary = {}
		for mod: Array in u.mods:
			before[mod[0]] = player.stats.value(mod[0])
		manager.apply(u)
		for mod: Array in u.mods:
			ne(player.stats.value(mod[0]), before[mod[0]], "%s changed %s" % [u.id, mod[0]])
		eq(manager.stacks(u.id), 1, "%s counted as owned" % u.id)
	manager.reset()
	near(player.stats.value(&"damage"), 1.0, "reset clears every upgrade modifier")
	near(player.stats.value(&"move_speed"), 12.0, "reset restores move speed")
	manager.free()
	player.free()


func test_upgrade_stacks_are_capped() -> void:
	var player: Node = (load(PLAYER_SCRIPT) as Script).new()
	var manager: UpgradeManager = UpgradeManager.new()
	manager.bind(player, null)
	var u: Dictionary = UpgradeDefinitions.find(&"brutal_rounds")
	for i: int in 10:
		manager.apply(u)
	eq(manager.stacks(&"brutal_rounds"), 5, "stops at its maximum")
	near(player.stats.value(&"damage"), pow(1.2, 5), "five stacks of +20%", 0.001)
	manager.free()
	player.free()


func test_pick_choices_respects_the_rules() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in 40:
		var picks: Array[Dictionary] = UpgradeDefinitions.pick_choices(3, {}, [&"pulse_rifle"], false, rng)
		eq(picks.size(), 3, "three choices")
		var ids: Dictionary = {}
		for p: Dictionary in picks:
			check(not ids.has(p.id), "choices are distinct")
			ids[p.id] = true
			var weapon: StringName = p.get("weapon", &"")
			check(weapon == &"" or weapon == &"pulse_rifle", "no upgrade for an unequipped weapon (%s)" % p.id)
	for i: int in 20:
		for p: Dictionary in UpgradeDefinitions.pick_choices(3, {}, [], true, rng):
			ne(p.get("rarity"), UpgradeDefinitions.RARITY_COMMON, "rare rewards contain no commons")
	# everything owned to the max: nothing left to offer
	var owned: Dictionary = {}
	for u: Dictionary in UpgradeDefinitions.CATALOG:
		owned[u.id] = UpgradeDefinitions.max_stacks(u)
	eq(UpgradeDefinitions.pick_choices(3, owned, WeaponDefs.ORDER).size(), 0, "a full build gets no choices")


func test_mutations() -> void:
	var stats: StatBlock = _player_stats()
	var seen: Dictionary = {}
	var manager_src: String = _source("res://systems/mutations/mutation_manager.gd")
	for m: Dictionary in MutationDefinitions.CATALOG:
		check(not seen.has(m.type), "mutation type is unique")
		seen[m.type] = true
		check(String(m.get("upside", "")).length() > 0 and String(m.get("downside", "")).length() > 0, "%s states both sides" % m.name)
		for mod: Array in m.get("mods", []):
			check(stats.has(mod[0]), "%s modifies a real stat (%s)" % [m.name, mod[0]])
		if (m.get("mods", []) as Array).is_empty():
			# no stat changes, so it must have scripted behaviour
			var key: String = MutationDefinitions.MutationType.find_key(m.type)
			check(manager_src.contains("T.%s" % key), "%s has behaviour in the mutation manager" % m.name)
	eq(seen.size(), MutationDefinitions.MutationType.size(), "every mutation type has an entry")
	var picks: Array[Dictionary] = MutationDefinitions.pick_choices(2, [MutationDefinitions.MutationType.GLASS_CANNON])
	eq(picks.size(), 2, "two mutation choices")
	for p: Dictionary in picks:
		ne(p.type, MutationDefinitions.MutationType.GLASS_CANNON, "excluded mutation is not offered")


func test_fracture_events() -> void:
	var src: String = _source("res://systems/fracture/fracture_manager.gd") + _source("res://scripts/game_manager.gd")
	for type: int in FractureDefinitions.EVENTS:
		var key: String = FractureDefinitions.FractureType.find_key(type)
		check(FractureDefinitions.get_event_name(type).length() > 0, "%s has a name" % key)
		check(FractureDefinitions.get_duration(type) > 0.0, "%s has a duration" % key)
		check(src.contains("T.%s" % key) or src.contains("FractureType.%s" % key), "%s has an effect in code" % key)
	eq(FractureDefinitions.EVENTS.size(), FractureDefinitions.FractureType.size(), "every fracture type has an entry")


func test_weapons() -> void:
	eq(WeaponDefs.ORDER.size(), WeaponDefs.CATALOG.size(), "armory order lists every weapon")
	for id: StringName in WeaponDefs.CATALOG:
		var def: Dictionary = WeaponDefs.CATALOG[id]
		check(ResourceLoader.exists(def.script), "%s script exists" % id)
		check(ResourceLoader.exists("res://assets/models/grafted-brood-%s.glb" % id), "%s model exists" % id)
		var weapon: BaseWeapon = WeaponDefs.create(id)
		if check(weapon != null, "%s can be created" % id):
			weapon._configure()
			eq(weapon.weapon_id, id, "%s reports its own id" % id)
			check(weapon.base_damage > 0.0 and weapon.fire_interval > 0.0, "%s has damage and a fire interval" % id)
			check(weapon.display_name.length() > 0, "%s has a display name" % id)
			weapon.free()
	for id: StringName in WeaponDefs.DEFAULT_LOADOUT:
		check(WeaponDefs.is_free(id), "default loadout weapon %s is free" % id)
	eq(WeaponDefs.sanitize_loadout(["nope", "ripper", "ripper"]), [&"ripper", &"pulse_rifle", &"scatter_cannon"], "bad ids dropped, duplicates collapsed, padded")
	eq(WeaponDefs.sanitize_loadout([]), WeaponDefs.DEFAULT_LOADOUT, "empty loadout becomes the default")


func test_enemies() -> void:
	for id: StringName in EnemyTypes.DEFS:
		var def: Dictionary = EnemyTypes.DEFS[id]
		check(ResourceLoader.exists("res://systems/enemy/types/%s.gd" % def.script), "%s script exists" % id)
		check(ResourceLoader.exists("res://assets/models/grafted-brood-%s.glb" % id), "%s model exists" % id)
		check(float(def.cost) > 0.0, "%s has a spawn cost" % id)
		check(EnemyComposition.BASE_WEIGHTS.has(id), "%s can be picked by room composition" % id)
		var enemy: EnemyBase = EnemyTypes.create(id, 1.0)
		if check(enemy != null, "%s can be created" % id):
			var hc: HealthComponent = enemy.get_node_or_null("HealthComponent") as HealthComponent
			check(hc != null and hc.max_health == int(def.health), "%s has its table health" % id)
			near(enemy.stats.value(&"move_speed"), float(def.speed), "%s has its table speed" % id)
			check(enemy.has_node("CollisionShape3D"), "%s has a collider" % id)
			enemy.free()
		var hard: EnemyBase = EnemyTypes.create(id, 2.0, &"shielded")
		if hard:
			var hc2: HealthComponent = hard.get_node("HealthComponent")
			check(hc2.max_health > int(def.health) * 2, "%s scales up when elite and harder" % id)
			check(hard.is_elite, "%s is flagged elite" % id)
			check(hc2.shield > 0, "the shielded affix grants a shield")
			hard.free()
	check(EnemyTypes.create(&"not_a_thing") == null, "unknown enemy id gives null")


func test_bosses() -> void:
	for id: StringName in BossDefs.DEFS:
		var def: Dictionary = BossDefs.DEFS[id]
		check(ResourceLoader.exists("res://systems/enemy/bosses/%s.gd" % def.script), "%s script exists" % id)
		check(ResourceLoader.exists("res://assets/models/grafted-brood-%s.glb" % def.model), "%s model exists" % id)
		var boss: BossBase = BossDefs.create(id, 2.0, 1.5)
		if check(boss != null, "%s can be created" % id):
			var hc: HealthComponent = boss.get_node("HealthComponent")
			eq(hc.max_health, int(def.health) * 2, "%s health scales" % id)
			near(boss.stats.value(&"damage"), float(def.damage) * 1.5, "%s damage scales" % id)
			boss.free()


func test_every_unlock_is_implemented() -> void:
	var src: String = _source("res://scripts/game_manager.gd")
	var seen: Dictionary = {}
	for entry: Dictionary in MetaProgression.unlock_catalog:
		var id: String = entry.id
		check(not seen.has(id), "unlock id '%s' is unique" % id)
		seen[id] = true
		check(int(entry.cost) > 0, "%s has a price" % id)
		match String(entry.category):
			"weapon":
				check(WeaponDefs.exists(StringName(id)), "weapon unlock %s is a real weapon" % id)
			"skin":
				check(Skins.exists(StringName(id.trim_prefix("skin:"))), "skin unlock %s is a real skin" % id)
			_:
				check(src.contains("\"%s\"" % id), "unlock '%s' is used by the game" % id)
		var req: String = entry.get("requirement", "")
		if not req.is_empty():
			check(MetaProgression.requirement_text(req).length() > 0, "%s requirement parses" % id)
	for id: StringName in Skins.PLAYER_SKINS:
		check(id == &"default" or seen.has("skin:%s" % id), "skin %s can be bought" % id)


func test_meta_upgrades_target_real_stats() -> void:
	var stats: StatBlock = _player_stats()
	for entry: Dictionary in MetaProgression.META_CATALOG:
		var stat: StringName = entry.stat
		if stat == &"":
			# handled outside the stat block: must be read somewhere by name
			var src: String = _source("res://systems/progression/meta_progression.gd")
			check(src.contains("get_meta_level(\"%s\")" % entry.id), "%s is read by a helper" % entry.id)
		else:
			check(stats.has(stat), "%s modifies a real stat (%s)" % [entry.id, stat])


func test_skins() -> void:
	for id: StringName in Skins.PALETTES:
		var p: Dictionary = Skins.PALETTES[id]
		for key: String in ["chitin", "bone", "membrane", "glow", "steel", "accent"]:
			check(p.has(key), "skin %s defines %s" % [id, key])
	for biome_id: StringName in Biome.DEFS:
		var b: Dictionary = Biome.DEFS[biome_id]
		check(Skins.exists(b.strain), "biome %s uses a real strain palette" % biome_id)
		check(Skins.exists(b.obstacle_skin), "biome %s uses a real obstacle palette" % biome_id)
		check((b.props as Array).size() > 0, "biome %s has set dressing" % biome_id)


func test_every_upgrade_applies_and_resets() -> void:
	var player: Node = (load(PLAYER_SCRIPT) as Script).new()
	var manager: UpgradeManager = UpgradeManager.new()
	manager.bind(player, null)
	for u: Dictionary in UpgradeDefinitions.CATALOG:
		for i: int in UpgradeDefinitions.max_stacks(u):
			manager.apply(u)
		eq(manager.stacks(u.id), UpgradeDefinitions.max_stacks(u), "%s taken to its maximum" % u.id)
	# the ongoing effects, with every one of them owned at once
	manager._tick_timers(0.1)
	manager._tick_conditions()
	check(player.stats.value(&"damage") > 1.0, "a full build hits harder")
	eq(manager.plates_max(), 2, "two stacks of bone plating are two plates")
	eq(manager.get_child_count(), 2, "two brood familiars exist")

	manager.reset()
	for stat: StringName in [&"damage", &"fire_rate", &"damage_taken", &"orb_heal", &"combo_time", &"dash_charges", &"essence_gain", &"field_boon", &"field_bane"]:
		near(player.stats.value(stat), 1.0, "reset restores %s" % stat)
	near(player.stats.value(&"max_health"), 100.0, "reset restores max health")
	near(player.stats.value(&"air_jumps"), 0.0, "reset removes air jumps")
	check(player.damage_filters.is_empty(), "reset removes the incoming damage filter")
	eq(manager.plates_max(), 0, "reset removes the plates")
	eq(manager.get_child_count(), 0, "reset removes the familiars")
	manager.free()
	player.free()


func test_bone_plating_soaks_one_hit_and_regrows() -> void:
	var player: Node = (load(PLAYER_SCRIPT) as Script).new()
	var manager: UpgradeManager = UpgradeManager.new()
	manager.bind(player, null)
	manager.apply(UpgradeDefinitions.find(&"bone_plating"))
	eq(manager.plates_ready(), 1, "the plate arrives ready")

	player.health = 100
	# your own blast goes straight through the plate
	player.take_damage(10, DamageInfo.make(10, DamageInfo.KIND_SELF))
	eq(player.health, 90, "self damage is not soaked")
	eq(manager.plates_ready(), 1, "and does not cost the plate")

	player._invuln_timer = 0.0
	player.take_damage(30, DamageInfo.make(30, DamageInfo.KIND_MELEE))
	eq(player.health, 90, "the plate soaked the whole hit")
	eq(manager.plates_ready(), 0, "and was spent")
	check(player.is_invulnerable(), "a soaked hit leaves a moment of grace")

	player._invuln_timer = 0.0
	player.take_damage(30, DamageInfo.make(30, DamageInfo.KIND_MELEE))
	eq(player.health, 60, "the next hit lands")

	manager._tick_timers(UpgradeManager.PLATE_REGROW * 0.5)
	eq(manager.plates_ready(), 0, "half way through, no plate yet")
	manager._tick_timers(UpgradeManager.PLATE_REGROW * 0.5 + 0.01)
	eq(manager.plates_ready(), 1, "the plate grew back")
	manager.free()
	player.free()


func test_timed_buffs_run_out() -> void:
	var player: Node = (load(PLAYER_SCRIPT) as Script).new()
	var manager: UpgradeManager = UpgradeManager.new()
	manager.bind(player, null)
	manager.apply(UpgradeDefinitions.find(&"adrenal_rush"))
	manager.apply(UpgradeDefinitions.find(&"bloodlust"))
	near(player.stats.value(&"fire_rate"), 1.0, "nothing yet")

	manager.on_player_damaged(5, null)
	near(player.stats.value(&"fire_rate"), 1.3, "adrenal rush after a hit")
	near(player.stats.value(&"move_speed"), 12.0 * 1.3, "and the speed with it")
	manager._tick_timers(UpgradeManager.RUSH_TIME + 0.1)
	near(player.stats.value(&"fire_rate"), 1.0, "adrenal rush ran out")

	for i: int in 14:
		manager.on_enemy_killed(null, null)
	near(player.stats.value(&"fire_rate"), 1.4, "bloodlust stops at +40%")
	manager._tick_timers(UpgradeManager.LUST_TIME + 0.1)
	near(player.stats.value(&"fire_rate"), 1.0, "bloodlust ran out")
	manager.free()
	player.free()


func test_reroll_leaves_out_what_was_on_screen() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	for i: int in 40:
		var shown: Array = []
		for p: Dictionary in UpgradeDefinitions.pick_choices(3, {}, WeaponDefs.DEFAULT_LOADOUT, false, rng):
			shown.append(p.id)
		var fresh: Array[Dictionary] = UpgradeDefinitions.pick_choices(3, {}, WeaponDefs.DEFAULT_LOADOUT, false, rng, shown)
		eq(fresh.size(), 3, "a reroll still deals three")
		for p: Dictionary in fresh:
			check(not shown.has(p.id), "a reroll does not repeat %s" % p.id)


func test_every_weapon_has_upgrades_of_its_own() -> void:
	var per_weapon: Dictionary = {}
	for u: Dictionary in UpgradeDefinitions.CATALOG:
		var weapon: StringName = u.get("weapon", &"")
		if weapon != &"":
			per_weapon[weapon] = int(per_weapon.get(weapon, 0)) + 1
	for id: StringName in WeaponDefs.ORDER:
		check(int(per_weapon.get(id, 0)) >= 3, "%s has at least three upgrades (%d)" % [id, int(per_weapon.get(id, 0))])


func test_dash_refund_and_combo_window() -> void:
	var player: Node = (load(PLAYER_SCRIPT) as Script).new()
	player.dash_charges_ready = 0
	player._dash_recharge = player.stats.value(&"dash_cooldown")
	player.refund_dash(0.5)
	eq(player.dash_charges_ready, 0, "half a cooldown is not a charge")
	player.refund_dash(0.5)
	eq(player.dash_charges_ready, 1, "two halves are")
	player.refund_dash(0.5)
	eq(player.dash_charges_ready, 1, "a full dash is not overfilled")

	var combo: ComboTracker = ComboTracker.new()
	combo.bind(player)
	combo.register_kill()
	near(combo.get_time_remaining(), ComboTracker.COMBO_WINDOW, "the plain combo window")
	player.stats.set_mul(&"combo_time", &"test", 1.3)
	combo.register_kill()
	near(combo.get_time_remaining(), ComboTracker.COMBO_WINDOW * 1.3, "a longer window with the upgrade")
	near(combo.time_ratio(), 1.0, "and the hud bar is full at the start of it")
	combo.free()
	player.free()


func test_trickle_and_cascade_effects() -> void:
	var player: Node = (load(PLAYER_SCRIPT) as Script).new()
	var manager: UpgradeManager = UpgradeManager.new()
	manager.bind(player, null)

	manager.apply(UpgradeDefinitions.find(&"regrowth"))
	player.health = 50
	manager._tick_timers(0.6)
	eq(player.health, 50, "less than a second: no whole point yet")
	manager._tick_timers(0.6)
	eq(player.health, 51, "regrowth heals a point a second")

	manager.apply(UpgradeDefinitions.find(&"hunger"))
	manager.reset()
	manager.apply(UpgradeDefinitions.find(&"hunger"))
	player.health = 3
	for i: int in 6:
		manager._tick_timers(1.0)
	eq(player.health, 1, "the hunger stops at the last point")

	manager.reset()
	manager.apply(UpgradeDefinitions.find(&"crit_cascade"))
	var crit: DamageInfo = DamageInfo.make(10)
	crit.crit = true
	var base_chance: float = player.stats.value(&"crit_chance")
	manager.on_enemy_hit(null, crit)
	near(player.stats.value(&"crit_chance"), base_chance + 1.0, "a crit arms a guaranteed one")
	manager.on_enemy_hit(null, crit)
	near(player.stats.value(&"crit_chance"), base_chance, "and that one does not arm another")

	manager.reset()
	manager.apply(UpgradeDefinitions.find(&"afterburner"))
	manager.on_player_dashed()
	near(player.stats.value(&"move_speed"), 12.0 * 1.25, "afterburner after a dash")
	manager._tick_timers(UpgradeManager.AFTERBURN_TIME + 0.1)
	near(player.stats.value(&"move_speed"), 12.0, "and it runs out")
	manager.free()
	player.free()


func test_rootbound_bends_fields_the_right_way() -> void:
	var player: Node = (load(PLAYER_SCRIPT) as Script).new()
	var manager: UpgradeManager = UpgradeManager.new()
	manager.bind(player, null)
	near(FieldZone.player_factor(FieldZone.KINDS[&"surge"], player.stats), 1.3, "a surge field as written")
	near(FieldZone.player_factor(FieldZone.KINDS[&"mire"], player.stats), 0.65, "a mire as written")
	manager.apply(UpgradeDefinitions.find(&"rootbound"))
	near(FieldZone.player_factor(FieldZone.KINDS[&"surge"], player.stats), 1.45, "a helpful field is half again as strong")
	near(FieldZone.player_factor(FieldZone.KINDS[&"ward"], player.stats), 0.55, "so is one that cuts damage taken")
	near(FieldZone.player_factor(FieldZone.KINDS[&"mire"], player.stats), 0.825, "a harmful field is half as strong")
	near(FieldZone.player_factor(FieldZone.KINDS[&"frail"], player.stats), 1.15, "so is one that raises damage taken")
	manager.free()
	player.free()
