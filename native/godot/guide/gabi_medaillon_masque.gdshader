shader_type canvas_item;
// Disque du médaillon de Gabi : bord adouci d'un pixel environ.
void fragment() {
	vec4 colour = texture(TEXTURE, UV);
	float d = distance(UV, vec2(0.5));
	float edge = fwidth(d) * 1.5;
	colour.a *= 1.0 - smoothstep(0.5 - edge, 0.5, d);
	COLOR = colour;
}
