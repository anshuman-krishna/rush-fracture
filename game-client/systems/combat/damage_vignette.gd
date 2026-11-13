extends ColorRect

# red edge-of-screen flash when the player is hit, plus a steady pulse while
# health is low. drawn with a small shader so only the edges tint.

const SHADER_CODE: String = """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.9, 0.05, 0.02, 1.0);
uniform float strength = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edge = smoothstep(0.35, 1.25, length(p * vec2(0.9, 1.0)));
	COLOR = vec4(tint.rgb, edge * strength);
}
"""

@export var fade_speed: float = 3.2

var _flash: float = 0.0
var _material: ShaderMaterial


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	var shader: Shader = Shader.new()
	shader.code = SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = shader
	material = _material


func flash(intensity: float = 1.0) -> void:
	_flash = clampf(maxf(_flash, 0.45 * intensity), 0.0, 1.0)


func flash_heavy() -> void:
	flash(2.0)


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - fade_speed * delta * maxf(_flash, 0.25))
	var low: float = 0.0
	var player: CharacterBody3D = Game.local_player()
	if is_instance_valid(player) and player.get("is_dead") != true:
		var ratio: float = float(player.health) / float(maxi(player.max_health, 1))
		if ratio <= 0.3:
			# heartbeat: gets stronger the closer to zero
			low = (0.3 - ratio) / 0.3 * (0.35 + 0.2 * sin(Time.get_ticks_msec() * 0.008))
	_material.set_shader_parameter("strength", clampf(_flash + low, 0.0, 1.0))
