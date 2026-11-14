extends CharacterBody3D

# first-person player body.
#
# movement is built around keeping speed: dash and slide push you past your
# normal run speed, air strafing steers that speed without bleeding it, and
# landing into a jump or slide carries it on. every tunable lives in `stats`
# (a StatBlock) so upgrades, mutations, combos and fracture events can each
# add and remove their own modifier without stepping on one another.

signal damaged(amount: int, info: DamageInfo)
signal died
signal healed(amount: int)
signal dashed
signal jumped
signal landed(fall_speed: float)
signal slide_started
signal slammed(impact_position: Vector3, fall_speed: float)
signal death_defied
signal dodged
## a hit was soaked whole by something (a bone plate)
signal absorbed

const INTERP_SPEED: float = 18.0
const STAND_HEIGHT: float = 1.8
const SLIDE_HEIGHT: float = 1.0
const HEAD_STAND_Y: float = 0.7
const HEAD_SLIDE_Y: float = 0.05
const COYOTE_TIME: float = 0.12
const JUMP_BUFFER: float = 0.13
const BHOP_GRACE: float = 0.12
const SLIDE_MIN_SPEED: float = 6.0
const SLIDE_END_SPEED: float = 4.5
const SLIDE_BOOST: float = 4.0
const SLIDE_COOLDOWN: float = 0.35
const SLAM_SPEED: float = 44.0
const SLAM_MIN_HEIGHT: float = 1.6
const DASH_INVULN: float = 0.18
const HURT_GRACE: float = 0.08
const VOID_Y: float = -14.0
const MAX_HORIZONTAL_SPEED: float = 46.0

const BODY_MODEL: String = "res://assets/models/grafted-brood-host.glb"

var stats: StatBlock = StatBlock.new()
var input: InputProvider = InputProvider.new()

var health: int = 100
var is_dead: bool = false
## extra lives against a killing blow (second wind upgrade)
var lethal_guards: int = 0
## callables (info: DamageInfo) -> float multiplier, for conditional defences
var damage_filters: Array[Callable] = []

var is_dashing: bool = false
var is_sliding: bool = false
var is_slamming: bool = false
var dash_charges_ready: int = 1
var mouse_sensitivity: float = 0.002
var invert_mouse_y: bool = false
var gamepad_look_sensitivity: float = 3.0
var controls_locked: bool = false

# network sync targets — the synchronizer writes these, puppets lerp to them
var sync_position: Vector3 = Vector3.ZERO
var sync_rotation_y: float = 0.0
var sync_head_rotation_x: float = 0.0
var sync_velocity: Vector3 = Vector3.ZERO
var sync_flags: int = 0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _dash_timer: float = 0.0
var _dash_recharge: float = 0.0
var _dash_direction: Vector3 = Vector3.ZERO
var _invuln_timer: float = 0.0
var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _air_jumps_used: int = 0
var _landing_grace: float = 0.0
var _slide_cooldown: float = 0.0
var _was_on_floor: bool = true
var _fall_speed: float = 0.0
var _slam_start_y: float = 0.0
var _step_distance: float = 0.0
var _base_mask: int = Layers.WORLD | Layers.ENEMY
var _launch_lock: float = 0.0
var _body: Node3D

@onready var head: Node3D = $Head
@onready var _collision: CollisionShape3D = $CollisionShape3D

var max_health: int:
	get:
		return maxi(1, int(round(stats.value(&"max_health"))))


func _init() -> void:
	_init_stats()


func _ready() -> void:
	add_to_group("player")
	collision_layer = Layers.PLAYER
	collision_mask = _base_mask
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50.0)

	# each player needs its own shape resource, since sliding resizes it
	if _collision and _collision.shape:
		_collision.shape = _collision.shape.duplicate()

	health = max_health
	dash_charges_ready = dash_charges()
	stats.changed.connect(_on_stat_changed)

	sync_position = global_position
	sync_rotation_y = rotation.y
	if head:
		sync_head_rotation_x = head.rotation.x

	if _is_local_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		apply_settings(GameSettings.load_settings())
		var cam: Camera3D = get_node_or_null("Head/Camera3D") as Camera3D
		if cam:
			cam.current = true
	else:
		_build_body()

	var pm: PlayerManager = _find_player_manager()
	if pm:
		pm.register_player(self)


