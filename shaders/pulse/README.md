# Pulse Shaders

This folder contains three pulse shaders authored as VisualShader resources for quick visual experimentation.

## Files

- `canvas_item_pulse.tres`
- `spatial_pulse_world_axis.tres`
- `spatial_pulse_local_axis.tres`

## Shared Parameters

- `base_color`: baseline color.
- `pulse_color`: pulse color.
- `blend_ratio` (`0..1`): midpoint blend.
  - `0.5` means evenly centered blend.
- `pulse_strength` (`0..1`): how strongly the wave deviates from `blend_ratio`.
- `axis_frequency`: number of wave cycles along axis.
- `pulse_speed`: animation speed over time.

Blend logic:

- Wave is computed as a sine in the `0..1` range.
- Final mix value is:
  - `mix_amount = clamp(blend_ratio + (wave - 0.5) * pulse_strength, 0, 1)`

## Which Shader To Use

- `canvas_item_pulse.tres`
  - For 2D nodes (`Sprite2D`, `TextureRect`, `Control` with `CanvasItemMaterial` shader).
  - Axis is in UV space (`axis_dir: vec2`).

- `spatial_pulse_world_axis.tres`
  - For 3D meshes where pulse should align to world coordinates.
  - Axis is world-space (`axis_dir: vec3`).
  - Good when multiple path meshes should share one global pulse direction.

- `spatial_pulse_local_axis.tres`
  - For 3D meshes where pulse should follow each mesh's local orientation.
  - Axis is object-space (`local_axis_dir: vec3`).
  - Good for dynamically generated path segments that each have their own transform.

## Quick Usage In Godot

1. Create `ShaderMaterial`.
2. Assign one shader file from this folder.
3. Assign material to target node.
4. Tune:
   - `blend_ratio = 0.5`
   - `pulse_strength = 1.0`
   - `axis_frequency` between `4..12`
   - `pulse_speed` between `1..4`

## Path Mesh Experiment Starter (GDScript)

```gdscript
var mat := ShaderMaterial.new()
mat.shader = load("res://shaders/pulse/spatial_pulse_local_axis.tres")
mat.set_shader_parameter("base_color", Color(0.12, 0.28, 0.85, 1.0))
mat.set_shader_parameter("pulse_color", Color(1.0, 0.3, 0.2, 1.0))
mat.set_shader_parameter("blend_ratio", 0.5)
mat.set_shader_parameter("pulse_strength", 1.0)
mat.set_shader_parameter("local_axis_dir", Vector3(1, 0, 0))
mat.set_shader_parameter("axis_frequency", 8.0)
mat.set_shader_parameter("pulse_speed", 2.0)

$YourPathMeshInstance.material_override = mat
```

If your generated segment runs along local Z instead of X, set `local_axis_dir` to `Vector3(0, 0, 1)`.
