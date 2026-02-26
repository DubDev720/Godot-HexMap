class_name HexLib
extends RefCounted
## Purpose/Goal: Provide a comprehensive Red Blob style hex-grid math library in GDScript.
## Design Pattern/Principle: Data-centric utility module with explicit value objects and pure operations.
## Source/Reference: `HexMap.md`, `hex_lib.cpp`, `hex_lib.cs`, Red Blob `lib.js`/`hex-algorithms.js`, `HexagonalGrids.pdf`, and Godot docs under `godot-docs/tutorials/scripting`.
## Expected Behavior/Usage: Use `Hex`, `FractionalHex`, `OffsetCoord`, `DoubledCoord`, `Orientation`, and `Layout` with static helpers for conversion, distance, line drawing, and map queries.
## Scope: Owns coordinate math/conversions only; does not own rendering, physics, editor UI, or map persistence.
## Break Risks: Invalid `q + r + s` invariants, wrong offset mode (`EVEN`/`ODD`), and mixing 2D pixel and 3D world spaces incorrectly.
## Timestamp: 2026-02-23 11:40:00 UTC

const EVEN: int = 1
const ODD: int = -1
const _HEX_LINE_NUDGE := Vector3(1e-6, 1e-6, -2e-6)


static func _div2_exact(value: int) -> int:
	assert((value & 1) == 0, "expected an even value for exact division by 2")
	return value >> 1


class Hex:
	var q: int
	var r: int
	var s: int

	func _init(q_: int, r_: int, s_: int) -> void:
		q = q_
		r = r_
		s = s_
		assert(q + r + s == 0, "q + r + s must be 0")

	func add(other: Hex) -> Hex:
		return Hex.new(q + other.q, r + other.r, s + other.s)

	func subtract(other: Hex) -> Hex:
		return Hex.new(q - other.q, r - other.r, s - other.s)

	func scale(k: int) -> Hex:
		return Hex.new(q * k, r * k, s * k)

	func rotate_left() -> Hex:
		return Hex.new(-s, -q, -r)

	func rotate_right() -> Hex:
		return Hex.new(-r, -s, -q)

	func neighbor(direction: int) -> Hex:
		return add(_direction(direction))

	func diagonal_neighbor(direction: int) -> Hex:
		return add(_diagonal(direction))

	func length() -> int:
		return (absi(q) + absi(r) + absi(s)) >> 1

	func distance_to(other: Hex) -> int:
		return subtract(other).length()

	func equals(other: Hex) -> bool:
		return q == other.q and r == other.r and s == other.s

	static func _direction(direction: int) -> Hex:
		assert(direction >= 0 and direction < 6, "direction must be in [0, 5]")
		match direction:
			0:
				return Hex.new(1, 0, -1)
			1:
				return Hex.new(1, -1, 0)
			2:
				return Hex.new(0, -1, 1)
			3:
				return Hex.new(-1, 0, 1)
			4:
				return Hex.new(-1, 1, 0)
			_:
				return Hex.new(0, 1, -1)

	static func _diagonal(direction: int) -> Hex:
		assert(direction >= 0 and direction < 6, "direction must be in [0, 5]")
		match direction:
			0:
				return Hex.new(2, -1, -1)
			1:
				return Hex.new(1, -2, 1)
			2:
				return Hex.new(-1, -1, 2)
			3:
				return Hex.new(-2, 1, 1)
			4:
				return Hex.new(-1, 2, -1)
			_:
				return Hex.new(1, 1, -2)


class FractionalHex:
	var q: float
	var r: float
	var s: float

	func _init(q_: float, r_: float, s_: float) -> void:
		q = q_
		r = r_
		s = s_
		assert(is_zero_approx(q + r + s), "q + r + s must be 0")

	func round_to_hex() -> Hex:
		var qi := roundi(q)
		var ri := roundi(r)
		var si := roundi(s)

		var q_diff := absf(float(qi) - q)
		var r_diff := absf(float(ri) - r)
		var s_diff := absf(float(si) - s)

		if q_diff > r_diff and q_diff > s_diff:
			qi = -ri - si
		elif r_diff > s_diff:
			ri = -qi - si
		else:
			si = -qi - ri

		return Hex.new(qi, ri, si)

	func lerp_to(other: FractionalHex, t: float) -> FractionalHex:
		return FractionalHex.new(
			lerpf(q, other.q, t),
			lerpf(r, other.r, t),
			lerpf(s, other.s, t)
		)