func _exit_tree() -> void:
	var pm: PlayerManager = _find_player_manager()
	if pm:
		pm.unregister_player(self)


func _init_stats() -> void:
	var defaults: Dictionary = {
		&"max_health": 100.0,
		&"move_speed": 12.0,
		&"acceleration": 62.0,
		&"friction": 40.0,
		&"air_acceleration": 30.0,
		&"air_friction": 1.2,
		&"jump_force": 10.0,
		&"air_jumps": 0.0,
		&"gravity_scale": 1.0,
		&"dash_force": 28.0,
		&"dash_duration": 0.14,
		&"dash_cooldown": 0.6,
		&"dash_charges": 1.0,
		&"slide_friction": 2.2,
		&"damage_taken": 1.0,
		&"damage": 1.0,
		&"fire_rate": 1.0,
		&"crit_chance": 0.05,
		&"crit_mult": 2.0,
		&"weak_damage": 1.0,
		&"blast_damage": 1.0,
		&"blast_radius": 1.0,
		&"dot_damage": 1.0,
		&"heat_gain": 1.0,
		&"recoil": 1.0,
		&"swap_speed": 1.0,
		&"pickup_radius": 3.5,
		&"essence_gain": 1.0,
		&"orb_heal": 1.0,
		&"combo_time": 1.0,
		&"ability_charge": 1.0,
		&"fov_bias": 0.0,
	}
	for key: StringName in defaults:
		stats.set_base(key, defaults[key])


## convenience for the many readers that only want the final number.
func stat(key: StringName) -> float:
	return stats.value(key)


func dash_charges() -> int:
	return maxi(1, int(round(stats.value(&"dash_charges"))))


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


## 0..1 progress toward the next dash charge (1 when a charge is ready and none recharging).
func dash_recharge_ratio() -> float:
	if dash_charges_ready >= dash_charges():
		return 1.0
	var cd: float = maxf(0.05, stats.value(&"dash_cooldown"))
	return clampf(1.0 - _dash_recharge / cd, 0.0, 1.0)


func is_invulnerable() -> bool:
	return _invuln_timer > 0.0


func grant_invulnerability(seconds: float) -> void:
	_invuln_timer = maxf(_invuln_timer, seconds)


func apply_settings(settings: GameSettings) -> void:
	mouse_sensitivity = settings.mouse_sensitivity
	invert_mouse_y = settings.invert_mouse_y
	var cam: Node = get_node_or_null("Head/Camera3D")
	if cam and cam.has_method("apply_settings"):
		cam.apply_settings(settings)


## restores the body for a fresh run. modifiers are cleared by whoever owns them.
func reset_for_run(spawn_position: Vector3) -> void:
	is_dead = false
	is_dashing = false
	is_slamming = false
	_end_slide(true)
	lethal_guards = 0
	damage_filters.clear()
	velocity = Vector3.ZERO
	global_position = spawn_position
	_invuln_timer = 0.0
	_dash_recharge = 0.0
	_air_jumps_used = 0
	_launch_lock = 0.0
	controls_locked = false
	collision_mask = _base_mask
	health = max_health
	dash_charges_ready = dash_charges()


func teleport(to: Vector3) -> void:
	global_position = to
	velocity = Vector3.ZERO
	sync_position = to


# --- input ------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not _is_local_authority() or is_dead or controls_locked:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_look(-motion.screen_relative.x * mouse_sensitivity, -motion.screen_relative.y * mouse_sensitivity)


func _look(yaw: float, pitch: float) -> void:
	rotate_y(yaw)
	if invert_mouse_y:
		pitch = -pitch
	head.rotation.x = clampf(head.rotation.x + pitch, -PI / 2.0 + 0.02, PI / 2.0 - 0.02)


