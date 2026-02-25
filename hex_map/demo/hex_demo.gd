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


var _focus_world_position: Vector3 = Vector3.ZERO
var _focus_hex_key: Vector3i = Vector3i.ZERO
var _hex_map = null
var _layout = null
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
var _panel_is_dragging: bool = false
var _panel_drag_last_mouse: Vector2 = Vector2.ZERO
var _panel_drag_is_candidate: bool = false
var _panel_drag_press_mouse: Vector2 = Vector2.ZERO
var _panel_anchor_is_hidden_bottom: bool = false
var _map_world_points: PackedVector3Array = PackedVector3Array()
var _interaction_handler: Node = null
var _selection_tooltip: Control = null
var _paint_toolbar: Control = null
var _map_renderer: Node3D = null
var _highlight_manager: Node3D = null
var _input_controller: Node3D = null
var _logic_service: Node = null

const SelectionTooltipScene = preload("res://hex_map/ui/selection_tooltip.tscn")
const PaintToolbarScene = preload("res://hex_map/ui/paint_toolbar.tscn")
const HexInteractionHandlerScript = preload("res://hex_map/hex_interaction_handler.gd")
const HexMapRendererScript = preload("res://hex_map/hex_map_renderer_3d.gd")
const HexHighlightManagerScript = preload("res://hex_map/hex_highlight_manager.gd")
const HexInputControllerScript = preload("res://hex_map/hex_input_controller.gd")
const HexMapLogicServiceScript = preload("res://hex_map/hex_map_logic_service.gd")


func _ready() -> void:
	_fit_window_to_screen()
	map_configure_is_requested.connect(HexMapEditor.configure_hex_map)
	map_edit_brush_set_is_requested.connect(HexMapEditor.set_edit_brush)
	map_edit_is_requested.connect(HexMapEditor.apply_edit_brush)
	HexMapEditor.hex_map_changed.connect(_on_hex_map_changed)
	HexMapEditor.edit_brush_changed.connect(_on_edit_brush_changed)
	emit_signal("map_edit_brush_set_is_requested", _edit_brush)
	_rebuild_topology_sets()
	_spawn_camera_if_missing()
	_spawn_light_if_missing()
	zoom_step_is_requested.connect(_on_zoom_step_is_requested)
	_ensure_controls_panel()
	_ensure_selection_tooltip()
	_ensure_paint_toolbar()
	_ensure_map_renderer()
	_ensure_highlight_manager()
	_ensure_input_controller()
	_ensure_logic_service()
	_refresh_controls_panel()


func _process(delta: float) -> void:
	var camera := get_node_or_null("Camera3D") as Camera3D
	if camera != null:
		CameraController.update_pan_inertia(camera, _focus_world_position, _map_world_points, delta)


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
			var edit_key = _get_hex_under_mouse(event.position)
			if edit_key != null:
				_apply_edit_brush(edit_key)
				_refresh_controls_panel()
			return

		if _mode == DemoMode.PATHFINDING:
			var picked = _get_hex_under_mouse(event.position)
			if picked != null:
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


func _is_point_inside_zoom_slider(_screen_point: Vector2) -> bool:
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
			pass

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

	_map_world_points = _hex_map.get_world_points()

	if _highlight_manager != null and _highlight_manager.has_method("configure"):
		_highlight_manager.configure(_layout, DEMO_CONFIG.tile_height)

	_refresh_controls_panel()








func _apply_edit_brush(key: Vector3i) -> void:
	if _hex_map == null or not _hex_map.is_key_inside_radius(key):
		return
	emit_signal("map_edit_is_requested", key)


func _get_hex_under_mouse(screen_pos: Vector2) -> Vector3i:
	if _layout == null or not has_node("Camera3D"):
		return Vector3i(-999, -999, -999)

	var camera := get_node("Camera3D") as Camera3D
	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_dir := camera.project_ray_normal(screen_pos)
	var hit = Plane.PLANE_XZ.intersects_ray(ray_origin, ray_dir)
	if hit == null or not (hit is Vector3):
		return Vector3i(-999, -999, -999)

	var world_pos: Vector3 = hit
	return _hex_map.local_to_map(world_pos)


func _label_text_for_key(key: Vector3i) -> String:
	var h = _hex_map.key_to_hex(key)
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
	lines.append("------------------------------")
	lines.append("[Tab] Cycle mode | [1] Inspect [2] Path [3] Edit")
	match _mode:
		DemoMode.INSPECT:
			lines.append("Inspect: hover to see tooltip")
			lines.append("Shortcut Keys: [L] labels")
			lines.append(DEMO_CONFIG.rotate_controls_hint)
			lines.append(DEMO_CONFIG.pan_controls_hint)
		DemoMode.PATHFINDING:
			lines.append("Pathfinding: use Tactics HUD")
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

	for i in range(_mode_tab_buttons.size()):
		var btn := _mode_tab_buttons[i]
		_apply_mode_tab_style(btn, i == _mode)
	_clamp_controls_root_to_screen()


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
	_build_demo_tiles()
	_refresh_controls_panel()


func _on_edit_brush_changed(brush: int) -> void:
	_edit_brush = brush
	_refresh_controls_panel()


func _on_path_result_ready(_start_key: Vector3i, _goal_key: Vector3i, _result: Dictionary) -> void:
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


func _ensure_interaction_handler() -> void:
	if _interaction_handler != null:
		return
	_interaction_handler = Node.new()
	_interaction_handler.name = "HexInteractionHandler"
	_interaction_handler.set_script(HexInteractionHandlerScript)
	add_child(_interaction_handler)


func _ensure_selection_tooltip() -> void:
	if _selection_tooltip != null:
		return
	_selection_tooltip = SelectionTooltipScene.instantiate()
	add_child(_selection_tooltip)


func _ensure_paint_toolbar() -> void:
	if _paint_toolbar != null:
		return
	_paint_toolbar = PaintToolbarScene.instantiate()
	_paint_toolbar.position = Vector2(20, 20)
	add_child(_paint_toolbar)


func _ensure_map_renderer() -> void:
	if _map_renderer != null:
		return
	_map_renderer = Node3D.new()
	_map_renderer.name = "HexMapRenderer3D"
	_map_renderer.set_script(HexMapRendererScript)
	add_child(_map_renderer)


func _ensure_highlight_manager() -> void:
	if _highlight_manager != null:
		return
	_highlight_manager = Node3D.new()
	_highlight_manager.name = "HexHighlightManager"
	_highlight_manager.set_script(HexHighlightManagerScript)
	add_child(_highlight_manager)
	if _highlight_manager.has_method("configure"):
		_highlight_manager.configure(_layout, DEMO_CONFIG.tile_height)


func _ensure_input_controller() -> void:
	if _input_controller != null:
		return
	_input_controller = Node3D.new()
	_input_controller.name = "HexInputController"
	_input_controller.set_script(HexInputControllerScript)
	add_child(_input_controller)


func _ensure_logic_service() -> void:
	if _logic_service != null:
		return
	_logic_service = Node.new()
	_logic_service.name = "HexMapLogicService"
	_logic_service.set_script(HexMapLogicServiceScript)
	add_child(_logic_service)
