extends Node
## Purpose/Goal: Own interaction-domain event channels for hover/select input.
## Design Pattern/Principle: Domain signal bus with explicit payload contracts.
## Source/Reference: AGENTS.md build-mode architecture rules and manager-signal workflow.
## Expected Behavior/Usage: Input systems emit hover/select; UI and presentation systems subscribe.
## Scope: Interaction events only; no map mutation, camera control, or mode ownership.
## Break Risks: Emitting sentinel/invalid keys as real selections can desync consumers.
## Timestamp: 2026-02-25 20:12:00 UTC

signal hex_hovered(key: Vector3i)
signal hex_selected(key: Vector3i)


func emit_hex_hovered(key: Vector3i) -> void:
	hex_hovered.emit(key)


func emit_hex_selected(key: Vector3i) -> void:
	hex_selected.emit(key)
