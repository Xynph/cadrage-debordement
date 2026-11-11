shader_type spatial;
render_mode unshaded;

uniform vec4 marker_color : source_color;
uniform vec4 outline_color : source_color;
varying vec2 local_offset;

void vertex() {
	local_offset = VERTEX.xz;
}

void fragment() {
	float radius = length(local_offset);
	float softness = max(fwidth(radius) * 0.25, 0.005);
	float outline = smoothstep(0.41 - softness, 0.41 + softness, radius);
	ALBEDO = mix(marker_color.rgb, outline_color.rgb, outline);
}
