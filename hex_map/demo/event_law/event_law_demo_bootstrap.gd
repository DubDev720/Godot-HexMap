extends Node
class_name EventLawDemoBootstrap
## Purpose/Goal: Bind demo authority callbacks into the example resolver.
## Design Pattern/Principle: Scene bootstrap binder at composition boundary.
## Source/Reference: `hex_map/docs/game-law-event-architecture.md`.
## Expected Behavior/Usage: Assign resolver and health authority node paths in demo scene.
## Scope: Demo bootstrap only.
## Break Risks: Missing callback assignment causes resolver to ignore commands.
## Timestamp: 2026-02-25 20:12:00 UTC

@export var spell_hit_resolver_path: NodePath
@export var health_authority_path: NodePath


func _ready() -> void:
	var spell_hit_resolver := get_node_or_null(spell_hit_resolver_path)
	var health_authority := get_node_or_null(health_authority_path)
	if spell_hit_resolver == null or health_authority == null:
		return
	spell_hit_resolver.health_query_fn = Callable(health_authority, "query_health")
	spell_hit_resolver.health_apply_fn = Callable(health_authority, "apply_health")
