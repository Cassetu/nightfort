shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float target_height = 270.0;
uniform float color_levels = 28.0;
uniform float dither_strength = 0.5;
uniform float desaturate = 0.12;
uniform float vignette_strength = 0.6;
uniform float vignette_inner = 0.3;
uniform float vignette_outer = 0.95;

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);


void fragment() {
	float cell = max(1.0, floor(1.0 / SCREEN_PIXEL_SIZE.y / target_height + 0.5));
	vec2 px = floor(FRAGCOORD.xy / cell);
	vec2 uv = (px * cell + vec2(cell * 0.5)) * SCREEN_PIXEL_SIZE;
	vec3 col = texture(screen_tex, uv).rgb;

	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, 1.0 - desaturate);

	int bx = int(mod(px.x, 4.0));
	int by = int(mod(px.y, 4.0));
	float threshold = BAYER[by * 4 + bx] / 16.0 - 0.5;
	col += threshold * dither_strength / color_levels;
	col = floor(col * color_levels + 0.5) / color_levels;

	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 q = (SCREEN_UV - 0.5) * vec2(aspect, 1.0);
	float v = smoothstep(vignette_inner, vignette_outer, length(q));
	col *= 1.0 - vignette_strength * v;

	COLOR = vec4(col, 1.0);
}
