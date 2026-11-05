shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform float sway = 0.12;
uniform float sway_height = 0.8;
uniform float wind_speed = 1.6;


vec3 to_linear(vec3 c) {
	vec3 lo = c / vec3(12.92);
	vec3 hi = pow((c + vec3(0.055)) / vec3(1.055), vec3(2.4));
	return mix(lo, hi, step(vec3(0.04045), c));
}


void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = origin.x * 0.45 + origin.z * 0.35;
	float weight = pow(clamp(VERTEX.y / sway_height, 0.0, 1.0), 1.5);
	float gust = sin(TIME * wind_speed + phase) + 0.5 * sin(TIME * wind_speed * 2.3 + phase * 1.7);
	VERTEX.x += gust * sway * weight;
	VERTEX.z += 0.6 * cos(TIME * wind_speed * 0.8 + phase) * sway * weight;
}


void fragment() {
	vec4 t = texture(albedo_tex, UV * uv_scale);
	if (t.a < 0.5) {
		discard;
	}
	ALBEDO = t.rgb * to_linear(COLOR.rgb);
	ROUGHNESS = 1.0;
	NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
}
