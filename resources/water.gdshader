shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec3 shallow_color : source_color = vec3(0.19, 0.36, 0.33);
uniform vec3 deep_color : source_color = vec3(0.035, 0.12, 0.15);
uniform vec3 foam_color : source_color = vec3(0.82, 0.87, 0.85);
uniform vec2 wind_dir = vec2(0.82, 0.57);
uniform float depth_scale : hint_range(0.5, 8.0) = 2.4;
uniform float foam_width : hint_range(0.05, 1.5) = 0.4;
uniform float crest_foam : hint_range(0.4, 0.95) = 0.74;
uniform float shallow_alpha : hint_range(0.0, 1.0) = 0.4;
uniform float deep_alpha : hint_range(0.0, 1.0) = 0.9;
uniform float wave_amp : hint_range(0.0, 0.3) = 0.1;
uniform float drift_speed : hint_range(0.0, 2.0) = 0.45;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;

varying vec3 world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 r = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 3; i++) {
		v += vnoise(p) * a;
		p = r * p * 2.03 + 11.7;
		a *= 0.5;
	}
	return v / 0.875;
}

float crest(float x) {
	float s = 1.0 - abs(sin(x));
	return s * s;
}

vec2 turn(vec2 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

float height(vec2 p, vec2 w, float t) {
	vec2 q = vec2(dot(p, w), dot(p, vec2(-w.y, w.x)));
	float warp = fbm(q * vec2(0.16, 0.38) - vec2(t * 0.4, 0.0)) * 3.2;
	float c1 = crest(q.x * 1.05 - t * 1.5 + warp + q.y * 0.22);
	float c2 = crest(dot(p, turn(w, 0.85)) * 1.65 - t * 1.9 + warp * 1.4);
	float c3 = crest(dot(p, turn(w, -0.7)) * 2.6 - t * 2.4 + warp * 0.8);
	float detail = fbm(q * vec2(2.4, 3.6) - vec2(t * 1.1, 0.0));
	return c1 * 0.46 + c2 * 0.28 + c3 * 0.16 + detail * 0.14;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME * drift_speed;
	vec2 w = normalize(wind_dir);
	vec2 p = world_pos.xz;
	float h0 = height(p, w, t);
	float hx = height(p + vec2(0.07, 0.0), w, t);
	float hz = height(p + vec2(0.0, 0.07), w, t);
	float far_fade = smoothstep(16.0, 85.0, length(VERTEX));
	vec2 g = vec2(hx - h0, hz - h0) / 0.07 * wave_amp * (1.0 - 0.9 * far_fade);
	vec3 n_world = normalize(vec3(-g.x, 1.0, -g.y));
	vec3 n_view = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	NORMAL = FRONT_FACING ? n_view : -n_view;

	float depth = texture(depth_tex, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 scene = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	scene.xyz /= scene.w;
	float thick = max(-scene.z + VERTEX.z, 0.0);

	vec2 q = vec2(dot(p, w), dot(p, vec2(-w.y, w.x)));
	float patch_noise = fbm(q * 0.11 + 7.0);
	float deep = 1.0 - exp(-thick / depth_scale);
	vec3 col = mix(shallow_color, deep_color, deep);
	col = mix(col * 0.82, col * 1.22, patch_noise);

	float breakup = fbm(q * vec2(2.2, 3.4) - vec2(t * 0.9, 0.0));
	float streak = fbm(q * vec2(5.5, 11.0) - vec2(t * 1.6, 0.0));
	float crest_mask = smoothstep(crest_foam, crest_foam + 0.16, h0 + (breakup - 0.5) * 0.34);
	crest_mask *= (0.45 + 0.55 * smoothstep(0.25, 0.7, streak)) * (1.0 - 0.85 * far_fade);
	float shore_break = fbm(q * vec2(3.0, 3.0) - vec2(t * 0.7, 0.0));
	float shore = (1.0 - smoothstep(0.0, foam_width * (0.55 + 0.9 * shore_break), thick)) * (0.5 + 0.5 * smoothstep(0.2, 0.7, streak));
	float foam = clamp(crest_mask * (0.35 + 0.65 * (1.0 - deep * 0.4)) + shore * (1.0 - 0.6 * far_fade), 0.0, 1.0);

	ALBEDO = mix(col, foam_color, foam);
	ALPHA = clamp(mix(shallow_alpha, deep_alpha, deep) + foam * 0.5, 0.0, 0.97);
	ROUGHNESS = mix(0.06, 0.6, foam);
	SPECULAR = 0.6;
	METALLIC = 0.0;
	EMISSION = col * 0.06 + foam_color * foam * 0.05;

	if (!FRONT_FACING) {
		ALBEDO = deep_color * 1.6;
		ALPHA = 0.5;
		ROUGHNESS = 0.2;
		EMISSION = deep_color * 0.5;
	}
}
