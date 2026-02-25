extends Control
class_name HexUIManager
## Purpose/Goal: Manages UI sub-module visibility and transitions.
## Design Pattern/Principle: Coordinates independent panels via mode domain bus transitions.
## Timestamp: 2026-02-24 03:00:00 UTC

@export var inspect_hud_is_enabled: bool = true
@export var paint_toolbar_is_enabled: bool = true
@export var tactics_hud_is_enabled: bool = true

@onready var inspect_hud: Control = $InspectHUD
@onready var paint_toolbar: Control = $PaintToolbar
@onready var tactics_hud: Control = $TacticsHUD


func _ready() -> void:
	# Root manager spans the whole viewport; it must not consume world clicks.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE

	if HexModeBus.interaction_mode_changed.is_connected(_on_mode_changed):
		HexModeBus.interaction_mode_changed.disconnect(_on_mode_changed)
	HexModeBus.interaction_mode_changed.connect(_on_mode_changed)
	
	_on_mode_changed(HexModeBus.get_current_mode())


func _on_mode_changed(new_mode: int) -> void:
	if inspect_hud:
		inspect_hud.visible = inspect_hud_is_enabled and (new_mode == HexModeBus.MODE_INSPECT)
	if paint_toolbar:
		paint_toolbar.visible = paint_toolbar_is_enabled and (new_mode == HexModeBus.MODE_PAINT)
	if tactics_hud:
		tactics_hud.visible = tactics_hud_is_enabled and (new_mode == HexModeBus.MODE_TACTICS)
