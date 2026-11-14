class_name RoomController
extends Node3D

# runs one room at a time: builds its arena, sets the biome's sky and light,
# spawns enemies in waves, tracks when the room is clear, and handles drops,
# breakable cover and shared effects.
#
# in multiplayer every peer builds the same arena from the room's seed, but
# only the host decides what spawns; clients mirror each spawn it announces.

signal all_enemies_dead
signal enemy_killed(enemy: Node3D, info: DamageInfo)
signal boss_spawned(boss: BossBase)
signal boss_defeated
signal pickup_collected(kind: StringName, value: int)
signal wave_started(index: int, total: int)

const FLOOR_SIZE: float = 160.0
const SPAWN_DELAY: float = 0.7
const BOSS_SPAWN_DELAY: float = 1.6
const REINFORCE_TIMEOUT: float = 16.0
const HEALTH_ORB_VALUE: int = 15

const FLOOR_SHADER: String = """
shader_type spatial;
uniform vec3 base_color : source_color = vec3(0.09, 0.1, 0.09);
uniform vec3 line_color : source_color = vec3(0.45, 0.9, 0.3);
uniform float line_energy = 0.8;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	vec2 p = wp.xz;
	vec2 warped = p + vec2(noise(p * 0.12), noise(p * 0.12 + 7.3)) * 2.4;
	vec2 cell = abs(fract(warped / 4.0 - 0.5) - 0.5) * 4.0;
	float grid = 1.0 - smoothstep(0.02, 0.06, min(cell.x, cell.y));
	float r = length(p);
	float ring = 1.0 - smoothstep(0.03, 0.09, abs(fract(r / 10.0 - 0.5) - 0.5) * 10.0);
	float mottle = noise(p * 0.5) * 0.55 + noise(p * 2.1) * 0.25;
	float pulse = 0.75 + 0.25 * sin(TIME * 1.1 - r * 0.22);
	ALBEDO = base_color * (0.65 + mottle * 0.7);
	ROUGHNESS = 0.85 - grid * 0.35;
	METALLIC = 0.08;
	EMISSION = line_color * (grid * 0.3 + ring * 0.5) * line_energy * pulse;
}
"""

var active_room: RunData.RoomData
var enemies_alive: int = 0
var room_active: bool = false
## goes up every time a room is torn down. anything that schedules damage
## for later remembers the value and does nothing if it has changed, so an
## explosion set off in one room can never land in the next.
var room_token: int = 0

## an enemy that no player has been able to see for this long is somewhere
## it should not be (wedged in geometry, fallen behind a wall). it gets moved
## to open ground, because a room with an enemy nobody can reach never ends.
const UNSEEN_LIMIT: float = 12.0
const SIGHT_CHECK_INTERVAL: float = 0.5
var _sight_timer: float = 0.0
var active_boss: BossBase
var arena: ArenaShape
var builder: ArenaBuilder
var player_count: int = 1
## health multiplier for everything that spawns, from the run's difficulty
var enemy_health_scale: float = 1.0
## what is true of the whole room while you are in it (see RoomConditions)
var condition: StringName = &""
var _storm_timer: float = 0.0
var _regrow_timer: float = 0.0

var _lib: ModelLibrary = ModelLibrary.new()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _spawn_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _waves: Array = []
var _wave_index: int = 0
var _wave_size: int = 0
var _spawn_timer: float = -1.0
var _reinforce_timer: float = 0.0
var _next_wave_delay: float = -1.0
var _serial: int = 0
var _enemy_speed_mods: Dictionary = {}
var _breakables: Array[StaticBody3D] = []
var _floor_material: ShaderMaterial
var _environment: Environment
var _sky_material: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _pickup_root: Node3D
var _focus_prop: Node3D

@onready var arena_root: Node3D = $ArenaRoot
@onready var enemy_root: Node3D = $EnemyRoot
@onready var hazard_root: Node3D = $HazardRoot


func _ready() -> void:
	_spawn_rng.randomize()
	_pickup_root = Node3D.new()
	_pickup_root.name = "PickupRoot"
	add_child(_pickup_root)
	_build_floor()
	_setup_environment()


func _exit_tree() -> void:
	_lib.free_all()


func _process(delta: float) -> void:
	if not active_room:
		return
	if _spawn_timer >= 0.0:
		_spawn_timer -= delta
		if _spawn_timer < 0.0:
			_begin_encounter()
		return
	if not room_active or not Game.is_host_or_solo():
		return

	_sight_timer -= delta
	if _sight_timer <= 0.0:
		_sight_timer = SIGHT_CHECK_INTERVAL
		_rescue_unreachable_enemies()
	_tick_condition(delta)

	if _next_wave_delay >= 0.0:
		_next_wave_delay -= delta
		if _next_wave_delay < 0.0:
			_spawn_next_wave()
		return

	# reinforcements arrive when the current wave is nearly dead, or after a
	# while regardless so a kiting player can't stall the room
	if _wave_index < _waves.size():
		_reinforce_timer += delta
		var threshold: int = maxi(1, int(ceil(float(_wave_size) * 0.25)))
		if enemies_alive <= threshold or _reinforce_timer >= REINFORCE_TIMEOUT:
			_next_wave_delay = 0.9


