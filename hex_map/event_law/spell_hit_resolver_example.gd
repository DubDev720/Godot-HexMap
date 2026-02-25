extends Node
class_name SpellHitResolverExample
## Purpose/Goal: Demonstrate lawful spell-hit handling: command -> authoritative commit -> gameplay event publish.
## Design Pattern/Principle: Single-writer authoritative resolver with explicit post-commit event emission.
## Source/Reference: `hex_map/development-guides/game-law-event-architecture.md`.
## Expected Behavior/Usage: Wire to `CombatCommandBus`; provide `health_query_fn` and `health_apply_fn` callbacks.
## Scope: Example workflow only; not a full combat system.
## Break Risks: Calling gameplay event bus emitters before health apply callback violates determinism contract.
## Timestamp: 2026-02-25 20:12:00 UTC

@export var combat_command_bus_path: NodePath
@export var gameplay_event_bus_path: NodePath

var health_query_fn: Callable = Callable()
var health_apply_fn: Callable = Callable()

var _combat_command_bus: Node = null
var _gameplay_event_bus: Node = null


func _ready() -> void:
	## Purpose/Goal: Subscribe to command ingress and bind authoritative event publisher.
	## Design Pattern/Principle: Boundary wiring at scene lifecycle start.
	## Source/Reference: manager signal architecture workflow.
	## Expected Behavior/Usage: Set exported paths before running.
	## Scope: Wiring only.
	## Break Risks: Missing bus references means commands are dropped.
	## Timestamp: 2026-02-25 20:12:00 UTC
	_combat_command_bus = get_node_or_null(combat_command_bus_path)
	_gameplay_event_bus = get_node_or_null(gameplay_event_bus_path)
	if _combat_command_bus == null or _gameplay_event_bus == null:
		return

	if not _combat_command_bus.apply_spell_hit_requested.is_connected(_on_apply_spell_hit_requested):
		_combat_command_bus.apply_spell_hit_requested.connect(_on_apply_spell_hit_requested)


func _on_apply_spell_hit_requested(
	event_id: StringName,
	caster_unit_id: StringName,
	target_unit_id: StringName,
	spell_id: StringName,
	damage_amount: int,
	damage_type: StringName,
	_camera_shake_is_requested: bool
) -> void:
	## Purpose/Goal: Resolve and commit spell-hit outcome before publishing authoritative events.
	## Design Pattern/Principle: Commit-then-publish deterministic mutation pipeline.
	## Source/Reference: presentation-event-pipeline contract.
	## Expected Behavior/Usage: Connected from `CombatCommandBus`.
	## Scope: One command handling pass.
	## Break Risks: Invalid callback contracts can skip state mutation and emit false events.
	## Timestamp: 2026-02-25 20:12:00 UTC
	if _gameplay_event_bus == null:
		return
	if String(event_id).is_empty():
		return
	if not health_query_fn.is_valid() or not health_apply_fn.is_valid():
		return

	var old_health_variant: Variant = health_query_fn.call(target_unit_id)
	if not (old_health_variant is int):
		return

	var old_health: int = old_health_variant
	var resolved_damage_amount: int = maxi(damage_amount, 0)
	var new_health: int = maxi(old_health - resolved_damage_amount, 0)
	var crit_is_true: bool = false
	var outcome: StringName = StringName("hit")
	if resolved_damage_amount <= 0:
		outcome = StringName("no_effect")
	elif new_health == 0:
		outcome = StringName("defeat")

	# Authoritative commit occurs before events are emitted.
	health_apply_fn.call(target_unit_id, new_health)

	_gameplay_event_bus.emit_unit_damaged(
		event_id,
		target_unit_id,
		resolved_damage_amount,
		damage_type,
		crit_is_true
	)
	_gameplay_event_bus.emit_health_changed(event_id, target_unit_id, old_health, new_health)
	if new_health == 0:
		_gameplay_event_bus.emit_unit_defeated(event_id, target_unit_id, StringName("spell_damage"))
	_gameplay_event_bus.emit_spell_resolved(event_id, caster_unit_id, target_unit_id, spell_id, outcome)
