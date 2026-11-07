shader_type spatial;

uniform sampler2DArray tiles : source_color, filter_nearest_mipmap, repeat_enable;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform float puddle_scale = 0.16;
uniform float puddle_cut = 0.56;
uniform sampler2D roof_map : filter_nearest, repeat_disable;
uniform vec2 roof_origin = vec2(0.0);
uniform float roof_size = 96.0;
uniform float roof_ready = 0.0;

varying float layer;
varying vec3 wpos;
varying float flat_up;
varying vec3 wnorm;


vec3 to_linear(vec3 c) {
	vec3 lo = c / vec3(12.92);
	vec3 hi = pow((c + vec3(0.055)) / vec3(1.055), vec3(2.4));
	return mix(lo, hi, step(vec3(0.04045), c));
}


float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}


float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}


void vertex() {
	layer = UV2.x;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	flat_up = wnorm.y;
}


void fragment() {
	vec4 t = texture(tiles, vec3(UV, floor(layer + 0.5)));
	float n = noise(wpos.xz * puddle_scale) * 0.65 + noise(wpos.xz * puddle_scale * 2.7 + 7.0) * 0.35;
	float top = smoothstep(0.85, 0.98, flat_up);
	float ex = 1.0;
	if (roof_ready > 0.5) {
		vec2 uv = (wpos.xz + wnorm.xz * 0.2 - roof_origin) / roof_size;
		if (uv.x > 0.0 && uv.y > 0.0 && uv.x < 1.0 && uv.y < 1.0) {
			float roof = texture(roof_map, uv).r;
			ex = smoothstep(roof - 1.3, roof - 0.5, wpos.y);
		}
	}
	float wet = wetness * ex;
	float soak = smoothstep(0.35, 1.0, wet);
	float puddle = smoothstep(puddle_cut, puddle_cut + 0.1, n) * top * soak;
	float damp = wet * (1.0 - puddle);
	vec3 base = t.rgb * to_linear(COLOR.rgb);
	base *= 1.0 - 0.2 * damp - 0.5 * puddle;
	ALBEDO = base;
	float grain = noise(wpos.xz * 2.3 + vec2(TIME * 0.04, -TIME * 0.03));
	float ripple = noise(wpos.xz * 5.5 + vec2(-TIME * 0.12, TIME * 0.09));
	float puddle_rough = 0.16 + 0.22 * grain + 0.08 * ripple;
	ROUGHNESS = mix(mix(1.0, 0.5, wet), puddle_rough, puddle);
	SPECULAR = mix(0.5, 0.7, puddle);
	CLEARCOAT = 0.2 * damp;
	CLEARCOAT_ROUGHNESS = 0.32;
	if (puddle > 0.01 && flat_up > 0.9) {
		vec3 wn = normalize(vec3((grain - 0.5) * 0.22 * puddle, 1.0, (ripple - 0.5) * 0.22 * puddle));
		NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	}
}