# --- room lifecycle -------------------------------------------------------------

func enter_room(room: RunData.RoomData) -> void:
	_clear_room()
	active_room = room
	_rng.seed = room.seed_value
	_serial = 0

	builder = ArenaBuilder.new()
	builder.build(room, _rng, arena_root, hazard_root, _lib)
	arena = builder.shape
	_collect_breakables()
	_apply_biome(room.biome, room.is_boss())
	_place_focus_prop(room)

	condition = RoomConditions.of(room)
	_storm_timer = RoomConditions.STORM_INTERVAL + 1.5
	_regrow_timer = 0.0
	if condition == &"haze" and _environment:
		_environment.fog_density *= RoomConditions.HAZE_FOG

	_spawn_timer = BOSS_SPAWN_DELAY if room.is_boss() else SPAWN_DELAY


func clear_current_room() -> void:
	_clear_room()


## ends the fight but leaves the arena standing: the duel that closes a
## versus match is fought in the last room of the gauntlet.
func clear_for_duel() -> void:
	for root: Node3D in [hazard_root, enemy_root, _pickup_root]:
		if not root:
			continue
		for child: Node in root.get_children():
			root.remove_child(child)
			child.queue_free()
	var pm: ProjectileManager = Game.projectiles()
	if pm:
		pm.clear_all()
	_waves.clear()
	_wave_index = 0
	_wave_size = 0
	_spawn_timer = -1.0
	_next_wave_delay = -1.0
	enemies_alive = 0
	room_active = false
	active_boss = null


## where duellist number `slot` of `count` starts: spread evenly around the
## arena, on open floor.
func duel_spawn_point(slot: int, count: int) -> Vector3:
	var angle: float = TAU * float(slot) / float(maxi(count, 1))
	var dir: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
	for distance: float in [14.0, 11.0, 17.0, 8.0, 20.0, 5.0]:
		var p: Vector3 = dir * distance
		if arena and not arena.contains(p.x, p.z, 1.5):
			continue
		if builder and builder.is_blocked(p.x, p.z, 1.0):
			continue
		return p + Vector3(0, 2.0, 0)
	return clamp_to_arena(dir * 10.0, 1.0) + Vector3(0, 2.0, 0)


func player_spawn_point(index: int = 0) -> Vector3:
	var base: Vector3 = builder.player_spawn if builder else Vector3(0, 2, 0)
	if index <= 0:
		return base
	var a: float = TAU * float(index) / 4.0
	return base + Vector3(cos(a), 0, sin(a)) * 2.5


func clamp_to_arena(pos: Vector3, margin: float = 0.5) -> Vector3:
	if not arena:
		return pos
	return arena.clamp_point(pos, margin + 0.6)


## where the altar or font stands in a peaceful room.
func focus_point() -> Vector3:
	return builder.focus_point if builder else Vector3.ZERO


func _begin_encounter() -> void:
	if not active_room:
		return
	room_active = true
	if not Game.is_host_or_solo():
		return

	var room: RunData.RoomData = active_room
	if room.is_boss():
		_spawn_boss(room)
		return
	if room.is_peaceful():
		# nothing to fight: report the room clear after a beat so the reward
		# flow is the same as any other room
		room_active = false
		get_tree().create_timer(0.6).timeout.connect(func() -> void:
			if active_room == room:
				all_enemies_dead.emit()
		)
		return

	var entries: Array[Dictionary] = EnemyComposition.build(room, _rng)
	var wave_count: int = 1
	if room.type == RoomDefinitions.RoomType.GAUNTLET:
		wave_count = 3
	elif entries.size() > 12:
		wave_count = 3
	elif entries.size() > 5:
		wave_count = 2
	_waves = EnemyComposition.split_waves(entries, wave_count)
	_wave_index = 0
	if _waves.is_empty():
		room_active = false
		all_enemies_dead.emit()
		return
	_spawn_next_wave()


func _spawn_next_wave() -> void:
	if _wave_index >= _waves.size():
		return
	var wave: Array = _waves[_wave_index]
	_wave_index += 1
	_wave_size = wave.size()
	_reinforce_timer = 0.0
	wave_started.emit(_wave_index, _waves.size())
	for entry: Dictionary in wave:
		_spawn_enemy(entry.type, entry.affix, _spawn_point(entry.type), true)
	if _wave_index > 1:
		Game.sfx(&"wave_incoming", -6.0)


# --- spawning -------------------------------------------------------------------

## summons an enemy mid-fight (boss adds, brood mothers). `counts` decides
## whether the room waits for it to die before clearing.
func spawn_add(type_id: StringName, at: Vector3, counts: bool = false, elite: bool = false) -> EnemyBase:
	if not active_room or not room_active or not Game.is_host_or_solo():
		return null
	var pos: Vector3 = clamp_to_arena(at, 1.0)
	if not EnemyTypes.DEFS.get(type_id, {}).get("flying", false):
		pos.y = 0.15
	return _spawn_enemy(type_id, EnemyTypes.random_affix(_spawn_rng) if elite else null, pos, counts)


