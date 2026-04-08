extends Control

# escape menu — pause, upgrade options, restart, quit.

signal resume_requested
signal restart_requested
signal main_menu_requested

var _active: bool = false

@onready var panel: PanelContainer = $Panel
@onready var btn_container: VBoxContainer = $Panel/VBoxContainer


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _active:
			_resume()
		else:
			_open()
		get_viewport().set_input_as_handled()


func _open() -> void:
	if _active:
		return
	# don't open during upgrade/mutation selection
	var gm: Node = get_node_or_null("/root/Main/GameManager")
	if gm and ("awaiting_upgrade" in gm and gm.awaiting_upgrade):
		return
	if gm and ("awaiting_mutation" in gm and gm.awaiting_mutation):
		return

	_active = true
	_build_menu()
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	modulate.a = 0.0
	var tween: Tween = create_tween().set_ignore_time_scale(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.12)


func _resume() -> void:
	if not _active:
		return
	_active = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	visible = false
	resume_requested.emit()


func is_paused() -> bool:
	return _active


func _build_menu() -> void:
	for child in btn_container.get_children():
		child.queue_free()

	# title
	var title: Label = Label.new()
	title.text = "paused"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.15, 0.1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn_container.add_child(title)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	btn_container.add_child(spacer)

	_add_button("resume", Color(0.9, 0.9, 0.9), func(): _resume())
	_add_button("restart run", Color(1.0, 0.6, 0.2), func():
		_active = false
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		visible = false
		restart_requested.emit()
	)
	_add_button("main menu", Color(0.6, 0.6, 0.6), func():
		_active = false
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		visible = false
		main_menu_requested.emit()
	)
	_add_button("quit game", Color(0.5, 0.3, 0.3), func():
		get_tree().quit()
	)


func _add_button(text: String, color: Color, callback: Callable) -> void:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(220, 48)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", Color(
		minf(color.r + 0.2, 1.0),
		minf(color.g + 0.2, 1.0),
		minf(color.b + 0.2, 1.0)
	))
	btn.pressed.connect(callback)
	btn_container.add_child(btn)
