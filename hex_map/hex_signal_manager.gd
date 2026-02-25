extends Node
## Purpose/Goal: Global Signal Bus for hex grid interactions.
## Design Pattern/Principle: Singleton compositional structuring for loose coupling.
## Timestamp: 2026-02-24 00:00:00 UTC

signal hex_hovered(key: Vector3i)
signal hex_selected(key: Vector3i)
signal interaction_mode_changed(mode: int)
signal hex_map_changed(hex_map)
signal simulation_updated

signal camera_rotation_requested(steps: int)
signal camera_zoom_requested(zoom_in: bool)

const MODE_INSPECT: int = 0
const MODE_PAINT: int = 1
const MODE_TACTICS: int = 2

var _current_mode: int = MODE_INSPECT


func emit_hex_hovered(key: Vector3i) -> void:
	hex_hovered.emit(key)


func emit_hex_selected(key: Vector3i) -> void:
	hex_selected.emit(key)


func emit_interaction_mode_changed(mode: int) -> void:
	_current_mode = mode
	interaction_mode_changed.emit(mode)


func get_current_mode() -> int:
	return _current_mode


func emit_hex_map_changed(hex_map) -> void:
	hex_map_changed.emit(hex_map)


func emit_simulation_updated() -> void:
	simulation_updated.emit()


func emit_camera_rotation_requested(steps: int) -> void:
	camera_rotation_requested.emit(steps)


func emit_camera_zoom_requested(zoom_in: bool) -> void:
	camera_zoom_requested.emit(zoom_in)
