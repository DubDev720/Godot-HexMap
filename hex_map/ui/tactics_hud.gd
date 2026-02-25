extends Control
class_name TacticsHUD
## Purpose/Goal: Controls pathfinding animation and heatmap visualization.
## Design Pattern/Principle: UI component for tactics mode interactions.
## Timestamp: 2026-02-24 03:00:00 UTC

const INVALID_KEY: Vector3i = Vector3i(2147483647, 2147483647, 2147483647)

@onready var animate_toggle: CheckButton = $MarginContainer/VBoxContainer/AnimateToggle
@onready var replay_button: Button = $MarginContainer/VBoxContainer/ReplayButton
@onready var speed_slider: HSlider = $MarginContainer/VBoxContainer/SpeedSlider

var _path_start_key: Vector3i = INVALID_KEY
var _path_goal_key: Vector3i = INVALID_KEY
var _last_path_start_key: Vector3i = INVALID_KEY
var _last_path_goal_key: Vector3i = INVALID_KEY
var _controls_are_applied_to_logic_service: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	animate_toggle.button_pressed = true
	if not animate_toggle.toggled.is_connected(_on_animate_toggled):
		animate_toggle.toggled.connect(_on_animate_toggled)
	if not replay_button.pressed.is_connected(_on_replay_pressed):
		replay_button.pressed.connect(_on_replay_pressed)
	if not speed_slider.value_changed.is_connected(_on_speed_changed):
		speed_slider.value_changed.connect(_on_speed_changed)
	
	if HexInteractionBus.hex_selected.is_connected(_on_hex_selected):
		HexInteractionBus.hex_selected.disconnect(_on_hex_selected)
	HexInteractionBus.hex_selected.connect(_on_hex_selected)

	if HexModeBus.interaction_mode_changed.is_connected(_on_mode_changed):
		HexModeBus.interaction_mode_changed.disconnect(_on_mode_changed)
	HexModeBus.interaction_mode_changed.connect(_on_mode_changed)

	_on_animate_toggled(animate_toggle.button_pressed)
	_on_speed_changed(speed_slider.value)
	_on_mode_changed(HexModeBus.get_current_mode())


func _process(_delta: float) -> void:
	if not _controls_are_applied_to_logic_service:
		_apply_controls_to_logic_service()


func _on_hex_selected(key: Vector3i) -> void:
	if HexModeBus.get_current_mode() != HexModeBus.MODE_TACTICS:
		return
	if _path_start_key == INVALID_KEY:
		_path_start_key = key
		_sync_pending_path_selection()
	elif _path_goal_key == INVALID_KEY:
		_path_goal_key = key
		_sync_pending_path_selection()
		_emit_path_query()


func _emit_path_query() -> void:
	var map = HexMapEditor.get_hex_map()
	if map == null:
		return
	
	if map.is_walkable(_path_start_key) and map.is_walkable(_path_goal_key):
		_last_path_start_key = _path_start_key
		_last_path_goal_key = _path_goal_key
		var command_bus = get_tree().get_first_node_in_group("hex_runtime_command_bus")
		if command_bus != null and command_bus.has_method("request_path_query"):
			command_bus.request_path_query(_path_start_key, _path_goal_key)
		else:
			HexPathfinder.request_path(
				_path_start_key,
				_path_goal_key,
				map.get_neighbor_cell,
				map.is_walkable,
				map.get_cell_distance
			)
	
	_path_start_key = INVALID_KEY
	_path_goal_key = INVALID_KEY
	_sync_pending_path_selection()


func _on_replay_pressed() -> void:
	if _last_path_start_key == INVALID_KEY or _last_path_goal_key == INVALID_KEY:
		return
	var map = HexMapEditor.get_hex_map()
	if map == null:
		return
	if not map.is_walkable(_last_path_start_key) or not map.is_walkable(_last_path_goal_key):
		return
	var command_bus = get_tree().get_first_node_in_group("hex_runtime_command_bus")
	if command_bus != null and command_bus.has_method("request_path_query"):
		command_bus.request_path_query(_last_path_start_key, _last_path_goal_key)
	else:
		HexPathfinder.request_path(
			_last_path_start_key,
			_last_path_goal_key,
			map.get_neighbor_cell,
			map.is_walkable,
			map.get_cell_distance
		)


func _on_speed_changed(value: float) -> void:
	var logic_service = get_tree().get_first_node_in_group("logic_service")
	if logic_service and logic_service.has_method("set_animation_speed"):
		logic_service.set_animation_speed(value)
		_controls_are_applied_to_logic_service = true


func _on_mode_changed(new_mode: int) -> void:
	var map_renderer = get_tree().root.find_child("HexMapRenderer3D", true, false)
	if map_renderer != null and map_renderer.has_method("set_heatmap_is_enabled"):
		map_renderer.set_heatmap_is_enabled(new_mode == HexModeBus.MODE_TACTICS)
	if new_mode != HexModeBus.MODE_TACTICS:
		_path_start_key = INVALID_KEY
		_path_goal_key = INVALID_KEY
		_sync_pending_path_selection()


func _sync_pending_path_selection() -> void:
	var logic_service = get_tree().get_first_node_in_group("logic_service")
	if logic_service != null and logic_service.has_method("set_pending_path_selection"):
		logic_service.set_pending_path_selection(_path_start_key, _path_goal_key)


func _on_animate_toggled(enabled: bool) -> void:
	var logic_service = get_tree().get_first_node_in_group("logic_service")
	if logic_service != null and logic_service.has_method("set_path_animation_is_enabled"):
		logic_service.set_path_animation_is_enabled(enabled)
		_controls_are_applied_to_logic_service = true


func _apply_controls_to_logic_service() -> void:
	_on_animate_toggled(animate_toggle.button_pressed)
	_on_speed_changed(speed_slider.value)
