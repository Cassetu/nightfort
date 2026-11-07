shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

uniform vec4 fog_color : source_color = vec4(0.2, 0.04, 0.3, 1.0);
uniform float density : hint_range(0.0, 1.0) = 0.6;
uniform float level : hint_range(0.0, 1.0) = 1.0;
uniform float fog_height = 9.0;
uniform float noise_scale = 0.085;
uniform float drift_speed = 0.05;
uniform float seed_offset = 0.0;

varying vec3 wpos;
varying float h01;


float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}


float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i + vec3(0.0, 0.0, 0.0)), hash(i + vec3(1.0, 0.0, 0.0)), f.x),
			mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), f.x),
			mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y),
		f.z);
}


void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	h01 = VERTEX.y / fog_height + 0.5;
}


void fragment() {
	vec3 p = wpos * noise_scale + vec3(seed_offset);
	float n = noise(p + vec3(TIME * drift_speed, 0.0, TIME * drift_speed * 0.6));
	n = n * 0.65 + noise(p * 2.3 + vec3(0.0, TIME * drift_speed * 1.4, 0.0)) * 0.35;
	float up = clamp(h01, 0.0, 1.0);
	float vert = pow(1.0 - up, 1.6);
	float foot = smoothstep(0.0, 0.06, up);
	float a = density * level * vert * foot * smoothstep(0.2, 0.7, n + 0.18);
	ALBEDO = fog_color.rgb * (0.65 + 0.7 * n);
	ALPHA = clamp(a, 0.0, 0.9);
}
