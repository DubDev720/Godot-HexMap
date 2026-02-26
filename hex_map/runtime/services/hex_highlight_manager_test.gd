extends Node3D
class_name HexHighlightManagerTest
## Purpose/Goal: Highlight manager variant that can apply material-aware path ribbon rendering from selected pathfinder results.
## Design Pattern/Principle: Signal-driven renderer with selected pathfinder + config/material fallback chain.
## Source/Reference: `hex_highlight_manager.gd` and `pathfinding_material_config_schema.gd` material fields.
## Expected Behavior/Usage: Use in test scene to render path ribbon with configured shader material.
## Scope: Selection ring and path ribbon visuals only; no pathfinding algorithm ownership.
## Break Risks: Missing material falls back to generated unshaded StandardMaterial3D path color.
## Timestamp: 2026-02-26 00:40:00 UTC

const DemoConfigResource: DemoConfigPathfinderSwap = preload("res://hex_map/demo/demo_config_pathfinder_swap.tres")
const HexPathTubeBuilderScript: Script = preload("res://hex_map/gameplay/services/hex_path_tube_builder.gd")

@export var selection_color: Color = Color(1.0, 0.95, 0.2, 0.45)
@export var path_color: Color = Color(1.0, 0.93, 0.08, 0.95)
@export var path_line_width: float = 0.28

var _highlight_ring: MeshInstance3D = null
var _path_ribbon: MeshInstance3D = null
var _path_tip_cone: MeshInstance3D = null
var _start_tile_overlay: MeshInstance3D = null
var _goal_tile_overlay: MeshInstance3D = null
var _layout: HexLib.Layout = null
var _tile_height: float = 0.25
var _path_line_y_offset: float = 0.195
var _path_tube_builder = null


func _ready() -> void:
	if DemoConfigResource.material_pathfinding_config is PathfindingMaterialConfigSchema:
		var material_cfg := DemoConfigResource.material_pathfinding_config as PathfindingMaterialConfigSchema
		path_color = material_cfg.path_line_color
		path_line_width = material_cfg.path_line_width
	_path_tube_builder = HexPathTubeBuilderScript.new()
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
	_path_ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var path_mat := StandardMaterial3D.new()
	path_mat.albedo_color = path_color
	path_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	path_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	path_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_path_ribbon.material_override = path_mat
	add_child(_path_ribbon)

	_path_tip_cone = MeshInstance3D.new()
	_path_tip_cone.name = "PathTipCone"
	_path_tip_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_path_tip_cone)
	_path_tip_cone.visible = false


func _connect_signals() -> void:
	if not HexInteractionBus.hex_hovered.is_connected(_on_hex_hovered):
		HexInteractionBus.hex_hovered.connect(_on_hex_hovered)
	if not HexInteractionBus.hex_selected.is_connected(_on_hex_selected):
		HexInteractionBus.hex_selected.connect(_on_hex_selected)

	var pathfinder = _get_active_pathfinder()
	if pathfinder != null and pathfinder.has_signal("path_result_ready"):
		if pathfinder.path_result_ready.is_connected(_on_path_ready):
			pathfinder.path_result_ready.disconnect(_on_path_ready)
		pathfinder.path_result_ready.connect(_on_path_ready)

	if HexModeBus.interaction_mode_changed.is_connected(_on_mode_changed):
		HexModeBus.interaction_mode_changed.disconnect(_on_mode_changed)
	HexModeBus.interaction_mode_changed.connect(_on_mode_changed)


func _get_active_pathfinder() -> Node:
	return get_node_or_null("/root/HexPathfinderMaterial")


func configure(layout: HexLib.Layout, tile_height: float) -> void:
	_layout = layout
	_tile_height = tile_height
	_path_line_y_offset = tile_height * 0.96
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


func _on_path_ready(start_key: Vector3i, goal_key: Vector3i, result: Dictionary) -> void:
	var path: Array[Vector3i] = result.get("path", [])
	if path.is_empty():
		_path_ribbon.mesh = null
		_path_tip_cone.mesh = null
		_path_tip_cone.visible = false
		_hide_overlay(_start_tile_overlay)
		_hide_overlay(_goal_tile_overlay)
		_start_tile_overlay = null
		_goal_tile_overlay = null
		return
	_update_path_tube_and_tip(path, result)
	_update_path_markers(start_key, goal_key, result)


