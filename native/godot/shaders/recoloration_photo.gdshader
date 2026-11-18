shader_type canvas_item;
// Photo de la banque aux tenues grises neutres : recolore notre équipe (masque « nous ») et l'adversaire
// (masque « eux ») aux couleurs des clubs. Seuls les pixels peu saturés du masque changent (tissu gris) :
// peau, pelouse et lumières gardent leurs couleurs, même si le masque déborde un peu.
uniform sampler2D masque_nous : filter_linear;
uniform sampler2D masque_eux : filter_linear;
uniform bool avec_eux = false;
uniform vec4 couleur_nous : source_color = vec4(0.12, 0.36, 0.26, 1.0);
uniform vec4 couleur_eux : source_color = vec4(0.91, 0.90, 0.86, 1.0);
uniform float gris_moyen = 0.46;
uniform float gris_eux = 0.46;

vec3 teindre(vec3 c, vec3 couleur, float gris) {
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	float ombre = lum / gris;
	return couleur * min(ombre, 1.0) + clamp(ombre - 1.0, 0.0, 0.6) * vec3(0.25);
}

void fragment() {
	vec4 photo = texture(TEXTURE, UV);
	float sat = max(photo.r, max(photo.g, photo.b)) - min(photo.r, min(photo.g, photo.b));
	float gris = 1.0 - smoothstep(0.06, 0.16, sat);
	vec3 c = photo.rgb;
	float n = texture(masque_nous, UV).r * gris;
	c = mix(c, teindre(photo.rgb, couleur_nous.rgb, gris_moyen), n);
	if (avec_eux) {
		float e = texture(masque_eux, UV).r * gris * (1.0 - n);
		c = mix(c, teindre(photo.rgb, couleur_eux.rgb, gris_eux), e);
	}
	COLOR = vec4(clamp(c, 0.0, 1.0), photo.a * COLOR.a);
}
