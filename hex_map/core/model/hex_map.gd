class_name HexMap
extends RefCounted
## Purpose/Goal: Provide a functional hex map container with GridMap-like cell operations.
## Design Pattern/Principle: Single-authority map state + explicit coordinate gateway over `HexLib`.
## Source/Reference: `hex_lib.gd` coordinate APIs and project HexMap requirements.
## Expected Behavior/Usage: Configure once, then use GridMap-style APIs (`set_cell_item`, `get_cell_item`, `get_used_cells`, `map_to_local`, `local_to_map`) and q/r/s(+tier) adapters to avoid x/y/z naming confusion.
## Scope: Map topology/state and coordinate conversions only; no scene/UI/mesh ownership.
## Break Risks: Mixing cube-axis vectors and stack-layer vectors without explicit conversion can target wrong cells.
## Timestamp: 2026-02-23 22:23:00 UTC

const INVALID_CELL_ITEM: int = -1
const CELL_ITEM_DEFAULT: int = 0
const CELL_ITEM_OBSTACLE: int = 1

const HexSetScript = preload("res://hex_map/core/resources/hex_set.gd")


class HexTierCoord:
	var q: int
	var r: int
	var s: int
	var tier: int

	func _init(q_: int, r_: int, s_: int, tier_: int = 0) -> void:
		q = q_
		r = r_
		s = s_
		tier = tier_
		assert(q + r + s == 0, "q + r + s must be 0")

var _layout: HexLib.Layout = null
var _radius: int = 0
var _center_hex: HexLib.Hex = HexLib.Hex.new(0, 0, 0)
var _tier_height: float = 1.0
var _used_cells: Dictionary = {}
var _blank_cells: Dictionary = {}
var _obstacle_cells: Dictionary = {}
var _stack_used_cells: Dictionary = {}
var _stack_obstacle_cells: Dictionary = {}
var _hex_set: HexSet = null
var _cell_data_ids: Dictionary = {}


func configure(
	layout: HexLib.Layout,
	radius: int,
	blank_cells: Array[Vector3i],
	obstacle_cells: Array[Vector3i],
	tier_height: float = 1.0
) -> void:
	_layout = layout
	_radius = maxi(radius, 0)
	_tier_height = maxf(0.001, tier_height)
	_cell_data_ids.clear()
	_rebuild_cells(blank_cells, obstacle_cells)


func configure_hex_set(hex_set: HexSet) -> void:
	_hex_set = hex_set


func get_hex_set() -> HexSet:
	return _hex_set


func get_layout() -> HexLib.Layout:
	return _layout


func get_tier_height() -> float:
	return _tier_height


func get_tile_data_for_cell(key: Vector3i) -> HexTileData:
	if _hex_set == null:
		return null
	var tile_id = get_cell_item(key)
	return _hex_set.get_tile_data(tile_id)


func get_used_cells() -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	for key in _used_cells.keys():
		cells.append(key)
	return cells


func get_world_points() -> PackedVector3Array:
	var points := PackedVector3Array()
	for key in _used_cells.keys():
		points.append(key_to_world(key))
	return points


func get_used_cells_v3() -> Array[Vector3]:
	var cells: Array[Vector3] = []
	for key in _used_cells.keys():
		cells.append(Vector3(key.x, key.y, key.z))
	return cells


func get_used_cells_v4() -> Array[Vector4]:
	var cells: Array[Vector4] = []
	for key in _used_cells.keys():
		cells.append(Vector4(key.x, key.y, key.z, 0))
	for key in _stack_used_cells.keys():
		cells.append(Vector4(key.x, key.y, key.z, key.w))
	return cells


func has_cell(key: Vector3i) -> bool:
	return _used_cells.has(key)


func is_walkable(key: Vector3i) -> bool:
	return has_cell(key) and not _obstacle_cells.has(key)


func is_obstacle(key: Vector3i) -> bool:
	return _obstacle_cells.has(key)


func is_key_inside_radius(key: Vector3i) -> bool:
	return HexLib.hex_distance(key_to_hex(key), _center_hex) <= _radius


