class_name HexPathTubeBuilder
extends RefCounted
## Purpose/Goal: Build a runtime tube mesh that follows a hex path centerline with smoothed turns.
## Design Pattern/Principle: Stateless geometry utility with explicit input points/path keys and tunable build options.
## Source/Reference: Existing path key usage in `hex_highlight_manager_test.gd` + Godot ArrayMesh/Curve3D APIs.
## Expected Behavior/Usage: Generate a single mesh spanning all path cells, curving through direction changes, for isolated testing.
## Scope: Mesh generation only; does not request paths, mutate map state, or attach itself to existing systems.
## Break Risks: Very tight corners with large radius can self-intersect; too-small bake interval can increase vertex count.
## Timestamp: 2026-02-26 23:35:00 UTC

const DEFAULT_RADIUS: float = 0.18
const DEFAULT_RADIAL_SEGMENTS: int = 14
const DEFAULT_BAKE_INTERVAL: float = 0.2
const DEFAULT_CORNER_SMOOTHNESS: float = 0.38
const DEFAULT_UV_TILES_PER_UNIT: float = 1.0


func build_tube_mesh_from_path_keys(
	map: HexMap,
	path_keys: Array[Vector3i],
	options: Dictionary = {}
) -> ArrayMesh:
	if map == null or path_keys.size() < 2:
		return null

	var y_offset: float = float(options.get("y_offset", 0.0))
	var centers := PackedVector3Array()
	for key in path_keys:
		if not map.has_cell(key):
			continue
		centers.append(map.key_to_world(key) + Vector3(0.0, y_offset, 0.0))
	return build_tube_mesh_from_points(centers, options)


func build_tube_mesh_from_points(points: PackedVector3Array, options: Dictionary = {}) -> ArrayMesh:
	var clean_points: PackedVector3Array = _dedupe_points(points)
	if clean_points.size() < 2:
		return null

	var radius: float = maxf(0.001, float(options.get("radius", DEFAULT_RADIUS)))
	var radial_segments: int = maxi(3, int(options.get("radial_segments", DEFAULT_RADIAL_SEGMENTS)))
	var bake_interval: float = maxf(0.02, float(options.get("bake_interval", DEFAULT_BAKE_INTERVAL)))
	var corner_smoothness: float = clampf(float(options.get("corner_smoothness", DEFAULT_CORNER_SMOOTHNESS)), 0.0, 0.8)
	var uv_tiles_per_unit: float = maxf(0.0001, float(options.get("uv_tiles_per_unit", DEFAULT_UV_TILES_PER_UNIT)))
	var cap_ends: bool = bool(options.get("cap_ends", true))

	var sampled_points: PackedVector3Array = _sample_centerline(clean_points, corner_smoothness, bake_interval)
	if sampled_points.size() < 2:
		return null

	return _build_tube_mesh(sampled_points, radius, radial_segments, uv_tiles_per_unit, cap_ends)


func create_tube_instance_from_path_keys(
	map: HexMap,
	path_keys: Array[Vector3i],
	options: Dictionary = {}
) -> MeshInstance3D:
	var mesh: ArrayMesh = build_tube_mesh_from_path_keys(map, path_keys, options)
	if mesh == null:
		return null
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if options.has("material") and options["material"] is Material:
		instance.material_override = options["material"]
	return instance


func create_tube_instance_from_points(points: PackedVector3Array, options: Dictionary = {}) -> MeshInstance3D:
	var mesh: ArrayMesh = build_tube_mesh_from_points(points, options)
	if mesh == null:
		return null
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if options.has("material") and options["material"] is Material:
		instance.material_override = options["material"]
	return instance


func _sample_centerline(
	points: PackedVector3Array,
	corner_smoothness: float,
	bake_interval: float
) -> PackedVector3Array:
	var curve := Curve3D.new()
	curve.bake_interval = bake_interval

	for i in range(points.size()):
		var p: Vector3 = points[i]
		if i == 0 or i == points.size() - 1:
			curve.add_point(p, Vector3.ZERO, Vector3.ZERO)
			continue

		var prev: Vector3 = points[i - 1]
		var nxt: Vector3 = points[i + 1]
		var tangent: Vector3 = (nxt - prev).normalized()
		var prev_len: float = p.distance_to(prev)
		var next_len: float = p.distance_to(nxt)
		var handle_len: float = minf(prev_len, next_len) * corner_smoothness * 0.5
		var in_handle: Vector3 = -tangent * handle_len
		var out_handle: Vector3 = tangent * handle_len
		curve.add_point(p, in_handle, out_handle)

	var baked: PackedVector3Array = curve.get_baked_points()
	if baked.size() < 2:
		return points
	return _dedupe_points(baked)


