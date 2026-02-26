extends Node
class_name HexRuntimeCommandBus
## Purpose/Goal: Accept runtime hex interaction/edit commands before authoritative handling.
## Design Pattern/Principle: Scene-local command ingress boundary.
## Source/Reference: `hex_map/docs/game-law-event-architecture.md`.
## Expected Behavior/Usage: Input/UI emit requests here; runtime state service is authoritative consumer.
## Scope: Command ingress only; no direct map mutation or presentation fanout.
## Break Risks: Bypassing this bus for runtime edits reintroduces split mutation pathways.
## Timestamp: 2026-02-25 20:12:00 UTC

signal hover_hex_requested(key: Vector3i)
signal select_hex_requested(key: Vector3i)
signal map_edit_requested(key: Vector3i)
signal path_query_requested(start_key: Vector3i, goal_key: Vector3i)


func _ready() -> void:
	add_to_group("hex_runtime_command_bus")


func request_hover_hex(key: Vector3i) -> void:
	hover_hex_requested.emit(key)


func request_select_hex(key: Vector3i) -> void:
	select_hex_requested.emit(key)


func request_map_edit(key: Vector3i) -> void:
	map_edit_requested.emit(key)


func request_path_query(start_key: Vector3i, goal_key: Vector3i) -> void:
	path_query_requested.emit(start_key, goal_key)
