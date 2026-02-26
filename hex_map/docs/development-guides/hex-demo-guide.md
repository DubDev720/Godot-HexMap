To implement a high-quality selection tooltip while adhering to Godot's loose-coupling principles, we will structure this as a **compositional UI component**. It will act as a "listener" to your existing `HexMapEditor` and `HexPathfinder` singletons, reacting to signals rather than being hard-coded into the demo logic.

Here is the itemized functional breakdown for the **Selection Tooltip & Info HUD**.

### 1. Dynamic Selection Tooltip (Cursor-Follower)

This is a small, high-density UI element that provides immediate feedback at the "point of contact" with the grid.

* **Loose Coupling:** It connects to a `cell_hovered(key: Vector3i)` signal from your interaction handler.
* **Ergonomics:** It utilizes a `PanelContainer` with "Mouse Filter" set to `Ignore` so it never intercepts clicks intended for tiles.
* **Data Points:**
* **Coordinates:** Cleanly formatted $Q, R$ coordinates (internal $S$ is hidden to reduce visual noise for designers).
* **Terrain Label:** Displays the metadata name (e.g., "Standard Tile" or "Obstacle") based on the `cell_item` ID.
* **Status Icons:** Small icons for "Impassable" or "Slow" status, preventing the need for dense text.

### 2. Contextual Data HUD (Screen-Anchored)

While the tooltip follows the mouse, a static HUD in a corner (e.g., Bottom-Left) provides deeper analysis of the currently **selected** hex.

* **Interaction Logic:** Updates only when a hex is clicked (Selected), allowing the designer to move their mouse away to adjust settings while keeping the data visible.
* **Ergonomics:** Uses a "Details" fold-out style to hide advanced math (Cube coordinates, index IDs) by default, showing only what is relevant to level design.
* **Safety:** Utilizes `is_instance_valid()` and signal-checking to ensure that if the `HexMap` singleton is reconfigured, the HUD clears its state rather than showing stale data.

### 3. Logic Feedback (Algorithm Integration)

This surfaces the "why" behind the pathfinding and range calculations.

* **Path Cost Display:** When in "Tactics Mode," hovering a tile shows the cumulative movement cost from the current path "Start".
* **Reachability Status:** If a designer hovers a tile during a pathfinding query, the HUD indicates if the cell is "Unreachable" due to an obstacle or range limit.

### 4. Implementation Specification

To follow your singleton compositional structuring, the system will be built as follows:

| Component | Role | Communication Method |
| --- | --- | --- |
| **HexInteractionHandler** | Logic for raycasting mouse to hex. | Emits `hex_hovered(key)` and `hex_selected(key)`. |
| **SelectionTooltip** | Independent UI Scene. | Connects to `HexInteractionHandler.hex_hovered`. |
| **SelectionHUD** | Independent UI Scene. | Connects to `HexInteractionHandler.hex_selected`. |

**Signal Handling Strategy:**
Each UI component will use a "Safe Connect" pattern:

```gdscript
func _ready():
    if InteractionBus.has_signal("hex_hovered"):
        InteractionBus.hex_hovered.connect(_on_hex_hovered)
    else:
        push_warning("SelectionTooltip: InteractionBus signal 'hex_hovered' missing.")

```

This ensures that if you remove the interaction system for a "Cinematic Mode," the UI components simply go dormant and emit a debug warning without crashing the scene.

To implement the selection tooltip and HUD system while following your architectural guidelines, we will establish the **HexSignalManager** as a global singleton (autoload). This acts as a central "Signal Bus," decoupling the high-level input logic from the UI display components.

### 1. HexSignalManager (Singleton Signal Bus)

This node exists solely to facilitate communication. By keeping it stateless, we ensure that UI elements only care about the *event* of hovering or selection, not the math behind it.

