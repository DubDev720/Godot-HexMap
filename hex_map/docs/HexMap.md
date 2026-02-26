# **Engineering Specification and Implementation Framework for a Multi-Level Hexagonal Grid System in Godot 4.6.1**

The development of a sophisticated hexagonal grid system within the Godot 4.6.1 environment necessitates a deep synthesis of hexagonal geometric theory and the engine's advanced plugin architecture. While Godot provides a native 2D TileMap system, its inherent optimizations for square and rectangular grids do not translate directly to the complexities of 3D multi-level hexagonal environments. This report provides a comprehensive architectural blueprint for a custom system designed to facilitate the creation, editing, and management of multi-floor hexagonal maps, utilizing the seminal work of Red Blob Games as the mathematical foundation. The focus is directed toward creating a robust, scalable toolset that functions as a professional-grade editor extension, allowing for discrete vertical stacking of combat environments while maintaining high performance through modern rendering techniques.

## **Geometric Foundations and Coordinate Systems**

The efficacy of a hexagonal grid system is fundamentally determined by its coordinate representation. For a system intended to support complex 3D operations, including pathfinding, line-of-sight calculations, and vertical stacking, the cube coordinate system is identified as the most mathematically elegant and computationally efficient choice.1 This system treats the hexagonal grid as a slice of a 3D cube grid, where the coordinates ![][image1], ![][image2], and ![][image3] are constrained by the identity ![][image4].1

### **Primary Orientations and Metric Calculations**

In the Godot 4.6.1 3D environment, hexagons are typically oriented on the ![][image5] plane, with the ![][image6] axis representing vertical elevation or floor levels.4 The choice between pointy-top and flat-top orientations dictates the placement logic and spacing constants required for the mesh library.

| Orientation | Primary Axis Alignment | Horizontal Spacing | Vertical (Depth) Spacing | Vertex Angles |
| :---- | :---- | :---- | :---- | :---- |
| **Pointy-Top** | Vertical (Z-axis) | ![][image7] | ![][image8] | ![][image9] |
| **Flat-Top** | Horizontal (X-axis) | ![][image8] | ![][image7] | ![][image10] |

The variable ![][image11] refers to the outer radius of the hexagon—the distance from the center to any corner.1 In Godot, the standard unit is often treated as one meter, and setting ![][image12] provides a consistent baseline for 3D asset creation.4 For pointy-top hexagons, which are common in tactical combat maps, the width of a single cell is ![][image13] units, while the height is 2 units.1

### **Coordinate Transformation Logic**

To ensure the system remains robust across different gameplay requirements, the implementation must utilize axial coordinates for storage while converting to cube coordinates for mathematical operations.1 Axial coordinates represent the grid using only two values ![][image14], as the third component ![][image3] can always be derived as ![][image15].1 This reduces memory consumption by ![][image16] in the primary map data structure.2

The transformation from hex coordinates to world space in Godot’s 3D engine is performed using a matrix multiplication approach, where the layout object stores the orientation-specific constants.7 For a pointy-top layout on the ![][image5] plane, the conversion from axial ![][image14] to world ![][image17] is defined by: ![][image18] ![][image19] This mapping ensures that every cell is perfectly aligned without the "zigzag" logic required by offset coordinate systems, which are prone to complex edge cases in 3D pathfinding.6

## **Architectural Design of the HexMap3D System**

Building a custom system that mirrors Godot's TileMap functionality requires a modular architecture composed of custom nodes, resources, and editor-side logic. The core of this system is the HexMap3D node, which serves as the container for the map data and the rendering logic.9

### **Node Hierarchy and Responsibility**

The system is structured to separate the visual representation from the underlying data. This separation allows for multi-level editing and the potential for procedural generation without tightly coupling the map to a specific scene structure.9

| Class Name | Inheritance | Primary Responsibility |
| :---- | :---- | :---- |
| HexMap3D | Node3D | Main controller; manages coordinate-to-world mapping and layer visibility. |
| HexSet | Resource | Custom library that maps integer IDs to 3D mesh resources and metadata. |
| HexLayer | RefCounted | Represents a single floor; stores a dictionary of axial coordinates to tile data. |
| HexEditorPlugin | EditorPlugin | Implements the viewport UI, brush tools, and Undo/Redo integration. |

Unlike the native GridMap, which is optimized for rectangular cells, the HexMap3D node must handle the fractional rounding required for hexagonal selection.1 The use of Vector3i for axial storage ![][image20] is mandatory to ensure integer precision across the potentially large coordinate space.10

### **Rendering Optimization via MultiMeshInstance3D**

In a combat map with multiple levels and structures, the number of individual mesh instances can quickly become a bottleneck for Godot's rendering pipeline.14 To mitigate this, the HexMap3D system utilizes MultiMeshInstance3D for batching.16 Each unique tile type defined in the HexSet is assigned to a specific MultiMeshInstance3D node. When the map is edited, the system updates the instance transforms within the relevant MultiMesh, significantly reducing draw calls compared to using individual MeshInstance3D nodes.14

For multi-level visibility, the system can assign each MultiMesh or individual instances to specific visual\_layers. Godot 4.6.1 allows for granular control over cull masks, which the custom editor uses to toggle the visibility of floors above or below the current edit level.19

## **Data Persistence and Multi-Floor Management**

A robust map system requires a serialization format that can handle sparse data across many floors. tactical maps often feature high-density areas (buildings) surrounded by low-density terrain.8

### **Sparse Dictionary Storage**

The underlying data structure for the map is a Dictionary where the key is a Vector3i ![][image21] and the value is a custom HexTileData resource or a simple integer ID.9 The ![][image22] component represents the discrete floor index. This approach is superior to a 3D array because it only consumes memory for cells that actually contain a tile, which is essential for maps with high verticality but sparse occupancy.9

The HexMap3D node exposes methods to the editor for querying this data:

* set\_cell(q, r, y, tile\_id): Places a tile and updates the MultiMesh batch.  
* get\_cell(q, r, y): Returns the tile ID at the given location.  
* get\_neighbors(q, r, y): Returns the IDs of the six adjacent hexes on the same floor.

### **Vertical Stacking and Floor Height**

The distance between levels is defined by a floor\_height constant in the HexMap3D properties.25 A tile at level ![][image23] is positioned at a world height of ![][image24]. For multi-level structures, it is often necessary to align tiles on different floors (e.g., walls that line up vertically). The system handles this by maintaining a global vertical offset that applies to the 3D gizmo and the raycasting logic in the editor.9

## **The Custom Editor Plugin Framework**

The user experience of the hex system is defined by its editor integration. To function similarly to Godot’s TileMap, the plugin must provide a painting interface directly in the 3D viewport, a tile palette dock, and a floor management UI.26

### **Viewport Interaction and Raycasting**

The plugin intercepts mouse events in the 3D viewport through the \_forward\_3d\_gui\_input method.29 When the user attempts to paint, the system generates a ray from the editor camera.30 This ray is intersected with a virtual plane at the current edit\_floor height.25

Once an intersection point is found in world space, it must be converted back into hex coordinates. This is the inverse of the hex-to-pixel operation.7 The resulting fractional hex coordinate is then rounded using the cube\_round algorithm to find the correct axial coordinate for the tile placement.1

GDScript

\# Cube Rounding Algorithm Implementation Logic  
func hex\_round(fractional\_hex: Vector3) \-\> Vector3i:  
    var q \= round(fractional\_hex.x)  
    var r \= round(fractional\_hex.y)  
    var s \= round(fractional\_hex.z)

    var q\_diff \= abs(q \- fractional\_hex.x)  
    var r\_diff \= abs(r \- fractional\_hex.y)  
    var s\_diff \= abs(s \- fractional\_hex.z)

    if q\_diff \> r\_diff and q\_diff \> s\_diff:  
        q \= \-r \- s  
    elif r\_diff \> s\_diff:  
        r \= \-q \- s  
    else:  
        s \= \-q \- r  
    return Vector3i(q, r, s)

This algorithm ensures that the selection remains stable even at the exact boundaries between hexes, where floating-point errors would otherwise cause flickering or incorrect placements.1

### **Painting Tools and Bresenham Interpolation**

To match the "Mind the Gap" improvement in Godot 4.6.1, the hex editor implements a hexagonal version of the Bresenham line algorithm.27 When the user drags the mouse quickly across the viewport, the plugin calculates the hex distance between the previous mouse position and the current one.1 It then samples points along a 3D line between these two hexes and fills in the gaps, ensuring a continuous line of tiles is painted.1

### **Undo/Redo Integration**

A critical requirement for any robust editor tool is integration with Godot's EditorUndoRedoManager.33 Every painting or erasing action is wrapped in an "UndoRedo action." This action stores the axial coordinates and the IDs of the tiles before and after the edit.33 When an undo is performed, the system calls the set\_cell method with the previous IDs, and the MultiMesh batch is updated to reflect the change.

## **Multi-Level Visualization and Display Settings**

Tactical 3D maps with multiple floors present a visualization challenge: how can a designer work on a ground floor when a roof and three upper levels are in the way? The hex system implements a "Floor Management" suite modeled after the native GridMap editor.25

### **Floor Indicator and Edit Plane**

A specialized toolbar is added to the 3D viewport containing a "Floor Indicator".25 This UI element shows the current ![][image6] level where tiles will be placed.

* **Up/Down Arrows:** Allow the user to quickly navigate between levels.25  
* **Active Plane Gizmo:** A semi-transparent hexagonal grid is rendered at the current floor's height to show exactly where tiles will snap.25  
* **Shift \+ Mouse Wheel:** A shortcut to rapidly cycle through floor levels, which is a standard workflow for building multi-story structures.25

### **Visibility Toggling (Clipping)**

The editor provides toggles for "Show Above" and "Show Below".25

* **Show Above:** When disabled, all tiles on floors higher than the current edit floor are hidden. This allows the designer to see "inside" buildings.25  
* **Show Below:** When disabled, it hides floors below the current one, reducing visual clutter and focus on the current layer.25  
* **Clip Above (Ctrl+K):** A standard shortcut that toggles whether geometry above the edit plane is rendered.25

