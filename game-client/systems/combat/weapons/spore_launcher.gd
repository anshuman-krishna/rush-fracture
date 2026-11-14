class_name SporeLauncher
extends BaseWeapon

# "bile mortar" — lobs an explosive spore on an arc. the answer to packs, and
# to getting somewhere fast: the blast throws you as well as them.

const SPEED: float = 36.0
const GRAVITY: float = 14.0
const SELF_DAMAGE_RATIO: float = 0.2
const SELF_DAMAGE_CAP: int = 18
const SELF_KNOCK: float = 15.0

var blast_radius: float = 4.6


func _configure() -> void:
	weapon_id = &"spore_launcher"
	display_name = "bile mortar"
	model_path = "res://assets/models/grafted-brood-spore_launcher.glb"
	grip_lift = 0.1
	base_damage = 75.0
	fire_interval = 0.85
	weapon_range = 80.0
	recoil_pitch = 2.2
	shake_on_fire = 3.0
	view_kick = 0.09
	tracer_color = Color(0.65, 1.0, 0.25)
	fire_sound = &"launcher_fire"
	fire_volume = -3.0


func _tick(_delta: float, held: bool, _pressed: bool, _released: bool) -> void:
	if not held or not _can_fire():
		return
	var pm: ProjectileManager = Game.projectiles()
	if not pm:
		return
	_start_cooldown()
	var dir: Vector3 = _aim_dir()
	# start a little ahead of the eye so it never clips the shooter's own collider
	var origin: Vector3 = _aim_origin() + dir * 0.6
	var inherit: Vector3 = owner_player.velocity * 0.35 if is_instance_valid(owner_player) else Vector3.ZERO
	pm.fire_player({
		"position": origin,
		"velocity": dir * SPEED + Vector3(0, 2.5, 0) + inherit,
		"gravity": GRAVITY,
		"life": 5.0,
		"radius": 0.2,
		"color": tracer_color,
		"shape": "orb",
		"source": owner_player,
		"on_hit": _on_direct_hit,
		"on_expire": _on_explode,
	})
	_after_shot()


func _on_direct_hit(_shot: ProjectileManager.Shot, _collider: Object, _pos: Vector3, _normal: Vector3) -> bool:
	return true


func _on_explode(shot: ProjectileManager.Shot, at: Vector3) -> void:
	_explode(at, base_damage, blast_radius, not shot.data.get("bomblet", false))


func _explode(at: Vector3, damage: float, radius: float, spawn_cluster: bool) -> void:
	var combat: Combat = Game.combat()
	if not combat:
		return
	radius *= _stat(&"blast_radius")
	Vfx.blast(at, radius, tracer_color)
	Game.sfx_at(&"explosion", at, -2.0, 0.12)
	Game.shake(6.0, at, 30.0)
	combat.blast(at, radius, damage, {"weapon": weapon_id, "knockback": 9.0})
	if has_flag(&"napalm"):
		for e: Node3D in Combat.enemies_in_radius(get_tree(), at, radius):
			if e.has_method("apply_status"):
				e.apply_status(&"burn", 4.0, damage * 0.2, owner_player)

	# the blast does not care whose it is
	if is_instance_valid(owner_player):
		var to_player: Vector3 = owner_player.global_position - at
		var d: float = to_player.length()
		if d < radius:
			var k: float = 1.0 - d / radius
			owner_player.apply_impulse((to_player.normalized() + Vector3(0, 0.7, 0)).normalized() * SELF_KNOCK * k)
			var self_damage: int = mini(SELF_DAMAGE_CAP, int(damage * SELF_DAMAGE_RATIO * k))
			if self_damage > 0 and not has_flag(&"insulated"):
				owner_player.take_damage(self_damage, DamageInfo.make(self_damage, DamageInfo.KIND_SELF, owner_player))

	if spawn_cluster and has_flag(&"cluster"):
		var pm: ProjectileManager = Game.projectiles()
		if pm:
			for i: int in 3:
				var a: float = TAU * float(i) / 3.0 + randf() * 0.6
				pm.fire_player({
					"position": at + Vector3(0, 0.3, 0),
					"velocity": Vector3(cos(a) * 6.0, 8.0, sin(a) * 6.0),
					"gravity": 20.0, "life": 2.0, "radius": 0.12, "color": tracer_color,
					"source": owner_player, "data": {"bomblet": true},
					"on_hit": _on_direct_hit,
					"on_expire": func(_s: ProjectileManager.Shot, p: Vector3) -> void: _explode(p, base_damage * 0.35, blast_radius * 0.6, false),
				})


func hud_state() -> Dictionary:
	if _cooldown <= 0.0:
		return {}
	var total: float = fire_interval / maxf(0.1, _stat(&"fire_rate"))
	return {"meter": 1.0 - _cooldown / total, "meter_color": tracer_color, "label": "loading"}
