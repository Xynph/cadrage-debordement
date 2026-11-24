shader_type spatial;
// ESSAI « matières » (CD_ESSAI_MATIERES = A, B ou C) : pelouse des temps forts.
// Sans la variable, le jeu garde stadium_surface.gdshader (inchangé).
// Présentation seule : l'usure est un décor fixe (en-buts, centre), pas une
// conséquence du match.
render_mode diffuse_burley, specular_disabled;
uniform int option = 1;
uniform float micro_detail : hint_range(0.0, 0.2) = 0.1;
// Hauteur des brins exportée de Material Maker (graphe pelouse.ptex).
uniform sampler2D brins : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D brins_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// Grandes taches : FastNoiseLite sans couture, calculé au chargement.
uniform sampler2D taches : hint_default_white, filter_linear_mipmap, repeat_enable;
varying vec3 ground_position;
void vertex() {
	ground_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = ground_position.xz;
	float stripe = mod(floor((p.x + 55.0) / 10.0), 2.0);
	float lean_x = 1.0 - stripe * 2.0;
	float lean_z = 0.0;
	if (option == 3) {
		// Damier : bandes croisées de 10 m (longueur) et 7 m (largeur).
		float cross_band = mod(floor((p.y + 35.0) / 7.0), 2.0);
		lean_z = 1.0 - cross_band * 2.0;
		stripe = abs(stripe - cross_band);
	}
	vec3 dark = vec3(0.116, 0.226, 0.124);
	vec3 light = vec3(0.146, 0.268, 0.152);
	vec3 grass = mix(dark, light, stripe);
	float broad = sin(p.x * 0.51 + sin(p.y * 0.37)) * sin(p.y * 0.63);
	float field = sin(p.x * 0.17 + p.y * 0.11) * sin(p.y * 0.24 - p.x * 0.09);
	grass *= 1.0 + broad * 0.035 + field * 0.025;
	// Reflet de tonte : une bande s'éclaircit ou s'assombrit selon le côté
	// d'où la caméra la regarde (brins couchés dans un sens puis l'autre).
	vec3 camera = INV_VIEW_MATRIX[3].xyz;
	vec3 to_ground = normalize(ground_position - camera);
	float sheen = (lean_x * to_ground.x + lean_z * to_ground.z) * 0.10;
	grass *= 1.0 + sheen;
	// Brins et touffes (Material Maker), tuile de 6 m.
	float blade = texture(brins, p / 6.0).r - 0.5;
	float near = 1.0 - smoothstep(0.03, 0.30, length(fwidth(p)));
	grass *= 1.0 + blade * (option == 1 ? 0.10 : 0.16) * mix(0.4, 1.0, near);
	float relief = option == 1 ? 0.0 : 1.0;
	if (option == 2) {
		// Variation naturelle : plaques plus jaunes ou plus bleutées sur ~40 m.
		float tache = texture(taches, p / 46.0).r;
		vec3 jaune = vec3(1.05, 1.03, 0.86);
		vec3 bleu = vec3(0.95, 0.99, 1.05);
		grass *= mix(bleu, jaune, smoothstep(0.30, 0.72, tache));
		// Usure : devant et derrière les poteaux, et au centre (coups d'envoi).
		float but = 1.0 - smoothstep(4.0, 12.0, length(vec2((abs(p.x) - 49.0) * 0.8, p.y)));
		float centre = 1.0 - smoothstep(2.0, 8.0, length(vec2(p.x * 0.9, p.y)));
		float casse = texture(taches, p / 7.0).r;
		float usure = clamp(max(but, centre) * smoothstep(0.25, 0.65, casse + max(but, centre) * 0.35), 0.0, 1.0);
		vec3 terre = vec3(0.235, 0.215, 0.140);
		grass = mix(grass, mix(grass, terre, 0.55), usure * 0.85);
		relief *= 1.0 - usure * 0.5;
	}
	ALBEDO = grass;
	ROUGHNESS = 1.0;
	if (relief > 0.0) {
		vec3 n = texture(brins_normal, p / 6.0).rgb * 2.0 - 1.0;
		float force = 0.55 * relief * mix(0.3, 1.0, near);
		vec3 world_normal = normalize(vec3(n.x * force + lean_x * 0.06, 1.0, n.y * force + lean_z * 0.06));
		NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
	}
}
