shader_type spatial;
// Pelouse du rendu moderne (Forward+ seulement, voir match_rendu.gd).
// Couleur strictement identique à stadium_surface.gdshader : le bloc ALBEDO
// ci-dessous en est une copie conforme, vérifiée par tests/godot-match-rendu.cjs.
// Ajouts purement techniques : relief (normales) et rugosité.
render_mode diffuse_burley;
uniform float micro_detail : hint_range(0.0, 0.2) = 0.1;
uniform sampler2D brins : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D brins_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D taches : hint_default_white, filter_linear_mipmap, repeat_enable;
// 0 = sol plat (équivalent à l'ancien rendu), 1 = relief complet.
uniform float relief : hint_range(0.0, 1.0) = 1.0;
varying vec3 ground_position;
void vertex() {
	ground_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
void fragment() {
	// --- début copie conforme de stadium_surface.gdshader ---
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
	// --- fin copie conforme ---
	// Ces couleurs ont été réglées à l'œil sous gl_compatibility, qui éclaire
	// dans l'espace sRGB. Forward+ éclaire en espace linéaire : sans cette
	// conversion, la même valeur y donne une pelouse nettement plus claire et
	// plus grise. On garde donc la teinte réglée, pas la valeur brute.
	ALBEDO = mix(ALBEDO / 12.92, pow((ALBEDO + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), ALBEDO));
	// Même relief des brins que sous gl_compatibility, dosé par le niveau de
	// qualité, plus une ondulation très douce du sol (plusieurs mètres).
	vec3 tuft = texture(brins_normal, p / 6.0).rgb * 2.0 - 1.0;
	float strength = 0.55 * flatten * mix(0.3, 1.0, near) * relief;
	vec2 swell = vec2(sin(p.x * 0.23 + p.y * 0.07), sin(p.y * 0.19 - p.x * 0.05)) * 0.02 * relief;
	vec3 world_normal = normalize(vec3(tuft.x * strength + lean * 0.06 * relief + swell.x, 1.0, tuft.y * strength + swell.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
	// Gazon mat, très léger reflet rasant différent selon le sens de tonte.
	ROUGHNESS = mix(0.86, 0.94, stripe);
	SPECULAR = 0.08 * relief;
}