class OffsetCoord:
	var col: int
	var row: int

	func _init(col_: int, row_: int) -> void:
		col = col_
		row = row_


class DoubledCoord:
	var col: int
	var row: int

	func _init(col_: int, row_: int) -> void:
		col = col_
		row = row_


class HexOrientation:
	var f0: float
	var f1: float
	var f2: float
	var f3: float
	var b0: float
	var b1: float
	var b2: float
	var b3: float
	var start_angle: float

	func _init(
		f0_: float,
		f1_: float,
		f2_: float,
		f3_: float,
		b0_: float,
		b1_: float,
		b2_: float,
		b3_: float,
		start_angle_: float
	) -> void:
		f0 = f0_
		f1 = f1_
		f2 = f2_
		f3 = f3_
		b0 = b0_
		b1 = b1_
		b2 = b2_
		b3 = b3_
		start_angle = start_angle_


class Layout:
	var orientation: HexOrientation
	var size: Vector2
	var origin: Vector2

	func _init(orientation_: HexOrientation, size_: Vector2, origin_: Vector2) -> void:
		orientation = orientation_
		size = size_
		origin = origin_


static func orientation_pointy() -> HexOrientation:
	var root3 := sqrt(3.0)
	return HexOrientation.new(
		root3,
		root3 / 2.0,
		0.0,
		3.0 / 2.0,
		root3 / 3.0,
		-1.0 / 3.0,
		0.0,
		2.0 / 3.0,
		0.5
	)


static func orientation_flat() -> HexOrientation:
	var root3 := sqrt(3.0)
	return HexOrientation.new(
		3.0 / 2.0,
		0.0,
		root3 / 2.0,
		root3,
		2.0 / 3.0,
		0.0,
		-1.0 / 3.0,
		root3 / 3.0,
		0.0
	)


static func hex_direction(direction: int) -> Hex:
	assert(direction >= 0 and direction < 6, "direction must be in [0, 5]")
	match direction:
		0:
			return Hex.new(1, 0, -1)
		1:
			return Hex.new(1, -1, 0)
		2:
			return Hex.new(0, -1, 1)
		3:
			return Hex.new(-1, 0, 1)
		4:
			return Hex.new(-1, 1, 0)
		_:
			return Hex.new(0, 1, -1)


static func hex_diagonal(direction: int) -> Hex:
	assert(direction >= 0 and direction < 6, "direction must be in [0, 5]")
	match direction:
		0:
			return Hex.new(2, -1, -1)
		1:
			return Hex.new(1, -2, 1)
		2:
			return Hex.new(-1, -1, 2)
		3:
			return Hex.new(-2, 1, 1)
		4:
			return Hex.new(-1, 2, -1)
		_:
			return Hex.new(1, 1, -2)


## Purpose/Goal: Convert fractional cube coordinates to a stable integer cube coordinate.
## Design Pattern/Principle: Constraint-repair rounding (single-authority for q+r+s=0 invariant).
## Source/Reference: Red Blob cube_round algorithm and `HexMap.md` rounding section.
## Expected Behavior/Usage: Round each axis, then repair the axis with the largest rounding error.
## Scope: Owns cube rounding only; callers handle storage/rendering decisions.
## Break Risks: Removing largest-error repair causes invalid cube sums and boundary flicker.
## Timestamp: 2026-02-23 11:40:00 UTC
static func hex_round(h: FractionalHex) -> Hex:
	var qi := roundi(h.q)
	var ri := roundi(h.r)
	var si := roundi(h.s)

	var q_diff := absf(float(qi) - h.q)
	var r_diff := absf(float(ri) - h.r)
	var s_diff := absf(float(si) - h.s)

	if q_diff > r_diff and q_diff > s_diff:
		qi = -ri - si
	elif r_diff > s_diff:
		ri = -qi - si
	else:
		si = -qi - ri

	return Hex.new(qi, ri, si)