## fracture event: one more of whatever this room spawns.
func spawn_duplicate_enemy() -> void:
	if not active_room or not room_active or enemies_alive <= 0 or not Game.is_host_or_solo():
		return
	var entries: Array[Dictionary] = EnemyComposition.build(active_room, _spawn_rng)
	if entries.is_empty():
		return
	var pick: Dictionary = entries[_spawn_rng.randi() % entries.size()]
	_spawn_enemy(pick.type, null, _spawn_point(pick.type), true)


## scales every enemy's speed under a named key (fracture events, cursed
## upgrades). applies to enemies alive now and any spawned later. 1.0 removes.
func set_enemy_speed_mod(key: StringName, mult: float) -> void:
	if is_equal_approx(mult, 1.0):
		_enemy_speed_mods.erase(key)
	else:
		_enemy_speed_mods[key] = mult
	for e: Node in enemy_root.get_children():
		if e is EnemyBase:
			(e as EnemyBase).stats.set_mul(&"move_speed", StringName("room:%s" % key), mult)


func _spawn_enemy(type_id: StringName, affix: Variant, at: Vector3, counts: bool) -> EnemyBase:
	_serial += 1
	var node_name: String = "E%d" % _serial
	var enemy: EnemyBase = _create_enemy(type_id, node_name, at, affix, active_room.difficulty, counts)
	if not enemy:
		return null
	if counts:
		enemies_alive += 1
	if Game.is_online():
		_rpc_spawn_enemy.rpc(String(type_id), node_name, at, String(affix) if affix != null else "", active_room.difficulty, counts)
	return enemy


@rpc("authority", "call_remote", "reliable")
func _rpc_spawn_enemy(type_id: String, node_name: String, at: Vector3, affix: String, difficulty: float, counts: bool) -> void:
	_create_enemy(StringName(type_id), node_name, at, StringName(affix) if not affix.is_empty() else null, difficulty, counts)


func _create_enemy(type_id: StringName, node_name: String, at: Vector3, affix: Variant, difficulty: float, counts: bool) -> EnemyBase:
	if not active_room:
		return null
	var enemy: EnemyBase = EnemyTypes.create(type_id, difficulty, affix, Biome.strain(active_room.biome))
	if not enemy:
		return null
	if not is_equal_approx(enemy_health_scale, 1.0):
		var hc: HealthComponent = enemy.get_node_or_null("HealthComponent") as HealthComponent
		if hc:
			hc.set_max(maxi(1, int(round(hc.max_health * enemy_health_scale))))
	enemy.name = node_name
	enemy.counts_for_room = counts
	for key: Variant in _enemy_speed_mods:
		enemy.stats.set_mul(&"move_speed", StringName("room:%s" % key), _enemy_speed_mods[key])
	RoomConditions.apply_to_enemy(condition, enemy.stats)
	enemy.position = at
	enemy_root.add_child(enemy)
	enemy.begin_spawn()
	if condition == &"brittle" and Game.is_host_or_solo():
		enemy.apply_status(&"brittle", 100000.0, RoomConditions.BRITTLE_BONUS)
	enemy.health.died.connect(_on_enemy_died.bind(enemy))
	_setup_enemy_multiplayer(enemy)
	return enemy


func _spawn_boss(room: RunData.RoomData) -> void:
	var boss_id: StringName = room.boss_id if room.boss_id != &"" else &"titan"
	var health_scale: float = (1.0 + maxf(0.0, room.difficulty - 1.0) * 0.5) * (1.0 + 0.7 * float(maxi(0, player_count - 1))) * enemy_health_scale
	var damage_scale: float = 1.0 + maxf(0.0, room.difficulty - 1.0) * 0.2
	var at: Vector3 = builder.boss_spawn
	_create_boss(boss_id, at, health_scale, damage_scale)
	enemies_alive += 1
	if Game.is_online():
		_rpc_spawn_boss.rpc(String(boss_id), at, health_scale, damage_scale)


@rpc("authority", "call_remote", "reliable")
func _rpc_spawn_boss(boss_id: String, at: Vector3, health_scale: float, damage_scale: float) -> void:
	_create_boss(StringName(boss_id), at, health_scale, damage_scale)


func _create_boss(boss_id: StringName, at: Vector3, health_scale: float, damage_scale: float) -> void:
	if not active_room:
		return
	var boss: BossBase = BossDefs.create(boss_id, health_scale, damage_scale, Biome.strain(active_room.biome))
	if not boss:
		return
	boss.name = "Boss"
	boss.position = at
	enemy_root.add_child(boss)
	boss.begin_spawn(1.0)
	boss.health.died.connect(_on_enemy_died.bind(boss))
	boss.boss_defeated.connect(func() -> void: boss_defeated.emit())
	_setup_enemy_multiplayer(boss)
	active_boss = boss
	Vfx.ring(at, 12.0, Biome.glow(active_room.biome), 0.9, 1.0, 0.2)
	Game.shake(6.0)
	boss_spawned.emit(boss)


