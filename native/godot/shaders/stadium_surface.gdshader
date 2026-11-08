shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform float micro_detail : hint_range(0.0, 0.2) = 0.1;
varying vec3 ground_position;
void vertex() {
	ground_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
void fragment() {
	vec2 p = ground_position.xz;
	float stripe = mod(floor((p.x + 55.0) / 10.0), 2.0);
	// Mowing bands support tactical orientation without overwhelming the lines.
	vec3 grass = mix(vec3(0.124, 0.237, 0.132), vec3(0.139, 0.257, 0.146), stripe);
	// Fine blades fade with projected pixel size, preventing distant shimmer.
	float grain = hash21(floor(p * vec2(25.0, 45.0))) - 0.5;
	float detail = 1.0 - smoothstep(0.025, 0.14, length(fwidth(p)));
	float broad = sin(p.x * 0.51 + sin(p.y * 0.37)) * sin(p.y * 0.63);
	// Restrained, static variation in the turf; no weather or match wear inferred.
	float field = sin(p.x * 0.17 + p.y * 0.11) * sin(p.y * 0.24 - p.x * 0.09);
	ALBEDO = grass * (1.0 + broad * 0.035 + field * 0.025 + grain * detail * micro_detail);
	ROUGHNESS = 1.0;
}