Godot 4.6.1's docking system allows these controls to be moved to a floating window or docked alongside the Inspector, giving designers more flexibility in their workspace layout.27

## **Advanced Physics and Collision for Multi-Level Grids**

For a combat map system, the collision data must be as precise as the visual representation. The system generates collision shapes based on the metadata in the HexSet resource.36

### **Mesh-to-Collision Workflow**

Each tile in the HexSet can define its own collision behavior. For a multi-level hex system, three types of collision are typically supported:

| Collision Type | Implementation | Use Case |
| :---- | :---- | :---- |
| **Convex Polygon** | Simplified hex prism | Standard floor/wall blocks; high performance for physics.37 |
| **Trimesh** | Exact mesh geometry | Complex architectural features like stairs or decorative arches.36 |
| **Polygon3D** | Dynamic polygon extrusion | Custom-shaped obstacles or partial hex barriers.39 |

When a tile is placed, the HexMap3D node can automatically instantiate a StaticBody3D with the appropriate shape.37 For performance, these bodies can be pooled or batched if the physics engine supports it. In Godot 4.6.1, the integration of Jolt physics by default provides a significant boost to the handling of complex 3D collision environments.40

### **Raycasting for Pathfinding and Selection**

Gameplay logic often requires finding the hex under the player or the target of a mouse click. The HexMap3D node provides a high-level raycast\_to\_hex method that performs a physics raycast, identifies the collider, and uses its world position to calculate the hex axial coordinates ![][image21].30 This is the primary method used for unit movement and targeting in combat scenarios.

## **Instructions for the Coding Agent: Phase-by-Phase Implementation**

The following roadmap provides a structured guide for building the system, ensuring that the Red Blob Games library is integrated as the mathematical engine for all Godot-specific features.

### **Phase 1: The Core Mathematical Library**

The agent must first implement a GDScript or C\# library that contains the Hex, FractionalHex, and Layout classes from the Red Blob Games documentation.1

* **Coordinate Storage:** Use Vector2i for axial and Vector3i for cube coordinates to maintain integer precision.  
* **Metric Constants:** Define the ![][image13] and ![][image25] constants for both pointy and flat orientations.  
* **Rounding Logic:** Implement the cube\_round function with the ![][image4] constraint check.1  
* **Mapping:** Implement hex\_to\_world and world\_to\_hex functions for the ![][image5] plane with a ![][image6] offset for levels.4

### **Phase 2: Map Data and Rendering**

The agent develops the HexMap3D node and the HexSet resource.

* **Resource Design:** Create a HexSet resource that stores a dictionary of int: TileData, where TileData includes a Mesh and a CollisionShape.  
* **Data Storage:** Implement a Dictionary in HexMap3D to store the axial coordinates and tile IDs.9  
* **Batch Rendering:** Implement a system that dynamically creates MultiMeshInstance3D nodes for each unique tile ID in the HexSet.16  
* **Level Support:** Add a floor\_height property and logic to position MultiMesh instances at the correct vertical offset.

### **Phase 3: The Editor Plugin Interface**

The agent creates the HexEditorPlugin to provide the editing tools.

* **Plugin Boilerplate:** Implement \_enter\_tree to register the plugin and \_handles to identify HexMap3D nodes.29  
* **Viewport Input:** Implement \_forward\_3d\_gui\_input to handle click-to-paint logic using raycasting to the active floor plane.29  
* **The Palette Dock:** Create a custom UI dock that displays the tiles from the selected HexSet and allows the user to select the "current brush."  
* **Undo/Redo:** Wrap every set\_cell call in an EditorUndoRedoManager action.33

### **Phase 4: Multi-Level Optimization and Polish**

The agent adds the advanced verticality and performance features.

* **Floor Indicator:** Add a viewport UI that tracks and modifies the current edit level.25  
* **Visibility Logic:** Implement a system to toggle the visible property of MultiMesh nodes or set their transparency based on the "Show Above/Below" settings.20  
* **Gizmos:** Implement a custom EditorNode3DGizmo to show the hexagonal grid plane and handle tile rotation (increments of ![][image26] degrees).27  
* **Auto-Tiling:** (Optional) Implement a basic neighbor-checking system that automatically selects "wall" or "edge" tiles based on adjacent occupancy.9

## **Integration with Gameplay Systems**

Once the editor tools are complete, the HexMap3D system provides a foundation for high-level gameplay features such as pathfinding and line-of-sight.8

### **Hexagonal A\* Pathfinding**

The axial coordinates allow for a simple integration with Godot's AStar3D class.

* **Graph Construction:** The system iterates through the map dictionary and adds each hex as a point in the AStar graph.  
* **Neighbor Weighting:** Connections are added between all six adjacent hexes on the same floor, and vertical connections are added where "stairs" or "ramp" tiles are present.23  
* **Cost Calculation:** The system can use custom tile data (e.g., "difficult terrain") to adjust the weights of specific hexes.23

### **Multi-Level Line of Sight**

Tactical combat requires checking if a unit on Floor 1 can see a unit on Floor 0\.43

* **Hex Raycasting:** The system uses the Red Blob Games line\_drawing algorithm, but extends it into 3D. It samples points along a 3D line between ![][image27] and ![][image28].1  
* **Occlusion Query:** For each sampled point, it checks the map dictionary for any hex that contains an "opaque" tile. If an opaque tile is found between the two units, the LOS is blocked.1

## **Performance Considerations for Godot 4.6.1**

The move to a custom hex system must not come at the cost of the engine's stability or performance. Godot 4.6.1 introduces several features that should be leveraged during implementation.27

* **Unique Node IDs:** Use the new unique ID system to ensure that references between tiles and gameplay entities (like units or triggers) remain valid even if the scene tree is restructured.27  
* **Modern Editor Theme:** Ensure all custom UI elements use the "Modern" theme colors and spacing to provide a seamless user experience for professional designers.27  
* **Multi-Threading:** For very large maps, the process of rebuilding MultiMesh instances should be handled in a separate thread to prevent "hiccups" in the editor's responsiveness.18

By following this architectural specification, the resulting hexagonal grid system will provide a robust, professional-grade platform for building complex 3D tactical environments. The system balances mathematical precision with the high-performance rendering and editing capabilities of Godot 4.6.1, fulfilling the requirements for a multi-level, discrete-verticality combat map editor.

#### **Works cited**

