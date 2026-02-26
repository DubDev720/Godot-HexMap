extends Node
class_name GameplayEventBus
## Purpose/Goal: Publish authoritative post-commit gameplay events for cross-domain projection.
## Design Pattern/Principle: Authoritative domain event bus with explicit typed channels.
## Source/Reference: `hex_map/docs/game-law-event-architecture.md`.
## Expected Behavior/Usage: Authoritative services emit; projection coordinator subscribes.
## Scope: Gameplay events only; no command ingress and no direct presentation handling.
## Break Risks: Emitting before state commit breaks determinism and replay assumptions.
## Timestamp: 2026-02-25 20:12:00 UTC

signal unit_damaged(
	event_id: StringName,
	target_unit_id: StringName,
	damage_amount: int,
	damage_type: StringName,
	crit_is_true: bool
)

signal health_changed(
	event_id: StringName,
	target_unit_id: StringName,
	old_health: int,
	new_health: int
)

signal unit_defeated(
	event_id: StringName,
	target_unit_id: StringName,
	reason: StringName
)

signal spell_resolved(
	event_id: StringName,
	caster_unit_id: StringName,
	target_unit_id: StringName,
	spell_id: StringName,
	outcome: StringName
)


func emit_unit_damaged(
	event_id: StringName,
	target_unit_id: StringName,
	damage_amount: int,
	damage_type: StringName,
	crit_is_true: bool
) -> void:
	unit_damaged.emit(event_id, target_unit_id, damage_amount, damage_type, crit_is_true)


func emit_health_changed(
	event_id: StringName,
	target_unit_id: StringName,
	old_health: int,
	new_health: int
) -> void:
	health_changed.emit(event_id, target_unit_id, old_health, new_health)


func emit_unit_defeated(
	event_id: StringName,
	target_unit_id: StringName,
	reason: StringName
) -> void:
	unit_defeated.emit(event_id, target_unit_id, reason)


func emit_spell_resolved(
	event_id: StringName,
	caster_unit_id: StringName,
	target_unit_id: StringName,
	spell_id: StringName,
	outcome: StringName
) -> void:
	spell_resolved.emit(event_id, caster_unit_id, target_unit_id, spell_id, outcome)
