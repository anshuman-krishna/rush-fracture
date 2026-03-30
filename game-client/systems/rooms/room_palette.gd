class_name RoomPalette
extends RefCounted

# visual palettes for room variety.
# each palette defines floor, obstacle, lighting, and emission colors.

enum PaletteType {
	CRIMSON,
	COLD,
	BLEACH,
	CORRUPT,
}

var floor_color: Color
var floor_emission: Color
var obstacle_color: Color
var light_color: Color
var light_energy: float
var ambient_color: Color
var hazard_tint: Color


static func pick_for_room(room_index: int, room_type: RoomDefinitions.RoomType) -> RoomPalette:
	if room_type == RoomDefinitions.RoomType.BOSS:
		return _create(PaletteType.CRIMSON)
	if room_type == RoomDefinitions.RoomType.RECOVERY:
		return _create(PaletteType.COLD)
	if room_type == RoomDefinitions.RoomType.ELITE_CHAMBER:
		return _create(PaletteType.CORRUPT)
	if room_type == RoomDefinitions.RoomType.HAZARD:
		return _create(PaletteType.CRIMSON)
	if room_type == RoomDefinitions.RoomType.GAUNTLET:
		return _create(PaletteType.BLEACH)

	# cycle through palettes with some randomness
	var options: Array = [PaletteType.CRIMSON, PaletteType.COLD, PaletteType.BLEACH, PaletteType.CORRUPT]
	var idx: int = (room_index + randi() % 2) % options.size()
	return _create(options[idx])


static func _create(type: PaletteType) -> RoomPalette:
	var p: RoomPalette = RoomPalette.new()
	match type:
		PaletteType.CRIMSON:
			p.floor_color = Color(0.10, 0.06, 0.06, 1)
			p.floor_emission = Color(0.15, 0.02, 0.0)
			p.obstacle_color = Color(0.08, 0.05, 0.05, 1)
			p.light_color = Color(1.0, 0.85, 0.8, 1)
			p.light_energy = 1.0
			p.ambient_color = Color(0.12, 0.04, 0.02)
			p.hazard_tint = Color(1.0, 0.2, 0.0)
		PaletteType.COLD:
			p.floor_color = Color(0.06, 0.08, 0.12, 1)
			p.floor_emission = Color(0.0, 0.04, 0.12)
			p.obstacle_color = Color(0.05, 0.06, 0.1, 1)
			p.light_color = Color(0.8, 0.9, 1.0, 1)
			p.light_energy = 0.9
			p.ambient_color = Color(0.02, 0.04, 0.1)
			p.hazard_tint = Color(0.3, 0.5, 1.0)
		PaletteType.BLEACH:
			p.floor_color = Color(0.14, 0.12, 0.12, 1)
			p.floor_emission = Color(0.08, 0.04, 0.04)
			p.obstacle_color = Color(0.18, 0.14, 0.14, 1)
			p.light_color = Color(1.0, 0.95, 0.95, 1)
			p.light_energy = 1.2
			p.ambient_color = Color(0.1, 0.06, 0.06)
			p.hazard_tint = Color(1.0, 0.3, 0.2)
		PaletteType.CORRUPT:
			p.floor_color = Color(0.06, 0.04, 0.1, 1)
			p.floor_emission = Color(0.08, 0.0, 0.12)
			p.obstacle_color = Color(0.06, 0.04, 0.08, 1)
			p.light_color = Color(0.9, 0.7, 1.0, 1)
			p.light_energy = 0.85
			p.ambient_color = Color(0.06, 0.0, 0.1)
			p.hazard_tint = Color(0.7, 0.1, 0.9)
	return p
