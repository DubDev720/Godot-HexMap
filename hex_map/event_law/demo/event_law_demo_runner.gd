extends Node
class_name EventLawDemoRunner
## Purpose/Goal: Trigger one spell-hit command to exercise the full event-law pipeline.
## Design Pattern/Principle: Scene orchestration runner for deterministic demo startup.
## Source/Reference: `hex_map/development-guides/game-law-event-architecture.md` spell-hit sequence.
## Expected Behavior/Usage: Attach in demo scene with required node paths assigned.
## Scope: Demo execution only.
## Break Risks: Incorrect command-bus path skips dispatch and yields no trace output.
## Timestamp: 2026-02-25 20:12:00 UTC

@export var combat_command_bus_path: NodePath
@export var spell_hit_resolver_path: NodePath


func _ready() -> void:
	## Purpose/Goal: Dispatch the demo command after all nodes finish `_ready`.
	## Design Pattern/Principle: Deferred dispatch to avoid startup ordering races.
	## Source/Reference: scene lifecycle composition workflow.
	## Expected Behavior/Usage: Runs once at scene boot.
	## Scope: Demo-only command trigger.
	## Break Risks: Dispatching synchronously may race resolver subscriptions.
	## Timestamp: 2026-02-25 20:12:00 UTC
	var combat_command_bus := get_node_or_null(combat_command_bus_path)
	var spell_hit_resolver := get_node_or_null(spell_hit_resolver_path)
	if combat_command_bus == null or spell_hit_resolver == null:
		return
	call_deferred("_dispatch_demo_spell_hit")


func _dispatch_demo_spell_hit() -> void:
	var combat_command_bus := get_node_or_null(combat_command_bus_path)
	if combat_command_bus == null:
		return
	combat_command_bus.request_apply_spell_hit(
		StringName("evt_spell_0001"),
		StringName("unit_mage"),
		StringName("unit_target"),
		StringName("firebolt"),
		6,
		StringName("fire"),
		true
	)
