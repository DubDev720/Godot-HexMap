extends Node3D
## Purpose/Goal: Render a minimal 7-tile hex cluster demo using `hex_lib.gd` only.
## Design Pattern/Principle: Single-scene procedural demo with one shared mesh and per-tile materials.
## Source/Reference: `hex_lib.gd` APIs and Red Blob hex layout/neighbor rules from project references.
## Expected Behavior/Usage: On run, spawns 1 center + 6 ring tiles with seamless shared edges and unique colors.
## Scope: Demo visualization and input studies for picking/pathfinding feedback only.
## Break Risks: Changing layout size/orientation without matching mesh construction can introduce gaps.
## Timestamp: 2026-02-23 11:56:00 UTC

const HexLibScript = preload("res://hex_map/hex_lib.gd")
const DEMO_CONFIG: DemoConfig = preload("res://hex_map/demo/demo_config.tres")

signal zoom_step_is_requested(zoom_in_is_requested: bool)
signal map_configure_is_requested(layout: HexLib.Layout, radius: int, blank_coords: Array[Vector3i], obstacle_coords: Array[Vector3i], tier_height: float)
signal map_edit_brush_set_is_requested(brush: int)
signal map_edit_is_requested(key: Vector3i)
signal path_query_is_requested(start_key: Vector3i, goal_key: Vector3i, neighbor_fn: Callable, is_walkable_fn: Callable, distance_fn: Callable)
enum DemoMode {
	INSPECT,
	PATHFINDING,
	MAP_EDIT,
}

enum EditBrush {
	TOGGLE_OBSTACLE,
	REMOVE_TILE,
	ADD_TILE,
}

enum LabelMode {
	CUBE,
	AXIAL,
	ODD_R,
	EVEN_R,
	ODD_Q,
	EVEN_Q,
	Q_DOUBLED,
	R_DOUBLED,
	DISTANCE,
}


func _label_y_offset() -> float:
	return DEMO_CONFIG.tile_height * 0.85


func _highlight_y_offset() -> float:
	return DEMO_CONFIG.tile_height * 0.62


func _path_line_y_offset() -> float:
	return DEMO_CONFIG.tile_height * 0.78

var _focus_world_position: Vector3 = Vector3.ZERO
var _focus_hex_key: Vector3i = Vector3i.ZERO
var _tile_meshes_by_key: Dictionary = {}
var _tile_labels_by_key: Dictionary = {}
var _tile_materials_by_key: Dictionary = {}
var _hex_map = null
var _heat_touch_counts: Dictionary = {}
var _path_start_key = null
var _path_goal_key = null
var _layout = null
var _highlight_outline: MeshInstance3D = null
var _path_lines: MeshInstance3D = null
var _final_path_keys: Array[Vector3i] = []
var _mode: int = DemoMode.INSPECT
var _edit_brush: int = EditBrush.TOGGLE_OBSTACLE
var _label_mode: int = LabelMode.CUBE
var _controls_layer: CanvasLayer = null
var _controls_root: VBoxContainer = null
var _controls_toggle_button: Button = null
var _controls_panel: PanelContainer = null
var _controls_label: RichTextLabel = null
var _mode_tabs_row: HBoxContainer = null
var _mode_tab_buttons: Array[Button] = []
var _animate_toggle_button: CheckButton = null
var _replay_button: Button = null
var _inspected_key = null
var _inspect_tooltip: Label3D = null
var _path_animation_is_enabled: bool = true
var _path_is_animating: bool = false
var _path_animation_touch_sequence: Array[Vector3i] = []
var _path_animation_final_path: Array[Vector3i] = []
var _path_animation_index: int = 0
var _path_animation_time_accum: float = 0.0
var _panel_is_dragging: bool = false
var _panel_drag_last_mouse: Vector2 = Vector2.ZERO
var _panel_drag_is_candidate: bool = false
var _panel_drag_press_mouse: Vector2 = Vector2.ZERO
var _panel_anchor_is_hidden_bottom: bool = false
var _map_world_points: PackedVector3Array = PackedVector3Array()


func _ready() -> void:
	_fit_window_to_screen()
	map_configure_is_requested.connect(HexMapEditor.configure_hex_map)
	map_edit_brush_set_is_requested.connect(HexMapEditor.set_edit_brush)
	map_edit_is_requested.connect(HexMapEditor.apply_edit_brush)
	path_query_is_requested.connect(HexPathfinder.request_path)
	HexMapEditor.hex_map_changed.connect(_on_hex_map_changed)
	HexMapEditor.edit_brush_changed.connect(_on_edit_brush_changed)
	HexPathfinder.path_result_ready.connect(_on_path_result_ready)
	emit_signal("map_edit_brush_set_is_requested", _edit_brush)
	_rebuild_topology_sets()
	_spawn_camera_if_missing()
	_spawn_light_if_missing()
	zoom_step_is_requested.connect(_on_zoom_step_is_requested)
	_ensure_controls_panel()
	_refresh_controls_panel()


