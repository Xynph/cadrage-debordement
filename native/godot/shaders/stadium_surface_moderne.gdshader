shader_type spatial;
// Pelouse du rendu moderne (Forward+ seulement, voir match_rendu.gd).
// Couleur strictement identique à stadium_surface.gdshader : le bloc ALBEDO
// ci-dessous en est une copie conforme, vérifiée par tests/godot-match-rendu.cjs.
// Ajouts purement techniques : relief (normales) et rugosité.
render_mode diffuse_burley;
uniform float micro_detail : hint_range(0.0, 0.2) = 0.1;
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
	// Mowing bands support tactical orientation without overwhelming the lines.
	vec3 grass = mix(vec3(0.124, 0.237, 0.132), vec3(0.139, 0.257, 0.146), stripe);
	// Fine blades fade with projected pixel size, preventing distant shimmer.
	float grain = hash21(floor(p * vec2(25.0, 45.0))) - 0.5;
	float detail = 1.0 - smoothstep(0.025, 0.14, length(fwidth(p)));
	float broad = sin(p.x * 0.51 + sin(p.y * 0.37)) * sin(p.y * 0.63);
	// Restrained, static variation in the turf; no weather or match wear inferred.
	float field = sin(p.x * 0.17 + p.y * 0.11) * sin(p.y * 0.24 - p.x * 0.09);
	ALBEDO = grass * (1.0 + broad * 0.035 + field * 0.025 + grain * detail * micro_detail);
	// --- fin copie conforme ---
	// Ces couleurs ont été réglées à l'œil sous gl_compatibility, qui éclaire
	// dans l'espace sRGB. Forward+ éclaire en espace linéaire : sans cette
	// conversion, la même valeur y donne une pelouse nettement plus claire et
	// plus grise. On garde donc la teinte réglée, pas la valeur brute.
	ALBEDO = mix(ALBEDO / 12.92, pow((ALBEDO + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), ALBEDO));
	// Brins couchés par la tondeuse, dans un sens puis l'autre d'une bande à
	// l'autre. Sens choisi pour que la bande claire penche vers le soleil du
	// stade (venant de -x) : le relief renforce les bandes existantes au lieu
	// de les effacer.
	float lean = (1.0 - stripe * 2.0) * 0.07 * relief;
	// Ondulation très douce du sol, à l'échelle de plusieurs mètres.
	vec2 swell = vec2(sin(p.x * 0.23 + p.y * 0.07), sin(p.y * 0.19 - p.x * 0.05)) * 0.02 * relief;
	// Grain de surface : s'efface avec la taille du pixel comme le grain de couleur.
	vec2 tuft = vec2(hash21(floor(p * 9.0)), hash21(floor(p * 9.0) + 17.0)) - 0.5;
	tuft *= 0.12 * relief * detail;
	vec3 world_normal = normalize(vec3(lean + swell.x + tuft.x, 1.0, swell.y + tuft.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
	// Gazon mat, très léger reflet rasant différent selon le sens de tonte.
	ROUGHNESS = mix(0.86, 0.94, stripe);
	SPECULAR = 0.08 * relief;
}
