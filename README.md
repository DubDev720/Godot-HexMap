# Godot-HexMap

Godot-HexMap is an open-source hex map tool system for **Godot 4.6.1+**.

It is currently in **active development** and is being built as a reusable foundation for hex-based workflows in Godot projects.

## Project Vision

The roadmap is to build a complete hex-tile-based map utility for Godot that mirrors core capabilities found in **TileMap2D** and **GridMap**, while extending them for hex-native workflows.

Planned direction includes:

- Hex map editing and runtime utilities aligned with Godot-style APIs
- Layered hex maps for multi-layered / multi-tiered spaces
- Composable multi-layer map structures for complex worlds
- Integrated custom property support on map data and cells

## Current Status

Implemented now (work in progress):

- Core hex math library (`HexLib`) adapted for Godot/GDScript usage
- Functional `HexMap` resource logic with q/r/s and tier-oriented coordinate support
- GridMap-style map APIs (`set_cell_item`, `get_cell_item`, `map_to_local`, `local_to_map`, etc.)
- Hex map editor utility singleton for map configuration and edit brush workflows
- Hex pathfinder utility singleton for A* path queries with signal-based results
- Demo/workbench scene with camera controls, picking, inspect/path/edit modes, and config-driven tuning

## Credits

This project draws heavily from the excellent hex grid research and reference material by:

- **Amit Patel (Red Blob Games)**  
  Website: https://www.redblobgames.com  
  Email: redblobgames@gmail.com

Huge thanks to Amit for publishing foundational, practical resources that make robust hex-grid implementation possible.

## Contact

If you'd like to contribute or collaborate, please email me at: **dubdev720@proton.me**
