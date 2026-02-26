	shader_type spatial;

// Purpose/Goal: Pulse between two colors along a world-space axis on 3D meshes.
// Design Pattern/Principle: World-position projection + time-domain sine blend.
// Source/Reference: In-project shader utility for movement path rendering prototypes.
// Expected Behavior/Usage: Attach to MeshInstance3D material when pulse should stay aligned to world axis.
// Scope: Albedo/alpha animation only; no normals/lighting customization.
// Break Risks: Zero-length axis_dir will produce invalid normalization.
// Timestamp: 2026-02-25 19:49:00 UTC

uniform vec4 base_color : source_color = vec4(0.1, 0.2, 0.8, 1.0);
uniform vec4 pulse_color : source_color = vec4(1.0, 0.3, 0.2, 1.0);

// 0.5 = even blend baseline
uniform float blend_ratio : hint_range(0.0, 1.0) = 0.5;
uniform float pulse_strength : hint_range(0.0, 1.0) = 1.0;

uniform vec3 axis_dir = vec3(1.0, 0.0, 0.0); // world X
uniform float axis_frequency : hint_range(0.1, 50.0) = 8.0;
uniform float pulse_speed : hint_range(0.0, 20.0) = 2.0;

varying vec3 world_pos_v;

void vertex() {
	world_pos_v = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 dir = normalize(axis_dir);
	float axis_pos = dot(world_pos_v, dir);
	float wave = 0.5 + 0.5 * sin(axis_pos * axis_frequency * TAU + TIME * pulse_speed);
	float t = clamp(blend_ratio + (wave - 0.5) * pulse_strength, 0.0, 1.0);
	vec4 c = mix(base_color, pulse_color, t);

	ALBEDO = c.rgb;
	ALPHA = c.a;
}
