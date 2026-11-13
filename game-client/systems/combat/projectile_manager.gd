class_name ProjectileManager
extends Node3D

# simulates every travelling projectile in one place: the player's launched
# shots and all enemy fire. each one is stepped with a swept ray per physics
# tick, so fast projectiles never tunnel, and visuals come from a small pool.
#
# enemy fire is real, dodgeable projectiles (the old ranged enemies hit
# instantly, even through cover). in multiplayer the host broadcasts each
# enemy shot and every peer simulates its own copy, damaging only the player
# it owns, the same model the arena hazards use.

const TEAM_PLAYER: int = 0
const TEAM_ENEMY: int = 1
const POOL_SIZE: int = 96
const MAX_ACTIVE: int = 220

const SHADER_CODE: String = """
shader_type spatial;
render_mode unshaded, shadows_disabled;
instance uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.5);
	ALBEDO = tint.rgb * (1.6 + rim * 2.2);
}
"""

# enemy projectile presets. velocity and damage come from the shooter.
const ENEMY_KINDS: Dictionary = {
	&"bolt": {"radius": 0.16, "shape": "orb", "gravity": 0.0, "life": 4.0, "hit_radius": 0.5},
	&"needle": {"radius": 0.09, "shape": "needle", "gravity": 0.0, "life": 3.0, "hit_radius": 0.42},
	&"orb": {"radius": 0.34, "shape": "orb", "gravity": 0.0, "life": 6.0, "hit_radius": 0.7},
	&"mortar": {"radius": 0.3, "shape": "orb", "gravity": 18.0, "life": 6.0, "hit_radius": 0.6, "blast": 3.4},
	&"big_mortar": {"radius": 0.45, "shape": "orb", "gravity": 18.0, "life": 7.0, "hit_radius": 0.8, "blast": 5.0},
}

class Shot extends RefCounted:
	var alive: bool = true
	var team: int = 0
	var position: Vector3
	var velocity: Vector3
	var gravity: float = 0.0
	var life: float = 3.0
	var damage: float = 0.0
	var radius: float = 0.15
	var hit_radius: float = 0.5
	var bounces: int = 0
	var pierce: bool = false
	var color: Color = Color.WHITE
	var shape: String = "orb"
	var spin: float = 0.0
	var blast: float = 0.0
	var pool: float = 0.0
	var kind: StringName = &""
	var trail: bool = true
	var on_hit: Callable
	var on_expire: Callable
	var source: Node
	var mesh: MeshInstance3D
	var hit_cooldowns: Dictionary = {}
	var data: Dictionary = {}

var _shots: Array[Shot] = []
var _free_meshes: Dictionary = {"orb": [], "needle": [], "disc": []}
var _material: ShaderMaterial
var _meshes: Dictionary = {}
var _stepping: bool = false


func _ready() -> void:
	var shader: Shader = Shader.new()
	shader.code = SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = shader

	var orb: SphereMesh = SphereMesh.new()
	orb.radius = 1.0
	orb.height = 2.0
	orb.radial_segments = 12
	orb.rings = 6
	_meshes["orb"] = orb

	var needle: CapsuleMesh = CapsuleMesh.new()
	needle.radius = 0.5
	needle.height = 5.0
	needle.radial_segments = 6
	needle.rings = 2
	_meshes["needle"] = needle

	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.16
	disc.radial_segments = 14
	_meshes["disc"] = disc


func active_count() -> int:
	return _shots.size()


func clear_all() -> void:
	if _stepping:
		# a projectile just ended the room from inside the step loop: mark
		# everything dead and let the loop release them as it passes
		for s: Shot in _shots:
			s.alive = false
		return
	for s: Shot in _shots:
		_release(s)
	_shots.clear()


# --- spawning ---------------------------------------------------------------

## launches a projectile owned by the local player.
##
## cfg keys: position, velocity (required); gravity, life, radius, color,
## shape ("orb" | "needle" | "disc"), bounces, pierce, spin, damage, trail,
## on_hit: Callable(shot, collider, position, normal) -> bool (true = stop here),
## on_expire: Callable(shot, position), data: Dictionary.
func fire_player(cfg: Dictionary) -> Shot:
	var s: Shot = _make(cfg)
	if s:
		s.team = TEAM_PLAYER
	return s


