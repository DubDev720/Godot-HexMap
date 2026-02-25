extends Node
class_name AudioEventBus
## Purpose/Goal: Route presentation-only audio events derived from authoritative gameplay outcomes.
## Design Pattern/Principle: Presentation bus with deterministic event correlation.
## Source/Reference: `hex_map/development-guides/game-law-event-architecture.md`.
## Expected Behavior/Usage: Projection coordinator emits; audio system consumes.
## Scope: Audio presentation only.
## Break Risks: Audio callbacks mutating gameplay state violate non-authority boundaries.
## Timestamp: 2026-02-25 20:12:00 UTC

signal play_hit_sfx(event_id: StringName, target_unit_id: StringName, damage_type: StringName)


func emit_play_hit_sfx(event_id: StringName, target_unit_id: StringName, damage_type: StringName) -> void:
	play_hit_sfx.emit(event_id, target_unit_id, damage_type)
