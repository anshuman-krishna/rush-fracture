extends "res://tests/unit/test_case.gd"

# run flow, room composition, arena shapes, health and combo: logic that
# does not need the full scene.


func _room(type: RoomDefinitions.RoomType, difficulty: float, biome: StringName = &"hatchery") -> RunData.RoomData:
	var room: RunData.RoomData = RunData.RoomData.new()
	room.type = type
	room.difficulty = difficulty
	room.biome = biome
	room.enemy_budget = RoomDefinitions.enemy_budget_for(type, difficulty)
	return room


# --- run manager ------------------------------------------------------------------

func test_run_manager_walks_the_chosen_path() -> void:
	var rm: RunManager = RunManager.new()
	var entered: Array = []
	var ended: Array = []
	rm.room_entered.connect(func(r: RunData.RoomData) -> void: entered.append(r))
	rm.run_completed.connect(func(_d: RunData) -> void: ended.append("completed"))
	rm.run_failed.connect(func(_d: RunData) -> void: ended.append("failed"))

	rm.start_run({"mode": RunData.MODE_SPRINT, "seed": 5})
	var data: RunData = rm.data
	eq(entered.size(), 1, "entering the first room")
	eq(data.total_rooms(), 6, "sprint length")
	check(rm.is_active, "run is active")

	# take the last option on every floor and check that is what gets entered
	while not data.is_final_room():
		rm.on_room_enemies_cleared()
		var options: Array = data.next_options()
		var pick: int = options.size() - 1
		rm.advance_to_next_room(pick)
		eq(data.current_room(), options[pick], "the chosen option becomes the current room")
	eq(entered.size(), 6, "every floor was entered")
	eq(data.rooms_cleared, 5, "five rooms cleared before the boss")

	rm.on_room_enemies_cleared()
	eq(data.bosses_defeated, 1, "the boss room counts as a boss defeated")
	rm.on_room_enemies_cleared()
	eq(data.rooms_cleared, 6, "clearing the same room twice counts once")
	rm.advance_to_next_room(0)
	eq(ended, ["completed"], "advancing past the last room completes the run")
	rm.complete_run()
	rm.fail_run()
	eq(ended, ["completed"], "a finished run cannot finish again")
	rm.free()


func test_run_manager_essence_and_kills() -> void:
	var rm: RunManager = RunManager.new()
	rm.start_run({"mode": RunData.MODE_SPRINT, "seed": 9})
	rm.add_essence(40)
	rm.add_essence(-15)
	rm.add_essence(-100)
	eq(rm.data.essence, 0, "essence cannot go negative")
	eq(rm.data.essence_earned, 40, "spending does not reduce the amount earned")
	rm.register_kill()
	rm.register_kill()
	eq(rm.data.total_enemies_killed, 2, "kills counted")
	eq(rm.data.current_room().enemies_killed, 2, "and attributed to the room")
	rm.fail_run()
	eq(rm.data.status, RunData.RunStatus.FAILED, "run failed")
	rm.free()


# --- composition ------------------------------------------------------------------

func test_composition_respects_difficulty_gates() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for seed_value: int in 20:
		rng.seed = seed_value
		var room: RunData.RoomData = _room(RoomDefinitions.RoomType.COMBAT, 1.0)
		for entry: Dictionary in EnemyComposition.build(room, rng):
			check(EnemyTypes.min_difficulty(entry.type) <= 1.0, "%s is allowed at difficulty 1.0" % entry.type)
			check(EnemyTypes.exists(entry.type), "%s is a real enemy" % entry.type)


func test_composition_scales_and_caps() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	var easy: int = EnemyComposition.build(_room(RoomDefinitions.RoomType.COMBAT, 1.0), rng).size()
	var total_hard: int = 0
	for i: int in 10:
		var entries: Array[Dictionary] = EnemyComposition.build(_room(RoomDefinitions.RoomType.COMBAT, 3.0, &"marrow"), rng)
		total_hard += entries.size()
		check(entries.size() <= EnemyComposition.MAX_PER_ROOM, "never more than the room cap")
		var supports: int = 0
		var mothers: int = 0
		for e: Dictionary in entries:
			if e.type == &"support":
				supports += 1
			if e.type == &"broodmother":
				mothers += 1
		check(supports <= EnemyComposition.MAX_SUPPORTS, "support cap")
		check(mothers <= EnemyComposition.MAX_BROODMOTHERS, "brood mother cap")
	check(float(total_hard) / 10.0 > float(easy), "harder rooms field more enemies")
	check(easy >= 3, "even the first room has something to fight (%d)" % easy)


