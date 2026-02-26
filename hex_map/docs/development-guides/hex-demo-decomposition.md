To decompose the demo to prepare it for production workflows, we will extract the visual and collision logic from `hex_demo.gd` and place it into a specialized **HexMapRenderer3D** node. This keeps the `HexMap` container as a "pure" data object and allows the demo script to focus on high-level UI and input orchestration.

### 1. Deactivating Legacy Billboard Tooltips

To silence the direct-on-tile labels while retaining the ability to flip them back on for debugging, update the configuration and the main demo loop.

**In `demo_config.gd`:**
* Add: `@export var show_legacy_labels: bool = false`.

**In `hex_demo.gd`:**
* Within `_build_demo_tiles`, wrap the `Label3D` instantiation:

```gdscript
# Inside the for key in _hex_map.get_used_cells() loop
if DEMO_CONFIG.show_legacy_labels:
    var label := Label3D.new()
    # ...(existing label configuration code)
    add_child(label)
    _tile_labels_by_key[key] = label

```

---

### 2. Implementation: `HexMapRenderer3D.gd`

This module becomes the "Visual Owner." It manages batching for performance and provides an optional entry point for walkthrough collisions.

```gdscript
extends Node3D
class_name HexMapRenderer3D
## Purpose: Centralized visual representation of a HexMap using MultiMeshes.
## Principle: Decoupled visual owner that reacts to HexSignalManager broadcasts.

# Map of tile_id to the specific MultiMeshInstance3D rendering that group
var _multimesh_nodes: Dictionary = {} 
# Map of coordinate to collision body for walkthrough/picking support
var _collision_nodes: Dictionary = {} 

@export var enable_collisions: bool = false

func _ready() -> void:
	if HexSignalManager.has_signal("hex_map_changed"):
		HexSignalManager.hex_map_changed.connect(_on_map_changed)
	else:
		push_error("HexMapRenderer3D: HexSignalManager 'hex_map_changed' signal missing.")

func _on_map_changed(map: HexMap) -> void:
	refresh_visuals(map)

## Regenerates the visuals based on the map's current cell-to-ID mapping
func refresh_visuals(map: HexMap) -> void:
	_clear_visuals()
	
	var hex_set = map.get_hex_set()
	if hex_set == null: return
	
	# Group cells by ID to create optimized MultiMesh batches
	var groups: Dictionary = {} 
	for key in map.get_used_cells():
		var id = map.get_cell_item(key)
		if not groups.has(id): groups[id] = []
		groups[id].append(key)
		
	for tile_id in groups:
		_create_tile_batch(map, hex_set, tile_id, groups[tile_id])

func _create_tile_batch(map: HexMap, hex_set: HexSet, id: int, coords: Array) -> void:
	var data: HexTileData = hex_set.get_tile_data(id)
	if data == null or data.mesh == null: return
	
	var mm_instance = MultiMeshInstance3D.new()
	var mm = MultiMesh.new()
	
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = data.mesh
	mm.instance_count = coords.size()
	
	for i in range(coords.size()):
		var key = coords[i]
		var world_pos = map.key_to_world(key)
		mm.set_instance_transform(i, Transform3D(Basis(), world_pos))
		
		# NOTE: Entry point for Walkthrough Mode collision support
		if enable_collisions:
			_generate_cell_collision(map, key, data)
			
	mm_instance.multimesh = mm
	if data.material_override != null:
		mm_instance.material_override = data.material_override
		
	add_child(mm_instance)
	_multimesh_nodes[id] = mm_instance

func _generate_cell_collision(map: HexMap, key: Vector3i, data: HexTileData) -> void:
	# Implementation for StaticBody3D generation will go here.
	# This ensures units can "walk" on the environment in future modes.
	pass

func _clear_visuals() -> void:
	for node in _multimesh_nodes.values():
		if is_instance_valid(node): node.queue_free()
	_multimesh_nodes.clear()
	
	for body in _collision_nodes.values():
		if is_instance_valid(body): body.queue_free()
	_collision_nodes.clear()

```

---

### 3. Decomposing `hex_demo.gd`