func set_cell(key: Vector3i, cell_is_present: bool = true) -> void:
	if not is_key_inside_radius(key):
		return
	if cell_is_present:
		_used_cells[key] = true
		_blank_cells.erase(key)
	else:
		_used_cells.erase(key)
		_blank_cells[key] = true
		_obstacle_cells.erase(key)


func erase_cell(key: Vector3i) -> void:
	set_cell(key, false)


func set_cell_item(position: Vector3i, item: int, _orientation: int = 0) -> void:
	if not is_key_inside_radius(position):
		return
	if item < 0:
		_cell_data_ids.erase(position)
		erase_cell(position)
		return
	set_cell(position, true)
	_cell_data_ids[position] = item
	if item == CELL_ITEM_OBSTACLE:
		set_cell_obstacle(position, true)
	else:
		set_cell_obstacle(position, false)


func get_cell_item(position: Vector3i) -> int:
	if not has_cell(position):
		return INVALID_CELL_ITEM
	if _cell_data_ids.has(position):
		return _cell_data_ids[position]
	if is_cell_obstacle(position):
		return CELL_ITEM_OBSTACLE
	return CELL_ITEM_DEFAULT


func get_used_cells_by_item(item: int) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	for key in _used_cells.keys():
		if get_cell_item(key) == item:
			cells.append(key)
	return cells


func clear() -> void:
	_used_cells.clear()
	_blank_cells.clear()
	_obstacle_cells.clear()
	_stack_used_cells.clear()
	_stack_obstacle_cells.clear()
	_cell_data_ids.clear()


func set_cell_item_qrs(hex: HexLib.Hex, item: int, orientation: int = 0) -> void:
	set_cell_item(_hex_to_key(hex), item, orientation)


func get_cell_item_qrs(hex: HexLib.Hex) -> int:
	return get_cell_item(_hex_to_key(hex))


func set_cell_item_tier(coord: HexTierCoord, item: int, _orientation: int = 0) -> void:
	var stack_key := _tier_to_stack_key(coord)
	if stack_key.w == 0:
		set_cell_item(Vector3i(stack_key.x, stack_key.y, stack_key.z), item)
		return
	var planar_key := Vector3i(stack_key.x, stack_key.y, stack_key.z)
	if not is_key_inside_radius(planar_key):
		return
	if item < 0:
		_stack_used_cells.erase(stack_key)
		_stack_obstacle_cells.erase(stack_key)
		return
	_stack_used_cells[stack_key] = true
	if item == CELL_ITEM_OBSTACLE:
		_stack_obstacle_cells[stack_key] = true
	else:
		_stack_obstacle_cells.erase(stack_key)


func get_cell_item_tier(coord: HexTierCoord) -> int:
	var stack_key := _tier_to_stack_key(coord)
	if stack_key.w == 0:
		return get_cell_item(Vector3i(stack_key.x, stack_key.y, stack_key.z))
	if not _stack_used_cells.has(stack_key):
		return INVALID_CELL_ITEM
	if _stack_obstacle_cells.has(stack_key):
		return CELL_ITEM_OBSTACLE
	return CELL_ITEM_DEFAULT


func map_qrs_to_local(hex: HexLib.Hex) -> Vector3:
	return map_to_local(_hex_to_key(hex))


func map_tier_to_local(coord: HexTierCoord) -> Vector3:
	var p := HexLib.hex_to_pixel(_layout, HexLib.Hex.new(coord.q, coord.r, coord.s))
	return Vector3(p.x, float(coord.tier) * _tier_height, p.y)


func local_to_qrs(local: Vector3) -> HexLib.Hex:
	return HexLib.world_to_hex_rounded(_layout, local)


func local_to_tier(local: Vector3) -> HexTierCoord:
	var hex := local_to_qrs(local)
	var tier := roundi(local.y / _tier_height)
	return HexTierCoord.new(hex.q, hex.r, hex.s, tier)


func set_cell_item_v3(position: Vector3, item: int, orientation: int = 0) -> void:
	set_cell_item(Vector3i(roundi(position.x), roundi(position.y), roundi(position.z)), item, orientation)


func set_cell_item_v4(position: Vector4, item: int, _orientation: int = 0) -> void:
	set_cell_item_tier(_vector4_to_tier(position), item)


