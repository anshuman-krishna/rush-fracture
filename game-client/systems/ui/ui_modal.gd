class_name UiModal
extends Control

# base for the panels that take over the screen mid-run (rewards, path
# choice, shop, summary, pause): a dim backdrop, a centred panel, a short
# fade, and handing the mouse to the player while it is open.

var _active: bool = false
var _backdrop: ColorRect
var _panel: PanelContainer
var _content: VBoxContainer
var _tween: Tween

## panel width in pixels; set before the first show
var panel_width: float = 760.0
var backdrop_alpha: float = 0.6


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_frame()


func _build_frame() -> void:
	_backdrop = UiKit.backdrop(backdrop_alpha)
	add_child(_backdrop)
	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(panel_width, 0)
	centre.add_child(_panel)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	_panel.add_child(_content)


func is_open() -> bool:
	return _active


func _clear_content() -> void:
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()


func _open() -> void:
	_active = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _tween and _tween.is_valid():
		_tween.kill()
	modulate.a = 0.0
	_tween = create_tween().set_ignore_time_scale(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.14)


## closes without emitting anything. safe to call when already closed.
func hide_panel() -> void:
	if not _active and not visible:
		return
	_active = false
	visible = false
	if _tween and _tween.is_valid():
		_tween.kill()
	_recapture_mouse()


func _recapture_mouse() -> void:
	# hand the mouse back to the game unless another panel still wants it
	if get_tree().paused:
		return
	var parent: Node = get_parent()
	if parent:
		for sibling: Node in parent.get_children():
			if sibling != self and sibling is UiModal and (sibling as UiModal).is_open():
				return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _title(text: String, color: Color = UiKit.ACCENT, size: int = 30) -> Label:
	var l: Label = UiKit.label(text, size, color, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(l)
	return l


func _note(text: String, color: Color = UiKit.TEXT_DIM, size: int = 16) -> Label:
	var l: Label = UiKit.label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(l)
	return l


func _focus_first(container: Node) -> void:
	for child: Node in container.get_children():
		if child is BaseButton and not (child as BaseButton).disabled:
			(child as BaseButton).grab_focus.call_deferred()
			return
