shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;
uniform vec4 climb_color : source_color;
uniform vec4 jump_color : source_color;
uniform vec4 ink_color : source_color;
uniform float outline_pixels = 1.0;
instance uniform bool climb_marker = true;
instance uniform vec3 shape_size = vec3(1.0);
varying vec3 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	vec3 d = abs(abs(local_position) - shape_size * 0.5);
	float edge = min(max(d.x, d.y), min(max(d.x, d.z), max(d.y, d.z)));
	float pixel = max(fwidth(edge), 0.0001);
	float border = 1.0 - smoothstep(pixel * outline_pixels, pixel * (outline_pixels + 0.6), edge);
	ALBEDO = mix(climb_marker ? climb_color.rgb : jump_color.rgb, ink_color.rgb, border);
}
