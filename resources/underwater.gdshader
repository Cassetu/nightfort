shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.04, 0.17, 0.2, 0.5);
uniform float vignette : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	vec2 c = UV - vec2(0.5);
	float edge = clamp(length(c) * 1.6, 0.0, 1.0);
	float a = tint.a * (1.0 + vignette * edge * edge);
	COLOR = vec4(tint.rgb * (1.0 - 0.5 * edge), clamp(a, 0.0, 0.85));
}
