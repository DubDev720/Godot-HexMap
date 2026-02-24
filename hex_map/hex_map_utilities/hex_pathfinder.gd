extends Node
## Purpose/Goal: Run hex A* path queries as a reusable singleton service.
## Design Pattern/Principle: Stateless compute service + signal return channel.
## Source/Reference: Existing `HexPathfinding` algorithm extracted from demo workflow.
## Expected Behavior/Usage: Request a path with callables, receive result via `path_result_ready`.
## Scope: Search algorithm and result packaging only; no map mutations or rendering.
## Break Risks: Invalid callback contracts can return empty/incorrect paths.
## Timestamp: 2026-02-23 22:42:00 UTC

signal path_result_ready(start_key: Vector3i, goal_key: Vector3i, result: Dictionary)


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
			path_result_ready.emit(start_key, goal_key, {
				"touches": touches,
				"path": _reconstruct_path(came_from, current_key),
				"touch_sequence": touch_sequence,
			})
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

	path_result_ready.emit(start_key, goal_key, {
		"touches": touches,
		"path": [],
		"touch_sequence": touch_sequence,
	})


func _reconstruct_path(came_from: Dictionary, current_key: Vector3i) -> Array[Vector3i]:
	var path: Array[Vector3i] = [current_key]
	var cursor: Variant = current_key
	while came_from.has(cursor):
		cursor = came_from[cursor]
		path.append(cursor)
	path.reverse()
	return path
