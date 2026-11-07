shader_type spatial;

uniform sampler2DArray tiles : source_color, filter_nearest_mipmap, repeat_enable;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;

varying float layer;


vec3 to_linear(vec3 c) {
	vec3 lo = c / vec3(12.92);
	vec3 hi = pow((c + vec3(0.055)) / vec3(1.055), vec3(2.4));
	return mix(lo, hi, step(vec3(0.04045), c));
}


void vertex() {
	layer = UV2.x;
}


void fragment() {
	vec4 t = texture(tiles, vec3(UV, floor(layer + 0.5)));
	ALBEDO = t.rgb * to_linear(COLOR.rgb) * (1.0 - 0.22 * wetness);
	ROUGHNESS = mix(1.0, 0.2, wetness);
	CLEARCOAT = 0.8 * wetness;
	CLEARCOAT_ROUGHNESS = 0.08;
}