func _process(delta: float) -> void:
	var camera := get_node_or_null("Camera3D") as Camera3D
	if camera != null:
		CameraController.update_pan_inertia(camera, _focus_world_position, _map_world_points, delta)

	if _path_is_animating:
		_path_animation_time_accum += delta
		var did_change := false
		while _path_animation_time_accum >= DEMO_CONFIG.path_animation_step_time and _path_animation_index < _path_animation_touch_sequence.size():
			_path_animation_time_accum -= DEMO_CONFIG.path_animation_step_time
			var key: Vector3i = _path_animation_touch_sequence[_path_animation_index]
			_path_animation_index += 1
			_heat_touch_counts[key] = int(_heat_touch_counts.get(key, 0)) + 1
			did_change = true

		if did_change:
			_apply_focus_visuals()

		if _path_animation_index >= _path_animation_touch_sequence.size():
			_path_is_animating = false
			_final_path_keys = _path_animation_final_path.duplicate()
			_update_path_lines_mesh()
			_refresh_controls_panel()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMagnifyGesture:
		if event.factor > 1.01:
			emit_signal("zoom_step_is_requested", true)
		elif event.factor < 0.99:
			emit_signal("zoom_step_is_requested", false)
		return

	if event is InputEventMouseButton and event.pressed:
		if _controls_panel != null and _controls_panel.visible and _is_point_inside_controls_panel(event.position):
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			emit_signal("zoom_step_is_requested", true)
			_refresh_controls_panel()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			emit_signal("zoom_step_is_requested", false)
			_refresh_controls_panel()
			return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _mode == DemoMode.MAP_EDIT:
			var edit_key = _pick_any_hex_key_from_screen(event.position)
			if edit_key != null:
				_apply_edit_brush(edit_key)
				_refresh_controls_panel()
			return

		var picked = _pick_hex_key_from_screen(event.position)
		if picked != null:
			if _mode != DemoMode.INSPECT and _hex_map.is_cell_obstacle(picked):
				return
			_set_inspected_key(picked)
			if _mode == DemoMode.INSPECT:
				_set_focus_key(picked, false)
			if _mode == DemoMode.PATHFINDING:
				_register_path_pick(picked)
			_refresh_controls_panel()


func _input(event: InputEvent) -> void:
	if _controls_root == null or _controls_panel == null or not _controls_panel.visible:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _is_point_inside_controls_panel(event.position):
			if not _is_point_inside_slider_controls(event.position):
				_panel_drag_is_candidate = true
				_panel_is_dragging = false
				_panel_drag_press_mouse = get_viewport().get_mouse_position()
				_panel_drag_last_mouse = _panel_drag_press_mouse
			else:
				_panel_drag_is_candidate = false
		else:
			_panel_drag_is_candidate = false
			_panel_is_dragging = false

	if event is InputEventMouseMotion:
		if _panel_drag_is_candidate and not _panel_is_dragging:
			var now_mouse := get_viewport().get_mouse_position()
			if now_mouse.distance_to(_panel_drag_press_mouse) >= DEMO_CONFIG.panel_drag_start_distance:
				_panel_is_dragging = true
		if _panel_is_dragging:
			var current_mouse := get_viewport().get_mouse_position()
			var delta: Vector2 = current_mouse - _panel_drag_last_mouse
			_controls_root.position += delta
			_panel_drag_last_mouse = current_mouse
			_clamp_controls_root_to_screen()
			get_viewport().set_input_as_handled()


func _is_point_inside_controls_panel(screen_point: Vector2) -> bool:
	var panel_rect := Rect2(_controls_panel.global_position, _controls_panel.size)
	return panel_rect.has_point(screen_point)


func _is_point_inside_zoom_slider(screen_point: Vector2) -> bool:
	return false


func _is_point_inside_slider_controls(screen_point: Vector2) -> bool:
	return _is_point_inside_zoom_slider(screen_point)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_H:
			_set_controls_panel_visible(_controls_panel == null or not _controls_panel.visible)
			_refresh_controls_panel()
			return

		if event.keycode == KEY_TAB:
			_set_mode((_mode + 1) % DemoMode.size())
			_refresh_controls_panel()
			return

		if event.keycode == KEY_1:
			_set_mode(DemoMode.INSPECT)
			_refresh_controls_panel()
			return
		if event.keycode == KEY_2:
			_set_mode(DemoMode.PATHFINDING)
			_refresh_controls_panel()
			return
		if event.keycode == KEY_3:
			_set_mode(DemoMode.MAP_EDIT)
			_refresh_controls_panel()
			return

		if event.keycode == KEY_L:
			_label_mode = (_label_mode + 1) % LabelMode.size()
			_apply_focus_visuals()
			_refresh_controls_panel()
			return

		if event.keycode == KEY_BRACKETLEFT:
			pass
		if event.keycode == KEY_BRACKETRIGHT:
			pass
		if event.keycode == KEY_SEMICOLON:
			pass
		if event.keycode == KEY_APOSTROPHE:
			pass
		if event.keycode == KEY_COMMA:
			CameraController.adjust_pan_clamp_aggressiveness(-1)
			_refresh_controls_panel()
			return
		if event.keycode == KEY_PERIOD:
			CameraController.adjust_pan_clamp_aggressiveness(1)
			_refresh_controls_panel()
			return

		if _mode == DemoMode.MAP_EDIT:
			if event.keycode == KEY_O:
				emit_signal("map_edit_brush_set_is_requested", HexMapEditor.EDIT_BRUSH_TOGGLE_OBSTACLE)
			elif event.keycode == KEY_R:
				emit_signal("map_edit_brush_set_is_requested", HexMapEditor.EDIT_BRUSH_REMOVE_TILE)
			elif event.keycode == KEY_A:
				emit_signal("map_edit_brush_set_is_requested", HexMapEditor.EDIT_BRUSH_ADD_TILE)
			_refresh_controls_panel()
			return

		if event.keycode == KEY_Q:
			_rotate_camera_by_steps(1)
		elif event.keycode == KEY_E:
			_rotate_camera_by_steps(-1)
		elif event.keycode == KEY_Z:
			emit_signal("zoom_step_is_requested", true)
		elif event.keycode == KEY_X:
			emit_signal("zoom_step_is_requested", false)
		elif event.keycode == KEY_C:
			_clear_path_pick_state()

		_refresh_controls_panel()


