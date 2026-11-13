class_name ArenaShape
extends RefCounted

# the playable footprint of a room: a disc, a rectangle, a cross, or a ring
# around a central mass. answers "is this point inside", "pull this point
# back inside", and "give me a random point", and lists the boundary segments
# the walls are built along.

enum Kind { DISC, RECT, CROSS, RING }

var kind: Kind = Kind.DISC
var radius: float = 34.0
## RING only: radius of the blocked centre
var inner_radius: float = 0.0
## RECT only: half width (x) and half depth (z)
var half: Vector2 = Vector2(32, 20)
## CROSS only: half width of an arm, and how far each arm reaches from centre
var arm_half: float = 9.0
var arm_reach: float = 30.0


static func disc(r: float) -> ArenaShape:
	var s: ArenaShape = ArenaShape.new()
	s.kind = Kind.DISC
	s.radius = r
	return s


static func rect(half_x: float, half_z: float) -> ArenaShape:
	var s: ArenaShape = ArenaShape.new()
	s.kind = Kind.RECT
	s.half = Vector2(half_x, half_z)
	return s


static func cross(p_arm_half: float, p_arm_reach: float) -> ArenaShape:
	var s: ArenaShape = ArenaShape.new()
	s.kind = Kind.CROSS
	s.arm_half = p_arm_half
	s.arm_reach = p_arm_reach
	return s


static func ring(outer: float, inner: float) -> ArenaShape:
	var s: ArenaShape = ArenaShape.new()
	s.kind = Kind.RING
	s.radius = outer
	s.inner_radius = inner
	return s


## furthest any playable point is from the centre.
func bounding_radius() -> float:
	match kind:
		Kind.RECT:
			return half.length()
		Kind.CROSS:
			return Vector2(arm_reach, arm_half).length()
	return radius


func contains(x: float, z: float, margin: float = 0.0) -> bool:
	match kind:
		Kind.DISC:
			return Vector2(x, z).length() <= radius - margin
		Kind.RING:
			var d: float = Vector2(x, z).length()
			return d <= radius - margin and d >= inner_radius + margin
		Kind.RECT:
			return absf(x) <= half.x - margin and absf(z) <= half.y - margin
		Kind.CROSS:
			var in_x_arm: bool = absf(x) <= arm_reach - margin and absf(z) <= arm_half - margin
			var in_z_arm: bool = absf(z) <= arm_reach - margin and absf(x) <= arm_half - margin
			return in_x_arm or in_z_arm
	return true


## nearest point inside the shape (y is left alone).
func clamp_point(p: Vector3, margin: float = 0.0) -> Vector3:
	if contains(p.x, p.z, margin):
		return p
	var flat: Vector2 = Vector2(p.x, p.z)
	match kind:
		Kind.DISC:
			flat = flat.limit_length(maxf(0.0, radius - margin))
		Kind.RING:
			var d: float = flat.length()
			if d < 0.001:
				flat = Vector2(inner_radius + margin, 0)
			else:
				flat = flat / d * clampf(d, inner_radius + margin, radius - margin)
		Kind.RECT:
			flat.x = clampf(flat.x, -(half.x - margin), half.x - margin)
			flat.y = clampf(flat.y, -(half.y - margin), half.y - margin)
		Kind.CROSS:
			var a: Vector2 = Vector2(clampf(flat.x, -(arm_reach - margin), arm_reach - margin), clampf(flat.y, -(arm_half - margin), arm_half - margin))
			var b: Vector2 = Vector2(clampf(flat.x, -(arm_half - margin), arm_half - margin), clampf(flat.y, -(arm_reach - margin), arm_reach - margin))
			flat = a if a.distance_squared_to(flat) <= b.distance_squared_to(flat) else b
	return Vector3(flat.x, p.y, flat.y)


## uniformly random point inside the shape, at floor height.
func random_point(rng: RandomNumberGenerator, margin: float = 2.0) -> Vector3:
	match kind:
		Kind.DISC:
			var r: float = sqrt(rng.randf()) * maxf(0.5, radius - margin)
			var a: float = rng.randf() * TAU
			return Vector3(cos(a) * r, 0, sin(a) * r)
		Kind.RING:
			var lo: float = inner_radius + margin
			var hi: float = maxf(lo + 0.5, radius - margin)
			var r2: float = sqrt(rng.randf_range(lo * lo, hi * hi))
			var a2: float = rng.randf() * TAU
			return Vector3(cos(a2) * r2, 0, sin(a2) * r2)
		Kind.RECT:
			return Vector3(rng.randf_range(-(half.x - margin), half.x - margin), 0, rng.randf_range(-(half.y - margin), half.y - margin))
		Kind.CROSS:
			# pick an arm by area so the density is even
			var along: float = rng.randf_range(-(arm_reach - margin), arm_reach - margin)
			var across: float = rng.randf_range(-(arm_half - margin), arm_half - margin)
			return Vector3(along, 0, across) if rng.randf() < 0.5 else Vector3(across, 0, along)
	return Vector3.ZERO


## closed loops of boundary corners, clockwise seen from above. the first
## loop is the outer wall; a RING adds no second loop (its centre is a solid).
func outline(segments: int = 28) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	match kind:
		Kind.DISC, Kind.RING:
			for i: int in segments:
				var a: float = TAU * float(i) / float(segments)
				pts.append(Vector2(cos(a), sin(a)) * radius)
		Kind.RECT:
			pts.append(Vector2(-half.x, -half.y))
			pts.append(Vector2(half.x, -half.y))
			pts.append(Vector2(half.x, half.y))
			pts.append(Vector2(-half.x, half.y))
		Kind.CROSS:
			var w: float = arm_half
			var l: float = arm_reach
			pts.append_array(PackedVector2Array([
				Vector2(-w, -l), Vector2(w, -l), Vector2(w, -w), Vector2(l, -w),
				Vector2(l, w), Vector2(w, w), Vector2(w, l), Vector2(-w, l),
				Vector2(-w, w), Vector2(-l, w), Vector2(-l, -w), Vector2(-w, -w),
			]))
	return pts
