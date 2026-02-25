extends Node
class_name HexRuntimeEventBus
## Purpose/Goal: Publish authoritative runtime gameplay events after command handling.
## Design Pattern/Principle: Scene-local gameplay event bus (post-commit only).
## Source/Reference: `hex_map/development-guides/game-law-event-architecture.md` commit-then-publish constraints.
## Expected Behavior/Usage: Runtime state service emits; projection coordinator subscribes.
## Scope: Authoritative runtime event publication only.
## Break Risks: Emitting events before map/state commit breaks determinism assumptions.
## Timestamp: 2026-02-25 20:12:00 UTC

signal hex_hovered(event_id: StringName, key: Vector3i)
signal hex_selected(event_id: StringName, key: Vector3i)
signal map_edit_applied(event_id: StringName, key: Vector3i, brush: int, paint_id: int, hex_map: HexMap)
signal path_query_dispatched(event_id: StringName, start_key: Vector3i, goal_key: Vector3i)
signal path_query_rejected(event_id: StringName, start_key: Vector3i, goal_key: Vector3i, reason: StringName)


func _ready() -> void:
	add_to_group("hex_runtime_event_bus")


func emit_hex_hovered(event_id: StringName, key: Vector3i) -> void:
	hex_hovered.emit(event_id, key)


func emit_hex_selected(event_id: StringName, key: Vector3i) -> void:
	hex_selected.emit(event_id, key)


func emit_map_edit_applied(event_id: StringName, key: Vector3i, brush: int, paint_id: int, hex_map: HexMap) -> void:
	map_edit_applied.emit(event_id, key, brush, paint_id, hex_map)


func emit_path_query_dispatched(event_id: StringName, start_key: Vector3i, goal_key: Vector3i) -> void:
	path_query_dispatched.emit(event_id, start_key, goal_key)


func emit_path_query_rejected(event_id: StringName, start_key: Vector3i, goal_key: Vector3i, reason: StringName) -> void:
	path_query_rejected.emit(event_id, start_key, goal_key, reason)