func get_cell_item_v3(position: Vector3) -> int:
	return get_cell_item(Vector3i(roundi(position.x), roundi(position.y), roundi(position.z)))


func get_cell_item_v4(position: Vector4) -> int:
	return get_cell_item_tier(_vector4_to_tier(position))


func set_cell_obstacle(key: Vector3i, obstacle_is_enabled: bool) -> void:
	if not is_key_inside_radius(key):
		return
	if not _used_cells.has(key):
		if not obstacle_is_enabled:
			return
		_used_cells[key] = true
		_blank_cells.erase(key)
	if obstacle_is_enabled:
		_obstacle_cells[key] = true
	else:
		_obstacle_cells.erase(key)


func is_cell_obstacle(key: Vector3i) -> bool:
	return _obstacle_cells.has(key)


func toggle_cell_obstacle(key: Vector3i) -> void:
	if _obstacle_cells.has(key):
		set_cell_obstacle(key, false)
	else:
		set_cell_obstacle(key, true)


func map_to_local(key: Vector3i) -> Vector3:
	var p := HexLib.hex_to_pixel(_layout, key_to_hex(key))
	return Vector3(p.x, 0.0, p.y)


func map_to_local_v3(map_position: Vector3) -> Vector3:
	var key := Vector3i(roundi(map_position.x), roundi(map_position.y), roundi(map_position.z))
	return map_to_local(key)


func map_to_local_v4(map_position: Vector4) -> Vector3:
	return map_tier_to_local(_vector4_to_tier(map_position))


func local_to_map(local: Vector3) -> Vector3i:
	return hex_to_key(HexLib.world_to_hex_rounded(_layout, local))


func local_to_map_v3(local: Vector3) -> Vector3:
	var key := local_to_map(local)
	return Vector3(key.x, key.y, key.z)


func local_to_map_v4(local: Vector3) -> Vector4:
	var coord := local_to_tier(local)
	return Vector4(coord.q, coord.r, coord.s, coord.tier)


func get_neighbor_cell(key: Vector3i, direction: int) -> Vector3i:
	var d := HexLib.hex_direction(direction)
	return Vector3i(key.x + d.q, key.y + d.r, key.z + d.s)


func get_cell_distance(a: Vector3i, b: Vector3i) -> int:
	return HexLib.hex_distance(key_to_hex(a), key_to_hex(b))


func set_cell_present(key: Vector3i, cell_is_present: bool) -> void:
	set_cell(key, cell_is_present)


func set_cell_obstacle_is_enabled(key: Vector3i, obstacle_is_enabled: bool) -> void:
	set_cell_obstacle(key, obstacle_is_enabled)


func key_to_hex(key: Vector3i) -> HexLib.Hex:
	return HexLib.Hex.new(key.x, key.y, key.z)


func hex_to_key(h: HexLib.Hex) -> Vector3i:
	return Vector3i(h.q, h.r, h.s)


func key_to_world(key: Vector3i) -> Vector3:
	return map_to_local(key)


func world_to_key_rounded(world: Vector3) -> Vector3i:
	return local_to_map(world)


func neighbor_key(key: Vector3i, direction: int) -> Vector3i:
	return get_neighbor_cell(key, direction)


func distance_between_keys(a: Vector3i, b: Vector3i) -> int:
	return get_cell_distance(a, b)


func _rebuild_cells(blank_cells: Array[Vector3i], obstacle_cells: Array[Vector3i]) -> void:
	_used_cells.clear()
	_blank_cells.clear()
	_obstacle_cells.clear()
	_stack_used_cells.clear()
	_stack_obstacle_cells.clear()
	_cell_data_ids.clear()

	for key in blank_cells:
		_blank_cells[key] = true

	var all_cells: Array[HexLib.Hex] = HexLib.hex_spiral(_center_hex, _radius)
	for h in all_cells:
		var key := hex_to_key(h)
		if _blank_cells.has(key):
			continue
		_used_cells[key] = true
		_cell_data_ids[key] = CELL_ITEM_DEFAULT

	for key in obstacle_cells:
		if _used_cells.has(key):
			_obstacle_cells[key] = true
			_cell_data_ids[key] = CELL_ITEM_OBSTACLE


