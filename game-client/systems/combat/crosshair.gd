extends CenterContainer

var hit_marker_timer := 0.0

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
