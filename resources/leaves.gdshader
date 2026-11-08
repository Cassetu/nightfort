shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec2 uv_scale = vec2(4.0, 3.0);
uniform float sway = 0.14;
uniform float sway_base = 1.4;
uniform float sway_span = 5.0;
uniform float wind_speed = 1.1;
uniform float lump = 0.07;
uniform float flutter = 0.035;
uniform float ragged = 1.0;
uniform vec2 leaf_cells = vec2(60.0, 22.0);
uniform float hole_cut = 0.86;
uniform float soft_normal = 0.5;


vec3 to_linear(vec3 c) {
	vec3 lo = c / vec3(12.92);
	vec3 hi = pow((c + vec3(0.055)) / vec3(1.055), vec3(2.4));
	return mix(lo, hi, step(vec3(0.04045), c));
}


float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = origin.x * 0.45 + origin.z * 0.35;
	float weight = pow(clamp((VERTEX.y - sway_base) / sway_span, 0.0, 1.0), 1.4);
	float gust = sin(TIME * wind_speed + phase) + 0.5 * sin(TIME * wind_speed * 2.3 + phase * 1.7);
	float lift = sin(TIME * wind_speed * 0.7 + phase + 1.9);
	float bumps = sin(VERTEX.x * 5.3 + VERTEX.y * 3.1) + sin(VERTEX.z * 6.1 - VERTEX.y * 4.3 + 1.7);
	float ruffle = sin(TIME * 2.6 + dot(VERTEX, vec3(3.1, 4.7, 3.7)) + phase);
	VERTEX += NORMAL * (bumps * lump * 0.5 + ruffle * flutter * (0.4 + weight));
	VERTEX.x += gust * sway * weight;
	VERTEX.z += 0.6 * lift * sway * weight;
	VERTEX.y += 0.3 * gust * sway * weight;
}


float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}


void fragment() {
	vec2 tuv = UV * uv_scale;
	float tone = 1.0;
	vec3 glow = vec3(0.0);
	if (ragged > 0.5) {
		vec2 cell = floor(UV * leaf_cells);
		float h = hash(cell);
		float clump = vnoise(cell * 0.5 + vec2(7.0, 3.0));
		float edge_px = min(UV.y, 1.0 - UV.y) * leaf_cells.y;
		float fringe = edge_px + (h - 0.5) * 3.2 + (clump - 0.5) * 2.0;
		float hole_score = 0.55 * clump + 0.45 * hash(cell + vec2(17.0, 5.0));
		if (fringe < 0.4 || hole_score > hole_cut) {
			discard;
		}
		tuv = cell / 16.0;
		tone = 0.72 + 0.5 * h + 0.25 * (clump - 0.5);
		glow = vec3(0.16, 0.14, 0.0) * step(0.9, hash(cell + vec2(3.0, 9.0)));
	}
	vec4 t = texture(albedo_tex, tuv);
	ALBEDO = (t.rgb * to_linear(COLOR.rgb) + glow) * tone;
	ROUGHNESS = 1.0;
	vec3 up = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	NORMAL = normalize(mix(NORMAL, up, soft_normal));
}
