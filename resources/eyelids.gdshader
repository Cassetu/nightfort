shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float open : hint_range(0.0, 1.0) = 0.0;
uniform float blur : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float lens = abs(uv.x - 0.5) * 2.0;
	float shape = 1.0 - lens * lens * 0.55;
	float gap = open * (shape + (1.0 - shape) * open * open) * 1.1;
	float dist = abs(uv.y - 0.5) * 2.0;
	float lid = smoothstep(gap - 0.08, gap, dist);
	vec3 col = textureLod(screen_tex, uv, blur * 5.0).rgb;
	col *= 1.0 - blur * 0.25;
	COLOR = vec4(mix(col, vec3(0.0), lid), 1.0);
}
