shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

uniform vec3 tint : source_color = vec3(0.42, 0.95, 0.58);
uniform float intensity : hint_range(0.0, 4.0) = 1.15;
uniform float pulse_speed = 2.4;
uniform float pulse_length = 3.4;
uniform float twist = 34.0;
uniform float near_fade_start = 0.3;
uniform float near_fade_end = 1.4;

varying float view_depth;


void vertex() {
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view_depth = -view_pos.z;
}


void fragment() {
	float across = UV.y * 2.0 - 1.0;
	float a = abs(across);
	float core = smoothstep(0.5, 0.0, a);
	float halo = exp(-a * a * 3.2);
	float strand = 0.78 + 0.22 * sin(UV.x * twist + across * 2.6);
	float wave = 0.5 + 0.5 * sin(UV.x / pulse_length * 6.2831853 + TIME * pulse_speed);
	float pulse = pow(wave, 5.0);
	float rope = (core * strand * 0.8 + halo * 0.2) * (0.5 + 1.2 * pulse);

	vec2 q = vec2(across, UV.x * 2.0 - 1.0);
	float bead = exp(-dot(q, q) * 4.5) * 0.85;

	float v = mix(rope, bead, COLOR.a);
	float near = smoothstep(near_fade_start, near_fade_end, view_depth);
	ALBEDO = tint * intensity * v * near;
	ALPHA = 1.0;
}