func _rebuild_topology_sets() -> void:
	if _layout == null:
		var orientation = HexLibScript.orientation_flat()
		_layout = HexLibScript.Layout.new(
			orientation,
			Vector2(DEMO_CONFIG.hex_size, DEMO_CONFIG.hex_size),
			Vector2.ZERO
		)
	emit_signal("map_configure_is_requested", _layout, DEMO_CONFIG.demo_radius, DEMO_CONFIG.blank_coords, DEMO_CONFIG.obstacle_coords, DEMO_CONFIG.tier_height)


func _build_demo_tiles() -> void:
	if _hex_map == null:
		return
	_tile_meshes_by_key.clear()
	_tile_labels_by_key.clear()
	_tile_materials_by_key.clear()
	_map_world_points = PackedVector3Array()

	for child in get_children():
		if child is MeshInstance3D and child.name.begins_with("HexTile"):
			child.free()
		elif child is Label3D and child.name.begins_with("HexLabel"):
			child.free()
		elif child is Label3D and child.name == "InspectTooltip":
			child.free()
		elif child is MeshInstance3D and child.name == "HexHighlight":
			child.free()
		elif child is MeshInstance3D and child.name == "PathLines":
			child.free()

	if _layout == null:
		return
	var mesh: ArrayMesh = _build_hex_prism_mesh(_layout, DEMO_CONFIG.tile_height)

	var center_hex = HexLibScript.Hex.new(0, 0, 0)
	var default_focus_key: Vector3i = _hex_map.hex_to_key(center_hex)
	if _tile_meshes_by_key.is_empty():
		_focus_hex_key = default_focus_key

	for key in _hex_map.get_used_cells():
		var tile := MeshInstance3D.new()
		tile.name = "HexTile_%d_%d_%d" % [key.x, key.y, key.z]
		tile.mesh = mesh
		tile.position = _hex_map.map_to_local(key)

		var material := StandardMaterial3D.new()
		material.albedo_color = DEMO_CONFIG.inactive_tile_color
		material.roughness = 0.95
		tile.material_override = material

		add_child(tile)
		_tile_meshes_by_key[key] = tile
		_tile_materials_by_key[key] = material

		var label := Label3D.new()
		label.name = "HexLabel_%d_%d_%d" % [key.x, key.y, key.z]
		label.text = "%d,%d,%d" % [key.x, key.y, key.z]
		label.position = tile.position + Vector3(0.0, _label_y_offset(), 0.0)
		label.modulate = DEMO_CONFIG.inactive_label_color
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.font_size = 48
		label.outline_size = 8
		label.outline_modulate = Color(0.04, 0.04, 0.04, 1.0)
		add_child(label)
		_tile_labels_by_key[key] = label

	if not _tile_meshes_by_key.has(_focus_hex_key):
		_focus_hex_key = default_focus_key
	if not _tile_meshes_by_key.has(_focus_hex_key) and not _tile_meshes_by_key.is_empty():
		_focus_hex_key = _tile_meshes_by_key.keys()[0]
	if _inspected_key != null and not _tile_meshes_by_key.has(_inspected_key):
		_inspected_key = null
	if _tile_meshes_by_key.has(_focus_hex_key):
		_focus_world_position = (_tile_meshes_by_key[_focus_hex_key] as MeshInstance3D).position
	_map_world_points = _hex_map.get_world_points()

	_ensure_highlight_outline()
	_ensure_path_lines_node()
	_ensure_inspect_tooltip()
	_apply_focus_visuals()
	_update_highlight_outline_position()
	_update_inspect_tooltip()
	_update_path_lines_mesh()
	_update_camera_orbit_position()
	_refresh_controls_panel()


func _ensure_highlight_outline() -> void:
	if _layout == null:
		return

	var corners_2d: PackedVector2Array = HexLibScript.polygon_corners(_layout, HexLibScript.Hex.new(0, 0, 0))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(corners_2d.size()):
		var next_i: int = (i + 1) % corners_2d.size()
		var outer_a := Vector3(corners_2d[i].x * DEMO_CONFIG.highlight_ring_outer_scale, _highlight_y_offset(), corners_2d[i].y * DEMO_CONFIG.highlight_ring_outer_scale)
		var outer_b := Vector3(corners_2d[next_i].x * DEMO_CONFIG.highlight_ring_outer_scale, _highlight_y_offset(), corners_2d[next_i].y * DEMO_CONFIG.highlight_ring_outer_scale)
		var inner_a := Vector3(corners_2d[i].x * DEMO_CONFIG.highlight_ring_inner_scale, _highlight_y_offset(), corners_2d[i].y * DEMO_CONFIG.highlight_ring_inner_scale)
		var inner_b := Vector3(corners_2d[next_i].x * DEMO_CONFIG.highlight_ring_inner_scale, _highlight_y_offset(), corners_2d[next_i].y * DEMO_CONFIG.highlight_ring_inner_scale)

		_append_triangle(st, outer_a, outer_b, inner_b)
		_append_triangle(st, outer_a, inner_b, inner_a)

	st.generate_normals()
	var ring_mesh: ArrayMesh = st.commit()

	_highlight_outline = MeshInstance3D.new()
	_highlight_outline.name = "HexHighlight"
	_highlight_outline.mesh = ring_mesh

	var highlight_mat := StandardMaterial3D.new()
	highlight_mat.albedo_color = Color(1.0, 0.95, 0.2, 0.45)
	highlight_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	highlight_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	highlight_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_highlight_outline.material_override = highlight_mat

	add_child(_highlight_outline)