func _apply_path_material(result: Dictionary) -> void:
	var mat: Material = result.get("path_ribbon_material", null)
	if mat == null and DemoConfigResource.material_pathfinding_config != null and DemoConfigResource.material_pathfinding_config is PathfindingMaterialConfigSchema:
		mat = DemoConfigResource.material_pathfinding_config.path_ribbon_material
	if mat != null:
		var instance_mat: Material = mat.duplicate(true)
		_configure_path_flow_material(instance_mat)
		_path_ribbon.material_override = instance_mat
		return
	var fallback := StandardMaterial3D.new()
	fallback.albedo_color = path_color
	fallback.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fallback.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fallback.cull_mode = BaseMaterial3D.CULL_DISABLED
	_path_ribbon.material_override = fallback


func _update_path_tube_and_tip(path_keys: Array[Vector3i], result: Dictionary) -> void:
	var map = HexMapEditor.get_hex_map()
	if map == null or _path_tube_builder == null:
		return
	if path_keys.size() < 2:
		_path_ribbon.mesh = null
		_path_tip_cone.mesh = null
		_path_tip_cone.visible = false
		return

	var profile: Dictionary = _build_tube_profile_points(map, path_keys)
	var tube_points: PackedVector3Array = profile.get("tube_points", PackedVector3Array())
	if tube_points.size() < 2:
		_path_ribbon.mesh = null
		_path_tip_cone.mesh = null
		_path_tip_cone.visible = false
		return

	_path_ribbon.mesh = _path_tube_builder.build_tube_mesh_from_points(tube_points, {
		"radius": maxf(0.035, path_line_width * 0.22),
		"radial_segments": 16,
		"bake_interval": 0.09,
		"corner_smoothness": 0.52,
		"uv_tiles_per_unit": 1.45,
		"cap_ends": true,
	})
	_apply_path_material(result)

	var cone_base: Vector3 = profile.get("cone_base", Vector3.ZERO)
	var cone_tip: Vector3 = profile.get("cone_tip", Vector3.ZERO)
	_path_tip_cone.mesh = _build_directional_cone_mesh(cone_base, cone_tip, maxf(0.04, path_line_width * 0.32), 16)
	_path_tip_cone.visible = _path_tip_cone.mesh != null
	_apply_tip_cone_material(result)


func _build_tube_profile_points(map: HexMap, path_keys: Array[Vector3i]) -> Dictionary:
	var centers := PackedVector3Array()
	for key in path_keys:
		if map.has_cell(key):
			centers.append(map.key_to_world(key) + Vector3(0.0, _path_line_y_offset, 0.0))
	if centers.size() < 2:
		return {
			"tube_points": PackedVector3Array(),
			"cone_base": Vector3.ZERO,
			"cone_tip": Vector3.ZERO,
		}

	var final_center: Vector3 = centers[centers.size() - 1]
	var prev_center: Vector3 = centers[centers.size() - 2]
	var final_dir: Vector3 = final_center - prev_center
	final_dir.y = 0.0
	if final_dir.length_squared() <= 1e-8:
		final_dir = Vector3.FORWARD
	else:
		final_dir = final_dir.normalized()

	var center_distance: float = prev_center.distance_to(final_center)
	var tube_end: Vector3 = final_center - final_dir * (center_distance * 0.25)
	tube_end.y = final_center.y

	var tube_points := PackedVector3Array(centers)
	tube_points[tube_points.size() - 1] = tube_end
	return {
		"tube_points": tube_points,
		"cone_base": tube_end,
		"cone_tip": final_center,
	}


func _build_directional_cone_mesh(base_center: Vector3, tip: Vector3, base_radius: float, radial_segments: int) -> ArrayMesh:
	var axis: Vector3 = tip - base_center
	var axis_len: float = axis.length()
	if axis_len <= 1e-6:
		return null
	var dir: Vector3 = axis / axis_len
	var ref_up := Vector3.UP
	if absf(dir.dot(ref_up)) > 0.95:
		ref_up = Vector3.RIGHT
	var right: Vector3 = dir.cross(ref_up).normalized()
	var up: Vector3 = right.cross(dir).normalized()

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var ring: Array[Vector3] = []
	ring.resize(radial_segments)
	for i in range(radial_segments):
		var t: float = float(i) / float(radial_segments)
		var a: float = TAU * t
		ring[i] = base_center + (right * cos(a) + up * sin(a)) * base_radius

	for i in range(radial_segments):
		var n: int = (i + 1) % radial_segments
		st.add_vertex(ring[i])
		st.add_vertex(ring[n])
		st.add_vertex(tip)

	for i in range(1, radial_segments - 1):
		st.add_vertex(base_center)
		st.add_vertex(ring[i + 1])
		st.add_vertex(ring[i])

	st.generate_normals()
	return st.commit()