func test_special_rooms() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	var elite: Array[Dictionary] = EnemyComposition.build(_room(RoomDefinitions.RoomType.ELITE, 1.6), rng)
	check(not elite.is_empty() and elite[0].affix != null, "an elite room leads with an elite")
	var chamber: Array[Dictionary] = EnemyComposition.build(_room(RoomDefinitions.RoomType.ELITE_CHAMBER, 2.0), rng)
	eq(chamber[0].type, &"broodmother", "the elite chamber is a brood mother")
	check(chamber[0].affix != null, "and she is an elite")
	eq(EnemyComposition.build(_room(RoomDefinitions.RoomType.SHOP, 2.0), rng).size(), 0, "nothing spawns in a shop")
	eq(EnemyComposition.build(_room(RoomDefinitions.RoomType.RECOVERY, 2.0), rng).size(), 0, "nothing spawns in a sanctuary")


func test_split_waves_keeps_everyone() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 21
	var entries: Array[Dictionary] = EnemyComposition.build(_room(RoomDefinitions.RoomType.GAUNTLET, 2.4, &"fracture"), rng)
	for wave_count: int in [1, 2, 3]:
		var waves: Array = EnemyComposition.split_waves(entries, wave_count)
		var total: int = 0
		for w: Array in waves:
			check(not w.is_empty(), "no empty waves")
			total += w.size()
		eq(total, entries.size(), "splitting into %d waves loses nobody" % wave_count)
	eq(EnemyComposition.split_waves([] as Array[Dictionary], 3).size(), 0, "nothing in, nothing out")


# --- arena shapes -----------------------------------------------------------------

func test_arena_shapes_contain_their_own_points() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4
	var shapes: Array = [ArenaShape.disc(34.0), ArenaShape.rect(32.0, 19.0), ArenaShape.cross(9.5, 31.0), ArenaShape.ring(34.0, 9.0)]
	for shape: ArenaShape in shapes:
		for i: int in 200:
			var p: Vector3 = shape.random_point(rng, 2.0)
			check(shape.contains(p.x, p.z, 1.9), "random point lies inside (kind %d)" % shape.kind)
		for i: int in 200:
			var wild: Vector3 = Vector3(rng.randf_range(-90, 90), 3.0, rng.randf_range(-90, 90))
			var fixed: Vector3 = shape.clamp_point(wild, 1.0)
			check(shape.contains(fixed.x, fixed.z, 0.99), "clamped point lies inside (kind %d)" % shape.kind)
			near(fixed.y, 3.0, "clamping leaves height alone")
		var inside: Vector3 = shape.random_point(rng, 3.0)
		eq(shape.clamp_point(inside, 1.0), inside, "a point already inside is untouched")
		check(shape.outline().size() >= 4, "outline has corners")
		check(shape.bounding_radius() > 10.0, "bounding radius is sane")


func test_ring_excludes_its_centre() -> void:
	var ring: ArenaShape = ArenaShape.ring(34.0, 9.0)
	check(not ring.contains(0.0, 0.0), "the centre of a ring is not playable")
	var pushed: Vector3 = ring.clamp_point(Vector3(1.0, 0, 0), 1.0)
	check(Vector2(pushed.x, pushed.z).length() >= 9.99, "a point in the centre is pushed out to the ring")


func test_cross_excludes_its_corners() -> void:
	var cross: ArenaShape = ArenaShape.cross(9.5, 31.0)
	check(cross.contains(25.0, 0.0), "along an arm is inside")
	check(cross.contains(0.0, -25.0), "along the other arm is inside")
	check(not cross.contains(25.0, 25.0), "the corner between arms is outside")


# --- health -----------------------------------------------------------------------

