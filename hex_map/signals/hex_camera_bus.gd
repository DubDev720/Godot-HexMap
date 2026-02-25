extends Node
## Purpose/Goal: Own camera-command event channels for rotation and zoom requests.
## Design Pattern/Principle: Domain signal bus with command-style payloads.
## Source/Reference: AGENTS.md architecture boundaries and scene-lifecycle signal wiring rules.
## Expected Behavior/Usage: Input emitters request camera operations; camera controller is the single consumer authority.
## Scope: Camera command routing only; no camera-state mutation or transform math.
## Break Risks: Multiple camera owners consuming these signals can reintroduce split authority.
## Timestamp: 2026-02-25 20:12:00 UTC

signal camera_rotation_requested(steps: int)
signal camera_zoom_requested(zoom_in_is_requested: bool)


func emit_camera_rotation_requested(steps: int) -> void:
	camera_rotation_requested.emit(steps)


func emit_camera_zoom_requested(zoom_in_is_requested: bool) -> void:
	camera_zoom_requested.emit(zoom_in_is_requested)