func _update_highlight_outline_position() -> void:
	if _highlight_outline == null:
		return
	if not _tile_meshes_by_key.has(_focus_hex_key):
		return

	var focus_tile := _tile_meshes_by_key[_focus_hex_key] as MeshInstance3D
	if focus_tile != null:
		_highlight_outline.position = focus_tile.position


func _ensure_inspect_tooltip() -> void:
	_inspect_tooltip = Label3D.new()
	_inspect_tooltip.name = "InspectTooltip"
	_inspect_tooltip.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_inspect_tooltip.no_depth_test = true
	_inspect_tooltip.outline_size = 8
	_inspect_tooltip.outline_modulate = Color(0.03, 0.03, 0.03, 1.0)
	_inspect_tooltip.font_size = 42
	_inspect_tooltip.visible = false
	add_child(_inspect_tooltip)


func _update_inspect_tooltip() -> void:
	if _inspect_tooltip == null:
		return
	if _inspected_key == null or not _tile_meshes_by_key.has(_inspected_key):
		_inspect_tooltip.visible = false
		return

	var tile := _tile_meshes_by_key[_inspected_key] as MeshInstance3D
	if tile == null:
		_inspect_tooltip.visible = false
		return

	var details := _inspect_detail_lines(_inspected_key)
	_inspect_tooltip.text = "\n".join(details)
	_inspect_tooltip.position = tile.position + Vector3(0.0, _label_y_offset() + 0.35, 0.0)
	_inspect_tooltip.modulate = Color(0.08, 0.08, 0.08, 1.0)
	_inspect_tooltip.visible = true


func _ensure_path_lines_node() -> void:
	if _path_lines != null:
		return

	_path_lines = MeshInstance3D.new()
	_path_lines.name = "PathLines"

	var mat := StandardMaterial3D.new()
	mat.albedo_color = DEMO_CONFIG.path_line_color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_path_lines.material_override = mat

	add_child(_path_lines)


func _update_path_lines_mesh() -> void:
	if _path_lines == null:
		return

	if _final_path_keys.size() < 2:
		_path_lines.mesh = null
		return

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(_final_path_keys.size() - 1):
		var a_key: Vector3i = _final_path_keys[i]
		var b_key: Vector3i = _final_path_keys[i + 1]
		if not _tile_meshes_by_key.has(a_key) or not _tile_meshes_by_key.has(b_key):
			continue

		var a_tile := _tile_meshes_by_key[a_key] as MeshInstance3D
		var b_tile := _tile_meshes_by_key[b_key] as MeshInstance3D
		if a_tile == null or b_tile == null:
			continue

		var a := a_tile.position + Vector3(0.0, _path_line_y_offset(), 0.0)
		var b := b_tile.position + Vector3(0.0, _path_line_y_offset(), 0.0)
		var seg := b - a
		seg.y = 0.0
		if seg.length_squared() <= 1e-8:
			continue
		var dir := seg.normalized()
		var side := Vector3(-dir.z, 0.0, dir.x) * (DEMO_CONFIG.path_line_width * 0.5)

		var v0 := a + side
		var v1 := a - side
		var v2 := b + side
		var v3 := b - side

		_append_triangle(st, v0, v2, v1)
		_append_triangle(st, v2, v3, v1)

	_path_lines.mesh = st.commit()


func _apply_focus_visuals() -> void:
	var min_touch: int = 2147483647
	var max_touch: int = 0
	for key in _heat_touch_counts.keys():
		var v: int = int(_heat_touch_counts[key])
		if v < min_touch:
			min_touch = v
		if v > max_touch:
			max_touch = v

	for key in _tile_materials_by_key.keys():
		var material := _tile_materials_by_key[key] as StandardMaterial3D
		if material == null:
			continue

		var color := DEMO_CONFIG.inactive_tile_color
		if _hex_map.is_cell_obstacle(key):
			color = DEMO_CONFIG.obstacle_tile_color
		elif _heat_touch_counts.has(key):
			var touches: int = int(_heat_touch_counts[key])
			var t: float = 0.0
			if max_touch > min_touch:
				t = float(touches - min_touch) / float(max_touch - min_touch)
			color = DEMO_CONFIG.heat_light_color.lerp(DEMO_CONFIG.heat_dark_color, t)

		if _path_start_key != null and key == _path_start_key:
			color = DEMO_CONFIG.start_tile_color
		elif _path_goal_key != null and key == _path_goal_key:
			color = DEMO_CONFIG.goal_tile_color
		elif key == _focus_hex_key:
			color = DEMO_CONFIG.active_tile_color

		material.albedo_color = color

	for key in _tile_labels_by_key.keys():
		var label := _tile_labels_by_key[key] as Label3D
		if label == null:
			continue
		label.text = _label_text_for_key(key)
		if _path_start_key != null and key == _path_start_key:
			label.modulate = DEMO_CONFIG.start_label_color
		elif _path_goal_key != null and key == _path_goal_key:
			label.modulate = DEMO_CONFIG.goal_label_color
		else:
			label.modulate = DEMO_CONFIG.active_label_color if key == _focus_hex_key else DEMO_CONFIG.inactive_label_color


