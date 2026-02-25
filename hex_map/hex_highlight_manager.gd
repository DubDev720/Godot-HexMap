extends Node3D
class_name HexHighlightManager
## Purpose/Goal: Centralizes selection rings and path ribbon rendering.
## Design Pattern/Principle: Reacts to signals to provide visual feedback for interaction and tactics.
## Timestamp: 2026-02-25 00:00:00 EST

const DemoConfigResource: DemoConfig = preload("res://hex_map/demo/demo_config.tres")

@export var selection_color: Color = Color(1.0, 0.95, 0.2, 0.45)
@export var path_color: Color = Color(1.0, 0.93, 0.08, 0.95)
@export var path_line_width: float = 0.28

var _highlight_ring: MeshInstance3D = null
var _path_ribbon: MeshInstance3D = null
var _layout: HexLib.Layout = null
var _tile_height: float = 0.25
var _path_line_y_offset: float = 0.195


func _ready() -> void:
	if DemoConfigResource.pathfinding_config != null:
		path_color = DemoConfigResource.pathfinding_config.path_line_color
		path_line_width = DemoConfigResource.pathfinding_config.path_line_width
	_setup_visual_nodes()
	_connect_signals()


func _setup_visual_nodes() -> void:
	_highlight_ring = MeshInstance3D.new()
	_highlight_ring.name = "SelectionRing"
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = selection_color
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_highlight_ring.material_override = ring_mat
	add_child(_highlight_ring)
	_highlight_ring.visible = false
	
	_path_ribbon = MeshInstance3D.new()
	_path_ribbon.name = "PathRibbon"
	var path_mat := StandardMaterial3D.new()
	path_mat.albedo_color = path_color
	path_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	path_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	path_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_path_ribbon.material_override = path_mat
	add_child(_path_ribbon)


func _connect_signals() -> void:
	if not HexInteractionBus.hex_hovered.is_connected(_on_hex_hovered):
		HexInteractionBus.hex_hovered.connect(_on_hex_hovered)
	
	if not HexInteractionBus.hex_selected.is_connected(_on_hex_selected):
		HexInteractionBus.hex_selected.connect(_on_hex_selected)
	
	if HexPathfinder.path_result_ready.is_connected(_on_path_ready):
		HexPathfinder.path_result_ready.disconnect(_on_path_ready)
	HexPathfinder.path_result_ready.connect(_on_path_ready)

	if HexModeBus.interaction_mode_changed.is_connected(_on_mode_changed):
		HexModeBus.interaction_mode_changed.disconnect(_on_mode_changed)
	HexModeBus.interaction_mode_changed.connect(_on_mode_changed)


func configure(layout: HexLib.Layout, tile_height: float) -> void:
	_layout = layout
	_tile_height = tile_height
	_path_line_y_offset = tile_height * 0.78
	_build_highlight_ring()


func _build_highlight_ring() -> void:
	if _layout == null:
		return
	
	var corners_2d: PackedVector2Array = HexLib.polygon_corners(_layout, HexLib.Hex.new(0, 0, 0))
	var outer_scale = 1.06
	var inner_scale = 0.9
	
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for i in range(corners_2d.size()):
		var next_i: int = (i + 1) % corners_2d.size()
		var outer_a := Vector3(corners_2d[i].x * outer_scale, 0.0, corners_2d[i].y * outer_scale)
		var outer_b := Vector3(corners_2d[next_i].x * outer_scale, 0.0, corners_2d[next_i].y * outer_scale)
		var inner_a := Vector3(corners_2d[i].x * inner_scale, 0.0, corners_2d[i].y * inner_scale)
		var inner_b := Vector3(corners_2d[next_i].x * inner_scale, 0.0, corners_2d[next_i].y * inner_scale)
		
		_append_triangle(st, outer_a, outer_b, inner_b)
		_append_triangle(st, outer_a, inner_b, inner_a)
	
	st.generate_normals()
	_highlight_ring.mesh = st.commit()


func _append_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


func _on_hex_hovered(key: Vector3i) -> void:
	var map = HexMapEditor.get_hex_map()
	if map == null or not map.has_cell(key):
		_highlight_ring.visible = false
		return
	
	_highlight_ring.visible = true
	_highlight_ring.global_position = map.key_to_world(key) + Vector3(0, _tile_height * 0.62, 0)


func _on_hex_selected(_key: Vector3i) -> void:
	pass


func _on_path_ready(_start, _goal, result: Dictionary) -> void:
	var path: Array[Vector3i] = result.get("path", [])
	if path.is_empty():
		_path_ribbon.mesh = null
		return
	
	_update_path_mesh(path)


func _update_path_mesh(path_keys: Array[Vector3i]) -> void:
	var map = HexMapEditor.get_hex_map()
	if map == null:
		return
	
	if path_keys.size() < 2:
		_path_ribbon.mesh = null
		return
	
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for i in range(path_keys.size() - 1):
		var a_key: Vector3i = path_keys[i]
		var b_key: Vector3i = path_keys[i + 1]
		
		if not map.has_cell(a_key) or not map.has_cell(b_key):
			continue
		
		var a_pos := map.key_to_world(a_key) + Vector3(0.0, _path_line_y_offset, 0.0)
		var b_pos := map.key_to_world(b_key) + Vector3(0.0, _path_line_y_offset, 0.0)
		
		var seg := b_pos - a_pos
		seg.y = 0.0
		if seg.length_squared() <= 1e-8:
			continue
		
		var dir := seg.normalized()
		var side := Vector3(-dir.z, 0.0, dir.x) * (path_line_width * 0.5)
		
		var v0 := a_pos + side
		var v1 := a_pos - side
		var v2 := b_pos + side
		var v3 := b_pos - side
		
		_append_triangle(st, v0, v2, v1)
		_append_triangle(st, v2, v3, v1)
	
	_path_ribbon.mesh = st.commit()


func clear_path() -> void:
	_path_ribbon.mesh = null


func clear_selection() -> void:
	_highlight_ring.visible = false


func _on_mode_changed(new_mode: int) -> void:
	if new_mode != HexModeBus.MODE_TACTICS:
		clear_path()
