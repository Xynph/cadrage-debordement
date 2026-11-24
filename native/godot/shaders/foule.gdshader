shader_type spatial;
// Public du stade (match_view.gd, match_foule.gd) : quatre lots MultiMesh (torse, tête, jambes, bras)
// animés ici, sans nœud ni script par spectateur. Coût : quelques opérations par sommet.
// INSTANCE_CUSTOM = (phase 0..1, tribu, rang 0..1, tenue)
//   tribu : 0 domicile, 1 extérieur, 2 neutres ; rang : ordre de lever dans sa tribu ;
//   tenue : 0 aucune, 1 maillot aux couleurs du club, 2 écharpe aux couleurs du club.
// Couleurs d'instance (COLOR) écrites en sRGB et lues telles quelles sous gl_compatibility ;
// couleurs_srgb (Forward+, match_rendu.gd) les convertit en linéaire, comme vertex_color_is_srgb.

uniform int partie = 0; // 0 torse, 1 tête, 2 jambes assises, 3 bras levés / écharpe
uniform bool couleurs_srgb = false;
uniform vec4 couleur_domicile = vec4(0.83, 0.24, 0.28, 1.0);
uniform vec4 couleur_exterieur = vec4(0.44, 0.60, 0.79, 1.0);
uniform vec3 debout = vec3(0.0); // part debout par tribu
uniform vec3 bras = vec3(0.0); // part bras levés par tribu
// Foule vivante (match_ambiance.gd) : bruit FastNoiseLite qui défile sur les tribunes ; 0 = sans bruit.
uniform sampler2D bruit_foule : filter_linear, repeat_enable;
uniform float bruit_force = 0.0;
uniform float agitation = 0.2; // intensité d'ambiance 0..1 : amplitude du balancement

const float HAUSSE = 0.34; // hauteur gagnée par un spectateur debout (m)

varying vec3 teinte;

float de_tribu(vec3 v, float tribu) {
	return tribu < 0.5 ? v.x : (tribu < 1.5 ? v.y : v.z);
}

vec3 lineaire(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
}

void vertex() {
	vec4 info = INSTANCE_CUSTOM;
	float phase = info.x * 6.2831853;
	float tribu = info.y;
	float rang = info.z;
	// Debout si la part levée de sa tribu dépasse son rang : la tribu se lève en vague.
	float d = smoothstep(rang - 0.03, rang + 0.03, de_tribu(debout, tribu));
	float b = smoothstep(rang - 0.03, rang + 0.03, de_tribu(bras, tribu)) * d;
	// Balancement désynchronisé au repos, sautillement des bras levés.
	// Poches plus vives qui se déplacent lentement : jamais tout le public en même temps.
	vec3 lieu = MODEL_MATRIX[3].xyz;
	float n = bruit_force > 0.0 ? textureLod(bruit_foule, lieu.xz * 0.011 + vec2(TIME * 0.045, TIME * -0.03), 0.0).r : 0.5;
	float vif = mix(1.0, mix(0.35, 1.9, n), bruit_force);
	float poche = smoothstep(0.66, 0.82, n) * 0.11 * bruit_force;
	float balance = vif * sin(TIME * (1.1 + info.x * 0.7) + phase) * (0.018 + 0.05 * agitation);
	float saut = abs(sin(TIME * 7.0 + phase)) * 0.07 * b;
	float hausse = HAUSSE * d + saut + poche * (1.0 - d);
	// Échelles de l'instance (rotation autour de la verticale seulement) : décalages en mètres.
	float sx = max(length(MODEL_MATRIX[0].xyz), 0.001);
	float sy = max(length(MODEL_MATRIX[1].xyz), 0.001);
	float haut = VERTEX.y + 0.5; // 0 en bas d'une boîte unité, 1 en haut
	if (partie == 0) {
		VERTEX.y += hausse / sy;
		VERTEX.x += balance * haut / sx;
	} else if (partie == 1) {
		VERTEX.y += hausse / sy;
		VERTEX.x += balance / sx;
	} else if (partie == 2) {
		// Jambes : debout, la boîte s'étire jusqu'aux hanches levées.
		VERTEX.y += HAUSSE * d * haut / sy;
	} else {
		// Bras levés ou écharpe tendue : invisibles (repliés au centre) tant que b vaut 0.
		VERTEX *= b;
		VERTEX.y += hausse / sy;
		float agite = info.w > 1.5 ? sin(TIME * 4.5 + phase) * 0.12 : sin(TIME * 6.0 + phase) * 0.04;
		VERTEX.x += (balance + agite) * b / sx;
	}
	vec3 c = COLOR.rgb;
	bool club = (partie == 0 && info.w > 0.5 && info.w < 1.5) || (partie == 3 && info.w > 1.5);
	if (club && tribu < 1.5) {
		c = tribu < 0.5 ? couleur_domicile.rgb : couleur_exterieur.rgb;
	}
	teinte = couleurs_srgb ? lineaire(c) : c;
}

void fragment() {
	ALBEDO = teinte;
	ROUGHNESS = 0.95;
}
