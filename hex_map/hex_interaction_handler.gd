extends Node
## Purpose/Goal: Maps screen input to hex keys and broadcasts via HexSignalManager.
## Design Pattern/Principle: Input handler with loose coupling via signal bus.
## Timestamp: 2026-02-24 00:00:00 UTC

var _last_hovered_key: Vector3i = Vector3i(-999, -999, -999)
var _hex_map_ref: Node = null


func _ready() -> void:
	_hex_map_ref = HexMapEditor


func _process(_delta: float) -> void:
	var current_key = _get_key_under_mouse()
	if current_key != _last_hovered_key:
		_last_hovered_key = current_key
		HexSignalManager.emit_hex_hovered(current_key)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var selected_key = _get_key_under_mouse()
		HexSignalManager.emit_hex_selected(selected_key)


func _get_key_under_mouse() -> Vector3i:
	var mouse_pos = get_viewport().get_mouse_position()
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		return Vector3i(-999, -999, -999)
	
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)

	var hit = Plane.PLANE_XZ.intersects_ray(ray_origin, ray_dir)
	if hit:
		var hex_map = HexMapEditor.get_hex_map()
		if hex_map != null:
			return hex_map.local_to_map(hit)
	return Vector3i(-999, -999, -999)
