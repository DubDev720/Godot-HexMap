extends Node
## Purpose/Goal: Own camera orbit, pan, and zoom stage motion for the hex demo.
## Design Pattern/Principle: Single-authority controller singleton for camera state/mutation.
## Source/Reference: Godot Camera3D + Tween usage from local docs via gdref and existing demo behavior contract.
## Expected Behavior/Usage: `hex_demo.gd` forwards focus/zoom/rotate/pan requests here; this script applies camera transforms.
## Scope: Camera motion only; no map generation, picking, or pathfinding logic.
## Break Risks: Passing stale focus/map points or bypassing this controller can desync camera clamp/follow behavior.
## Timestamp: 2026-02-23 21:25:00 UTC

const ZOOM_LEVELS: Array[float] = [55.0, 45.0, 35.0, 25.0, 15.0]
const CAMERA_ROTATE_TWEEN_TIME: float = 0.32
const ZOOM_TWEEN_TIME: float = 0.18
const PAN_MAX_SPEED: float = 2.4
const PAN_ACCEL: float = 8.0

var _camera_orbit_angle_rad: float = 0.0
var _camera_orbit_radius: float = 22.0
var _camera_height: float = 16.0
var _zoom_step_index: int = 0
var _camera_follow_is_enabled: bool = true
var _camera_pan_local_offset: Vector2 = Vector2.ZERO
var _camera_pan_local_velocity: Vector2 = Vector2.ZERO
var _camera_pan_accel_debug: float = 0.0
var _pan_clamp_margin_levels: Array[float] = [0.20, 0.27, 0.33, 0.38, 0.43]
var _pan_clamp_margin_index: int = 2
var _rotation_tween: Tween = null
var _zoom_tween: Tween = null
var _rotation_camera: Camera3D = null
var _rotation_focus_world_position: Vector3 = Vector3.ZERO
var _rotation_map_world_points: PackedVector3Array = PackedVector3Array()
var _focus_world_pos: Vector3 = Vector3.ZERO
var _map_bounds_points: PackedVector3Array = PackedVector3Array()


func _ready() -> void:
	HexMapBus.hex_map_changed.connect(_on_map_changed)
	HexCameraBus.camera_rotation_requested.connect(_on_rotation_requested)
	HexCameraBus.camera_zoom_requested.connect(_on_zoom_requested)


func _on_map_changed(map) -> void:
	if map:
		_map_bounds_points = map.get_world_points()


func _on_rotation_requested(steps: int) -> void:
	var camera = get_viewport().get_camera_3d()
	if camera:
		rotate_by_steps(camera, _focus_world_pos, _map_bounds_points, steps)


func _on_zoom_requested(zoom_in: bool) -> void:
	var camera = get_viewport().get_camera_3d()
	if camera:
		request_zoom_step(camera, zoom_in, true)


func ensure_camera(target_parent: Node3D, focus_world_position: Vector3) -> Camera3D:
	_focus_world_pos = focus_world_position

	if target_parent.has_node("Camera3D"):
		var existing_camera := target_parent.get_node("Camera3D") as Camera3D
		_bootstrap_state_from_camera(existing_camera, focus_world_position)
		existing_camera.current = true
		existing_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		existing_camera.size = ZOOM_LEVELS[_zoom_step_index]
		existing_camera.look_at(focus_world_position + _get_camera_pan_world_offset(existing_camera), Vector3.UP)
		return existing_camera

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = ZOOM_LEVELS[_zoom_step_index]
	camera.current = true
	target_parent.add_child(camera)
	apply_camera_transform(camera, focus_world_position, PackedVector3Array())
	return camera

func apply_camera_transform(camera: Camera3D, focus_world_position: Vector3, map_world_points: PackedVector3Array) -> void:
	if camera == null:
		return
	_clamp_pan_offset_world_space(map_world_points, focus_world_position)
	var look_target := focus_world_position + _get_camera_pan_world_offset(camera)
	camera.position = look_target + Vector3(
		cos(_camera_orbit_angle_rad) * _camera_orbit_radius,
		_camera_height,
		sin(_camera_orbit_angle_rad) * _camera_orbit_radius
	)
	camera.look_at(look_target, Vector3.UP)


