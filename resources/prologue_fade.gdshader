shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur : hint_range(0.0, 1.0) = 0.0;
uniform float dark : hint_range(0.0, 1.0) = 0.0;
uniform float red : hint_range(0.0, 1.0) = 0.0;


void fragment() {
	vec3 col = textureLod(screen_tex, SCREEN_UV, blur * 5.5).rgb;
	float edge = smoothstep(0.2, 0.85, length(SCREEN_UV - vec2(0.5)) * 1.45);
	col = mix(col, col * vec3(1.0, 0.5, 0.5), red * 0.5);
	col = mix(col, vec3(0.5, 0.0, 0.02), red * edge * 0.8);
	col *= 1.0 - dark;
	COLOR = vec4(col, 1.0);
}
