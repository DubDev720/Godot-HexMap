class_name PathfindingConfigSchema
extends Resource
## Purpose/Goal: Defines canonical pathfinding visualization and animation configuration fields.
## Design Pattern/Principle: Versioned schema resource used as a stable contract for derived pathfinding templates.
## Source/Reference: Path highlighting and heatmap behavior in `hex_highlight_manager.gd` and `hex_map_logic_service.gd`.
## Expected Behavior/Usage: Duplicate this schema resource into per-scene/per-mode path templates and override fields.
## Scope: Owns path/heat/start/end presentation and animation pacing; does not own map topology generation.
## Break Risks: Invalid colors or step timing can produce unreadable overlays or unstable animation cadence.
## Timestamp: 2026-02-25 00:00:00 EST

@export var schema_version: int = 1

@export var start_tile_color: Color = Color(0.25, 0.50, 1.00)
@export var goal_tile_color:  Color = Color(0.25, 0.00, 0.75)
@export var heat_light_color: Color = Color(0.35, 1.00, 0.35)
@export var heat_dark_color:  Color = Color(0.00, 0.15, 0.00)

@export var path_line_color: Color = Color(1.0, 0.0, 0.00, 1.0)
@export var path_line_width: float = 0.28
@export var path_animation_step_time: float = 0.03


func derive_template(overrides: Dictionary = {}) -> PathfindingConfigSchema:
	var derived := duplicate(true) as PathfindingConfigSchema
	for key in overrides.keys():
		if _has_property(derived, key):
			derived.set(key, overrides[key])
	return derived


func _has_property(target: Object, property_name: StringName) -> bool:
	for property in target.get_property_list():
		if StringName(property.name) == property_name:
			return true
	return false
