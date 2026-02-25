extends Control
class_name HexUIManager
## Purpose/Goal: Manages UI sub-module visibility and transitions.
## Design Pattern/Principle: Coordinates independent panels via HexSignalManager modes.
## Timestamp: 2026-02-24 03:00:00 UTC

@export var show_inspect_hud: bool = true
@export var show_paint_toolbar: bool = true
@export var show_tactics_hud: bool = true

@onready var inspect_hud: Control = $InspectHUD
@onready var paint_toolbar: Control = $PaintToolbar
@onready var tactics_hud: Control = $TacticsHUD


func _ready() -> void:
	if HexSignalManager.interaction_mode_changed.is_connected(_on_mode_changed):
		HexSignalManager.interaction_mode_changed.disconnect(_on_mode_changed)
	HexSignalManager.interaction_mode_changed.connect(_on_mode_changed)
	
	_on_mode_changed(HexSignalManager.get_current_mode())


func _on_mode_changed(new_mode: int) -> void:
	if inspect_hud:
		inspect_hud.visible = show_inspect_hud and (new_mode == HexSignalManager.MODE_INSPECT)
	if paint_toolbar:
		paint_toolbar.visible = show_paint_toolbar and (new_mode == HexSignalManager.MODE_PAINT)
	if tactics_hud:
		tactics_hud.visible = show_tactics_hud and (new_mode == HexSignalManager.MODE_TACTICS)
