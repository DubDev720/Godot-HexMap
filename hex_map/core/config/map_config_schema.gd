class_name MapConfigSchema
extends Resource
## Purpose/Goal: Defines canonical map-generation and base tile-visual configuration fields.
## Design Pattern/Principle: Versioned schema resource used as a stable contract for derived map templates.
## Source/Reference: Project map generation flow in `hex_demo.gd` and fallback tile rendering in `hex_map_renderer_3d.gd`.
## Expected Behavior/Usage: Duplicate this schema resource into per-scene/per-mode map config templates and override fields.
## Scope: Owns topology and base tile-state colors only; does not own pathfinding visualization behavior.
## Break Risks: Missing or invalid coords/radius can generate empty maps or disconnected layouts.
## Timestamp: 2026-02-25 00:00:00 EST

@export var schema_version: int = 1

@export var tile_height: float = 0.25
@export var hex_size: float = 1.0
@export var demo_radius: int = 10
@export var tier_height: float = 1.0

@export var inactive_tile_color: Color = Color(0.42, 0.42, 0.42)
@export var active_tile_color: Color = Color(1.0, 0.1, 0.1)
@export var obstacle_tile_color: Color = Color(0.2, 0.2, 0.2)

@export var blank_coords: Array[Vector3i] = [
	Vector3i(2, -2, 0),
	Vector3i(2, -1, -1),
	Vector3i(3, -2, -1),
	Vector3i(-2, 2, 0),
	Vector3i(-2, 1, 1),
	Vector3i(-3, 2, 1),
	Vector3i(0, 3, -3),
	Vector3i(0, -3, 3),
]

@export var obstacle_coords: Array[Vector3i] = [
	Vector3i(1, -1, 0),
	Vector3i(1, 0, -1),
	Vector3i(2, 0, -2),
	Vector3i(-1, 1, 0),
	Vector3i(-1, 0, 1),
	Vector3i(-2, 0, 2),
	Vector3i(0, 2, -2),
	Vector3i(0, -2, 2),
]


func derive_template(overrides: Dictionary = {}) -> MapConfigSchema:
	var derived := duplicate(true) as MapConfigSchema
	for key in overrides.keys():
		if _has_property(derived, key):
			derived.set(key, overrides[key])
	return derived


func _has_property(target: Object, property_name: StringName) -> bool:
	for property in target.get_property_list():
		if StringName(property.name) == property_name:
			return true
	return false
