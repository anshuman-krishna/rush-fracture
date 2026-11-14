class_name Needler
extends BaseWeapon

# "needle hive" — a stream of quills that bend toward whatever is near the
# crosshair and stay stuck in it. enough quills in one body detonate together,
# so it starts weak and ends every fight with a bang.

const AIM_ASSIST_ANGLE: float = 0.11
const STACK_LIFETIME: float = 2.5
const SPREAD: float = 0.028

var stacks_to_detonate: int = 8
var detonate_damage: float = 60.0
var detonate_radius: float = 3.4

# enemy instance id -> {count, expires (sim seconds)}
var _stacks: Dictionary = {}
var _clock: float = 0.0


func _configure() -> void:
	weapon_id = &"needler"
	display_name = "needle hive"
	model_path = "res://assets/models/grafted-brood-needler.glb"
	grip_lift = 0.08
	base_damage = 6.0
	fire_interval = 0.062
	weapon_range = 70.0
	weak_mult = 1.3
	recoil_pitch = 0.16
	shake_on_fire = 0.35
	view_kick = 0.012
	tracer_color = Color(1.0, 0.35, 0.8)
	fire_sound = &"needle_fire"
	fire_volume = -10.0


func reset_state() -> void:
	super.reset_state()
	_stacks.clear()


func _tick(delta: float, held: bool, _pressed: bool, _released: bool) -> void:
	_clock += delta
	if not held or not _can_fire():
		return
	_start_cooldown()

	var dir: Vector3 = _spread_dir(SPREAD)
	var assist: Node3D = _assist_target()
	if assist:
		var to: Vector3 = (assist.aim_point() if assist.has_method("aim_point") else assist.global_position) - _aim_origin()
		dir = dir.slerp(to.normalized(), 0.65).normalized()

	var result: Dictionary = _hitscan(dir, base_damage, {"tracer_width": 0.006, "tracer_time": 0.1})
	_after_shot(0.5)
	if not result.is_empty() and result.collider is CharacterBody3D:
		_add_stack(result.collider as CharacterBody3D, result.position)


func _tick_holstered(delta: float) -> void:
	_clock += delta


func _assist_target() -> Node3D:
	var origin: Vector3 = _aim_origin()
	var aim: Vector3 = _aim_dir()
	var best: Node3D = null
	var best_angle: float = AIM_ASSIST_ANGLE
	for e: Node3D in Combat.living_enemies(get_tree()):
		var p: Vector3 = e.aim_point() if e.has_method("aim_point") else e.global_position
		var to: Vector3 = p - origin
		var dist: float = to.length()
		if dist > weapon_range or dist < 0.5:
			continue
		var angle: float = aim.angle_to(to / dist)
		if angle < best_angle:
			best_angle = angle
			best = e
	return best


func _add_stack(enemy: CharacterBody3D, at: Vector3) -> void:
	var id: int = enemy.get_instance_id()
	var entry: Dictionary = _stacks.get(id, {"count": 0, "expires": 0.0})
	if entry.expires < _clock:
		entry.count = 0
	entry.count += 1
	entry.expires = _clock + STACK_LIFETIME * (2.0 if has_flag(&"barbed") else 1.0)
	if has_flag(&"barbed") and enemy.has_method("apply_status"):
		enemy.apply_status(&"slow", 1.5, 0.2, owner_player)
	var needed: int = stacks_to_detonate - (2 if has_flag(&"hair_trigger") else 0)
	if entry.count >= needed:
		_stacks.erase(id)
		_detonate(enemy, at)
	else:
		_stacks[id] = entry

	# drop expired entries now and then so the table can't grow forever
	if _stacks.size() > 24:
		for key: Variant in _stacks.keys():
			if _stacks[key].expires < _clock:
				_stacks.erase(key)


func _detonate(enemy: CharacterBody3D, at: Vector3) -> void:
	var combat: Combat = Game.combat()
	if not combat:
		return
	var caustic: bool = has_flag(&"caustic")
	var radius: float = detonate_radius * _stat(&"blast_radius") * (1.4 if caustic else 1.0)
	var centre: Vector3 = enemy.aim_point() if enemy.has_method("aim_point") else at
	Vfx.blast(centre, radius, tracer_color)
	Game.sfx_at(&"explosion_small", centre, -5.0, 0.2)
	Game.shake(3.0, centre, 25.0)
	if caustic:
		# before the blast, so anything it leaves alive is already burning
		for e: Node3D in Combat.enemies_in_radius(get_tree(), centre, radius):
			if e.has_method("apply_status"):
				e.apply_status(&"burn", 3.0, 16.0, owner_player)
	combat.blast(centre, radius, detonate_damage, {"weapon": weapon_id})


## quills currently stuck in the enemy under the crosshair, for the hud.
func hud_state() -> Dictionary:
	var best: int = 0
	for key: Variant in _stacks:
		if _stacks[key].expires >= _clock:
			best = maxi(best, _stacks[key].count)
	if best <= 0:
		return {}
	var needed: int = stacks_to_detonate - (2 if has_flag(&"hair_trigger") else 0)
	return {"meter": float(best) / float(needed), "meter_color": tracer_color, "label": "quills"}
