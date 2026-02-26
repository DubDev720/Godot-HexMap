class_name PathfindingMaterialConfigSchema
extends Resource
## Purpose/Goal: Provide pathfinding visualization config with material overrides for path mesh rendering experiments.
## Design Pattern/Principle: Versioned schema resource for rendering contract + optional material injection.
## Source/Reference: Existing `pathfinding_config_schema.gd` fields and path ribbon behavior in `hex_highlight_manager.gd`.
## Expected Behavior/Usage: Assign this resource to the material-aware pathfinder copy to pass render settings/materials with path results.
## Scope: Owns path presentation parameters and optional material references; does not own path search algorithm.
## Break Risks: Null or incompatible material assignments can fall back to default visuals in consumers.
## Timestamp: 2026-02-26 00:25:00 UTC

@export var schema_version: int = 1

@export var start_tile_color: Color = Color(0.25, 0.50, 1.00)
@export var goal_tile_color: Color = Color(0.25, 0.00, 0.75)
@export var heat_light_color: Color = Color(0.35, 1.00, 0.35)
@export var heat_dark_color: Color = Color(0.00, 0.15, 0.00)

@export var path_line_color: Color = Color(1.0, 0.0, 0.0, 1.0)
@export var path_line_width: float = 0.28
@export var path_animation_step_time: float = 0.03

# Optional material overrides for generated path meshes/ribbons.
@export var path_ribbon_material: Material = null
@export var path_start_marker_material: Material = null
@export var path_goal_marker_material: Material = null
@export var path_goal_cone_material: Material = null


func derive_template(overrides: Dictionary = {}) -> PathfindingMaterialConfigSchema:
	var derived := duplicate(true) as PathfindingMaterialConfigSchema
	for key in overrides.keys():
		if _has_property(derived, key):
			derived.set(key, overrides[key])
	return derived


func _has_property(target: Object, property_name: StringName) -> bool:
	for property in target.get_property_list():
		if StringName(property.name) == property_name:
			return true
	return false
