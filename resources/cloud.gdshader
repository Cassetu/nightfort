shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

uniform vec2 offset = vec2(0.0);
uniform float cover : hint_range(0.0, 1.0) = 0.3;
uniform float darkness : hint_range(0.0, 1.0) = 0.0;
uniform vec3 tint : source_color = vec3(1.0);
uniform float cloud_scale = 0.0032;
uniform float fade_near = 250.0;
uniform float fade_far = 720.0;

varying vec3 world_pos;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = (world_pos.xz + offset) * cloud_scale;
	float n = fbm(p);
	float detail = fbm(p * 3.0 + 7.0);
	float thresh = mix(0.62, 0.2, cover);
	float density = smoothstep(thresh, thresh + 0.2, n + detail * 0.08);
	float thick = smoothstep(thresh, thresh + 0.45, n);
	float d = distance(world_pos.xz, CAMERA_POSITION_WORLD.xz);
	float fade = 1.0 - smoothstep(fade_near, fade_far, d);
	vec3 gray = vec3(0.3, 0.32, 0.36);
	vec3 col = mix(vec3(1.0), gray, clamp(thick * 0.6 + darkness * 0.85, 0.0, 1.0)) * tint;
	ALBEDO = col;
	ALPHA = density * fade * mix(0.8, 0.97, cover);
}
