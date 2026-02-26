shader_type spatial;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded, shadows_disabled;



// GlobalExpression:0
	
	uniform vec4 base_color : source_color = vec4(0.1, 0.2, 0.8, 1.0);
	uniform vec4 pulse_color : source_color = vec4(1.0, 0.3, 0.2, 1.0);
	uniform float blend_ratio : hint_range(0.0, 1.0) = 0.5;
	uniform float pulse_strength : hint_range(0.0, 1.0) = 1.0;
	uniform vec3 local_axis_dir = vec3(1.0, 1.0, 0.0); // object-space axis
	uniform float axis_frequency : hint_range(0.1, 50.0) = 8.0;
	uniform float pulse_speed : hint_range(0.0, 20.0) = 2.0;
	uniform float emissive_strength : hint_range(0.0, 8.0) = 2.5;
	

void fragment() {
	vec3 n_out3p0;
	float n_out3p1;
	vec3 n_out3p2;
// Expression:3
	n_out3p0 = vec3(0.0, 0.0, 0.0);
	n_out3p1 = 0.0;
	n_out3p2 = vec3(0.0, 0.0, 0.0);
	{
		
		float axis_pos = UV.y;
		float wave = 0.5 + 0.5 * sin(axis_pos * axis_frequency * TAU - TIME * abs(pulse_speed));
		float t = clamp(blend_ratio + (wave - 0.5) * pulse_strength, 0.0, 1.0);
		vec4 c = mix(base_color, pulse_color, t);
		n_out3p0 = c.rgb;
		n_out3p1 = c.a;
		n_out3p2 = c.rgb * emissive_strength;
		
	}


// Output:0
	ALBEDO = n_out3p0;
	ALPHA = n_out3p1;
	EMISSION = n_out3p2;


}