func update_pan_inertia(camera: Camera3D, focus_world_position: Vector3, map_world_points: PackedVector3Array, delta: float) -> void:
	if camera == null or delta <= 0.0:
		return

	var previous_velocity := _camera_pan_local_velocity
	var x_axis := 0.0
	var y_axis := 0.0
	if Input.is_physical_key_pressed(KEY_LEFT):
		x_axis -= 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT):
		x_axis += 1.0
	if Input.is_physical_key_pressed(KEY_UP):
		y_axis += 1.0
	if Input.is_physical_key_pressed(KEY_DOWN):
		y_axis -= 1.0

	var axis := Vector2(x_axis, y_axis)
	var target_velocity := Vector2.ZERO
	if axis.length_squared() > 0.0:
		target_velocity = axis.normalized() * PAN_MAX_SPEED

	if axis.length_squared() == 0.0:
		_camera_pan_local_velocity = Vector2.ZERO
		_camera_pan_accel_debug = 0.0
		return

	_camera_pan_local_velocity = _camera_pan_local_velocity.move_toward(target_velocity, PAN_ACCEL * delta)
	if _camera_pan_local_velocity.length() > PAN_MAX_SPEED:
		_camera_pan_local_velocity = _camera_pan_local_velocity.normalized() * PAN_MAX_SPEED
	_camera_pan_accel_debug = (_camera_pan_local_velocity - previous_velocity).length() / delta

	if _camera_pan_local_velocity.length_squared() > 1e-6:
		_camera_pan_local_offset += _camera_pan_local_velocity * delta
		apply_camera_transform(camera, focus_world_position, map_world_points)


func rotate_by_steps(camera: Camera3D, focus_world_position: Vector3, map_world_points: PackedVector3Array, step_delta: int) -> void:
	if camera == null or step_delta == 0:
		return
	var from_angle := _camera_orbit_angle_rad
	var to_angle := _camera_orbit_angle_rad + deg_to_rad(60.0) * float(step_delta)
	_rotation_camera = camera
	_rotation_focus_world_position = focus_world_position
	_rotation_map_world_points = map_world_points
	if _rotation_tween != null and _rotation_tween.is_running():
		_rotation_tween.kill()

	_rotation_tween = create_tween()
	_rotation_tween.set_trans(Tween.TRANS_SINE)
	_rotation_tween.set_ease(Tween.EASE_IN_OUT)
	_rotation_tween.tween_method(_set_camera_orbit_angle, from_angle, to_angle, CAMERA_ROTATE_TWEEN_TIME)


func _set_camera_orbit_angle(angle: float) -> void:
	_camera_orbit_angle_rad = angle
	apply_camera_transform(_rotation_camera, _rotation_focus_world_position, _rotation_map_world_points)


func request_zoom_step(camera: Camera3D, zoom_in_is_requested: bool, animate: bool = true) -> void:
	if camera == null:
		return
	var delta := 1 if zoom_in_is_requested else -1
	var next_index := clampi(_zoom_step_index + delta, 0, ZOOM_LEVELS.size() - 1)
	set_zoom_index(camera, next_index, animate)


func set_zoom_index(camera: Camera3D, index: int, animate: bool = false) -> void:
	if camera == null:
		return
	_zoom_step_index = clampi(index, 0, ZOOM_LEVELS.size() - 1)
	var target_size := ZOOM_LEVELS[_zoom_step_index]

	if _zoom_tween != null and _zoom_tween.is_running():
		_zoom_tween.kill()

	if animate:
		_zoom_tween = create_tween()
		_zoom_tween.set_trans(Tween.TRANS_SINE)
		_zoom_tween.set_ease(Tween.EASE_IN_OUT)
		_zoom_tween.tween_property(camera, "size", target_size, ZOOM_TWEEN_TIME)
	else:
		camera.size = target_size


func set_focus_follow_is_enabled(enabled: bool) -> void:
	_camera_follow_is_enabled = enabled


func get_focus_follow_is_enabled() -> bool:
	return _camera_follow_is_enabled


