class_name HexTileData
extends Resource
## Purpose/Goal: Defines metadata and visual assets for a single hex type.
## Design Pattern/Principle: Resource-based data container for designer-friendly tile definitions.
## Timestamp: 2026-02-24 00:30:00 UTC

@export_group("Visuals")
@export var mesh: Mesh
@export var material_override: Material

@export_group("Tactical Data")
@export var terrain_name: String = "Plains"
@export var movement_cost: int = 1
@export var is_obstacle: bool = false

@export_group("Advanced")
@export var metadata: Dictionary = {}


func _init() -> void:
	resource_name = "HexTileData"
