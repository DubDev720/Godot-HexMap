extends Node3D
class_name HexMapRenderer3D
## Purpose/Goal: Centralized visual representation of a HexMap using MultiMeshes.
## Design Pattern/Principle: Decoupled visual owner that reacts to map and interaction domain buses.
## Timestamp: 2026-02-24 02:00:00 UTC

const DemoConfigScript = preload("res://hex_map/demo/demo_config.gd")
const HexLibScript = preload("res://hex_map/core/math/hex_lib.gd")
const MapConfigSchemaScript = preload("res://hex_map/core/config/map_config_schema.gd")
const PathfindingConfigSchemaScript = preload("res://hex_map/core/config/pathfinding_config_schema.gd")
const INVALID_KEY: Vector3i = Vector3i(2147483647, 2147483647, 2147483647)
const EFFECT_FENCE_BASE_HEIGHT: float = 0.08
const FLOOR_MESH_Y_EPSILON: float = 0.001

var _multimesh_nodes: Dictionary = {}
var _collision_nodes: Dictionary = {}
var _tile_mesh_instances: Array[MeshInstance3D] = []
var _fallback_tiles_by_key: Dictionary = {}
var _fallback_fence_meshes_by_key: Dictionary = {}
var _fallback_floor_meshes_by_key: Dictionary = {}
var _logic_service: Node = null

@export var collision_is_enabled: bool = false
@export var heatmap_is_enabled: bool = false
@export var fallback_rendering_is_enabled: bool = true

var _current_map: HexMap = null
var _demo_config: DemoConfig = null
var _path_start_key: Vector3i = INVALID_KEY
var _path_goal_key: Vector3i = INVALID_KEY
var _fallback_fence_mesh: Mesh = null
var _fallback_floor_mesh: Mesh = null


func _ready() -> void:
	if HexMapBus.hex_map_changed.is_connected(_on_map_changed):
		HexMapBus.hex_map_changed.disconnect(_on_map_changed)
	HexMapBus.hex_map_changed.connect(_on_map_changed)
	
	if HexInteractionBus.hex_hovered.is_connected(_on_hex_hovered):
		HexInteractionBus.hex_hovered.disconnect(_on_hex_hovered)
	HexInteractionBus.hex_hovered.connect(_on_hex_hovered)

	if HexPathfinder.path_result_ready.is_connected(_on_path_result_ready):
		HexPathfinder.path_result_ready.disconnect(_on_path_result_ready)
	HexPathfinder.path_result_ready.connect(_on_path_result_ready)

	if HexModeBus.interaction_mode_changed.is_connected(_on_mode_changed):
		HexModeBus.interaction_mode_changed.disconnect(_on_mode_changed)
	HexModeBus.interaction_mode_changed.connect(_on_mode_changed)

	_bind_logic_service()


func _on_map_changed(map: HexMap) -> void:
	_current_map = map
	_path_start_key = INVALID_KEY
	_path_goal_key = INVALID_KEY
	refresh_visuals(map)


func _on_hex_hovered(_key: Vector3i) -> void:
	pass


func _on_path_result_ready(start_key: Vector3i, goal_key: Vector3i, _result: Dictionary) -> void:
	_path_start_key = start_key
	_path_goal_key = goal_key
	_refresh_fallback_state_visuals()


func _on_mode_changed(new_mode: int) -> void:
	if new_mode != HexModeBus.MODE_TACTICS:
		_hide_all_state_meshes()


