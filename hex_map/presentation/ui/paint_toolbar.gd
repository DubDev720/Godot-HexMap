extends PanelContainer
## Purpose/Goal: Designer palette for selecting and painting hex assets.
## Design Pattern/Principle: UI component listening to signal bus, composable with HexMapEditor.
## Timestamp: 2026-02-24 01:00:00 UTC

@onready var grid_container: GridContainer = $MarginContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var brush_preview: Label = $MarginContainer/VBoxContainer/StatusBar/ActiveBrushName
@onready var tool_buttons: HBoxContainer = $MarginContainer/VBoxContainer/ToolBar/ToolButtons
@onready var single_button: Button = null
@onready var line_button: Button = null

var _selected_tile_id: int = 0
var _current_tool: int = 0
var _line_start_key: Vector3i = Vector3i.ZERO
var _is_line_mode: bool = false
var _interaction_mode: int = HexModeBus.MODE_INSPECT

const TOOL_SINGLE: int = 0
const TOOL_LINE: int = 1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_tool_buttons()
	_populate_palette()
	_connect_signals()


func _connect_signals() -> void:
	if HexInteractionBus.hex_hovered.is_connected(_on_hex_hovered):
		HexInteractionBus.hex_hovered.disconnect(_on_hex_hovered)
	HexInteractionBus.hex_hovered.connect(_on_hex_hovered)
	
	if HexInteractionBus.hex_selected.is_connected(_on_hex_selected):
		HexInteractionBus.hex_selected.disconnect(_on_hex_selected)
	HexInteractionBus.hex_selected.connect(_on_hex_selected)

	if HexModeBus.interaction_mode_changed.is_connected(_on_interaction_mode_changed):
		HexModeBus.interaction_mode_changed.disconnect(_on_interaction_mode_changed)
	HexModeBus.interaction_mode_changed.connect(_on_interaction_mode_changed)
	_on_interaction_mode_changed(HexModeBus.get_current_mode())


func _build_tool_buttons() -> void:
	single_button = Button.new()
	single_button.text = "Single"
	single_button.toggled.connect(_on_tool_toggled.bind(TOOL_SINGLE))
	single_button.button_pressed = true
	tool_buttons.add_child(single_button)
	
	line_button = Button.new()
	line_button.text = "Line"
	line_button.toggled.connect(_on_tool_toggled.bind(TOOL_LINE))
	tool_buttons.add_child(line_button)


func _populate_palette() -> void:
	for child in grid_container.get_children():
		child.queue_free()
	
	var hex_map = HexMapEditor.get_hex_map()
	if hex_map == null:
		return
	
	var hex_set = hex_map.get_hex_set()
	if hex_set == null:
		_add_default_buttons()
		return
	
	var ids = hex_set.get_ids()
	if ids.is_empty():
		_add_default_buttons()
		return
	
	for id in ids:
		var data = hex_set.get_tile_data(id)
		if data == null:
			continue
		var btn = Button.new()
		btn.text = data.terrain_name
		btn.custom_minimum_size = Vector2(70, 50)
		btn.pressed.connect(_on_tile_selected.bind(id, data))
		grid_container.add_child(btn)


func _add_default_buttons() -> void:
	var default_tiles = [
		{"id": 0, "name": "Standard"},
		{"id": 1, "name": "Obstacle"},
	]
	for tile in default_tiles:
		var btn = Button.new()
		btn.text = tile["name"]
		btn.custom_minimum_size = Vector2(70, 50)
		btn.pressed.connect(_on_tile_selected.bind(tile["id"], null))
		grid_container.add_child(btn)


func _on_tile_selected(id: int, _data) -> void:
	_selected_tile_id = id
	HexMapEditor.set_paint_id(id)
	HexMapEditor.set_edit_brush(HexMapEditor.EDIT_BRUSH_ADD_TILE)
	brush_preview.text = "Brush: " + str(id)


func _on_tool_toggled(tool: int, toggled_on: bool) -> void:
	if not toggled_on:
		return
	_current_tool = tool
	_is_line_mode = (tool == TOOL_LINE)
	if single_button and line_button:
		single_button.button_pressed = (tool == TOOL_SINGLE)
		line_button.button_pressed = (tool == TOOL_LINE)
	if _is_line_mode:
		brush_preview.text = "Line Mode - Click start hex"
	else:
		brush_preview.text = "Single Mode"


func _on_hex_hovered(key: Vector3i) -> void:
	if _interaction_mode != HexModeBus.MODE_PAINT:
		return
	if not _is_line_mode:
		return
	if _line_start_key == Vector3i.ZERO:
		return
	
	var hex_map = HexMapEditor.get_hex_map()
	if hex_map == null:
		return


func _on_hex_selected(key: Vector3i) -> void:
	if _interaction_mode != HexModeBus.MODE_PAINT:
		return
	var hex_map = HexMapEditor.get_hex_map()
	if hex_map == null:
		return
	
	if _is_line_mode:
		if _line_start_key == Vector3i.ZERO:
			_line_start_key = key
			brush_preview.text = "Line Mode - Click end hex"
		else:
			_paint_line(_line_start_key, key)
			_line_start_key = Vector3i.ZERO
			brush_preview.text = "Line Mode - Click start hex"
	else:
		_request_map_edit(key)


func _paint_line(start_key: Vector3i, end_key: Vector3i) -> void:
	var hex_map = HexMapEditor.get_hex_map()
	if hex_map == null:
		return
	
	var start_hex = hex_map.key_to_hex(start_key)
	var end_hex = hex_map.key_to_hex(end_key)
	
	var line_hexes = HexLib.hex_linedraw(start_hex, end_hex)
	
	for h in line_hexes:
		var key = hex_map.hex_to_key(h)
		if hex_map.is_key_inside_radius(key):
			_request_map_edit(key)


func _on_interaction_mode_changed(mode: int) -> void:
	_interaction_mode = mode


func _request_map_edit(key: Vector3i) -> void:
	var command_bus = get_tree().get_first_node_in_group("hex_runtime_command_bus")
	if command_bus != null and command_bus.has_method("request_map_edit"):
		command_bus.request_map_edit(key)
		return
	HexMapEditor.apply_edit_brush(key)