## launches an enemy projectile of a preset kind. the host calls this and it
## is replicated to every other peer.
func fire_enemy(kind: StringName, origin: Vector3, velocity: Vector3, damage: int,
		color: Color = Color(1.0, 0.35, 0.2), target: Vector3 = Vector3.INF, pool_seconds: float = 0.0) -> void:
	_spawn_enemy(kind, origin, velocity, damage, color, target, pool_seconds)
	if Game.is_online() and multiplayer.is_server():
		_rpc_enemy_shot.rpc(String(kind), origin, velocity, damage, color, target, pool_seconds)


## lobs an enemy mortar that lands on `target` after `flight_time` seconds,
## with a ground warning at the landing point.
func fire_enemy_mortar(origin: Vector3, target: Vector3, flight_time: float, damage: int,
		color: Color = Color(0.6, 1.0, 0.2), kind: StringName = &"mortar", pool_seconds: float = 0.0) -> void:
	var g: float = ENEMY_KINDS[kind].gravity
	var t: float = maxf(0.3, flight_time)
	var velocity: Vector3 = (target - origin) / t
	velocity.y += 0.5 * g * t
	fire_enemy(kind, origin, velocity, damage, color, target, pool_seconds)


@rpc("authority", "call_remote", "reliable")
func _rpc_enemy_shot(kind: String, origin: Vector3, velocity: Vector3, damage: int, color: Color,
		target: Vector3, pool_seconds: float) -> void:
	_spawn_enemy(StringName(kind), origin, velocity, damage, color, target, pool_seconds)


func _spawn_enemy(kind: StringName, origin: Vector3, velocity: Vector3, damage: int, color: Color,
		target: Vector3, pool_seconds: float) -> void:
	var preset: Dictionary = ENEMY_KINDS.get(kind, ENEMY_KINDS[&"bolt"])
	var s: Shot = _make({
		"position": origin, "velocity": velocity, "gravity": preset.gravity, "life": preset.life,
		"radius": preset.radius, "shape": preset.shape, "color": color, "damage": damage,
	})
	if not s:
		return
	s.team = TEAM_ENEMY
	s.kind = kind
	s.hit_radius = preset.hit_radius
	s.blast = preset.get("blast", 0.0)
	s.pool = pool_seconds
	if s.blast > 0.0 and target != Vector3.INF:
		var g: float = preset.gravity
		# time to land, for the warning circle: solve the vertical arc
		var flight: float = 1.0
		if g > 0.0:
			var dy: float = origin.y - target.y
			flight = (velocity.y + sqrt(maxf(0.0, velocity.y * velocity.y + 2.0 * g * dy))) / g
		Vfx.telegraph_circle(target, s.blast, clampf(flight, 0.2, 6.0), color)


func _make(cfg: Dictionary) -> Shot:
	if _shots.size() >= MAX_ACTIVE:
		return null
	var s: Shot = Shot.new()
	s.position = cfg.get("position", Vector3.ZERO)
	s.velocity = cfg.get("velocity", Vector3.ZERO)
	s.gravity = cfg.get("gravity", 0.0)
	s.life = cfg.get("life", 3.0)
	s.radius = cfg.get("radius", 0.15)
	s.color = cfg.get("color", Color.WHITE)
	s.shape = cfg.get("shape", "orb")
	s.bounces = cfg.get("bounces", 0)
	s.pierce = cfg.get("pierce", false)
	s.spin = cfg.get("spin", 0.0)
	s.damage = cfg.get("damage", 0.0)
	s.trail = cfg.get("trail", true)
	s.on_hit = cfg.get("on_hit", Callable())
	s.on_expire = cfg.get("on_expire", Callable())
	s.source = cfg.get("source", null)
	s.data = cfg.get("data", {})
	s.mesh = _acquire(s.shape)
	s.mesh.scale = Vector3.ONE * s.radius
	s.mesh.set_instance_shader_parameter("tint", s.color)
	s.mesh.position = s.position
	s.mesh.visible = true
	_orient(s)
	_shots.append(s)
	return s


