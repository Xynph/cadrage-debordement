shader_type spatial;
// ESSAI « matières » (CD_ESSAI_MATIERES = A, B ou C) : tissu des tenues.
// Copie conforme de la logique d'athlete_kit.gdshader (couleurs des clubs et
// zones inchangées) ; seul le relief du tissu est ajouté après coup.
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
uniform vec4 jersey_color : source_color = vec4(0.63, 0.18, 0.25, 1.0);
uniform vec4 panel_color : source_color = vec4(0.43, 0.10, 0.15, 1.0);
uniform vec4 trim_color : source_color = vec4(0.87, 0.66, 0.61, 1.0);
uniform vec4 shorts_color : source_color = vec4(0.12, 0.17, 0.20, 1.0);
uniform vec4 socks_color : source_color = vec4(0.63, 0.18, 0.25, 1.0);
uniform vec4 skin_color : source_color = vec4(0.74, 0.55, 0.43, 1.0);
uniform vec4 hair_color : source_color = vec4(0.15, 0.12, 0.10, 1.0);
uniform int option = 1;
// Maille exportée de Material Maker (graphe tissu.ptex) ; plis : FastNoiseLite.
uniform sampler2D maille : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D plis : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
// Répétitions par unité du maillage de repos (≈ 0,048 unité = 1,85 m).
uniform float echelle_maille = 300.0;
uniform float echelle_plis = 22.0;

float triplanar(sampler2D tex, vec3 rest, vec3 w, vec2 scale) {
	return texture(tex, rest.zy * scale).r * w.x + texture(tex, rest.xz * scale).r * w.y + texture(tex, rest.xy * scale).r * w.z;
}

void fragment() {
	// UV/UV2 portent les attributs de repos : limites attachées au mesh.
	float h = UV.x;
	float x = UV.y;
	float depth = UV2.x;
	int part = int(floor(UV2.y + 0.5));
	vec3 color = jersey_color.rgb;
	float roughness = 0.92;
	if (part == 0 || part == 1) {
		// Panneaux originaux sobres : épaules, flancs et bord de manche.
		if (h > 0.0372 && abs(x) > 0.0036) color = panel_color.rgb;
		if (abs(x) > 0.0037 && h < 0.0350) color = panel_color.rgb;
		if (abs(x) > 0.0110) color = trim_color.rgb;
		if (h > 0.0394 && abs(x) < 0.0033) color = panel_color.rgb;
		// Fin accent sternum, sans logo, sponsor, boutons ni tenue de club réel.
		if (h > 0.0345 && h < 0.0350 && depth < -0.0010 && abs(x) < 0.0035) color = trim_color.rgb;
	} else if (part == 3) {
		color = shorts_color.rgb;
		if (h < 0.0190) color = skin_color.rgb;
		if (h < 0.0106) {
			color = socks_color.rgb;
			if (h > 0.0096) color = panel_color.rgb;
			if (h > 0.00975 && h < 0.0100) color = trim_color.rgb;
		}
	} else if (part == 5) {
		color = socks_color.rgb;
	} else if (part == 2) {
		color = skin_color.rgb;
		roughness = 0.81;
	} else if (part == 6 || part == 7) {
		color = hair_color.rgb * (part == 6 ? 0.84 : 1.0);
		roughness = 0.96;
	} else if (part == 4) {
		color = vec3(0.032, 0.043, 0.048);
		roughness = 0.82;
	} else if (part == 8) {
		color = vec3(0.028, 0.027, 0.024);
	}
	// --- fin de la copie conforme ---
	bool shirt = part == 0 || part == 1;
	bool cloth = shirt || part == 5 || (part == 3 && (h >= 0.0190 || h < 0.0106));
	if (cloth) {
		bool panel = shirt && all(equal(color, panel_color.rgb));
		// Coordonnées de repos (latéral, hauteur, profondeur) : le motif suit le corps.
		vec3 rest = vec3(x, h, depth);
		vec3 rn = normalize(cross(dFdx(rest), dFdy(rest)));
		vec3 w = pow(abs(rn), vec3(4.0));
		w /= (w.x + w.y + w.z + 1e-5);
		float s = echelle_maille;
		if (option == 3 && panel) s *= 0.45; // panneaux aérés : maille plus grosse
		float knit = triplanar(maille, rest, w, vec2(s));
		if (option == 3 && (part == 5 || (part == 3 && h < 0.0106))) {
			// Chaussettes côtelées : côtes verticales.
			knit = 0.5 + 0.5 * sin((x + depth) * 11600.0); // côtes d'environ 2 cm
		}
		float fold = 0.5;
		if (option >= 2) fold = triplanar(plis, rest, w, vec2(echelle_plis, echelle_plis * 3.0));
		// Ombrage de surface : luminance seulement, la teinte du club ne bouge pas.
		float knit_amp = option == 1 ? 0.035 : 0.05;
		color *= 1.0 + (knit - 0.5) * knit_amp - (option >= 2 ? (0.5 - fold) * 0.10 : 0.0);
		if (option == 3 && panel) color *= 1.0 + (knit - 0.5) * 0.10;
		// Relief sans tangentes (bump de Mikkelsen dans l'espace vue), hauteur en mètres.
		float height = knit * (option == 1 ? 0.0006 : 0.0005) + (option >= 2 ? fold * 0.012 : 0.0);
		vec3 dpx = dFdx(VERTEX);
		vec3 dpy = dFdy(VERTEX);
		vec3 r1 = cross(dpy, NORMAL);
		vec3 r2 = cross(NORMAL, dpx);
		float det = dot(dpx, r1);
		vec3 grad = sign(det) * (dFdx(height) * r1 + dFdy(height) * r2);
		NORMAL = normalize(abs(det) * NORMAL - grad);
		if (option >= 2) roughness = 0.84; // léger lustre du synthétique
	}
	ALBEDO = color;
	METALLIC = 0.0;
	ROUGHNESS = roughness;
}
