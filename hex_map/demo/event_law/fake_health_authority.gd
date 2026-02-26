extends Node
class_name FakeHealthAuthority
## Purpose/Goal: Provide a tiny authoritative health store for event-law demo execution.
## Design Pattern/Principle: Single-authority in-memory state service.
## Source/Reference: `hex_map/docs/game-law-event-architecture.md`.
## Expected Behavior/Usage: Resolver queries and applies health through this node callbacks.
## Scope: Demo-only health ownership.
## Break Risks: External direct mutation of `_health_by_unit_id` bypasses authority methods.
## Timestamp: 2026-02-25 20:12:00 UTC

signal health_applied(unit_id: StringName, old_health: int, new_health: int)

var _health_by_unit_id: Dictionary = {
	StringName("unit_mage"): 30,
	StringName("unit_knight"): 42,
	StringName("unit_target"): 18,
}


func query_health(unit_id: StringName) -> int:
	## Purpose/Goal: Read authoritative health value for a unit.
	## Design Pattern/Principle: Narrow query gateway.
	## Source/Reference: demo resolver callback contract.
	## Expected Behavior/Usage: Resolver calls this before applying damage.
	## Scope: Read only.
	## Break Risks: Unknown IDs defaulting silently may hide bad test setup.
	## Timestamp: 2026-02-25 20:12:00 UTC
	return int(_health_by_unit_id.get(unit_id, 0))


func apply_health(unit_id: StringName, new_health: int) -> void:
	## Purpose/Goal: Commit authoritative health update for a unit.
	## Design Pattern/Principle: Single mutation gateway.
	## Source/Reference: commit-before-publish contract.
	## Expected Behavior/Usage: Resolver invokes this once per resolved command.
	## Scope: Mutation only.
	## Break Risks: Negative values violate domain constraints if caller skips validation.
	## Timestamp: 2026-02-25 20:12:00 UTC
	var clamped_health: int = maxi(new_health, 0)
	var old_health: int = query_health(unit_id)
	_health_by_unit_id[unit_id] = clamped_health
	health_applied.emit(unit_id, old_health, clamped_health)
