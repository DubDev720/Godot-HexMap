extends Node
class_name CombatCommandBus
## Purpose/Goal: Receive gameplay intent commands before authoritative resolution.
## Design Pattern/Principle: Command ingress boundary with typed signal payloads.
## Source/Reference: `hex_map/development-guides/game-law-event-architecture.md`.
## Expected Behavior/Usage: Producers call request methods; authoritative resolver subscribes.
## Scope: Command ingress only; no state mutation and no presentation fanout.
## Break Risks: Bypassing this boundary can introduce split authority and nondeterministic flow.
## Timestamp: 2026-02-25 20:12:00 UTC

signal apply_spell_hit_requested(
	event_id: StringName,
	caster_unit_id: StringName,
	target_unit_id: StringName,
	spell_id: StringName,
	damage_amount: int,
	damage_type: StringName,
	camera_shake_is_requested: bool
)


func request_apply_spell_hit(
	event_id: StringName,
	caster_unit_id: StringName,
	target_unit_id: StringName,
	spell_id: StringName,
	damage_amount: int,
	damage_type: StringName,
	camera_shake_is_requested: bool
) -> void:
	## Purpose/Goal: Emit a spell-hit intent command toward authoritative gameplay resolution.
	## Design Pattern/Principle: Thin command forwarder.
	## Source/Reference: `hex_map/development-guides/game-law-event-architecture.md` spell-hit sequence.
	## Expected Behavior/Usage: Called by runtime/editor interfaces; consumed by resolver.
	## Scope: Emits command signal only.
	## Break Risks: Empty event IDs break correlation across buses.
	## Timestamp: 2026-02-25 20:12:00 UTC
	assert(not String(event_id).is_empty(), "event_id must be non-empty")
	apply_spell_hit_requested.emit(
		event_id,
		caster_unit_id,
		target_unit_id,
		spell_id,
		damage_amount,
		damage_type,
		camera_shake_is_requested
	)
