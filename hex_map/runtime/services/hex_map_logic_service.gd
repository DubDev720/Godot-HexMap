extends Node
class_name HexMapLogicService
## Purpose/Goal: Manages transient simulation state (Pathfinding results, Heatmaps).
## Design Pattern/Principle: Acts as the "Logic Controller" decoupled from rendering and raw input.
## Timestamp: 2026-02-25 00:00:00 EST

const DemoConfigResource: DemoConfig = preload("res://hex_map/demo/demo_config.tres")

signal simulation_updated
signal path_animation_updated

const INVALID_KEY: Vector3i = Vector3i(2147483647, 2147483647, 2147483647)

var heat_touch_counts: Dictionary = {}
var path_is_animating: bool = false
var path_animation_is_enabled: bool = true
var path_start_key: Vector3i = INVALID_KEY
var path_goal_key: Vector3i = INVALID_KEY

var _path_animation_touch_sequence: Array[Vector3i] = []
var _path_animation_index: int = 0
var _path_animation_time_accum: float = 0.0
var _animation_step_time: float = 0.03

var _final_path_keys: Array[Vector3i] = []


func _ready() -> void:
	if DemoConfigResource.pathfinding_config != null:
		_animation_step_time = DemoConfigResource.pathfinding_config.path_animation_step_time

	if HexPathfinder.path_result_ready.is_connected(_on_path_result_ready):
		HexPathfinder.path_result_ready.disconnect(_on_path_result_ready)
	HexPathfinder.path_result_ready.connect(_on_path_result_ready)
	
	if HexInteractionBus.hex_selected.is_connected(_on_hex_selected):
		HexInteractionBus.hex_selected.disconnect(_on_hex_selected)
	HexInteractionBus.hex_selected.connect(_on_hex_selected)

	if HexModeBus.interaction_mode_changed.is_connected(_on_mode_changed):
		HexModeBus.interaction_mode_changed.disconnect(_on_mode_changed)
	HexModeBus.interaction_mode_changed.connect(_on_mode_changed)


func _process(delta: float) -> void:
	if path_is_animating and path_animation_is_enabled:
		_update_path_animation(delta)


func set_animation_speed(step_time: float) -> void:
	_animation_step_time = step_time


func set_path_animation_is_enabled(enabled: bool) -> void:
	path_animation_is_enabled = enabled
	if not enabled and path_is_animating:
		_finish_path_animation_immediately()


func _on_path_result_ready(start_key: Vector3i, goal_key: Vector3i, result: Dictionary) -> void:
	path_start_key = start_key
	path_goal_key = goal_key
	_final_path_keys = result.get("path", [])
	
	heat_touch_counts.clear()
	_path_animation_touch_sequence = result.get("touch_sequence", [])
	_path_animation_index = 0
	path_is_animating = path_animation_is_enabled
	if not path_animation_is_enabled:
		_finish_path_animation_immediately()
	simulation_updated.emit()


func _on_hex_selected(_key: Vector3i) -> void:
	pass


func _update_path_animation(delta: float) -> void:
	_path_animation_time_accum += delta
	
	while _path_animation_time_accum >= _animation_step_time and _path_animation_index < _path_animation_touch_sequence.size():
		_path_animation_time_accum -= _animation_step_time
		
		if _path_animation_index < _path_animation_touch_sequence.size():
			var key = _path_animation_touch_sequence[_path_animation_index]
			heat_touch_counts[key] = int(heat_touch_counts.get(key, 0)) + 1
			_path_animation_index += 1
			path_animation_updated.emit()
	
	if _path_animation_index >= _path_animation_touch_sequence.size():
		path_is_animating = false
		_final_path_keys = _path_animation_touch_sequence.duplicate()
		simulation_updated.emit()


func _finish_path_animation_immediately() -> void:
	for key in _path_animation_touch_sequence:
		heat_touch_counts[key] = int(heat_touch_counts.get(key, 0)) + 1
	_path_animation_index = _path_animation_touch_sequence.size()
	path_is_animating = false
	_final_path_keys = _path_animation_touch_sequence.duplicate()
	path_animation_updated.emit()
	simulation_updated.emit()


func clear_path_state() -> void:
	path_is_animating = false
	path_start_key = INVALID_KEY
	path_goal_key = INVALID_KEY
	heat_touch_counts.clear()
	_path_animation_touch_sequence.clear()
	_path_animation_index = 0
	_path_animation_time_accum = 0.0
	_final_path_keys.clear()
	simulation_updated.emit()


func get_final_path() -> Array[Vector3i]:
	return _final_path_keys


func set_pending_path_selection(start_key: Vector3i, goal_key: Vector3i) -> void:
	path_start_key = start_key
	path_goal_key = goal_key
	simulation_updated.emit()


func _on_mode_changed(new_mode: int) -> void:
	if new_mode != HexModeBus.MODE_TACTICS:
		clear_path_state()