func _set_focus_key(new_focus_key: Vector3i, update_camera: bool = true) -> void:
	if not _tile_meshes_by_key.has(new_focus_key):
		return
	if _hex_map.is_cell_obstacle(new_focus_key):
		return

	_focus_hex_key = new_focus_key
	var focus_tile := _tile_meshes_by_key[new_focus_key] as MeshInstance3D
	if focus_tile != null:
		_focus_world_position = focus_tile.position

	_apply_focus_visuals()
	_update_highlight_outline_position()
	var camera := get_node_or_null("Camera3D") as Camera3D
	CameraController.on_focus_changed(camera, _focus_world_position, _map_world_points, update_camera)


func _set_inspected_key(new_key: Vector3i) -> void:
	if _tile_meshes_by_key.has(new_key):
		_inspected_key = new_key
		_update_inspect_tooltip()


## Purpose/Goal: Map a screen-space click to an existing hex tile key.
## Design Pattern/Principle: Camera ray projection onto the board plane, then cube rounding via the hex library.
## Source/Reference: Camera ray projection docs and `hex_lib.gd` world-to-hex conversion.
## Expected Behavior/Usage: Returns `Vector3i(q,r,s)` for valid board tiles, otherwise `null`.
## Scope: Picking only; does not perform any movement or path mutation.
## Break Risks: Changing board plane height or camera basis without updating the ray-plane intersection.
## Timestamp: 2026-02-23 12:42:00 UTC
func _pick_hex_key_from_screen(screen_pos: Vector2):
	if _layout == null or not has_node("Camera3D"):
		return null

	var camera := get_node("Camera3D") as Camera3D
	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_dir := camera.project_ray_normal(screen_pos)
	var hit = Plane.PLANE_XZ.intersects_ray(ray_origin, ray_dir)
	if hit == null or not (hit is Vector3):
		return null

	var world_pos: Vector3 = hit
	var key: Vector3i = _hex_map.local_to_map(world_pos)
	if _tile_meshes_by_key.has(key):
		return key
	return null


func _pick_any_hex_key_from_screen(screen_pos: Vector2):
	if _layout == null or not has_node("Camera3D"):
		return null

	var camera := get_node("Camera3D") as Camera3D
	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_dir := camera.project_ray_normal(screen_pos)
	var hit = Plane.PLANE_XZ.intersects_ray(ray_origin, ray_dir)
	if hit == null or not (hit is Vector3):
		return null

	var world_pos: Vector3 = hit
	var key: Vector3i = _hex_map.local_to_map(world_pos)
	if _hex_map.is_key_inside_radius(key):
		return key
	return null


func _register_path_pick(hex_key: Vector3i) -> void:
	if _path_start_key == null or _path_goal_key != null:
		_path_start_key = hex_key
		_path_goal_key = null
		_path_is_animating = false
		_final_path_keys.clear()
		_heat_touch_counts.clear()
		_apply_focus_visuals()
		_update_path_lines_mesh()
		_refresh_controls_panel()
		return

	_path_goal_key = hex_key
	if _is_walkable(_path_start_key) and _is_walkable(_path_goal_key):
		emit_signal(
			"path_query_is_requested",
			_path_start_key,
			_path_goal_key,
			_neighbor_key,
			_is_walkable,
			_hex_distance_between_keys
		)
	else:
		_path_is_animating = false
		_final_path_keys.clear()
		_heat_touch_counts.clear()

	_apply_focus_visuals()
	_update_path_lines_mesh()
	_refresh_controls_panel()


func _clear_path_pick_state() -> void:
	_path_is_animating = false
	_path_animation_touch_sequence.clear()
	_path_animation_final_path.clear()
	_path_animation_index = 0
	_path_animation_time_accum = 0.0
	_path_start_key = null
	_path_goal_key = null
	_final_path_keys.clear()
	_heat_touch_counts.clear()
	_apply_focus_visuals()
	_update_path_lines_mesh()
	_refresh_controls_panel()


func _is_walkable(hex_key: Vector3i) -> bool:
	return _hex_map.is_walkable(hex_key)


func _key_to_hex(key: Vector3i):
	return _hex_map.key_to_hex(key)


func _neighbor_key(key: Vector3i, direction: int) -> Vector3i:
	return _hex_map.get_neighbor_cell(key, direction)


func _is_key_inside_demo_radius(key: Vector3i) -> bool:
	return _hex_map.is_key_inside_radius(key)


func _apply_edit_brush(key: Vector3i) -> void:
	if not _is_key_inside_demo_radius(key):
		return
	emit_signal("map_edit_is_requested", key)


func _label_text_for_key(key: Vector3i) -> String:
	var h = _key_to_hex(key)
	match _label_mode:
		LabelMode.CUBE:
			return "q:%d r:%d s:%d" % [key.x, key.y, key.z]
		LabelMode.AXIAL:
			return "q:%d r:%d" % [key.x, key.y]
		LabelMode.ODD_R:
			var odd_r = HexLibScript.roffset_from_cube(HexLibScript.ODD, h)
			return "odd-r %d,%d" % [odd_r.col, odd_r.row]
		LabelMode.EVEN_R:
			var even_r = HexLibScript.roffset_from_cube(HexLibScript.EVEN, h)
			return "even-r %d,%d" % [even_r.col, even_r.row]
		LabelMode.ODD_Q:
			var odd_q = HexLibScript.qoffset_from_cube(HexLibScript.ODD, h)
			return "odd-q %d,%d" % [odd_q.col, odd_q.row]
		LabelMode.EVEN_Q:
			var even_q = HexLibScript.qoffset_from_cube(HexLibScript.EVEN, h)
			return "even-q %d,%d" % [even_q.col, even_q.row]
		LabelMode.Q_DOUBLED:
			var qd = HexLibScript.qdoubled_from_cube(h)
			return "qd %d,%d" % [qd.col, qd.row]
		LabelMode.R_DOUBLED:
			var rd = HexLibScript.rdoubled_from_cube(h)
			return "rd %d,%d" % [rd.col, rd.row]
		LabelMode.DISTANCE:
			var dist = HexLibScript.hex_distance(h, HexLibScript.Hex.new(0, 0, 0))
			return "dist %d" % dist
		_:
			return "%d,%d,%d" % [key.x, key.y, key.z]