# --- simulation -------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not _is_local_authority():
		_puppet_process(delta)
		return

	_invuln_timer = maxf(0.0, _invuln_timer - delta)
	_slide_cooldown = maxf(0.0, _slide_cooldown - delta)
	_launch_lock = maxf(0.0, _launch_lock - delta)
	_recharge_dash(delta)

	if global_position.y < VOID_Y:
		_recover_from_void()

	if is_dead:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		velocity.y -= _gravity * delta
		move_and_slide()
		_write_sync()
		return

	var look: Vector2 = input.get_look_vector() if not controls_locked else Vector2.ZERO
	if look != Vector2.ZERO:
		_look(-look.x * gamepad_look_sensitivity * delta, -look.y * gamepad_look_sensitivity * delta)

	var on_floor: bool = is_on_floor()
	if on_floor:
		_coyote = COYOTE_TIME
		_air_jumps_used = 0
	else:
		_coyote = maxf(0.0, _coyote - delta)
		_fall_speed = maxf(_fall_speed, -velocity.y)
	_landing_grace = maxf(0.0, _landing_grace - delta)

	var wish: Vector3 = Vector3.ZERO
	if not controls_locked:
		var mv: Vector2 = input.get_move_vector()
		if mv.length() > 1.0:
			mv = mv.normalized()
		wish = transform.basis * Vector3(mv.x, 0, mv.y)
		wish.y = 0.0

		if input.is_jump_pressed():
			_jump_buffer = JUMP_BUFFER
		if input.is_dash_pressed():
			_try_dash(wish)
		_handle_slide_input(on_floor)
	_jump_buffer = maxf(0.0, _jump_buffer - delta)

	if is_dashing:
		_dash_timer -= delta
		velocity = _dash_direction * stats.value(&"dash_force")
		if _dash_timer <= 0.0:
			_end_dash()
	else:
		_apply_gravity(delta, on_floor)
		_try_jump(on_floor)
		if is_sliding:
			_move_slide(delta, wish, on_floor)
		elif on_floor:
			_move_ground(delta, wish)
		else:
			_move_air(delta, wish)

	_limit_speed()
	move_and_slide()

	var now_on_floor: bool = is_on_floor()
	if now_on_floor and not _was_on_floor:
		_on_landed()
	_was_on_floor = now_on_floor
	if now_on_floor:
		_step_tick(delta)

	_write_sync()


func _puppet_process(delta: float) -> void:
	global_position = global_position.lerp(sync_position, clampf(INTERP_SPEED * delta, 0.0, 1.0))
	rotation.y = lerp_angle(rotation.y, sync_rotation_y, clampf(INTERP_SPEED * delta, 0.0, 1.0))
	velocity = sync_velocity
	if head:
		head.rotation.x = lerp_angle(head.rotation.x, sync_head_rotation_x, clampf(INTERP_SPEED * delta, 0.0, 1.0))
	if _body:
		var sliding: bool = (sync_flags & 1) != 0
		_body.scale.y = lerpf(_body.scale.y, 0.6 if sliding else 1.0, clampf(12.0 * delta, 0.0, 1.0))


func _write_sync() -> void:
	sync_position = global_position
	sync_rotation_y = rotation.y
	sync_velocity = velocity
	if head:
		sync_head_rotation_x = head.rotation.x
	sync_flags = (1 if is_sliding else 0) | (2 if is_dashing else 0)


func _apply_gravity(delta: float, on_floor: bool) -> void:
	if is_slamming:
		velocity.y = -SLAM_SPEED
		return
	if not on_floor:
		velocity.y -= _gravity * stats.value(&"gravity_scale") * delta


