extends Node
class_name CameraEventBus
## Purpose/Goal: Route presentation-only camera events derived from authoritative gameplay outcomes.
## Design Pattern/Principle: Presentation bus with command-like camera effect requests.
## Source/Reference: `hex_map/development-guides/game-law-event-architecture.md`.
## Expected Behavior/Usage: Projection coordinator emits; camera controller consumes.
## Scope: Camera presentation only.
## Break Risks: Multiple camera authorities consuming and writing gameplay state from effects.
## Timestamp: 2026-02-25 20:12:00 UTC

signal request_screen_shake(event_id: StringName, amplitude: float, duration_seconds: float)


func emit_request_screen_shake(event_id: StringName, amplitude: float, duration_seconds: float) -> void:
	request_screen_shake.emit(event_id, amplitude, duration_seconds)
