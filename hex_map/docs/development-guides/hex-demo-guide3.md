To implement the **Paint Mode UI Toolbar**, we need to create a visual bridge between the `HexSet` (your library of hex types) and the active viewport. This toolbar will serve as the primary workstation for a level designer.

Following your architectural guidelines, this component will be a standalone UI scene that interacts with the `HexMapEditor` and `HexSignalManager` to apply mutations.

---

## 1. The Paint Mode Toolbar (UI Component)

This panel is designed to be docked or displayed at the top of the screen. It itemizes every asset in your `HexSet` as a selectable button.

### Functional Breakdown:

* **Asset Palette**: Dynamically generates a grid of buttons. Each button represents a `HexTileData` entry from the current `HexSet`.
* 
**Brush Selection**: Toggles between **Single Cell** and **Line Tool** (leveraging `hex_linedraw`) .


* **Active Preview**: Displays the name and icon of the tile currently "on the brush."

### Implementation (GDScript):

```gdscript
extends PanelContainer
## Purpose: Designer palette for selecting and painting hex assets.

@onready var grid_container: GridContainer = $Margin/VBox/Scroll/Grid
@onready var brush_preview: Label = $Margin/VBox/Status/ActiveBrushName

var _selected_tile_id: int = 0

func _ready() -> void:
    # Safe connect to the map change signal to refresh the palette if the set changes
    if HexSignalManager.has_signal("hex_map_changed"):
        HexSignalManager.hex_map_changed.connect(_on_map_changed)
    _populate_palette()

func _populate_palette() -> void:
    # Clear existing buttons
    for child in grid_container.get_children():
        child.queue_free()
    
    var map = HexMapEditor.get_hex_map()
    if not map or not map._hex_set: return
    
    var hex_set: HexSet = map._hex_set
    for id in hex_set.get_ids():
        var data = hex_set.get_tile_data(id)
        var btn = Button.new()
        btn.text = data.terrain_name
        btn.custom_minimum_size = Vector2(64, 64)
        btn.pressed.connect(_on_tile_selected.bind(id, data))
        grid_container.add_child(btn)

func _on_tile_selected(id: int, data: HexTileData) -> void:
    _selected_tile_id = id
    brush_preview.text = "Brush: " + data.terrain_name
    # Update the editor singleton state
    HexMapEditor.set_edit_brush(HexMapEditor.EDIT_BRUSH_ADD_TILE)
    # We could extend HexMapEditor to store the current 'TileID' as well
    HexMapEditor.current_paint_id = id 

func _on_map_changed(_map) -> void:
    _populate_palette()

```

---

## 2. Integrated "Line Tool" Logic

To make the toolbar ergonomic, we implement the **Line Tool** using your existing `HexLib.hex_linedraw` function. This allows designers to "click-drag" or "click-click" to create long walls or paths instantly .

### Ergonomic Implementation:

1. **Start Point**: Designer clicks a hex in "Line Mode."
2. **Visual Ghosting**: As the designer moves the mouse, the `HexSignalManager` emits `hex_hovered`. The UI calculates the line between the start and current hover.


3. 
**End Point**: Second click calls `_hex_map.set_cell_item` for every key returned by the line algorithm.



---

## 3. Designer Interface Checklist

* **Visual Icons**: In a production version, replace the text on buttons with a `SubViewport` render of the hex's `mesh` and `material_override`.
* **Hotkey Support**: Ergonomically, designers should be able to use `1`, `2`, `3` to swap brushes or `B` for Paint and `E` for Erase.
* 
**Batch Confirmation**: When painting a line, the `HexMap.update_visuals()` should be called once at the end of the operation to minimize `MultiMesh` buffer updates.

---

To keep this ergonomic for a designer, we will integrate this into the `update_visuals` logic so that collisions are generated automatically as tiles are painted.

### 4. Collision Generation Strategy

While visuals are batched in a `MultiMeshInstance3D`, collisions work best as individual `StaticBody3D` nodes for precision or a single combined `ArrayMesh` collider for performance.

For a walkthrough experience, we will use the **Hex Prism Collider** approach.

#### Updated HexMap Logic

Add this method to your `hex_map.gd` to handle the generation of collision shapes based on the `HexTileData` resource.

```gdscript
# Inside hex_map.gd

## Map to keep track of collision bodies for cleanup
var _collision_bodies: Dictionary = {} # Vector3i: StaticBody3D

func _update_collision_for_cell(key: Vector3i, tile_id: int) -> void:
    # 1. Clean up old collision if it exists
    if _collision_bodies.has(key):
        _collision_bodies[key].queue_free()
        _collision_bodies.erase(key)
        
    # 2. Skip if it's an empty cell
    if tile_id == INVALID_CELL_ITEM: return
    
    var data: HexTileData = _hex_set.get_tile_data(tile_id)
    if not data: return

    # 3. Create a new StaticBody3D for the hex
    var body := StaticBody3D.new()
    body.position = key_to_world(key)
    
    var collision_shape := CollisionShape3D.new()
    
    # Ergonomics: If the tile data has a custom shape, use it. 
    # Otherwise, default to a standard hex prism.
    if data.metadata.has("custom_collision"):
        collision_shape.shape = data.metadata["custom_collision"]
    else:
        # [cite_start]Generate a simple hex prism shape for standard traversal [cite: 37]
        collision_shape.shape = _generate_hex_collision_shape()
        
    body.add_child(collision_shape)
    add_child(body)
    _collision_bodies[key] = body

func _generate_hex_collision_shape() -> ConvexPolygonShape3D:
    var shape := ConvexPolygonShape3D.new()
    # [cite_start]Use corners from HexLib to define the collision boundary [cite: 3009-3012, 3041]
    var points := PackedVector3Array()
    var corners = HexLib.polygon_corners(_layout, HexLib.Hex.new(0,0,0))
    
    for p in corners:
        points.append(Vector3(p.x, 0.5, p.y)) # Top face
        points.append(Vector3(p.x, -0.5, p.y)) # Bottom face
        
    shape.set_points(points)
    return shape

```

---

### 5. Designer Usability: The "Walkthrough" Flag

To follow your intent of making this an "easy adjustment later," we will add a global toggle to the `HexMapEditor` singleton.

* **Editor Toggle**: A "Enable Collision" checkbox in the UI.
* **Performance**: When disabled, the `_collision_bodies` are cleared, and the generation logic is skipped during painting.
* 
**Raycasting**: This ensures that even without physics, your `_pick_hex_key_from_screen` can still hit the `Plane.PLANE_XZ` or the actual geometry if preferred .



---

###	 Final UI Implementation Itemization

To wrap up this phase, the **Main Toolbar** should now include these final ergonomic controls:

* **Grid Settings**:
* **Show Grid**: Toggles the visual helper lines.
* **Enable Collisions**: Toggles the `StaticBody3D` generation we just implemented.


* **Viewport Feedback**:
* **Walk Mode**: A specialized camera mode (similar to standard FPS controls) that utilizes the generated collisions to let the designer "walk" through the hex map they just built.