With the renderer extracted, you can now strip `hex_demo.gd` of its low-level mesh builders.

**Logic to remove from `hex_demo.gd`:**

* `_build_hex_prism_mesh` : The renderer now uses meshes from your `HexTileData` resource instead of generating a prism manually.

* `_tile_meshes_by_key`, `_tile_materials_by_key`, and `_tile_labels_by_key` dictionaries: These are now internal to the `HexMapRenderer3D` or governed by `DemoConfig`.

**Ergonomic Benefits:**

* **Consistency:** Whether you are in the "Map Editor" tool or the final game, you drop in a `HexMapRenderer3D`, point it to a `HexMap`, and the visuals are guaranteed to be identical.
* **Clarity:** The demo script's `_on_hex_map_changed`  now only needs to tell UI components to refresh, while the renderer handles the 3D scene updates independently via the signal bus.

---

To further clean up `hex_demo.gd` and standardize the toolkit's visual language, we will extract the selection and pathfinding visualization logic into a specialized **HexHighlightManager**. This module will handle the high-contrast selection ring and the 3D path line rendering.

### 4. Implementation: `HexHighlightManager.gd`

This component acts as a visual listener. It doesn't perform calculations; it simply renders what the **HexSignalManager** or **HexPathfinder** broadcasts.

```gdscript
extends Node3D
class_name HexHighlightManager
## Purpose: Centralizes selection rings and path ribbon rendering.
## Principle: Reacts to signals to provide visual feedback for interaction and tactics.

@export var selection_color: Color = Color(1.0, 0.95, 0.2, 0.45)
@export var path_color: Color = Color(1.0, 0.93, 0.08, 0.95)

var _highlight_ring: MeshInstance3D = null
var _path_ribbon: MeshInstance3D = null

func _ready() -> void:
    _setup_visual_nodes()
    _connect_signals()

func _setup_visual_nodes() -> void:
    # Selection Ring
    _highlight_ring = MeshInstance3D.new()
    _highlight_ring.name = "SelectionRing"
    var ring_mat := StandardMaterial3D.new()
    ring_mat.albedo_color = selection_color
    ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _highlight_ring.material_override = ring_mat
    add_child(_highlight_ring)

    # Path Ribbon
    _path_ribbon = MeshInstance3D.new()
    _path_ribbon.name = "PathRibbon"
    var path_mat := StandardMaterial3D.new()
    path_mat.albedo_color = path_color
    path_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    path_mat.no_depth_test = true # Ergonomics: visible through terrain
    _path_ribbon.material_override = path_mat
    add_child(_path_ribbon)

func _connect_signals() -> void:
    if HexSignalManager.has_signal("hex_hovered"):
        HexSignalManager.hex_hovered.connect(_on_hex_hovered)
    
    if HexPathfinder.has_signal("path_result_ready"):
        HexPathfinder.path_result_ready.connect(_on_path_ready)

func _on_hex_hovered(key: Vector3i) -> void:
    var map = HexMapEditor.get_hex_map()
    if map == null or not map.has_cell(key):
        _highlight_ring.visible = false
        return
    
    _highlight_ring.visible = true
    _highlight_ring.global_position = map.key_to_world(key) + Vector3(0, 0.1, 0)
    # Note: Use the existing geometry logic to build the ring mesh if not already cached

func _on_path_ready(_start, _goal, result: Dictionary) -> void:
    var path: Array[Vector3i] = result.get("path", [])
    if path.is_empty():
        _path_ribbon.mesh = null
        return
    
    _update_path_mesh(path)

func _update_path_mesh(path_keys: Array[Vector3i]) -> void:
    # Logic extracted from hex_demo.gd _update_path_lines_mesh
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    # ... build the path ribbon using path_keys ...
    _path_ribbon.mesh = st.commit()

```

### 5. Cleaning up `hex_demo.gd`

With this manager in place, you can strip the following from your demo script:

