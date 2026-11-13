class_name MenuBackdrop
extends SubViewportContainer

# the 3d scene behind the menus: one model on a glowing floor, slowly
# turning, lit in the colours of the current skin. the menu swaps the model
# to show whatever is being looked at (a boss on the title screen, a weapon
# in the armory).

const BOSS_MODELS: Array[String] = ["titan", "warden", "matriarch", "stalker", "core"]

var _viewport: SubViewport
var _pivot: Node3D
var _model: Node3D
var _camera: Camera3D
var _key_light: OmniLight3D
var _rim_light: OmniLight3D
var _floor_material: ShaderMaterial
var _environment: Environment
var _target_distance: float = 9.0
var _target_height: float = 2.4
var _time: float = 0.0
var _spin_speed: float = 0.25


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color(0.015, 0.02, 0.02)
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.25, 0.3, 0.28)
	_environment.ambient_light_energy = 0.6
	_environment.fog_enabled = true
	_environment.fog_light_color = Color(0.04, 0.08, 0.06)
	_environment.fog_density = 0.035
	_environment.glow_enabled = true
	_environment.glow_intensity = 0.9
	_environment.glow_bloom = 0.15
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = _environment
	_viewport.add_child(we)

	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(120, 120)
	floor_mesh.mesh = plane
	var shader: Shader = Shader.new()
	shader.code = RoomController.FLOOR_SHADER
	_floor_material = ShaderMaterial.new()
	_floor_material.shader = shader
	floor_mesh.material_override = _floor_material
	_viewport.add_child(floor_mesh)

	_pivot = Node3D.new()
	_viewport.add_child(_pivot)

	_key_light = OmniLight3D.new()
	_key_light.omni_range = 30.0
	_key_light.light_energy = 5.0
	_key_light.position = Vector3(5, 7, 6)
	_key_light.shadow_enabled = true
	_viewport.add_child(_key_light)
	_rim_light = OmniLight3D.new()
	_rim_light.omni_range = 26.0
	_rim_light.light_energy = 4.0
	_rim_light.position = Vector3(-6, 4, -6)
	_viewport.add_child(_rim_light)

	_camera = Camera3D.new()
	_camera.fov = 42.0
	_viewport.add_child(_camera)
	_camera.current = true

	set_tint(Color(0.62, 1.0, 0.36))


func _process(delta: float) -> void:
	_time += delta
	if _pivot:
		_pivot.rotate_y(delta * _spin_speed)
	if _camera:
		# a slow drift so the scene never sits perfectly still
		var sway: float = sin(_time * 0.2) * 0.35
		var goal: Vector3 = Vector3(_target_distance * 0.55 + sway, _target_height * 0.75, _target_distance)
		_camera.position = _camera.position.lerp(goal, clampf(delta * 2.5, 0.0, 1.0))
		_camera.look_at(Vector3(-_target_distance * 0.18, _target_height * 0.5, 0), Vector3.UP)


## the glow colour of the floor, lights and fog.
func set_tint(color: Color) -> void:
	if _floor_material:
		_floor_material.set_shader_parameter("base_color", Color(0.06, 0.07, 0.07))
		_floor_material.set_shader_parameter("line_color", color)
		_floor_material.set_shader_parameter("line_energy", 0.7)
	if _key_light:
		_key_light.light_color = Color(1.0, 0.95, 0.88)
	if _rim_light:
		_rim_light.light_color = color
	if _environment:
		_environment.fog_light_color = Color(color.r * 0.1, color.g * 0.1, color.b * 0.1)


func show_random_boss(skin: StringName = &"default") -> void:
	show_model("res://assets/models/grafted-brood-%s.glb" % BOSS_MODELS[randi() % BOSS_MODELS.size()], skin, 0.25)


## replaces the model on the pedestal and frames the camera to it.
func show_model(path: String, skin: StringName = &"default", spin: float = 0.25) -> void:
	if _model and is_instance_valid(_model):
		_model.queue_free()
		_model = null
	_spin_speed = spin
	if not ResourceLoader.exists(path):
		return
	var scene: PackedScene = load(path) as PackedScene
	if not scene:
		return
	_model = scene.instantiate() as Node3D
	Skins.apply(_model, skin)
	_pivot.add_child(_model)

	var box: AABB = _bounds(_model)
	var height: float = maxf(box.size.y, 0.05)
	var radius: float = maxf(box.size.length() * 0.5, 0.05)
	# small things (weapons) float at chest height; big things stand on the floor
	if height < 1.2:
		_model.position.y = 1.2 - box.get_center().y
		_target_height = 2.4
		_target_distance = maxf(radius * 3.4, 1.6)
	else:
		_target_height = height
		_target_distance = radius * 2.6


func _bounds(node: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi: MeshInstance3D = n as MeshInstance3D
			var b: AABB = mi.global_transform * mi.get_aabb()
			out = b if first else out.merge(b)
			first = false
		for child: Node in n.get_children():
			stack.append(child)
	return out
