shader_type canvas_item;
// Recoloration d'une carte d'ombres grise (banque d'images : maillots, écussons) aux couleurs d'un club.
// TEXTURE : carte d'ombres achromatique avec alpha ; masque : blanc = couleur du club, noir = encre de contraste.
// Le relief (plis, coutures) vient de la luminance de la carte, ramenée autour de `gris_moyen`.
uniform sampler2D masque : filter_linear;
uniform vec4 couleur_base : source_color = vec4(0.12, 0.36, 0.26, 1.0);
uniform vec4 couleur_motif : source_color = vec4(0.91, 0.90, 0.86, 1.0);
uniform float gris_moyen = 0.62;
uniform float relief = 1.0;

void fragment() {
	vec4 carte = texture(TEXTURE, UV);
	float lum = dot(carte.rgb, vec3(0.299, 0.587, 0.114));
	float ombre = mix(1.0, lum / gris_moyen, relief);
	float m = texture(masque, UV).r;
	// Blanc du masque : zones recolorables (couleur du club) ; noir : motif, col et liserés (encre de contraste).
	vec3 teinte = mix(couleur_motif.rgb, couleur_base.rgb, step(0.5, m));
	// Hautes lumières : un peu de blanc au-dessus de 1 pour garder la brillance du tissu.
	vec3 c = teinte * min(ombre, 1.0) + max(ombre - 1.0, 0.0) * vec3(0.55);
	COLOR = vec4(clamp(c, 0.0, 1.0), carte.a * COLOR.a);
}