* **Variables:** `_highlight_outline`, `_path_lines`, `_final_path_keys`.
* **Logic:** `_ensure_highlight_outline`, `_ensure_path_lines_node`, and `_update_path_lines_mesh`.
* **Signals:** The demo no longer needs to manually tell the path lines to update; the **HighlightManager** hears the same signal from the **Pathfinder** and reacts automatically.

### Workflow Ergonomics: Reusability

* **Consistency:** By using the same **HighlightManager** in your "Level Editor" and your "Game Tactics" scene, the path ribbon will look and behave exactly the same, ensuring the designer is testing what the player will eventually see.
* **Independent Toggles:** You can now easily add a "Hide UI/Highlights" feature just by toggling the `visible` property of this single node.

---

To move the toolkit toward a professional production workflow, we will now decompose the **Interaction and Camera Logic**. Currently, `hex_demo.gd` is burdened with raw input events, ray-plane intersections, and camera orbit math.

By moving these into a dedicated **HexInputController**, you can swap between "Editor Controls" and "Gameplay Controls" instantly while keeping your demo script focused on high-level UI states.

---

### 6. Implementation: `HexInputController.gd`

This component acts as the "Nervous System." It processes hardware input and translates it into grid-space intents via the `HexSignalManager`.

```gdscript
extends Node3D
class_name HexInputController
## Purpose: Processes raw hardware input into hex-space signals.
## Principle: Abstracts viewport raycasting and camera manipulation away from the demo.

@export var camera: Camera3D
@export var hex_map_renderer: HexMapRenderer3D

# state for camera panning/orbiting
var _is_orbiting: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
    # 1. Coordinate Raycasting
    if event is InputEventMouseMotion:
        var hovered_key = _get_hex_at_mouse(event.position)
        HexSignalManager.emit_hex_hovered(hovered_key)
        
    # 2. Selection Intent
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        var selected_key = _get_hex_at_mouse(event.position)
        HexSignalManager.emit_hex_selected(selected_key)

    # 3. Camera Controls (Decoupled from hex_demo.gd)
    _handle_camera_input(event)

func _get_hex_at_mouse(screen_pos: Vector2) -> Vector3i:
    if not camera: return Vector3i(-999, -999, -999)
    
    var ray_origin = camera.project_ray_origin(screen_pos)
    var ray_dir = camera.project_ray_normal(screen_pos)
    var hit = Plane.PLANE_XZ.intersects_ray(ray_origin, ray_dir)
    
    if hit:
        var map = HexMapEditor.get_hex_map()
        if map: return map.local_to_map(hit)
    return Vector3i(-999, -999, -999)

func _handle_camera_input(event: InputEvent) -> void:
    # Logic for Q/E Rotation and Z/X Zoom moved from hex_demo.gd
    if event.is_action_pressed("rotate_left"):
        CameraController.rotate_by_steps(camera, Vector3.ZERO, [], 1)
    elif event.is_action_pressed("rotate_right"):
        CameraController.rotate_by_steps(camera, Vector3.ZERO, [], -1)

```

---

### 7. Decomposing the Demo UI: `HexUIManager`

The massive `_refresh_controls_panel` function in `hex_demo.gd`  is a primary candidate for decomposition into **UI Sub-Modules**.

#### **A. Navigation HUD**

* **Responsibility:** Displays current Mode (Inspect, Paint, Tactics) and cycles them via [Tab].
* **Signals:** Listens to `HexSignalManager.interaction_mode_changed`.

#### **B. Metadata Inspector**

* **Responsibility:** Extracted from `_inspect_detail_lines`.
* **Ergonomics:** Displays the "Friendly" terrain data we built in the `HexTileData` resource.

#### **C. Tactical Toolset**

* **Responsibility:** Controls pathfinding animation replay and toggling the "Animate" flag.
* **Signals:** Emits `path_query_is_requested`.

---

### 8. Benefits of the New Structure

By separating **Input** and **UI Sub-Modules**, the toolkit becomes modular:

| Component | Can be used in... | Why? |
| --- | --- | --- |
| **HexInputController** | Editor & Game | Standardizes how mouse-clicks turn into hex selections. |
| **Metadata Inspector** | Inspect & Tactics | Provides consistent data feedback for designers and players. |
| **HexHighlightManager** | Visuals | One source of truth for "What is currently active." |