func _move_ground(delta: float, wish: Vector3) -> void:
	var cap: float = stats.value(&"move_speed")
	var hvel: Vector3 = Vector3(velocity.x, 0, velocity.z)
	var speed: float = hvel.length()

	# just landed while moving faster than a run: hold that speed for a
	# moment so a well-timed jump or slide carries it on
	if speed > cap + 0.5 and _landing_grace > 0.0:
		return

	if wish.length() > 0.01:
		var target: Vector3 = wish.normalized() * cap * minf(wish.length(), 1.0)
		var rate: float = stats.value(&"acceleration")
		if speed > cap + 0.5:
			# over speed: bleed toward run speed at friction rate, still steerable
			rate = stats.value(&"friction")
			target = wish.normalized() * cap
		hvel = hvel.move_toward(target, rate * delta)
	else:
		hvel = hvel.move_toward(Vector3.ZERO, stats.value(&"friction") * delta)
	velocity.x = hvel.x
	velocity.z = hvel.z


func _move_air(delta: float, wish: Vector3) -> void:
	var cap: float = stats.value(&"move_speed")
	var hvel: Vector3 = Vector3(velocity.x, 0, velocity.z)
	if _launch_lock <= 0.0 and wish.length() > 0.01:
		# classic air strafe: only add speed along the wish direction up to the
		# run cap, which lets you redirect momentum without ever losing it
		var dir: Vector3 = wish.normalized()
		var along: float = hvel.dot(dir)
		var add: float = clampf(cap - along, 0.0, stats.value(&"air_acceleration") * delta)
		hvel += dir * add
	else:
		var drag: float = stats.value(&"air_friction") * delta
		hvel = hvel.move_toward(Vector3.ZERO, drag)
	velocity.x = hvel.x
	velocity.z = hvel.z


func _move_slide(delta: float, wish: Vector3, on_floor: bool) -> void:
	var hvel: Vector3 = Vector3(velocity.x, 0, velocity.z)
	var speed: float = hvel.length()
	if on_floor:
		speed = maxf(0.0, speed - stats.value(&"slide_friction") * delta)
	if speed > 0.01:
		var dir: Vector3 = hvel.normalized()
		if wish.length() > 0.01:
			# gentle steering: lean the slide toward where you're holding
			dir = dir.slerp(wish.normalized(), clampf(2.2 * delta, 0.0, 1.0)).normalized()
		hvel = dir * speed
	velocity.x = hvel.x
	velocity.z = hvel.z
	if on_floor and speed < SLIDE_END_SPEED:
		_end_slide()


func _handle_slide_input(on_floor: bool) -> void:
	var held: bool = input.is_slide_held()
	var pressed: bool = input.is_slide_pressed()

	if is_sliding:
		if not held:
			_end_slide()
		return

	if pressed and not on_floor and not is_slamming and not is_dashing:
		if _height_above_ground() >= SLAM_MIN_HEIGHT:
			is_slamming = true
			_slam_start_y = global_position.y
			velocity.x *= 0.35
			velocity.z *= 0.35
			return

	if held and on_floor and _slide_cooldown <= 0.0 and not is_dashing and horizontal_speed() >= SLIDE_MIN_SPEED:
		_start_slide()


func _start_slide() -> void:
	is_sliding = true
	_set_crouched(true)
	var hvel: Vector3 = Vector3(velocity.x, 0, velocity.z)
	var speed: float = minf(hvel.length() + SLIDE_BOOST, maxf(hvel.length(), stats.value(&"move_speed") * 1.9))
	hvel = hvel.normalized() * speed
	velocity.x = hvel.x
	velocity.z = hvel.z
	slide_started.emit()


func _end_slide(force: bool = false) -> void:
	if not is_sliding and not force:
		return
	if is_sliding:
		_slide_cooldown = SLIDE_COOLDOWN
	is_sliding = false
	_set_crouched(false)


func _set_crouched(crouched: bool) -> void:
	if not _collision or not _collision.shape is CapsuleShape3D:
		return
	var capsule: CapsuleShape3D = _collision.shape as CapsuleShape3D
	if crouched:
		capsule.height = SLIDE_HEIGHT
		_collision.position.y = -(STAND_HEIGHT - SLIDE_HEIGHT) * 0.5
	else:
		capsule.height = STAND_HEIGHT
		_collision.position.y = 0.0


