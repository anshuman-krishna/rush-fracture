class_name OnboardingOverlay
extends Control

# shows controls once on first run. dismissed with any key or click.

signal dismissed

var _active: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP


func show_onboarding() -> void:
	_active = true
	visible = true
	modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	var should_dismiss: bool = false
	if event is InputEventKey and event.pressed:
		should_dismiss = true
	elif event is InputEventMouseButton and event.pressed:
		should_dismiss = true
	if should_dismiss:
		_dismiss()
		get_viewport().set_input_as_handled()


func _dismiss() -> void:
	if not _active:
		return
	_active = false
	var settings: GameSettings = GameSettings.load_settings()
	settings.has_seen_onboarding = true
	settings.save()
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func():
		visible = false
		dismissed.emit()
	)