func _ensure_controls_panel() -> void:
	if _controls_layer != null:
		return

	_controls_layer = CanvasLayer.new()
	_controls_layer.name = "ControlsLayer"
	add_child(_controls_layer)

	_controls_root = VBoxContainer.new()
	_controls_root.name = "ControlsRoot"
	_controls_root.position = DEMO_CONFIG.panel_root_position
	_controls_root.add_theme_constant_override("separation", 4)
	_controls_layer.add_child(_controls_root)

	_controls_toggle_button = Button.new()
	_controls_toggle_button.text = DEMO_CONFIG.controls_hide_text
	_controls_toggle_button.focus_mode = Control.FOCUS_NONE
	_controls_toggle_button.add_theme_font_size_override("font_size", DEMO_CONFIG.panel_button_text_size)
	_controls_toggle_button.pressed.connect(_on_toggle_controls_pressed)
	_controls_root.add_child(_controls_toggle_button)

	_controls_panel = PanelContainer.new()
	_controls_panel.name = "ControlsPanel"
	_controls_panel.size = DEMO_CONFIG.panel_size
	_controls_panel.focus_mode = Control.FOCUS_NONE
	_controls_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_controls_root.add_child(_controls_panel)

	var margin := MarginContainer.new()
	margin.focus_mode = Control.FOCUS_NONE
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	_controls_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.focus_mode = Control.FOCUS_NONE
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(vbox)

	_mode_tabs_row = HBoxContainer.new()
	_mode_tabs_row.add_theme_constant_override("separation", 4)
	_mode_tabs_row.focus_mode = Control.FOCUS_NONE
	_mode_tabs_row.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(_mode_tabs_row)
	_mode_tab_buttons.clear()
	for i in range(DemoMode.size()):
		var tab_button := Button.new()
		tab_button.custom_minimum_size = DEMO_CONFIG.mode_tab_button_size
		tab_button.focus_mode = Control.FOCUS_NONE
		tab_button.add_theme_font_size_override("font_size", DEMO_CONFIG.panel_button_text_size)
		tab_button.text = _mode_name(i)
		tab_button.pressed.connect(_on_mode_tab_pressed.bind(i))
		_mode_tabs_row.add_child(tab_button)
		_mode_tab_buttons.append(tab_button)


	_controls_label = RichTextLabel.new()
	_controls_label.name = "ControlsLabel"
	_controls_label.bbcode_enabled = true
	_controls_label.fit_content = true
	_controls_label.add_theme_font_size_override("normal_font_size", DEMO_CONFIG.panel_text_size)
	_controls_label.focus_mode = Control.FOCUS_NONE
	_controls_label.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(_controls_label)

	var zoom_note := Label.new()
	zoom_note.text = DEMO_CONFIG.zoom_levels_note
	zoom_note.add_theme_font_size_override("font_size", DEMO_CONFIG.panel_text_size)
	zoom_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(zoom_note)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	vbox.add_child(button_row)

	_animate_toggle_button = CheckButton.new()
	_animate_toggle_button.text = "Animate Pathfinding"
	_animate_toggle_button.focus_mode = Control.FOCUS_NONE
	_animate_toggle_button.add_theme_font_size_override("font_size", DEMO_CONFIG.panel_button_text_size)
	_animate_toggle_button.button_pressed = _path_animation_is_enabled
	_animate_toggle_button.toggled.connect(_on_path_animation_toggled)
	button_row.add_child(_animate_toggle_button)

	_replay_button = Button.new()
	_replay_button.text = "Replay Path"
	_replay_button.focus_mode = Control.FOCUS_NONE
	_replay_button.add_theme_font_size_override("font_size", DEMO_CONFIG.panel_button_text_size)
	_replay_button.pressed.connect(_on_replay_path_pressed)
	button_row.add_child(_replay_button)

	_clamp_controls_root_to_screen()


func _on_toggle_controls_pressed() -> void:
	_set_controls_panel_visible(not _controls_panel.visible)
	_refresh_controls_panel()


func _set_controls_panel_visible(visible_value: bool) -> void:
	if _controls_panel == null or _controls_toggle_button == null:
		return
	if _controls_panel.visible == visible_value:
		return

	var sep := _controls_root.get_theme_constant("separation")
	if not visible_value:
		_controls_root.position.y += _controls_panel.size.y + sep
		_panel_anchor_is_hidden_bottom = true
	elif _panel_anchor_is_hidden_bottom:
		_controls_root.position.y -= _controls_panel.size.y + sep
		_panel_anchor_is_hidden_bottom = false
	_controls_panel.visible = visible_value
	_controls_toggle_button.text = DEMO_CONFIG.controls_hide_text if visible_value else DEMO_CONFIG.controls_show_text
	_clamp_controls_root_to_screen()