```gdscript
extends Node
## Purpose: Global Signal Bus for hex grid interactions.
## Principle: Singleton compositional structuring for loose coupling.

signal hex_hovered(key: Vector3i)
signal hex_selected(key: Vector3i)
signal interaction_mode_changed(mode: int) # e.g., INSPECT, PAINT, TACTICS

func emit_hex_hovered(key: Vector3i) -> void:
	hex_hovered.emit(key)

func emit_hex_selected(key: Vector3i) -> void:
	hex_selected.emit(key)

```

---

### 2. HexInteractionHandler (Input Logic)

This component lives in your main scene (e.g., inside `HexDemo`). It performs the heavy lifting of raycasting and coordinate conversion , then passes the result to the singleton.

```gdscript
extends Node3D

## Purpose: Maps screen input to hex keys and broadcasts via HexSignalManager.

@export var hex_map_node: Node # Reference to your HexMap container
var _last_hovered_key: Vector3i = Vector3i(-999, -999, -999)

func _process(_delta: float) -> void:
	var current_key = _get_key_under_mouse()
	if current_key != _last_hovered_key:
		_last_hovered_key = current_key
		HexSignalManager.emit_hex_hovered(current_key)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var selected_key = _get_key_under_mouse()
		HexSignalManager.emit_hex_selected(selected_key)

func _get_key_under_mouse() -> Vector3i:
	# [cite_start]Implementation uses your existing ray-to-hex logic [cite: 2994-2998]
	var mouse_pos = get_viewport().get_mouse_position()
	var camera = get_viewport().get_camera_3d()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)

	var hit = Plane.PLANE_XZ.intersects_ray(ray_origin, ray_dir)
	if hit:
		# [cite_start]Use your existing HexMap.local_to_map [cite: 3027]
		return HexMapEditor.get_hex_map().local_to_map(hit)
	return Vector3i(-999, -999, -999)

```

---

### 3. SmartSelectionTooltip (UI Component)

This is an independent scene (`SelectionTooltip.tscn`). It is "safe" because it checks for the existence of the Signal Bus before connecting.

```gdscript
extends PanelContainer
## Purpose: Floating tooltip that follows the mouse with hex metadata.

@onready var label: Label = $MarginContainer/VBoxContainer/TerrainLabel
@onready var coord_label: Label = $MarginContainer/VBoxContainer/CoordLabel

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE # Ergonomics: don't block clicks
	visible = false

	if HexSignalManager.has_signal("hex_hovered"):
		HexSignalManager.hex_hovered.connect(_on_hex_hovered)
	else:
		push_error("SelectionTooltip: HexSignalManager 'hex_hovered' signal missing.")

func _process(_delta: float) -> void:
	if visible:
		# Ergonomics: Offset from cursor so it doesn't cover the hex
		global_position = get_global_mouse_position() + Vector2(15, 15)

func _on_hex_hovered(key: Vector3i) -> void:
	var map = HexMapEditor.get_hex_map()
	[cite_start]if map == null or not map.has_cell(key)[cite: 3024]:
		visible = false
		return

	visible = true
	# [cite_start]Ergonomics: Surface designer-friendly data (Axial Q, R) [cite: 3008]
	coord_label.text = "Hex: %d, %d" % [key.x, key.y]

	# [cite_start]Metadata retrieval [cite: 3008]
	if map.is_cell_obstacle(key):
		label.text = "Obstacle"
		modulate = Color.TOMATO
	else:
		label.text = "Standard Tile"
		modulate = Color.WHITE

```

---

### UI Component Itemization:

* **Decoupled Signals:** Components do not reference each other; they only reference `HexSignalManager`.
* **Designer-First Display:** Raw Cube coordinates (S) and internal IDs are filtered out in favor of $Q, R$ labels.

* **Ergonomic Hover:** The tooltip uses `MOUSE_FILTER_IGNORE` to ensure the level designer can still click the til "under" the tooltip.x
* **Debug Safety:** The `push_error` provides developers with immediate feedback if the bus is broken without causing a hard crash for the designer.

Would you like me to provide the **Contextual Data HUD** (the screen-anchored panel) script to handle the more detailed "Selection" view?