func _try_jump(on_floor: bool) -> void:
	if _jump_buffer <= 0.0:
		return
	var force: float = stats.value(&"jump_force")
	if on_floor or _coyote > 0.0:
		_jump_buffer = 0.0
		_coyote = 0.0
		is_slamming = false
		velocity.y = force
		if is_sliding:
			# slide hop: leave the ground with the slide's speed intact
			_end_slide()
			var hvel: Vector3 = Vector3(velocity.x, 0, velocity.z) * 1.06
			velocity.x = hvel.x
			velocity.z = hvel.z
		jumped.emit()
	elif _air_jumps_used < int(round(stats.value(&"air_jumps"))) and not is_slamming:
		_jump_buffer = 0.0
		_air_jumps_used += 1
		velocity.y = force * 0.95
		jumped.emit()


func _try_dash(wish: Vector3) -> void:
	if is_dashing or dash_charges_ready <= 0:
		return
	if wish.length() > 0.01:
		_dash_direction = wish.normalized()
	else:
		_dash_direction = -transform.basis.z
		_dash_direction.y = 0.0
		_dash_direction = _dash_direction.normalized()

	dash_charges_ready -= 1
	if _dash_recharge <= 0.0:
		_dash_recharge = maxf(0.05, stats.value(&"dash_cooldown"))
	is_dashing = true
	is_slamming = false
	_end_slide()
	_dash_timer = stats.value(&"dash_duration")
	_invuln_timer = maxf(_invuln_timer, DASH_INVULN)
	# pass through enemies while dashing
	collision_mask = Layers.WORLD
	velocity = _dash_direction * stats.value(&"dash_force")

	var cam: Node = get_node_or_null("Head/Camera3D")
	if cam and cam.has_method("dash_kick"):
		cam.dash_kick()
	dashed.emit()


func _end_dash() -> void:
	is_dashing = false
	collision_mask = _base_mask
	# come out of the dash still carrying more than run speed
	var carry: float = maxf(stats.value(&"move_speed") * 1.45, 0.0)
	velocity = _dash_direction * carry
	_landing_grace = BHOP_GRACE


func _recharge_dash(delta: float) -> void:
	var max_charges: int = dash_charges()
	if dash_charges_ready >= max_charges:
		_dash_recharge = 0.0
		return
	if _dash_recharge <= 0.0:
		_dash_recharge = maxf(0.05, stats.value(&"dash_cooldown"))
	_dash_recharge -= delta
	if _dash_recharge <= 0.0:
		dash_charges_ready += 1
		if dash_charges_ready < max_charges:
			_dash_recharge = maxf(0.05, stats.value(&"dash_cooldown"))


## takes `ratio` of a full cooldown off the dash charge that is recharging.
func refund_dash(ratio: float) -> void:
	if dash_charges_ready < dash_charges():
		_recharge_dash(maxf(0.05, stats.value(&"dash_cooldown")) * ratio)


func _on_landed() -> void:
	var speed: float = _fall_speed
	_fall_speed = 0.0
	_landing_grace = BHOP_GRACE
	if is_slamming:
		is_slamming = false
		var drop: float = maxf(0.0, _slam_start_y - global_position.y)
		slammed.emit(global_position - Vector3(0, STAND_HEIGHT * 0.5, 0), maxf(speed, drop * 6.0))
	landed.emit(speed)


func _limit_speed() -> void:
	var hvel: Vector2 = Vector2(velocity.x, velocity.z)
	if hvel.length() > MAX_HORIZONTAL_SPEED:
		hvel = hvel.normalized() * MAX_HORIZONTAL_SPEED
		velocity.x = hvel.x
		velocity.z = hvel.y
	velocity.y = clampf(velocity.y, -60.0, 60.0)


func _height_above_ground() -> float:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var from: Vector3 = global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -30.0, 0), Layers.WORLD)
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return 30.0
	return from.y - STAND_HEIGHT * 0.5 - hit.position.y


func _step_tick(delta: float) -> void:
	if is_sliding or is_dashing:
		return
	var speed: float = horizontal_speed()
	if speed < 3.0:
		_step_distance = 0.0
		return
	_step_distance += speed * delta
	if _step_distance >= 3.2:
		_step_distance = 0.0
		Game.sfx(&"step", -16.0, 0.15)