func _acquire(shape: String) -> MeshInstance3D:
	var bucket: Array = _free_meshes.get(shape, _free_meshes["orb"])
	if not bucket.is_empty():
		return bucket.pop_back()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = _meshes.get(shape, _meshes["orb"])
	mi.material_override = _material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("shape", shape)
	add_child(mi)
	return mi


func _release(s: Shot) -> void:
	s.alive = false
	if is_instance_valid(s.mesh):
		s.mesh.visible = false
		var shape: String = s.mesh.get_meta("shape", "orb")
		if (_free_meshes[shape] as Array).size() < POOL_SIZE:
			_free_meshes[shape].append(s.mesh)
		else:
			s.mesh.queue_free()
	s.mesh = null


# --- simulation -------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _shots.is_empty():
		return
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var players: Array[CharacterBody3D] = []
	var pm: PlayerManager = Game.players()
	if pm:
		players = pm.get_all_players()

	_stepping = true
	var i: int = 0
	while i < _shots.size():
		var s: Shot = _shots[i]
		if s.alive:
			_step(s, delta, space, players)
		if not s.alive:
			_release(s)
			_shots.remove_at(i)
		else:
			i += 1
	_stepping = false


func _step(s: Shot, delta: float, space: PhysicsDirectSpaceState3D, players: Array[CharacterBody3D]) -> void:
	s.life -= delta
	if s.life <= 0.0:
		_expire(s, s.position)
		return

	for key: Variant in s.hit_cooldowns.keys():
		s.hit_cooldowns[key] -= delta
		if s.hit_cooldowns[key] <= 0.0:
			s.hit_cooldowns.erase(key)

	s.velocity.y -= s.gravity * delta
	var from: Vector3 = s.position
	var to: Vector3 = from + s.velocity * delta

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	if s.team == TEAM_PLAYER:
		query.collision_mask = Layers.WORLD | Layers.ENEMY
		# in a duel the other players are targets too (the shooter is excluded below)
		var combat: Combat = Game.combat()
		if combat and combat.pvp_manager and combat.pvp_manager.is_active():
			query.collision_mask |= Layers.PLAYER
		var exclude: Array[RID] = []
		if is_instance_valid(s.source) and s.source is CollisionObject3D:
			exclude.append((s.source as CollisionObject3D).get_rid())
		for key: Variant in s.hit_cooldowns:
			exclude.append(key)
		query.exclude = exclude
	else:
		query.collision_mask = Layers.WORLD

	var hit: Dictionary = space.intersect_ray(query)

	if s.team == TEAM_ENEMY and _enemy_shot_vs_players(s, from, to if hit.is_empty() else hit.position, players):
		return

	if hit.is_empty():
		s.position = to
	else:
		s.position = hit.position
		if not _resolve_hit(s, hit):
			return

	if s.trail and from.distance_squared_to(s.position) > 0.01:
		Vfx.tracer(from, s.position, Color(s.color.r, s.color.g, s.color.b, 0.6), 0.14, s.radius * 0.45, 0.0)
	if is_instance_valid(s.mesh):
		s.mesh.position = s.position
		_orient(s)
		if s.spin != 0.0:
			s.mesh.rotate_object_local(Vector3.UP, s.spin * delta)


