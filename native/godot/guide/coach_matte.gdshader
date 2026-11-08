shader_type canvas_item;
// Runtime matte only: the original opaque atlas remains byte-for-byte unchanged.
void fragment() {
	vec4 sample_color = texture(TEXTURE, UV);
	float distance_to_paper = distance(sample_color.rgb, vec3(0.141, 0.137, 0.161));
	float matte = smoothstep(0.032, 0.078, distance_to_paper);
	COLOR.a *= matte;
}
