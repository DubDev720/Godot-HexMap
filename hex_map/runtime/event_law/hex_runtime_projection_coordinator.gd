extends Node
class_name HexRuntimeProjectionCoordinator
## Purpose/Goal: Project authoritative runtime events into existing interaction/map buses.
## Design Pattern/Principle: Scene-boundary gameplay-to-presentation projection coordinator.
## Source/Reference: `hex_map/docs/game-law-event-architecture.md`.
## Expected Behavior/Usage: Subscribe to `HexRuntimeEventBus`; emit through existing bus APIs for compatibility.
## Scope: Projection only; no authoritative mutation.
## Break Risks: Duplicate projection paths will double-fire downstream listeners.
## Timestamp: 2026-02-25 20:12:00 UTC

@export var event_bus_path: NodePath

var _event_bus: Node = null


func _ready() -> void:
	_event_bus = get_node_or_null(event_bus_path)
	if _event_bus == null:
		return
	if not _event_bus.hex_hovered.is_connected(_on_hex_hovered):
		_event_bus.hex_hovered.connect(_on_hex_hovered)
	if not _event_bus.hex_selected.is_connected(_on_hex_selected):
		_event_bus.hex_selected.connect(_on_hex_selected)
	if not _event_bus.map_edit_applied.is_connected(_on_map_edit_applied):
		_event_bus.map_edit_applied.connect(_on_map_edit_applied)


func _on_hex_hovered(_event_id: StringName, key: Vector3i) -> void:
	HexInteractionBus.emit_hex_hovered(key)


func _on_hex_selected(_event_id: StringName, key: Vector3i) -> void:
	HexInteractionBus.emit_hex_selected(key)


func _on_map_edit_applied(_event_id: StringName, _key: Vector3i, _brush: int, _paint_id: int, hex_map: HexMap) -> void:
	# HexMapEditor is still the active map-change broadcaster in current runtime wiring.
	# Keep this hook for future migration steps without double-emitting map-change events.
	if hex_map == null:
		return