func _rescue_unreachable_enemies() -> void:
	var pm: PlayerManager = Game.players()
	if not pm or not arena_root.is_inside_tree():
		return
	var living: Array[CharacterBody3D] = pm.get_living_players()
	if living.is_empty():
		return
	var space: PhysicsDirectSpaceState3D = arena_root.get_world_3d().direct_space_state
	for node: Node in enemy_root.get_children():
		var enemy: EnemyBase = node as EnemyBase
		if not enemy or enemy is BossBase or enemy.is_dying or not enemy.health or not enemy.health.is_alive():
			continue
		if _any_player_sees(space, enemy.aim_point(), living):
			enemy.unseen_time = 0.0
			continue
		enemy.unseen_time += SIGHT_CHECK_INTERVAL
		if enemy.unseen_time < UNSEEN_LIMIT:
			continue
		enemy.unseen_time = 0.0
		# somewhere open, and in view of a player if one can be found
		var to: Vector3 = _spawn_point(enemy.type_id)
		for attempt: int in 8:
			if _any_player_sees(space, to + Vector3(0, 1.0, 0), living):
				break
			to = _spawn_point(enemy.type_id)
		enemy.global_position = to
		enemy.velocity = Vector3.ZERO
		net_fx(&"ring", to, Vector3.ZERO, 2.6, 0.45, Color(0.8, 0.5, 1.0))
		Game.sfx_at(&"warp", to, -6.0, 0.08)


func _any_player_sees(space: PhysicsDirectSpaceState3D, point: Vector3, players: Array[CharacterBody3D]) -> bool:
	for p: CharacterBody3D in players:
		if not is_instance_valid(p):
			continue
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(point, p.global_position + Vector3(0, 0.5, 0))
		query.collision_mask = Layers.WORLD
		query.collide_with_areas = false
		if space.intersect_ray(query).is_empty():
			return true
	return false


func _spawn_point(type_id: StringName = &"") -> Vector3:
	var flying: bool = EnemyTypes.DEFS.get(type_id, {}).get("flying", false)
	var players: Array[CharacterBody3D] = []
	var pm: PlayerManager = Game.players()
	if pm:
		players = pm.get_all_players()
	var best: Vector3 = Vector3.ZERO
	for attempt: int in 16:
		var p: Vector3 = arena.random_point(_spawn_rng, 3.0)
		if builder.is_blocked(p.x, p.z, 1.0):
			continue
		best = p
		var too_close: bool = false
		# relax the distance rule as attempts run out
		var min_dist: float = 9.0 if attempt < 10 else 5.0
		for pl: CharacterBody3D in players:
			if is_instance_valid(pl) and Vector2(pl.global_position.x - p.x, pl.global_position.z - p.z).length() < min_dist:
				too_close = true
				break
		if not too_close:
			break
	best.y = 4.5 if flying else 0.15
	return best


func _on_enemy_died(info: DamageInfo, enemy: Node3D) -> void:
	enemy_killed.emit(enemy, info)
	if not Game.is_host_or_solo():
		return
	if Game.is_online():
		# 0 = nobody in particular (a hazard, a fall, another enemy)
		var killer: int = 0
		if info and info.peer != 0:
			killer = info.peer
		elif info and info.source != null and info.source == Game.local_player():
			killer = multiplayer.get_unique_id()
		_rpc_enemy_died.rpc(String(enemy.name), killer)
	if condition == &"volatile" and enemy is EnemyBase and not enemy is BossBase and (enemy as EnemyBase).affix != &"volatile":
		_condition_burst(enemy as EnemyBase)
	if not enemy.get("counts_for_room"):
		return
	enemies_alive = maxi(0, enemies_alive - 1)
	if enemies_alive > 0 or not room_active:
		return
	if _wave_index < _waves.size():
		_next_wave_delay = 0.9
		return
	_finish_room()


func _finish_room() -> void:
	room_active = false
	# anything that was summoned rather than spawned dies with the room
	for e: Node in enemy_root.get_children():
		if e is EnemyBase and not (e as EnemyBase).is_dying:
			var hc: HealthComponent = (e as EnemyBase).health
			if hc and hc.is_alive():
				hc.kill()
	var pm: ProjectileManager = Game.projectiles()
	if pm:
		pm.clear_all()
	for p: Node in _pickup_root.get_children():
		if p is Pickup:
			(p as Pickup).attract()
	all_enemies_dead.emit()


# --- drops ----------------------------------------------------------------------

## called by an enemy on the peer that owns it, as it dies.
func on_enemy_dropped(enemy: EnemyBase, _info: DamageInfo) -> void:
	if not active_room:
		return
	var at: Vector3 = enemy.aim_point()
	var essence: int = maxi(0, int(round(enemy.essence_value * _spawn_rng.randf_range(0.8, 1.25))))
	var orbs: int = 0
	if enemy is BossBase:
		orbs = 3
	elif enemy.is_elite:
		orbs = 1
	elif _spawn_rng.randf() < 0.06:
		orbs = 1
	if not enemy.counts_for_room:
		# summoned adds pay a fraction, so a spawner can't be farmed
		essence = 1 if _spawn_rng.randf() < 0.3 else 0
		orbs = 0
	if condition == &"famine":
		orbs = 0
	if essence <= 0 and orbs <= 0:
		return
	_spawn_drops(at, essence, orbs)
	if Game.is_online():
		_rpc_spawn_drops.rpc(at, essence, orbs)