func _build_tube_mesh(
	centerline: PackedVector3Array,
	radius: float,
	radial_segments: int,
	uv_tiles_per_unit: float,
	cap_ends: bool
) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var arc_lengths := PackedFloat32Array()
	arc_lengths.resize(centerline.size())
	arc_lengths[0] = 0.0
	for i in range(1, centerline.size()):
		arc_lengths[i] = arc_lengths[i - 1] + centerline[i].distance_to(centerline[i - 1])

	var prev_normal: Vector3 = Vector3.UP
	for ring in range(centerline.size()):
		var p: Vector3 = centerline[ring]
		var tangent: Vector3 = _centerline_tangent(centerline, ring)
		var frame := _build_frame(tangent, prev_normal)
		var normal_axis: Vector3 = frame.x
		var binormal_axis: Vector3 = frame.y
		prev_normal = normal_axis

		var v_coord: float = arc_lengths[ring] * uv_tiles_per_unit
		for seg in range(radial_segments):
			var t: float = float(seg) / float(radial_segments)
			var angle: float = TAU * t
			var circle_dir: Vector3 = (normal_axis * cos(angle)) + (binormal_axis * sin(angle))
			vertices.append(p + circle_dir * radius)
			normals.append(circle_dir)
			uvs.append(Vector2(t, v_coord))

	for ring_i in range(centerline.size() - 1):
		var ring_start: int = ring_i * radial_segments
		var next_start: int = (ring_i + 1) * radial_segments
		for seg_i in range(radial_segments):
			var seg_next: int = (seg_i + 1) % radial_segments
			var a: int = ring_start + seg_i
			var b: int = next_start + seg_i
			var c: int = next_start + seg_next
			var d: int = ring_start + seg_next
			indices.append(a)
			indices.append(b)
			indices.append(d)
			indices.append(b)
			indices.append(c)
			indices.append(d)

	if cap_ends:
		_append_cap_inline(vertices, normals, uvs, indices, centerline[0], -_centerline_tangent(centerline, 0), radius, radial_segments)
		_append_cap_inline(
			vertices,
			normals,
			uvs,
			indices,
			centerline[centerline.size() - 1],
			_centerline_tangent(centerline, centerline.size() - 1),
			radius,
			radial_segments
		)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _append_cap_inline(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	center: Vector3,
	normal_dir: Vector3,
	radius: float,
	radial_segments: int
) -> void:
	var frame := _build_frame(normal_dir.normalized(), Vector3.UP)
	var x_axis: Vector3 = frame.x
	var y_axis: Vector3 = frame.y

	var center_index: int = vertices.size()
	vertices.append(center)
	normals.append(normal_dir.normalized())
	uvs.append(Vector2(0.5, 0.5))

	var ring_start: int = vertices.size()
	for i in range(radial_segments):
		var t: float = float(i) / float(radial_segments)
		var angle: float = TAU * t
		var offset: Vector3 = (x_axis * cos(angle) + y_axis * sin(angle)) * radius
		var v: Vector3 = center + offset
		vertices.append(v)
		normals.append(normal_dir.normalized())
		uvs.append(Vector2(cos(angle) * 0.5 + 0.5, sin(angle) * 0.5 + 0.5))

	for i in range(radial_segments):
		var n: int = (i + 1) % radial_segments
		var a: int = ring_start + i
		var b: int = ring_start + n
		if normal_dir.dot(Vector3.UP) >= 0.0:
			indices.append(center_index)
			indices.append(a)
			indices.append(b)
		else:
			indices.append(center_index)
			indices.append(b)
			indices.append(a)


func _centerline_tangent(points: PackedVector3Array, idx: int) -> Vector3:
	if points.size() < 2:
		return Vector3.FORWARD
	if idx <= 0:
		return (points[1] - points[0]).normalized()
	if idx >= points.size() - 1:
		return (points[idx] - points[idx - 1]).normalized()
	return (points[idx + 1] - points[idx - 1]).normalized()


func _build_frame(tangent: Vector3, previous_normal: Vector3) -> Basis:
	var t: Vector3 = tangent.normalized()
	if t.length_squared() <= 1e-8:
		t = Vector3.FORWARD

	var n: Vector3 = previous_normal - t * previous_normal.dot(t)
	if n.length_squared() <= 1e-8:
		var fallback_up: Vector3 = Vector3.UP
		if absf(t.dot(fallback_up)) > 0.95:
			fallback_up = Vector3.RIGHT
		n = fallback_up - t * fallback_up.dot(t)
	n = n.normalized()

	var b: Vector3 = t.cross(n).normalized()
	n = b.cross(t).normalized()
	return Basis(n, b, t)


func _dedupe_points(points: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	if points.is_empty():
		return out
	var last: Vector3 = points[0]
	out.append(last)
	for i in range(1, points.size()):
		var p: Vector3 = points[i]
		if p.distance_squared_to(last) > 1e-8:
			out.append(p)
			last = p
	return out
