shader_type canvas_item;

uniform sampler2D tex : source_color, filter_nearest, repeat_enable;
uniform float tile_px = 192.0;
uniform vec2 drift = vec2(0.03, 0.0);
uniform float brightness = 0.5;
uniform float vignette = 0.55;
uniform vec3 tint = vec3(1.0, 1.0, 1.0);


void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 uv = UV * size / tile_px + drift * TIME;
	vec3 c = texture(tex, uv).rgb * tint * brightness;
	vec2 d = UV - vec2(0.5);
	float v = 1.0 - smoothstep(0.25, 0.85, length(d * vec2(1.0, 0.8))) * vignette;
	COLOR = vec4(c * v, 1.0);
}
