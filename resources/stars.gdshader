shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float rotation = 0.0;
uniform float density : hint_range(0.0, 1.0) = 0.09;
uniform float grid = 52.0;
uniform float brightness = 1.7;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 0.000001, 1.0);
}

void fragment() {
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, 1.0);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	vec3 dir = normalize((INV_VIEW_MATRIX * vec4(view.xyz, 0.0)).xyz);

	float horizon = smoothstep(0.0, 0.22, dir.y);
	float c = cos(rotation);
	float s = sin(rotation);
	vec3 d = vec3(dir.x, dir.y * c - dir.z * s, dir.y * s + dir.z * c);

	vec3 a = abs(d);
	float m = max(a.x, max(a.y, a.z));
	vec2 uv;
	float face;
	if (a.x >= m) {
		uv = d.yz / a.x;
		face = d.x > 0.0 ? 0.0 : 1.0;
	} else if (a.y >= m) {
		uv = d.xz / a.y;
		face = d.y > 0.0 ? 2.0 : 3.0;
	} else {
		uv = d.xy / a.z;
		face = d.z > 0.0 ? 4.0 : 5.0;
	}

	vec2 p = uv * grid;
	vec2 id = floor(p);
	vec2 f = fract(p);
	float roll = hash13(vec3(id, face));
	float star = 0.0;
	vec3 tint = vec3(1.0);
	if (roll < density) {
		vec3 r = hash33(vec3(id, face + 7.0));
		vec2 center = 0.2 + 0.6 * r.xy;
		float px = max(length(fwidth(p)), 0.0001);
		float radius = px * mix(0.9, 2.1, r.z * r.z);
		float body = smoothstep(radius, 0.0, length(f - center));
		float twinkle = 0.78 + 0.22 * sin(TIME * (1.2 + r.x * 3.0) + r.y * 40.0);
		float level = mix(0.3, 1.0, r.z * r.z * r.z);
		star = body * twinkle * level;
		tint = mix(vec3(0.72, 0.82, 1.0), vec3(1.0, 0.88, 0.72), r.y);
	}

	ALBEDO = tint * star * brightness * horizon * strength;
}
