extends ColorRect

@export var flash_color := Color(0.8, 0.0, 0.0, 0.3)
@export var fade_speed := 4.0


func _ready() -> void:
	color = Color(0, 0, 0, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func flash() -> void:
	color = flash_color
	var tween := create_tween()
	tween.tween_property(self, "color:a", 0.0, 1.0 / fade_speed)