func _apply_tip_cone_material(result: Dictionary) -> void:
	var mat: Material = result.get("path_goal_cone_material", null)
	if mat == null and DemoConfigResource.material_pathfinding_config is PathfindingMaterialConfigSchema:
		var cfg := DemoConfigResource.material_pathfinding_config as PathfindingMaterialConfigSchema
		mat = cfg.path_goal_cone_material
		if mat == null:
			# Backward-compat: existing goal marker assignment becomes cone material.
			mat = cfg.path_goal_marker_material
		if mat == null:
			mat = _build_fallback_marker_material(cfg.goal_tile_color)
	if mat == null:
		mat = _build_fallback_marker_material(Color(0.82, 0.14, 1.0, 1.0))
	_path_tip_cone.material_override = mat


func _configure_path_flow_material(mat: Material) -> void:
	if mat == null:
		return
	if mat is ShaderMaterial:
		var shader_mat := mat as ShaderMaterial
		if shader_mat.shader != null:
			shader_mat.set_shader_parameter("pulse_speed", absf(float(shader_mat.get_shader_parameter("pulse_speed"))))
			shader_mat.set_shader_parameter("axis_frequency", 1.8)
			shader_mat.set_shader_parameter("local_axis_dir", Vector3(0.0, -1.0, 0.0))


func _update_path_markers(start_key: Vector3i, goal_key: Vector3i, result: Dictionary) -> void:
	var map = HexMapEditor.get_hex_map()
	if map == null:
		_hide_overlay(_start_tile_overlay)
		_hide_overlay(_goal_tile_overlay)
		_start_tile_overlay = null
		_goal_tile_overlay = null
		return

	var start_mat: Material = result.get("path_start_marker_material", null)
	var goal_mat: Material = result.get("path_goal_marker_material", null)
	if DemoConfigResource.material_pathfinding_config is PathfindingMaterialConfigSchema:
		var material_cfg := DemoConfigResource.material_pathfinding_config as PathfindingMaterialConfigSchema
		if start_mat == null:
			start_mat = material_cfg.path_start_marker_material
		if goal_mat == null:
			goal_mat = material_cfg.path_goal_marker_material
		if start_mat == null:
			start_mat = _build_fallback_marker_material(material_cfg.start_tile_color)
		if goal_mat == null:
			goal_mat = _build_fallback_marker_material(material_cfg.goal_tile_color)
	else:
		if start_mat == null:
			start_mat = _build_fallback_marker_material(Color(0.15, 0.45, 1.0, 1.0))
		if goal_mat == null:
			goal_mat = _build_fallback_marker_material(Color(0.75, 0.1, 0.95, 1.0))

	if map.has_cell(start_key):
		var start_overlay := _resolve_tile_overlay(start_key)
		if _start_tile_overlay != start_overlay:
			_hide_overlay(_start_tile_overlay)
		_start_tile_overlay = start_overlay
		if _start_tile_overlay != null:
			_start_tile_overlay.material_override = start_mat
			_start_tile_overlay.visible = true
	else:
		_hide_overlay(_start_tile_overlay)
		_start_tile_overlay = null

	if map.has_cell(goal_key):
		var goal_overlay := _resolve_tile_overlay(goal_key)
		if _goal_tile_overlay != goal_overlay:
			_hide_overlay(_goal_tile_overlay)
		_goal_tile_overlay = goal_overlay
		if _goal_tile_overlay != null:
			_goal_tile_overlay.material_override = goal_mat
			_goal_tile_overlay.visible = true
	else:
		_hide_overlay(_goal_tile_overlay)
		_goal_tile_overlay = null


func _resolve_tile_overlay(key: Vector3i) -> MeshInstance3D:
	var map_renderer := get_tree().root.find_child("HexMapRenderer3D", true, false)
	if map_renderer == null:
		return null
	var tile_name := "HexTile_%d_%d_%d" % [key.x, key.y, key.z]
	var tile_node := map_renderer.find_child(tile_name, true, false)
	if tile_node == null:
		return null
	var overlay := tile_node.find_child("tile_floor_mesh", false, false)
	if overlay is MeshInstance3D:
		return overlay as MeshInstance3D
	return null


func _hide_overlay(overlay: MeshInstance3D) -> void:
	if overlay == null or not is_instance_valid(overlay):
		return
	overlay.visible = false


func _build_fallback_marker_material(source_color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(source_color.r, source_color.g, source_color.b, 0.62)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func clear_path() -> void:
	_path_ribbon.mesh = null
	_path_tip_cone.mesh = null
	_path_tip_cone.visible = false
	_hide_overlay(_start_tile_overlay)
	_hide_overlay(_goal_tile_overlay)
	_start_tile_overlay = null
	_goal_tile_overlay = null


func clear_selection() -> void:
	_highlight_ring.visible = false


func _on_mode_changed(new_mode: int) -> void:
	if new_mode != HexModeBus.MODE_TACTICS:
		clear_path()
