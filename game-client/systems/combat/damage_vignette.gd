extends ColorRect

@export var flash_color := Color(0.8, 0.0, 0.0, 0.3)
@export var fade_speed := 4.0


func _ready() -> void:
	color = Color(0, 0, 0, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func flash(intensity: float = 1.0) -> void:
	var c := flash_color
	c.a = clamp(flash_color.a * intensity, 0.1, 0.6)
	color = c
	var tween := create_tween()
	tween.tween_property(self, "color:a", 0.0, 1.0 / fade_speed)


func flash_heavy() -> void:
	flash(2.0)
