extends Node
class_name VfxEventBus
## Purpose/Goal: Route presentation-only VFX events derived from authoritative gameplay outcomes.
## Design Pattern/Principle: Presentation bus with explicit effect spawn payloads.
## Source/Reference: `hex_map/docs/game-law-event-architecture.md`.
## Expected Behavior/Usage: Projection coordinator emits; VFX controller consumes.
## Scope: VFX presentation only.
## Break Risks: VFX listeners mutating gameplay state will break determinism.
## Timestamp: 2026-02-25 20:12:00 UTC

signal spawn_spell_impact_fx(event_id: StringName, target_unit_id: StringName, effect_id: StringName)


func emit_spawn_spell_impact_fx(event_id: StringName, target_unit_id: StringName, effect_id: StringName) -> void:
	spawn_spell_impact_fx.emit(event_id, target_unit_id, effect_id)