@rpc("authority", "call_remote", "reliable")
func _rpc_spawn_drops(at: Vector3, essence: int, orbs: int) -> void:
	_spawn_drops(at, essence, orbs)


func _spawn_drops(at: Vector3, essence: int, orbs: int) -> void:
	var gems: int = clampi(int(ceil(float(essence) / 3.0)), 1, 5) if essence > 0 else 0
	var remaining: int = essence
	for i: int in gems:
		var v: int = remaining if i == gems - 1 else maxi(1, essence / gems)
		remaining -= v
		_add_pickup(Pickup.KIND_ESSENCE, maxi(1, v), at)
	for i: int in orbs:
		_add_pickup(Pickup.KIND_HEALTH, HEALTH_ORB_VALUE, at)


## banks every pickup still on the floor. called as the player leaves a room,
## so nothing earned is lost to a quick exit.
func collect_all_pickups() -> void:
	for p: Node in _pickup_root.get_children():
		if p is Pickup:
			pickup_collected.emit((p as Pickup).kind, (p as Pickup).value)
			p.queue_free()


## drops a pickup into the world (also used for essence caches and rewards).
func drop_pickup(kind: StringName, value: int, at: Vector3) -> void:
	_add_pickup(kind, value, at)


func _add_pickup(kind: StringName, value: int, at: Vector3) -> void:
	var p: Pickup = Pickup.create(kind, value)
	p.position = Vector3(at.x, maxf(at.y, 0.6), at.z)
	_pickup_root.add_child(p)
	p.collected.connect(func(k: StringName, v: int) -> void: pickup_collected.emit(k, v))


# --- breakable cover ------------------------------------------------------------

func damage_breakable(wall: StaticBody3D, hits: int = 1) -> void:
	if not is_instance_valid(wall) or not wall.has_meta("breakable"):
		return
	var hp: int = int(wall.get_meta("hit_points")) - hits
	wall.set_meta("hit_points", hp)
	var model: Node3D = wall.get_node_or_null("WallModel") as Node3D
	if model:
		var tw: Tween = model.create_tween()
		tw.tween_property(model, "position:x", 0.06, 0.03)
		tw.tween_property(model, "position:x", -0.06, 0.03)
		tw.tween_property(model, "position:x", 0.0, 0.03)
	if hp <= 0:
		var idx: int = _breakables.find(wall)
		_destroy_breakable(wall)
		if Game.is_online() and idx >= 0:
			_rpc_wall_destroyed.rpc(idx)


func damage_breakables_in_radius(centre: Vector3, radius: float) -> void:
	for wall: StaticBody3D in _breakables.duplicate():
		if is_instance_valid(wall) and wall.global_position.distance_to(centre) <= radius + 1.5:
			damage_breakable(wall, 3)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_wall_destroyed(index: int) -> void:
	if index >= 0 and index < _breakables.size() and is_instance_valid(_breakables[index]):
		_destroy_breakable(_breakables[index])


func _destroy_breakable(wall: StaticBody3D) -> void:
	var at: Vector3 = wall.global_position + Vector3(0, 1.0, 0)
	var glow: Color = Biome.glow(active_room.biome) if active_room else Color(0.6, 1.0, 0.4)
	Vfx.chunks(at, glow.darkened(0.4), 7.0)
	Vfx.sparks(at, Vector3.UP, glow, 6.0, 160.0)
	Game.sfx_at(&"wall_break", at, -5.0, 0.15)
	# keep the slot so indices stay stable across peers
	var idx: int = _breakables.find(wall)
	if idx >= 0:
		_breakables[idx] = null
	wall.queue_free()


func _collect_breakables() -> void:
	_breakables.clear()
	for child: Node in arena_root.get_children():
		if child is StaticBody3D and child.has_meta("breakable"):
			_breakables.append(child as StaticBody3D)


# --- hazards and shared effects ---------------------------------------------------

func add_timed_hazard(at: Vector3, radius: float, tick_damage: int, seconds: float, color: Color) -> void:
	if not active_room:
		return
	var zone: HazardZone = HazardZone.create(radius, tick_damage, color, seconds)
	zone.position = Vector3(at.x, 0.1, at.z)
	hazard_root.add_child(zone)


## plays a world effect on every peer. enemy and boss attack warnings go
## through this so clients see what the host's ai is about to do.
func net_fx(kind: StringName, a: Vector3, b: Vector3 = Vector3.ZERO, f1: float = 0.0, f2: float = 0.0, color: Color = Color.WHITE) -> void:
	_do_fx(kind, a, b, f1, f2, color)
	if Game.is_online() and multiplayer.is_server():
		_rpc_fx.rpc(String(kind), a, b, f1, f2, color)