func test_health_component() -> void:
	var holder: Node3D = Node3D.new()
	var hc: HealthComponent = HealthComponent.new()
	hc.max_health = 100
	holder.add_child(hc)
	hc._ready()
	var deaths: Array = []
	hc.died.connect(func(_i: DamageInfo) -> void: deaths.append(1))

	check(not hc.take_damage(30), "a non-lethal hit does not report a kill")
	eq(hc.current_health, 70, "damage applied")
	check(not hc.take_damage(0), "zero damage is ignored")
	hc.heal(1000)
	eq(hc.current_health, 100, "healing stops at the maximum")

	hc.invulnerable = true
	hc.take_damage(50)
	eq(hc.current_health, 100, "invulnerable targets take nothing")
	hc.invulnerable = false

	hc.set_shield(40)
	hc.take_damage(25)
	eq(hc.shield, 15, "the shield absorbs first")
	eq(hc.current_health, 100, "health untouched while the shield holds")
	hc.take_damage(35)
	eq(hc.shield, 0, "shield spent")
	eq(hc.current_health, 80, "the overflow reaches health")

	hc.damage_scale = 2.0
	hc.take_damage(10)
	eq(hc.current_health, 60, "damage scale doubles the hit")
	hc.damage_scale = 1.0

	check(hc.take_damage(500), "the killing blow reports a kill")
	eq(hc.current_health, 0, "health floors at zero")
	check(not hc.is_alive(), "dead")
	check(not hc.take_damage(10), "the dead cannot be killed again")
	hc.heal(50)
	eq(hc.current_health, 0, "the dead cannot be healed")
	eq(deaths.size(), 1, "died fires exactly once")
	holder.free()


func test_health_kill_bypasses_protection() -> void:
	var holder: Node3D = Node3D.new()
	var hc: HealthComponent = HealthComponent.new()
	hc.max_health = 100
	holder.add_child(hc)
	hc._ready()
	hc.invulnerable = true
	hc.set_shield(999)
	var deaths: Array = []
	hc.died.connect(func(_i: DamageInfo) -> void: deaths.append(1))
	hc.kill()
	check(not hc.is_alive(), "kill() ends an invulnerable, shielded target")
	hc.kill()
	eq(deaths.size(), 1, "and only once")
	holder.free()


# --- combo ------------------------------------------------------------------------

func test_combo_buffs_are_stat_modifiers() -> void:
	var player: Node = (load("res://systems/player/player_controller.gd") as Script).new()
	var combo: ComboTracker = ComboTracker.new()
	combo.bind(player)
	near(player.stats.value(&"damage"), 1.0, "no buff at the start")
	for i: int in 3:
		combo.register_kill()
	eq(combo.combo_multiplier, 2, "three kills reach x2")
	check(player.stats.value(&"damage") > 1.0, "the combo damage buff is actually applied")
	check(player.stats.value(&"move_speed") > 12.0, "and so is the speed buff")
	for i: int in 22:
		combo.register_kill()
	eq(combo.combo_multiplier, 6, "twenty five kills reach x6")
	eq(combo.best_combo, 25, "best combo tracked")
	combo._process(ComboTracker.COMBO_WINDOW + 0.1)
	eq(combo.combo_count, 0, "the combo drops when the window runs out")
	near(player.stats.value(&"damage"), 1.0, "damage buff removed exactly")
	near(player.stats.value(&"move_speed"), 12.0, "speed buff removed exactly")
	eq(combo.best_combo, 25, "the best combo survives the drop")
	combo.reset_run()
	eq(combo.best_combo, 0, "a new run starts clean")
	combo.free()
	player.free()


