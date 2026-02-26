To evolve your toolkit from hard-coded strings to a robust, designer-friendly workflow, we will implement the **HexTileData** and **HexSet** resource system. This moves your map data into Godot's native Resource pipeline, allowing level designers to swap terrain types and metadata visually in the Inspector.

---

## 1. HexTileData (Single Asset Metadata)

Create `hex_tile_data.gd`. This represents one specific type of hex (e.g., "Deep Water" or "Grass").

```gdscript
class_name HexTileData
extends Resource
## Purpose: Defines metadata and visual assets for a single hex type.

@export_group("Visuals")
[cite_start]@export var mesh: Mesh [cite: 3009]
[cite_start]@export var material_override: Material [cite: 2988]

@export_group("Tactical Data")
@export var terrain_name: String = "Plains"
@export var movement_cost: int = 1
[cite_start]@export var is_obstacle: bool = false [cite: 3024]

@export_group("Advanced")
@export var metadata: Dictionary = {}

```

## 2. HexSet (The Map Palette)

Create `hex_set.gd`. This is a library resource, similar to a `TileSet`, that maps integer IDs to your `HexTileData` resources.

```gdscript
class_name HexSet
extends Resource
## Purpose: A collection of HexTileData used as a palette for the HexMap.

## Maps ID (int) to HexTileData (Resource)
@export var tile_library: Dictionary = {}

func get_tile_data(id: int) -> HexTileData:
	return tile_library.get(id, null)

func get_ids() -> Array:
	return tile_library.keys()

```

## 3. Integration with HexMap.gd

We need to update your `HexMap` to store these data objects instead of just a boolean in the `_used_cells` dictionary.

### Updated HexMap Properties

```gdscript
# Inside hex_map.gd
var _hex_set: HexSet = null
# Key: Vector3i, Value: int (the ID from the HexSet)
var _cell_data_ids: Dictionary = {} 

```

### Updated Cell Mutation Logic

Replace your current `set_cell_item` with a version that tracks the ID:

```gdscript
func set_cell_item(position: Vector3i, item_id: int, _orientation: int = 0) -> void:
    [cite_start]if not is_key_inside_radius(position): [cite: 3024]
        return
        
    if item_id == INVALID_CELL_ITEM:
        _used_cells.erase(position)
        _cell_data_ids.erase(position)
        return
        
    _used_cells[position] = true
    _cell_data_ids[position] = item_id
    
    # Broadcast change via Signal Manager for UI updates
    HexSignalManager.emit_hex_map_changed(self)

```

---

## 4. UI Ergonomics: The Selection Tooltip (Updated)

Now that we have real metadata, we can update the **SmartSelectionTooltip** you just built to show the actual terrain name and cost.

```gdscript
# Inside selection_tooltip.gd
func _on_hex_hovered(key: Vector3i) -> void:
    var map = HexMapEditor.get_hex_map()
    if map == null or not map.has_cell(key):
        visible = false
        return
    
    var tile_id = map.get_cell_item(key)
    var hex_set = map.get_hex_set() # You'll need a getter for this
    var data = hex_set.get_tile_data(tile_id)
    
    if data:
        label.text = data.terrain_name
        cost_label.text = "Cost: %d" % data.movement_cost
        modulate = Color.TOMATO if data.is_obstacle else Color.WHITE
    visible = true

```

---

### Implementation Itemization

* **Asset Decoupling**: Designers can now create a `.tres` file for "Snowy Mountain" and "Lava" without touching a single line of GDScript.

* **Inspector Integration**: The `HexSet` dictionary allows designers to drag-and-drop `HexTileData` resources into slots directly in the Godot Editor.
* **Signal Safety**: By emitting `hex_map_changed` after a metadata update, the **Contextual HUD** will automatically refresh to show the new movement cost or terrain type.

To implement a production-grade rendering system for your toolkit, we will integrate **MultiMeshInstance3D** logic into `hex_map.gd`. This strategy significantly reduces draw calls by batching all hexes of the same type into a single render operation .

---

### 5. MultiMesh Architecture for HexMap

The `HexMap` will now manage a collection of `MultiMeshInstance3D` nodes, one for each unique `HexTileData` ID defined in your `HexSet`.

#### Updated HexMap Implementation

Add these properties and logic to your existing `hex_map.gd`:

```gdscript
# Inside hex_map.gd
## Map of tile_id to the specific MultiMeshInstance3D rendering that group
var _multimesh_nodes: Dictionary = {}

## Regenerates the visual representation based on current _cell_data_ids
func update_visuals(parent_node: Node3D) -> void:
	_clear_multimesh_nodes()
	
	# Group current map coordinates by their tile ID
	var groups: Dictionary = {} # tile_id: Array[Vector3i]
	for key in _cell_data_ids:
		var id = _cell_data_ids[key]
		if not groups.has(id):
			groups[id] = []
		groups[id].append(key)
		
	for tile_id in groups:
		_create_multimesh_for_tile(tile_id, groups[tile_id], parent_node)

func _create_multimesh_for_tile(id: int, coordinates: Array, parent: Node3D) -> void:
	var data: HexTileData = _hex_set.get_tile_data(id)
	if not data or not data.mesh: return
	
	var mm_instance = MultiMeshInstance3D.new()
	var mm = MultiMesh.new()
	
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = data.mesh
	mm.instance_count = coordinates.size()
	
	for i in range(coordinates.size()):
		var key = coordinates[i]
		# [cite_start]Use your existing hex_to_world logic [cite: 3057-3061]
		var world_pos = key_to_world(key)
		var basis = Basis() # Add rotation logic here if needed
		mm.set_instance_transform(i, Transform3D(basis, world_pos))
		
	mm_instance.multimesh = mm
	mm_instance.material_override = data.material_override
	parent.add_child(mm_instance)
	_multimesh_nodes[id] = mm_instance

func _clear_multimesh_nodes() -> void:
	for node in _multimesh_nodes.values():
		node.queue_free()
	_multimesh_nodes.clear()

```

---

### 6. Designer Ergonomics: Visual Feedback

By using MultiMeshes, the level designer gains high-performance viewport updates even on large maps.

* **Batched Updates:** Instead of rebuilding the entire map on every click, you can flag the `HexMap` as "dirty" and call `update_visuals` at the end of a frame or paint stroke to maintain editor responsiveness.

* **Asset Swapping:** If a designer changes a `HexTileData` resource (e.g., changing a Grass material to Sand), the system automatically updates all corresponding instances because the `MultiMesh` references that specific resource.

---

### Implementation Checklist

* **Mesh Orientation:** Ensure the meshes in your `HexSet` resources match the orientation (Pointy vs Flat) defined in your `HexLib` to avoid gaps.

* **Origin Alignment:** Meshes should be centered at `(0, 0, 0)` in their source file so that `hex_to_world` correctly positions them on the grid .

* **Collision Batching:** While MultiMesh handles visuals, you should still create individual `StaticBody3D` nodes or a batched `ArrayMesh` for physics if high-precision collision is required .
