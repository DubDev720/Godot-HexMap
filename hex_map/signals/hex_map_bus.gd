extends Node
## Purpose/Goal: Own map-domain change events for scene consumers.
## Design Pattern/Principle: Domain signal bus with strongly typed map payload.
## Source/Reference: AGENTS.md single-writer mutation gateway via HexMapEditor.
## Expected Behavior/Usage: HexMapEditor emits map changes; renderer/camera/UI listeners react.
## Scope: Map change notification only; no map mutation logic.
## Break Risks: Emitting stale map references after edits can produce desynced visuals.
## Timestamp: 2026-02-25 20:12:00 UTC

signal hex_map_changed(hex_map: HexMap)


func emit_hex_map_changed(hex_map: HexMap) -> void:
	hex_map_changed.emit(hex_map)