func test_room_conditions_are_backed_by_something() -> void:
	var player: Node = (load("res://systems/player/player_controller.gd") as Script).new()
	var enemy: EnemyBase = EnemyTypes.create(&"chaser", 1.0)
	var controller_src: String = (load("res://systems/rooms/room_controller.gd") as Script).source_code
	for id: StringName in RoomConditions.DEFS:
		var def: Dictionary = RoomConditions.DEFS[id]
		check(String(def.get("name", "")).length() > 0 and String(def.get("text", "")).length() > 0, "%s is named and explained" % id)
		for mod: Array in def.get("player", []):
			check(player.stats.has(mod[0]), "%s changes a stat the player has (%s)" % [id, mod[0]])
		for mod: Array in def.get("enemy", []):
			check(enemy.stats.has(mod[0]), "%s changes a stat enemies have (%s)" % [id, mod[0]])
		var has_mods: bool = def.has("player") or def.has("enemy")
		check(has_mods or controller_src.contains("&\"%s\"" % id), "%s does something" % id)

	RoomConditions.apply_to_player(&"tailwind", player.stats)
	near(player.stats.value(&"move_speed"), 12.0 * 1.2, "tailwind speeds the player up")
	RoomConditions.apply_to_player(&"thin_air", player.stats)
	near(player.stats.value(&"move_speed"), 12.0, "a new condition replaces the old one")
	near(player.stats.value(&"gravity_scale"), 0.55, "thin air weakens gravity")
	RoomConditions.clear_player(player.stats)
	near(player.stats.value(&"gravity_scale"), 1.0, "clearing restores the player")
	RoomConditions.apply_to_enemy(&"frenzy", enemy.stats)
	check(enemy.damage() > 0, "an enemy under frenzy still reports damage")
	enemy.free()
	player.free()


func test_room_conditions_come_from_the_seed() -> void:
	var with_condition: int = 0
	var fights: int = 0
	for seed_value: int in [1, 2, 3, 4, 5, 6]:
		var a: Array = RoomGenerator.generate({"seed": seed_value, "mode": RunData.MODE_STANDARD})
		var b: Array = RoomGenerator.generate({"seed": seed_value, "mode": RunData.MODE_STANDARD})
		for f: int in a.size():
			for r: int in (a[f] as Array).size():
				var room: RunData.RoomData = a[f][r]
				eq(RoomConditions.of(room), RoomConditions.of(b[f][r]), "the same seed gives the same condition")
				if room.is_peaceful() or room.is_boss() or room.floor_index <= 0:
					eq(RoomConditions.of(room), &"", "no condition on %s (floor %d)" % [room.title(), room.floor_index])
				else:
					fights += 1
					if RoomConditions.of(room) != &"":
						with_condition += 1
	check(with_condition > fights / 5 and with_condition < fights * 4 / 5, "some fights have a condition and some do not (%d of %d)" % [with_condition, fights])


func test_fields_use_real_stats_and_statuses() -> void:
	var player: Node = (load("res://systems/player/player_controller.gd") as Script).new()
	var enemy_src: String = (load("res://systems/enemy/enemy_base.gd") as Script).source_code
	for id: StringName in FieldZone.KINDS:
		var def: Dictionary = FieldZone.KINDS[id]
		check(String(def.get("name", "")).length() > 0 and String(def.get("text", "")).length() > 0, "%s is named and explained" % id)
		if def.has("stat"):
			check(player.stats.has(def.stat), "%s changes a stat the player has" % id)
			check(not is_equal_approx(float(def.factor), 1.0), "%s changes it by something" % id)
		if def.has("enemy"):
			check(enemy_src.contains("&\"%s\"" % def.enemy[0]), "%s uses a status enemies understand (%s)" % [id, def.enemy[0]])
		check(def.has("stat") or def.has("heal"), "%s does something to the player" % id)
	player.free()

	# the statuses a field puts on an enemy change what they are meant to
	var enemy: EnemyBase = EnemyTypes.create(&"chaser", 1.0)
	var base_damage: int = enemy.damage()
	enemy.apply_status(&"empower", 1.0, 0.3)
	check(enemy.damage() > base_damage, "empower raises enemy damage")
	enemy.apply_status(&"weaken", 1.0, 0.5)
	check(enemy.damage() < int(base_damage * 1.3), "weaken lowers it again")
	var hc: HealthComponent = enemy.get_node("HealthComponent")
	enemy.health = hc
	enemy._refresh_status_mods()
	near(hc.damage_scale, 1.0, "no change to damage taken yet")
	enemy.apply_status(&"frail", 1.0, 0.3)
	near(hc.damage_scale, 1.3, "frail raises damage taken")
	enemy.apply_status(&"mark", 1.0, 0.25)
	near(hc.damage_scale, 1.55, "a mark adds to it")
	enemy.apply_status(&"ward", 1.0, 0.3)
	near(hc.damage_scale, 1.55 * 0.7, "a ward cuts it")
	enemy.free()
