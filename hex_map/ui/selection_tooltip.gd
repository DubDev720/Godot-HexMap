extends PanelContainer
## Purpose/Goal: Floating tooltip that follows the mouse with hex metadata.
## Design Pattern/Principle: UI component listening to signal bus for loose coupling.
## Timestamp: 2026-02-24 00:00:00 UTC

@onready var terrain_label: Label = $MarginContainer/VBoxContainer/TerrainLabel
@onready var coord_label: Label = $MarginContainer/VBoxContainer/CoordLabel
@onready var cost_label: Label = $MarginContainer/VBoxContainer/CostLabel
@onready var status_container: HBoxContainer = $MarginContainer/VBoxContainer/StatusContainer
@onready var impassable_icon: TextureRect = $MarginContainer/VBoxContainer/StatusContainer/ImpassableIcon

var _tooltip_offset: Vector2 = Vector2(15, 15)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	if not HexSignalManager.hex_hovered.is_connected(_on_hex_hovered):
		HexSignalManager.hex_hovered.connect(_on_hex_hovered)


func _process(_delta: float) -> void:
	if visible:
		global_position = get_global_mouse_position() + _tooltip_offset


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
		if tile_data.is_obstacle:
			modulate = Color(1.0, 0.4, 0.4, 1.0)
			impassable_icon.visible = true
		else:
			modulate = Color.WHITE
			impassable_icon.visible = false
	else:
		if map.is_cell_obstacle(key):
			terrain_label.text = "Obstacle"
			cost_label.text = "Cost: N/A"
			modulate = Color(1.0, 0.4, 0.4, 1.0)
			impassable_icon.visible = true
		else:
			terrain_label.text = "Standard Tile"
			cost_label.text = "Cost: 1"
			modulate = Color.WHITE
			impassable_icon.visible = false
