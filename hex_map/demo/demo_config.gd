class_name DemoConfig
extends Resource

@export var tile_height: float = 0.25
@export var hex_size: float = 1.0
@export var demo_radius: int = 10
@export var tier_height: float = 1.0

@export var inactive_tile_color: Color = Color(0.42, 0.42, 0.42)
@export var active_tile_color: Color = Color(1.0, 0.1, 0.1)
@export var start_tile_color: Color = Color(0.22, 0.48, 1.0)
@export var goal_tile_color: Color = Color(0.62, 0.2, 0.88)
@export var obstacle_tile_color: Color = Color(0.2, 0.2, 0.2)
@export var heat_light_color: Color = Color(0.72, 0.92, 0.72)
@export var heat_dark_color: Color = Color(0.13, 0.37, 0.13)

@export var inactive_label_color: Color = Color(0.08, 0.08, 0.08)
@export var active_label_color: Color = Color(0.45, 0.0, 0.0)
@export var start_label_color: Color = Color(0.1, 0.25, 0.7)
@export var goal_label_color: Color = Color(0.35, 0.08, 0.5)

@export var axis_q_color: Color = Color(0.92, 0.30, 0.30)
@export var axis_r_color: Color = Color(0.25, 0.70, 0.30)
@export var axis_s_color: Color = Color(0.28, 0.45, 0.88)

@export var highlight_ring_outer_scale: float = 1.06
@export var highlight_ring_inner_scale: float = 0.9
@export var path_line_color: Color = Color(1.0, 0.93, 0.08, 0.95)
@export var path_line_width: float = 0.28
@export var path_animation_step_time: float = 0.03
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

@export var blank_coords: Array[Vector3i] = [
	Vector3i(2, -2, 0),
	Vector3i(2, -1, -1),
	Vector3i(3, -2, -1),
	Vector3i(-2, 2, 0),
	Vector3i(-2, 1, 1),
	Vector3i(-3, 2, 1),
	Vector3i(0, 3, -3),
	Vector3i(0, -3, 3),
]

@export var obstacle_coords: Array[Vector3i] = [
	Vector3i(1, -1, 0),
	Vector3i(1, 0, -1),
	Vector3i(2, 0, -2),
	Vector3i(-1, 1, 0),
	Vector3i(-1, 0, 1),
	Vector3i(-2, 0, 2),
	Vector3i(0, 2, -2),
	Vector3i(0, -2, 2),
]
