shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform vec4 building_color : source_color;
uniform vec4 platform_color : source_color;
uniform vec4 ground_color : source_color;
uniform vec4 highlight_color : source_color;
uniform vec4 ink_color : source_color;
uniform bool outline_enabled = false;
uniform bool toon_enabled = false;
uniform float outline_pixels = 1.3;
uniform int toon_steps = 3;
instance uniform int color_role = 0;
instance uniform vec3 shape_size = vec3(1.0);
instance uniform bool ramp_shape = false;
varying vec3 local_position;

void vertex() {
	local_position = VERTEX;
}

// Second-nearest face gives the distance to a real edge, without extra geometry.
float edge_distance(vec3 p, vec3 h) {
	vec3 d = abs(abs(p) - h);
	if (!ramp_shape) {
		return min(max(d.x, d.y), min(max(d.x, d.z), max(d.y, d.z)));
	}
	float slope = h.y / max(h.z, 0.0001);
	vec4 r = vec4(d.x, abs(p.y + h.y), abs(p.z + h.z),
		abs(p.y + slope * p.z) / sqrt(1.0 + slope * slope));
	return min(min(max(r.x, r.y), max(r.x, r.z)),
		min(min(max(r.x, r.w), max(r.y, r.z)), min(max(r.y, r.w), max(r.z, r.w))));
}

void fragment() {
	vec3 face_normal = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	NORMAL = dot(face_normal, NORMAL) < 0.0 ? -face_normal : face_normal;
	vec3 base = building_color.rgb;
	if (color_role == 1) { base = platform_color.rgb; }
	if (color_role == 2) { base = ground_color.rgb; }
	if (color_role == 3) { base = highlight_color.rgb; }
	float edge = edge_distance(local_position, shape_size * 0.5);
	float pixel = max(fwidth(edge), 0.0001);
	float border = outline_enabled ? 1.0 - smoothstep(pixel * outline_pixels,
		pixel * (outline_pixels + 0.8), edge) : 0.0;
	ALBEDO = mix(base, ink_color.rgb, border);
	ROUGHNESS = 1.0;
}

void light() {
	float diffuse = max(dot(NORMAL, LIGHT), 0.0);
	if (toon_enabled) {
		float bands = float(max(toon_steps - 1, 1));
		diffuse = floor(diffuse * bands + 0.5) / bands;
	}
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * diffuse / PI;
}