func _clamp_controls_root_to_screen() -> void:
	if _controls_root == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var size_x := maxf(_controls_toggle_button.size.x, _controls_panel.size.x)
	var size_y := _controls_toggle_button.size.y
	if _controls_panel.visible:
		size_y += _controls_panel.size.y + _controls_root.get_theme_constant("separation")

	var max_x := maxf(0.0, viewport_size.x - size_x)
	var max_y := maxf(0.0, viewport_size.y - size_y)
	_controls_root.position = Vector2(
		clampf(_controls_root.position.x, 0.0, max_x),
		clampf(_controls_root.position.y, 0.0, max_y)
	)


func _on_mode_tab_pressed(mode_value: int) -> void:
	_set_mode(mode_value)
	_refresh_controls_panel()


func _set_mode(mode_value: int) -> void:
	_mode = clampi(mode_value, 0, DemoMode.size() - 1)


func _refresh_controls_panel() -> void:
	if _controls_label == null:
		return

	var mode_name := _mode_name(_mode)
	var brush_name := _edit_brush_name(_edit_brush)
	var label_name := _label_mode_name(_label_mode)
	var anim_name := "ON" if _path_animation_is_enabled else "OFF"
	var clamp_margin := CameraController.get_pan_clamp_margin()
	var pan_speed := CameraController.get_pan_speed()
	var q_color := DEMO_CONFIG.axis_q_color.to_html(false)
	var r_color := DEMO_CONFIG.axis_r_color.to_html(false)
	var s_color := DEMO_CONFIG.axis_s_color.to_html(false)

	var lines: PackedStringArray = []
	lines.append("Mode: %s" % mode_name)
	lines.append("Label Mode: %s  [L]" % label_name)
	lines.append(DEMO_CONFIG.zoom_controls_hint)
	lines.append("Pan Clamp < >: margin %.0f%% each side" % [clamp_margin * 100.0])
	lines.append("Pan Debug: accel %.2f | speed %.2f" % [CameraController.get_pan_accel_debug(), pan_speed])
	lines.append("Axis Legend: [color=#%s]q[/color] [color=#%s]r[/color] [color=#%s]s[/color]" % [q_color, r_color, s_color])
	if _inspected_key != null:
		lines.append("Selected: [color=#%s]q=%d[/color] [color=#%s]r=%d[/color] [color=#%s]s=%d[/color]" % [q_color, _inspected_key.x, r_color, _inspected_key.y, s_color, _inspected_key.z])
	lines.append("------------------------------")
	lines.append("[Tab] Cycle mode | [1] Inspect [2] Path [3] Edit")
	match _mode:
		DemoMode.INSPECT:
			lines.append("Inspect: click tile to focus and inspect")
			lines.append("Shortcut Keys: [L] labels")
			lines.append(DEMO_CONFIG.rotate_controls_hint)
			lines.append(DEMO_CONFIG.pan_controls_hint)
		DemoMode.PATHFINDING:
			lines.append("Pathfinding: click A then B | [C] clear")
			lines.append("Path Animation: %s" % anim_name)
			lines.append("Replay: button below")
			lines.append(DEMO_CONFIG.rotate_controls_hint)
			lines.append(DEMO_CONFIG.pan_controls_hint)
		DemoMode.MAP_EDIT:
			lines.append("Map Edit: [A] add | [R] remove | [O] obstacle")
			lines.append("Apply brush with left-click")
			lines.append("Current Brush: %s" % brush_name)
			lines.append(DEMO_CONFIG.rotate_controls_hint)
			lines.append(DEMO_CONFIG.pan_controls_hint)

	_controls_label.clear()
	_controls_label.append_text("\n".join(lines))

	if _animate_toggle_button != null:
		_animate_toggle_button.button_pressed = _path_animation_is_enabled
		_animate_toggle_button.visible = _mode == DemoMode.PATHFINDING
	if _replay_button != null:
		_replay_button.disabled = _path_start_key == null or _path_goal_key == null
		_replay_button.visible = _mode == DemoMode.PATHFINDING
	for i in range(_mode_tab_buttons.size()):
		var btn := _mode_tab_buttons[i]
		_apply_mode_tab_style(btn, i == _mode)
	_clamp_controls_root_to_screen()


func _on_path_animation_toggled(toggled_on: bool) -> void:
	_path_animation_is_enabled = toggled_on
	_refresh_controls_panel()


func _on_replay_path_pressed() -> void:
	_replay_pathfinding_animation()


func _on_zoom_step_is_requested(zoom_in_is_requested: bool) -> void:
	var camera := get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		return
	CameraController.request_zoom_step(camera, zoom_in_is_requested, true)
	_refresh_controls_panel()


func _on_hex_map_changed(hex_map: HexMap) -> void:
	_hex_map = hex_map
	if _hex_map == null:
		return
	if not _hex_map.has_cell(_focus_hex_key):
		_focus_hex_key = Vector3i.ZERO
	if _inspected_key != null and not _hex_map.has_cell(_inspected_key):
		_inspected_key = null
		_update_inspect_tooltip()
	_clear_path_pick_state()
	_build_demo_tiles()
	_refresh_controls_panel()


func _on_edit_brush_changed(brush: int) -> void:
	_edit_brush = brush
	_refresh_controls_panel()


func _on_path_result_ready(start_key: Vector3i, goal_key: Vector3i, result: Dictionary) -> void:
	if _path_start_key == null or _path_goal_key == null:
		return
	if start_key != _path_start_key or goal_key != _path_goal_key:
		return
	if _path_animation_is_enabled:
		_start_path_animation(result["touch_sequence"], result["path"])
	else:
		_path_is_animating = false
		_heat_touch_counts = result["touches"]
		_final_path_keys = result["path"]
	_apply_focus_visuals()
	_update_path_lines_mesh()
	_refresh_controls_panel()


