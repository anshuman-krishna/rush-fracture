extends CenterContainer

var hit_marker_timer: float = 0.0

@onready var crosshair_dot: ColorRect = $CrosshairDot
@onready var hit_marker: Label = $HitMarker


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit_marker.visible = false


func _process(delta: float) -> void:
	if hit_marker_timer > 0:
		hit_marker_timer -= delta
		if hit_marker_timer <= 0:
			hit_marker.visible = false


func show_hit() -> void:
	hit_marker.visible = true
	hit_marker_timer = 0.15
	_punch_scale()


func show_kill() -> void:
	hit_marker.visible = true
	hit_marker_timer = 0.25
	hit_marker.add_theme_color_override("font_color", Color(1, 0.9, 0.1, 1))
	_punch_scale(1.6)
	# revert kill color
	await get_tree().create_timer(0.25).timeout
	hit_marker.add_theme_color_override("font_color", Color(1, 0.2, 0.2, 1))


func _punch_scale(amount: float = 1.3) -> void:
	crosshair_dot.scale = Vector2(amount, amount)
	var tween: Tween = create_tween()
	tween.tween_property(crosshair_dot, "scale", Vector2.ONE, 0.1)
