class_name DemoConfigPathfinderSwap
extends DemoConfig
## Purpose/Goal: Provide a demo config variant with swappable pathfinding utility and material-aware pathfinding config.
## Design Pattern/Principle: Composition extension over `DemoConfig` with explicit utility injection points.
## Source/Reference: `demo_config.gd` and pathfinding utility autoload contract used by `hex_demo.gd`.
## Expected Behavior/Usage: Use this resource to switch between legacy and material-aware pathfinder script utilities without editing runtime code.
## Scope: Config wiring only; does not run pathfinding or render path meshes itself.
## Break Risks: Assigning a script without `request_path` + `path_result_ready` contract will break dependent systems.
## Timestamp: 2026-02-26 00:25:00 UTC

const PathfindingMaterialConfigTemplate: PathfindingMaterialConfigSchema = preload("res://hex_map/core/config/templates/pathfinding_material_config_template.tres")

@export var pathfinding_utility_script: Script = preload("res://hex_map/gameplay/services/hex_pathfinder.gd")
@export var alternate_pathfinding_utility_script: Script = preload("res://hex_map/gameplay/services/hex_pathfinder_material.gd")
@export var material_pathfinding_config: Resource = PathfindingMaterialConfigTemplate
