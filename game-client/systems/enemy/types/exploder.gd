extends EnemyBase

# "swelling spore" — sprints at you and detonates. it stops and swells for a
# moment first, which is your window to get out of the circle or to pop it
# early, in which case the blast is your weapon against everything near it.

const TRIGGER_RANGE: float = 3.2
const FUSE: float = 0.6
const BLAST_RADIUS: float = 4.6
const FRIENDLY_DAMAGE: float = 55.0

var _fuse: float = -1.0
var _exploded: bool = false
var _core: MeshInstance3D


func _setup() -> void:
	weak_ratio = 0.0


func _build_visual() -> void:
	super._build_visual()
	_core = _find_part("fuse_core")


func _ai(delta: float, dist: float) -> void:
	if _fuse >= 0.0:
		_fuse -= delta
		_brake(40.0, delta)
		if _fuse <= 0.0:
			_detonate(true)
		return
	if dist <= TRIGGER_RANGE:
		_fuse = FUSE
		_warn_circle(global_position, BLAST_RADIUS, FUSE, Color(1.0, 0.4, 0.1))
		_flare(FUSE)
		Game.sfx_at(&"fuse", global_position, -6.0, 0.1)
		return
	_chase(delta, 1.0, 28.0)


func _tick_visual(delta: float) -> void:
	# the model swells as the fuse burns
	if model and _fuse >= 0.0:
		var t: float = 1.0 - clampf(_fuse / FUSE, 0.0, 1.0)
		model.scale = Vector3.ONE * (1.0 + t * 0.45 + sin(Time.get_ticks_msec() * 0.03) * 0.04)
	elif model and _spawn_timer <= 0.0 and not is_dying:
		model.scale = model.scale.lerp(Vector3.ONE, clampf(8.0 * delta, 0.0, 1.0))


func _on_death(_info: DamageInfo) -> void:
	# shot before it reached you: it still goes off where it stands
	_detonate(false)


func _detonate(self_triggered: bool) -> void:
	if _exploded:
		return
	_exploded = true
	var at: Vector3 = aim_point()
	Vfx.blast(at, BLAST_RADIUS, Color(1.0, 0.45, 0.1))
	Game.sfx_at(&"explosion", at, -2.0, 0.12)
	Game.shake(5.0, at, 26.0)
	_hit_players_in_radius(global_position, BLAST_RADIUS, damage())

	# the blast hurts the brood too. through the player's combat when one
	# exists, so a chain of spores popping counts as the player's kills.
	var combat: Combat = Game.combat()
	if combat:
		combat.blast(at, BLAST_RADIUS, FRIENDLY_DAMAGE, {"knockback": 8.0})
	else:
		for e: Node3D in Combat.enemies_in_radius(get_tree(), at, BLAST_RADIUS):
			if e != self:
				var hc: HealthComponent = e.get_node_or_null("HealthComponent") as HealthComponent
				if hc:
					hc.take_damage(int(FRIENDLY_DAMAGE), DamageInfo.make(int(FRIENDLY_DAMAGE), DamageInfo.KIND_BLAST))

	if self_triggered and health and health.is_alive():
		# going through the health component is what tells the room this
		# enemy is gone; skipping it used to leave rooms unclearable
		health.kill()
