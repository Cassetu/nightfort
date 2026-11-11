shader_type sky;

uniform vec3 zenith : source_color = vec3(0.06, 0.015, 0.13);
uniform vec3 mid : source_color = vec3(0.26, 0.04, 0.2);
uniform vec3 horizon : source_color = vec3(0.52, 0.05, 0.07);
uniform float flash : hint_range(0.0, 1.0) = 0.0;


float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(7.1, 3.7);
		a *= 0.5;
	}
	return v;
}


void sky() {
	vec3 dir = EYEDIR;
	float h = clamp(dir.y, 0.0, 1.0);
	vec3 col = mix(horizon, mid, smoothstep(0.0, 0.3, h));
	col = mix(col, zenith, smoothstep(0.2, 0.85, h));
	float cover = 0.0;
	if (dir.y > 0.0) {
		vec2 uv = dir.xz / (dir.y + 0.3) * 1.6 + vec2(TIME * 0.015, TIME * 0.007);
		float c = fbm(uv * 1.8);
		cover = smoothstep(0.38, 0.78, c) * smoothstep(0.0, 0.22, dir.y);
		vec3 cloud = mix(vec3(0.04, 0.008, 0.05), vec3(0.4, 0.07, 0.13), smoothstep(0.4, 0.9, c));
		col = mix(col, cloud, cover * 0.9);
	}
	float below = 1.0 - smoothstep(-0.35, 0.0, dir.y);
	col = mix(col, vec3(0.1, 0.01, 0.02), below);
	col += vec3(0.85, 0.55, 0.95) * flash * (0.35 + 0.65 * cover);
	COLOR = col;
}
