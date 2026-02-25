extends Node3D
class_name HexInputController
## Purpose/Goal: Processes raw hardware input into hex-space signals.
## Design Pattern/Principle: Abstracts viewport raycasting and camera manipulation away from the demo.
## Timestamp: 2026-02-24 02:00:00 UTC

signal focus_changed(key: Vector3i)
signal hovered_changed(key: Vector3i)
signal selection_changed(key: Vector3i)

@export var camera: Camera3D = null

var hovered_hex_key: Vector3i = Vector3i(-999, -999, -999)
var selected_hex_key: Vector3i = Vector3i(-999, -999, -999)
var focused_hex_key: Vector3i = Vector3i(-999, -999, -999)

var _last_hovered_key: Vector3i = Vector3i(-999, -999, -999)
var _map_world_points: PackedVector3Array = PackedVector3Array()
var _focus_world_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	print("[HexInputController] _ready called")
	_find_camera()


func _find_camera() -> void:
	if camera == null:
		camera = get_viewport().get_camera_3d()
		print("[HexInputController] camera found: ", camera)


func _process(_delta: float) -> void:
	if camera == null:
		_find_camera()
		return
	
	var current_key = _get_hex_at_mouse(get_viewport().get_mouse_position())
	if current_key != _last_hovered_key:
		_last_hovered_key = current_key
		hovered_hex_key = current_key
		hovered_changed.emit(current_key)
		print("[HexInputController] emitting hex_hovered: ", current_key)
		HexSignalManager.emit_hex_hovered(current_key)


func _unhandled_input(event: InputEvent) -> void:
	_handle_camera_input(event)
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var selected_key = _get_hex_at_mouse(event.position)
		selected_hex_key = selected_key
		selection_changed.emit(selected_key)
		HexSignalManager.emit_hex_selected(selected_key)


func _get_hex_at_mouse(screen_pos: Vector2) -> Vector3i:
	if camera == null:
		return Vector3i(-999, -999, -999)
	
	var ray_origin = camera.project_ray_origin(screen_pos)
	var ray_dir = camera.project_ray_normal(screen_pos)
	var hit = Plane.PLANE_XZ.intersects_ray(ray_origin, ray_dir)
	
	if hit:
		var map = HexMapEditor.get_hex_map()
		if map:
			return map.local_to_map(hit)
	return Vector3i(-999, -999, -999)


func _handle_camera_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			HexSignalManager.emit_camera_rotation_requested(1)
		elif event.keycode == KEY_E:
			HexSignalManager.emit_camera_rotation_requested(-1)
		elif event.keycode == KEY_Z:
			HexSignalManager.emit_camera_zoom_requested(true)
		elif event.keycode == KEY_X:
			HexSignalManager.emit_camera_zoom_requested(false)
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			HexSignalManager.emit_camera_zoom_requested(true)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			HexSignalManager.emit_camera_zoom_requested(false)


func update_focus_position(focus_pos: Vector3, map_points: PackedVector3Array) -> void:
	_focus_world_position = focus_pos
	_map_world_points = map_points


func set_focused_hex(key: Vector3i) -> void:
	if key != focused_hex_key:
		focused_hex_key = key
		focus_changed.emit(key)