## Purpose/Goal: Return all hexes on a straight line between two cube hexes.
## Design Pattern/Principle: Nudge-and-interpolate sampling with deterministic tie-breaking.
## Source/Reference: Red Blob line drawing algorithm from `hex_lib.cpp` and `HexagonalGrids.pdf`.
## Expected Behavior/Usage: Includes both endpoints and returns exactly `distance + 1` cells.
## Scope: Owns interpolation and rounding of line samples; no obstacle checks.
## Break Risks: Removing epsilon nudge can make edge cases non-deterministic.
## Timestamp: 2026-02-23 11:40:00 UTC
static func hex_linedraw(a: Hex, b: Hex) -> Array[Hex]:
	var n := hex_distance(a, b)
	var a_nudge := FractionalHex.new(
		a.q + _HEX_LINE_NUDGE.x,
		a.r + _HEX_LINE_NUDGE.y,
		a.s + _HEX_LINE_NUDGE.z
	)
	var b_nudge := FractionalHex.new(
		b.q + _HEX_LINE_NUDGE.x,
		b.r + _HEX_LINE_NUDGE.y,
		b.s + _HEX_LINE_NUDGE.z
	)

	var results: Array[Hex] = []
	var step := 1.0 / float(max(n, 1))
	for i in range(n + 1):
		results.append(hex_round(hex_lerp(a_nudge, b_nudge, step * float(i))))
	return results


static func hex_add(a: Hex, b: Hex) -> Hex:
	return Hex.new(a.q + b.q, a.r + b.r, a.s + b.s)


static func hex_subtract(a: Hex, b: Hex) -> Hex:
	return Hex.new(a.q - b.q, a.r - b.r, a.s - b.s)


static func hex_scale(a: Hex, k: int) -> Hex:
	return Hex.new(a.q * k, a.r * k, a.s * k)


static func hex_rotate_left(a: Hex) -> Hex:
	return Hex.new(-a.s, -a.q, -a.r)


static func hex_rotate_right(a: Hex) -> Hex:
	return Hex.new(-a.r, -a.s, -a.q)


static func hex_neighbor(hex: Hex, direction: int) -> Hex:
	return hex_add(hex, hex_direction(direction))


static func hex_diagonal_neighbor(hex: Hex, direction: int) -> Hex:
	return hex_add(hex, hex_diagonal(direction))


static func hex_length(hex: Hex) -> int:
	return _div2_exact(absi(hex.q) + absi(hex.r) + absi(hex.s))


static func hex_distance(a: Hex, b: Hex) -> int:
	return hex_length(hex_subtract(a, b))


static func hex_lerp(a: FractionalHex, b: FractionalHex, t: float) -> FractionalHex:
	return FractionalHex.new(
		lerpf(a.q, b.q, t),
		lerpf(a.r, b.r, t),
		lerpf(a.s, b.s, t)
	)


static func _validate_offset(offset: int) -> void:
	assert(offset == EVEN or offset == ODD, "offset must be EVEN (+1) or ODD (-1)")


static func qoffset_from_cube(offset: int, h: Hex) -> OffsetCoord:
	_validate_offset(offset)
	var parity := h.q & 1
	var col := h.q
	var row := h.r + _div2_exact(h.q + offset * parity)
	return OffsetCoord.new(col, row)


static func qoffset_to_cube(offset: int, h: OffsetCoord) -> Hex:
	_validate_offset(offset)
	var parity := h.col & 1
	var q := h.col
	var r := h.row - _div2_exact(h.col + offset * parity)
	var s := -q - r
	return Hex.new(q, r, s)


static func roffset_from_cube(offset: int, h: Hex) -> OffsetCoord:
	_validate_offset(offset)
	var parity := h.r & 1
	var col := h.q + _div2_exact(h.r + offset * parity)
	var row := h.r
	return OffsetCoord.new(col, row)


static func roffset_to_cube(offset: int, h: OffsetCoord) -> Hex:
	_validate_offset(offset)
	var parity := h.row & 1
	var q := h.col - _div2_exact(h.row + offset * parity)
	var r := h.row
	var s := -q - r
	return Hex.new(q, r, s)


static func qoffset_from_qdoubled(offset: int, h: DoubledCoord) -> OffsetCoord:
	var parity := h.col & 1
	return OffsetCoord.new(h.col, _div2_exact(h.row + offset * parity))


static func qoffset_to_qdoubled(offset: int, h: OffsetCoord) -> DoubledCoord:
	var parity := h.col & 1
	return DoubledCoord.new(h.col, 2 * h.row - offset * parity)


static func roffset_from_rdoubled(offset: int, h: DoubledCoord) -> OffsetCoord:
	var parity := h.row & 1
	return OffsetCoord.new(_div2_exact(h.col + offset * parity), h.row)


static func roffset_to_rdoubled(offset: int, h: OffsetCoord) -> DoubledCoord:
	var parity := h.row & 1
	return DoubledCoord.new(2 * h.col - offset * parity, h.row)


