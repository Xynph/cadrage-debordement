shader_type canvas_item;
render_mode unshaded;

// Keep the approved black-background master intact; composite it in the UI.
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float lightness = max(max(source.r, source.g), source.b);
	float coverage = smoothstep(0.025, 0.18, lightness);
	COLOR = vec4(source.rgb, source.a * coverage);
}
