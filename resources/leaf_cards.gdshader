shader_type spatial;
render_mode cull_disabled;

uniform sampler2D card_tex : source_color, filter_nearest, repeat_disable;
uniform float cutoff = 0.5;
uniform float sway = 0.12;
uniform float sway_base = 1.4;
uniform float sway_span = 5.0;
uniform float wind_speed = 1.1;
uniform float flutter = 0.03;
uniform float soft_normal = 0.45;


vec3 to_linear(vec3 c) {
	vec3 lo = c / vec3(12.92);
	vec3 hi = pow((c + vec3(0.055)) / vec3(1.055), vec3(2.4));
	return mix(lo, hi, step(vec3(0.04045), c));
}


void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = origin.x * 0.45 + origin.z * 0.35;
	float weight = pow(clamp((VERTEX.y - sway_base) / sway_span, 0.0, 1.0), 1.4);
	float gust = sin(TIME * wind_speed + phase) + 0.5 * sin(TIME * wind_speed * 2.3 + phase * 1.7);
	float lift = sin(TIME * wind_speed * 0.7 + phase + 1.9);
	float ruffle = sin(TIME * 2.6 + dot(VERTEX, vec3(3.1, 4.7, 3.7)) + phase);
	VERTEX.x += gust * sway * weight + ruffle * flutter * (0.3 + weight);
	VERTEX.z += 0.6 * lift * sway * weight;
	VERTEX.y += 0.3 * gust * sway * weight;
}


void fragment() {
	vec4 t = texture(card_tex, UV);
	if (t.a < cutoff) {
		discard;
	}
	ALBEDO = t.rgb * to_linear(COLOR.rgb);
	ROUGHNESS = 1.0;
	vec3 n = FRONT_FACING ? NORMAL : -NORMAL;
	vec3 up = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	NORMAL = normalize(mix(n, up, soft_normal));
}
