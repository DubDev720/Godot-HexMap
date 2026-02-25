extends Node
## Purpose/Goal: Centralize HexMap editing/state mutations behind one singleton authority.
## Design Pattern/Principle: Command gateway + signal fan-out for map configuration and edit operations.
## Source/Reference: Project editor workflow requirements and GridMap-style mutation API on `HexMap`.
## Expected Behavior/Usage: Other systems emit configure/edit/brush commands here; this singleton emits map/brush changes.
## Scope: Map setup and edit mutations only; no rendering, camera, or path search.
## Break Risks: Mutating HexMap outside this gateway can desync editor brush state and listeners.
## Timestamp: 2026-02-23 22:42:00 UTC

const HexMapScript = preload("res://hex_map/hex_map.gd")

const EDIT_BRUSH_TOGGLE_OBSTACLE: int = 0
const EDIT_BRUSH_REMOVE_TILE: int = 1
const EDIT_BRUSH_ADD_TILE: int = 2

signal hex_map_changed(hex_map: HexMap)
signal edit_brush_changed(brush: int)
signal paint_id_changed(paint_id: int)

var _hex_map: HexMap = null
var _edit_brush: int = EDIT_BRUSH_TOGGLE_OBSTACLE
var _current_paint_id: int = 0
var _collision_is_enabled: bool = false


func configure_hex_map(
	layout: HexLib.Layout,
	radius: int,
	blank_coords: Array[Vector3i],
	obstacle_coords: Array[Vector3i],
	tier_height: float = 1.0
) -> void:
	if _hex_map == null:
		_hex_map = HexMapScript.new()
	_hex_map.configure(layout, radius, blank_coords, obstacle_coords, tier_height)
	hex_map_changed.emit(_hex_map)
	HexMapBus.emit_hex_map_changed(_hex_map)


func get_hex_map() -> HexMap:
	return _hex_map


func set_edit_brush(brush: int) -> void:
	_edit_brush = clampi(brush, EDIT_BRUSH_TOGGLE_OBSTACLE, EDIT_BRUSH_ADD_TILE)
	edit_brush_changed.emit(_edit_brush)


func get_edit_brush() -> int:
	return _edit_brush


func set_paint_id(paint_id: int) -> void:
	_current_paint_id = paint_id
	paint_id_changed.emit(_current_paint_id)


func get_paint_id() -> int:
	return _current_paint_id


func set_collision_enabled(enabled: bool) -> void:
	_collision_is_enabled = enabled


func is_collision_enabled() -> bool:
	return _collision_is_enabled


func apply_edit_brush(key: Vector3i) -> void:
	if _hex_map == null:
		return
	if not _hex_map.is_key_inside_radius(key):
		return

	match _edit_brush:
		EDIT_BRUSH_ADD_TILE:
			_hex_map.set_cell_item(key, _current_paint_id)
		EDIT_BRUSH_REMOVE_TILE:
			_hex_map.set_cell_item(key, HexMap.INVALID_CELL_ITEM)
		_:
			_hex_map.toggle_cell_obstacle(key)

	hex_map_changed.emit(_hex_map)
	HexMapBus.emit_hex_map_changed(_hex_map)