func refresh_visuals(map: HexMap) -> void:
	_clear_visuals()
	
	if map == null:
		return
	
	var hex_set = map.get_hex_set()
	
	if hex_set != null:
		_render_with_hex_set(map, hex_set)
	elif fallback_rendering_is_enabled:
		_load_demo_config()
		_render_fallback(map)


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
		
		if collision_is_enabled:
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
	var layout = map.get_layout()
	if layout == null:
		return
	
	var map_config = _demo_config.map_config if _demo_config.map_config != null else MapConfigSchemaScript.new()
	var tile_height = map_config.tile_height
	var mesh = _build_hex_prism_mesh(layout, tile_height)
	var fence_height: float = EFFECT_FENCE_BASE_HEIGHT * 2.0
	_fallback_fence_mesh = _build_hex_effect_walls_mesh(layout, fence_height)
	_fallback_floor_mesh = _build_hex_floor_mesh(layout, 0.9)
	
	var used_cells = map.get_used_cells()
	
	for key in used_cells:
		var tile := MeshInstance3D.new()
		tile.name = "HexTile_%d_%d_%d" % [key.x, key.y, key.z]
		tile.mesh = mesh
		tile.position = map.key_to_world(key)
		
		var material := StandardMaterial3D.new()
		material.albedo_color = _fallback_color_for_cell(map, key)
		material.roughness = 0.95
		tile.material_override = material
		
		add_child(tile)
		_tile_mesh_instances.append(tile)
		_fallback_tiles_by_key[key] = tile
		var tile_fence_mesh := MeshInstance3D.new()
		tile_fence_mesh.name = "tile_fence_mesh"
		tile_fence_mesh.mesh = _fallback_fence_mesh
		var fence_y_offset: float = (fence_height * 0.5) + tile_height
		tile_fence_mesh.position = Vector3(0.0, fence_y_offset, 0.0)
		var fence_material := StandardMaterial3D.new()
		fence_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fence_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fence_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		fence_material.albedo_color = Color(0.0, 0.0, 0.0, 0.0)
		tile_fence_mesh.material_override = fence_material
		tile_fence_mesh.visible = false
		tile.add_child(tile_fence_mesh)
		_fallback_fence_meshes_by_key[key] = tile_fence_mesh

		var tile_floor_mesh := MeshInstance3D.new()
		tile_floor_mesh.name = "tile_floor_mesh"
		tile_floor_mesh.mesh = _fallback_floor_mesh
		tile_floor_mesh.position = Vector3(0.0, (tile_height * 0.5) + FLOOR_MESH_Y_EPSILON, 0.0)
		var floor_material := StandardMaterial3D.new()
		floor_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		floor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		floor_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		floor_material.albedo_color = Color(0.0, 0.0, 0.0, 0.0)
		tile_floor_mesh.material_override = floor_material
		tile_floor_mesh.visible = false
		tile.add_child(tile_floor_mesh)
		_fallback_floor_meshes_by_key[key] = tile_floor_mesh
		
		if collision_is_enabled:
			_generate_fallback_collision(map, key)

	_bind_logic_service()
	_refresh_fallback_state_visuals()


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


func _build_hex_effect_walls_mesh(layout, wall_height: float) -> ArrayMesh:
	var corners_2d: PackedVector2Array = HexLibScript.polygon_corners(layout, HexLibScript.Hex.new(0, 0, 0))
	var half_height: float = wall_height * 0.5
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

	for i in range(corners_2d.size()):
		var next_i: int = (i + 1) % corners_2d.size()
		# Inward-facing wall triangles (winding intentionally inverted from outer shell).
		_append_triangle(st, top[i], bottom[next_i], top[next_i])
		_append_triangle(st, top[i], bottom[i], bottom[next_i])

	st.generate_normals()
	return st.commit()


func _build_hex_floor_mesh(layout, scale: float) -> ArrayMesh:
	var corners_2d: PackedVector2Array = HexLibScript.polygon_corners(layout, HexLibScript.Hex.new(0, 0, 0))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3.ZERO
	for i in range(corners_2d.size()):
		var next_i: int = (i + 1) % corners_2d.size()
		var a2: Vector2 = corners_2d[i]
		var b2: Vector2 = corners_2d[next_i]
		var a := Vector3(a2.x * scale, 0.0, a2.y * scale)
		var b := Vector3(b2.x * scale, 0.0, b2.y * scale)
		_append_triangle(st, center, a, b)
	st.generate_normals()
	return st.commit()


func _fallback_color_for_cell(map: HexMap, key: Vector3i) -> Color:
	var map_config = _demo_config.map_config if _demo_config.map_config != null else MapConfigSchemaScript.new()
	if map.is_obstacle(key):
		return map_config.obstacle_tile_color
	var item_id: int = map.get_cell_item(key)
	if item_id == HexMap.CELL_ITEM_DEFAULT:
		return map_config.inactive_tile_color
	if item_id == HexMap.CELL_ITEM_OBSTACLE:
		return map_config.obstacle_tile_color
	return map_config.active_tile_color