func _recover_from_void() -> void:
	# falling out of the arena costs health instead of ending the run outright
	teleport(Vector3(0, 3.0, 0))
	var info: DamageInfo = DamageInfo.make(15, DamageInfo.KIND_HAZARD)
	info.ignore_invulnerable = true
	_apply_damage_local(15, info)


# --- external pushes --------------------------------------------------------

## throws the player (jump pads, knock-ups). `lock` briefly suspends air
## steering so the arc is not cancelled by held input.
func launch(new_velocity: Vector3, lock: float = 0.0) -> void:
	is_slamming = false
	is_dashing = false
	collision_mask = _base_mask
	_end_slide()
	velocity = new_velocity
	_launch_lock = lock
	_air_jumps_used = 0
	_coyote = 0.0


func apply_impulse(impulse: Vector3) -> void:
	velocity += impulse


# --- health -----------------------------------------------------------------

func take_damage(amount: int, info: DamageInfo = null) -> void:
	if not _is_local_authority():
		# the caller (an enemy on the host, a hazard on another peer) does not
		# own this player; mutating health here would be overwritten by the
		# next sync from the real owner, so send it there.
		_rpc_request_damage.rpc_id(get_multiplayer_authority(), amount)
		return
	_apply_damage_local(amount, info)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_damage(amount: int) -> void:
	if not _is_local_authority():
		return
	_apply_damage_local(clampi(amount, 0, 500), null)


func _apply_damage_local(amount: int, info: DamageInfo) -> void:
	if is_dead or amount <= 0:
		return
	var forced: bool = info != null and info.ignore_invulnerable
	if _invuln_timer > 0.0 and not forced:
		dodged.emit()
		return

	var mult: float = stats.value(&"damage_taken")
	for filter: Callable in damage_filters:
		if filter.is_valid():
			mult *= float(filter.call(info))
	if mult <= 0.0:
		# soaked whole. a moment of grace, so one swing cannot take the plate and the health under it
		_invuln_timer = maxf(_invuln_timer, 0.35)
		absorbed.emit()
		return
	var actual: int = maxi(1, int(round(amount * mult)))

	if actual >= health and lethal_guards > 0:
		lethal_guards -= 1
		health = maxi(1, int(max_health * 0.3))
		_invuln_timer = 2.0
		damaged.emit(0, info)
		death_defied.emit()
		return

	health = maxi(0, health - actual)
	if not forced:
		_invuln_timer = maxf(_invuln_timer, HURT_GRACE)
	damaged.emit(actual, info)
	if health <= 0:
		is_dead = true
		is_dashing = false
		is_slamming = false
		collision_mask = _base_mask
		_end_slide(true)
		died.emit()


func heal(amount: int) -> int:
	if is_dead or amount <= 0:
		return 0
	var before: int = health
	health = mini(health + amount, max_health)
	var gained: int = health - before
	if gained > 0:
		healed.emit(gained)
	return gained


func _on_stat_changed(key: StringName) -> void:
	if key == &"max_health":
		health = mini(health, max_health)
	elif key == &"dash_charges":
		dash_charges_ready = mini(dash_charges_ready, dash_charges())


# --- helpers ----------------------------------------------------------------

func _build_body() -> void:
	# other players see this; the owner sees only their weapon
	if not ResourceLoader.exists(BODY_MODEL):
		return
	var scene: PackedScene = load(BODY_MODEL) as PackedScene
	if not scene:
		return
	_body = scene.instantiate() as Node3D
	_body.name = "Body"
	_body.position.y = -STAND_HEIGHT * 0.5
	add_child(_body)


func get_body() -> Node3D:
	return _body


func _find_player_manager() -> PlayerManager:
	var pm: PlayerManager = Game.players()
	if pm:
		return pm
	return get_node_or_null("/root/Main/PlayerManager") as PlayerManager


func _is_local_authority() -> bool:
	if not Game.is_online():
		return true
	return is_multiplayer_authority()
