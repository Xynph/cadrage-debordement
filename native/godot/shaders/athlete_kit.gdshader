shader_type spatial;
// Tenues des joueurs du match 3D. Les couleurs viennent des clubs (paramètres) ;
// la logique des zones ci-dessous ne change pas. Matière du tissu (24/11/2026,
// option B de l'essai « matières ») : maille fine (Material Maker, art/matieres/)
// et plis (FastNoiseLite), en relief et en luminance seulement, jamais en teinte.
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
uniform vec4 jersey_color : source_color = vec4(0.63, 0.18, 0.25, 1.0);
uniform vec4 panel_color : source_color = vec4(0.43, 0.10, 0.15, 1.0);
uniform vec4 trim_color : source_color = vec4(0.87, 0.66, 0.61, 1.0);
uniform vec4 shorts_color : source_color = vec4(0.12, 0.17, 0.20, 1.0);
uniform vec4 socks_color : source_color = vec4(0.63, 0.18, 0.25, 1.0);
uniform vec4 skin_color : source_color = vec4(0.74, 0.55, 0.43, 1.0);
uniform vec4 hair_color : source_color = vec4(0.15, 0.12, 0.10, 1.0);
// Maille et plis fournis par match_matieres.gd.
uniform sampler2D maille : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D plis : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
// Répétitions par unité du maillage de repos (≈ 0,048 unité = 1,85 m) ; la
// tuile de maille compte 32 mailles.
uniform float echelle_maille = 300.0;
uniform float echelle_plis = 22.0;
const float MAILLES_PAR_TUILE = 32.0;
const float PLIS_PAR_TUILE = 5.0;

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
	// --- fin de la logique des couleurs ---
	bool shirt = part == 0 || part == 1;
	bool cloth = shirt || part == 5 || (part == 3 && (h >= 0.0190 || h < 0.0106));
	if (cloth) {
		// Coordonnées de repos (latéral, hauteur, profondeur) : le motif suit le corps.
		vec3 rest = vec3(x, h, depth);
		vec3 rest_dx = dFdx(rest);
		vec3 rest_dy = dFdy(rest);
		vec3 rn = normalize(cross(rest_dx, rest_dy));
		vec3 w = pow(abs(rn), vec3(4.0));
		w /= (w.x + w.y + w.z + 1e-5);
		// Anticrénelage : la maille s'efface sous ~3 pixels par maille, les plis
		// sous ~5 pixels par ondulation (sinon rayures fines en diagonale).
		float footprint = max(length(rest_dx), length(rest_dy));
		float knit_fade = 1.0 - smoothstep(0.2, 0.35, footprint * echelle_maille * MAILLES_PAR_TUILE);
		// Plis : ~5 ondulations par tuile de bruit, 2 octaves (la plus fine au double).
		float fold_fade = 1.0 - smoothstep(0.06, 0.20, footprint * echelle_plis * 3.0 * PLIS_PAR_TUILE * 2.0);
		float knit = mix(0.5, triplanar(maille, rest, w, vec2(echelle_maille)), knit_fade);
		float fold = mix(0.5, triplanar(plis, rest, w, vec2(echelle_plis, echelle_plis * 3.0)), fold_fade);
		// Ombrage de surface : luminance seulement, la teinte du club ne bouge pas.
		color *= 1.0 + (knit - 0.5) * 0.05 - (0.5 - fold) * 0.10;
		// Relief sans tangentes (bump de Mikkelsen dans l'espace vue), hauteur en mètres.
		float height = knit * 0.0005 + fold * 0.012;
		vec3 dpx = dFdx(VERTEX);
		vec3 dpy = dFdy(VERTEX);
		vec3 r1 = cross(dpy, NORMAL);
		vec3 r2 = cross(NORMAL, dpx);
		float det = dot(dpx, r1);
		vec3 grad = sign(det) * (dFdx(height) * r1 + dFdy(height) * r2);
		NORMAL = normalize(abs(det) * NORMAL - grad);
		roughness = 0.84; // léger lustre du synthétique
	}
	ALBEDO = color;
	METALLIC = 0.0;
	ROUGHNESS = roughness;
}
