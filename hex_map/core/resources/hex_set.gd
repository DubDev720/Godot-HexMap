class_name HexSet
extends Resource
## Purpose/Goal: A collection of HexTileData used as a palette for the HexMap.
## Design Pattern/Principle: Resource-based tile library similar to TileSet.
## Timestamp: 2026-02-24 00:30:00 UTC

@export var tile_library: Dictionary = {}


func get_tile_data(id: int) -> HexTileData:
	return tile_library.get(id, null)


func get_ids() -> Array:
	return tile_library.keys()


func set_tile_data(id: int, data: HexTileData) -> void:
	tile_library[id] = data


func has_tile_data(id: int) -> bool:
	return tile_library.has(id)


func remove_tile_data(id: int) -> void:
	tile_library.erase(id)


func _init() -> void:
	resource_name = "HexSet"