func on_focus_changed(camera: Camera3D, focus_world_position: Vector3, map_world_points: PackedVector3Array, update_camera: bool) -> void:
	if not update_camera or not _camera_follow_is_enabled:
		return
	apply_camera_transform(camera, focus_world_position, map_world_points)


func adjust_pan_clamp_aggressiveness(delta: int) -> void:
	_pan_clamp_margin_index = clampi(_pan_clamp_margin_index + delta, 0, _pan_clamp_margin_levels.size() - 1)


func get_pan_clamp_margin() -> float:
	return _pan_clamp_margin_levels[_pan_clamp_margin_index]


func get_pan_accel_debug() -> float:
	return _camera_pan_accel_debug


func get_pan_speed() -> float:
	return _camera_pan_local_velocity.length()


func get_zoom_size() -> float:
	return ZOOM_LEVELS[_zoom_step_index]


func _bootstrap_state_from_camera(camera: Camera3D, focus_world_position: Vector3) -> void:
	var from_focus_total: Vector3 = camera.position - focus_world_position
	var axes := _get_camera_pan_axes(camera)
	var from_focus_planar := Vector3(from_focus_total.x, 0.0, from_focus_total.z)
	_camera_pan_local_offset = Vector2(
		from_focus_planar.dot(axes["right"]),
		from_focus_planar.dot(axes["forward"])
	)

	var from_focus := from_focus_total - _get_camera_pan_world_offset(camera)
	var planar: Vector2 = Vector2(from_focus.x, from_focus.z)
	_camera_orbit_radius = planar.length()
	_camera_height = from_focus.y
	_camera_orbit_angle_rad = atan2(from_focus.z, from_focus.x)
	_sync_zoom_index_to_camera_size(camera)


func _sync_zoom_index_to_camera_size(camera: Camera3D) -> void:
	var best_index := 0
	var best_diff := absf(camera.size - ZOOM_LEVELS[0])
	for i in range(1, ZOOM_LEVELS.size()):
		var diff := absf(camera.size - ZOOM_LEVELS[i])
		if diff < best_diff:
			best_diff = diff
			best_index = i
	_zoom_step_index = best_index


func _get_camera_pan_axes(camera: Camera3D) -> Dictionary:
	var right := camera.global_transform.basis.x
	var forward := -camera.global_transform.basis.z
	right.y = 0.0
	forward.y = 0.0
	if right.length_squared() > 1e-8 and forward.length_squared() > 1e-8:
		return {
			"right": right.normalized(),
			"forward": forward.normalized()
		}


	var right_fallback := Vector3(sin(_camera_orbit_angle_rad), 0.0, -cos(_camera_orbit_angle_rad))
	var forward_fallback := Vector3(-cos(_camera_orbit_angle_rad), 0.0, -sin(_camera_orbit_angle_rad))
	return {
		"right": right_fallback.normalized(),
		"forward": forward_fallback.normalized()
	}


func _get_camera_pan_world_offset(camera: Camera3D) -> Vector3:
	var axes := _get_camera_pan_axes(camera)
	var right: Vector3 = axes["right"]
	var forward: Vector3 = axes["forward"]
	return right * _camera_pan_local_offset.x + forward * _camera_pan_local_offset.y


func _clamp_pan_offset_world_space(map_world_points: PackedVector3Array, focus_world_position: Vector3) -> void:
	if map_world_points.is_empty():
		return

	var max_radius := 0.0
	for p in map_world_points:
		var d := Vector2(p.x - focus_world_position.x, p.z - focus_world_position.z).length()
		if d > max_radius:
			max_radius = d

	if max_radius <= 0.0:
		return

	var margin_ratio := _pan_clamp_margin_levels[_pan_clamp_margin_index]
	var axis_limit := max_radius * clampf(1.0 - margin_ratio, 0.35, 0.9)
	var clamped_x := clampf(_camera_pan_local_offset.x, -axis_limit, axis_limit)
	var clamped_y := clampf(_camera_pan_local_offset.y, -axis_limit, axis_limit)
	if not is_equal_approx(clamped_x, _camera_pan_local_offset.x) or not is_equal_approx(clamped_y, _camera_pan_local_offset.y):
		_camera_pan_local_velocity = Vector2.ZERO
	_camera_pan_local_offset = Vector2(clamped_x, clamped_y)