@rpc("authority", "call_remote", "unreliable")
func _rpc_fx(kind: String, a: Vector3, b: Vector3, f1: float, f2: float, color: Color) -> void:
	_do_fx(StringName(kind), a, b, f1, f2, color)


func _do_fx(kind: StringName, a: Vector3, b: Vector3, f1: float, f2: float, color: Color) -> void:
	match kind:
		&"circle":
			Vfx.telegraph_circle(a, f1, f2, color)
		&"line":
			Vfx.telegraph_line(a, b, f1, f2, color)
		&"blast":
			Vfx.blast(a, f1, color)
		&"ring":
			Vfx.ring(a, f1, color, f2)
		&"bolt":
			Vfx.lightning(a + Vector3(0, 26.0, 0), a, color, 0.22, 1.4, 0.07)
			Vfx.blast(a + Vector3(0, 0.4, 0), f1, color)
		&"wave":
			Shockwave.spawn(hazard_root, a, f1, f2, int(b.x), color, b.z, b.y > 0.5)


# --- environment ------------------------------------------------------------------

func _build_floor() -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Floor"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(FLOOR_SIZE, 2.0, FLOOR_SIZE)
	col.shape = shape
	col.position.y = -0.9
	body.add_child(col)

	var mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(FLOOR_SIZE, FLOOR_SIZE)
	mesh.mesh = plane
	mesh.position.y = 0.1
	var shader: Shader = Shader.new()
	shader.code = FLOOR_SHADER
	_floor_material = ShaderMaterial.new()
	_floor_material.shader = shader
	mesh.material_override = _floor_material
	body.add_child(mesh)
	add_child(body)


func _setup_environment() -> void:
	var main: Node = get_parent()
	var we: WorldEnvironment = main.get_node_or_null("WorldEnvironment") as WorldEnvironment if main else null
	if not we:
		we = WorldEnvironment.new()
		we.name = "WorldEnvironment"
		add_child(we)
	_environment = Environment.new()
	_sky_material = ProceduralSkyMaterial.new()
	_sky_material.sun_angle_max = 12.0
	_sky_material.sun_curve = 0.08
	var sky: Sky = Sky.new()
	sky.sky_material = _sky_material
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.tonemap_white = 6.0
	_environment.tonemap_exposure = 1.3
	_environment.glow_enabled = true
	_environment.glow_intensity = 0.85
	_environment.glow_bloom = 0.12
	_environment.glow_hdr_threshold = 0.95
	_environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	_environment.fog_enabled = true
	_environment.fog_sky_affect = 0.35
	_environment.adjustment_enabled = true
	_environment.adjustment_contrast = 1.06
	_environment.adjustment_saturation = 1.12
	we.environment = _environment

	_sun = main.get_node_or_null("DirectionalLight3D") as DirectionalLight3D if main else null
	if not _sun:
		_sun = DirectionalLight3D.new()
		_sun.name = "Sun"
		add_child(_sun)
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 90.0
	_sun.shadow_bias = 0.06
	_apply_biome(&"hatchery", false)


## graphics quality from settings: 0 low, 1 medium, 2 high.
func apply_quality(level: int) -> void:
	if not _environment:
		return
	_environment.ssao_enabled = level >= 2
	_environment.glow_enabled = level >= 1
	_environment.volumetric_fog_enabled = false
	if _sun:
		_sun.shadow_enabled = level >= 1
		_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if level >= 2 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS


func _apply_biome(biome_id: StringName, boss_room: bool) -> void:
	var b: Dictionary = Biome.get_def(biome_id)
	if _sky_material:
		_sky_material.sky_top_color = b.sky_top
		_sky_material.sky_horizon_color = b.sky_horizon
		_sky_material.ground_bottom_color = b.ground
		_sky_material.ground_horizon_color = (b.sky_horizon as Color).darkened(0.25)
	if _environment:
		_environment.ambient_light_color = b.ambient
		_environment.ambient_light_energy = b.ambient_energy * (0.8 if boss_room else 1.0)
		_environment.fog_light_color = b.fog
		_environment.fog_density = b.fog_density * (1.35 if boss_room else 1.0)
	if _sun:
		_sun.light_color = b.sun
		_sun.light_energy = b.sun_energy * (0.85 if boss_room else 1.0)
		_sun.rotation_degrees = Vector3(b.sun_pitch, b.sun_yaw, 0)
	if _floor_material:
		_floor_material.set_shader_parameter("base_color", b.floor)
		_floor_material.set_shader_parameter("line_color", b.floor_line)
		_floor_material.set_shader_parameter("line_energy", 0.8 if boss_room else 0.6)


func _place_focus_prop(room: RunData.RoomData) -> void:
	if not room.is_peaceful():
		return
	var part_name: String = "shop_altar" if room.type == RoomDefinitions.RoomType.SHOP else "totem"
	var prop: Node3D = _lib.part("props", part_name)
	if not prop:
		return
	Skins.apply(prop, Biome.get_def(room.biome).obstacle_skin)
	prop.position = builder.focus_point + Vector3(0, 0.1, 0)
	prop.scale = Vector3.ONE * 1.4
	arena_root.add_child(prop)
	_focus_prop = prop
	var l: OmniLight3D = OmniLight3D.new()
	l.light_color = Color(1.0, 0.85, 0.45) if room.type == RoomDefinitions.RoomType.SHOP else Color(0.4, 1.0, 0.5)
	l.light_energy = 4.0
	l.omni_range = 14.0
	l.shadow_enabled = false
	l.position = builder.focus_point + Vector3(0, 3.0, 0)
	arena_root.add_child(l)


