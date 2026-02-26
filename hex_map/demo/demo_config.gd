class_name DemoConfig
extends Resource
## Purpose/Goal: Stores demo-scene composition flags plus references to map and pathfinding schema resources.
## Design Pattern/Principle: Composition root config resource that delegates domain settings to versioned sub-schemas.
## Source/Reference: Runtime scene bootstrap in `hex_demo.gd`.
## Expected Behavior/Usage: Keep runtime/editor/UI toggles here and place map/path values in dedicated schema resources.
## Scope: Owns scene-surface enablement and panel presentation config only.
## Break Risks: Missing schema resources block map generation or path visualization defaults.
## Timestamp: 2026-02-25 00:00:00 EST

const MapConfigTemplate = preload("res://hex_map/core/config/templates/map_config_template.tres")
const PathfindingConfigTemplate = preload("res://hex_map/core/config/templates/pathfinding_config_template.tres")

@export var runtime_interface_is_enabled: bool = true
@export var editor_tool_interface_is_enabled: bool = true
@export var runtime_ui_manager_is_enabled: bool = true
@export var selection_tooltip_is_enabled: bool = true
@export var map_renderer_is_enabled: bool = true
@export var highlight_manager_is_enabled: bool = true
@export var input_controller_is_enabled: bool = true
@export var logic_service_is_enabled: bool = true
@export var runtime_command_pipeline_is_enabled: bool = true

@export var show_legacy_labels: bool = false

@export var map_config: Resource = MapConfigTemplate
@export var pathfinding_config: Resource = PathfindingConfigTemplate

@export var inactive_label_color: Color = Color(0.08, 0.08, 0.08)
@export var active_label_color: Color = Color(0.45, 0.0, 0.0)
@export var start_label_color: Color = Color(0.1, 0.25, 0.7)
@export var goal_label_color: Color = Color(0.35, 0.08, 0.5)

@export var axis_q_color: Color = Color(0.92, 0.30, 0.30)
@export var axis_r_color: Color = Color(0.25, 0.70, 0.30)
@export var axis_s_color: Color = Color(0.28, 0.45, 0.88)

@export var highlight_ring_outer_scale: float = 1.06
@export var highlight_ring_inner_scale: float = 0.9
@export var panel_text_size: int = 17
@export var panel_button_text_size: int = 16
@export var panel_root_position: Vector2 = Vector2(16.0, 16.0)
@export var panel_size: Vector2 = Vector2(560.0, 360.0)
@export var mode_tab_button_size: Vector2 = Vector2(126.0, 28.0)
@export var panel_drag_start_distance: float = 6.0
@export var controls_hide_text: String = "Hide Control Panel [H]"
@export var controls_show_text: String = "Show Control Panel [H]"
@export var zoom_levels_note: String = "Zoom Levels: 15 / 25 / 35 / 45 / 55"
@export var zoom_controls_hint: String = "Zoom Controls: [Z]/[X], wheel, pinch"
@export var rotate_controls_hint: String = "Rotate: [Q]/[E]"
@export var pan_controls_hint: String = "Camera Pan: Arrow keys"
