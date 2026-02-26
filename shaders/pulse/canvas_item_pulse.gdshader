shader_type canvas_item;

// Purpose/Goal: Pulse between two colors along a configurable 2D axis.
// Design Pattern/Principle: Time-driven sine wave mapped to UV projection.
// Source/Reference: In-project shader utility for path visualization experiments.
// Expected Behavior/Usage: Attach to Sprite2D/Control materials for animated directional pulse.
// Scope: Color blending only; no geometry or texture sampling logic.
// Break Risks: Zero-length axis_dir will produce invalid normalization.
// Timestamp: 2026-02-25 19:49:00 UTC

uniform vec4 base_color : source_color = vec4(0.1, 0.2, 0.8, 1.0);
uniform vec4 pulse_color : source_color = vec4(1.0, 0.3, 0.2, 1.0);

// 0.5 = even blend baseline
uniform float blend_ratio : hint_range(0.0, 1.0) = 0.5;
uniform float pulse_strength : hint_range(0.0, 1.0) = 1.0;

uniform vec2 axis_dir = vec2(1.0, 0.0); // X axis
uniform float axis_frequency : hint_range(0.1, 50.0) = 8.0;
uniform float pulse_speed : hint_range(0.0, 20.0) = 2.0;

void fragment() {
	vec2 dir = normalize(axis_dir);
	float axis_pos = dot(UV, dir);
	float wave = 0.5 + 0.5 * sin(axis_pos * axis_frequency * TAU + TIME * pulse_speed);
	float t = clamp(blend_ratio + (wave - 0.5) * pulse_strength, 0.0, 1.0);
	COLOR = mix(base_color, pulse_color, t);
}
