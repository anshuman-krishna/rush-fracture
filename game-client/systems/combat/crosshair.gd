extends CenterContainer

# crosshair with hit/kill feedback markers and scale punch.

var hit_marker_timer: float = 0.0
var _kill_active: bool = false
var _punch_tween: Tween

@onready var crosshair_dot: ColorRect = $CrosshairDot
@onready var hit_marker: Label = $HitMarker

const HIT_COLOR := Color(1, 0.2, 0.2, 1)
const KILL_COLOR := Color(1, 0.9, 0.1, 1)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit_marker.visible = false


func _process(delta: float) -> void:
	if hit_marker_timer > 0:
		hit_marker_timer -= delta
		if hit_marker_timer <= 0:
			hit_marker.visible = false
			_kill_active = false
			hit_marker.add_theme_color_override("font_color", HIT_COLOR)


func show_hit() -> void:
	if _kill_active:
		return
	hit_marker.visible = true
	hit_marker.add_theme_color_override("font_color", HIT_COLOR)
	hit_marker_timer = 0.15
	_punch_scale()


func show_kill() -> void:
	_kill_active = true
	hit_marker.visible = true
	hit_marker.add_theme_color_override("font_color", KILL_COLOR)
	hit_marker_timer = 0.25
	_punch_scale(1.6)


func _punch_scale(amount: float = 1.3) -> void:
	if _punch_tween and _punch_tween.is_valid():
		_punch_tween.kill()
	crosshair_dot.scale = Vector2(amount, amount)
	_punch_tween = create_tween()
	_punch_tween.tween_property(crosshair_dot, "scale", Vector2.ONE, 0.1).set_ease(Tween.EASE_OUT)
