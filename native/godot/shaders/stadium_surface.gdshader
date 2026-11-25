shader_type spatial;
// Pelouse du stade (GL Compatibility). Forward+ : stadium_surface_moderne.gdshader,
// qui recopie à l'identique le bloc de couleur ci-dessous.
// Matière choisie par Léo le 24/11/2026 (essai « matières », option B) : bandes
// de tonte, variation de teinte, usure discrète (herbe pâlie et clairsemée)
// devant les poteaux et au centre, relief des brins. Décor fixe : rien ne
// dépend du match. Textures : art/matieres/ (hauteur exportée de Material
// Maker, relief tiré de cette hauteur) ; taches : FastNoiseLite (match_matieres.gd).
render_mode diffuse_burley, specular_disabled;
uniform float micro_detail : hint_range(0.0, 0.2) = 0.1;
uniform sampler2D brins : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D brins_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D taches : hint_default_white, filter_linear_mipmap, repeat_enable;
varying vec3 ground_position;
void vertex() {
	ground_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
void fragment() {
	vec2 p = ground_position.xz;
	float stripe = mod(floor((p.x + 55.0) / 10.0), 2.0);
	// Sens des brins couchés par la tondeuse, alterné d'une bande à l'autre.
	float lean = 1.0 - stripe * 2.0;
	vec3 grass = mix(vec3(0.116, 0.226, 0.124), vec3(0.146, 0.268, 0.152), stripe);
	// Fine blades fade with projected pixel size, preventing distant shimmer.
	float grain = hash21(floor(p * vec2(25.0, 45.0))) - 0.5;
	float detail = 1.0 - smoothstep(0.025, 0.14, length(fwidth(p)));
	float near = 1.0 - smoothstep(0.03, 0.30, length(fwidth(p)));
	float broad = sin(p.x * 0.51 + sin(p.y * 0.37)) * sin(p.y * 0.63);
	float field = sin(p.x * 0.17 + p.y * 0.11) * sin(p.y * 0.24 - p.x * 0.09);
	// Reflet de tonte : la bande s'éclaircit ou s'assombrit selon le côté d'où
	// la caméra la regarde.
	vec3 to_ground = normalize(ground_position - INV_VIEW_MATRIX[3].xyz);
	float sheen = lean * to_ground.x * 0.10;
	// Touffes (Material Maker, tuile de 6 m).
	float blade = (texture(brins, p / 6.0).r - 0.5) * 0.16 * mix(0.4, 1.0, near);
	// Plaques un peu plus jaunes ou plus bleutées, sur une quarantaine de mètres.
	float tache = texture(taches, p / 46.0).r;
	vec3 tint = mix(vec3(0.95, 0.99, 1.05), vec3(1.05, 1.03, 0.86), smoothstep(0.30, 0.72, tache));
	// Usure discrète devant les poteaux et au rond central : herbe pâlie,
	// jaunie et clairsemée (jamais couleur terre), opacité limitée à 45 %.
	float posts = 1.0 - smoothstep(4.0, 12.0, length(vec2((abs(p.x) - 49.0) * 0.8, p.y)));
	float centre = 1.0 - smoothstep(2.0, 8.0, length(vec2(p.x * 0.9, p.y)));
	float zone = max(posts, centre);
	float sparse = texture(taches, p / 3.0).r;
	float wear = zone * smoothstep(0.35, 0.75, sparse + zone * 0.25) * 0.45;
	vec3 faded = mix(vec3(1.0), vec3(1.16, 1.10, 0.80), wear);
	float flatten = 1.0 - wear;
	ALBEDO = grass * tint * faded * (1.0 + broad * 0.035 + field * 0.025 + sheen + blade + grain * detail * micro_detail);
	ROUGHNESS = 1.0;
	// Relief des brins : normal map dans le plan du sol (+Y), atténuée au loin.
	vec3 tuft = texture(brins_normal, p / 6.0).rgb * 2.0 - 1.0;
	float strength = 0.55 * flatten * mix(0.3, 1.0, near);
	vec3 world_normal = normalize(vec3(tuft.x * strength + lean * 0.06, 1.0, tuft.y * strength));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
}