func _refresh_fallback_state_visuals() -> void:
	if _current_map == null or _fallback_fence_meshes_by_key.is_empty() or _fallback_floor_meshes_by_key.is_empty():
		return

	_load_demo_config()
	_bind_logic_service()

	if HexModeBus.get_current_mode() != HexModeBus.MODE_TACTICS:
		_hide_all_state_meshes()
		return

	var path_config = _demo_config.pathfinding_config if _demo_config.pathfinding_config != null else PathfindingConfigSchemaScript.new()
	var heat_counts: Dictionary = {}
	var max_heat: int = 0
	var start_key: Vector3i = _path_start_key
	var goal_key: Vector3i = _path_goal_key

	if _logic_service != null:
		var heat_data = _logic_service.get("heat_touch_counts")
		if heat_data is Dictionary:
			heat_counts = heat_data
		var state_start = _logic_service.get("path_start_key")
		if state_start is Vector3i and _current_map.has_cell(state_start):
			start_key = state_start
		var state_goal = _logic_service.get("path_goal_key")
		if state_goal is Vector3i and _current_map.has_cell(state_goal):
			goal_key = state_goal

	for count in heat_counts.values():
		var parsed_count: int = int(count)
		if parsed_count > max_heat:
			max_heat = parsed_count

	var desired_fence_keys: Dictionary = {}
	var desired_floor_keys: Dictionary = {}
	if _current_map.has_cell(start_key):
		desired_fence_keys[start_key] = _with_alpha(path_config.start_tile_color, 0.5)
	if _current_map.has_cell(goal_key):
		desired_fence_keys[goal_key] = _with_alpha(path_config.goal_tile_color, 0.5)
	if heatmap_is_enabled:
		for key in heat_counts.keys():
			if key == start_key or key == goal_key:
				continue
			if not _current_map.has_cell(key):
				continue
			var touches: int = int(heat_counts.get(key, 0))
			var t: float = 1.0
			if max_heat > 0:
				t = clampf(float(touches) / float(max_heat), 0.0, 1.0)
			desired_floor_keys[key] = _with_alpha(path_config.heat_light_color.lerp(path_config.heat_dark_color, t), 0.5)

	_hide_all_state_meshes()
	for key in desired_fence_keys.keys():
		_apply_fence_mesh_color(key, desired_fence_keys[key])
	for key in desired_floor_keys.keys():
		_apply_floor_mesh_color(key, desired_floor_keys[key])


func _bind_logic_service() -> void:
	if _logic_service != null and is_instance_valid(_logic_service):
		return

	var logic_candidate := get_tree().get_first_node_in_group("logic_service")
	if logic_candidate == null:
		return

	_logic_service = logic_candidate
	if _logic_service.has_signal("simulation_updated"):
		if _logic_service.is_connected("simulation_updated", Callable(self, "_on_logic_state_updated")):
			_logic_service.disconnect("simulation_updated", Callable(self, "_on_logic_state_updated"))
		_logic_service.connect("simulation_updated", Callable(self, "_on_logic_state_updated"))
	if _logic_service.has_signal("path_animation_updated"):
		if _logic_service.is_connected("path_animation_updated", Callable(self, "_on_logic_state_updated")):
			_logic_service.disconnect("path_animation_updated", Callable(self, "_on_logic_state_updated"))
		_logic_service.connect("path_animation_updated", Callable(self, "_on_logic_state_updated"))


func _on_logic_state_updated() -> void:
	_refresh_fallback_state_visuals()


func _hide_all_state_meshes() -> void:
	for fence_mesh in _fallback_fence_meshes_by_key.values():
		if fence_mesh != null and is_instance_valid(fence_mesh):
			fence_mesh.visible = false
	for floor_mesh in _fallback_floor_meshes_by_key.values():
		if floor_mesh != null and is_instance_valid(floor_mesh):
			floor_mesh.visible = false


func _apply_fence_mesh_color(key: Vector3i, color: Color) -> void:
	if not _fallback_fence_meshes_by_key.has(key):
		return
	var fence_mesh: MeshInstance3D = _fallback_fence_meshes_by_key[key]
	if fence_mesh == null or not is_instance_valid(fence_mesh):
		return
	var fence_material := fence_mesh.material_override as StandardMaterial3D
	if fence_material == null:
		fence_material = StandardMaterial3D.new()
		fence_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fence_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fence_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		fence_mesh.material_override = fence_material
	fence_material.albedo_color = color
	fence_mesh.visible = true


func _apply_floor_mesh_color(key: Vector3i, color: Color) -> void:
	if not _fallback_floor_meshes_by_key.has(key):
		return
	var floor_mesh: MeshInstance3D = _fallback_floor_meshes_by_key[key]
	if floor_mesh == null or not is_instance_valid(floor_mesh):
		return
	var floor_material := floor_mesh.material_override as StandardMaterial3D
	if floor_material == null:
		floor_material = StandardMaterial3D.new()
		floor_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		floor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		floor_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		floor_mesh.material_override = floor_material
	floor_material.albedo_color = color
	floor_mesh.visible = true


func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)


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
	_fallback_tiles_by_key.clear()
	_fallback_fence_meshes_by_key.clear()
	_fallback_floor_meshes_by_key.clear()
	
	for body in _collision_nodes.values():
		if is_instance_valid(body):
			body.queue_free()
	_collision_nodes.clear()


func set_collision_is_enabled(enabled: bool) -> void:
	collision_is_enabled = enabled
	if _current_map != null:
		refresh_visuals(_current_map)


func set_heatmap_is_enabled(enabled: bool) -> void:
	heatmap_is_enabled = enabled
	_refresh_fallback_state_visuals()


func set_enable_collisions(enabled: bool) -> void:
	set_collision_is_enabled(enabled)


func set_enable_heatmap(enabled: bool) -> void:
	set_heatmap_is_enabled(enabled)
