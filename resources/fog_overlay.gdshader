shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.24, 0.04, 0.34, 1.0);


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


void fragment() {
	vec2 d = UV - vec2(0.5);
	float vig = smoothstep(0.12, 0.78, length(d * vec2(1.25, 1.0)));
	float n = noise(UV * 5.0 + vec2(TIME * 0.07, -TIME * 0.05));
	n = n * 0.7 + noise(UV * 11.0 - vec2(TIME * 0.05, TIME * 0.09)) * 0.3;
	float a = intensity * (0.26 + 0.5 * vig + 0.2 * n);
	COLOR = vec4(tint.rgb * (0.65 + 0.7 * n), clamp(a, 0.0, 0.88));
}