---

To finalize the decomposition of the toolkit, we will implement the **HexMapLogicService**. This module centralizes the "Simulation" state—specifically the pathfinding execution, the visual "touch" heatmap (which currently clutters the demo), and path animation logic.

### 9. Where Pathfinding Logic Lives

In the current architecture, the pathfinding is split across three distinct levels to maintain loose coupling:

* **The Algorithm (`HexPathfinder.gd`)**: This is a stateless singleton service. It owns the actual A* math but knows nothing about your map's visual state or unit data .
* **The State (`HexMapLogicService.gd` - New)**: This node (extracted from `hex_demo.gd`) will own the *results* of the pathfinding—such as the `_heat_touch_counts` (heatmap) and the `touch_sequence` used for animation .
* **The Bridge (`HexInputController.gd`)**: This module captures the  user's clicks and emits the `path_query_is_requested` signal that triggers the logic service.

---

### 10. Implementation: `HexMapLogicService.gd`

This component pulls the "thinking" out of the demo script. It listens for path requests, communicates with the pathfinding singleton, and manages the animation timer.

```gdscript
extends Node
class_name HexMapLogicService
## Purpose: Manages transient simulation state (Pathfinding results, Heatmaps).
## Principle: Acts as the "Logic Controller" decoupled from rendering and raw input.

# Extracted state from hex_demo.gd
var heat_touch_counts: Dictionary = {}
var path_is_animating: bool = false
var _path_animation_touch_sequence: Array[Vector3i] = []
var _path_animation_index: int = 0
var _path_animation_time_accum: float = 0.0

func _ready() -> void:
    if HexPathfinder.has_signal("path_result_ready"):
        HexPathfinder.path_result_ready.connect(_on_path_result_ready)

func _process(delta: float) -> void:
    if path_is_animating:
        _update_path_animation(delta)

func _on_path_result_ready(_start, _goal, result: Dictionary) -> void:
    # Logic extracted from hex_demo.gd
    heat_touch_counts.clear()
    _path_animation_touch_sequence = result["touch_sequence"]
    _path_animation_index = 0
    path_is_animating = true
    
    # Notify visuals/UI that new simulation data is available
    HexSignalManager.emit_simulation_updated()

func _update_path_animation(delta: float) -> void:
    # Logic extracted from the demo's _process loop
    _path_animation_time_accum += delta
    while _path_animation_time_accum >= 0.03: # Using constant from DemoConfig
        _path_animation_time_accum -= 0.03
        if _path_animation_index < _path_animation_touch_sequence.size():
            var key = _path_animation_touch_sequence[_path_animation_index]
            heat_touch_counts[key] = int(heat_touch_counts.get(key, 0)) + 1
            _path_animation_index += 1
        else:
            path_is_animating = false
            break

```

---

### 11. Workflow Decomposition Summary

With this final piece, the `hex_demo.gd` script is now reduced to a few lines of configuration.

| Module | Logic Extracted From Demo | Production Value |
| --- | --- | --- |
| **HexMapRenderer3D** | <br>`_build_demo_tiles`, `_create_multimesh` | High-performance batch rendering. |
| **HexHighlightManager** | <br>`_update_path_lines_mesh`, `_ensure_highlight` | Consistent visual feedback for selection/paths. |
| **HexInputController** | <br>`_unhandled_input`, `_pick_hex_key`  | Reusable raycasting/camera orbit logic. |
| **HexMapLogicService** | <br>`_heat_touch_counts`, `_path_is_animating` | Pathfinding state independent of the scene tree. |

---

### UI Ergonomics: The Tactics Inspector

Now that the logic is centralized, we can build a dedicated **Tactics Inspector UI** that simply reads from the `HexMapLogicService`.

* **Heatmap Toggle**: A checkbox that tells the `HexMapRenderer3D` to lerp tile colors based on the logic service's `heat_touch_counts`.
* **Animation Speed**: A slider to modify the `_path_animation_time_accum` threshold for faster/slower path previews.