func _apply_mode_tab_style(button: Button, is_active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 1.0) if is_active else Color(0.56, 0.56, 0.56, 1.0)
	style.border_color = Color(0.15, 0.15, 0.15, 0.9)
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("focus", style)
	button.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05, 1.0))


func _mode_name(mode_value: int) -> String:
	match mode_value:
		DemoMode.INSPECT:
			return "INSPECT"
		DemoMode.PATHFINDING:
			return "PATHFINDING"
		DemoMode.MAP_EDIT:
			return "MAP EDIT"
		_:
			return "UNKNOWN"


func _edit_brush_name(brush: int) -> String:
	match brush:
		EditBrush.ADD_TILE:
			return "ADD TILE"
		EditBrush.REMOVE_TILE:
			return "REMOVE TILE"
		EditBrush.TOGGLE_OBSTACLE:
			return "TOGGLE OBSTACLE"
		_:
			return "UNKNOWN"


func _label_mode_name(mode_value: int) -> String:
	match mode_value:
		LabelMode.CUBE:
			return "Cube (q,r,s)"
		LabelMode.AXIAL:
			return "Axial (q,r)"
		LabelMode.ODD_R:
			return "Offset odd-r"
		LabelMode.EVEN_R:
			return "Offset even-r"
		LabelMode.ODD_Q:
			return "Offset odd-q"
		LabelMode.EVEN_Q:
			return "Offset even-q"
		LabelMode.Q_DOUBLED:
			return "Doubled q"
		LabelMode.R_DOUBLED:
			return "Doubled r"
		LabelMode.DISTANCE:
			return "Distance from center"
		_:
			return "Unknown"


func _inspect_detail_lines(key: Vector3i) -> PackedStringArray:
	var lines: PackedStringArray = []
	var h = _key_to_hex(key)
	var odd_r = HexLibScript.roffset_from_cube(HexLibScript.ODD, h)
	var even_r = HexLibScript.roffset_from_cube(HexLibScript.EVEN, h)
	var odd_q = HexLibScript.qoffset_from_cube(HexLibScript.ODD, h)
	var even_q = HexLibScript.qoffset_from_cube(HexLibScript.EVEN, h)
	var qd = HexLibScript.qdoubled_from_cube(h)
	var rd = HexLibScript.rdoubled_from_cube(h)
	var dist = HexLibScript.hex_distance(h, HexLibScript.Hex.new(0, 0, 0))
	lines.append("Inspect: q:%d r:%d s:%d" % [key.x, key.y, key.z])
	lines.append("Axial: q:%d r:%d | dist center: %d" % [key.x, key.y, dist])
	lines.append("Offset odd-r: %d,%d | even-r: %d,%d" % [odd_r.col, odd_r.row, even_r.col, even_r.row])
	lines.append("Offset odd-q: %d,%d | even-q: %d,%d" % [odd_q.col, odd_q.row, even_q.col, even_q.row])
	lines.append("Doubled q: %d,%d | doubled r: %d,%d" % [qd.col, qd.row, rd.col, rd.row])
	lines.append("Walkable: %s | Obstacle: %s" % [
		"yes" if _is_walkable(key) else "no",
		"yes" if _hex_map.is_cell_obstacle(key) else "no",
	])
	return lines


func _hex_distance_between_keys(a: Vector3i, b: Vector3i) -> int:
	return _hex_map.get_cell_distance(a, b)


func _start_path_animation(touch_sequence: Array[Vector3i], final_path: Array[Vector3i]) -> void:
	_path_is_animating = true
	_path_animation_touch_sequence = touch_sequence.duplicate()
	_path_animation_final_path = final_path.duplicate()
	_path_animation_index = 0
	_path_animation_time_accum = 0.0
	_heat_touch_counts.clear()
	_final_path_keys.clear()
	_update_path_lines_mesh()


func _replay_pathfinding_animation() -> void:
	if _path_start_key == null or _path_goal_key == null:
		return
	if not _is_walkable(_path_start_key) or not _is_walkable(_path_goal_key):
		return
	emit_signal(
		"path_query_is_requested",
		_path_start_key,
		_path_goal_key,
		_neighbor_key,
		_is_walkable,
		_hex_distance_between_keys
	)
	_refresh_controls_panel()


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

	# Top cap (+Y normal).
	for i in range(1, 5):
		_append_triangle(st, top[0], top[i + 1], top[i])

	# Bottom cap (-Y normal).
	for i in range(1, 5):
		_append_triangle(st, bottom[0], bottom[i], bottom[i + 1])

	# Side walls.
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


func _spawn_camera_if_missing() -> void:
	CameraController.ensure_camera(self, _focus_world_position)


func _fit_window_to_screen() -> void:
	var usable_rect: Rect2i = DisplayServer.screen_get_usable_rect()
	if usable_rect.size == Vector2i.ZERO:
		return

	DisplayServer.window_set_position(usable_rect.position)
	DisplayServer.window_set_size(usable_rect.size)


func _rotate_camera_by_steps(step_delta: int) -> void:
	var camera := get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		return
	CameraController.rotate_by_steps(camera, _focus_world_position, _map_world_points, step_delta)


func _update_camera_orbit_position() -> void:
	var camera := get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		return
	CameraController.apply_camera_transform(camera, _focus_world_position, _map_world_points)


func _spawn_light_if_missing() -> void:
	if has_node("Sun"):
		return

	var light := DirectionalLight3D.new()
	light.name = "Sun"
	light.light_energy = 2.5
	light.rotation_degrees = Vector3(-55.0, 40.0, 0.0)
	add_child(light)
