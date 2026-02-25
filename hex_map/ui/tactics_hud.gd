extends Control
class_name TacticsHUD
## Purpose/Goal: Controls pathfinding animation and heatmap visualization.
## Design Pattern/Principle: UI component for tactics mode interactions.
## Timestamp: 2026-02-24 03:00:00 UTC

@onready var animate_toggle: CheckButton = $MarginContainer/VBoxContainer/AnimateToggle
@onready var replay_button: Button = $MarginContainer/VBoxContainer/ReplayButton
@onready var speed_slider: HSlider = $MarginContainer/VBoxContainer/SpeedSlider

var _path_start_key: Vector3i = Vector3i.ZERO
var _path_goal_key: Vector3i = Vector3i.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	animate_toggle.button_pressed = true
	
	if HexSignalManager.hex_selected.is_connected(_on_hex_selected):
		HexSignalManager.hex_selected.disconnect(_on_hex_selected)
	HexSignalManager.hex_selected.connect(_on_hex_selected)


func _on_hex_selected(key: Vector3i) -> void:
	if _path_start_key == Vector3i.ZERO:
		_path_start_key = key
	elif _path_goal_key == Vector3i.ZERO:
		_path_goal_key = key
		_emit_path_query()


func _emit_path_query() -> void:
	var map = HexMapEditor.get_hex_map()
	if map == null:
		return
	
	if map.is_walkable(_path_start_key) and map.is_walkable(_path_goal_key):
		HexPathfinder.request_path(
			_path_start_key,
			_path_goal_key,
			map.get_neighbor_cell,
			map.is_walkable,
			map.get_cell_distance
		)
	
	_path_start_key = Vector3i.ZERO
	_path_goal_key = Vector3i.ZERO


func _on_replay_pressed() -> void:
	if _path_start_key != Vector3i.ZERO and _path_goal_key != Vector3i.ZERO:
		_emit_path_query()


func _on_speed_changed(value: float) -> void:
	var logic_service = get_tree().get_first_node_in_group("logic_service")
	if logic_service and logic_service.has_method("set_animation_speed"):
		logic_service.set_animation_speed(value)