func _vector4_to_stack_key(position: Vector4) -> Vector4i:
	return Vector4i(
		roundi(position.x),
		roundi(position.y),
		roundi(position.z),
		roundi(position.w)
	)


func _vector4_to_tier(position: Vector4) -> HexTierCoord:
	var stack_key := _vector4_to_stack_key(position)
	return HexTierCoord.new(stack_key.x, stack_key.y, stack_key.z, stack_key.w)


func _tier_to_stack_key(coord: HexTierCoord) -> Vector4i:
	return Vector4i(coord.q, coord.r, coord.s, coord.tier)


func _hex_to_key(hex: HexLib.Hex) -> Vector3i:
	return Vector3i(hex.q, hex.r, hex.s)


var _multimesh_nodes: Dictionary = {}


func update_visuals(parent_node: Node3D) -> void:
	_clear_multimesh_nodes()
	if _hex_set == null:
		return
	
	var groups: Dictionary = {}
	for key in _cell_data_ids:
		var id = _cell_data_ids[key]
		if not groups.has(id):
			groups[id] = []
		groups[id].append(key)
		
	for tile_id in groups:
		_create_multimesh_for_tile(tile_id, groups[tile_id], parent_node)


func _create_multimesh_for_tile(id: int, coordinates: Array, parent: Node3D) -> void:
	var data: HexTileData = _hex_set.get_tile_data(id)
	if data == null or data.mesh == null:
		return
	
	var mm_instance = MultiMeshInstance3D.new()
	var mm = MultiMesh.new()
	
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = data.mesh
	mm.instance_count = coordinates.size()
	
	for i in range(coordinates.size()):
		var key = coordinates[i]
		var world_pos = key_to_world(key)
		var basis = Basis()
		mm.set_instance_transform(i, Transform3D(basis, world_pos))
	
	mm_instance.multimesh = mm
	if data.material_override != null:
		mm_instance.material_override = data.material_override
	parent.add_child(mm_instance)
	_multimesh_nodes[id] = mm_instance


func _clear_multimesh_nodes() -> void:
	for node in _multimesh_nodes.values():
		if is_instance_valid(node):
			node.queue_free()
	_multimesh_nodes.clear()


var _collision_bodies: Dictionary = {}
var _collision_parent: Node3D = null


func update_collisions(parent_node: Node3D, collision_enabled: bool) -> void:
	_collision_parent = parent_node
	_clear_collision_bodies()
	
	if not collision_enabled:
		return
	
	for key in _cell_data_ids:
		_update_collision_for_cell(key, _cell_data_ids[key])


func _update_collision_for_cell(key: Vector3i, tile_id: int) -> void:
	if _collision_parent == null:
		return
	if tile_id == INVALID_CELL_ITEM:
		return
	
	if _collision_bodies.has(key):
		_collision_bodies[key].queue_free()
		_collision_bodies.erase(key)
	
	if _hex_set == null:
		return
	
	var data: HexTileData = _hex_set.get_tile_data(tile_id)
	if data == null:
		return
	
	var body := StaticBody3D.new()
	body.position = key_to_world(key)
	
	var collision_shape := CollisionShape3D.new()
	
	if data.metadata.has("custom_collision"):
		collision_shape.shape = data.metadata["custom_collision"]
	else:
		collision_shape.shape = _generate_hex_collision_shape()
	
	body.add_child(collision_shape)
	_collision_parent.add_child(body)
	_collision_bodies[key] = body


func _generate_hex_collision_shape() -> ConvexPolygonShape3D:
	var shape := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	
	if _layout == null:
		shape.set_points(points)
		return shape
	
	var corners = HexLib.polygon_corners(_layout, HexLib.Hex.new(0, 0, 0))
	
	for p in corners:
		points.append(Vector3(p.x, _tier_height * 0.5, p.y))
	for p in corners:
		points.append(Vector3(p.x, -_tier_height * 0.5, p.y))
	
	shape.set_points(points)
	return shape


func _clear_collision_bodies() -> void:
	for body in _collision_bodies.values():
		if is_instance_valid(body):
			body.queue_free()
	_collision_bodies.clear()