## returns false if the shot ended.
func _resolve_hit(s: Shot, hit: Dictionary) -> bool:
	var collider: Object = hit.collider
	var is_body: bool = collider is CharacterBody3D

	if s.team == TEAM_PLAYER and is_body:
		var stop: bool = true
		if s.on_hit.is_valid():
			stop = bool(s.on_hit.call(s, collider, hit.position, hit.normal))
		if s.pierce and not stop:
			s.hit_cooldowns[(collider as CollisionObject3D).get_rid()] = 0.3
			return true
		_expire(s, hit.position)
		return false

	# world geometry
	if collider is StaticBody3D and (collider as StaticBody3D).has_meta("breakable"):
		var rooms: RoomController = Game.rooms()
		if rooms:
			rooms.damage_breakable(collider as StaticBody3D, 2 if s.team == TEAM_PLAYER else 1)

	if s.bounces > 0:
		s.bounces -= 1
		s.velocity = s.velocity.bounce(hit.normal) * 0.94
		s.position = hit.position + hit.normal * 0.06
		Vfx.sparks(hit.position, hit.normal, s.color, 5.0, 50.0)
		Game.sfx_at(&"ricochet", hit.position, -10.0, 0.2)
		if s.on_hit.is_valid() and s.data.get("notify_bounce", false):
			s.on_hit.call(s, collider, hit.position, hit.normal)
		return true

	_expire(s, hit.position + hit.normal * 0.05)
	return false


func _enemy_shot_vs_players(s: Shot, from: Vector3, to: Vector3, players: Array[CharacterBody3D]) -> bool:
	for p: CharacterBody3D in players:
		if not is_instance_valid(p) or p.get("is_dead") == true:
			continue
		var centre: Vector3 = p.global_position
		var closest: Vector3 = Geometry3D.get_closest_point_to_segment(centre, from, to)
		var offset: Vector3 = closest - centre
		# a player is a tall capsule: generous vertically, tight horizontally
		if Vector2(offset.x, offset.z).length() > s.hit_radius or absf(offset.y) > 1.0:
			continue
		if s.blast > 0.0:
			_expire(s, closest)
			return true
		if _is_owned_locally(p):
			var info: DamageInfo = DamageInfo.make(int(s.damage), DamageInfo.KIND_PROJECTILE)
			info.position = closest
			info.direction = s.velocity.normalized()
			p.take_damage(int(s.damage), info)
		Vfx.sparks(closest, -s.velocity.normalized(), s.color, 6.0, 70.0)
		s.alive = false
		return true
	return false


func _expire(s: Shot, at: Vector3) -> void:
	s.alive = false
	if s.team == TEAM_ENEMY:
		if s.blast > 0.0:
			_enemy_blast(s, at)
		else:
			Vfx.sparks(at, Vector3.UP, s.color, 4.0, 90.0)
	if s.on_expire.is_valid():
		s.on_expire.call(s, at)


func _enemy_blast(s: Shot, at: Vector3) -> void:
	Vfx.blast(at, s.blast, s.color)
	Game.sfx_at(&"explosion_small", at, -4.0, 0.15)
	Game.shake(4.0, at, 22.0)
	var pm: PlayerManager = Game.players()
	if pm:
		for p: CharacterBody3D in pm.get_all_players():
			if not is_instance_valid(p) or not _is_owned_locally(p):
				continue
			var d: float = p.global_position.distance_to(at)
			if d <= s.blast + 0.4:
				var info: DamageInfo = DamageInfo.make(int(s.damage), DamageInfo.KIND_BLAST)
				info.position = at
				p.take_damage(int(s.damage), info)
	if s.pool > 0.0:
		var rooms: RoomController = Game.rooms()
		if rooms:
			rooms.add_timed_hazard(Vector3(at.x, 0.0, at.z), s.blast * 0.8, maxi(3, int(s.damage * 0.25)), s.pool, s.color)


func _orient(s: Shot) -> void:
	if s.shape == "orb" or not is_instance_valid(s.mesh):
		return
	var v: Vector3 = s.velocity
	if v.length() < 0.1:
		return
	if s.shape == "needle":
		# capsule long axis is +Y
		var dir: Vector3 = v.normalized()
		var up: Vector3 = Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
		var x_axis: Vector3 = up.cross(dir).normalized()
		var z_axis: Vector3 = x_axis.cross(dir).normalized()
		s.mesh.basis = Basis(x_axis, dir, z_axis).scaled(Vector3.ONE * s.radius)


func _is_owned_locally(p: CharacterBody3D) -> bool:
	if not Game.is_online():
		return true
	return p.is_multiplayer_authority()
