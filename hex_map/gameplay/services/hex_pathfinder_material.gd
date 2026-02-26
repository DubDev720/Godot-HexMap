extends Node
class_name HexPathfinderMaterialService
## Purpose/Goal: Run hex A* path queries and attach material-aware rendering config to results.
## Design Pattern/Principle: Stateless search service + externally injected config resource.
## Source/Reference: `hex_pathfinder.gd` algorithm and `pathfinding_material_config_schema.gd` rendering contract.
## Expected Behavior/Usage: Configure once via `set_pathfinding_config`, request paths, consume `path_result_ready` payload including optional materials.
## Scope: Search algorithm and result packaging only; no direct scene rendering or mesh mutation.
## Break Risks: Missing config is tolerated, but downstream renderers must handle null material fields safely.
## Timestamp: 2026-02-26 00:25:00 UTC

const PathfindingMaterialConfigSchemaScript = preload("res://hex_map/core/config/pathfinding_material_config_schema.gd")
const PathfindingMaterialConfigTemplate: PathfindingMaterialConfigSchema = preload("res://hex_map/core/config/templates/pathfinding_material_config_template.tres")

signal path_result_ready(start_key: Vector3i, goal_key: Vector3i, result: Dictionary)

var _pathfinding_config: PathfindingMaterialConfigSchema = null


func _ready() -> void:
	if _pathfinding_config == null:
		_pathfinding_config = PathfindingMaterialConfigTemplate


func set_pathfinding_config(config: Resource) -> void:
	if config != null and config is PathfindingMaterialConfigSchema:
		_pathfinding_config = config
		return
	if config != null:
		push_warning("HexPathfinderMaterial expected PathfindingMaterialConfigSchema; ignoring incompatible config.")


func get_pathfinding_config() -> PathfindingMaterialConfigSchema:
	if _pathfinding_config == null:
		_pathfinding_config = PathfindingMaterialConfigSchemaScript.new()
	return _pathfinding_config


func request_path(
	start_key: Vector3i,
	goal_key: Vector3i,
	neighbor_fn: Callable,
	is_walkable_fn: Callable,
	distance_fn: Callable
) -> void:
	var open_set: Array[Vector3i] = [start_key]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start_key: 0}
	var f_score: Dictionary = {start_key: int(distance_fn.call(start_key, goal_key))}
	var touches: Dictionary = {}
	var touch_sequence: Array[Vector3i] = []

	while not open_set.is_empty():
		var current_index := 0
		var current_key: Vector3i = open_set[0]
		var current_f: int = int(f_score.get(current_key, 2147483647))
		for i in range(1, open_set.size()):
			var candidate_key: Vector3i = open_set[i]
			var candidate_f: int = int(f_score.get(candidate_key, 2147483647))
			if candidate_f < current_f:
				current_f = candidate_f
				current_index = i
				current_key = candidate_key

		open_set.remove_at(current_index)
		touches[current_key] = int(touches.get(current_key, 0)) + 1
		touch_sequence.append(current_key)

		if current_key == goal_key:
			path_result_ready.emit(start_key, goal_key, _build_result_payload(touches, _reconstruct_path(came_from, current_key), touch_sequence))
			return

		for direction in range(6):
			var neighbor_key: Vector3i = neighbor_fn.call(current_key, direction)
			if not is_walkable_fn.call(neighbor_key):
				continue

			touches[neighbor_key] = int(touches.get(neighbor_key, 0)) + 1
			touch_sequence.append(neighbor_key)
			var tentative_g: int = int(g_score.get(current_key, 2147483647)) + 1
			if tentative_g < int(g_score.get(neighbor_key, 2147483647)):
				came_from[neighbor_key] = current_key
				g_score[neighbor_key] = tentative_g
				f_score[neighbor_key] = tentative_g + int(distance_fn.call(neighbor_key, goal_key))
				if not open_set.has(neighbor_key):
					open_set.append(neighbor_key)

	path_result_ready.emit(start_key, goal_key, _build_result_payload(touches, [], touch_sequence))


func _build_result_payload(touches: Dictionary, path: Array[Vector3i], touch_sequence: Array[Vector3i]) -> Dictionary:
	var config := get_pathfinding_config()
	return {
		"touches": touches,
		"path": path,
		"touch_sequence": touch_sequence,
		"pathfinding_config": config,
		"path_ribbon_material": config.path_ribbon_material,
		"path_start_marker_material": config.path_start_marker_material,
		"path_goal_marker_material": config.path_goal_marker_material,
		"path_goal_cone_material": config.path_goal_cone_material,
	}


func _reconstruct_path(came_from: Dictionary, current_key: Vector3i) -> Array[Vector3i]:
	var path: Array[Vector3i] = [current_key]
	var cursor: Variant = current_key
	while came_from.has(cursor):
		cursor = came_from[cursor]
		path.append(cursor)
	path.reverse()
	return path
