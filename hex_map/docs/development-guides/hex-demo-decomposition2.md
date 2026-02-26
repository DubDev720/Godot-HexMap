To fix the camera system and eliminate the shadowing and unused parameter errors, we need to transform the **CameraController** into a reactive listener that follows the **HexSignalManager**.

Here are the portions to update of the files that still need to be updated to align with the current modular architecture.

### 1. HexSignalManager Updates

Add the missing signals to `hex_signal_manager.gd` so the `HexInputController` can request camera actions without knowing about the `CameraController` script.

```gdscript
# hex_signal_manager.gd
extends Node

signal hex_hovered(key: Vector3i)
signal hex_selected(key: Vector3i)
signal interaction_mode_changed(mode: int)
signal hex_map_changed(hex_map)
signal simulation_updated

# New signals for Camera orchestration
signal camera_rotation_requested(steps: int)
signal camera_zoom_requested(zoom_in: bool)

# ... (rest of the existing constants and methods)

```

### 2. Rewriting CameraController.gd

This revision fixes the `SHADOWED_VARIABLE_BASE_CLASS` error by renaming `owner` to `target_parent`. It also becomes a listener for the signal bus to handle selection and rotation automatically.

```gdscript
# camera_controller.gd
extends Node
## Purpose: Independent listener that manages the viewport camera.

const ZOOM_LEVELS: Array[float] = [55.0, 45.0, 35.0, 25.0, 15.0]
const CAMERA_ROTATE_TWEEN_TIME: float = 0.32
const ZOOM_TWEEN_TIME: float = 0.18
const PAN_MAX_SPEED: float = 2.4
const PAN_ACCEL: float = 8.0

var _current_camera: Camera3D = null
var _focus_world_pos: Vector3 = Vector3.ZERO
var _map_bounds_points: PackedVector3Array = PackedVector3Array()

# Internal camera state variables
var _camera_orbit_angle_rad: float = 0.0
var _camera_orbit_radius: float = 22.0
var _camera_height: float = 16.0
var _zoom_step_index: int = 0
var _camera_pan_local_offset: Vector2 = Vector2.ZERO
var _pan_clamp_margin_levels: Array[float] = [0.20, 0.27, 0.33, 0.38, 0.43]
var _pan_clamp_margin_index: int = 2

func _ready() -> void:
	# Standard bus connections for a decoupled architecture
	HexSignalManager.hex_selected.connect(_on_hex_selected)
	HexSignalManager.hex_map_changed.connect(_on_map_changed)
	HexSignalManager.camera_rotation_requested.connect(_on_rotation_requested)
	HexSignalManager.camera_zoom_requested.connect(_on_zoom_requested)

func _on_hex_selected(key: Vector3i) -> void:
	var map = HexMapEditor.get_hex_map()
	if map and map.has_cell(key):
		_focus_world_pos = map.key_to_world(key)
		if _current_camera:
			apply_camera_transform(_current_camera, _focus_world_pos, _map_bounds_points)

func _on_map_changed(map) -> void:
	if map:
		_map_bounds_points = map.get_world_points()

func _on_rotation_requested(steps: int) -> void:
	if _current_camera:
		rotate_by_steps(_current_camera, _focus_world_pos, _map_bounds_points, steps)

func _on_zoom_requested(zoom_in: bool) -> void:
	if _current_camera:
		request_zoom_step(_current_camera, zoom_in, true)

## FIXED: renamed 'owner' to 'target_parent' to avoid shadowing Node.owner
func ensure_camera(target_parent: Node3D, focus_pos: Vector3) -> Camera3D:
	_focus_world_pos = focus_pos

	if target_parent.has_node("Camera3D"):
		_current_camera = target_parent.get_node("Camera3D")
		return _current_camera

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = ZOOM_LEVELS[_zoom_step_index]
	camera.current = true
	target_parent.add_child(camera)
	_current_camera = camera
	apply_camera_transform(camera, _focus_world_pos, _map_bounds_points)
	return camera

# ...(Maintain existing tweening and math methods like apply_camera_transform)

```

### 3. Cleanup of Warnings

In `hex_map_logic_service.gd`, suppress the unused parameter warning for the `_on_hex_selected` callback.

