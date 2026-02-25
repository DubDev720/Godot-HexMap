extends Node3D
class_name HexMapRenderer3D
## Purpose/Goal: Centralized visual representation of a HexMap using MultiMeshes.
## Design Pattern/Principle: Decoupled visual owner that reacts to HexSignalManager broadcasts.
## Timestamp: 2026-02-24 02:00:00 UTC

const DemoConfigScript = preload("res://hex_map/demo/demo_config.gd")
const HexLibScript = preload("res://hex_map/hex_lib.gd")

var _multimesh_nodes: Dictionary = {}
var _collision_nodes: Dictionary = {}
var _tile_mesh_instances: Array[MeshInstance3D] = []

@export var enable_collisions: bool = false
@export var enable_heatmap: bool = false
@export var use_fallback_rendering: bool = true

var _current_map: HexMap = null
var _demo_config: DemoConfig = null


func _ready() -> void:
	print("[HexMapRenderer3D] _ready called")
	if HexSignalManager.hex_map_changed.is_connected(_on_map_changed):
		HexSignalManager.hex_map_changed.disconnect(_on_map_changed)
	HexSignalManager.hex_map_changed.connect(_on_map_changed)
	
	if HexSignalManager.hex_hovered.is_connected(_on_hex_hovered):
		HexSignalManager.hex_hovered.disconnect(_on_hex_hovered)
	HexSignalManager.hex_hovered.connect(_on_hex_hovered)


func _on_map_changed(map: HexMap) -> void:
	print("[HexMapRenderer3D] _on_map_changed called with map: ", map)
	_current_map = map
	refresh_visuals(map)


func _on_hex_hovered(_key: Vector3i) -> void:
	pass


func refresh_visuals(map: HexMap) -> void:
	print("[HexMapRenderer3D] refresh_visuals called")
	_clear_visuals()
	
	if map == null:
		print("[HexMapRenderer3D] map is null, returning")
		return
	
	print("[HexMapRenderer3D] map is valid, getting hex_set")
	var hex_set = map.get_hex_set()
	print("[HexMapRenderer3D] hex_set = ", hex_set)
	
	if hex_set != null:
		print("[HexMapRenderer3D] Using HexSet rendering")
		_render_with_hex_set(map, hex_set)
	elif use_fallback_rendering:
		print("[HexMapRenderer3D] Using fallback rendering")
		_load_demo_config()
		_render_fallback(map)
	else:
		print("[HexMapRenderer3D] No hex_set and fallback disabled, nothing rendered")


func _create_tile_batch(map: HexMap, hex_set: HexSet, id: int, coords: Array) -> void:
	var data: HexTileData = hex_set.get_tile_data(id)
	if data == null or data.mesh == null:
		return
	
	var mm_instance = MultiMeshInstance3D.new()
	var mm = MultiMesh.new()
	
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = data.mesh
	mm.instance_count = coords.size()
	
	for i in range(coords.size()):
		var key = coords[i]
		var world_pos = map.key_to_world(key)
		mm.set_instance_transform(i, Transform3D(Basis(), world_pos))
		
		if enable_collisions:
			_generate_cell_collision(map, key, data)
	
	mm_instance.multimesh = mm
	if data.material_override != null:
		mm_instance.material_override = data.material_override
	
	add_child(mm_instance)
	_multimesh_nodes[id] = mm_instance


func _render_with_hex_set(map: HexMap, hex_set: HexSet) -> void:
	var groups: Dictionary = {}
	for key in map.get_used_cells():
		var id = map.get_cell_item(key)
		if not groups.has(id):
			groups[id] = []
		groups[id].append(key)
	
	for tile_id in groups:
		_create_tile_batch(map, hex_set, tile_id, groups[tile_id])


func _load_demo_config() -> void:
	if _demo_config == null:
		_demo_config = DemoConfigScript.new()


