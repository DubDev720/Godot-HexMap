extends Node
## Purpose/Goal: Own interaction-mode state transitions for runtime scene UI domains.
## Design Pattern/Principle: Single-authority mode bus with current-state cache.
## Source/Reference: AGENTS.md mode ownership guidance (runtime scene vs editor tool interface).
## Expected Behavior/Usage: Runtime scene owners emit mode transitions; UI managers subscribe for visibility/routing.
## Scope: Mode state only; no input parsing or map editing.
## Break Risks: Bypassing this bus and mutating local mode state silently can desync scene UI behavior.
## Timestamp: 2026-02-25 20:12:00 UTC

signal interaction_mode_changed(mode: int)

const MODE_INSPECT: int = 0
const MODE_PAINT: int = 1
const MODE_TACTICS: int = 2

var _current_mode: int = MODE_INSPECT


func emit_interaction_mode_changed(mode: int) -> void:
	_current_mode = mode
	interaction_mode_changed.emit(mode)


func get_current_mode() -> int:
	return _current_mode
