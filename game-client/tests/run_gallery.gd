extends SceneTree

# renders every requested model on a neutral stage and writes one contact
# sheet, so new or changed art can be reviewed at a glance.
#
#   godot --path game-client -s res://tests/run_gallery.gd -- \
#       --out=C:/dir/sheet.png [--models=titan,core,...] [--cols=4] [--yaw=35]
#
# with no --models, every grafted-brood-*.glb under assets/models is shown.

const MODEL_DIR: String = "res://assets/models"
const CELL: Vector2i = Vector2i(640, 480)

var _cam: Camera3D
var _stage: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var opts: Dictionary = _parse_args()
	var out_path: String = String(opts.get("out", "user://gallery.png"))
	var cols: int = int(opts.get("cols", 4))
	var yaw: float = deg_to_rad(float(opts.get("yaw", 35.0)))
	var keys: PackedStringArray = _resolve_models(String(opts.get("models", "")))

	_build_stage()
	await process_frame
	await process_frame

	var rows: int = int(ceil(float(keys.size()) / float(cols)))
	var sheet: Image = Image.create(CELL.x * cols, CELL.y * rows, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.1, 0.1, 0.12))

	for i: int in keys.size():
		var key: String = keys[i]
		var scene: PackedScene = load("%s/grafted-brood-%s.glb" % [MODEL_DIR, key]) as PackedScene
		if not scene:
			print("[shot] missing model %s" % key)
			continue
		var inst: Node3D = scene.instantiate() as Node3D
		_stage.add_child(inst)
		await process_frame
		var box: AABB = _bounds(inst)
		_frame(box, yaw)
		await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i((i % cols) * CELL.x, (i / cols) * CELL.y))
		print("[shot] %s size=%.2f x %.2f x %.2f" % [key, box.size.x, box.size.y, box.size.z])
		_stage.remove_child(inst)
		inst.free()

	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var err: Error = sheet.save_png(out_path)
	print("[shot] sheet %s (%s) %d models" % [out_path, error_string(err), keys.size()])
	quit(0)


func _build_stage() -> void:
	_stage = Node3D.new()
	_stage.name = "Stage"
	root.add_child(_stage)

	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.17, 0.2)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.57, 0.65)
	env.ambient_light_energy = 0.9
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	_stage.add_child(we)

	var key_light: DirectionalLight3D = DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-42, -40, 0)
	key_light.light_energy = 1.5
	key_light.shadow_enabled = true
	_stage.add_child(key_light)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, 140, 0)
	fill.light_energy = 0.5
	fill.light_color = Color(0.7, 0.8, 1.0)
	_stage.add_child(fill)

	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(80, 80)
	floor_mesh.mesh = plane
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.2, 0.23)
	mat.roughness = 0.9
	floor_mesh.material_override = mat
	_stage.add_child(floor_mesh)

	_cam = Camera3D.new()
	_cam.fov = 40.0
	_stage.add_child(_cam)
	_cam.current = true


func _bounds(node: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi: MeshInstance3D = n as MeshInstance3D
			var b: AABB = mi.global_transform * mi.get_aabb()
			if first:
				out = b
				first = false
			else:
				out = out.merge(b)
		for child: Node in n.get_children():
			stack.append(child)
	return out


func _frame(box: AABB, yaw: float) -> void:
	var center: Vector3 = box.get_center()
	var radius: float = maxf(box.size.length() * 0.5, 0.05)
	var dist: float = radius / tan(deg_to_rad(_cam.fov * 0.5)) * 1.05
	# models face -Z, so stand in front of them and a little to one side
	var dir: Vector3 = Vector3(sin(yaw), 0.32, -cos(yaw)).normalized()
	_cam.global_position = center + dir * dist
	_cam.look_at(center, Vector3.UP)
	_cam.near = maxf(0.01, dist * 0.02)
	_cam.far = dist * 6.0 + 100.0


func _resolve_models(csv: String) -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	if not csv.is_empty():
		for k: String in csv.split(",", false):
			keys.append(k.strip_edges())
		return keys
	var dir: DirAccess = DirAccess.open(MODEL_DIR)
	if dir:
		for f: String in dir.get_files():
			# imported resources list as "name.glb.import" in exports
			var fname: String = f.trim_suffix(".import")
			if fname.begins_with("grafted-brood-") and fname.ends_with(".glb"):
				var key: String = fname.trim_prefix("grafted-brood-").trim_suffix(".glb")
				if not keys.has(key):
					keys.append(key)
	keys.sort()
	return keys


func _parse_args() -> Dictionary:
	var out: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var body: String = arg.substr(2)
		var eq: int = body.find("=")
		if eq < 0:
			out[body] = "1"
		else:
			out[body.substr(0, eq)] = body.substr(eq + 1)
	return out