func _render_fallback(map: HexMap) -> void:
	print("[HexMapRenderer3D] _render_fallback started")
	var layout = map.get_layout()
	print("[HexMapRenderer3D] layout = ", layout)
	if layout == null:
		print("[HexMapRenderer3D] layout is null, returning")
		return
	
	print("[HexMapRenderer3D] demo_config = ", _demo_config)
	print("[HexMapRenderer3D] tile_height = ", _demo_config.tile_height)
	var tile_height = _demo_config.tile_height
	var mesh = _build_hex_prism_mesh(layout, tile_height)
	print("[HexMapRenderer3D] mesh created: ", mesh)
	
	var used_cells = map.get_used_cells()
	print("[HexMapRenderer3D] used_cells count: ", used_cells.size())
	
	for key in used_cells:
		print("[HexMapRenderer3D] Creating tile for key: ", key)
		var tile := MeshInstance3D.new()
		tile.name = "HexTile_%d_%d_%d" % [key.x, key.y, key.z]
		tile.mesh = mesh
		tile.position = map.key_to_world(key)
		print("[HexMapRenderer3D] tile position: ", tile.position)
		
		var material := StandardMaterial3D.new()
		material.albedo_color = _demo_config.inactive_tile_color
		material.roughness = 0.95
		tile.material_override = material
		
		add_child(tile)
		_tile_mesh_instances.append(tile)
		
		if enable_collisions:
			_generate_fallback_collision(map, key)
	
	print("[HexMapRenderer3D] _render_fallback finished, created ", used_cells.size(), " tiles")


func _build_hex_prism_mesh(layout, height: float) -> ArrayMesh:
	var corners_2d: PackedVector2Array = HexLibScript.polygon_corners(layout, HexLibScript.Hex.new(0, 0, 0))
	var half_height: float = height * 0.5

	var top: Array[Vector3] = []
	var bottom: Array[Vector3] = []
	top.resize(corners_2d.size())
	bottom.resize(corners_2d.size())

	for i in range(corners_2d.size()):
		var p: Vector2 = corners_2d[i]
		top[i] = Vector3(p.x, half_height, p.y)
		bottom[i] = Vector3(p.x, -half_height, p.y)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(1, 5):
		_append_triangle(st, top[0], top[i + 1], top[i])

	for i in range(1, 5):
		_append_triangle(st, bottom[0], bottom[i], bottom[i + 1])

	for i in range(6):
		var next_i: int = (i + 1) % 6
		_append_triangle(st, top[i], top[next_i], bottom[next_i])
		_append_triangle(st, top[i], bottom[next_i], bottom[i])

	st.generate_normals()
	return st.commit()


func _append_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


func _generate_fallback_collision(map: HexMap, key: Vector3i) -> void:
	if _collision_nodes.has(key):
		return
	
	var body := StaticBody3D.new()
	body.position = map.key_to_world(key)
	
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = _generate_hex_collision_shape(map)
	
	body.add_child(collision_shape)
	add_child(body)
	_collision_nodes[key] = body


func _generate_cell_collision(map: HexMap, key: Vector3i, data: HexTileData) -> void:
	if _collision_nodes.has(key):
		return
	
	var body := StaticBody3D.new()
	body.position = map.key_to_world(key)
	
	var collision_shape := CollisionShape3D.new()
	
	if data.metadata.has("custom_collision"):
		collision_shape.shape = data.metadata["custom_collision"]
	else:
		collision_shape.shape = _generate_hex_collision_shape(map)
	
	body.add_child(collision_shape)
	add_child(body)
	_collision_nodes[key] = body


func _generate_hex_collision_shape(map: HexMap) -> ConvexPolygonShape3D:
	var shape := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	
	var layout = map.get_layout()
	if layout == null:
		shape.set_points(points)
		return shape
	
	var corners = HexLib.polygon_corners(layout, HexLib.Hex.new(0, 0, 0))
	var tier_height = map.get_tier_height()
	if tier_height == null:
		tier_height = 1.0
	
	for p in corners:
		points.append(Vector3(p.x, tier_height * 0.5, p.y))
	for p in corners:
		points.append(Vector3(p.x, -tier_height * 0.5, p.y))
	
	shape.set_points(points)
	return shape


func _clear_visuals() -> void:
	for node in _multimesh_nodes.values():
		if is_instance_valid(node):
			node.queue_free()
	_multimesh_nodes.clear()
	
	for tile in _tile_mesh_instances:
		if is_instance_valid(tile):
			tile.queue_free()
	_tile_mesh_instances.clear()
	
	for body in _collision_nodes.values():
		if is_instance_valid(body):
			body.queue_free()
	_collision_nodes.clear()


func set_enable_collisions(enabled: bool) -> void:
	enable_collisions = enabled
	if _current_map != null:
		refresh_visuals(_current_map)


func set_enable_heatmap(enabled: bool) -> void:
	enable_heatmap = enabled