# --- cleanup ----------------------------------------------------------------------

func _clear_room() -> void:
	room_token += 1
	for root: Node3D in [arena_root, hazard_root, enemy_root, _pickup_root]:
		if not root:
			continue
		for child: Node in root.get_children():
			root.remove_child(child)
			child.queue_free()
	var pm: ProjectileManager = Game.projectiles()
	if pm:
		pm.clear_all()
	_breakables.clear()
	_waves.clear()
	_wave_index = 0
	_wave_size = 0
	_spawn_timer = -1.0
	_next_wave_delay = -1.0
	_reinforce_timer = 0.0
	enemies_alive = 0
	room_active = false
	active_room = null
	active_boss = null
	_focus_prop = null
	builder = null
	condition = &""


## clients normally see a death through the replicated health value, but
## those updates are allowed to get lost. this one is not, and it also says
## who gets the credit.
@rpc("authority", "call_remote", "reliable")
func _rpc_enemy_died(node_name: String, killer_peer: int) -> void:
	var enemy: Node3D = enemy_root.get_node_or_null(NodePath(node_name)) as Node3D
	if not enemy:
		return
	var hc: HealthComponent = enemy.get_node_or_null("HealthComponent") as HealthComponent
	if hc and hc.is_alive():
		hc.kill()
	if killer_peer == multiplayer.get_unique_id():
		var combat: Combat = Game.combat()
		if combat:
			combat.credit_kill(enemy)


# --- room conditions ---------------------------------------------------------------

## the parts of a condition that happen over time. host only.
func _tick_condition(delta: float) -> void:
	match condition:
		&"overgrowth":
			_regrow_timer -= delta
			if _regrow_timer > 0.0:
				return
			_regrow_timer = 0.5
			var now: int = Time.get_ticks_msec()
			for node: Node in enemy_root.get_children():
				var e: EnemyBase = node as EnemyBase
				if not e or e.is_dying or not e.health or not e.health.is_alive():
					continue
				if e.health.current_health < e.health.max_health and now - e.health.last_damage_msec > RoomConditions.REGROW_QUIET_MSEC:
					e.health.heal(maxi(1, int(e.health.max_health * RoomConditions.REGROW_PER_SECOND * 0.5)))
		&"storm":
			_storm_timer -= delta
			if _storm_timer <= 0.0:
				_storm_timer = RoomConditions.STORM_INTERVAL * _spawn_rng.randf_range(0.7, 1.3)
				_storm_strike()


## marks a spot, then hits whatever is still standing on it.
func _storm_strike() -> void:
	if not arena:
		return
	var at: Vector3 = arena.random_point(_spawn_rng, 3.0)
	var pm: PlayerManager = Game.players()
	var living: Array[CharacterBody3D] = []
	if pm:
		living = pm.get_living_players()
	if not living.is_empty() and _spawn_rng.randf() < 0.6:
		# near someone, not on them: stand still and it finds you
		var who: CharacterBody3D = living[_spawn_rng.randi() % living.size()]
		var off: float = _spawn_rng.randf() * TAU
		at = clamp_to_arena(who.global_position + Vector3(cos(off), 0, sin(off)) * _spawn_rng.randf_range(0.0, 4.0), 1.0)
	at.y = 0.0
	var tint: Color = RoomConditions.color(&"storm")
	net_fx(&"circle", at, Vector3.ZERO, RoomConditions.STORM_RADIUS, RoomConditions.STORM_WARNING, tint)
	var difficulty: float = active_room.difficulty if active_room else 1.0
	_delayed_area_hit(at, RoomConditions.STORM_RADIUS, RoomConditions.STORM_WARNING,
		int(14.0 + difficulty * 4.0), int(60.0 * difficulty), tint, &"bolt")


## volatile brood: a body bursts a moment after it drops.
func _condition_burst(enemy: EnemyBase) -> void:
	var at: Vector3 = enemy.global_position
	at.y = 0.0
	var tint: Color = RoomConditions.color(&"volatile")
	net_fx(&"circle", at, Vector3.ZERO, RoomConditions.BURST_RADIUS, RoomConditions.BURST_DELAY, tint)
	_delayed_area_hit(at, RoomConditions.BURST_RADIUS, RoomConditions.BURST_DELAY,
		enemy.damage(0.9), int(35.0 * enemy.difficulty), tint, &"blast")