```gdscript
# hex_map_logic_service.gd
# ...
func _on_hex_selected(_key: Vector3i) -> void: # Prefix with underscore
	pass
# ...

```

### 4. Integrating HexInputController

Finally, update the `HexInputController.gd` to use the new signals. This removes the need for it to have a direct reference to the `CameraController` script.

```gdscript
# hex_input_controller.gd
# ...
func _handle_camera_input(event: InputEvent) -> void:
	if event.is_action_pressed("rotate_left"):
		HexSignalManager.camera_rotation_requested.emit(1)
	elif event.is_action_pressed("rotate_right"):
		HexSignalManager.camera_rotation_requested.emit(-1)

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			HexSignalManager.camera_zoom_requested.emit(true)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			HexSignalManager.camera_zoom_requested.emit(false)
# ...

```

---

To modularize the UI and replace the monolithic `_refresh_controls_panel` function , we will implement a **HexUIManager** that orchestrates independent, reactive UI sub-modules. These modules listen directly to the `HexSignalManager` bus, ensuring that your `hex_demo.gd` script is relieved of UI state tracking.

---

### 5. HexUIManager (The Orchestrator)

Instead of a single "God panel," this node manages the visibility of sub-components based on the global interaction mode.

```gdscript
extends Control
class_name HexUIManager
## Purpose: Manages UI sub-module visibility and transitions.
## Principle: Coordinates independent panels via HexSignalManager modes.

@onready var inspect_hud: Control = $InspectHUD
@onready var paint_toolbar: Control = $PaintToolbar
@onready var tactics_hud: Control = $TacticsHUD

func _ready() -> void:
    HexSignalManager.interaction_mode_changed.connect(_on_mode_changed)
    _on_mode_changed(HexSignalManager.get_current_mode())

func _on_mode_changed(new_mode: int) -> void:
    # Ergonomics: Only show the tools relevant to the current designer intent
    inspect_hud.visible = (new_mode == HexSignalManager.MODE_INSPECT)
    paint_toolbar.visible = (new_mode == HexSignalManager.MODE_PAINT)
    tactics_hud.visible = (new_mode == HexSignalManager.MODE_TACTICS)

```

---

### 6. UI Sub-Module: Metadata Inspector (Inspect Mode)

This module replaces your legacy `_inspect_detail_lines` logic . It renders the **Designer-First** data you established in the `HexTileData` resources.

* **Logic:** Listens for `hex_hovered(key)`.
* **Ergonomics:** Automatically updates coordinate and terrain labels .

---

### 3. UI Sub-Module: Paint Palette (Paint Mode)

This component replaces the hard-coded brush logic in the demo.

* **Logic:** Iterates through the `HexSet` to create buttons for each tile type.
* **Mutation:** Clicking a tile button updates `HexMapEditor.current_paint_id`.

---

### 7. UI Sub-Module: Tactics Panel (Tactics Mode)

This surfaces the `HexMapLogicService` state, replacing the pathfinding animation toggles from the original demo .

* **Controls:**
* **Animation Speed Slider:** Updates `HexMapLogicService.set_animation_speed()`.
* **Replay Button:** Emits `path_query_is_requested` using the current `path_start_key`.

---

### 8. Final Decomposition Results

By extracting these modules, the `hex_demo.gd` script is now reduced to simple setup logic:

| Component | Responsibility | Extracted Legacy Variables |
| --- | --- | --- |
| **InspectHUD** | Hover feedback & metadata | <br>`_inspect_tooltip`, `_label_mode` |
| **PaintToolbar** | Asset selection & brush modes | <br>`_edit_brush`, `_mode_tabs_row` |
| **TacticsHUD** | Path replay & heatmap toggles | <br>`_animate_toggle_button`, `_replay_button` |

### Implementation Checklist

1. **Scene Structure:** Create a `res://hex_map/presentation/ui/` folder and save each module as its own `.tscn`.
2. **Theme Consistency:** Ensure each `PanelContainer` uses your shared `DEMO_CONFIG` values for font sizes and colors.
3. **Mouse Filter:** Set HUD containers to `MOUSE_FILTER_STOP` to prevent clicks on UI buttons from also painting tiles "underneath" them.