1. Hexagonal Grids \- Red Blob Games, accessed February 23, 2026, [https://www.redblobgames.com/grids/hexagons/](https://www.redblobgames.com/grids/hexagons/)  
2. Hexagon grid coordinate system \- Mathematics Stack Exchange, accessed February 23, 2026, [https://math.stackexchange.com/questions/2254655/hexagon-grid-coordinate-system](https://math.stackexchange.com/questions/2254655/hexagon-grid-coordinate-system)  
3. Implementation of Hex Grids \- Red Blob Games, accessed February 23, 2026, [https://www.redblobgames.com/grids/hexagons/implementation.html](https://www.redblobgames.com/grids/hexagons/implementation.html)  
4. Beginner seeking help with hexagonal tile based map \- Programming \- Godot Forum, accessed February 23, 2026, [https://forum.godotengine.org/t/beginner-seeking-help-with-hexagonal-tile-based-map/99035](https://forum.godotengine.org/t/beginner-seeking-help-with-hexagonal-tile-based-map/99035)  
5. How to Make a 3D Hex Grid in Godot (Tutorial) \- Reddit, accessed February 23, 2026, [https://www.reddit.com/r/godot/comments/q1xy51/how\_to\_make\_a\_3d\_hex\_grid\_in\_godot\_tutorial/](https://www.reddit.com/r/godot/comments/q1xy51/how_to_make_a_3d_hex_grid_in_godot_tutorial/)  
6. Introduction to Axial Coordinates for Hexagonal Tile-Based Games | Envato Tuts+ \- Code, accessed February 23, 2026, [https://code.tutsplus.com/introduction-to-axial-coordinates-for-hexagonal-tile-based-games--cms-28820t](https://code.tutsplus.com/introduction-to-axial-coordinates-for-hexagonal-tile-based-games--cms-28820t)  
7. Hexagon conversions \- Red Blob Games, accessed February 23, 2026, [https://www.redblobgames.com/blog/2025-05-28-hexagon-conversions/](https://www.redblobgames.com/blog/2025-05-28-hexagon-conversions/)  
8. Finally figured out how to work Hex-Grids properly and made my own Map Generator\! : r/godot \- Reddit, accessed February 23, 2026, [https://www.reddit.com/r/godot/comments/umnh4j/finally\_figured\_out\_how\_to\_work\_hexgrids\_properly/](https://www.reddit.com/r/godot/comments/umnh4j/finally_figured_out_how_to_work_hexgrids_properly/)  
9. dmlary/godot-hex-map: GDExtension for hexagonal 3d maps in Godot Engine v4 \- GitHub, accessed February 23, 2026, [https://github.com/dmlary/godot-hex-map](https://github.com/dmlary/godot-hex-map)  
10. Vector3i — Godot Engine (stable) documentation in English, accessed February 23, 2026, [https://docs.godotengine.org/en/stable/classes/class\_vector3i.html](https://docs.godotengine.org/en/stable/classes/class_vector3i.html)  
11. Features \- Godot Engine, accessed February 23, 2026, [https://godotengine.org/features/](https://godotengine.org/features/)  
12. Hexagon Grid Tutorial (Axial/Cubial Coordinates) \- Orx, accessed February 23, 2026, [https://orx-project.org/wiki/en/tutorials/shaders/hexagongrid2](https://orx-project.org/wiki/en/tutorials/shaders/hexagongrid2)  
13. Vector3i in godot::prelude \- Rust \- Docs.rs, accessed February 23, 2026, [https://docs.rs/godot/latest/godot/prelude/struct.Vector3i.html](https://docs.rs/godot/latest/godot/prelude/struct.Vector3i.html)  
14. Help Needed with MultiMeshInstance3D \- Godot Forums, accessed February 23, 2026, [https://godotforums.org/d/40823-help-needed-with-multimeshinstance3d](https://godotforums.org/d/40823-help-needed-with-multimeshinstance3d)  
15. Any way to get the Tilemap to work in 3D? : r/godot \- Reddit, accessed February 23, 2026, [https://www.reddit.com/r/godot/comments/19cs4lv/any\_way\_to\_get\_the\_tilemap\_to\_work\_in\_3d/](https://www.reddit.com/r/godot/comments/19cs4lv/any_way_to_get_the_tilemap_to_work_in_3d/)  
16. Using MultiMeshInstance3D — Godot Engine (stable) documentation in English, accessed February 23, 2026, [https://docs.godotengine.org/en/stable/tutorials/3d/using\_multi\_mesh\_instance.html](https://docs.godotengine.org/en/stable/tutorials/3d/using_multi_mesh_instance.html)  
17. Optimization using MultiMeshes — Godot Engine (latest) documentation in English, accessed February 23, 2026, [https://docs.godotengine.org/en/latest/tutorials/performance/using\_multimesh.html](https://docs.godotengine.org/en/latest/tutorials/performance/using_multimesh.html)  
18. How to improve performance when using multiple meshes \- Shaders \- Godot Forum, accessed February 23, 2026, [https://forum.godotengine.org/t/how-to-improve-performance-when-using-multiple-meshes/36266](https://forum.godotengine.org/t/how-to-improve-performance-when-using-multiple-meshes/36266)  
19. Hide render layers in the editor \- UI \- Godot Forum, accessed February 23, 2026, [https://forum.godotengine.org/t/hide-render-layers-in-the-editor/106820](https://forum.godotengine.org/t/hide-render-layers-in-the-editor/106820)  
20. Hide render layers in the editor \- godot \- Reddit, accessed February 23, 2026, [https://www.reddit.com/r/godot/comments/1jmmkjs/hide\_render\_layers\_in\_the\_editor/](https://www.reddit.com/r/godot/comments/1jmmkjs/hide_render_layers_in_the_editor/)  
21. Visibility ranges (HLOD) — Godot Engine (stable) documentation in English, accessed February 23, 2026, [https://docs.godotengine.org/en/stable/tutorials/3d/visibility\_ranges.html](https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html)  
22. Finding coordinates on a 3d Hex grid, how to store x,y value or other data on creation for each instance of an object? : r/godot \- Reddit, accessed February 23, 2026, [https://www.reddit.com/r/godot/comments/199pvkg/finding\_coordinates\_on\_a\_3d\_hex\_grid\_how\_to\_store/](https://www.reddit.com/r/godot/comments/199pvkg/finding_coordinates_on_a_3d_hex_grid_how_to_store/)  
23. Persisting Custom Resource Data \- Programming \- Godot Forum, accessed February 23, 2026, [https://forum.godotengine.org/t/persisting-custom-resource-data/121445](https://forum.godotengine.org/t/persisting-custom-resource-data/121445)  
24. www.redblobgames.com, accessed February 23, 2026, [https://www.redblobgames.com/grids/hexagons/implementation.org](https://www.redblobgames.com/grids/hexagons/implementation.org)  
25. Using GridMaps — Godot Engine (stable) documentation in English, accessed February 23, 2026, [https://docs.godotengine.org/en/stable/tutorials/3d/using\_gridmaps.html](https://docs.godotengine.org/en/stable/tutorials/3d/using_gridmaps.html)  
26. How to make an editor plugin for level editing? : r/godot \- Reddit, accessed February 23, 2026, [https://www.reddit.com/r/godot/comments/1im8p35/how\_to\_make\_an\_editor\_plugin\_for\_level\_editing/](https://www.reddit.com/r/godot/comments/1im8p35/how_to_make_an_editor_plugin_for_level_editing/)  
27. Godot 4.6 Release: It's all about your flow, accessed February 23, 2026, [https://godotengine.org/releases/4.6/](https://godotengine.org/releases/4.6/)  
28. If I want to make a 2D Brush tool for objects, how would I start? : r/godot \- Reddit, accessed February 23, 2026, [https://www.reddit.com/r/godot/comments/e5x9q7/if\_i\_want\_to\_make\_a\_2d\_brush\_tool\_for\_objects\_how/](https://www.reddit.com/r/godot/comments/e5x9q7/if_i_want_to_make_a_2d_brush_tool_for_objects_how/)  
29. EditorPlugin — Godot Engine (stable) documentation in English, accessed February 23, 2026, [https://docs.godotengine.org/en/stable/classes/class\_editorplugin.html](https://docs.godotengine.org/en/stable/classes/class_editorplugin.html)  
30. Ray-casting — Godot Engine (stable) documentation in English, accessed February 23, 2026, [https://docs.godotengine.org/en/stable/tutorials/physics/ray-casting.html](https://docs.godotengine.org/en/stable/tutorials/physics/ray-casting.html)  
31. Tutorial: RayCast3D Projectiles in Godot 4 \- YouTube, accessed February 23, 2026, [https://www.youtube.com/watch?v=vGpFwaLUG4U](https://www.youtube.com/watch?v=vGpFwaLUG4U)  
32. \[GDExtension\] Any methods to raycast in an Editor Scene Viewport? \- Help \- Godot Forum, accessed February 23, 2026, [https://forum.godotengine.org/t/gdextension-any-methods-to-raycast-in-an-editor-scene-viewport/48483](https://forum.godotengine.org/t/gdextension-any-methods-to-raycast-in-an-editor-scene-viewport/48483)  
33. Undo/Redo and tool scripts \- Godot Forums, accessed February 23, 2026, [https://godotforums.org/d/41196-undoredo-and-tool-scripts](https://godotforums.org/d/41196-undoredo-and-tool-scripts)  
34. Tiled Custom Properties and Godot 4 \- Questions, accessed February 23, 2026, [https://discourse.mapeditor.org/t/tiled-custom-properties-and-godot-4/7372](https://discourse.mapeditor.org/t/tiled-custom-properties-and-godot-4/7372)  
35. EditorNode3DGizmoPlugin — Godot Engine (stable) documentation in English, accessed February 23, 2026, [https://docs.godotengine.org/en/stable/classes/class\_editornode3dgizmoplugin.html](https://docs.godotengine.org/en/stable/classes/class_editornode3dgizmoplugin.html)  
36. Add a Shape3D resource that creates the collision from a Mesh · Issue \#6037 · godotengine/godot-proposals \- GitHub, accessed February 23, 2026, [https://github.com/godotengine/godot-proposals/issues/6037](https://github.com/godotengine/godot-proposals/issues/6037)  
37. How to set a mesh as a collision shape \- Archive \- Godot Forum, accessed February 23, 2026, [https://forum.godotengine.org/t/how-to-set-a-mesh-as-a-collision-shape/23218](https://forum.godotengine.org/t/how-to-set-a-mesh-as-a-collision-shape/23218)  
38. How to make a custom 3d collision shape? \- Archive \- Godot Forum, accessed February 23, 2026, [https://forum.godotengine.org/t/how-to-make-a-custom-3d-collision-shape/22419](https://forum.godotengine.org/t/how-to-make-a-custom-3d-collision-shape/22419)  
39. Godot 4 Polygon Collision 3D Tutorial \- YouTube, accessed February 23, 2026, [https://www.youtube.com/watch?v=P2S223UbXwQ](https://www.youtube.com/watch?v=P2S223UbXwQ)  
40. Godot 4.6: What changes for you | GDQuest Library, accessed February 23, 2026, [https://www.gdquest.com/library/godot\_4\_6\_workflow\_changes/](https://www.gdquest.com/library/godot_4_6_workflow_changes/)  
41. EditorPlugin: handles(object) and edit(object) not called for custom node type despite plugin activation · Issue \#105609 · godotengine/godot \- GitHub, accessed February 23, 2026, [https://github.com/godotengine/godot/issues/105609](https://github.com/godotengine/godot/issues/105609)  
42. Custom tile data for my web-based map editor (with Godot 4 export\!) \- Reddit, accessed February 23, 2026, [https://www.reddit.com/r/godot/comments/1oe7xzd/custom\_tile\_data\_for\_my\_webbased\_map\_editor\_with/](https://www.reddit.com/r/godot/comments/1oe7xzd/custom_tile_data_for_my_webbased_map_editor_with/)  
43. I'm testing a visibility occlusion technique in 3D. The biggest issue is that it's not very efficient. What do you think of the effect? : r/godot \- Reddit, accessed February 23, 2026, [https://www.reddit.com/r/godot/comments/11kdief/im\_testing\_a\_visibility\_occlusion\_technique\_in\_3d/](https://www.reddit.com/r/godot/comments/11kdief/im_testing_a_visibility_occlusion_technique_in_3d/)

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAwAAAAeCAYAAAAYa/93AAAAs0lEQVR4XmNgGAWjgGggBsR7gfgvEHdCxZSA+AlcBRK4AMT/gVgKyt8OxDehYjUwRTAAk9BAEweJgTAHsqAfVBCbtTANhAWBwIABIn4MWVALKohNwwYGiLg7smAaVPAjsiAUYDVIDyq4Al2CAYcGEAAJgsIdGfyAip9EEwcDkBtBkrVAnA5lP4bSXkjqMEAAEMdB2TidgwuQpMGSAaL4HLoELnCPAaKhAF0CHcCcgY6HFQAAZaQ5yQsu0roAAAAASUVORK5CYII=>

[image2]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAwAAAAeCAYAAAAYa/93AAAAiklEQVR4XmNgGAWjAC9gBuKPQPwNiJWgYr5A/AeI3wOxJFQMDv4DMSsQ34WyDwDxKahcPVQMDjSA+CSUfZoBInkfyg+G8lE0XARiFSgbXVIWyo9BEoMDJgaIJMgfRIF8BoiGGnQJXOAtA0QDG7oELoDufoKAJPdHMEA0lKBL4AKMQJyHLjgKBi8AAPFdIJzv1oUaAAAAAElFTkSuQmCC>

[image3]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAsAAAAgCAYAAADEx4LTAAAAmUlEQVR4XmNgGAWjAAyYgZgVXRAd9ADxfyDeD8SXoGwZFBVQ0MwAkUQG34D4O5oYGIAU3kTiW0PFupHE4AAkAcJTgZgfKsaIkEYFMMUg/BeIy1GlUUEgA6oGEH6OogILMAPivQwIDShgHlQwAk38IFQcBcBM8EAT/wLEv9HEGH4AcROa2EQGiAFsaOJgcI0B1WM7UaVHwaAEAGvbKgulG3YgAAAAAElFTkSuQmCC>

[image4]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAIoAAAAfCAYAAAA4LFWUAAADR0lEQVR4Xu2ZS6hNURjH/17lHfImAyNMDCgjBh5FHuUxkJRbKMnATN2UyS1hQlIKs1sMpESRKBcTojDySEkeRTLwSN7ru99ad6/9nb332Y912O75fvXvnP3/1tnn23v/z1n7rAMoiqIoiqIoiqIoSn/nrNFvox/28YPRgNgIpe15Bg7HQM87b72/zhGjVdKsGWON7kqznzMHHIidsgD230mz1RxD/YMyAe0XlI9I/+b4hfRayziO+gdlMtovKBSEtDA8BtcWy4JjotE1o59GB6w30+hl34jinECYoNwGN7/dbk8xegG+CdvoBpVkGsIHZZvRI3DPtO9B8fI/Jyso18G1U8Lv5T64ONVuX0KUrL1uUAlOonpQbhitMNoC7ueQ0TejIUazrVeF6QgbFJrfKcSOZajeY0gGIzsol8E1Ou8xXCBmCd/tbKjwixAiKO6AVtrn/gHK7TKEDEoHGvsp0mMHovFlNAnNoTFufBIXwLXXvrnGmknTS9bO8lI1KGuNuu1zl/QNURnfjXq87TKEDMpTcI9jPO8B+DzUBZpqs67tRXDts2+6F8z1TfBva/LpK74ZlLw3KfoCXsSRvtMt5Cfr4JpxGo3v7fQWHDjp+8qL+zQ6XYmXawHNEFnnkm47qNY3fdIKXNoLdoP9/bKQAO0nTXRDtDrBdypCWq95ke/tNMPoXoJftU9fdSOrr5vgGi2+9bLZGkkveA/2R8pCQapOPQ76xqN+rspCAEJOPY5RRvsQnV9aJsjL0grKS9p1J56DazucQZ90Mnqc4ZG1oyKECso5cD8LZSEAIYIyDNwf/Vz3GW79LuGnQUsU3RWUF1oCSbu+Ddd+hDXu+KZhnfXlQZchVFAamg9IiKCcAff3VfiLrO//n1IH6JpQX5tkASnnmsLgm1vtNumg55elXYKyHo03/uPAPR8Vfl2gHxrynNK3Enk0dTbwENGFoIOiXyn0fLQ/qCQhg9IpzUCECAqxB9F5JH0yWhAbUT9egXt9Yh9J42MjMgj56Q0VlFYSKij/M4X/YqAXUEjoZicEy8ELPHWG1hV2SVPJpgsclMOyoCgErcbR6qQ/x9JaiqLEoD8E54MXtkjzjJbERiiKoiiKoihKTfgDTEAcwzPp0vUAAAAASUVORK5CYII=>

[image5]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACYAAAAfCAYAAACLSL/LAAACAklEQVR4Xu2Wu2sVQRjFj6Lii5DSNlUQFPQfEOyFECKIQaMW6QQrOxtRQZT4QpMUQgIqSKqkiI2PRsg/IFgICkkhKgo+QHxFPSczc+fb7+bezd6EVPuDA/fOOd+3s7O7swvU1NQ02E5NUreo69S1+HuM2pNjuEddoS5Q56lL1LjxLQPUXYS+qrtPPWihiVDSzD7qNvWS+mc0TW0zOTWw/jx1w/gWm5M0gTsIJz2CMNnk9ceatqTwH29E5Kl5Gcr9orZ4g2xAPs5l57XkBHLRJud9Rbh8ZRxHqG9F6v/EG2Wkwkdm7BU1Y/634zPV5wcjPxB66zaozBzy5MRj6kW2S2m1WgsInibXETtQXO6PRbsjnqF4sh2Tmqy6EbmK3Es3/qo4h7Vpdhi5T7fzKrMLxRXTHtQJu5F77HVeZbTvqNFOND8EVehCrj3qPKENfdgPtkONeuJvvapS8wONRDl2A73pvESlk1X44DJjUpVHPNU890akFxUm9pM67QfJSVS7nN8Rsm+9YVjEyl5rS/vUQz9oSBOb8objDULutzcMrxEyG70hNlPHqKfIB9VGutWGEB6EM8gZaYjab0ORWeTMkahB6hR1FmEFbZ9l0TeV3mcfqHfUJ4QX9CEbIqPUF4QVVe49QvabDUU0pttBXyV/UZyEpMunldSlvhhrampqamrWg/9nB6juZ794DgAAAABJRU5ErkJggg==>

[image6]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABMAAAAgCAYAAADwvkPPAAAA10lEQVR4XmNgGAXDC2QA8X8c2AtJHQysYsBUB8IogBlJYj2aHDroZoCom4ougQx+MOCwCQ2A5KXRBdFBEAPCMB40ORgAybmjC+ICMMO2oEsAwSsg7kMXxAeeMWD36h4gPocmRhCYMCAMk4WKlQLxF7gKEgHMsItAbAVlkw3OMCAMBGFQsiEbSDFgepVsIMmAPRLIAqCUDTLoO7oEOeAfA8SwenQJcgDMi+zoEqQCqoSXJhA7A/EbBoRhbkCsj6yIWPAJiN8xQPLfCyB+DcTvofxRMAqGJwAA3KNEpzBmVI0AAAAASUVORK5CYII=>

[image7]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFsAAAAbCAYAAAATbvP1AAACaElEQVR4Xu2Zv2sUQRzFv2oUMRG1EkJsTCIKIogWBiRgCkXQFBYhkEIQBEUR7NT/wMpCLAQbIYiKoOIvDEmQBAIWIRBBRREPVLCwsBARUfR9+d54s8/L7s56gV2ZDzxI3pu93Ly7HWYnIq1lC3QwUJECrIF+QDehqwGKFGAEestmZHH4CnWwGWk9Z6BxNiOLQw3azmak9RyDrrNZZxL6RdqaGBHJzUroA9THAfgm9kH4uMJPkh/JgZZ5i03QLY1ifS4t4EdyMCVWLDMgjVJXef4Jz48EsBOaZdPjEXScvFEpVnbe8fp+9rL5P6BPiqfZzMAVfYSDDLaJXbeEA48X0B02y84QtJ5NYrfY5EKYESvsMgc52SF2/VIOwEvoHptlRp/+zkLfoXOUMXehYTYXwH2bVYOUhaJLFxeuRT/wfi89ndATaEJsMh+htf4Aj01i271QdJvoStdDq6L4hWvRj5Nx+emHDkDt0GexyZxPjDB0zZyXv/fPedHlxxX+L7jCK39EoMeeOpFnHIh9I39CKzgIwJWtS1FR3kNjYq+zjLJKsQ76JDaRzZTpbXuIvGZcEbt+PwfSKLvot1uLvl//uVcaS0pluSA2iTloed3T4r9Aq92gFNIKdb5+cKH4RTsqX3iX2AT0Py/uNE8Pmw7/GZGOK/Qh+Ru8bCNlWbyDbrNZxxWetg8vNTfEJvAU2gc9T8ap6JNjs0J1vVd/mvws3kDX2CR6pPmdVAn2SPKWP5WMM9E9tbve11F/UE7y/m3drvpnMZVB33RNrKBXySgYt+5HUtBzal23L3IQaT1t0GtoFweRSCRi/AZCEZp2ofKKUAAAAABJRU5ErkJggg==>

[image8]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEsAAAAbCAYAAAA0wHIdAAABa0lEQVR4Xu2ZvUoDURCFx1/EWOgrBNPaKEiwUxDENxDyCjY2PoZPkcJGQQUVH8BGsNNGEbUQC7G2UGeYe8nsWW7YdYO4Zj447M4ZCHsPyZ3lhsipzD7ri3XJakPPMbyxpsL9NGloa722Y5FwRLZ+NLVjiN8qYZI0rB3jOQkeWPdoOlmWWXusD1YHek4f5Gd4gqajzECNG74TWCUNZtd4HlaCOdYnq2E8Cera1GUoGvIVax3NOrBFusjzcD3OtkuxQPoZI9gw3LAO0RxWFkkDG8UGc8s6QnPYWaJ8YBKUT9kENjAJ6izbrh9x8qVUlRjYBTacPM/UGxxj0HMMElScrC3K72FOwAYV+TeBnZIu5JXVhF5ZnlgHaAZiYP3ew/40ctIQ2SBdjFx/wh2riyYwT4MZHr/OOOmDbxqvyiTcRiPBLOkRdu2QYFZM/RI8pwAS1DuaTh45JfV3ogJMkAZl/8BwEth9qrajfZB8A75jUlfg90wRAAAAAElFTkSuQmCC>

[image9]: <data:image/png;base64,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>

[image10]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAI4AAAAZCAYAAADnnhbzAAAFMUlEQVR4Xu2aScgcRRTHn2tE4pJEUSJKPKghCR4SUTEKLgfBBUHcvXyEENeIih6CQTSIB3cFFVdQBD247+QU9RCIBPclanRUEndUEhV368+rl3n9n6qe6W+m+/ML/YPHTP1fTdfrntfVtbRIS0tLS0tLS0tLS8tImMrC/5xtWNgKmcJCEzwe7N9gf8XPHyV9sY8L9l6wI4MtC/ZW0T0UOwf7VrR9s0sKNbqcJsV6sP0LNZQdg/0e7ORgZ8Xvo2RasE3BnmIHgbY53isKNYrMkG69f+LneYUaXb4Kdn6w44N9GWx20V0f60UD29Zpz0SNWUvlvYKtIG08zBNt7wmnLYjaDk4Dl0f9QKcdFbWDnQZwIzA/sFCR+4L9JsUkKEuch4N978q4zvY7/NHMnqK+O5yG3gTaY04DuOFxw3m+oHItzBEN6EJ2iOrfufJB0vvHgD9ZqAgSA229SLpd3DMSeuri/Crq8zxJZfAGCxVBb3dCsO2C3S7liWPnxn8usPO7iPS/o87cJqojsYxUvVOkgccWutlU48C6SAMXapErGx+yUBG7e5kPpLfHuEq07hjp4HpR33ynpRLsDxaGoF/iLJFugjAYDkDHdTasZ+k4zdhJ1Pes03DtmOtYqIPcSYF1or5jnbbZfQcvBduNtCr4bnsQ7G7EY4w5W9T3qtPuDDbXlXEul7rysPRLnGMkf36PSq/vxlh+zmkero9x3b2uvH2wz125NjgQzypR3wOk45EC/edg08lXlVtFj4W7DxwmekFzA0eLdyY7AkdL+nyWRg13NrrxUdIvccC5UuwFjdelN953Y9kng4frg1nBfon6Q0VXPSA7U4EYL4v6/B08ar4RbeOdYBtFxw+zpNvbHbClpmLxphL2cCk/nzoYJHFyWKx4xLLmB8aeps8vCWZEZYGgu4QPf2hdWPuwsaIrGZtpu5AObBbGv6kTS5yn2dEHv5zgMe1m0o3UbxpnHykP5HlRH7rBurD2UzHcJaqvcprV3dVpxiGSP1ZdWOJg+aIKuThNv4UdkdzvGsVG6blAMPCFLzUzGRXWfiqGK6XXZ2UsvDEYH3H9urHEyQ1mU2BWl4vR4sdxUzR9flnKAnlN1Ff1bqrCx6Jt4JO5WHrjs/K+TjOwqs3168YS5wV2ZOhIeQ+OJQgcjyckRtPnl6UskI6oD8vZdXGDaBsb2CE6beb4bDp+hNOMMVHf16TXiSUOL16mWCnp8aI/PzyiUEbdFHw9JozcKiVoIkjsh6ENXugD14r6/Mq0rZ5e4DTDpvapVfC6sMTBDLQM3CDoTVL4a4zZIsqYbTJYL8v5Guck0WDOYYcMlziLRX+bWtlkcu10RPUTSYeW+hN+kvRxBqHqQqRhiZPrIcDpouMaPHqxkoweHGtL2CReE82Ti+MaUR1bP+PBjosN6jJs39CvaCdJ7fE8ErXUtHcQsDhoge5OPsb2y/xYau+ove00435RH3aQDTsG7/sMymXSjfcm8jGYjR4quhttu/kYt5wqutDnd+mxU23HzdnyLbUVrF1Bv5p0aJ+SVgVrL9W7e/A/WN2+YIyBih/FT9gehRrVwPs62CB9X3TQ2g+MWfiC8k6wx5IHCWqJf2ahRnXeDPaK6KSgDGwLIGE6wT4RHdjjE2U8RnzcFmeZpTaOF4r6cNd/Fr/7ParxcI90e/F+dILdzWIZ2MgcJXgNYz8W+5B6D6gp8N7OgyxOMP51l1EwSOJMOJMiSMdqmXxvN1YBj9dGds+HAZt72MibLNgrDVszOL+hevT/APS1w6XGzeunAAAAAElFTkSuQmCC>

[image11]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACoAAAAfCAYAAACRdF9FAAAB/UlEQVR4Xu2WvUuXURTHD2Uv4ksiFKJDk4uOghKoYDSEkNDgy5/QErUFOQiCIIRDa4ROItiSDpGDQ4u0NOokhiiFm6WUWKbn6zmH59zDo9ZmeD/whXu/59x7z/Pc+9zfjyiTyWT+hVrWIWs7Bs4br0gK/RYD55EH0cj8z0yxfrL+sMZCDHSxDlibrIoQ89Sw1lm72jbmWXdc32hhzZKce4xpS8MF10iSnjpviaRw4x5rTdvIhcq4RUXcdJ/Vy/ri8sB1kheDnGb1GrR/w5I8+5ReNTdJkj87zxd2WqG/Wc+1jbf+mOTtxvxL6kUfoJ6BaII4AJPssZq0f5c1p+1WktyP2j+Ly1RejK2Jbfd0ql+KDYJwBp+l4QRsH/LqYqCEKipf9DYV6z1hjbDekqwND8enlIeUFgt9TTIKLH4WjSQLlzFFMscGa5DVTcXu/RXtrEU6uZhHJP6LGAjgeOxE07FMMs9wDJzEJMmAoeB/UD8SHwAfTqSDtRVN5goVY6e13VOET8cWxvXhwV32K3gAufgiQSXJm/HYh9ZPcuUZ1er3aR8Foo8boYz3rAlv4Mse9QbzkmSSq8EH8N9oOz6IXTf4w/Ja216rReoxWNvvDqhn/WDNBP+YFUonXEjDCfYQkF3QxndKf1Fw3i133Pmed5Su/YlkpzKZTCZz0TgCUUiPsAOhXxcAAAAASUVORK5CYII=>

[image12]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAGkAAAAfCAYAAADk+ePmAAADU0lEQVR4Xu2Yy6tPURTHlzd5JiQGCOUx8ShSKDKQUJTHH2BAkStvBkRKycCQ5FJETDAQycBEUsKAgWdy88jEK+/X+v7WXs7eq/P7+f3Oz63fvdanvt1z1neds393r7P32fsQOY7jOI7jOI7Sh/WL9cYa/wmjWD9Za61RA7tI+lD1ndUryaiTQyQ3fmuNdsw1ko6MO7Zokc6SXI+HXdkaYj2jWN0ssIF2zmrWnHB8h4oXqSvJtaetQRLHCHX+AfUU6TLJtcNNHGC0wutkDad26imSTpV5HCTx8L4qSzPrE8mQ22M8MIP1g9XC6my8mN6sp6wP4Vg5z5oWnSvjSIY/fiCumZzaDUdrFWkniffIxEt0IzGbohiGHoqmYD5+HI4rNTSIMl81lzWP9TzKA91JHgrkjA6xweG8ryY1IK1VpC0kXu576Suly+mBJMlPolh840oNYQW0LRxjtK0hGVU2v2OI2TjA71lqgzmMpPRhqFWLqRhapPihrhZtO4/1VMG3BjrwM2toOJ/NOheOx5PkXg/nfwMvwbxGtU1MdTHTQ7yR0SKts0YV2L6O2UAVfDUgvHM2p3YCpizk9bNGDljz5zU4jLL2MGXsINk7oG3EMGU2MlokPPm1UrYIJP1e1l9EaaGgF0lGRtmbGIaQdHoezST3eMZaxppJ2ahtC2iRNlqjCir1324Sr+JHgimsK1T+RitJ4vusYcCU+N4GI+6S3Ge7NQqABU1RFd2PaJE2WaMKyvUtOErinYqDR0JweRxkroa4xTaARYJlKuuVDTJdKLv2RDieldmF6MA6Xofi7UEtaJGwGquV2yTXjrUGc4vES97T2ulYIsdgr/LNxABysfICPUhGRIwuKpaQLOsVfDhEfGE4R3FwjpVfHhdZ+22wgdAi6So2j2MkOfdNfECI4/unxQ6CEljB2d3tAZJEfGOyIH4mHNsi6pIajR8Ox7EeZqkl0Lb9Qf1ZH1knTbwRGEMyS8xnfSH57S3hfBJJ58fE/7tFp3v0mbIixCZGsT/co/SGl1I7QQsI6eZTeUfplwK83zR3bxSPuUBp2zdJRmgjcoP1kmTviAfuQfiLPeBr1qostcQIkj7B9iUP/U6H1bJ+XZ+QZDiO4ziO4ziO4zhOW+M3j8cjdHCXqNYAAAAASUVORK5CYII=>

[image13]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAdCAYAAADLnm6HAAABOElEQVR4Xu2UPU4DMRCFp0FCNJyAhrQcgcKiS8MhIkUKgkP4EhRIKXMBmtCxRaScIUehQbBmPfLk4fHaWUtu8klP1r4Zz4+lhKg+plBV+enVFaoa1qsZbvtmWGo8QNPmhvQBPmmISd0dZVRAa/7VawUeD/EC/iRiA8woNJO8Kv7JaIUeKDS6Ev6z8KuQKvTR6wm8DVUc4JQi3HyBAYlBQ6F0gD0Nd94wILE0JLkzRUlz3trpEWJHuITOn2MNxuIxLinUvobYH8afnMTfSM4LadxTxoKW0kmanwvXfseARHsF6zXGmob7cwxQqJ1cpKN4En5rpJqwf8AAggWsVw58dwv+jYjdQuwf/ArudMS20XD/gLEm397fga/C01qvEtxvnu9LLWXSGPLiFC7QyMVQeIFmTN3+zJkkv4cxfMsexJ2xAAAAAElFTkSuQmCC>

[image14]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADUAAAAfCAYAAABH0YUgAAACWElEQVR4Xu2XT8hNQRjGH/9TlGyk1MdGNkgWsuBTLBQWKMlWlhZib6UsWNpQFjYWkvzZKJQoslLKgpVkoWRDbPybxzvvvdPznTkzx73pLM6v3u6Z53ln5p1z554zFxgYGPhffAyxS8UecD/EFRVruBXikYo94keIYyq2cTDEbxV7xjxYjevUyMHkIyr2kOchfqrYxBn0/1tyFsBq3ayGwqS7KvYY1tv6ba2FJc2K3mduo7CzLqKQIFwO8TXEg0R7nVx34Sxs7uuJxh1D7VqiKTtgOWvUcL6gblHbYXmXYntDbHt0ZXeIJxg/0R7Hz/UhFsbro6PsudC/oKJTU9RGWM5b0Z9GnQV1JZ3Ta1gp7ZOjjLnQv6eiU7OoXI7v7T1qVODj+Q54lXjvQnxP2k003eQRuYKdczD/kxoo963Bb8ysGgXY55eKTqkw9w+pgXLfGv51DPb5pqJTGjTn8+VHnW/4SciNX4J9sk/d0qA5n4df6nvV6MAm2BgP1aiA/bIPijdoLtrJLSqnz0feU27A8naqUWAxrF/TT+Ivh2EJTGziOMyfiW0fMFf4KYy97HskkhujhM/RChNOq5jgC2fwT+TWeP0iTUp4CXt38eXaBsd4r2IFH1C5qM8qtnAH1me/GgkHQlxVcUpwbv6zaMV/sDyy1FCzbZ6FWKbiFNiH8twjeJRPD6ltlBa1BO3+JHBc7pQqFsE6rFAjsgrjw68H2+fTpAhvUG6cSTgBm7MTM8jfYW7NbSG2wA64/ORfgKVpUmS1ClNgOfK1FWGxN1XsAXyQcTcNDPSRP6U7suJyhmSNAAAAAElFTkSuQmCC>

[image15]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAHMAAAAfCAYAAADUdfLHAAACHklEQVR4Xu2ZTSsGURTHD3nJW1IU+QwkC9kpWbCwsPMBrFhgZUcUyULZSaGQFVlbEIVPIGWlWCjvCyHv53Tvbe6c5xlmZjFvnV/9e+b+z52Ze+bO3LlzHwBBEARBEARBEARBEARBEFLOKuoV9Y2aZrEss4n6QG3pciHqzgnHRh/qB3VkeUvaO7A8F6WgKoxY3gmozs0yg6DyHtDlXtSX9l5MpZioQ93qbWrPjf7t1t4zalFvu3hHPVllOhDteGF5f/EJqn5YxQF1IJ17jfnUieRPMj9qrlA1ettcp3ZdNtd7W5dd8ItKw8wbqtHyskQB5OZseATll/NAxJi2FelteuAM+9qjPHKwnxIaZsbc4cTQj7oOoXPa2eIYVK47zCe8Ojkf/Dx+1UA7+2QUVHsmeMAL86K1RSdNInQ3hpGNybGW+TQikU+TIT/wc/hVEB5AtamEB/6jDbUHwe5OognVFVKdED1e+Q2D8md5IEa82prDCqiKNHzZHGrfL/OojZBahujxukD3oPwqHogJeoqpPb5m1iYpM9010LTX71CTRvJ1ZpmHHydDoNozzgP5oBnrFPMWQB0g8BidItZB5Visy/W6TKJpf1K4hIB9cQZOIqRddzizzICT8yk4s8Y5u1LM0Gqc/Uki+MR8X1bzgJA+kva+FEJSCaoj6Q8GIaX0gLMWa0TDLS24CymjAtRCSQuqGdWK6nDVEARBEAQhM/wCsWu/BbC61xIAAAAASUVORK5CYII=>

[image16]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACwAAAAdCAYAAADRoo4JAAACA0lEQVR4Xu2WvStHURjHHyRJKcpOCpMoZZOXhVIMSvKyKDFaDLKwyMiAgQwmmfwDJjZlshgoSRkUJi95eR7nnO5zn/Pc+ztnstxPfdPzPd97z7nHefkBFBQUhNKK+kG9ob5RVelmj2ow+X+hHEznvbZut/WaCwiawbTPywbJDZig0zuqLpVIE5o/B3+2nlH71n9BnaBObf2Jek2iOhTsVzxSp/CJmLzzOXuoYVbzJULZMlZ7zELyZZwr68vOYvOaN47aEh5B7yi5FGgtaS89zvBj85q3jloQXjcELAXHGWpUePegd0bE5Ok/Ib1LVIvwKJO7FErhOqcjKYSsfJ/1621dYWvONWpOeMHQMfQI5qUzok0jJO+Wy6L928jaeiBiKXBop7pZInWkmz1i8zWoCWmCP9vEJOjZTJogGUjIuorNO27BnDoceseO9bWPyWQFkkGEEJsfAHOBcKj+YDWdSAeszqUBkgHQ2itFbF77MPKWFS+FuzrpDpe4AVwwLzavcQf+Bm0D8+y08L0Bu06+ZAMkbbuKF5qXDKKepImMgHmWbkFO5oCXhD/F2ujocsTmJd4ALG7japswxRGYX1q1wnedbwg/Ns+h23BMmgx6/pDVleD/ZvmD73CuXpbhxOaJIdSDNAWbkJ5RulC6WK1CXxVDaJ4PJI9tSCZgVbQVFBQU5PALA0HMHQekpZYAAAAASUVORK5CYII=>

[image17]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADgAAAAfCAYAAACyLw6QAAACcElEQVR4Xu2XS+hNURTGl2fyLuRR8i+lUGQgIzFQJiZSZpgZUBJKBspM4m/mUcYm5BV5lAykpEjIRBJJUmKAUp7rs/Zy9/06r3va/zqnzq++uvvb3153n0d77yPS0dHRVD6o1rLZMN6ptrJZhUuqO2w2lD+qxWwWsVFsUFuYKTbfsdyRB8Kb2Ww431Rv2Mxin7Tr6TmLxOY9gTsYhK6y2RIw98dsxgyJhdaQ3xY+S8nbNywlgcBo1WWx7MXIvxa8U5FXl1Gqh6ofYq+fs1d1IGrHHJSS+X+RkoAyT/VbNTG08fuT6qdqffBQY1f4XQfcQNSItVO1UPUryjHzxbIbuMPxYkVw/4ng3QptrwG/Li9V58WeItiieiJWd4yHckAGC2UmZRd4TLWfvLdiY6aH9iOxp5oa1JzCZgaYyxk2nbILzKLOmEFB/cls5oDsXTadOpNFHgvBSDBOrH7lE4pY/jqbzqAXuF0sf4Q7EjBVBpuLgzEn2XTKLnCO6p5qfGh/FMtP+58wimpUAWdLrMpZFNWeJNafu8i8kOICfgN2Uztmqeo1ecCzs7iDwEKC3Dbpv3HYOr6qjkces1ps7AzucDaJBfwJMejD9xe4oXoQPJ/0UGgzK6R3gdi8i0DmivQ27Vjfo1wWGJf1/30ggNNCFkuk92eng3co8p4HL4ubqqdSPIH7qh1Re7b0ap+L/Dyq3IR/IZxMRgLsla/YTAjmvpJNZplY0E8RKTmsWsdmIo5K8dvRB857t9lMQOUJ1AC197CZh2+wfvxKwXvVKjYTcVb1jM0yFkjaOz6XjUQsl/w9sxQs7xfYbBj4yO3oaDN/Ae1hpPzE4/l5AAAAAElFTkSuQmCC>

[image18]: <data:image/png;base64,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>

[image19]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAL8AAAAfCAYAAAC29hzoAAAFlElEQVR4Xu2cV4gtNRjHP/UiFsRybYjo1YtgQcGCKAgqKthAfVGxca8PYkHBF8W6FrA+iIKgvlwVxV5AHyzYBX1RH6zYsIuKBXvX/Ey+u5lvZ+Yks+7umTn5wcc5+WeSM5mUSb5kV6RQKBQmnFWcvebsH2f3O1ujGl0oDBcavXKyCRcKg2VV8Y392hDeIIRPXHlFodBjjnD2mRUjtom+Xyi+8a8VaX3jPGcvW7EweehInsLq4q+lA/SdT5zdaMVJ5g3xlbu2jRgwlHczK9ZwjvjG8oOzpSaur1D2w6w4qfAwsI1txEB509nvVhwB0x2e0R42oodcIelvvcGzobONrDhgqPjdrFiDdW3qIDEEKMcZViwMm2skrQE/K/66uAMMqfF/KsMpy2BIXXuscHaZFRMg/1+tWMOlzt6NwrpAPirSUlni7GMrNvCHFeaIMyWx8esc6SajJyVeILZ29oz4e/za2Q7V6P94UXw8D6KN3PKf6uwL8fF3mbhRrCs+HZ9N3OPsHSsmQt5XW7GBh5394uwJ8emOr0ZnwaKZZ9IGv7GPFUeAu5Z0z0ca9YT2dKRZ1IN1nI2I+VD8RWr04NWc/STju0C8Tvy96jx+vRDmvhVGv52cHR7ito/iYnLKPyX+musjjUr5NgqnoKMsn5Z7nb1nxUR2l/ayzjUrxA9EdXBf+1lxBNTvV+E76b8MnwcG7UdnN4TvdXDtS1ZUthJ/wSYhvIuzu4N2ll6UQNx4ci3XK0HDJB33quj5lCUhfLqzC8J3Nj6IOzaEY3LKf1/QGYlidITJZbH4dHEHoOG/H4VzwW1JnnYhO5/c4uwbo3FPBxgtBQai9cN3bS/qjfozhKmXJoingyRzu1RHtnGDRkyhLom0KalOE+LGqA8tlbry88DJgwduYTR60IqJxB2Ahv9BJTYfph45ZZ0r4g7A/ehInYuWZVH4Hg+UTwaNw3lNZNX9Y86usuKYsatMFwpjirB55Ypp9C2RsgCEpvLrKEMjP1u8R+XVoN0ZXdcF7QCpC8Y2HpH0yo6fYZ3NFjoA+RxqIzqgi9cpGzGC5LK87uwUK44pzANtZTHftdAwiTvYRtTQVn79jROcHeJs52r0rHhKfAcm/9nuRfDWSqrseYD7wBnwvY3oAG8R8mOKmUNS4+fwU5c5mbK3s/07WspmTB287pY7+02aC9mkW0aVPzWfXLThA+5PfoM3QVf0cNpCwz1Qt4Dn6bsorgtdn//IdPTMOjchPuAtrdjArc5u62gXSzp/S31h0P4y2nZB19U+U6PnpqNXklL+kQ+xA3HDV7QD1HmBUjhSfHpdwC8EccNX6AB2EZwKgxx5/mwjEiBd44KX6cPNznY0+uXy/1f2bNlWmhsh2jKjsQBG52gD4IKLXaGQWv6m34U1pTmuCfzqb1sxoGds1MuRAwfZSMvULAWeh065WMPY55ML+exrxcCV0q0DnCY+3y4nTkmHW3wGj4q/maNlunJja9uEWSi4LzvvY9pT52d/QaYb5THiR9qYnPIvDdqySIPzg76O0dt4SHxDa0M7QE6+CulsWZuI3apseNU931RIu6cVDexYq98+lY+k232xLiMdg2YFFlb2NaKbPTSI3B+aL5jKML2JG2nb7q1OkzjSHNOl/JtK9XfJm/2EXPDFp8BfWrEPkYt6pkZxrsy8jvDjRkvFvj2byPX+sAOduxcE47T4L8wTqWda9pKZ1xFOdQuPO5SFt1lhwqDi7TmlFEh3kRV7COs8ytK2AVYYKCfJzFF9FG+JXz8Ngc/F/zljYUKh8h+wYgMHSYtLsGdwmDG34xcGCItfjoO0sYVUzxSx0O4zNPxFVixMJm2+dU5/2n/18YoJ9wncogu5wVfoEYySHD1gA5CdbsI5O+6FQi+5Q3xjtzZqmlQoFPrIv/lWtHPxuaVOAAAAAElFTkSuQmCC>

[image20]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAHIAAAAfCAYAAAA7t5n5AAAEzklEQVR4Xu2aR6gsRRSGf3MGc0Dx6sIIZjGA+h4GEFRERVEXvoUbFURERTFvzIq6EFQMIKigqKgbM4o5gZjAgBjAgAkxYq7/njpvqv+u6u6Ze6/2PPqDw+3+z5kzVd3V1adqLjAwMDAwMDAwLl8FW6ziwP/CP8HWUrELDwR7SsUp5dFgn8IuxsdVV6+4O9hbwX6HtTVl/YzWyhGY4EM9Zd1g12B0cc6uunvFJcEeg7Uzd/3PD/a3ik0wyTEqTjm/wfq1kjp6xmJYOx8X3aHvJBVznIn8aJh2SqO8bzwNa+e+ojt3omM/GPSwilPOKrB+/aqOHtJlwNF/uIopW8CCFok+7VwE69eF6ughXW/kOyqmsChoS5Jyc7Cfgj2RaO8mx+PgF5uVm8OZgdodiTYJfBKZh09mE8cHex8W+6z4yJbBvg/2JayISmG/PxcthUuHK4P9CStYzqi6Z9kP9t1PqkPw/hT5ES0Bkb1hcTfE823jeZfRlOMA2IVbDvb5Z+LfrYOtGI+PXRo9Pm3tOg7mTwuM66PmbAwbtETzbZbRUl5FtQ/eJ50huNyjvo/oyq0of9csTY1xdoDFfCD6c1HnTRiX9Du9DT7i/fzUpRHjsTLs8z+rI3IazH+dOlBvV3qs16n0lPwC01cV/WLUp8dc3hxchjTGdUlUinkQph+ojg54Pn/SuSh2PsHcipQLYDnPVUdgdZT781qwL+LxGrBdLsLlC+N1YPiASXkkaneJ7rG7il5qi8JXAOM2VYfTlogLVvq/UQfaP9sFHwyL1DEH/InIrR/9ffh2sLOCXRHs5ai9nsSl8B1O/6HqQL3/fk341J8X7HbYtaOm63ROp9S5IdDGXrDY/dXhtN0M9x+pDrR/tgvzkUNpyum+U2Dl/O7BVqhE1Cnl40VNC7UZjGL5BB0UbLvEr7BgZCxnpTYOhsXuoQ6n1Ein5N8Jpr+kjjEp5Z8Unwa9SFHG/b7lYfGsPBVWrOsk50fDYru+FsZpy8mw2A3V4bQlK/m5wU6dI2VSdoTlaCu9x4HTGXPyL/kw2Gojd7E/JTgTMf4mdaCeZ6uodS3+0rZsHuyFxKdchfr3VfB3RolSx0u6j+CcT7kXFse1VBc87wbqSGCxwhivGLUdP2S0FPXtHDWut1NeDLa9aISx36oYOQS2kU+2gcX6Ted7cs94nIODXdtW4ShYAKuqHCfC/DPx3KsvN+V0jHxXi08p5cixC0bxrC5L3INRziXBbkx8xKderstSvCrkOlah/ldyfg5s6ZXjFlj8eonGtTJv/NeJRhh3f3LcRKdrxYDcroPjN5vGkny3ePxKGpTwBmyk5XZKUpjjMxUbYGn/Jto75FXie+qIcDD+gVGfaNyBKcGb4j+J0S6tumucgGpuPqF8shV+p8cUlxURxlyrosKg71Rs4CHYZ3LluHNYsNtUnAfWDvaRiss4rHzbBu8sXnRwCuiCj6ImOJWsqeI8cBkm24CYZlgFl2aXGnwHpBvhTbTdSP8JaSFYqLx9xWuSzv+740UAp64cG2G0we7G88vToAgHRSnPXGBF2lTZLYtwl2qJim3MoDziOe3yIrJ65CY6//IX7XSN5myiwjyxUHn7Cvdru86SNXiD7lNx4D+Hr6fnVRwYGBgYWHD+BQcUfU0xE67PAAAAAElFTkSuQmCC>

[image21]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEwAAAAfCAYAAABNjStyAAADLElEQVR4Xu2YS6hNURjHP/JIUR65Itw7kBgg3SQDLlEMKI+SoZIyQIm6QxOv8hgoE8lAyUAIhQHKozyiRBlQShLyKFEUYv3vWuucz99aa699zxnonP2rr7P3//+t76y1ztr7rL1FKioqKlqTdyYWstji9Jj4xGIO50xcZ7FNuGziIYspVpn4zWKbgfEfYjEGktey2GYsk8xFs0MyE9sAzMNZFhkkXWSxTTkpBYunS2wC/ikqRGaLnY8ONjwHpWBGiaMmvpq4qrSn6rgMO8V+9ymlYaVDO6G0/oA+/TKxhg3DQBO7WFTg+4+x6PkieRM2T2zeEXc+zZ37KMtiE7dMDBDb/ob7nGpikDteV8suB9qOMbHPHTNFY06OKWk6ZojNeU76badjsGXR3+n7MJrOt9Qy8rlkYpE7vie2zpS63UfRmJN+0nTEcs6L1ZewkYGv51fuE+W9NPFNnZdB9zPU7xFOe0u6JtSuRtI07Bbrf2BDitvm4Ce9h40G6RJbl6+K/U7fTLrmuyTGVTRo769mQ4rb5tCMGiEei62L24kGfwTQce+MkexT0pS4P0usfpeNksTqN0qsbkzXJHOSpsR9PKhDx+NEf5kptsY1NppAqN+jnPaRdCbUtsYzSZgSbxzTsceJecxpsXkL2Ijg645lIwDyfpJ23OlbSWeQg0s6CDZ2SBjChmODWL/TnSPPdzw0Kduk7h0gj4nVCOF34IgH5IXg2r1KS92//L5wExsaJGxnUeEnFYEXjN3u+L5OUjwSuzfDxjQFarxiMcEVqd/Mc3gv9X7jCYUnMcRGKc7pSyjzxvGC2DbL2VCsEHsJNJuRJl6wmMFSsX2+yQbxWsJbqL/wN9/UUtXk/FJ3TAxnsQnslfRGeaKE++c13GNTIGcyiyGwP9EP1ClCHdIMlbTfCEV1/euZz0rb47T1SguB92A/WIwxWGxRLPkQ46T+0OoD53jAZTD5sTqN8MbEXBaJ6WL7NkdsH7BPxHnR9gdXQ9GP8Q+dEm+EyxWdxb8Vds/4nG9imE5yjGehSeTWnWTisNjHrpXkxcC4J7CYAybiDIstDsZbtHIrKir+H/4AHI7+LUr/GnUAAAAASUVORK5CYII=>

[image22]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA0AAAAeCAYAAAD3qZRJAAAA4klEQVR4XmNgGAWjgKqgBYj/A/FedAkoKAJiEWSBTUDcCWWDNK5CkgMBS6j4ZJgAJxC/hbJ5oZJPYJJQcAQqrgQTOAzEJlD2OqhkIEwSCkBiIIwVYJPkh4q9RhMHg0QGiOR0NPE+qHg+mjgYgPwBkhRDE/8HFWdEEwcDbE4DAVziYHCbAVNyIVQMq39AABT0IAUvgTgaiJ9C+SCciaQOKwgG4hIGSKj9YcC0HQ58gHgrmpg0A0TDTzRxOIA5QxhJDGYLyNlYAUhyIxIflGhBYoZIYhgghQFhGwjfYMARL8MVAAC0IDzfKSFscgAAAABJRU5ErkJggg==>

[image23]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAgCAYAAAAbifjMAAAAvElEQVR4XmNgGAWDExwG4v94MCNCKX5QwYDQRBZ4zgDRfBtdglgAsz0CXYJYQJHzoxgoNOAWA0TzZXQJYgHM9iB0CWIBRc6PZiDOAJwJag4DcQY8QxeAAZjmGegSaACnBTADpNElkMBSIG5GFwQBFQbCzudjwCO/igG/AeIMELnf6BLmQBzIgNB8BoitgNgUiO2BOBWIHyLJR0K0QYAXEH8F4l9A/AeI/0EVIWOQGMjWH0D8EaJtFIwCKgIAyylC4UJ0q74AAAAASUVORK5CYII=>

[image24]: <data:image/png;base64,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>

[image25]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAB8AAAAdCAYAAABSZrcyAAABOklEQVR4Xu2VvS5FQRSFV/wl4hFE5wWQaHQSCiFRUBDxAAqFhIZWPIBC4g0Ueu8gEtGiEJQajcrP2tlz7pnZd4ZhEgrzJSs5d+01e52be++5QKXy3zmi3q2ZyQL07AW1Sy1T+9Sj87sYoG6hQ18/YQXdexoNe7kOvdQaNepel5QvUa8IS7eCxBeUlC9SD9b8DiXl8pn/Wfk8wvJB7zqLkvI5aPkV9UKdQ3fd+6HPKCmfgZ4dMb54b8aLUlI+RE1Zk5xCdx7YgaWkPMU6MvdmhRL0WMMxi8y9WaEI/UifXUV6FpAVijCJ9Nk9pGcBOaEm0xfxY8jPTmbTdiBMQL+lh2gX70DfzbiXE8bQZjbN7IR6Mt42NHtn/A7P0AeB/LtdUzfuWh4YcteWM+rSmo5jtDfXaCNIVCqV3+IDrG1pbNeILGUAAAAASUVORK5CYII=>

[image26]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABgAAAAdCAYAAACwuqxLAAABdElEQVR4Xu2UTStGYRCGx0dIsVIWVkjJxtJedtiwY63kR/gZrJRko5R8FDtipfwAlBKxsbAQC/l6xtzzvvPMmSMLdueq6XSue+Y855z3PQ9RRcV/MJ3q09R7qtaso84mSc8bjo+pGrIOxyFJY69xG3CeKxLfaNw2XMgySdhh3CScHxqCW3CeYf/gZQuCVx8kPlKdOfdExUUV7i9k+hoWfVBC9FTKBUk2aqUODON8LtVKqpFaR85PCxyRZDxfQwf6SR5/MNU43LPpY5rhyxY4IMmOrdQBP9QOd2tcN5zvVXZJsnsrdWDVSqBZJ857jIvYI8myJ9eBWSuBZks4bzMuYp8ku7FSB/juPJqdBi7ihCTjj66GDgxYCTTjO/Mu4pokm7dSv4MxK4FebMo43p/KFggX5x+Q5ZYPKB6YgJtxnon6vzknCfTfwqzB8XfheaHihdbh7H6WsUP1O9Dqyzpy7kh6LnHk6so6SrBb8G9o8qKi4u/4AolahpwTMZ+LAAAAAElFTkSuQmCC>

[image27]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAHEAAAAfCAYAAADQgCL6AAAEKElEQVR4Xu2ZSahPURzHf+aEMpUU3lsgFsg8xSOKBZlKFpKwRIlYWFgYUoYFSSwslCwkGbJCGcpQJGRhyjxkyhALxPm+3znvf97vnXPPvf933vu/dD716937Pd/7u797z/+de+65RIlEIpFIJEK8UzFFiolmZaOKW1LMywkVF6SYqAgvVRyQYoh5Kv5KMQLnqGnyFmU/tYw6wHrKVws8c6SYBQ5YKMUyGKfiNXE+O5qb9ioeU+XrMNyj4rVsp3y+WtZRAXOAfsQ/hl4qulH+gmPTRsViFf31fqXqMCxTMUxvF6kFvtVSdAHjaSlGoJKdKGkpdYAitbyiHN5qYlON0GOQOtFNkVrWUA7vLsphsjio4jvxhMVw39q2id2Jm4hzHbU0jCDQDluai5h1AFzzHxULZIOitYotUrQoUgue7fDi0eDlG+VLOJ7Yt0/vD9L7WQXF7MRpKi6raEWc76L+O1BFW729qM7dkFh1AOTpQf6JR+ieFq0F3ptStMmTcAix56HQr2gdN9RFzE60c5ic3cX+qjpHQ2LVcVbFVL19nTinmTwZQucKtUvgxejnJU9Cn+cksT5dNmiaohPNiHDXanum4qe17yJ2HWZb5uyitbdCt3Edl0XQHzJsJW7/IBsofGzMTjSYH06NbAgQu45q4nxydNqh9ZVCtylaS9AfMpj2+bKBwsc2RSeWm6/c43zcIc6HR40NJjvQ8ez2UbSWoD9k8LXjxRX6Ndlg8T93oi+fT7fJ47EJ+kMGXzsWy6HPlA0WsTtxKHGu87IhBzHrAK585no/Cl3iOjYLeDMnNg8oO6HvhD7dJk8nDqCwx3CM2DdZNuQgdA6824U8NvD9FtohrYeWyYqcB8C7R4o2eFmFCS+VLpYTt1fpffPy6SsEN2MU8Y0+QyXfCq2PKFlrMRMVxCzRJvGd08dIFRNV7KXSsfiCMIYa1mFWRhA7RZsLWcsGS3M9D1HLBKrv201cn6zFZjixF+/lmcC0VooWpqMR+GiMgrB9wzZpOqn4rOI58VcEzN4eqXhCvA74q2St4ynxs3Wz0CU45wspZvCV2G/XgW18q3O9ktwmfufFokIe3lPpvmAlS3aszQ/i8+L8qAP1YBv1YXHAxxHy56wHTJ+kmMEp4mNC/zlFwPLfEilWgNnEw2JRZhDfk0uyoZEgJ0a0IGbC4BoGXGT94srF9R9aCa6q6CxFiz7kvn6j4XESi55UrF9q32/sRe0sXBfRGDC5+SLFCtCBwtdlhje73m1aW2ppMXhDPATnph1xIV1lgwYfec3CrgnsYxG4sYRuXHOBH7Lv+g2DiesdTezFsxz7Wa9a5WBGx8JUkf9A/EuPJZ4tYZUCfyep6GibygSvIi2B3lLw0Jd4yo+Z9VzRFgv0A77OlAU657gUE80KZvYY+RKJRCLR9PwDFqR8qMz3SpQAAAAASUVORK5CYII=>

[image28]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAHEAAAAfCAYAAADQgCL6AAAE6klEQVR4Xu2aachtUxjHHzIPcVHm7itDlDEkH7ivIVNkyk0St5ShkDHFh2uO8EX5QEIKCZlJoQyZMoUkvhhDhgiRef3vs573POd/19pr7bPPu+/9sH/19J79/z97rbXXPmfttdZ+RQYGBgYGBgZKfBtilsWBXrksxNss1vJwiOdZHFghfBniVhZLHBviPxYnZI0Qf4qWZ/HRWEZ/YGTx7fgxxJpjGf3xjoy35a8Qm45ljIOco1lsAicsZnEC1hEtaxOnPRM1xGpOn29Q317u+LqoIbZweh+gztPc8QlRQxzodI+1t4qLpEVyAZRzOIuBn2TU6D74OcQVLAZekH7bAZ4K8TSLou0rtQXeuSymQOLjLE6INepi0ndzXh9YXU+yISNvhvT5wurDUM6Ydyobka+kos9mRJMWkT4p1qjr2ZCRtzsb84DV9TobMvLOY2Oe+E20vt/ZkFFbHmEjcr5U3MSbpCLJcVuIX0M867QP3eetQpzhjo11ZdTgSVkqev59TsMIAu1up4G1JX+TrB17sNECXPM/IY5nI7BqiKtJu4CODWsLblYKTBLhn8yG5xep69h9RfNuicc7xuPaG3OX1OemOCjESyFWES3Dnm07iE6W8PnEuew8S6RbOwDO3VjyE4/aPt1G6toC/y0WPTWF7CKa8wnpL0cdHVrC6tmJjUp8G62sjej4nLmMPJZ7EhuVYJJyQPyMoRplbTeyl1HTp+AP0bzSehA5GP2y1FSYy3lUVD+YDeID0bxT2GiB1W8jwvvO+0zSzxvmdqnrtCZ8P6T6Zf2ofUM6g+EReW+wkSBVzxilhGtE/e/ZkPK54FLRHPv2dsW+OIvYKDAreh6WU9NgRrQ8Hp1uiPrZpHs2F815kI0MxX4uJZh/HBtSPndW1N+W9C6U6kxhnXYEGx14T7RMPGo8mOxAx7M7hT2/l7LRQPGaSwk539Z9r7ERwSwV/gakvyI6GZmUXHtyrC6avzPp14Y4nbQ25NqR0w14PAE7JMS9pHlKZRYTcj42y6EfxkZgLVEP02MmVVYtu4qe/xwbDSB/SxZFn1mbsdiCVL8siNoPpBt/S/oN0f2y/I31oMzGic3HsnxjPKnGgpwOoGONdqbomvGsEBeGuDF6nu2jxnqKB0Tz9mcjA4a2y2W8HViP4VfI9WFtV9sOgDzcFM8dUU9tk2FOcadoGzACoE3ooytFz8E6Ogf8m1n0YLGKpNSvBmDTFv7CeGyLz9wF/yvjfio8NlFBHEkekzo/B7a4uF4Oj+2MIPBlK8FlXOI0fh6+6bxc5MCGBHysyxtBEn4pOexGI/BqZ8/4OTU95sZxpIaaT0WfrVeRzuD8L1jMwPWmgnlXdM2LTYUavpNRWdjJypXL9aYixz3S7M+BpNTmbI7HRM8p/XLagO2/LuvIaXGU6LDYlkNF++RFNjqCMp9gMYVNGHgYyFH69kwCXpCuDLwaYj0WHTbr5us3Dc/WaYF3sm3uy7JJgN/UbiJ1EV3A5Abv/1Y0eONfui4b3nx7baK0xGnT4GvRf9OoxtZTG7IRwb8R2MauBY6xCdyVUsf1Bb7Iues3sPeL9u4tmotnOY5TS60u2OjYmoWSPxE/6X1EZ0vYpcDf/URf+XQF66uVAezs1LC16JQfM+tjyJsWuA8T/ysLbs5DLA70yufS/A9UAwMDAwPT439yCbk1ncb5BQAAAABJRU5ErkJggg==>
