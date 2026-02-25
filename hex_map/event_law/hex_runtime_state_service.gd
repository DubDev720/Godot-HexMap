extends Node
class_name HexRuntimeStateService
## Purpose/Goal: Authoritatively process runtime hex commands and publish post-commit gameplay events.
## Design Pattern/Principle: Single-writer runtime command handler + deterministic event publisher.
## Source/Reference: `hex_map/development-guides/game-law-event-architecture.md`.
## Expected Behavior/Usage: Place in scene with command/event buses; receives runtime command signals.
## Scope: Runtime command handling for hover/select/map edit only.
## Break Risks: Direct map mutation outside this service can desync projected events and map visuals.
## Timestamp: 2026-02-25 20:12:00 UTC

@export var command_bus_path: NodePath
@export var event_bus_path: NodePath

var _command_bus: Node = null
var _event_bus: Node = null
var _event_sequence: int = 0


func _ready() -> void:
	_command_bus = get_node_or_null(command_bus_path)
	_event_bus = get_node_or_null(event_bus_path)
	if _command_bus == null or _event_bus == null:
		return

	if not _command_bus.hover_hex_requested.is_connected(_on_hover_hex_requested):
		_command_bus.hover_hex_requested.connect(_on_hover_hex_requested)
	if not _command_bus.select_hex_requested.is_connected(_on_select_hex_requested):
		_command_bus.select_hex_requested.connect(_on_select_hex_requested)
	if not _command_bus.map_edit_requested.is_connected(_on_map_edit_requested):
		_command_bus.map_edit_requested.connect(_on_map_edit_requested)
	if not _command_bus.path_query_requested.is_connected(_on_path_query_requested):
		_command_bus.path_query_requested.connect(_on_path_query_requested)


func _next_event_id(prefix: StringName) -> StringName:
	_event_sequence += 1
	return StringName("%s_%06d" % [prefix, _event_sequence])


func _on_hover_hex_requested(key: Vector3i) -> void:
	if _event_bus == null:
		return
	_event_bus.emit_hex_hovered(_next_event_id(StringName("evt_hover")), key)


func _on_select_hex_requested(key: Vector3i) -> void:
	if _event_bus == null:
		return
	_event_bus.emit_hex_selected(_next_event_id(StringName("evt_select")), key)


func _on_map_edit_requested(key: Vector3i) -> void:
	if _event_bus == null:
		return
	var hex_map := HexMapEditor.get_hex_map()
	if hex_map == null:
		return
	if not hex_map.is_key_inside_radius(key):
		return

	HexMapEditor.apply_edit_brush(key)
	var event_id := _next_event_id(StringName("evt_map_edit"))
	_event_bus.emit_map_edit_applied(
		event_id,
		key,
		HexMapEditor.get_edit_brush(),
		HexMapEditor.get_paint_id(),
		hex_map
	)


func _on_path_query_requested(start_key: Vector3i, goal_key: Vector3i) -> void:
	if _event_bus == null:
		return
	var event_id := _next_event_id(StringName("evt_path_query"))
	if HexModeBus.get_current_mode() != HexModeBus.MODE_TACTICS:
		_event_bus.emit_path_query_rejected(event_id, start_key, goal_key, StringName("invalid_mode"))
		return
	var hex_map := HexMapEditor.get_hex_map()
	if hex_map == null:
		_event_bus.emit_path_query_rejected(event_id, start_key, goal_key, StringName("missing_map"))
		return
	if not hex_map.is_walkable(start_key):
		_event_bus.emit_path_query_rejected(event_id, start_key, goal_key, StringName("start_not_walkable"))
		return
	if not hex_map.is_walkable(goal_key):
		_event_bus.emit_path_query_rejected(event_id, start_key, goal_key, StringName("goal_not_walkable"))
		return

	HexPathfinder.request_path(
		start_key,
		goal_key,
		hex_map.get_neighbor_cell,
		hex_map.is_walkable,
		hex_map.get_cell_distance
	)
	_event_bus.emit_path_query_dispatched(event_id, start_key, goal_key)
