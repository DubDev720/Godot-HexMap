extends Control
class_name InspectHUD
## Purpose/Goal: Displays hover metadata and coordinate information.
## Design Pattern/Principle: UI component listening to interaction-domain signals for hover feedback.
## Timestamp: 2026-02-24 03:00:00 UTC

@onready var coord_label: Label = $MarginContainer/VBoxContainer/CoordLabel
@onready var terrain_label: Label = $MarginContainer/VBoxContainer/TerrainLabel
@onready var cost_label: Label = $MarginContainer/VBoxContainer/CostLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	if not HexInteractionBus.hex_hovered.is_connected(_on_hex_hovered):
		HexInteractionBus.hex_hovered.connect(_on_hex_hovered)
	
	visible = false


func _on_hex_hovered(key: Vector3i) -> void:
	var map = HexMapEditor.get_hex_map()
	if map == null or not map.has_cell(key):
		visible = false
		return

	visible = true
	coord_label.text = "Hex: %d, %d" % [key.x, key.y]

	var tile_data = map.get_tile_data_for_cell(key)
	if tile_data != null:
		terrain_label.text = tile_data.terrain_name
		cost_label.text = "Cost: %d" % tile_data.movement_cost
	else:
		if map.is_cell_obstacle(key):
			terrain_label.text = "Obstacle"
			cost_label.text = "Cost: N/A"
		else:
			terrain_label.text = "Standard Tile"
			cost_label.text = "Cost: 1"
