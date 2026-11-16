shader_type canvas_item;
render_mode unshaded, blend_add;

// Filet doré de l'ouverture (Rugby Legacy 27, novembre 2026) : trait fin lumineux qui se trace depuis le
// centre (ou depuis la gauche), plus intense au milieu, extrémités qui s'effacent, tête brillante pendant
// le tracé. Sert aussi de jauge de chargement. Cible : GL Compatibility, aucune texture.

group_uniforms trace;
// Avancement du tracé (0..1).
uniform float progress = 1.0;
// 0 : depuis le centre vers les deux côtés ; 1 : depuis la gauche (jauge).
uniform float from_left = 0.0;
// Taille du rectangle en pixels, pour une épaisseur nette quelle que soit la mise à l'échelle.
uniform vec2 rect_size = vec2(900.0, 40.0);
uniform float thickness = 1.6;
uniform float intensity = 1.0;
uniform vec4 colour : source_color = vec4(0.843, 0.678, 0.349, 1.0);
group_uniforms;

void fragment() {
	vec4 tint = COLOR;
	float dy = abs(UV.y - 0.5) * rect_size.y;
	float along = mix(abs(UV.x - 0.5) * 2.0, UV.x, from_left);
	float drawn = smoothstep(progress + 0.004, progress - 0.004, along);
	// Le trait s'amincit vers ses extrémités (centre) ou reste plein (jauge).
	float taper = mix(1.0 - smoothstep(0.55, 1.0, along), 1.0, from_left);
	float line = exp(-pow(dy / thickness, 2.0)) + exp(-dy / (thickness * 4.0)) * 0.22;
	float head_dist = (along - progress) * rect_size.x * mix(0.5, 1.0, from_left);
	float head = exp(-(head_dist * head_dist) / 90.0 - dy * dy / 14.0) * step(progress, 0.995) * 1.4;
	float value = (line * drawn * taper + head) * intensity;
	COLOR = vec4(colour.rgb * value * tint.a, 1.0);
}