## after `delay`, damages every player and every enemy within `radius` of
## `at`. does nothing if the room has changed or the fight is over by then.
func _delayed_area_hit(at: Vector3, radius: float, delay: float, player_damage: int, enemy_damage: int,
		tint: Color, fx: StringName) -> void:
	var token: int = room_token
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if room_token != token or not room_active:
			return
		if fx == &"bolt":
			net_fx(&"bolt", at, Vector3.ZERO, radius, 0.0, tint)
		else:
			net_fx(&"blast", at + Vector3(0, 0.6, 0), Vector3.ZERO, radius, 0.0, tint)
		Game.sfx_at(&"explosion_small", at, -4.0, 0.15)
		var pm: PlayerManager = Game.players()
		if pm:
			for p: CharacterBody3D in pm.get_living_players():
				if is_instance_valid(p) and Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length() <= radius + 0.4 \
						and p.global_position.y < 3.5:
					var info: DamageInfo = DamageInfo.make(player_damage, DamageInfo.KIND_HAZARD)
					info.position = at
					p.take_damage(player_damage, info)
		for node: Node in enemy_root.get_children():
			var e: EnemyBase = node as EnemyBase
			if not e or e.is_dying or e is BossBase or not e.health or not e.health.is_alive():
				continue
			if e.global_position.distance_to(at) <= radius + e.body_radius:
				e.health.take_damage(enemy_damage, DamageInfo.make(enemy_damage, DamageInfo.KIND_HAZARD))
	)


# --- what a client does to an enemy ----------------------------------------------
#
# these go through the room, not to the enemy's own node. the host may have
# removed that enemy a moment before the message lands; a message addressed to
# a node that no longer exists is an engine error, while one addressed to the
# room with a name the room no longer knows is simply dropped.

const CLIENT_STATUSES: Array[StringName] = [&"slow", &"burn", &"mark"]


func send_enemy_hit(enemy: Node, amount: int, crit: bool) -> void:
	_rpc_enemy_hit.rpc_id(1, String(enemy.name), amount, crit)


func send_enemy_status(enemy: Node, id: StringName, seconds: float, power: float) -> void:
	_rpc_enemy_status.rpc_id(1, String(enemy.name), String(id), seconds, power)


func send_enemy_shove(enemy: Node, dir: Vector3, force: float) -> void:
	_rpc_enemy_shove.rpc_id(1, String(enemy.name), dir, force)


func send_enemy_stun(enemy: Node, seconds: float) -> void:
	_rpc_enemy_stun.rpc_id(1, String(enemy.name), seconds)


## the living enemy a client's message is about, or null.
func _reported_enemy(node_name: String) -> EnemyBase:
	if not multiplayer.is_server() or node_name.contains("/") or node_name.contains(":"):
		return null
	var enemy: EnemyBase = enemy_root.get_node_or_null(NodePath(node_name)) as EnemyBase
	return enemy if enemy and not enemy.is_dying else null


@rpc("any_peer", "call_remote", "reliable")
func _rpc_enemy_hit(node_name: String, amount: int, crit: bool) -> void:
	var enemy: EnemyBase = _reported_enemy(node_name)
	if enemy and enemy.health:
		enemy.health.apply_reported_damage(multiplayer.get_remote_sender_id(), amount, crit)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_enemy_status(node_name: String, id: String, seconds: float, power: float) -> void:
	var enemy: EnemyBase = _reported_enemy(node_name)
	if not enemy or not CLIENT_STATUSES.has(StringName(id)) or not is_finite(seconds) or not is_finite(power):
		return
	enemy.apply_status(StringName(id), clampf(seconds, 0.0, 10.0), clampf(power, 0.0, 200.0), null, multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "unreliable")
func _rpc_enemy_shove(node_name: String, dir: Vector3, force: float) -> void:
	var enemy: EnemyBase = _reported_enemy(node_name)
	if enemy and dir.is_finite() and is_finite(force):
		enemy.apply_knockback(dir, clampf(force, 0.0, 20.0))


@rpc("any_peer", "call_remote", "reliable")
func _rpc_enemy_stun(node_name: String, seconds: float) -> void:
	var enemy: EnemyBase = _reported_enemy(node_name)
	if enemy and is_finite(seconds):
		enemy.stun(clampf(seconds, 0.0, 3.0))


func _setup_enemy_multiplayer(enemy: CharacterBody3D) -> void:
	# the host owns every enemy; clients get its transform and health
	if not Game.is_online():
		return
	enemy.set_multiplayer_authority(1)

	var interp: NetworkInterpolator = NetworkInterpolator.new()
	interp.name = "NetInterp"
	enemy.add_child(interp)

	var sync: MultiplayerSynchronizer = MultiplayerSynchronizer.new()
	sync.name = "EnemySync"
	sync.set_multiplayer_authority(1)
	sync.replication_interval = 0.05

	var config: SceneReplicationConfig = SceneReplicationConfig.new()
	# paths are relative to the synchronizer's root, which is the enemy
	config.add_property(NodePath("NetInterp:sync_position"))
	config.add_property(NodePath("NetInterp:sync_rotation"))
	if enemy.has_node("HealthComponent"):
		config.add_property(NodePath("HealthComponent:current_health"))
		config.add_property(NodePath("HealthComponent:shield"))
		config.add_property(NodePath("HealthComponent:invulnerable"))
	sync.replication_config = config
	enemy.add_child(sync)