static func qdoubled_from_cube(h: Hex) -> DoubledCoord:
	return DoubledCoord.new(h.q, 2 * h.r + h.q)


static func qdoubled_to_cube(h: DoubledCoord) -> Hex:
	var q := h.col
	var r := _div2_exact(h.row - h.col)
	var s := -q - r
	return Hex.new(q, r, s)


static func rdoubled_from_cube(h: Hex) -> DoubledCoord:
	return DoubledCoord.new(2 * h.q + h.r, h.r)


static func rdoubled_to_cube(h: DoubledCoord) -> Hex:
	var q := _div2_exact(h.col - h.row)
	var r := h.row
	var s := -q - r
	return Hex.new(q, r, s)


static func hex_to_pixel(layout: Layout, h: Hex) -> Vector2:
	var m := layout.orientation
	var x := (m.f0 * h.q + m.f1 * h.r) * layout.size.x
	var y := (m.f2 * h.q + m.f3 * h.r) * layout.size.y
	return Vector2(x + layout.origin.x, y + layout.origin.y)


static func pixel_to_hex_fractional(layout: Layout, p: Vector2) -> FractionalHex:
	var m := layout.orientation
	var pt := Vector2(
		(p.x - layout.origin.x) / layout.size.x,
		(p.y - layout.origin.y) / layout.size.y
	)
	var q := m.b0 * pt.x + m.b1 * pt.y
	var r := m.b2 * pt.x + m.b3 * pt.y
	return FractionalHex.new(q, r, -q - r)


static func pixel_to_hex_rounded(layout: Layout, p: Vector2) -> Hex:
	return hex_round(pixel_to_hex_fractional(layout, p))


## Purpose/Goal: Bridge 2D layout math to 3D world XZ placement without extra adapters.
## Design Pattern/Principle: Thin coordinate adapter over canonical pixel/hex conversions.
## Source/Reference: Existing demo usage and Red Blob layout coordinate mapping.
## Expected Behavior/Usage: Use for world placement/picking where world X maps to pixel X and world Z maps to pixel Y.
## Scope: Conversion only; no map storage, collision, or rendering ownership.
## Break Risks: Changing XZ mapping conventions will break picking and tile alignment.
## Timestamp: 2026-02-23 21:44:00 UTC
static func hex_to_world(layout: Layout, h: Hex, level: int = 0, floor_height: float = 1.0) -> Vector3:
	var p := hex_to_pixel(layout, h)
	return Vector3(p.x, float(level) * floor_height, p.y)


static func world_to_hex_fractional(layout: Layout, world: Vector3) -> FractionalHex:
	return pixel_to_hex_fractional(layout, Vector2(world.x, world.z))


static func world_to_hex_rounded(layout: Layout, world: Vector3) -> Hex:
	return pixel_to_hex_rounded(layout, Vector2(world.x, world.z))


static func hex_corner_offset(layout: Layout, corner: int) -> Vector2:
	var angle := TAU * (layout.orientation.start_angle - float(corner)) / 6.0
	return Vector2(layout.size.x * cos(angle), layout.size.y * sin(angle))


static func polygon_corners(layout: Layout, h: Hex) -> PackedVector2Array:
	var corners := PackedVector2Array()
	var center := hex_to_pixel(layout, h)
	for i in range(6):
		corners.append(center + hex_corner_offset(layout, i))
	return corners


static func hex_ring(center: Hex, radius: int) -> Array[Hex]:
	assert(radius >= 0, "radius must be >= 0")
	if radius == 0:
		return [center]

	var results: Array[Hex] = []
	var hex := hex_add(center, hex_scale(hex_direction(4), radius))
	for side in range(6):
		for _step in range(radius):
			results.append(hex)
			hex = hex_neighbor(hex, side)
	return results


static func hex_spiral(center: Hex, radius: int) -> Array[Hex]:
	assert(radius >= 0, "radius must be >= 0")
	var results: Array[Hex] = [center]
	for ring_radius in range(1, radius + 1):
		results.append_array(hex_ring(center, ring_radius))
	return results


static func hex_range(center: Hex, radius: int) -> Array[Hex]:
	assert(radius >= 0, "radius must be >= 0")
	var results: Array[Hex] = []
	for q in range(-radius, radius + 1):
		var r_min: int = maxi(-radius, -q - radius)
		var r_max: int = mini(radius, -q + radius)
		for r in range(r_min, r_max + 1):
			results.append(hex_add(center, Hex.new(q, r, -q - r)))
	return results
